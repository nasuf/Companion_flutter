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
  int _agentMoveElapsed = 0;
  int _userActionSequence = 0;
  bool _finishing = false;
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
    setState(() {
      _engine = null;
      _finishing = false;
      _userGravityElapsed = 0;
      _agentMoveElapsed = 0;
      _userActionSequence = 0;
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
    setState(() {
      _engine = TetrisDuelEngine(
        seed: seed,
        config: gameConfig ?? TetrisDuelConfig.fromJson(session.engineConfig),
      );
      _finishing = false;
      _userGravityElapsed = 0;
      _agentMoveElapsed = 0;
      _userActionSequence = 0;
      _eventChain = Future<void>.value();
      _lastTickAt = DateTime.now();
    });
    _ticker = Timer.periodic(_tickInterval, (_) => _tick());
  }

  void _tick() {
    final engine = _engine;
    if (engine == null || engine.isFinished || _finishing) return;
    if (_runtime.turnTimeoutVisible) {
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
    _agentMoveElapsed += delta;

    if (_userGravityElapsed >= _userGravityInterval(engine.user.level)) {
      _userGravityElapsed = 0;
      final result = engine.user.softDrop();
      if (result != null) _handleLock(result);
    }
    if (!engine.isFinished &&
        _agentMoveElapsed >= _agentMoveInterval(engine.agent.level)) {
      _agentMoveElapsed = 0;
      final decision = engine.agent.chooseAiPlacement(config: engine.config);
      final result = engine.agent.playAiPlacement(decision);
      _handleLock(result, decision: decision);
    }
    if (engine.isFinished) {
      unawaited(_finish());
    } else if (mounted) {
      setState(() {});
    }
  }

  int _userGravityInterval(int level) =>
      math.max(170, _userGravityMilliseconds - (level - 1) * 48);

  int _agentMoveInterval(int level) =>
      math.max(260, (_engine?.config.agentMoveMs ?? 760) - (level - 1) * 32);

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
        !_finishing;
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

  @override
  Widget build(BuildContext context) {
    final engine = _engine;
    return _NativeGameExperienceScaffold(
      runtime: _runtime,
      game: widget.game,
      subtitle: engine == null
          ? '和 ${_runtime.agentName} 同时开局，90 秒比分见真章'
          : engine.isFinished
          ? '本局已经结束'
          : '双方同时落块 · 还剩 ${engine.remainingSeconds} 秒',
      onStart: _start,
      onActiveRoundDeleted: _clearActiveRound,
      restartDisabled: _finishing,
      showPlayers: false,
      userTurnActive:
          engine != null &&
          !engine.isFinished &&
          !_runtime.completed &&
          !_finishing,
      turnToken: engine == null ? 'idle' : 'input:$_userActionSequence',
      turnLabel: '双方同时行动',
      moveCount: engine == null
          ? 0
          : engine.user.piecesPlaced + engine.agent.piecesPlaced,
      currentSummary: _sessionSummary,
      activeChild: engine == null
          ? null
          : _TetrisDuelStage(
              engine: engine,
              runtime: _runtime,
              canControl: _canControl,
              onMove: _move,
              onRotate: _rotate,
              onHold: _hold,
              onHardDrop: _hardDrop,
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
            ),
    );
  }
}

class _TetrisDuelStage extends StatefulWidget {
  const _TetrisDuelStage({
    required this.engine,
    required this.runtime,
    required this.canControl,
    required this.onMove,
    required this.onRotate,
    required this.onHold,
    required this.onHardDrop,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  final TetrisDuelEngine engine;
  final _NativeGameRuntime runtime;
  final bool canControl;
  final ValueChanged<int> onMove;
  final VoidCallback onRotate;
  final VoidCallback onHold;
  final VoidCallback onHardDrop;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;

  @override
  State<_TetrisDuelStage> createState() => _TetrisDuelStageState();
}

class _TetrisDuelStageState extends State<_TetrisDuelStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _pulse,
    builder: (context, _) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TetrisDuelHeader(
          engine: widget.engine,
          runtime: widget.runtime,
          pulse: _pulse.value,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final gap = constraints.maxWidth < 390 ? 8.0 : 12.0;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _TetrisBoardPanel(
                    label: '你',
                    board: widget.engine.user,
                    accent: const Color(0xFF39D5FF),
                    interactive: widget.canControl,
                    onTap: widget.onRotate,
                    onPanStart: widget.onPanStart,
                    onPanUpdate: widget.onPanUpdate,
                    onPanEnd: widget.onPanEnd,
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  child: _TetrisBoardPanel(
                    label: widget.runtime.agentName,
                    board: widget.engine.agent,
                    accent: const Color(0xFFFF5A9B),
                    interactive: false,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _TetrisControls(
          enabled: widget.canControl,
          onLeft: () => widget.onMove(-1),
          onRight: () => widget.onMove(1),
          onRotate: widget.onRotate,
          onHold: widget.onHold,
          onDrop: widget.onHardDrop,
        ),
      ],
    ),
  );
}

class _TetrisDuelHeader extends StatelessWidget {
  const _TetrisDuelHeader({
    required this.engine,
    required this.runtime,
    required this.pulse,
  });

  final TetrisDuelEngine engine;
  final _NativeGameRuntime runtime;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final urgent = engine.remainingSeconds <= 15;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF10152C).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF5869B4).withValues(alpha: 0.34),
        ),
      ),
      child: Row(
        children: [
          _TetrisDuelIdentity(
            name: '你',
            imageUrl: runtime.authSession.userAvatarUrl,
            score: engine.user.score,
            color: const Color(0xFF39D5FF),
            pulse: pulse,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '${engine.remainingSeconds}',
                  style: TextStyle(
                    color: urgent ? const Color(0xFFFFC857) : Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  '双方同步进行',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.48),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          _TetrisDuelIdentity(
            name: runtime.agentName,
            imageUrl: runtime.authSession.agentAvatarUrl,
            score: engine.agent.score,
            color: const Color(0xFFFF5A9B),
            pulse: pulse,
            alignEnd: true,
          ),
        ],
      ),
    );
  }
}

