part of 'package:companion_flutter/main.dart';

class _AchievementHeader extends StatefulWidget {
  const _AchievementHeader({required this.items, required this.score});

  final List<AchievementItem> items;
  final int score;

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AchievementTopBar(onBack: () => Navigator.of(context).maybePop()),
          const SizedBox(height: 28),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final breath = Curves.easeInOut.transform(_controller.value);
              return _AchievementHeroCard(
                breath: breath,
                unlocked: widget.items.length,
                weeklyNew: weeklyNew,
                score: widget.score,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AchievementTopBar extends StatelessWidget {
  const _AchievementTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _AchievementCircleButton(
          icon: CupertinoIcons.chevron_left,
          onTap: onBack,
        ),
        const SizedBox(width: 14),
        const Text(
          '成就',
          style: TextStyle(
            color: Color(0xFF151719),
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

class _AchievementCircleButton extends StatelessWidget {
  const _AchievementCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.86),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.92)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF20242A).withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Icon(icon, color: const Color(0xFF151719), size: 28),
      ),
    );
  }
}

class _AchievementHeroCard extends StatelessWidget {
  const _AchievementHeroCard({
    required this.breath,
    required this.unlocked,
    required this.weeklyNew,
    required this.score,
  });

  final double breath;
  final int unlocked;
  final int weeklyNew;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      constraints: const BoxConstraints(minHeight: 316),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.84)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.96),
            blurRadius: 1,
            offset: const Offset(0, -1),
          ),
          BoxShadow(
            color: const Color(0xFF20242A).withValues(alpha: 0.10),
            blurRadius: 42,
            offset: const Offset(0, 22),
          ),
          BoxShadow(
            color: const Color(0xFFFFC936).withValues(alpha: 0.15),
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
              painter: _AchievementHeroLightPainter(progress: breath),
            ),
          ),
          Positioned(
            right: -8 + breath * 6,
            bottom: 38 + breath * 8,
            child: Transform.rotate(
              angle: -0.17 + breath * 0.09,
              child: Transform.scale(
                scale: 0.96 + breath * 0.06,
                child: const _AchievementFloatingBlock(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ACHIEVEMENT',
                  style: TextStyle(
                    color: Color(0xFFC29A22),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 18),
                const Padding(
                  padding: EdgeInsets.only(right: 22),
                  child: Text(
                    '把关系里发生过的事，变成可回看的里程碑',
                    style: TextStyle(
                      color: Color(0xFF151719),
                      fontSize: 30,
                      height: 1.13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.only(right: 56),
                  child: Text(
                    '成就不是任务压力，而是你们长期陪伴慢慢留下的证据。',
                    style: TextStyle(
                      color: Color(0xFF6F7775),
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
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _AchievementMetric(
                          value: '$weeklyNew',
                          label: '本周新增',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _AchievementMetric(value: '$score', label: '积分'),
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
  const _AchievementFloatingBlock();

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
                    color: Color(0xFFE0A51D).withValues(alpha: 0.24),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFD658), Color(0xFFE0A51D)],
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
  const _AchievementHeroLightPainter({required this.progress});

  final double progress;

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
            Colors.white.withValues(alpha: 0.86),
            const Color(0xFFFFFBF0).withValues(alpha: 0.76),
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
      const Color(0xFFFFC936),
      0.26 + progress * 0.08,
      size.width * 0.74,
    );
    drawGlow(
      Alignment(-1.08 + progress * 0.05, 0.82 - progress * 0.04),
      const Color(0xFFCDB9FF),
      0.12,
      size.width * 0.62,
    );
  }

  @override
  bool shouldRepaint(_AchievementHeroLightPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _AchievementMetric extends StatelessWidget {
  const _AchievementMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.62),
            blurRadius: 1,
            offset: const Offset(0, -1),
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
            style: const TextStyle(
              color: Color(0xFF151719),
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
            style: const TextStyle(
              color: Color(0xFF9CA4A2),
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
