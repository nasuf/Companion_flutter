part of 'package:companion_flutter/main.dart';

/// What a finished plan shows when you tap it.
///
/// A completed plan has nothing left to edit, and reusing the editor with every
/// field greyed out reads as broken rather than as "done". This is a short
/// read-only card instead: the outcome first, then the facts, then the one verb
/// that still applies.
Future<Object?> _showCheckinDetail({
  required BuildContext context,
  required ReminderItem item,
  required DateTime date,
}) {
  final topInset = MediaQuery.paddingOf(context).top;
  return showModalBottomSheet<Object?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: _CheckinTokens.of(context).scrim,
    builder: (_) =>
        _CheckinDetailSheet(item: item, date: date, topInset: topInset),
  );
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
    return Container(
      key: const Key('checkin-detail'),
      constraints: BoxConstraints(maxHeight: maxHeight),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _CheckinCheckBadge(size: 24, color: tokens.accent),
                const SizedBox(width: 8),
                Text(
                  '已完成',
                  style: TextStyle(
                    color: tokens.accent,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: _kCheckinMargin),
              decoration: BoxDecoration(
                color: tokens.card,
                borderRadius: BorderRadius.circular(_kCheckinCardRadius),
                boxShadow: tokens.cardShadow,
              ),
              child: Column(
                children: [
                  _row(tokens, '计划类型', _taskPlanLabel(item)),
                  _divider(tokens),
                  _row(
                    tokens,
                    '提醒时间',
                    item.isHabit
                        ? _timeLabel(item.triggerTime)
                        : _checkinDateTimeLabel(item.triggerTime),
                  ),
                  _divider(tokens),
                  _row(tokens, '完成于', _checkinDayLabel(date)),
                  if ((item.note ?? '').isNotEmpty) ...[
                    _divider(tokens),
                    _row(tokens, '备注', item.note!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            _CheckinPrimaryButton(
              label: '删除计划',
              busy: false,
              danger: true,
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
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

  Widget _divider(_CheckinTokens tokens) {
    return Container(height: 1, color: tokens.dayPill);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    // The row this came from is already ticked, so a stray tap here would be
    // deleting history rather than cancelling something pending.
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('删除这个计划？'),
        content: const Text('删除后打卡记录也会一起消失。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    Navigator.of(context).pop(_CheckinDeleteRequest(item));
  }
}

/// Asks the page to delete this plan — the page owns the API call so the list
/// can hide the row straight away.
class _CheckinDeleteRequest {
  const _CheckinDeleteRequest(this.item);

  final ReminderItem item;
}
