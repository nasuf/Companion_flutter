/// 连续使用时长提醒（《人工智能拟人化互动服务管理暂行办法》：连续使用每超过 2 小时
/// 提醒用户注意使用时长）。
///
/// 只累计 App 在前台的时间。退到后台不超过 [resetGap] 视为同一段连续使用；
/// 超过就从零重新计。纯计时逻辑，不依赖 Flutter，时间由调用方传入，便于测试。
class UsageReminderClock {
  UsageReminderClock({
    this.interval = const Duration(hours: 2),
    this.resetGap = const Duration(minutes: 10),
  });

  final Duration interval;
  final Duration resetGap;

  Duration _used = Duration.zero;
  DateTime? _foregroundSince;
  DateTime? _backgroundSince;
  int _remindersShown = 0;

  Duration usedAt(DateTime now) {
    final since = _foregroundSince;
    return since == null ? _used : _used + now.difference(since);
  }

  void resume(DateTime now) {
    if (_foregroundSince != null) return;
    final away = _backgroundSince;
    if (away != null && now.difference(away) > resetGap) {
      _used = Duration.zero;
      _remindersShown = 0;
    }
    _backgroundSince = null;
    _foregroundSince = now;
  }

  void pause(DateTime now) {
    final since = _foregroundSince;
    if (since == null) return;
    _used += now.difference(since);
    _foregroundSince = null;
    _backgroundSince = now;
  }

  /// 到了下一个 2 小时整点就返回 true（每满一次只提醒一次）。
  bool due(DateTime now) {
    final reached = usedAt(now).inMicroseconds ~/ interval.inMicroseconds;
    if (reached <= _remindersShown) return false;
    _remindersShown = reached;
    return true;
  }

  /// 距离下一次提醒还要多久（前台计时中才有意义）。
  Duration untilNext(DateTime now) {
    final next = interval * (_remindersShown + 1);
    final left = next - usedAt(now);
    return left.isNegative ? Duration.zero : left;
  }
}
