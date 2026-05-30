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

class _CalendarExpansionPanel extends StatefulWidget {
  const _CalendarExpansionPanel({
    required this.progress,
    required this.dragging,
    required this.week,
    required this.month,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  static const double collapsedHeight = 84;
  static const double expandedHeight = 398;

  final double progress;
  final bool dragging;
  final Widget week;
  final Widget month;
  final VoidCallback onDragStart;
  final ValueChanged<double> onDragUpdate;
  final ValueChanged<double> onDragEnd;

  @override
  State<_CalendarExpansionPanel> createState() =>
      _CalendarExpansionPanelState();
}

class _CalendarExpansionPanelState extends State<_CalendarExpansionPanel> {
  double _dragDy = 0;
  double _dragDx = 0;
  int? _dragPointer;
  bool _verticalDragActive = false;
  bool _horizontalDragIgnored = false;
  VelocityTracker? _velocityTracker;

  double get _height {
    final eased = Curves.easeOutCubic.transform(widget.progress);
    return _CalendarExpansionPanel.collapsedHeight +
        (_CalendarExpansionPanel.expandedHeight -
                _CalendarExpansionPanel.collapsedHeight) *
            eased;
  }

  @override
  Widget build(BuildContext context) {
    final weekOpacity = (1 - widget.progress * 1.35).clamp(0.0, 1.0);
    final monthOpacity = ((widget.progress - 0.10) / 0.90).clamp(0.0, 1.0);
    final duration = widget.dragging
        ? Duration.zero
        : const Duration(milliseconds: 240);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutCubic,
        height: _height,
        child: ClipRect(
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: _CalendarExpansionPanel.collapsedHeight,
                child: IgnorePointer(
                  ignoring: widget.progress > 0.35,
                  child: AnimatedOpacity(
                    duration: duration,
                    opacity: weekOpacity.toDouble(),
                    child: widget.week,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: _CalendarExpansionPanel.expandedHeight,
                child: IgnorePointer(
                  ignoring: widget.progress < 0.45,
                  child: AnimatedOpacity(
                    duration: duration,
                    opacity: monthOpacity.toDouble(),
                    child: widget.month,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_dragPointer != null) return;
    _dragPointer = event.pointer;
    _dragDx = 0;
    _dragDy = 0;
    _verticalDragActive = false;
    _horizontalDragIgnored = false;
    _velocityTracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_dragPointer != event.pointer || _horizontalDragIgnored) return;
    _velocityTracker?.addPosition(event.timeStamp, event.position);
    _dragDx += event.delta.dx;
    _dragDy += event.delta.dy;
    final absDx = _dragDx.abs();
    final absDy = _dragDy.abs();

    if (!_verticalDragActive) {
      if (absDx < 7 && absDy < 7) return;
      if (absDx > absDy * 1.12) {
        _horizontalDragIgnored = true;
        return;
      }
      if (absDy > absDx * 1.24) {
        _verticalDragActive = true;
        widget.onDragStart();
      } else {
        return;
      }
    }

    widget.onDragUpdate(_dragDy);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_dragPointer != event.pointer) return;
    if (_verticalDragActive) {
      final velocity =
          _velocityTracker?.getVelocity().pixelsPerSecond.dy ?? 0.0;
      widget.onDragEnd(velocity);
    }
    _resetPointerDrag();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_dragPointer != event.pointer) return;
    if (_verticalDragActive) {
      widget.onDragEnd(0);
    }
    _resetPointerDrag();
  }

  void _resetPointerDrag() {
    _dragPointer = null;
    _dragDx = 0;
    _dragDy = 0;
    _verticalDragActive = false;
    _horizontalDragIgnored = false;
    _velocityTracker = null;
  }
}

class _DateRail extends StatefulWidget {
  const _DateRail({
    required this.active,
    required this.selectedDate,
    required this.visibleMonth,
    required this.datesWithTasks,
    required this.onSelected,
    required this.onVisibleMonthChanged,
    required this.onExpand,
  });

  final bool active;
  final DateTime selectedDate;
  final DateTime visibleMonth;
  final Set<String> datesWithTasks;
  final ValueChanged<DateTime> onSelected;
  final ValueChanged<DateTime> onVisibleMonthChanged;
  final VoidCallback onExpand;

  @override
  State<_DateRail> createState() => _DateRailState();
}

class _DateRailState extends State<_DateRail> {
  static const int _initialPage = 520;

  late final PageController _pageController;
  late DateTime _baseWeek;
  late DateTime _visibleWeek;

  @override
  void initState() {
    super.initState();
    _baseWeek = _weekForMonth(widget.visibleMonth, widget.selectedDate);
    _visibleWeek = _baseWeek;
    _pageController = PageController(initialPage: _initialPage);
  }

  @override
  void didUpdateWidget(covariant _DateRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active) return;
    final targetWeek = _weekForMonth(widget.visibleMonth, widget.selectedDate);
    final becameActive = !oldWidget.active && widget.active;
    final monthChanged = !_isSameMonth(
      oldWidget.visibleMonth,
      widget.visibleMonth,
    );
    final selectedWeekChanged = !_isSameDate(
      _weekStart(oldWidget.selectedDate),
      _weekStart(widget.selectedDate),
    );
    if (!_isSameDate(targetWeek, _visibleWeek) &&
        (becameActive || monthChanged || selectedWeekChanged)) {
      final weekDelta = targetWeek.difference(_baseWeek).inDays ~/ 7;
      _visibleWeek = targetWeek;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        _pageController.animateToPage(
          _initialPage + weekDelta,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: _weekdayShortLabels
              .map(
                (label) => Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 11,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 55,
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (page) {
              final week = _baseWeek.add(
                Duration(days: (page - _initialPage) * 7),
              );
              setState(() => _visibleWeek = week);
              if (widget.active) {
                widget.onVisibleMonthChanged(_monthForWeek(week));
              }
            },
            itemBuilder: (context, page) {
              final week = _baseWeek.add(
                Duration(days: (page - _initialPage) * 7),
              );
              return Row(
                children: List.generate(7, (index) {
                  final date = week.add(Duration(days: index));
                  return Expanded(
                    child: _WeekDayCell(
                      date: date,
                      selected: _isSameDate(date, widget.selectedDate),
                      today: _isSameDate(date, DateTime.now()),
                      hasTask: widget.datesWithTasks.contains(_dateKey(date)),
                      onTap: () => widget.onSelected(date),
                    ),
                  );
                }),
              );
            },
          ),
        ),
        const SizedBox(height: 2),
        _WeekDragHandle(onExpand: widget.onExpand),
      ],
    );
  }
}

class _WeekDayCell extends StatelessWidget {
  const _WeekDayCell({
    required this.date,
    required this.selected,
    required this.today,
    required this.hasTask,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool today;
  final bool hasTask;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lunar = _SolarLunar.label(date);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: SizedBox(
        height: 55,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 31,
                  height: 31,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: today ? const Color(0xFFFFC23A) : Colors.transparent,
                    border: Border.all(
                      color: selected && !today
                          ? const Color(0xFFFFC23A).withValues(alpha: 0.60)
                          : Colors.transparent,
                      width: selected && !today ? 1.2 : 0,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: today || selected ? 18 : 17,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                if (hasTask)
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF6D45D9),
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  Text(
                    lunar,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: today || selected
                          ? AppColors.text
                          : AppColors.muted,
                      fontSize: 8,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekDragHandle extends StatelessWidget {
  const _WeekDragHandle({required this.onExpand});

  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onExpand,
      child: SizedBox(
        height: 8,
        width: double.infinity,
        child: Center(
          child: Container(
            width: 30,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFFFFC8BE),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}

const _weekdayShortLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

class _MonthCalendar extends StatefulWidget {
  const _MonthCalendar({
    required this.allowExternalSync,
    required this.selectedDate,
    required this.visibleMonth,
    required this.datesWithTasks,
    required this.onSelected,
    required this.onVisibleMonthChanged,
    required this.onCollapse,
  });

  final bool allowExternalSync;
  final DateTime selectedDate;
  final DateTime visibleMonth;
  final Set<String> datesWithTasks;
  final ValueChanged<DateTime> onSelected;
  final ValueChanged<DateTime> onVisibleMonthChanged;
  final VoidCallback onCollapse;

  @override
  State<_MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<_MonthCalendar> {
  static const int _initialPage = 1200;

  late final PageController _pageController;
  late DateTime _baseMonth;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _baseMonth = _monthOnly(widget.visibleMonth);
    _visibleMonth = _baseMonth;
    _pageController = PageController(initialPage: _initialPage);
  }

  @override
  void didUpdateWidget(covariant _MonthCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.allowExternalSync) return;
    final nextMonth = _monthOnly(widget.visibleMonth);
    if (!_isSameMonth(nextMonth, _visibleMonth) &&
        !_isSameMonth(oldWidget.visibleMonth, widget.visibleMonth)) {
      final monthDelta = _monthDifference(_baseMonth, nextMonth);
      final targetPage = _initialPage + monthDelta;
      _visibleMonth = nextMonth;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        _pageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.10),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Text(
                '${_visibleMonth.year}年${_visibleMonth.month}月',
                key: ValueKey(_dateKey(_visibleMonth)),
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Spacer(),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: widget.onCollapse,
              child: const Icon(
                CupertinoIcons.chevron_up,
                size: 18,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: ['一', '二', '三', '四', '五', '六', '日']
              .map(
                (day) => Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 318,
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (page) {
              setState(() {
                _visibleMonth = DateTime(
                  _baseMonth.year,
                  _baseMonth.month + (page - _initialPage),
                );
              });
              widget.onVisibleMonthChanged(_visibleMonth);
            },
            itemBuilder: (context, page) {
              final month = DateTime(
                _baseMonth.year,
                _baseMonth.month + (page - _initialPage),
              );
              return _MonthGrid(
                month: month,
                selectedDate: widget.selectedDate,
                datesWithTasks: widget.datesWithTasks,
                onSelected: widget.onSelected,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selectedDate,
    required this.datesWithTasks,
    required this.onSelected,
  });

  final DateTime month;
  final DateTime selectedDate;
  final Set<String> datesWithTasks;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final start = first.subtract(Duration(days: first.weekday - 1));
    final days = List.generate(42, (index) => start.add(Duration(days: index)));
    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: days.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisExtent: 52,
      ),
      itemBuilder: (context, index) {
        final date = days[index];
        final selected = _isSameDate(date, selectedDate);
        final today = _isSameDate(date, DateTime.now());
        final muted = date.month != month.month;
        final hasTask = datesWithTasks.contains(_dateKey(date));
        final label = _SolarLunar.label(date);
        return _MonthDayCell(
          date: date,
          label: label,
          selected: selected,
          today: today,
          muted: muted,
          hasTask: hasTask,
          onTap: () => onSelected(date),
        );
      },
    );
  }
}

class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({
    required this.date,
    required this.label,
    required this.selected,
    required this.today,
    required this.muted,
    required this.hasTask,
    required this.onTap,
  });

  final DateTime date;
  final String label;
  final bool selected;
  final bool today;
  final bool muted;
  final bool hasTask;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
        padding: const EdgeInsets.symmetric(vertical: 3),
        decoration: const BoxDecoration(color: Colors.transparent),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: 2,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: today ? const Color(0xFFFFC23A) : Colors.transparent,
                  border: Border.all(
                    color: selected && !today
                        ? const Color(0xFFFFC23A).withValues(alpha: 0.76)
                        : Colors.transparent,
                    width: selected && !today ? 1.4 : 0,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    color: muted && !today && !selected
                        ? AppColors.muted.withValues(alpha: 0.54)
                        : AppColors.text,
                    fontSize: 15,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            if (hasTask)
              Positioned(
                top: 35,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: today
                        ? const Color(0xFF6D45D9)
                        : const Color(0xFF6374F6),
                    shape: BoxShape.circle,
                  ),
                ),
              )
            else
              Positioned(
                top: 33,
                left: 2,
                right: 2,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: muted && !selected
                        ? const Color(0xFF4FBF9F).withValues(alpha: 0.58)
                        : const Color(0xFF4FBF9F),
                    fontSize: 8,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SwipeTaskRow extends StatefulWidget {
  const _SwipeTaskRow({
    required this.item,
    required this.completed,
    required this.pinned,
    required this.openItemId,
    required this.onSwipeOpen,
    required this.onTap,
    required this.onComplete,
    required this.onPin,
    required this.onReschedule,
    required this.onDelete,
  });

  final ReminderItem item;
  final bool completed;
  final bool pinned;
  final String? openItemId;
  final ValueChanged<String> onSwipeOpen;
  final VoidCallback onTap;
  final Future<void> Function() onComplete;
  final Future<void> Function() onPin;
  final Future<void> Function() onReschedule;
  final Future<void> Function() onDelete;

  @override
  State<_SwipeTaskRow> createState() => _SwipeTaskRowState();
}

class _AnimatedTaskList extends StatelessWidget {
  const _AnimatedTaskList({
    required this.items,
    required this.isCompleted,
    required this.isPinned,
    required this.openItemId,
    required this.onSwipeOpen,
    required this.onItemTap,
    required this.onComplete,
    required this.onPin,
    required this.onReschedule,
    required this.onDelete,
  });

  static const double _rowExtent = 84;
  static const double _rowGap = 10;

  final List<ReminderItem> items;
  final bool Function(ReminderItem item) isCompleted;
  final bool Function(ReminderItem item) isPinned;
  final String? openItemId;
  final ValueChanged<String> onSwipeOpen;
  final ValueChanged<ReminderItem> onItemTap;
  final Future<void> Function(ReminderItem item) onComplete;
  final Future<void> Function(ReminderItem item) onPin;
  final Future<void> Function(ReminderItem item) onReschedule;
  final Future<void> Function(ReminderItem item) onDelete;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: SizedBox(
        height: items.length * _rowExtent,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var index = 0; index < items.length; index += 1)
              AnimatedPositioned(
                key: ValueKey(items[index].id),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                left: 0,
                right: 0,
                top: index * _rowExtent,
                height: _rowExtent - _rowGap,
                child: _SwipeTaskRow(
                  item: items[index],
                  completed: isCompleted(items[index]),
                  pinned: isPinned(items[index]),
                  openItemId: openItemId,
                  onSwipeOpen: onSwipeOpen,
                  onTap: () => onItemTap(items[index]),
                  onComplete: () => onComplete(items[index]),
                  onPin: () => onPin(items[index]),
                  onReschedule: () => onReschedule(items[index]),
                  onDelete: () => onDelete(items[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SwipeTaskRowState extends State<_SwipeTaskRow>
    with SingleTickerProviderStateMixin {
  static const double _leadingReveal = 112;
  static const double _trailingReveal = 112;

  double _offset = 0;
  bool _flashFromRight = false;
  bool _collapsing = false;
  bool _sweeping = false;
  bool _optimisticCompleted = false;
  Color _flashColor = const Color(0xFF5DCFA8);
  AnimationController? _sweepControllerInstance;

  AnimationController get _sweepController {
    return _sweepControllerInstance ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void initState() {
    super.initState();
    _sweepController;
  }

  @override
  void didUpdateWidget(covariant _SwipeTaskRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id || widget.completed) {
      _optimisticCompleted = false;
    }
    if (widget.openItemId != widget.item.id &&
        _offset != 0 &&
        !_sweeping &&
        !_collapsing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.openItemId != widget.item.id && _offset != 0) {
          setState(() => _offset = 0);
        }
      });
    }
  }

  @override
  void dispose() {
    _sweepControllerInstance?.dispose();
    super.dispose();
  }

  Future<void> _closeActions() async {
    if (_offset == 0) return;
    setState(() => _offset = 0);
    await Future<void>.delayed(const Duration(milliseconds: 130));
  }

  Future<void> _flash(Color color, {bool fromRight = false}) async {
    setState(() {
      _flashColor = color;
      _flashFromRight = fromRight;
      _offset = 0;
      _sweeping = true;
    });
    await _sweepController.forward(from: 0);
    if (!mounted) return;
    _sweepController.value = 0;
    setState(() => _sweeping = false);
  }

  Future<void> _handleComplete() async {
    if (widget.completed || _optimisticCompleted) return;
    setState(() => _optimisticCompleted = true);
    try {
      await _flash(const Color(0xFF5DCFA8));
      await widget.onComplete();
      if (mounted) setState(() => _offset = 0);
    } catch (_) {
      if (mounted) {
        setState(() {
          _optimisticCompleted = false;
          _offset = 0;
        });
      }
      rethrow;
    }
  }

  Future<void> _handlePin() async {
    await _closeActions();
    await widget.onPin();
  }

  Future<void> _handleReschedule() async {
    if (widget.completed || _optimisticCompleted) return;
    await _closeActions();
    await widget.onReschedule();
  }

  Future<void> _handleDelete() async {
    await _flash(const Color(0xFFFF4C4C), fromRight: true);
    if (mounted) setState(() => _collapsing = true);
    await Future<void>.delayed(const Duration(milliseconds: 170));
    await widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final completed = widget.completed || _optimisticCompleted;
    final leadingLimit = completed ? _leadingReveal / 2 : _leadingReveal;
    final trailingLimit = completed ? _trailingReveal / 2 : _trailingReveal;
    final leadingWidth = _offset > 0 ? _offset : 0.0;
    final trailingWidth = _offset < 0 ? -_offset : 0.0;
    final leadingProgress = (leadingWidth / _leadingReveal).clamp(0.0, 1.0);
    final foregroundRadius = BorderRadius.horizontal(
      left: Radius.circular(_offset > 0 ? 0 : 22),
      right: Radius.circular(_offset < 0 ? 0 : 22),
    );
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (_sweeping || _collapsing) return;
        final next = (_offset + details.delta.dx).clamp(
          -trailingLimit,
          leadingLimit,
        );
        if (next.abs() > 2) widget.onSwipeOpen(widget.item.id);
        setState(() => _offset = next);
      },
      onHorizontalDragEnd: (_) {
        if (_sweeping || _collapsing) return;
        setState(() {
          if (_offset > 44) {
            _offset = leadingLimit;
          } else if (_offset < -44) {
            _offset = -trailingLimit;
          } else {
            _offset = 0;
          }
        });
      },
      onTap: () {
        if (_sweeping || _collapsing) return;
        if (_offset != 0) {
          unawaited(_closeActions());
          return;
        }
        widget.onTap();
      },
      child: AnimatedSize(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 140),
          opacity: _collapsing ? 0 : 1,
          child: _collapsing
              ? const SizedBox(width: double.infinity)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    children: [
                      if (!_sweeping) ...[
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: leadingWidth,
                          child: Row(
                            children: [
                              if (!completed)
                                Expanded(
                                  child: _TaskActionButton(
                                    color: const Color(0xFF5DCFA8),
                                    icon: CupertinoIcons.check_mark,
                                    borderRadius: const BorderRadius.horizontal(
                                      left: Radius.circular(22),
                                    ),
                                    onTap: _handleComplete,
                                    reveal: leadingWidth / leadingLimit,
                                  ),
                                ),
                              Expanded(
                                child: _TaskActionButton(
                                  color: const Color(0xFFFFB83F),
                                  icon: widget.pinned
                                      ? CupertinoIcons.pin_slash
                                      : CupertinoIcons.pin,
                                  borderRadius: completed
                                      ? const BorderRadius.horizontal(
                                          left: Radius.circular(22),
                                        )
                                      : BorderRadius.zero,
                                  onTap: _handlePin,
                                  reveal: leadingWidth / leadingLimit,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          width: trailingWidth,
                          child: Row(
                            children: [
                              if (!completed)
                                Expanded(
                                  child: _TaskActionButton(
                                    color: const Color(0xFF4F6DF5),
                                    icon: CupertinoIcons.calendar,
                                    borderRadius: BorderRadius.zero,
                                    onTap: _handleReschedule,
                                    reveal: trailingWidth / trailingLimit,
                                  ),
                                ),
                              Expanded(
                                child: _TaskActionButton(
                                  color: const Color(0xFFFF4C4C),
                                  icon: CupertinoIcons.delete,
                                  borderRadius: const BorderRadius.horizontal(
                                    right: Radius.circular(22),
                                  ),
                                  onTap: _handleDelete,
                                  reveal: trailingWidth / trailingLimit,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Transform.translate(
                        offset: Offset(_offset, 0),
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.fromLTRB(
                                13,
                                11,
                                14,
                                11,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: foregroundRadius,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF24344A,
                                    ).withValues(alpha: 0.06),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  if (completed)
                                    Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF5DCFA8),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.check_mark,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    )
                                  else
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 120,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      width: 26 * (1 - leadingProgress),
                                      child: IgnorePointer(
                                        ignoring: leadingProgress > 0.12,
                                        child: AnimatedOpacity(
                                          duration: const Duration(
                                            milliseconds: 100,
                                          ),
                                          opacity: 1 - leadingProgress,
                                          child: CupertinoButton(
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size.zero,
                                            onPressed: _handleComplete,
                                            child: Container(
                                              width: 26,
                                              height: 26,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFF9EA4AA,
                                                  ),
                                                  width: 2,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  SizedBox(
                                    width: completed
                                        ? 11
                                        : 11 * (1 - leadingProgress),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.summary,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: completed
                                                ? AppColors.text.withValues(
                                                    alpha: 0.55,
                                                  )
                                                : AppColors.text,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            decoration: completed
                                                ? TextDecoration.lineThrough
                                                : TextDecoration.none,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          completed
                                              ? '已完成'
                                              : item.isHabit
                                              ? '${_chatCardRecurrenceLabel(item.recurrence, item.habitWeekdays)} · ${_timeLabel(item.triggerTime)}'
                                              : '${_timeLabel(item.triggerTime)} · ${_recurrenceLabel(item.recurrence)}',
                                          style: const TextStyle(
                                            color: AppColors.muted,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (widget.pinned)
                                    const Icon(
                                      CupertinoIcons.pin_fill,
                                      color: Color(0xFFFFB83F),
                                      size: 16,
                                    ),
                                ],
                              ),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    return AnimatedBuilder(
                                      animation: _sweepController,
                                      builder: (context, _) {
                                        final progress = Curves.easeOutCubic
                                            .transform(_sweepController.value);
                                        final width =
                                            constraints.maxWidth * progress;
                                        final opacity =
                                            (1 - _sweepController.value * 0.25)
                                                .clamp(0.0, 1.0);
                                        return Stack(
                                          children: [
                                            Positioned(
                                              top: 0,
                                              bottom: 0,
                                              left: _flashFromRight ? null : 0,
                                              right: _flashFromRight ? 0 : null,
                                              width: width,
                                              child: Opacity(
                                                opacity: opacity,
                                                child: DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        foregroundRadius,
                                                    gradient: LinearGradient(
                                                      begin: _flashFromRight
                                                          ? Alignment
                                                                .centerRight
                                                          : Alignment
                                                                .centerLeft,
                                                      end: _flashFromRight
                                                          ? Alignment.centerLeft
                                                          : Alignment
                                                                .centerRight,
                                                      colors: [
                                                        _flashColor.withValues(
                                                          alpha: 0.42,
                                                        ),
                                                        _flashColor.withValues(
                                                          alpha: 0.24,
                                                        ),
                                                        _flashColor.withValues(
                                                          alpha: 0.06,
                                                        ),
                                                      ],
                                                      stops: const [0, 0.72, 1],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _TaskActionButton extends StatelessWidget {
  const _TaskActionButton({
    required this.color,
    required this.icon,
    required this.borderRadius,
    required this.onTap,
    required this.reveal,
  });

  final Color color;
  final IconData icon;
  final BorderRadius borderRadius;
  final VoidCallback onTap;
  final double reveal;

  @override
  Widget build(BuildContext context) {
    final progress = Curves.easeOutCubic.transform(reveal.clamp(0.0, 1.0));
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: AnimatedContainer(
        duration: Duration.zero,
        height: double.infinity,
        decoration: BoxDecoration(color: color, borderRadius: borderRadius),
        alignment: Alignment.center,
        child: Transform.scale(
          scale: 0.76 + progress * 0.24,
          child: Opacity(
            opacity: progress,
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}

class _CheckinEditorSheet extends StatefulWidget {
  const _CheckinEditorSheet({
    required this.api,
    required this.session,
    required this.initialDate,
    this.item,
    this.readOnly = false,
  });

  final CompanionApi api;
  final AuthSession session;
  final DateTime initialDate;
  final ReminderItem? item;
  final bool readOnly;

  @override
  State<_CheckinEditorSheet> createState() => _CheckinEditorSheetState();
}

class _CheckinDeletedResult {
  const _CheckinDeletedResult(this.item);

  final ReminderItem item;
}

class _CheckinEditorSheetState extends State<_CheckinEditorSheet> {
  static const double _settingHeight = 112;
  static const double _editableContentHeight = 444;
  static const double _readOnlyContentHeight = 370;
  static const double _timePickerContentHeight = 444;

  final _controller = TextEditingController();
  late DateTime _dateTime;
  late DateTime _draftDateTime;
  _CheckinEntryMode _mode = _CheckinEntryMode.once;
  final Set<int> _habitWeekdays = {DateTime.now().weekday};
  bool _editingTime = false;
  bool _saving = false;
  bool _completing = false;
  bool _deleting = false;
  bool _sentToAi = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _mode = item != null && item.isHabit
        ? _CheckinEntryMode.habit
        : _CheckinEntryMode.once;
    if (item != null) {
      _controller.text = item.summary;
    }
    _sentToAi = item?.sentToAi ?? false;
    _dateTime = item?.triggerTime.toLocal() ?? _defaultReminderDateTime();
    _draftDateTime = _dateTime;
    _habitWeekdays
      ..clear()
      ..addAll(
        item != null && item.habitWeekdays.isNotEmpty
            ? item.habitWeekdays
            : <int>{DateTime.now().weekday},
      );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardHeight = media.viewInsets.bottom;
    final keyboardExpansion = _editingTime
        ? 0.0
        : math.min(keyboardHeight * 0.62, 220.0);
    final maxContentHeight = media.size.height - media.padding.top - 78;
    final baseContentHeight = _editingTime
        ? _timePickerContentHeight
        : widget.readOnly
        ? _readOnlyContentHeight
        : _editableContentHeight;
    final contentHeight = math.min(
      baseContentHeight + keyboardExpansion,
      maxContentHeight,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: contentHeight,
          constraints: BoxConstraints(maxHeight: maxContentHeight),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (currentChild, previousChildren) {
              return Stack(
                alignment: Alignment.topCenter,
                children: [
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              );
            },
            transitionBuilder: (child, animation) {
              final slide = Tween<Offset>(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: _editingTime
                ? _EditorTimePickerView(
                    key: const ValueKey('time-picker'),
                    dateTime: _draftDateTime,
                    title: _mode == _CheckinEntryMode.habit ? '打卡时间' : '提醒时间',
                    timeOnly: _mode == _CheckinEntryMode.habit,
                    minimumDate: _minimumReminderDateTime(),
                    onChanged: (value) => _draftDateTime = value,
                    onCancel: () => setState(() => _editingTime = false),
                    onSave: _savePickedDateTime,
                  )
                : _buildEditorForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildEditorForm() {
    return SingleChildScrollView(
      key: const ValueKey('editor-form'),
      physics: const ClampingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFE1E3E8),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '我的计划是...',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _buildHeaderAction(),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF4F5F7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFECEFF3)),
            ),
            child: TextField(
              controller: _controller,
              autofocus: widget.item == null && !widget.readOnly,
              enabled: !widget.readOnly,
              minLines: 1,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                hintText: '添加计划信息',
                hintStyle: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (widget.readOnly)
            _ReadOnlyModePill(mode: _mode)
          else
            _PlanModeSwitch(
              value: _mode,
              onChanged: (value) => setState(() => _mode = value),
            ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final slide = Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: SizedBox(
              key: ValueKey('setting-${_mode.name}'),
              height: _settingHeight,
              child: _mode == _CheckinEntryMode.once
                  ? _SingleReminderTimeRow(
                      dateTime: _dateTime,
                      onPick: widget.readOnly ? null : _pickDateTime,
                    )
                  : _HabitWeekdaySection(
                      selected: _habitWeekdays,
                      dateTime: _dateTime,
                      onPickTime: widget.readOnly ? null : _pickDateTime,
                      onToggle: widget.readOnly ? null : _toggleHabitWeekday,
                    ),
            ),
          ),
          const SizedBox(height: 18),
          if (!widget.readOnly) _buildActionRow(),
        ],
      ),
    );
  }

  Widget _buildActionRow() {
    final existing = widget.item;
    final primaryLabel = existing == null ? '确认' : '更新';
    return Row(
      children: [
        if (existing != null && !_sentToAi) ...[
          SizedBox(
            width: 124,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(124, 58),
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFFF3F5F8),
              disabledColor: const Color(0xFFF3F5F8),
              onPressed: _saving || _completing || _deleting || !_canSave
                  ? null
                  : _shareToChat,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.paperplane_fill,
                    color: _canSave
                        ? const Color(0xFF4F5EA8)
                        : AppColors.muted.withValues(alpha: 0.52),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '发聊天',
                    style: TextStyle(
                      color: _canSave
                          ? const Color(0xFF4F5EA8)
                          : AppColors.muted.withValues(alpha: 0.52),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: CupertinoButton(
            color: const Color(0xFF101922),
            disabledColor: const Color(0xFF101922).withValues(alpha: 0.38),
            minimumSize: const Size.fromHeight(58),
            borderRadius: BorderRadius.circular(20),
            onPressed: _saving || _completing || _deleting || !_canSave
                ? null
                : _save,
            child: Text(
              _saving ? '保存中...' : primaryLabel,
              style: TextStyle(
                color: _saving || !_canSave
                    ? Colors.white.withValues(alpha: 0.56)
                    : Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool get _canSave =>
      _controller.text.trim().isNotEmpty &&
      (_mode == _CheckinEntryMode.once || _habitWeekdays.isNotEmpty);

  Widget _buildHeaderAction() {
    if (widget.readOnly && widget.item != null) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(42, 42),
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFFFFF1F1),
        disabledColor: const Color(0xFFFFF1F1),
        onPressed: _saving || _deleting ? null : _deleteFromSheet,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: _deleting
              ? const CupertinoActivityIndicator(
                  key: ValueKey('delete-loading'),
                  radius: 9,
                  color: Color(0xFFFF4D4F),
                )
              : const Icon(
                  key: ValueKey('delete-icon'),
                  CupertinoIcons.delete,
                  color: Color(0xFFFF4D4F),
                  size: 20,
                ),
        ),
      );
    }
    if (!widget.readOnly && widget.item != null) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(42, 42),
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF5BD1A6),
        disabledColor: const Color(0xFF5BD1A6).withValues(alpha: 0.45),
        onPressed: _saving || _completing || _deleting
            ? null
            : _completeFromSheet,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: _completing
              ? const CupertinoActivityIndicator(
                  key: ValueKey('complete-loading'),
                  radius: 9,
                  color: Colors.white,
                )
              : const Icon(
                  key: ValueKey('complete-icon'),
                  CupertinoIcons.check_mark,
                  color: Colors.white,
                  size: 22,
                ),
        ),
      );
    }
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(
        CupertinoIcons.sparkles,
        color: Color(0xFF4F5EA8),
        size: 20,
      ),
    );
  }

  Future<void> _shareToChat() async {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.item == null) return;
    final isHabit = _mode == _CheckinEntryMode.habit;
    final trigger = isHabit
        ? _nextHabitTriggerTime(_habitWeekdays, _dateTime)
        : _dateTime;
    final weekdays = _habitWeekdays.toList()..sort();
    setState(() => _saving = true);
    try {
      final updated = await widget.api.updateReminder(
        widget.item!.id,
        conversationId: widget.session.conversationId,
        summary: text,
        triggerTime: trigger,
        recurrence: isHabit ? 'weekly' : 'once',
        habitWeekdays: isHabit ? weekdays : null,
        sentToAi: true,
      );
      await CheckinNotificationService.instance.scheduleReminder(updated);
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    Navigator.of(context).pop(
      _draftForCheckinData(
        id: widget.item!.id,
        summary: text,
        triggerTime: trigger,
        recurrence: isHabit ? 'weekly' : 'once',
        habitWeekdays: isHabit ? weekdays : const <int>[],
      ),
    );
  }

  void _toggleHabitWeekday(int weekday) {
    setState(() {
      if (_habitWeekdays.contains(weekday)) {
        if (_habitWeekdays.length > 1) _habitWeekdays.remove(weekday);
      } else {
        _habitWeekdays.add(weekday);
      }
    });
  }

  void _pickDateTime() {
    FocusScope.of(context).unfocus();
    final minimum = _minimumReminderDateTime();
    final initialValue =
        _mode == _CheckinEntryMode.habit || _dateTime.isAfter(minimum)
        ? _dateTime
        : _defaultReminderDateTime();
    setState(() {
      _draftDateTime = initialValue;
      _editingTime = true;
    });
  }

  void _savePickedDateTime() {
    if (_mode == _CheckinEntryMode.once &&
        !_isFutureReminderTime(_draftDateTime)) {
      _showFutureTimeRequired(context);
      return;
    }
    setState(() {
      _dateTime = _draftDateTime;
      _editingTime = false;
    });
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    final agentId = widget.session.agentId;
    if (text.isEmpty || agentId == null || agentId.isEmpty) return;
    final isHabit = _mode == _CheckinEntryMode.habit;
    final trigger = isHabit
        ? _nextHabitTriggerTime(_habitWeekdays, _dateTime)
        : _dateTime;
    if (!isHabit && !_isFutureReminderTime(trigger)) {
      _showFutureTimeRequired(context);
      return;
    }
    final weekdays = _habitWeekdays.toList()..sort();
    setState(() => _saving = true);
    try {
      final existing = widget.item;
      final item = existing == null
          ? await widget.api.createReminder(
              agentId: agentId,
              workspaceId: widget.session.workspaceId,
              conversationId: widget.session.conversationId,
              summary: text,
              triggerTime: trigger,
              recurrence: isHabit ? 'weekly' : 'once',
              habitWeekdays: isHabit ? weekdays : null,
              sentToAi: false,
            )
          : await widget.api.updateReminder(
              existing.id,
              conversationId: widget.session.conversationId,
              summary: text,
              triggerTime: trigger,
              recurrence: isHabit ? 'weekly' : 'once',
              habitWeekdays: isHabit ? weekdays : null,
              sentToAi: _sentToAi,
            );
      if (mounted) Navigator.of(context).pop(item);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _completeFromSheet() async {
    final existing = widget.item;
    if (existing == null || _saving || _completing || _deleting) return;
    setState(() => _completing = true);
    try {
      final completed = await widget.api.completeReminder(
        existing.id,
        conversationId: widget.session.conversationId,
        occurrenceDate: widget.initialDate,
      );
      if (existing.isHabit) {
        await CheckinNotificationService.instance.scheduleReminder(completed);
      } else {
        await CheckinNotificationService.instance.cancelReminderItem(completed);
      }
      if (mounted) Navigator.of(context).pop(completed);
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  Future<void> _deleteFromSheet() async {
    final existing = widget.item;
    if (existing == null || _saving || _deleting) return;
    setState(() => _deleting = true);
    try {
      await widget.api.deleteReminder(
        existing.id,
        conversationId: widget.session.conversationId,
      );
      await CheckinNotificationService.instance.cancelReminderItem(existing);
      if (mounted) Navigator.of(context).pop(_CheckinDeletedResult(existing));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }
}

class _EditorTimePickerView extends StatelessWidget {
  const _EditorTimePickerView({
    super.key,
    required this.dateTime,
    required this.title,
    required this.timeOnly,
    required this.minimumDate,
    required this.onChanged,
    required this.onCancel,
    required this.onSave,
  });

  final DateTime dateTime;
  final String title;
  final bool timeOnly;
  final DateTime minimumDate;
  final ValueChanged<DateTime> onChanged;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Localizations.override(
      context: context,
      locale: const Locale('zh', 'CN'),
      child: SizedBox.expand(
        key: const ValueKey('editor-time-picker-content'),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE1E3E8),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 42),
            Text(
              title,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 230,
              child: CupertinoDatePicker(
                mode: timeOnly
                    ? CupertinoDatePickerMode.time
                    : CupertinoDatePickerMode.dateAndTime,
                initialDateTime: dateTime,
                minimumDate: timeOnly ? null : minimumDate,
                minuteInterval: 1,
                use24hFormat: true,
                onDateTimeChanged: onChanged,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    onPressed: onCancel,
                    child: const Text('取消'),
                  ),
                ),
                Expanded(
                  child: CupertinoButton(
                    onPressed: onSave,
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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

class _PlanModeSwitch extends StatelessWidget {
  const _PlanModeSwitch({required this.value, required this.onChanged});

  final _CheckinEntryMode value;
  final ValueChanged<_CheckinEntryMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final onceSelected = value == _CheckinEntryMode.once;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F8),
        borderRadius: BorderRadius.circular(22),
      ),
      child: SizedBox(
        height: 48,
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: onceSelected
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F5EA8).withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                _PlanModeButton(
                  selected: onceSelected,
                  label: '单次计划',
                  icon: CupertinoIcons.clock,
                  onTap: () => onChanged(_CheckinEntryMode.once),
                ),
                _PlanModeButton(
                  selected: !onceSelected,
                  label: '周期习惯',
                  icon: CupertinoIcons.repeat,
                  onTap: () => onChanged(_CheckinEntryMode.habit),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanModeButton extends StatelessWidget {
  const _PlanModeButton({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF4F5EA8) : AppColors.muted;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.expand(
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 7),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyModePill extends StatelessWidget {
  const _ReadOnlyModePill({required this.mode});

  final _CheckinEntryMode mode;

  @override
  Widget build(BuildContext context) {
    final isHabit = mode == _CheckinEntryMode.habit;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F8),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isHabit ? CupertinoIcons.repeat : CupertinoIcons.clock,
            color: const Color(0xFF4F5EA8),
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            isHabit ? '周期习惯' : '单次计划',
            style: const TextStyle(
              color: Color(0xFF4F5EA8),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFECEFF3)),
      ),
      child: child,
    );
  }
}

class _SettingIconBox extends StatelessWidget {
  const _SettingIconBox({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: AppColors.text, size: 23),
    );
  }
}

class _SettingLabel extends StatelessWidget {
  const _SettingLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 15,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _SettingTitle extends StatelessWidget {
  const _SettingTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AppColors.text,
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _IconPillButton extends StatelessWidget {
  const _IconPillButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(42, 42),
      onPressed: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, color: const Color(0xFF4F5EA8), size: 21),
      ),
    );
  }
}

class _SingleReminderTimeRow extends StatelessWidget {
  const _SingleReminderTimeRow({required this.dateTime, required this.onPick});

  final DateTime dateTime;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    return _SettingCard(
      child: Row(
        children: [
          const _SettingIconBox(icon: CupertinoIcons.alarm),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SettingLabel('提醒时间'),
                const SizedBox(height: 3),
                _SettingTitle(_fullDateTimeLabel(dateTime)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (onPick != null)
            _IconPillButton(icon: CupertinoIcons.pencil, onTap: onPick!),
        ],
      ),
    );
  }
}

class _HabitWeekdaySection extends StatelessWidget {
  const _HabitWeekdaySection({
    required this.selected,
    required this.dateTime,
    required this.onPickTime,
    required this.onToggle,
  });

  final Set<int> selected;
  final DateTime dateTime;
  final VoidCallback? onPickTime;
  final ValueChanged<int>? onToggle;

  @override
  Widget build(BuildContext context) {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return _SettingCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SettingLabel('习惯周期'),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: onPickTime,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE7EAF0)),
                  ),
                  child: Text(
                    _timeLabel(dateTime),
                    style: const TextStyle(
                      color: Color(0xFF4F5EA8),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: List.generate(7, (index) {
              final weekday = index + 1;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: index == 0 ? 0 : 6),
                  child: _WeekdayDotButton(
                    selected: selected.contains(weekday),
                    label: labels[index],
                    onTap: onToggle == null ? null : () => onToggle!(weekday),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _WeekdayDotButton extends StatelessWidget {
  const _WeekdayDotButton({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(38.0, constraints.maxWidth);
        return Center(
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              curve: Curves.easeOutCubic,
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFFFC338) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? const Color(0xFFFFC338)
                      : const Color(0xFFE4E8EE),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.text : AppColors.muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PickerSheet extends StatelessWidget {
  const _PickerSheet({
    required this.title,
    required this.child,
    required this.onCancel,
    required this.onSave,
  });

  final String title;
  final Widget child;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 360,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.none,
              ),
            ),
            Expanded(child: child),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                CupertinoButton(onPressed: onCancel, child: const Text('取消')),
                CupertinoButton(onPressed: onSave, child: const Text('保存')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF24344A).withValues(alpha: 0.10),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.text, size: 25),
      ),
    );
  }
}

class _CheckinLoadingCard extends StatelessWidget {
  const _CheckinLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 118,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(26),
      ),
      child: const CupertinoActivityIndicator(),
    );
  }
}

class _CheckinEmptyCard extends StatelessWidget {
  const _CheckinEmptyCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onAdd,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(26),
        ),
        child: const Text(
          '这一天还没有打卡任务',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _CheckinBackdrop extends StatelessWidget {
  const _CheckinBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFCFDFB), Color(0xFFF3F8F5), Color(0xFFFAFBF8)],
        ),
      ),
    );
  }
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

class _SolarLunar {
  static const _terms = [
    '小寒',
    '大寒',
    '立春',
    '雨水',
    '惊蛰',
    '春分',
    '清明',
    '谷雨',
    '立夏',
    '小满',
    '芒种',
    '夏至',
    '小暑',
    '大暑',
    '立秋',
    '处暑',
    '白露',
    '秋分',
    '寒露',
    '霜降',
    '立冬',
    '小雪',
    '大雪',
    '冬至',
  ];
  static const _termInfo = [
    0,
    21208,
    42467,
    63836,
    85337,
    107014,
    128867,
    150921,
    173149,
    195551,
    218072,
    240693,
    263343,
    285989,
    308563,
    331033,
    353350,
    375494,
    397447,
    419210,
    440795,
    462224,
    483532,
    504758,
  ];
  static const _lunarInfo = [
    0x04bd8,
    0x04ae0,
    0x0a570,
    0x054d5,
    0x0d260,
    0x0d950,
    0x16554,
    0x056a0,
    0x09ad0,
    0x055d2,
    0x04ae0,
    0x0a5b6,
    0x0a4d0,
    0x0d250,
    0x1d255,
    0x0b540,
    0x0d6a0,
    0x0ada2,
    0x095b0,
    0x14977,
    0x04970,
    0x0a4b0,
    0x0b4b5,
    0x06a50,
    0x06d40,
    0x1ab54,
    0x02b60,
    0x09570,
    0x052f2,
    0x04970,
    0x06566,
    0x0d4a0,
    0x0ea50,
    0x06e95,
    0x05ad0,
    0x02b60,
    0x186e3,
    0x092e0,
    0x1c8d7,
    0x0c950,
    0x0d4a0,
    0x1d8a6,
    0x0b550,
    0x056a0,
    0x1a5b4,
    0x025d0,
    0x092d0,
    0x0d2b2,
    0x0a950,
    0x0b557,
    0x06ca0,
    0x0b550,
    0x15355,
    0x04da0,
    0x0a5d0,
    0x14573,
    0x052d0,
    0x0a9a8,
    0x0e950,
    0x06aa0,
    0x0aea6,
    0x0ab50,
    0x04b60,
    0x0aae4,
    0x0a570,
    0x05260,
    0x0f263,
    0x0d950,
    0x05b57,
    0x056a0,
    0x096d0,
    0x04dd5,
    0x04ad0,
    0x0a4d0,
    0x0d4d4,
    0x0d250,
    0x0d558,
    0x0b540,
    0x0b5a0,
    0x195a6,
    0x095b0,
    0x049b0,
    0x0a974,
    0x0a4b0,
    0x0b27a,
    0x06a50,
    0x06d40,
    0x0af46,
    0x0ab60,
    0x09570,
    0x04af5,
    0x04970,
    0x064b0,
    0x074a3,
    0x0ea50,
    0x06b58,
    0x055c0,
    0x0ab60,
    0x096d5,
    0x092e0,
    0x0c960,
    0x0d954,
    0x0d4a0,
    0x0da50,
    0x07552,
    0x056a0,
    0x0abb7,
    0x025d0,
    0x092d0,
    0x0cab5,
    0x0a950,
    0x0b4a0,
    0x0baa4,
    0x0ad50,
    0x055d9,
    0x04ba0,
    0x0a5b0,
    0x15176,
    0x052b0,
    0x0a930,
    0x07954,
    0x06aa0,
    0x0ad50,
    0x05b52,
    0x04b60,
    0x0a6e6,
    0x0a4e0,
    0x0d260,
    0x0ea65,
    0x0d530,
    0x05aa0,
    0x076a3,
    0x096d0,
    0x04bd7,
    0x04ad0,
    0x0a4d0,
    0x1d0b6,
    0x0d250,
    0x0d520,
    0x0dd45,
    0x0b5a0,
    0x056d0,
    0x055b2,
    0x049b0,
    0x0a577,
    0x0a4b0,
    0x0aa50,
    0x1b255,
    0x06d20,
    0x0ada0,
    0x14b63,
    0x09370,
    0x049f8,
    0x04970,
    0x064b0,
    0x168a6,
    0x0ea50,
    0x06aa0,
    0x1a6c4,
    0x0aae0,
    0x092e0,
    0x0d2e3,
    0x0c960,
    0x0d557,
    0x0d4a0,
    0x0da50,
    0x05d55,
    0x056a0,
    0x0a6d0,
    0x055d4,
    0x052d0,
    0x0a9b8,
    0x0a950,
    0x0b4a0,
    0x0b6a6,
    0x0ad50,
    0x055a0,
    0x0aba4,
    0x0a5b0,
    0x052b0,
    0x0b273,
    0x06930,
    0x07337,
    0x06aa0,
    0x0ad50,
    0x14b55,
    0x04b60,
    0x0a570,
    0x054e4,
    0x0d160,
    0x0e968,
    0x0d520,
    0x0daa0,
    0x16aa6,
    0x056d0,
    0x04ae0,
    0x0a9d4,
    0x0a2d0,
    0x0d150,
    0x0f252,
    0x0d520,
  ];

  static String label(DateTime date) {
    final term = _solarTerm(date);
    if (term != null) return term;
    return _lunarDay(date);
  }

  static String? _solarTerm(DateTime date) {
    if (date.year < 1900 || date.year > 2100) return null;
    for (var i = 0; i < 24; i += 1) {
      final millis = 31556925974.7 * (date.year - 1900) + _termInfo[i] * 60000;
      final termDate = DateTime.utc(
        1900,
        1,
        6,
        2,
        5,
      ).add(Duration(milliseconds: millis.round()));
      final local = termDate.toLocal();
      if (local.month == date.month && local.day == date.day) return _terms[i];
    }
    return null;
  }

  static String _lunarDay(DateTime date) {
    if (date.year < 1900 || date.year > 2100) return '';
    var offset = _dateOnlyTime(date).difference(DateTime(1900, 1, 31)).inDays;
    var year = 1900;
    var daysOfYear = 0;
    for (; year < 2101 && offset > 0; year += 1) {
      daysOfYear = _lunarYearDays(year);
      offset -= daysOfYear;
    }
    if (offset < 0) offset += daysOfYear;
    final leap = _leapMonth(year - 1);
    var isLeap = false;
    var month = 1;
    var daysOfMonth = 0;
    for (; month < 13 && offset > 0; month += 1) {
      if (leap > 0 && month == leap + 1 && !isLeap) {
        month -= 1;
        isLeap = true;
        daysOfMonth = _leapDays(year - 1);
      } else {
        daysOfMonth = _monthDays(year - 1, month);
      }
      offset -= daysOfMonth;
      if (isLeap && month == leap + 1) isLeap = false;
    }
    if (offset < 0) offset += daysOfMonth;
    final day = offset + 1;
    return _dayName(day);
  }

  static int _lunarYearDays(int year) {
    var sum = 348;
    var info = _lunarInfo[year - 1900];
    for (var mask = 0x8000; mask > 0x8; mask >>= 1) {
      if ((info & mask) != 0) sum += 1;
    }
    return sum + _leapDays(year);
  }

  static int _leapDays(int year) {
    if (_leapMonth(year) == 0) return 0;
    return (_lunarInfo[year - 1900] & 0x10000) != 0 ? 30 : 29;
  }

  static int _leapMonth(int year) => _lunarInfo[year - 1900] & 0xf;

  static int _monthDays(int year, int month) =>
      (_lunarInfo[year - 1900] & (0x10000 >> month)) != 0 ? 30 : 29;

  static String _dayName(int day) {
    const nums = ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十'];
    if (day <= 0) return '';
    if (day == 10) return '初十';
    if (day == 20) return '二十';
    if (day == 30) return '三十';
    final prefix = switch ((day - 1) ~/ 10) {
      0 => '初',
      1 => '十',
      2 => '廿',
      _ => '三',
    };
    return '$prefix${nums[(day - 1) % 10]}';
  }
}
