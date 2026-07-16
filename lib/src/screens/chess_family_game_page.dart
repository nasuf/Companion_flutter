part of 'package:companion_flutter/main.dart';

class _ChessFamilyGamePage extends StatefulWidget {
  const _ChessFamilyGamePage({
    required this.api,
    required this.authSession,
    required this.game,
    required this.kind,
  });

  final CompanionApi api;
  final AuthSession authSession;
  final _GameTile game;
  final ChessFamilyKind kind;

  @override
  State<_ChessFamilyGamePage> createState() => _ChessFamilyGamePageState();
}

class _ChessFamilyGamePageState extends State<_ChessFamilyGamePage> {
  late final _NativeGameRuntime _runtime;
  ChessFamilyEngine? _engine;
  int? _selectedSquare;
  Set<int> _legalTargets = const {};
  bool _isFullscreen = false;

  String get _gameKey => widget.kind == ChessFamilyKind.chess
      ? _nativeChessGameKey
      : _nativeXiangqiGameKey;

  @override
  void initState() {
    super.initState();
    _runtime = _NativeGameRuntime(
      api: widget.api,
      authSession: widget.authSession,
      gameKey: _gameKey,
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

  Future<void> _deleteRound(GameSession session) async {
    final wasActive = _runtime.session?.id == session.id;
    if (wasActive && _runtime.aiThinking) {
      _runtime.showNotice('${_runtime.agentName} 还在完成当前这一步，请稍等一下。');
      return;
    }
    final deleted = await _runtime.deleteRound(session);
    if (!mounted || !deleted || !wasActive) return;
    setState(() {
      _engine = null;
      _selectedSquare = null;
      _legalTargets = const {};
      _isFullscreen = false;
    });
  }

  Future<void> _startGame() async {
    final current = _engine;
    if (_runtime.session != null && !_runtime.completed) {
      await _runtime.abort('restarted', current?.summaryJson() ?? const {});
    }
    final session = await _runtime.start({
      'variant': widget.kind.name,
      'first_actor': 'user',
      'rules_engine': 'bishop_1_4_4',
      'search': 'iterative_deepening_pvs_alpha_beta',
    });
    if (session == null || !mounted) return;
    setState(() {
      _engine = ChessFamilyEngine(kind: widget.kind);
      _selectedSquare = null;
      _legalTargets = const {};
      _isFullscreen = true;
    });
  }

  Future<void> _handleSquareTap(int square) async {
    final engine = _engine;
    if (engine == null ||
        engine.isFinished ||
        engine.isAgentTurn ||
        _runtime.aiThinking) {
      return;
    }
    if (_selectedSquare != null && _legalTargets.contains(square)) {
      final before = engine.analyze();
      final result = engine.play(from: _selectedSquare!, to: square);
      setState(() {
        _selectedSquare = null;
        _legalTargets = const {};
      });
      unawaited(HapticFeedback.selectionClick());
      await _reportMove(result.move, before);
      if (result.status != ChessFamilyStatus.playing) {
        await _finish(result.status);
      } else {
        await _playAgentTurn();
      }
      return;
    }
    final piece = engine.pieces
        .where((item) => item.square == square)
        .firstOrNull;
    if (piece == null || piece.actor != ChessFamilyActor.user) {
      setState(() {
        _selectedSquare = null;
        _legalTargets = const {};
      });
      return;
    }
    final targets = engine.legalDestinations(square).toSet();
    setState(() {
      _selectedSquare = targets.isEmpty ? null : square;
      _legalTargets = targets;
    });
    unawaited(HapticFeedback.selectionClick());
  }

  Future<void> _playAgentTurn() async {
    final engine = _engine;
    if (engine == null || engine.isFinished || !engine.isAgentTurn) return;
    setState(() => _runtime.aiThinking = true);
    final before = engine.analyze();
    await _runtime.reportEvent(
      'ai_thinking_started',
      payload: {
        'move_number': engine.moveCount + 1,
        'analysis': before.toJson(),
      },
    );
    try {
      final decision = await engine.chooseAiMove();
      if (!mounted || engine.isFinished) return;
      await _runtime.reportEvent('ai_move_decided', payload: decision.toJson());
      final result = engine.playAlgebraic(
        decision.algebraic,
        decision: decision,
      );
      unawaited(HapticFeedback.lightImpact());
      await _reportMove(result.move, before);
      if (result.status != ChessFamilyStatus.playing) {
        await _finish(result.status);
      }
    } catch (caught) {
      _runtime.syncNotice = '这一步没有算完，请重新开一局：$caught';
    } finally {
      if (mounted) setState(() => _runtime.aiThinking = false);
    }
  }

  Future<void> _reportMove(
    ChessFamilyMove move,
    ChessPositionAnalysis before,
  ) async {
    final after = move.analysis;
    await _runtime.reportEvent(
      'piece_moved',
      state: 'playing',
      payload: {
        ...move.toJson(),
        'action_id': '${_runtime.session?.id}:${move.number}',
        'state_before': before.toJson(),
        'state_after': {...after.toJson(), 'status': _engine!.status.name},
        'state_before_hash': before.boardHash.toString(),
        'state_after_hash': after.boardHash.toString(),
      },
    );
    if (move.moment != null) {
      await _runtime.reportEvent(
        'key_moment',
        payload: {...move.moment!, 'move_number': move.number},
      );
    }
  }

  Future<void> _finish(ChessFamilyStatus status) async {
    final engine = _engine;
    if (engine == null) return;
    final summary = engine.summaryJson();
    await _runtime.finish({
      ...summary,
      'actions': summary['moves'],
      'user_outcome': switch (status) {
        ChessFamilyStatus.userWon => 'win',
        ChessFamilyStatus.agentWon => 'lose',
        ChessFamilyStatus.draw => 'draw',
        ChessFamilyStatus.playing => 'draw',
      },
      'terminal_state': {'status': status.name, 'result': summary['result']},
      'final_state': summary['analysis'],
      'state_after_hash': (summary['analysis'] as Map)['board_hash'],
    });
  }

  @override
  Widget build(BuildContext context) {
    final engine = _engine;
    if (_isFullscreen && engine != null) {
      return _NativeFullscreenGameSurface(
        onExit: () => setState(() => _isFullscreen = false),
        onRestart: _startGame,
        restartLabel: engine.isFinished ? '再来一局' : '重新开一局',
        restartDisabled: _runtime.starting || _runtime.aiThinking,
        restartLoading: _runtime.starting,
        child: _gameContents(engine),
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
              SliverToBoxAdapter(child: _header()),
              SliverToBoxAdapter(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 360),
                  child: engine == null ? _cover() : _gamePanel(engine),
                ),
              ),
              SliverToBoxAdapter(child: _history()),
              const SliverToBoxAdapter(child: SizedBox(height: 42)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final engine = _engine;
    final subtitle = engine == null
        ? '和 ${_runtime.agentName} 安静下一盘'
        : _statusSubtitle(engine);
    return Padding(
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
              child: const Icon(CupertinoIcons.chevron_left, size: 17),
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
            subtitle,
            style: TextStyle(
              color: AppColors.text.withValues(alpha: 0.55),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _statusSubtitle(ChessFamilyEngine engine) => _runtime.aiThinking
      ? '${_runtime.agentName} 正在想'
      : switch (engine.status) {
          ChessFamilyStatus.playing => '轮到你走棋',
          ChessFamilyStatus.userWon => '你赢了',
          ChessFamilyStatus.agentWon => '${_runtime.agentName} 赢了',
          ChessFamilyStatus.draw => '这一局和棋',
        };

  Widget _cover() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
    child: _GlassPanel(
      radius: 24,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _GamePlaceholderStage(game: widget.game),
            ),
          ),
          if (_runtime.error != null) ...[
            const SizedBox(height: 10),
            _GomokuNotice(text: _runtime.error!, isError: true),
          ],
          const SizedBox(height: 12),
          _PrimaryGameButton(
            label: '开始游戏',
            loading: _runtime.starting || _runtime.initializing,
            disabled: _runtime.starting || _runtime.initializing,
            onPressed: _startGame,
          ),
        ],
      ),
    ),
  );

  Widget _gamePanel(ChessFamilyEngine engine) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
    child: _GlassPanel(
      radius: 24,
      padding: const EdgeInsets.all(13),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: _NativeFullscreenToggleButton(
              expanded: false,
              onPressed: () => setState(() => _isFullscreen = true),
            ),
          ),
          const SizedBox(height: 6),
          _gameContents(engine),
          const SizedBox(height: 12),
          _PrimaryGameButton(
            label: engine.isFinished ? '再来一局' : '重新开一局',
            loading: _runtime.starting,
            disabled: _runtime.starting || _runtime.aiThinking,
            onPressed: _startGame,
          ),
        ],
      ),
    ),
  );

  Widget _gameContents(ChessFamilyEngine engine) => Column(
    children: [
      _ChessPlayersStrip(
        agentName: _runtime.agentName,
        thinking: _runtime.aiThinking,
        moveCount: engine.moves.length,
      ),
      const SizedBox(height: 12),
      AspectRatio(
        aspectRatio: widget.kind == ChessFamilyKind.chess ? 1 : 0.9,
        child: _ChessFamilyBoard(
          engine: engine,
          selectedSquare: _selectedSquare,
          legalTargets: _legalTargets,
          onSquareTap: _handleSquareTap,
        ),
      ),
      const SizedBox(height: 10),
      _ChessAnalysisStrip(analysis: engine.analyze(), kind: widget.kind),
      if (_runtime.syncNotice != null) ...[
        const SizedBox(height: 10),
        _GomokuNotice(text: _runtime.syncNotice!, isError: false),
      ],
    ],
  );

  Widget _history() => Padding(
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
            if (_runtime.rounds.isNotEmpty)
              _SoftCountPill(text: '${_runtime.rounds.length} 局'),
          ],
        ),
        const SizedBox(height: 11),
        if (_runtime.roundsLoading)
          const Center(child: CupertinoActivityIndicator())
        else if (_runtime.rounds.isEmpty)
          const _GameRoundEmptyState(
            icon: CupertinoIcons.square_grid_3x2,
            title: '第一局还在等你',
            subtitle: '走完以后，完整棋谱和关键局面都会留在这里。',
          )
        else
          for (final round in _runtime.rounds.take(8))
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _GameRoundCard(
                summary: _GameRoundSummary.fromSession(round),
                onTap: () {
                  unawaited(
                    _handleGameRoundTap(
                      context: context,
                      session: round,
                      onDelete: () => _deleteRound(round),
                    ),
                  );
                },
              ),
            ),
      ],
    ),
  );
}

