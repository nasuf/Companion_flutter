part of 'package:companion_flutter/main.dart';

class _TicketMiniPainter extends CustomPainter {
  const _TicketMiniPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.10,
        size.height * 0.26,
        size.width * 0.80,
        size.height * 0.48,
      ),
      Radius.circular(size.width * 0.10),
    );
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-0.20);
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.drawRRect(rect, Paint()..color = const Color(0xFFE6F9ED));
    canvas.drawRRect(
      rect,
      Paint()
        ..color = const Color(0xFF5CCB83)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.08,
    );
    canvas.drawCircle(
      Offset(size.width * 0.50, size.height * 0.50),
      size.width * 0.13,
      Paint()..color = const Color(0xFFFFD45F),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TicketMiniPainter oldDelegate) => false;
}

class _TicketStackPainter extends CustomPainter {
  const _TicketStackPainter({this.labelColor, this.glowColor});

  final Color? labelColor;
  final Color? glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (glowColor != null) {
      final glowRect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.44),
        width: size.width * 1.04,
        height: size.height * 0.92,
      );
      canvas.drawOval(
        glowRect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              glowColor!.withValues(alpha: 0.18),
              glowColor!.withValues(alpha: 0),
            ],
          ).createShader(glowRect),
      );
    }
    for (var i = 0; i < 3; i += 1) {
      canvas.save();
      canvas.translate(
        size.width * (0.10 + i * 0.06),
        size.height * (0.18 - i * 0.04),
      );
      canvas.rotate(-0.18 + i * 0.08);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width * 0.72, size.height * 0.44),
        const Radius.circular(10),
      );
      canvas.drawRRect(rect, Paint()..color = labelColor ?? Colors.white);
      canvas.drawRRect(
        rect,
        Paint()
          ..color = const Color(0xFF67C987)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
      canvas.drawCircle(
        Offset(size.width * 0.36, size.height * 0.22),
        13,
        Paint()..color = const Color(0xFFFFD464),
      );
      canvas.restore();
    }
    final wing = Paint()
      ..color = (labelColor ?? Colors.white).withValues(alpha: 0.84);
    canvas.drawOval(Rect.fromLTWH(0, size.height * 0.30, 26, 18), wing);
    canvas.drawOval(
      Rect.fromLTWH(size.width - 26, size.height * 0.30, 26, 18),
      wing,
    );
  }

  @override
  bool shouldRepaint(covariant _TicketStackPainter oldDelegate) {
    return oldDelegate.labelColor != labelColor ||
        oldDelegate.glowColor != glowColor;
  }
}
