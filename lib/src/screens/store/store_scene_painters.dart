part of 'package:companion_flutter/main.dart';

class _StoreBackground extends StatelessWidget {
  const _StoreBackground();

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: w.isDark
              ? [
                  const Color(0xFF0B1522),
                  w.base,
                  const Color(0xFF0A1018),
                ]
              : const [
                  Color(0xFFE9F0FB),
                  Color(0xFFF4F7FC),
                  Color(0xFFE7EEF8),
                ],
        ),
      ),
      child: CustomPaint(painter: _StoreBackgroundPainter(isDark: w.isDark)),
    );
  }
}

class _StoreBackgroundPainter extends CustomPainter {
  const _StoreBackgroundPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    // 右上角蓝色大圆：保持不变。
    paint.color = const Color(0xFF4B9AFF).withValues(alpha: isDark ? 0.16 : 0.10);
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.10),
      140,
      paint,
    );
    // 原左侧蓝色圆 → 移到左侧偏下、改成淡粉色（保持在底部按钮上方，不贴到最底）。
    paint.color = const Color(0xFFF3B8D2).withValues(alpha: isDark ? 0.12 : 0.16);
    canvas.drawCircle(
      Offset(size.width * 0.08, size.height * 0.72),
      120,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _StoreBackgroundPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}