class _ChessPlayersStrip extends StatelessWidget {
  const _ChessPlayersStrip({
    required this.agentName,
    required this.thinking,
    required this.moveCount,
  });

  final String agentName;
  final bool thinking;
  final int moveCount;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(
        CupertinoIcons.person_fill,
        size: 16,
        color: Color(0xFFCC594E),
      ),
      const SizedBox(width: 7),
      Text(
        '你',
        style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w900),
      ),
      const Spacer(),
      Text(
        thinking ? '$agentName 思考中' : '$moveCount 手',
        style: TextStyle(
          color: AppColors.text.withValues(alpha: 0.52),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      const Spacer(),
      Text(
        agentName,
        style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w900),
      ),
      const SizedBox(width: 7),
      const Icon(CupertinoIcons.sparkles, size: 16, color: Color(0xFF1F6FFF)),
    ],
  );
}

class _ChessAnalysisStrip extends StatelessWidget {
  const _ChessAnalysisStrip({required this.analysis, required this.kind});

  final ChessPositionAnalysis analysis;
  final ChessFamilyKind kind;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.subtleFill(context, light: 0.48),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.glassBorder(context)),
    ),
    child: Row(
      children: [
        _ChessStat(label: '可走', value: '${analysis.legalMoveCount}'),
        _ChessStat(
          label: '局面',
          value: analysis.materialBalance == 0
              ? '均衡'
              : analysis.materialBalance > 0
              ? '你稍优'
              : '对方稍优',
        ),
        _ChessStat(
          label: '状态',
          value: analysis.inCheck
              ? (kind == ChessFamilyKind.chess ? '将军' : '被将')
              : '进行中',
        ),
      ],
    ),
  );
}

