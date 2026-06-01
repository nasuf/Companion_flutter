part of 'package:companion_flutter/main.dart';

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({
    required this.item,
    required this.flipped,
    required this.onTap,
  });

  final AchievementItem item;
  final bool flipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _achievementColor(item.id);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        transitionBuilder: (child, animation) {
          final rotate = Tween<double>(begin: 0.88, end: 1).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: rotate, child: child),
          );
        },
        child: flipped
            ? _AchievementCardBack(
                key: ValueKey('b${item.id}'),
                item: item,
                color: color,
              )
            : _AchievementCardFront(
                key: ValueKey('f${item.id}'),
                item: item,
                color: color,
              ),
      ),
    );
  }
}

class _AchievementCardFront extends StatelessWidget {
  const _AchievementCardFront({
    super.key,
    required this.item,
    required this.color,
  });

  final AchievementItem item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _AchievementShell(
      item: item,
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AchievementIcon(
                color: color,
                label: item.name.isEmpty ? '?' : item.name.substring(0, 1),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  item.levelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              Icon(
                item.unlocked
                    ? CupertinoIcons.checkmark_seal_fill
                    : CupertinoIcons.lock_fill,
                size: 16,
                color: item.unlocked
                    ? color
                    : AppColors.muted.withValues(alpha: 0.58),
              ),
            ],
          ),
          const Spacer(),
          Text(
            item.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.conditionText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              height: 1.18,
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementCardBack extends StatelessWidget {
  const _AchievementCardBack({
    super.key,
    required this.item,
    required this.color,
  });

  final AchievementItem item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _AchievementShell(
      item: item,
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.category,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Text(
              item.conditionText,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 14,
                height: 1.28,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          Text(
            '${item.score} 分',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementShell extends StatelessWidget {
  const _AchievementShell({
    required this.item,
    required this.color,
    required this.child,
  });

  final AchievementItem item;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: item.unlocked ? 1 : 0.58,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: item.unlocked ? color.withValues(alpha: 0.28) : Colors.white,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: item.unlocked ? 0.16 : 0.06),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _AchievementIcon extends StatelessWidget {
  const _AchievementIcon({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

Color _achievementColor(int id) {
  const colors = [
    Color(0xFF0A84FF),
    Color(0xFFFF6A3D),
    Color(0xFF22C66B),
    Color(0xFF7C3CFF),
    Color(0xFFFFB22E),
    Color(0xFF18A0A8),
    Color(0xFF96556A),
  ];
  return colors[id % colors.length];
}
