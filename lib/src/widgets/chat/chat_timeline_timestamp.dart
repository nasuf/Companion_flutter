import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../utils/chat_timestamp_policy.dart';

/// One clock per transcript. Only date labels listen to it, so midnight never
/// rebuilds message bodies, restarts their animations or moves a reading anchor.
class ChatCalendarClock extends ValueNotifier<DateTime>
    with WidgetsBindingObserver {
  ChatCalendarClock({DateTime Function()? now})
    : _readNow = now ?? DateTime.now,
      super((now ?? DateTime.now)().toLocal()) {
    _dateKey = _localDateKey(value);
    _zoneOffset = value.timeZoneOffset;
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  final DateTime Function() _readNow;
  Timer? _timer;
  bool _active = true;
  bool _disposed = false;
  late int _dateKey;
  late Duration _zoneOffset;

  static int _localDateKey(DateTime time) =>
      time.year * 10000 + time.month * 100 + time.day;

  void _refresh() {
    final current = _readNow().toLocal();
    final dateKey = _localDateKey(current);
    // Preserve scalar observations: asking an old local DateTime for its zone
    // again after an OS change may already return the new zone.
    if (dateKey != _dateKey || current.timeZoneOffset != _zoneOffset) {
      _dateKey = dateKey;
      _zoneOffset = current.timeZoneOffset;
      value = current;
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (!_active || _disposed) return;
    final now = _readNow().toLocal();
    final untilMidnight = DateTime(
      now.year,
      now.month,
      now.day + 1,
    ).difference(now);
    // Refresh exactly at midnight; a bounded clock check also catches an OS
    // date/time-zone change while the app remains open.
    final delay = untilMidnight < const Duration(minutes: 1)
        ? untilMidnight
        : const Duration(minutes: 1);
    _timer = Timer(delay, () {
      _refresh();
      _schedule();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    if (state == AppLifecycleState.resumed) {
      _active = true;
      _refresh();
      _schedule();
    } else if (state != AppLifecycleState.inactive) {
      _active = false;
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _active = false;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class ChatTimelineTimestamp extends StatelessWidget {
  const ChatTimelineTimestamp({
    super.key,
    required this.timestamp,
    required this.clock,
    required this.style,
  });

  final DateTime timestamp;
  final ValueListenable<DateTime> clock;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 14, 0, 10),
    child: Center(
      child: ValueListenableBuilder<DateTime>(
        valueListenable: clock,
        builder: (context, now, _) => Text(
          ChatTimestampPolicy.format(timestamp, now: now),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    ),
  );
}
