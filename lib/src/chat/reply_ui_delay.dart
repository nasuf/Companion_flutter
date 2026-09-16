import 'dart:async';

/// Schedules read + typing UI feedback to align with server-side reply delay.
class ReplyUiDelayController {
  ReplyUiDelayController({required this.onApply});

  final void Function({
    required String clientId,
    String? messageId,
  }) onApply;

  final Map<String, Timer> _timers = {};

  void schedule({
    required String clientId,
    String? messageId,
    required double delaySeconds,
  }) {
    cancel(clientId: clientId);
    if (delaySeconds <= 0) {
      onApply(clientId: clientId, messageId: messageId);
      return;
    }
    final delayMs = (delaySeconds * 1000).round();
    _timers[clientId] = Timer(Duration(milliseconds: delayMs), () {
      _timers.remove(clientId);
      onApply(clientId: clientId, messageId: messageId);
    });
  }

  void cancel({String? clientId}) {
    if (clientId != null) {
      _timers.remove(clientId)?.cancel();
      return;
    }
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }

  void dispose() => cancel();
}

double replyUiDelaySeconds(Object? raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '') ?? 0.0;
}

bool replyUiDefer(Object? raw) => raw == true;
