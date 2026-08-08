part of 'package:companion_flutter/main.dart';

class _TetrisDuelGamePage extends StatefulWidget {
  const _TetrisDuelGamePage({
    required this.api,
    required this.authSession,
    required this.game,
  });

  final CompanionApi api;
  final AuthSession authSession;
  final _GameTile game;

  @override
  State<_TetrisDuelGamePage> createState() => _TetrisDuelGamePageState();
}

class _TetrisDuelGamePageState extends State<_TetrisDuelGamePage> {
  static const _tickInterval = Duration(milliseconds: 100);
  static const _userGravityMilliseconds = 680;

  late final _NativeGameRuntime _runtime;
  TetrisDuelEngine? _engine;
  Timer? _ticker;
  DateTime? _lastTickAt;
  int _userGravityElapsed = 0;
  int _userActionSequence = 0;

  // The agent plays its piece down the board the way a person does: it picks a
  // target, then nudges the piece across while gravity carries it down.
  // Dropping it straight into place read as a bot and, because that path
  // scored the whole drop distance at once, also handed it points the player
  // had no way to match.
  TetrisAiPlacement? _agentPlan;
  int _agentActionElapsed = 0;
  int _agentFallElapsed = 0;
  bool _agentLinedUp = false;
  bool _finishing = false;
  // The duel clock keeps running on a Timer, so the pause / exit sheets have to
  // freeze it explicitly or the match plays on behind the dialog.
  bool _paused = false;
  // The soft-drop (速降) button accelerates gravity while held instead of
  // slamming the piece to the floor (spec 4).
  bool _softDropping = false;
  // Non-null once the duel ends: the full-screen win/lose page replaces the
  // board, like the other games.
  _TetrisResultKind? _result;
  Timer? _resultTimer;
  double _horizontalDrag = 0;
  double _verticalDrag = 0;
  Future<void> _eventChain = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _runtime = _NativeGameRuntime(
      api: widget.api,
      authSession: widget.authSession,
      gameKey: _nativeTetrisDuelGameKey,
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
    unawaited(_runtime.initialize());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _resultTimer?.cancel();
    _runtime.dispose();
    unawaited(
      _eventChain.then(
        (_) =>
            _runtime.abort('page_closed', _sessionSummary(), updateUi: false),
      ),
    );
    super.dispose();
  }

  void _clearActiveRound() {
    _ticker?.cancel();
    _resultTimer?.cancel();
    _resultTimer = null;
    setState(() {
      _engine = null;
      _finishing = false;
      _paused = false;
      _softDropping = false;
      _result = null;
      _userGravityElapsed = 0;
      _userActionSequence = 0;
      _resetAgentPlan();
    });
  }

  Future<void> _start() async {
    final old = _engine;
    _ticker?.cancel();
    await _eventChain;
    if (_runtime.session != null && !_runtime.completed) {
      await _runtime.abort('restarted', old?.summaryJson() ?? const {});
    }
    final seed = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
    TetrisDuelConfig? gameConfig;
    final session = await _runtime.start(
      {
        'mode': 'timed_split_board_duel',
        'board_size': {'columns': 10, 'rows': 20},
        'randomizer': 'seven_bag',
        'rotation_system': 'srs_wall_kick',
        'agent_strategy': 'weighted_surface_search',
        'seed': seed,
      },
      payloadBuilder: (created) {
        gameConfig = TetrisDuelConfig.fromJson(created.engineConfig);
        return {
          'mode': 'timed_split_board_duel',
          'duration_seconds': gameConfig!.durationSeconds,
          'board_size': {'columns': 10, 'rows': 20},
          'randomizer': 'seven_bag',
          'rotation_system': 'srs_wall_kick',
          'agent_strategy': 'weighted_surface_search',
          'seed': seed,
        };
      },
    );
    if (session == null || !mounted) return;
    _resultTimer?.cancel();
    _resultTimer = null;
    setState(() {
      _engine = TetrisDuelEngine(
        seed: seed,
        config: gameConfig ?? TetrisDuelConfig.fromJson(session.engineConfig),
      );
      _finishing = false;
      _result = null;
      _softDropping = false;
      _userGravityElapsed = 0;
      _userActionSequence = 0;
      _resetAgentPlan();
      _paused = false;
      _eventChain = Future<void>.value();
      _lastTickAt = DateTime.now();
    });
    _ticker = Timer.periodic(_tickInterval, (_) => _tick());
  }

