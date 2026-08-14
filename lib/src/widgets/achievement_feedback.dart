part of 'package:companion_flutter/main.dart';

class _AchievementError extends StatelessWidget {
  const _AchievementError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_circle,
              color: AppColors.muted,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 14),
            ),
            const SizedBox(height: 14),
            CupertinoButton.filled(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

class _AchievementTimelineRow extends StatelessWidget {
  const _AchievementTimelineRow({required this.item, required this.onTap});

  final AchievementItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _achievementLevelColor(item);
    final isDark = AppColors.isDark(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final pillWidth = math.min(238.0, math.max(212.0, screenWidth - 136));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.92, end: 1),
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: CupertinoButton(
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            onPressed: onTap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceMuted.withValues(alpha: 0.88)
                    : Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.white,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: isDark ? 0.24 : 0.18),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: SizedBox(
                width: pillWidth,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(11, 7, 13, 7),
                  child: Row(
                    children: [
                      _AchievementLevelIcon(item: item, size: 34),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFFF2F7FB)
                                : AppColors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Icon(Icons.auto_awesome, size: 16, color: color),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AchievementDetailOverlay extends StatefulWidget {
  const _AchievementDetailOverlay({
    super.key,
    required this.item,
    required this.onDismiss,
  });

  final AchievementItem item;
  final VoidCallback onDismiss;

  @override
  State<_AchievementDetailOverlay> createState() =>
      _AchievementDetailOverlayState();
}

class _AchievementDetailOverlayState extends State<_AchievementDetailOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _presenceController;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _presenceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
    )..forward();
  }

  @override
  void dispose() {
    _presenceController.dispose();
    super.dispose();
  }

  Future<void> _requestDismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    try {
      await _presenceController.reverse().orCancel;
    } on TickerCanceled {
      return;
    }
    if (mounted) widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _presenceController,
      builder: (context, _) {
        final progress = Curves.easeOutCubic.transform(
          _presenceController.value,
        );
        return Opacity(
          opacity: progress,
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _requestDismiss();
            },
            child: _AchievementUnlockPopup(
              item: widget.item,
              onAccept: _requestDismiss,
            ),
          ),
        );
      },
    );
  }
}

/// Symmetric side inset on the 390 CSS artboard (was Figma 47/296).
/// Use left+right, not left+width, so the slot stays on the screen center.
const _kPopupCopyInset = 16.0;

/// Full-screen unlock popup. Positions are the 390×844 CSS from
/// 微光成就弹框, scaled independently on X/Y so the cluster sits
/// where Figma put it instead of being stretched by Spacer.
class _AchievementUnlockPopup extends StatefulWidget {
  const _AchievementUnlockPopup({required this.item, required this.onAccept});

  final AchievementItem item;
  final VoidCallback onAccept;

  @override
  State<_AchievementUnlockPopup> createState() =>
      _AchievementUnlockPopupState();
}

