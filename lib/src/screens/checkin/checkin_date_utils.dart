part of 'package:companion_flutter/main.dart';

enum _CheckinEntryMode { once, habit }

DateTime _nextHabitTriggerTime(Set<int> weekdays, DateTime timeOfDay) {
  final now = DateTime.now();
  final selected = weekdays.isEmpty ? {now.weekday} : weekdays;
  for (var offset = 0; offset < 8; offset += 1) {
    final candidateDate = now.add(Duration(days: offset));
    if (!selected.contains(candidateDate.weekday)) continue;
    final candidate = DateTime(
      candidateDate.year,
      candidateDate.month,
      candidateDate.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );
    if (candidate.isAfter(now)) return candidate;
  }
  final fallback = now.add(const Duration(days: 1));
  return DateTime(
    fallback.year,
    fallback.month,
    fallback.day,
    timeOfDay.hour,
    timeOfDay.minute,
  );
}

bool _matchesDate(ReminderItem item, DateTime date) {
  final local = item.triggerTime.toLocal();
  if (item.recurrence == 'daily') {
    return !date.isBefore(_dateOnlyTime(local));
  }
  if (item.recurrence == 'weekly') {
    if (item.habitWeekdays.isNotEmpty) {
      final habitStart = _dateOnlyTime(item.createdAt.toLocal());
      return !date.isBefore(habitStart) &&
          item.habitWeekdays.contains(date.weekday);
    }
    return !date.isBefore(_dateOnlyTime(local)) &&
        date.weekday == local.weekday;
  }
  if (item.recurrence == 'monthly') {
    return !date.isBefore(_dateOnlyTime(local)) && date.day == local.day;
  }
  if (item.recurrence == 'yearly') {
    return !date.isBefore(_dateOnlyTime(local)) &&
        date.month == local.month &&
        date.day == local.day;
  }
  return _isSameDate(local, date);
}

bool _isCompletedForDate(ReminderItem item, DateTime date) {
  if (item.isHabit) {
    return item.completedDates.contains(_dateKey(date));
  }
  return item.completedAt != null && _matchesDate(item, date);
}

CapsuleChatDraft _draftForCheckinData({
  required String id,
  required String summary,
  required DateTime triggerTime,
  required String recurrence,
  required List<int> habitWeekdays,
}) {
  final isHabit = recurrence != 'once';
  final time = _fullDateTimeLabel(triggerTime.toLocal());
  final cardRecurrenceText = _chatCardRecurrenceLabel(
    recurrence,
    habitWeekdays,
  );
  final habitTimeText = _timeLabel(triggerTime);
  final habitSubtitle = '$cardRecurrenceText $habitTimeText';
  final type = isHabit ? 'checkin_habit' : 'checkin_reminder';
  final text = isHabit
      ? '我设置了习惯打卡：$summary，周期是$cardRecurrenceText，时间是$habitTimeText。'
      : '我设置了一次性提醒：$summary，提醒时间是$time。';
  final card = ChatComponentCard(
    type: type,
    title: isHabit ? '习惯打卡' : '打卡提醒',
    subtitle: isHabit ? habitSubtitle : time,
    body: summary,
    footer: isHabit ? '打卡 · 周期习惯' : '打卡 · 一次提醒',
    accent: isHabit ? '#22C66B' : '#4F6DF5',
    payload: {
      'trigger_id': id,
      'summary': summary,
      'trigger_time': triggerTime.toUtc().toIso8601String(),
      'recurrence': recurrence,
      'habit_weekdays': habitWeekdays,
      'sent_to_ai': true,
    },
  );
  return CapsuleChatDraft(agentText: text, card: card);
}

DateTime _dateOnlyTime(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _monthOnly(DateTime value) => DateTime(value.year, value.month);

DateTime _earliestDate(List<DateTime> dates) {
  return dates.reduce((a, b) => a.isBefore(b) ? a : b);
}

DateTime _latestDate(List<DateTime> dates) {
  return dates.reduce((a, b) => a.isAfter(b) ? a : b);
}

DateTime _defaultReminderDateTime() {
  final now = DateTime.now();
  return DateTime(
    now.year,
    now.month,
    now.day,
    now.hour,
    now.minute,
  ).add(const Duration(minutes: 5));
}

DateTime _minimumReminderDateTime() {
  return DateTime.now();
}

bool _isFutureReminderTime(DateTime value) {
  return value.isAfter(DateTime.now());
}

void _showFutureTimeRequired(BuildContext context) {
  showCupertinoDialog<void>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: const Text('请选择未来时间'),
      content: const Text('这个提醒时间已经过去了，请重新选择一个当前时间之后的时间。'),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}

DateTime _weekStart(DateTime value) {
  final date = _dateOnlyTime(value);
  return date.subtract(Duration(days: date.weekday - 1));
}

DateTime _weekForMonth(DateTime month, DateTime selectedDate) {
  final visibleMonth = _monthOnly(month);
  if (_isSameMonth(visibleMonth, selectedDate)) {
    return _weekStart(selectedDate);
  }
  return _weekStart(visibleMonth);
}

DateTime _monthForWeek(DateTime weekStart) =>
    _monthOnly(weekStart.add(const Duration(days: 3)));

bool _isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _isSameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

int _monthDifference(DateTime from, DateTime to) =>
    (to.year - from.year) * 12 + to.month - from.month;

String _dateKey(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _timeLabel(DateTime date) {
  final local = date.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _fullDateTimeLabel(DateTime date) {
  final local = date.toLocal();
  return '${local.year}年${local.month.toString().padLeft(2, '0')}月${local.day.toString().padLeft(2, '0')}日 ${_timeLabel(local)}';
}

String _recurrenceLabel(String recurrence) => switch (recurrence) {
  'daily' => '每天',
  'weekly' => '每周',
  'monthly' => '每月',
  'yearly' => '每年',
  _ => '一次提醒',
};

String _recurrenceDetailLabel(String recurrence, List<int> habitWeekdays) {
  if (recurrence == 'weekly' && habitWeekdays.isNotEmpty) {
    const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return (habitWeekdays.toList()..sort())
        .map((weekday) => labels[weekday - 1])
        .join('、');
  }
  return _recurrenceLabel(recurrence);
}

String _chatCardRecurrenceLabel(String recurrence, List<int> habitWeekdays) {
  final detail = _recurrenceDetailLabel(recurrence, habitWeekdays);
  if (recurrence == 'weekly' && habitWeekdays.isNotEmpty) {
    return '每$detail';
  }
  return detail;
}
