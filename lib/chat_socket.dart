import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'models.dart';

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
    this.token,
  });

  final String baseUrl;
  final String conversationId;

  /// JWT for the current session. conversation_id is not a capability token;
  /// the backend requires a valid JWT owner. Sent as the `token` query param
  /// (WebSocket handshakes cannot carry custom headers uniformly).
  final String? token;

  final _events = StreamController<WsEnvelope>.broadcast();
  final _states = StreamController<ChatSocketState>.broadcast();
  WebSocket? _socket;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _disposed = false;
  bool _intentionalClose = false;
  int _reconnectAttempt = 0;

  Stream<WsEnvelope> get events => _events.stream;
  Stream<ChatSocketState> get states => _states.stream;

  bool get isOpen => _socket?.readyState == WebSocket.open;

  Uri _wsUri() {
    final normalized = baseUrl.replaceFirst(RegExp('^http'), 'ws');
    final base = '$normalized/ws/$conversationId';
    final t = token;
    if (t == null || t.isEmpty) return Uri.parse(base);
    return Uri.parse('$base?token=${Uri.encodeQueryComponent(t)}');
  }

  Future<void> connect() async {
    if (_disposed) return;
    final current = _socket;
    if (current != null &&
        (current.readyState == WebSocket.open ||
            current.readyState == WebSocket.connecting)) {
      return;
    }

    _intentionalClose = false;
    _states.add(const ChatSocketState(ChatSocketStatus.connecting));
    try {
      final socket = await WebSocket.connect(_wsUri().toString());
      if (_disposed) {
        await socket.close(1000, 'disposed');
        return;
      }
      _socket = socket;
      _reconnectAttempt = 0;
      _states.add(const ChatSocketState(ChatSocketStatus.open));
      _startKeepalive();

      socket.listen(
        _handleMessage,
        onDone: () => _handleClose(socket),
        onError: (_) {
          if (_socket == socket) {
            _states.add(const ChatSocketState(ChatSocketStatus.error));
          }
        },
        cancelOnError: false,
      );
    } catch (error) {
      _states.add(ChatSocketState(ChatSocketStatus.error, reason: '$error'));
      _scheduleReconnect();
    }
  }

  bool sendMessage(
    String text,
    String clientId, {
    ChatComponentCard? componentCard,
    List<ChatAttachment> attachments = const [],
  }) {
    return send({
      'type': 'message',
      'data': {
        'message': text,
        'client_id': clientId,
        if (componentCard != null) 'component_card': componentCard.toJson(),
        if (attachments.isNotEmpty)
          'attachments': attachments.map((item) => item.toJson()).toList(),
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
        final envelope = WsEnvelope.fromJson(json);
        _events.add(envelope);
      }
    } catch (_) {
      // Ignore malformed frames; the server protocol is JSON envelopes.
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
    if (!_intentionalClose) _scheduleReconnect();
  }

  void _startKeepalive() {
    _stopKeepalive();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      send({'type': 'ping'});
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
    _reconnectTimer?.cancel();
    _stopKeepalive();
    final socket = _socket;
    _socket = null;
    await socket?.close(1000, 'user');
    await _events.close();
    await _states.close();
  }
}
