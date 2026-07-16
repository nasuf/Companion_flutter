part of 'package:companion_flutter/main.dart';

enum _SidebarDestination {
  weather('天气', Color(0xFF4B9AFF)),
  capsule('胶囊', Color(0xFFFE9631)),
  legacy('遗言', Color(0xFF1C1E28)),
  mail('信箱', Color(0xFF7C3CFF)),
  task('打卡', Color(0xFF1AB88D)),
  achievement('成就', Color(0xFFFD6846)),
  shop('商城', Color(0xFF124DB2));

  const _SidebarDestination(this.label, this.color);

  final String label;
  final Color color;
}

class _ChatSidebarOverlay extends StatelessWidget {
  const _ChatSidebarOverlay({
    required this.visible,
    required this.onDismiss,
    required this.onSelected,
  });

  final bool visible;
  final VoidCallback onDismiss;
  final ValueChanged<_SidebarDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final top = math.max(safeTop + 98, screenHeight * 0.16);

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDismiss,
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: visible ? 0.22 : 0),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              top: top,
              right: visible ? 28 : -92,
              child: _SidebarRail(onSelected: onSelected),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarRail extends StatelessWidget {
  const _SidebarRail({required this.onSelected});

  final ValueChanged<_SidebarDestination> onSelected;

  static const _grouped = [
    _SidebarDestination.weather,
    _SidebarDestination.capsule,
    _SidebarDestination.legacy,
    _SidebarDestination.task,
    _SidebarDestination.achievement,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LiquidRailContainer(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _grouped.length; i += 1) ...[
                _SidebarButton(
                  destination: _grouped[i],
                  onTap: () => onSelected(_grouped[i]),
                ),
                if (i != _grouped.length - 1) const SizedBox(height: 16),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        _LiquidRailContainer(
          padding: const EdgeInsets.all(20),
          child: _SidebarButton(
            destination: _SidebarDestination.shop,
            onTap: () => onSelected(_SidebarDestination.shop),
          ),
        ),
      ],
    );
  }
}

class _LiquidRailContainer extends StatelessWidget {
  const _LiquidRailContainer({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: child,
    );
  }
}

class _SidebarButton extends StatelessWidget {
  const _SidebarButton({required this.destination, required this.onTap});

  final _SidebarDestination destination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final showBadge = destination != _SidebarDestination.weather;
    final badgeOffset = destination == _SidebarDestination.capsule
        ? const Offset(44, 8)
        : const Offset(48, 4);

    return Tooltip(
      message: destination.label,
      child: CupertinoButton(
        minimumSize: Size.zero,
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: SizedBox(
          width: 60,
          height: 60,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: destination.color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: _SidebarIcon(destination: destination),
                ),
              ),
              if (showBadge)
                Positioned(
                  left: badgeOffset.dx,
                  top: badgeOffset.dy,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFFF4778),
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(width: 8, height: 8),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarIcon extends StatelessWidget {
  const _SidebarIcon({required this.destination});

  final _SidebarDestination destination;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CustomPaint(
        size: const Size(36, 36),
        painter: _GlossSidebarIconPainter(destination: destination),
      ),
    );
  }
}

class _GlossSidebarIconPainter extends CustomPainter {
  const _GlossSidebarIconPainter({required this.destination});

  final _SidebarDestination destination;

  @override
  void paint(Canvas canvas, Size size) {
    switch (destination) {
      case _SidebarDestination.weather:
        _paintWeather(canvas, size);
      case _SidebarDestination.capsule:
        _CapsuleSidebarIconPainter(
          accent: destination.color,
        ).paint(canvas, size);
      case _SidebarDestination.legacy:
        _paintNote(canvas, size);
      case _SidebarDestination.mail:
        _paintMail(canvas, size);
      case _SidebarDestination.task:
        _paintTask(canvas, size);
      case _SidebarDestination.achievement:
        _paintAchievement(canvas, size);
      case _SidebarDestination.shop:
        _paintShop(canvas, size);
    }
  }

  void _paintAchievement(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final rect = Rect.fromLTWH(8, 7, 20, 22);
    final ribbon = Path()
      ..moveTo(13, 25)
      ..lineTo(12, 34)
      ..lineTo(18, 30)
      ..lineTo(24, 34)
      ..lineTo(23, 25)
      ..close();
    canvas.drawPath(
      ribbon,
      paint..color = Colors.white.withValues(alpha: 0.72),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      paint..color = Colors.white,
    );
    final star = Path();
    const center = Offset(18, 18);
    for (var i = 0; i < 10; i += 1) {
      final radius = i.isEven ? 7.0 : 3.2;
      final angle = -math.pi / 2 + i * math.pi / 5;
      final point = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      if (i == 0) {
        star.moveTo(point.dx, point.dy);
      } else {
        star.lineTo(point.dx, point.dy);
      }
    }
    star.close();
    canvas.drawPath(star, Paint()..color = destination.color);
  }

