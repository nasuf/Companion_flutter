part of 'package:companion_flutter/main.dart';

// ===========================================================================
// Charts (CustomPainter based, zero dependency)
// ===========================================================================

class _AdminAreaChart extends StatelessWidget {
  const _AdminAreaChart({required this.points, required this.color});

  static const double _height = 180;

  final List<_DailyPoint> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const _AdminInlineHint(text: '暂无数据', height: _height);
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: _height,
      child: Column(
        children: [
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _AreaLinePainter(
                values: points.map((p) => p.value).toList(),
                color: color,
                gridColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0x14181F2A),
              ),
            ),
          ),
          const SizedBox(height: 6),
          _ChartXLabels(
            labels: points.map((p) => _fmtMmDd(p.date)).toList(),
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _AreaLinePainter extends CustomPainter {
  _AreaLinePainter({
    required this.values,
    required this.color,
    required this.gridColor,
  });

  final List<double> values;
  final Color color;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxValue = values.reduce(math.max);
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final dx = values.length == 1 ? 0.0 : size.width / (values.length - 1);
    Offset pointAt(int i) {
      final x = values.length == 1 ? size.width / 2 : dx * i;
      final y = size.height - (values[i] / safeMax) * size.height * 0.92 - 2;
      return Offset(x, y);
    }

    final linePath = Path();
    for (var i = 0; i < values.length; i++) {
      final p = pointAt(i);
      if (i == 0) {
        linePath.moveTo(p.dx, p.dy);
      } else {
        linePath.lineTo(p.dx, p.dy);
      }
    }

    final fillPath = Path.from(linePath)
      ..lineTo(pointAt(values.length - 1).dx, size.height)
      ..lineTo(pointAt(0).dx, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.42),
            color.withValues(alpha: 0.04),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _AreaLinePainter old) =>
      old.values != values || old.color != color;
}

class _AdminBarChart extends StatelessWidget {
  const _AdminBarChart({
    required this.values,
    required this.labels,
    required this.color,
  });

  static const double _height = 180;

  final List<double> values;
  final List<String> labels;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const _AdminInlineHint(text: '暂无数据', height: _height);
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: _height,
      child: Column(
        children: [
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _BarsPainter(
                values: values,
                color: color,
                gridColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0x14181F2A),
              ),
            ),
          ),
          const SizedBox(height: 6),
          _ChartXLabels(labels: labels, isDark: isDark),
        ],
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.values,
    required this.color,
    required this.gridColor,
  });

  final List<double> values;
  final Color color;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxValue = values.reduce(math.max);
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final slot = size.width / values.length;
    final barWidth = math.min(slot * 0.62, 18.0);
    final paint = Paint()..color = color;
    for (var i = 0; i < values.length; i++) {
      final barHeight = (values[i] / safeMax) * size.height * 0.92;
      final left = slot * i + (slot - barWidth) / 2;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(left, size.height - barHeight, barWidth, barHeight),
        topLeft: const Radius.circular(3),
        topRight: const Radius.circular(3),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) =>
      old.values != values || old.color != color;
}

/// Bars (messages) + line overlay (active users), independent normalization.
class _AdminDualChart extends StatelessWidget {
  const _AdminDualChart({required this.points});

  static const double _height = 200;

  final List<_DailyActivePoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const _AdminInlineHint(text: '暂无数据', height: _height);
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: _height,
      child: Column(
        children: [
          _ChartLegend(
            items: [
              _ChartLegendItem(color: _chartColors[2], label: '聊天句子'),
              _ChartLegendItem(color: _chartColors[0], label: '活跃用户'),
            ],
            isDark: isDark,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _DualPainter(
                bars: points.map((p) => p.userMessages.toDouble()).toList(),
                line: points.map((p) => p.activeUsers.toDouble()).toList(),
                barColor: _chartColors[2],
                lineColor: _chartColors[0],
                gridColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0x14181F2A),
              ),
            ),
          ),
          const SizedBox(height: 6),
          _ChartXLabels(
            labels: points.map((p) => _fmtMmDd(p.date)).toList(),
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _DualPainter extends CustomPainter {
  _DualPainter({
    required this.bars,
    required this.line,
    required this.barColor,
    required this.lineColor,
    required this.gridColor,
  });

  final List<double> bars;
  final List<double> line;
  final Color barColor;
  final Color lineColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final barMax = bars.reduce(math.max);
    final lineMax = line.isEmpty ? 1.0 : line.reduce(math.max);
    final safeBarMax = barMax <= 0 ? 1.0 : barMax;
    final safeLineMax = lineMax <= 0 ? 1.0 : lineMax;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final slot = size.width / bars.length;
    final barWidth = math.min(slot * 0.5, 16.0);
    final barPaint = Paint()..color = barColor.withValues(alpha: 0.55);
    for (var i = 0; i < bars.length; i++) {
      final barHeight = (bars[i] / safeBarMax) * size.height * 0.9;
      final left = slot * i + (slot - barWidth) / 2;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(left, size.height - barHeight, barWidth, barHeight),
        topLeft: const Radius.circular(3),
        topRight: const Radius.circular(3),
      );
      canvas.drawRRect(rect, barPaint);
    }

    final linePath = Path();
    for (var i = 0; i < line.length; i++) {
      final x = slot * i + slot / 2;
      final y = size.height - (line[i] / safeLineMax) * size.height * 0.9;
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _DualPainter old) =>
      old.bars != bars || old.line != line;
}

class _ChartXLabels extends StatelessWidget {
  const _ChartXLabels({required this.labels, required this.isDark});

