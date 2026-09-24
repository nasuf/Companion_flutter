part of 'package:companion_flutter/main.dart';

class _ChineseCheckersBoard extends StatefulWidget {
  const _ChineseCheckersBoard({
    required this.engine,
    required this.lastMove,
    required this.selected,
    required this.targets,
    required this.onTap,
    this.figmaStyle = false,
  });
  final ChineseCheckersEngine engine;
  final ChineseCheckersMove? lastMove;
  final int? selected;
  final Map<int, List<int>> targets;
  final ValueChanged<int> onTap;
  final bool figmaStyle;

  @override
  State<_ChineseCheckersBoard> createState() => _ChineseCheckersBoardState();
}

class _ChineseCheckersBoardState extends State<_ChineseCheckersBoard>
    with TickerProviderStateMixin {
  late final AnimationController _targetPulse;
  late final AnimationController _moveController;

  @override
  void initState() {
    super.initState();
    _targetPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      value: 1,
    );
    if (widget.targets.isNotEmpty) {
      _targetPulse.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _ChineseCheckersBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targets.isEmpty && widget.targets.isNotEmpty) {
      _targetPulse.repeat(reverse: true);
    } else if (oldWidget.targets.isNotEmpty && widget.targets.isEmpty) {
      _targetPulse
        ..stop()
        ..value = 0;
    }
    if (oldWidget.lastMove?.number != widget.lastMove?.number &&
        widget.lastMove != null) {
      _moveController.duration = _checkersMoveDuration(widget.lastMove!);
      _moveController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _targetPulse.dispose();
    _moveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([_targetPulse, _moveController]),
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          if (!_moveController.isCompleted) return;
          final index = _nearest(details.localPosition, constraints.biggest);
          if (index != null) widget.onTap(index);
        },
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _ChineseCheckersPainter(
              board: widget.engine.board,
              lastMove: widget.lastMove,
              moveProgress: _moveController.value,
              selected: widget.selected,
              targets: widget.targets,
              pulse: _targetPulse.value,
              darkMode: AppColors.isDark(context),
              figmaStyle: widget.figmaStyle,
            ),
          ),
        ),
      ),
    ),
  );

  int? _nearest(Offset point, Size size) {
    final geometry = _checkersGeometry(size, figmaStyle: widget.figmaStyle);
    var nearest = -1;
    var distance = double.infinity;
    for (final cell in ChineseCheckersEngine.cells) {
      final value = (geometry.positions[cell.index] - point).distanceSquared;
      if (value < distance) {
        distance = value;
        nearest = cell.index;
      }
    }
    return distance <= math.pow(geometry.spacing * .5, 2) ? nearest : null;
  }
}

