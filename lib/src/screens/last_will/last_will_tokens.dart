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

// 失联倒计时 ruler geometry. Marker band (20) + tick slot (12) + label slot (16).
const _legacyRulerPitch = 32.0;
const _legacyRulerMarkerSize = 20.0;
const _legacyRulerHeight = 48.0;

/// How many ticks either side of the marker still get scaled up. The exponent
/// keeps the peak narrow so the selected day stays clearly the largest one.
const _legacyRulerEmphasisSpan = 2.6;

double _legacyRulerEmphasis(double ticksFromCentre) {
  final falloff = (1 - ticksFromCentre.abs() / _legacyRulerEmphasisSpan).clamp(
    0.0,
    1.0,
  );
  return math.pow(falloff, 1.7).toDouble();
}

/// linear-gradient(104.7deg, #56575B 0%, #4D4D4D 100%)
const _legacyCardGradient = LinearGradient(
  begin: Alignment(-0.97, -0.26),
  end: Alignment(0.97, 0.26),
  colors: [Color(0xFF56575B), Color(0xFF4D4D4D)],
);

/// The export paints the canvas flat #999999. A shallow vertical ramp keeps the
/// same graphite identity while giving the white headline usable contrast.
const _legacyPageGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFA1A3A6), Color(0xFF75777B)],
);

const _legacyCardShadow = BoxShadow(
  color: Color(0x40000000),
  blurRadius: 16,
  offset: Offset(2, 8),
);

const _legacyPanelFill = Color(0xB36E7074); // #6E7074 @ 70%
const _legacyGlassFill = Color(0x66FFFFFF); // rgba(255, 255, 255, 0.4)
const _legacyChipFill = Color(0x0DFFFFFF);
const _legacyChipFillActive = Color(0x1FFFFFFF);
const _legacyChipBorder = Color(0x33FFFFFF);
const _legacyFaint = Color(0x66FFFFFF);
const _legacyDialogFill = Color(0xB3999999); // #999999 @ 70%
const _legacyBannerFill = Color(0x66000000);
const _legacyGlyph = Color(0xFFD9D9D9);

/// Text on the 40% white glass fills (the design sets 存草稿 in #000000).
const _legacyInk = Color(0xFF17181A);

/// The export sets the field placeholders in #D3D3D3, which is invisible on the
/// 40% white glass they sit on — darkened to stay in the graphite family.
const _legacyPlaceholderOnGlass = Color(0xFF5F6266);
const _legacyPlaceholderOnCard = Color(0xFFACACAC);

BorderRadius get _legacyCardBorderRadius =>
    const BorderRadius.all(_legacyCardRadius);

class _LegacyBackground extends StatelessWidget {
  const _LegacyBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(gradient: _legacyPageGradient),
      child: SizedBox.expand(),
    );
  }
}

/// The graphite card used by every surface in this flow.
class _LegacyCard extends StatelessWidget {
  const _LegacyCard({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: _legacyCardGradient,
        borderRadius: _legacyCardBorderRadius,
        boxShadow: const [_legacyCardShadow],
      ),
      child: child,
    );
  }
}

/// 36px translucent circle used for back / close in the header.
class _LegacyCircleButton extends StatelessWidget {
  const _LegacyCircleButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: _legacyGlassFill,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 4,
              offset: Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}

/// Header band: back button at (24, 8) with the optional page title centered
/// below it, matching the 84px gap the export leaves above the first card.
class _LegacyHeader extends StatelessWidget {
  const _LegacyHeader({
    required this.onBack,
    this.title,
    this.trailing,
    this.backIcon = CupertinoIcons.chevron_left,
  });

