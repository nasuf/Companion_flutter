part of 'package:companion_flutter/main.dart';

// Design tokens for the 遗言 (last will) screens. Every offset in the last_will
// files is expressed against the 390x844 reference canvas of the design export.

const _legacyGutter = 16.0;
const _legacyCardRadius = Radius.circular(20);
const _legacyMaxContacts = 3;

/// Headline of the 遗言 card once something is saved. Deliberately a fixed line
/// rather than the note's opening sentence — the note itself is right below it,
/// and echoing its first line there read as a duplicate.
const _legacyWillHeadline = '既要生得光荣，也要死得伟大';
const _legacyWillEmptyHeadline = '留下你的一段遗言';
const _legacyDayPresets = <int>[7, 10, 30, 60];
const _legacyMinDays = 1;
const _legacyMaxDays = 90;

// 失联倒计时 ruler geometry. Marker band (20) + gap (4) + tick slot (12) +
// label slot (16).
const _legacyRulerPitch = 32.0;
const _legacyRulerMarkerSize = 20.0;

/// Breathing room between the marker circle and the tick line under it — they
/// used to sit flush against each other.
const _legacyRulerMarkerGap = 4.0;
const _legacyRulerHeight = 52.0;

/// How many ticks either side of the marker still get highlighted. The
/// exponent keeps the peak narrow so the selected day clearly reads as the
/// darkest one.
const _legacyRulerEmphasisSpan = 2.6;

double _legacyRulerEmphasis(double ticksFromCentre) {
  final falloff = (1 - ticksFromCentre.abs() / _legacyRulerEmphasisSpan).clamp(
    0.0,
    1.0,
  );
  return math.pow(falloff, 1.7).toDouble();
}

// 玻璃扁平重构（对齐天气/胶囊/商城/打卡）：不再有任何深色/黑色组件——卡片、
// bottom sheet、弹框、三级页面全部直接复用 _W2b（天气页定义、同库私有可见）
// 的中性浅色玻璃 token，跟天气/胶囊/商城像素级一致，而不是自成一套深色系统。

/// 明亮的中性页面底——比旧版 #999999 灰底亮得多，但仍是石墨/银灰家族，不落到
/// 任何其它页面的彩色（天气蓝/胶囊橙/打卡蓝）上，保持遗言页克制、庄重的气质。
const _legacyPageBase = Color(0xFFF3F4F6);

/// 三团呼吸光斑用的柔灰色（大圆形色块允许保留灰调，与其它页面的「光斑」手法
/// 一致，只是配色换成银灰而非彩色）。
const _legacyBlobSteel = Color(0xFFC7CCD6);
const _legacyBlobDove = Color(0xFFD9D5DA);
const _legacyBlobSlate = Color(0xFFB7BCC4);

/// 唯一保留的非中性色——仅用于删除/危险操作，跟胶囊页同值，属状态色而非
/// 「组件底色」，不违反「不要黑色组件」的要求。
const _legacyDanger = Color(0xFFE05555);

/// 中性灰阶，用于放在浅玻璃卡上仍需要比 `w.glass` 更明显区分的小面（预设天数
/// 胶囊未选中态、联系人表单内嵌面板）。都不透明度很低，读出来是「浅灰」而不是
/// 「黑」。
const _legacyChipFillIdle = Color(0x0A1B1C1F); // 黑 @ 4%
const _legacyChipBorderIdle = Color(0x1A1B1C1F); // 黑 @ 10%

BorderRadius get _legacyCardBorderRadius =>
    const BorderRadius.all(_legacyCardRadius);

/// 明亮呼吸背景：亮底 + 3 团银灰柔光 + 细噪点，复用天气/胶囊同款
/// _WeatherGlowBlob/_WeatherGrain（同库私有，可见）——已验证的低开销方案，
/// 不会重蹈 _GlowBorderPainter 的性能问题。
class _LegacyBackground extends StatefulWidget {
  const _LegacyBackground();

  @override
  State<_LegacyBackground> createState() => _LegacyBackgroundState();
}

class _LegacyBackgroundState extends State<_LegacyBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => _LegacyBackgroundPaint(
        progress: Curves.easeInOut.transform(_controller.value),
      ),
    );
  }
}

