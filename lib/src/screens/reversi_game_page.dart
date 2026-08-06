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
        rounds: _runtime.rounds,
        starting: _runtime.starting,
        error: _runtime.error,
        onStart: _start,
        onExit: () => Navigator.of(context).maybePop(),
      );
    } else if (_result != null) {
      child = _ReversiResultScreen(
        key: const ValueKey('reversi-result'),
        kind: _result!,
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
          // Quitting or restarting mid-game counts as a loss (design note).
          onShowLose: () {
            if (mounted && _result == null) {
              setState(() => _result = _ReversiResultKind.lose);
            }
          },
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

class _ReversiHome extends StatelessWidget {
  const _ReversiHome({
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

class _ReversiGameScreen extends StatefulWidget {
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
    required this.onShowLose,
    required this.bannerInMs,
    required this.bannerHoldMs,
    required this.bannerOutMs,
    required this.gamePoints,
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
  // Quit / restart mid-game → show the loss result instead of exiting directly.
  final VoidCallback onShowLose;
  // "你的回合" banner timing (ms), from the per-game admin config.
  final int bannerInMs;
  final int bannerHoldMs;
  final int bannerOutMs;
  // Current game points, shown in the top-right coin badge.
  final int? gamePoints;

  @override
  State<_ReversiGameScreen> createState() => _ReversiGameScreenState();
}

class _ReversiGameScreenState extends State<_ReversiGameScreen> {
  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    final lastMove = widget.lastMove;
    final agentName = widget.agentName;
    final userName = widget.userName;
    final agentAvatarUrl = widget.agentAvatarUrl;
    final userAvatarUrl = widget.userAvatarUrl;
    final aiThinking = widget.aiThinking;
    final resolving = widget.resolving;
    final enabled = widget.enabled;
    final onTap = widget.onTap;
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
              // Avatars sit on the outer edges with their name plates tucked
              // inside, all in one row (design 37:200). Positions are measured
              // from the design proportions — nudge if slightly off.
              Positioned(
                left: width * (31 / 393),
                top: height * (146 / 852),
                width: width * (50 / 393),
                child: _ReversiAvatar(
                  frameAsset: '${_reversiAsset}game_avatar_frame_user.png',
                  imageUrl: userAvatarUrl,
                  fallback: userName,
                  active: userTurn,
                  glowColor: const Color(0xFF49DFFF),
                  paused: widget.timerPaused,
                  onTimeout: _handleUserIdleTimeout,
                ),
              ),
              Positioned(
                left: width * (312 / 393),
                top: height * (146 / 852),
                width: width * (50 / 393),
                child: _ReversiAvatar(
                  frameAsset: '${_reversiAsset}game_avatar_frame_agent.png',
                  imageUrl: agentAvatarUrl,
                  fallback: agentName,
                  active: agentTurn,
                  glowColor: const Color(0xFFFFC94D),
                  paused: widget.timerPaused,
                ),
              ),
              // Name plates sit right beside the avatars with a small gap
              // (design 37:200, measured).
              Positioned(
                left: width * (93 / 393),
                top: height * (152 / 852),
                width: width * (97 / 393),
                child: _ReversiNamePlate(
                  asset: '${_reversiAsset}game_name_user.png',
                  name: userName,
                  active: userTurn,
                ),
              ),
              Positioned(
                left: width * (203 / 393),
                top: height * (152 / 852),
                width: width * (97 / 393),
                child: _ReversiNamePlate(
                  asset: '${_reversiAsset}game_name_agent.png',
                  name: agentName,
                  active: agentTurn,
                ),
              ),
              // Live disc score "user VS agent" — replaces the old standalone
              // countdown + hourglass.
              Positioned(
                left: width * (138 / 393),
                top: height * (214 / 852),
                width: width * (116 / 393),
                child: _ReversiScorePlate(
                  userCount: engine.userCount,
                  agentCount: engine.agentCount,
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
              // Gear (bottom-right) opens the reversi rules popup (design 198:1273).
              // 40x41 in Figma; vertical centre aligned with the exit/pause
              // buttons (their centre sits at 666 + 55/2 = 693.5).
              Positioned(
                left: width * (330 / 393),
                top: height * (673 / 852),
                width: width * (40 / 393),
                child: _ReversiGearButton(
                  onTap: () => unawaited(_showRules(context)),
                ),
              ),
              // "你的回合" ribbon flashes in at the board's lower-middle on the
              // user's turn (shared with gomoku).
              Positioned(
                left: 0,
                right: 0,
                top: height * 0.63 - (width * 0.13) / 2,
                height: width * 0.13,
                child: _TurnBanner(
                  userTurn: userTurn,
                  inMs: widget.bannerInMs,
                  holdMs: widget.bannerHoldMs,
                  outMs: widget.bannerOutMs,
                ),
              ),
              _NativeGamePointsBadge(points: widget.gamePoints),
            ],
          );
        },
      ),
    );
  }

  // The 30s turn countdown ran out while the user hadn't moved — auto-open the
  // pause menu (mirrors gomoku; replaces the old idle-timeout prompt).
  void _handleUserIdleTimeout() {
    if (!mounted || widget.timerPaused || widget.engine.isFinished) return;
    unawaited(_showPause(context));
  }

  Future<void> _confirmExit(BuildContext context) async {
    widget.onTimerPauseChanged(true);
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
              widget.onShowLose();
            },
          ),
        ),
      ],
    );
    widget.onTimerPauseChanged(false);
  }

  Future<void> _showPause(BuildContext context) async {
    widget.onTimerPauseChanged(true);
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
              widget.onShowLose();
            },
          ),
        ),
      ],
    );
    widget.onTimerPauseChanged(false);
  }

  // Rules popup — pauses the turn countdown while open (no pause dialog),
  // resumes on close.
  Future<void> _showRules(BuildContext context) async {
    widget.onTimerPauseChanged(true);
    await _showGameRulesDialog(
      context,
      gameName: '黑白棋',
      rules: const [
        '1、落子需夹住对方棋子，将其翻转为己方颜色',
        '2、棋盘无子可落则跳过回合',
        '3、对局结束棋子数量多者获胜',
      ],
    );
    widget.onTimerPauseChanged(false);
  }
}

