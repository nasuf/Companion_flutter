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
  // True while the pause / exit sheet is on screen.
  bool _paused = false;
  // Non-null once the win / lose scene has taken over from the board.
  _MergeResultKind? _result;
  Timer? _resultTimer;

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
    _resultTimer?.cancel();
    _runtime.dispose();
    unawaited(
      _runtime.abort('page_closed', _sessionSummary(), updateUi: false),
    );
    super.dispose();
  }

  void _clearActiveRound() {
    _resultTimer?.cancel();
    _resultTimer = null;
    setState(() {
      _engine = null;
      _lastMove = null;
      _actionHistory.clear();
      _resolving = false;
      _result = null;
    });
  }

  Future<void> _start() async {
    _resultTimer?.cancel();
    _resultTimer = null;
    if (_result != null) setState(() => _result = null);
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
    final sw = Stopwatch()..start();
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
      await _runtime.paceAiMove(sw);
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
    // Let the last merge animation land before the result scene takes over.
    if (engine != null &&
        engine.isFinished &&
        _result == null &&
        _resultTimer == null) {
      final win = engine.status == NumberMergeStatus.completed;
      _resultTimer = Timer(const Duration(milliseconds: 1400), () {
        if (!mounted || _result != null) return;
        setState(
          () => _result = win ? _MergeResultKind.win : _MergeResultKind.lose,
        );
      });
    }
    if (engine != null && _result != null) {
      return _MergeResultScreen(
        kind: _result!,
        onRestart: _start,
        onExit: _closeGame,
      );
    }
    if (engine == null) {
      return _MergeHome(
        rounds: _runtime.rounds,
        starting: _runtime.starting,
        error: _runtime.error,
        onStart: _start,
        onExit: () => Navigator.of(context).maybePop(),
      );
    }
    final userTurnActive =
        !engine.isFinished &&
        engine.turn == NumberMergeActor.user &&
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
            '${_runtime.session?.id}:${engine.moveCount}:${engine.turn.name}',
        turnTimeout: _nativeGameTurnTimeout(_nativeNumberMergeGameKey),
        turnLabel: _runtime.aiThinking
            ? '${_runtime.agentName} 在合并'
            : _resolving
            ? '数字移动中'
            : '轮到你滑动',
        moveCount: engine.moveCount,
        showPlayers: false,
        child: _MergeGameScreen(
          engine: engine,
          lastMove: _lastMove,
          agentName: _runtime.agentName,
          userName: widget.authSession.userFacingName,
          agentAvatarUrl: widget.authSession.agentAvatarUrl,
          userAvatarUrl: widget.authSession.userAvatarUrl,
          aiThinking: _runtime.aiThinking,
          starting: _runtime.starting,
          enabled: userTurnActive,
          gamePoints: _runtime.pointsBalance,
          onMove: (direction) => unawaited(_userMove(direction)),
          onExit: _closeGame,
          onPauseChanged: _setPaused,
          onAbandon: _abandonRound,
        ),
      ),
    );
  }

  /// Quitting or restarting from the pause sheet gives up the board, so the
  /// lose screen takes over and the player chooses from there.
  ///
  /// Note this only drives the UI: the round itself is still reported as an
  /// abort by _start / _closeGame, so no loss is recorded and no points are
  /// deducted despite the screen showing 积分 -3.
  void _abandonRound() {
    _resultTimer?.cancel();
    _resultTimer = null;
    setState(() => _result = _MergeResultKind.lose);
  }

  void _setPaused(bool value) {
    if (_paused == value || !mounted) return;
    setState(() => _paused = value);
  }
}

class _NumberMergeBoard extends StatefulWidget {
  const _NumberMergeBoard({
    required this.engine,
    required this.lastMove,
    required this.thinking,
    required this.enabled,
    required this.onMove,
    this.figmaStyle = false,
  });

