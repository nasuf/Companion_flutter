import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'models.dart';
import 'socket_ticket.dart';

/// Admin-only inbox. It never connects to `/ws/{conversationId}`.
class TakeoverInbox {
  TakeoverInbox._();

  static final TakeoverInbox instance = TakeoverInbox._();

  final _events = StreamController<WsEnvelope>.broadcast();
  WebSocket? _socket;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  String? _baseUrl;
  String? _adminId;
  Future<String> Function()? _ticketProvider;
  int _generation = 0;
  bool _disposed = false;
  String? activeTakeoverId;

  Stream<WsEnvelope> get events => _events.stream;

  void start({
    required String baseUrl,
    required String adminId,
    required Future<String> Function() ticketProvider,
  }) {
    if (_adminId == adminId &&
        _baseUrl == baseUrl &&
        _socket?.readyState == WebSocket.open) {
      return;
    }
    _baseUrl = baseUrl;
    _adminId = adminId;
    _ticketProvider = ticketProvider;
    _disposed = false;
    unawaited(_connect());
  }

  Future<void> stop() async {
    _disposed = true;
    _generation++;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    final socket = _socket;
    _socket = null;
    _adminId = null;
    activeTakeoverId = null;
    if (socket != null) {
      try {
        await socket.close(1000, 'stopped');
      } catch (_) {}
    }
  }

  Future<void> _connect() async {
    final provider = _ticketProvider;
    final adminId = _adminId;
    final baseUrl = _baseUrl;
    if (provider == null || adminId == null || baseUrl == null || _disposed) {
      return;
    }
    final generation = ++_generation;
    try {
      final ticket = await provider().timeout(const Duration(seconds: 15));
      if (_disposed || generation != _generation) return;
      final normalized = baseUrl.replaceFirst(RegExp('^http'), 'ws');
      final uri = Uri.parse(
        '$normalized/ws/admin-inbox/${Uri.encodeComponent(adminId)}',
      );
      final socket = await WebSocket.connect(
        uri.toString(),
        protocols: ['companion.chat.v1', 'companion.ticket.$ticket'],
      ).timeout(const Duration(seconds: 15));
      if (_disposed || generation != _generation) {
        await socket.close(1000, 'disposed');
        return;
      }
      _socket = socket;
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        if (socket.readyState == WebSocket.open) {
          socket.add(jsonEncode({'type': 'ping'}));
        }
      });
      socket.listen(
        (message) {
          if (_disposed || _socket != socket) return;
          final decoded = jsonDecode(message is String ? message : utf8.decode(message));
          if (decoded is Map<String, dynamic>) {
            _events.add(WsEnvelope.fromJson(decoded));
          } else if (decoded is Map) {
            _events.add(WsEnvelope.fromJson(Map<String, dynamic>.from(decoded)));
          }
        },
        onDone: () {
          if (_socket == socket) _scheduleReconnect();
        },
        onError: (_) {
          if (_socket == socket) _scheduleReconnect();
        },
        cancelOnError: false,
      );
    } on SocketTicketException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) return;
      _scheduleReconnect();
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      unawaited(_connect());
    });
  }
}
