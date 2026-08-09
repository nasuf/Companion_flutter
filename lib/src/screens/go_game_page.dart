part of 'package:companion_flutter/main.dart';

class _GoGamePage extends StatefulWidget {
  const _GoGamePage({
    required this.api,
    required this.authSession,
    required this.game,
  });

  final CompanionApi api;
  final AuthSession authSession;
  final _GameTile game;

  @override
  State<_GoGamePage> createState() => _GoGamePageState();
}

class _GoGamePageState extends State<_GoGamePage> {
  late final _NativeGameRuntime _runtime;
  GoEngine? _engine;
  GoMove? _lastMove;
  bool _resolving = false;
  // Non-null once the round ends (win/lose): the full-screen result replaces
  // the game (like 五子棋), so the board / avatars / turn dial are torn down
  // rather than left running behind an overlay.
  _GoResultKind? _result;
  Timer? _resultTimer;

  @override
  void initState() {
    super.initState();
    _runtime = _NativeGameRuntime(
      api: widget.api,
      authSession: widget.authSession,
      gameKey: _nativeGoGameKey,
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
      _lastMove = null;
      _resolving = false;
    });
  }

  /// Quitting or restarting mid-game counts as a loss: settle the round so the
  /// score is deducted, then show the 失败 result screen (its buttons then do
  /// the real exit / restart). No-op if the round already ended or settled.
  Future<void> _forfeit() async {
    if (_result != null || _engine == null || _runtime.completed) return;
    setState(() => _result = _GoResultKind.lose);
    await _finish(GoStatus.agentWon);
  }

  Future<void> _start() async {
    final old = _engine;
    if (_runtime.session != null && !_runtime.completed) {
      await _runtime.abort('restarted', old?.summaryJson() ?? const {});
    }
    final session = await _runtime.start({
      'board_size': GoEngine.boardSize,
      'first_actor': 'user',
      'user_color': 'black',
      'agent_color': 'white',
      'komi': 6.5,
      'rules': 'chinese_area_scoring_positional_superko',
      'search': 'uct_mcts_pattern_capture_rollout',
    });
    _resultTimer?.cancel();
    _resultTimer = null;
    if (session != null && mounted) {
      setState(() {
        _result = null;
        _engine = GoEngine(aiConfig: GoAiConfig.fromJson(session.engineConfig));
        _lastMove = null;
        _resolving = false;
      });
    }
  }

  Future<void> _userPlay(int index) async {
    final engine = _engine;
    if (engine == null ||
        engine.isFinished ||
        engine.turn != GoActor.user ||
        _runtime.aiThinking ||
        _resolving) {
      return;
    }
    if (!engine.isLegal(index)) {
      _NativeGameHaptics.rejected();
      return;
    }
    await _playAndReport(index);
    if (!engine.isFinished) await _agentTurn();
  }

  Future<void> _agentTurn() async {
    final engine = _engine;
    if (engine == null || engine.isFinished || engine.turn != GoActor.agent) {
      return;
    }
    final sw = Stopwatch()..start();
    setState(() => _runtime.aiThinking = true);
    await _runtime.reportEvent(
      'ai_thinking_started',
      payload: {
        'move_number': engine.moveCount + 1,
        'analysis': engine.analysisJson(),
      },
    );
    try {
      final decision = await engine.chooseAiMove();
      if (!mounted || engine.isFinished || engine.turn != GoActor.agent) return;
      await _runtime.reportEvent('ai_move_decided', payload: decision.toJson());
      await _runtime.paceAiMove(sw);
      if (!mounted || engine.isFinished || engine.turn != GoActor.agent) return;
      await _playAndReport(decision.index, decision: decision);
    } finally {
      if (mounted) setState(() => _runtime.aiThinking = false);
    }
  }

  Future<void> _playAndReport(int? index, {GoAiDecision? decision}) async {
    final engine = _engine!;
    final before = engine.stateJson();
    final result = engine.play(index, decision: decision);
    if (mounted) {
      setState(() {
        _lastMove = result.move;
        _resolving = true;
      });
    }
    if (result.move.index == null) {
      _NativeGameHaptics.pass();
    } else if (result.move.captured.isNotEmpty) {
      _NativeGameHaptics.capture(
        result.move.captured.length,
        keyMoment: result.move.moment != null,
      );
    } else {
      _NativeGameHaptics.placement(keyMoment: result.move.moment != null);
    }
    try {
      await Future.wait([
        _reportMove(result.move, before),
        Future<void>.delayed(
          Duration(milliseconds: result.move.captured.isEmpty ? 380 : 620),
        ),
      ]);
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
    if (result.status != GoStatus.playing) await _finish(result.status);
  }

  Future<void> _reportMove(GoMove move, Map<String, dynamic> before) async {
    final engine = _engine!;
    await _runtime.reportEvent(
      'stone_placed',
      state: 'playing',
      payload: {
        ...move.toJson(),
        'action_id': '${_runtime.session?.id}:${move.number}',
        'state_before': before,
        'state_after': engine.stateJson(),
        'analysis': engine.analysisJson(),
      },
    );
    if (move.moment != null) {
      await _runtime.reportEvent(
        'key_moment',
        payload: {
          ...move.moment!,
          'move_number': move.number,
          'actor': move.actor.name,
          if (move.index != null) 'point': GoPoint(move.index!).toJson(),
        },
      );
    }
  }

  Future<void> _finish(GoStatus status) async {
    final engine = _engine!;
    await _runtime.finish({
      ...engine.summaryJson(),
      'user_outcome': switch (status) {
        GoStatus.userWon => 'win',
        GoStatus.agentWon => 'lose',
        GoStatus.draw => 'draw',
        GoStatus.playing => 'aborted',
      },
      'terminal_state': {'status': status.name},
      'state_after_hash': engine.stateHash.toString(),
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
      final win = engine.status == GoStatus.userWon;
      _resultTimer = Timer(const Duration(milliseconds: 1400), () {
        if (!mounted || _result != null) return;
        setState(
          () => _result = win ? _GoResultKind.win : _GoResultKind.lose,
        );
      });
    }

    final Widget child;
    if (engine == null) {
      child = _GoHome(
        key: const ValueKey('go-home'),
        rounds: _runtime.rounds,
        starting: _runtime.starting,
        error: _runtime.error,
        onStart: _start,
        onExit: () => Navigator.of(context).maybePop(),
      );
    } else if (_result != null) {
      // Full-screen result replaces the game (board / avatars / dial are torn
      // down), so nothing keeps running behind it.
      child = _GoResultScreen(
        key: const ValueKey('go-result'),
        kind: _result!,
        pointsDelta: _runtime.pointRules?.deltaFor(
          _result == _GoResultKind.win ? GameOutcome.win : GameOutcome.lose,
        ),
        onRestart: _start,
        onExit: _closeGame,
      );
    } else {
      final userTurnActive =
          !engine.isFinished &&
          engine.turn == GoActor.user &&
          !_runtime.aiThinking &&
          !_resolving;
      child = PopScope(
        key: const ValueKey('go-game'),
        canPop: false,
        child: _NativeGameInteractionLayer(
          runtime: _runtime,
          game: widget.game,
          onPlayAgain: _start,
          onCloseGame: _closeGame,
          userTurnActive: userTurnActive,
          turnToken: '${engine.moveCount}:${engine.turn.name}',
          turnTimeout: _nativeGameTurnTimeout(_nativeGoGameKey),
          turnLabel: _runtime.aiThinking
              ? '${_runtime.agentName} 在落子'
              : '轮到你落子',
          moveCount: engine.moveCount,
          showPlayers: false,
          // The page renders its own full-screen 围棋 result, so the shared
          // generic terminal overlay is suppressed.
          suppressResult: true,
          child: _GoGameScreen(
            engine: engine,
            lastMove: _lastMove,
            agentName: _runtime.agentName,
            userName: widget.authSession.userFacingName,
            agentAvatarUrl: widget.authSession.agentAvatarUrl,
            userAvatarUrl: widget.authSession.userAvatarUrl,
            aiThinking: _runtime.aiThinking,
            enabled: userTurnActive,
            onTap: _userPlay,
            // Quitting or restarting mid-game → 失败 + 扣分.
            onShowLose: _forfeit,
            bannerInMs: _runtime.bannerInMs,
            bannerHoldMs: _runtime.bannerHoldMs,
            bannerOutMs: _runtime.bannerOutMs,
            gamePoints: _runtime.pointsBalance,
          ),
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

class _GoBoard extends StatefulWidget {
  const _GoBoard({
    required this.engine,
    required this.lastMove,
    required this.thinking,
    required this.enabled,
    required this.onTap,
    this.artwork = false,
  });

  final GoEngine engine;
  final GoMove? lastMove;
  final bool thinking;
  final bool enabled;
  final ValueChanged<int> onTap;
  final bool artwork;

  @override
  State<_GoBoard> createState() => _GoBoardState();
}

class _GoBoardState extends State<_GoBoard> with TickerProviderStateMixin {
  late final AnimationController _moveController;

  @override
  void initState() {
    super.initState();
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant _GoBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lastMove?.number != widget.lastMove?.number) {
      _moveController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _moveController.dispose();
    super.dispose();
  }

  void _handleTap(TapUpDetails details, Size size) {
    if (!widget.enabled) return;
    final geometry = _GoBoardGeometry(size, artwork: widget.artwork);
    final index = geometry.indexAt(details.localPosition);
    if (index != null) widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        final size = widget.artwork ? constraints.biggest : Size.square(side);
        final geometry = _GoBoardGeometry(size, artwork: widget.artwork);
        // The stone body is a design sprite (glossy black / pearl white); the
        // grid, star points and capture particles stay in the painter beneath.
        final stoneSize = geometry.stoneRadius * 2 * 1.06;
        final board = widget.engine.board;
        final lastIndex = widget.lastMove?.index;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => _handleTap(details, size),
          child: AnimatedBuilder(
            animation: _moveController,
            builder: (context, _) {
              final progress = Curves.easeOutCubic.transform(
                _moveController.value,
              );
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      size: size,
                      painter: _GoBoardPainter(
                        board: board,
                        lastMove: widget.lastMove,
                        moveProgress: progress,
                        thinking: widget.thinking,
                        darkMode: AppColors.isDark(context),
                        artwork: widget.artwork,
                      ),
                    ),
                  ),
                  for (var i = 0; i < board.length; i += 1)
                    if (board[i] != 0)
                      _stoneSprite(
                        geometry,
                        i,
                        board[i] == 1,
                        stoneSize,
                        i == lastIndex ? progress : 1.0,
                      ),
                ],
              );
            },
          ),
        );
      },
    ),
  );

  // A single stone sprite centred on its intersection; the last-placed stone
  // pops in (scale) via [t] (0→1), others stay at full size (t = 1).
  Widget _stoneSprite(
    _GoBoardGeometry geometry,
    int index,
    bool black,
    double size,
    double t,
  ) {
    final center = geometry.point(index);
    final scale = t < 1
        ? 0.12 + Curves.easeOutBack.transform(t) * 0.88
        : 1.0;
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      width: size,
      height: size,
      child: Transform.scale(
        scale: scale,
        child: Image.asset(
          black ? '${_goAsset}stone_black.png' : '${_goAsset}stone_white.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _GoBoardGeometry {
  const _GoBoardGeometry(this.size, {this.artwork = false});

  final Size size;
  final bool artwork;

  double get inset => size.width * 0.105;
  double get left => artwork ? size.width * (15 / 330) : inset;
  double get right => artwork ? size.width * (315 / 330) : size.width - inset;
  double get top => artwork ? (size.height - (right - left)) / 2 : inset;
  double get bottom => artwork ? top + (right - left) : size.height - inset;
  double get stepX => (right - left) / (GoEngine.boardSize - 1);
  double get stepY => (bottom - top) / (GoEngine.boardSize - 1);
  double get step => math.min(stepX, stepY);
  double get stoneRadius => step * 0.455;

  Offset point(int index) => Offset(
    left + (index % GoEngine.boardSize) * stepX,
    top + (index ~/ GoEngine.boardSize) * stepY,
  );

  int? indexAt(Offset position) {
    final col = ((position.dx - left) / stepX).round();
    final row = ((position.dy - top) / stepY).round();
    if (row < 0 ||
        row >= GoEngine.boardSize ||
        col < 0 ||
        col >= GoEngine.boardSize) {
      return null;
    }
    final index = row * GoEngine.boardSize + col;
    final center = point(index);
    final normalizedDistance = math.sqrt(
      math.pow((center.dx - position.dx) / stepX, 2) +
          math.pow((center.dy - position.dy) / stepY, 2),
    );
    return normalizedDistance <= 0.48 ? index : null;
  }
}

class _GoBoardPainter extends CustomPainter {
  const _GoBoardPainter({
    required this.board,
    required this.lastMove,
    required this.moveProgress,
    required this.thinking,
    required this.darkMode,
    this.artwork = false,
  });

  final List<int> board;
  final GoMove? lastMove;
  final double moveProgress;
  final bool thinking;
  final bool darkMode;
  final bool artwork;
  static const _starPoints = <int>[60, 66, 72, 174, 180, 186, 288, 294, 300];

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _GoBoardGeometry(size, artwork: artwork);
    if (artwork) {
      _paintArtworkBoard(canvas, size, geometry);
      _paintStonesAndCaptures(canvas, geometry);
      return;
    }
    final boardRect = Offset.zero & size;
    final radius = Radius.circular(size.width * 0.038);
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, radius),
      Paint()..color = const Color(0xFF6E421E),
    );
    final woodRect = boardRect.deflate(size.width * 0.012);
    canvas.drawRRect(
      RRect.fromRectAndRadius(woodRect, radius * 0.78),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFE5B665), Color(0xFFD19A4D), Color(0xFFE8BC70)],
          stops: [0, 0.52, 1],
        ).createShader(woodRect),
    );
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(woodRect, radius * 0.78));
    final grainPaint = Paint()
      ..color = const Color(0xFF6C3A1D).withValues(alpha: 0.08)
      ..strokeWidth = 0.7;
    for (var i = 0; i < 17; i += 1) {
      final x = size.width * (i + 0.4) / 17;
      final wave = math.sin(i * 1.71) * size.width * 0.015;
      final path = Path()
        ..moveTo(x, -10)
        ..cubicTo(
          x + wave,
          size.height * 0.28,
          x - wave,
          size.height * 0.68,
          x + wave * 0.3,
          size.height + 10,
        );
      canvas.drawPath(path, grainPaint);
    }
    canvas.restore();

    canvas.drawRRect(
      RRect.fromRectAndRadius(woodRect, radius * 0.78),
      Paint()
        ..color = const Color(0xFF6F421F).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, size.width * 0.006),
    );

    final gridPaint = Paint()
      ..color = const Color(0xFF2E2118).withValues(alpha: 0.9)
      ..strokeWidth = math.max(0.9, size.width / 390)
      ..strokeCap = StrokeCap.square;
    for (var line = 0; line < GoEngine.boardSize; line += 1) {
      final a = geometry.point(line);
      final b = geometry.point(
        (GoEngine.boardSize - 1) * GoEngine.boardSize + line,
      );
      canvas.drawLine(a, b, gridPaint);
      final c = geometry.point(line * GoEngine.boardSize);
      final d = geometry.point(
        line * GoEngine.boardSize + GoEngine.boardSize - 1,
      );
      canvas.drawLine(c, d, gridPaint);
    }
    final starPaint = Paint()..color = const Color(0xFF322014);
    for (final point in _starPoints) {
      canvas.drawCircle(
        geometry.point(point),
        geometry.step * 0.085,
        starPaint,
      );
    }

    _paintStonesAndCaptures(canvas, geometry);
  }

  void _paintArtworkBoard(Canvas canvas, Size size, _GoBoardGeometry geometry) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.width * (22 / 330));
    final panel = RRect.fromRectAndRadius(rect.deflate(1), radius);
    canvas.drawRRect(
      panel,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFECC47D), Color(0xFFD9A357), Color(0xFFE7B96C)],
          stops: [0, 0.54, 1],
        ).createShader(rect),
    );
    canvas.save();
    canvas.clipRRect(panel);
    final grain = Paint()
      ..color = const Color(0xFF7A4526).withValues(alpha: 0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, size.width / 700);
    for (var index = 0; index < 17; index += 1) {
      final x = size.width * (index + 0.4) / 17;
      final wave = math.sin(index * 1.37) * size.width * 0.012;
      canvas.drawPath(
        Path()
          ..moveTo(x, -8)
          ..cubicTo(
            x + wave,
            size.height * 0.3,
            x - wave,
            size.height * 0.7,
            x + wave * 0.25,
            size.height + 8,
          ),
        grain,
      );
    }
    canvas.restore();
    canvas.drawRRect(
      panel,
      Paint()
        ..color = const Color(0xFF7B4626).withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.4, size.width * (2 / 330)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(size.width * (9 / 330)),
        Radius.circular(size.width * (15 / 330)),
      ),
      Paint()
        ..color = const Color(0xFFFFD998).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, size.width / 500),
    );

    final gridShadow = Paint()
      ..color = const Color(0xFF2B190F).withValues(alpha: 0.22)
      ..strokeWidth = math.max(1.8, size.width / 180)
      ..strokeCap = StrokeCap.square;
    final grid = Paint()
      ..color = const Color(0xFF3B2417).withValues(alpha: 0.9)
      ..strokeWidth = math.max(0.9, size.width / 390)
      ..strokeCap = StrokeCap.square;
    for (var line = 0; line < GoEngine.boardSize; line += 1) {
      final verticalStart = geometry.point(line);
      final verticalEnd = geometry.point(
        (GoEngine.boardSize - 1) * GoEngine.boardSize + line,
      );
      final horizontalStart = geometry.point(line * GoEngine.boardSize);
      final horizontalEnd = geometry.point(
        line * GoEngine.boardSize + GoEngine.boardSize - 1,
      );
      const shadowOffset = Offset(0.7, 0.8);
      canvas.drawLine(
        verticalStart + shadowOffset,
        verticalEnd + shadowOffset,
        gridShadow,
      );
      canvas.drawLine(
        horizontalStart + shadowOffset,
        horizontalEnd + shadowOffset,
        gridShadow,
      );
      canvas.drawLine(verticalStart, verticalEnd, grid);
      canvas.drawLine(horizontalStart, horizontalEnd, grid);
    }

    for (final point in _starPoints) {
      final center = geometry.point(point);
      final starRect = Rect.fromCircle(
        center: center,
        radius: size.width * (4.5 / 330),
      );
      canvas.drawCircle(
        center,
        size.width * (4.5 / 330),
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.35, -0.4),
            colors: [Color(0xFFFFE49A), Color(0xFFC48A2C), Color(0xFF56301A)],
            stops: [0, 0.65, 1],
          ).createShader(starRect),
      );
      canvas.drawCircle(
        center,
        size.width * (2.1 / 330),
        Paint()..color = const Color(0xFF3A2114),
      );
    }
  }

  // Stone bodies are drawn as sprite widgets above the board; here we only add
  // the capture particles that puff out when stones are removed.
  void _paintStonesAndCaptures(Canvas canvas, _GoBoardGeometry geometry) {
    final captured = lastMove?.captured ?? const <int>[];
    if (captured.isNotEmpty && moveProgress < 1) {
      for (var i = 0; i < captured.length; i += 1) {
        final center = geometry.point(captured[i]);
        final angle = (i * 2.4 + 0.8) * math.pi;
        final distance = geometry.step * (0.18 + moveProgress * 0.62);
        final particle =
            center + Offset(math.cos(angle), math.sin(angle)) * distance;
        canvas.drawCircle(
          particle,
          geometry.step * 0.08 * (1 - moveProgress),
          Paint()..color = Colors.white.withValues(alpha: 1 - moveProgress),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GoBoardPainter oldDelegate) => true;
}
