part of 'package:companion_flutter/main.dart';

class _NumberMergeGamePage extends StatefulWidget {
  const _NumberMergeGamePage({
    required this.api,
    required this.authSession,
    required this.game,
  });

  final CompanionApi api;
  final AuthSession authSession;
  final _GameTile game;

  @override
  State<_NumberMergeGamePage> createState() => _NumberMergeGamePageState();
}

class _NumberMergeGamePageState extends State<_NumberMergeGamePage> {
  late final _NativeGameRuntime _runtime;
  NumberMergeEngine? _engine;
  NumberMergeMove? _lastMove;
  final List<Map<String, dynamic>> _actionHistory = [];
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _runtime = _NativeGameRuntime(
      api: widget.api,
      authSession: widget.authSession,
      gameKey: _nativeNumberMergeGameKey,
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
      _lastMove = null;
      _actionHistory.clear();
      _resolving = false;
    });
  }

  Future<void> _start() async {
    if (_runtime.session != null && !_runtime.completed) {
      await _runtime.abort('restarted', _sessionSummary());
    }
    NumberMergeEngine? candidate;
    final session = await _runtime.start(
      {
        'board_size': 4,
        'first_actor': 'user',
        'mode': 'cooperative',
        'rules': 'single_merge_per_move_spawn_2_or_4',
        'spawn_probability': {'2': 0.9, '4': 0.1},
        'solver': 'expectimax_chance_nodes_monotonicity_smoothness_mobility',
      },
      payloadBuilder: (created) {
        final config = NumberMergeGameConfig.fromJson(created.engineConfig);
        candidate = NumberMergeEngine(
          seed: created.id.hashCode,
          target: config.target,
          searchDepthOffset: config.searchDepthOffset,
          nearBestProbability: config.nearBestProbability,
          nearBestToleranceRatio: config.nearBestToleranceRatio,
        );
        return {
          'board_size': 4,
          'target': config.target,
          'first_actor': 'user',
          'mode': 'cooperative',
          'rules': 'single_merge_per_move_spawn_2_or_4',
          'spawn_probability': {'2': 0.9, '4': 0.1},
          'solver': 'expectimax_chance_nodes_monotonicity_smoothness_mobility',
          'initial_state': candidate!.stateJson(),
        };
      },
    );
    if (session != null && mounted) {
      final config = NumberMergeGameConfig.fromJson(session.engineConfig);
      setState(() {
        _engine =
            candidate ??
            NumberMergeEngine(
              seed: session.id.hashCode,
              target: config.target,
              searchDepthOffset: config.searchDepthOffset,
              nearBestProbability: config.nearBestProbability,
              nearBestToleranceRatio: config.nearBestToleranceRatio,
            );
        _lastMove = null;
        _actionHistory.clear();
        _resolving = false;
      });
    }
  }

  Future<void> _userMove(NumberMergeDirection direction) async {
    final engine = _engine;
    if (engine == null ||
        engine.isFinished ||
        engine.turn != NumberMergeActor.user ||
        _runtime.aiThinking ||
        _resolving ||
        !engine.canMove(direction)) {
      if (engine != null && !engine.isFinished) {
        _NativeGameHaptics.rejected();
      }
      return;
    }
    await _applyAndReport(direction);
    if (!engine.isFinished && engine.turn == NumberMergeActor.agent) {
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
          'move_number': engine.moveCount + 1,
          'analysis': engine.analysisJson(),
        },
      );
      final decision = await engine.chooseAiMove();
      if (!mounted ||
          engine.isFinished ||
          engine.turn != NumberMergeActor.agent) {
        return;
      }
      await _runtime.reportEvent('ai_move_decided', payload: decision.toJson());
      await Future<void>.delayed(const Duration(milliseconds: 330));
      if (!mounted ||
          engine.isFinished ||
          engine.turn != NumberMergeActor.agent) {
        return;
      }
      await _applyAndReport(decision.direction, decision: decision);
    } finally {
      if (mounted) setState(() => _runtime.aiThinking = false);
    }
  }

  Future<void> _applyAndReport(
    NumberMergeDirection direction, {
    NumberMergeAiDecision? decision,
  }) async {
    final engine = _engine!;
    final before = engine.stateJson();
    final result = engine.move(direction, decision: decision);
    if (mounted) {
      setState(() {
        _lastMove = result.move;
        _resolving = true;
      });
    }
    _NativeGameHaptics.merge(result.move.mergedValues);
    final duration = result.move.mergedValues.any((value) => value >= 128)
        ? const Duration(milliseconds: 820)
        : const Duration(milliseconds: 620);
    try {
      await Future.wait([
        _reportMove(result.move, before),
        Future<void>.delayed(duration),
      ]);
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
    if (result.status != NumberMergeStatus.playing) {
      await _finish(result.status);
    }
  }

  Future<void> _reportMove(
    NumberMergeMove move,
    Map<String, dynamic> before,
  ) async {
    final engine = _engine!;
    final canonicalAction = <String, dynamic>{
      ...move.toJson(),
      'action_id': '${_runtime.session?.id}:${move.number}',
      'state_before': before,
      'state_after': engine.stateJson(),
      'analysis': engine.analysisJson(),
    };
    _actionHistory.add(canonicalAction);
    await _runtime.reportEvent(
      'board_slid',
      state: 'playing',
      payload: canonicalAction,
    );
    if (move.mergedValues.isNotEmpty) {
      await _runtime.reportEvent(
        'tiles_merged',
        payload: {
          'move_number': move.number,
          'actor': move.actor.name,
          'direction': move.direction.name,
          'values': move.mergedValues,
          'score_gained': move.scoreGained,
          'transitions': move.transitions
              .where((transition) => transition.merged)
              .map((transition) => transition.toJson())
              .toList(),
        },
      );
    }
    await _runtime.reportEvent(
      'tile_spawned',
      payload: {
        'move_number': move.number,
        'actor': move.actor.name,
        ...move.spawn.toJson(),
      },
    );
    for (final moment in move.moments) {
      await _runtime.reportEvent(
        'key_moment',
        payload: {
          ...moment.toJson(),
          'action_number': move.number,
          'actor': move.actor.name,
        },
      );
    }
  }

  Future<void> _finish(NumberMergeStatus status) async {
    final engine = _engine!;
    await _runtime.finish({
      ..._sessionSummary(),
      'user_outcome': status == NumberMergeStatus.completed ? 'win' : 'lose',
      'shared_outcome': status == NumberMergeStatus.completed
          ? 'target_reached'
          : 'no_legal_moves',
      'terminal_state': {'status': status.name},
      'state_after_hash': engine.stateHash.toString(),
    });
  }

  Map<String, dynamic> _sessionSummary() => {
    ...?_engine?.summaryJson(),
    'actions': List<Map<String, dynamic>>.of(_actionHistory),
  };

  @override
  Widget build(BuildContext context) {
    final engine = _engine;
    return _NativeGameExperienceScaffold(
      runtime: _runtime,
      game: widget.game,
      subtitle: engine == null
          ? '和 ${_runtime.agentName} 轮流滑动，慢慢合到 2048'
          : engine.status == NumberMergeStatus.completed
          ? '你们一起合出了 ${engine.maxTile}'
          : engine.status == NumberMergeStatus.failed
          ? '盘面装满了，这局已经完整保存'
          : _runtime.aiThinking
          ? '${_runtime.agentName} 正在计算出生概率'
          : _resolving
          ? '数字正在靠拢'
          : engine.turn == NumberMergeActor.user
          ? '轮到你选择滑动方向'
          : '轮到 ${_runtime.agentName} 接着合',
      onStart: _start,
      onActiveRoundDeleted: _clearActiveRound,
      restartDisabled: _runtime.aiThinking || _resolving,
      historySubtitle: '每次滑动、方块轨迹、合并得分、出生位置和搜索判断都会保存。',
      userTurnActive:
          engine != null &&
          !engine.isFinished &&
          engine.turn == NumberMergeActor.user &&
          !_runtime.aiThinking &&
          !_resolving,
      turnToken: engine == null
          ? 'idle'
          : '${engine.moveCount}:${engine.turn.name}',
      turnLabel: _runtime.aiThinking
          ? '${_runtime.agentName} 在合并'
          : _resolving
          ? '数字移动中'
          : '轮到你滑动',
      moveCount: engine?.moveCount ?? 0,
      currentSummary: _sessionSummary,
      activeChild: engine == null
          ? null
          : Column(
              children: [
                _NativeScoreHeader(
                  // 合作模式：左右是双方贡献分，中间是共同总分。
                  left: '你 ${engine.userScore}',
                  center: '共同 ${engine.score}',
                  right: '${_runtime.agentName} ${engine.agentScore}',
                ),
                const SizedBox(height: 10),
                AspectRatio(
                  aspectRatio: 1,
                  child: _NumberMergeBoard(
                    engine: engine,
                    lastMove: _lastMove,
                    thinking: _runtime.aiThinking,
                    enabled:
                        engine.turn == NumberMergeActor.user &&
                        !_runtime.aiThinking &&
                        !_resolving &&
                        !engine.isFinished,
                    onMove: _userMove,
                  ),
                ),
                const SizedBox(height: 11),
                _NumberMergePositionStrip(
                  engine: engine,
                  enabled:
                      engine.turn == NumberMergeActor.user &&
                      !_runtime.aiThinking &&
                      !_resolving &&
                      !engine.isFinished,
                  onMove: _userMove,
                ),
              ],
            ),
    );
  }
}

