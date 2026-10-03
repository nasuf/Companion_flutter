part of 'package:companion_flutter/main.dart';

/// A quiet, non-interactive status in the conversation timeline.
class MusicActivityBurstRow extends StatelessWidget {
  const MusicActivityBurstRow({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final label = musicActivityTimelineLabel(message);
    if (label == null) return const SizedBox.shrink();
    final isDark = AppColors.isDark(context);
    final accent = isDark ? AppColors.accent : const Color(0xFF177DDC);
    final textColor = isDark
        ? const Color(0xFF8B95A1)
        : const Color(0xFF888888);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: math.min(320.0, MediaQuery.sizeOf(context).width - 72),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.music_note_2,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