  void _tick() {
    final engine = _engine;
    if (engine == null || engine.isFinished || _finishing) return;
    if (_paused || _runtime.turnTimeoutVisible) {
      _lastTickAt = DateTime.now();
      return;
    }
    final now = DateTime.now();
    final delta = math.min(
      250,
      math.max(1, now.difference(_lastTickAt ?? now).inMilliseconds),
    );
    _lastTickAt = now;
    engine.advanceClock(delta);
    _userGravityElapsed += delta;

    // Holding 速降 accelerates gravity (spec 4) rather than hard-dropping.
    final gravityInterval = _softDropping
        ? 45
        : _userGravityInterval(engine.user.level);
    if (_userGravityElapsed >= gravityInterval) {
      _userGravityElapsed = 0;
      final result = engine.user.softDrop();
      if (result != null) _handleLock(result);
    }
    if (!engine.isFinished) _advanceAgent(delta);
    if (engine.isFinished) {
      unawaited(_finish());
    } else if (mounted) {
      setState(() {});
    }
  }

  int _userGravityInterval(int level) =>
      math.max(170, _userGravityMilliseconds - (level - 1) * 48);

  /// Budget for one whole piece, from spawn to lock.
  int _agentPieceBudget(int level) =>
      math.max(600, (_engine?.config.agentMoveMs ?? 760) - (level - 1) * 32);

  /// Gap between the agent's individual nudges. Roughly how fast a person
  /// taps, so the piece visibly slides across rather than teleporting.
  static const _agentActionMs = 110;

  /// Rows a piece falls through from spawn to the floor on an empty board.
  /// Used to spread the piece's time budget across its descent.
  static const _agentFallRows = 20;

  /// The agent rides gravity all the way down instead of soft-dropping once it
  /// is lined up. Slamming it home the moment it was in position made the
  /// budget meaningless — every piece took the same ~1.1s no matter what
  /// agent_move_ms said, because the descent was always at soft-drop speed.
  int _agentFallInterval(int level) =>
      math.max(60, (_agentPieceBudget(level) / _agentFallRows).round());

  void _resetAgentPlan() {
    _agentPlan = null;
    _agentLinedUp = false;
    _agentActionElapsed = 0;
    _agentFallElapsed = 0;
  }

  /// One tick of the agent's hands: line the piece up, then bring it down.
  void _advanceAgent(int delta) {
    final engine = _engine;
    if (engine == null) return;
    final agent = engine.agent;
    if (agent.topOut || agent.current == null) return;

    if (_agentPlan == null) {
      _resetAgentPlan();
      _agentPlan = agent.chooseAiPlacement(config: engine.config);
    }
    final plan = _agentPlan!;
    _agentActionElapsed += delta;
    _agentFallElapsed += delta;

    if (!_agentLinedUp && _agentActionElapsed >= _agentActionMs) {
      _agentActionElapsed = 0;
      _agentLinedUp = _stepAgentTowards(plan);
    }

    if (_agentFallElapsed >= _agentFallInterval(agent.level)) {
      _agentFallElapsed = 0;
      final result = agent.softDrop();
      if (result != null) {
        _agentPlan = null;
        _handleLock(result, decision: plan);
      }
    }
  }