class _TetrisDuelIdentity extends StatelessWidget {
  const _TetrisDuelIdentity({
    required this.name,
    required this.imageUrl,
    required this.score,
    required this.color,
    required this.pulse,
    this.alignEnd = false,
  });

  final String name;
  final String? imageUrl;
  final int score;
  final Color color;
  final double pulse;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18 + pulse * 0.2),
            blurRadius: 8 + pulse * 8,
          ),
        ],
      ),
      child: _Avatar(
        size: 32,
        label: name.isEmpty ? '?' : name.characters.first,
        gradient: [color.withValues(alpha: 0.72), const Color(0xFF151B38)],
        imageUrl: imageUrl,
      ),
    );
    final text = Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          '$score',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
    return SizedBox(
      width: 104,
      child: Row(
        mainAxisAlignment: alignEnd
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: alignEnd
            ? [Flexible(child: text), const SizedBox(width: 7), avatar]
            : [avatar, const SizedBox(width: 7), Flexible(child: text)],
      ),
    );
  }
}

class _TetrisBoardPanel extends StatelessWidget {
  const _TetrisBoardPanel({
    required this.label,
    required this.board,
    required this.accent,
    required this.interactive,
    this.onTap,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
  });

  final String label;
  final TetrisBoardEngine board;
  final Color accent;
  final bool interactive;
  final VoidCallback? onTap;
  final GestureDragStartCallback? onPanStart;
  final GestureDragUpdateCallback? onPanUpdate;
  final GestureDragEndCallback? onPanEnd;

