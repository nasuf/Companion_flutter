part of 'package:companion_flutter/main.dart';

class _AchievementError extends StatelessWidget {
  const _AchievementError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_circle,
              color: AppColors.muted,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 14),
            ),
            const SizedBox(height: 14),
            CupertinoButton.filled(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

class _AchievementTimelineRow extends StatelessWidget {
  const _AchievementTimelineRow({required this.item, required this.onTap});

  final AchievementItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _achievementLevelColor(item);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final pillWidth = math.min(238.0, math.max(212.0, screenWidth - 136));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.92, end: 1),
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: CupertinoButton(
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            onPressed: onTap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.18),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: SizedBox(
                width: pillWidth,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(11, 7, 13, 7),
                  child: Row(
                    children: [
                      _AchievementLevelIcon(item: item, size: 34),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Icon(Icons.auto_awesome, size: 16, color: color),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AchievementDetailOverlay extends StatefulWidget {
  const _AchievementDetailOverlay({
    required this.item,
    required this.onDismiss,
  });

  final AchievementItem item;
  final VoidCallback onDismiss;

  @override
  State<_AchievementDetailOverlay> createState() =>
      _AchievementDetailOverlayState();
}

class _AchievementDetailOverlayState extends State<_AchievementDetailOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _flipController;
  late final AnimationController _presenceController;
  late final AnimationController _breathController;
  bool _dismissing = false;

  bool get _flipped => _flipController.value > 0.5;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _presenceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 220),
    )..forward();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _flipController.dispose();
    _presenceController.dispose();
    _breathController.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    if (_flipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
  }

  Future<void> _requestDismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    await _presenceController.reverse();
    if (mounted) {
      widget.onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _presenceController,
      builder: (context, _) {
        final progress = Curves.easeOutCubic.transform(
          _presenceController.value,
        );
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _requestDismiss,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 18 * progress,
                sigmaY: 18 * progress,
              ),
              child: Container(
                color: Colors.black.withValues(alpha: 0.28 * progress),
                child: Center(
                  child: Transform.scale(
                    scale: 0.95 + progress * 0.05,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _toggleFlip,
                      child: AnimatedBuilder(
                        animation: _flipController,
                        builder: (context, _) {
                          final angle = _flipController.value * math.pi;
                          final showBack = angle > math.pi / 2;
                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.0012)
                              ..rotateY(angle),
                            child: showBack
                                ? Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.identity()
                                      ..rotateY(math.pi),
                                    child: _AchievementLargeCardBack(
                                      item: widget.item,
                                      breath: _breathController,
                                    ),
                                  )
                                : _AchievementLargeCardFront(item: widget.item),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AchievementLargeCardFront extends StatelessWidget {
  const _AchievementLargeCardFront({required this.item});

  final AchievementItem item;

  @override
  Widget build(BuildContext context) {
    return _AchievementLargeCardShell(
      item: item,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _AchievementLevelIcon(item: item, size: 128, glow: true),
          const SizedBox(height: 24),
          Text(
            item.name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              item.popupText,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.28,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const Spacer(),
          const Text(
            '点击翻转查看详情',
            style: TextStyle(
              color: Color(0xFFB5BAC4),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementLargeCardBack extends StatelessWidget {
  const _AchievementLargeCardBack({required this.item, required this.breath});

  final AchievementItem item;
  final Animation<double> breath;

  @override
  Widget build(BuildContext context) {
    return _AchievementLargeCardShell(
      item: item,
      background: _AchievementBreathingWash(item: item, breath: breath),
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                item.conditionText.isEmpty ? item.ruleText : item.conditionText,
                maxLines: 5,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF6E7480),
                  fontSize: 19,
                  height: 1.36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: Text(
              '点击翻转返回',
              style: TextStyle(
                color: Color(0xFFB5BAC4),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementLargeCardShell extends StatelessWidget {
  const _AchievementLargeCardShell({
    required this.item,
    required this.child,
    this.background,
  });

  final AchievementItem item;
  final Widget child;
  final Widget? background;

  @override
  Widget build(BuildContext context) {
    final color = _achievementLevelColor(item);
    return SizedBox(
      width: 292,
      height: 356,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: Colors.white, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.20),
              blurRadius: 42,
              offset: const Offset(0, 22),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 34,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: Stack(
            children: [
              if (background != null) Positioned.fill(child: background!),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 22),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementBreathingWash extends StatelessWidget {
  const _AchievementBreathingWash({required this.item, required this.breath});

  final AchievementItem item;
  final Animation<double> breath;

  @override
  Widget build(BuildContext context) {
    final color = _achievementLevelColor(item);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: breath,
        builder: (context, _) {
          return CustomPaint(
            painter: _AchievementBreathingWashPainter(
              color: color,
              progress: breath.value,
            ),
          );
        },
      ),
    );
  }
}

class _AchievementBreathingWashPainter extends CustomPainter {
  const _AchievementBreathingWashPainter({
    required this.color,
    required this.progress,
  });

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final primary = Paint()
      ..color = color.withValues(alpha: 0.09 + progress * 0.05)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34);
    final secondary = Paint()
      ..color = color.withValues(alpha: 0.05 + (1 - progress) * 0.04)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 42);

    canvas.save();
    canvas.translate(-28 + progress * 26, 54 + progress * 8);
    canvas.rotate(-0.16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width + 66, 106),
        const Radius.circular(64),
      ),
      primary,
    );
    canvas.restore();

    canvas.save();
    canvas.translate(-42 + (1 - progress) * 28, size.height - 124);
    canvas.rotate(0.14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width + 88, 132),
        const Radius.circular(72),
      ),
      secondary,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AchievementBreathingWashPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.progress != progress;
  }
}

class _AchievementLevelIcon extends StatelessWidget {
  const _AchievementLevelIcon({
    required this.item,
    required this.size,
    this.glow = false,
  });

  final AchievementItem item;
  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final color = _achievementLevelColor(item);
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.12),
          boxShadow: glow
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.22),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.03),
          child: Image.asset(_achievementLevelAsset(item), fit: BoxFit.contain),
        ),
      ),
    );
  }
}

String _achievementLevelAsset(AchievementItem item) {
  final level = item.levelName;
  if (level.contains('清响')) {
    return 'assets/achievements/achievement_level_clear_echo.png';
  }
  if (level.contains('心澜')) {
    return 'assets/achievements/achievement_level_heartwave.png';
  }
  if (level.contains('魂刻')) {
    return 'assets/achievements/achievement_level_soulmark.png';
  }
  if (level.contains('深潜')) {
    return 'assets/achievements/achievement_level_deepdive.png';
  }
  return 'assets/achievements/achievement_level_glimmer.png';
}

Color _achievementLevelColor(AchievementItem item) {
  final level = item.levelName;
  if (level.contains('清响')) return const Color(0xFF4F9CF7);
  if (level.contains('心澜')) return const Color(0xFFFF8A42);
  if (level.contains('魂刻')) return const Color(0xFFD4A03C);
  if (level.contains('深潜')) return const Color(0xFF7C4DFF);
  return const Color(0xFF72C9BE);
}