class _ChineseCheckersPainter extends CustomPainter {
  const _ChineseCheckersPainter({
    required this.board,
    required this.lastMove,
    required this.moveProgress,
    required this.selected,
    required this.targets,
    required this.pulse,
    required this.darkMode,
    this.figmaStyle = false,
  });
  final List<int> board;
  final ChineseCheckersMove? lastMove;
  final double moveProgress;
  final int? selected;
  final Map<int, List<int>> targets;
  final double pulse;
  final bool darkMode;
  final bool figmaStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stage = RRect.fromRectAndRadius(rect, const Radius.circular(20));
    canvas.save();
    // The hand-drawn board fills the box edge to edge; clipping would shave
    // the drop shadow off its top and bottom points.
    if (!figmaStyle) canvas.clipRRect(stage);
    final geometry = _checkersGeometry(size, figmaStyle: figmaStyle);
    final layout = geometry.positions;
    final slabRadius = geometry.outerRadius + geometry.spacing * 0.2;
    final slabRect = Rect.fromCircle(
      center: geometry.center,
      radius: slabRadius,
    );
    if (figmaStyle) {
      _paintFigmaBoard(canvas, geometry);
    } else {
      canvas.drawRRect(
        stage,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: darkMode
                ? const [Color(0xFF14272A), Color(0xFF091A1D)]
                : const [Color(0xFFE7F2EE), Color(0xFFD4E8E4)],
          ).createShader(rect),
      );
      canvas.drawCircle(
        geometry.center + Offset(0, geometry.spacing * 0.18),
        slabRadius,
        Paint()
          ..color = Colors.black.withValues(alpha: darkMode ? .34 : .2)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            geometry.spacing * .28,
          ),
      );
      canvas.drawCircle(
        geometry.center,
        slabRadius,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.34, -0.4),
            radius: 1.08,
            colors: [Color(0xFFF1CD91), Color(0xFFD39A5E), Color(0xFF8D5438)],
            stops: [0, 0.72, 1],
          ).createShader(slabRect),
      );
      canvas.save();
      canvas.clipPath(Path()..addOval(slabRect));
      final grainPaint = Paint()
        ..color = const Color(0xFF6D392B).withValues(alpha: .11)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.55, geometry.spacing * .035);
      for (var line = 0; line < 21; line += 1) {
        final y = slabRect.top + slabRect.height * (line + 0.5) / 21;
        final wave = math.sin(line * 1.41) * geometry.spacing * 0.32;
        canvas.drawPath(
          Path()
            ..moveTo(slabRect.left - 12, y)
            ..cubicTo(
              slabRect.left + slabRect.width * .28,
              y + wave,
              slabRect.left + slabRect.width * .7,
              y - wave,
              slabRect.right + 12,
              y + wave * 0.25,
            ),
          grainPaint,
        );
      }
      canvas.restore();
      canvas.drawCircle(
        geometry.center,
        slabRadius,
        Paint()
          ..color = const Color(0xFF70412F).withValues(alpha: 0.72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = geometry.spacing * 0.13,
      );
    }

    if (!figmaStyle) {
      final star = _checkersStarPath(
        geometry.center,
        geometry.outerRadius - geometry.spacing * 0.03,
      );
      canvas.drawPath(
        star,
        Paint()..color = const Color(0xFFFFE2AD).withValues(alpha: 0.13),
      );
      canvas.drawPath(
        star,
        Paint()
          ..color = const Color(0xFF744630).withValues(alpha: 0.38)
          ..style = PaintingStyle.stroke
          ..strokeWidth = geometry.spacing * 0.055,
      );
    }

    final holeRadius = geometry.spacing * (figmaStyle ? 0.335 : 0.215);
    const userColor = Color(0xFF36A9E8);
    const agentColor = Color(0xFFA642E8);
    if (figmaStyle) {
      _paintFigmaTrack(canvas, geometry);
      for (final cell in ChineseCheckersEngine.cells) {
        _paintFigmaCheckersHole(canvas, layout[cell.index], holeRadius);
      }
    } else {
      for (final cell in ChineseCheckersEngine.cells) {
        final center = layout[cell.index];
        final campColor = cell.row <= 3
            ? agentColor
            : cell.row >= 13
            ? userColor
            : const Color(0xFF57372A);
        canvas.drawCircle(
          center + Offset(0, holeRadius * 0.28),
          holeRadius * 1.16,
          Paint()..color = Colors.white.withValues(alpha: 0.22),
        );
        canvas.drawCircle(
          center,
          holeRadius * 1.08,
          Paint()
            ..shader =
                RadialGradient(
                  center: const Alignment(0.2, 0.28),
                  radius: 1.0,
                  colors: [
                    const Color(0xFF3E281F).withValues(alpha: 0.82),
                    campColor.withValues(
                      alpha: cell.row <= 3 || cell.row >= 13 ? 0.44 : 0.27,
                    ),
                  ],
                ).createShader(
                  Rect.fromCircle(center: center, radius: holeRadius * 1.08),
                ),
        );
      }
    }

    final jumpPaths = targets.values.where((path) => path.length > 2).toList();
    if (jumpPaths.isNotEmpty) {
      jumpPaths.sort((left, right) => right.length.compareTo(left.length));
      final path = Path()
        ..moveTo(
          layout[jumpPaths.first.first].dx,
          layout[jumpPaths.first.first].dy,
        );
      for (final index in jumpPaths.first.skip(1)) {
        path.lineTo(layout[index].dx, layout[index].dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color =
              (figmaStyle ? const Color(0xFFFFE7C4) : const Color(0xFF1F7566))
                  .withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = geometry.spacing * 0.065
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    for (final target in targets.keys) {
      final center = layout[target];
      if (figmaStyle) {
        // Warm glow that reads as light pooling inside the carved hole.
        canvas.drawCircle(
          center,
          holeRadius * (0.98 + pulse * 0.18),
          Paint()
            ..color = const Color(
              0xFFFFEFD2,
            ).withValues(alpha: 0.85 - pulse * 0.25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = geometry.spacing * 0.07,
        );
        canvas.drawCircle(
          center,
          holeRadius * 0.34,
          Paint()..color = const Color(0xFFFFF7E6).withValues(alpha: 0.92),
        );
        continue;
      }
      canvas.drawCircle(
        center,
        holeRadius * (1.38 + pulse * 0.22),
        Paint()
          ..color = const Color(
            0xFF187864,
          ).withValues(alpha: 0.78 - pulse * 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = geometry.spacing * 0.065,
      );
      canvas.drawCircle(
        center,
        holeRadius * 0.36,
        Paint()..color = const Color(0xFFE8FFF9).withValues(alpha: 0.9),
      );
    }

    if (lastMove != null && moveProgress < 1 && lastMove!.isJump) {
      final route = Path()
        ..moveTo(
          layout[lastMove!.path.first].dx,
          layout[lastMove!.path.first].dy,
        );
      for (final index in lastMove!.path.skip(1)) {
        route.lineTo(layout[index].dx, layout[index].dy);
      }
      final routeColor = lastMove!.actor == ChineseCheckersActor.user
          ? userColor
          : agentColor;
      canvas.drawPath(
        route,
        Paint()
          ..color = routeColor.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = geometry.spacing * 0.07
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      for (final index in lastMove!.path.skip(1)) {
        canvas.drawCircle(
          layout[index],
          holeRadius * 1.36,
          Paint()
            ..color = routeColor.withValues(alpha: 0.22)
            ..style = PaintingStyle.stroke
            ..strokeWidth = geometry.spacing * 0.05,
        );
      }
    }

    final pieceRadius = geometry.spacing * (figmaStyle ? 0.355 : 0.325);
    final hiddenDestination = moveProgress < 1 ? lastMove?.path.last : null;
    for (final cell in ChineseCheckersEngine.cells) {
      final center = layout[cell.index];
      final actor = board[cell.index];
      if (actor >= 0 && cell.index != hiddenDestination) {
        final color = actor == ChineseCheckersActor.user.index
            ? userColor
            : agentColor;
        _paintCheckersMarble(canvas, center, pieceRadius, color);
      }
      if (cell.index == selected) {
        canvas.drawCircle(
          center,
          pieceRadius * 1.4,
          Paint()
            ..color = figmaStyle
                ? const Color(0xFFFFE3A8)
                : const Color(0xFF176E60)
            ..style = PaintingStyle.stroke
            ..strokeWidth = geometry.spacing * 0.075,
        );
      }
    }

    if (lastMove != null && moveProgress < 1) {
      _paintMovingCheckersPiece(
        canvas,
        geometry,
        lastMove!,
        moveProgress,
        pieceRadius,
        lastMove!.actor == ChineseCheckersActor.user ? userColor : agentColor,
      );
    }
    canvas.restore();
  }

  /// Carved wooden star: outer bevel, dark groove, gold inner rim, playfield.
  void _paintFigmaBoard(Canvas canvas, _ChineseCheckersGeometry geometry) {
    final center = geometry.center;
    final tip = geometry.outerRadius;
    final bounds = Rect.fromCircle(center: center, radius: tip);
    final frame = _checkersHexagramPath(center, tip);

    canvas.drawPath(
      frame.shift(Offset(0, tip * 0.02)),
      Paint()
        ..color = const Color(0xFF33150A).withValues(alpha: 0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, tip * 0.035),
    );
    canvas.drawPath(
      frame,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF9A755),
            Color(0xFFD5823C),
            Color(0xFFA55123),
            Color(0xFF7C3009),
          ],
          stops: [0, 0.32, 0.8, 1],
        ).createShader(bounds),
    );
    canvas.drawPath(
      frame,
      Paint()
        ..color = const Color(0xFF5E2208).withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, tip * 0.007),
    );
    canvas.drawPath(
      _checkersHexagramPath(center, tip * _checkersFrameInner, rounding: 0.05),
      Paint()..color = const Color(0xFF8A3B0C),
    );
    canvas.drawPath(
      _checkersHexagramPath(center, tip * _checkersRingOuter, rounding: 0.05),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFDDA1), Color(0xFFFFC98A), Color(0xFFE79A54)],
          stops: [0, 0.55, 1],
        ).createShader(bounds),
    );
    canvas.drawPath(
      _checkersHexagramPath(center, tip * _checkersRingInner, rounding: 0.05),
      Paint()..color = const Color(0xFF8A3B0C),
    );
    canvas.drawPath(
      _checkersHexagramPath(center, tip * _checkersFieldEdge, rounding: 0.05),
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.42),
          radius: 1.16,
          colors: [Color(0xFFFFDCB0), Color(0xFFFCC28E), Color(0xFFE79E62)],
          stops: [0, 0.56, 1],
        ).createShader(bounds),
    );
  }

  /// Engraved groove that links the outermost holes into the classic star track.
  void _paintFigmaTrack(Canvas canvas, _ChineseCheckersGeometry geometry) {
    final track = _checkersHexagramPath(
      geometry.center,
      geometry.spacing * 4 * math.sqrt(3),
      rounding: 0.02,
    );
    canvas.drawPath(
      track.shift(Offset(0, geometry.spacing * 0.06)),
      Paint()
        ..color = const Color(0xFFFFE7C4).withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = geometry.spacing * 0.13,
    );
    canvas.drawPath(
      track,
      Paint()
        ..color = const Color(0xFFC1793F).withValues(alpha: 0.62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = geometry.spacing * 0.12,
    );
  }

  /// Drilled recess: the top wall falls into shadow, the bottom lip catches
  /// the light — same read as the carved holes in the reference artwork.
  void _paintFigmaCheckersHole(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center - Offset(0, radius * 0.08),
      radius * 1.12,
      Paint()..color = const Color(0xFFB06428).withValues(alpha: 0.38),
    );
    canvas.drawCircle(
      center + Offset(0, radius * 0.12),
      radius * 1.06,
      Paint()..color = const Color(0xFFFFDDB0),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6B2A05), Color(0xFF8E4113), Color(0xFFC87235)],
          stops: [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  void _paintCheckersMarble(
    Canvas canvas,
    Offset center,
    double radius,
    Color color, {
    double shadowScale = 1,
    Offset? shadowCenter,
  }) {
    canvas.drawOval(
      Rect.fromCenter(
        center:
            (shadowCenter ?? center) + Offset(0, radius * 0.48 * shadowScale),
        width: radius * 1.7,
        height: radius * 0.7,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3 / shadowScale)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.23),
    );
    canvas.drawCircle(
      center,
      radius * 1.04,
      Paint()..color = Color.lerp(color, Colors.black, 0.28)!,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.42, -0.48),
          radius: 1.05,
          colors: [
            Color.lerp(color, Colors.white, 0.52)!,
            color,
            Color.lerp(color, Colors.black, 0.25)!,
          ],
          stops: const [0, 0.5, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawCircle(
      center - Offset(radius * 0.3, radius * 0.35),
      radius * 0.18,
      Paint()..color = Colors.white.withValues(alpha: 0.78),
    );
  }

  void _paintMovingCheckersPiece(
    Canvas canvas,
    _ChineseCheckersGeometry geometry,
    ChineseCheckersMove move,
    double progress,
    double radius,
    Color color,
  ) {
    final segmentCount = math.max(1, move.path.length - 1);
    final scaled = (progress * segmentCount).clamp(
      0.0,
      segmentCount.toDouble(),
    );
    final segment = math.min(segmentCount - 1, scaled.floor());
    final local = (scaled - segment).clamp(0.0, 1.0);
    final eased = Curves.easeInOutCubic.transform(local);
    final from = geometry.positions[move.path[segment]];
    final to = geometry.positions[move.path[segment + 1]];
    final ground = Offset.lerp(from, to, eased)!;
    final lift =
        math.sin(math.pi * local) *
        geometry.spacing *
        (move.isJump ? 0.4 : 0.16);
    final center = ground - Offset(0, lift);
    _paintCheckersMarble(
      canvas,
      center,
      radius * (1 + math.sin(math.pi * local) * 0.06),
      color,
      shadowScale: 1 + lift / geometry.spacing,
      shadowCenter: ground,
    );
  }

  @override
  bool shouldRepaint(covariant _ChineseCheckersPainter oldDelegate) =>
      oldDelegate.board != board ||
      oldDelegate.lastMove?.number != lastMove?.number ||
      oldDelegate.moveProgress != moveProgress ||
      oldDelegate.selected != selected ||
      oldDelegate.targets != targets ||
      oldDelegate.pulse != pulse ||
      oldDelegate.darkMode != darkMode ||
      oldDelegate.figmaStyle != figmaStyle;
}

