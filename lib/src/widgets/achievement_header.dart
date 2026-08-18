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
                onBack: () => Navigator.of(context).maybePop(),
                tint: color,
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _AchievementStatCard(
                      label: '已解锁成就',
                      value: '${items.length}',
                      glyph: _AchievementStatGlyph.unlocked,
                      tint: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AchievementStatCard(
                      label: '本周新增',
                      // Keep the plus so "delta" and "total" stay distinct.
                      value: weeklyNew > 0 ? '+$weeklyNew' : '0',
                      glyph: _AchievementStatGlyph.weekly,
                      tint: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AchievementStatCard(
                      label: '累计积分',
                      value: '$score',
                      glyph: _AchievementStatGlyph.score,
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
  const _AchievementTopBar({required this.onBack, required this.tint});

  final VoidCallback onBack;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    // Title centred on the whole bar (the same 24/w700 as the check-in "打卡"),
    // with the back button floating at the left.
    return SizedBox(
      height: 38,
      child: Stack(
        children: [
          Center(
            child: Text(
              '成就',
              style: TextStyle(
                color: isDark ? AppColors.text : const Color(0xFF151719),
                fontSize: 24,
                height: 1.2,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            // Exactly the weather page's back button (36 circle / 20 chevron /
            // same weight), tinted with the achievement level colour.
            child: _WeatherBackButton(onTap: onBack, iconColor: tint),
          ),
        ],
      ),
    );
  }
}

/// Weather-metric-card language, packed for a 3-up strip.
///
/// Weather lays a 48pt well beside the copy because each tile is ~168pt
/// wide. Three-up here is ~108pt, so the well sits under the label instead
/// of beside it. Fill, border, type, and the circular white glyph are the
/// same recipe.
class _AchievementStatCard extends StatelessWidget {
  const _AchievementStatCard({
    required this.label,
    required this.value,
    required this.glyph,
    required this.tint,
  });

  final String label;
  final String value;
  final _AchievementStatGlyph glyph;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Container(
      height: 94,
      padding: const EdgeInsets.fromLTRB(13, 15, 13, 13),
      decoration: BoxDecoration(
        color: _achievementGlassFill(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _achievementGlassBorder(context)),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: isDark ? 0.22 : 0.14),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // Exactly the store VIP benefit-card title font: 14 / w800 / 1.2.
            style: TextStyle(
              color: isDark ? AppColors.muted : Colors.black,
              fontSize: 14,
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              _AchievementStatIcon(glyph: glyph, tint: tint),
              const SizedBox(width: 8),
              Expanded(
                child: _AchievementStatValue(
                  value: value,
                  style: TextStyle(
                    color: isDark ? AppColors.text : Colors.black,
                    fontSize: 24,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    decoration: TextDecoration.none,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _AchievementStatGlyph { unlocked, weekly, score }

/// Shared value type for the 3-up strip. A 5-digit probe owns the FittedBox
/// width so "18", "0", and "14500" all render at the same size; score can
/// reach five digits without shrinking only that one card.
class _AchievementStatValue extends StatelessWidget {
  const _AchievementStatValue({required this.value, required this.style});

  static const _fiveDigitProbe = '00000';

  final String value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      alignment: Alignment.centerLeft,
      fit: BoxFit.scaleDown,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Visibility(
            visible: false,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: Text(_fiveDigitProbe, style: style),
          ),
          Text(value, maxLines: 1, style: style),
        ],
      ),
    );
  }
}

/// 24pt well + 12pt white glyph. Weather uses 48/24; this is the same 2:1
/// ratio, sized so five tabular digits still fit beside the well on a
/// 3-up tile. Well color is the contrast-safe pill tint so the white
/// glyph stays readable on every level.
class _AchievementStatIcon extends StatelessWidget {
  const _AchievementStatIcon({required this.glyph, required this.tint});

  static const _diameter = 34.0;
  static const _glyphSize = 18.0;

  final _AchievementStatGlyph glyph;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final well = _achievementTabPillColor(tint);
    return Container(
      width: _diameter,
      height: _diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: well,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: well.withValues(alpha: 0.30),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: SizedBox(
        width: _glyphSize,
        height: _glyphSize,
        child: CustomPaint(painter: _AchievementStatGlyphPainter(glyph)),
      ),
    );
  }
}

/// Line-and-fill glyphs in the weather metric style: thick rounded stroke
/// for the silhouette, solid faces for the focal nodes.
class _AchievementStatGlyphPainter extends CustomPainter {
  const _AchievementStatGlyphPainter(this.kind);

  final _AchievementStatGlyph kind;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    switch (kind) {
      case _AchievementStatGlyph.unlocked:
        _paintMedal(canvas, size, stroke, fill);
      case _AchievementStatGlyph.weekly:
        _paintSpark(canvas, size, stroke, fill);
      case _AchievementStatGlyph.score:
        _paintStar(canvas, size, stroke, fill);
    }
  }

  void _paintMedal(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final center = Offset(size.width * 0.50, size.height * 0.42);
    final radius = size.width * 0.28;
    canvas.drawCircle(center, radius, stroke);
    canvas.drawCircle(center, radius * 0.42, fill);
    final banner = RRect.fromLTRBR(
      size.width * 0.22,
      size.height * 0.68,
      size.width * 0.78,
      size.height * 0.90,
      Radius.circular(size.width * 0.08),
    );
    canvas.drawRRect(banner, fill);
  }

  void _paintSpark(Canvas canvas, Size size, Paint stroke, Paint fill) {
    canvas.drawPath(
      _starPath(
        Offset(size.width * 0.42, size.height * 0.52),
        size.width * 0.34,
        4,
        inner: 0.38,
      ),
      fill,
    );
    canvas.drawPath(
      _starPath(
        Offset(size.width * 0.78, size.height * 0.24),
        size.width * 0.16,
        4,
        inner: 0.38,
      ),
      stroke,
    );
  }

  void _paintStar(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final center = Offset(size.width * 0.50, size.height * 0.52);
    canvas.drawCircle(center, size.width * 0.38, stroke);
    canvas.drawPath(_starPath(center, size.width * 0.26, 5, inner: 0.42), fill);
  }

  Path _starPath(
    Offset center,
    double radius,
    int points, {
    double inner = 0.4,
  }) {
    final path = Path();
    final step = math.pi / points;
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : radius * inner;
      final angle = -math.pi / 2 + i * step;
      final point = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _AchievementStatGlyphPainter oldDelegate) {
    return oldDelegate.kind != kind;
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
