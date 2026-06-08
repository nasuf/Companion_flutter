part of 'package:companion_flutter/main.dart';

String _formatTime(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _asMessage(Object error) {
  if (error is ApiException) return error.message;
  if (error is Exception) {
    return error.toString().replaceFirst('Exception: ', '');
  }
  return '操作失败';
}
