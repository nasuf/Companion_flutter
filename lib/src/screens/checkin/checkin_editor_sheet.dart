part of 'package:companion_flutter/main.dart';

class _CheckinDeletedResult {
  const _CheckinDeletedResult(this.item);

  final ReminderItem item;
}

/// `2026年7月23日 09:00` — the reminder value as the design writes it.
String _checkinDateTimeLabel(DateTime value) {
  final local = value.toLocal();
  return '${local.year}年${local.month}月${local.day}日 ${_timeLabel(local)}';
}

Future<Object?> _showCheckinEditor({
  required BuildContext context,
  required CompanionApi api,
  required AuthSession session,
  required DateTime initialDate,
  ReminderItem? item,
}) {
  // showModalBottomSheet strips the top padding from the sheet's MediaQuery,
  // so the safe area has to be read here or the sheet would grow under the
  // status bar once the keyboard pushes it up.
  final topInset = MediaQuery.paddingOf(context).top;
  return showModalBottomSheet<Object?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: _CheckinTokens.of(context).scrim,
    builder: (_) => _CheckinEditorSheet(
      api: api,
      session: session,
      initialDate: initialDate,
      item: item,
      topInset: topInset,
    ),
  );
}

class _CheckinEditorSheet extends StatefulWidget {
  const _CheckinEditorSheet({
    required this.api,
    required this.session,
    required this.initialDate,
    required this.topInset,
    this.item,
  });

  final CompanionApi api;
  final AuthSession session;
  final DateTime initialDate;
  final double topInset;
  final ReminderItem? item;

  @override
  State<_CheckinEditorSheet> createState() => _CheckinEditorSheetState();
}

class _CheckinEditorSheetState extends State<_CheckinEditorSheet> {
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();

  late DateTime _dateTime;
  _CheckinEntryMode _mode = _CheckinEntryMode.once;
  final Set<int> _habitWeekdays = <int>{};
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
    _nameController.text = item?.summary ?? '';
    _noteController.text = item?.note ?? '';
    _sentToAi = item?.sentToAi ?? false;
    _dateTime = item?.triggerTime.toLocal() ?? _defaultReminderDateTime();
    _habitWeekdays.addAll(
      item != null && item.habitWeekdays.isNotEmpty
          ? item.habitWeekdays
          : <int>{DateTime.now().weekday},
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  bool get _busy => _saving || _completing || _deleting;

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      (_mode == _CheckinEntryMode.once || _habitWeekdays.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final tokens = _CheckinTokens.of(context);
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final safeBottom = media.padding.bottom;
    // The keyboard's own top corners are rounded, so a sheet that stops exactly
    // at the keyboard line leaves two dark notches of scrim showing. Running it
    // a little way underneath fills them.
    const underlap = 20.0;
    final lift = keyboard > 0 ? math.max(keyboard - underlap, 0.0) : 0.0;
    // The panel is as tall as what is in it, not a fixed slice of the screen.
    // The Figma frame is a fixed 680 with a dead gap above the button; keeping
    // that gap means the button has to fly ~280px when the keyboard opens,
    // which reads as the whole screen being reflowed. Sized to its content the
    // panel simply rides up onto the keyboard in one piece.
    final available = media.size.height - widget.topInset - 24 - lift;
    return Padding(
      padding: EdgeInsets.only(bottom: lift),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: math.max(available, 0)),
        // Switching to 周期习惯 adds a 140px card; with a content-sized panel
        // that would otherwise pop the top edge up in one frame.
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: Container(
            key: const Key('checkin-sheet'),
            decoration: BoxDecoration(
              color: tokens.page,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(_kCheckinCardRadius),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Flexible, not Expanded: the form takes only the room it needs
                // until the panel hits the cap, and scrolls after that.
                Flexible(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => FocusScope.of(context).unfocus(),
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(
                        _kCheckinMargin,
                        _kCheckinSheetPadTop,
                        _kCheckinMargin,
                        8,
                      ),
                      child: _form(tokens),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    _kCheckinMargin,
                    12,
                    _kCheckinMargin,
                    keyboard > 0
                        ? 16 + underlap
                        : _kCheckinSheetSaveGap + safeBottom,
                  ),
                  child: _CheckinPrimaryButton(
                    label: '保存计划',
                    busy: _saving,
                    onPressed: _busy || !_canSave ? null : _save,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(_CheckinTokens tokens) {
    final habit = _mode == _CheckinEntryMode.habit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The design only draws the "create" flow. Editing needs a couple of
        // extra verbs, so they sit in a compact row above the name field and
        // the create layout stays exactly as drawn.
        if (widget.item != null) ...[
          _actionRow(tokens),
          const SizedBox(height: 12),
        ],
        _CheckinNameField(
          controller: _nameController,
          enabled: true,
          autofocus: widget.item == null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: _kCheckinSheetFieldGap),
        _CheckinModeSwitch(
          value: _mode,
          onChanged: (value) => setState(() => _mode = value),
        ),
        const SizedBox(height: _kCheckinSheetFieldGap),
        if (habit) ...[
          _CheckinWeekdayCard(
            selected: _habitWeekdays,
            onToggle: _toggleWeekday,
          ),
          const SizedBox(height: _kCheckinSheetFieldGap),
        ],
        _CheckinReminderRow(
          value: habit
              ? _timeLabel(_dateTime)
              : _checkinDateTimeLabel(_dateTime),
          onPick: _pickDateTime,
        ),
        const SizedBox(height: _kCheckinSheetFieldGap),
        _CheckinNoteCard(controller: _noteController),
      ],
    );
  }

  Widget _actionRow(_CheckinTokens tokens) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _CheckinSheetAction(
          icon: CupertinoIcons.paperplane_fill,
          color: tokens.accent,
          busy: false,
          onPressed: !_sentToAi && _canSave && !_busy ? _shareToChat : null,
        ),
        const SizedBox(width: 10),
        _CheckinSheetAction(
          icon: CupertinoIcons.check_mark,
          color: const Color(0xFF5DCFA8),
          busy: _completing,
          onPressed: _busy ? null : _complete,
        ),
        const SizedBox(width: 10),
        _CheckinSheetAction(
          icon: CupertinoIcons.delete,
          color: const Color(0xFFFF4C4C),
          busy: _deleting,
          onPressed: _busy ? null : _delete,
        ),
      ],
    );
  }