  @override
  Widget build(BuildContext context) {
    final boardWidget = AspectRatio(
      aspectRatio: TetrisBoardEngine.width / TetrisBoardEngine.height,
      child: CustomPaint(
        painter: _TetrisBoardPainter(board: board, accent: accent),
      ),
    );
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.text.withValues(alpha: 0.76),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${board.lines} 行',
              style: TextStyle(
                color: accent,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF080B18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.62)),
            boxShadow: [
              BoxShadow(color: accent.withValues(alpha: 0.14), blurRadius: 14),
            ],
          ),
          child: interactive
              ? GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  onPanStart: onPanStart,
                  onPanUpdate: onPanUpdate,
                  onPanEnd: onPanEnd,
                  child: boardWidget,
                )
              : boardWidget,
        ),
        const SizedBox(height: 5),
        Text(
          'Lv.${board.level} · ${board.piecesPlaced} 块',
          style: TextStyle(
            color: AppColors.text.withValues(alpha: 0.42),
            fontSize: 8,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _TetrisControls extends StatelessWidget {
  const _TetrisControls({
    required this.enabled,
    required this.onLeft,
    required this.onRight,
    required this.onRotate,
    required this.onHold,
    required this.onDrop,
  });

  final bool enabled;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VoidCallback onRotate;
  final VoidCallback onHold;
  final VoidCallback onDrop;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _TetrisControlButton(
        icon: Icons.chevron_left_rounded,
        onTap: onLeft,
        enabled: enabled,
      ),
      const SizedBox(width: 7),
      _TetrisControlButton(
        icon: Icons.rotate_right_rounded,
        onTap: onRotate,
        enabled: enabled,
      ),
      const SizedBox(width: 7),
      _TetrisControlButton(
        icon: Icons.chevron_right_rounded,
        onTap: onRight,
        enabled: enabled,
      ),
      const Spacer(),
      _TetrisControlButton(
        icon: Icons.inventory_2_outlined,
        onTap: onHold,
        enabled: enabled,
      ),
      const SizedBox(width: 7),
      _TetrisControlButton(
        icon: Icons.keyboard_double_arrow_down_rounded,
        onTap: onDrop,
        enabled: enabled,
        emphasized: true,
      ),
    ],
  );
}

class _TetrisControlButton extends StatelessWidget {
  const _TetrisControlButton({
    required this.icon,
    required this.onTap,
    required this.enabled,
    this.emphasized = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(42, 42),
      onPressed: enabled ? onTap : null,
      child: Container(
        width: emphasized ? 54 : 42,
        height: 42,
        decoration: BoxDecoration(
          gradient: emphasized
              ? const LinearGradient(
                  colors: [Color(0xFF7D5CFF), Color(0xFFFF5A9B)],
                )
              : null,
          color: emphasized ? null : const Color(0xFF151B38),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: emphasized
                ? const Color(0xFFFFC857).withValues(alpha: 0.62)
                : const Color(0xFF5966A6).withValues(alpha: 0.4),
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.3),
          size: 22,
        ),
      ),
    ),
  );
}

class _TetrisBoardPainter extends CustomPainter {
  _TetrisBoardPainter({required this.board, required this.accent})
    : stateHash = board.stateHash;

  final TetrisBoardEngine board;
  final Color accent;
  final int stateHash;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / TetrisBoardEngine.width;
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
    for (var column = 0; column <= TetrisBoardEngine.width; column++) {
      canvas.drawLine(
        Offset(column * cell, 0),
        Offset(column * cell, size.height),
        grid,
      );
    }
    for (var row = 0; row <= TetrisBoardEngine.height; row++) {
      canvas.drawLine(
        Offset(0, row * cell),
        Offset(size.width, row * cell),
        grid,
      );
    }
    for (var row = 0; row < TetrisBoardEngine.height; row++) {
      for (var column = 0; column < TetrisBoardEngine.width; column++) {
        final value = board.board[row * TetrisBoardEngine.width + column];
        if (value != 0) _paintCell(canvas, column, row, cell, value, 1);
      }
    }
    for (final ghost in board.ghostCells()) {
      if (ghost.y >= 0) {
        _paintCell(
          canvas,
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
      x * cell + 1.1,
      y * cell + 1.1,
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