Duration _checkersMoveDuration(ChineseCheckersMove move) {
  final segments = math.max(1, move.path.length - 1);
  final milliseconds = move.isJump
      ? (segments * 300).clamp(480, 1500).toInt()
      : 420;
  return Duration(milliseconds: milliseconds);
}

class _ChineseCheckersGeometry {
  const _ChineseCheckersGeometry({
    required this.positions,
    required this.spacing,
    required this.center,
    required this.outerRadius,
  });

  final List<Offset> positions;
  final double spacing;
  final Offset center;
  final double outerRadius;
}

/// Star tip radius of the hand-drawn board, expressed in hole-spacing units.
///
/// The 121 holes span 8 lattice rows from the centre to a tip, so the outer
/// artwork has to sit a little beyond `8 * sqrt(3) / 2 == 6.93` spacings.
/// Sized so the outermost holes clear the carved rim by ~3px on a phone board.
const double _checkersTipUnits = 8.78;

/// Radial fractions of the tip radius where each carved band of the board ends.
const double _checkersFrameInner = 0.954;
const double _checkersRingOuter = 0.947;
const double _checkersRingInner = 0.905;
const double _checkersFieldEdge = 0.898;

_ChineseCheckersGeometry _checkersGeometry(
  Size size, {
  bool figmaStyle = false,
}) {
  if (figmaStyle) {
    // Regular hexagram lattice. Both the artwork and the playable holes are
    // derived from this single spacing, so a marble can never drift off a hole.
    final spacing = math.min(
      size.width / (math.sqrt(3) * _checkersTipUnits),
      size.height / (2 * _checkersTipUnits),
    );
    final xUnit = spacing / 2;
    final yUnit = spacing * math.sqrt(3) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    return _ChineseCheckersGeometry(
      positions: [
        for (final cell in ChineseCheckersEngine.cells)
          center + Offset(cell.x * xUnit, (cell.row - 8) * yUnit),
      ],
      spacing: spacing,
      center: center,
      outerRadius: spacing * _checkersTipUnits,
    );
  }
  final inset = size.shortestSide * .055;
  const rows = 16;
  const horizontalSteps = 12.0;
  final verticalSteps = rows * math.sqrt(3) / 2;
  final spacing = math.min(
    (size.width - inset * 2) / (horizontalSteps + 1.4),
    (size.height - inset * 2) / (verticalSteps + 1.4),
  );
  final xUnit = spacing / 2;
  final yUnit = spacing * math.sqrt(3) / 2;
  final centerX = size.width / 2;
  final top = (size.height - yUnit * rows) / 2;
  final positions = [
    for (final cell in ChineseCheckersEngine.cells)
      Offset(centerX + cell.x * xUnit, top + cell.row * yUnit),
  ];
  final center = Offset(centerX, top + yUnit * rows / 2);
  return _ChineseCheckersGeometry(
    positions: positions,
    spacing: spacing,
    center: center,
    outerRadius: yUnit * rows / 2 + spacing * .68,
  );
}

