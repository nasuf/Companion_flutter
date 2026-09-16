import 'dart:async';

import 'package:companion_flutter/models.dart';

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

int? findReadReceiptMessageIndex(
  List<ChatMessage> messages, {
  required String clientId,
  String? messageId,
}) {
  for (var i = 0; i < messages.length; i += 1) {
    final message = messages[i];
    final matchesClient =
        message.id == clientId || message.clientId == clientId;
    final matchesMessageId =
        messageId != null &&
        messageId.isNotEmpty &&
        message.id == messageId;
    if (matchesClient || matchesMessageId) {
      return i;
    }
  }
  return null;
}

/// When one user message becomes read, every earlier user message in the
/// same uninterrupted streak should also show read (later timers can fire
/// first when each message carries its own delay budget).
List<ChatMessage> applyReadReceiptCascade(
  List<ChatMessage> messages, {
  required String clientId,
  String? messageId,
}) {
  final matchedIndex = findReadReceiptMessageIndex(
    messages,
    clientId: clientId,
    messageId: messageId,
  );
  if (matchedIndex == null) {
    return messages;
  }

  final updated = List<ChatMessage>.from(messages);
  for (var i = matchedIndex; i >= 0; i -= 1) {
    final message = updated[i];
    if (!message.isMine) {
      break;
    }
    if (!message.read || message.pending) {
      updated[i] = message.copyWith(read: true, pending: false);
    }
  }
  return updated;
}
