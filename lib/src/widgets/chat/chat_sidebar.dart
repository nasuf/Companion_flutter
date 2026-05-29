part of 'package:companion_flutter/main.dart';

enum _SidebarDestination {
  weather('天气', Color(0xFF0A84FF)),
  capsule('胶囊', Color(0xFF7C3CFF)),
  legacy('遗言', Color(0xFF151820)),
  mail('信箱', Color(0xFF7C3CFF)),
  task('任务', Color(0xFFFF6B34)),
  list('清单', Color(0xFF08C767)),
  note('记录', Color(0xFFFF8B26));

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
    _SidebarDestination.list,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LiquidRailContainer(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
          padding: const EdgeInsets.all(12),
          child: _SidebarButton(
            destination: _SidebarDestination.note,
            onTap: () => onSelected(_SidebarDestination.note),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(38),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(38),
            border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF315B88).withValues(alpha: 0.15),
                blurRadius: 26,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.76),
                blurRadius: 1,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SidebarButton extends StatelessWidget {
  const _SidebarButton({required this.destination, required this.onTap});

  final _SidebarDestination destination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(destination.color, Colors.white, 0.08)!,
                        destination.color,
                        Color.lerp(destination.color, Colors.black, 0.08)!,
                      ],
                      stops: const [0, 0.58, 1],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.58),
                        blurRadius: 1,
                        offset: const Offset(-1, -1),
                      ),
                      BoxShadow(
                        color: destination.color.withValues(alpha: 0.22),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: _SidebarIcon(destination: destination),
                ),
              ),
              Positioned(
                right: 5,
                top: 4,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _badgeColor(destination),
                    shape: BoxShape.circle,
                    border: Border.all(color: destination.color, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _badgeColor(_SidebarDestination destination) {
    return switch (destination) {
      _SidebarDestination.weather => AppColors.accentCyan,
      _SidebarDestination.capsule => const Color(0xFFB491FF),
      _SidebarDestination.legacy => const Color(0xFF9EA4AA),
      _SidebarDestination.mail => AppColors.accent,
      _SidebarDestination.task => const Color(0xFFFFC23A),
      _SidebarDestination.list => const Color(0xFFFFC23A),
      _SidebarDestination.note => const Color(0xFFFFC23A),
    };
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
      case _SidebarDestination.list:
        _paintList(canvas, size);
      case _SidebarDestination.note:
        _paintNote(canvas, size);
    }
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
    final badge = Path();
    const center = Offset(18, 18);
    for (var i = 0; i < 20; i += 1) {
      final angle = -math.pi / 2 + i * math.pi / 10;
      final radius = i.isEven ? 13.3 : 11.3;
      final point = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      if (i == 0) {
        badge.moveTo(point.dx, point.dy);
      } else {
        badge.lineTo(point.dx, point.dy);
      }
    }
    badge.close();

    _drawPathShadow(canvas, badge, const Offset(0, 1.7));
    canvas.drawPath(badge, Paint()..color = Colors.white);
    canvas.drawCircle(
      const Offset(14, 12.8),
      3.4,
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );

    final check = Path()
      ..moveTo(12.4, 18.2)
      ..lineTo(16.3, 22.1)
      ..lineTo(24.3, 13.9);
    canvas.drawPath(
      check,
      Paint()
        ..color = destination.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintList(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(9, 8.2, 18, 21.6),
      const Radius.circular(3.4),
    );
    final body = Path()..addRRect(rect);
    _drawPathShadow(canvas, body, const Offset(0, 1.5));
    canvas.drawRRect(rect, Paint()..color = Colors.white);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(11, 10.1, 14, 4.4),
        const Radius.circular(2.2),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.20),
    );
    final check = Path()
      ..moveTo(12.8, 18.2)
      ..lineTo(16.2, 21.7)
      ..lineTo(23.5, 14.2);
    canvas.drawPath(
      check,
      Paint()
        ..color = destination.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
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
