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

  @override
  void initState() {
    super.initState();
    _runtime = _NativeGameRuntime(
      api: widget.api,
      authSession: widget.authSession,
      gameKey: _nativeMinesweeperGameKey,
      gameTitle: widget.game.title,
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
    unawaited(_runtime.initialize());
  }

  @override
  void dispose() {
    if (_runtime.session != null && !_runtime.completed) {
      unawaited(
        _runtime.abort('page_closed', _sessionSummary(), updateUi: false),
      );
    }
    super.dispose();
  }

  Future<void> _start() async {
    if (_runtime.session != null && !_runtime.completed) {
      await _runtime.abort('restarted', _sessionSummary());
    }
    final session = await _runtime.start({
      'board_size': {'rows': 9, 'columns': 9},
      'mine_count': 12,
      'first_actor': 'user',
      'mode': 'cooperative',
      'rules': 'first_move_safe_bounded_no_guess_board_generation',
      'solver': 'constraint_propagation_subset_bounded_component_probability',
    });
    if (session != null && mounted) {
      setState(() {
        _engine = MinesweeperEngine(
          seed: DateTime.now().microsecondsSinceEpoch & 0x7fffffff,
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
          'action_number': engine.actions.length + 1,
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
    if (result.action.hitMine) {
      unawaited(HapticFeedback.heavyImpact());
    } else if (result.action.revealed.length >= 8) {
      unawaited(HapticFeedback.mediumImpact());
    } else {
      unawaited(HapticFeedback.selectionClick());
    }
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
      'state_after': engine.stateJson(),
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

  @override
  Widget build(BuildContext context) {
    final engine = _engine;
    return _NativeGameExperienceScaffold(
      runtime: _runtime,
      game: widget.game,
      subtitle: engine == null
          ? '和 ${_runtime.agentName} 一起推理，清掉每一格'
          : engine.status == MinesweeperStatus.completed
          ? '你们把雷区完整清掉了'
          : engine.status == MinesweeperStatus.failed
          ? '踩到了一颗雷，这局先收到共同记忆里'
          : _runtime.aiThinking
          ? '${_runtime.agentName} 正在核对数字约束'
          : _resolving
          ? '线索正在展开'
          : engine.turn == MinesweeperActor.user
          ? '轮到你，点开或标记一格'
          : '轮到 ${_runtime.agentName} 推理',
      onStart: _start,
      restartDisabled: _runtime.aiThinking || _resolving,
      historySubtitle: '每次揭格、标雷、约束推理、冒险判断和最终雷盘都会保存。',
      activeChild: engine == null
          ? null
          : Column(
              children: [
                _NativeScoreHeader(
                  left: '已清 ${engine.revealedCount}/${engine.safeCellCount}',
                  center: '${engine.actions.length} 步',
                  right: '旗 ${engine.flagCount}/${engine.mineCount}',
                ),
                const SizedBox(height: 10),
                AspectRatio(
                  aspectRatio: 1,
                  child: _MinesweeperBoard(
                    engine: engine,
                    lastAction: _lastAction,
                    thinking: _runtime.aiThinking,
                    enabled:
                        engine.turn == MinesweeperActor.user &&
                        !_runtime.aiThinking &&
                        !_resolving &&
                        !engine.isFinished,
                    onReveal: (index) => _userAct(index),
                    onFlag: (index) => _userAct(index, forceFlag: true),
                  ),
                ),
                const SizedBox(height: 11),
                _MinesweeperControlStrip(
                  engine: engine,
                  tool: _tool,
                  agentName: _runtime.agentName,
                  onToolChanged: (tool) => setState(() => _tool = tool),
                ),
              ],
            ),
    );
  }
}

class _MinesweeperControlStrip extends StatelessWidget {
  const _MinesweeperControlStrip({
    required this.engine,
    required this.tool,
    required this.agentName,
    required this.onToolChanged,
  });

  final MinesweeperEngine engine;
  final _MinesweeperTool tool;
  final String agentName;
  final ValueChanged<_MinesweeperTool> onToolChanged;

  @override
  Widget build(BuildContext context) {
    final analysis = engine.analysisJson();
    final forcedSafe = analysis['forced_safe_count'] as int;
    final forcedMines = analysis['forced_mine_count'] as int;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.text.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          if (!engine.isFinished)
            SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<_MinesweeperTool>(
                groupValue: tool,
                backgroundColor: const Color(
                  0xFF0A3041,
                ).withValues(alpha: 0.08),
                thumbColor: const Color(0xFF0C6371),
                padding: const EdgeInsets.all(3),
                onValueChanged: (value) {
                  if (value != null) onToolChanged(value);
                },
                children: {
                  _MinesweeperTool.reveal: _MinesweeperToolLabel(
                    icon: CupertinoIcons.sparkles,
                    label: '揭示',
                    selected: tool == _MinesweeperTool.reveal,
                  ),
                  _MinesweeperTool.flag: _MinesweeperToolLabel(
                    icon: CupertinoIcons.flag_fill,
                    label: '标记',
                    selected: tool == _MinesweeperTool.flag,
                  ),
                },
              ),
            ),
          if (!engine.isFinished) const SizedBox(height: 9),
          Row(
            children: [
              _MinesweeperInfoChip(
                icon: CupertinoIcons.shield_lefthalf_fill,
                text: '连安全 ${engine.safeStreak}',
              ),
              const SizedBox(width: 7),
              _MinesweeperInfoChip(
                icon: CupertinoIcons.lightbulb_fill,
                text: forcedSafe + forcedMines > 0
                    ? '确定线索 ${forcedSafe + forcedMines}'
                    : '继续找线索',
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  engine.isFinished
                      ? engine.status == MinesweeperStatus.completed
                            ? '共同清场成功'
                            : '和 $agentName 一起复盘'
                      : '剩余约 ${engine.estimatedMinesRemaining} 雷',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text.withValues(alpha: 0.46),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MinesweeperToolLabel extends StatelessWidget {
  const _MinesweeperToolLabel({
    required this.icon,
    required this.label,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 15,
          color: selected ? Colors.white : const Color(0xFF0C6371),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF0C6371),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _MinesweeperInfoChip extends StatelessWidget {
  const _MinesweeperInfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFE2A34A).withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: const Color(0xFFB87825)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF9C671F),
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _MinesweeperBoard extends StatefulWidget {
  const _MinesweeperBoard({
    required this.engine,
    required this.lastAction,
    required this.thinking,
    required this.enabled,
    required this.onReveal,
    required this.onFlag,
  });

  final MinesweeperEngine engine;
  final MinesweeperAction? lastAction;
  final bool thinking;
  final bool enabled;
  final ValueChanged<int> onReveal;
  final ValueChanged<int> onFlag;

  @override
  State<_MinesweeperBoard> createState() => _MinesweeperBoardState();
}

class _MinesweeperBoardState extends State<_MinesweeperBoard>
    with TickerProviderStateMixin {
  late final AnimationController _actionController;
  late final AnimationController _ambientController;
  int? _pressedIndex;

  @override
  void initState() {
    super.initState();
    _actionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
      value: 1,
    );
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _MinesweeperBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lastAction?.number != widget.lastAction?.number &&
        widget.lastAction != null) {
      _actionController.duration = widget.lastAction!.hitMine
          ? const Duration(milliseconds: 980)
          : widget.lastAction!.revealed.length >= 8
          ? const Duration(milliseconds: 820)
          : const Duration(milliseconds: 560);
      _actionController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _actionController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  int? _indexAt(Offset localPosition, Size size) {
    const inset = 12.0;
    final boardSide = math.min(size.width, size.height) - inset * 2;
    final origin = Offset(
      (size.width - boardSide) / 2,
      (size.height - boardSide) / 2,
    );
    final local = localPosition - origin;
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx >= boardSide ||
        local.dy >= boardSide) {
      return null;
    }
    final cell = boardSide / widget.engine.columns;
    final column = (local.dx / cell).floor();
    final row = (local.dy / cell).floor();
    return row * widget.engine.columns + column;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([_actionController, _ambientController]),
    builder: (context, _) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled
          ? (details) => setState(
              () => _pressedIndex = _indexAt(
                details.localPosition,
                context.size!,
              ),
            )
          : null,
      onTapCancel: () => setState(() => _pressedIndex = null),
      onTapUp: widget.enabled
          ? (details) {
              final index = _indexAt(details.localPosition, context.size!);
              setState(() => _pressedIndex = null);
              if (index != null) widget.onReveal(index);
            }
          : null,
      onLongPressStart: widget.enabled
          ? (details) {
              setState(() => _pressedIndex = null);
              final index = _indexAt(details.localPosition, context.size!);
              if (index != null) widget.onFlag(index);
            }
          : null,
      child: CustomPaint(
        painter: _MinesweeperBoardPainter(
          engine: widget.engine,
          lastAction: widget.lastAction,
          actionProgress: Curves.easeOutCubic.transform(
            _actionController.value,
          ),
          ambientProgress: _ambientController.value,
          thinking: widget.thinking,
          pressedIndex: _pressedIndex,
        ),
      ),
    ),
  );
}

class _MinesweeperBoardPainter extends CustomPainter {
  const _MinesweeperBoardPainter({
    required this.engine,
    required this.lastAction,
    required this.actionProgress,
    required this.ambientProgress,
    required this.thinking,
    required this.pressedIndex,
  });

  final MinesweeperEngine engine;
  final MinesweeperAction? lastAction;
  final double actionProgress;
  final double ambientProgress;
  final bool thinking;
  final int? pressedIndex;

  static const _numberColors = <int, Color>{
    1: Color(0xFF2D70A9),
    2: Color(0xFF268269),
    3: Color(0xFFC3574D),
    4: Color(0xFF6257A5),
    5: Color(0xFFA25D37),
    6: Color(0xFF148A8C),
    7: Color(0xFF2E3543),
    8: Color(0xFF7D8490),
  };

  @override
  void paint(Canvas canvas, Size size) {
    const outerInset = 7.0;
    final boardSide = math.min(size.width, size.height) - outerInset * 2;
    final boardRect = Rect.fromLTWH(
      (size.width - boardSide) / 2,
      (size.height - boardSide) / 2,
      boardSide,
      boardSide,
    );
    final outer = RRect.fromRectAndRadius(boardRect, const Radius.circular(25));
    canvas.drawShadow(Path()..addRRect(outer), Colors.black, 15, true);
    canvas.drawRRect(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF103F4A), Color(0xFF071E2D)],
        ).createShader(boardRect),
    );
    final inner = boardRect.deflate(8);
    final cellSize = inner.width / engine.columns;
    final revealOrder = <int, int>{};
    final revealed = lastAction?.revealed ?? const <MinePoint>[];
    for (var i = 0; i < revealed.length; i += 1) {
      revealOrder[revealed[i].index(engine.columns)] = i;
    }

    for (var index = 0; index < engine.cellCount; index += 1) {
      final row = index ~/ engine.columns;
      final column = index % engine.columns;
      final rect = Rect.fromLTWH(
        inner.left + column * cellSize + 1.35,
        inner.top + row * cellSize + 1.35,
        cellSize - 2.7,
        cellSize - 2.7,
      );
      final revealIndex = revealOrder[index];
      var localReveal = 1.0;
      if (revealIndex != null && revealed.isNotEmpty) {
        final delay = (revealIndex / math.max(1, revealed.length)) * 0.42;
        localReveal = ((actionProgress - delay) / (1 - delay)).clamp(0.0, 1.0);
      }
      _paintCell(canvas, rect, index, localReveal);
    }

    if (thinking && !engine.isFinished) {
      final y = inner.top + inner.height * ambientProgress;
      canvas.save();
      canvas.clipRRect(
        RRect.fromRectAndRadius(inner, const Radius.circular(18)),
      );
      canvas.drawRect(
        Rect.fromLTWH(inner.left, y - 18, inner.width, 36),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              const Color(0xFF75F0D1).withValues(alpha: 0.18),
              Colors.transparent,
            ],
          ).createShader(Rect.fromLTWH(inner.left, y - 18, inner.width, 36)),
      );
      canvas.restore();
    }

    final origin = lastAction?.point.index(engine.columns);
    if (origin != null && lastAction!.revealed.length >= 5) {
      final center = _cellCenter(inner, cellSize, origin);
      for (var i = 0; i < 8; i += 1) {
        final angle = i * math.pi / 4 + 0.3;
        final distance = 8 + 18 * actionProgress;
        final particle =
            center +
            Offset(math.cos(angle) * distance, math.sin(angle) * distance);
        canvas.drawCircle(
          particle,
          1.8 * (1 - actionProgress).clamp(0.2, 1.0),
          Paint()
            ..color = const Color(
              0xFFFFD47A,
            ).withValues(alpha: (1 - actionProgress) * 0.8),
        );
      }
    }
    if (lastAction?.hitMine == true && origin != null) {
      final center = _cellCenter(inner, cellSize, origin);
      canvas.drawCircle(
        center,
        cellSize * (0.5 + actionProgress * 1.8),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - actionProgress)
          ..color = const Color(
            0xFFFF754F,
          ).withValues(alpha: (1 - actionProgress) * 0.8),
      );
    }
  }

  Offset _cellCenter(Rect inner, double cellSize, int index) => Offset(
    inner.left + (index % engine.columns + 0.5) * cellSize,
    inner.top + (index ~/ engine.columns + 0.5) * cellSize,
  );

  void _paintCell(Canvas canvas, Rect rect, int index, double revealProgress) {
    final radius = Radius.circular(rect.width * 0.18);
    final rounded = RRect.fromRectAndRadius(rect, radius);
    final isRevealed = engine.isRevealed(index);
    final isFlagged = engine.isFlagged(index);
    final isMine = engine.isMine(index) || engine.explodedIndex == index;
    if (isRevealed || isMine) {
      canvas.drawRRect(
        rounded,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7F2E7), Color(0xFFD9E2DE)],
          ).createShader(rect),
      );
      canvas.drawRRect(
        rounded,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = const Color(0xFF0C3541).withValues(alpha: 0.14),
      );
      if (isMine) {
        _paintMine(
          canvas,
          rect.center,
          rect.width * 0.2,
          exploded: engine.explodedIndex == index,
        );
      } else {
        final number = engine.adjacentMineCount(index);
        if (number > 0) _paintNumber(canvas, rect, number);
      }
    }
    if (!isRevealed || revealProgress < 1) {
      final coverScale = isRevealed ? 1 - revealProgress : 1.0;
      if (coverScale > 0.02) {
        canvas.save();
        canvas.translate(rect.center.dx, rect.center.dy);
        final pressScale = pressedIndex == index ? 0.92 : 1.0;
        canvas.scale(coverScale * pressScale, coverScale * pressScale);
        canvas.translate(-rect.center.dx, -rect.center.dy);
        canvas.drawShadow(Path()..addRRect(rounded), Colors.black, 2.5, true);
        canvas.drawRRect(
          rounded,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF176474), Color(0xFF083344)],
            ).createShader(rect),
        );
        canvas.drawRRect(
          rounded.deflate(2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = const Color(0xFF7FD7D2).withValues(alpha: 0.16),
        );
        final glint = Offset(
          rect.left + rect.width * 0.28,
          rect.top + rect.height * 0.25,
        );
        canvas.drawCircle(
          glint,
          rect.width * 0.055,
          Paint()..color = Colors.white.withValues(alpha: 0.28),
        );
        canvas.restore();
      }
    }
    if (isFlagged && !isRevealed) {
      final isCurrent =
          lastAction?.point.index(engine.columns) == index &&
          lastAction?.kind == MinesweeperActionKind.flag;
      final pop = isCurrent ? Curves.elasticOut.transform(actionProgress) : 1.0;
      _paintFlag(canvas, rect, pop);
    }
  }

  void _paintNumber(Canvas canvas, Rect rect, int number) {
    final painter = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(
          color: _numberColors[number] ?? const Color(0xFF2D3540),
          fontSize: rect.width * 0.5,
          fontWeight: FontWeight.w900,
          shadows: const [Shadow(color: Colors.white54, blurRadius: 1)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      rect.center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  void _paintFlag(Canvas canvas, Rect rect, double scale) {
    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.scale(scale.clamp(0.0, 1.2));
    canvas.translate(-rect.center.dx, -rect.center.dy);
    final poleX = rect.center.dx - rect.width * 0.08;
    final top = rect.top + rect.height * 0.22;
    final bottom = rect.bottom - rect.height * 0.2;
    canvas.drawLine(
      Offset(poleX, top),
      Offset(poleX, bottom),
      Paint()
        ..color = const Color(0xFFFFD178)
        ..strokeWidth = math.max(1.5, rect.width * 0.07)
        ..strokeCap = StrokeCap.round,
    );
    final flag = Path()
      ..moveTo(poleX, top)
      ..lineTo(rect.right - rect.width * 0.18, top + rect.height * 0.15)
      ..lineTo(poleX, top + rect.height * 0.3)
      ..close();
    canvas.drawShadow(flag, Colors.black, 2, false);
    canvas.drawPath(flag, Paint()..color = const Color(0xFFFF695F));
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(poleX, bottom),
        width: rect.width * 0.42,
        height: rect.height * 0.13,
      ),
      Paint()..color = const Color(0xFFE4A746),
    );
    canvas.restore();
  }

  void _paintMine(
    Canvas canvas,
    Offset center,
    double radius, {
    required bool exploded,
  }) {
    if (exploded) {
      canvas.drawCircle(
        center,
        radius * (1.65 + ambientProgress * 0.2),
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFC451).withValues(alpha: 0.8),
              const Color(0xFFFF5B45).withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius * 2)),
      );
    }
    final spikePaint = Paint()
      ..color = exploded ? const Color(0xFF66251D) : const Color(0xFF26343B)
      ..strokeWidth = radius * 0.35
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i += 1) {
      final angle = i * math.pi / 4;
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.7,
        center + Offset(math.cos(angle), math.sin(angle)) * radius * 1.35,
        spikePaint,
      );
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.35),
          colors: exploded
              ? const [Color(0xFFFF9B45), Color(0xFF7C261C)]
              : const [Color(0xFF65757A), Color(0xFF17262D)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawCircle(
      center - Offset(radius * 0.3, radius * 0.3),
      radius * 0.16,
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _MinesweeperBoardPainter oldDelegate) =>
      oldDelegate.engine.stateHash != engine.stateHash ||
      oldDelegate.lastAction?.number != lastAction?.number ||
      oldDelegate.actionProgress != actionProgress ||
      oldDelegate.ambientProgress != ambientProgress ||
      oldDelegate.thinking != thinking ||
      oldDelegate.pressedIndex != pressedIndex;
}
