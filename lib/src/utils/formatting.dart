part of 'package:companion_flutter/main.dart';

/// Shared with transcript separators; older messages always use a date.
String _formatTime(DateTime time) =>
    ChatTimestampPolicy.format(time, now: DateTime.now());

String _asMessage(Object error) {
  if (error is ApiException) return error.message;
  // 原文是英文且带完整 URL (曾显示成 "HttpConnection closed ... uri=...")。
  if (error is HttpException) return '网络连接中断，请稍后重试';
  if (error is Exception) {
    return error.toString().replaceFirst(RegExp(r'^\w*Exception: '), '');
  }
  return '操作失败';
}
