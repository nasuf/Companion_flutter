import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'models.dart';
import 'socket_ticket.dart';
import 'companion_api.dart';

enum ChatSocketStatus { disconnected, connecting, open, closed, error }

class ChatSocketState {
  const ChatSocketState(this.status, {this.code, this.reason});

  final ChatSocketStatus status;
  final int? code;
  final String? reason;
}

class ChatSocket {
  ChatSocket({
    required this.baseUrl,
    required this.conversationId,
    required this.ticketProvider,
    this.replyEventProvider,
  });

  final String baseUrl;
  final String conversationId;
  final Future<String> Function() ticketProvider;
  int _generation = 0;
  final Future<ReplyEventPage> Function(int? afterSequence)? replyEventProvider;

  final _events = StreamController<WsEnvelope>.broadcast();
  final _states = StreamController<ChatSocketState>.broadcast();
  WebSocket? _socket;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _disposed = false;
  bool _intentionalClose = false;
  int _reconnectAttempt = 0;
  bool _connecting = false;
  final _seenEventIds = <String>{};
  int? _replySequence;
  WebSocket? _replayingFor;
  bool _replayUnavailable = false;

  Stream<WsEnvelope> get events => _events.stream;
  Stream<ChatSocketState> get states => _states.stream;

  bool get isOpen => _socket?.readyState == WebSocket.open;

  Uri _wsUri() {
    final normalized = baseUrl.replaceFirst(RegExp('^http'), 'ws');
    return Uri.parse(
      '$normalized/ws/$conversationId',
    ).replace(queryParameters: const {'client': 'flutter'});
  }

