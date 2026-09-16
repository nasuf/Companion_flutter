part of 'package:companion_flutter/main.dart';

const double _kGameActivityDigestBlur = 16;

class GameActivityBurstRow extends StatelessWidget {
  const GameActivityBurstRow({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final presentation = parseGameActivityBurst(message);
    if (presentation == null || presentation.segments.isEmpty) {
      return const SizedBox.shrink();
    }
    final summaries = summarizeGameActivity(presentation.segments);
    final label = collapsedGameActivityLabel(summaries);
    final canOpen = canOpenGameActivityDigest(summaries);
    final isDark = AppColors.isDark(context);
    final accent = isDark ? AppColors.accent : const Color(0xFF177DDC);
    final textColor = isDark
        ? const Color(0xFF8B95A1)
        : const Color(0xFF888888);
    final maxBubbleWidth = math.min(
      320.0,
      MediaQuery.sizeOf(context).width - 72,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxBubbleWidth),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: canOpen
                  ? () => showGameActivityDigestDialog(
                      context,
                      summaries: summaries,
                    )
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.game_controller,
                      size: 13,
                      color: accent.withValues(alpha: 0.62),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                        ),
                      ),
                    ),
                    if (canOpen) ...[
                      const SizedBox(width: 4),
                      Icon(
                        CupertinoIcons.chevron_right,
                        size: 11,
                        color: textColor.withValues(alpha: 0.72),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showGameActivityDigestDialog(
  BuildContext context, {
  required List<GameActivitySummary> summaries,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (dialogContext, _, __) {
      return _GameActivityDigestDialog(
        summaries: summaries,
        onClose: () => Navigator.of(dialogContext).pop(),
      );
    },
    transitionBuilder: (_, animation, __, child) {
      final curve = animation.status == AnimationStatus.reverse
          ? Curves.easeInCubic
          : Curves.easeOutCubic;
      final t = curve.transform(animation.value.clamp(0.0, 1.0));
      final backdrop = t <= 0.001
          ? const SizedBox.shrink()
          : BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: _kGameActivityDigestBlur * t,
                sigmaY: _kGameActivityDigestBlur * t,
              ),
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.22 * t),
                child: const SizedBox.expand(),
              ),
            );
      return Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(child: backdrop),
          Opacity(
            opacity: t,
            child: Transform.scale(scale: 0.96 + 0.04 * t, child: child),
          ),
        ],
      );
    },
  );
}

class _GameActivityDigestDialog extends StatelessWidget {
  const _GameActivityDigestDialog({
    required this.summaries,
    required this.onClose,
  });

  final List<GameActivitySummary> summaries;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final title = gameActivityDigestHeading(summaries);
    final range = formatGameActivityTimeRange(summaries);
    final cardColor = isDark
        ? const Color(0xE61C232C)
        : const Color(0xF2FFFFFF);
    final titleColor = isDark ? Colors.white : const Color(0xFF1F2A37);
    final muted = isDark ? const Color(0xFF9AA8B8) : const Color(0xFF64748B);
    final divider = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE8EEF4);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.62;

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onClose,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: math.min(340, MediaQuery.sizeOf(context).width - 48),
                maxHeight: maxHeight,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : const Color(0xFFE4EBF2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    color: titleColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                if (range.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    range,
                                    style: TextStyle(
                                      color: muted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: onClose,
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              CupertinoIcons.xmark,
                              size: 16,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: math.max(120, maxHeight - 88),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.only(top: 4, bottom: 4),
                          itemCount: summaries.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: divider),
                          itemBuilder: (context, index) {
                            final item = summaries[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.game_controller,
                                    size: 16,
                                    color: muted,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      item.gameTitle,
                                      style: TextStyle(
                                        color: titleColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    item.visitCount > 1
                                        ? '${formatGameActivityClock(item.firstAt)} · ${item.visitCount} 次'
                                        : formatGameActivityClock(item.firstAt),
                                    style: TextStyle(
                                      color: muted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
