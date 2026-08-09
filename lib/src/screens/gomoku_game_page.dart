part of 'package:companion_flutter/main.dart';

class _NativeGomokuGamePage extends StatefulWidget {
  const _NativeGomokuGamePage({
    required this.api,
    required this.authSession,
    required this.game,
  });

  final CompanionApi api;
  final AuthSession authSession;
  final _GameTile game;

  @override
  State<_NativeGomokuGamePage> createState() => _NativeGomokuGamePageState();
}

class _NativeGomokuGamePageState extends State<_NativeGomokuGamePage> {
  late final _NativeGameRuntime _runtime;
  GomokuEngine? _engine;
  // Non-null once the round ends (win/lose): the full-screen result replaces
  // the game (like reversi), so the board / avatars / turn countdown are torn
  // down rather than left running behind an overlay.
  _GomokuResultKind? _result;
  Timer? _resultTimer;

  String get _agentName => _runtime.agentName;

  @override
  void initState() {
    super.initState();
    _runtime = _NativeGameRuntime(
      api: widget.api,
      authSession: widget.authSession,
      gameKey: _nativeGomokuGameKey,
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
    unawaited(_runtime.initialize());
  }

  @override
  void dispose() {
    _resultTimer?.cancel();
    _runtime.dispose();
    unawaited(
      _runtime.abort(
        'page_closed',
        _engine?.summaryJson() ?? const {},
        updateUi: false,
      ),
    );
    super.dispose();
  }

  Future<void> _startGame() async {
    final current = _engine;
    if (_runtime.session != null && !_runtime.completed) {
      await _runtime.abort('restarted', current?.summaryJson() ?? const {});
    }
    final session = await _runtime.start({
      'board_size': GomokuEngine.boardSize,
      'first_actor': 'user',
    });
    _resultTimer?.cancel();
    _resultTimer = null;
    if (session == null || !mounted) return;
    setState(() {
      _result = null;
      _engine = GomokuEngine(
        aiConfig: GomokuAiConfig.fromJson(session.engineConfig),
      );
    });
  }

  Future<void> _closeGame() async {
    final engine = _engine;
    if (_runtime.session != null && !_runtime.completed) {
      await _runtime.abort(
        _runtime.turnTimeoutVisible ? 'turn_timeout_ended' : 'closed',
        engine?.summaryJson() ?? const {},
      );
    }
    _runtime.clearPresentation();
    _resultTimer?.cancel();
    _resultTimer = null;
    if (!mounted) return;
    setState(() {
      _result = null;
      _engine = null;
    });
  }

  /// Quitting or restarting mid-game counts as a loss: settle the round so the
  /// score is deducted, then show the 失败 result screen (its buttons then do
  /// the real exit / restart). No-op if the round already ended or settled.
  Future<void> _forfeit() async {
    if (_result != null || _engine == null || _runtime.completed) return;
    setState(() => _result = _GomokuResultKind.lose);
    await _finishGame(GomokuGameStatus.agentWon);
  }

  Future<void> _handleBoardTap(GomokuPoint point) async {
    final engine = _engine;
    if (engine == null ||
        engine.isFinished ||
        _runtime.aiThinking ||
        _runtime.starting) {
      return;
    }
    try {
      final result = engine.place(point, GomokuActor.user);
      _NativeGameHaptics.placement(keyMoment: result.move.moment != null);
      if (mounted) setState(() {});
      await _reportMove(result.move);
      if (result.status != GomokuGameStatus.playing) {
        await _finishGame(result.status);
        return;
      }
      await _playAgentTurn();
    } on StateError catch (error) {
      final code = error.message.toString();
      if (code == 'occupied_position') {
        _NativeGameHaptics.rejected();
        _runtime.showNotice('这里已经有棋子了，换一个交叉点。');
        unawaited(
          _runtime.reportEvent(
            'invalid_move',
            payload: {'reason': code, 'row': point.row, 'col': point.col},
          ),
        );
      }
    }
  }

  Future<void> _playAgentTurn() async {
    final engine = _engine;
    if (engine == null || engine.isFinished) return;
    final sw = Stopwatch()..start();
    setState(() => _runtime.aiThinking = true);
    await _runtime.reportEvent(
      'ai_thinking_started',
      payload: {
        'move_number': engine.moves.length + 1,
        'play_style': 'natural_companion',
        'analysis': engine.analyze().toJson(),
      },
    );
    if (!mounted || engine.isFinished) return;
    final decision = await engine.chooseAiMove();
    // The search suspends this method; the round may have been restarted
    // (fresh engine) or the page disposed while the isolate was thinking.
    if (!mounted || !identical(engine, _engine) || engine.isFinished) return;
    await _runtime.reportEvent(
      'ai_move_decided',
      payload: {...decision.toJson(), 'play_style': 'natural_companion'},
    );
    await _runtime.paceAiMove(sw);
    if (!mounted || !identical(engine, _engine) || engine.isFinished) return;
    final result = engine.place(
      decision.point,
      GomokuActor.agent,
      decision: decision,
    );
    _NativeGameHaptics.placement(keyMoment: result.move.moment != null);
    if (mounted) setState(() => _runtime.aiThinking = false);
    await _reportMove(result.move);
    if (result.status != GomokuGameStatus.playing) {
      await _finishGame(result.status);
    }
  }

  Future<void> _reportMove(GomokuMove move) async {
    await _runtime.reportEvent(
      'move_placed',
      state: 'playing',
      payload: move.toJson(),
    );
    if (move.moment != null) {
      await _runtime.reportEvent(
        'threat_detected',
        payload: {
          ...move.moment!,
          'move_number': move.number,
          'actor': move.actor.name,
          'row': move.point.row,
          'col': move.point.col,
          'analysis': move.analysis.toJson(),
        },
      );
    }
  }

  Future<void> _finishGame(GomokuGameStatus status) async {
    final engine = _engine;
    if (engine == null || _runtime.completed) return;
    if (mounted) setState(() => _runtime.aiThinking = false);
    final summary = engine.summaryJson();
    await _runtime.finish({
      ...summary,
      'user_outcome': switch (status) {
        GomokuGameStatus.userWon => 'win',
        GomokuGameStatus.agentWon => 'lose',
        GomokuGameStatus.draw => 'draw',
        GomokuGameStatus.playing => 'draw',
      },
      'analysis': engine.analyze().toJson(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final engine = _engine;
    // When a round ends naturally, hold the final board briefly, then reveal
    // the full-screen result (win for the user, otherwise loss).
    if (engine != null &&
        engine.isFinished &&
        _result == null &&
        _resultTimer == null) {
      final win = engine.status == GomokuGameStatus.userWon;
      _resultTimer = Timer(const Duration(milliseconds: 1400), () {
        if (!mounted || _result != null) return;
        setState(
          () => _result = win ? _GomokuResultKind.win : _GomokuResultKind.lose,
        );
      });
    }

    final Widget child;
    if (engine == null) {
      // Before a round starts, show the illustrated Gomoku home (1:1 with the
      // game-art design). Starting a game replaces it with the board surface.
      child = _GomokuHome(
        key: const ValueKey('gomoku-home'),
        rounds: _runtime.rounds,
        starting: _runtime.starting,
        error: _runtime.error,
        onStart: _startGame,
        onExit: () => Navigator.of(context).maybePop(),
      );
    } else if (_result != null) {
      // Full-screen result replaces the game (board / avatars / countdown are
      // torn down), so nothing keeps running behind it.
      child = _GomokuResultScreen(
        key: const ValueKey('gomoku-result'),
        kind: _result!,
        pointsDelta: _runtime.pointRules?.deltaFor(
          _result == _GomokuResultKind.win
              ? GameOutcome.win
              : GameOutcome.lose,
        ),
        onRestart: _startGame,
        onExit: _closeGame,
      );
    } else {
      child = PopScope(
        // An active round can only be left through the in-game exit/pause UI.
        // This also disables the iOS edge-swipe back gesture.
        key: const ValueKey('gomoku-game'),
        canPop: false,
        child: _GomokuGameScreen(
          engine: engine,
          agentName: _agentName,
          userName: widget.authSession.userFacingName,
          agentAvatarUrl: widget.authSession.agentAvatarUrl,
          userAvatarUrl: widget.authSession.userAvatarUrl,
          aiThinking: _runtime.aiThinking,
          starting: _runtime.starting,
          syncNotice: _runtime.syncNotice,
          onPointTap: _handleBoardTap,
          // Quitting / restarting mid-game counts as a loss (design note).
          onShowLose: _forfeit,
          bannerInMs: _runtime.bannerInMs,
          bannerHoldMs: _runtime.bannerHoldMs,
          bannerOutMs: _runtime.bannerOutMs,
          gamePoints: _runtime.pointsBalance,
        ),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: child,
    );
  }
}

class _GomokuBoard extends StatefulWidget {
  const _GomokuBoard({
    required this.engine,
    required this.enabled,
    required this.onPointTap,
  });

  final GomokuEngine engine;
  final bool enabled;
  final ValueChanged<GomokuPoint> onPointTap;

  @override
  State<_GomokuBoard> createState() => _GomokuBoardState();
}

class _GomokuBoardState extends State<_GomokuBoard>
    with TickerProviderStateMixin {
  late final AnimationController _placement;
  late int _lastMoveCount;
  GomokuPoint? _previewPoint;

  @override
  void initState() {
    super.initState();
    _placement = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: 1,
    );
    _lastMoveCount = widget.engine.moves.length;
  }

  @override
  void didUpdateWidget(covariant _GomokuBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_lastMoveCount != widget.engine.moves.length) {
      _lastMoveCount = widget.engine.moves.length;
      _placement.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _placement.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final geometry = _GomokuBoardGeometry(size);
        return AnimatedBuilder(
          animation: _placement,
          builder: (context, _) {
            final progress = Curves.easeOutBack.transform(_placement.value);
            final lastMove = widget.engine.moves.isEmpty
                ? null
                : widget.engine.moves.last.point;
            final preview =
                _previewPoint != null &&
                    widget.engine.board[_previewPoint!.row][_previewPoint!
                            .col] ==
                        GomokuStone.empty
                ? _previewPoint
                : null;
            return Semantics(
              label: '十五乘十五五子棋棋盘',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: widget.enabled
                    ? (details) => setState(() {
                        _previewPoint = _pointForOffset(
                          details.localPosition,
                          geometry,
                        );
                      })
                    : null,
                onTapCancel: widget.enabled
                    ? () => setState(() => _previewPoint = null)
                    : null,
                onTapUp: widget.enabled
                    ? (details) {
                        final point = _pointForOffset(
                          details.localPosition,
                          geometry,
                        );
                        setState(() => _previewPoint = null);
                        if (point != null) widget.onPointTap(point);
                      }
                    : null,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _GomokuBoardPainter(
                          previewPoint: preview,
                          winningLine: widget.engine.winningLine,
                          placementProgress: progress,
                        ),
                      ),
                    ),
                    for (var row = 0; row < GomokuEngine.boardSize; row += 1)
                      for (var col = 0; col < GomokuEngine.boardSize; col += 1)
                        if (widget.engine.board[row][col] != GomokuStone.empty)
                          _GomokuStoneSprite(
                            point: GomokuPoint(row, col),
                            stone: widget.engine.board[row][col],
                            geometry: geometry,
                            scale: lastMove == GomokuPoint(row, col)
                                ? progress.clamp(0.05, 1.08)
                                : 1,
                          ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  GomokuPoint? _pointForOffset(Offset offset, _GomokuBoardGeometry geometry) {
    final col = ((offset.dx - geometry.left) / geometry.cellWidth).round();
    final row = ((offset.dy - geometry.top) / geometry.cellHeight).round();
    if (row < 0 ||
        row >= GomokuEngine.boardSize ||
        col < 0 ||
        col >= GomokuEngine.boardSize) {
      return null;
    }
    final center = geometry.offset(GomokuPoint(row, col));
    if ((center - offset).distance > geometry.stoneSize * 0.62) return null;
    return GomokuPoint(row, col);
  }
}

/// Grid bounds measured from the exported 1050×1113 Figma board artwork.
class _GomokuBoardGeometry {
  const _GomokuBoardGeometry(this.size);

  final Size size;

  double get left => size.width * (46 / 1050);
  double get right => size.width * (1006 / 1050);
  double get top => size.height * (42 / 1113);
  double get bottom => size.height * (1041 / 1113);
  double get cellWidth => (right - left) / (GomokuEngine.boardSize - 1);
  double get cellHeight => (bottom - top) / (GomokuEngine.boardSize - 1);
  double get stoneSize => math.min(cellWidth, cellHeight) * 0.9;

  Offset offset(GomokuPoint point) =>
      Offset(left + point.col * cellWidth, top + point.row * cellHeight);
}

class _GomokuStoneSprite extends StatelessWidget {
  const _GomokuStoneSprite({
    required this.point,
    required this.stone,
    required this.geometry,
    required this.scale,
  });

  final GomokuPoint point;
  final GomokuStone stone;
  final _GomokuBoardGeometry geometry;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final diameter = geometry.stoneSize;
    final center = geometry.offset(point);
    final asset = stone == GomokuStone.black
        ? '${_gomokuHomeAsset}game_stone_black.svg'
        : '${_gomokuHomeAsset}game_stone_white.svg';
    return Positioned(
      left: center.dx - diameter / 2,
      top: center.dy - diameter / 2,
      width: diameter,
      height: diameter,
      child: Transform.scale(
        scale: scale,
        child: SvgPicture.asset(asset, fit: BoxFit.contain),
      ),
    );
  }
}

class _GomokuBoardPainter extends CustomPainter {
  const _GomokuBoardPainter({
    required this.previewPoint,
    required this.winningLine,
    required this.placementProgress,
  });

  final GomokuPoint? previewPoint;
  final List<GomokuPoint> winningLine;
  final double placementProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _GomokuBoardGeometry(size);
    final gridRect = Rect.fromLTRB(
      geometry.left,
      geometry.top,
      geometry.right,
      geometry.bottom,
    );

    // Vignette: the board wood darkens toward the edges/corners (design 2:3).
    canvas.drawRect(
      gridRect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment.center,
          radius: 0.82,
          colors: [
            Color(0x00000000),
            Color(0x00000000),
            Color(0x3D4A240F),
          ],
          stops: [0.0, 0.5, 1.0],
        ).createShader(gridRect),
    );

    // Thin interior grid lines (the outer edges are drawn by the bold border).
    final line = Paint()
      ..color = const Color(0xFF5A2D16).withValues(alpha: 0.85)
      ..strokeWidth = math.max(0.8, size.width * (2.1 / 1050));
    for (var i = 1; i < GomokuEngine.boardSize - 1; i += 1) {
      final x = geometry.left + i * geometry.cellWidth;
      final y = geometry.top + i * geometry.cellHeight;
      canvas.drawLine(Offset(geometry.left, y), Offset(geometry.right, y), line);
      canvas.drawLine(Offset(x, geometry.top), Offset(x, geometry.bottom), line);
    }

    // Bold outer border framing the 15x15 grid.
    canvas.drawRect(
      gridRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.4, size.width * (6 / 1050))
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF4A2410),
    );

    if (previewPoint != null) {
      final center = geometry.offset(previewPoint!);
      canvas.drawCircle(
        center,
        geometry.stoneSize * 0.46,
        Paint()..color = const Color(0xFF292828).withValues(alpha: 0.28),
      );
      canvas.drawCircle(
        center,
        geometry.stoneSize * 0.50,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    if (winningLine.length >= 2) {
      final winPaint = Paint()
        ..color = const Color(0xFFFFD56A).withValues(alpha: 0.74)
        ..strokeWidth = geometry.stoneSize * 0.28
        ..strokeCap = StrokeCap.round;
      final start = geometry.offset(winningLine.first);
      final end = geometry.offset(winningLine.last);
      canvas.drawLine(
        start,
        Offset.lerp(start, end, placementProgress.clamp(0, 1))!,
        winPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GomokuBoardPainter oldDelegate) =>
      oldDelegate.previewPoint != previewPoint ||
      oldDelegate.winningLine != winningLine ||
      oldDelegate.placementProgress != placementProgress;
}

class _GomokuNotice extends StatelessWidget {
  const _GomokuNotice({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFD84A4A) : const Color(0xFFB8791D);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          height: 1.3,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ===========================================================================
// 五子棋首页 (illustrated game-art home, 1:1 with Figma). Positions are
// fractions measured from the design composite so overlays land exactly where
// the artwork expects them. Replace any PNG in
// assets/prototype/games/gomoku/ with a higher-res version (same name) and the
// layout stays identical.
// ===========================================================================

const String _gomokuHomeAsset = 'assets/prototype/games/gomoku/';

/// Subtle idle motion for decorative artwork only. Interactive controls and
/// gameplay geometry deliberately never use this wrapper.
class _GomokuBreathingMotion extends StatefulWidget {
  const _GomokuBreathingMotion({
    required this.child,
    this.duration = const Duration(milliseconds: 6000),
    this.scaleAmount = 0.008,
    this.translateY = 0,
    this.phase = 0,
  });

  final Widget child;
  final Duration duration;
  final double scaleAmount;
  final double translateY;
  final double phase;

  @override
  State<_GomokuBreathingMotion> createState() => _GomokuBreathingMotionState();
}

class _GomokuBreathingMotionState extends State<_GomokuBreathingMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool? _animationsDisabled;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: widget.phase.clamp(0, 1),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_animationsDisabled == disabled) return;
    _animationsDisabled = disabled;
    if (disabled) {
      _controller
        ..stop()
        ..value = 0;
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final progress = Curves.easeInOut.transform(_controller.value);
          return Transform.translate(
            offset: Offset(0, -widget.translateY * progress),
            child: Transform.scale(
              scale: 1 + widget.scaleAmount * progress,
              child: child,
            ),
          );
        },
      ),
    );
  }
}

class _GomokuHome extends StatelessWidget {
  const _GomokuHome({
    super.key,
    required this.rounds,
    required this.starting,
    required this.error,
    required this.onStart,
    required this.onExit,
  });

  final List<GameSession> rounds;
  final bool starting;
  final String? error;
  final Future<void> Function() onStart;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final summaries = rounds.map(_GameRoundSummary.fromSession).toList();
    final total = summaries.length;
    final wins = summaries.where((s) => s.isWin).length;
    final rate = total == 0 ? 0 : (wins / total * 100).round();
    final totalSeconds = summaries.fold<int>(
      0,
      (sum, s) => sum + (s.durationSeconds ?? 0),
    );

    return Scaffold(
      // Sky-toned fallback so the frame never flashes black before the bg
      // texture decodes.
      backgroundColor: const Color(0xFF9AD0EE),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return Stack(
            children: [
              Positioned.fill(
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 9500),
                  scaleAmount: 0.004,
                  child: Image.asset(
                    '${_gomokuHomeAsset}home_bg.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
              Positioned(
                left: w * 0.117,
                top: h * 0.103,
                width: w * 0.761,
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 4800),
                  scaleAmount: 0.009,
                  translateY: 2.2,
                  phase: 0.35,
                  child: Image.asset(
                    '${_gomokuHomeAsset}home_logo.png',
                    fit: BoxFit.fitWidth,
                  ),
                ),
              ),
              if (error != null)
                Positioned(
                  left: w * 0.08,
                  right: w * 0.08,
                  top: h * 0.64,
                  child: _GomokuNotice(text: error!, isError: true),
                ),
              Positioned(
                left: w * 0.072,
                top: h * 0.714,
                width: w * 0.379,
                child: _GomokuHomeButton(
                  base: '${_gomokuHomeAsset}home_btn_exit.png',
                  textAsset: '${_gomokuHomeAsset}home_btn_exit_text.png',
                  aspectRatio: 450 / 207,
                  onTap: starting ? null : onExit,
                ),
              ),
              Positioned(
                left: w * 0.548,
                top: h * 0.714,
                width: w * 0.381,
                child: _GomokuHomeButton(
                  base: '${_gomokuHomeAsset}home_btn_start.png',
                  textAsset: '${_gomokuHomeAsset}home_btn_start_text.png',
                  aspectRatio: 450 / 210,
                  loading: starting,
                  onTap: starting ? null : () => onStart(),
                ),
              ),
              Positioned(
                left: w * 0.030,
                top: h * 0.831,
                width: w * 0.938,
                child: _GomokuHomeStats(
                  total: '$total',
                  wins: '$wins',
                  rate: '$rate%',
                  duration: _formatDuration(totalSeconds),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0m';
    if (seconds >= 3600) {
      final hours = seconds / 3600;
      final text = hours == hours.truncateToDouble()
          ? hours.round().toString()
          : hours.toStringAsFixed(1);
      return '${text}H';
    }
    final minutes = (seconds / 60).ceil();
    return '${minutes}m';
  }
}

class _GomokuHomeButton extends StatefulWidget {
  const _GomokuHomeButton({
    required this.base,
    required this.textAsset,
    required this.aspectRatio,
    required this.onTap,
    this.loading = false,
  });

  final String base;
  final String textAsset;
  final double aspectRatio;
  final VoidCallback? onTap;
  final bool loading;

  @override
  State<_GomokuHomeButton> createState() => _GomokuHomeButtonState();
}

class _GomokuHomeButtonState extends State<_GomokuHomeButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null && !widget.loading;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.955 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Opacity(
          opacity: enabled ? 1 : 0.75,
          child: AspectRatio(
            aspectRatio: widget.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Image.asset(widget.base, fit: BoxFit.fill),
                ),
                // The text rides the raised button face, a hair above the
                // geometric center to clear the 3D bottom lip.
                if (widget.loading)
                  const Align(
                    alignment: Alignment(0, -0.14),
                    child: CupertinoActivityIndicator(color: Colors.white),
                  )
                else
                  Align(
                    alignment: const Alignment(0, -0.14),
                    child: FractionallySizedBox(
                      widthFactor: 0.62,
                      child: Image.asset(widget.textAsset, fit: BoxFit.contain),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GomokuHomeStats extends StatelessWidget {
  const _GomokuHomeStats({
    required this.total,
    required this.wins,
    required this.rate,
    required this.duration,
  });

  final String total;
  final String wins;
  final String rate;
  final String duration;

  // Exact horizontal bounds of the four inset squares in the 1110px-wide
  // frame. Explicit bounds + clipping prevent painted text strokes from ever
  // bleeding into a neighbouring statistic.
  static const List<(double, double)> _slots = [
    (46 / 1110, 280 / 1110),
    (305 / 1110, 542 / 1110),
    (567 / 1110, 803 / 1110),
    (828 / 1110, 1065 / 1110),
  ];

  @override
  Widget build(BuildContext context) {
    final labels = [
      '${_gomokuHomeAsset}stat_label_total.png',
      '${_gomokuHomeAsset}stat_label_wins.png',
      '${_gomokuHomeAsset}stat_label_rate.png',
      '${_gomokuHomeAsset}stat_label_time.png',
    ];
    final values = [total, wins, rate, duration];
    return AspectRatio(
      aspectRatio: 1110 / 336,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fw = constraints.maxWidth;
          final fh = constraints.maxHeight;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: Image.asset(
                  '${_gomokuHomeAsset}home_stats_frame.png',
                  fit: BoxFit.fill,
                ),
              ),
              for (var i = 0; i < 4; i += 1) ...[
                Positioned(
                  left: fw * _slots[i].$1,
                  top: fh * 0.20,
                  width: fw * (_slots[i].$2 - _slots[i].$1),
                  height: fh * 0.24,
                  child: ClipRect(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: fw * 0.008),
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Image.asset(labels[i]),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: fw * _slots[i].$1,
                  top: fh * 0.49,
                  width: fw * (_slots[i].$2 - _slots[i].$1),
                  height: fh * 0.30,
                  child: ClipRect(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: fw * 0.012),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _StrokeText(
                          text: values[i],
                          fontSize: fh * 0.225,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ===========================================================================
// 五子棋游戏界面 (illustrated game-art board screen, 1:1 with Figma). Canyon
// background, two framed avatars (user left + medal, agent right) whose frame
// glows on that player's turn, a warm wooden 15×15 board, and 退出/暂停.
// Positions are fractions measured from the 393×852 design frame.
// ===========================================================================

const String _gomokuGameBg = '${_gomokuHomeAsset}game_bg.png';
const String _gomokuNamePlate = '${_gomokuHomeAsset}game_name_plate.png';

class _GomokuGameScreen extends StatefulWidget {
  const _GomokuGameScreen({
    required this.engine,
    required this.agentName,
    required this.userName,
    required this.agentAvatarUrl,
    required this.userAvatarUrl,
    required this.aiThinking,
    required this.starting,
    required this.syncNotice,
    required this.onPointTap,
    required this.onShowLose,
    required this.bannerInMs,
    required this.bannerHoldMs,
    required this.bannerOutMs,
    required this.gamePoints,
  });

  final GomokuEngine engine;
  final String agentName;
  final String userName;
  final String? agentAvatarUrl;
  final String? userAvatarUrl;
  final bool aiThinking;
  final bool starting;
  final String? syncNotice;
  final ValueChanged<GomokuPoint> onPointTap;
  // Quitting / restarting mid-game → settle as a loss and show the 失败 screen.
  final Future<void> Function() onShowLose;
  // "你的回合" banner timing (ms), from the per-game admin config.
  final int bannerInMs;
  final int bannerHoldMs;
  final int bannerOutMs;
  // Current game points, shown in the top-right coin badge.
  final int? gamePoints;

  @override
  State<_GomokuGameScreen> createState() => _GomokuGameScreenState();
}

class _GomokuGameScreenState extends State<_GomokuGameScreen> {
  // True while a modal (pause / exit confirm) is open, so the turn countdown
  // freezes instead of ticking behind the dialog.
  bool _paused = false;

  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    final agentName = widget.agentName;
    final userName = widget.userName;
    final agentAvatarUrl = widget.agentAvatarUrl;
    final userAvatarUrl = widget.userAvatarUrl;
    final aiThinking = widget.aiThinking;
    final starting = widget.starting;
    final syncNotice = widget.syncNotice;
    final onPointTap = widget.onPointTap;
    final finished = engine.isFinished;
    final userTurn =
        !finished &&
        !aiThinking &&
        !starting &&
        engine.status == GomokuGameStatus.playing;
    final boardEnabled = userTurn;

    return Scaffold(
      backgroundColor: const Color(0xFFE7C9A6),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          // Figma outer avatar ring is 86px on a 393px frame; the inner image
          // is 80px, leaving a 3px ring on each side.
          final avatarD = w * (66 / 393);
          final plateW = w * (121 / 393);
          return Stack(
            children: [
              Positioned.fill(
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 10000),
                  scaleAmount: 0.006,
                  phase: 0.45,
                  child: Image.asset(_gomokuGameBg, fit: BoxFit.cover),
                ),
              ),

              // Both avatars sit at the same height (design 2:3). Each glows
              // and shows a 30s turn countdown while it is that player's turn.
              _centered(
                w,
                h,
                cx: 0.763,
                cy: 0.18,
                width: avatarD,
                child: _GomokuAvatar(
                  imageUrl: agentAvatarUrl,
                  fallback: agentName,
                  diameter: avatarD,
                  active: aiThinking,
                  paused: _paused,
                ),
              ),
              _centered(
                w,
                h,
                cx: 0.237,
                cy: 0.18,
                width: avatarD,
                child: _GomokuAvatar(
                  imageUrl: userAvatarUrl,
                  fallback: '你',
                  diameter: avatarD,
                  active: userTurn,
                  paused: _paused,
                  onTimeout: _handleUserIdleTimeout,
                ),
              ),
              // Name plates sit directly under each avatar, overlapping its
              // lower edge, with the player's stone colour shown as a chip.
              _centered(
                w,
                h,
                cx: 0.763,
                cy: 0.252,
                width: plateW,
                child: _GomokuNamePlate(
                  name: agentName,
                  stone: GomokuStone.white,
                  stoneOnRight: false,
                ),
              ),
              _centered(
                w,
                h,
                cx: 0.237,
                cy: 0.252,
                width: plateW,
                child: _GomokuNamePlate(
                  name: userName,
                  stone: GomokuStone.black,
                  stoneOnRight: true,
                ),
              ),

              // Board.
              _centered(
                w,
                h,
                cx: 0.501,
                cy: 0.539,
                width: w * 0.891,
                child: _GomokuDesignBoard(
                  engine: engine,
                  enabled: boardEnabled,
                  onPointTap: onPointTap,
                ),
              ),

              // "你的回合" ribbon — flashes in from the right, holds ~2s, then
              // slides out to the left whenever the user's turn begins.
              Positioned(
                left: 0,
                right: 0,
                top: h * 0.64 - (w * 0.13) / 2,
                height: w * 0.13,
                child: _TurnBanner(
                  userTurn: userTurn,
                  inMs: widget.bannerInMs,
                  holdMs: widget.bannerHoldMs,
                  outMs: widget.bannerOutMs,
                ),
              ),

              if (syncNotice != null)
                Positioned(
                  left: w * 0.08,
                  right: w * 0.08,
                  top: h * 0.70,
                  child: _GomokuNotice(text: syncNotice, isError: false),
                ),

              // Bottom buttons — nudged down from the board per the design.
              Positioned(
                left: w * 0.074,
                top: h * 0.804,
                width: w * 0.254,
                child: _GomokuGameButton(
                  base: '${_gomokuHomeAsset}home_btn_exit.png',
                  label: '退出',
                  onTap: () => _confirmExit(context),
                ),
              ),
              Positioned(
                left: w * 0.374,
                top: h * 0.804,
                width: w * 0.254,
                child: _GomokuGameButton(
                  base: '${_gomokuHomeAsset}home_btn_start.png',
                  label: '暂停',
                  onTap: () => _showPauseMenu(context),
                ),
              ),
              // Help (?) button on the right — opens the rules popup.
              _centered(
                w,
                h,
                cx: 0.910,
                cy: 0.829,
                width: w * 0.064,
                child: _GomokuHelpButton(onTap: () => _showRules(context)),
              ),
              _NativeGamePointsBadge(points: widget.gamePoints),
            ],
          );
        },
      ),
    );
  }

  // Places a fixed-aspect child so its center lands on (cx,cy) as a fraction of
  // the screen; height follows the child's own aspect via the width.
  Widget _centered(
    double w,
    double h, {
    required double cx,
    required double cy,
    required double width,
    required Widget child,
  }) {
    return Positioned(
      left: w * cx - width / 2,
      top: h * cy,
      width: width,
      child: FractionalTranslation(
        translation: const Offset(0, -0.5),
        child: child,
      ),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    setState(() => _paused = true);
    await _showGomokuModal(
      context,
      title: '退出对局',
      message: '当前这盘还没下完，退出后进度会清空。确定要退出吗？',
      actions: (dialogContext) => [
        Expanded(
          child: _GomokuGameButton(
            base: '${_gomokuHomeAsset}home_btn_start.png',
            label: '再想想',
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GomokuGameButton(
            base: '${_gomokuHomeAsset}home_btn_exit.png',
            label: '退出',
            onTap: () {
              Navigator.of(dialogContext).pop();
              // Quitting mid-game → 失败 + 扣分; the 失败 screen's 退出 then leaves.
              unawaited(widget.onShowLose());
            },
          ),
        ),
      ],
    );
    if (mounted) setState(() => _paused = false);
  }

  // The turn countdown ran out while the user hadn't moved — surface the pause
  // menu automatically (replaces the old idle-timeout prompt).
  void _handleUserIdleTimeout() {
    if (!mounted || _paused || widget.engine.isFinished) return;
    unawaited(_showPauseMenu(context));
  }

  Future<void> _showPauseMenu(BuildContext context) async {
    setState(() => _paused = true);
    await _showGomokuModal(
      context,
      title: '游戏暂停',
      message: '要继续当前对局，还是重新开一盘？',
      actions: (dialogContext) => [
        Expanded(
          child: _GomokuGameButton(
            base: '${_gomokuHomeAsset}home_btn_start.png',
            label: '继续',
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GomokuGameButton(
            base: '${_gomokuHomeAsset}home_btn_exit.png',
            label: '重新开局',
            onTap: () {
              Navigator.of(dialogContext).pop();
              // Restarting mid-game → 失败 + 扣分; the 失败 screen's 重来一局 then
              // starts the new round.
              unawaited(widget.onShowLose());
            },
          ),
        ),
      ],
    );
    if (mounted) setState(() => _paused = false);
  }

  // Rules popup — pauses the turn dial while open (no pause dialog), resumes on
  // close.
  Future<void> _showRules(BuildContext context) async {
    setState(() => _paused = true);
    await _showGameRulesDialog(
      context,
      gameName: '五子棋',
      rules: const [
        '1、黑白双方交替落子',
        '2、率先横向 / 竖向 / 斜向连成五子直接获胜',
        '3、棋盘布满无五子则平局',
      ],
    );
    if (mounted) setState(() => _paused = false);
  }
}

/// Custom game-art modal (cream wood card + gold border) shown centered, used
/// for the exit confirm and pause menu so we never fall back to a system sheet.
Future<void> _showGomokuModal(
  BuildContext context, {
  required String title,
  String? message,
  required List<Widget> Function(BuildContext dialogContext) actions,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, _, __) {
      final rowActions = actions(dialogContext);
      return Center(
        child: _GomokuModalCard(
          title: title,
          message: message,
          child: Row(children: rowActions),
        ),
      );
    },
    transitionBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.86, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _GomokuModalCard extends StatelessWidget {
  const _GomokuModalCard({
    required this.title,
    required this.message,
    required this.child,
  });

  final String title;
  final String? message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: w * 0.13),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFDF6E9), Color(0xFFF3E4C9)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE0B072), width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7A4A22).withValues(alpha: 0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF5C3E22),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    height: 1.1,
                    decoration: TextDecoration.none,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF8A6A45),
                      fontSize: 13.5,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                child,
              ],
            ),
          ),
        );
      },
    );
  }
}


/// Circular avatar framed by a coin-ring asset — golden normally, swapped to
/// the silver-white ring while it is this player's turn. Shows a 30s countdown
/// dial over the portrait during that turn.
class _GomokuAvatar extends StatefulWidget {
  const _GomokuAvatar({
    required this.imageUrl,
    required this.fallback,
    required this.diameter,
    required this.active,
    required this.paused,
    this.onTimeout,
  });