class _NumberMergePositionStrip extends StatelessWidget {
  const _NumberMergePositionStrip({
    required this.engine,
    required this.enabled,
    required this.onMove,
  });

  final NumberMergeEngine engine;
  final bool enabled;
  final ValueChanged<NumberMergeDirection> onMove;

  @override
  Widget build(BuildContext context) {
    final maxExponent = math.max(1, math.log(engine.target) ~/ math.ln2);
    final currentExponent = math.log(math.max(2, engine.maxTile)) / math.ln2;
    final progress = (currentExponent / maxExponent).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.text.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '最大 ${engine.maxTile}',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '${engine.totalMerges} 次合并 · ${engine.emptyCount} 个空位',
                style: TextStyle(
                  color: AppColors.text.withValues(alpha: 0.48),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 7,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFF173B4A).withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF0C9E9A)),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _NumberMergeDirectionButton(
                icon: CupertinoIcons.arrow_up,
                enabled: enabled && engine.canMove(NumberMergeDirection.up),
                onPressed: () => onMove(NumberMergeDirection.up),
              ),
              const SizedBox(width: 7),
              _NumberMergeDirectionButton(
                icon: CupertinoIcons.arrow_left,
                enabled: enabled && engine.canMove(NumberMergeDirection.left),
                onPressed: () => onMove(NumberMergeDirection.left),
              ),
              const SizedBox(width: 7),
              _NumberMergeDirectionButton(
                icon: CupertinoIcons.arrow_down,
                enabled: enabled && engine.canMove(NumberMergeDirection.down),
                onPressed: () => onMove(NumberMergeDirection.down),
              ),
              const SizedBox(width: 7),
              _NumberMergeDirectionButton(
                icon: CupertinoIcons.arrow_right,
                enabled: enabled && engine.canMove(NumberMergeDirection.right),
                onPressed: () => onMove(NumberMergeDirection.right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumberMergeDirectionButton extends StatelessWidget {
  const _NumberMergeDirectionButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    minimumSize: const Size(42, 38),
    onPressed: enabled ? onPressed : null,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 42,
      height: 38,
      decoration: BoxDecoration(
        color: enabled
            ? const Color(0xFF0C6371).withValues(alpha: 0.13)
            : AppColors.text.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: enabled
              ? const Color(0xFF0C6371).withValues(alpha: 0.2)
              : Colors.transparent,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: 18,
        color: enabled
            ? const Color(0xFF0C6371)
            : AppColors.text.withValues(alpha: 0.18),
      ),
    ),
  );
}