  final NumberMergeEngine engine;
  final NumberMergeMove? lastMove;
  final bool thinking;
  final bool enabled;
  final ValueChanged<NumberMergeDirection> onMove;
  final bool figmaStyle;

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
      // Own layer so every repaint replaces the whole board rather than a
      // damaged sub-rect.
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _NumberMergeBoardPainter(
            engine: widget.engine,
            lastMove: widget.lastMove,
            moveProgress: Curves.easeOutCubic.transform(_moveController.value),
            thinking: widget.thinking,
            figmaStyle: widget.figmaStyle,
          ),
        ),
      ),
    ),
  );
}

class _NumberMergeBoardPainter extends CustomPainter {
  _NumberMergeBoardPainter({
    required this.engine,
    required this.lastMove,
    required this.moveProgress,
    required this.thinking,
    this.figmaStyle = false,
  }) : boardSnapshot = List<int>.of(engine.board);

  final NumberMergeEngine engine;
  final NumberMergeMove? lastMove;
  final double moveProgress;
  final bool thinking;
  final bool figmaStyle;

  // Snapshot of the board taken when this painter is built. `engine` is one
  // long-lived mutable instance shared by every painter, so `oldDelegate.engine`
  // and `engine` are the same object and `engine.stateHash` can never differ
  // between the old and new delegate. That made the "board changed" branch of
  // shouldRepaint dead code: when the board changed without a matching change to
  // lastMove/moveProgress (e.g. after the slide animation settles), the painter
  // reported "no repaint" and the RepaintBoundary kept compositing its cached
  // layer — leaving a stale tile (the ghost "2") on a now-empty cell. Comparing
  // an immutable per-build snapshot restores correct repaint detection.
  final List<int> boardSnapshot;

