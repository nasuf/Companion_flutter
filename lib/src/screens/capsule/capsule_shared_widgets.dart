part of 'package:companion_flutter/main.dart';

class _CapsuleActionButton extends StatelessWidget {
  const _CapsuleActionButton({
    required this.label,
    required this.filled,
    required this.enabled,
    required this.loading,
    required this.loadingLabel,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final bool enabled;
  final bool loading;
  final String? loadingLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: enabled && !loading ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: !enabled && !loading ? 0.55 : 1,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            // 封存 stays the solid orange CTA; 存草稿 is a frosted-glass panel
            // matching the rest of the capsule glass chrome.
            color: filled ? _capsuleOrange : w.glass,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: filled ? _capsuleOrange : w.glassBorder),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: _capsuleOrange.withValues(alpha: 0.32),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [w.pillShadow],
          ),
          alignment: Alignment.center,
          child: loading
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.1,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          filled ? Colors.white : _capsuleOrange,
                        ),
                      ),
                    ),
                    if ((loadingLabel ?? '').isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        loadingLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: filled ? Colors.white : _capsuleOrange,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                )
              : Text(
                  label,
                  style: TextStyle(
                    color: filled ? Colors.white : w.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }
}

/// 36pt frosted-glass circle for the editor header close / delete — the same
/// diameter and recipe as the home / weather back button, so the whole app's
/// top-left control reads at one size.
class _CapsuleCircleButton extends StatelessWidget {
  const _CapsuleCircleButton({
    required this.icon,
    required this.onTap,
    this.danger = false,
    this.loading = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool danger;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: onTap == null && !loading ? 0.55 : 1,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: w.glass,
            shape: BoxShape.circle,
            border: Border.all(color: w.glassBorder),
            boxShadow: [w.pillShadow],
          ),
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(_capsuleDanger),
                  ),
                )
              : Icon(icon, color: danger ? _capsuleDanger : w.ink, size: 20),
        ),
      ),
    );
  }
}

class _CapsuleError extends StatelessWidget {
  const _CapsuleError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CupertinoButton(
        onPressed: onRetry,
        child: const Text('胶囊暂时没有回来，点一下重试'),
      ),
    );
  }
}

CapsuleChatDraft _draftForCapsule(TimeCapsule capsule) {
  final created = _formatCapsuleDate(capsule.createdAt);
  final open = capsule.openDate == null
      ? '约定的那一天'
      : _formatCapsuleDate(capsule.openDate!);
  final text = '我于$created埋下了时间胶囊，于$open开启，胶囊内容是：${capsule.content}';
  final card = ChatComponentCard(
    type: 'time_capsule',
    title: '时间胶囊',
    subtitle: '$open开启',
    body: capsule.content,
    footer: '时间胶囊 · 已开启',
    accent: '#7C3CFF',
    payload: {
      'capsule_id': capsule.id,
      'created_date': _dateOnly(capsule.createdAt),
      'open_date': capsule.openDate == null
          ? null
          : _dateOnly(capsule.openDate!),
      'content': capsule.content,
      'skin': capsule.skin,
    },
  );
  return CapsuleChatDraft(agentText: text, card: card);
}

String _effectiveCapsuleSkinId(
  BuildContext context,
  String? storedSkin, {
  required bool useThemeDefaultForPaper,
}) {
  final raw = storedSkin?.trim() ?? '';
  final defaultSkin = AppColors.isDark(context) ? 'night' : 'paper';
  if (raw.isEmpty) return defaultSkin;
  if (useThemeDefaultForPaper && raw == 'paper' && AppColors.isDark(context)) {
    return defaultSkin;
  }
  return raw;
}

Future<bool?> _confirmDeleteCapsule(BuildContext context) {
  return showCupertinoDialog<bool>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: const Text('删除这个胶囊？'),
      content: const Text('删除后，里面的文字、图片和语音都会被彻底删除，无法恢复。'),
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
}

Future<void> _waitForNavigatorUnlock({
  Duration delay = const Duration(milliseconds: 80),
}) async {
  await WidgetsBinding.instance.endOfFrame;
  if (delay > Duration.zero) {
    await Future<void>.delayed(delay);
  }
  await WidgetsBinding.instance.endOfFrame;
}

String _formatCapsuleDate(DateTime value) {
  return '${value.year}年${value.month}月${value.day}日';
}

String _formatCapsuleShortDate(DateTime value) {
  return '${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}';
}

/// Compact Chinese form for the draft rows ("7月12日 编辑"), where the year is
/// noise and the row only has a 10pt line to spend.
String _formatCapsuleMonthDay(DateTime value) {
  return '${value.month}月${value.day}日';
}

/// Dotted form used by the opened-capsule list design ("2025.07.12 创建").
String _formatCapsuleDotDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}.$month.$day';
}

String _dateOnly(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
