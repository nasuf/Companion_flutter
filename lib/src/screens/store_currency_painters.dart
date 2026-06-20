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

class _PointMiniPainter extends CustomPainter {
  const _PointMiniPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path()
      ..moveTo(center.dx, size.height * 0.04)
      ..lineTo(size.width * 0.90, size.height * 0.34)
      ..lineTo(size.width * 0.70, size.height * 0.92)
      ..lineTo(size.width * 0.24, size.height * 0.86)
      ..lineTo(size.width * 0.08, size.height * 0.30)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFF8ABB), Color(0xFF8DEBFF), Color(0xFFFFD6EA)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _PointMiniPainter oldDelegate) => false;
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

class _PointCrystalPainter extends CustomPainter {
  const _PointCrystalPainter({
    this.sizeScale = 1,
    this.labelColor,
    this.glowColor,
  });

  final double sizeScale;
  final Color? labelColor;
  final Color? glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (glowColor != null) {
      final glowRect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width,
        height: size.height,
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
    canvas.save();
    canvas.translate(
      size.width * (1 - sizeScale) / 2,
      size.height * (1 - sizeScale) / 2,
    );
    canvas.scale(sizeScale);
    if (labelColor == null) {
      const mini = _PointMiniPainter();
      mini.paint(canvas, size);
    } else {
      final center = Offset(size.width / 2, size.height / 2);
      final path = Path()
        ..moveTo(center.dx, size.height * 0.04)
        ..lineTo(size.width * 0.90, size.height * 0.34)
        ..lineTo(size.width * 0.70, size.height * 0.92)
        ..lineTo(size.width * 0.24, size.height * 0.86)
        ..lineTo(size.width * 0.08, size.height * 0.30)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Color.lerp(labelColor!, const Color(0xFFFF8ABB), 0.34)!,
              const Color(0xFF8DEBFF),
              Color.lerp(labelColor!, const Color(0xFFFFD6EA), 0.30)!,
            ],
          ).createShader(Offset.zero & size),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = labelColor!.withValues(alpha: 0.70)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PointCrystalPainter oldDelegate) {
    return oldDelegate.sizeScale != sizeScale ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.glowColor != glowColor;
  }
}

class _RechargePatternPainter extends CustomPainter {
  const _RechargePatternPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.08);
    for (var y = 18.0; y < size.height; y += 44) {
      for (var x = 8.0; x < size.width; x += 44) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, 24, 30),
            const Radius.circular(8),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RechargePatternPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