class _ChessStat extends StatelessWidget {
  const _ChessStat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: AppColors.text,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: AppColors.text.withValues(alpha: 0.42),
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _ChessFamilyBoard extends StatelessWidget {
  const _ChessFamilyBoard({
    required this.engine,
    required this.selectedSquare,
    required this.legalTargets,
    required this.onSquareTap,
  });

  final ChessFamilyEngine engine;
  final int? selectedSquare;
  final Set<int> legalTargets;
  final ValueChanged<int> onSquareTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => GestureDetector(
      onTapUp: (details) {
        final square = _squareAt(details.localPosition, constraints.biggest);
        if (square != null) {
          onSquareTap(square);
        }
      },
      child: CustomPaint(
        painter: _ChessFamilyBoardPainter(
          kind: engine.kind,
          files: engine.files,
          ranks: engine.ranks,
          pieces: engine.pieces,
          selectedSquare: selectedSquare,
          legalTargets: legalTargets,
        ),
      ),
    ),
  );

  int? _squareAt(Offset point, Size size) {
    const padding = 12.0;
    if (engine.kind == ChessFamilyKind.chess) {
      final cell = (math.min(size.width, size.height) - padding * 2) / 8;
      final file = ((point.dx - padding) / cell).floor();
      final row = ((point.dy - padding) / cell).floor();
      if (file < 0 || file >= 8 || row < 0 || row >= 8) return null;
      final rank = 7 - row;
      return engine.squareAt(file, rank);
    }
    final geometry = _XiangqiBoardGeometry(size);
    final file =
        ((point.dx - geometry.board.left + geometry.step / 2) / geometry.step)
            .floor();
    final row =
        ((point.dy - geometry.board.top + geometry.step / 2) / geometry.step)
            .floor();
    if (file < 0 || file >= 9 || row < 0 || row >= 10) return null;
    return engine.squareAt(file, 9 - row);
  }
}