class _LegacyBackgroundPaint extends StatelessWidget {
  const _LegacyBackgroundPaint({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final drift = progress * 8;
    return DecoratedBox(
      decoration: const BoxDecoration(color: _legacyPageBase),
      child: Stack(
        children: [
          Positioned(
            left: -90,
            top: -70 + drift,
            child: const _WeatherGlowBlob(
              width: 258,
              height: 228,
              color: _legacyBlobSteel,
              opacity: 0.85,
            ),
          ),
          Positioned(
            right: -92,
            top: 88 - drift,
            child: const _WeatherGlowBlob(
              width: 228,
              height: 204,
              color: _legacyBlobDove,
              opacity: 0.78,
            ),
          ),
          Positioned(
            left: -72,
            bottom: -82 + drift,
            child: const _WeatherGlowBlob(
              width: 248,
              height: 214,
              color: _legacyBlobSlate,
              opacity: 0.6,
            ),
          ),
          const Positioned.fill(
            child: _WeatherGrain(dotColor: Color(0x59FFFFFF), opacity: 0.5),
          ),
        ],
      ),
    );
  }
}

/// 每个界面都用到的浅色玻璃卡：与天气/胶囊完全同款的 `w.glass` 半透明面 +
/// `w.glassBorder` 描边 + `w.panelShadow` 柔化投影——不再有专属的深色系统。
class _LegacyCard extends StatelessWidget {
  const _LegacyCard({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.of(context);
    // DecoratedBox rather than Container.decoration: Container auto-insets its
    // child by the border's width (via BoxDecoration.padding), which would
    // shift every card's content by an extra 1px now that a border exists —
    // DecoratedBox paints the border without touching layout.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: w.glass,
        borderRadius: _legacyCardBorderRadius,
        border: Border.all(color: w.glassBorder),
        boxShadow: w.panelShadow,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Header band for the back-navigating screens (home + contacts manage — the
/// editor builds its own header to match capsule's exactly instead, see
/// _LastWillEditorPageState.build). Back button on the left (the exact
/// weather-page glass circle, inset by the page's own gutter so it lines up
/// with the cards below it — matching how every other page insets its back
/// button rather than sitting flush against the screen edge), optional title
/// centred on the SAME row.
class _LegacyHeader extends StatelessWidget {
  const _LegacyHeader({required this.onBack, this.title});

  final VoidCallback onBack;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.of(context);
    final title = this.title;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _legacyGutter),
      child: SizedBox(
        height: 36,
        child: Stack(
          children: [
            if (title != null)
              Center(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: w.ink,
                    fontSize: 24,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              // 与天气页返回键完全一致的玻璃圆 + 箭头尺寸/粗细。
              child: _WeatherBackButton(onTap: onBack, iconColor: w.ink),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small "管理 ›" / "编辑 ›" affordance sitting in a card's top-right corner.
class _LegacyCardAction extends StatelessWidget {
  const _LegacyCardAction({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.of(context);
    final text = Text(
      label,
      style: TextStyle(
        color: w.inkSoft,
        fontSize: 12,
        height: 14 / 12,
        fontWeight: FontWeight.w400,
        decoration: TextDecoration.none,
      ),
    );
    if (onTap == null) return text;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          text,
          const SizedBox(width: 5),
          Icon(CupertinoIcons.chevron_right, size: 12, color: w.inkSoft),
        ],
      ),
    );
  }
}

/// 20-radius pill button. Neither state uses a dark fill any more — `primary`
/// is the same light glass as `secondary` but with a bolder ink border and
/// bold text, so the CTA still reads as the emphasized action through weight
/// alone (this module has no chromatic accent to lean on for that instead).
class _LegacyPillButton extends StatelessWidget {
  const _LegacyPillButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.of(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: w.glass,
          borderRadius: _legacyCardBorderRadius,
          border: Border.all(
            color: primary ? w.ink : w.glassBorder,
            width: primary ? 1.4 : 1,
          ),
          boxShadow: w.panelShadow,
        ),
        child: SizedBox(
          height: 56,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: w.ink,
                fontSize: 20,
                height: 1.2,
                fontWeight: primary ? FontWeight.w800 : FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 68x28 preset pill (7天 / 10天 / 30天 / 60天). Idle uses a faint dark wash
/// (visible against the light glass card without introducing a dark fill);
/// selected uses the same bordered-emphasis language as the primary button.
class _LegacyChip extends StatelessWidget {
  const _LegacyChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.of(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? w.glass : _legacyChipFillIdle,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? w.ink : _legacyChipBorderIdle,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: SizedBox(
          width: 68,
          height: 28,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? w.ink : w.inkSoft,
                fontSize: 13,
                height: 16 / 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 48px contact bubble. Filled slots get a solid hairline plus the person
/// glyph; empty slots get the dashed hairline over a plus. Both states carry
/// their own solid light backing now (rather than relying on the dark card
/// behind them for contrast, per the old design) — the glyph/ring stay legible
/// regardless of what card colour surrounds them.
class _LegacyContactAvatar extends StatelessWidget {
  const _LegacyContactAvatar({required this.filled});

  static const _backing = Color(0xFFE4E7EB);
  static const _ring = Color(0xFFAEB4BB);
  static const _glyph = Color(0xFF7B8087);

  final bool filled;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.of(context);
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, color: _backing),
          ),
          if (filled)
            const ClipOval(child: CustomPaint(painter: _LegacyPersonPainter()))
          else
            Center(
              child: Text(
                '+',
                style: TextStyle(
                  color: w.ink,
                  fontSize: 20,
                  height: 24 / 20,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          if (filled)
            const DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: _ring, width: 1.5),
                ),
              ),
            )
          else
            const CustomPaint(painter: _LegacyDashedCirclePainter()),
        ],
      ),
    );
  }
}

class _LegacyPersonPainter extends CustomPainter {
  const _LegacyPersonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 48;
    final paint = Paint()..color = _LegacyContactAvatar._glyph;
    canvas.drawCircle(Offset(23.5 * scale, 18.5 * scale), 6.5 * scale, paint);
    canvas.drawOval(
      Rect.fromLTWH(11.65 * scale, 27.07 * scale, 24.71 * scale, 24 * scale),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// border: 1.5px dashed #FFFFFF
class _LegacyDashedCirclePainter extends CustomPainter {
  const _LegacyDashedCirclePainter();

  static const _strokeWidth = 1.5;
  static const _dash = 5.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = (size.shortestSide - _strokeWidth) / 2;
    final circumference = 2 * math.pi * radius;
    const step = _dash + _gap;
    final count = math.max(4, (circumference / step).round());
    final sweep = 2 * math.pi / count;
    final dashSweep = sweep * (_dash / step);
    final paint = Paint()
      ..color = _LegacyContactAvatar._ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;
    final bounds = Rect.fromCircle(center: rect.center, radius: radius);
    for (var i = 0; i < count; i += 1) {
      canvas.drawArc(bounds, i * sweep, dashSweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LegacyDashedCirclePainter oldDelegate) => false;
}

/// Travelling halo around a card border — the "已计时" signal on the home
/// screen.
///
/// The previous revision drew this with 72 tail segments × 2 strokes each
/// (144 `drawPath` calls a frame, ~73 of them carrying a Gaussian
/// `MaskFilter.blur`), recomputed every frame at up to 60/120fps for as long
/// as the countdown was running — that per-frame blur-heavy rasterization was
/// the jank the user was seeing. Same visual language (soft blurred tail +
/// bright travelling head), but the tail is now 8 segments, each with its own
/// blurred-glow + crisp-core pair whose WIDTH and BLUR (not just alpha) taper
/// segment to segment — that's what makes it read as one continuously
/// narrowing tail rather than a flat-width line that merely fades. ~18 draw
/// calls a frame, ~9 with blur — still roughly an 8x cut from the original.
class _GlowBorderPainter extends CustomPainter {
  const _GlowBorderPainter({required this.progress, required this.color});

  final double progress;

  /// The travelling highlight's colour — plain white. The card already has a
  /// white glass border; this is meant to read as a brighter, moving segment
  /// of that same border rather than an unrelated accent colour.
  final Color color;

  static const _segmentCount = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect.deflate(0.8), _legacyCardRadius);
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().iterator;
    if (!metrics.moveNext()) return;
    final metric = metrics.current;
    final length = metric.length;
    final head = (length * progress) % length;
    // Short and tightly tapered — a longer/gentler tail read as a smear
    // rather than a travelling spark.
    final tailLength = length * 0.07;

    Path tailSegment(double start, double end) {
      final normalizedStart = (start + length) % length;
      final normalizedEnd = (end + length) % length;
      final segment = Path();
      if (normalizedStart <= normalizedEnd) {
        segment.addPath(
          metric.extractPath(normalizedStart, normalizedEnd),
          Offset.zero,
        );
      } else {
        segment
          ..addPath(metric.extractPath(normalizedStart, length), Offset.zero)
          ..addPath(metric.extractPath(0, normalizedEnd), Offset.zero);
      }
      return segment;
    }

    for (var i = _segmentCount - 1; i >= 0; i--) {
      final from = head - tailLength * ((i + 1.15) / _segmentCount);
      final to = head - tailLength * (i / _segmentCount);
      // 1 right at the head, easing to 0 by the tail's far end — every visual
      // property below rides on this one curve, which is what keeps the taper
      // reading as one continuous line instead of stacked flat segments.
      final strength = math.pow(1 - i / _segmentCount, 2.3).toDouble();
      final segment = tailSegment(from, to);
      // Soft outer glow: wide and heavily blurred near the head, narrowing
      // and going almost fully diffuse (blur > width) by the tail's end, the
      // way a real light trail dissolves rather than just dims.
      canvas.drawPath(
        segment,
        Paint()
          ..color = color.withValues(alpha: 0.06 + strength * 0.46)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8 + strength * 5.6
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            3 + (1 - strength) * 6,
          ),
      );
      // Crisp inner core, narrower than the glow and unblurred, so the head
      // end of the tail still has a defined bright line rather than reading
      // as pure haze.
      canvas.drawPath(
        segment,
        Paint()
          ..color = color.withValues(alpha: 0.08 + strength * 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.4 + strength * 2.4
          ..strokeCap = StrokeCap.round,
      );
    }

    final tangent = metric.getTangentForOffset(head);
    if (tangent == null) return;
    canvas.drawCircle(
      tangent.position,
      5.5,
      Paint()
        ..color = color.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawCircle(tangent.position, 2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _GlowBorderPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