  void _paintWeather(Canvas canvas, Size size) {
    final white = Paint()..color = Colors.white;
    final sunPaint = Paint()..color = Colors.white.withValues(alpha: 0.96);
    final rayPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    _drawCircleShadow(canvas, const Offset(22.5, 12), 5.2);
    canvas.drawCircle(const Offset(22.5, 12), 5.2, sunPaint);

    for (final angle in const [
      -math.pi / 2,
      -math.pi / 5,
      0.1,
      math.pi / 3.4,
    ]) {
      final start = Offset(
        22.5 + math.cos(angle) * 7.6,
        12 + math.sin(angle) * 7.6,
      );
      final end = Offset(
        22.5 + math.cos(angle) * 10.5,
        12 + math.sin(angle) * 10.5,
      );
      canvas.drawLine(start, end, rayPaint);
    }

    final cloud = Path()
      ..moveTo(10, 25)
      ..cubicTo(7.2, 25, 5.8, 23.4, 5.8, 21.3)
      ..cubicTo(5.8, 19.2, 7.2, 17.7, 9.4, 17.4)
      ..cubicTo(10.6, 13.8, 13.5, 12.1, 16.8, 13)
      ..cubicTo(19.4, 13.7, 21, 15.6, 21.4, 18.2)
      ..cubicTo(24.5, 18.2, 26.4, 20, 26.4, 22.5)
      ..cubicTo(26.4, 24.2, 25.1, 25, 22.7, 25)
      ..close();
    _drawPathShadow(canvas, cloud, const Offset(0, 1.3));
    canvas.drawPath(cloud, white);
    canvas.drawOval(
      const Rect.fromLTWH(11.2, 14, 8.2, 3.4),
      Paint()..color = Colors.white.withValues(alpha: 0.42),
    );
  }

  void _paintMail(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(6.7, 9.5, 22.6, 17.6),
      const Radius.circular(2.6),
    );
    final body = Path()..addRRect(rect);
    _drawPathShadow(canvas, body, const Offset(0, 1.5));
    canvas.drawRRect(rect, Paint()..color = Colors.white);

