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
          padding: const EdgeInsets.all(12),
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
            children: [
              Positioned.fill(child: _SidebarIcon(destination: destination)),
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
    if (destination == _SidebarDestination.shop) {
      return CustomPaint(
        size: const Size(60, 60),
        painter: const _ShopVipIconPainter(),
      );
    }
    return Image.asset(
      destination.assetPath,
      width: 60,
      height: 60,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}

extension on _SidebarDestination {
  String get assetPath => switch (this) {
    _SidebarDestination.weather => 'assets/chat_sidebar/sidebar-weather.png',
    _SidebarDestination.capsule => 'assets/chat_sidebar/sidebar-capsule.png',
    _SidebarDestination.legacy => 'assets/chat_sidebar/sidebar-legacy.png',
    _SidebarDestination.task => 'assets/chat_sidebar/sidebar-task.png',
    _SidebarDestination.achievement =>
      'assets/chat_sidebar/sidebar-achievement.png',
    _SidebarDestination.shop => throw StateError(
      'Shop sidebar icon is drawn to preserve the circular frame.',
    ),
    _SidebarDestination.mail => 'assets/chat_sidebar/sidebar-legacy.png',
  };
}

class _ShopVipIconPainter extends CustomPainter {
  const _ShopVipIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final blue = Paint()..color = _SidebarDestination.shop.color;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 30, blue);

    final crown = Path()
      ..moveTo(15, 25.5)
      ..lineTo(21.8, 32.4)
      ..lineTo(30, 14.7)
      ..lineTo(38.2, 32.4)
      ..lineTo(45, 25.5)
      ..lineTo(42.6, 41.7)
      ..lineTo(17.4, 41.7)
      ..close();
    canvas.drawPath(crown, Paint()..color = Colors.white);

    final base = RRect.fromRectAndRadius(
      const Rect.fromLTWH(17.7, 38.5, 24.6, 9.8),
      const Radius.circular(2),
    );
    canvas.drawRRect(base, Paint()..color = Colors.white);

    for (final point in const [
      Offset(15.2, 25.4),
      Offset(30, 14.5),
      Offset(44.8, 25.4),
    ]) {
      canvas.drawCircle(point, 2.4, Paint()..color = Colors.white);
    }

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'VIP',
        style: TextStyle(
          color: Color(0xFF124DB2),
          fontSize: 9.4,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(30 - textPainter.width / 2, 43.5 - textPainter.height / 2),
    );

    canvas.drawCircle(
      const Offset(52, 8),
      4,
      Paint()..color = const Color(0xFFFF4778),
    );
  }

  @override
  bool shouldRepaint(covariant _ShopVipIconPainter oldDelegate) => false;
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
