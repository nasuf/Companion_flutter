part of 'package:companion_flutter/main.dart';

class _StoreBackground extends StatelessWidget {
  const _StoreBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEAF7FF), Color(0xFFF7FAFF), Color(0xFFFFF7FB)],
          stops: [0, 0.58, 1],
        ),
      ),
      child: CustomPaint(painter: const _StoreBackgroundPainter()),
    );
  }
}

class _StoreBackgroundPainter extends CustomPainter {
  const _StoreBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    paint.color = AppColors.accent.withValues(alpha: 0.055);
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.12),
      120,
      paint,
    );
    paint.color = const Color(0xFFFF9EB6).withValues(alpha: 0.055);
    canvas.drawCircle(
      Offset(size.width * 0.10, size.height * 0.70),
      150,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _StoreBackgroundPainter oldDelegate) => false;
}
