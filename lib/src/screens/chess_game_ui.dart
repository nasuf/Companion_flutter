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

class _ChessGameScreen extends StatelessWidget {
  const _ChessGameScreen({
    required this.engine,
    required this.selectedSquare,
    required this.legalTargets,
    required this.agentName,
    required this.userName,
    required this.agentAvatarUrl,
    required this.userAvatarUrl,
    required this.aiThinking,
    required this.starting,
    required this.timerPaused,
    required this.enabled,
    required this.onSquareTap,
    required this.onRestart,
    required this.onExit,
    required this.onTimerPauseChanged,
  });

  final ChessFamilyEngine engine;
  final int? selectedSquare;
  final Set<int> legalTargets;
  final String agentName;
  final String userName;
  final String? agentAvatarUrl;
  final String? userAvatarUrl;
  final bool aiThinking;
  final bool starting;
  final bool timerPaused;
  final bool enabled;
  final ValueChanged<int> onSquareTap;
  final Future<void> Function() onRestart;
  final Future<void> Function() onExit;
  final ValueChanged<bool> onTimerPauseChanged;

  @override
  Widget build(BuildContext context) {
    final userTurn = enabled && !engine.isFinished;
    final agentTurn = !engine.isFinished && (engine.isAgentTurn || aiThinking);
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
              Positioned(
                left: width * (19 / 393),
                top: height * (98 / 852),
                width: width * (189 / 393),
                height: height * (64 / 852),
                child: _ChessPlayerPanel(
                  name: userName,
                  imageUrl: userAvatarUrl,
                  active: userTurn,
                ),
              ),
              Positioned(
                left: width * (222 / 393),
                top: height * (106 / 852),
                width: width * (101 / 393),
                height: height * (45 / 852),
                child: _ChessClockPlate(
                  token: token,
                  active: userTurn,
                  paused: timerPaused || !userTurn,
                ),
              ),
              Positioned(
                left: width * (197 / 393),
                top: height * (188 / 852),
                width: width * (185 / 393),
                height: height * (63 / 852),
                child: _ChessPlayerPanel(
                  name: agentName,
                  imageUrl: agentAvatarUrl,
                  active: agentTurn,
                  mirroredContent: true,
                ),
              ),
              Positioned(
                left: width * (84 / 393),
                top: height * (200 / 852),
                width: width * (101 / 393),
                height: height * (45 / 852),
                child: _ChessClockPlate(
                  token: token,
                  active: agentTurn,
                  paused: timerPaused || !agentTurn || aiThinking,
                ),
              ),
              Positioned(
                left: width * (19 / 393),
                top: height * (288 / 852),
                width: width * (355 / 393),
                height: height * (362 / 852),
                child: _ChessArtworkBoard(
                  engine: engine,
                  selectedSquare: selectedSquare,
                  legalTargets: legalTargets,
                  enabled: enabled,
                  onTap: onSquareTap,
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
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    onTimerPauseChanged(true);
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
              unawaited(onExit());
            },
          ),
        ),
      ],
    );
    onTimerPauseChanged(false);
  }

  Future<void> _showPause(BuildContext context) async {
    onTimerPauseChanged(true);
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
            label: starting ? '载入中' : '重开',
            enabled: !starting,
            onTap: () {
              Navigator.of(dialogContext).pop();
              unawaited(onRestart());
            },
          ),
        ),
      ],
    );
    onTimerPauseChanged(false);
  }
}

class _ChessPlayerPanel extends StatelessWidget {
  const _ChessPlayerPanel({
    required this.name,
    required this.imageUrl,
    required this.active,
    this.mirroredContent = false,
  });

  final String name;
  final String? imageUrl;
  final bool active;
  final bool mirroredContent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Transform.flip(
                flipX: mirroredContent,
                child: Image.asset(
                  '${_chessFigmaAsset}game_player_panel.png',
                  fit: BoxFit.fill,
                ),
              ),
            ),
            Positioned(
              left: width * ((mirroredContent ? 108 : 5) / 189),
              top: -height * (3 / 64),
              width: width * (70 / 189),
              height: width * (70 / 189),
              child: _ChessAvatar(
                name: name,
                imageUrl: imageUrl,
                active: active,
              ),
            ),
            Positioned(
              left: width * ((mirroredContent ? 5 : 65) / 189),
              top: height * (20 / 64),
              width: width * ((mirroredContent ? 110 : 115) / 189),
              height: height * (26 / 64),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFF71513C),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChessAvatar extends StatelessWidget {
  const _ChessAvatar({
    required this.name,
    required this.imageUrl,
    required this.active,
  });

  final String name;
  final String? imageUrl;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        return Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              width: size * 0.86,
              height: size * 0.86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: active
                    ? const [
                        BoxShadow(
                          color: Color(0xCCFFD279),
                          blurRadius: 18,
                          spreadRadius: 3,
                        ),
                      ]
                    : const [],
              ),
              child: ClipOval(
                child: _Avatar(
                  size: size * 0.86,
                  label: name.trim().isEmpty
                      ? '伴'
                      : name.trim().characters.first,
                  imageUrl: imageUrl,
                  gradient: const [Color(0xFFF4E4CA), Color(0xFFC49B6E)],
                ),
              ),
            ),
            Positioned.fill(
              child: Image.asset(
                '${_chessFigmaAsset}game_avatar_frame.png',
                fit: BoxFit.contain,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChessClockPlate extends StatelessWidget {
  const _ChessClockPlate({
    required this.token,
    required this.active,
    required this.paused,
  });

  final String token;
  final bool active;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: Image.asset(
            '${_chessFigmaAsset}game_nameplate.png',
            fit: BoxFit.fill,
          ),
        ),
        _ChessTurnClock(token: token, active: active, paused: paused),
      ],
    );
  }
}

class _ChessTurnClock extends StatefulWidget {
  const _ChessTurnClock({
    required this.token,
    required this.active,
    required this.paused,
  });

  final String token;
  final bool active;
  final bool paused;

  @override
  State<_ChessTurnClock> createState() => _ChessTurnClockState();
}

class _ChessTurnClockState extends State<_ChessTurnClock> {
  Timer? _timer;
  int _remaining = 90;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !widget.active || widget.paused || _remaining <= 0) {
        return;
      }
      setState(() => _remaining -= 1);
    });
  }

  @override
  void didUpdateWidget(covariant _ChessTurnClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token && widget.active) _remaining = 90;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _remaining ~/ 60;
    final seconds = (_remaining % 60).toString().padLeft(2, '0');
    return Text(
      '$minutes:$seconds',
      style: const TextStyle(
        color: Color(0xFFBC9B71),
        fontSize: 20,
        fontWeight: FontWeight.w900,
        decoration: TextDecoration.none,
      ),
    );
  }
}

class _ChessArtworkBoard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final geometry = _ChessArtworkGeometry(size);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: enabled
              ? (details) {
                  final square = geometry.squareAt(
                    details.localPosition,
                    engine,
                  );
                  if (square != null) onTap(square);
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
                    selectedSquare: selectedSquare,
                    legalTargets: legalTargets,
                  ),
                ),
              ),
              for (final piece in engine.pieces)
                Positioned.fromRect(
                  rect: geometry.pieceRect(piece),
                  child: IgnorePointer(
                    child: Image.asset(
                      _chessPieceAssetForArtwork(piece),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
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

  Rect pieceRect(ChessBoardPiece piece) {
    final cell = cellRect(piece.file, piece.rank);
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
  const _ChessModalButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
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
