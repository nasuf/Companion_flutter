part of 'package:companion_flutter/main.dart';

/// What a finished plan shows when you tap it.
///
/// Nothing here is a field. Reusing the editor with everything greyed out reads
/// as broken rather than as done, so this is a read-only card: the outcome
/// first, then the facts, then the verbs that still apply. Editing a habit is
/// one of those verbs, but it is a deliberate second tap rather than the state
/// you land in.
Future<Object?> _showCheckinDetail({
  required BuildContext context,
  required ReminderItem item,
  required DateTime date,
}) {
  return showModalBottomSheet<Object?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: _CheckinTokens.of(context).scrim,
    builder: (_) => _CheckinDetailSheet(
      item: item,
      date: date,
      topInset: MediaQuery.paddingOf(context).top,
    ),
  );
}

/// Asks the page to delete this plan — the page owns the API call so the list
/// can hide the row straight away.
class _CheckinDeleteRequest {
  const _CheckinDeleteRequest(this.item);

  final ReminderItem item;
}

/// Asks the page to reopen this plan in the editor.
class _CheckinEditRequest {
  const _CheckinEditRequest(this.item);

  final ReminderItem item;
}

class _CheckinDetailSheet extends StatelessWidget {
  const _CheckinDetailSheet({
    required this.item,
    required this.date,
    required this.topInset,
  });

  final ReminderItem item;
  final DateTime date;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    final tokens = _CheckinTokens.of(context);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height - topInset - 24;
    final habit = item.isHabit;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: math.max(maxHeight, 0)),
      child: Container(
        key: const Key('checkin-detail'),
        decoration: BoxDecoration(
          color: tokens.page,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(_kCheckinCardRadius),
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            _kCheckinMargin,
            _kCheckinSheetPadTop,
            _kCheckinMargin,
            _kCheckinSheetSaveGap + safeBottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _status(tokens, habit),
              const SizedBox(height: 12),
              Text(
                item.summary,
                style: TextStyle(
                  color: tokens.title,
                  fontSize: 20,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 20),
              if (habit) ...[
                // The weekdays as chips, the same ones the editor draws. A
                // comma-joined sentence is the sort of thing you have to read;
                // the row you just glance at.
                _CheckinWeekdayCard(selected: item.habitWeekdays.toSet()),
                const SizedBox(height: _kCheckinSheetFieldGap),
              ],
              _facts(tokens, habit),
              const SizedBox(height: 24),
              _actions(context, tokens, habit),
            ],
          ),
        ),
      ),
    );
  }

  Widget _status(_CheckinTokens tokens, bool habit) {
    final done = habit ? item.completedDates.length : 1;
    return Row(
      children: [
        _CheckinCheckBadge(size: 24, color: tokens.accent),
        const SizedBox(width: 8),
        Text(
          habit ? '今日已打卡' : '已完成',
          style: TextStyle(
            color: tokens.accent,
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.none,
          ),
        ),
        const Spacer(),
        if (habit)
          Text(
            '累计 $done 次',
            style: TextStyle(
              color: tokens.subtitle,
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w400,
              decoration: TextDecoration.none,
            ),
          ),
      ],
    );
  }

  Widget _facts(_CheckinTokens tokens, bool habit) {
    final note = item.note ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: _kCheckinMargin),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(_kCheckinCardRadius),
        boxShadow: tokens.cardShadow,
      ),
      child: Column(
        children: [
          _row(tokens, '计划类型', habit ? '周期习惯' : '单次计划'),
          _divider(tokens),
          _row(
            tokens,
            '提醒时间',
            habit
                ? _timeLabel(item.triggerTime)
                : _checkinDateTimeLabel(item.triggerTime),
          ),
          _divider(tokens),
          _row(tokens, habit ? '本次打卡' : '完成于', _checkinDayLabel(date)),
          if (note.isNotEmpty) ...[_divider(tokens), _row(tokens, '备注', note)],
        ],
      ),
    );
  }

  Widget _row(_CheckinTokens tokens, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: tokens.sectionTitle,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: tokens.title,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w400,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(_CheckinTokens tokens) =>
      Container(height: 1, color: tokens.dayPill);

  Widget _actions(BuildContext context, _CheckinTokens tokens, bool habit) {
    final delete = _CheckinPrimaryButton(
      label: '删除计划',
      busy: false,
      danger: true,
      onPressed: () => _confirmDelete(context),
    );
    // A finished one-off has nothing left to change, and the server refuses to
    // edit it anyway. A habit is still running, so it keeps a way back in.
    if (!habit) return delete;
    return Row(
      children: [
        Expanded(
          child: _CheckinSecondaryButton(
            label: '编辑习惯',
            onPressed: () =>
                Navigator.of(context).pop(_CheckinEditRequest(item)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: delete),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    if (!await _confirmCheckinDelete(context) || !context.mounted) return;
    Navigator.of(context).pop(_CheckinDeleteRequest(item));
  }
}
