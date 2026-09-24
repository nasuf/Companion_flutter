part of 'package:companion_flutter/main.dart';

class _ChineseCheckersGamePage extends StatefulWidget {
  const _ChineseCheckersGamePage({
    required this.api,
    required this.authSession,
    required this.game,
  });
  final CompanionApi api;
  final AuthSession authSession;
  final _GameTile game;

  @override
  State<_ChineseCheckersGamePage> createState() =>
      _ChineseCheckersGamePageState();
}

class _ChineseCheckersGamePageState extends State<_ChineseCheckersGamePage> {
  late final _NativeGameRuntime _runtime;
  ChineseCheckersEngine? _engine;
  ChineseCheckersMove? _lastMove;
  int? _selected;
  Map<int, List<int>> _targets = const {};
  bool _moveAnimating = false;
  // Non-null once the round ends (win/lose): the full-screen result replaces
  // the game (board / avatars / dial torn down), like the other board games.
  _CheckersResultKind? _checkersResult;
  Timer? _checkersResultTimer;

  @override
  void initState() {
    super.initState();
    _runtime = _NativeGameRuntime(
      api: widget.api,
      authSession: widget.authSession,
      gameKey: _nativeChineseCheckersGameKey,
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
    _checkersResultTimer?.cancel();
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

  Future<void> _closeCheckersGame() async {
    final engine = _engine;
    if (_runtime.session != null && !_runtime.completed) {
      await _runtime.abort(
        _runtime.turnTimeoutVisible ? 'turn_timeout_ended' : 'closed',
        engine?.summaryJson() ?? const {},
      );
    }
    _runtime.clearPresentation();
    _checkersResultTimer?.cancel();
    _checkersResultTimer = null;
    if (!mounted) return;
    setState(() {
      _checkersResult = null;
      _engine = null;
      _lastMove = null;
      _selected = null;
      _targets = const {};
      _moveAnimating = false;
    });
  }

  /// Quitting or restarting mid-game counts as a loss: settle so the score is
  /// deducted, then show the 失败 result screen (its buttons do exit / restart).
  Future<void> _forfeit() async {
    if (_checkersResult != null || _engine == null || _runtime.completed) {
      return;
    }
    setState(() => _checkersResult = _CheckersResultKind.lose);
    await _finish(ChineseCheckersStatus.agentWon);
  }

  Future<void> _start() async {
    final old = _engine;
    if (_runtime.session != null && !_runtime.completed) {
      await _runtime.abort('restarted', old?.summaryJson() ?? const {});
    }
    final session = await _runtime.start({
      'board_cells': 121,
      'pieces_per_player': 10,
      'first_actor': 'user',
      'search': 'iterative_deepening_alpha_beta_beam_tt',
    });
    _checkersResultTimer?.cancel();
    _checkersResultTimer = null;
    if (session != null && mounted) {
      setState(() {
        _checkersResult = null;
        _engine = ChineseCheckersEngine(
          aiConfig: ChineseCheckersAiConfig.fromJson(session.engineConfig),
        );
        _lastMove = null;
        _selected = null;
        _targets = const {};
        _moveAnimating = false;
      });
    }
  }

  Future<void> _tapCell(int index) async {
    final engine = _engine;
    if (engine == null ||
        engine.isFinished ||
        _runtime.aiThinking ||
        _moveAnimating) {
      return;
    }
    final target = _targets[index];
    if (_selected != null && target != null) {
      final before = engine.stateJson();
      final result = engine.playPath(target);
      setState(() {
        _lastMove = result.move;
        _moveAnimating = true;
        _selected = null;
        _targets = const {};
      });
      _NativeGameHaptics.jump(
        hops: result.move.isJump ? math.max(2, result.move.path.length - 1) : 1,
        keyMoment: result.move.moment != null,
      );
      try {
        await Future.wait([
          _reportMove(result.move, before),
          Future<void>.delayed(_checkersMoveDuration(result.move)),
        ]);
      } finally {
        if (mounted) setState(() => _moveAnimating = false);
      }
      if (result.status != ChineseCheckersStatus.playing) {
        await _finish(result.status);
      } else {
        await _agentTurn();
      }
      return;
    }
    final paths = engine.legalPathsFrom(index);
    final targets = <int, List<int>>{};
    for (final path in paths) {
      targets[path.last] = _shorterPath(targets[path.last], path);
    }
    setState(() {
      _selected = paths.isEmpty ? null : index;
      _targets = targets;
    });
    if (paths.isNotEmpty) _NativeGameHaptics.selection();
  }

  List<int> _shorterPath(List<int>? existing, List<int> candidate) =>
      existing == null || candidate.length < existing.length
      ? candidate
      : existing;

  Future<void> _agentTurn() async {
    final engine = _engine;
    if (engine == null || engine.isFinished) return;
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
      final before = engine.stateJson();
      final decision = await engine.chooseAiMove();
      if (!mounted) return;
      await _runtime.reportEvent('ai_move_decided', payload: decision.toJson());
      await _runtime.paceAiMove(sw);
      if (!mounted || engine.isFinished) return;
      final result = engine.playPath(decision.path, decision: decision);
      if (mounted) {
        setState(() {
          _lastMove = result.move;
          _moveAnimating = true;
        });
      }
      _NativeGameHaptics.jump(
        hops: result.move.isJump ? math.max(2, result.move.path.length - 1) : 1,
        keyMoment: result.move.moment != null,
      );
      try {
        await Future.wait([
          _reportMove(result.move, before),
          Future<void>.delayed(_checkersMoveDuration(result.move)),
        ]);
      } finally {
        if (mounted) setState(() => _moveAnimating = false);
      }
      if (result.status != ChineseCheckersStatus.playing) {
        await _finish(result.status);
      }
    } finally {
      if (mounted) setState(() => _runtime.aiThinking = false);
    }
  }

  Future<void> _reportMove(
    ChineseCheckersMove move,
    Map<String, dynamic> before,
  ) async {
    final engine = _engine!;
    await _runtime.reportEvent(
      'piece_moved',
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
        payload: {...move.moment!, 'move_number': move.number},
      );
    }
  }

