part of 'package:companion_flutter/main.dart';

class _NativeGameFullscreenTransition extends StatelessWidget {
  const _NativeGameFullscreenTransition({
    required this.expanded,
    required this.compactChild,
    required this.expandedChild,
  });

  static const _expandDuration = Duration(milliseconds: 480);
  static const _collapseDuration = Duration(milliseconds: 400);

  final bool expanded;
  final Widget compactChild;
  final Widget expandedChild;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : _expandDuration,
      reverseDuration: reduceMotion ? Duration.zero : _collapseDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        fit: StackFit.expand,
        children: [...previousChildren, if (currentChild != null) currentChild],
      ),
      transitionBuilder: (child, animation) {
        final key = child.key;
        final isExpanded = key is ValueKey<bool> ? key.value : expanded;
        return AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            final progress = animation.value;
            final startScale = isExpanded ? 0.92 : 0.975;
            final startOpacity = isExpanded ? 0.28 : 0.58;
            final scale = startScale + (1 - startScale) * progress;
            final opacity = startOpacity + (1 - startOpacity) * progress;
            final radius = isExpanded ? 28 * (1 - progress) : 0.0;
            final travel = isExpanded ? 18.0 : 7.0;
            return Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(0, travel * (1 - progress)),
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.center,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(radius),
                    child: RepaintBoundary(child: child),
                  ),
                ),
              ),
            );
          },
        );
      },
      child: KeyedSubtree(
        key: ValueKey<bool>(expanded),
        child: expanded ? expandedChild : compactChild,
      ),
    );
  }
}

class _NativeFullscreenGameSurface extends StatefulWidget {
  const _NativeFullscreenGameSurface({
    required this.gameKey,
    required this.gameTitle,
    required this.child,
    required this.onExit,
    required this.onRestart,
    required this.restartLabel,
    required this.restartDisabled,
    required this.restartLoading,
  });

  final String gameKey;
  final String gameTitle;
  final Widget child;
  final VoidCallback onExit;
  final Future<void> Function() onRestart;
  final String restartLabel;
  final bool restartDisabled;
  final bool restartLoading;

  @override
  State<_NativeFullscreenGameSurface> createState() =>
      _NativeFullscreenGameSurfaceState();
}

class _NativeFullscreenGameSurfaceState
    extends State<_NativeFullscreenGameSurface> {
  @override
  void initState() {
    super.initState();
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]),
    );
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
  }

  @override
  void dispose() {
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]),
    );
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visual = _NativeFullscreenVisual.forGame(widget.gameKey);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) widget.onExit();
      },
      child: Scaffold(
        backgroundColor: visual.backgroundBottom,
        body: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _NativeFullscreenBackdropPainter(
                    gameKey: widget.gameKey,
                    visual: visual,
                  ),
                ),
              ),
            ),
            SafeArea(
              minimum: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const controlBandHeight = 48.0;
                  const scrollVerticalPadding = 20.0;
                  final minimumStageHeight = math.max(
                    0.0,
                    constraints.maxHeight -
                        controlBandHeight -
                        scrollVerticalPadding * 2,
                  );
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(
                            top: controlBandHeight + scrollVerticalPadding,
                            bottom: scrollVerticalPadding,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: minimumStageHeight,
                            ),
                            child: Align(
                              alignment: const Alignment(0, 0.08),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 680,
                                ),
                                child: _NativeFullscreenGameStage(
                                  visual: visual,
                                  gameTitle: widget.gameTitle,
                                  child: widget.child,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _NativeFullscreenActionButton(
                              tooltip: widget.restartLabel,
                              icon: Icons.refresh_rounded,
                              loading: widget.restartLoading,
                              onPressed: widget.restartDisabled
                                  ? null
                                  : widget.onRestart,
                              backgroundColor: visual.chromeBackground,
                              foregroundColor: visual.chromeForeground,
                              borderColor: visual.chromeBorder,
                            ),
                            const SizedBox(width: 8),
                            _NativeFullscreenToggleButton(
                              expanded: true,
                              onPressed: widget.onExit,
                              backgroundColor: visual.chromeBackground,
                              foregroundColor: visual.chromeForeground,
                              borderColor: visual.chromeBorder,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NativeFullscreenGameStage extends StatelessWidget {
  const _NativeFullscreenGameStage({
    required this.visual,
    required this.gameTitle,
    required this.child,
  });

  final _NativeFullscreenVisual visual;
  final String gameTitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final dark = AppColors.isDark(context);
    final surface = Color.alphaBlend(
      visual.stageTint.withValues(alpha: dark ? 0.13 : 0.09),
      colors.surface.withValues(alpha: dark ? 0.94 : 0.91),
    );
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: visual.accent.withValues(alpha: dark ? 0.28 : 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: visual.shadow.withValues(alpha: dark ? 0.26 : 0.2),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: visual.accent.withValues(alpha: dark ? 0.22 : 0.15),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: visual.accent.withValues(alpha: 0.34),
                    ),
                  ),
                  child: Icon(
                    visual.icon,
                    size: 17,
                    color: dark
                        ? Color.lerp(visual.accent, Colors.white, 0.28)
                        : visual.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    gameTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                Container(
                  width: 34,
                  height: 3,
                  decoration: BoxDecoration(
                    color: visual.accent.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: visual.accent.withValues(alpha: dark ? 0.18 : 0.12),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
            child: SizedBox(width: double.infinity, child: child),
          ),
        ],
      ),
    );
  }
}

