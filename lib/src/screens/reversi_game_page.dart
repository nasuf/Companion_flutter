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
      _lastMove = null;
      _resolving = false;
      _timerPaused = false;
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
    if (session != null && mounted) {
      setState(() {
        _engine = ReversiEngine(
          aiConfig: ReversiAiConfig.fromJson(session.engineConfig),
        );
        _lastMove = null;
        _resolving = false;
        _timerPaused = false;
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
        await Future<void>.delayed(const Duration(milliseconds: 230));
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
    if (engine == null) {
      return _ReversiHome(
        rounds: _runtime.rounds,
        starting: _runtime.starting,
        error: _runtime.error,
        onStart: _start,
        onExit: () => Navigator.of(context).maybePop(),
      );
    }
    return PopScope(
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
      ),
    );
  }
}

const String _reversiAsset = 'assets/prototype/games/reversi/';

class _ReversiHome extends StatelessWidget {
  const _ReversiHome({
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
    final wins = summaries.where((round) => round.isWin).length;
    final rate = total == 0 ? 0 : (wins / total * 100).round();
    final seconds = summaries.fold<int>(
      0,
      (sum, round) => sum + (round.durationSeconds ?? 0),
    );
    final values = ['$total', '$wins', '$rate%', _formatDuration(seconds)];
    final labels = [
      '${_reversiAsset}stat_label_total.png',
      '${_reversiAsset}stat_label_wins.png',
      '${_reversiAsset}stat_label_rate.png',
      '${_reversiAsset}stat_label_time.png',
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF69B9EE),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          return Stack(
            children: [
              Positioned.fill(
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 10000),
                  scaleAmount: 0.004,
                  child: Image.asset(
                    '${_reversiAsset}home_bg.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                left: width * (46 / 393),
                top: height * (129 / 852),
                width: width * (300 / 393),
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 5000),
                  scaleAmount: 0.008,
                  translateY: 2,
                  phase: 0.3,
                  child: Image.asset(
                    '${_reversiAsset}home_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                left: width * (36 / 393),
                top: height * (313 / 852),
                width: width * (321 / 393),
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 6200),
                  scaleAmount: 0.005,
                  translateY: 1.5,
                  phase: 0.65,
                  child: Image.asset(
                    '${_reversiAsset}home_board.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              if (error != null)
                Positioned(
                  left: width * 0.08,
                  right: width * 0.08,
                  top: height * 0.60,
                  child: _GomokuNotice(text: error!, isError: true),
                ),
              Positioned(
                left: width * (30 / 393),
                top: height * (526 / 852),
                width: width * (150 / 393),
                child: _ReversiImageButton(
                  base: '${_reversiAsset}home_btn_exit.png',
                  textAsset: '${_reversiAsset}home_btn_exit_text.png',
                  aspectRatio: 450 / 186,
                  enabled: !starting,
                  onTap: onExit,
                ),
              ),
              Positioned(
                left: width * (203 / 393),
                top: height * (526 / 852),
                width: width * (150 / 393),
                child: _ReversiImageButton(
                  base: '${_reversiAsset}home_btn_start.png',
                  textAsset: '${_reversiAsset}home_btn_start_text.png',
                  aspectRatio: 450 / 186,
                  loading: starting,
                  enabled: !starting,
                  onTap: () => unawaited(onStart()),
                ),
              ),
              for (var index = 0; index < 4; index += 1)
                Positioned(
                  left: width * ((5 + index * 98) / 393),
                  top: height * (673 / 852),
                  width: width * (90 / 393),
                  child: _ReversiHomeStatCard(
                    labelAsset: labels[index],
                    value: values[index],
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
    return '${(seconds / 60).ceil()}m';
  }
}

class _ReversiHomeStatCard extends StatelessWidget {
  const _ReversiHomeStatCard({required this.labelAsset, required this.value});

  final String labelAsset;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 270 / 342,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  '${_reversiAsset}home_stat_card.png',
                  fit: BoxFit.fill,
                ),
              ),
              Positioned(
                left: width * 0.13,
                right: width * 0.13,
                top: height * (41 / 114),
                height: height * (19 / 114),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Image.asset(labelAsset),
                ),
              ),
              Positioned(
                left: width * 0.12,
                right: width * 0.12,
                top: height * (67 / 114),
                height: height * (26 / 114),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF502A2A),
                      fontSize: 20,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      decoration: TextDecoration.none,
                      shadows: [
                        Shadow(
                          color: Color(0x40000000),
                          offset: Offset(1, 1),
                          blurRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReversiImageButton extends StatefulWidget {
  const _ReversiImageButton({
    required this.base,
    required this.textAsset,
    required this.aspectRatio,
    required this.onTap,
    this.textWidthFactor = 0.74,
    this.textAlignment = Alignment.center,
    this.enabled = true,
    this.loading = false,
  });

  final String base;
  final String textAsset;
  final double aspectRatio;
  final VoidCallback onTap;
  final double textWidthFactor;
  final Alignment textAlignment;
  final bool enabled;
  final bool loading;

  @override
  State<_ReversiImageButton> createState() => _ReversiImageButtonState();
}

class _ReversiImageButtonState extends State<_ReversiImageButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !widget.loading;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 100),
        child: Opacity(
          opacity: enabled ? 1 : 0.72,
          child: AspectRatio(
            aspectRatio: widget.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Image.asset(widget.base, fit: BoxFit.fill),
                ),
                if (widget.loading)
                  const CupertinoActivityIndicator(color: Colors.white)
                else
                  Align(
                    alignment: widget.textAlignment,
                    child: FractionallySizedBox(
                      widthFactor: widget.textWidthFactor,
                      heightFactor: 0.62,
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

class _ReversiGameScreen extends StatelessWidget {
  const _ReversiGameScreen({
    required this.engine,
    required this.lastMove,
    required this.agentName,
    required this.userName,
    required this.agentAvatarUrl,
    required this.userAvatarUrl,
    required this.startedAt,
    required this.aiThinking,
    required this.resolving,
    required this.starting,
    required this.timerPaused,
    required this.enabled,
    required this.onTap,
    required this.onRestart,
    required this.onExit,
    required this.onTimerPauseChanged,
  });

  final ReversiEngine engine;
  final ReversiMove? lastMove;
  final String agentName;
  final String userName;
  final String? agentAvatarUrl;
  final String? userAvatarUrl;
  final DateTime? startedAt;
  final bool aiThinking;
  final bool resolving;
  final bool starting;
  final bool timerPaused;
  final bool enabled;
  final ValueChanged<int> onTap;
  final Future<void> Function() onRestart;
  final VoidCallback onExit;
  final ValueChanged<bool> onTimerPauseChanged;

  @override
  Widget build(BuildContext context) {
    final userTurn =
        !engine.isFinished &&
        engine.turn == ReversiActor.user &&
        !aiThinking &&
        !resolving;
    final agentTurn =
        !engine.isFinished && (engine.turn == ReversiActor.agent || aiThinking);
    return Scaffold(
      backgroundColor: const Color(0xFF85D3EB),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          return Stack(
            children: [
              Positioned.fill(
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 10000),
                  scaleAmount: 0.005,
                  phase: 0.4,
                  child: Image.asset(
                    '${_reversiAsset}game_bg.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                left: width * (50 / 393),
                top: height * (101 / 852),
                width: width * (88 / 393),
                child: _ReversiAvatar(
                  frameAsset: '${_reversiAsset}game_avatar_frame_user.png',
                  imageUrl: userAvatarUrl,
                  fallback: userName,
                  active: userTurn,
                  glowColor: const Color(0xFF49DFFF),
                ),
              ),
              Positioned(
                left: width * (283 / 393),
                top: height * (101 / 852),
                width: width * (88 / 393),
                child: _ReversiAvatar(
                  frameAsset: '${_reversiAsset}game_avatar_frame_agent.png',
                  imageUrl: agentAvatarUrl,
                  fallback: agentName,
                  active: agentTurn,
                  glowColor: const Color(0xFFFFC94D),
                ),
              ),
              Positioned(
                left: width * (44 / 393),
                top: height * (192 / 852),
                width: width * (100 / 393),
                child: _ReversiNamePlate(
                  asset: '${_reversiAsset}game_name_user.png',
                  name: userName,
                ),
              ),
              Positioned(
                left: width * (277 / 393),
                top: height * (192 / 852),
                width: width * (100 / 393),
                child: _ReversiNamePlate(
                  asset: '${_reversiAsset}game_name_agent.png',
                  name: agentName,
                ),
              ),
              Positioned(
                left: width * (177 / 393),
                top: height * (129 / 852),
                width: width * (74 / 393),
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 3600),
                  scaleAmount: 0.012,
                  translateY: 1.5,
                  phase: 0.25,
                  child: Image.asset(
                    '${_reversiAsset}game_hourglass.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                left: width * (176 / 393),
                top: height * (214 / 852),
                width: width * (70 / 393),
                child: _ReversiRoundTimer(
                  startedAt: startedAt,
                  paused: timerPaused || engine.isFinished,
                ),
              ),
              Positioned(
                left: width * (17 / 393),
                top: height * (274 / 852),
                width: width * (368 / 393),
                child: AspectRatio(
                  aspectRatio: 368 / 374,
                  child: _ReversiBoard(
                    engine: engine,
                    lastMove: lastMove,
                    thinking: aiThinking,
                    enabled: enabled,
                    onTap: onTap,
                  ),
                ),
              ),
              Positioned(
                left: width * (27 / 393),
                top: height * (666 / 852),
                width: width * (100 / 393),
                child: _ReversiImageButton(
                  base: '${_reversiAsset}game_btn_exit.png',
                  textAsset: '${_reversiAsset}game_btn_exit_text.png',
                  aspectRatio: 300 / 165,
                  textWidthFactor: 0.46,
                  textAlignment: const Alignment(0, 0.10),
                  onTap: () => unawaited(_confirmExit(context)),
                ),
              ),
              Positioned(
                left: width * (144 / 393),
                top: height * (666 / 852),
                width: width * (100 / 393),
                child: _ReversiImageButton(
                  base: '${_reversiAsset}game_btn_pause.png',
                  textAsset: '${_reversiAsset}game_btn_pause_text.png',
                  aspectRatio: 300 / 165,
                  textWidthFactor: 0.46,
                  textAlignment: const Alignment(0, 0.10),
                  onTap: () => unawaited(_showPause(context)),
                ),
              ),
              if (engine.isFinished)
                _ReversiFinishOverlay(
                  engine: engine,
                  agentName: agentName,
                  restarting: starting,
                  onRestart: onRestart,
                  onExit: onExit,
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    onTimerPauseChanged(true);
    await _showReversiModal(
      context,
      title: '退出对局',
      message: '当前棋局还没结束，退出后本局进度会清空。',
      actions: (dialogContext) => [
        Expanded(
          child: _ReversiModalButton(
            asset: '${_reversiAsset}game_btn_pause.png',
            label: '继续',
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ReversiModalButton(
            asset: '${_reversiAsset}game_btn_exit.png',
            label: '退出',
            onTap: () {
              Navigator.of(dialogContext).pop();
              onExit();
            },
          ),
        ),
      ],
    );
    onTimerPauseChanged(false);
  }

  Future<void> _showPause(BuildContext context) async {
    onTimerPauseChanged(true);
    await _showReversiModal(
      context,
      title: '游戏暂停',
      message: '要继续当前棋局，还是重新开一盘？',
      actions: (dialogContext) => [
        Expanded(
          child: _ReversiModalButton(
            asset: '${_reversiAsset}game_btn_pause.png',
            label: '继续',
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ReversiModalButton(
            asset: '${_reversiAsset}game_btn_exit.png',
            label: '重新开局',
            onTap: () {
              Navigator.of(dialogContext).pop();
              unawaited(onRestart());
            },
          ),
        ),
      ],
    );
    onTimerPauseChanged(false);
  }
}

class _ReversiAvatar extends StatelessWidget {
  const _ReversiAvatar({
    required this.frameAsset,
    required this.imageUrl,
    required this.fallback,
    required this.active,
    required this.glowColor,
  });

  final String frameAsset;
  final String? imageUrl;
  final String fallback;
  final bool active;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 88 / 90,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final inner = width * (80 / 88);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: width * (4 / 88),
                top: height * (8 / 90),
                width: inner,
                height: inner,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: glowColor.withValues(alpha: 0.75),
                              blurRadius: 16,
                              spreadRadius: 3,
                            ),
                          ]
                        : const [],
                  ),
                  child: ClipOval(
                    child: _Avatar(
                      size: inner,
                      label: fallback.trim().isEmpty
                          ? '伴'
                          : fallback.trim().characters.first,
                      imageUrl: imageUrl,
                      gradient: const [Color(0xFFE8F3FF), Color(0xFFD7E9FF)],
                    ),
                  ),
                ),
              ),
              Positioned.fill(child: Image.asset(frameAsset, fit: BoxFit.fill)),
            ],
          );
        },
      ),
    );
  }
}

class _ReversiNamePlate extends StatelessWidget {
  const _ReversiNamePlate({required this.asset, required this.name});

  final String asset;
  final String name;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 300 / 120,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: Image.asset(asset, fit: BoxFit.fill)),
              Positioned(
                left: -width * 0.15,
                top: height * 0.20,
                width: width * 1.30,
                height: height * 0.72,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _ReversiOutlinedText(text: name, fontSize: 15),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReversiRoundTimer extends StatefulWidget {
  const _ReversiRoundTimer({required this.startedAt, required this.paused});

  final DateTime? startedAt;
  final bool paused;

  @override
  State<_ReversiRoundTimer> createState() => _ReversiRoundTimerState();
}

class _ReversiRoundTimerState extends State<_ReversiRoundTimer> {
  Timer? _timer;
  late DateTime _fallbackStart;
  DateTime? _pausedAt;
  Duration _pausedDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _fallbackStart = DateTime.now();
    if (widget.paused) _pausedAt = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !widget.paused) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _ReversiRoundTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startedAt != widget.startedAt) {
      _fallbackStart = DateTime.now();
      _pausedDuration = Duration.zero;
      _pausedAt = widget.paused ? DateTime.now() : null;
      return;
    }
    if (!oldWidget.paused && widget.paused) {
      _pausedAt = DateTime.now();
    } else if (oldWidget.paused && !widget.paused && _pausedAt != null) {
      _pausedDuration += DateTime.now().difference(_pausedAt!);
      _pausedAt = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.startedAt ?? _fallbackStart;
    final now = _pausedAt ?? DateTime.now();
    final elapsed = (now.difference(start) - _pausedDuration).inSeconds.clamp(
      0,
      5999,
    );
    final minutes = elapsed ~/ 60;
    final seconds = elapsed % 60;
    return AspectRatio(
      aspectRatio: 210 / 75,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Image.asset(
              '${_reversiAsset}game_timer_plate.png',
              fit: BoxFit.fill,
            ),
          ),
          _ReversiOutlinedText(
            text: '$minutes:${seconds.toString().padLeft(2, '0')}',
            fontSize: 15,
          ),
        ],
      ),
    );
  }
}

