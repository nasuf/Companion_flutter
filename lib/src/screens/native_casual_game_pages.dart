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
  int? _selected;
  Map<int, List<int>> _targets = const {};

  @override
  void initState() {
    super.initState();
    _runtime = _NativeGameRuntime(
      api: widget.api,
      authSession: widget.authSession,
      gameKey: _nativeChineseCheckersGameKey,
      gameTitle: widget.game.title,
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final resume = await _runtime.initialize();
    if (!mounted || resume == null) return;
    try {
      final engine = resume.state.isEmpty
          ? ChineseCheckersEngine()
          : ChineseCheckersEngine.restore(
              resume.state,
              actionCount: resume.actionCount,
            );
      setState(() {
        _engine = engine;
        _selected = null;
        _targets = const {};
      });
      if (engine.isFinished) {
        unawaited(_finish(engine.status));
      } else if (engine.turn == ChineseCheckersActor.agent) {
        unawaited(_agentTurn());
      }
    } catch (caught) {
      _runtime.syncNotice = '上一局棋盘无法恢复，可以重新开一局：$caught';
      if (mounted) setState(() {});
    }
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
    if (session != null && mounted) {
      setState(() {
        _engine = ChineseCheckersEngine();
        _selected = null;
        _targets = const {};
      });
    }
  }

  Future<void> _tapCell(int index) async {
    final engine = _engine;
    if (engine == null || engine.isFinished || _runtime.aiThinking) return;
    final target = _targets[index];
    if (_selected != null && target != null) {
      final before = engine.stateJson();
      final result = engine.playPath(target);
      setState(() {
        _selected = null;
        _targets = const {};
      });
      await _reportMove(result.move, before);
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
    if (paths.isNotEmpty) unawaited(HapticFeedback.selectionClick());
  }

  List<int> _shorterPath(List<int>? existing, List<int> candidate) =>
      existing == null || candidate.length < existing.length
      ? candidate
      : existing;

  Future<void> _agentTurn() async {
    final engine = _engine;
    if (engine == null || engine.isFinished) return;
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
      final result = engine.playPath(decision.path, decision: decision);
      await _reportMove(result.move, before);
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
    return _NativeGameExperienceScaffold(
      runtime: _runtime,
      game: widget.game,
      subtitle: engine == null
          ? '和 ${_runtime.agentName} 跳过整片棋盘'
          : _runtime.aiThinking
          ? '${_runtime.agentName} 正在找一条长跳'
          : engine.isFinished
          ? '这一局结束了'
          : '轮到你移动棋子',
      onStart: _start,
      restartDisabled: _runtime.aiThinking,
      historySubtitle: '每条连续跳路径和进营过程都会保存。',
      activeChild: engine == null
          ? null
          : Column(
              children: [
                _NativeScoreHeader(
                  left: '你 ${engine.analysisJson()['user_target_pieces']}/10',
                  center: '${engine.moves.length} 步',
                  right:
                      '${_runtime.agentName} ${engine.analysisJson()['agent_target_pieces']}/10',
                ),
                const SizedBox(height: 10),
                AspectRatio(
                  aspectRatio: 1,
                  child: _ChineseCheckersBoard(
                    engine: engine,
                    selected: _selected,
                    targets: _targets,
                    onTap: _tapCell,
                  ),
                ),
              ],
            ),
    );
  }
}

class _LudoGamePage extends StatefulWidget {
  const _LudoGamePage({
    required this.api,
    required this.authSession,
    required this.game,
  });
  final CompanionApi api;
  final AuthSession authSession;
  final _GameTile game;

  @override
  State<_LudoGamePage> createState() => _LudoGamePageState();
}

class _LudoGamePageState extends State<_LudoGamePage> {
  late final _NativeGameRuntime _runtime;
  LudoEngine? _engine;
  int? _lastRoll;

  @override
  void initState() {
    super.initState();
    _runtime = _NativeGameRuntime(
      api: widget.api,
      authSession: widget.authSession,
      gameKey: _nativeLudoGameKey,
      gameTitle: widget.game.title,
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final resume = await _runtime.initialize();
    if (!mounted || resume == null) return;
    try {
      final engine = resume.state.isEmpty
          ? LudoEngine(seed: resume.session.id.hashCode)
          : LudoEngine.restore(
              resume.state,
              moveCount: resume.actionCount,
              rollCount: resume.rollCount,
              seed: resume.session.id.hashCode,
            );
      setState(() {
        _engine = engine;
        _lastRoll = engine.pendingRoll?.value;
      });
      if (engine.isFinished) {
        unawaited(_finishLudo(engine.status));
      } else if (engine.turn == LudoActor.agent) {
        unawaited(_agentLoop());
      }
    } catch (caught) {
      _runtime.syncNotice = '上一局飞行棋无法恢复，可以重新开一局：$caught';
      if (mounted) setState(() {});
    }
  }

  Future<void> _start() async {
    final old = _engine;
    if (_runtime.session != null && !_runtime.completed) {
      await _runtime.abort('restarted', old?.summaryJson() ?? const {});
    }
    final session = await _runtime.start({
      'pieces_per_player': 4,
      'first_actor': 'user',
      'rules':
          'launch_6_color_jump_cross_board_shortcut_capture_exact_finish_three_sixes',
      'search': 'stochastic_expectimax',
    });
    if (session != null && mounted) {
      setState(() {
        _engine = LudoEngine(seed: session.id.hashCode);
        _lastRoll = null;
      });
    }
  }

  Future<void> _userRoll() async {
    final engine = _engine;
    if (engine == null ||
        engine.turn != LudoActor.user ||
        engine.pendingRoll != null) {
      return;
    }
    final beforeTurn = engine.turn;
    final roll = engine.roll();
    setState(() => _lastRoll = roll.value);
    unawaited(HapticFeedback.mediumImpact());
    await _reportRoll(roll);
    if (roll.legalPieces.isEmpty && engine.turn != beforeTurn) {
      await _agentLoop();
    }
  }

  Future<void> _userPiece(int index) async {
    final engine = _engine;
    final roll = engine?.pendingRoll;
    if (engine == null ||
        engine.turn != LudoActor.user ||
        roll == null ||
        !roll.legalPieces.contains(index)) {
      return;
    }
    final before = engine.stateJson();
    final result = engine.movePiece(index);
    await _reportLudoMove(result.move, before);
    if (result.status != LudoStatus.playing) {
      await _finishLudo(result.status);
    } else if (engine.turn == LudoActor.agent) {
      await _agentLoop();
    }
    if (mounted) setState(() {});
  }

  Future<void> _agentLoop() async {
    final engine = _engine;
    if (engine == null) return;
    setState(() => _runtime.aiThinking = true);
    try {
      var guard = 0;
      while (mounted &&
          !engine.isFinished &&
          engine.turn == LudoActor.agent &&
          guard++ < 8) {
        await Future<void>.delayed(const Duration(milliseconds: 520));
        if (!mounted) break;
        final existingRoll = engine.pendingRoll;
        final roll = existingRoll ?? engine.roll();
        setState(() => _lastRoll = roll.value);
        if (existingRoll == null) await _reportRoll(roll);
        if (roll.legalPieces.isEmpty) continue;
        final before = engine.stateJson();
        final decision = engine.chooseAgentPiece();
        await _runtime.reportEvent(
          'ai_move_decided',
          payload: decision.toJson(),
        );
        final result = engine.movePiece(
          decision.pieceIndex,
          decision: decision,
        );
        await _reportLudoMove(result.move, before);
        if (result.status != LudoStatus.playing) {
          await _finishLudo(result.status);
          break;
        }
      }
    } finally {
      if (mounted) setState(() => _runtime.aiThinking = false);
    }
  }

  Future<void> _reportRoll(LudoRoll roll) async {
    final after = _engine!.stateJson();
    await _runtime.reportEvent(
      'dice_rolled',
      state: 'playing',
      payload: {
        ...roll.toJson(),
        'state_before_hash': roll.stateHash.toString(),
        'state_after_hash': after['state_hash'],
        'state_after': after,
        'analysis': _engine!.analysisJson(),
      },
    );
  }

  Future<void> _reportLudoMove(
    LudoMove move,
    Map<String, dynamic> before,
  ) async {
    await _runtime.reportEvent(
      'piece_moved',
      state: 'playing',
      payload: {
        ...move.toJson(),
        'action_id': '${_runtime.session?.id}:${move.number}',
        'state_before': before,
        'state_after': _engine!.stateJson(),
        'analysis': _engine!.analysisJson(),
        'extra_turn': move.extraTurn,
      },
    );
    if (move.moment != null) {
      await _runtime.reportEvent(
        'key_moment',
        payload: {...move.moment!, 'move_number': move.number},
      );
    }
  }

  Future<void> _finishLudo(LudoStatus status) async {
    final summary = _engine!.summaryJson();
    await _runtime.finish({
      ...summary,
      'user_outcome': status == LudoStatus.userWon ? 'win' : 'lose',
      'terminal_state': {'status': status.name},
      'state_after_hash': _engine!.stateHash.toString(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final engine = _engine;
    final legal = engine?.pendingRoll?.legalPieces.toSet() ?? const <int>{};
    return _NativeGameExperienceScaffold(
      runtime: _runtime,
      game: widget.game,
      subtitle: engine == null
          ? '和 ${_runtime.agentName} 掷一局运气'
          : _runtime.aiThinking
          ? '${_runtime.agentName} 正在掷骰子'
          : engine.turn == LudoActor.user
          ? engine.pendingRoll == null
                ? '轮到你掷骰子'
                : '选一架要走的飞机'
          : '等待 ${_runtime.agentName}',
      onStart: _start,
      restartDisabled: _runtime.aiThinking,
      historySubtitle: '每次骰面、路线、撞回和冲线都会保存。',
      activeChild: engine == null
          ? null
          : Column(
              children: [
                _NativeScoreHeader(
                  left:
                      '你 ${engine.pieces.where((piece) => piece.actor == LudoActor.user && piece.finished).length}/4',
                  center: _lastRoll == null ? '待掷骰' : '骰子 $_lastRoll',
                  right:
                      '${_runtime.agentName} ${engine.pieces.where((piece) => piece.actor == LudoActor.agent && piece.finished).length}/4',
                ),
                const SizedBox(height: 10),
                AspectRatio(
                  aspectRatio: 1,
                  child: _LudoBoard(
                    engine: engine,
                    selectablePieces: legal,
                    onPieceTap: _userPiece,
                  ),
                ),
                const SizedBox(height: 12),
                _LudoTurnConsole(
                  engine: engine,
                  agentName: _runtime.agentName,
                  lastRoll: _lastRoll,
                  aiThinking: _runtime.aiThinking,
                  onRoll: _userRoll,
                  onPieceTap: _userPiece,
                ),
              ],
            ),
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
  Match3Point? _selected;
  Match3Turn? _lastTurn;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _runtime = _NativeGameRuntime(
      api: widget.api,
      authSession: widget.authSession,
      gameKey: _nativeMatch3GameKey,
      gameTitle: widget.game.title,
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final resume = await _runtime.initialize();
    if (!mounted || resume == null) return;
    try {
      final engine = resume.state.isEmpty
          ? Match3Engine(seed: resume.session.id.hashCode)
          : Match3Engine.restore(
              resume.state,
              actionCount: resume.actionCount,
              seed: resume.session.id.hashCode,
            );
      setState(() {
        _engine = engine;
        _selected = null;
        _lastTurn = null;
        _resolving = false;
      });
      if (engine.isFinished) {
        unawaited(_finishMatch3(engine.status));
      } else if (engine.turn == Match3Actor.agent) {
        unawaited(_match3AgentTurn());
      }
    } catch (caught) {
      _runtime.syncNotice = '上一局消消乐无法恢复，可以重新开一局：$caught';
      if (mounted) setState(() {});
    }
  }

  Future<void> _start() async {
    final old = _engine;
    if (_runtime.session != null && !_runtime.completed) {
      await _runtime.abort('restarted', old?.summaryJson() ?? const {});
    }
    final session = await _runtime.start({
      'board_size': 8,
      'mode': 'cooperate',
      'turn_limit': 30,
      'target_score': 12000,
      'first_actor': 'user',
    });
    if (session != null && mounted) {
      setState(() {
        _engine = Match3Engine(seed: session.id.hashCode);
        _selected = null;
        _lastTurn = null;
        _resolving = false;
      });
    }
  }

  Future<void> _tileTap(Match3Point point) async {
    final engine = _engine;
    if (engine == null ||
        engine.isFinished ||
        engine.turn != Match3Actor.user ||
        _resolving ||
        _runtime.aiThinking) {
      return;
    }
    final selected = _selected;
    if (selected == null) {
      setState(() => _selected = point);
      unawaited(HapticFeedback.selectionClick());
      return;
    }
    if (selected == point) {
      setState(() => _selected = null);
      return;
    }
    final swap = Match3Swap(selected, point);
    final legal = engine.availableSwaps().any(
      (item) =>
          (item.a == swap.a && item.b == swap.b) ||
          (item.a == swap.b && item.b == swap.a),
    );
    if (!legal) {
      setState(() => _selected = point);
      unawaited(HapticFeedback.selectionClick());
      return;
    }
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
    setState(() => _runtime.aiThinking = true);
    await Future<void>.delayed(const Duration(milliseconds: 580));
    try {
      if (!mounted || engine.isFinished || engine.turn != Match3Actor.agent) {
        return;
      }
      final before = engine.stateJson();
      final decision = engine.chooseAgentSwap();
      await _runtime.reportEvent('ai_move_decided', payload: decision.toJson());
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
      _selected = null;
      _lastTurn = turn;
      _resolving = true;
    });
    unawaited(
      turn.cascades.length >= 3
          ? HapticFeedback.heavyImpact()
          : HapticFeedback.mediumImpact(),
    );
    try {
      await Future.wait([
        _reportMatchTurn(turn, before),
        Future<void>.delayed(_match3TurnAnimationDuration(turn)),
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
      restartDisabled: _runtime.aiThinking || _resolving,
      historySubtitle: '每次交换、连消、特殊块和贡献分都会保存。',
      activeChild: engine == null
          ? null
          : Column(
              children: [
                _NativeScoreHeader(
                  left: '你 ${engine.userScore}',
                  center: '${engine.totalScore}/${engine.targetScore}',
                  right: '${_runtime.agentName} ${engine.agentScore}',
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _Match3Board(
                      engine: engine,
                      selected: _selected,
                      lastTurn: _lastTurn,
                      thinking: _runtime.aiThinking && !_resolving,
                      onTap: _tileTap,
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

class _NativeGameExperienceScaffold extends StatefulWidget {
  const _NativeGameExperienceScaffold({
    required this.runtime,
    required this.game,
    required this.subtitle,
    required this.onStart,
    required this.restartDisabled,
    required this.historySubtitle,
    this.activeChild,
  });

  final _NativeGameRuntime runtime;
  final _GameTile game;
  final String subtitle;
  final Future<void> Function() onStart;
  final bool restartDisabled;
  final String historySubtitle;
  final Widget? activeChild;

  @override
  State<_NativeGameExperienceScaffold> createState() =>
      _NativeGameExperienceScaffoldState();
}

class _NativeGameExperienceScaffoldState
    extends State<_NativeGameExperienceScaffold> {
  bool _isFullscreen = false;

  @override
  void didUpdateWidget(covariant _NativeGameExperienceScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeChild == null && widget.activeChild != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.activeChild != null) {
          setState(() => _isFullscreen = true);
        }
      });
    }
  }

  Future<void> _start() async {
    await widget.onStart();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.activeChild != null) {
        setState(() => _isFullscreen = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeChild = widget.activeChild;
    if (_isFullscreen && activeChild != null) {
      return _NativeFullscreenGameSurface(
        title: widget.game.title,
        subtitle: widget.subtitle,
        onExit: () => setState(() => _isFullscreen = false),
        onRestart: _start,
        restartLabel: widget.runtime.completed ? '再来一局' : '重新开一局',
        restartDisabled: widget.runtime.starting || widget.restartDisabled,
        restartLoading: widget.runtime.starting,
        child: activeChild,
      );
    }
    return Scaffold(
      backgroundColor: AppColors.page,
      body: Stack(
        children: [
          const _GameBackground(progress: 0.5),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    MediaQuery.paddingOf(context).top + 12,
                    18,
                    14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(38, 38),
                        onPressed: () => Navigator.maybePop(context),
                        child: _GlassButton(
                          size: 38,
                          child: const Icon(
                            CupertinoIcons.chevron_left,
                            size: 17,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        widget.game.title,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 36,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          color: AppColors.text.withValues(alpha: 0.55),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                  child: _GlassPanel(
                    radius: 24,
                    padding: const EdgeInsets.all(13),
                    child: activeChild == null
                        ? Column(
                            children: [
                              AspectRatio(
                                aspectRatio: 1,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: _GamePlaceholderStage(
                                    game: widget.game,
                                  ),
                                ),
                              ),
                              if (widget.runtime.error != null) ...[
                                const SizedBox(height: 10),
                                _GomokuNotice(
                                  text: widget.runtime.error!,
                                  isError: true,
                                ),
                              ],
                              const SizedBox(height: 12),
                              _PrimaryGameButton(
                                label: '开始游戏',
                                loading:
                                    widget.runtime.starting ||
                                    widget.runtime.recovering,
                                disabled:
                                    widget.runtime.starting ||
                                    widget.runtime.recovering,
                                onPressed: _start,
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Align(
                                alignment: Alignment.centerRight,
                                child: _NativeFullscreenToggleButton(
                                  expanded: false,
                                  onPressed: () =>
                                      setState(() => _isFullscreen = true),
                                ),
                              ),
                              const SizedBox(height: 6),
                              activeChild,
                              if (widget.runtime.syncNotice != null) ...[
                                const SizedBox(height: 10),
                                _GomokuNotice(
                                  text: widget.runtime.syncNotice!,
                                  isError: false,
                                ),
                              ],
                              const SizedBox(height: 12),
                              _PrimaryGameButton(
                                label: widget.runtime.completed
                                    ? '再来一局'
                                    : '重新开一局',
                                loading: widget.runtime.starting,
                                disabled:
                                    widget.runtime.starting ||
                                    widget.restartDisabled,
                                onPressed: _start,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              if (widget.runtime.timeline.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                    child: _GlassPanel(
                      radius: 22,
                      padding: const EdgeInsets.fromLTRB(15, 14, 15, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.runtime.agentName} 在旁边',
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          for (final item
                              in widget.runtime.timeline.reversed.take(3))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _TimelineRow(item: item),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: _NativeGameHistory(
                  runtime: widget.runtime,
                  subtitle: widget.historySubtitle,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 42)),
            ],
          ),
        ],
      ),
    );
  }
}

class _NativeGameHistory extends StatelessWidget {
  const _NativeGameHistory({required this.runtime, required this.subtitle});
  final _NativeGameRuntime runtime;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '游戏回忆',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            if (runtime.rounds.isNotEmpty)
              _SoftCountPill(text: '${runtime.rounds.length} 局'),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: TextStyle(
            color: AppColors.text.withValues(alpha: 0.46),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 11),
        if (runtime.roundsLoading)
          const Center(child: CupertinoActivityIndicator())
        else if (runtime.rounds.isEmpty)
          const _GameRoundEmptyState(
            icon: CupertinoIcons.square_grid_3x2,
            title: '第一局还在等你',
            subtitle: '玩完以后，这里会留下你们共同的一局。',
          )
        else
          for (final round in runtime.rounds.take(8))
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _GameRoundCard(
                summary: _GameRoundSummary.fromSession(round),
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: false,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _GameRoundDetailSheet(
                    summary: _GameRoundSummary.fromSession(round),
                  ),
                ),
              ),
            ),
      ],
    ),
  );
}

class _NativeScoreHeader extends StatelessWidget {
  const _NativeScoreHeader({
    required this.left,
    required this.center,
    required this.right,
  });
  final String left;
  final String center;
  final String right;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: _score(left, CrossAxisAlignment.start)),
      Expanded(child: _score(center, CrossAxisAlignment.center)),
      Expanded(child: _score(right, CrossAxisAlignment.end)),
    ],
  );

  Widget _score(String text, CrossAxisAlignment alignment) => Column(
    crossAxisAlignment: alignment,
    children: [
      Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.text,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

class _ChineseCheckersBoard extends StatefulWidget {
  const _ChineseCheckersBoard({
    required this.engine,
    required this.selected,
    required this.targets,
    required this.onTap,
  });
  final ChineseCheckersEngine engine;
  final int? selected;
  final Map<int, List<int>> targets;
  final ValueChanged<int> onTap;

  @override
  State<_ChineseCheckersBoard> createState() => _ChineseCheckersBoardState();
}

class _ChineseCheckersBoardState extends State<_ChineseCheckersBoard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _targetPulse;

  @override
  void initState() {
    super.initState();
    _targetPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.targets.isNotEmpty) {
      _targetPulse.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _ChineseCheckersBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targets.isEmpty && widget.targets.isNotEmpty) {
      _targetPulse.repeat(reverse: true);
    } else if (oldWidget.targets.isNotEmpty && widget.targets.isEmpty) {
      _targetPulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _targetPulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _targetPulse,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          final index = _nearest(details.localPosition, constraints.biggest);
          if (index != null) widget.onTap(index);
        },
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _ChineseCheckersPainter(
              board: widget.engine.board,
              selected: widget.selected,
              targets: widget.targets,
              pulse: _targetPulse.value,
              darkMode: AppColors.isDark(context),
            ),
          ),
        ),
      ),
    ),
  );

  int? _nearest(Offset point, Size size) {
    final geometry = _checkersGeometry(size);
    var nearest = -1;
    var distance = double.infinity;
    for (final cell in ChineseCheckersEngine.cells) {
      final value = (geometry.positions[cell.index] - point).distanceSquared;
      if (value < distance) {
        distance = value;
        nearest = cell.index;
      }
    }
    return distance <= math.pow(geometry.spacing * .5, 2) ? nearest : null;
  }
}

class _ChineseCheckersPainter extends CustomPainter {
  const _ChineseCheckersPainter({
    required this.board,
    required this.selected,
    required this.targets,
    required this.pulse,
    required this.darkMode,
  });
  final List<int> board;
  final int? selected;
  final Map<int, List<int>> targets;
  final double pulse;
  final bool darkMode;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stage = RRect.fromRectAndRadius(rect, const Radius.circular(20));
    canvas.save();
    canvas.clipRRect(stage);
    canvas.drawRRect(
      stage,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: darkMode
              ? const [Color(0xFF172B2D), Color(0xFF0E2023)]
              : const [Color(0xFFEAF4EF), Color(0xFFD9EAE6)],
        ).createShader(rect),
    );
    final geometry = _checkersGeometry(size);
    final layout = geometry.positions;
    final star = _checkersStarPath(geometry.center, geometry.outerRadius);
    canvas.drawPath(
      star.shift(Offset(0, geometry.spacing * .13)),
      Paint()
        ..color = Colors.black.withValues(alpha: darkMode ? .34 : .2)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          geometry.spacing * .22,
        ),
    );
    canvas.drawPath(
      star,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE1AF74), Color(0xFFBF7A49), Color(0xFF8F5238)],
          stops: [0, .55, 1],
        ).createShader(star.getBounds()),
    );
    canvas.save();
    canvas.clipPath(star);
    final grainPaint = Paint()
      ..color = const Color(0xFF6D392B).withValues(alpha: .12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.55, geometry.spacing * .035);
    for (var line = 0; line < 18; line += 1) {
      final y = rect.top + rect.height * (line + .5) / 18;
      final wave = math.sin(line * 1.41) * geometry.spacing * .3;
      canvas.drawPath(
        Path()
          ..moveTo(rect.left - 12, y)
          ..cubicTo(
            rect.width * .28,
            y + wave,
            rect.width * .7,
            y - wave,
            rect.right + 12,
            y + wave * .25,
          ),
        grainPaint,
      );
    }
    canvas.restore();
    canvas.drawPath(
      star,
      Paint()
        ..color = const Color(0xFF6B3A2B).withValues(alpha: .62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = geometry.spacing * .09,
    );

    final holeRadius = geometry.spacing * .255;
    final userColor = const Color(0xFFFFBE45);
    final agentColor = const Color(0xFF4AA8F5);
    for (final cell in ChineseCheckersEngine.cells) {
      final center = layout[cell.index];
      final campColor = cell.row <= 3
          ? agentColor
          : cell.row >= 13
          ? userColor
          : const Color(0xFF4E2D25);
      canvas.drawCircle(
        center + Offset(0, holeRadius * .22),
        holeRadius * 1.12,
        Paint()..color = Colors.white.withValues(alpha: .2),
      );
      canvas.drawCircle(
        center,
        holeRadius * 1.08,
        Paint()..color = const Color(0xFF653C2E).withValues(alpha: .42),
      );
      canvas.drawCircle(
        center,
        holeRadius,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-.32, -.38),
            radius: .95,
            colors: [
              campColor.withValues(
                alpha: cell.row <= 3 || cell.row >= 13 ? .34 : .22,
              ),
              const Color(0xFF42281F).withValues(alpha: .72),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: holeRadius)),
      );
    }

    final jumpPaths = targets.values.where((path) => path.length > 2).toList();
    if (jumpPaths.isNotEmpty) {
      jumpPaths.sort((left, right) => right.length.compareTo(left.length));
      final path = Path()
        ..moveTo(
          layout[jumpPaths.first.first].dx,
          layout[jumpPaths.first.first].dy,
        );
      for (final index in jumpPaths.first.skip(1)) {
        path.lineTo(layout[index].dx, layout[index].dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: .48)
          ..style = PaintingStyle.stroke
          ..strokeWidth = geometry.spacing * .08
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    for (final target in targets.keys) {
      final center = layout[target];
      canvas.drawCircle(
        center,
        holeRadius * (1.3 + pulse * .24),
        Paint()
          ..color = Colors.white.withValues(alpha: .58 - pulse * .22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = geometry.spacing * .07,
      );
      canvas.drawCircle(
        center,
        holeRadius * .42,
        Paint()..color = Colors.white.withValues(alpha: .9),
      );
    }

    final pieceRadius = geometry.spacing * .37;
    for (final cell in ChineseCheckersEngine.cells) {
      final center = layout[cell.index];
      final actor = board[cell.index];
      if (actor >= 0) {
        final color = actor == ChineseCheckersActor.user.index
            ? userColor
            : agentColor;
        canvas.drawCircle(
          center + Offset(0, pieceRadius * .24),
          pieceRadius * 1.02,
          Paint()
            ..color = Colors.black.withValues(alpha: .34)
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              geometry.spacing * .07,
            ),
        );
        canvas.drawCircle(
          center,
          pieceRadius * 1.05,
          Paint()..color = Color.lerp(color, Colors.black, .24)!,
        );
        canvas.drawCircle(
          center,
          pieceRadius,
          Paint()
            ..shader =
                RadialGradient(
                  center: const Alignment(-.38, -.46),
                  radius: .92,
                  colors: [
                    Color.lerp(color, Colors.white, .46)!,
                    color,
                    Color.lerp(color, Colors.black, .2)!,
                  ],
                  stops: const [0, .48, 1],
                ).createShader(
                  Rect.fromCircle(center: center, radius: pieceRadius),
                ),
        );
        canvas.drawCircle(
          center - Offset(pieceRadius * .31, pieceRadius * .36),
          pieceRadius * .2,
          Paint()..color = Colors.white.withValues(alpha: .78),
        );
      }
      if (cell.index == selected) {
        canvas.drawCircle(
          center,
          pieceRadius * 1.34,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = geometry.spacing * .09,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ChineseCheckersPainter oldDelegate) =>
      oldDelegate.board != board ||
      oldDelegate.selected != selected ||
      oldDelegate.targets != targets ||
      oldDelegate.pulse != pulse ||
      oldDelegate.darkMode != darkMode;
}

class _ChineseCheckersGeometry {
  const _ChineseCheckersGeometry({
    required this.positions,
    required this.spacing,
    required this.center,
    required this.outerRadius,
  });

  final List<Offset> positions;
  final double spacing;
  final Offset center;
  final double outerRadius;
}

_ChineseCheckersGeometry _checkersGeometry(Size size) {
  final inset = size.shortestSide * .055;
  const rows = 16;
  const horizontalSteps = 12.0;
  final verticalSteps = rows * math.sqrt(3) / 2;
  final spacing = math.min(
    (size.width - inset * 2) / (horizontalSteps + 1.4),
    (size.height - inset * 2) / (verticalSteps + 1.4),
  );
  final xUnit = spacing / 2;
  final yUnit = spacing * math.sqrt(3) / 2;
  final centerX = size.width / 2;
  final top = (size.height - yUnit * rows) / 2;
  final positions = [
    for (final cell in ChineseCheckersEngine.cells)
      Offset(centerX + cell.x * xUnit, top + cell.row * yUnit),
  ];
  final center = Offset(centerX, top + yUnit * rows / 2);
  return _ChineseCheckersGeometry(
    positions: positions,
    spacing: spacing,
    center: center,
    outerRadius: yUnit * rows / 2 + spacing * .68,
  );
}

Path _checkersStarPath(Offset center, double radius) {
  final path = Path();
  for (var point = 0; point < 12; point += 1) {
    final angle = -math.pi / 2 + point * math.pi / 6;
    final distance = point.isEven ? radius : radius * .5;
    final position =
        center + Offset(math.cos(angle), math.sin(angle)) * distance;
    if (point == 0) {
      path.moveTo(position.dx, position.dy);
    } else {
      path.lineTo(position.dx, position.dy);
    }
  }
  return path..close();
}

class _LudoTurnConsole extends StatelessWidget {
  const _LudoTurnConsole({
    required this.engine,
    required this.agentName,
    required this.lastRoll,
    required this.aiThinking,
    required this.onRoll,
    required this.onPieceTap,
  });

  final LudoEngine engine;
  final String agentName;
  final int? lastRoll;
  final bool aiThinking;
  final Future<void> Function() onRoll;
  final ValueChanged<int> onPieceTap;

  @override
  Widget build(BuildContext context) {
    final pending = engine.pendingRoll;
    final isUserTurn = engine.turn == LudoActor.user;
    final legal = pending?.legalPieces ?? const <int>[];
    final title = aiThinking
        ? '$agentName 正在掷骰子'
        : !isUserTurn
        ? '等 $agentName 走完这一步'
        : pending == null
        ? '轮到你掷骰子'
        : legal.length == 1
        ? '只有这架飞机能走'
        : '选一架飞机前进 ${pending.value} 格';
    final detail = pending == null && isUserTurn
        ? '掷到 6 可以让停机坪里的飞机起飞，并获得一次额外机会。'
        : legal.isEmpty
        ? '这一骰没有可走的飞机，回合会自动交给对方。'
        : '你可以直接点棋盘上发光的飞机，也可以用下面的按钮选择。';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1824323F)),
      ),
      child: Row(
        children: [
          _LudoDiceFace(value: pending?.value ?? lastRoll),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text.withValues(alpha: .5),
                    fontSize: 10,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 9),
                if (!engine.isFinished && isUserTurn && pending == null)
                  SizedBox(
                    width: double.infinity,
                    child: _PrimaryGameButton(label: '掷骰子', onPressed: onRoll),
                  )
                else if (isUserTurn && legal.isNotEmpty)
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final index in legal)
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(72, 34),
                          onPressed: () => onPieceTap(index),
                          child: Container(
                            height: 34,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF5F5F),
                              borderRadius: BorderRadius.circular(11),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33EF5F5F),
                                  blurRadius: 9,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              '飞机 ${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LudoDiceFace extends StatelessWidget {
  const _LudoDiceFace({required this.value});
  final int? value;

  @override
  Widget build(BuildContext context) {
    final active = value != null && value! >= 1 && value! <= 6;
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF172433) : const Color(0xFFE8EDF1),
        borderRadius: BorderRadius.circular(17),
        boxShadow: active
            ? const [
                BoxShadow(
                  color: Color(0x30172433),
                  blurRadius: 12,
                  offset: Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: active
          ? CustomPaint(painter: _LudoDicePainter(value!))
          : const Icon(
              Icons.casino_rounded,
              color: Color(0xFF7B8791),
              size: 29,
            ),
    );
  }
}

class _LudoDicePainter extends CustomPainter {
  const _LudoDicePainter(this.value);
  final int value;

  @override
  void paint(Canvas canvas, Size size) {
    const patterns = <int, List<(int, int)>>{
      1: [(1, 1)],
      2: [(0, 0), (2, 2)],
      3: [(0, 0), (1, 1), (2, 2)],
      4: [(0, 0), (2, 0), (0, 2), (2, 2)],
      5: [(0, 0), (2, 0), (1, 1), (0, 2), (2, 2)],
      6: [(0, 0), (0, 1), (0, 2), (2, 0), (2, 1), (2, 2)],
    };
    final paint = Paint()..color = Colors.white;
    for (final (x, y) in patterns[value]!) {
      canvas.drawCircle(
        Offset(size.width * (.27 + x * .23), size.height * (.27 + y * .23)),
        size.width * .055,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LudoDicePainter oldDelegate) =>
      oldDelegate.value != value;
}

class _LudoBoard extends StatefulWidget {
  const _LudoBoard({
    required this.engine,
    required this.selectablePieces,
    required this.onPieceTap,
  });
  final LudoEngine engine;
  final Set<int> selectablePieces;
  final ValueChanged<int> onPieceTap;

  @override
  State<_LudoBoard> createState() => _LudoBoardState();
}

class _LudoBoardState extends State<_LudoBoard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _pulse,
    builder: (context, child) => LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final positions = _ludoPiecePositions(widget.engine, size);
        final hitSize = math.max(44.0, size.width / 9.5);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _LudoPainter(
                  pieces: widget.engine.pieces,
                  selectablePieces: widget.selectablePieces,
                  pulse: _pulse.value,
                ),
              ),
            ),
            for (final entry in positions.entries)
              if (entry.key.actor == LudoActor.user &&
                  widget.selectablePieces.contains(entry.key.index))
                Positioned(
                  left: entry.value.dx - hitSize / 2,
                  top: entry.value.dy - hitSize / 2,
                  width: hitSize,
                  height: hitSize,
                  child: Semantics(
                    button: true,
                    label: '选择飞机 ${entry.key.index + 1}',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => widget.onPieceTap(entry.key.index),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
          ],
        );
      },
    ),
  );
}

