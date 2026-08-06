part of 'package:companion_flutter/main.dart';

const String _chessFigmaAsset = 'assets/prototype/games/chess-figma/';

class _ChessHome extends StatelessWidget {
  const _ChessHome({
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
    final labels = ['总对局', '胜利局', '胜率', '时长'];
    final values = ['$total', '$wins', '$rate%', _formatDuration(seconds)];
    return Scaffold(
      backgroundColor: const Color(0xFF5D351F),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          return Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                width: width,
                height: height * (891 / 852),
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 11000),
                  scaleAmount: 0.004,
                  phase: 0.4,
                  child: Image.asset(
                    '${_chessFigmaAsset}home_bg.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                left: width * (83 / 393),
                top: height * (59 / 852),
                width: width * (235 / 393),
                height: height * (144 / 852),
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 5400),
                  scaleAmount: 0.008,
                  translateY: 1.4,
                  child: Image.asset(
                    '${_chessFigmaAsset}home_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                left: width * (71 / 393),
                top: height * (244 / 852),
                width: width * (258 / 393),
                height: height * (245 / 852),
                child: _ChessHomeBoardButton(
                  loading: starting,
                  onTap: () => unawaited(onStart()),
                ),
              ),
              if (error != null)
                Positioned(
                  left: width * 0.08,
                  right: width * 0.08,
                  top: height * 0.58,
                  child: _GomokuNotice(text: error!, isError: true),
                ),
              Positioned(
                left: width * (24 / 393),
                top: height * (530 / 852),
                width: width * (165 / 393),
                height: height * (52 / 852),
                child: _ChessHomeImageButton(
                  asset: '${_chessFigmaAsset}home_btn_exit.png',
                  enabled: !starting,
                  onTap: onExit,
                ),
              ),
              Positioned(
                left: width * (204 / 393),
                top: height * (530 / 852),
                width: width * (165 / 393),
                height: height * (52 / 852),
                child: _ChessHomeImageButton(
                  asset: '${_chessFigmaAsset}home_btn_start.png',
                  enabled: !starting,
                  loading: starting,
                  onTap: () => unawaited(onStart()),
                ),
              ),
              Positioned(
                left: width * (15 / 393),
                top: height * (612 / 852),
                width: width * (370 / 393),
                height: height * (200 / 852),
                child: _ChessHomeStats(labels: labels, values: values),
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
      final value = hours == hours.truncateToDouble()
          ? hours.round().toString()
          : hours.toStringAsFixed(1);
      return '${value}H';
    }
    return '${(seconds / 60).ceil()}m';
  }
}

class _ChessHomeBoardButton extends StatefulWidget {
  const _ChessHomeBoardButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  State<_ChessHomeBoardButton> createState() => _ChessHomeBoardButtonState();
}

class _ChessHomeImageButton extends StatefulWidget {
  const _ChessHomeImageButton({
    required this.asset,
    required this.onTap,
    this.enabled = true,
    this.loading = false,
  });

  final String asset;
  final VoidCallback onTap;
  final bool enabled;
  final bool loading;

  @override
  State<_ChessHomeImageButton> createState() => _ChessHomeImageButtonState();
}

class _ChessHomeImageButtonState extends State<_ChessHomeImageButton> {
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
        duration: const Duration(milliseconds: 90),
        child: Opacity(
          opacity: enabled ? 1 : 0.7,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Image.asset(widget.asset, fit: BoxFit.fill),
              ),
              if (widget.loading)
                const CupertinoActivityIndicator(color: Color(0xFFF4DDAE)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChessHomeBoardButtonState extends State<_ChessHomeBoardButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.loading ? null : (_) => setState(() => _pressed = true),
      onTapCancel: widget.loading
          ? null
          : () => setState(() => _pressed = false),
      onTapUp: widget.loading
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onTap();
            },
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1,
        duration: const Duration(milliseconds: 100),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: _GomokuBreathingMotion(
                duration: const Duration(milliseconds: 6200),
                scaleAmount: 0.006,
                translateY: 1.5,
                phase: 0.55,
                child: Image.asset(
                  '${_chessFigmaAsset}home_board.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            if (widget.loading)
              const CupertinoActivityIndicator(color: Color(0xFFF0D4A0)),
          ],
        ),
      ),
    );
  }
}