  /// Rotates or shifts the piece one notch towards [plan]. Returns true once
  /// there is nothing left to do — either it is in position, or it is wedged
  /// and should ride down where it stands rather than hover.
  bool _stepAgentTowards(TetrisAiPlacement plan) {
    final agent = _engine?.agent;
    final piece = agent?.current;
    if (agent == null || piece == null) return true;
    // A blocked rotation should not stop it from still sliding sideways.
    if (piece.rotation != plan.rotation && agent.rotate()) return false;
    if (piece.x != plan.x) {
      return !agent.moveHorizontal(plan.x > piece.x ? 1 : -1);
    }
    return true;
  }

  void _handleLock(TetrisLockResult result, {TetrisAiPlacement? decision}) {
    final engine = _engine;
    final sessionId = _runtime.session?.id;
    if (engine == null || sessionId == null) return;
    engine.applyAttack(result);
    if (result.actor == TetrisDuelActor.user) {
      if (result.linesCleared > 0) {
        _NativeGameHaptics.capture(
          result.linesCleared,
          keyMoment: result.linesCleared == 4 || result.combo >= 3,
        );
      } else {
        _NativeGameHaptics.placement();
      }
    }
    _queueEvent(
      () => _reportLock(result, sessionId: sessionId, decision: decision),
    );
  }

  void _queueEvent(Future<void> Function() task) {
    _eventChain = _eventChain.then((_) => task()).catchError((Object error) {
      debugPrint('Tetris event reporting failed: $error');
    });
  }

  Future<void> _reportLock(
    TetrisLockResult result, {
    required String sessionId,
    TetrisAiPlacement? decision,
  }) async {
    final engine = _engine;
    if (engine == null ||
        _runtime.completed ||
        _runtime.session?.id != sessionId) {
      return;
    }
    final board = result.actor == TetrisDuelActor.user
        ? engine.user
        : engine.agent;
    if (decision != null) {
      await _runtime.reportEvent(
        'ai_move_decided',
        payload: {
          'actor': 'agent',
          'piece_number': board.piecesPlaced,
          ...decision.toJson(),
        },
        updateUi: false,
      );
      if (_runtime.completed || _runtime.session?.id != sessionId) return;
    }
    await _runtime.reportEvent(
      'tetromino_locked',
      state: 'playing',
      payload: {
        ...result.toJson(),
        'piece_number': board.piecesPlaced,
        'score_after': board.score,
        'lines_after': board.lines,
        'level_after': board.level,
        'board_after': board.board,
        'remaining_seconds': engine.remainingSeconds,
      },
      updateUi: false,
    );
    if (_runtime.completed || _runtime.session?.id != sessionId) return;
    if (result.attack > 0) {
      await _runtime.reportEvent(
        'garbage_sent',
        payload: {
          'actor': result.actor.name,
          'rows': result.attack,
          'piece_number': board.piecesPlaced,
          'receiver': result.actor == TetrisDuelActor.user ? 'agent' : 'user',
        },
        updateUi: false,
      );
      if (_runtime.completed || _runtime.session?.id != sessionId) return;
    }
    if (result.linesCleared >= 2 || result.combo >= 3 || result.topOut) {
      await _runtime.reportEvent(
        'key_moment',
        payload: {
          'actor': result.actor.name,
          'type': result.topOut
              ? 'top_out'
              : result.linesCleared == 4
              ? 'tetris'
              : result.combo >= 3
              ? 'combo'
              : 'multi_line_clear',
          'lines_cleared': result.linesCleared,
          'combo': result.combo,
          'action_number': engine.user.piecesPlaced + engine.agent.piecesPlaced,
          'score_after': board.score,
          'remaining_seconds': engine.remainingSeconds,
        },
        updateUi: false,
      );
    }
  }

