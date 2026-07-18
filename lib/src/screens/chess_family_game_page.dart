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
  bool _chessAssetsPrecached = false;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.kind != ChessFamilyKind.chess || _chessAssetsPrecached) return;
    _chessAssetsPrecached = true;
    unawaited(
      Future.wait([
        for (final asset in _chessPieceAssets)
          precacheImage(AssetImage(asset), context),
      ]),
    );
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
      _engine = ChessFamilyEngine(
        kind: widget.kind,
        aiConfig: ChessFamilyAiConfig.fromJson(
          session.engineConfig,
          kind: widget.kind,
        ),
      );
      _selectedSquare = null;
      _legalTargets = const {};
      _isFullscreen = true;
    });
  }

  Future<void> _closeGame() async {
    final engine = _engine;
    if (_runtime.session != null && !_runtime.completed) {
      await _runtime.abort(
        _runtime.turnTimeoutVisible ? 'turn_timeout_ended' : 'closed',
        engine?.summaryJson() ?? const {},
      );
    }
    _runtime.clearPresentation();
    if (!mounted) return;
    setState(() {
      _engine = null;
      _selectedSquare = null;
      _legalTargets = const {};
      _isFullscreen = false;
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
      if (result.move.capturedPiece != null) {
        _NativeGameHaptics.capture(1, keyMoment: result.move.moment != null);
      } else {
        _NativeGameHaptics.placement(keyMoment: result.move.moment != null);
      }
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
      if (_selectedSquare != null) _NativeGameHaptics.rejected();
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
    _NativeGameHaptics.selection();
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
      if (result.move.capturedPiece != null) {
        _NativeGameHaptics.capture(1, keyMoment: result.move.moment != null);
      } else {
        _NativeGameHaptics.placement(keyMoment: result.move.moment != null);
      }
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
    final compact = Scaffold(
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
    final expanded = engine == null
        ? const SizedBox.shrink()
        : _NativeFullscreenGameSurface(
            gameKey: widget.game.nativeGameKey,
            gameTitle: widget.game.title,
            onExit: () => setState(() => _isFullscreen = false),
            onRestart: _startGame,
            restartLabel: engine.isFinished ? '再来一局' : '重新开一局',
            restartDisabled: _runtime.starting || _runtime.aiThinking,
            restartLoading: _runtime.starting,
            child: _gameContents(engine),
          );
    return _NativeGameFullscreenTransition(
      expanded: _isFullscreen && engine != null,
      compactChild: compact,
      expandedChild: expanded,
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
            loading: _runtime.starting,
            disabled: _runtime.starting,
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

  Widget _gameContents(ChessFamilyEngine engine) => _NativeGameInteractionLayer(
    runtime: _runtime,
    game: widget.game,
    onPlayAgain: _startGame,
    onCloseGame: _closeGame,
    userTurnActive:
        !engine.isFinished &&
        !engine.isAgentTurn &&
        !_runtime.aiThinking &&
        !_runtime.starting,
    turnToken:
        '${_runtime.session?.id}:${engine.moveCount}:${engine.isAgentTurn ? 'agent' : 'user'}',
    turnTimeout: _nativeGameTurnTimeout(_gameKey),
    turnLabel: _runtime.aiThinking ? '${_runtime.agentName} 在走棋' : '轮到你走棋',
    moveCount: engine.moveCount,
    child: Column(
      children: [
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
    ),
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

class _ChessAnalysisStrip extends StatelessWidget {
  const _ChessAnalysisStrip({required this.analysis, required this.kind});

  final ChessPositionAnalysis analysis;
  final ChessFamilyKind kind;

  @override
  Widget build(BuildContext context) {
    final xiangqi = kind == ChessFamilyKind.xiangqi;
    final valueColor = xiangqi ? const Color(0xFF4A291A) : AppColors.text;
    final labelColor = xiangqi
        ? const Color(0x995A3420)
        : AppColors.text.withValues(alpha: 0.42);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: xiangqi
            ? const Color(0xFFEBC58A)
            : AppColors.subtleFill(context, light: 0.48),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: xiangqi
              ? const Color(0x997A4528)
              : AppColors.glassBorder(context),
        ),
      ),
      child: Row(
        children: [
          _ChessStat(
            label: '可走',
            value: '${analysis.legalMoveCount}',
            valueColor: valueColor,
            labelColor: labelColor,
          ),
          _ChessStat(
            label: '局面',
            value: analysis.materialBalance == 0
                ? '均衡'
                : analysis.materialBalance > 0
                ? '你稍优'
                : '对方稍优',
            valueColor: valueColor,
            labelColor: labelColor,
          ),
          _ChessStat(
            label: '状态',
            value: analysis.inCheck
                ? (kind == ChessFamilyKind.chess ? '将军' : '被将')
                : '进行中',
            valueColor: valueColor,
            labelColor: labelColor,
          ),
        ],
      ),
    );
  }
}

class _ChessStat extends StatelessWidget {
  const _ChessStat({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.labelColor,
  });
  final String label;
  final String value;
  final Color valueColor;
  final Color labelColor;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: labelColor,
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
          lastMove: engine.moves.isEmpty ? null : engine.moves.last,
          selectedSquare: selectedSquare,
          legalTargets: legalTargets,
        ),
        child: engine.kind == ChessFamilyKind.chess
            ? _ChessPieceLayer(size: constraints.biggest, pieces: engine.pieces)
            : null,
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

class _ChessPieceLayer extends StatelessWidget {
  const _ChessPieceLayer({required this.size, required this.pieces});

  final Size size;
  final List<ChessBoardPiece> pieces;

  @override
  Widget build(BuildContext context) {
    const padding = 12.0;
    final side = math.min(size.width, size.height) - padding * 2;
    final cell = side / 8;
    final origin = Offset((size.width - side) / 2, (size.height - side) / 2);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final piece in pieces)
          Positioned(
            left: origin.dx + piece.file * cell - cell * .025,
            top: origin.dy + (7 - piece.rank) * cell - cell * .055,
            width: cell * 1.05,
            height: cell * 1.05,
            child: IgnorePointer(
              child: Image.asset(
                _chessPieceAsset(piece),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
              ),
            ),
          ),
      ],
    );
  }

  String _chessPieceAsset(ChessBoardPiece piece) {
    final color = piece.actor == ChessFamilyActor.user ? 'white' : 'black';
    final name = switch (piece.symbol.toUpperCase()) {
      'K' => 'king',
      'Q' => 'queen',
      'R' => 'rook',
      'B' => 'bishop',
      'N' => 'knight',
      _ => 'pawn',
    };
    return 'assets/prototype/games/chess-$color-$name.png';
  }
}

const _chessPieceAssets = <String>[
  'assets/prototype/games/chess-white-king.png',
  'assets/prototype/games/chess-white-queen.png',
  'assets/prototype/games/chess-white-rook.png',
  'assets/prototype/games/chess-white-bishop.png',
  'assets/prototype/games/chess-white-knight.png',
  'assets/prototype/games/chess-white-pawn.png',
  'assets/prototype/games/chess-black-king.png',
  'assets/prototype/games/chess-black-queen.png',
  'assets/prototype/games/chess-black-rook.png',
  'assets/prototype/games/chess-black-bishop.png',
  'assets/prototype/games/chess-black-knight.png',
  'assets/prototype/games/chess-black-pawn.png',
];

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
    required this.lastMove,
    required this.selectedSquare,
    required this.legalTargets,
  });

  final ChessFamilyKind kind;
  final int files;
  final int ranks;
  final List<ChessBoardPiece> pieces;
  final ChessFamilyMove? lastMove;
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
    final boardRect = Rect.fromLTWH(origin.dx, origin.dy, side, side);
    final outerRect = boardRect.inflate(cell * .13);
    canvas.drawRRect(
      RRect.fromRectAndRadius(outerRect, Radius.circular(cell * .15)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A2118), Color(0xFF8A5A38), Color(0xFF24140F)],
          stops: [0, .48, 1],
        ).createShader(outerRect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, Radius.circular(cell * .055)),
      Paint()
        ..color = Colors.black.withValues(alpha: .38)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * .08),
    );
    final previousSquares = _chessLastMoveSquares();
    for (var row = 0; row < 8; row++) {
      for (var file = 0; file < 8; file++) {
        final square = Rect.fromLTWH(
          origin.dx + file * cell,
          origin.dy + row * cell,
          cell,
          cell,
        );
        final dark = (row + file).isOdd;
        final squareColors = dark
            ? const [Color(0xFF6C4B35), Color(0xFF4C3126)]
            : const [Color(0xFFF2DFC0), Color(0xFFD9B98B)];
        canvas.drawRect(
          square,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: squareColors,
            ).createShader(square),
        );
        canvas.drawRect(
          square.deflate(cell * .025),
          Paint()
            ..color = Colors.white.withValues(alpha: dark ? .018 : .08)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(.45, cell * .012),
        );
        final piece = pieces.firstWhereOrNull(
          (item) => item.file == file && item.rank == 7 - row,
        );
        final squareName = '${String.fromCharCode(97 + file)}${8 - row}';
        if (previousSquares.contains(squareName)) {
          canvas.drawRect(
            square.deflate(cell * .045),
            Paint()..color = const Color(0x99E5B64D),
          );
        }
        if (piece?.square == selectedSquare) {
          canvas.drawRect(
            square.deflate(cell * .035),
            Paint()..color = const Color(0xB054A8FF),
          );
        }
        if (row == 7) {
          _paintChessCoordinate(
            canvas,
            String.fromCharCode(97 + file),
            square.bottomRight - Offset(cell * .09, cell * .19),
            cell,
            dark: dark,
          );
        }
        if (file == 0) {
          _paintChessCoordinate(
            canvas,
            '${8 - row}',
            square.topLeft + Offset(cell * .075, cell * .035),
            cell,
            dark: dark,
          );
        }
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
      if (piece == null) {
        canvas.drawCircle(
          center,
          cell * .105,
          Paint()..color = const Color(0xCC58B58A),
        );
      } else {
        canvas.drawCircle(
          center,
          cell * .39,
          Paint()
            ..color = const Color(0x9958B58A)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2, cell * .055),
        );
      }
    }
  }

  Set<String> _chessLastMoveSquares() {
    final move = lastMove;
    if (move == null || kind != ChessFamilyKind.chess) return const {};
    return {move.from.toLowerCase(), move.to.toLowerCase()};
  }

  void _paintChessCoordinate(
    Canvas canvas,
    String text,
    Offset offset,
    double cell, {
    required bool dark,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: dark
              ? const Color(0xFFE7CEAA).withValues(alpha: .72)
              : const Color(0xFF5A3A28).withValues(alpha: .7),
          fontSize: cell * .15,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  void _paintXiangqi(Canvas canvas, Size size) {
    final geometry = _XiangqiBoardGeometry(size);
    final board = geometry.board;
    final step = geometry.step;
    final rect = Offset.zero & size;
    final frame = RRect.fromRectAndRadius(rect, const Radius.circular(20));

    // The dark walnut shell and pale maple playing surface are painted as
    // separate layers so the board reads as a physical object, not a texture.
    canvas.drawRRect(
      frame,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B1C11), Color(0xFF8E4D28), Color(0xFF2B140D)],
          stops: [0, 0.52, 1],
        ).createShader(rect),
    );
    canvas.save();
    canvas.clipRRect(frame);
    final shellGrain = Paint()
      ..color = const Color(0xFFF4C67B).withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.7, step * 0.024);
    for (var index = 0; index < 15; index += 1) {
      final x = size.width * (index + 0.35) / 15;
      final wave = math.sin(index * 1.57) * step * 0.2;
      canvas.drawPath(
        Path()
          ..moveTo(x, -8)
          ..cubicTo(
            x + wave,
            size.height * 0.3,
            x - wave,
            size.height * 0.7,
            x + wave * 0.25,
            size.height + 8,
          ),
        shellGrain,
      );
    }
    canvas.restore();

    canvas.drawRRect(
      frame.deflate(1.4),
      Paint()
        ..color = const Color(0xFFF2C16D).withValues(alpha: 0.46)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.4, step * 0.052),
    );

    final panelRect = board.inflate(step * 0.5);
    final panelFrame = RRect.fromRectAndRadius(
      panelRect,
      Radius.circular(step * 0.18),
    );
    canvas.drawRRect(
      panelFrame.shift(Offset(0, step * 0.1)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.38)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, step * 0.18),
    );
    canvas.drawRRect(
      panelFrame,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFC47A38), Color(0xFF7B3E20), Color(0xFF4A2416)],
          stops: [0, 0.58, 1],
        ).createShader(panelRect),
    );

    final surfaceRect = panelRect.deflate(step * 0.12);
    final surface = RRect.fromRectAndRadius(
      surfaceRect,
      Radius.circular(step * 0.1),
    );
    canvas.drawRRect(
      surface,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6DBA2), Color(0xFFE7BD78), Color(0xFFD49750)],
          stops: [0, 0.62, 1],
        ).createShader(surfaceRect),
    );
    canvas.save();
    canvas.clipRRect(surface);
    _paintXiangqiBoardGrain(canvas, surfaceRect, step);
    canvas.restore();
    canvas.drawRRect(
      surface,
      Paint()
        ..color = const Color(0xFFFFE9B8).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, step * 0.04),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        surfaceRect.deflate(step * 0.07),
        Radius.circular(step * 0.07),
      ),
      Paint()
        ..color = const Color(0xFF72401F).withValues(alpha: 0.44)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, step * 0.025),
    );

    _paintXiangqiFrameStuds(canvas, panelRect, step);

    final lineShadow = Paint()
      ..color = const Color(0xFF3B1E13).withValues(alpha: 0.23)
      ..strokeWidth = math.max(2.2, step * 0.075)
      ..strokeCap = StrokeCap.square;
    final line = Paint()
      ..color = const Color(0xFF67351F).withValues(alpha: 0.86)
      ..strokeWidth = math.max(1.0, step * 0.033)
      ..strokeCap = StrokeCap.square;
    for (var row = 0; row < 10; row++) {
      canvas.drawLine(
        geometry.point(0, row) + Offset(0, step * 0.018),
        geometry.point(8, row) + Offset(0, step * 0.018),
        lineShadow,
      );
      canvas.drawLine(geometry.point(0, row), geometry.point(8, row), line);
    }
    for (var file = 0; file < 9; file++) {
      if (file == 0 || file == 8) {
        canvas.drawLine(
          geometry.point(file, 0) + Offset(step * 0.018, 0),
          geometry.point(file, 9) + Offset(step * 0.018, 0),
          lineShadow,
        );
        canvas.drawLine(geometry.point(file, 0), geometry.point(file, 9), line);
      } else {
        canvas.drawLine(
          geometry.point(file, 0) + Offset(step * 0.018, 0),
          geometry.point(file, 4) + Offset(step * 0.018, 0),
          lineShadow,
        );
        canvas.drawLine(
          geometry.point(file, 5) + Offset(step * 0.018, 0),
          geometry.point(file, 9) + Offset(step * 0.018, 0),
          lineShadow,
        );
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
      Offset(board.left + step * 2, board.top + step * 4.5) +
          Offset(0, step * 0.035),
      step * 0.49,
      const Color(0x32421F14),
    );
    _paintCenteredText(
      canvas,
      '楚 河',
      Offset(board.left + step * 2, board.top + step * 4.5),
      step * 0.49,
      const Color(0xA65C2C1B),
    );
    _paintCenteredText(
      canvas,
      '汉 界',
      Offset(board.left + step * 6, board.top + step * 4.5) +
          Offset(0, step * 0.035),
      step * 0.49,
      const Color(0x32421F14),
    );
    _paintCenteredText(
      canvas,
      '汉 界',
      Offset(board.left + step * 6, board.top + step * 4.5),
      step * 0.49,
      const Color(0xA65C2C1B),
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
          step * 0.15,
          Paint()
            ..color = const Color(0xFF176B5E).withValues(alpha: 0.22)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          center,
          step * 0.1,
          Paint()
            ..color = const Color(0xFF176B5E)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.7, step * 0.052),
        );
      } else {
        _paintXiangqiBrackets(
          canvas,
          center,
          step * 0.52,
          step * 0.16,
          const Color(0xFF167765),
          math.max(2.0, step * 0.065),
        );
      }
    }
  }

  void _paintXiangqiBoardGrain(Canvas canvas, Rect rect, double step) {
    final grain = Paint()
      ..color = const Color(0xFF7A4327).withValues(alpha: 0.095)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, step * 0.016);
    for (var index = 0; index < 19; index += 1) {
      final x = rect.left + rect.width * (index + 0.4) / 19;
      final wave = math.sin(index * 1.43) * step * 0.16;
      canvas.drawPath(
        Path()
          ..moveTo(x, rect.top - 5)
          ..cubicTo(
            x + wave,
            rect.top + rect.height * 0.3,
            x - wave,
            rect.top + rect.height * 0.7,
            x + wave * 0.25,
            rect.bottom + 5,
          ),
        grain,
      );
    }
    final fiber = Paint()
      ..color = const Color(0xFFFFE8B1).withValues(alpha: 0.1)
      ..strokeWidth = math.max(0.45, step * 0.012);
    for (var index = 0; index < 14; index += 1) {
      final y = rect.top + rect.height * (index + 0.5) / 14;
      canvas.drawLine(
        Offset(rect.left, y),
        Offset(rect.right, y + math.sin(index * 1.2) * step * 0.035),
        fiber,
      );
    }
  }

  void _paintXiangqiFrameStuds(Canvas canvas, Rect panelRect, double step) {
    final radius = math.max(2.2, step * 0.075);
    final top = panelRect.top + step * 0.095;
    final bottom = panelRect.bottom - step * 0.095;
    for (var index = 0; index < 11; index += 1) {
      final x = panelRect.left + panelRect.width * index / 10;
      final studRect = Rect.fromCircle(center: Offset(x, top), radius: radius);
      final studPaint = Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          colors: [Color(0xFFFFE28B), Color(0xFFD49429), Color(0xFF6C3519)],
          stops: [0, 0.68, 1],
        ).createShader(studRect);
      canvas.drawCircle(Offset(x, top), radius, studPaint);
      canvas.drawCircle(Offset(x, bottom), radius, studPaint);
    }
  }

  void _paintXiangqiBrackets(
    Canvas canvas,
    Offset center,
    double radius,
    double length,
    Color color,
    double width,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    for (final xDirection in const [-1.0, 1.0]) {
      for (final yDirection in const [-1.0, 1.0]) {
        final corner =
            center + Offset(radius * xDirection, radius * yDirection);
        canvas.drawPath(
          Path()
            ..moveTo(corner.dx - length * xDirection, corner.dy)
            ..lineTo(corner.dx, corner.dy)
            ..lineTo(corner.dx, corner.dy - length * yDirection),
          paint,
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
    final radius = step * 0.41;
    canvas.drawCircle(
      center + Offset(radius * 0.05, radius * 0.2),
      radius * 1.1,
      Paint()
        ..color = const Color(0xFF32170E).withValues(alpha: 0.42)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.18),
    );
    final rimRect = Rect.fromCircle(center: center, radius: radius * 1.08);
    canvas.drawCircle(
      center,
      radius * 1.08,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.42),
          colors: [Color(0xFFFFEDB9), Color(0xFFD89A4C), Color(0xFF6D341D)],
          stops: [0, 0.7, 1],
        ).createShader(rimRect),
    );
    canvas.drawCircle(
      center,
      radius * 0.91,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.28, -0.32),
          colors: [Color(0xFFFFF0C4), Color(0xFFE9BC72), Color(0xFFC47B38)],
          stops: [0, 0.74, 1],
        ).createShader(rimRect),
    );
    final actorColor = piece.actor == ChessFamilyActor.user
        ? const Color(0xFFB62D27)
        : const Color(0xFF25372F);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.97),
      math.pi * 1.08,
      math.pi * 0.7,
      false,
      Paint()
        ..color = const Color(0xFFFFF2C8).withValues(alpha: 0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.9, step * 0.027)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.95),
      math.pi * 0.08,
      math.pi * 0.72,
      false,
      Paint()
        ..color = const Color(0xFF6C361E).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.9, step * 0.03)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      center,
      radius * 0.76,
      Paint()
        ..color = actorColor.withValues(alpha: 0.84)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, step * 0.04),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.58),
      math.pi * 1.2,
      math.pi * 0.52,
      false,
      Paint()
        ..color = const Color(0xFF8B512D).withValues(alpha: 0.13)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.7, step * 0.018),
    );
    if (selected) {
      canvas.drawCircle(
        center,
        radius * 1.22,
        Paint()
          ..color = const Color(0xFFD6A43A).withValues(alpha: 0.2)
          ..style = PaintingStyle.fill,
      );
      _paintXiangqiBrackets(
        canvas,
        center,
        radius * 1.3,
        radius * 0.48,
        const Color(0xFF0D806E),
        math.max(2.2, step * 0.068),
      );
      canvas.drawCircle(
        center,
        radius * 1.14,
        Paint()
          ..color = const Color(0xFFF0C45F).withValues(alpha: 0.88)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.4, step * 0.038),
      );
    }
    _paintCenteredText(
      canvas,
      _xiangqiGlyph(piece),
      center - Offset(0, radius * 0.02) + Offset(0, radius * 0.055),
      radius * 1.06,
      const Color(0x4A31170E),
    );
    _paintCenteredText(
      canvas,
      _xiangqiGlyph(piece),
      center - Offset(0, radius * 0.02),
      radius * 1.06,
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
          fontFamily: 'Kaiti SC',
          fontFamilyFallback: const ['STKaiti', 'Noto Serif CJK SC'],
          letterSpacing: 0,
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