class _ChessHomeStats extends StatelessWidget {
  const _ChessHomeStats({required this.labels, required this.values});

  final List<String> labels;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                '${_chessFigmaAsset}home_stats.png',
                fit: BoxFit.fill,
              ),
            ),
            for (var index = 0; index < 4; index += 1) ...[
              Positioned(
                left:
                    width * (const [0.145, 0.382, 0.620, 0.855][index] - 0.125),
                top: height * 0.36,
                width: width * 0.25,
                height: height * 0.18,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    labels[index],
                    style: const TextStyle(
                      color: Color(0xFF5C381E),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
              Positioned(
                left:
                    width * (const [0.145, 0.382, 0.620, 0.855][index] - 0.125),
                top: height * 0.67,
                width: width * 0.25,
                height: height * 0.18,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    values[index],
                    style: const TextStyle(
                      color: Color(0xFF5C381E),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ChessGameScreen extends StatefulWidget {
  const _ChessGameScreen({
    required this.engine,
    required this.selectedSquare,
    required this.legalTargets,
    required this.agentName,
    required this.userName,
    required this.agentAvatarUrl,
    required this.userAvatarUrl,
    required this.aiThinking,
    required this.enabled,
    required this.onSquareTap,
    required this.onShowLose,
    required this.bannerInMs,
    required this.bannerHoldMs,
    required this.bannerOutMs,
    required this.gamePoints,
  });

  final ChessFamilyEngine engine;
  final int? selectedSquare;
  final Set<int> legalTargets;
  final String agentName;
  final String userName;
  final String? agentAvatarUrl;
  final String? userAvatarUrl;
  final bool aiThinking;
  final bool enabled;
  final ValueChanged<int> onSquareTap;
  // Quitting or restarting mid-game → 失败 + 扣分.
  final Future<void> Function() onShowLose;
  // "你的回合" banner timing (ms), from the per-game admin config.
  final int bannerInMs;
  final int bannerHoldMs;
  final int bannerOutMs;
  // Current game points, shown in the top-right coin badge.
  final int? gamePoints;

  @override
  State<_ChessGameScreen> createState() => _ChessGameScreenState();
}

class _ChessGameScreenState extends State<_ChessGameScreen> {
  // True while a modal (pause / exit) is open, so the per-turn dial freezes.
  bool _paused = false;

  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    final userTurn = widget.enabled && !engine.isFinished;
    final agentTurn =
        !engine.isFinished && (engine.isAgentTurn || widget.aiThinking);
    final token =
        '${engine.moveCount}:${engine.isAgentTurn ? 'agent' : 'user'}';
    return Scaffold(
      backgroundColor: const Color(0xFF7D4B2C),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          return Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                width: width,
                height: height * 1.034,
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 11000),
                  scaleAmount: 0.004,
                  child: Image.asset(
                    '${_chessFigmaAsset}game_bg.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // Two wooden nameplates (design 国际象棋-游戏, frame 393x852). The
              // coin avatar carries a per-turn 30s dial (like 五子棋). User card
              // top-left, agent card lower-right (mirrored).
              Positioned(
                left: width * (9 / 393),
                top: height * (98 / 852),
                width: width * (173 / 393),
                child: _ChessPlayerCard(
                  name: widget.userName,
                  imageUrl: widget.userAvatarUrl,
                  active: userTurn,
                  paused: _paused,
                  clockToken: token,
                  onTimeout: _handleUserIdleTimeout,
                ),
              ),
              Positioned(
                left: width * (209 / 393),
                top: height * (176 / 852),
                width: width * (174 / 393),
                child: _ChessPlayerCard(
                  name: widget.agentName,
                  imageUrl: widget.agentAvatarUrl,
                  active: agentTurn,
                  paused: _paused || widget.aiThinking,
                  clockToken: token,
                  mirrored: true,
                ),
              ),
              Positioned(
                left: width * (19 / 393),
                top: height * (288 / 852),
                width: width * (355 / 393),
                height: height * (362 / 852),
                child: _ChessArtworkBoard(
                  engine: engine,
                  selectedSquare: widget.selectedSquare,
                  legalTargets: widget.legalTargets,
                  enabled: widget.enabled,
                  onTap: widget.onSquareTap,
                ),
              ),
              // "你的回合" ribbon at the board's lower-middle, flashing in when
              // the user's turn begins (timing from the per-game admin config).
              Positioned(
                left: 0,
                right: 0,
                top: height * 0.60 - (width * 0.13) / 2,
                height: width * 0.13,
                child: _TurnBanner(
                  userTurn: userTurn,
                  inMs: widget.bannerInMs,
                  holdMs: widget.bannerHoldMs,
                  outMs: widget.bannerOutMs,
                ),
              ),
              // Both assets are cropped to the pill artwork, so identical
              // slots render identical buttons.
              Positioned(
                left: width * (22 / 393),
                top: height * (704 / 852),
                width: width * (124 / 393),
                height: height * (36 / 852),
                child: _ChessArtButton(
                  asset: '${_chessFigmaAsset}game_btn_exit.png',
                  onTap: () => unawaited(_confirmExit(context)),
                ),
              ),
              Positioned(
                left: width * (160 / 393),
                top: height * (704 / 852),
                width: width * (124 / 393),
                height: height * (36 / 852),
                child: _ChessArtButton(
                  asset: '${_chessFigmaAsset}game_btn_pause.png',
                  onTap: () => unawaited(_showPause(context)),
                ),
              ),
              _NativeGamePointsBadge(points: widget.gamePoints),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    setState(() => _paused = true);
    await _showChessModal(
      context,
      title: '退出对局',
      message: '当前棋局还没有结束，退出后本局进度会清空。',
      actions: (dialogContext) => [
        Expanded(
          child: _ChessModalButton(
            label: '继续',
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ChessModalButton(
            label: '退出',
            onTap: () {
              Navigator.of(dialogContext).pop();
              // Quitting mid-game → 失败 + 扣分; the 失败 screen's 退出 then leaves.
              unawaited(widget.onShowLose());
            },
          ),
        ),
      ],
    );
    if (mounted) setState(() => _paused = false);
  }

  // The per-turn dial ran out while the user hadn't moved → auto-open the pause
  // menu (tapping 继续 resumes with a fresh dial).
  void _handleUserIdleTimeout() {
    if (!mounted || _paused || widget.engine.isFinished) return;
    unawaited(_showPause(context));
  }

  Future<void> _showPause(BuildContext context) async {
    setState(() => _paused = true);
    await _showChessModal(
      context,
      title: '游戏暂停',
      message: '要继续当前棋局，还是重新开一盘？',
      actions: (dialogContext) => [
        Expanded(
          child: _ChessModalButton(
            label: '继续',
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ChessModalButton(
            label: '重开',
            onTap: () {
              Navigator.of(dialogContext).pop();
              // Restarting mid-game → 失败 + 扣分; the 失败 screen's 重来一局 then
              // starts the new round.
              unawaited(widget.onShowLose());
            },
          ),
        ),
      ],
    );
    if (mounted) setState(() => _paused = false);
  }
}

/// Wooden nameplate: a coin avatar (with a per-turn 30s dial) on the outer end
/// and the player's name on the cream plate. The card art is flipped for the
/// agent (avatar on the right). Positions are card-relative (173x59).
class _ChessPlayerCard extends StatelessWidget {
  const _ChessPlayerCard({
    required this.name,
    required this.imageUrl,
    required this.active,
    required this.paused,
    required this.clockToken,
    this.mirrored = false,
    this.onTimeout,
  });

  final String name;
  final String? imageUrl;
  final bool active;
  final bool paused;
  final String clockToken;
  final bool mirrored;
  final VoidCallback? onTimeout;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 173 / 59,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final ringD = w * (58 / 173);
          // Avatar coin on the outer end; name centred on the cream plate
          // (user centre 109, agent centre 66 in 173-space).
          final ringLeft = mirrored ? w * (105 / 173) : w * (10 / 173);
          final nameCentre = mirrored ? 66.0 : 109.0;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Transform.flip(
                  flipX: mirrored,
                  child: Image.asset(
                    '${_chessFigmaAsset}game_card.png',
                    fit: BoxFit.fill,
                  ),
                ),
              ),
              Positioned(
                left: ringLeft,
                top: -h * (1 / 59),
                width: ringD,
                height: ringD,
                child: _ChessTurnAvatar(
                  token: clockToken,
                  imageUrl: imageUrl,
                  fallback: name,
                  diameter: ringD,
                  active: active,
                  paused: paused,
                  onTimeout: onTimeout,
                ),
              ),
              Positioned(
                left: w * ((nameCentre - 52) / 173),
                top: 0,
                width: w * (104 / 173),
                height: h,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: Color(0xFF71513C),
                        fontSize: 15,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.none,
                      ),
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

/// Coin avatar with a per-turn countdown dial (reuses the 五子棋 painter). The
/// frame art has a baked default portrait, so the real avatar is drawn on top
/// to cover it, leaving only the gold ring; the dial + cyan seconds show while
/// it is this player's turn.
class _ChessTurnAvatar extends StatefulWidget {
  const _ChessTurnAvatar({
    required this.token,
    required this.imageUrl,
    required this.fallback,
    required this.diameter,
    required this.active,
    required this.paused,
    this.onTimeout,
  });

  final String token;
  final String? imageUrl;
  final String fallback;
  final double diameter;
  final bool active;
  final bool paused;
  final VoidCallback? onTimeout;

  @override
  State<_ChessTurnAvatar> createState() => _ChessTurnAvatarState();
}

class _ChessTurnAvatarState extends State<_ChessTurnAvatar>
    with SingleTickerProviderStateMixin {
  static const int _turnSeconds = 30;
  static const Color _cyan = Color(0xFF01FFFF);

  late final AnimationController _countdown;

  @override
  void initState() {
    super.initState();
    _countdown = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _turnSeconds),
    )..addStatusListener(_onCountdownStatus);
    _sync();
  }

  void _onCountdownStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        widget.active &&
        !widget.paused) {
      widget.onTimeout?.call();
    }
  }

  @override
  void didUpdateWidget(covariant _ChessTurnAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active || widget.token != oldWidget.token) {
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
    final d = widget.diameter;
    final inner = d * (51 / 58);
    return AnimatedBuilder(
      animation: _countdown,
      builder: (context, _) {
        final remainingFraction = (1 - _countdown.value).clamp(0.0, 1.0);
        final remainingSeconds = (remainingFraction * _turnSeconds)
            .ceil()
            .clamp(0, _turnSeconds);
        return SizedBox(
          width: d,
          height: d,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Gold ring frame (with a baked default portrait underneath).
              Image.asset(
                '${_chessFigmaAsset}game_avatar_ring.png',
                width: d,
                height: d,
                fit: BoxFit.contain,
              ),
              // Real portrait covers the baked one; ring shows around it.
              ClipOval(
                child: SizedBox(
                  width: inner,
                  height: inner,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _Avatar(
                        size: inner,
                        label: widget.fallback.trim().isEmpty
                            ? '伴'
                            : widget.fallback.trim().characters.first,
                        imageUrl: widget.imageUrl,
                        gradient: const [Color(0xFFF4E4CA), Color(0xFFC49B6E)],
                      ),
                      if (widget.active) ...[
                        CustomPaint(
                          painter: _GomokuTurnTimerPainter(
                            remainingFraction: remainingFraction,
                          ),
                        ),
                        Center(
                          child: Text(
                            '$remainingSeconds',
                            style: TextStyle(
                              color: _cyan,
                              fontSize: inner * 0.4,
                              fontWeight: FontWeight.w900,
                              height: 1,
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
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChessArtworkBoard extends StatefulWidget {
  const _ChessArtworkBoard({
    required this.engine,
    required this.selectedSquare,
    required this.legalTargets,
    required this.enabled,
    required this.onTap,
  });

  final ChessFamilyEngine engine;
  final int? selectedSquare;
  final Set<int> legalTargets;
  final bool enabled;
  final ValueChanged<int> onTap;

  @override
  State<_ChessArtworkBoard> createState() => _ChessArtworkBoardState();
}

class _ChessArtworkBoardState extends State<_ChessArtworkBoard>
    with SingleTickerProviderStateMixin {
  // The moving piece slides between squares (like 象棋 / 跳棋) instead of
  // snapping; long enough to read, short enough not to delay the reply.
  static const _slide = Duration(milliseconds: 260);
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _slide,
  );

  // Pieces the previous build drew — the engine mutates in place, so this is
  // the only record of where the last move started from.
  List<ChessBoardPiece>? _lastRender;
  ChessFamilyMove? _sliding;
  int _slideFromFile = 0;
  int _slideFromRank = 0;
  // The piece being captured stays put until the mover lands on it.
  ChessBoardPiece? _captured;
  int _seenMoveCount = 0;

  @override
  void initState() {
    super.initState();
    _seenMoveCount = widget.engine.moveCount;
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _sliding = null;
          _captured = null;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant _ChessArtworkBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final engine = widget.engine;
    // A restart hands over a fresh engine; drop any slide still in flight.
    if (!identical(oldWidget.engine, engine) ||
        engine.moveCount < _seenMoveCount) {
      _controller.stop();
      _sliding = null;
      _captured = null;
      _lastRender = null;
      _seenMoveCount = engine.moveCount;
      return;
    }
    if (engine.moveCount == _seenMoveCount) return;
    // Only the newest single move is worth animating; if several landed at
    // once (a replay / restored session) just show the result.
    final jumped = engine.moveCount - _seenMoveCount > 1;
    _seenMoveCount = engine.moveCount;
    final before = _lastRender;
    if (jumped || before == null) {
      _sliding = null;
      _captured = null;
      return;
    }
    final move = engine.moves.last;
    final fromPiece = before.firstWhereOrNull(
      (piece) => piece.square == move.fromSquare,
    );
    final mover = engine.pieces.firstWhereOrNull(
      (piece) => piece.square == move.toSquare,
    );
    if (fromPiece == null || mover == null) {
      _sliding = null;
      _captured = null;
      return;
    }
    _sliding = move;
    _slideFromFile = fromPiece.file;
    _slideFromRank = fromPiece.rank;
    _captured = before.firstWhereOrNull(
      (piece) => piece.square == move.toSquare && piece.actor != mover.actor,
    );
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _pieceImage(ChessBoardPiece piece) => IgnorePointer(
    child: Image.asset(
      _chessPieceAssetForArtwork(piece),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    final current = engine.pieces;
    _lastRender = current;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final geometry = _ChessArtworkGeometry(size);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: widget.enabled
              ? (details) {
                  final square = geometry.squareAt(
                    details.localPosition,
                    engine,
                  );
                  if (square != null) widget.onTap(square);
                }
              : null,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  '${_chessFigmaAsset}game_board_reference.png',
                  fit: BoxFit.fill,
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _ChessArtworkOverlayPainter(
                    engine: engine,
                    geometry: geometry,
                    selectedSquare: widget.selectedSquare,
                    legalTargets: widget.legalTargets,
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final move = _sliding;
                  final animating = move != null && _controller.isAnimating;
                  final moverSquare = move?.toSquare;
                  final mover = animating
                      ? current.firstWhereOrNull((p) => p.square == moverSquare)
                      : null;
                  final t = Curves.easeInOut.transform(_controller.value);
                  return Stack(
                    children: [
                      // Captured piece lingers beneath the incoming mover.
                      if (animating && _captured != null)
                        Positioned.fromRect(
                          rect: geometry.pieceRect(_captured!),
                          child: _pieceImage(_captured!),
                        ),
                      for (final piece in current)
                        if (!(animating && piece.square == moverSquare))
                          Positioned.fromRect(
                            rect: geometry.pieceRect(piece),
                            child: _pieceImage(piece),
                          ),
                      if (mover != null)
                        Positioned.fromRect(
                          rect: Rect.lerp(
                            geometry.pieceRectAt(_slideFromFile, _slideFromRank),
                            geometry.pieceRect(mover),
                            t,
                          )!,
                          child: _pieceImage(mover),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _chessPieceAssetForArtwork(ChessBoardPiece piece) {
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

class _ChessArtworkGeometry {
  const _ChessArtworkGeometry(this.size);

  final Size size;
  double get left => size.width * (64 / 852);
  double get right => size.width * (786 / 852);
  double get top => size.height * (65 / 868);
  double get bottom => size.height * (798 / 868);
  double get cellWidth => (right - left) / 8;
  double get cellHeight => (bottom - top) / 8;

  Rect cellRect(int file, int rank) => Rect.fromLTWH(
    left + file * cellWidth,
    top + (7 - rank) * cellHeight,
    cellWidth,
    cellHeight,
  );

  Rect pieceRect(ChessBoardPiece piece) => pieceRectAt(piece.file, piece.rank);

  Rect pieceRectAt(int file, int rank) {
    final cell = cellRect(file, rank);
    final side = math.min(cellWidth, cellHeight) * 1.08;
    return Rect.fromCenter(
      center: cell.center + Offset(0, -cellHeight * 0.03),
      width: side,
      height: side,
    );
  }

  int? squareAt(Offset point, ChessFamilyEngine engine) {
    if (point.dx < left ||
        point.dx >= right ||
        point.dy < top ||
        point.dy >= bottom) {
      return null;
    }
    final file = ((point.dx - left) / cellWidth).floor();
    final row = ((point.dy - top) / cellHeight).floor();
    return engine.squareAt(file, 7 - row);
  }
}

class _ChessArtworkOverlayPainter extends CustomPainter {
  const _ChessArtworkOverlayPainter({
    required this.engine,
    required this.geometry,
    required this.selectedSquare,
    required this.legalTargets,
  });

  final ChessFamilyEngine engine;
  final _ChessArtworkGeometry geometry;
  final int? selectedSquare;
  final Set<int> legalTargets;

  @override
  void paint(Canvas canvas, Size size) {
    for (final piece in engine.pieces) {
      final rect = geometry.cellRect(piece.file, piece.rank);
      if (piece.square == selectedSquare) {
        canvas.drawRect(
          rect.deflate(2),
          Paint()..color = const Color(0x8054B5E8),
        );
      }
      if (legalTargets.contains(piece.square)) {
        canvas.drawCircle(
          rect.center,
          math.min(rect.width, rect.height) * 0.39,
          Paint()
            ..color = const Color(0xCC64C18F)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
    for (final target in legalTargets) {
      if (engine.pieces.any((piece) => piece.square == target)) continue;
      for (var rank = 0; rank < 8; rank += 1) {
        for (var file = 0; file < 8; file += 1) {
          if (engine.squareAt(file, rank) != target) continue;
          canvas.drawCircle(
            geometry.cellRect(file, rank).center,
            math.min(geometry.cellWidth, geometry.cellHeight) * 0.12,
            Paint()..color = const Color(0xCC64C18F),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChessArtworkOverlayPainter oldDelegate) =>
      oldDelegate.engine.fen != engine.fen ||
      oldDelegate.selectedSquare != selectedSquare ||
      oldDelegate.legalTargets != legalTargets;
}

class _ChessArtButton extends StatefulWidget {
  const _ChessArtButton({required this.asset, required this.onTap});

  final String asset;
  final VoidCallback onTap;

  @override
  State<_ChessArtButton> createState() => _ChessArtButtonState();
}

class _ChessArtButtonState extends State<_ChessArtButton> {
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
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 90),
        child: Image.asset(widget.asset, fit: BoxFit.fill),
      ),
    );
  }
}

class _ChessModalButton extends StatelessWidget {
  const _ChessModalButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: 1,
        child: Container(
          height: 42,
          alignment: const Alignment(0, 0.12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFD8B780), Color(0xFF835638)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF4B2A1B), width: 2),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFFE7B8),
              fontSize: 16,
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showChessModal(
  BuildContext context, {
  required String title,
  required String message,
  required List<Widget> Function(BuildContext dialogContext) actions,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, _, __) => Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 44),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF2E1C2), Color(0xFFBF966C)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF4D3024), width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF3F281E),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xCC3F281E),
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 17),
              Row(children: actions(dialogContext)),
            ],
          ),
        ),
      ),
    ),
    transitionBuilder: (_, animation, __, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: child,
      ),
    ),
  );
}

enum _ChessResultKind { win, lose }

/// Full-screen 国际象棋 win / lose result scene, composed from the exported art
/// (wooden shield → golden sun → banner → title → 积分 → buttons) with a
/// staggered pop-in. Shown at the page level in place of the game so the board
/// / avatars / dial are torn down. Both outcomes share the same layout; only
/// the title text (胜利/失败) and score number differ. Positions letterboxed
/// onto the 393x852 design canvas so overlaps hold on any aspect ratio.
class _ChessResultScreen extends StatefulWidget {
  const _ChessResultScreen({
    super.key,
    required this.kind,
    required this.onRestart,
    required this.onExit,
  });

  final _ChessResultKind kind;
  final Future<void> Function() onRestart;
  final Future<void> Function() onExit;

  @override
  State<_ChessResultScreen> createState() => _ChessResultScreenState();
}

class _ChessResultScreenState extends State<_ChessResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  static const double _designW = 393;
  static const double _designH = 852;
  double _canvasW = _designW;
  double _canvasH = _designH;
  double _originX = 0;
  double _originY = 0;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
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

  Widget _img(String name) =>
      Image.asset('$_chessFigmaAsset$name', fit: BoxFit.fill);

  Widget _piece({
    required double cx,
    required double cy,
    required double wFrac,
    required double aspect,
    required double begin,
    required double end,
    bool drop = false,
    required Widget child,
  }) {
    final p = ((_c.value - begin) / (end - begin)).clamp(0.0, 1.0);
    final eased = Curves.easeOutBack.transform(p);
    final opacity = (p * 2.4).clamp(0.0, 1.0);
    final width = _canvasW * wFrac;
    final height = width * aspect;
    final dy = drop
        ? -_canvasH * 0.10 * (1 - Curves.easeOutCubic.transform(p))
        : 0.0;
    final scale = drop ? 1.0 : (0.7 + 0.3 * eased);
    return Positioned(
      left: _originX + _canvasW * cx - width / 2,
      top: _originY + _canvasH * cy - height / 2 + dy,
      width: width,
      height: height,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(scale: scale, child: child),
      ),
    );
  }

  // Gold gradient title (胜利 / 失败) with a soft drop shadow, matching the CSS.
  Widget _scorePlate(String numAsset) => Stack(
    alignment: Alignment.center,
    children: [
      Positioned.fill(child: _img('result_score_plate.png')),
      Positioned.fill(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('${_chessFigmaAsset}result_score_label.png', height: 26),
                const SizedBox(width: 6),
                Image.asset('$_chessFigmaAsset$numAsset', height: 26),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final win = widget.kind == _ChessResultKind.win;
    return Scaffold(
      backgroundColor: const Color(0xFF7D4B2C),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final s = math.min(w / _designW, h / _designH);
          _canvasW = _designW * s;
          _canvasH = _designH * s;
          _originX = (w - _canvasW) / 2;
          _originY = (h - _canvasH) / 2;
          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              return Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    width: w,
                    height: h * 1.034,
                    child: Image.asset(
                      '${_chessFigmaAsset}game_bg.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  ...(win ? _winPieces() : _losePieces()),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _exitButton() => _ChessResultButton(
    base: 'result_btn_exit.png',
    text: 'result_txt_exit.png',
    onTap: () => unawaited(widget.onExit()),
  );

  Widget _againButton() => _ChessResultButton(
    base: 'result_btn_again.png',
    text: 'result_txt_again.png',
    onTap: () => unawaited(widget.onRestart()),
  );

  // 胜利 layout (国际象棋-胜利 CSS, frame 393x852). z-order: shield → sun glow →
  // sun → banner glow → banner → 胜利 title (centred on the ribbon band) →
  // 积分 → buttons. The glow layers behind the sun and banner are the 光晕.
  List<Widget> _winPieces() => [
    _piece(
      cx: 0.5, cy: 0.359, wFrac: 0.695,
      aspect: 837 / 819, begin: 0.1, end: 0.44, drop: true,
      child: _img('result_shield.png'),
    ),
    // Soft halo behind the sun (pre-blurred).
    _piece(
      cx: 0.5, cy: 0.229, wFrac: 0.90,
      aspect: 1062 / 1065, begin: 0.06, end: 0.42,
      child: _img('result_sun_glow.png'),
    ),
    // Compass rose emblem (win-specific, distinct from the lose golden sun).
    _piece(
      cx: 0.5, cy: 0.229, wFrac: 0.496,
      aspect: 582 / 585, begin: 0.16, end: 0.5,
      child: _img('result_win_sun.png'),
    ),
    // Soft halo behind the banner (pre-blurred).
    _piece(
      cx: 0.5, cy: 0.3975, wFrac: 1.0,
      aspect: 729 / 1179, begin: 0.28, end: 0.56,
      child: _img('result_win_banner_glow.png'),
    ),
    _piece(
      cx: 0.5, cy: 0.3975, wFrac: 0.812,
      aspect: 369 / 957, begin: 0.32, end: 0.58,
      child: _img('result_win_banner.png'),
    ),
    // 胜利 title centred on the ribbon band, sized to sit within its edges.
    _piece(
      cx: 0.5, cy: 0.3678, wFrac: 0.24,
      aspect: 161 / 291, begin: 0.44, end: 0.68,
      child: _img('result_win_title.png'),
    ),
    _piece(
      cx: 0.5, cy: 0.641, wFrac: 0.361,
      aspect: 153 / 426, begin: 0.56, end: 0.76,
      child: _scorePlate('result_win_num.png'),
    ),
    _piece(
      cx: 0.277, cy: 0.796, wFrac: 0.412,
      aspect: 177 / 486, begin: 0.66, end: 0.88,
      child: _exitButton(),
    ),
    _piece(
      cx: 0.725, cy: 0.796, wFrac: 0.412,
      aspect: 180 / 486, begin: 0.72, end: 0.94,
      child: _againButton(),
    ),
  ];

  // 失败 layout (国际象棋-失败 CSS). z-order: shield → sun → banner → 失败 title
  // (centred on the ribbon band) → 积分 → buttons. No glow on the lose screen.
  List<Widget> _losePieces() => [
    _piece(
      cx: 0.5, cy: 0.361, wFrac: 0.695,
      aspect: 837 / 819, begin: 0.1, end: 0.44, drop: true,
      child: _img('result_shield.png'),
    ),
    _piece(
      cx: 0.5, cy: 0.208, wFrac: 0.57,
      aspect: 669 / 672, begin: 0.16, end: 0.5,
      child: _img('result_sun.png'),
    ),
    _piece(
      cx: 0.5, cy: 0.37, wFrac: 0.84,
      aspect: 240 / 990, begin: 0.32, end: 0.58,
      child: _img('result_banner.png'),
    ),
    // 失败 title centred on the ribbon band, sized to sit within its edges.
    _piece(
      cx: 0.5, cy: 0.3575, wFrac: 0.21,
      aspect: 160 / 300, begin: 0.44, end: 0.68,
      child: _img('result_lose_title.png'),
    ),
    _piece(
      cx: 0.5, cy: 0.641, wFrac: 0.361,
      aspect: 153 / 426, begin: 0.56, end: 0.76,
      child: _scorePlate('result_lose_num.png'),
    ),
    _piece(
      cx: 0.277, cy: 0.796, wFrac: 0.412,
      aspect: 177 / 486, begin: 0.66, end: 0.88,
      child: _exitButton(),
    ),
    _piece(
      cx: 0.725, cy: 0.796, wFrac: 0.412,
      aspect: 180 / 486, begin: 0.72, end: 0.94,
      child: _againButton(),
    ),
  ];
}

/// Result-screen button (退出 / 重来一局): textless base art + text overlay,
/// sized by height so both share the same glyph size, with a press-in scale.
class _ChessResultButton extends StatefulWidget {
  const _ChessResultButton({
    required this.base,
    required this.text,
    required this.onTap,
  });

  final String base;
  final String text;
  final VoidCallback onTap;

  @override
  State<_ChessResultButton> createState() => _ChessResultButtonState();
}

class _ChessResultButtonState extends State<_ChessResultButton> {
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
        scale: _pressed ? 0.92 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                '$_chessFigmaAsset${widget.base}',
                fit: BoxFit.fill,
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment: const Alignment(0, -0.02),
                child: FractionallySizedBox(
                  heightFactor: 0.4,
                  child: Image.asset(
                    '$_chessFigmaAsset${widget.text}',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
