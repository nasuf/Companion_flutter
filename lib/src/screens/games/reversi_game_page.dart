part of 'package:companion_flutter/main.dart';

class _ReversiGamePage extends StatefulWidget {
  const _ReversiGamePage({
    required this.api,
    required this.authSession,
    required this.game,
  });

  final CompanionApi api;
  final AuthSession authSession;
  final _GameTile game;

  @override
  State<_ReversiGamePage> createState() => _ReversiGamePageState();
}

class _ReversiGamePageState extends State<_ReversiGamePage> {
  late final _NativeGameRuntime _runtime;
  ReversiEngine? _engine;
  ReversiMove? _lastMove;
  bool _resolving = false;
  bool _timerPaused = false;
  // Full-screen win/lose result (null while playing). Shown a beat after the
  // game ends, and also when the user quits / restarts mid-game (counts as a
  // loss). The game screen fades out and this fades in.
  _ReversiResultKind? _result;
  Timer? _finishTimer;

  @override
  void initState() {
    super.initState();
    _runtime = _NativeGameRuntime(
      api: widget.api,
      authSession: widget.authSession,
      gameKey: _nativeReversiGameKey,
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
    _finishTimer?.cancel();
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

  void _clearActiveRound() {
    _finishTimer?.cancel();
    _finishTimer = null;
    setState(() {
      _engine = null;
      _lastMove = null;
      _resolving = false;
      _timerPaused = false;
      _result = null;
    });
  }

  void _setTimerPaused(bool paused) {
    if (!mounted || _timerPaused == paused) return;
    setState(() => _timerPaused = paused);
  }

  Future<void> _closeGame() async {
    final engine = _engine;
    if (_runtime.session != null && !_runtime.completed) {
      await _runtime.abort('closed', engine?.summaryJson() ?? const {});
    }
    _runtime.clearPresentation();
    if (!mounted) return;
    _clearActiveRound();
  }

  Future<void> _start() async {
    final old = _engine;
    if (_runtime.session != null && !_runtime.completed) {
      await _runtime.abort('restarted', old?.summaryJson() ?? const {});
    }
    final session = await _runtime.start({
      'board_size': ReversiEngine.size,
      'first_actor': 'user',
      'user_color': 'black',
      'agent_color': 'ivory',
      'rules': 'standard_reversi_forced_pass_exact_scoring',
      'search':
          'iterative_deepening_pvs_alpha_beta_tt_mobility_stability_parity',
    });
    _finishTimer?.cancel();
    _finishTimer = null;
    if (session != null && mounted) {
      setState(() {
        _engine = ReversiEngine(
          aiConfig: ReversiAiConfig.fromJson(session.engineConfig),
        );
        _lastMove = null;
        _resolving = false;
        _timerPaused = false;
        _result = null;
      });
    }
  }

  Future<void> _userPlay(int index) async {
    final engine = _engine;
    if (engine == null ||
        engine.isFinished ||
        engine.turn != ReversiActor.user ||
        _runtime.aiThinking ||
        _resolving) {
      return;
    }
    if (!engine.isLegal(index)) {
      _NativeGameHaptics.rejected();
      return;
    }
    await _playAndReport(index);
    if (!engine.isFinished && engine.turn == ReversiActor.agent) {
      await _agentLoop();
    }
  }

  Future<void> _agentLoop() async {
    final engine = _engine;
    if (engine == null || engine.isFinished) return;
    setState(() => _runtime.aiThinking = true);
    try {
      while (mounted &&
          !engine.isFinished &&
          engine.turn == ReversiActor.agent) {
        final sw = Stopwatch()..start();
        await _runtime.reportEvent(
          'ai_thinking_started',
          payload: {
            'move_number': engine.moveCount + 1,
            'analysis': engine.analysisJson(),
          },
        );
        final decision = await engine.chooseAiMove();
        if (!mounted ||
            engine.isFinished ||
            engine.turn != ReversiActor.agent) {
          return;
        }
        await _runtime.reportEvent(
          'ai_move_decided',
          payload: decision.toJson(),
        );
        await _runtime.paceAiMove(sw);
        if (!mounted ||
            engine.isFinished ||
            engine.turn != ReversiActor.agent) {
          return;
        }
        await _playAndReport(decision.point.index, decision: decision);
        if (!engine.isFinished && engine.turn == ReversiActor.agent) {
          await Future<void>.delayed(const Duration(milliseconds: 420));
        }
      }
    } finally {
      if (mounted) setState(() => _runtime.aiThinking = false);
    }
  }

  Future<void> _playAndReport(int index, {ReversiAiDecision? decision}) async {
    final engine = _engine!;
    final before = engine.stateJson();
    final result = engine.play(index, decision: decision);
    if (mounted) {
      setState(() {
        _lastMove = result.move;
        _resolving = true;
      });
    }
    _NativeGameHaptics.flip(
      result.move.flipped.length,
      corner: result.move.cornerCaptured,
    );
    try {
      await Future.wait([
        _reportMove(result.move, before),
        Future<void>.delayed(
          Duration(milliseconds: result.move.flipped.length >= 8 ? 960 : 760),
        ),
      ]);
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
    if (result.status != ReversiStatus.playing) {
      await _finish(result.status);
    }
  }

  Future<void> _reportMove(
    ReversiMove move,
    Map<String, dynamic> before,
  ) async {
    final engine = _engine!;
    await _runtime.reportEvent(
      'disc_placed',
      state: 'playing',
      payload: {
        ...move.toJson(),
        'action_id': '${_runtime.session?.id}:${move.number}',
        'state_before': before,
        'state_after': engine.stateJson(),
        'analysis': engine.analysisJson(),
      },
    );
    for (final moment in move.moments) {
      await _runtime.reportEvent(
        'key_moment',
        payload: {
          ...moment,
          'move_number': move.number,
          'actor': move.actor.name,
          'at': move.point.toJson(),
        },
      );
    }
    if (move.forcedPass != null) {
      await _runtime.reportEvent(
        'turn_changed',
        payload: {
          'move_number': move.number,
          'passed_actor': move.forcedPass!.name,
          'next_actor': engine.turn.name,
          'reason': 'no_legal_move',
        },
      );
    }
  }

  /// Quitting or restarting mid-game counts as a loss: the lose screen takes
  /// over and the round is settled as a defeat, so the points are actually
  /// deducted rather than the session merely being aborted.
  Future<void> _forfeit() async {
    if (!mounted || _result != null || _engine == null) return;
    if (_runtime.completed) return;
    setState(() => _result = _ReversiResultKind.lose);
    await _finish(ReversiStatus.agentWon);
  }

  Future<void> _finish(ReversiStatus status) async {
    final engine = _engine!;
    await _runtime.finish({
      ...engine.summaryJson(),
      'user_outcome': switch (status) {
        ReversiStatus.userWon => 'win',
        ReversiStatus.agentWon => 'lose',
        ReversiStatus.draw => 'draw',
        ReversiStatus.playing => 'aborted',
      },
      'terminal_state': {'status': status.name},
      'state_after_hash': engine.stateHash.toString(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final engine = _engine;
    // When a round ends, hold the final board briefly, then reveal the
    // full-screen result (win for the user, otherwise loss).
    if (engine != null &&
        engine.isFinished &&
        _result == null &&
        _finishTimer == null) {
      final win = engine.status == ReversiStatus.userWon;
      _finishTimer = Timer(const Duration(milliseconds: 1400), () {
        if (!mounted || _result != null) return;
        setState(
          () => _result = win ? _ReversiResultKind.win : _ReversiResultKind.lose,
        );
      });
    }

    final Widget child;
    if (engine == null) {
      child = _ReversiHome(
        key: const ValueKey('reversi-home'),
        stats: _runtime.recordStats,
        starting: _runtime.starting,
        error: _runtime.error,
        onStart: _start,
        onExit: () => Navigator.of(context).maybePop(),
      );
    } else if (_result != null) {
      child = _ReversiResultScreen(
        key: const ValueKey('reversi-result'),
        kind: _result!,
        pointsDelta: _runtime.pointRules?.deltaFor(
          _result == _ReversiResultKind.win
              ? GameOutcome.win
              : GameOutcome.lose,
        ),
        onAgain: () async {
          setState(() => _result = null);
          await _start();
        },
        onConfirm: () async {
          setState(() => _result = null);
          await _closeGame();
        },
      );
    } else {
      child = PopScope(
        key: const ValueKey('reversi-game'),
        canPop: false,
        child: _ReversiGameScreen(
          engine: engine,
          lastMove: _lastMove,
          agentName: _runtime.agentName,
          userName: widget.authSession.userFacingName,
          agentAvatarUrl: widget.authSession.agentAvatarUrl,
          userAvatarUrl: widget.authSession.userAvatarUrl,
          startedAt: _runtime.session?.startedAt,
          aiThinking: _runtime.aiThinking,
          resolving: _resolving,
          starting: _runtime.starting,
          timerPaused: _timerPaused,
          enabled:
              engine.turn == ReversiActor.user &&
              !_runtime.aiThinking &&
              !_resolving &&
              !_timerPaused &&
              !engine.isFinished,
          onTap: _userPlay,
          onRestart: _start,
          onExit: _closeGame,
          onTimerPauseChanged: _setTimerPaused,
          bannerInMs: _runtime.bannerInMs,
          bannerHoldMs: _runtime.bannerHoldMs,
          bannerOutMs: _runtime.bannerOutMs,
          gamePoints: _runtime.pointsBalance,
          onShowLose: _forfeit,
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

const String _reversiAsset = 'assets/prototype/games/reversi/';
