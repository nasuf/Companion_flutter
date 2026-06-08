part of 'package:companion_flutter/main.dart';

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.agentName,
    this.interactionDays,
    this.avatarUrl,
    required this.onAvatarDoubleTap,
    required this.onOpenSidebar,
  });

  final String agentName;
  final int? interactionDays;
  final String? avatarUrl;
  final VoidCallback onAvatarDoubleTap;
  final VoidCallback onOpenSidebar;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.page,
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: onAvatarDoubleTap,
            child: _Avatar(
              size: 44,
              label: '伴',
              imageUrl: avatarUrl,
              gradient: [Color(0xFFE8F3FF), Color(0xFFDDEBFF)],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agentName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _HeaderPill(
                      foreground: const Color(0xFFFF8A22),
                      background: const Color(0xFFFFF1E4),
                      icon: CupertinoIcons.flame_fill,
                      label: interactionDays == null
                          ? '互动中'
                          : '互动第$interactionDays天',
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '更多',
            onPressed: onOpenSidebar,
            icon: const Icon(CupertinoIcons.ellipsis, size: 24),
          ),
        ],
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({
    required this.label,
    required this.foreground,
    required this.background,
    this.icon,
  });

  final String label;
  final Color foreground;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      constraints: const BoxConstraints(minHeight: 21),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
          ] else ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                height: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