  final List<String> labels;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    // Show at most first / middle / last to avoid clutter on mobile.
    final indices = <int>{0, labels.length ~/ 2, labels.length - 1}.toList()
      ..sort();
    final style = TextStyle(
      color: isDark
          ? Colors.white.withValues(alpha: 0.4)
          : const Color(0x8012171B),
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      decoration: TextDecoration.none,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final index in indices) Text(labels[index], style: style),
      ],
    );
  }
}

class _ChartLegendItem {
  const _ChartLegendItem({required this.color, required this.label});

  final Color color;
  final String label;
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.items, required this.isDark});

  final List<_ChartLegendItem> items;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: item.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  item.label,
                  style: TextStyle(
                    color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Horizontal progress-bar list (buckets / cost / model share) — mobile friendly.
class _AdminHBarRow extends StatelessWidget {
  const _AdminHBarRow({
    required this.label,
    required this.fraction,
    required this.color,
    required this.trailing,
    this.leadingRank,
    this.subtitle,
  });

  final String label;
  final double fraction;
  final Color color;
  final String trailing;
  final int? leadingRank;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final clamped = fraction.isFinite ? fraction.clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leadingRank != null) ...[
            SizedBox(
              width: 18,
              child: Text(
                '$leadingRank',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.42)
                      : const Color(0x8012171B),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? AppColors.text : const Color(0xFF12171B),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 5,
                    child: Stack(
                      children: [
                        Container(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0x14181F2A),
                        ),
                        FractionallySizedBox(
                          widthFactor: clamped == 0 ? 0.02 : clamped,
                          child: Container(color: color),
                        ),
                      ],
                    ),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.4)
                          : const Color(0x8012171B),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            trailing,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminDonut extends StatelessWidget {
  const _AdminDonut({required this.byModel});

  final List<_ModelCost> byModel;

  static const Map<String, Color> _modelColors = {
    'qwen3.5-flash': Color(0xFFFF8C6B),
    'qwen3.5-plus': Color(0xFFA8C4F5),
  };

  Color _colorFor(String model, int index) {
    return _modelColors[model] ?? _chartColors[index % _chartColors.length];
  }

  @override
  Widget build(BuildContext context) {
    if (byModel.isEmpty) {
      return const _AdminInlineHint(text: '暂无数据', height: 150);
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = byModel.fold<double>(0, (sum, m) => sum + m.costCny);
    final segments = <_DonutSegment>[
      for (var i = 0; i < byModel.length; i++)
        _DonutSegment(
          value: byModel[i].costCny,
          color: _colorFor(byModel[i].model, i),
        ),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 110,
          height: 110,
          child: CustomPaint(
            painter: _DonutPainter(
              segments: segments,
              trackColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0x14181F2A),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < byModel.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: _colorFor(byModel[i].model, i),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          byModel[i].model,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark
                                ? AppColors.text
                                : const Color(0xFF12171B),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        total > 0
                            ? '${(byModel[i].costCny / total * 100).toStringAsFixed(1)}%'
                            : '0%',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.42)
                              : const Color(0x8012171B),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutSegment {
  const _DonutSegment({required this.value, required this.color});

  final double value;
  final Color color;
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.segments, required this.trackColor});

  final List<_DonutSegment> segments;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = math.min(size.width, size.height) / 2;
    const stroke = 20.0;
    final arcRect = Rect.fromCircle(
      center: center,
      radius: radius - stroke / 2,
    );

    canvas.drawArc(
      arcRect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = trackColor
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke,
    );

    final total = segments.fold<double>(0, (sum, s) => sum + s.value);
    if (total <= 0) return;
    var start = -math.pi / 2;
    for (final segment in segments) {
      final sweep = segment.value / total * 2 * math.pi;
      canvas.drawArc(
        arcRect,
        start,
        sweep - 0.02,
        false,
        Paint()
          ..color = segment.color
          ..strokeWidth = stroke
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.segments != segments;
}
