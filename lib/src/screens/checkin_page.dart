part of 'package:companion_flutter/main.dart';

class CheckinPage extends StatefulWidget {
  const CheckinPage({
    super.key,
    required this.api,
    required this.session,
    this.initialReminderId,
  });

  final CompanionApi api;
  final AuthSession session;
  final String? initialReminderId;

  @override
  State<CheckinPage> createState() => _CheckinPageState();
}

class _CheckinPageState extends State<CheckinPage> {
  late DateTime _selectedDate;
  DateTime? _calendarMonth;
  late Future<List<ReminderItem>> _future;
  final Set<String> _hiddenReminderIds = <String>{};
  final Set<String> _optimisticCompletedKeys = <String>{};
  final Map<String, bool> _optimisticPinnedOverrides = <String, bool>{};
  String? _openSwipeItemId;
  bool _calendarExpanded = false;
  bool _initialReminderOpened = false;
  double? _calendarExpansion;
  double _calendarDragStart = 0;
  bool _calendarDragging = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateOnlyTime(DateTime.now());
    _calendarMonth = _monthOnly(_selectedDate);
    _future = _load();
  }

  Future<List<ReminderItem>> _load() async {
    final response = await widget.api.listReminders(
      userId: widget.session.userId,
      agentId: widget.session.agentId,
      status: 'open',
    );
    await CheckinNotificationService.instance.syncReminders(response.items);
    return response.items;
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  double get _calendarProgress =>
      _calendarExpansion ?? (_calendarExpanded ? 1.0 : 0.0);

  void _beginCalendarDrag() {
    setState(() {
      _calendarDragStart = _calendarProgress;
      _calendarDragging = true;
    });
  }

  void _updateCalendarDrag(double dy) {
    final next = (_calendarDragStart + dy / 260).clamp(0.0, 1.0);
    if (next == _calendarExpansion) return;
    setState(() => _calendarExpansion = next);
  }

  void _endCalendarDrag(double velocity) {
    final progress = _calendarProgress;
    final expand = velocity > 260
        ? true
        : velocity < -260
        ? false
        : progress >= 0.45;
    setState(() {
      _calendarDragging = false;
      _calendarExpanded = expand;
      _calendarExpansion = expand ? 1.0 : 0.0;
    });
  }

  void _setCalendarExpanded(bool expanded) {
    setState(() {
      _calendarDragging = false;
      _calendarExpanded = expanded;
      _calendarExpansion = expanded ? 1.0 : 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: AppColors.page,
      floatingActionButton: FloatingActionButton(
        elevation: 18,
        backgroundColor: const Color(0xFF4F6DF5),
        shape: const CircleBorder(),
        onPressed: () => _openEditor(),
        child: const Icon(CupertinoIcons.add, color: Colors.white, size: 31),
      ),
      body: FutureBuilder<List<ReminderItem>>(
        future: _future,
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <ReminderItem>[];
          final activeItems = items
              .where((item) => !_hiddenReminderIds.contains(item.id))
              .toList();
          _openInitialReminderIfNeeded(activeItems);
          final visible = _tasksForDate(activeItems, _selectedDate);
          return Stack(
            children: [
              const Positioned.fill(child: _CheckinBackdrop()),
              SafeArea(
                bottom: false,
                child: ListView(
                  physics: _calendarDragging
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(18, 14, 18, 112 + safeBottom),
                  children: [
                    _topBar(activeItems),
                    const SizedBox(height: 26),
                    _hero(activeItems),
                    const SizedBox(height: 22),
                    _sectionHeader(visible.length),
                    const SizedBox(height: 12),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const _CheckinLoadingCard()
                    else if (visible.isEmpty)
                      _CheckinEmptyCard(onAdd: () => _openEditor())
                    else
                      _AnimatedTaskList(
                        items: visible,
                        isCompleted: _isCompleted,
                        isPinned: _isPinned,
                        openItemId: _openSwipeItemId,
                        onSwipeOpen: _setOpenSwipeItem,
                        onItemTap: _openTaskSheet,
                        onComplete: _complete,
                        onPin: _pin,
                        onReschedule: _reschedule,
                        onDelete: _delete,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _topBar(List<ReminderItem> items) {
    return Row(
      children: [
        _CircleAction(
          icon: CupertinoIcons.chevron_back,
          onTap: () => Navigator.of(context).pop(),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _hero(List<ReminderItem> items) {
    final taskDates = _datesWithTasks(items);
    final calendarMonth = _calendarMonth ?? _monthOnly(_selectedDate);
    final calendarProgress = _calendarProgress;
    final weekActive = calendarProgress < 0.35;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3CFF).withValues(alpha: 0.12),
            blurRadius: 36,
            offset: const Offset(0, 22),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            const Color(0xFFE9DDFF).withValues(alpha: 0.78),
            Colors.white.withValues(alpha: 0.90),
            const Color(0xFFFFF3D7).withValues(alpha: 0.62),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'HABIT RHYTHM',
            style: TextStyle(
              color: Color(0xFF6D45D9),
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            '提醒不是催促，是有人陪你把一天收住',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 31,
              height: 1.12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '${widget.session.agentName ?? '小芜'}会按你的状态选择语音、消息或轻提醒，不把打卡做成压力。',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 15,
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 22),
          _CalendarExpansionPanel(
            progress: calendarProgress,
            dragging: _calendarDragging,
            onDragStart: _beginCalendarDrag,
            onDragUpdate: _updateCalendarDrag,
            onDragEnd: _endCalendarDrag,
            week: _DateRail(
              active: weekActive,
              selectedDate: _selectedDate,
              visibleMonth: calendarMonth,
              datesWithTasks: taskDates,
              onVisibleMonthChanged: (month) =>
                  setState(() => _calendarMonth = _monthOnly(month)),
              onExpand: () => _setCalendarExpanded(true),
              onSelected: (date) => setState(() {
                _selectedDate = date;
                _calendarMonth = _monthOnly(date);
              }),
            ),
            month: _MonthCalendar(
              allowExternalSync: weekActive,
              selectedDate: _selectedDate,
              visibleMonth: calendarMonth,
              datesWithTasks: taskDates,
              onVisibleMonthChanged: (month) =>
                  setState(() => _calendarMonth = _monthOnly(month)),
              onCollapse: () => _setCalendarExpanded(false),
              onSelected: (date) => setState(() {
                _selectedDate = date;
                _calendarMonth = _monthOnly(date);
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(int count) {
    return Row(
      children: [
        Text(
          _isSameDate(_selectedDate, DateTime.now()) ? '今天的任务' : '当天任务',
          style: const TextStyle(
            color: Color(0xFF97A0A4),
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        Text(
          '$count 件',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Future<void> _openEditor() async {
    final created = await showModalBottomSheet<ReminderItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CheckinEditorSheet(
        api: widget.api,
        session: widget.session,
        initialDate: _selectedDate,
      ),
    );
    if (created == null || !mounted) return;
    await CheckinNotificationService.instance.scheduleReminder(created);
    setState(() {
      _selectedDate = _dateOnlyTime(created.triggerTime.toLocal());
      _future = _load();
    });
  }

  Future<void> _openTaskSheet(ReminderItem item) async {
    setState(() => _openSwipeItemId = null);
    final completed = _isCompleted(item);
    final result = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CheckinEditorSheet(
        api: widget.api,
        session: widget.session,
        initialDate: _selectedDate,
        item: item,
        readOnly: completed,
      ),
    );
    if (!mounted || result == null) return;
    if (result is CapsuleChatDraft) {
      Navigator.of(context).pop(result);
      return;
    }
    if (result is _CheckinDeletedResult) {
      await CheckinNotificationService.instance.cancelReminderItem(result.item);
      setState(() {
        _openSwipeItemId = null;
        _hiddenReminderIds.add(result.item.id);
      });
      return;
    }
    if (result is ReminderItem) {
      await CheckinNotificationService.instance.scheduleReminder(result);
      setState(() {
        _selectedDate = _dateOnlyTime(result.triggerTime.toLocal());
        _future = _load();
      });
    }
  }

  void _setOpenSwipeItem(String itemId) {
    if (_openSwipeItemId == itemId) return;
    setState(() => _openSwipeItemId = itemId);
  }

  Future<void> _complete(ReminderItem item) async {
    final key = _completionKey(item, _selectedDate);
    setState(() {
      _openSwipeItemId = null;
      _optimisticCompletedKeys.add(key);
    });
    try {
      final completed = await widget.api.completeReminder(
        item.id,
        conversationId: widget.session.conversationId,
        occurrenceDate: _selectedDate,
      );
      if (item.isHabit) {
        await CheckinNotificationService.instance.scheduleReminder(completed);
      } else {
        await CheckinNotificationService.instance.cancelReminderItem(completed);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _optimisticCompletedKeys.remove(key));
      }
      rethrow;
    }
  }

  String _completionKey(ReminderItem item, DateTime date) {
    return '${item.id}:${_dateKey(date)}';
  }

  bool _isCompleted(ReminderItem item) {
    return _isCompletedOnDate(item, _selectedDate);
  }

  bool _isCompletedOnDate(ReminderItem item, DateTime date) {
    return _optimisticCompletedKeys.contains(_completionKey(item, date)) ||
        _isCompletedForDate(item, date);
  }

  bool _isPinned(ReminderItem item) {
    return _optimisticPinnedOverrides[item.id] ?? item.pinned;
  }

  Future<void> _pin(ReminderItem item) async {
    final nextPinned = !_isPinned(item);
    final previousOverride = _optimisticPinnedOverrides[item.id];
    setState(() {
      _openSwipeItemId = null;
      _optimisticPinnedOverrides[item.id] = nextPinned;
    });
    try {
      await widget.api.updateReminder(
        item.id,
        pinned: nextPinned,
        conversationId: widget.session.conversationId,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          if (previousOverride == null) {
            _optimisticPinnedOverrides.remove(item.id);
          } else {
            _optimisticPinnedOverrides[item.id] = previousOverride;
          }
        });
      }
      rethrow;
    }
  }

  Future<void> _reschedule(ReminderItem item) async {
    if (item.isHabit) {
      await _openTaskSheet(item);
      return;
    }
    final picked = await _pickDateTime(
      initial: item.triggerTime.toLocal(),
      title: '修改日期',
    );
    if (picked == null) return;
    final updated = await widget.api.updateReminder(
      item.id,
      triggerTime: picked,
      conversationId: widget.session.conversationId,
    );
    await CheckinNotificationService.instance.scheduleReminder(updated);
    _reload();
  }

  Future<void> _delete(ReminderItem item) async {
    await widget.api.deleteReminder(
      item.id,
      conversationId: widget.session.conversationId,
    );
    if (!mounted) return;
    setState(() {
      _openSwipeItemId = null;
      _hiddenReminderIds.add(item.id);
    });
    await CheckinNotificationService.instance.cancelReminderItem(item);
  }

  void _openInitialReminderIfNeeded(List<ReminderItem> items) {
    final targetId = widget.initialReminderId;
    if (_initialReminderOpened || targetId == null || targetId.isEmpty) return;
    ReminderItem? target;
    for (final item in items) {
      if (item.id == targetId || item.memoryId == targetId) {
        target = item;
        break;
      }
    }
    if (target == null) return;
    final targetItem = target;
    _initialReminderOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final today = _dateOnlyTime(DateTime.now());
      final focusDate = targetItem.isHabit && _matchesDate(targetItem, today)
          ? today
          : _dateOnlyTime(targetItem.triggerTime.toLocal());
      setState(() {
        _selectedDate = focusDate;
        _calendarMonth = _monthOnly(_selectedDate);
      });
      unawaited(_openTaskSheet(targetItem));
    });
  }

  Future<DateTime?> _pickDateTime({
    required DateTime initial,
    required String title,
  }) async {
    final minimum = _minimumReminderDateTime();
    final initialValue = initial.isAfter(minimum)
        ? initial
        : _defaultReminderDateTime();
    var value = initialValue;
    return showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (context) => Localizations.override(
        context: context,
        locale: const Locale('zh', 'CN'),
        child: _PickerSheet(
          title: title,
          onCancel: () => Navigator.of(context).pop(),
          onSave: () {
            if (!_isFutureReminderTime(value)) {
              _showFutureTimeRequired(context);
              return;
            }
            Navigator.of(context).pop(value);
          },
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.dateAndTime,
            initialDateTime: initialValue,
            minimumDate: minimum,
            minuteInterval: 1,
            use24hFormat: true,
            onDateTimeChanged: (date) => value = date,
          ),
        ),
      ),
    );
  }

  List<ReminderItem> _tasksForDate(List<ReminderItem> items, DateTime date) {
    final result = items.where((item) => _matchesDate(item, date)).toList();
    result.sort((a, b) {
      final aPinned = _isPinned(a);
      final bPinned = _isPinned(b);
      if (aPinned != bPinned) return aPinned ? -1 : 1;
      final aCompleted = _isCompletedOnDate(a, date);
      final bCompleted = _isCompletedOnDate(b, date);
      if (aCompleted != bCompleted) return aCompleted ? 1 : -1;
      return a.triggerTime.toLocal().compareTo(b.triggerTime.toLocal());
    });
    return result;
  }

  Set<String> _datesWithTasks(List<ReminderItem> items) {
    final result = <String>{};
    final today = _dateOnlyTime(DateTime.now());
    final visibleMonth = _calendarMonth ?? _monthOnly(_selectedDate);
    final visibleGridStart = _monthOnly(
      visibleMonth,
    ).subtract(Duration(days: visibleMonth.weekday - 1));
    final visibleGridEnd = visibleGridStart.add(const Duration(days: 41));
    final rangeStart = _earliestDate([
      today,
      _selectedDate,
      visibleGridStart,
    ]).subtract(const Duration(days: 7));
    final rangeEnd = _latestDate([
      today,
      _selectedDate,
      visibleGridEnd,
    ]).add(const Duration(days: 7));
    for (
      var date = rangeStart;
      !date.isAfter(rangeEnd);
      date = date.add(const Duration(days: 1))
    ) {
      if (items.any((item) => _matchesDate(item, date))) {
        result.add(_dateKey(date));
      }
    }
    return result;
  }
}