  Future<void> _finish() async {
    final engine = _engine;
    if (engine == null || _finishing) return;
    _finishing = true;
    _ticker?.cancel();
    await _eventChain;
    final outcome = switch (engine.status) {
      TetrisDuelStatus.userWon => 'win',
      TetrisDuelStatus.agentWon => 'lose',
      _ => 'draw',
    };
    await _runtime.finish({
      ...engine.summaryJson(),
      'user_outcome': outcome,
      'terminal_state': {
        'status': engine.status.name,
        'reason': engine.user.topOut || engine.agent.topOut
            ? 'top_out'
            : 'time_limit',
      },
      'score': {'user': engine.user.score, 'agent': engine.agent.score},
      'state_after_hash': Object.hash(
        engine.user.stateHash,
        engine.agent.stateHash,
      ).toString(),
    });
    if (mounted) setState(() {});
  }

  bool get _canControl {
    final engine = _engine;
    return engine != null &&
        !engine.isFinished &&
        !_runtime.completed &&
        !_finishing &&
        !_paused;
  }

  void _setPaused(bool value) {
    if (_paused == value || !mounted) return;
    if (value) _stopSoftDrop();
    setState(() => _paused = value);
    // Drop the elapsed slice so the pause never counts against the clock.
    if (!value) _lastTickAt = DateTime.now();
  }

  void _move(int delta) {
    final engine = _engine;
    if (!_canControl || engine == null) return;
    if (engine.user.moveHorizontal(delta)) {
      _userActionSequence += 1;
      _NativeGameHaptics.selection();
      setState(() {});
    }
  }

  void _rotate() {
    final engine = _engine;
    if (!_canControl || engine == null) return;
    if (engine.user.rotate()) {
      _userActionSequence += 1;
      _NativeGameHaptics.selection();
      setState(() {});
    } else {
      _NativeGameHaptics.rejected();
    }
  }

  void _hold() {
    final engine = _engine;
    if (!_canControl || engine == null) return;
    if (engine.user.swapHold()) {
      _userActionSequence += 1;
      _NativeGameHaptics.selection();
      setState(() {});
    }
  }

  void _hardDrop() {
    final engine = _engine;
    if (!_canControl || engine == null || engine.user.current == null) return;
    final result = engine.user.hardDrop();
    _userActionSequence += 1;
    _handleLock(result);
    if (engine.isFinished) unawaited(_finish());
    setState(() {});
  }

  void _softDrop() {
    final engine = _engine;
    if (!_canControl || engine == null) return;
    final result = engine.user.softDrop();
    _userActionSequence += 1;
    if (result != null) _handleLock(result);
    if (engine.isFinished) unawaited(_finish());
    setState(() {});
  }

  // 速降 button held → accelerate gravity (spec 4). The tick reads _softDropping.
  void _startSoftDrop() {
    if (!_canControl || _softDropping) return;
    _softDropping = true;
    // Give an immediate first step so the tap feels responsive.
    _userGravityElapsed = 1000;
    _NativeGameHaptics.selection();
  }

  void _stopSoftDrop() {
    if (!_softDropping) return;
    _softDropping = false;
  }

  /// Quitting mid-duel → 失败 page; the page shows it in place of the board.
  Future<void> _forfeit() async {
    if (_result != null || _engine == null || _runtime.completed) return;
    _stopSoftDrop();
    setState(() => _result = _TetrisResultKind.lose);
    await _finish();
  }

  /// TEMP (spec 3): the pause-menu 重新开局 previews the 胜利 page for testing.
  /// Swap back to [_forfeit] once the win screen is signed off.
  Future<void> _forfeitWin() async {
    if (_result != null || _engine == null || _runtime.completed) return;
    _stopSoftDrop();
    setState(() => _result = _TetrisResultKind.win);
    await _finish();
  }