class _LudoPainter extends CustomPainter {
  const _LudoPainter({
    required this.pieces,
    required this.selectablePieces,
    required this.pulse,
  });
  final List<LudoPiece> pieces;
  final Set<int> selectablePieces;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final board = RRect.fromRectAndRadius(bounds, const Radius.circular(20));
    canvas.drawRRect(
      board,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFDFBF4), Color(0xFFEAF4F5), Color(0xFFF7EFE4)],
        ).createShader(bounds),
    );
    canvas.save();
    canvas.clipRRect(board);
    final center = Offset(size.width / 2, size.height / 2);
    final track = _ludoTrack(size);
    final userColor = const Color(0xFFEF5F5F);
    final agentColor = const Color(0xFF397BEF);
    const yellow = Color(0xFFF2B840);
    const green = Color(0xFF35AE7D);
    final yardSize = size.width * .29;
    _paintFlightYard(
      canvas,
      Rect.fromCenter(
        center: Offset(size.width * .24, size.height * .76),
        width: yardSize,
        height: yardSize,
      ),
      userColor,
    );
    _paintFlightYard(
      canvas,
      Rect.fromCenter(
        center: Offset(size.width * .76, size.height * .24),
        width: yardSize,
        height: yardSize,
      ),
      agentColor,
    );
    _paintFlightYard(
      canvas,
      Rect.fromCenter(
        center: Offset(size.width * .24, size.height * .24),
        width: yardSize,
        height: yardSize,
      ),
      green.withValues(alpha: .42),
    );
    _paintFlightYard(
      canvas,
      Rect.fromCenter(
        center: Offset(size.width * .76, size.height * .76),
        width: yardSize,
        height: yardSize,
      ),
      yellow.withValues(alpha: .46),
    );

    final cellRadius = size.width / 43;
    final routeColors = [userColor, yellow, agentColor, green];
    for (var i = 0; i < track.length; i++) {
      final safe = LudoEngine.safeGlobalCells.contains(i);
      final routeColor = routeColors[(i ~/ 13) % routeColors.length];
      canvas.drawCircle(
        track[i],
        cellRadius,
        Paint()
          ..color = safe
              ? routeColor.withValues(alpha: .82)
              : Color.lerp(Colors.white, routeColor, .16)!,
      );
      canvas.drawCircle(
        track[i],
        cellRadius,
        Paint()
          ..color = routeColor.withValues(alpha: .34)
          ..style = PaintingStyle.stroke,
      );
      if (safe) {
        canvas.drawPath(
          _flightStarPath(track[i], cellRadius * .55),
          Paint()..color = Colors.white.withValues(alpha: .88),
        );
      }
    }

    _paintHomeLane(canvas, size, LudoActor.user, userColor);
    _paintHomeLane(canvas, size, LudoActor.agent, agentColor);
    _paintShortcut(canvas, track, LudoActor.user, userColor);
    _paintShortcut(canvas, track, LudoActor.agent, agentColor);
    _paintFlightCenter(canvas, center, size.width * .105, [
      userColor,
      yellow,
      agentColor,
      green,
    ]);

    final positions = _ludoPiecePositionsFromPieces(pieces, size);
    for (final entry in positions.entries) {
      final piece = entry.key;
      final color = piece.actor == LudoActor.user ? userColor : agentColor;
      final radius = size.width / 27;
      if (piece.actor == LudoActor.user &&
          selectablePieces.contains(piece.index)) {
        canvas.drawCircle(
          entry.value,
          radius * (1.3 + pulse * .26),
          Paint()
            ..color = Color.lerp(
              const Color(0xFFFFC64B),
              const Color(0xFFEF5F5F),
              pulse,
            )!
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
      _paintPlane(
        canvas,
        entry.value,
        radius,
        color,
        piece.actor == LudoActor.user ? 0 : math.pi,
      );
    }
    canvas.restore();
  }

  void _paintFlightYard(Canvas canvas, Rect rect, Color color) {
    final radius = Radius.circular(rect.width * .18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()..color = color.withValues(alpha: .16),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(3), radius),
      Paint()
        ..color = color.withValues(alpha: .5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    for (final offset in const [
      Offset(-.22, -.22),
      Offset(.22, -.22),
      Offset(-.22, .22),
      Offset(.22, .22),
    ]) {
      canvas.drawCircle(
        Offset(
          rect.center.dx + offset.dx * rect.width,
          rect.center.dy + offset.dy * rect.height,
        ),
        rect.width * .105,
        Paint()..color = Colors.white.withValues(alpha: .72),
      );
    }
  }

  void _paintHomeLane(Canvas canvas, Size size, LudoActor actor, Color color) {
    final center = Offset(size.width / 2, size.height / 2);
    final start = actor == LudoActor.user
        ? Offset(size.width * .5, size.height * .88)
        : Offset(size.width * .5, size.height * .12);
    for (var step = 1; step <= 5; step++) {
      final point = Offset.lerp(start, center, step / 6)!;
      canvas.drawCircle(
        point,
        size.width / 43,
        Paint()..color = color.withValues(alpha: .66 + step * .045),
      );
      canvas.drawCircle(
        point,
        size.width / 43,
        Paint()
          ..color = Colors.white.withValues(alpha: .55)
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _paintShortcut(
    Canvas canvas,
    List<Offset> track,
    LudoActor actor,
    Color color,
  ) {
    final from =
        track[LudoEngine.globalCell(actor, LudoEngine.shortcutEntryProgress)];
    final to =
        track[LudoEngine.globalCell(actor, LudoEngine.shortcutExitProgress)];
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = color.withValues(alpha: .22)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = Colors.white.withValues(alpha: .52)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintFlightCenter(
    Canvas canvas,
    Offset center,
    double radius,
    List<Color> colors,
  ) {
    for (var index = 0; index < 4; index++) {
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + math.cos(index * math.pi / 2 - math.pi / 4) * radius,
          center.dy + math.sin(index * math.pi / 2 - math.pi / 4) * radius,
        )
        ..lineTo(
          center.dx +
              math.cos((index + 1) * math.pi / 2 - math.pi / 4) * radius,
          center.dy +
              math.sin((index + 1) * math.pi / 2 - math.pi / 4) * radius,
        )
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = colors[index].withValues(alpha: .8),
      );
    }
    canvas.drawCircle(
      center,
      radius * .26,
      Paint()..color = Colors.white.withValues(alpha: .92),
    );
  }

  void _paintPlane(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double rotation,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy + radius * .1);
    canvas.rotate(rotation);
    canvas.scale(radius, radius);
    final shadow = Path()
      ..moveTo(0, -1.05)
      ..lineTo(.25, -.3)
      ..lineTo(.9, .05)
      ..lineTo(.88, .34)
      ..lineTo(.2, .18)
      ..lineTo(.26, .82)
      ..lineTo(0, 1)
      ..lineTo(-.26, .82)
      ..lineTo(-.2, .18)
      ..lineTo(-.88, .34)
      ..lineTo(-.9, .05)
      ..lineTo(-.25, -.3)
      ..close();
    canvas.translate(0, .12);
    canvas.drawPath(shadow, Paint()..color = const Color(0x3D13202C));
    canvas.translate(0, -.12);
    canvas.drawPath(shadow, Paint()..color = color);
    canvas.drawPath(
      Path()
        ..moveTo(0, -.88)
        ..lineTo(.12, .5)
        ..lineTo(0, .72)
        ..lineTo(-.12, .5)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: .74),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LudoPainter oldDelegate) =>
      oldDelegate.pieces != pieces ||
      oldDelegate.selectablePieces != selectablePieces ||
      oldDelegate.pulse != pulse;
}

Path _flightStarPath(Offset center, double radius) {
  final path = Path();
  for (var point = 0; point < 10; point++) {
    final angle = -math.pi / 2 + point * math.pi / 5;
    final distance = point.isEven ? radius : radius * .43;
    final offset = center + Offset(math.cos(angle), math.sin(angle)) * distance;
    if (point == 0) {
      path.moveTo(offset.dx, offset.dy);
    } else {
      path.lineTo(offset.dx, offset.dy);
    }
  }
  return path..close();
}

Map<LudoPiece, Offset> _ludoPiecePositions(LudoEngine engine, Size size) =>
    _ludoPiecePositionsFromPieces(engine.pieces, size);

Map<LudoPiece, Offset> _ludoPiecePositionsFromPieces(
  List<LudoPiece> pieces,
  Size size,
) {
  final track = _ludoTrack(size);
  final result = <LudoPiece, Offset>{};
  final yardOrigins = {
    LudoActor.user: Offset(size.width * .25, size.height * .75),
    LudoActor.agent: Offset(size.width * .75, size.height * .25),
  };
  final center = Offset(size.width / 2, size.height / 2);
  for (final piece in pieces) {
    if (piece.inYard) {
      final origin = yardOrigins[piece.actor]!;
      final dx = piece.index.isEven ? -1 : 1;
      final dy = piece.index < 2 ? -1 : 1;
      result[piece] =
          origin + Offset(dx * size.width * .055, dy * size.width * .055);
    } else if (piece.finished) {
      final angle = (piece.actor.index * 4 + piece.index) * math.pi / 4;
      result[piece] =
          center + Offset(math.cos(angle), math.sin(angle)) * size.width * .055;
    } else if (piece.progress >= 52) {
      final distance = (piece.progress - 51) / 6;
      final start = piece.actor == LudoActor.user
          ? Offset(size.width * .5, size.height * .88)
          : Offset(size.width * .5, size.height * .12);
      result[piece] = Offset.lerp(start, center, distance)!;
    } else {
      result[piece] = track[LudoEngine.globalCell(piece.actor, piece.progress)];
    }
  }
  return result;
}

List<Offset> _ludoTrack(Size size) {
  final inset = size.width * .1;
  final side = size.width - inset * 2;
  final result = <Offset>[];
  for (var i = 0; i < 13; i++) {
    result.add(Offset(inset + side * i / 13, size.height - inset));
  }
  for (var i = 0; i < 13; i++) {
    result.add(Offset(size.width - inset, size.height - inset - side * i / 13));
  }
  for (var i = 0; i < 13; i++) {
    result.add(Offset(size.width - inset - side * i / 13, inset));
  }
  for (var i = 0; i < 13; i++) {
    result.add(Offset(inset, inset + side * i / 13));
  }
  return result;
}

class _Match3MissionBar extends StatelessWidget {
  const _Match3MissionBar({
    required this.score,
    required this.target,
    required this.movesRemaining,
  });

  final int score;
  final int target;
  final int movesRemaining;

  @override
  Widget build(BuildContext context) {
    final progress = (score / target).clamp(0.0, 1.0);
    return Column(
      children: [
        Row(
          children: [
            Text(
              '共同能量',
              style: TextStyle(
                color: AppColors.text.withValues(alpha: .62),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              '$score / $target',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        LayoutBuilder(
          builder: (context, constraints) => Container(
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFF12263E).withValues(alpha: .12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.text.withValues(alpha: .06)),
            ),
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeOutCubic,
              width: constraints.maxWidth * progress,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF28C987),
                    Color(0xFF53B9FF),
                    Color(0xFFA16EFF),
                  ],
                ),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF53B9FF).withValues(alpha: .28),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.arrow_2_squarepath,
              size: 12,
              color: AppColors.text.withValues(alpha: .42),
            ),
            const SizedBox(width: 5),
            Text(
              '还剩 $movesRemaining 次交换',
              style: TextStyle(
                color: AppColors.text.withValues(alpha: .48),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Match3Board extends StatefulWidget {
  const _Match3Board({
    required this.engine,
    required this.selected,
    required this.lastTurn,
    required this.thinking,
    required this.onTap,
  });

  final Match3Engine engine;
  final Match3Point? selected;
  final Match3Turn? lastTurn;
  final bool thinking;
  final ValueChanged<Match3Point> onTap;

  @override
  State<_Match3Board> createState() => _Match3BoardState();
}

class _Match3BoardState extends State<_Match3Board>
    with TickerProviderStateMixin {
  late final AnimationController _ambient;
  late final AnimationController _resolve;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
    _resolve = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant _Match3Board oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lastTurn?.number != widget.lastTurn?.number &&
        widget.lastTurn != null) {
      _resolve.duration = _match3TurnAnimationDuration(widget.lastTurn!);
      _resolve.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ambient.dispose();
    _resolve.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final legalTargets = <int>{};
    final selected = widget.selected;
    if (selected != null) {
      for (final swap in widget.engine.availableSwaps()) {
        if (swap.a == selected) legalTargets.add(swap.b.index);
        if (swap.b == selected) legalTargets.add(swap.a.index);
      }
    }
    return Semantics(
      label: '怪物消消乐棋盘，点击棋子后选择发光的相邻棋子进行交换',
      child: AnimatedBuilder(
        animation: Listenable.merge([_ambient, _resolve]),
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            final geometry = _Match3BoardGeometry(size);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final point = geometry.pointAt(details.localPosition);
                if (point != null) widget.onTap(point);
              },
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _Match3BoardPainter(
                    board: widget.engine.board,
                    stateHash: widget.engine.stateHash,
                    selected: selected,
                    legalTargets: legalTargets,
                    lastTurn: widget.lastTurn,
                    thinking: widget.thinking,
                    ambient: _ambient.value,
                    resolve: _resolve.value,
                    geometry: geometry,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Match3BoardGeometry {
  _Match3BoardGeometry(Size size)
    : boardRect = Offset.zero & size,
      gap = size.shortestSide * .008,
      padding = size.shortestSide * .025 {
    tileSize = math.min(
      (size.width - padding * 2 - gap * (Match3Engine.size - 1)) /
          Match3Engine.size,
      (size.height - padding * 2 - gap * (Match3Engine.size - 1)) /
          Match3Engine.size,
    );
    final gridSide =
        tileSize * Match3Engine.size + gap * (Match3Engine.size - 1);
    gridOrigin = Offset(
      (size.width - gridSide) / 2,
      (size.height - gridSide) / 2,
    );
  }

  final Rect boardRect;
  final double gap;
  final double padding;
  late final double tileSize;
  late final Offset gridOrigin;

  Rect rectFor(int index) {
    final row = index ~/ Match3Engine.size;
    final col = index % Match3Engine.size;
    return Rect.fromLTWH(
      gridOrigin.dx + col * (tileSize + gap),
      gridOrigin.dy + row * (tileSize + gap),
      tileSize,
      tileSize,
    );
  }

  Match3Point? pointAt(Offset position) {
    for (
      var index = 0;
      index < Match3Engine.size * Match3Engine.size;
      index++
    ) {
      if (rectFor(index).inflate(gap / 2).contains(position)) {
        return Match3Point(
          index ~/ Match3Engine.size,
          index % Match3Engine.size,
        );
      }
    }
    return null;
  }
}

class _Match3Presentation {
  const _Match3Presentation({
    required this.board,
    this.swap,
    this.swapProgress = 1,
    this.clearing = const {},
    this.clearProgress = 1,
    this.dropProgress = 1,
  });

  final List<Match3Tile> board;
  final Match3Swap? swap;
  final double swapProgress;
  final Set<int> clearing;
  final double clearProgress;
  final double dropProgress;
}

Duration _match3TurnAnimationDuration(Match3Turn turn) =>
    Duration(milliseconds: 300 + turn.cascades.length * 620);

_Match3Presentation _match3Presentation(
  List<Match3Tile> finalBoard,
  Match3Turn? turn,
  double progress,
) {
  if (turn == null || progress >= 1 || turn.cascades.isEmpty) {
    return _Match3Presentation(board: finalBoard);
  }
  const swapUnits = .34;
  final totalUnits = swapUnits + turn.cascades.length;
  final position = progress * totalUnits;
  if (position < swapUnits) {
    return _Match3Presentation(
      board: turn.boardBefore,
      swap: turn.swap,
      swapProgress: Curves.easeInOutCubic.transform(position / swapUnits),
    );
  }
  final cascadePosition = position - swapUnits;
  final waveIndex = math.min(turn.cascades.length - 1, cascadePosition.floor());
  final local = cascadePosition - waveIndex;
  final wave = turn.cascades[waveIndex];
  if (local < .43) {
    return _Match3Presentation(
      board: wave.boardBefore,
      clearing: {for (final point in wave.cleared) point.index},
      clearProgress: Curves.easeInCubic.transform(local / .43),
      dropProgress: 0,
    );
  }
  return _Match3Presentation(
    board: wave.boardAfter,
    dropProgress: Curves.easeOutBack.transform((local - .43) / .57),
  );
}

class _Match3BoardPainter extends CustomPainter {
  const _Match3BoardPainter({
    required this.board,
    required this.stateHash,
    required this.selected,
    required this.legalTargets,
    required this.lastTurn,
    required this.thinking,
    required this.ambient,
    required this.resolve,
    required this.geometry,
  });

  final List<Match3Tile> board;
  final int stateHash;
  final Match3Point? selected;
  final Set<int> legalTargets;
  final Match3Turn? lastTurn;
  final bool thinking;
  final double ambient;
  final double resolve;
  final _Match3BoardGeometry geometry;

  static const _colors = [
    Color(0xFFFF5F72),
    Color(0xFFFFB43C),
    Color(0xFF39D58B),
    Color(0xFF3CAAF5),
    Color(0xFF9968FF),
    Color(0xFFFF72C6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = geometry.boardRect;
    final boardShape = RRect.fromRectAndRadius(
      bounds,
      Radius.circular(size.shortestSide * .055),
    );
    canvas.save();
    canvas.clipRRect(boardShape);
    canvas.drawRRect(
      boardShape,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF172F4B), Color(0xFF0A182A), Color(0xFF14243A)],
          stops: [0, .58, 1],
        ).createShader(bounds),
    );
    _paintBoardAtmosphere(canvas, bounds);
    final presentation = _match3Presentation(board, lastTurn, resolve);

    for (var index = 0; index < presentation.board.length; index++) {
      final rect = geometry.rectFor(index);
      final radius = Radius.circular(geometry.tileSize * .25);
      final cavity = RRect.fromRectAndRadius(rect, radius);
      canvas.drawRRect(
        cavity,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.black.withValues(alpha: .34),
              const Color(0xFF2A4561).withValues(alpha: .2),
            ],
          ).createShader(rect),
      );
      canvas.drawRRect(
        cavity,
        Paint()
          ..color = Colors.white.withValues(alpha: .055)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(.65, geometry.tileSize * .018),
      );

      final phase = ambient * math.pi * 2 + index * .79;
      final bob = math.sin(phase) * geometry.tileSize * .018;
      final active = selected?.index == index;
      final target = legalTargets.contains(index);
      var tileRect = rect;
      final swap = presentation.swap;
      if (swap != null) {
        if (index == swap.a.index) {
          final targetCenter = geometry.rectFor(swap.b.index).center;
          tileRect = rect.shift(
            (targetCenter - rect.center) * presentation.swapProgress,
          );
        } else if (index == swap.b.index) {
          final targetCenter = geometry.rectFor(swap.a.index).center;
          tileRect = rect.shift(
            (targetCenter - rect.center) * presentation.swapProgress,
          );
        }
      }
      if (presentation.dropProgress < 1) {
        final row = index ~/ Match3Engine.size;
        tileRect = tileRect.shift(
          Offset(
            0,
            -geometry.tileSize *
                (1.15 + row * .13) *
                (1 - presentation.dropProgress),
          ),
        );
      }
      final clearing = presentation.clearing.contains(index);
      final disappearScale = clearing
          ? math.max(0.0, 1 - presentation.clearProgress)
          : 1.0;
      final scale = (active ? .89 : 1.0) * disappearScale;
      canvas.save();
      canvas.translate(tileRect.center.dx, tileRect.center.dy + bob);
      canvas.scale(scale, scale);
      canvas.translate(-tileRect.center.dx, -tileRect.center.dy);
      if (target) _paintTargetGlow(canvas, tileRect, phase);
      final tile = presentation.board[index];
      if (tile.color >= 0 && disappearScale > .03) {
        _paintMonster(canvas, tileRect.deflate(geometry.tileSize * .055), tile);
      }
      if (active) _paintSelectedRing(canvas, tileRect, phase);
      canvas.restore();
      if (clearing && presentation.clearProgress > .18) {
        _paintClearSparkles(
          canvas,
          rect.center,
          index,
          presentation.clearProgress,
        );
      }
    }

    if (lastTurn != null && resolve < 1) {
      _paintResolveFeedback(canvas, lastTurn!, resolve);
    }
    if (thinking) _paintThinkingSweep(canvas, bounds, ambient);

    canvas.drawRRect(
      boardShape.deflate(1),
      Paint()
        ..color = Colors.white.withValues(alpha: .14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.restore();
  }

  void _paintBoardAtmosphere(Canvas canvas, Rect bounds) {
    final glow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF4AAEFF).withValues(alpha: .16),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(bounds.width * .72, bounds.height * .12),
              radius: bounds.width * .56,
            ),
          );
    canvas.drawRect(bounds, glow);
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: .08);
    for (var i = 0; i < 18; i++) {
      final x = (i * 73 % 101) / 101 * bounds.width;
      final y = (i * 47 % 97) / 97 * bounds.height;
      final pulse = .65 + .35 * math.sin(ambient * math.pi * 2 + i);
      canvas.drawCircle(Offset(x, y), 1.1 * pulse, dotPaint);
    }
  }

  void _paintMonster(Canvas canvas, Rect rect, Match3Tile tile) {
    final base = _colors[tile.color];
    final center = rect.center;
    final bodyRect = Rect.fromCenter(
      center: center + Offset(0, rect.height * .035),
      width: rect.width * .82,
      height: rect.height * .76,
    );
    final bodyPath = _monsterBodyPath(bodyRect, tile.color);

    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(0, rect.height * .4),
        width: rect.width * .7,
        height: rect.height * .18,
      ),
      Paint()..color = Colors.black.withValues(alpha: .3),
    );
    _paintMonsterEars(canvas, bodyRect, tile.color, base);
    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.38, -.52),
          radius: 1.1,
          colors: [
            Color.lerp(base, Colors.white, .48)!,
            base,
            Color.lerp(base, const Color(0xFF101B32), .28)!,
          ],
          stops: const [0, .48, 1],
        ).createShader(bodyRect),
    );
    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = Color.lerp(base, Colors.white, .65)!.withValues(alpha: .46)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(.7, rect.width * .025),
    );
    canvas.drawOval(
      Rect.fromLTWH(
        bodyRect.left + bodyRect.width * .16,
        bodyRect.top + bodyRect.height * .1,
        bodyRect.width * .27,
        bodyRect.height * .12,
      ),
      Paint()..color = Colors.white.withValues(alpha: .28),
    );
    _paintMonsterFace(canvas, bodyRect, tile.color);
    if (tile.special != Match3Special.none) {
      _paintSpecialBadge(canvas, bodyRect, tile.special);
    }
  }

  Path _monsterBodyPath(Rect rect, int color) {
    if (color == 1) {
      return Path()..addOval(rect);
    }
    if (color == 2) {
      final path = Path()
        ..moveTo(rect.left + rect.width * .12, rect.bottom)
        ..quadraticBezierTo(
          rect.left + rect.width * .18,
          rect.bottom - rect.height * .12,
          rect.left + rect.width * .15,
          rect.top + rect.height * .42,
        )
        ..quadraticBezierTo(
          rect.left + rect.width * .2,
          rect.top,
          rect.center.dx,
          rect.top,
        )
        ..quadraticBezierTo(
          rect.right - rect.width * .2,
          rect.top,
          rect.right - rect.width * .15,
          rect.top + rect.height * .42,
        )
        ..quadraticBezierTo(
          rect.right - rect.width * .18,
          rect.bottom - rect.height * .12,
          rect.right - rect.width * .12,
          rect.bottom,
        )
        ..quadraticBezierTo(
          rect.right - rect.width * .28,
          rect.bottom - rect.height * .1,
          rect.center.dx,
          rect.bottom,
        )
        ..quadraticBezierTo(
          rect.left + rect.width * .28,
          rect.bottom - rect.height * .1,
          rect.left + rect.width * .12,
          rect.bottom,
        )
        ..close();
      return path;
    }
    return Path()..addRRect(
      RRect.fromRectAndRadius(
        rect,
        Radius.circular(rect.width * (color == 5 ? .42 : .3)),
      ),
    );
  }

  void _paintMonsterEars(Canvas canvas, Rect rect, int color, Color base) {
    if (color == 0 || color == 4) {
      final hornPaint = Paint()..color = Color.lerp(base, Colors.white, .12)!;
      final left = Path()
        ..moveTo(rect.left + rect.width * .1, rect.top + rect.height * .24)
        ..lineTo(rect.left + rect.width * .17, rect.top - rect.height * .22)
        ..lineTo(rect.left + rect.width * .38, rect.top + rect.height * .09)
        ..close();
      final right = Path()
        ..moveTo(rect.right - rect.width * .1, rect.top + rect.height * .24)
        ..lineTo(rect.right - rect.width * .17, rect.top - rect.height * .22)
        ..lineTo(rect.right - rect.width * .38, rect.top + rect.height * .09)
        ..close();
      canvas.drawPath(left, hornPaint);
      canvas.drawPath(right, hornPaint);
    } else if (color == 3) {
      final earPaint = Paint()..color = Color.lerp(base, Colors.white, .18)!;
      canvas.drawCircle(
        Offset(rect.left + rect.width * .1, rect.top + rect.height * .18),
        rect.width * .17,
        earPaint,
      );
      canvas.drawCircle(
        Offset(rect.right - rect.width * .1, rect.top + rect.height * .18),
        rect.width * .17,
        earPaint,
      );
    }
  }

  void _paintMonsterFace(Canvas canvas, Rect rect, int color) {
    final eyeY = rect.top + rect.height * .43;
    if (color == 1) {
      _paintEye(canvas, Offset(rect.center.dx, eyeY), rect.width * .18);
    } else {
      final spacing = rect.width * (color == 5 ? .16 : .18);
      _paintEye(
        canvas,
        Offset(rect.center.dx - spacing, eyeY),
        rect.width * .105,
        sleepy: color == 5,
      );
      _paintEye(
        canvas,
        Offset(rect.center.dx + spacing, eyeY),
        rect.width * .105,
        sleepy: color == 5,
      );
      if (color == 0 || color == 4) {
        final browPaint = Paint()
          ..color = const Color(0xFF273143).withValues(alpha: .8)
          ..strokeWidth = rect.width * .055
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(rect.center.dx - spacing * 1.45, eyeY - rect.height * .18),
          Offset(rect.center.dx - spacing * .45, eyeY - rect.height * .11),
          browPaint,
        );
        canvas.drawLine(
          Offset(rect.center.dx + spacing * 1.45, eyeY - rect.height * .18),
          Offset(rect.center.dx + spacing * .45, eyeY - rect.height * .11),
          browPaint,
        );
      }
    }

    final mouthY = rect.top + rect.height * .7;
    final mouth = Path()
      ..moveTo(rect.center.dx - rect.width * .16, mouthY)
      ..quadraticBezierTo(
        rect.center.dx,
        mouthY + rect.height * (color == 4 ? -.02 : .13),
        rect.center.dx + rect.width * .16,
        mouthY,
      );
    canvas.drawPath(
      mouth,
      Paint()
        ..color = const Color(0xFF273143).withValues(alpha: .82)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, rect.width * .052)
        ..strokeCap = StrokeCap.round,
    );
    if (color == 3 || color == 4) {
      final fang = Path()
        ..moveTo(rect.center.dx + rect.width * .04, mouthY + rect.height * .025)
        ..lineTo(rect.center.dx + rect.width * .12, mouthY + rect.height * .16)
        ..lineTo(rect.center.dx + rect.width * .17, mouthY)
        ..close();
      canvas.drawPath(
        fang,
        Paint()..color = Colors.white.withValues(alpha: .9),
      );
    }
  }

  void _paintEye(
    Canvas canvas,
    Offset center,
    double radius, {
    bool sleepy = false,
  }) {
    if (sleepy) {
      final path = Path()
        ..moveTo(center.dx - radius, center.dy)
        ..quadraticBezierTo(
          center.dx,
          center.dy + radius * .65,
          center.dx + radius,
          center.dy,
        );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF253046)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, radius * .45)
          ..strokeCap = StrokeCap.round,
      );
      return;
    }
    canvas.drawCircle(center, radius, Paint()..color = Colors.white);
    canvas.drawCircle(
      center + Offset(radius * .12, radius * .16),
      radius * .52,
      Paint()..color = const Color(0xFF253046),
    );
    canvas.drawCircle(
      center - Offset(radius * .13, radius * .14),
      radius * .19,
      Paint()..color = Colors.white,
    );
  }

  void _paintSpecialBadge(Canvas canvas, Rect rect, Match3Special special) {
    final radius = rect.width * .17;
    final center = Offset(
      rect.right - radius * .55,
      rect.bottom - radius * .55,
    );
    canvas.drawCircle(
      center + Offset(0, radius * .12),
      radius * 1.08,
      Paint()..color = Colors.black.withValues(alpha: .28),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7FCFF), Color(0xFFBFDDF4)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    final paint = Paint()
      ..color = const Color(0xFF23456A)
      ..strokeWidth = math.max(1.1, radius * .22)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    switch (special) {
      case Match3Special.row:
        canvas.drawLine(
          center - Offset(radius * .55, 0),
          center + Offset(radius * .55, 0),
          paint,
        );
        break;
      case Match3Special.column:
        canvas.drawLine(
          center - Offset(0, radius * .55),
          center + Offset(0, radius * .55),
          paint,
        );
        break;
      case Match3Special.bomb:
        canvas.drawCircle(
          center,
          radius * .4,
          paint..style = PaintingStyle.fill,
        );
        canvas.drawLine(
          center - Offset(0, radius * .38),
          center + Offset(radius * .35, radius * .72),
          paint..style = PaintingStyle.stroke,
        );
        break;
      case Match3Special.color:
        for (var i = 0; i < 6; i++) {
          final angle = i * math.pi / 3;
          canvas.drawCircle(
            center + Offset(math.cos(angle), math.sin(angle)) * radius * .48,
            radius * .15,
            Paint()..color = _colors[i],
          );
        }
        break;
      case Match3Special.none:
        break;
    }
  }

  void _paintSelectedRing(Canvas canvas, Rect rect, double phase) {
    final pulse = .5 + .5 * math.sin(phase);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.inflate(geometry.tileSize * (.035 + pulse * .018)),
        Radius.circular(geometry.tileSize * .29),
      ),
      Paint()
        ..color = const Color(0xFFFFE58A).withValues(alpha: .84)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, geometry.tileSize * .055),
    );
  }

  void _paintTargetGlow(Canvas canvas, Rect rect, double phase) {
    final pulse = .5 + .5 * math.sin(phase + 1.2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.inflate(geometry.tileSize * .035),
        Radius.circular(geometry.tileSize * .29),
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: .36 + pulse * .3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, geometry.tileSize * .035),
    );
  }

  void _paintClearSparkles(
    Canvas canvas,
    Offset center,
    int index,
    double progress,
  ) {
    final travel = Curves.easeOutCubic.transform(progress);
    final fade = 1 - progress;
    for (var particle = 0; particle < 5; particle++) {
      final angle = index * .73 + particle * math.pi * 2 / 5;
      final radius = geometry.tileSize * (.12 + travel * .48);
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawCircle(
        point,
        geometry.tileSize * .055 * fade,
        Paint()
          ..color = _colors[(index + particle) % _colors.length].withValues(
            alpha: fade,
          ),
      );
    }
  }

  void _paintResolveFeedback(Canvas canvas, Match3Turn turn, double progress) {
    final curve = Curves.easeOutCubic.transform(progress);
    final center = geometry.rectFor(turn.swap.b.index).center;
    final radius = geometry.tileSize * (.45 + curve * 1.6);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: (1 - curve) * .7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, geometry.tileSize * .07 * (1 - curve)),
    );
    for (var i = 0; i < 7; i++) {
      final angle = i * math.pi * 2 / 7 + .35;
      final position =
          center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawCircle(
        position,
        geometry.tileSize * .055 * (1 - curve),
        Paint()..color = _colors[(i + turn.number) % _colors.length],
      );
    }
    final opacity = (1 - ((progress - .5).clamp(0.0, .5) * 2));
    final label = turn.cascades.length > 1
        ? '+${turn.score}  ${turn.cascades.length} 连消'
        : '+${turn.score}';
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: opacity),
          fontSize: geometry.tileSize * .3,
          fontWeight: FontWeight.w900,
          shadows: const [Shadow(color: Color(0xCC14233A), blurRadius: 8)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
      canvas,
      center - Offset(text.width / 2, geometry.tileSize * (.55 + curve * .65)),
    );
  }

  void _paintThinkingSweep(Canvas canvas, Rect bounds, double progress) {
    final y = bounds.top + bounds.height * progress;
    final sweep = Rect.fromLTWH(
      bounds.left,
      y - bounds.height * .08,
      bounds.width,
      bounds.height * .16,
    );
    canvas.drawRect(
      sweep,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF7DD8FF).withValues(alpha: .12),
            Colors.transparent,
          ],
        ).createShader(sweep),
    );
  }

  @override
  bool shouldRepaint(covariant _Match3BoardPainter oldDelegate) =>
      oldDelegate.stateHash != stateHash ||
      oldDelegate.selected != selected ||
      oldDelegate.legalTargets != legalTargets ||
      oldDelegate.lastTurn?.number != lastTurn?.number ||
      oldDelegate.thinking != thinking ||
      oldDelegate.ambient != ambient ||
      oldDelegate.resolve != resolve ||
      oldDelegate.geometry.boardRect != geometry.boardRect;
}