  final String? imageUrl;
  final String fallback;
  final double diameter;
  final bool active;
  final bool paused;
  // Fired when the turn countdown runs out while still this player's turn.
  final VoidCallback? onTimeout;

  @override
  State<_GomokuAvatar> createState() => _GomokuAvatarState();
}

class _GomokuAvatarState extends State<_GomokuAvatar>
    with SingleTickerProviderStateMixin {
  // Seconds a player has to move; the design shows a 30s dial per turn.
  static const int _turnSeconds = 30;
  static const Color _cyan = Color(0xFF44E0FF);

  late final AnimationController _countdown;

  @override
  void initState() {
    super.initState();
    _countdown = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _turnSeconds),
    )..addStatusListener(_onCountdownStatus);
    _sync();
  }

  void _onCountdownStatus(AnimationStatus status) {
    // Turn ran out while it is still this player's turn (and no modal open).
    if (status == AnimationStatus.completed &&
        widget.active &&
        !widget.paused) {
      widget.onTimeout?.call();
    }
  }

  @override
  void didUpdateWidget(covariant _GomokuAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      _sync();
    } else if (widget.paused != oldWidget.paused && widget.active) {
      // Freeze/resume the turn dial when a modal (pause / exit) opens & closes,
      // keeping the current remaining time instead of restarting or ticking.
      if (widget.paused) {
        _countdown.stop();
      } else if (_countdown.value >= 1.0) {
        // The dial had already run out (e.g. the modal was the auto-timeout
        // pause) — give a fresh turn on resume rather than staying at 0.
        _countdown.forward(from: 0);
      } else {
        _countdown.forward();
      }
    }
  }

  void _sync() {
    if (widget.active && !widget.paused) {
      // Restart the dial from full at the start of every turn.
      _countdown.forward(from: 0);
    } else if (!widget.active) {
      _countdown.stop();
      _countdown.value = 0;
    }
  }

  @override
  void dispose() {
    _countdown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.diameter;
    // The portrait fills the ring asset's transparent hole; the ring PNG
    // (game_avatar_frame.png) overlays it as the golden coin frame.
    final inner = d * 0.74;
    return AnimatedBuilder(
      animation: _countdown,
      builder: (context, _) {
        final remainingFraction = (1 - _countdown.value).clamp(0.0, 1.0);
        final remainingSeconds = (remainingFraction * _turnSeconds)
            .ceil()
            .clamp(0, _turnSeconds);
        return SizedBox(
          width: d,
          height: d,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Portrait clipped to the ring's inner hole.
              ClipOval(
                child: SizedBox(
                  width: inner,
                  height: inner,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _Avatar(
                        size: inner,
                        label: widget.fallback.trim().isEmpty
                            ? '伴'
                            : widget.fallback.trim().characters.first,
                        imageUrl: widget.imageUrl,
                        gradient: const [Color(0xFFE8F3FF), Color(0xFFD7E9FF)],
                      ),
                      if (widget.active) ...[
                        // Countdown mask + sweeping red hand + seconds.
                        CustomPaint(
                          painter: _GomokuTurnTimerPainter(
                            remainingFraction: remainingFraction,
                          ),
                        ),
                        Center(
                          child: Text(
                            '$remainingSeconds',
                            style: TextStyle(
                              color: _cyan,
                              fontSize: inner * 0.32,
                              fontWeight: FontWeight.w900,
                              height: 1,
                              letterSpacing: 0,
                              decoration: TextDecoration.none,
                              shadows: const [
                                Shadow(
                                  color: Color(0x99000000),
                                  offset: Offset(0, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Coin frame on top: golden by default, silver-white while it is
              // this player's turn (design 2:3 / 125:1028) — the frame itself
              // is the turn highlight, no extra glow.
              Image.asset(
                widget.active
                    ? '${_gomokuHomeAsset}game_avatar_frame_active.png'
                    : '${_gomokuHomeAsset}game_avatar_frame.png',
                width: d,
                height: d,
                fit: BoxFit.contain,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Draws the per-turn stopwatch: a translucent white disc over the portrait
/// and a red ring that drains clockwise from the top as time runs out.
class _GomokuTurnTimerPainter extends CustomPainter {
  const _GomokuTurnTimerPainter({required this.remainingFraction});

  final double remainingFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final elapsed = (1 - remainingFraction).clamp(0.0, 1.0);
    final handAngle = -math.pi / 2 + elapsed * 2 * math.pi;

    // Gray pie mask over the sector not yet swept. It starts covering the whole
    // portrait and shrinks clockwise as the red hand sweeps, revealing the
    // portrait — the mask is "eaten away" over the turn.
    final remainingSweep = (1 - elapsed) * 2 * math.pi;
    if (remainingSweep > 0.0001) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        handAngle,
        remainingSweep,
        true,
        Paint()..color = const Color(0xFF8E8E8E).withValues(alpha: 0.82),
      );
    }

    // Red sweeping hand at the leading edge of the mask.
    final dir = Offset(math.cos(handAngle), math.sin(handAngle));
    const red = Color(0xFFC81E1E);
    canvas.drawLine(
      center,
      center + dir * (radius * 0.94),
      Paint()
        ..color = red
        ..strokeWidth = radius * 0.08
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, radius * 0.08, Paint()..color = red);
  }

  @override
  bool shouldRepaint(covariant _GomokuTurnTimerPainter oldDelegate) =>
      oldDelegate.remainingFraction != remainingFraction;
}

/// Cream name pill (art) with the player's name and their stone colour shown
/// as a chip on the side facing the board centre.
class _GomokuNamePlate extends StatelessWidget {
  const _GomokuNamePlate({
    required this.name,
    required this.stone,
    required this.stoneOnRight,
  });

  final String name;
  final GomokuStone stone;
  final bool stoneOnRight;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 450 / 138,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final stoneWidget = SvgPicture.asset(
            stone == GomokuStone.black
                ? '${_gomokuHomeAsset}game_stone_black.svg'
                : '${_gomokuHomeAsset}game_stone_white.svg',
            width: h * 0.5,
            height: h * 0.5,
            fit: BoxFit.contain,
          );
          final nameWidget = Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                // Design 2:3: the name glyph is ~0.37x the plate height, so the
                // font size is ~0.42x height (was a fixed 22 → too large).
                child: Text(
                  name,
                  maxLines: 1,
                  style: _kNamePlateStyle.copyWith(fontSize: h * 0.42),
                ),
              ),
            ),
          );
          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Image.asset(_gomokuNamePlate, fit: BoxFit.fill),
              ),
              // The stone sits hard against the outer end of the pill; the name
              // centres in the remaining space (matches Figma 2:3).
              Padding(
                padding: EdgeInsets.symmetric(horizontal: h * 0.3),
                child: Row(
                  children: stoneOnRight
                      ? [nameWidget, SizedBox(width: h * 0.12), stoneWidget]
                      : [stoneWidget, SizedBox(width: h * 0.12), nameWidget],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

const TextStyle _kNamePlateStyle = TextStyle(
  color: Color(0xFF6B4A2E),
  fontSize: 22,
  fontWeight: FontWeight.w900,
  letterSpacing: 0,
  height: 1,
  decoration: TextDecoration.none,
);

/// Wooden framed 15×15 board that reuses the interactive board painter.
class _GomokuDesignBoard extends StatelessWidget {
  const _GomokuDesignBoard({
    required this.engine,
    required this.enabled,
    required this.onPointTap,
  });

  final GomokuEngine engine;
  final bool enabled;
  final ValueChanged<GomokuPoint> onPointTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1050 / 1113,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              '${_gomokuHomeAsset}game_board_base.png',
              fit: BoxFit.fill,
            ),
          ),
          Positioned.fill(
            child: _GomokuBoard(
              engine: engine,
              enabled: enabled,
              onPointTap: onPointTap,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom action button (art base + rendered label), matching 退出/暂停.
class _GomokuGameButton extends StatefulWidget {
  const _GomokuGameButton({
    required this.base,
    required this.label,
    required this.onTap,
  });

  final String base;
  final String label;
  final VoidCallback onTap;

  @override
  State<_GomokuGameButton> createState() => _GomokuGameButtonState();
}

class _GomokuGameButtonState extends State<_GomokuGameButton> {
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
        scale: _pressed ? 0.95 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AspectRatio(
          aspectRatio: 450 / 207,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Image.asset(widget.base, fit: BoxFit.fill),
              ),
              Align(
                alignment: const Alignment(0, -0.14),
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    height: 1,
                    decoration: TextDecoration.none,
                    shadows: [
                      Shadow(
                        color: Color(0x66000000),
                        offset: Offset(1.5, 1.5),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

/// Centered rules popup with a gaussian-blurred backdrop and a themed close (×)
/// button in the top-right corner.
// Shared game-art rules popup (cream card + blurred backdrop + themed close),
// used by both five-in-a-row and reversi.
// Returns the dialog's Future so callers can pause the turn countdown while
// the popup is open and resume when it closes (reversi / gomoku / checkers).
Future<void> _showGameRulesDialog(
  BuildContext context, {
  required String gameName,
  required List<String> rules,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭',
    barrierColor: Colors.black.withValues(alpha: 0.2),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (dialogContext, _, __) => Center(
      child: _GameRulesCard(
        gameName: gameName,
        rules: rules,
        onClose: () => Navigator.of(dialogContext).pop(),
      ),
    ),
    transitionBuilder: (_, animation, __, child) {
      // Ramp the gaussian blur in with the entrance and back out on close, in
      // step with the card's fade, rather than snapping to the final blur.
      return AnimatedBuilder(
        animation: animation,
        builder: (context, inner) {
          final t = animation.value.clamp(0.0, 1.0);
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10 * t, sigmaY: 10 * t),
            child: Opacity(opacity: t, child: inner),
          );
        },
        child: child,
      );
    },
  );
}

class _GameRulesCard extends StatelessWidget {
  const _GameRulesCard({
    required this.gameName,
    required this.rules,
    required this.onClose,
  });

  final String gameName;
  final List<String> rules;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final cardW = math.min(screenW * 0.74, 340.0);
    return SizedBox(
      width: cardW,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Dark-brown outer frame + tan inner line = the design's double edge.
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF6DEB4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF7A3D1E), width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5A2E14).withValues(alpha: 0.45),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            padding: const EdgeInsets.all(4),
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFDEFD6), Color(0xFFF6DEB4)],
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFFE7C58C), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: _StrokeText(text: gameName, fontSize: cardW * 0.092),
                  ),
                  const SizedBox(height: 2),
                  Center(
                    child: _StrokeText(text: '规则说明', fontSize: cardW * 0.082),
                  ),
                  const SizedBox(height: 20),
                  for (var i = 0; i < rules.length; i += 1) ...[
                    if (i > 0) const SizedBox(height: 12),
                    Text(
                      rules[i],
                      style: TextStyle(
                        color: const Color(0xFF7A4A22),
                        fontSize: cardW * 0.052,
                        height: 1.35,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            top: -14,
            right: -14,
            child: _GomokuCloseButton(onTap: onClose),
          ),
        ],
      ),
    );
  }
}

/// Themed circular close (×) button used in the top-right of the rules popup.
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
