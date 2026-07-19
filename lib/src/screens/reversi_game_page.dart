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
    });
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
    return _NativeGameExperienceScaffold(
      runtime: _runtime,
      game: widget.game,
      subtitle: engine == null
          ? '和 ${_runtime.agentName} 翻一盘黑白棋'
          : engine.isFinished
          ? _reversiResultText(engine, _runtime.agentName)
          : _runtime.aiThinking
          ? '${_runtime.agentName} 正在算角和机动性'
          : _resolving
          ? '棋子正在翻面'
          : engine.turn == ReversiActor.user
          ? '你执黑，落在发光的位置'
          : '${_runtime.agentName} 执白，轮到对方落子',
      onStart: _start,
      onActiveRoundDeleted: _clearActiveRound,
      restartDisabled: _runtime.aiThinking || _resolving,
      userTurnActive:
          engine != null &&
          !engine.isFinished &&
          engine.turn == ReversiActor.user &&
          !_runtime.aiThinking &&
          !_resolving,
      turnToken: engine == null
          ? 'idle'
          : '${engine.moveCount}:${engine.turn.name}',
      turnLabel: _runtime.aiThinking ? '${_runtime.agentName} 在落子' : '轮到你',
      moveCount: engine?.moveCount ?? 0,
      currentSummary: () => _engine?.summaryJson() ?? const {},
      activeChild: engine == null
          ? null
          : Column(
              children: [
                _NativeScoreHeader(
                  left: '黑 · 你  ${engine.userCount}',
                  center: '${engine.moves.length} 手',
                  right: '白 · ${_runtime.agentName}  ${engine.agentCount}',
                ),
                const SizedBox(height: 10),
                AspectRatio(
                  aspectRatio: 1,
                  child: _ReversiBoard(
                    engine: engine,
                    lastMove: _lastMove,
                    thinking: _runtime.aiThinking,
                    enabled:
                        engine.turn == ReversiActor.user &&
                        !_runtime.aiThinking &&
                        !_resolving &&
                        !engine.isFinished,
                    onTap: _userPlay,
                  ),
                ),
                const SizedBox(height: 11),
                _ReversiPositionStrip(
                  engine: engine,
                  agentName: _runtime.agentName,
                ),
              ],
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

class _ReversiPositionStrip extends StatelessWidget {
  const _ReversiPositionStrip({required this.engine, required this.agentName});

  final ReversiEngine engine;
  final String agentName;

  @override
  Widget build(BuildContext context) {
    final occupied = math.max(1, engine.userCount + engine.agentCount);
    final blackShare = (engine.userCount / occupied).clamp(0.06, 0.94);
    final analysis = engine.analysisJson();
    final userMobility = analysis['user_mobility'] as int;
    final agentMobility = analysis['agent_mobility'] as int;
    final userCorners = analysis['user_corner_count'] as int;
    final agentCorners = analysis['agent_corner_count'] as int;
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.text.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                engine.isFinished ? '最终盘面' : '黑白势力',
                style: TextStyle(
                  color: AppColors.text.withValues(alpha: 0.58),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${engine.userCount} : ${engine.agentCount}',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(
                    flex: (blackShare * 1000).round(),
                    child: const ColoredBox(color: Color(0xFF14191D)),
                  ),
                  Expanded(
                    flex: ((1 - blackShare) * 1000).round(),
                    child: const ColoredBox(color: Color(0xFFF2EBD9)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _ReversiStatChip(
                icon: CupertinoIcons.scope,
                text: '可下 $userMobility : $agentMobility',
              ),
              const SizedBox(width: 7),
              _ReversiStatChip(
                icon: CupertinoIcons.square_grid_2x2,
                text: '角落 $userCorners : $agentCorners',
              ),
              const Spacer(),
              Text(
                engine.isFinished
                    ? _reversiResultText(engine, agentName)
                    : '空位 ${engine.emptyCount}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.text.withValues(alpha: 0.45),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReversiStatChip extends StatelessWidget {
  const _ReversiStatChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFF13715D).withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: const Color(0xFF13715D)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF13715D),
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
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
            final side = math.min(constraints.maxWidth, constraints.maxHeight);
            final size = Size.square(side);
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
                builder: (context, _) => CustomPaint(
                  size: size,
                  painter: _ReversiBoardPainter(
                    board: widget.engine.board,
                    legalMoves: legal,
                    currentActor: widget.engine.turn,
                    lastMove: widget.lastMove,
                    moveProgress: Curves.easeInOutCubic.transform(
                      _moveController.value,
                    ),
                    ambientProgress: _ambientController.value,
                    thinking: widget.thinking,
                    geometry: geometry,
                    darkMode: AppColors.isDark(context),
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

class _ReversiBoardGeometry {
  const _ReversiBoardGeometry(this.size);

  final Size size;

  double get inset => size.width * 0.045;
  double get cell => (size.width - inset * 2) / ReversiEngine.size;
  Rect get gridRect => Rect.fromLTWH(
    inset,
    inset,
    cell * ReversiEngine.size,
    cell * ReversiEngine.size,
  );

  Rect cellRect(int index) => Rect.fromLTWH(
    inset + (index % ReversiEngine.size) * cell,
    inset + (index ~/ ReversiEngine.size) * cell,
    cell,
    cell,
  );

  int? indexAt(Offset position) {
    if (!gridRect.contains(position)) return null;
    final col = ((position.dx - inset) / cell).floor();
    final row = ((position.dy - inset) / cell).floor();
    if (row < 0 ||
        row >= ReversiEngine.size ||
        col < 0 ||
        col >= ReversiEngine.size) {
      return null;
    }
    return row * ReversiEngine.size + col;
  }
}

class _ReversiBoardPainter extends CustomPainter {
  const _ReversiBoardPainter({
    required this.board,
    required this.legalMoves,
    required this.currentActor,
    required this.lastMove,
    required this.moveProgress,
    required this.ambientProgress,
    required this.thinking,
    required this.geometry,
    required this.darkMode,
  });

  final List<int> board;
  final Map<int, List<int>> legalMoves;
  final ReversiActor currentActor;
  final ReversiMove? lastMove;
  final double moveProgress;
  final double ambientProgress;
  final bool thinking;
  final _ReversiBoardGeometry geometry;
  final bool darkMode;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final radius = Radius.circular(size.width * 0.055);
    final shape = RRect.fromRectAndRadius(bounds, radius);
    canvas.save();
    canvas.clipRRect(shape);
    canvas.drawRRect(
      shape,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E594B), Color(0xFF073D35), Color(0xFF0B4A3D)],
          stops: [0, 0.58, 1],
        ).createShader(bounds),
    );
    _paintFelt(canvas, bounds);
    final grid = geometry.gridRect;
    canvas.drawRRect(
      RRect.fromRectAndRadius(grid.inflate(size.width * 0.012), radius * 0.55),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFCCA765), Color(0xFF76552D)],
        ).createShader(grid),
    );
    canvas.drawRect(grid, Paint()..color = const Color(0xFF126B56));

    for (var index = 0; index < board.length; index++) {
      final rect = geometry.cellRect(index);
      final row = index ~/ ReversiEngine.size;
      final col = index % ReversiEngine.size;
      canvas.drawRect(
        rect.deflate(0.45),
        Paint()
          ..color = (row + col).isEven
              ? const Color(0xFF16745E)
              : const Color(0xFF126A57),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = const Color(0xFF073B32).withValues(alpha: 0.62)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.65, geometry.cell * 0.016),
      );
    }

    for (final index in [27, 28, 35, 36]) {
      canvas.drawCircle(
        geometry.cellRect(index).center,
        geometry.cell * 0.035,
        Paint()..color = const Color(0xFFD9BD7C).withValues(alpha: 0.7),
      );
    }

    final flipping =
        lastMove?.flipped.map((point) => point.index).toSet() ?? const <int>{};
    for (var index = 0; index < board.length; index++) {
      final current = board[index];
      if (current == 0) continue;
      final rect = geometry.cellRect(index);
      if (lastMove?.point.index == index && moveProgress < 1) {
        final value = Curves.elasticOut.transform(
          (moveProgress / 0.56).clamp(0.0, 1.0),
        );
        _paintDisc(canvas, rect, current, scaleX: value, scaleY: value);
        continue;
      }
      if (flipping.contains(index) && moveProgress < 0.88) {
        final local = ((moveProgress - 0.12) / 0.68).clamp(0.0, 1.0);
        final before = lastMove!.boardBefore[index];
        final after = lastMove!.boardAfter[index];
        final scaleX = math.cos(local * math.pi).abs().clamp(0.045, 1.0);
        _paintDisc(
          canvas,
          rect,
          local < 0.5 ? before : after,
          scaleX: scaleX,
          scaleY: 1 + math.sin(local * math.pi) * 0.08,
          lift: math.sin(local * math.pi) * geometry.cell * 0.08,
        );
        continue;
      }
      _paintDisc(canvas, rect, current);
    }

    final pulse = 0.55 + ambientProgress * 0.45;
    for (final entry in legalMoves.entries) {
      final center = geometry.cellRect(entry.key).center;
      final actorValue = currentActor == ReversiActor.user ? 1 : -1;
      canvas.drawCircle(
        center,
        geometry.cell * (0.19 + pulse * 0.025),
        Paint()
          ..color = actorValue == 1
              ? Colors.black.withValues(alpha: 0.2 + pulse * 0.12)
              : Colors.white.withValues(alpha: 0.18 + pulse * 0.12),
      );
      canvas.drawCircle(
        center,
        geometry.cell * 0.11,
        Paint()
          ..color = const Color(0xFFFFD980).withValues(alpha: 0.78)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.1, geometry.cell * 0.035),
      );
      if (entry.value.length >= 4) {
        canvas.drawCircle(
          center,
          geometry.cell * 0.055,
          Paint()..color = const Color(0xFFFFE7AE),
        );
      }
    }

    if (lastMove != null) {
      final marker = geometry.cellRect(lastMove!.point.index).center;
      canvas.drawCircle(
        marker,
        geometry.cell * 0.08,
        Paint()
          ..color = const Color(0xFFFFD36B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, geometry.cell * 0.028),
      );
      if (moveProgress < 1) _paintFlipTrails(canvas, lastMove!, moveProgress);
    }
    canvas.drawRRect(
      shape.deflate(1),
      Paint()
        ..color = Colors.white.withValues(alpha: darkMode ? 0.13 : 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.restore();
  }

  void _paintFelt(Canvas canvas, Rect bounds) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 0.7;
    for (var index = 0; index < 42; index++) {
      final y = (index * 37 % 101) / 101 * bounds.height;
      final x = (index * 61 % 97) / 97 * bounds.width;
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(bounds.right, x + bounds.width * 0.13), y + 0.7),
        paint,
      );
    }
  }

  void _paintDisc(
    Canvas canvas,
    Rect cell,
    int value, {
    double scaleX = 1,
    double scaleY = 1,
    double lift = 0,
  }) {
    if (value == 0) return;
    final center = cell.center - Offset(0, lift);
    final radius = geometry.cell * 0.37;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scaleX, scaleY);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(0, geometry.cell * 0.075),
        width: radius * 1.82,
        height: radius * 0.62,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.34),
    );
    final discRect = Rect.fromCircle(center: center, radius: radius);
    final colors = value == 1
        ? const [Color(0xFF555C61), Color(0xFF15191C), Color(0xFF050607)]
        : const [Color(0xFFFFFFFF), Color(0xFFF0E7D5), Color(0xFFC8BDAA)];
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.42, -0.52),
          radius: 1.08,
          colors: colors,
          stops: const [0, 0.52, 1],
        ).createShader(discRect),
    );
    canvas.drawCircle(
      center,
      radius * 0.91,
      Paint()
        ..color = value == 1
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.7, geometry.cell * 0.018),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center - Offset(radius * 0.2, radius * 0.27),
        width: radius * 0.62,
        height: radius * 0.2,
      ),
      Paint()..color = Colors.white.withValues(alpha: value == 1 ? 0.13 : 0.52),
    );
    canvas.restore();
  }

  void _paintFlipTrails(Canvas canvas, ReversiMove move, double progress) {
    if (progress < 0.16 || progress > 0.88) return;
    final fade = math.sin(((progress - 0.16) / 0.72) * math.pi);
    for (final point in move.flipped) {
      final center = geometry.cellRect(point.index).center;
      for (var particle = 0; particle < 3; particle++) {
        final angle = point.index * 0.43 + particle * math.pi * 2 / 3;
        final offset =
            Offset(math.cos(angle), math.sin(angle)) *
            geometry.cell *
            (0.23 + progress * 0.12);
        canvas.drawCircle(
          center + offset,
          geometry.cell * 0.032 * fade,
          Paint()
            ..color = const Color(0xFFFFD878).withValues(alpha: fade * 0.8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ReversiBoardPainter oldDelegate) =>
      !listEquals(oldDelegate.board, board) ||
      oldDelegate.legalMoves.keys
          .toSet()
          .difference(legalMoves.keys.toSet())
          .isNotEmpty ||
      legalMoves.keys
          .toSet()
          .difference(oldDelegate.legalMoves.keys.toSet())
          .isNotEmpty ||
      oldDelegate.lastMove?.number != lastMove?.number ||
      oldDelegate.moveProgress != moveProgress ||
      oldDelegate.ambientProgress != ambientProgress ||
      oldDelegate.thinking != thinking ||
      oldDelegate.geometry.gridRect != geometry.gridRect ||
      oldDelegate.darkMode != darkMode;
}
