part of 'package:companion_flutter/main.dart';

class GameActivityBurstRow extends StatefulWidget {
  const GameActivityBurstRow({super.key, required this.message});

  final ChatMessage message;

  @override
  State<GameActivityBurstRow> createState() => _GameActivityBurstRowState();
}

class _GameActivityBurstRowState extends State<GameActivityBurstRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final presentation = parseGameActivityBurst(widget.message);
    if (presentation == null || presentation.segments.isEmpty) {
      return const SizedBox.shrink();
    }
    final segments = presentation.segments;
    final metadata = widget.message.metadata ?? const {};
    final gameTitle =
        metadata['game_title']?.toString().trim().isNotEmpty == true
        ? metadata['game_title']!.toString().trim()
        : '游戏';
    final actorName =
        metadata['game_status_actor_name']?.toString().trim() ?? '';
    final collapsed = widget.message.content.trim().isNotEmpty
        ? widget.message.content.trim()
        : collapsedGameActivityLabel(
            gameTitle: gameTitle,
            actorName: actorName,
            segments: segments,
          );
    final isDark = AppColors.isDark(context);
    final accent = isDark ? AppColors.accent : const Color(0xFF177DDC);
    final fill = isDark
        ? AppColors.surfaceMuted.withValues(alpha: 0.76)
        : const Color(0xFFF1F5F9);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFD5DEE9);
    final textColor = isDark
        ? const Color(0xFF9AA8B8)
        : const Color(0xFF64748B);
    final maxBubbleWidth = math.min(
      320.0,
      MediaQuery.sizeOf(context).width - 72,
    );
    final canExpand = segments.length > 1;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxBubbleWidth),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: canExpand
                  ? () => setState(() => _expanded = !_expanded)
                  : null,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.game_controller,
                            size: 14,
                            color: accent.withValues(alpha: 0.72),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              collapsed,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                          ),
                          if (canExpand) ...[
                            const SizedBox(width: 4),
                            Icon(
                              _expanded
                                  ? CupertinoIcons.chevron_up
                                  : CupertinoIcons.chevron_down,
                              size: 12,
                              color: accent.withValues(alpha: 0.56),
                            ),
                          ],
                        ],
                      ),
                      if (_expanded && canExpand) ...[
                        const SizedBox(height: 8),
                        for (var i = 0; i < segments.length; i++)
                          _GameActivitySegmentLine(
                            segment: segments[i],
                            gameTitle: gameTitle,
                            actorName: actorName,
                            isLast: i == segments.length - 1,
                          ),
                      ],
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

class _GameActivitySegmentLine extends StatelessWidget {
  const _GameActivitySegmentLine({
    required this.segment,
    required this.gameTitle,
    required this.actorName,
    required this.isLast,
  });

  final GameActivitySegment segment;
  final String gameTitle;
  final String actorName;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final accent = segment.isExit
        ? (isDark ? const Color(0xFF9AA8B8) : const Color(0xFF64748B))
        : (isDark ? AppColors.accent : const Color(0xFF177DDC));
    final label = expandedGameActivitySegmentLabel(
      segment: segment,
      gameTitle: gameTitle,
      actorName: actorName,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 42,
            child: Text(
              formatGameActivityClock(segment.at),
              style: TextStyle(
                color: accent.withValues(alpha: 0.72),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: accent,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
