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
  late DateTime _visibleWeek;
  late DateTime _visibleMonth;
  late Future<List<ReminderItem>> _future;
  final Set<String> _hiddenReminderIds = <String>{};
  final Set<String> _optimisticCompletedKeys = <String>{};
  final Map<String, bool> _optimisticPinnedOverrides = <String, bool>{};
  String? _openSwipeItemId;
  bool _calendarExpanded = false;
  bool _initialReminderOpened = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateOnlyTime(DateTime.now());
    _visibleWeek = _weekStart(_selectedDate);
    _visibleMonth = _monthOnly(_selectedDate);
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

  void _selectDate(DateTime date) {
    final day = _dateOnlyTime(date);
    setState(() {
      _selectedDate = day;
      _visibleWeek = _weekStart(day);
      _visibleMonth = _monthOnly(day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = _CheckinTokens.of(context);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: tokens.page,
      body: FutureBuilder<List<ReminderItem>>(
        future: _future,
        builder: (context, snapshot) {
          final items = (snapshot.data ?? const <ReminderItem>[])
              .where((item) => !_hiddenReminderIds.contains(item.id))
              .toList();
          _openInitialReminderIfNeeded(items);
          final visible = _tasksForDate(items, _selectedDate);
          final loading = snapshot.connectionState == ConnectionState.waiting;
          return Stack(
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _header(tokens),
                    const SizedBox(height: 24),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          _kCheckinMargin,
                          0,
                          _kCheckinMargin,
                          safeBottom + 96,
                        ),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _CheckinCalendarCard(
                            selectedDate: _selectedDate,
                            visibleWeek: _visibleWeek,
                            visibleMonth: _visibleMonth,
                            expanded: _calendarExpanded,
                            markFor: (date) => _markFor(items, date),
                            onSelected: _selectDate,
                            onVisibleWeekChanged: (week) =>
                                setState(() => _visibleWeek = week),
                            onVisibleMonthChanged: (month) =>
                                setState(() => _visibleMonth = month),
                            onExpandedChanged: (expanded) =>
                                setState(() => _calendarExpanded = expanded),
                          ),
                          const SizedBox(height: _kCheckinSectionGap),
                          _sectionTitle(tokens),
                          const SizedBox(height: _kCheckinSectionTitleGap),
                          if (loading)
                            const _CheckinLoadingCard()
                          else if (visible.isEmpty)
                            _CheckinEmptyCard(onAdd: _openEditor)
                          else
                            _CheckinTaskList(
                              items: visible,
                              isCompleted: _isCompleted,
                              isPinned: _isPinned,
                              openItemId: _openSwipeItemId,
                              onSwipeOpen: _setOpenSwipeItem,
                              onItemTap: _openTaskSheet,
                              onComplete: _complete,
                              onPin: _pin,
                              onDelete: _delete,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: _kCheckinMargin,
                bottom: safeBottom + 24,
                child: _CheckinFab(onPressed: _openEditor),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(_CheckinTokens tokens) {
    return SizedBox(
      height: 36,
      child: Stack(
        children: [
          Positioned(
            left: 24,
            top: 0,
            child: _CheckinNavButton(
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Center(
            child: Text(
              '打卡',
              style: TextStyle(
                color: tokens.title,
                fontSize: 24,
                height: 1.2,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(_CheckinTokens tokens) {
    final today = _isSameDate(_selectedDate, DateTime.now());
    return Text(
      today ? '今日任务' : '打卡任务',
      style: TextStyle(
        color: tokens.sectionTitle,
        fontSize: 20,
        height: 1.2,
        fontWeight: FontWeight.w700,
        decoration: TextDecoration.none,
      ),
    );
  }

  _CheckinDayMark _markFor(List<ReminderItem> items, DateTime date) {
    var total = 0;
    var done = 0;
    for (final item in items) {
      if (!_matchesDate(item, date)) continue;
      total += 1;
      if (_isCompletedOnDate(item, date)) done += 1;
    }
    if (total == 0) return _CheckinDayMark.none;
    if (done == total) return _CheckinDayMark.done;
    if (done > 0) return _CheckinDayMark.partial;
    return _CheckinDayMark.pending;
  }

  Future<void> _openEditor() async {
    final created = await _showCheckinEditor(
      context: context,
      api: widget.api,
      session: widget.session,
      initialDate: _selectedDate,
    );
    if (created == null || !mounted) return;
    if (created is ReminderItem) {
      await CheckinNotificationService.instance.scheduleReminder(created);
      if (!mounted) return;
      final day = _dateOnlyTime(created.triggerTime.toLocal());
      setState(() {
        _selectedDate = day;
        _visibleWeek = _weekStart(day);
        _visibleMonth = _monthOnly(day);
        _future = _load();
      });
    }
  }

  Future<void> _openTaskSheet(ReminderItem item) async {
    setState(() => _openSwipeItemId = null);
    // A finished one-off has nothing left to edit, so it opens as a summary.
    // A habit ticked today is still a running habit and stays editable.
    if (_isCompleted(item) && !item.isHabit) {
      final request = await _showCheckinDetail(
        context: context,
        item: item,
        date: _selectedDate,
      );
      if (!mounted || request is! _CheckinDeleteRequest) return;
      await _delete(request.item);
      return;
    }
    final result = await _showCheckinEditor(
      context: context,
      api: widget.api,
      session: widget.session,
      initialDate: _selectedDate,
      item: item,
    );
    if (!mounted || result == null) return;
    if (result is CapsuleChatDraft) {
      Navigator.of(context).pop(result);
      return;
    }
    if (result is _CheckinDeletedResult) {
      await CheckinNotificationService.instance.cancelReminderItem(result.item);
      if (!mounted) return;
      setState(() {
        _openSwipeItemId = null;
        _hiddenReminderIds.add(result.item.id);
      });
      return;
    }
    if (result is ReminderItem) {
      await CheckinNotificationService.instance.scheduleReminder(result);
      if (!mounted) return;
      setState(() {
        _selectedDate = _dateOnlyTime(result.triggerTime.toLocal());
        _visibleWeek = _weekStart(_selectedDate);
        _visibleMonth = _monthOnly(_selectedDate);
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
      _selectDate(focusDate);
      unawaited(_openTaskSheet(targetItem));
    });
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
}