class _NativeFullscreenActionButton extends StatelessWidget {
  const _NativeFullscreenActionButton({
    required this.tooltip,
    required this.icon,
    required this.loading,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
  });

  final String tooltip;
  final IconData icon;
  final bool loading;
  final Future<void> Function()? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final foreground = foregroundColor ?? colors.text.withValues(alpha: 0.78);
    return Tooltip(
      message: tooltip,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(38, 38),
        onPressed: onPressed == null ? null : () => unawaited(onPressed!()),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: backgroundColor ?? colors.surface.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor ?? colors.text.withValues(alpha: 0.09),
            ),
          ),
          alignment: Alignment.center,
          child: loading
              ? CupertinoActivityIndicator(radius: 8, color: foreground)
              : Icon(icon, color: foreground, size: 21),
        ),
      ),
    );
  }
}

class _NativeFullscreenToggleButton extends StatelessWidget {
  const _NativeFullscreenToggleButton({
    required this.expanded,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
  });

  final bool expanded;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      label: expanded ? '退出全屏' : '进入全屏',
      button: true,
      child: ExcludeSemantics(
        child: Tooltip(
          message: expanded ? '退出全屏' : '全屏',
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(38, 38),
            onPressed: onPressed,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color:
                    backgroundColor ?? colors.surface.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: borderColor ?? colors.text.withValues(alpha: 0.09),
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                expanded
                    ? Icons.fullscreen_exit_rounded
                    : Icons.fullscreen_rounded,
                color: foregroundColor ?? colors.text.withValues(alpha: 0.78),
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NativeFullscreenVisual {
  const _NativeFullscreenVisual({
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.accent,
    required this.secondary,
    required this.ink,
    required this.stageTint,
    required this.chromeBackground,
    required this.chromeForeground,
    required this.chromeBorder,
    required this.shadow,
    required this.icon,
  });

  final Color backgroundTop;
  final Color backgroundBottom;
  final Color accent;
  final Color secondary;
  final Color ink;
  final Color stageTint;
  final Color chromeBackground;
  final Color chromeForeground;
  final Color chromeBorder;
  final Color shadow;
  final IconData icon;

  static _NativeFullscreenVisual forGame(String gameKey) => switch (gameKey) {
    _nativeGoGameKey => const _NativeFullscreenVisual(
      backgroundTop: Color(0xFFF3E8CB),
      backgroundBottom: Color(0xFFCDBA8C),
      accent: Color(0xFF416253),
      secondary: Color(0xFF202B27),
      ink: Color(0xFF30483D),
      stageTint: Color(0xFFD6C28F),
      chromeBackground: Color(0xEEF9F2DF),
      chromeForeground: Color(0xFF293A32),
      chromeBorder: Color(0x55416253),
      shadow: Color(0xFF594628),
      icon: Icons.circle_outlined,
    ),
    _nativeReversiGameKey => const _NativeFullscreenVisual(
      backgroundTop: Color(0xFF08241E),
      backgroundBottom: Color(0xFF11624B),
      accent: Color(0xFFD9B961),
      secondary: Color(0xFFF6F0DF),
      ink: Color(0xFF03110E),
      stageTint: Color(0xFF0E7257),
      chromeBackground: Color(0xEEF8F3E5),
      chromeForeground: Color(0xFF173B31),
      chromeBorder: Color(0x88D9B961),
      shadow: Color(0xFF001A13),
      icon: Icons.contrast_rounded,
    ),
    _nativeGomokuGameKey => const _NativeFullscreenVisual(
      backgroundTop: Color(0xFF4A2516),
      backgroundBottom: Color(0xFFAD7138),
      accent: Color(0xFFF0C56E),
      secondary: Color(0xFF17130F),
      ink: Color(0xFF2F190F),
      stageTint: Color(0xFFCB8C47),
      chromeBackground: Color(0xEEF9E9CA),
      chromeForeground: Color(0xFF3C2417),
      chromeBorder: Color(0x88F0C56E),
      shadow: Color(0xFF28140C),
      icon: Icons.grid_4x4_rounded,
    ),
    _nativeXiangqiGameKey => const _NativeFullscreenVisual(
      backgroundTop: Color(0xFF2D160F),
      backgroundBottom: Color(0xFF7B4125),
      accent: Color(0xFFE7B75D),
      secondary: Color(0xFFEBC98C),
      ink: Color(0xFF4A2416),
      stageTint: Color(0xFFB97738),
      chromeBackground: Color(0xEEF7E4BE),
      chromeForeground: Color(0xFF542D1D),
      chromeBorder: Color(0x88E7B75D),
      shadow: Color(0xFF1B0C08),
      icon: Icons.blur_circular_rounded,
    ),
    _nativeChessGameKey => const _NativeFullscreenVisual(
      backgroundTop: Color(0xFF17191E),
      backgroundBottom: Color(0xFF5F6269),
      accent: Color(0xFFD8B56D),
      secondary: Color(0xFFECE8DE),
      ink: Color(0xFF090B0E),
      stageTint: Color(0xFF5B5D63),
      chromeBackground: Color(0xEEF3EFE5),
      chromeForeground: Color(0xFF292B31),
      chromeBorder: Color(0x88D8B56D),
      shadow: Color(0xFF050608),
      icon: Icons.castle_outlined,
    ),
    _nativeChineseCheckersGameKey => const _NativeFullscreenVisual(
      backgroundTop: Color(0xFF102A3A),
      backgroundBottom: Color(0xFF2C5D62),
      accent: Color(0xFF68D6CB),
      secondary: Color(0xFFFFB65E),
      ink: Color(0xFF081A25),
      stageTint: Color(0xFF2E7471),
      chromeBackground: Color(0xEEF2F5EC),
      chromeForeground: Color(0xFF163B40),
      chromeBorder: Color(0x8868D6CB),
      shadow: Color(0xFF061923),
      icon: Icons.hub_outlined,
    ),
    _nativeMatch3GameKey => const _NativeFullscreenVisual(
      backgroundTop: Color(0xFF241633),
      backgroundBottom: Color(0xFF6A3159),
      accent: Color(0xFFFF6F91),
      secondary: Color(0xFF58D8D3),
      ink: Color(0xFF160D23),
      stageTint: Color(0xFF8D3D73),
      chromeBackground: Color(0xEEF8EDF4),
      chromeForeground: Color(0xFF4A2442),
      chromeBorder: Color(0x88FF8AAB),
      shadow: Color(0xFF170B21),
      icon: Icons.diamond_outlined,
    ),
    _nativeMinesweeperGameKey => const _NativeFullscreenVisual(
      backgroundTop: Color(0xFF1C2C3A),
      backgroundBottom: Color(0xFF607887),
      accent: Color(0xFFFFCA58),
      secondary: Color(0xFFFF776D),
      ink: Color(0xFF0D1820),
      stageTint: Color(0xFF557383),
      chromeBackground: Color(0xEEF1F4F3),
      chromeForeground: Color(0xFF2B3C46),
      chromeBorder: Color(0x88FFCA58),
      shadow: Color(0xFF0A131A),
      icon: Icons.flag_outlined,
    ),
    _nativeNumberMergeGameKey => const _NativeFullscreenVisual(
      backgroundTop: Color(0xFF173B38),
      backgroundBottom: Color(0xFF3A766B),
      accent: Color(0xFFFF8A66),
      secondary: Color(0xFFFFE1A8),
      ink: Color(0xFF0C2422),
      stageTint: Color(0xFF4B887A),
      chromeBackground: Color(0xEEF6F1DF),
      chromeForeground: Color(0xFF244A44),
      chromeBorder: Color(0x88FF9B79),
      shadow: Color(0xFF0B211E),
      icon: Icons.grid_view_rounded,
    ),
    _ => const _NativeFullscreenVisual(
      backgroundTop: Color(0xFF1A3F4B),
      backgroundBottom: Color(0xFF347B7B),
      accent: Color(0xFF7DE0D4),
      secondary: Color(0xFFFFD37B),
      ink: Color(0xFF0D252C),
      stageTint: Color(0xFF3C8584),
      chromeBackground: Color(0xEEF5F5EC),
      chromeForeground: Color(0xFF23484A),
      chromeBorder: Color(0x887DE0D4),
      shadow: Color(0xFF071B20),
      icon: Icons.sports_esports_outlined,
    ),
  };
}

class _NativeFullscreenBackdropPainter extends CustomPainter {
  const _NativeFullscreenBackdropPainter({
    required this.gameKey,
    required this.visual,
  });

  final String gameKey;
  final _NativeFullscreenVisual visual;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [visual.backgroundTop, visual.backgroundBottom],
        ).createShader(rect),
    );
    switch (gameKey) {
      case _nativeGoGameKey:
        _paintGo(canvas, size);
      case _nativeReversiGameKey:
        _paintReversi(canvas, size);
      case _nativeGomokuGameKey:
        _paintGomoku(canvas, size);
      case _nativeXiangqiGameKey:
        _paintXiangqi(canvas, size);
      case _nativeChessGameKey:
        _paintChess(canvas, size);
      case _nativeChineseCheckersGameKey:
        _paintChineseCheckers(canvas, size);
      case _nativeMatch3GameKey:
        _paintMatch3(canvas, size);
      case _nativeMinesweeperGameKey:
        _paintMinesweeper(canvas, size);
      case _nativeNumberMergeGameKey:
        _paintNumberMerge(canvas, size);
      default:
        _paintFallback(canvas, size);
    }
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.12),
          radius: 1.05,
          colors: [Colors.transparent, visual.shadow.withValues(alpha: 0.22)],
          stops: const [0.58, 1],
        ).createShader(rect),
    );
  }

  void _paintGo(Canvas canvas, Size size) {
    final fiber = Paint()
      ..color = visual.ink.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (var i = 0; i < 18; i++) {
      final y = size.height * (0.04 + i * 0.057);
      canvas.drawLine(
        Offset(-20, y),
        Offset(size.width + 20, y + math.sin(i * 1.7) * 8),
        fiber,
      );
    }
    final board = Rect.fromLTWH(
      size.width * 0.5,
      size.height * 0.08,
      size.width * 0.72,
      size.width * 0.72,
    );
    _drawGrid(canvas, board, 9, 9, visual.ink.withValues(alpha: 0.18));
    for (final point in const [Offset(0.25, 0.25), Offset(0.5, 0.5)]) {
      canvas.drawCircle(
        Offset(
          board.left + board.width * point.dx,
          board.top + board.height * point.dy,
        ),
        3,
        Paint()..color = visual.ink.withValues(alpha: 0.25),
      );
    }
    _drawDisc(
      canvas,
      Offset(size.width * 0.9, size.height * 0.17),
      size.width * 0.13,
      const Color(0xFF171B19),
      const Color(0xFF607269),
    );
    _drawDisc(
      canvas,
      Offset(size.width * 0.66, size.height * 0.75),
      size.width * 0.1,
      const Color(0xFFF3EEE1),
      const Color(0xFFC9BEA6),
    );
    final brush = Paint()
      ..color = visual.ink.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 9;
    final path = Path()
      ..moveTo(-30, size.height * 0.84)
      ..cubicTo(
        size.width * 0.18,
        size.height * 0.76,
        size.width * 0.24,
        size.height * 0.98,
        size.width * 0.52,
        size.height * 0.9,
      );
    canvas.drawPath(path, brush);
  }

  void _paintReversi(Canvas canvas, Size size) {
    final line = Paint()
      ..color = visual.secondary.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    final cell = size.width / 6;
    for (var x = -2; x < 9; x++) {
      canvas.drawLine(
        Offset(x * cell, 0),
        Offset(x * cell + size.height * 0.28, size.height),
        line,
      );
    }
    for (var y = 0; y < 14; y++) {
      canvas.drawLine(Offset(0, y * cell), Offset(size.width, y * cell), line);
    }
    final rail = Paint()
      ..color = visual.accent.withValues(alpha: 0.26)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(size.width * 0.08, 0),
      Offset(size.width * 0.92, size.height),
      rail,
    );
    _drawDisc(
      canvas,
      Offset(size.width * 0.09, size.height * 0.28),
      size.width * 0.17,
      const Color(0xFFF5F0E4),
      const Color(0xFFCBC2AC),
    );
    _drawDisc(
      canvas,
      Offset(size.width * 0.93, size.height * 0.74),
      size.width * 0.2,
      const Color(0xFF090E0C),
      const Color(0xFF41534D),
    );
  }

  void _paintGomoku(Canvas canvas, Size size) {
    final grain = Paint()
      ..color = visual.accent.withValues(alpha: 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < 12; i++) {
      final y = size.height * (i / 11);
      final wave = math.sin(i * 1.31) * size.width * 0.08;
      final path = Path()
        ..moveTo(-30, y)
        ..cubicTo(
          size.width * 0.22,
          y + wave,
          size.width * 0.7,
          y - wave,
          size.width + 30,
          y + wave * 0.25,
        );
      canvas.drawPath(path, grain);
    }
    final board = Rect.fromLTWH(
      -size.width * 0.08,
      size.height * 0.56,
      size.width * 1.16,
      size.width * 1.16,
    );
    _drawGrid(canvas, board, 11, 11, visual.secondary.withValues(alpha: 0.25));
    for (final point in const [Offset(0.27, 0.27), Offset(0.73, 0.27)]) {
      canvas.drawCircle(
        Offset(
          board.left + board.width * point.dx,
          board.top + board.height * point.dy,
        ),
        3,
        Paint()..color = visual.secondary.withValues(alpha: 0.3),
      );
    }
    _drawDisc(
      canvas,
      Offset(size.width * 0.12, size.height * 0.76),
      size.width * 0.11,
      const Color(0xFF0D1010),
      const Color(0xFF4D514F),
    );
    _drawDisc(
      canvas,
      Offset(size.width * 0.85, size.height * 0.88),
      size.width * 0.13,
      const Color(0xFFF4ECDD),
      const Color(0xFFCBBEAA),
    );
  }

  void _paintXiangqi(Canvas canvas, Size size) {
    final grain = Paint()
      ..color = visual.secondary.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (var index = 0; index < 15; index += 1) {
      final x = size.width * (index + 0.4) / 15;
      final wave = math.sin(index * 1.47) * size.width * 0.035;
      canvas.drawPath(
        Path()
          ..moveTo(x, -10)
          ..cubicTo(
            x + wave,
            size.height * 0.3,
            x - wave,
            size.height * 0.7,
            x + wave * 0.2,
            size.height + 10,
          ),
        grain,
      );
    }
    final board = Rect.fromLTWH(
      -size.width * 0.06,
      size.height * 0.09,
      size.width * 1.12,
      size.height * 0.82,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(board, const Radius.circular(26)),
      Paint()..color = visual.secondary.withValues(alpha: 0.13),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(board, const Radius.circular(26)),
      Paint()
        ..color = visual.accent.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final gridRect = board.deflate(size.width * 0.07);
    _drawGrid(
      canvas,
      gridRect,
      9,
      10,
      visual.secondary.withValues(alpha: 0.18),
    );
    final riverY = board.top + board.height * 0.5;
    canvas.drawRect(
      Rect.fromLTWH(board.left, riverY - 26, board.width, 52),
      Paint()..color = visual.backgroundTop.withValues(alpha: 0.44),
    );
    _drawText(
      canvas,
      '楚 河',
      Offset(board.left + board.width * 0.13, riverY - 15),
      22,
      visual.secondary.withValues(alpha: 0.3),
      FontWeight.w900,
    );
    _drawText(
      canvas,
      '汉 界',
      Offset(board.left + board.width * 0.62, riverY - 15),
      22,
      visual.secondary.withValues(alpha: 0.3),
      FontWeight.w900,
    );
    final studPaint = Paint()..color = visual.accent.withValues(alpha: 0.48);
    for (var index = 0; index < 9; index += 1) {
      final x = size.width * (index + 0.5) / 9;
      canvas.drawCircle(Offset(x, board.top + 9), 3.2, studPaint);
      canvas.drawCircle(Offset(x, board.bottom - 9), 3.2, studPaint);
    }
  }

  void _paintChess(Canvas canvas, Size size) {
    final tile = size.width / 4;
    final light = Paint()..color = visual.secondary.withValues(alpha: 0.08);
    for (var row = -1; row < size.height / tile + 2; row++) {
      for (var column = 0; column < 5; column++) {
        if ((row + column).isEven) {
          canvas.drawRect(
            Rect.fromLTWH(column * tile, row * tile, tile, tile),
            light,
          );
        }
      }
    }
    final gold = Paint()
      ..color = visual.accent.withValues(alpha: 0.28)
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(-20, size.height * 0.25),
      Offset(size.width + 20, size.height * 0.05),
      gold,
    );
    canvas.drawLine(
      Offset(-20, size.height * 0.92),
      Offset(size.width + 20, size.height * 0.72),
      gold,
    );
    _drawText(
      canvas,
      '♞',
      Offset(size.width * 0.63, size.height * 0.66),
      size.width * 0.42,
      visual.secondary.withValues(alpha: 0.1),
      FontWeight.w400,
    );
  }

  void _paintChineseCheckers(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final outer = size.width * 0.48;
    final star = Path();
    for (var i = 0; i < 12; i++) {
      final radius = i.isEven ? outer : outer * 0.48;
      final angle = -math.pi / 2 + i * math.pi / 6;
      final point = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      if (i == 0) {
        star.moveTo(point.dx, point.dy);
      } else {
        star.lineTo(point.dx, point.dy);
      }
    }
    star.close();
    canvas.drawPath(
      star,
      Paint()
        ..color = visual.accent.withValues(alpha: 0.09)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      star,
      Paint()
        ..color = visual.accent.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final marbleColors = [
      visual.accent,
      visual.secondary,
      const Color(0xFFFF746A),
    ];
    for (var ring = 1; ring <= 3; ring++) {
      for (var i = 0; i < 6; i++) {
        final angle = -math.pi / 2 + i * math.pi / 3;
        final point = Offset(
          center.dx + math.cos(angle) * outer * ring / 3,
          center.dy + math.sin(angle) * outer * ring / 3,
        );
        _drawDisc(
          canvas,
          point,
          7 + ring * 1.4,
          marbleColors[(i + ring) % marbleColors.length].withValues(alpha: 0.5),
          Colors.white.withValues(alpha: 0.24),
        );
      }
    }
  }

  void _paintMatch3(Canvas canvas, Size size) {
    final gems = <({Offset center, double radius, int sides, Color color})>[
      (
        center: Offset(size.width * 0.08, size.height * 0.2),
        radius: size.width * 0.16,
        sides: 6,
        color: visual.secondary,
      ),
      (
        center: Offset(size.width * 0.92, size.height * 0.32),
        radius: size.width * 0.2,
        sides: 5,
        color: visual.accent,
      ),
      (
        center: Offset(size.width * 0.13, size.height * 0.8),
        radius: size.width * 0.18,
        sides: 4,
        color: const Color(0xFFFFBE4C),
      ),
      (
        center: Offset(size.width * 0.88, size.height * 0.86),
        radius: size.width * 0.15,
        sides: 6,
        color: const Color(0xFF9D77FF),
      ),
    ];
    for (final gem in gems) {
      final path = _polygon(gem.center, gem.radius, gem.sides, -math.pi / 2);
      canvas.drawPath(path, Paint()..color = gem.color.withValues(alpha: 0.15));
      canvas.drawPath(
        path,
        Paint()
          ..color = gem.color.withValues(alpha: 0.34)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      for (var i = 0; i < gem.sides; i++) {
        final angle = -math.pi / 2 + i * math.pi * 2 / gem.sides;
        canvas.drawLine(
          gem.center,
          Offset(
            gem.center.dx + math.cos(angle) * gem.radius,
            gem.center.dy + math.sin(angle) * gem.radius,
          ),
          Paint()..color = Colors.white.withValues(alpha: 0.08),
        );
      }
    }
    for (final point in [
      Offset(size.width * 0.24, size.height * 0.38),
      Offset(size.width * 0.78, size.height * 0.62),
    ]) {
      final sparkle = Paint()
        ..color = Colors.white.withValues(alpha: 0.34)
        ..strokeWidth = 2;
      canvas.drawLine(
        point - const Offset(0, 12),
        point + const Offset(0, 12),
        sparkle,
      );
      canvas.drawLine(
        point - const Offset(12, 0),
        point + const Offset(12, 0),
        sparkle,
      );
    }
  }

  void _paintMinesweeper(Canvas canvas, Size size) {
    final cell = size.width / 7;
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (var x = 0; x <= 7; x++) {
      canvas.drawLine(Offset(x * cell, 0), Offset(x * cell, size.height), grid);
    }
    for (var y = 0; y <= size.height / cell + 1; y++) {
      canvas.drawLine(Offset(0, y * cell), Offset(size.width, y * cell), grid);
    }
    _drawMine(
      canvas,
      Offset(size.width * 0.13, size.height * 0.2),
      size.width * 0.08,
    );
    _drawMine(
      canvas,
      Offset(size.width * 0.88, size.height * 0.72),
      size.width * 0.11,
    );
    final pole = Paint()
      ..color = visual.secondary.withValues(alpha: 0.45)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final flagPoint = Offset(size.width * 0.75, size.height * 0.2);
    canvas.drawLine(flagPoint, flagPoint + const Offset(0, 65), pole);
    canvas.drawPath(
      Path()
        ..moveTo(flagPoint.dx, flagPoint.dy)
        ..lineTo(flagPoint.dx + 48, flagPoint.dy + 15)
        ..lineTo(flagPoint.dx, flagPoint.dy + 32)
        ..close(),
      Paint()..color = visual.secondary.withValues(alpha: 0.38),
    );
  }

  void _paintNumberMerge(Canvas canvas, Size size) {
    final tiles = <({Offset center, String label, Color color, double scale})>[
      (
        center: Offset(size.width * 0.12, size.height * 0.18),
        label: '2',
        color: visual.secondary,
        scale: 1,
      ),
      (
        center: Offset(size.width * 0.88, size.height * 0.28),
        label: '4',
        color: visual.accent,
        scale: 1.2,
      ),
      (
        center: Offset(size.width * 0.16, size.height * 0.78),
        label: '8',
        color: const Color(0xFF6CD6C6),
        scale: 1.25,
      ),
      (
        center: Offset(size.width * 0.84, size.height * 0.86),
        label: '16',
        color: const Color(0xFFFFC55F),
        scale: 1.4,
      ),
    ];
    for (final tile in tiles) {
      final side = size.width * 0.18 * tile.scale;
      final rect = Rect.fromCenter(
        center: tile.center,
        width: side,
        height: side,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(side * 0.2)),
        Paint()..color = tile.color.withValues(alpha: 0.2),
      );
      _drawText(
        canvas,
        tile.label,
        Offset(tile.center.dx - side * 0.18, tile.center.dy - side * 0.2),
        side * 0.34,
        Colors.white.withValues(alpha: 0.42),
        FontWeight.w900,
      );
    }
    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.48)
      ..lineTo(size.width * 0.42, size.height * 0.48)
      ..lineTo(size.width * 0.42, size.height * 0.42)
      ..lineTo(size.width * 0.58, size.height * 0.5)
      ..lineTo(size.width * 0.42, size.height * 0.58)
      ..lineTo(size.width * 0.42, size.height * 0.52)
      ..lineTo(size.width * 0.2, size.height * 0.52)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = visual.accent.withValues(alpha: 0.2),
    );
  }

  void _paintFallback(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (var i = 0; i < 12; i++) {
      canvas.drawLine(
        Offset(0, size.height * i / 11),
        Offset(size.width, size.height * i / 11),
        line,
      );
    }
  }

  void _drawGrid(Canvas canvas, Rect rect, int columns, int rows, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var i = 0; i < columns; i++) {
      final x = rect.left + rect.width * i / (columns - 1);
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint);
    }
    for (var i = 0; i < rows; i++) {
      final y = rect.top + rect.height * i / (rows - 1);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
    }
  }

  void _drawDisc(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    Color rim,
  ) {
    canvas.drawCircle(
      center + Offset(0, radius * 0.12),
      radius * 1.03,
      Paint()..color = visual.shadow.withValues(alpha: 0.24),
    );
    canvas.drawCircle(center, radius, Paint()..color = rim);
    canvas.drawCircle(center, radius * 0.88, Paint()..color = color);
    canvas.drawOval(
      Rect.fromCenter(
        center: center - Offset(radius * 0.22, radius * 0.28),
        width: radius * 0.62,
        height: radius * 0.28,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
  }

  void _drawMine(Canvas canvas, Offset center, double radius) {
    final paint = Paint()..color = visual.accent.withValues(alpha: 0.33);
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      canvas.drawLine(
        Offset(
          center.dx + math.cos(angle) * radius * 0.72,
          center.dy + math.sin(angle) * radius * 0.72,
        ),
        Offset(
          center.dx + math.cos(angle) * radius * 1.35,
          center.dy + math.sin(angle) * radius * 1.35,
        ),
        paint..strokeWidth = 4,
      );
    }
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(
      center - Offset(radius * 0.24, radius * 0.24),
      radius * 0.16,
      Paint()..color = Colors.white.withValues(alpha: 0.26),
    );
  }

  Path _polygon(Offset center, double radius, int sides, double rotation) {
    final path = Path();
    for (var i = 0; i < sides; i++) {
      final angle = rotation + math.pi * 2 * i / sides;
      final point = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
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

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    double fontSize,
    Color color,
    FontWeight fontWeight,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: 0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_NativeFullscreenBackdropPainter oldDelegate) =>
      oldDelegate.gameKey != gameKey || oldDelegate.visual != visual;
}