class _XiangqiBoardGeometry {
  _XiangqiBoardGeometry(Size size) {
    final margin = math.max(20.0, size.shortestSide * 0.07);
    final availableWidth = math.max(0.0, size.width - margin * 2);
    final availableHeight = math.max(0.0, size.height - margin * 2);
    final width = math.min(availableWidth, availableHeight * 8 / 9);
    step = width / 8;
    board = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: width,
      height: step * 9,
    );
  }

  late final Rect board;
  late final double step;

  Offset point(int file, int row) =>
      Offset(board.left + file * step, board.top + row * step);
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final item in this) {
      if (test(item)) return item;
    }
    return null;
  }
}

class _ChessFamilyBoardPainter extends CustomPainter {
  const _ChessFamilyBoardPainter({
    required this.kind,
    required this.files,
    required this.ranks,
    required this.pieces,
    required this.selectedSquare,
    required this.legalTargets,
  });

  final ChessFamilyKind kind;
  final int files;
  final int ranks;
  final List<ChessBoardPiece> pieces;
  final int? selectedSquare;
  final Set<int> legalTargets;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final background = Paint()
      ..color = kind == ChessFamilyKind.chess
          ? const Color(0xFFF4E8D0)
          : const Color(0xFFD9A45F);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(18)),
      background,
    );
    if (kind == ChessFamilyKind.chess) {
      _paintChess(canvas, size);
    } else {
      _paintXiangqi(canvas, size);
    }
  }

  void _paintChess(Canvas canvas, Size size) {
    const pad = 12.0;
    final side = math.min(size.width, size.height) - pad * 2;
    final cell = side / 8;
    final origin = Offset((size.width - side) / 2, (size.height - side) / 2);
    for (var row = 0; row < 8; row++) {
      for (var file = 0; file < 8; file++) {
        final square = Rect.fromLTWH(
          origin.dx + file * cell,
          origin.dy + row * cell,
          cell,
          cell,
        );
        final dark = (row + file).isOdd;
        canvas.drawRect(
          square,
          Paint()
            ..color = dark ? const Color(0xFF6D8A72) : const Color(0xFFF0E5CC),
        );
        final piece = pieces.firstWhereOrNull(
          (item) => item.file == file && item.rank == 7 - row,
        );
        if (piece?.square == selectedSquare) {
          canvas.drawRect(square, Paint()..color = const Color(0x8054A8FF));
        }
        if (piece != null) _paintChessPiece(canvas, square.center, cell, piece);
      }
    }
    for (final target in legalTargets) {
      final piece = _pieceBySquare(target);
      final file = piece?.file ?? target % (files * 2);
      final rank = piece?.rank ?? ranks - target ~/ (files * 2) - 1;
      final center = Offset(
        origin.dx + (file + .5) * cell,
        origin.dy + (7 - rank + .5) * cell,
      );
      canvas.drawCircle(
        center,
        piece == null ? cell * .12 : cell * .34,
        Paint()
          ..color = piece == null
              ? const Color(0xB02E7D65)
              : const Color(0x552E7D65)
          ..style = piece == null ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  void _paintChessPiece(
    Canvas canvas,
    Offset center,
    double cell,
    ChessBoardPiece piece,
  ) {
    final symbol = _chessGlyph(piece.symbol);
    final painter = TextPainter(
      text: TextSpan(
        text: symbol,
        style: TextStyle(
          color: piece.actor == ChessFamilyActor.user
              ? const Color(0xFFFDF8EA)
              : const Color(0xFF17202B),
          fontSize: cell * .72,
          fontWeight: FontWeight.w700,
          shadows: const [
            Shadow(
              color: Color(0x55000000),
              blurRadius: 3,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  void _paintXiangqi(Canvas canvas, Size size) {
    final geometry = _XiangqiBoardGeometry(size);
    final board = geometry.board;
    final step = geometry.step;
    final rect = Offset.zero & size;
    final frame = RRect.fromRectAndRadius(rect, const Radius.circular(18));
    canvas.drawRRect(
      frame,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF3D49A), Color(0xFFE2AE68), Color(0xFFC98247)],
          stops: [0, 0.58, 1],
        ).createShader(rect),
    );
    canvas.save();
    canvas.clipRRect(frame);
    final grain = Paint()
      ..color = const Color(0xFF704127).withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.55, step * 0.018);
    for (var index = 0; index < 17; index += 1) {
      final y = size.height * (index + 0.5) / 17;
      final wave = math.sin(index * 1.37) * step * 0.18;
      canvas.drawPath(
        Path()
          ..moveTo(-8, y)
          ..cubicTo(
            size.width * 0.28,
            y + wave,
            size.width * 0.72,
            y - wave,
            size.width + 8,
            y + wave * 0.35,
          ),
        grain,
      );
    }
    canvas.restore();
    canvas.drawRRect(
      frame.deflate(1.2),
      Paint()
        ..color = const Color(0xFF7A4528).withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, step * 0.075),
    );
    final boardFrame = RRect.fromRectAndRadius(
      board.inflate(step * 0.18),
      Radius.circular(step * 0.12),
    );
    canvas.drawRRect(
      boardFrame,
      Paint()
        ..color = const Color(0xFF6C3B23).withValues(alpha: 0.24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, step * 0.045),
    );
    final line = Paint()
      ..color = const Color(0xFF4E2B1A).withValues(alpha: 0.9)
      ..strokeWidth = math.max(1.0, step * 0.038)
      ..strokeCap = StrokeCap.square;
    for (var row = 0; row < 10; row++) {
      canvas.drawLine(geometry.point(0, row), geometry.point(8, row), line);
    }
    for (var file = 0; file < 9; file++) {
      if (file == 0 || file == 8) {
        canvas.drawLine(geometry.point(file, 0), geometry.point(file, 9), line);
      } else {
        canvas.drawLine(geometry.point(file, 0), geometry.point(file, 4), line);
        canvas.drawLine(geometry.point(file, 5), geometry.point(file, 9), line);
      }
    }
    canvas.drawLine(geometry.point(3, 0), geometry.point(5, 2), line);
    canvas.drawLine(geometry.point(5, 0), geometry.point(3, 2), line);
    canvas.drawLine(geometry.point(3, 9), geometry.point(5, 7), line);
    canvas.drawLine(geometry.point(5, 9), geometry.point(3, 7), line);
    for (final (file, row) in const [
      (1, 2),
      (7, 2),
      (0, 3),
      (2, 3),
      (4, 3),
      (6, 3),
      (8, 3),
      (0, 6),
      (2, 6),
      (4, 6),
      (6, 6),
      (8, 6),
      (1, 7),
      (7, 7),
    ]) {
      _paintXiangqiMark(canvas, geometry.point(file, row), step, file, line);
    }
    _paintCenteredText(
      canvas,
      '楚 河',
      Offset(board.left + step * 2, board.top + step * 4.5),
      step * 0.5,
      const Color(0xC44E2B1A),
    );
    _paintCenteredText(
      canvas,
      '漢 界',
      Offset(board.left + step * 6, board.top + step * 4.5),
      step * 0.5,
      const Color(0xC44E2B1A),
    );
    for (final piece in pieces) {
      _paintXiangqiPiece(
        canvas,
        geometry.point(piece.file, 9 - piece.rank),
        step,
        piece,
        selected: piece.square == selectedSquare,
      );
    }
    for (final target in legalTargets) {
      final piece = _pieceBySquare(target);
      final file = piece?.file ?? target % (files * 2);
      final rank = piece?.rank ?? ranks - target ~/ (files * 2) - 1;
      final center = geometry.point(file, 9 - rank);
      if (piece == null) {
        canvas.drawCircle(
          center,
          step * 0.13,
          Paint()..color = const Color(0xE51C7B67),
        );
      } else {
        canvas.drawCircle(
          center,
          step * 0.47,
          Paint()
            ..color = const Color(0xFF1C7B67)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2.0, step * 0.07),
        );
      }
    }
  }

  void _paintXiangqiMark(
    Canvas canvas,
    Offset center,
    double step,
    int file,
    Paint line,
  ) {
    final gap = step * 0.11;
    final length = step * 0.17;
    final stroke = Paint()
      ..color = line.color
      ..strokeWidth = math.max(0.9, step * 0.032)
      ..style = PaintingStyle.stroke;
    void corner(double xDirection, double yDirection) {
      final start = center + Offset(gap * xDirection, gap * yDirection);
      canvas.drawPath(
        Path()
          ..moveTo(start.dx + length * xDirection, start.dy)
          ..lineTo(start.dx, start.dy)
          ..lineTo(start.dx, start.dy + length * yDirection),
        stroke,
      );
    }

    if (file > 0) {
      corner(-1, -1);
      corner(-1, 1);
    }
    if (file < 8) {
      corner(1, -1);
      corner(1, 1);
    }
  }

  void _paintXiangqiPiece(
    Canvas canvas,
    Offset center,
    double step,
    ChessBoardPiece piece, {
    required bool selected,
  }) {
    final radius = step * 0.405;
    canvas.drawCircle(
      center + Offset(0, radius * 0.18),
      radius * 1.08,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.2),
    );
    final rimRect = Rect.fromCircle(center: center, radius: radius * 1.05);
    canvas.drawCircle(
      center,
      radius * 1.05,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.42),
          colors: [Color(0xFFFFE9B7), Color(0xFFD7A45F), Color(0xFF8A532E)],
          stops: [0, 0.72, 1],
        ).createShader(rimRect),
    );
    canvas.drawCircle(
      center,
      radius * 0.87,
      Paint()..color = const Color(0xFFF6DDA3),
    );
    final actorColor = piece.actor == ChessFamilyActor.user
        ? const Color(0xFFC63F34)
        : const Color(0xFF253C32);
    canvas.drawCircle(
      center,
      radius * 0.78,
      Paint()
        ..color = actorColor.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.3, step * 0.045),
    );
    if (selected) {
      canvas.drawCircle(
        center,
        radius * 1.23,
        Paint()
          ..color = const Color(0xFF0E8C77)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2.2, step * 0.075),
      );
    }
    _paintCenteredText(
      canvas,
      _xiangqiGlyph(piece),
      center - Offset(0, radius * 0.02),
      radius * 1.04,
      actorColor,
    );
  }

  ChessBoardPiece? _pieceBySquare(int square) =>
      pieces.firstWhereOrNull((item) => item.square == square);

  String _xiangqiGlyph(ChessBoardPiece piece) {
    final key = piece.symbol.toUpperCase();
    return switch (key) {
      'K' => piece.actor == ChessFamilyActor.user ? '帅' : '将',
      'A' => piece.actor == ChessFamilyActor.user ? '仕' : '士',
      'B' => piece.actor == ChessFamilyActor.user ? '相' : '象',
      'N' => '马',
      'R' => '车',
      'C' => '炮',
      'P' => piece.actor == ChessFamilyActor.user ? '兵' : '卒',
      _ => piece.symbol,
    };
  }

  String _chessGlyph(String symbol) => switch (symbol) {
    'K' => '♔',
    'Q' => '♕',
    'R' => '♖',
    'B' => '♗',
    'N' => '♘',
    'P' => '♙',
    'k' => '♚',
    'q' => '♛',
    'r' => '♜',
    'b' => '♝',
    'n' => '♞',
    'p' => '♟',
    _ => symbol,
  };

  void _paintCenteredText(
    Canvas canvas,
    String text,
    Offset center,
    double size,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _ChessFamilyBoardPainter oldDelegate) =>
      oldDelegate.pieces != pieces ||
      oldDelegate.selectedSquare != selectedSquare ||
      oldDelegate.legalTargets != legalTargets;
}
