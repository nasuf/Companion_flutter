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
      onNeedPoints: () {
        if (mounted) _showGameNoPointsDialog(context);
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
        stats: _runtime.recordStats,
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
