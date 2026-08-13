part of 'package:companion_flutter/main.dart';

class _AchievementHeader extends StatelessWidget {
  const _AchievementHeader({
    required this.items,
    required this.score,
    required this.tint,
  });

  final List<AchievementItem> items;
  final int score;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final weeklyNew = _achievementWeeklyNewCount(items);
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: tint),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        final color = value ?? tint;
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AchievementTopBar(
                tint: color,
                onBack: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _AchievementStatCard(
                      label: '已解锁成就',
                      value: '${items.length}',
                      icon: CupertinoIcons.rosette,
                      tint: color,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AchievementStatCard(
                      label: '本周新增',
                      // 正号保留，用来区分「增量」和「总量」；字色跟其余两张一致。
                      value: weeklyNew > 0 ? '+$weeklyNew' : '0',
                      icon: CupertinoIcons.sparkles,
                      tint: color,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AchievementStatCard(
                      label: '累计积分',
                      value: '$score',
                      icon: CupertinoIcons.star_fill,
                      tint: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AchievementTopBar extends StatelessWidget {
  const _AchievementTopBar({required this.tint, required this.onBack});

  final Color tint;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Row(
      children: [
        _AppNavCircleButton(
          icon: CupertinoIcons.chevron_left,
          onPressed: onBack,
        ),
        const SizedBox(width: 14),
        Text(
          '成就',
          style: TextStyle(
            color: isDark ? AppColors.text : const Color(0xFF151719),
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}

/// 顶部三联指标卡：左上角标签 + 右上角图标底座，数字居中压在下半部。
class _AchievementStatCard extends StatelessWidget {
  const _AchievementStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Container(
      height: 88,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface(context, light: 0.93),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.glassBorder(context)),
        boxShadow: [
          // 浅色下顶边压一条白线，卡片才有「一片玻璃」的受光边缘而不是贴纸。
          if (!isDark)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.96),
              blurRadius: 1,
              offset: const Offset(0, -1),
            ),
          BoxShadow(
            color: tint.withValues(alpha: isDark ? 0.16 : 0.10),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: isDark ? 0.50 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? AppColors.muted : const Color(0xFF8B9491),
                    fontSize: 11,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // 跟下方成就卡的图标底座同构（圆角方块 + 层级色淡底），是同一套语言。
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: isDark ? 0.22 : 0.14),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 11.5, color: tint),
              ),
            ],
          ),
          const Spacer(),
          // 撑满整宽再居中，三张卡的数字才在同一条基线上左右对齐；
          // 窄屏下积分可能到 5 位数，等宽数字 + scaleDown 兜住溢出。
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  color: isDark ? AppColors.text : const Color(0xFF151719),
                  fontSize: 26,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                  decoration: TextDecoration.none,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

int _achievementWeeklyNewCount(List<AchievementItem> items) {
  final now = DateTime.now();
  final start = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: now.weekday - DateTime.monday));
  return items.where((item) {
    final unlockedAt = item.unlockedAt?.toLocal();
    return unlockedAt != null && !unlockedAt.isBefore(start);
  }).length;
}
