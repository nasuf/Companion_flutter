part of 'package:companion_flutter/main.dart';

class _AchievementHeader extends StatefulWidget {
  const _AchievementHeader({
    required this.items,
    required this.score,
    required this.tint,
  });

  final List<AchievementItem> items;
  final int score;
  final Color tint;

  @override
  State<_AchievementHeader> createState() => _AchievementHeaderState();
}

class _AchievementHeaderState extends State<_AchievementHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weeklyNew = _achievementWeeklyNewCount(widget.items);
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: widget.tint),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        final tint = value ?? widget.tint;
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AchievementTopBar(
                tint: tint,
                onBack: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(height: 28),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final breath = Curves.easeInOut.transform(_controller.value);
                  return _AchievementHeroCard(
                    breath: breath,
                    tint: tint,
                    unlocked: widget.items.length,
                    weeklyNew: weeklyNew,
                    score: widget.score,
                  );
                },
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

class _AchievementHeroCard extends StatelessWidget {
  const _AchievementHeroCard({
    required this.breath,
    required this.tint,
    required this.unlocked,
    required this.weeklyNew,
    required this.score,
  });

  final double breath;
  final Color tint;
  final int unlocked;
  final int weeklyNew;
  final int score;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      constraints: const BoxConstraints(minHeight: 316),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface(context, light: 0.93),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.glassBorder(context)),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.96),
              blurRadius: 1,
              offset: const Offset(0, -1),
            ),
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: isDark ? 0.72 : 0.10),
            blurRadius: 42,
            offset: const Offset(0, 22),
          ),
          BoxShadow(
            color: tint.withValues(alpha: 0.16),
            blurRadius: 32,
            offset: const Offset(16, 24),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _AchievementHeroLightPainter(
                progress: breath,
                tint: tint,
                isDark: isDark,
              ),
            ),
          ),
          Positioned(
            right: -8 + breath * 6,
            bottom: 38 + breath * 8,
            child: Transform.rotate(
              angle: -0.17 + breath * 0.09,
              child: Transform.scale(
                scale: 0.96 + breath * 0.06,
                child: _AchievementFloatingBlock(tint: tint),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACHIEVEMENT',
                  style: TextStyle(
                    color: tint,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.only(right: 22),
                  child: Text(
                    '把关系里发生过的事，变成可回看的里程碑',
                    style: TextStyle(
                      color: isDark ? AppColors.text : const Color(0xFF151719),
                      fontSize: 30,
                      height: 1.13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(right: 56),
                  child: Text(
                    '成就不是任务压力，而是你们长期陪伴慢慢留下的证据。',
                    style: TextStyle(
                      color: isDark ? AppColors.muted : const Color(0xFF6F7775),
                      fontSize: 14,
                      height: 1.58,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: 272,
                  child: Row(
                    children: [
                      Expanded(
                        child: _AchievementMetric(
                          value: '$unlocked',
                          label: '已解锁',
                          tint: tint,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _AchievementMetric(
                          value: '$weeklyNew',
                          label: '本周新增',
                          tint: tint,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _AchievementMetric(
                          value: '$score',
                          label: '积分',
                          tint: tint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementFloatingBlock extends StatelessWidget {
  const _AchievementFloatingBlock({required this.tint});

  final Color tint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 116,
      height: 116,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: tint.withValues(alpha: 0.24),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(tint, Colors.white, 0.34)!,
                        Color.lerp(tint, Colors.black, 0.08)!,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            top: 16,
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.48)),
              ),
            ),
          ),
          Positioned(
            right: -8,
            bottom: 10,
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.58),
                  width: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementHeroLightPainter extends CustomPainter {
  const _AchievementHeroLightPainter({
    required this.progress,
    required this.tint,
    required this.isDark,
  });

  final double progress;
  final Color tint;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            if (isDark) ...[
              AppColors.surface.withValues(alpha: 0.84),
              Color.lerp(
                AppColors.surfaceMuted,
                tint,
                0.10,
              )!.withValues(alpha: 0.78),
            ] else ...[
              Colors.white.withValues(alpha: 0.86),
              Color.lerp(Colors.white, tint, 0.08)!.withValues(alpha: 0.76),
            ],
          ],
        ).createShader(rect),
    );

    void drawGlow(Alignment center, Color color, double alpha, double radius) {
      final offset = Offset(
        (center.x + 1) * size.width / 2,
        (center.y + 1) * size.height / 2,
      );
      final glowRect = Rect.fromCenter(
        center: offset,
        width: radius,
        height: radius * 0.84,
      );
      canvas.drawOval(
        glowRect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: alpha * 0.26),
              color.withValues(alpha: 0),
            ],
            stops: const [0, 0.66, 1],
          ).createShader(glowRect),
      );
    }

    drawGlow(
      Alignment(0.72 + progress * 0.05, -0.72 + progress * 0.04),
      tint,
      0.26 + progress * 0.08,
      size.width * 0.74,
    );
    drawGlow(
      Alignment(-1.08 + progress * 0.05, 0.82 - progress * 0.04),
      Color.lerp(tint, isDark ? AppColors.surfaceMuted : Colors.white, 0.36)!,
      isDark ? 0.18 : 0.12,
      size.width * 0.62,
    );
  }

  @override
  bool shouldRepaint(_AchievementHeroLightPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.tint != tint ||
        oldDelegate.isDark != isDark;
  }
}

class _AchievementMetric extends StatelessWidget {
  const _AchievementMetric({
    required this.value,
    required this.label,
    required this.tint,
  });

  final String value;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Container(
      height: 64,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 7),
      decoration: BoxDecoration(
        color: AppColors.subtleFill(context, light: 0.58),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : tint.withValues(alpha: 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: isDark ? 0.14 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? AppColors.text : const Color(0xFF151719),
              fontSize: 18,
              height: 1.0,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? AppColors.muted : const Color(0xFF9CA4A2),
              fontSize: 10.5,
              height: 1.05,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
              decoration: TextDecoration.none,
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