class _ReversiOutlinedText extends StatelessWidget {
  const _ReversiOutlinedText({required this.text, required this.fontSize});

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
            decoration: TextDecoration.none,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.2
              ..strokeJoin = StrokeJoin.round
              ..color = Colors.black,
          ),
        ),
        Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            height: 1,
            fontWeight: FontWeight.w900,
            decoration: TextDecoration.none,
            shadows: const [
              Shadow(
                color: Color(0x55000000),
                offset: Offset(1, 1),
                blurRadius: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReversiModalButton extends StatelessWidget {
  const _ReversiModalButton({
    required this.asset,
    required this.label,
    required this.onTap,
  });

  final String asset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 300 / 165,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(child: Image.asset(asset, fit: BoxFit.fill)),
            _ReversiOutlinedText(text: label, fontSize: 17),
          ],
        ),
      ),
    );
  }
}

Future<void> _showReversiModal(
  BuildContext context, {
  required String title,
  required String message,
  required List<Widget> Function(BuildContext dialogContext) actions,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, _, __) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 46),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF5D8), Color(0xFFE9C695)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF8A4B27), width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF502A2A),
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF75513B),
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 18),
                Row(children: actions(dialogContext)),
              ],
            ),
          ),
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
          scale: Tween<double>(begin: 0.88, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _ReversiFinishOverlay extends StatelessWidget {
  const _ReversiFinishOverlay({
    required this.engine,
    required this.agentName,
    required this.restarting,
    required this.onRestart,
    required this.onExit,
  });

  final ReversiEngine engine;
  final String agentName;
  final bool restarting;
  final Future<void> Function() onRestart;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 46),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF5D8), Color(0xFFE9C695)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFF8A4B27), width: 3),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _reversiResultText(engine, agentName),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF502A2A),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _ReversiModalButton(
                          asset: '${_reversiAsset}game_btn_exit.png',
                          label: '退出',
                          onTap: onExit,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ReversiModalButton(
                          asset: '${_reversiAsset}game_btn_pause.png',
                          label: restarting ? '...' : '再来一盘',
                          onTap: () => unawaited(onRestart()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _reversiResultText(ReversiEngine engine, String agentName) =>
    switch (engine.status) {
      ReversiStatus.userWon =>
        '你以 ${engine.userCount}:${engine.agentCount} 拿下这一盘',
      ReversiStatus.agentWon =>
        '$agentName 以 ${engine.agentCount}:${engine.userCount} 赢了这一盘',
      ReversiStatus.draw => '这一盘 ${engine.userCount}:${engine.agentCount} 平分秋色',
      ReversiStatus.playing => '棋局进行中',
    };

class _ReversiBoard extends StatefulWidget {
  const _ReversiBoard({
    required this.engine,
    required this.lastMove,
    required this.thinking,
    required this.enabled,
    required this.onTap,
  });

  final ReversiEngine engine;
  final ReversiMove? lastMove;
  final bool thinking;
  final bool enabled;
  final ValueChanged<int> onTap;

  @override
  State<_ReversiBoard> createState() => _ReversiBoardState();
}

class _ReversiBoardState extends State<_ReversiBoard>
    with TickerProviderStateMixin {
  late final AnimationController _moveController;
  late final AnimationController _ambientController;

  @override
  void initState() {
    super.initState();
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
      value: 1,
    );
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _ReversiBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lastMove?.number != widget.lastMove?.number &&
        widget.lastMove != null) {
      _moveController.duration = Duration(
        milliseconds: widget.lastMove!.flipped.length >= 8 ? 960 : 820,
      );
      _moveController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _moveController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final legal = widget.enabled
        ? widget.engine.legalMoves
        : const <int, List<int>>{};
    return Semantics(
      label: '黑白棋棋盘，轻点发光位置落下黑棋',
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            final geometry = _ReversiBoardGeometry(size);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: widget.enabled
                  ? (details) {
                      final index = geometry.indexAt(details.localPosition);
                      if (index != null && legal.containsKey(index)) {
                        widget.onTap(index);
                      }
                    }
                  : null,
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _moveController,
                  _ambientController,
                ]),
                builder: (context, _) {
                  final moveProgress = Curves.easeInOutCubic.transform(
                    _moveController.value,
                  );
                  final pulse = 0.55 + _ambientController.value * 0.45;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          '${_reversiAsset}game_board.png',
                          fit: BoxFit.fill,
                        ),
                      ),
                      for (final index in legal.keys)
                        _ReversiLegalHint(
                          rect: geometry.cellRect(index),
                          pulse: pulse,
                        ),
                      for (
                        var index = 0;
                        index < widget.engine.board.length;
                        index += 1
                      )
                        if (widget.engine.board[index] != 0)
                          _buildDisc(index, geometry, moveProgress),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDisc(
    int index,
    _ReversiBoardGeometry geometry,
    double moveProgress,
  ) {
    var value = widget.engine.board[index];
    var scaleX = 1.0;
    var scaleY = 1.0;
    var lift = 0.0;
    final move = widget.lastMove;
    if (move?.point.index == index && moveProgress < 1) {
      final progress = Curves.elasticOut.transform(
        (moveProgress / 0.56).clamp(0.0, 1.0),
      );
      scaleX = progress;
      scaleY = progress;
    } else if (move != null &&
        move.flipped.any((point) => point.index == index) &&
        moveProgress < 0.88) {
      final local = ((moveProgress - 0.12) / 0.68).clamp(0.0, 1.0);
      value = local < 0.5 ? move.boardBefore[index] : move.boardAfter[index];
      scaleX = math.cos(local * math.pi).abs().clamp(0.045, 1.0);
      scaleY = 1 + math.sin(local * math.pi) * 0.08;
      lift = math.sin(local * math.pi) * geometry.discSize * 0.12;
    }
    final center = geometry.cellRect(index).center;
    final size = geometry.discSize;
    final asset = value == 1
        ? '${_reversiAsset}game_disc_black.png'
        : '${_reversiAsset}game_disc_white.png';
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2 - lift,
      width: size,
      height: size,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(scaleX, scaleY, 1),
        child: Image.asset(asset, fit: BoxFit.contain),
      ),
    );
  }
}