    final linePaint = Paint()
      ..color = destination.color.withValues(alpha: 0.54)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final flap = Path()
      ..moveTo(8.2, 12.1)
      ..lineTo(18, 19.2)
      ..lineTo(27.8, 12.1);
    final bottom = Path()
      ..moveTo(8.4, 25.1)
      ..lineTo(15.8, 18.2)
      ..moveTo(27.6, 25.1)
      ..lineTo(20.2, 18.2);
    canvas.drawPath(flap, linePaint);
    canvas.drawPath(bottom, linePaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8.8, 11.5, 18.4, 4.8),
        const Radius.circular(2.4),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
  }

  void _paintTask(Canvas canvas, Size size) {
    final pin = Path()
      ..moveTo(18, 7)
      ..cubicTo(11.6, 7, 7.2, 11.4, 7.2, 17.1)
      ..cubicTo(7.2, 24.3, 15.2, 29.8, 18, 32)
      ..cubicTo(20.8, 29.8, 28.8, 24.3, 28.8, 17.1)
      ..cubicTo(28.8, 11.4, 24.4, 7, 18, 7)
      ..close();

    _drawPathShadow(canvas, pin, const Offset(0, 1.4));
    canvas.drawPath(pin, Paint()..color = Colors.white);

    final check = Path()
      ..moveTo(13.8, 16.8)
      ..lineTo(16.9, 19.9)
      ..lineTo(22.5, 14.1);
    canvas.drawPath(
      check,
      Paint()
        ..color = destination.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final base = Path()
      ..moveTo(9.5, 30.2)
      ..cubicTo(13.3, 33, 22.7, 33, 26.5, 30.2);
    canvas.drawPath(
      base,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintNote(Canvas canvas, Size size) {
    final doc = Path()
      ..moveTo(10.5, 6.7)
      ..lineTo(22.2, 6.7)
      ..lineTo(27.4, 12)
      ..lineTo(27.4, 29.1)
      ..lineTo(10.5, 29.1)
      ..close();
    _drawPathShadow(canvas, doc, const Offset(0, 1.6));
    canvas.drawPath(doc, Paint()..color = Colors.white);

    final fold = Path()
      ..moveTo(22.2, 6.7)
      ..lineTo(22.2, 12)
      ..lineTo(27.4, 12)
      ..close();
    canvas.drawPath(
      fold,
      Paint()..color = destination.color.withValues(alpha: 0.18),
    );
    canvas.drawPath(
      fold,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final linePaint = Paint()
      ..color = destination.color.withValues(alpha: 0.45)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      const Offset(14, 17.2),
      const Offset(23.7, 17.2),
      linePaint,
    );
    canvas.drawLine(
      const Offset(14, 21.7),
      const Offset(24.8, 21.7),
      linePaint,
    );
    canvas.drawLine(const Offset(14, 26), const Offset(21.8, 26), linePaint);
  }

  void _paintShop(Canvas canvas, Size size) {
    final crown = Path()
      ..moveTo(5.6, 12.8)
      ..lineTo(12.2, 19.5)
      ..lineTo(18, 7.1)
      ..lineTo(23.8, 19.5)
      ..lineTo(30.4, 12.8)
      ..lineTo(28.2, 26.1)
      ..lineTo(7.8, 26.1)
      ..close();
    _drawPathShadow(canvas, crown, const Offset(0, 1.2));
    canvas.drawPath(crown, Paint()..color = Colors.white);

    final base = RRect.fromRectAndRadius(
      const Rect.fromLTWH(8.2, 23.4, 19.6, 8.8),
      const Radius.circular(1.6),
    );
    canvas.drawRRect(base, Paint()..color = Colors.white);

    for (final point in const [
      Offset(5.8, 12.6),
      Offset(18, 7),
      Offset(30.2, 12.6),
    ]) {
      canvas.drawCircle(point, 2.2, Paint()..color = Colors.white);
    }

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'VIP',
        style: TextStyle(
          color: Color(0xFF124DB2),
          fontSize: 7.8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(18 - textPainter.width / 2, 27 - textPainter.height / 2),
    );
  }

  void _drawPathShadow(Canvas canvas, Path path, Offset offset) {
    canvas.drawPath(
      path.shift(offset),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  void _drawCircleShadow(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center + const Offset(0, 1.2),
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  @override
  bool shouldRepaint(covariant _GlossSidebarIconPainter oldDelegate) {
    return oldDelegate.destination != destination;
  }
}

class _CapsuleSidebarIconPainter extends CustomPainter {
  const _CapsuleSidebarIconPainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final capsuleRect = Rect.fromCenter(
      center: Offset.zero,
      width: size.width * 0.92,
      height: size.height * 0.46,
    );
    final radius = Radius.circular(capsuleRect.height / 2);
    final capsule = RRect.fromRectAndRadius(capsuleRect, radius);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 4);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawRRect(capsule.shift(const Offset(0, 1.4)), shadowPaint);

    canvas.save();
    canvas.clipRRect(capsule);
    canvas.drawRect(
      Rect.fromLTRB(capsuleRect.left, capsuleRect.top, 0, capsuleRect.bottom),
      Paint()..color = Colors.white,
    );
    canvas.drawRect(
      Rect.fromLTRB(0, capsuleRect.top, capsuleRect.right, capsuleRect.bottom),
      Paint()..color = Colors.white.withValues(alpha: 0.72),
    );
    canvas.restore();

    canvas.drawLine(
      Offset(0, capsuleRect.top + 2.2),
      Offset(0, capsuleRect.bottom - 2.2),
      Paint()
        ..color = accent.withValues(alpha: 0.70)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawRRect(
      capsule,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.90)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7,
    );

    canvas.drawCircle(
      Offset(capsuleRect.right - 8, capsuleRect.top + 5),
      2.2,
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CapsuleSidebarIconPainter oldDelegate) {
    return oldDelegate.accent != accent;
  }
}

class _SidebarDestinationPage extends StatelessWidget {
  const _SidebarDestinationPage({
    required this.destination,
    required this.api,
    required this.session,
  });

  final _SidebarDestination destination;
  final CompanionApi api;
  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    if (destination == _SidebarDestination.weather) {
      return WeatherPage(
        api: api,
        agentId: session.agentId,
        agentName: session.agentName ?? '小芜',
        initialCity: session.agentCity,
      );
    }
    if (destination == _SidebarDestination.capsule) {
      return CapsulePage(api: api, session: session);
    }
    if (destination == _SidebarDestination.legacy) {
      return LastWillPage(api: api, session: session);
    }
    if (destination == _SidebarDestination.task) {
      return CheckinPage(api: api, session: session);
    }
    if (destination == _SidebarDestination.achievement) {
      return AchievementPage(api: api, session: session);
    }
    if (destination == _SidebarDestination.shop) {
      return StorePage(api: api, session: session);
    }

    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.page,
        foregroundColor: AppColors.text,
        title: Text(destination.label),
      ),
      body: const SizedBox.expand(),
    );
  }
}
