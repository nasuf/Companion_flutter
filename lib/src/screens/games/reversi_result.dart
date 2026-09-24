part of 'package:companion_flutter/main.dart';

enum _ReversiResultKind { win, lose }

/// Clips a child to the top [fraction] of its height. Used to show only the
/// rope coil from the rope+tablet art, so the hanging stone tablet never peeks
/// out below the coil (design note: 只显示吊绳).
class _TopFractionClipper extends CustomClipper<Rect> {
  const _TopFractionClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width, size.height * fraction);

  @override
  bool shouldReclip(covariant _TopFractionClipper oldClipper) =>
      oldClipper.fraction != fraction;
}

/// Result-screen button (再来一局 / 确认) with a subtle press-in scale so a tap
/// reads as physical instead of a flat hit target.
class _ReversiResultButton extends StatefulWidget {
  const _ReversiResultButton({
    required this.base,
    required this.text,
    required this.textWidthFactor,
    required this.onTap,
  });

  final String base;
  final String text;
  final double textWidthFactor;
  final Future<void> Function() onTap;

  @override
  State<_ReversiResultButton> createState() => _ReversiResultButtonState();
}

class _ReversiResultButtonState extends State<_ReversiResultButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        unawaited(widget.onTap());
      },
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Image.asset(
                '$_reversiAsset${widget.base}',
                fit: BoxFit.fill,
              ),
            ),
            FractionallySizedBox(
              widthFactor: widget.textWidthFactor,
              child: Image.asset(
                '$_reversiAsset${widget.text}',
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen win / lose result scene composed from individual art pieces so
/// each element flies in with its own stagger (bg → frame/emblem → title →
/// score → buttons) instead of one flat, lifeless image.
class _ReversiResultScreen extends StatefulWidget {
  const _ReversiResultScreen({
    super.key,
    required this.kind,
    required this.pointsDelta,
    required this.onAgain,
    required this.onConfirm,
  });

  final _ReversiResultKind kind;

  /// What this round settled for; null while the wallet hasn't loaded, in
  /// which case the number is left off rather than shown wrong.
  final int? pointsDelta;
  final Future<void> Function() onAgain;
  final Future<void> Function() onConfirm;

  @override
  State<_ReversiResultScreen> createState() => _ReversiResultScreenState();
}

class _ReversiResultScreenState extends State<_ReversiResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      // Lose runs longer so the "失败" pendant can drop, swing and settle
      // gradually; win keeps its original snappier staggered entrance.
      duration: Duration(
        milliseconds: widget.kind == _ReversiResultKind.lose ? 2000 : 1400,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
        _c.value = 1;
      } else {
        _c.forward();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _fade(double a, double b) =>
      ((_c.value - a) / (b - a)).clamp(0.0, 1.0);

  Widget _img(String name) =>
      Image.asset('$_reversiAsset$name', fit: BoxFit.fill);

  // Rope coil only (top slice of the rope+tablet art) so the stone tablet is
  // never revealed below the coil.
  Widget _ropeCoil({bool flip = false}) {
    Widget coil = ClipRect(
      clipper: const _TopFractionClipper(0.36),
      child: _img('result_lose_rope.png'),
    );
    if (flip) coil = Transform.flip(flipX: true, child: coil);
    return coil;
  }

  // Positions a piece centered at (cx,cy) fractions with width [wFrac]; height
  // follows the art's [aspect] (h/w). Drops in from above or pops (scale).
  Widget _piece({
    required double screenW,
    required double screenH,
    required double cx,
    required double cy,
    required double wFrac,
    required double aspect,
    required double begin,
    required double end,
    required bool drop,
    required Widget child,
  }) {
    final p = ((_c.value - begin) / (end - begin)).clamp(0.0, 1.0);
    final eased = Curves.easeOutBack.transform(p);
    final opacity = (p * 2.2).clamp(0.0, 1.0);
    final width = screenW * wFrac;
    final height = width * aspect;
    final dy = drop
        ? -screenH * 0.12 * (1 - Curves.easeOutCubic.transform(p))
        : 0.0;
    final scale = drop ? 1.0 : (0.72 + 0.28 * eased);
    return Positioned(
      left: screenW * cx - width / 2,
      top: screenH * cy - height / 2 + dy,
      width: width,
      height: height,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(scale: scale, child: child),
      ),
    );
  }

  Widget _button({
    required String base,
    required String text,
    required double textWidthFactor,
    required Future<void> Function() onTap,
  }) {
    return _ReversiResultButton(
      base: base,
      text: text,
      textWidthFactor: textWidthFactor,
      onTap: onTap,
    );
  }

  Widget _scoreContent(
    String labelAsset, {
    Alignment align = Alignment.center,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Align(
        alignment: align,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('$_reversiAsset$labelAsset', height: 26),
              const SizedBox(width: 8),
              if (widget.pointsDelta != null)
                // Slightly under the label: the digits are solid strokes and
                // read heavier than the 积分 characters at a matching height.
                _NativeGameScoreDelta(
                  delta: widget.pointsDelta!,
                  assetPrefix: _reversiAsset,
                  winValue: 4,
                  loseValue: -3,
                  fill: const Color(0xFFF1DFC5),
                  stroke: const Color(0xFF4E1F0F),
                  height: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── "失败" hanging pendant (ropes + plate) — drop from above, get caught,
  // swing, then settle (design note). Shared timeline so the ropes and plate
  // move together as one pendant, pivoting about the top (the rope anchors).
  double get _hangDy {
    final q = ((_c.value - 0.35) / (0.60 - 0.35)).clamp(0.0, 1.0);
    // Fraction of screen height; starts high above, eases down to 0.
    return -0.55 * (1 - Curves.easeOutCubic.transform(q));
  }

  double get _hangAngle {
    final q = ((_c.value - 0.50) / 0.50).clamp(0.0, 1.0);
    if (q <= 0) return 0.0;
    // Damped pendulum: sin() starts at 0 (continuous with the drop) then swings
    // ~1.5 times, the exp envelope settling it back to level.
    return 0.11 * math.exp(-3.0 * q) * math.sin(3.0 * math.pi * q);
  }

  double get _hangOpacity => ((_c.value - 0.33) / 0.12).clamp(0.0, 1.0);

  Widget _hang({
    required double screenW,
    required double screenH,
    required double cx,
    required double cy,
    required double wFrac,
    required double aspect,
    required Widget child,
  }) {
    final width = screenW * wFrac;
    final height = width * aspect;
    return Positioned(
      left: screenW * cx - width / 2,
      top: screenH * cy - height / 2,
      width: width,
      height: height,
      child: Opacity(
        opacity: _hangOpacity,
        child: Transform.translate(
          offset: Offset(0, _hangDy * screenH),
          child: Transform.rotate(
            angle: _hangAngle,
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final win = widget.kind == _ReversiResultKind.win;
    return Scaffold(
      backgroundColor: const Color(0xFF9AD0EE),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: _fade(0.0, 0.28),
                      child: Image.asset(
                        '${_reversiAsset}result_bg.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  ...win ? _winPieces(w, h) : _losePieces(w, h),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // Positions measured from Figma 胜利弹窗 (frame 393x852, node 125:1136):
  // emblem 42,193,309x329 · ribbon 36,349,321x102 · 积分 147,456,100x55 ·
  // buttons 37/224,588,136x54 · 胜利 text 104,364,187x47.
  List<Widget> _winPieces(double w, double h) => [
    // Sun emblem stone — sits lower than before so the ribbon can cross its
    // lower third (design: centre y ~0.42, not near the top).
    _piece(
      screenW: w, screenH: h, cx: 0.5, cy: 0.4196, wFrac: 0.786,
      aspect: 329 / 309, begin: 0.12, end: 0.5, drop: true,
      child: _img('result_win_emblem.png'),
    ),
    // "胜利" ribbon over the emblem's lower third. The 胜利 art is centred on the
    // red banner body (~0.38 of the ribbon box height), not the box centre.
    _piece(
      screenW: w, screenH: h, cx: 0.5, cy: 0.4695, wFrac: 0.8168,
      aspect: 102 / 321, begin: 0.4, end: 0.64, drop: false,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: _img('result_win_ribbon.png')),
          // Upper thicker part of the band (height OK per review). Nudged right
          // because the title art's visible mass sits left of centre (its drop
          // shadow pads the right edge), so a centred box reads slightly left.
          Align(
            alignment: const Alignment(0.09, -0.5),
            child: FractionallySizedBox(
              widthFactor: 0.52,
              heightFactor: 0.4,
              child: Image.asset(
                '${_reversiAsset}result_win_title.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    ),
    // "积分" hanging sign, just below the ribbon.
    _piece(
      screenW: w, screenH: h, cx: 0.501, cy: 0.5675, wFrac: 0.2545,
      aspect: 55 / 100, begin: 0.52, end: 0.76, drop: false,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: _img('result_win_scroll.png')),
          // Biased down onto the lower body of the parchment panel (rope loops
          // sit above it, so a centred score reads "high").
          Positioned.fill(
            child: _scoreContent(
              'result_txt_score.png',
              align: const Alignment(0, 0.85),
            ),
          ),
        ],
      ),
    ),
    _piece(
      screenW: w, screenH: h, cx: 0.267, cy: 0.722, wFrac: 0.346,
      aspect: 54 / 136, begin: 0.68, end: 0.92, drop: false,
      child: _button(
        base: 'result_win_btn.png',
        text: 'result_txt_again.png',
        textWidthFactor: 0.66,
        onTap: widget.onAgain,
      ),
    ),
    _piece(
      screenW: w, screenH: h, cx: 0.743, cy: 0.722, wFrac: 0.346,
      aspect: 54 / 136, begin: 0.74, end: 0.98, drop: false,
      child: _button(
        base: 'result_win_btn.png',
        text: 'result_txt_ok.png',
        textWidthFactor: 0.34,
        onTap: widget.onConfirm,
      ),
    ),
  ];

  List<Widget> _losePieces(double w, double h) => [
    // Outer stone frame drops in first as the backdrop.
    _piece(
      screenW: w, screenH: h, cx: 0.5, cy: 0.45, wFrac: 0.665,
      aspect: 1062 / 804, begin: 0.1, end: 0.42, drop: true,
      child: _img('result_lose_frame.png'),
    ),
    // Crossed swords crown atop the frame.
    _piece(
      screenW: w, screenH: h, cx: 0.5, cy: 0.265, wFrac: 0.225,
      aspect: 327 / 309, begin: 0.3, end: 0.54, drop: false,
      child: _img('result_lose_swords.png'),
    ),
    // Crossed bones tied into the two bottom corners. The long bone reads as a
    // "/" on the left and its mirror "\" on the right, matching the design
    // (the asset's long bone sits near-horizontal, so it needs a counter-
    // clockwise tilt on the left and the mirror on the right).
    _piece(
      screenW: w, screenH: h, cx: 0.242, cy: 0.62, wFrac: 0.15,
      aspect: 250 / 258, begin: 0.5, end: 0.72, drop: false,
      child: Transform.rotate(
        angle: -0.7,
        child: _img('result_lose_bones.png'),
      ),
    ),
    _piece(
      screenW: w, screenH: h, cx: 0.758, cy: 0.62, wFrac: 0.15,
      aspect: 250 / 258, begin: 0.5, end: 0.72, drop: false,
      child: Transform.rotate(
        angle: 0.7,
        child: Transform.flip(
          flipX: true,
          child: _img('result_lose_bones.png'),
        ),
      ),
    ),
    // Hanging pendant: the two rope coils and the "失败" plate drop from above
    // as a group and swing before settling. Only the coil is shown (tablet
    // clipped away), and the plate rides just under the coils.
    // Rope coils centred on the frame's two tiki blocks. The frame art leans
    // slightly right, so the right tiki sits further right than a mirror of the
    // left — tuned on-device to 0.360 / 0.662.
    _hang(
      screenW: w, screenH: h, cx: 0.360, cy: 0.365, wFrac: 0.072,
      aspect: 249 / 84,
      child: _ropeCoil(),
    ),
    _hang(
      screenW: w, screenH: h, cx: 0.662, cy: 0.365, wFrac: 0.072,
      aspect: 249 / 84,
      child: _ropeCoil(flip: true),
    ),
    // "失败" title plate — slightly right of centre, raised so its top meets the
    // rope coils (design note: 靠右居中一些 + 板子上移).
    _hang(
      screenW: w, screenH: h, cx: 0.515, cy: 0.395, wFrac: 0.405,
      aspect: 282 / 492,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: _img('result_lose_title_plate.png')),
          FractionallySizedBox(
            widthFactor: 0.58,
            heightFactor: 0.6,
            child: Image.asset(
              '${_reversiAsset}result_lose_title.png',
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    ),
    _piece(
      screenW: w, screenH: h, cx: 0.505, cy: 0.518, wFrac: 0.32,
      aspect: 153 / 402, begin: 0.72, end: 0.88, drop: false,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: _img('result_lose_score_plate.png')),
          Positioned.fill(
            child: _scoreContent(
              'result_lose_score_label.png',
            ),
          ),
        ],
      ),
    ),
    _piece(
      screenW: w, screenH: h, cx: 0.29, cy: 0.74, wFrac: 0.34,
      aspect: 258 / 405, begin: 0.82, end: 0.94, drop: false,
      child: _button(
        base: 'result_lose_btn_again.png',
        text: 'result_txt_again.png',
        textWidthFactor: 0.6,
        onTap: widget.onAgain,
      ),
    ),
    _piece(
      screenW: w, screenH: h, cx: 0.71, cy: 0.74, wFrac: 0.34,
      aspect: 255 / 399, begin: 0.88, end: 1.0, drop: false,
      child: _button(
        base: 'result_lose_btn_ok.png',
        text: 'result_txt_ok.png',
        textWidthFactor: 0.32,
        onTap: widget.onConfirm,
      ),
    ),
  ];
}