class _AchievementUnlockPopupState extends State<_AchievementUnlockPopup>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _idle;
  late final Listenable _motion;
  bool _alive = true;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 920),
    );
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _motion = Listenable.merge([_enter, _idle]);
    _enter.forward().whenComplete(() {
      if (_alive) _idle.repeat(reverse: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(
      precacheImage(AssetImage(_achievementLevelAsset(widget.item)), context),
    );
  }

  @override
  void dispose() {
    _alive = false;
    _enter.dispose();
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final sx = size.width / 390;
    final sy = size.height / 844;
    final item = widget.item;
    final onAccept = widget.onAccept;
    final body = item.popupText.isEmpty ? item.conditionText : item.popupText;
    final bodyStyle = TextStyle(
      color: Colors.white,
      fontSize: 18 * sy,
      height: 22 / 18,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
      decoration: TextDecoration.none,
    );
    final nameStyle = TextStyle(
      color: Colors.white,
      fontSize: 24 * sy,
      height: 29 / 24,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
      decoration: TextDecoration.none,
    );
    final badgeAsset = _achievementLevelAsset(item);
    return AnimatedBuilder(
      animation: _motion,
      builder: (context, _) {
        final t = _enter.value;
        final idle = Curves.easeInOut.transform(_idle.value);
        final badgePop = _popupInterval(t, 0.08, 0.58, Curves.easeOutBack);
        final badgeScale =
            lerpDouble(0.42, 1.0, badgePop)! * lerpDouble(1.0, 1.045, idle)!;
        final badgeRotate = lerpDouble(
          -0.14,
          0,
          _popupInterval(t, 0.08, 0.5, Curves.easeOutCubic),
        )!;
        final glowOpacity =
            _popupInterval(t, 0.1, 0.48, Curves.easeOut) *
            lerpDouble(0.72, 1.0, idle)!;
        final glowScale = badgeScale * lerpDouble(1.0, 1.07, idle)!;
        final rays = _popupInterval(t, 0.0, 0.36, Curves.easeOut);
        final title = _popupInterval(t, 0.18, 0.48, Curves.easeOutCubic);
        final name = _popupInterval(t, 0.32, 0.58, Curves.easeOutCubic);
        final bodyIn = _popupInterval(t, 0.38, 0.64, Curves.easeOutCubic);
        final reward = _popupInterval(t, 0.46, 0.72, Curves.easeOutCubic);
        final button = _popupInterval(t, 0.52, 0.84, Curves.easeOutBack);
        final coinPop = _popupInterval(t, 0.5, 0.78, Curves.easeOutBack);

        Widget fadeSlide(double progress, Widget child, {double dy = 14}) {
          return Opacity(
            opacity: progress.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, dy * (1 - progress) * sy),
              child: child,
            ),
          );
        }

        return Material(
          color: Colors.transparent,
          child: SizedBox.expand(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned.fill(child: _AchievementPopupVeil()),
                Positioned.fill(
                  child: Opacity(
                    opacity: rays,
                    child: const _AchievementPopupRays(),
                  ),
                ),
                // Group 475: same badge PNG at 271×245 with CSS blur(25px).
                _AchievementPopupGlow(
                  asset: badgeAsset,
                  sx: sx,
                  sy: sy,
                  scale: glowScale,
                  opacity: glowOpacity,
                  rotation: badgeRotate,
                ),
                _CssPos(
                  left: (390 - 204) / 2,
                  top: 243,
                  width: 204,
                  height: 184,
                  sx: sx,
                  sy: sy,
                  child: Transform.rotate(
                    angle: badgeRotate,
                    child: Transform.scale(
                      scale: badgeScale,
                      child: Image.asset(badgeAsset, fit: BoxFit.contain),
                    ),
                  ),
                ),
                _CssPos(
                  left: 3,
                  top: 138,
                  width: 384,
                  height: 70,
                  sx: sx,
                  sy: sy,
                  child: fadeSlide(
                    title,
                    Transform.scale(
                      scale: lerpDouble(0.9, 1.0, title)!,
                      child: _AchievementPopupTitle(fontSize: 50 * sy),
                    ),
                    dy: 10,
                  ),
                ),
                _CssHPad(
                  inset: _kPopupCopyInset,
                  top: 436,
                  height: 47,
                  sx: sx,
                  sy: sy,
                  child: fadeSlide(
                    name,
                    _AchievementPopupOneLine(text: item.name, style: nameStyle),
                  ),
                ),
                _CssHPad(
                  inset: _kPopupCopyInset,
                  top: 483,
                  height: 31,
                  sx: sx,
                  sy: sy,
                  child: fadeSlide(
                    bodyIn,
                    _AchievementPopupOneLine(text: body, style: bodyStyle),
                  ),
                ),
                _CssHPad(
                  inset: _kPopupCopyInset,
                  top: 530,
                  height: 31,
                  sx: sx,
                  sy: sy,
                  child: fadeSlide(
                    reward,
                    Center(
                      child: Text(
                        '奖励明细',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16 * sy,
                          height: 19 / 16,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    dy: 10,
                  ),
                ),
                // Line 7 / Line 6: brightest next to the label, fade to the edges.
                _CssPos(
                  left: 67,
                  top: 541,
                  width: 86,
                  height: 2,
                  sx: sx,
                  sy: sy,
                  child: fadeSlide(
                    reward,
                    Image.asset(
                      'assets/achievements/popup_reward_line_left.png',
                      fit: BoxFit.fill,
                    ),
                    dy: 8,
                  ),
                ),
                _CssPos(
                  left: 236,
                  top: 541,
                  width: 86,
                  height: 2,
                  sx: sx,
                  sy: sy,
                  child: fadeSlide(
                    reward,
                    Image.asset(
                      'assets/achievements/popup_reward_line_right.png',
                      fit: BoxFit.fill,
                    ),
                    dy: 8,
                  ),
                ),
                _CssPos(
                  left: (390 - 24) / 2,
                  top: 561,
                  width: 24,
                  height: 24,
                  sx: sx,
                  sy: sy,
                  child: fadeSlide(
                    reward,
                    Transform.scale(
                      scale: lerpDouble(0.4, 1.0, coinPop)!,
                      child: Image.asset(
                        'assets/achievements/popup_gold_coin.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    dy: 8,
                  ),
                ),
                _CssHPad(
                  inset: _kPopupCopyInset,
                  top: 604,
                  height: 31,
                  sx: sx,
                  sy: sy,
                  child: fadeSlide(
                    reward,
                    Center(
                      child: Text(
                        '积分+${item.score}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14 * sy,
                          height: 17 / 14,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    dy: 8,
                  ),
                ),
                _CssPos(
                  left: 42,
                  top: 651,
                  width: 306,
                  height: 56,
                  sx: sx,
                  sy: sy,
                  child: fadeSlide(
                    button,
                    Transform.scale(
                      scale: lerpDouble(0.86, 1.0, button)!,
                      child: _AchievementAcceptButton(
                        sy: sy,
                        onPressed: onAccept,
                      ),
                    ),
                    dy: 18,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Name and body stay on one CSS line at the Figma font size.
/// Long copy is clipped instead of wrapping or shrinking.
class _AchievementPopupOneLine extends StatelessWidget {
  const _AchievementPopupOneLine({required this.text, required this.style});

  final String text;
  final TextStyle style;

  static final _trailingCjkPunct = RegExp(r'[！？～。，、…]');

  @override
  Widget build(BuildContext context) {
    final t = text.trim();
    final fontSize = style.fontSize ?? 18;
    // Trailing fullwidth punct sits in the left of its em-box, so advance-width
    // centering looks left-heavy. Left pad shifts the visual midpoint back.
    final opticalNudge =
        t.isNotEmpty && _trailingCjkPunct.hasMatch(t[t.length - 1])
        ? fontSize * 0.32
        : 0.0;
    return Padding(
      padding: EdgeInsets.only(left: opticalNudge * 2),
      child: Text(
        t,
        maxLines: 1,
        textAlign: TextAlign.center,
        overflow: TextOverflow.clip,
        style: style,
      ),
    );
  }
}

double _popupInterval(double t, double start, double end, Curve curve) {
  if (t <= start) return 0;
  if (t >= end) return 1;
  return curve.transform((t - start) / (end - start));
}

class _CssPos extends StatelessWidget {
  const _CssPos({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.sx,
    required this.sy,
    required this.child,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final double sx;
  final double sy;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left * sx,
      top: top * sy,
      width: width * sx,
      height: height * sy,
      child: child,
    );
  }
}

/// Full-width row with equal left/right inset so text sits on the screen center.
class _CssHPad extends StatelessWidget {
  const _CssHPad({
    required this.inset,
    required this.top,
    required this.height,
    required this.sx,
    required this.sy,
    required this.child,
  });

  final double inset;
  final double top;
  final double height;
  final double sx;
  final double sy;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: inset * sx,
      right: inset * sx,
      top: top * sy,
      height: height * sy,
      child: child,
    );
  }
}

/// Rectangle 305: brown-black veil at 90% over the chat.
class _AchievementPopupVeil extends StatelessWidget {
  const _AchievementPopupVeil();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xE6534641), Color(0xE61E1F23)],
        ),
      ),
    );
  }
}

/// Rectangle 306–309 rasterized as one overlay. Two shafts from each
/// top corner, angling into the badge — same sprites as the Figma file.
class _AchievementPopupRays extends StatelessWidget {
  const _AchievementPopupRays();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Image(
        image: AssetImage('assets/achievements/popup_rays.png'),
        fit: BoxFit.fill,
        filterQuality: FilterQuality.high,
        alignment: Alignment.topCenter,
      ),
    );
  }
}

/// CSS Group 475: `url(微光.png)` at 271×245 with `filter: blur(25px)`.
/// Pad the layer so the Gaussian tail is not clipped by the 271 box.
class _AchievementPopupGlow extends StatelessWidget {
  const _AchievementPopupGlow({
    required this.asset,
    required this.sx,
    required this.sy,
    this.scale = 1,
    this.opacity = 1,
    this.rotation = 0,
  });

  final String asset;
  final double sx;
  final double sy;
  final double scale;
  final double opacity;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    const glowW = 271.0;
    const glowH = 245.0;
    const glowLeft = (390 - 271) / 2 - 0.5;
    const glowTop = 212.0;
    final sigmaX = 25 * sx;
    final sigmaY = 25 * sy;
    final pad = math.max(sigmaX, sigmaY) * 2;
    return Positioned(
      left: glowLeft * sx - pad,
      top: glowTop * sy - pad,
      width: glowW * sx + pad * 2,
      height: glowH * sy + pad * 2,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: rotation,
            child: Transform.scale(
              scale: scale,
              child: RepaintBoundary(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: sigmaX,
                    sigmaY: sigmaY,
                    tileMode: TileMode.decal,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(pad),
                    child: ColorFiltered(
                      // Lift the dark badge core so blur(25px) blooms as a halo
                      // instead of a muddy disc. Alpha is preserved.
                      colorFilter: const ColorFilter.matrix(<double>[
                        1.45,
                        0,
                        0,
                        0,
                        28,
                        0,
                        1.45,
                        0,
                        0,
                        28,
                        0,
                        0,
                        1.45,
                        0,
                        28,
                        0,
                        0,
                        0,
                        0.92,
                        0,
                      ]),
                      child: Image.asset(asset, fit: BoxFit.fill),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 「达成新成就」: cream vertical gradient, 0.3px brown stroke, white highlight.
class _AchievementPopupTitle extends StatelessWidget {
  const _AchievementPopupTitle({required this.fontSize});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: fontSize,
      height: 59 / 50,
      fontWeight: FontWeight.w800,
      letterSpacing: 0,
      decoration: TextDecoration.none,
    );
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Text(
            '达成新成就',
            textAlign: TextAlign.center,
            style: style.copyWith(
              shadows: const [
                Shadow(
                  color: Color(0x73FFFFFF),
                  offset: Offset(-2, -2),
                  blurRadius: 2,
                ),
              ],
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 0.8
                ..color = const Color(0xFF892C02),
            ),
          ),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFFEF8), Color(0xFFF5ECC4)],
            ).createShader(bounds),
            child: Text(
              '达成新成就',
              textAlign: TextAlign.center,
              style: style.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementAcceptButton extends StatefulWidget {
  const _AchievementAcceptButton({required this.sy, required this.onPressed});

  final double sy;
  final VoidCallback onPressed;

  @override
  State<_AchievementAcceptButton> createState() =>
      _AchievementAcceptButtonState();
}

class _AchievementAcceptButtonState extends State<_AchievementAcceptButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.92,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 22,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.92,
          end: 1.06,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 32,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.06,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 46,
      ),
    ]).animate(_press);
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_busy) return;
    _busy = true;
    try {
      await _press.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }
    if (mounted) widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) {
          return Transform.scale(scale: _scale.value, child: child);
        },
        child: Container(
          width: double.infinity,
          height: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40FFFFFF),
                offset: Offset(2, 8),
                blurRadius: 16,
              ),
              BoxShadow(
                color: Color(0x1A496CFC),
                offset: Offset(0, 8),
                blurRadius: 16,
              ),
            ],
          ),
          child: Text(
            '我收下啦',
            style: TextStyle(
              color: const Color(0xFF060606),
              fontSize: 22 * widget.sy,
              height: 26 / 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _AchievementLevelIcon extends StatelessWidget {
  const _AchievementLevelIcon({required this.item, required this.size});

  final AchievementItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = _achievementLevelColor(item);
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.12),
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.03),
          child: Image.asset(_achievementLevelAsset(item), fit: BoxFit.contain),
        ),
      ),
    );
  }
}

String _achievementLevelAsset(AchievementItem item) {
  final level = item.levelName;
  if (level.contains('清响')) {
    return 'assets/achievements/achievement_level_clear_echo.png';
  }
  if (level.contains('心澜')) {
    return 'assets/achievements/achievement_level_heartwave.png';
  }
  if (level.contains('魂刻')) {
    return 'assets/achievements/achievement_level_soulmark.png';
  }
  if (level.contains('深潜')) {
    return 'assets/achievements/achievement_level_deepdive.png';
  }
  return 'assets/achievements/achievement_level_glimmer.png';
}

Color _achievementLevelColor(AchievementItem item) {
  final level = item.levelName;
  if (level.contains('清响')) return const Color(0xFF4F9CF7);
  if (level.contains('心澜')) return const Color(0xFFFF8A42);
  if (level.contains('魂刻')) return const Color(0xFFD4A03C);
  if (level.contains('深潜')) return const Color(0xFF7C4DFF);
  return const Color(0xFF72C9BE);
}