class _NumberMergeBoard extends StatefulWidget {
  const _NumberMergeBoard({
    required this.engine,
    required this.lastMove,
    required this.thinking,
    required this.enabled,
    required this.onMove,
  });

  final NumberMergeEngine engine;
  final NumberMergeMove? lastMove;
  final bool thinking;
  final bool enabled;
  final ValueChanged<NumberMergeDirection> onMove;

  @override
  State<_NumberMergeBoard> createState() => _NumberMergeBoardState();
}

class _NumberMergeBoardState extends State<_NumberMergeBoard>
    with TickerProviderStateMixin {
  late final AnimationController _moveController;
  Offset _drag = Offset.zero;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant _NumberMergeBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lastMove?.number != widget.lastMove?.number &&
        widget.lastMove != null) {
      _moveController.duration =
          widget.lastMove!.mergedValues.any((value) => value >= 128)
          ? const Duration(milliseconds: 820)
          : const Duration(milliseconds: 620);
      _moveController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _moveController.dispose();
    super.dispose();
  }

  void _handleDrag(DragUpdateDetails details) {
    if (!widget.enabled || _handled) return;
    _drag += details.delta;
    if (_drag.distance < 24) return;
    _handled = true;
    if (_drag.dx.abs() > _drag.dy.abs()) {
      widget.onMove(
        _drag.dx > 0 ? NumberMergeDirection.right : NumberMergeDirection.left,
      );
    } else {
      widget.onMove(
        _drag.dy > 0 ? NumberMergeDirection.down : NumberMergeDirection.up,
      );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _moveController,
    builder: (context, _) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: widget.enabled
          ? (_) {
              _drag = Offset.zero;
              _handled = false;
            }
          : null,
      onPanUpdate: widget.enabled ? _handleDrag : null,
      onPanEnd: (_) {
        _drag = Offset.zero;
        _handled = false;
      },
      child: CustomPaint(
        painter: _NumberMergeBoardPainter(
          engine: widget.engine,
          lastMove: widget.lastMove,
          moveProgress: Curves.easeOutCubic.transform(_moveController.value),
          thinking: widget.thinking,
        ),
      ),
    ),
  );
}

