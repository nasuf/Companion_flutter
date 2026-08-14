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
    paint.color = const Color(0xFF4B9AFF).withValues(alpha: isDark ? 0.16 : 0.10);
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.10),
      140,
      paint,
    );
    paint.color = const Color(0xFF8ABAFF).withValues(alpha: isDark ? 0.10 : 0.12);
    canvas.drawCircle(
      Offset(size.width * 0.08, size.height * 0.42),
      120,
      paint,
    );
    paint.color = const Color(0xFFFFB020).withValues(alpha: isDark ? 0.06 : 0.05);
    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.72),
      110,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _StoreBackgroundPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}
