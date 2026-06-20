part of 'package:companion_flutter/main.dart';

class _DailyBreathingBackground extends StatelessWidget {
  const _DailyBreathingBackground({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.page,
            Color.lerp(colors.page, colors.surfaceMuted, 0.38)!,
            Color.lerp(colors.page, colors.accentSoft, 0.20)!,
          ],
          stops: [0, 0.54, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _DailyGridPainter())),
          Positioned(
            right: -86 - progress * 14,
            top: 82 + progress * 22,
            child: _DailyAura(
              size: 258,
              colors: [
                const Color(0xFFFF7940).withValues(alpha: 0.18),
                const Color(0xFF7C3CFF).withValues(alpha: 0.12),
                AppColors.accentDeep.withValues(alpha: 0.10),
              ],
            ),
          ),
          Positioned(
            left: -80 + progress * 12,
            bottom: 52 - progress * 16,
            child: _DailyAura(
              size: 286,
              colors: [
                AppColors.accentCyan.withValues(alpha: 0.12),
                AppColors.accentDeep.withValues(alpha: 0.10),
                Colors.white.withValues(alpha: 0.02),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyAura extends StatelessWidget {
  const _DailyAura({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 11, sigmaY: 11),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
      ),
    );
  }
}

class _DailyGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF9BB0C6).withValues(alpha: 0.08)
      ..strokeWidth = 0.8;
    const gap = 42.0;
    for (var x = 0.0; x <= size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DailyGridPainter oldDelegate) => false;
}

class _DailyCircleButton extends StatelessWidget {
  const _DailyCircleButton({
    required this.icon,
    required this.onPressed,
    this.dark = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: CupertinoButton(
          minimumSize: Size.zero,
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          child: Container(
            width: dark ? 46 : 58,
            height: dark ? 46 : 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: dark
                  ? Colors.white.withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: 0.70),
              shape: dark ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: dark ? null : BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: dark ? 0.22 : 0.76),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFF343246,
                  ).withValues(alpha: dark ? 0.22 : 0.10),
                  blurRadius: 42,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: dark ? Colors.white : AppColors.text,
              size: dark ? 20 : 24,
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyRailArrow extends StatefulWidget {
  const _DailyRailArrow({
    super.key,
    required this.direction,
    required this.onPressed,
  });

  final int direction;
  final VoidCallback onPressed;

  @override
  State<_DailyRailArrow> createState() => _DailyRailArrowState();
}

class _DailyRailArrowState extends State<_DailyRailArrow> {
  static const _initialOpacity = 0.68;
  static const _idleOpacity = 0.38;
  static const _pressedOpacity = 0.24;

  Timer? _settleTimer;
  bool _pressed = false;
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    _scheduleSettleFade();
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    super.dispose();
  }

  void _scheduleSettleFade() {
    _settleTimer?.cancel();
    _settleTimer = Timer(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      setState(() => _settled = true);
    });
  }

  void _handleTapDown(TapDownDetails _) {
    _settleTimer?.cancel();
    setState(() {
      _pressed = true;
      _settled = false;
    });
  }

  void _handleTapUp(TapUpDetails _) {
    widget.onPressed();
    _releasePress();
  }

  void _handleTapCancel() => _releasePress();

  void _releasePress() {
    if (!mounted) return;
    setState(() {
      _pressed = false;
      _settled = false;
    });
    _scheduleSettleFade();
  }

  double get _opacity {
    if (_pressed) return _pressedOpacity;
    if (_settled) return _idleOpacity;
    return _initialOpacity;
  }

  Duration get _opacityDuration {
    if (_pressed) return const Duration(milliseconds: 80);
    if (_settled) return const Duration(milliseconds: 1500);
    return const Duration(milliseconds: 180);
  }

  @override
  Widget build(BuildContext context) {
    final isNext = widget.direction > 0;
    return Semantics(
      button: true,
      label: isNext ? '下一组照片' : '上一组照片',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: AnimatedOpacity(
          opacity: _opacity,
          duration: _opacityDuration,
          curve: Curves.easeOutCubic,
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1B1D23).withValues(alpha: 0.48),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1B1D23).withValues(alpha: 0.18),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  isNext
                      ? CupertinoIcons.chevron_right
                      : CupertinoIcons.chevron_left,
                  color: Colors.white,
                  size: 23,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyLoadingState extends StatelessWidget {
  const _DailyLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 34, 24, 0),
      child: Center(child: CupertinoActivityIndicator(radius: 13)),
    );
  }
}

class _DailyErrorState extends StatelessWidget {
  const _DailyErrorState({
    required this.onRetry,
    this.title = '照片暂时没拿到',
    this.subtitle = '网络恢复后再整理一次。',
  });

  final Future<void> Function() onRetry;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
      child: _DailyStateCard(
        title: title,
        subtitle: subtitle,
        actionLabel: '重试',
        onAction: onRetry,
      ),
    );
  }
}

class _DailyEmptyState extends StatelessWidget {
  const _DailyEmptyState({
    this.icon = CupertinoIcons.photo_on_rectangle,
    this.title = '还没有照片',
    this.subtitle = '聊天里发出的图片会自动出现在这里。',
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
      child: _DailyStateCard(icon: icon, title: title, subtitle: subtitle),
    );
  }
}

class _DailyStateCard extends StatelessWidget {
  const _DailyStateCard({
    required this.title,
    required this.subtitle,
    this.icon = CupertinoIcons.photo_on_rectangle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface(context, light: 0.62),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.glassBorder(context)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(icon, color: AppColors.accentDeep),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isDark
                              ? AppColors.muted
                              : const Color(0x99707A85),
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(width: 12),
                  CupertinoButton(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    color: AppColors.accentDeep,
                    onPressed: onAction,
                    child: Text(
                      actionLabel!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyImageFallback extends StatelessWidget {
  const _DailyImageFallback({this.dark = false});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: dark
          ? Colors.white.withValues(alpha: 0.08)
          : AppColors.surfaceMuted,
      child: Center(
        child: Icon(
          CupertinoIcons.photo,
          color: dark ? Colors.white70 : AppColors.muted,
          size: 24,
        ),
      ),
    );
  }
}

class _DailyPreviewCaption extends StatelessWidget {
  const _DailyPreviewCaption({required this.title, required this.note});

  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        note,
                        style: const TextStyle(
                          color: Color(0xB8FFFFFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