  Future<void> connect() async {
    if (_disposed || _connecting) return;
    final current = _socket;
    if (current != null &&
        (current.readyState == WebSocket.open ||
            current.readyState == WebSocket.connecting)) {
      return;
    }

    _connecting = true;
    final generation = ++_generation;
    _intentionalClose = false;
    _states.add(const ChatSocketState(ChatSocketStatus.connecting));
    try {
      final ticket = await ticketProvider().timeout(
        const Duration(seconds: 15),
      );
      if (_disposed || generation != _generation) return;
      if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(ticket)) {
        throw const SocketTicketException(502);
      }
      var timedOut = false;
      final opening = WebSocket.connect(
        _wsUri().toString(),
        protocols: ['companion.chat.v1', 'companion.ticket.$ticket'],
      );
      unawaited(
        opening.then((lateSocket) async {
          if (_disposed || generation != _generation || timedOut) {
            await lateSocket.close(1000, 'cancelled');
          }
        }, onError: (Object error) {}),
      );
      final socket = await opening.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          timedOut = true;
          throw TimeoutException('WebSocket connection timed out');
        },
      );
      if (_disposed || generation != _generation) {
        await socket.close(1000, 'disposed');
        return;
      }
      _socket = socket;
      _reconnectAttempt = 0;
      _states.add(const ChatSocketState(ChatSocketStatus.open));
      _startKeepalive();
      unawaited(_replayReplies(socket));

      socket.listen(
        (message) {
          if (!_disposed && _socket == socket) {
            _handleMessage(message);
            unawaited(_replayReplies(socket));
          }
        },
        onDone: () => _handleClose(socket),
        onError: (_) {
          if (_socket == socket) {
            _states.add(const ChatSocketState(ChatSocketStatus.error));
          }
        },
        cancelOnError: false,
      );
    } catch (error) {
      if (_disposed || generation != _generation) return;
      final status = error is SocketTicketException ? error.statusCode : null;
      _states.add(
        ChatSocketState(
          ChatSocketStatus.error,
          code: status,
          reason: status == 401
              ? '登录已过期，请重新登录'
              : status == 403
              ? '无权访问此会话'
              : '聊天连接暂时不可用',
        ),
      );
      if (![401, 403, 404, 410].contains(status)) _scheduleReconnect();
    } finally {
      if (generation == _generation) _connecting = false;
    }
  }

  bool sendMessage(
    String text,
    String clientId, {
    ChatComponentCard? componentCard,
    List<ChatAttachment> attachments = const [],
    bool paidConfirmed = false,
  }) {
    return send({
      'type': 'message',
      'data': {
        'message': text,
        'client_id': clientId,
        if (componentCard != null) 'component_card': componentCard.toJson(),
        if (attachments.isNotEmpty)
          'attachments': attachments.map((item) => item.toJson()).toList(),
        // CLAUDE.md 权益项 1: 用户在额度确认框里点了"继续发送"才为 true；
        // 服务端只在这个值为 true 时才真正扣钞票，否则超额消息会被拒绝。
        if (paidConfirmed) 'paid_confirmed': true,
      },
    });
  }

  bool send(Map<String, dynamic> payload) {
    final socket = _socket;
    if (socket == null || socket.readyState != WebSocket.open) return false;
    socket.add(jsonEncode(payload));
    return true;
  }

  void _handleMessage(dynamic message) {
    try {
      final json = jsonDecode(message as String);
      if (json is Map<String, dynamic>) {
        _emitEnvelope(WsEnvelope.fromJson(json));
      }
    } catch (_) {
      // Ignore malformed frames; the server protocol is JSON envelopes.
    }
  }

  void _emitEnvelope(WsEnvelope envelope) {
    if (_disposed) return;
    final eventId = envelope.data['event_id'];
    if (eventId is String && eventId.isNotEmpty && eventId.length <= 128) {
      if (!_seenEventIds.add(eventId)) return;
      if (_seenEventIds.length > 2048) {
        _seenEventIds.remove(_seenEventIds.first);
      }
    }
    _events.add(envelope);
  }

  Future<void> _replayReplies(WebSocket socket) async {
    final provider = replyEventProvider;
    if (provider == null ||
        _disposed ||
        _socket != socket ||
        _replayingFor == socket ||
        _replayUnavailable) {
      return;
    }
    _replayingFor = socket;
    var more = false;
    try {
      for (var pageNumber = 0; pageNumber < 8; pageNumber++) {
        final page = await provider(
          _replySequence,
        ).timeout(const Duration(seconds: 15));
        if (_disposed || _socket != socket) return;
        if (page.nextSequence < (_replySequence ?? 0) ||
            (page.hasMore &&
                (page.events.isEmpty ||
                    page.nextSequence <= (_replySequence ?? 0)))) {
          throw StateError('Invalid replay cursor');
        }
        for (final event in page.events) {
          _emitEnvelope(event);
        }
        final recoverAll = _replySequence == null && page.activeWaitsTruncated;
        _replySequence = recoverAll ? 0 : page.nextSequence;
        more = recoverAll || page.hasMore;
        if (!more) break;
      }
    } catch (error) {
      if (!_disposed && _socket == socket && error is ApiException) {
        if (error.statusCode == 404) _replayUnavailable = true;
        if ([401, 403, 410].contains(error.statusCode)) {
          _replayUnavailable = true;
          await socket.close(4403, '授权已失效');
        }
      }
      more = false;
    } finally {
      if (_replayingFor == socket) _replayingFor = null;
    }
    if (more && !_disposed && _socket == socket) {
      Timer.run(() => unawaited(_replayReplies(socket)));
    }
  }

  void _handleClose(WebSocket socket) {
    if (_socket != socket) return;
    _stopKeepalive();
    _socket = null;
    _states.add(
      ChatSocketState(
        ChatSocketStatus.closed,
        code: socket.closeCode,
        reason: socket.closeReason,
      ),
    );
    if (!_intentionalClose && socket.closeCode != 4403) _scheduleReconnect();
  }

  void _startKeepalive() {
    _stopKeepalive();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      send({'type': 'ping'});
      final socket = _socket;
      if (socket != null) unawaited(_replayReplies(socket));
    });
  }

  void _stopKeepalive() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void _scheduleReconnect() {
    if (_disposed || _intentionalClose) return;
    _reconnectTimer?.cancel();
    final millis = (1500 * _pow(1.5, _reconnectAttempt)).round();
    final delay = Duration(milliseconds: millis.clamp(1500, 8000));
    _reconnectAttempt += 1;
    _reconnectTimer = Timer(delay, connect);
  }

  num _pow(num base, int exponent) {
    var result = 1.0;
    for (var i = 0; i < exponent; i += 1) {
      result *= base;
    }
    return result;
  }

  Future<void> close() async {
    _intentionalClose = true;
    _disposed = true;
    _generation += 1;
    _connecting = false;
    _reconnectTimer?.cancel();
    _stopKeepalive();
    final socket = _socket;
    _socket = null;
    await socket?.close(1000, 'user');
    await _events.close();
    await _states.close();
  }
}