class _ReversiAvatar extends StatefulWidget {
  const _ReversiAvatar({
    required this.frameAsset,
    required this.imageUrl,
    required this.fallback,
    required this.active,
    required this.glowColor,
    required this.paused,
    this.onTimeout,
  });

  final String frameAsset;
  final String? imageUrl;
  final String fallback;
  final bool active;
  final Color glowColor;
  final bool paused;
  // Fired when the 30s turn countdown runs out while still this player's turn.
  final VoidCallback? onTimeout;

  @override
  State<_ReversiAvatar> createState() => _ReversiAvatarState();
}

class _ReversiAvatarState extends State<_ReversiAvatar>
    with SingleTickerProviderStateMixin {
  static const int _turnSeconds = 30;
  late final AnimationController _countdown;

  @override
  void initState() {
    super.initState();
    _countdown = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _turnSeconds),
    )..addStatusListener(_onStatus);
    _sync();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        widget.active &&
        !widget.paused) {
      widget.onTimeout?.call();
    }
  }

  @override
  void didUpdateWidget(covariant _ReversiAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      _sync();
    } else if (widget.paused != oldWidget.paused && widget.active) {
      if (widget.paused) {
        _countdown.stop();
      } else if (_countdown.value >= 1.0) {
        _countdown.forward(from: 0);
      } else {
        _countdown.forward();
      }
    }
  }

  void _sync() {
    if (widget.active && !widget.paused) {
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
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: ClipOval(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _Avatar(
                          size: inner,
                          label: widget.fallback.trim().isEmpty
                              ? '伴'
                              : widget.fallback.trim().characters.first,
                          imageUrl: widget.imageUrl,
                          gradient: const [
                            Color(0xFFE8F3FF),
                            Color(0xFFD7E9FF),
                          ],
                        ),
                        if (widget.active)
                          AnimatedBuilder(
                            animation: _countdown,
                            builder: (context, _) {
                              final remaining = (1 - _countdown.value).clamp(
                                0.0,
                                1.0,
                              );
                              final secs = (remaining * _turnSeconds)
                                  .ceil()
                                  .clamp(0, _turnSeconds);
                              return Stack(
                                fit: StackFit.expand,
                                children: [
                                  CustomPaint(
                                    painter: _GomokuTurnTimerPainter(
                                      remainingFraction: remaining,
                                    ),
                                  ),
                                  Center(
                                    child: Text(
                                      '$secs',
                                      style: TextStyle(
                                        color: widget.glowColor,
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
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Image.asset(widget.frameAsset, fit: BoxFit.fill),
              ),
              // Glowing ring swapped in while it is this player's turn.
              if (widget.active)
                Positioned.fill(
                  child: Transform.scale(
                    scale: 1.12,
                    child: Image.asset(
                      '${_reversiAsset}game_avatar_frame_active.png',
                      fit: BoxFit.contain,
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

class _ReversiNamePlate extends StatelessWidget {
  const _ReversiNamePlate({
    required this.asset,
    required this.name,
    this.active = false,
  });

  final String asset;
  final String name;
  final bool active;

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
              // The plate swaps to the glowing active art while it is this
              // player's turn (design "头像/名字方框变色").
              Positioned.fill(
                child: Image.asset(
                  active ? '${_reversiAsset}game_name_active.png' : asset,
                  fit: BoxFit.fill,
                ),
              ),
              // Name centered in the plate.
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: width * 0.14,
                    vertical: height * 0.2,
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _ReversiOutlinedText(text: name, fontSize: 15),
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

/// Live disc score "user VS agent" on the wooden plate (design 37:200),
/// replacing the old elapsed-time timer + hourglass.
class _ReversiScorePlate extends StatelessWidget {
  const _ReversiScorePlate({
    required this.userCount,
    required this.agentCount,
  });

  final int userCount;
  final int agentCount;

  @override
  Widget build(BuildContext context) {
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _ReversiOutlinedText(
                text: '$userCount  VS  $agentCount',
                fontSize: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom-right gear that opens the rules popup (design 198:1273).
class _ReversiGearButton extends StatefulWidget {
  const _ReversiGearButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ReversiGearButton> createState() => _ReversiGearButtonState();
}

class _ReversiGearButtonState extends State<_ReversiGearButton> {
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
        child: Image.asset(
          '${_reversiAsset}game_gear.png',
          fit: BoxFit.contain,
        ),
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

enum _ReversiResultKind { win, lose }

/// Clips a child to the top [fraction] of its height. Used to show only the
/// rope coil from the rope+tablet art, so the hanging stone tablet never peeks
/// out below the coil (design note: 只显示吊绳).
class _TopFractionClipper extends CustomClipper<Rect> {
  const _TopFractionClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width, size.height * fraction);

  @override
  bool shouldReclip(covariant _TopFractionClipper oldClipper) =>
      oldClipper.fraction != fraction;
}

/// Result-screen button (再来一局 / 确认) with a subtle press-in scale so a tap
/// reads as physical instead of a flat hit target.
class _ReversiResultButton extends StatefulWidget {
  const _ReversiResultButton({
    required this.base,
    required this.text,
    required this.textWidthFactor,
    required this.onTap,
  });

  final String base;
  final String text;
  final double textWidthFactor;
  final Future<void> Function() onTap;

  @override
  State<_ReversiResultButton> createState() => _ReversiResultButtonState();
}

class _ReversiResultButtonState extends State<_ReversiResultButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        unawaited(widget.onTap());
      },
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Image.asset(
                '$_reversiAsset${widget.base}',
                fit: BoxFit.fill,
              ),
            ),
            FractionallySizedBox(
              widthFactor: widget.textWidthFactor,
              child: Image.asset(
                '$_reversiAsset${widget.text}',
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen win / lose result scene composed from individual art pieces so
/// each element flies in with its own stagger (bg → frame/emblem → title →
/// score → buttons) instead of one flat, lifeless image.
class _ReversiResultScreen extends StatefulWidget {
  const _ReversiResultScreen({
    super.key,
    required this.kind,
    required this.onAgain,
    required this.onConfirm,
  });

  final _ReversiResultKind kind;
  final Future<void> Function() onAgain;
  final Future<void> Function() onConfirm;

  @override
  State<_ReversiResultScreen> createState() => _ReversiResultScreenState();
}

class _ReversiResultScreenState extends State<_ReversiResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      // Lose runs longer so the "失败" pendant can drop, swing and settle
      // gradually; win keeps its original snappier staggered entrance.
      duration: Duration(
        milliseconds: widget.kind == _ReversiResultKind.lose ? 2000 : 1400,
      ),
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

  double _fade(double a, double b) =>
      ((_c.value - a) / (b - a)).clamp(0.0, 1.0);

  Widget _img(String name) =>
      Image.asset('$_reversiAsset$name', fit: BoxFit.fill);

  // Rope coil only (top slice of the rope+tablet art) so the stone tablet is
  // never revealed below the coil.
  Widget _ropeCoil({bool flip = false}) {
    Widget coil = ClipRect(
      clipper: const _TopFractionClipper(0.36),
      child: _img('result_lose_rope.png'),
    );
    if (flip) coil = Transform.flip(flipX: true, child: coil);
    return coil;
  }

  // Positions a piece centered at (cx,cy) fractions with width [wFrac]; height
  // follows the art's [aspect] (h/w). Drops in from above or pops (scale).
  Widget _piece({
    required double screenW,
    required double screenH,
    required double cx,
    required double cy,
    required double wFrac,
    required double aspect,
    required double begin,
    required double end,
    required bool drop,
    required Widget child,
  }) {
    final p = ((_c.value - begin) / (end - begin)).clamp(0.0, 1.0);
    final eased = Curves.easeOutBack.transform(p);
    final opacity = (p * 2.2).clamp(0.0, 1.0);
    final width = screenW * wFrac;
    final height = width * aspect;
    final dy = drop
        ? -screenH * 0.12 * (1 - Curves.easeOutCubic.transform(p))
        : 0.0;
    final scale = drop ? 1.0 : (0.72 + 0.28 * eased);
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

  Widget _button({
    required String base,
    required String text,
    required double textWidthFactor,
    required Future<void> Function() onTap,
  }) {
    return _ReversiResultButton(
      base: base,
      text: text,
      textWidthFactor: textWidthFactor,
      onTap: onTap,
    );
  }

  Widget _scoreContent(
    String labelAsset,
    String numAsset, {
    Alignment align = Alignment.center,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Align(
        alignment: align,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('$_reversiAsset$labelAsset', height: 30),
              const SizedBox(width: 8),
              Image.asset('$_reversiAsset$numAsset', height: 34),
            ],
          ),
        ),
      ),
    );
  }

  // ── "失败" hanging pendant (ropes + plate) — drop from above, get caught,
  // swing, then settle (design note). Shared timeline so the ropes and plate
  // move together as one pendant, pivoting about the top (the rope anchors).
  double get _hangDy {
    final q = ((_c.value - 0.35) / (0.60 - 0.35)).clamp(0.0, 1.0);
    // Fraction of screen height; starts high above, eases down to 0.
    return -0.55 * (1 - Curves.easeOutCubic.transform(q));
  }

  double get _hangAngle {
    final q = ((_c.value - 0.50) / 0.50).clamp(0.0, 1.0);
    if (q <= 0) return 0.0;
    // Damped pendulum: sin() starts at 0 (continuous with the drop) then swings
    // ~1.5 times, the exp envelope settling it back to level.
    return 0.11 * math.exp(-3.0 * q) * math.sin(3.0 * math.pi * q);
  }

  double get _hangOpacity => ((_c.value - 0.33) / 0.12).clamp(0.0, 1.0);

  Widget _hang({
    required double screenW,
    required double screenH,
    required double cx,
    required double cy,
    required double wFrac,
    required double aspect,
    required Widget child,
  }) {
    final width = screenW * wFrac;
    final height = width * aspect;
    return Positioned(
      left: screenW * cx - width / 2,
      top: screenH * cy - height / 2,
      width: width,
      height: height,
      child: Opacity(
        opacity: _hangOpacity,
        child: Transform.translate(
          offset: Offset(0, _hangDy * screenH),
          child: Transform.rotate(
            angle: _hangAngle,
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final win = widget.kind == _ReversiResultKind.win;
    return Scaffold(
      backgroundColor: const Color(0xFF9AD0EE),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: _fade(0.0, 0.28),
                      child: Image.asset(
                        '${_reversiAsset}result_bg.png',
                        fit: BoxFit.cover,
                      ),
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

  // Positions measured from Figma 胜利弹窗 (frame 393x852, node 125:1136):
  // emblem 42,193,309x329 · ribbon 36,349,321x102 · 积分 147,456,100x55 ·
  // buttons 37/224,588,136x54 · 胜利 text 104,364,187x47.
  List<Widget> _winPieces(double w, double h) => [
    // Sun emblem stone — sits lower than before so the ribbon can cross its
    // lower third (design: centre y ~0.42, not near the top).
    _piece(
      screenW: w, screenH: h, cx: 0.5, cy: 0.4196, wFrac: 0.786,
      aspect: 329 / 309, begin: 0.12, end: 0.5, drop: true,
      child: _img('result_win_emblem.png'),
    ),
    // "胜利" ribbon over the emblem's lower third. The 胜利 art is centred on the
    // red banner body (~0.38 of the ribbon box height), not the box centre.
    _piece(
      screenW: w, screenH: h, cx: 0.5, cy: 0.4695, wFrac: 0.8168,
      aspect: 102 / 321, begin: 0.4, end: 0.64, drop: false,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: _img('result_win_ribbon.png')),
          // Upper thicker part of the band (height OK per review). Nudged right
          // because the title art's visible mass sits left of centre (its drop
          // shadow pads the right edge), so a centred box reads slightly left.
          Align(
            alignment: const Alignment(0.09, -0.5),
            child: FractionallySizedBox(
              widthFactor: 0.52,
              heightFactor: 0.4,
              child: Image.asset(
                '${_reversiAsset}result_win_title.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    ),
    // "积分" hanging sign, just below the ribbon.
    _piece(
      screenW: w, screenH: h, cx: 0.501, cy: 0.5675, wFrac: 0.2545,
      aspect: 55 / 100, begin: 0.52, end: 0.76, drop: false,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: _img('result_win_scroll.png')),
          // Biased down onto the lower body of the parchment panel (rope loops
          // sit above it, so a centred score reads "high").
          Positioned.fill(
            child: _scoreContent(
              'result_txt_score.png',
              'result_win_num.png',
              align: const Alignment(0, 0.85),
            ),
          ),
        ],
      ),
    ),
    _piece(
      screenW: w, screenH: h, cx: 0.267, cy: 0.722, wFrac: 0.346,
      aspect: 54 / 136, begin: 0.68, end: 0.92, drop: false,
      child: _button(
        base: 'result_win_btn.png',
        text: 'result_txt_again.png',
        textWidthFactor: 0.66,
        onTap: widget.onAgain,
      ),
    ),
    _piece(
      screenW: w, screenH: h, cx: 0.743, cy: 0.722, wFrac: 0.346,
      aspect: 54 / 136, begin: 0.74, end: 0.98, drop: false,
      child: _button(
        base: 'result_win_btn.png',
        text: 'result_txt_ok.png',
        textWidthFactor: 0.34,
        onTap: widget.onConfirm,
      ),
    ),
  ];

  List<Widget> _losePieces(double w, double h) => [
    // Outer stone frame drops in first as the backdrop.
    _piece(
      screenW: w, screenH: h, cx: 0.5, cy: 0.45, wFrac: 0.665,
      aspect: 1062 / 804, begin: 0.1, end: 0.42, drop: true,
      child: _img('result_lose_frame.png'),
    ),
    // Crossed swords crown atop the frame.
    _piece(
      screenW: w, screenH: h, cx: 0.5, cy: 0.265, wFrac: 0.225,
      aspect: 327 / 309, begin: 0.3, end: 0.54, drop: false,
      child: _img('result_lose_swords.png'),
    ),
    // Crossed bones tied into the two bottom corners. The long bone reads as a
    // "/" on the left and its mirror "\" on the right, matching the design
    // (the asset's long bone sits near-horizontal, so it needs a counter-
    // clockwise tilt on the left and the mirror on the right).
    _piece(
      screenW: w, screenH: h, cx: 0.242, cy: 0.62, wFrac: 0.15,
      aspect: 250 / 258, begin: 0.5, end: 0.72, drop: false,
      child: Transform.rotate(
        angle: -0.7,
        child: _img('result_lose_bones.png'),
      ),
    ),
    _piece(
      screenW: w, screenH: h, cx: 0.758, cy: 0.62, wFrac: 0.15,
      aspect: 250 / 258, begin: 0.5, end: 0.72, drop: false,
      child: Transform.rotate(
        angle: 0.7,
        child: Transform.flip(
          flipX: true,
          child: _img('result_lose_bones.png'),
        ),
      ),
    ),
    // Hanging pendant: the two rope coils and the "失败" plate drop from above
    // as a group and swing before settling. Only the coil is shown (tablet
    // clipped away), and the plate rides just under the coils.
    // Rope coils centred on the frame's two tiki blocks. The frame art leans
    // slightly right, so the right tiki sits further right than a mirror of the
    // left — tuned on-device to 0.360 / 0.662.
    _hang(
      screenW: w, screenH: h, cx: 0.360, cy: 0.365, wFrac: 0.072,
      aspect: 249 / 84,
      child: _ropeCoil(),
    ),
    _hang(
      screenW: w, screenH: h, cx: 0.662, cy: 0.365, wFrac: 0.072,
      aspect: 249 / 84,
      child: _ropeCoil(flip: true),
    ),
    // "失败" title plate — slightly right of centre, raised so its top meets the
    // rope coils (design note: 靠右居中一些 + 板子上移).
    _hang(
      screenW: w, screenH: h, cx: 0.515, cy: 0.395, wFrac: 0.405,
      aspect: 282 / 492,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: _img('result_lose_title_plate.png')),
          FractionallySizedBox(
            widthFactor: 0.58,
            heightFactor: 0.6,
            child: Image.asset(
              '${_reversiAsset}result_lose_title.png',
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    ),
    _piece(
      screenW: w, screenH: h, cx: 0.505, cy: 0.518, wFrac: 0.32,
      aspect: 153 / 402, begin: 0.72, end: 0.88, drop: false,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: _img('result_lose_score_plate.png')),
          Positioned.fill(
            child: _scoreContent(
              'result_lose_score_label.png',
              'result_lose_num.png',
            ),
          ),
        ],
      ),
    ),
    _piece(
      screenW: w, screenH: h, cx: 0.29, cy: 0.74, wFrac: 0.34,
      aspect: 258 / 405, begin: 0.82, end: 0.94, drop: false,
      child: _button(
        base: 'result_lose_btn_again.png',
        text: 'result_txt_again.png',
        textWidthFactor: 0.6,
        onTap: widget.onAgain,
      ),
    ),
    _piece(
      screenW: w, screenH: h, cx: 0.71, cy: 0.74, wFrac: 0.34,
      aspect: 255 / 399, begin: 0.88, end: 1.0, drop: false,
      child: _button(
        base: 'result_lose_btn_ok.png',
        text: 'result_txt_ok.png',
        textWidthFactor: 0.32,
        onTap: widget.onConfirm,
      ),
    ),
  ];
}
