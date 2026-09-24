part of 'package:companion_flutter/main.dart';

class _Match3MissionBar extends StatelessWidget {
  const _Match3MissionBar({
    required this.score,
    required this.target,
    required this.movesRemaining,
  });

  final int score;
  final int target;
  final int movesRemaining;

  @override
  Widget build(BuildContext context) {
    final progress = (score / target).clamp(0.0, 1.0);
    return Column(
      children: [
        Row(
          children: [
            Text(
              '共同能量',
              style: TextStyle(
                color: AppColors.text.withValues(alpha: .62),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              '$score / $target',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        LayoutBuilder(
          builder: (context, constraints) => Container(
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFF12263E).withValues(alpha: .12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.text.withValues(alpha: .06)),
            ),
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeOutCubic,
              width: constraints.maxWidth * progress,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF28C987),
                    Color(0xFF53B9FF),
                    Color(0xFFA16EFF),
                  ],
                ),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF53B9FF).withValues(alpha: .28),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.arrow_2_squarepath,
              size: 12,
              color: AppColors.text.withValues(alpha: .42),
            ),
            const SizedBox(width: 5),
            Text(
              '还剩 $movesRemaining 次交换',
              style: TextStyle(
                color: AppColors.text.withValues(alpha: .48),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Match3Board extends StatefulWidget {
  const _Match3Board({
    required this.engine,
    required this.lastTurn,
    required this.thinking,
    required this.enabled,
    required this.onSwap,
  });

  final Match3Engine engine;
  final Match3Turn? lastTurn;
  final bool thinking;
  final bool enabled;
  final Future<void> Function(Match3Swap) onSwap;

  @override
  State<_Match3Board> createState() => _Match3BoardState();
}

class _Match3BoardState extends State<_Match3Board>
    with TickerProviderStateMixin {
  late final AnimationController _ambient;
  late final AnimationController _resolve;
  late final AnimationController _gesture;
  Match3Point? _dragOrigin;
  Offset? _dragStartPosition;
  Match3Swap? _gestureSwap;
  Animation<double>? _gestureAnimation;
  double _dragProgress = 0;
  bool _gestureInvalid = false;
  bool _gestureSettling = false;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
    if (widget.thinking) _ambient.repeat();
    _resolve = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
      value: 1,
    );
    _gesture = AnimationController(vsync: this, value: 1);
  }

  @override
  void didUpdateWidget(covariant _Match3Board oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lastTurn?.number != widget.lastTurn?.number &&
        widget.lastTurn != null) {
      _resolve.duration = _match3TurnAnimationDuration(widget.lastTurn!);
      _resolve.forward(from: _match3ResolveStart(widget.lastTurn!));
    }
    if (oldWidget.thinking != widget.thinking) {
      if (widget.thinking) {
        _ambient.repeat();
      } else {
        _ambient
          ..stop()
          ..value = 0;
      }
    }
  }

  @override
  void dispose() {
    _ambient.dispose();
    _resolve.dispose();
    _gesture.dispose();
    super.dispose();
  }

  bool get _canInteract =>
      widget.enabled && _resolve.isCompleted && !_gestureSettling;

  double get _gestureProgress => _gestureAnimation?.value ?? _dragProgress;

  void _handlePanDown(DragDownDetails details, _Match3BoardGeometry geometry) {
    if (!_canInteract) return;
    final origin = geometry.pointAt(details.localPosition);
    if (origin == null) return;
    _gesture.stop();
    setState(() {
      _dragOrigin = origin;
      _dragStartPosition = details.localPosition;
      _gestureSwap = null;
      _gestureAnimation = null;
      _dragProgress = 0;
      _gestureInvalid = false;
    });
  }

  void _handlePanUpdate(
    DragUpdateDetails details,
    _Match3BoardGeometry geometry,
  ) {
    final origin = _dragOrigin;
    final start = _dragStartPosition;
    if (!_canInteract || origin == null || start == null) return;
    final delta = details.localPosition - start;
    final swap = geometry.swapFromDrag(origin, delta);
    if (swap == null) {
      setState(() {
        _gestureSwap = null;
        _dragProgress = 0;
        _gestureInvalid = false;
      });
      return;
    }
    final travel = (swap.a.row == swap.b.row ? delta.dx.abs() : delta.dy.abs());
    final previous = _gestureSwap;
    final directionChanged = previous?.a != swap.a || previous?.b != swap.b;
    final invalid = directionChanged
        ? !widget.engine.isLegalSwap(swap)
        : _gestureInvalid;
    setState(() {
      _gestureSwap = swap;
      _dragProgress = (travel / geometry.stride).clamp(0.0, 0.86);
      _gestureInvalid = invalid;
    });
  }

  void _handlePanEnd() {
    final swap = _gestureSwap;
    if (swap == null || _dragProgress < 0.24) {
      unawaited(_settleGesture(commit: false, rejected: false));
    } else if (_gestureInvalid) {
      unawaited(_settleGesture(commit: false, rejected: true));
    } else {
      unawaited(_settleGesture(commit: true, rejected: false));
    }
  }

  Future<void> _settleGesture({
    required bool commit,
    required bool rejected,
  }) async {
    final swap = _gestureSwap;
    final from = _dragProgress;
    if (swap == null) {
      _clearGesture();
      return;
    }
    _gesture
      ..stop()
      ..value = 0
      ..duration = Duration(
        milliseconds: commit
            ? 135
            : rejected
            ? 250
            : 150,
      );
    final Animation<double> animation;
    if (rejected) {
      final peak = math.max(from, 0.46);
      animation = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(
            begin: from,
            end: peak,
          ).chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: 34,
        ),
        TweenSequenceItem(
          tween: Tween(
            begin: peak,
            end: 0.0,
          ).chain(CurveTween(curve: Curves.easeOutBack)),
          weight: 66,
        ),
      ]).animate(_gesture);
      _NativeGameHaptics.rejected();
    } else {
      animation = Tween(begin: from, end: commit ? 1.0 : 0.0).animate(
        CurvedAnimation(
          parent: _gesture,
          curve: commit ? Curves.easeOutCubic : Curves.easeOutBack,
        ),
      );
    }
    setState(() {
      _gestureAnimation = animation;
      _gestureSettling = true;
      _gestureInvalid = rejected;
    });
    try {
      await _gesture.forward().orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted) return;
    _clearGesture();
    if (commit) {
      await widget.onSwap(swap);
    }
  }

  void _clearGesture() {
    if (!mounted) return;
    setState(() {
      _dragOrigin = null;
      _dragStartPosition = null;
      _gestureSwap = null;
      _gestureAnimation = null;
      _dragProgress = 0;
      _gestureInvalid = false;
      _gestureSettling = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '怪物消消乐棋盘，向上下左右滑动怪物来交换相邻位置',
      child: AnimatedBuilder(
        animation: Listenable.merge([_ambient, _resolve, _gesture]),
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            final geometry = _Match3BoardGeometry(size);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanDown: (details) => _handlePanDown(details, geometry),
              onPanUpdate: (details) => _handlePanUpdate(details, geometry),
              onPanEnd: (_) => _handlePanEnd(),
              onPanCancel: () =>
                  unawaited(_settleGesture(commit: false, rejected: false)),
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _Match3BoardPainter(
                    board: widget.engine.board,
                    stateHash: widget.engine.stateHash,
                    gestureOrigin: _dragOrigin,
                    gestureSwap: _gestureSwap,
                    gestureProgress: _gestureProgress,
                    gestureInvalid: _gestureInvalid,
                    lastTurn: widget.lastTurn,
                    thinking: widget.thinking,
                    ambient: _ambient.value,
                    resolve: _resolve.value,
                    geometry: geometry,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Match3BoardGeometry {
  _Match3BoardGeometry(Size size)
    : boardRect = Offset.zero & size,
      gap = size.shortestSide * .008,
      padding = size.shortestSide * .025 {
    tileSize = math.min(
      (size.width - padding * 2 - gap * (Match3Engine.size - 1)) /
          Match3Engine.size,
      (size.height - padding * 2 - gap * (Match3Engine.size - 1)) /
          Match3Engine.size,
    );
    final gridSide =
        tileSize * Match3Engine.size + gap * (Match3Engine.size - 1);
    gridOrigin = Offset(
      (size.width - gridSide) / 2,
      (size.height - gridSide) / 2,
    );
  }

  final Rect boardRect;
  final double gap;
  final double padding;
  late final double tileSize;
  late final Offset gridOrigin;

  Rect rectFor(int index) {
    final row = index ~/ Match3Engine.size;
    final col = index % Match3Engine.size;
    return Rect.fromLTWH(
      gridOrigin.dx + col * (tileSize + gap),
      gridOrigin.dy + row * (tileSize + gap),
      tileSize,
      tileSize,
    );
  }

  Match3Point? pointAt(Offset position) {
    for (
      var index = 0;
      index < Match3Engine.size * Match3Engine.size;
      index++
    ) {
      if (rectFor(index).inflate(gap / 2).contains(position)) {
        return Match3Point(
          index ~/ Match3Engine.size,
          index % Match3Engine.size,
        );
      }
    }
    return null;
  }

  double get stride => tileSize + gap;

  Match3Swap? swapFromDrag(Match3Point origin, Offset delta) {
    if (math.max(delta.dx.abs(), delta.dy.abs()) < tileSize * 0.08) {
      return null;
    }
    final horizontal = delta.dx.abs() > delta.dy.abs();
    final row = origin.row + (horizontal ? 0 : delta.dy.sign.toInt());
    final col = origin.col + (horizontal ? delta.dx.sign.toInt() : 0);
    if (row < 0 ||
        row >= Match3Engine.size ||
        col < 0 ||
        col >= Match3Engine.size) {
      return null;
    }
    return Match3Swap(origin, Match3Point(row, col));
  }
}

class _Match3Presentation {
  const _Match3Presentation({
    required this.board,
    this.swap,
    this.swapProgress = 1,
    this.clearing = const {},
    this.clearProgress = 1,
    this.dropRows = const {},
    this.dropProgress = 1,
    this.cascadeIndex = 0,
    this.cascadeScore = 0,
    this.cascadeAnchor,
    this.cascadeProgress = 1,
  });

  final List<Match3Tile> board;
  final Match3Swap? swap;
  final double swapProgress;
  final Set<int> clearing;
  final double clearProgress;
  final Map<int, double> dropRows;
  final double dropProgress;
  final int cascadeIndex;
  final int cascadeScore;
  final int? cascadeAnchor;
  final double cascadeProgress;
}

const double _match3SwapUnits = .34;

Duration _match3TurnAnimationDuration(Match3Turn turn) =>
    Duration(milliseconds: 300 + turn.cascades.length * 620);

double _match3ResolveStart(Match3Turn turn) {
  if (turn.actor != Match3Actor.user || turn.cascades.isEmpty) return 0;
  return _match3SwapUnits / (_match3SwapUnits + turn.cascades.length);
}

Duration _match3RemainingAnimationDuration(Match3Turn turn) {
  final fullDuration = _match3TurnAnimationDuration(turn);
  final remaining = 1 - _match3ResolveStart(turn);
  return Duration(
    milliseconds: (fullDuration.inMilliseconds * remaining).round(),
  );
}

_Match3Presentation _match3Presentation(
  List<Match3Tile> finalBoard,
  Match3Turn? turn,
  double progress,
) {
  if (turn == null || progress >= 1 || turn.cascades.isEmpty) {
    return _Match3Presentation(board: finalBoard);
  }
  final totalUnits = _match3SwapUnits + turn.cascades.length;
  final position = progress * totalUnits;
  if (position < _match3SwapUnits) {
    return _Match3Presentation(
      board: turn.boardBefore,
      swap: turn.swap,
      swapProgress: Curves.easeInOutCubic.transform(
        position / _match3SwapUnits,
      ),
    );
  }
  final cascadePosition = position - _match3SwapUnits;
  final waveIndex = math.min(turn.cascades.length - 1, cascadePosition.floor());
  final local = cascadePosition - waveIndex;
  final wave = turn.cascades[waveIndex];
  final anchor = _match3CascadeAnchor(wave.cleared);
  if (local < .43) {
    return _Match3Presentation(
      board: wave.boardBefore,
      clearing: {for (final point in wave.cleared) point.index},
      clearProgress: Curves.easeInCubic.transform(local / .43),
      dropProgress: 0,
      cascadeIndex: wave.index,
      cascadeScore: wave.score,
      cascadeAnchor: anchor,
      cascadeProgress: local,
    );
  }
  return _Match3Presentation(
    board: wave.boardAfter,
    dropRows: _match3DropRows(wave.boardAfterClear),
    dropProgress: Curves.easeOutBack.transform((local - .43) / .57),
    cascadeIndex: wave.index,
    cascadeScore: wave.score,
    cascadeAnchor: anchor,
    cascadeProgress: local,
  );
}

int? _match3CascadeAnchor(List<Match3Point> points) {
  if (points.isEmpty) return null;
  final averageRow =
      points.fold<double>(0, (sum, point) => sum + point.row) / points.length;
  final averageCol =
      points.fold<double>(0, (sum, point) => sum + point.col) / points.length;
  Match3Point nearest = points.first;
  var nearestDistance = double.infinity;
  for (final point in points) {
    final rowDistance = point.row - averageRow;
    final colDistance = point.col - averageCol;
    final distance = rowDistance * rowDistance + colDistance * colDistance;
    if (distance < nearestDistance) {
      nearest = point;
      nearestDistance = distance;
    }
  }
  return nearest.index;
}

Map<int, double> _match3DropRows(List<Match3Tile> boardAfterClear) {
  final result = <int, double>{};
  for (var col = 0; col < Match3Engine.size; col++) {
    final sourceRows = <int>[];
    for (var row = Match3Engine.size - 1; row >= 0; row--) {
      if (boardAfterClear[row * Match3Engine.size + col].color >= 0) {
        sourceRows.add(row);
      }
    }
    for (
      var destination = Match3Engine.size - 1, item = 0;
      destination >= 0;
      destination--, item++
    ) {
      final source = item < sourceRows.length
          ? sourceRows[item]
          : -(item - sourceRows.length + 1);
      result[destination * Match3Engine.size + col] = (destination - source)
          .toDouble();
    }
  }
  return result;
}

class _Match3BoardPainter extends CustomPainter {
  const _Match3BoardPainter({
    required this.board,
    required this.stateHash,
    required this.gestureOrigin,
    required this.gestureSwap,
    required this.gestureProgress,
    required this.gestureInvalid,
    required this.lastTurn,
    required this.thinking,
    required this.ambient,
    required this.resolve,
    required this.geometry,
  });

  final List<Match3Tile> board;
  final int stateHash;
  final Match3Point? gestureOrigin;
  final Match3Swap? gestureSwap;
  final double gestureProgress;
  final bool gestureInvalid;
  final Match3Turn? lastTurn;
  final bool thinking;
  final double ambient;
  final double resolve;
  final _Match3BoardGeometry geometry;

  static const _colors = [
    Color(0xFFFF5F72),
    Color(0xFFFFB43C),
    Color(0xFF39D58B),
    Color(0xFF3CAAF5),
    Color(0xFF9968FF),
    Color(0xFFFF72C6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = geometry.boardRect;
    final boardShape = RRect.fromRectAndRadius(
      bounds,
      Radius.circular(size.shortestSide * .055),
    );
    canvas.save();
    canvas.clipRRect(boardShape);
    canvas.drawRRect(
      boardShape,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF172F4B), Color(0xFF0A182A), Color(0xFF14243A)],
          stops: [0, .58, 1],
        ).createShader(bounds),
    );
    _paintBoardAtmosphere(canvas, bounds);
    final presentation = _match3Presentation(board, lastTurn, resolve);

    for (var index = 0; index < presentation.board.length; index++) {
      final rect = geometry.rectFor(index);
      final cavity = RRect.fromRectAndRadius(
        rect,
        Radius.circular(geometry.tileSize * .25),
      );
      canvas.drawRRect(
        cavity,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.black.withValues(alpha: .34),
              const Color(0xFF2A4561).withValues(alpha: .2),
            ],
          ).createShader(rect),
      );
      canvas.drawRRect(
        cavity,
        Paint()
          ..color = Colors.white.withValues(alpha: .055)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(.65, geometry.tileSize * .018),
      );
    }

    final paintOrder = List<int>.generate(
      presentation.board.length,
      (index) => index,
    );
    final originIndex = gestureOrigin?.index;
    if (originIndex != null &&
        presentation.swap == null &&
        paintOrder.remove(originIndex)) {
      paintOrder.add(originIndex);
    }

    for (final index in paintOrder) {
      final rect = geometry.rectFor(index);
      final phase = ambient * math.pi * 2 + index * .79;
      final bob = thinking ? math.sin(phase) * geometry.tileSize * .012 : 0.0;
      var tileRect = rect;
      var interactionScale = 1.0;
      final swap = presentation.swap;
      if (swap != null) {
        if (index == swap.a.index) {
          final targetCenter = geometry.rectFor(swap.b.index).center;
          tileRect = rect.shift(
            (targetCenter - rect.center) * presentation.swapProgress,
          );
        } else if (index == swap.b.index) {
          final targetCenter = geometry.rectFor(swap.a.index).center;
          tileRect = rect.shift(
            (targetCenter - rect.center) * presentation.swapProgress,
          );
        }
      } else {
        final gesture = gestureSwap;
        if (gesture != null && index == gesture.a.index) {
          final targetCenter = geometry.rectFor(gesture.b.index).center;
          tileRect = rect.shift((targetCenter - rect.center) * gestureProgress);
          interactionScale = 1.035;
        } else if (gesture != null && index == gesture.b.index) {
          final originCenter = geometry.rectFor(gesture.a.index).center;
          tileRect = rect.shift((originCenter - rect.center) * gestureProgress);
          interactionScale = 1 - gestureProgress * .035;
        } else if (index == originIndex) {
          interactionScale = .96;
        }
      }
      if (presentation.dropProgress < 1) {
        final rows = presentation.dropRows[index] ?? 0;
        tileRect = tileRect.shift(
          Offset(0, -geometry.stride * rows * (1 - presentation.dropProgress)),
        );
      }
      final clearing = presentation.clearing.contains(index);
      final disappearScale = clearing
          ? math.max(0.0, 1 - presentation.clearProgress)
          : 1.0;
      canvas.save();
      canvas.translate(tileRect.center.dx, tileRect.center.dy + bob);
      canvas.scale(interactionScale * disappearScale);
      canvas.translate(-tileRect.center.dx, -tileRect.center.dy);
      final tile = presentation.board[index];
      if (tile.color >= 0 && disappearScale > .03) {
        _paintMonster(canvas, tileRect.deflate(geometry.tileSize * .055), tile);
      }
      canvas.restore();
      if (clearing && presentation.clearProgress > .18) {
        _paintClearSparkles(
          canvas,
          rect.center,
          index,
          presentation.clearProgress,
        );
      }
    }

    if (presentation.swap == null && gestureSwap != null) {
      _paintGestureTarget(canvas, gestureSwap!.b.index);
    }

    if (presentation.cascadeAnchor != null) {
      _paintCascadeFeedback(canvas, presentation);
    }

    canvas.drawRRect(
      boardShape.deflate(1),
      Paint()
        ..color = Colors.white.withValues(alpha: .14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.restore();
  }

  void _paintBoardAtmosphere(Canvas canvas, Rect bounds) {
    final glow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF4AAEFF).withValues(alpha: .16),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(bounds.width * .72, bounds.height * .12),
              radius: bounds.width * .56,
            ),
          );
    canvas.drawRect(bounds, glow);
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: .08);
    for (var i = 0; i < 18; i++) {
      final x = (i * 73 % 101) / 101 * bounds.width;
      final y = (i * 47 % 97) / 97 * bounds.height;
      final pulse = .65 + .35 * math.sin(ambient * math.pi * 2 + i);
      canvas.drawCircle(Offset(x, y), 1.1 * pulse, dotPaint);
    }
  }

  void _paintMonster(Canvas canvas, Rect rect, Match3Tile tile) {
    final base = _colors[tile.color];
    final center = rect.center;
    final bodyRect = Rect.fromCenter(
      center: center + Offset(0, rect.height * .035),
      width: rect.width * .82,
      height: rect.height * .76,
    );
    final bodyPath = _monsterBodyPath(bodyRect, tile.color);

    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(0, rect.height * .4),
        width: rect.width * .7,
        height: rect.height * .18,
      ),
      Paint()..color = Colors.black.withValues(alpha: .3),
    );
    _paintMonsterEars(canvas, bodyRect, tile.color, base);
    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.38, -.52),
          radius: 1.1,
          colors: [
            Color.lerp(base, Colors.white, .48)!,
            base,
            Color.lerp(base, const Color(0xFF101B32), .28)!,
          ],
          stops: const [0, .48, 1],
        ).createShader(bodyRect),
    );
    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = Color.lerp(base, Colors.white, .65)!.withValues(alpha: .46)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(.7, rect.width * .025),
    );
    canvas.drawOval(
      Rect.fromLTWH(
        bodyRect.left + bodyRect.width * .16,
        bodyRect.top + bodyRect.height * .1,
        bodyRect.width * .27,
        bodyRect.height * .12,
      ),
      Paint()..color = Colors.white.withValues(alpha: .28),
    );
    _paintMonsterFace(canvas, bodyRect, tile.color);
    if (tile.special != Match3Special.none) {
      _paintSpecialBadge(canvas, bodyRect, tile.special);
    }
  }

  Path _monsterBodyPath(Rect rect, int color) {
    if (color == 1) {
      return Path()..addOval(rect);
    }
    if (color == 2) {
      final path = Path()
        ..moveTo(rect.left + rect.width * .12, rect.bottom)
        ..quadraticBezierTo(
          rect.left + rect.width * .18,
          rect.bottom - rect.height * .12,
          rect.left + rect.width * .15,
          rect.top + rect.height * .42,
        )
        ..quadraticBezierTo(
          rect.left + rect.width * .2,
          rect.top,
          rect.center.dx,
          rect.top,
        )
        ..quadraticBezierTo(
          rect.right - rect.width * .2,
          rect.top,
          rect.right - rect.width * .15,
          rect.top + rect.height * .42,
        )
        ..quadraticBezierTo(
          rect.right - rect.width * .18,
          rect.bottom - rect.height * .12,
          rect.right - rect.width * .12,
          rect.bottom,
        )
        ..quadraticBezierTo(
          rect.right - rect.width * .28,
          rect.bottom - rect.height * .1,
          rect.center.dx,
          rect.bottom,
        )
        ..quadraticBezierTo(
          rect.left + rect.width * .28,
          rect.bottom - rect.height * .1,
          rect.left + rect.width * .12,
          rect.bottom,
        )
        ..close();
      return path;
    }
    return Path()..addRRect(
      RRect.fromRectAndRadius(
        rect,
        Radius.circular(rect.width * (color == 5 ? .42 : .3)),
      ),
    );
  }

  void _paintMonsterEars(Canvas canvas, Rect rect, int color, Color base) {
    if (color == 0 || color == 4) {
      final hornPaint = Paint()..color = Color.lerp(base, Colors.white, .12)!;
      final left = Path()
        ..moveTo(rect.left + rect.width * .1, rect.top + rect.height * .24)
        ..lineTo(rect.left + rect.width * .17, rect.top - rect.height * .22)
        ..lineTo(rect.left + rect.width * .38, rect.top + rect.height * .09)
        ..close();
      final right = Path()
        ..moveTo(rect.right - rect.width * .1, rect.top + rect.height * .24)
        ..lineTo(rect.right - rect.width * .17, rect.top - rect.height * .22)
        ..lineTo(rect.right - rect.width * .38, rect.top + rect.height * .09)
        ..close();
      canvas.drawPath(left, hornPaint);
      canvas.drawPath(right, hornPaint);
    } else if (color == 3) {
      final earPaint = Paint()..color = Color.lerp(base, Colors.white, .18)!;
      canvas.drawCircle(
        Offset(rect.left + rect.width * .1, rect.top + rect.height * .18),
        rect.width * .17,
        earPaint,
      );
      canvas.drawCircle(
        Offset(rect.right - rect.width * .1, rect.top + rect.height * .18),
        rect.width * .17,
        earPaint,
      );
    }
  }

  void _paintMonsterFace(Canvas canvas, Rect rect, int color) {
    final eyeY = rect.top + rect.height * .43;
    if (color == 1) {
      _paintEye(canvas, Offset(rect.center.dx, eyeY), rect.width * .18);
    } else {
      final spacing = rect.width * (color == 5 ? .16 : .18);
      _paintEye(
        canvas,
        Offset(rect.center.dx - spacing, eyeY),
        rect.width * .105,
        sleepy: color == 5,
      );
      _paintEye(
        canvas,
        Offset(rect.center.dx + spacing, eyeY),
        rect.width * .105,
        sleepy: color == 5,
      );
      if (color == 0 || color == 4) {
        final browPaint = Paint()
          ..color = const Color(0xFF273143).withValues(alpha: .8)
          ..strokeWidth = rect.width * .055
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(rect.center.dx - spacing * 1.45, eyeY - rect.height * .18),
          Offset(rect.center.dx - spacing * .45, eyeY - rect.height * .11),
          browPaint,
        );
        canvas.drawLine(
          Offset(rect.center.dx + spacing * 1.45, eyeY - rect.height * .18),
          Offset(rect.center.dx + spacing * .45, eyeY - rect.height * .11),
          browPaint,
        );
      }
    }

    final mouthY = rect.top + rect.height * .7;
    final mouth = Path()
      ..moveTo(rect.center.dx - rect.width * .16, mouthY)
      ..quadraticBezierTo(
        rect.center.dx,
        mouthY + rect.height * (color == 4 ? -.02 : .13),
        rect.center.dx + rect.width * .16,
        mouthY,
      );
    canvas.drawPath(
      mouth,
      Paint()
        ..color = const Color(0xFF273143).withValues(alpha: .82)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, rect.width * .052)
        ..strokeCap = StrokeCap.round,
    );
    if (color == 3 || color == 4) {
      final fang = Path()
        ..moveTo(rect.center.dx + rect.width * .04, mouthY + rect.height * .025)
        ..lineTo(rect.center.dx + rect.width * .12, mouthY + rect.height * .16)
        ..lineTo(rect.center.dx + rect.width * .17, mouthY)
        ..close();
      canvas.drawPath(
        fang,
        Paint()..color = Colors.white.withValues(alpha: .9),
      );
    }
  }

  void _paintEye(
    Canvas canvas,
    Offset center,
    double radius, {
    bool sleepy = false,
  }) {
    if (sleepy) {
      final path = Path()
        ..moveTo(center.dx - radius, center.dy)
        ..quadraticBezierTo(
          center.dx,
          center.dy + radius * .65,
          center.dx + radius,
          center.dy,
        );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF253046)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, radius * .45)
          ..strokeCap = StrokeCap.round,
      );
      return;
    }
    canvas.drawCircle(center, radius, Paint()..color = Colors.white);
    canvas.drawCircle(
      center + Offset(radius * .12, radius * .16),
      radius * .52,
      Paint()..color = const Color(0xFF253046),
    );
    canvas.drawCircle(
      center - Offset(radius * .13, radius * .14),
      radius * .19,
      Paint()..color = Colors.white,
    );
  }

  void _paintSpecialBadge(Canvas canvas, Rect rect, Match3Special special) {
    final radius = rect.width * .17;
    final center = Offset(
      rect.right - radius * .55,
      rect.bottom - radius * .55,
    );
    canvas.drawCircle(
      center + Offset(0, radius * .12),
      radius * 1.08,
      Paint()..color = Colors.black.withValues(alpha: .28),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7FCFF), Color(0xFFBFDDF4)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    final paint = Paint()
      ..color = const Color(0xFF23456A)
      ..strokeWidth = math.max(1.1, radius * .22)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    switch (special) {
      case Match3Special.row:
        canvas.drawLine(
          center - Offset(radius * .55, 0),
          center + Offset(radius * .55, 0),
          paint,
        );
        break;
      case Match3Special.column:
        canvas.drawLine(
          center - Offset(0, radius * .55),
          center + Offset(0, radius * .55),
          paint,
        );
        break;
      case Match3Special.bomb:
        canvas.drawCircle(
          center,
          radius * .4,
          paint..style = PaintingStyle.fill,
        );
        canvas.drawLine(
          center - Offset(0, radius * .38),
          center + Offset(radius * .35, radius * .72),
          paint..style = PaintingStyle.stroke,
        );
        break;
      case Match3Special.color:
        for (var i = 0; i < 6; i++) {
          final angle = i * math.pi / 3;
          canvas.drawCircle(
            center + Offset(math.cos(angle), math.sin(angle)) * radius * .48,
            radius * .15,
            Paint()..color = _colors[i],
          );
        }
        break;
      case Match3Special.none:
        break;
    }
  }

  void _paintGestureTarget(Canvas canvas, int index) {
    final rect = geometry.rectFor(index);
    final emphasis = Curves.easeOutCubic.transform(
      gestureProgress.clamp(0.0, 1.0),
    );
    final color = gestureInvalid
        ? const Color(0xFFFF7A7A)
        : const Color(0xFF7BE7C0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.inflate(geometry.tileSize * (.018 + emphasis * .025)),
        Radius.circular(geometry.tileSize * .29),
      ),
      Paint()
        ..color = color.withValues(alpha: .32 + emphasis * .58)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(
          1,
          geometry.tileSize * (.025 + .02 * emphasis),
        ),
    );
  }

  void _paintClearSparkles(
    Canvas canvas,
    Offset center,
    int index,
    double progress,
  ) {
    final travel = Curves.easeOutCubic.transform(progress);
    final fade = 1 - progress;
    for (var particle = 0; particle < 5; particle++) {
      final angle = index * .73 + particle * math.pi * 2 / 5;
      final radius = geometry.tileSize * (.12 + travel * .48);
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawCircle(
        point,
        geometry.tileSize * .055 * fade,
        Paint()
          ..color = _colors[(index + particle) % _colors.length].withValues(
            alpha: fade,
          ),
      );
    }
  }

  void _paintCascadeFeedback(Canvas canvas, _Match3Presentation presentation) {
    final progress = presentation.cascadeProgress;
    final appear = Curves.easeOutBack.transform(
      (progress / .2).clamp(0.0, 1.0),
    );
    final fade = 1 - ((progress - .58) / .42).clamp(0.0, 1.0);
    if (fade <= 0) return;
    final center = geometry.rectFor(presentation.cascadeAnchor!).center;
    final radius = geometry.tileSize * (.35 + progress * 1.35);
    final accent = presentation.cascadeIndex > 1
        ? const Color(0xFFFFD66E)
        : Colors.white;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = accent.withValues(alpha: fade * .62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.1, geometry.tileSize * .065 * fade),
    );
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi * 2 / 8 + presentation.cascadeIndex * .31;
      final position =
          center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawCircle(
        position,
        geometry.tileSize * .05 * fade,
        Paint()
          ..color = _colors[(i + presentation.cascadeIndex) % _colors.length]
              .withValues(alpha: fade),
      );
    }
    final label = presentation.cascadeIndex > 1
        ? '${presentation.cascadeIndex} 连消  +${presentation.cascadeScore}'
        : '+${presentation.cascadeScore}';
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: accent.withValues(alpha: fade),
          fontSize:
              geometry.tileSize * (presentation.cascadeIndex > 1 ? .34 : .3),
          fontWeight: FontWeight.w900,
          shadows: const [Shadow(color: Color(0xCC14233A), blurRadius: 8)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(.8 + appear * .2);
    text.paint(
      canvas,
      Offset(-text.width / 2, -geometry.tileSize * (.62 + progress * .55)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _Match3BoardPainter oldDelegate) =>
      oldDelegate.stateHash != stateHash ||
      oldDelegate.gestureOrigin != gestureOrigin ||
      oldDelegate.gestureSwap != gestureSwap ||
      oldDelegate.gestureProgress != gestureProgress ||
      oldDelegate.gestureInvalid != gestureInvalid ||
      oldDelegate.lastTurn?.number != lastTurn?.number ||
      oldDelegate.thinking != thinking ||
      oldDelegate.ambient != ambient ||
      oldDelegate.resolve != resolve ||
      oldDelegate.geometry.boardRect != geometry.boardRect;
}
