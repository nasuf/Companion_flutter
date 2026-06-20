part of 'package:companion_flutter/main.dart';

class _StoreBackground extends StatelessWidget {
  const _StoreBackground();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = AppColors.isDark(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  Color.lerp(colors.page, const Color(0xFF0E2338), 0.40)!,
                  colors.page,
                  Color.lerp(colors.page, const Color(0xFF251322), 0.24)!,
                ]
              : const [Color(0xFFEAF7FF), Color(0xFFF7FAFF), Color(0xFFFFF7FB)],
          stops: const [0, 0.58, 1],
        ),
      ),
      child: CustomPaint(painter: _StoreBackgroundPainter(isDark: isDark)),
    );
  }
}

class _StoreBackgroundPainter extends CustomPainter {
  const _StoreBackgroundPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    paint.color = AppColors.accent.withValues(alpha: isDark ? 0.12 : 0.055);
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.12),
      120,
      paint,
    );
    paint.color = const Color(
      0xFFFF9EB6,
    ).withValues(alpha: isDark ? 0.08 : 0.055);
    canvas.drawCircle(
      Offset(size.width * 0.10, size.height * 0.70),
      150,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _StoreBackgroundPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}