  void _toggleWeekday(int weekday) {
    setState(() {
      if (_habitWeekdays.contains(weekday)) {
        if (_habitWeekdays.length > 1) _habitWeekdays.remove(weekday);
      } else {
        _habitWeekdays.add(weekday);
      }
    });
  }

  Future<void> _pickDateTime() async {
    FocusScope.of(context).unfocus();
    final habit = _mode == _CheckinEntryMode.habit;
    final minimum = _minimumReminderDateTime();
    final initialValue = habit || _dateTime.isAfter(minimum)
        ? _dateTime
        : _defaultReminderDateTime();
    var value = initialValue;
    final picked = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (context) => Localizations.override(
        context: context,
        locale: const Locale('zh', 'CN'),
        child: _PickerSheet(
          title: habit ? '打卡时间' : '提醒时间',
          onCancel: () => Navigator.of(context).pop(),
          onSave: () {
            if (!habit && !_isFutureReminderTime(value)) {
              _showFutureTimeRequired(context);
              return;
            }
            Navigator.of(context).pop(value);
          },
          child: CupertinoDatePicker(
            mode: habit
                ? CupertinoDatePickerMode.time
                : CupertinoDatePickerMode.dateAndTime,
            initialDateTime: initialValue,
            minimumDate: habit ? null : minimum,
            minuteInterval: 1,
            use24hFormat: true,
            onDateTimeChanged: (date) => value = date,
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _dateTime = picked);
  }

  /// Empty string clears the stored note; `null` would leave it untouched.
  String get _notePayload => _noteController.text.trim();

  Future<void> _save() async {
    final text = _nameController.text.trim();
    final agentId = widget.session.agentId;
    if (text.isEmpty || agentId == null || agentId.isEmpty) return;
    final habit = _mode == _CheckinEntryMode.habit;
    final trigger = habit
        ? _nextHabitTriggerTime(_habitWeekdays, _dateTime)
        : _dateTime;
    if (!habit && !_isFutureReminderTime(trigger)) {
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
              note: _notePayload,
              triggerTime: trigger,
              recurrence: habit ? 'weekly' : 'once',
              habitWeekdays: habit ? weekdays : null,
              sentToAi: false,
            )
          : await widget.api.updateReminder(
              existing.id,
              conversationId: widget.session.conversationId,
              summary: text,
              note: _notePayload,
              triggerTime: trigger,
              recurrence: habit ? 'weekly' : 'once',
              habitWeekdays: habit ? weekdays : null,
              sentToAi: _sentToAi,
            );
      if (mounted) Navigator.of(context).pop(item);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _shareToChat() async {
    final existing = widget.item;
    final text = _nameController.text.trim();
    if (existing == null || text.isEmpty) return;
    final habit = _mode == _CheckinEntryMode.habit;
    final trigger = habit
        ? _nextHabitTriggerTime(_habitWeekdays, _dateTime)
        : _dateTime;
    final weekdays = _habitWeekdays.toList()..sort();
    setState(() => _saving = true);
    try {
      final updated = await widget.api.updateReminder(
        existing.id,
        conversationId: widget.session.conversationId,
        summary: text,
        note: _notePayload,
        triggerTime: trigger,
        recurrence: habit ? 'weekly' : 'once',
        habitWeekdays: habit ? weekdays : null,
        sentToAi: true,
      );
      await CheckinNotificationService.instance.scheduleReminder(updated);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    Navigator.of(context).pop(
      _draftForCheckinData(
        id: existing.id,
        summary: text,
        triggerTime: trigger,
        recurrence: habit ? 'weekly' : 'once',
        habitWeekdays: habit ? weekdays : const <int>[],
      ),
    );
  }

  Future<void> _complete() async {
    final existing = widget.item;
    if (existing == null || _busy) return;
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

  Future<void> _delete() async {
    final existing = widget.item;
    if (existing == null || _busy) return;
    if (!await _confirmCheckinDelete(context) || !mounted) return;
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
