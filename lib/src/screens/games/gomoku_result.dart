part of 'package:companion_flutter/main.dart';

/// Simple result overlay shown when a round ends.
enum _GomokuResultKind { win, lose }

/// Full-screen 五子棋 win / lose result scene, composed from the exported art
/// pieces (bg → sun/emblem → ribbon/title → 积分 → buttons) with a staggered
/// pop-in. Positions measured from Figma 五子棋-胜利/失败 (frame 393x852,
/// nodes 248:89 / 248:113).
class _GomokuResultScreen extends StatefulWidget {
  const _GomokuResultScreen({
    super.key,
    required this.kind,
    required this.pointsDelta,
    required this.onRestart,
    required this.onExit,
  });

  final _GomokuResultKind kind;

  /// What this round settled for; null while the wallet hasn't loaded, in
  /// which case the number is left off rather than shown wrong.
  final int? pointsDelta;
  final Future<void> Function() onRestart;
  final VoidCallback onExit;

  @override
  State<_GomokuResultScreen> createState() => _GomokuResultScreenState();
}

class _GomokuResultScreenState extends State<_GomokuResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
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

  Widget _img(String name) =>
      Image.asset('$_gomokuHomeAsset$name', fit: BoxFit.fill);

  // Positions a piece centered at (cx,cy) fractions with width [wFrac]; height
  // follows the art's [aspect] (h/w). Pops (scale) or drops in from above.
  Widget _piece({
    required double screenW,
    required double screenH,
    required double cx,
    required double cy,
    required double wFrac,
    required double aspect,
    required double begin,
    required double end,
    bool drop = false,
    required Widget child,
  }) {
    final p = ((_c.value - begin) / (end - begin)).clamp(0.0, 1.0);
    final eased = Curves.easeOutBack.transform(p);
    final opacity = (p * 2.4).clamp(0.0, 1.0);
    final width = screenW * wFrac;
    final height = width * aspect;
    final dy = drop
        ? -screenH * 0.10 * (1 - Curves.easeOutCubic.transform(p))
        : 0.0;
    final scale = drop ? 1.0 : (0.7 + 0.3 * eased);
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

  Widget _scoreContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('${_gomokuHomeAsset}result_score_label.png', height: 28),
            const SizedBox(width: 7),
            if (widget.pointsDelta != null)
              _NativeGameScoreDelta(
                delta: widget.pointsDelta!,
                assetPrefix: _gomokuHomeAsset,
                winValue: 3,
                loseValue: -2,
                fill: const Color(0xFFFFFFFF),
                stroke: const Color(0xFF000000),
                height: 28,
              ),
          ],
        ),
      ),
    );
  }

  Widget _button({
    required String base,
    required String text,
    required VoidCallback onTap,
  }) {
    return _GomokuResultButton(base: base, text: text, onTap: onTap);
  }

  Widget _scorePlate() => Stack(
    alignment: Alignment.center,
    children: [
      Positioned.fill(child: _img('result_score_plate.png')),
      Positioned.fill(child: _scoreContent()),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final win = widget.kind == _GomokuResultKind.win;
    return Scaffold(
      // Sandy canyon tone behind the bg image, so the page-level cross-fade in
      // never flashes white.
      backgroundColor: const Color(0xFFEAD1A2),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              return Stack(
                children: [
                  // Opaque immediately (the page cross-fades the whole screen
                  // in); only the emblem/ribbon/score/buttons stagger.
                  Positioned.fill(
                    child: Image.asset(
                      '${_gomokuHomeAsset}result_bg.png',
                      fit: BoxFit.cover,
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

  List<Widget> _winPieces(double w, double h) => [
    // Radial light-ray burst behind the sun (Figma Group 59 — blurred sunburst
    // glow). Drawn first so the emblem covers its bright centre and only the
    // soft rays radiate out around the sun/ribbon.
    _piece(
      screenW: w, screenH: h, cx: 0.5, cy: 0.29, wFrac: 1.1,
      aspect: 1339 / 1179, begin: 0.06, end: 0.42,
      child: _img('result_win_glow.png'),
    ),
    // Sun + ribbon emblem (combined art) drops in.
    _piece(
      screenW: w, screenH: h, cx: 0.5, cy: 0.298, wFrac: 0.829,
      aspect: 555 / 978, begin: 0.12, end: 0.46, drop: true,
      child: _img('result_win_emblem.png'),
    ),
    // "胜利" centred on the ribbon band. Width/height come from the actual
    // glyph size measured in the composed design (~0.30 of the frame); the art
    // is tight glyphs, so a bigger wFrac over-sizes it.
    _piece(
      screenW: w, screenH: h, cx: 0.5, cy: 0.31, wFrac: 0.30,
      aspect: 197 / 367, begin: 0.34, end: 0.6,
      child: _img('result_win_title.png'),
    ),
    _piece(
      screenW: w, screenH: h, cx: 0.492, cy: 0.585, wFrac: 0.497,
      aspect: 177 / 586, begin: 0.5, end: 0.72,
      child: _scorePlate(),
    ),
    _piece(
      screenW: w, screenH: h, cx: 0.262, cy: 0.725, wFrac: 0.3817,
      aspect: 207 / 450, begin: 0.62, end: 0.86,
      child: _button(
        base: 'result_win_btn_exit.png',
        text: 'result_txt_exit.png',
        onTap: widget.onExit,
      ),
    ),
    _piece(
      screenW: w, screenH: h, cx: 0.738, cy: 0.724, wFrac: 0.3817,
      aspect: 210 / 450, begin: 0.68, end: 0.92,
      child: _button(
        base: 'result_win_btn_again.png',
        text: 'result_txt_again.png',
        onTap: () => unawaited(widget.onRestart()),
      ),
    ),
  ];

  List<Widget> _losePieces(double w, double h) => [
    // Radial glow burst behind the sad sun (Figma Group 62 — the dimmed
    // dark-ray counterpart of the win glow). Drawn first, under the sun.
    _piece(
      screenW: w, screenH: h, cx: 0.5, cy: 0.28, wFrac: 1.1,
      aspect: 1339 / 1179, begin: 0.06, end: 0.42,
      child: _img('result_lose_glow.png'),
    ),
    // Sad sun drops in behind the ribbon.
    _piece(
      screenW: w, screenH: h, cx: 0.5, cy: 0.282, wFrac: 0.4606,
      aspect: 549 / 543, begin: 0.12, end: 0.46, drop: true,
      child: _img('result_lose_sun.png'),
    ),
    // Ribbon (drawn after the sun so it crosses the sun's lower half).
    _piece(
      screenW: w, screenH: h, cx: 0.5, cy: 0.344, wFrac: 0.8702,
      aspect: 312 / 1026, begin: 0.32, end: 0.56,
      child: _img('result_lose_ribbon.png'),
    ),
    // "失败" centred on the ribbon band (measured glyph width ~0.30, centre
    // 0.356 — the CSS text-box centre 0.372 sits below the glyphs, which made
    // it read too big and too low before).
    _piece(
      screenW: w, screenH: h, cx: 0.5, cy: 0.356, wFrac: 0.30,
      aspect: 193 / 387, begin: 0.44, end: 0.66,
      child: _img('result_lose_title.png'),
    ),
    _piece(
      screenW: w, screenH: h, cx: 0.485, cy: 0.5675, wFrac: 0.497,
      aspect: 177 / 586, begin: 0.56, end: 0.76,
      child: _scorePlate(),
    ),
    _piece(
      screenW: w, screenH: h, cx: 0.2545, cy: 0.707, wFrac: 0.3817,
      aspect: 207 / 450, begin: 0.66, end: 0.88,
      child: _button(
        base: 'result_lose_btn_exit.png',
        text: 'result_txt_exit.png',
        onTap: widget.onExit,
      ),
    ),
    _piece(
      screenW: w, screenH: h, cx: 0.7303, cy: 0.706, wFrac: 0.3817,
      aspect: 210 / 450, begin: 0.72, end: 0.94,
      child: _button(
        base: 'result_lose_btn_again.png',
        text: 'result_txt_again.png',
        onTap: () => unawaited(widget.onRestart()),
      ),
    ),
  ];
}

/// Result-screen button (退出 / 重来一局): textless base art + text overlay,
/// with a subtle press-in scale.
class _GomokuResultButton extends StatefulWidget {
  const _GomokuResultButton({
    required this.base,
    required this.text,
    required this.onTap,
  });

  final String base;
  final String text;
  final VoidCallback onTap;

  @override
  State<_GomokuResultButton> createState() => _GomokuResultButtonState();
}

class _GomokuResultButtonState extends State<_GomokuResultButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                '$_gomokuHomeAsset${widget.base}',
                fit: BoxFit.fill,
              ),
            ),
            // Sized by HEIGHT so 退出 (2 chars) and 重来一局 (4 chars) share the
            // same glyph size, and lifted onto the raised button face (its
            // centre sits at ~0.46, above the geometric centre because of the
            // bottom bevel).
            Positioned.fill(
              child: Align(
                alignment: const Alignment(0, -0.085),
                child: FractionallySizedBox(
                  heightFactor: 0.42,
                  child: Image.asset(
                    '$_gomokuHomeAsset${widget.text}',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White display text with a dark outline, matching the game-art number style.
class _StrokeText extends StatelessWidget {
  const _StrokeText({required this.text, required this.fontSize});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
            decoration: TextDecoration.none,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = fontSize * 0.16
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0xFF181818),
          ),
        ),
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
            decoration: TextDecoration.none,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// "你的回合" ribbon. Whenever the user's turn begins it flashes in from the
/// right, holds for ~2s, then continues sliding out to the left.
class _TurnBanner extends StatefulWidget {
  const _TurnBanner({
    required this.userTurn,
    this.inMs = 200,
    this.holdMs = 600,
    this.outMs = 200,
  });

  final bool userTurn;
  // Pop-in / hold / fade-out phase durations (ms). Per-game, admin-tunable —
  // the runtime reads them from engine_config and passes them in. Defaults
  // match the original hard-coded cadence.
  final int inMs;
  final int holdMs;
  final int outMs;

  @override
  State<_TurnBanner> createState() => _TurnBannerState();
}

class _TurnBannerState extends State<_TurnBanner>
    with SingleTickerProviderStateMixin {
  // Phase boundaries as a fraction of the total, derived from the configured
  // in/hold/out durations. Total is guarded to be > 0 so the controller is
  // always valid even if all three are set to zero.
  late double _inEnd;
  late double _holdEnd;

  late final AnimationController _controller;

  int get _totalMs {
    final total = widget.inMs + widget.holdMs + widget.outMs;
    return total > 0 ? total : 1;
  }

  void _computePhases() {
    final total = _totalMs;
    _inEnd = (widget.inMs / total).clamp(0.0, 1.0);
    _holdEnd = ((widget.inMs + widget.holdMs) / total).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _computePhases();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _totalMs),
      value: 1, // start finished (hidden) until a turn actually begins
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.userTurn) _play();
    });
  }

  @override
  void didUpdateWidget(covariant _TurnBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.inMs != oldWidget.inMs ||
        widget.holdMs != oldWidget.holdMs ||
        widget.outMs != oldWidget.outMs) {
      _computePhases();
      _controller.duration = Duration(milliseconds: _totalMs);
    }
    if (widget.userTurn && !oldWidget.userTurn) _play();
  }

  void _play() {
    if (!mounted) return;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller.value = 1; // skip the animated banner entirely
      return;
    }
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final v = _controller.value;
          double dx;
          double opacity;
          // Guards: a zero-length phase makes its boundary coincide with the
          // next, so `v < _inEnd` (0) / the out denominator (1 - _holdEnd = 0)
          // are handled without dividing by zero.
          if (_inEnd > 0 && v < _inEnd) {
            final p = Curves.easeOut.transform((v / _inEnd).clamp(0.0, 1.0));
            dx = 1.3 * (1 - p);
            opacity = p;
          } else if (v < _holdEnd) {
            dx = 0;
            opacity = 1;
          } else if (_holdEnd < 1) {
            final p = Curves.easeIn.transform(
              ((v - _holdEnd) / (1 - _holdEnd)).clamp(0.0, 1.0),
            );
            dx = -1.3 * p;
            opacity = 1 - p;
          } else {
            // No fade-out phase: snap hidden once hold ends.
            dx = 0;
            opacity = v >= 1 ? 0 : 1;
          }
          if (opacity <= 0) return const SizedBox.shrink();
          return Opacity(
            opacity: opacity,
            child: FractionalTranslation(
              translation: Offset(dx, 0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final fontSize = constraints.maxHeight * 0.38;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Soft dark band: horizontal fade at the ends + a vertical
                      // fade (via the mask) so the top/bottom edges blur out
                      // instead of showing hard lines. The text stays crisp on
                      // top, unaffected by the mask.
                      Positioned.fill(
                        child: ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (rect) => const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x00000000),
                              Color(0xFF000000),
                              Color(0xFF000000),
                              Color(0x00000000),
                            ],
                            stops: [0.0, 0.34, 0.66, 1.0],
                          ).createShader(rect),
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Color(0x00000000),
                                  Color(0x73000000),
                                  Color(0x73000000),
                                  Color(0x00000000),
                                ],
                                stops: [0.0, 0.28, 0.72, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        '你的回合',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          height: 1,
                          decoration: TextDecoration.none,
                          shadows: const [
                            Shadow(
                              color: Color(0xB3000000),
                              offset: Offset(0, 1),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Round "?" button (game-art cream face + brown outline) that opens the rules.
class _GomokuHelpButton extends StatefulWidget {
  const _GomokuHelpButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_GomokuHelpButton> createState() => _GomokuHelpButtonState();
}

class _GomokuHelpButtonState extends State<_GomokuHelpButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        // The "?" is the exported game-art glyph asset (Figma jTiZSp), not a
        // font render, so its slim 25x37 proportions match the design exactly.
        child: Image.asset(
          '${_gomokuHomeAsset}game_help.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _GomokuCloseButton extends StatefulWidget {
  const _GomokuCloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_GomokuCloseButton> createState() => _GomokuCloseButtonState();
}

class _GomokuCloseButtonState extends State<_GomokuCloseButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF7A3D1E),
            border: Border.all(color: const Color(0xFFFBF3E4), width: 2.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3E2110).withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.close_rounded,
            color: Color(0xFFFBF3E4),
            size: 22,
          ),
        ),
      ),
    );
  }
}