Path _checkersStarPath(Offset center, double radius) {
  final path = Path();
  for (var point = 0; point < 12; point += 1) {
    final angle = -math.pi / 2 + point * math.pi / 6;
    final distance = point.isEven ? radius : radius * .5;
    final position =
        center + Offset(math.cos(angle), math.sin(angle)) * distance;
    if (point == 0) {
      path.moveTo(position.dx, position.dy);
    } else {
      path.lineTo(position.dx, position.dy);
    }
  }
  return path..close();
}

/// Regular six-pointed star with softened corners, matching the carved wooden
/// board artwork. [rounding] is the corner radius as a fraction of [radius].
Path _checkersHexagramPath(
  Offset center,
  double radius, {
  double rounding = 0.055,
}) {
  if (radius <= 0) return Path();
  final innerRadius = radius / math.sqrt(3);
  final vertices = [
    for (var point = 0; point < 12; point += 1)
      center +
          Offset.fromDirection(
            -math.pi / 2 + point * math.pi / 6,
            point.isEven ? radius : innerRadius,
          ),
  ];
  final corner = radius * rounding;
  final path = Path();
  for (var index = 0; index < vertices.length; index += 1) {
    final vertex = vertices[index];
    final toPrevious = vertices[(index + 11) % 12] - vertex;
    final toNext = vertices[(index + 1) % 12] - vertex;
    final entry =
        vertex +
        toPrevious /
            toPrevious.distance *
            math.min(corner, toPrevious.distance / 2);
    final exit =
        vertex +
        toNext / toNext.distance * math.min(corner, toNext.distance / 2);
    if (index == 0) {
      path.moveTo(entry.dx, entry.dy);
    } else {
      path.lineTo(entry.dx, entry.dy);
    }
    path.quadraticBezierTo(vertex.dx, vertex.dy, exit.dx, exit.dy);
  }
  return path..close();
}
