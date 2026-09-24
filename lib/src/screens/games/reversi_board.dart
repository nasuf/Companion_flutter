part of 'package:companion_flutter/main.dart';

class _ReversiBoard extends StatefulWidget {
  const _ReversiBoard({
    required this.engine,
    required this.lastMove,
    required this.thinking,
    required this.enabled,
    required this.onTap,
  });

  final ReversiEngine engine;
  final ReversiMove? lastMove;
  final bool thinking;
  final bool enabled;
  final ValueChanged<int> onTap;

  @override
  State<_ReversiBoard> createState() => _ReversiBoardState();
}

class _ReversiBoardState extends State<_ReversiBoard>
    with TickerProviderStateMixin {
  late final AnimationController _moveController;
  late final AnimationController _ambientController;

  @override
  void initState() {
    super.initState();
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
      value: 1,
    );
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _ReversiBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lastMove?.number != widget.lastMove?.number &&
        widget.lastMove != null) {
      _moveController.duration = Duration(
        milliseconds: widget.lastMove!.flipped.length >= 8 ? 960 : 820,
      );
      _moveController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _moveController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final legal = widget.enabled
        ? widget.engine.legalMoves
        : const <int, List<int>>{};
    return Semantics(
      label: '黑白棋棋盘，轻点发光位置落下黑棋',
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            final geometry = _ReversiBoardGeometry(size);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: widget.enabled
                  ? (details) {
                      final index = geometry.indexAt(details.localPosition);
                      if (index != null && legal.containsKey(index)) {
                        widget.onTap(index);
                      }
                    }
                  : null,
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _moveController,
                  _ambientController,
                ]),
                builder: (context, _) {
                  final moveProgress = Curves.easeInOutCubic.transform(
                    _moveController.value,
                  );
                  final pulse = 0.55 + _ambientController.value * 0.45;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          '${_reversiAsset}game_board.png',
                          fit: BoxFit.fill,
                        ),
                      ),
                      for (final index in legal.keys)
                        _ReversiLegalHint(
                          rect: geometry.cellRect(index),
                          pulse: pulse,
                        ),
                      for (
                        var index = 0;
                        index < widget.engine.board.length;
                        index += 1
                      )
                        if (widget.engine.board[index] != 0)
                          _buildDisc(index, geometry, moveProgress),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDisc(
    int index,
    _ReversiBoardGeometry geometry,
    double moveProgress,
  ) {
    var value = widget.engine.board[index];
    var scaleX = 1.0;
    var scaleY = 1.0;
    var lift = 0.0;
    final move = widget.lastMove;
    if (move?.point.index == index && moveProgress < 1) {
      final progress = Curves.elasticOut.transform(
        (moveProgress / 0.56).clamp(0.0, 1.0),
      );
      scaleX = progress;
      scaleY = progress;
    } else if (move != null &&
        move.flipped.any((point) => point.index == index) &&
        moveProgress < 0.88) {
      final local = ((moveProgress - 0.12) / 0.68).clamp(0.0, 1.0);
      value = local < 0.5 ? move.boardBefore[index] : move.boardAfter[index];
      scaleX = math.cos(local * math.pi).abs().clamp(0.045, 1.0);
      scaleY = 1 + math.sin(local * math.pi) * 0.08;
      lift = math.sin(local * math.pi) * geometry.discSize * 0.12;
    }
    final center = geometry.cellRect(index).center;
    final size = geometry.discSize;
    final asset = value == 1
        ? '${_reversiAsset}game_disc_black.png'
        : '${_reversiAsset}game_disc_white.png';
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2 - lift,
      width: size,
      height: size,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(scaleX, scaleY, 1),
        child: Image.asset(asset, fit: BoxFit.contain),
      ),
    );
  }
}

class _ReversiBoardGeometry {
  const _ReversiBoardGeometry(this.size);

  final Size size;

  static const List<double> _sourceX = [
    87,
    204,
    321,
    435,
    553,
    667,
    784,
    898,
    1017,
  ];
  static const List<double> _sourceY = [
    84,
    196,
    315,
    431,
    551,
    667,
    788,
    903,
    1022,
  ];

  double _x(int index) => size.width * (_sourceX[index] / 1104);
  double _y(int index) => size.height * (_sourceY[index] / 1122);
  double get discSize => size.width * (33 / 368);

  Rect cellRect(int index) {
    final row = index ~/ ReversiEngine.size;
    final col = index % ReversiEngine.size;
    return Rect.fromLTRB(_x(col), _y(row), _x(col + 1), _y(row + 1));
  }

  int? indexAt(Offset position) {
    for (var row = 0; row < ReversiEngine.size; row += 1) {
      for (var col = 0; col < ReversiEngine.size; col += 1) {
        final index = row * ReversiEngine.size + col;
        if (cellRect(index).contains(position)) return index;
      }
    }
    return null;
  }
}

class _ReversiLegalHint extends StatelessWidget {
  const _ReversiLegalHint({required this.rect, required this.pulse});

  final Rect rect;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final size = math.min(rect.width, rect.height) * (0.26 + pulse * 0.025);
    return Positioned(
      left: rect.center.dx - size / 2,
      top: rect.center.dy - size / 2,
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.18 + pulse * 0.08),
          border: Border.all(
            color: const Color(0xFFFFD980).withValues(alpha: 0.82),
            width: 1.3,
          ),
        ),
      ),
    );
  }
}
