import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Lightweight WebSocket client for /ws/voice/{conversationId}.
///
/// Uses the same ticket-based auth as the text-chat socket. Audio is sent as
/// binary PCM16 frames; all other messages are JSON.
enum VoiceCallStatus { connecting, ready, active, ended, error }

class VoiceCallSocket {
  VoiceCallSocket({
    required this.baseUrl,
    required this.conversationId,
    required this.ticketProvider,
  });

  final String baseUrl;
  final String conversationId;
  final Future<String> Function() ticketProvider;

  WebSocket? _socket;
  bool _disposed = false;
  Timer? _pingTimer;

  final _statusCtrl = StreamController<VoiceCallStatus>.broadcast();
  final _audioCtrl = StreamController<Uint8List>.broadcast();
  final _stateCtrl = StreamController<String>.broadcast();

  Stream<VoiceCallStatus> get statusStream => _statusCtrl.stream;
  Stream<Uint8List> get audioChunks => _audioCtrl.stream;

  /// Raw event type stream for UI state tracking (speech.started, response.started, etc.)
  Stream<String> get rawEvents => _stateCtrl.stream;

  String? agentName;
  String? voice;
  String? model;
  int sampleRate = 24000;

  /// Server-provided reason from the last `error` event, if any.
  String? errorMessage;

  VoiceCallStatus _lastStatus = VoiceCallStatus.connecting;
  VoiceCallStatus get currentStatus => _lastStatus;

  /// The server tunes speech detection per platform: Android's call capture
  /// is much quieter than iOS voice processing.
  Uri _wsUri() {
    final normalized = baseUrl.replaceFirst(RegExp('^http'), 'ws');
    return Uri.parse('$normalized/ws/voice/$conversationId')
        .replace(queryParameters: {'platform': Platform.operatingSystem});
  }

  Future<bool> connect() async {
    if (_disposed) return false;
    _setStatus(VoiceCallStatus.connecting);

    try {
      final ticket = await ticketProvider().timeout(
        const Duration(seconds: 15),
      );
      if (_disposed) return false;
      if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(ticket)) {
        _setStatus(VoiceCallStatus.error);
        return false;
      }

      final socket = await WebSocket.connect(
        _wsUri().toString(),
        protocols: ['companion.chat.v1', 'companion.ticket.$ticket'],
      ).timeout(const Duration(seconds: 15));

      if (_disposed) {
        await socket.close(1000, 'disposed');
        return false;
      }

      _socket = socket;
      _startKeepalive();

      socket.listen(
        _handleMessage,
        onDone: () {
          if (!_disposed) {
            _setStatus(VoiceCallStatus.ended);
          }
        },
        onError: (_) {
          if (!_disposed) {
            _setStatus(VoiceCallStatus.error);
          }
        },
      );
      return true;
    } on TimeoutException {
      if (!_disposed) _setStatus(VoiceCallStatus.error);
      return false;
    } catch (_) {
      if (!_disposed) _setStatus(VoiceCallStatus.error);
      return false;
    }
  }

  void sendAudio(Uint8List pcm) {
    final s = _socket;
    if (s != null && s.readyState == WebSocket.open) {
      s.add(pcm);
    }
  }

  void sendGreet() => _sendJson({'type': 'greet'});
  void sendInterrupt() => _sendJson({'type': 'interrupt'});

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _pingTimer?.cancel();
    _pingTimer = null;
    final s = _socket;
    _socket = null;
    try {
      await s?.close(1000, 'user_hangup');
    } catch (_) {}
    unawaited(_statusCtrl.close());
    unawaited(_audioCtrl.close());
    unawaited(_stateCtrl.close());
  }

  // ---------------------------------------------------------------------------

  void _handleMessage(dynamic message) {
    if (_disposed || message is! String) return;
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final type = data['type'] as String?;
      if (type == null) return;

      switch (type) {
        case 'ready':
          sampleRate = (data['sample_rate'] as num?)?.toInt() ?? 24000;
          agentName = data['agent_name'] as String?;
          voice = data['voice'] as String?;
          model = data['model'] as String?;
          _setStatus(VoiceCallStatus.ready);
        case 'speech.started':
          _stateCtrl.add(type);
          _setStatus(VoiceCallStatus.active);
        case 'speech.stopped':
        case 'response.started':
        case 'response.done':
        case 'audio.done':
        case 'interrupted':
          _stateCtrl.add(type);
        case 'transcript.user':
        case 'transcript.assistant':
          // The call UI is audio-only; transcripts are persisted server-side.
          break;
        case 'audio.delta':
          final b64 = data['audio'] as String?;
          if (b64 != null && b64.isNotEmpty) {
            try {
              _audioCtrl.add(base64Decode(b64));
            } catch (_) {}
          }
        case 'warning':
          // Warnings don't change status but could be surfaced later.
          break;
        case 'error':
          errorMessage = data['message'] as String?;
          _setStatus(VoiceCallStatus.error);
        case 'session.expiring':
          _stateCtrl.add(type);
        case 'pong':
          break;
      }
    } catch (_) {}
  }

  void _setStatus(VoiceCallStatus status) {
    _lastStatus = status;
    if (!_statusCtrl.isClosed) _statusCtrl.add(status);
  }

  void _sendJson(Map<String, dynamic> event) {
    final s = _socket;
    if (s != null && s.readyState == WebSocket.open) {
      s.add(jsonEncode(event));
    }
  }

  void _startKeepalive() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _sendJson({'type': 'ping'});
    });
  }
}
