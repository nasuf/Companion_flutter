part of 'package:companion_flutter/main.dart';

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
      decoration: BoxDecoration(
        color: AppColors.page,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: AppColors.glassBorder(context))),
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
              Expanded(
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
              color: AppColors.elevatedSurface(context, light: 0.82),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.glassBorder(context)),
            ),
            child: TextField(
              controller: _controller,
              autofocus: widget.item == null && !widget.readOnly,
              enabled: !widget.readOnly,
              minLines: 1,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
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
              color: AppColors.subtleFill(context, light: 0.74),
              disabledColor: AppColors.subtleFill(context, light: 0.58),
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
        color: AppColors.subtleFill(context, light: 0.74),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder(context)),
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
