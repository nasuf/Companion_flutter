import 'dart:async';
import 'dart:math';

/// Composer activity only. Draft content never leaves this controller.
class LocalChatTyping {
  LocalChatTyping({required this.onSend})
    : sessionId =
          '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${Random.secure().nextInt(1 << 32).toRadixString(36)}';

  final void Function(bool active, int revision, String sessionId) onSend;
  final String sessionId;
  Timer? _idle;
  Timer? _heartbeat;
  bool _visible = true;
  bool _textActive = false;
  bool _voiceActive = false;
  bool _active = false;
  int _revision = 0;

  void textChanged(String text) {
    _idle?.cancel();
    _textActive = _visible && text.trim().isNotEmpty;
    if (_textActive) {
      _idle = Timer(const Duration(seconds: 4), () {
        _textActive = false;
        _sync();
      });
    }
    _sync();
  }

  void voiceChanged(bool active) {
    _voiceActive = _visible && active;
    _sync();
  }

  void setVisible(bool visible) {
    _visible = visible;
    if (!visible) stop();
  }

  void _sync() {
    final next = _visible && (_textActive || _voiceActive);
    if (next == _active) return;
    _active = next;
    onSend(next, ++_revision, sessionId);
    _heartbeat?.cancel();
    if (next) {
      _heartbeat = Timer.periodic(const Duration(seconds: 2), (_) {
        if (_active) onSend(true, ++_revision, sessionId);
      });
    }
  }

  void stop() {
    _idle?.cancel();
    _heartbeat?.cancel();
    _textActive = false;
    _voiceActive = false;
    _sync();
  }

  void dispose() => stop();
}

/// Ordered transient presence. A lost stop event cannot leave a stuck indicator.
class RemoteChatTyping {
  RemoteChatTyping({required this.onChanged});
  final void Function(bool active) onChanged;
  Timer? _expiry;
  int _revision = -1;
  bool _active = false;

  void apply(Map<String, dynamic> payload) {
    final revision = payload['revision'];
    final active = payload['active'];
    if (revision is! int || active is! bool || revision <= _revision) return;
    _revision = revision;
    _expiry?.cancel();
    _set(active);
    _expiry = Timer(const Duration(seconds: 8), () {
      _revision = -1;
      _set(false);
    });
  }

  void _set(bool active) {
    if (_active == active) return;
    _active = active;
    onChanged(active);
  }

  void clear({bool resetRevision = false}) {
    if (resetRevision) {
      _expiry?.cancel();
      _revision = -1;
    }
    _set(false);
  }

  void dispose() => _expiry?.cancel();
}
