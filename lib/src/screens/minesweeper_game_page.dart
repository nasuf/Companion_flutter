part of 'package:companion_flutter/main.dart';

enum _MinesweeperTool { reveal, flag }

class _MinesweeperGamePage extends StatefulWidget {
  const _MinesweeperGamePage({
    required this.api,
    required this.authSession,
    required this.game,
  });

  final CompanionApi api;
  final AuthSession authSession;
  final _GameTile game;

  @override
  State<_MinesweeperGamePage> createState() => _MinesweeperGamePageState();
}

class _MinesweeperGamePageState extends State<_MinesweeperGamePage> {
  late final _NativeGameRuntime _runtime;
  MinesweeperEngine? _engine;
  MinesweeperAction? _lastAction;
  final List<Map<String, dynamic>> _actionHistory = [];
  _MinesweeperTool _tool = _MinesweeperTool.reveal;
  bool _resolving = false;
  // True while the pause / exit sheet is on screen.
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _runtime = _NativeGameRuntime(
      api: widget.api,
      authSession: widget.authSession,
      gameKey: _nativeMinesweeperGameKey,
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
    unawaited(_runtime.initialize());
  }

  @override
  void dispose() {
    _runtime.dispose();
    unawaited(
      _runtime.abort('page_closed', _sessionSummary(), updateUi: false),
    );
    super.dispose();
  }

  void _clearActiveRound() {
    setState(() {
      _engine = null;
      _lastAction = null;
      _actionHistory.clear();
      _tool = _MinesweeperTool.reveal;
      _resolving = false;
    });
  }

  Future<void> _start() async {
    if (_runtime.session != null && !_runtime.completed) {
      await _runtime.abort('restarted', _sessionSummary());
    }
    final session = await _runtime.start(
      {
        'first_actor': 'user',
        'mode': 'cooperative',
        'rules': 'first_move_safe_bounded_no_guess_board_generation',
        'solver': 'constraint_propagation_subset_bounded_component_probability',
      },
      payloadBuilder: (created) {
        final config = MinesweeperGameConfig.fromJson(created.engineConfig);
        return {
          'board_size': {'rows': config.rows, 'columns': config.columns},
          'mine_count': config.mineCount,
          'first_actor': 'user',
          'mode': 'cooperative',
          'rules': config.requireNoGuess
              ? 'first_move_safe_bounded_no_guess_board_generation'
              : 'first_move_safe_seeded_board_generation',
          'solver':
              'constraint_propagation_subset_bounded_component_probability',
        };
      },
    );
    if (session != null && mounted) {
      final config = MinesweeperGameConfig.fromJson(session.engineConfig);
      setState(() {
        _engine = MinesweeperEngine(
          seed: session.id.hashCode,
          rows: config.rows,
          columns: config.columns,
          mineCount: config.mineCount,
          requireNoGuess: config.requireNoGuess,
          generationAttempts: config.generationAttempts,
        );
        _lastAction = null;
        _actionHistory.clear();
        _tool = _MinesweeperTool.reveal;
        _resolving = false;
      });
    }
  }

  Future<void> _userAct(int index, {bool forceFlag = false}) async {
    final engine = _engine;
    if (engine == null ||
        engine.isFinished ||
        engine.turn != MinesweeperActor.user ||
        _runtime.aiThinking ||
        _resolving ||
        engine.isRevealed(index)) {
      return;
    }
    final flag = forceFlag || _tool == _MinesweeperTool.flag;
    if (!flag && engine.isFlagged(index)) return;
    await _applyAndReport(index, flag: flag);
    if (!engine.isFinished && engine.turn == MinesweeperActor.agent) {
      await _agentTurn();
    }
  }

  Future<void> _agentTurn() async {
    final engine = _engine;
    if (engine == null || engine.isFinished) return;
    setState(() => _runtime.aiThinking = true);
    try {
      await _runtime.reportEvent(
        'ai_thinking_started',
        payload: {
          'action_number': engine.actionCount + 1,
          'visible_analysis': engine.analysisJson(),
        },
      );
      final decision = await engine.chooseAiAction();
      if (!mounted ||
          engine.isFinished ||
          engine.turn != MinesweeperActor.agent) {
        return;
      }
      await _runtime.reportEvent('ai_move_decided', payload: decision.toJson());
      await Future<void>.delayed(const Duration(milliseconds: 360));
      if (!mounted ||
          engine.isFinished ||
          engine.turn != MinesweeperActor.agent) {
        return;
      }
      await _applyAndReport(
        decision.point.index(engine.columns),
        flag: decision.kind == MinesweeperActionKind.flag,
        decision: decision,
      );
    } finally {
      if (mounted) setState(() => _runtime.aiThinking = false);
    }
  }