  @override
  void paint(Canvas canvas, Size size) {
    // Tile glows are blurred past their cell, and near the board edge that
    // spilled outside `size`. Painting outside the reported bounds leaves stale
    // ink behind when Flutter repaints only the damaged region, which is what
    // put ghost digits on already-cleared cells.
    canvas.clipRect(Offset.zero & size);
    const outerInset = 7.0;
    final side = math.min(size.width, size.height) - outerInset * 2;
    final boardRect = Rect.fromLTWH(
      (size.width - side) / 2,
      (size.height - side) / 2,
      side,
      side,
    );
    final outer = RRect.fromRectAndRadius(boardRect, const Radius.circular(26));
    if (figmaStyle) {
      // The design's frosted well. Deliberately a flat translucent fill rather
      // than a BackdropFilter widget: sampling the backdrop pulled the previous
      // frame's tiles into the pane, and since the pane also lightens whatever
      // it covers, only the digits' dark drop shadow survived — a ghost "2" on
      // cells that had already been cleared.
      canvas.drawRRect(
        outer,
        Paint()..color = const Color(0xFFD9D9D9).withValues(alpha: 0.34),
      );
    }
    if (!figmaStyle) {
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
    }
    final inner = boardRect.deflate(11);
    final gap = inner.width * 0.025;
    final tileSize = (inner.width - gap * 3) / 4;
    for (var index = 0; index < 16; index += 1) {
      final rect = _rectFor(index, inner, tileSize, gap);
      if (figmaStyle) {
        // The frosted pane behind the board already reads as the well, so an
        // empty cell only needs the faintest outline to keep the 4x4 legible.
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(tileSize * 0.22)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = tileSize * 0.022
            ..color = Colors.white.withValues(alpha: 0.10),
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(tileSize * 0.17)),
          Paint()..color = const Color(0xFF081721).withValues(alpha: 0.72),
        );
      }
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
    if (figmaStyle) {
      _paintFigmaTile(canvas, rect, value);
    } else {
      _paintClassicTile(canvas, rect, value);
    }
    canvas.restore();
  }

  /// Lit keycap in the style of the home-screen board art: flat body with a
  /// slight bottom-up lift, a bright rim, and an outer glow in the tile's hue.
  void _paintFigmaTile(Canvas canvas, Rect rect, int value) {
    final colors = _numberMergeFigmaColors(value);
    final radius = Radius.circular(rect.width * 0.22);
    final body = RRect.fromRectAndRadius(rect, radius);

    canvas.drawRRect(
      body,
      Paint()
        ..color = colors[2].withValues(alpha: 0.42)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, rect.width * 0.075),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors[0], colors[1]],
        ).createShader(rect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(rect.width * 0.018), radius),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rect.width * 0.028
        ..color = colors[2],
    );

    _paintTileValue(canvas, rect, value, light: false);
  }

  void _paintClassicTile(Canvas canvas, Rect rect, int value) {
    final colors = _numberMergeColors(value);
    final rounded = RRect.fromRectAndRadius(
      rect.deflate(1.2),
      Radius.circular(rect.width * 0.17),
    );
    canvas.drawShadow(Path()..addRRect(rounded), Colors.black, 5, true);
    canvas.drawRRect(
      rounded,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors[0], colors[1]],
        ).createShader(rect),
    );
    canvas.drawRRect(
      rounded.deflate(2.3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.22),
    );
    _paintTileValue(canvas, rect, value, light: value <= 4);
    canvas.drawCircle(
      Offset(rect.left + rect.width * 0.23, rect.top + rect.height * 0.19),
      rect.width * 0.035,
      Paint()..color = Colors.white.withValues(alpha: 0.3),
    );
  }

  void _paintTileValue(
    Canvas canvas,
    Rect rect,
    int value, {
    required bool light,
  }) {
    final digits = '$value'.length;
    final fontSize =
        rect.width *
        switch (digits) {
          1 || 2 => 0.42,
          3 => 0.34,
          _ => 0.26,
        };
    // Deliberately no TextStyle.shadows. On Impeller the shadow layer and the
    // glyph itself can come apart, leaving just the dark blurred shadow on the
    // tile — that was the stray dark digit on iOS. The tile body already gives
    // the number enough contrast without one.
    final painter = TextPainter(
      text: TextSpan(
        text: '$value',
        style: TextStyle(
          color: light ? const Color(0xFF263640) : const Color(0xFFF8F2E6),
          fontSize: fontSize,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: -fontSize * 0.02,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: rect.width);
    painter.paint(
      canvas,
      rect.center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  /// `[bodyTop, bodyBottom, rim]` sampled from the home-screen board art.
  /// Values above 128 continue the ramp; the artwork only covers 4 – 128.
  List<Color> _numberMergeFigmaColors(int value) => switch (value) {
    2 => const [Color(0xFF8C8A88), Color(0xFFA8A29B), Color(0xFFE6E2D6)],
    4 => const [Color(0xFF9B8E84), Color(0xFFB2A094), Color(0xFFFAF7E6)],
    8 => const [Color(0xFF936E59), Color(0xFFAC7B5A), Color(0xFFF6D9A8)],
    16 => const [Color(0xFFAF775D), Color(0xFFD8825C), Color(0xFFFFF3B5)],
    32 => const [Color(0xFFA8676B), Color(0xFFCC6D6E), Color(0xFFE3A980)],
    64 => const [Color(0xFF9F4E46), Color(0xFFC6564E), Color(0xFFE4A780)],
    128 => const [Color(0xFFB99C7B), Color(0xFFC6A47E), Color(0xFFD7D0A2)],
    256 => const [Color(0xFFB0608C), Color(0xFFD06896), Color(0xFFECB2CD)],
    512 => const [Color(0xFF8060B4), Color(0xFF966CD0), Color(0xFFC4B0F0)],
    1024 => const [Color(0xFF5678B4), Color(0xFF648CD0), Color(0xFFA8CCF0)],
    _ => const [Color(0xFFC4A85C), Color(0xFFDEBE68), Color(0xFFFFF0AA)],
  };

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
      !listEquals(oldDelegate.boardSnapshot, boardSnapshot) ||
      oldDelegate.lastMove?.number != lastMove?.number ||
      oldDelegate.moveProgress != moveProgress ||
      oldDelegate.thinking != thinking ||
      oldDelegate.figmaStyle != figmaStyle;
}
