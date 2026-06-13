part of 'package:companion_flutter/main.dart';

class _StoreItemIconPainter extends CustomPainter {
  const _StoreItemIconPainter({required this.kind, required this.accent});

  final _StoreItemKind kind;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case _StoreItemKind.tea:
        _paintCup(canvas, size, const Color(0xFFFFB45E), 'T');
      case _StoreItemKind.cake:
        _paintCake(canvas, size);
      case _StoreItemKind.coffee:
        _paintCup(canvas, size, const Color(0xFF7A4B34), 'C');
      case _StoreItemKind.cola:
        _paintBottle(canvas, size);
      case _StoreItemKind.flower:
        _paintFlower(canvas, size);
      case _StoreItemKind.plush:
        _paintPlush(canvas, size);
      case _StoreItemKind.capsuleSkin:
        _paintCapsule(canvas, size);
      case _StoreItemKind.chatFrame:
        _paintFrame(canvas, size);
      case _StoreItemKind.bubble:
        _paintBubble(canvas, size);
      case _StoreItemKind.backdrop:
        _paintBackdrop(canvas, size);
      case _StoreItemKind.theme:
        _paintTheme(canvas, size);
      case _StoreItemKind.stationery:
        _paintStationery(canvas, size);
      case _StoreItemKind.checkinSkin:
        _paintCheckin(canvas, size);
      case _StoreItemKind.signCard:
        _paintCard(canvas, size, CupertinoIcons.check_mark);
      case _StoreItemKind.musicCoupon:
        _paintCard(canvas, size, CupertinoIcons.music_note_2);
      case _StoreItemKind.gameCoupon:
        _paintCard(canvas, size, CupertinoIcons.gamecontroller_fill);
      case _StoreItemKind.movieCoupon:
        _paintCard(canvas, size, CupertinoIcons.film_fill);
      case _StoreItemKind.musicBundle:
        _paintBundle(canvas, size, CupertinoIcons.music_note_2);
      case _StoreItemKind.gameBundle:
        _paintBundle(canvas, size, CupertinoIcons.gamecontroller_fill);
      case _StoreItemKind.movieBundle:
        _paintBundle(canvas, size, CupertinoIcons.film_fill);
    }
  }

  void _paintCup(Canvas canvas, Size size, Color color, String mark) {
    final rect = Rect.fromLTWH(
      size.width * 0.24,
      size.height * 0.24,
      size.width * 0.44,
      size.height * 0.52,
    );
    final cup = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.width * 0.12),
    );
    _shadow(canvas, Path()..addRRect(cup));
    canvas.drawRRect(cup, Paint()..color = color);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.30,
          size.height * 0.15,
          size.width * 0.34,
          size.height * 0.12,
        ),
        Radius.circular(size.width * 0.06),
      ),
      Paint()..color = Colors.white,
    );
    canvas.drawArc(
      Rect.fromLTWH(
        size.width * 0.60,
        size.height * 0.38,
        size.width * 0.23,
        size.height * 0.24,
      ),
      -math.pi / 2,
      math.pi,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    _drawIconText(
      canvas,
      size,
      mark,
      color == const Color(0xFF7A4B34) ? Colors.white : const Color(0xFF8C4E1E),
    );
  }

  void _paintCake(Canvas canvas, Size size) {
    final plate = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.18,
        size.height * 0.68,
        size.width * 0.62,
        size.height * 0.10,
      ),
      Radius.circular(size.width * 0.05),
    );
    canvas.drawRRect(plate, Paint()..color = Colors.white);
    final cake = Path()
      ..moveTo(size.width * 0.25, size.height * 0.66)
      ..lineTo(size.width * 0.76, size.height * 0.66)
      ..lineTo(size.width * 0.62, size.height * 0.28)
      ..lineTo(size.width * 0.32, size.height * 0.36)
      ..close();
    _shadow(canvas, cake);
    canvas.drawPath(cake, Paint()..color = const Color(0xFFFFB8C7));
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.31, size.height * 0.44)
        ..lineTo(size.width * 0.66, size.height * 0.35)
        ..lineTo(size.width * 0.70, size.height * 0.47)
        ..lineTo(size.width * 0.28, size.height * 0.57)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.72),
    );
  }

  void _paintBottle(Canvas canvas, Size size) {
    final bottle = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.34,
        size.height * 0.18,
        size.width * 0.32,
        size.height * 0.62,
      ),
      Radius.circular(size.width * 0.12),
    );
    _shadow(canvas, Path()..addRRect(bottle));
    canvas.drawRRect(bottle, Paint()..color = const Color(0xFFE94B4B));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.38,
          size.height * 0.42,
          size.width * 0.24,
          size.height * 0.14,
        ),
        Radius.circular(size.width * 0.04),
      ),
      Paint()..color = Colors.white,
    );
  }

  void _paintFlower(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.50, size.height * 0.42);
    for (var i = 0; i < 7; i += 1) {
      final angle = i * math.pi * 2 / 7;
      canvas.drawOval(
        Rect.fromCenter(
          center: center + Offset(math.cos(angle) * 13, math.sin(angle) * 13),
          width: 18,
          height: 26,
        ),
        Paint()
          ..color = Color.lerp(const Color(0xFFFF79A8), Colors.white, i / 12)!,
      );
    }
    canvas.drawCircle(center, 9, Paint()..color = const Color(0xFFFFD15F));
    canvas.drawLine(
      Offset(size.width * 0.50, size.height * 0.55),
      Offset(size.width * 0.43, size.height * 0.82),
      Paint()
        ..color = const Color(0xFF34B66E)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintPlush(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFB98962);
    canvas.drawCircle(Offset(size.width * 0.32, size.height * 0.30), 12, paint);
    canvas.drawCircle(Offset(size.width * 0.68, size.height * 0.30), 12, paint);
    canvas.drawCircle(Offset(size.width * 0.50, size.height * 0.46), 28, paint);
    canvas.drawCircle(
      Offset(size.width * 0.40, size.height * 0.42),
      4,
      Paint()..color = Colors.black,
    );
    canvas.drawCircle(
      Offset(size.width * 0.60, size.height * 0.42),
      4,
      Paint()..color = Colors.black,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.50, size.height * 0.54),
        width: 16,
        height: 11,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.86),
    );
  }

  void _paintCapsule(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-math.pi / 5);
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: size.width * 0.70,
        height: size.height * 0.34,
      ),
      Radius.circular(size.height * 0.17),
    );
    canvas.drawRRect(rect, Paint()..color = Colors.white);
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        -size.height * 0.17,
        size.width * 0.35,
        size.height * 0.34,
      ),
      Paint()..color = accent.withValues(alpha: 0.72),
    );
    canvas.restore();
  }

  void _paintFrame(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.18,
        size.height * 0.22,
        size.width * 0.64,
        size.height * 0.48,
      ),
      Radius.circular(size.width * 0.08),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    canvas.drawLine(
      Offset(size.width * 0.30, size.height * 0.40),
      Offset(size.width * 0.68, size.height * 0.40),
      Paint()
        ..color = accent.withValues(alpha: 0.42)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintBubble(Canvas canvas, Size size) {
    final bubble = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.18,
        size.height * 0.24,
        size.width * 0.62,
        size.height * 0.42,
      ),
      Radius.circular(size.width * 0.14),
    );
    canvas.drawRRect(bubble, Paint()..color = accent.withValues(alpha: 0.78));
    canvas.drawCircle(
      Offset(size.width * 0.36, size.height * 0.45),
      3,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(size.width * 0.50, size.height * 0.45),
      3,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(size.width * 0.64, size.height * 0.45),
      3,
      Paint()..color = Colors.white,
    );
  }

  void _paintBackdrop(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.16,
        size.height * 0.18,
        size.width * 0.68,
        size.height * 0.56,
      ),
      Radius.circular(size.width * 0.08),
    );
    canvas.drawRRect(rect, Paint()..color = const Color(0xFFEAF7FF));
    canvas.drawCircle(
      Offset(size.width * 0.32, size.height * 0.34),
      8,
      Paint()..color = const Color(0xFFFFC86B),
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.20, size.height * 0.70)
        ..lineTo(size.width * 0.42, size.height * 0.46)
        ..lineTo(size.width * 0.58, size.height * 0.62)
        ..lineTo(size.width * 0.74, size.height * 0.42)
        ..lineTo(size.width * 0.82, size.height * 0.70)
        ..close(),
      Paint()..color = accent.withValues(alpha: 0.54),
    );
  }

  void _paintTheme(Canvas canvas, Size size) {
    final colors = [
      accent,
      const Color(0xFFFF8FB4),
      const Color(0xFFFFC85A),
      const Color(0xFF78D6B5),
    ];
    for (var i = 0; i < colors.length; i += 1) {
      canvas.drawCircle(
        Offset(
          size.width * (0.36 + (i % 2) * 0.28),
          size.height * (0.34 + (i ~/ 2) * 0.28),
        ),
        13,
        Paint()..color = colors[i],
      );
    }
  }

  void _paintStationery(Canvas canvas, Size size) {
    final paper = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.24,
        size.height * 0.18,
        size.width * 0.48,
        size.height * 0.62,
      ),
      Radius.circular(size.width * 0.06),
    );
    canvas.drawRRect(paper, Paint()..color = Colors.white);
    for (var i = 0; i < 3; i += 1) {
      canvas.drawLine(
        Offset(size.width * 0.32, size.height * (0.34 + i * 0.12)),
        Offset(size.width * 0.64, size.height * (0.34 + i * 0.12)),
        Paint()
          ..color = accent.withValues(alpha: 0.44)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _paintCheckin(Canvas canvas, Size size) {
    final calendar = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.20,
        size.height * 0.22,
        size.width * 0.60,
        size.height * 0.54,
      ),
      Radius.circular(size.width * 0.08),
    );
    canvas.drawRRect(calendar, Paint()..color = Colors.white);
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.20,
        size.height * 0.22,
        size.width * 0.60,
        size.height * 0.16,
      ),
      Paint()..color = accent,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.36, size.height * 0.56)
        ..lineTo(size.width * 0.46, size.height * 0.66)
        ..lineTo(size.width * 0.66, size.height * 0.46),
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintCard(Canvas canvas, Size size, IconData icon) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.18,
        size.height * 0.24,
        size.width * 0.64,
        size.height * 0.48,
      ),
      Radius.circular(size.width * 0.08),
    );
    _shadow(canvas, Path()..addRRect(rect));
    canvas.drawRRect(rect, Paint()..color = accent.withValues(alpha: 0.76));
    _drawIconGlyph(canvas, size, icon, Colors.white, 28);
  }

  void _paintBundle(Canvas canvas, Size size, IconData icon) {
    final box = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.20,
        size.height * 0.30,
        size.width * 0.60,
        size.height * 0.42,
      ),
      Radius.circular(size.width * 0.07),
    );
    _shadow(canvas, Path()..addRRect(box));
    canvas.drawRRect(box, Paint()..color = accent.withValues(alpha: 0.86));
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.46,
        size.height * 0.30,
        size.width * 0.08,
        size.height * 0.42,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.74),
    );
    canvas.drawLine(
      Offset(size.width * 0.24, size.height * 0.42),
      Offset(size.width * 0.76, size.height * 0.42),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.72)
        ..strokeWidth = 5,
    );
    _drawIconGlyph(canvas, size, icon, Colors.white, 23, dy: 2);
  }

  void _drawIconText(Canvas canvas, Size size, String text, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset((size.width - painter.width) / 2, size.height * 0.40),
    );
  }

  void _drawIconGlyph(
    Canvas canvas,
    Size size,
    IconData icon,
    Color color,
    double fontSize, {
    double dy = 0,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(
        (size.width - painter.width) / 2,
        (size.height - painter.height) / 2 + dy,
      ),
    );
  }

  void _shadow(Canvas canvas, Path path) {
    canvas.drawPath(
      path.shift(const Offset(0, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  @override
  bool shouldRepaint(covariant _StoreItemIconPainter oldDelegate) {
    return oldDelegate.kind != kind || oldDelegate.accent != accent;
  }
}