  Future<void> _applyAndReport(
    int index, {
    required bool flag,
    MinesweeperAiDecision? decision,
  }) async {
    final engine = _engine!;
    final before = engine.stateJson();
    final result = flag
        ? engine.toggleFlag(index, decision: decision)
        : engine.reveal(index, decision: decision);
    if (mounted) {
      setState(() {
        _lastAction = result.action;
        _resolving = true;
      });
    }
    _NativeGameHaptics.mineAction(
      hitMine: result.action.hitMine,
      revealedCount: result.action.revealed.length,
      flagAction:
          result.action.kind == MinesweeperActionKind.flag ||
          result.action.kind == MinesweeperActionKind.unflag,
    );
    final animationTime = result.action.hitMine
        ? const Duration(milliseconds: 980)
        : result.action.revealed.length >= 8
        ? const Duration(milliseconds: 820)
        : const Duration(milliseconds: 560);
    try {
      await Future.wait([
        _reportAction(result.action, before),
        Future<void>.delayed(animationTime),
      ]);
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
    if (result.status == MinesweeperStatus.completed ||
        result.status == MinesweeperStatus.failed) {
      await _finish(result.status);
    }
  }

  Future<void> _reportAction(
    MinesweeperAction action,
    Map<String, dynamic> before,
  ) async {
    final engine = _engine!;
    final canonicalAction = <String, dynamic>{
      ...action.toJson(),
      'action_id': '${_runtime.session?.id}:${action.number}',
      'state_before': before,
      'state_after': engine.stateJson(revealMines: true),
      'analysis': engine.analysisJson(),
    };
    _actionHistory.add(canonicalAction);
    await _runtime.reportEvent(
      'cell_action',
      state: 'playing',
      payload: canonicalAction,
    );
    if (action.revealed.isNotEmpty) {
      await _runtime.reportEvent(
        'cells_revealed',
        payload: {
          'action_number': action.number,
          'actor': action.actor.name,
          'origin': action.point.toJson(),
          'cells': action.revealed.map((point) => point.toJson()).toList(),
          'revealed_count': action.revealed.length,
          'hit_mine': action.hitMine,
        },
      );
    }
    if (action.kind == MinesweeperActionKind.flag ||
        action.kind == MinesweeperActionKind.unflag) {
      await _runtime.reportEvent(
        'flag_toggled',
        payload: {
          'action_number': action.number,
          'actor': action.actor.name,
          'at': action.point.toJson(),
          'flagged': action.flagged,
          'flags_used': engine.flagCount,
        },
      );
    }
    final decision = action.decision;
    if (decision != null) {
      await _runtime.reportEvent(
        'inference_made',
        payload: {
          'action_number': action.number,
          'actor': action.actor.name,
          ...decision.toJson(),
        },
      );
    }
    for (final moment in action.moments) {
      await _runtime.reportEvent(
        'key_moment',
        payload: {
          ...moment.toJson(),
          'action_number': action.number,
          'actor': action.actor.name,
          'at': action.point.toJson(),
        },
      );
    }
  }

  Future<void> _finish(MinesweeperStatus status) async {
    final engine = _engine!;
    await _runtime.finish({
      ..._sessionSummary(),
      'user_outcome': status == MinesweeperStatus.completed ? 'win' : 'lose',
      'shared_outcome': status == MinesweeperStatus.completed
          ? 'cleared_together'
          : 'mine_triggered',
      'terminal_state': {'status': status.name},
      'state_after_hash': engine.stateHash.toString(),
    });
  }

  Map<String, dynamic> _sessionSummary() => {
    ...?_engine?.summaryJson(),
    'actions': List<Map<String, dynamic>>.of(_actionHistory),
  };

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
    if (engine == null) {
      return _MinesweeperHome(
        rounds: _runtime.rounds,
        starting: _runtime.starting,
        error: _runtime.error,
        onStart: _start,
        onExit: () => Navigator.of(context).maybePop(),
      );
    }
    final userTurnActive =
        !engine.isFinished &&
        engine.turn == MinesweeperActor.user &&
        !_runtime.aiThinking &&
        !_resolving &&
        // The pause / exit sheet is up: the player is right there, so the idle
        // nudge shouldn't count down behind it.
        !_paused;
    return PopScope(
      canPop: false,
      child: _NativeGameInteractionLayer(
        runtime: _runtime,
        game: widget.game,
        onPlayAgain: _start,
        onCloseGame: _closeGame,
        userTurnActive: userTurnActive,
        turnToken:
            '${_runtime.session?.id}:${engine.actions.length}:${engine.turn.name}',
        turnTimeout: _nativeGameTurnTimeout(_nativeMinesweeperGameKey),
        turnLabel: _runtime.aiThinking
            ? '${_runtime.agentName} 在推理'
            : _resolving
            ? '线索展开中'
            : '轮到你判断',
        moveCount: engine.actions.length,
        showPlayers: false,
        child: _MinesweeperGameScreen(
          engine: engine,
          lastAction: _lastAction,
          agentName: _runtime.agentName,
          userName: widget.authSession.userFacingName,
          agentAvatarUrl: widget.authSession.agentAvatarUrl,
          userAvatarUrl: widget.authSession.userAvatarUrl,
          aiThinking: _runtime.aiThinking,
          starting: _runtime.starting,
          flagMode: _tool == _MinesweeperTool.flag,
          enabled: userTurnActive,
          onReveal: (index) => unawaited(_userAct(index)),
          onFlag: (index) => unawaited(_userAct(index, forceFlag: true)),
          onFlagModeChanged: (flag) {
            _NativeGameHaptics.selection();
            setState(
              () => _tool = flag
                  ? _MinesweeperTool.flag
                  : _MinesweeperTool.reveal,
            );
          },
          onRestart: _start,
          onExit: _closeGame,
          onPauseChanged: _setPaused,
        ),
      ),
    );
  }

  void _setPaused(bool value) {
    if (_paused == value || !mounted) return;
    setState(() => _paused = value);
  }
}
