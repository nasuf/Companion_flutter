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
    final color = _achievementLevelColor(item);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        transitionBuilder: (child, animation) {
          final scale = Tween<double>(begin: 0.94, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: scale, child: child),
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
      color: color,
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -26,
            child: _AchievementCardWash(color: color),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AchievementCardIcon(item: item, color: color),
                    const Spacer(),
                    _AchievementScorePill(score: item.score, color: color),
                  ],
                ),
                const Spacer(),
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF151719),
                    fontSize: 20,
                    height: 1.13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.popupText.isEmpty ? item.conditionText : item.popupText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF747C82),
                    fontSize: 12,
                    height: 1.34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      _achievementCardTrail(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF9BA4A1),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 14,
                      color: const Color(0xFF9BA4A1).withValues(alpha: 0.78),
                    ),
                  ],
                ),
              ],
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
    final condition = item.conditionText.isEmpty
        ? item.ruleText
        : item.conditionText;
    return _AchievementShell(
      color: color,
      child: Stack(
        children: [
          Positioned(
            left: -34,
            bottom: -28,
            child: _AchievementCardWash(color: color, compact: true),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.levelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Center(
                    child: Text(
                      condition,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF5F6765),
                        fontSize: 15,
                        height: 1.42,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '+${item.score} 积分',
                      style: const TextStyle(
                        color: Color(0xFF9BA4A1),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      '点击返回',
                      style: TextStyle(
                        color: Color(0xFFB1B7B5),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementShell extends StatelessWidget {
  const _AchievementShell({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.13),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: const Color(0xFF20242A).withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _AchievementCardIcon extends StatelessWidget {
  const _AchievementCardIcon({required this.item, required this.color});

  final AchievementItem item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Image.asset(_achievementLevelAsset(item), fit: BoxFit.contain),
    );
  }
}

class _AchievementScorePill extends StatelessWidget {
  const _AchievementScorePill({required this.score, required this.color});

  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(
        '+$score',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _AchievementCardWash extends StatelessWidget {
  const _AchievementCardWash({required this.color, this.compact = false});

  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
      child: Container(
        width: compact ? 110 : 130,
        height: compact ? 110 : 130,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(42),
        ),
      ),
    );
  }
}

String _achievementCardTrail(AchievementItem item) {
  final unlockedAt = item.unlockedAt?.toLocal();
  if (unlockedAt == null) {
    return item.levelName.isEmpty ? '里程碑' : item.levelName;
  }
  final month = unlockedAt.month.toString().padLeft(2, '0');
  final day = unlockedAt.day.toString().padLeft(2, '0');
  return '$month/$day 点亮';
}
