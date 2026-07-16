part of 'package:companion_flutter/main.dart';

class _GoGamePage extends StatefulWidget {
  const _GoGamePage({
    required this.api,
    required this.authSession,
    required this.game,
  });

  final CompanionApi api;
  final AuthSession authSession;
  final _GameTile game;

  @override
  State<_GoGamePage> createState() => _GoGamePageState();
}

class _GoGamePageState extends State<_GoGamePage> {
  late final _NativeGameRuntime _runtime;
  GoEngine? _engine;
  GoMove? _lastMove;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _runtime = _NativeGameRuntime(
      api: widget.api,
      authSession: widget.authSession,
      gameKey: _nativeGoGameKey,
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
    unawaited(_runtime.initialize());
  }

  @override
  void dispose() {
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
      'board_size': GoEngine.boardSize,
      'first_actor': 'user',
      'user_color': 'black',
      'agent_color': 'white',
      'komi': 6.5,
      'rules': 'chinese_area_scoring_positional_superko',
      'search': 'uct_mcts_pattern_capture_rollout',
    });
    if (session != null && mounted) {
      setState(() {
        _engine = GoEngine();
        _lastMove = null;
        _resolving = false;
      });
    }
  }

  Future<void> _userPlay(int index) async {
    final engine = _engine;
    if (engine == null ||
        engine.isFinished ||
        engine.turn != GoActor.user ||
        _runtime.aiThinking ||
        _resolving ||
        !engine.isLegal(index)) {
      return;
    }
    await _playAndReport(index);
    if (!engine.isFinished) await _agentTurn();
  }

  Future<void> _userPass() async {
    final engine = _engine;
    if (engine == null ||
        engine.isFinished ||
        engine.turn != GoActor.user ||
        _runtime.aiThinking ||
        _resolving) {
      return;
    }
    await _playAndReport(null);
    if (!engine.isFinished) await _agentTurn();
  }

  Future<void> _agentTurn() async {
    final engine = _engine;
    if (engine == null || engine.isFinished || engine.turn != GoActor.agent) {
      return;
    }
    setState(() => _runtime.aiThinking = true);
    await _runtime.reportEvent(
      'ai_thinking_started',
      payload: {
        'move_number': engine.moveCount + 1,
        'analysis': engine.analysisJson(),
      },
    );
    try {
      final decision = await engine.chooseAiMove();
      if (!mounted || engine.isFinished || engine.turn != GoActor.agent) return;
      await _runtime.reportEvent('ai_move_decided', payload: decision.toJson());
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (!mounted || engine.isFinished || engine.turn != GoActor.agent) return;
      await _playAndReport(decision.index, decision: decision);
    } finally {
      if (mounted) setState(() => _runtime.aiThinking = false);
    }
  }

  Future<void> _playAndReport(int? index, {GoAiDecision? decision}) async {
    final engine = _engine!;
    final before = engine.stateJson();
    final result = engine.play(index, decision: decision);
    if (mounted) {
      setState(() {
        _lastMove = result.move;
        _resolving = true;
      });
    }
    unawaited(
      result.move.captured.length >= 3
          ? HapticFeedback.heavyImpact()
          : HapticFeedback.selectionClick(),
    );
    try {
      await Future.wait([
        _reportMove(result.move, before),
        Future<void>.delayed(
          Duration(milliseconds: result.move.captured.isEmpty ? 380 : 620),
        ),
      ]);
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
    if (result.status != GoStatus.playing) await _finish(result.status);
  }

  Future<void> _reportMove(GoMove move, Map<String, dynamic> before) async {
    final engine = _engine!;
    await _runtime.reportEvent(
      'stone_placed',
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
        payload: {
          ...move.moment!,
          'move_number': move.number,
          'actor': move.actor.name,
          if (move.index != null) 'point': GoPoint(move.index!).toJson(),
        },
      );
    }
  }

  Future<void> _finish(GoStatus status) async {
    final engine = _engine!;
    await _runtime.finish({
      ...engine.summaryJson(),
      'user_outcome': switch (status) {
        GoStatus.userWon => 'win',
        GoStatus.agentWon => 'lose',
        GoStatus.draw => 'draw',
        GoStatus.playing => 'aborted',
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
          ? '和 ${_runtime.agentName} 下一盘 9 路快棋'
          : engine.isFinished
          ? _goResultText(engine, _runtime.agentName)
          : _runtime.aiThinking
          ? '${_runtime.agentName} 正在读这一片棋形'
          : _resolving
          ? '这一手正在落定'
          : '你执黑，轮到你落子',
      onStart: _start,
      onActiveRoundDeleted: _clearActiveRound,
      restartDisabled: _runtime.aiThinking || _resolving,
      historySubtitle: '每一手、提子、叫吃、停着与最终数目都会保存。',
      activeChild: engine == null
          ? null
          : Column(
              children: [
                _NativeScoreHeader(
                  left: '黑 · 你  提 ${engine.userCaptures}',
                  center: '${engine.moves.length} 手',
                  right: '白 · ${_runtime.agentName}  提 ${engine.agentCaptures}',
                ),
                const SizedBox(height: 10),
                AspectRatio(
                  aspectRatio: 1,
                  child: _GoBoard(
                    engine: engine,
                    lastMove: _lastMove,
                    thinking: _runtime.aiThinking,
                    enabled:
                        engine.turn == GoActor.user &&
                        !_runtime.aiThinking &&
                        !_resolving &&
                        !engine.isFinished,
                    onTap: _userPlay,
                  ),
                ),
                const SizedBox(height: 11),
                _GoPositionStrip(
                  engine: engine,
                  agentName: _runtime.agentName,
                  onPass: _userPass,
                  passEnabled:
                      engine.turn == GoActor.user &&
                      !_runtime.aiThinking &&
                      !_resolving &&
                      !engine.isFinished,
                ),
              ],
            ),
    );
  }
}

String _goResultText(GoEngine engine, String agentName) {
  final score = engine.score;
  final margin = _goScoreLabel(score.margin);
  return switch (engine.status) {
    GoStatus.userWon => '你执黑胜 $margin 目',
    GoStatus.agentWon => '$agentName 执白胜 $margin 目',
    GoStatus.draw => '这一盘刚好持平',
    GoStatus.playing => '棋局进行中',
  };
}

String _goScoreLabel(double score) => score == score.roundToDouble()
    ? score.toInt().toString()
    : score.toStringAsFixed(1);

class _GoPositionStrip extends StatelessWidget {
  const _GoPositionStrip({
    required this.engine,
    required this.agentName,
    required this.onPass,
    required this.passEnabled,
  });

  final GoEngine engine;
  final String agentName;
  final VoidCallback onPass;
  final bool passEnabled;

  @override
  Widget build(BuildContext context) {
    final score = engine.score;
    final isFinal = engine.isFinished;
    final blackValue = isFinal ? score.userTotal : score.userStones.toDouble();
    final whiteValue = isFinal
        ? score.agentTotal
        : score.agentStones.toDouble();
    final total = math.max(1.0, blackValue + whiteValue);
    final blackShare = blackValue + whiteValue == 0
        ? 0.5
        : (blackValue / total).clamp(0.08, 0.92);
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.text.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isFinal ? '最终数目' : '盘面棋子',
                      style: TextStyle(
                        color: AppColors.text.withValues(alpha: 0.58),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_goScoreLabel(blackValue)} : ${_goScoreLabel(whiteValue)}',
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
                    height: 7,
                    child: Row(
                      children: [
                        Expanded(
                          flex: (blackShare * 1000).round(),
                          child: const ColoredBox(color: Color(0xFF17202A)),
                        ),
                        Expanded(
                          flex: ((1 - blackShare) * 1000).round(),
                          child: const ColoredBox(color: Color(0xFFF7F6F0)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isFinal
                      ? _goResultText(engine, agentName)
                      : '白棋含 6.5 目贴目 · 连续两次停着后数目',
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
          ),
          const SizedBox(width: 10),
          Tooltip(
            message: '停一手',
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(52, 52),
              onPressed: passEnabled ? onPass : null,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: passEnabled
                      ? const Color(0xFF1C6B5A)
                      : AppColors.text.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: passEnabled
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFF1C6B5A,
                            ).withValues(alpha: 0.22),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  Icons.front_hand_rounded,
                  color: passEnabled
                      ? Colors.white
                      : AppColors.text.withValues(alpha: 0.28),
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoBoard extends StatefulWidget {
  const _GoBoard({
    required this.engine,
    required this.lastMove,
    required this.thinking,
    required this.enabled,
    required this.onTap,
  });

  final GoEngine engine;
  final GoMove? lastMove;
  final bool thinking;
  final bool enabled;
  final ValueChanged<int> onTap;

  @override
  State<_GoBoard> createState() => _GoBoardState();
}

class _GoBoardState extends State<_GoBoard> with TickerProviderStateMixin {
  late final AnimationController _moveController;
  late final AnimationController _ambientController;

  @override
  void initState() {
    super.initState();
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
      value: 1,
    );
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _GoBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lastMove?.number != widget.lastMove?.number) {
      _moveController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _moveController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  void _handleTap(TapUpDetails details, Size size) {
    if (!widget.enabled) return;
    final geometry = _GoBoardGeometry(size);
    final index = geometry.indexAt(details.localPosition);
    if (index != null) widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        final size = Size.square(side);
        final legalMoves = widget.enabled
            ? widget.engine.legalMoves().toSet()
            : const <int>{};
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => _handleTap(details, size),
          child: AnimatedBuilder(
            animation: Listenable.merge([_moveController, _ambientController]),
            builder: (context, _) => CustomPaint(
              size: size,
              painter: _GoBoardPainter(
                board: widget.engine.board,
                legalMoves: legalMoves,
                lastMove: widget.lastMove,
                moveProgress: Curves.easeOutCubic.transform(
                  _moveController.value,
                ),
                ambientProgress: _ambientController.value,
                thinking: widget.thinking,
                darkMode: AppColors.isDark(context),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _GoBoardGeometry {
  const _GoBoardGeometry(this.size);

  final Size size;

  double get inset => size.width * 0.09;
  double get step => (size.width - inset * 2) / (GoEngine.boardSize - 1);

  Offset point(int index) => Offset(
    inset + (index % GoEngine.boardSize) * step,
    inset + (index ~/ GoEngine.boardSize) * step,
  );

  int? indexAt(Offset position) {
    final col = ((position.dx - inset) / step).round();
    final row = ((position.dy - inset) / step).round();
    if (row < 0 ||
        row >= GoEngine.boardSize ||
        col < 0 ||
        col >= GoEngine.boardSize) {
      return null;
    }
    final index = row * GoEngine.boardSize + col;
    return (point(index) - position).distance <= step * 0.48 ? index : null;
  }
}

class _GoBoardPainter extends CustomPainter {
  const _GoBoardPainter({
    required this.board,
    required this.legalMoves,
    required this.lastMove,
    required this.moveProgress,
    required this.ambientProgress,
    required this.thinking,
    required this.darkMode,
  });

  final List<int> board;
  final Set<int> legalMoves;
  final GoMove? lastMove;
  final double moveProgress;
  final double ambientProgress;
  final bool thinking;
  final bool darkMode;

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _GoBoardGeometry(size);
    final boardRect = Offset.zero & size;
    final radius = Radius.circular(size.width * 0.045);
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, radius),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD9A85D), Color(0xFFC9873F), Color(0xFFE1B66C)],
          stops: [0, 0.56, 1],
        ).createShader(boardRect),
    );
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(boardRect, radius));
    final grainPaint = Paint()
      ..color = const Color(0xFF6C3A1D).withValues(alpha: 0.08)
      ..strokeWidth = 0.7;
    for (var i = 0; i < 13; i += 1) {
      final y = size.height * (i + 0.7) / 13;
      final wave = math.sin(i * 1.71) * size.width * 0.018;
      final path = Path()
        ..moveTo(-10, y)
        ..cubicTo(
          size.width * 0.28,
          y + wave,
          size.width * 0.66,
          y - wave,
          size.width + 10,
          y + wave * 0.3,
        );
      canvas.drawPath(path, grainPaint);
    }
    canvas.restore();

    final gridPaint = Paint()
      ..color = const Color(0xFF3B2416).withValues(alpha: 0.78)
      ..strokeWidth = math.max(0.8, size.width / 420);
    for (var line = 0; line < GoEngine.boardSize; line += 1) {
      final a = geometry.point(line);
      final b = geometry.point(
        (GoEngine.boardSize - 1) * GoEngine.boardSize + line,
      );
      canvas.drawLine(a, b, gridPaint);
      final c = geometry.point(line * GoEngine.boardSize);
      final d = geometry.point(
        line * GoEngine.boardSize + GoEngine.boardSize - 1,
      );
      canvas.drawLine(c, d, gridPaint);
    }
    final starPaint = Paint()..color = const Color(0xFF322014);
    for (final point in const [20, 24, 40, 56, 60]) {
      canvas.drawCircle(
        geometry.point(point),
        geometry.step * 0.075,
        starPaint,
      );
    }

    if (thinking) {
      final sweep = (ambientProgress * 1.4 - 0.2) * size.width;
      final rect = Rect.fromCenter(
        center: Offset(sweep, size.height / 2),
        width: size.width * 0.34,
        height: size.height * 1.4,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              Colors.white.withValues(alpha: darkMode ? 0.035 : 0.09),
              Colors.transparent,
            ],
          ).createShader(rect),
      );
    }

    final lastIndex = lastMove?.index;
    for (var index = 0; index < board.length; index += 1) {
      final stone = board[index];
      if (stone == 0) continue;
      final isLast = lastIndex == index;
      final scale = isLast
          ? 0.12 + Curves.easeOutBack.transform(moveProgress) * 0.88
          : 1.0;
      _paintGoStone(
        canvas,
        geometry.point(index),
        geometry.step * 0.43 * scale,
        black: stone == 1,
        last: isLast,
      );
    }

    final captured = lastMove?.captured ?? const <int>[];
    if (captured.isNotEmpty && moveProgress < 1) {
      for (var i = 0; i < captured.length; i += 1) {
        final center = geometry.point(captured[i]);
        final angle = (i * 2.4 + 0.8) * math.pi;
        final distance = geometry.step * (0.18 + moveProgress * 0.62);
        final particle =
            center + Offset(math.cos(angle), math.sin(angle)) * distance;
        canvas.drawCircle(
          particle,
          geometry.step * 0.08 * (1 - moveProgress),
          Paint()..color = Colors.white.withValues(alpha: 1 - moveProgress),
        );
      }
    }

    if (legalMoves.isNotEmpty) {
      final pulse = 0.45 + ambientProgress * 0.3;
      final hintPaint = Paint()
        ..color = const Color(0xFF0D5F4E).withValues(alpha: pulse * 0.22);
      for (final index in legalMoves) {
        canvas.drawCircle(
          geometry.point(index),
          geometry.step * 0.075,
          hintPaint,
        );
      }
    }

    _paintGoCoordinates(canvas, geometry, size);
  }

  void _paintGoStone(
    Canvas canvas,
    Offset center,
    double radius, {
    required bool black,
    required bool last,
  }) {
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(0, radius * 0.18),
        width: radius * 1.75,
        height: radius * 1.18,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.27),
    );
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.42, -0.5),
          radius: 1.12,
          colors: black
              ? const [Color(0xFF545B60), Color(0xFF171B1E), Color(0xFF050607)]
              : const [Color(0xFFFFFFFF), Color(0xFFF1EEE7), Color(0xFFC8C3BA)],
          stops: const [0, 0.58, 1],
        ).createShader(rect),
    );
    canvas.drawCircle(
      center - Offset(radius * 0.26, radius * 0.31),
      radius * 0.19,
      Paint()..color = Colors.white.withValues(alpha: black ? 0.2 : 0.62),
    );
    if (last) {
      canvas.drawCircle(
        center,
        radius * 0.22,
        Paint()
          ..color = black ? const Color(0xFFE5B85C) : const Color(0xFF267160)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.4, radius * 0.12),
      );
    }
  }

  void _paintGoCoordinates(
    Canvas canvas,
    _GoBoardGeometry geometry,
    Size size,
  ) {
    final style = TextStyle(
      color: const Color(0xFF382416).withValues(alpha: 0.64),
      fontSize: math.max(7, size.width * 0.023),
      fontWeight: FontWeight.w800,
    );
    for (var i = 0; i < GoEngine.boardSize; i += 1) {
      final column = TextPainter(
        text: TextSpan(text: _goDisplayColumns[i], style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      column.paint(
        canvas,
        Offset(
          geometry.point(i).dx - column.width / 2,
          size.height - geometry.inset * 0.56,
        ),
      );
      final row = TextPainter(
        text: TextSpan(text: '${GoEngine.boardSize - i}', style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      row.paint(
        canvas,
        Offset(
          geometry.inset * 0.31 - row.width / 2,
          geometry.point(i * 9).dy - row.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GoBoardPainter oldDelegate) => true;
}

const _goDisplayColumns = 'ABCDEFGHJ';
