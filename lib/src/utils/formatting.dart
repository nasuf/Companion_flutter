part of 'package:companion_flutter/main.dart';

/// Shared with transcript separators; older messages always use a date.
String _formatTime(DateTime time) =>
    ChatTimestampPolicy.format(time, now: DateTime.now());

String _asMessage(Object error) {
  if (error is ApiException) return error.message;
  if (error is Exception) {
    return error.toString().replaceFirst('Exception: ', '');
  }
  return '操作失败';
}
