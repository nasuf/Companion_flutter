part of 'package:companion_flutter/main.dart';

class _GomokuBoard extends StatefulWidget {
  const _GomokuBoard({
    required this.engine,
    required this.enabled,
    required this.onPointTap,
  });

  final GomokuEngine engine;
  final bool enabled;
  final ValueChanged<GomokuPoint> onPointTap;

  @override
  State<_GomokuBoard> createState() => _GomokuBoardState();
}

class _GomokuBoardState extends State<_GomokuBoard>
    with TickerProviderStateMixin {
  late final AnimationController _placement;
  late int _lastMoveCount;
  GomokuPoint? _previewPoint;

  @override
  void initState() {
    super.initState();
    _placement = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: 1,
    );
    _lastMoveCount = widget.engine.moves.length;
  }

  @override
  void didUpdateWidget(covariant _GomokuBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_lastMoveCount != widget.engine.moves.length) {
      _lastMoveCount = widget.engine.moves.length;
      _placement.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _placement.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final geometry = _GomokuBoardGeometry(size);
        return AnimatedBuilder(
          animation: _placement,
          builder: (context, _) {
            final progress = Curves.easeOutBack.transform(_placement.value);
            final lastMove = widget.engine.moves.isEmpty
                ? null
                : widget.engine.moves.last.point;
            final preview =
                _previewPoint != null &&
                    widget.engine.board[_previewPoint!.row][_previewPoint!
                            .col] ==
                        GomokuStone.empty
                ? _previewPoint
                : null;
            return Semantics(
              label: '十五乘十五五子棋棋盘',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: widget.enabled
                    ? (details) => setState(() {
                        _previewPoint = _pointForOffset(
                          details.localPosition,
                          geometry,
                        );
                      })
                    : null,
                onTapCancel: widget.enabled
                    ? () => setState(() => _previewPoint = null)
                    : null,
                onTapUp: widget.enabled
                    ? (details) {
                        final point = _pointForOffset(
                          details.localPosition,
                          geometry,
                        );
                        setState(() => _previewPoint = null);
                        if (point != null) widget.onPointTap(point);
                      }
                    : null,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _GomokuBoardPainter(
                          previewPoint: preview,
                          winningLine: widget.engine.winningLine,
                          placementProgress: progress,
                        ),
                      ),
                    ),
                    for (var row = 0; row < GomokuEngine.boardSize; row += 1)
                      for (var col = 0; col < GomokuEngine.boardSize; col += 1)
                        if (widget.engine.board[row][col] != GomokuStone.empty)
                          _GomokuStoneSprite(
                            point: GomokuPoint(row, col),
                            stone: widget.engine.board[row][col],
                            geometry: geometry,
                            scale: lastMove == GomokuPoint(row, col)
                                ? progress.clamp(0.05, 1.08)
                                : 1,
                          ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  GomokuPoint? _pointForOffset(Offset offset, _GomokuBoardGeometry geometry) {
    final col = ((offset.dx - geometry.left) / geometry.cellWidth).round();
    final row = ((offset.dy - geometry.top) / geometry.cellHeight).round();
    if (row < 0 ||
        row >= GomokuEngine.boardSize ||
        col < 0 ||
        col >= GomokuEngine.boardSize) {
      return null;
    }
    final center = geometry.offset(GomokuPoint(row, col));
    if ((center - offset).distance > geometry.stoneSize * 0.62) return null;
    return GomokuPoint(row, col);
  }
}

/// Grid bounds measured from the exported 1050×1113 Figma board artwork.
class _GomokuBoardGeometry {
  const _GomokuBoardGeometry(this.size);

  final Size size;

  double get left => size.width * (46 / 1050);
  double get right => size.width * (1006 / 1050);
  double get top => size.height * (42 / 1113);
  double get bottom => size.height * (1041 / 1113);
  double get cellWidth => (right - left) / (GomokuEngine.boardSize - 1);
  double get cellHeight => (bottom - top) / (GomokuEngine.boardSize - 1);
  double get stoneSize => math.min(cellWidth, cellHeight) * 0.9;

  Offset offset(GomokuPoint point) =>
      Offset(left + point.col * cellWidth, top + point.row * cellHeight);
}

class _GomokuStoneSprite extends StatelessWidget {
  const _GomokuStoneSprite({
    required this.point,
    required this.stone,
    required this.geometry,
    required this.scale,
  });

  final GomokuPoint point;
  final GomokuStone stone;
  final _GomokuBoardGeometry geometry;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final diameter = geometry.stoneSize;
    final center = geometry.offset(point);
    final asset = stone == GomokuStone.black
        ? '${_gomokuHomeAsset}game_stone_black.svg'
        : '${_gomokuHomeAsset}game_stone_white.svg';
    return Positioned(
      left: center.dx - diameter / 2,
      top: center.dy - diameter / 2,
      width: diameter,
      height: diameter,
      child: Transform.scale(
        scale: scale,
        child: SvgPicture.asset(asset, fit: BoxFit.contain),
      ),
    );
  }
}

class _GomokuBoardPainter extends CustomPainter {
  const _GomokuBoardPainter({
    required this.previewPoint,
    required this.winningLine,
    required this.placementProgress,
  });

  final GomokuPoint? previewPoint;
  final List<GomokuPoint> winningLine;
  final double placementProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _GomokuBoardGeometry(size);
    final gridRect = Rect.fromLTRB(
      geometry.left,
      geometry.top,
      geometry.right,
      geometry.bottom,
    );

    // Vignette: the board wood darkens toward the edges/corners (design 2:3).
    canvas.drawRect(
      gridRect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment.center,
          radius: 0.82,
          colors: [
            Color(0x00000000),
            Color(0x00000000),
            Color(0x3D4A240F),
          ],
          stops: [0.0, 0.5, 1.0],
        ).createShader(gridRect),
    );

    // Thin interior grid lines (the outer edges are drawn by the bold border).
    final line = Paint()
      ..color = const Color(0xFF5A2D16).withValues(alpha: 0.85)
      ..strokeWidth = math.max(0.8, size.width * (2.1 / 1050));
    for (var i = 1; i < GomokuEngine.boardSize - 1; i += 1) {
      final x = geometry.left + i * geometry.cellWidth;
      final y = geometry.top + i * geometry.cellHeight;
      canvas.drawLine(Offset(geometry.left, y), Offset(geometry.right, y), line);
      canvas.drawLine(Offset(x, geometry.top), Offset(x, geometry.bottom), line);
    }

    // Bold outer border framing the 15x15 grid.
    canvas.drawRect(
      gridRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.4, size.width * (6 / 1050))
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF4A2410),
    );

    if (previewPoint != null) {
      final center = geometry.offset(previewPoint!);
      canvas.drawCircle(
        center,
        geometry.stoneSize * 0.46,
        Paint()..color = const Color(0xFF292828).withValues(alpha: 0.28),
      );
      canvas.drawCircle(
        center,
        geometry.stoneSize * 0.50,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    if (winningLine.length >= 2) {
      final winPaint = Paint()
        ..color = const Color(0xFFFFD56A).withValues(alpha: 0.74)
        ..strokeWidth = geometry.stoneSize * 0.28
        ..strokeCap = StrokeCap.round;
      final start = geometry.offset(winningLine.first);
      final end = geometry.offset(winningLine.last);
      canvas.drawLine(
        start,
        Offset.lerp(start, end, placementProgress.clamp(0, 1))!,
        winPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GomokuBoardPainter oldDelegate) =>
      oldDelegate.previewPoint != previewPoint ||
      oldDelegate.winningLine != winningLine ||
      oldDelegate.placementProgress != placementProgress;
}

class _GomokuNotice extends StatelessWidget {
  const _GomokuNotice({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFD84A4A) : const Color(0xFFB8791D);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          height: 1.3,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