  Future<void> _finish(ChineseCheckersStatus status) async {
    final summary = _engine!.summaryJson();
    await _runtime.finish({
      ...summary,
      'user_outcome': status == ChineseCheckersStatus.userWon ? 'win' : 'lose',
      'terminal_state': {'status': status.name},
      'state_after_hash': (_engine!.stateJson()['state_hash']),
    });
  }

  @override
  Widget build(BuildContext context) {
    final engine = _engine;
    // Hold the final board briefly, then reveal the full-screen result.
    if (engine != null &&
        engine.isFinished &&
        _checkersResult == null &&
        _checkersResultTimer == null) {
      final win = engine.status == ChineseCheckersStatus.userWon;
      _checkersResultTimer = Timer(const Duration(milliseconds: 1400), () {
        if (!mounted || _checkersResult != null) return;
        setState(
          () => _checkersResult = win
              ? _CheckersResultKind.win
              : _CheckersResultKind.lose,
        );
      });
    }

    final Widget child;
    if (engine == null) {
      child = KeyedSubtree(
        key: const ValueKey('checkers-home'),
        child: _CheckersHome(
          stats: _runtime.recordStats,
          starting: _runtime.starting,
          error: _runtime.error,
          onStart: _start,
          onExit: () => Navigator.of(context).maybePop(),
        ),
      );
    } else if (_checkersResult != null) {
      // Full-screen result replaces the game — board/avatars/dial torn down.
      child = _CheckersResultScreen(
        key: const ValueKey('checkers-result'),
        kind: _checkersResult!,
        pointsDelta: _runtime.pointRules?.deltaFor(
          _checkersResult == _CheckersResultKind.win
              ? GameOutcome.win
              : GameOutcome.lose,
        ),
        onRestart: _start,
        onExit: _closeCheckersGame,
      );
    } else {
      final userTurnActive =
          !engine.isFinished && !_runtime.aiThinking && !_moveAnimating;
      child = PopScope(
        key: const ValueKey('checkers-game'),
        canPop: false,
        child: _NativeGameInteractionLayer(
          runtime: _runtime,
          game: widget.game,
          onPlayAgain: _start,
          onCloseGame: _closeCheckersGame,
          userTurnActive: userTurnActive,
          turnToken:
              '${_runtime.session?.id}:${engine.moveCount}:${_runtime.aiThinking ? 'agent' : 'user'}',
          turnTimeout: _nativeGameTurnTimeout(_nativeChineseCheckersGameKey),
          turnLabel: _runtime.aiThinking ? '${_runtime.agentName} 在走' : '轮到你',
          moveCount: engine.moveCount,
          showPlayers: false,
          // The page renders its own full-screen result screen.
          suppressResult: true,
          child: _CheckersGameScreen(
            engine: engine,
            lastMove: _lastMove,
            selected: _selected,
            targets: _targets,
            agentName: _runtime.agentName,
            userName: widget.authSession.userFacingName,
            agentAvatarUrl: widget.authSession.agentAvatarUrl,
            userAvatarUrl: widget.authSession.userAvatarUrl,
            aiThinking: _runtime.aiThinking,
            enabled: userTurnActive,
            onTap: _tapCell,
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

class _Match3GamePage extends StatefulWidget {
  const _Match3GamePage({
    required this.api,
    required this.authSession,
    required this.game,
  });
  final CompanionApi api;
  final AuthSession authSession;
  final _GameTile game;

  @override
  State<_Match3GamePage> createState() => _Match3GamePageState();
}

class _Match3GamePageState extends State<_Match3GamePage> {
  late final _NativeGameRuntime _runtime;
  Match3Engine? _engine;
  Match3Turn? _lastTurn;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _runtime = _NativeGameRuntime(
      api: widget.api,
      authSession: widget.authSession,
      gameKey: _nativeMatch3GameKey,
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
    setState(() {
      _engine = null;
      _lastTurn = null;
      _resolving = false;
    });
  }

  Future<void> _start() async {
    final old = _engine;
    if (_runtime.session != null && !_runtime.completed) {
      await _runtime.abort('restarted', old?.summaryJson() ?? const {});
    }
    final session = await _runtime.start(
      {'board_size': 8, 'mode': 'cooperate', 'first_actor': 'user'},
      payloadBuilder: (created) {
        final config = Match3GameConfig.fromJson(created.engineConfig);
        return {
          'board_size': 8,
          'mode': 'cooperate',
          'turn_limit': config.turnLimit,
          'target_score': config.targetScore,
          'first_actor': 'user',
        };
      },
    );
    if (session != null && mounted) {
      final config = Match3GameConfig.fromJson(session.engineConfig);
      setState(() {
        _engine = Match3Engine(
          seed: session.id.hashCode,
          turnLimit: config.turnLimit,
          targetScore: config.targetScore,
          agentChoicePercentile: config.agentChoicePercentile,
        );
        _lastTurn = null;
        _resolving = false;
      });
    }
  }

  Future<void> _tileSwipe(Match3Swap swap) async {
    final engine = _engine;
    if (engine == null ||
        engine.isFinished ||
        engine.turn != Match3Actor.user ||
        _resolving ||
        _runtime.aiThinking) {
      return;
    }
    if (!engine.isLegalSwap(swap)) return;
    final before = engine.stateJson();
    final result = engine.swap(swap);
    await _presentTurn(result.turn, before);
    if (result.status != Match3Status.playing) {
      await _finishMatch3(result.status);
    } else {
      await _match3AgentTurn();
    }
  }

  Future<void> _match3AgentTurn() async {
    final engine = _engine;
    if (engine == null || engine.isFinished) return;
    final sw = Stopwatch()..start();
    setState(() => _runtime.aiThinking = true);
    try {
      if (!mounted || engine.isFinished || engine.turn != Match3Actor.agent) {
        return;
      }
      final before = engine.stateJson();
      final decision = engine.chooseAgentSwap();
      await _runtime.reportEvent('ai_move_decided', payload: decision.toJson());
      await _runtime.paceAiMove(sw);
      if (!mounted || engine.isFinished || engine.turn != Match3Actor.agent) {
        return;
      }
      final result = engine.swap(decision.swap, decision: decision);
      await _presentTurn(result.turn, before);
      if (result.status != Match3Status.playing) {
        await _finishMatch3(result.status);
      }
    } finally {
      if (mounted) setState(() => _runtime.aiThinking = false);
    }
  }

  Future<void> _presentTurn(
    Match3Turn turn,
    Map<String, dynamic> before,
  ) async {
    if (!mounted) return;
    setState(() {
      _lastTurn = turn;
      _resolving = true;
    });
    _NativeGameHaptics.match3Turn(turn.cascades.length);
    try {
      await Future.wait([
        _reportMatchTurn(turn, before),
        Future<void>.delayed(_match3RemainingAnimationDuration(turn)),
      ]);
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _reportMatchTurn(
    Match3Turn turn,
    Map<String, dynamic> before,
  ) async {
    await _runtime.reportEvent(
      'tiles_swapped',
      state: 'playing',
      payload: {
        ...turn.toJson(),
        'action_id': '${_runtime.session?.id}:${turn.number}',
        'state_before': before,
        'state_after': _engine!.stateJson(),
        'analysis': _engine!.analysisJson(),
      },
    );
    for (final cascade in turn.cascades) {
      await _runtime.reportEvent(
        'cascade_resolved',
        payload: {
          'move_number': turn.number,
          'actor': turn.actor.name,
          ...cascade.toJson(),
        },
      );
    }
    if (turn.shuffled) {
      await _runtime.reportEvent(
        'board_shuffled',
        payload: {
          'move_number': turn.number,
          'state_after': _engine!.stateJson(),
        },
      );
    }
    if (turn.moment != null) {
      await _runtime.reportEvent(
        'key_moment',
        payload: {...turn.moment!, 'move_number': turn.number},
      );
    }
  }

  Future<void> _finishMatch3(Match3Status status) async {
    final summary = _engine!.summaryJson();
    await _runtime.finish({
      ...summary,
      'user_outcome': status == Match3Status.completed ? 'win' : 'lose',
      'terminal_state': {'status': status.name},
      'state_after_hash': _engine!.stateHash.toString(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final engine = _engine;
    return _NativeGameExperienceScaffold(
      runtime: _runtime,
      game: widget.game,
      subtitle: engine == null
          ? '和 ${_runtime.agentName} 一起接连消'
          : _resolving
          ? '连消还在继续'
          : _runtime.aiThinking
          ? '${_runtime.agentName} 正在找下一组'
          : engine.isFinished
          ? engine.status == Match3Status.completed
                ? '我们一起过关了'
                : '这一关差一点'
          : '轮到你交换相邻方块',
      onStart: _start,
      onActiveRoundDeleted: _clearActiveRound,
      restartDisabled: _runtime.aiThinking || _resolving,
      userTurnActive:
          engine != null &&
          !engine.isFinished &&
          engine.turn == Match3Actor.user &&
          !_resolving &&
          !_runtime.aiThinking,
      turnToken: engine == null
          ? 'idle'
          : '${engine.turns.length}:${engine.turn.name}',
      turnLabel: _runtime.aiThinking
          ? '${_runtime.agentName} 在交换'
          : _resolving
          ? '连消结算中'
          : '轮到你交换',
      moveCount: engine?.turns.length ?? 0,
      currentSummary: () => _engine?.summaryJson() ?? const {},
      activeChild: engine == null
          ? null
          : Column(
              children: [
                _NativeScoreHeader(
                  // 合作模式：左右是双方贡献分，中间是共同目标进度。
                  left: '你 ${engine.userScore}',
                  center: '共同 ${engine.totalScore}/${engine.targetScore}',
                  right: '${_runtime.agentName} ${engine.agentScore}',
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _Match3Board(
                      engine: engine,
                      lastTurn: _lastTurn,
                      thinking: _runtime.aiThinking && !_resolving,
                      enabled:
                          engine.turn == Match3Actor.user &&
                          !_resolving &&
                          !_runtime.aiThinking &&
                          !engine.isFinished,
                      onSwap: _tileSwipe,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _Match3MissionBar(
                  score: engine.totalScore,
                  target: engine.targetScore,
                  movesRemaining: engine.turnsRemaining,
                ),
              ],
            ),
    );
  }
}