class _NumberMergeBoardPainter extends CustomPainter {
  const _NumberMergeBoardPainter({
    required this.engine,
    required this.lastMove,
    required this.moveProgress,
    required this.thinking,
  });

  final NumberMergeEngine engine;
  final NumberMergeMove? lastMove;
  final double moveProgress;
  final bool thinking;

  @override
  void paint(Canvas canvas, Size size) {
    const outerInset = 7.0;
    final side = math.min(size.width, size.height) - outerInset * 2;
    final boardRect = Rect.fromLTWH(
      (size.width - side) / 2,
      (size.height - side) / 2,
      side,
      side,
    );
    final outer = RRect.fromRectAndRadius(boardRect, const Radius.circular(26));
    canvas.drawShadow(Path()..addRRect(outer), Colors.black, 16, true);
    canvas.drawRRect(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF183744), Color(0xFF0B1926)],
        ).createShader(boardRect),
    );
    final inner = boardRect.deflate(11);
    final gap = inner.width * 0.025;
    final tileSize = (inner.width - gap * 3) / 4;
    for (var index = 0; index < 16; index += 1) {
      final rect = _rectFor(index, inner, tileSize, gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(tileSize * 0.17)),
        Paint()..color = const Color(0xFF081721).withValues(alpha: 0.72),
      );
    }

    final move = lastMove;
    if (move != null && moveProgress < 0.7) {
      final slideProgress = Curves.easeInOutCubic.transform(
        (moveProgress / 0.7).clamp(0.0, 1.0),
      );
      for (final transition in move.transitions) {
        final from = _rectFor(transition.from.index, inner, tileSize, gap);
        final to = _rectFor(transition.to.index, inner, tileSize, gap);
        final center = Offset.lerp(from.center, to.center, slideProgress)!;
        _paintTile(
          canvas,
          Rect.fromCenter(center: center, width: tileSize, height: tileSize),
          transition.value,
          scale: 1,
        );
      }
    } else {
      final settleProgress = move == null
          ? 1.0
          : ((moveProgress - 0.7) / 0.3).clamp(0.0, 1.0);
      final mergeTargets = <int>{
        if (move != null)
          for (final transition in move.transitions)
            if (transition.merged) transition.to.index,
      };
      for (var index = 0; index < engine.board.length; index += 1) {
        final value = engine.valueAt(index);
        if (value == 0) continue;
        var scale = 1.0;
        if (move?.spawn.point.index == index) {
          scale = Curves.elasticOut.transform(settleProgress);
        } else if (mergeTargets.contains(index)) {
          scale = 1 + math.sin(settleProgress * math.pi) * 0.13;
        }
        _paintTile(
          canvas,
          _rectFor(index, inner, tileSize, gap),
          value,
          scale: scale,
        );
      }
      if (move != null && move.mergedValues.isNotEmpty) {
        final alpha = (1 - settleProgress).clamp(0.0, 1.0);
        for (final target in mergeTargets) {
          final center = _rectFor(target, inner, tileSize, gap).center;
          canvas.drawCircle(
            center,
            tileSize * (0.38 + settleProgress * 0.55),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5 * alpha
              ..color = const Color(0xFFFFCE73).withValues(alpha: alpha * 0.8),
          );
        }
      }
    }
  }

  Rect _rectFor(int index, Rect inner, double tileSize, double gap) {
    final row = index ~/ 4;
    final column = index % 4;
    return Rect.fromLTWH(
      inner.left + column * (tileSize + gap),
      inner.top + row * (tileSize + gap),
      tileSize,
      tileSize,
    );
  }

  void _paintTile(
    Canvas canvas,
    Rect rect,
    int value, {
    required double scale,
  }) {
    if (scale <= 0.01) return;
    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.scale(scale, scale);
    canvas.translate(-rect.center.dx, -rect.center.dy);
    final rounded = RRect.fromRectAndRadius(
      rect.deflate(1.2),
      Radius.circular(rect.width * 0.17),
    );
    canvas.drawShadow(Path()..addRRect(rounded), Colors.black, 5, true);
    final colors = _numberMergeColors(value);
    canvas.drawRRect(
      rounded,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ).createShader(rect),
    );
    canvas.drawRRect(
      rounded.deflate(2.3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.22),
    );
    final digits = '$value'.length;
    final fontSize =
        rect.width *
        (digits <= 2
            ? 0.36
            : digits == 3
            ? 0.3
            : 0.24);
    final painter = TextPainter(
      text: TextSpan(
        text: '$value',
        style: TextStyle(
          color: value <= 4 ? const Color(0xFF263640) : Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          shadows: value <= 4
              ? null
              : const [
                  Shadow(
                    color: Colors.black26,
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: rect.width * 0.9);
    painter.paint(
      canvas,
      rect.center - Offset(painter.width / 2, painter.height / 2),
    );
    canvas.drawCircle(
      Offset(rect.left + rect.width * 0.23, rect.top + rect.height * 0.19),
      rect.width * 0.035,
      Paint()..color = Colors.white.withValues(alpha: 0.3),
    );
    canvas.restore();
  }

  List<Color> _numberMergeColors(int value) => switch (value) {
    2 => const [Color(0xFFF3F0E7), Color(0xFFDDE6E2)],
    4 => const [Color(0xFFE9E3D4), Color(0xFFD6C7AE)],
    8 => const [Color(0xFF64C6A8), Color(0xFF278D78)],
    16 => const [Color(0xFFFF8B73), Color(0xFFD94F52)],
    32 => const [Color(0xFFFFC35D), Color(0xFFE07B2D)],
    64 => const [Color(0xFF4AA8E8), Color(0xFF2469B5)],
    128 => const [Color(0xFF8A77E8), Color(0xFF5644B7)],
    256 => const [Color(0xFFE76AA9), Color(0xFFA93579)],
    512 => const [Color(0xFF24B8B3), Color(0xFF08717D)],
    1024 => const [Color(0xFFE0A93A), Color(0xFFAA6720)],
    _ => const [Color(0xFFFFD76A), Color(0xFFE95D48)],
  };

  @override
  bool shouldRepaint(covariant _NumberMergeBoardPainter oldDelegate) =>
      oldDelegate.engine.stateHash != engine.stateHash ||
      oldDelegate.lastMove?.number != lastMove?.number ||
      oldDelegate.moveProgress != moveProgress ||
      oldDelegate.thinking != thinking;
}
