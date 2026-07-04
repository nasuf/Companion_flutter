part of 'package:companion_flutter/main.dart';

/// Message timestamp with date awareness (WeChat convention):
/// today -> HH:MM; yesterday -> 昨天 HH:MM; within a week -> 周X HH:MM;
/// same year -> M月D日 HH:MM; otherwise -> YYYY年M月D日 HH:MM.
String _formatTime(DateTime time) {
  final local = time.toLocal();
  final now = DateTime.now();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  final clock = '$hour:$minute';

  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diffDays = today.difference(day).inDays;

  if (diffDays <= 0) return clock;
  if (diffDays == 1) return '昨天 $clock';
  if (diffDays <= 6) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${weekdays[local.weekday - 1]} $clock';
  }
  if (local.year == now.year) return '${local.month}月${local.day}日 $clock';
  return '${local.year}年${local.month}月${local.day}日 $clock';
}

String _asMessage(Object error) {
  if (error is ApiException) return error.message;
  if (error is Exception) {
    return error.toString().replaceFirst('Exception: ', '');
  }
  return '操作失败';
}