  final VoidCallback? onBack;
  final String? title;
  final Widget? trailing;
  final IconData backIcon;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return SizedBox(
      height: title == null ? 54 : 84,
      child: Stack(
        children: [
          Positioned(
            left: 24,
            top: 9,
            child: _LegacyCircleButton(icon: backIcon, onPressed: onBack),
          ),
          if (trailing != null)
            Positioned(right: 18, top: 9, child: trailing!),
          if (title != null)
            Positioned(
              left: 0,
              right: 0,
              top: 39,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  height: 29 / 24,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
        ],
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
    final text = Text(
      label,
      style: const TextStyle(
        color: Colors.white,
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
          const Icon(CupertinoIcons.chevron_right, size: 12, color: Colors.white),
        ],
      ),
    );
  }
}

/// 20-radius pill button. `primary` renders the graphite gradient with a white
/// hairline; otherwise the 40% white glass fill.
class _LegacyPillButton extends StatelessWidget {
  const _LegacyPillButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.height = 56,
    this.fontSize = 20,
    this.textColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final double height;
  final double fontSize;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? (primary ? Colors.white : _legacyInk);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: primary ? _legacyCardGradient : null,
          color: primary ? null : _legacyGlassFill,
          borderRadius: _legacyCardBorderRadius,
          border: primary ? Border.all(color: Colors.white) : null,
          boxShadow: const [_legacyCardShadow],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            height: 1.2,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

/// 68x28 preset pill (7天 / 10天 / 30天 / 60天).
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
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        width: 68,
        height: 28,
        decoration: BoxDecoration(
          color: selected ? _legacyChipFillActive : _legacyChipFill,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? Colors.white : _legacyChipBorder,
          ),
          boxShadow: selected ? const [_legacyCardShadow] : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            height: 16 / 13,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

/// 48px contact bubble. Filled slots get a solid hairline plus the person
/// glyph; empty slots get the dashed hairline over the frosted orb and a plus.
class _LegacyContactAvatar extends StatelessWidget {
  const _LegacyContactAvatar({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!filled)
            const DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  radius: 0.74,
                  colors: [
                    Color(0xB3DCDCDC),
                    Color(0x998C8C8C),
                    Color(0x99404040),
                  ],
                  stops: [0, 0.6, 1],
                ),
              ),
            ),
          // inset 0 4px 10px 3px rgba(255,255,255,0.25) — approximated with a
          // top-down white wash since Flutter has no inset box shadow.
          const DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [Color(0x3DFFFFFF), Color(0x00FFFFFF)],
              ),
            ),
          ),
          if (filled)
            const ClipOval(child: CustomPaint(painter: _LegacyPersonPainter()))
          else
            const Center(
              child: Text(
                '+',
                style: TextStyle(
                  color: Colors.white,
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
                  BorderSide(color: Colors.white, width: 1.5),
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
    final paint = Paint()..color = _legacyGlyph;
    canvas.drawCircle(
      Offset(23.5 * scale, 18.5 * scale),
      6.5 * scale,
      paint,
    );
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
      ..color = Colors.white
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

/// 283px confirmation dialog shared by 失联天数确认 and 删除遗言.
Future<bool> _showLegacyConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = '取消',
  double buttonHeight = 30,
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _LegacyDialogShell(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        buttonHeight: buttonHeight,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
  return result ?? false;
}

class _LegacyDialogShell extends StatelessWidget {
  const _LegacyDialogShell({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.buttonHeight,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final double buttonHeight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(false),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: const ColoredBox(color: Color(0x1A000000)),
            ),
          ),
        ),
        Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: 283,
              padding: const EdgeInsets.fromLTRB(27, 20, 28, 13),
              decoration: BoxDecoration(
                color: _legacyDialogFill,
                borderRadius: _legacyCardBorderRadius,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      height: 24 / 20,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 17 / 14,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: _LegacyPillButton(
                          label: cancelLabel,
                          height: buttonHeight,
                          fontSize: 14,
                          textColor: Colors.white,
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _LegacyPillButton(
                          label: confirmLabel,
                          height: buttonHeight,
                          fontSize: 14,
                          primary: true,
                          onPressed: () => Navigator.of(context).pop(true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Travelling halo around a card border. Kept from the previous revision — it
/// is the "已计时" signal on the home screen.
class _GlowBorderPainter extends CustomPainter {
  const _GlowBorderPainter({required this.progress});

  final double progress;

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
    const segmentCount = 72;
    final tailLength = length * 0.105;

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

    for (var i = segmentCount - 1; i >= 0; i--) {
      final from = head - tailLength * ((i + 1.46) / segmentCount);
      final to = head - tailLength * (i / segmentCount);
      final strength = math.pow(1 - i / segmentCount, 2.35).toDouble();
      final segment = tailSegment(from, to);
      final coreWidth = 0.16 + strength * 4.6;
      canvas.drawPath(
        segment,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.03 + strength * 0.26)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 + strength * 9
          ..strokeCap = StrokeCap.butt
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      canvas.drawPath(
        segment,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.04 + strength * 0.46)
          ..style = PaintingStyle.stroke
          ..strokeWidth = coreWidth
          ..strokeCap = StrokeCap.butt,
      );
    }

    final tangent = metric.getTangentForOffset(head);
    if (tangent == null) return;
    canvas.drawCircle(
      tangent.position,
      5.6,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.38)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawCircle(
      tangent.position,
      1.9,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _GlowBorderPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