class _ReversiBoardGeometry {
  const _ReversiBoardGeometry(this.size);

  final Size size;

  static const List<double> _sourceX = [
    87,
    204,
    321,
    435,
    553,
    667,
    784,
    898,
    1017,
  ];
  static const List<double> _sourceY = [
    84,
    196,
    315,
    431,
    551,
    667,
    788,
    903,
    1022,
  ];

  double _x(int index) => size.width * (_sourceX[index] / 1104);
  double _y(int index) => size.height * (_sourceY[index] / 1122);
  double get discSize => size.width * (33 / 368);

  Rect cellRect(int index) {
    final row = index ~/ ReversiEngine.size;
    final col = index % ReversiEngine.size;
    return Rect.fromLTRB(_x(col), _y(row), _x(col + 1), _y(row + 1));
  }

  int? indexAt(Offset position) {
    for (var row = 0; row < ReversiEngine.size; row += 1) {
      for (var col = 0; col < ReversiEngine.size; col += 1) {
        final index = row * ReversiEngine.size + col;
        if (cellRect(index).contains(position)) return index;
      }
    }
    return null;
  }
}

class _ReversiLegalHint extends StatelessWidget {
  const _ReversiLegalHint({required this.rect, required this.pulse});

  final Rect rect;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final size = math.min(rect.width, rect.height) * (0.26 + pulse * 0.025);
    return Positioned(
      left: rect.center.dx - size / 2,
      top: rect.center.dy - size / 2,
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.18 + pulse * 0.08),
          border: Border.all(
            color: const Color(0xFFFFD980).withValues(alpha: 0.82),
            width: 1.3,
          ),
        ),
      ),
    );
  }
}