  void _onPanStart(DragStartDetails details) {
    _horizontalDrag = 0;
    _verticalDrag = 0;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_canControl) return;
    _horizontalDrag += details.delta.dx;
    _verticalDrag += details.delta.dy;
    const horizontalThreshold = 18.0;
    while (_horizontalDrag.abs() >= horizontalThreshold) {
      final direction = _horizontalDrag.isNegative ? -1 : 1;
      _move(direction);
      _horizontalDrag -= direction * horizontalThreshold;
    }
    if (_verticalDrag >= 24) {
      _softDrop();
      _verticalDrag -= 24;
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (details.velocity.pixelsPerSecond.dy > 850) _hardDrop();
  }

  Map<String, dynamic> _sessionSummary() =>
      _engine?.summaryJson() ?? const <String, dynamic>{};

  Future<void> _closeGame() async {
    if (_runtime.session != null && !_runtime.completed) {
      await _runtime.abort(
        _runtime.turnTimeoutVisible ? 'turn_timeout_ended' : 'closed',
        _sessionSummary(),
      );
    }
    _runtime.clearPresentation();
    if (!mounted) return;
    _clearActiveRound();
  }

  @override
  Widget build(BuildContext context) {
    final engine = _engine;
    // Hold the final board briefly, then reveal the full-screen result.
    if (engine != null &&
        engine.isFinished &&
        _result == null &&
        _resultTimer == null) {
      final win = engine.status == TetrisDuelStatus.userWon;
      _resultTimer = Timer(const Duration(milliseconds: 1200), () {
        if (!mounted || _result != null) return;
        setState(
          () => _result = win ? _TetrisResultKind.win : _TetrisResultKind.lose,
        );
      });
    }

    final Widget child;
    if (engine == null) {
      child = KeyedSubtree(
        key: const ValueKey('tetris-home'),
        child: _TetrisHome(
          rounds: _runtime.rounds,
          starting: _runtime.starting,
          error: _runtime.error,
          onStart: _start,
          onExit: () => Navigator.of(context).maybePop(),
        ),
      );
    } else if (_result != null) {
      child = _TetrisResultScreen(
        key: const ValueKey('tetris-result'),
        kind: _result!,
        onRestart: _start,
        onExit: _closeGame,
      );
    } else {
      child = PopScope(
        key: const ValueKey('tetris-game'),
        canPop: false,
        child: _NativeGameInteractionLayer(
          runtime: _runtime,
          game: widget.game,
          onPlayAgain: _start,
          onCloseGame: _closeGame,
          // `_paused` is set while the pause / exit sheet is up, which also
          // stops the idle-nudge countdown.
          userTurnActive:
              !engine.isFinished &&
              !_runtime.completed &&
              !_finishing &&
              !_paused,
          turnToken: '${_runtime.session?.id}:input:$_userActionSequence',
          turnTimeout: _nativeGameTurnTimeout(_nativeTetrisDuelGameKey),
          turnLabel: '双方同时行动',
          moveCount: engine.user.piecesPlaced + engine.agent.piecesPlaced,
          showPlayers: false,
          // The page renders its own full-screen win/lose page.
          suppressResult: true,
          child: _TetrisGameScreen(
            engine: engine,
            agentName: _runtime.agentName,
            userName: widget.authSession.userFacingName,
            agentAvatarUrl: widget.authSession.agentAvatarUrl,
            userAvatarUrl: widget.authSession.userAvatarUrl,
            canControl: _canControl,
            gamePoints: _runtime.pointsBalance,
            onMove: _move,
            onRotate: _rotate,
            onHold: _hold,
            onSoftDropStart: _startSoftDrop,
            onSoftDropEnd: _stopSoftDrop,
            onHardDrop: _hardDrop,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            // Exit mid-duel forfeits → 失败; pause 重新开局 → 胜利 preview (TEMP).
            onShowLose: _forfeit,
            onShowWin: _forfeitWin,
            onPauseChanged: _setPaused,
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

class _TetrisBoardPainter extends CustomPainter {
  _TetrisBoardPainter({required this.board, required this.accent})
    : stateHash = board.stateHash;

  final TetrisBoardEngine board;
  final Color accent;
  final int stateHash;

  /// The panel clips its content to a rounded rectangle, so a grid drawn edge
  /// to edge loses its corner cells to the curve. A radius r cuts in by
  /// r*(1 - 1/√2) on the diagonal — about 4.7pt for the 16pt clip — so the
  /// playfield is inset past that and centred in what is left.
  static const _cornerInset = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = math.min(
      (size.width - _cornerInset * 2) / TetrisBoardEngine.width,
      (size.height - _cornerInset * 2) / TetrisBoardEngine.height,
    );
    final origin = Offset(
      (size.width - cell * TetrisBoardEngine.width) / 2,
      (size.height - cell * TetrisBoardEngine.height) / 2,
    );
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF11172D), Color(0xFF070A14)],
        ).createShader(rect),
    );
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..strokeWidth = 0.7;
    final boardWidth = cell * TetrisBoardEngine.width;
    final boardHeight = cell * TetrisBoardEngine.height;
    for (var column = 0; column <= TetrisBoardEngine.width; column++) {
      final x = origin.dx + column * cell;
      canvas.drawLine(
        Offset(x, origin.dy),
        Offset(x, origin.dy + boardHeight),
        grid,
      );
    }
    for (var row = 0; row <= TetrisBoardEngine.height; row++) {
      final y = origin.dy + row * cell;
      canvas.drawLine(
        Offset(origin.dx, y),
        Offset(origin.dx + boardWidth, y),
        grid,
      );
    }
    for (var row = 0; row < TetrisBoardEngine.height; row++) {
      for (var column = 0; column < TetrisBoardEngine.width; column++) {
        final value = board.board[row * TetrisBoardEngine.width + column];
        if (value != 0) {
          _paintCell(canvas, origin, column, row, cell, value, 1);
        }
      }
    }
    for (final ghost in board.ghostCells()) {
      if (ghost.y >= 0) {
        _paintCell(
          canvas,
          origin,
          ghost.x,
          ghost.y,
          cell,
          (board.current?.type.index ?? 0) + 1,
          0.18,
        );
      }
    }
    final active = board.current;
    if (active != null) {
      for (final activeCell in active.cells) {
        if (activeCell.y >= 0) {
          _paintCell(
            canvas,
            origin,
            activeCell.x,
            activeCell.y,
            cell,
            active.type.index + 1,
            1,
          );
        }
      }
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(1), const Radius.circular(8)),
      Paint()
        ..color = accent.withValues(alpha: 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  void _paintCell(
    Canvas canvas,
    Offset origin,
    int x,
    int y,
    double cell,
    int value,
    double opacity,
  ) {
    final palette = value == 8
        ? const [Color(0xFF67708B), Color(0xFF353B50)]
        : _tetrisPalette[(value - 1).clamp(0, _tetrisPalette.length - 1)];
    final rect = Rect.fromLTWH(
      origin.dx + x * cell + 1.1,
      origin.dy + y * cell + 1.1,
      cell - 2.2,
      cell - 2.2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.17)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.first.withValues(alpha: opacity),
            palette.last.withValues(alpha: opacity),
          ],
        ).createShader(rect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(1), Radius.circular(cell * 0.14)),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.16 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );
  }

  @override
  bool shouldRepaint(covariant _TetrisBoardPainter oldDelegate) =>
      oldDelegate.stateHash != stateHash || oldDelegate.accent != accent;
}

const _tetrisPalette = <List<Color>>[
  [Color(0xFF55E6FF), Color(0xFF139AD1)],
  [Color(0xFF5878FF), Color(0xFF3046BD)],
  [Color(0xFFFFA638), Color(0xFFD76A1D)],
  [Color(0xFFFFE45C), Color(0xFFD5A928)],
  [Color(0xFF5BE381), Color(0xFF1FA258)],
  [Color(0xFFB36CFF), Color(0xFF7134CC)],
  [Color(0xFFFF6585), Color(0xFFD62D55)],
];
