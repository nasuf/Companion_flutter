/// Display-only rules. Persisted message times and ordering stay unchanged.
class ChatTimestampPolicy {
  static const groupGap = Duration(minutes: 5);

  /// Compare adjacent messages, so a continuous conversation can last longer
  /// than five minutes without periodic timestamps interrupting it.
  static bool startsGroup(DateTime current, {DateTime? previous}) =>
      previous == null ||
      !sameLocalDay(current, previous) ||
      current.difference(previous) >= groupGap;

  static bool sameLocalDay(DateTime a, DateTime b) {
    final left = a.toLocal();
    final right = b.toLocal();
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  static String format(DateTime timestamp, {required DateTime now}) {
    final local = timestamp.toLocal();
    final today = now.toLocal();
    final clock =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    // Calendar ordinals avoid 23/25-hour days breaking "yesterday" at DST.
    final age = DateTime.utc(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime.utc(local.year, local.month, local.day)).inDays;
    if (age == 0) return clock;
    if (age == 1) return '昨天 $clock';
    final date = '${local.month}月${local.day}日';
    return local.year == today.year
        ? '$date $clock'
        : '${local.year}年$date $clock';
  }
}
