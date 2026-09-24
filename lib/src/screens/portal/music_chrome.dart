part of 'package:companion_flutter/main.dart';

class _MusicBackdrop extends StatelessWidget {
  const _MusicBackdrop({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final breath = Curves.easeInOutSine.transform(progress);
    final pulse = 0.5 - (0.5 - breath).abs();
    final slowDrift = (breath - 0.5) * 2;
    final counterDrift = math.sin((progress + 0.22) * math.pi * 2);
    final settled = RouteSettled.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF182033), Color(0xFF0F1624), Color(0xFF070A10)],
          stops: [0, 0.52, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.68 + pulse * 0.36,
              child: Transform.scale(
                scale: 1.0 + pulse * 0.025,
                child: CustomPaint(painter: _MusicGridPainter()),
              ),
            ),
          ),
          if (settled) ...[
            Positioned(
              right: -122 + 56 * slowDrift,
              top: 52 + 44 * counterDrift,
              child: Opacity(
                opacity: 0.78 + pulse * 0.22,
                child: Transform.rotate(
                  angle: 0.05 * slowDrift,
                  child: Transform.scale(
                    scale: 0.94 + pulse * 0.16,
                    child: _MusicGlow(
                      width: 360,
                      height: 340,
                      radius: 168,
                      color: const Color(0x63276FFF),
                      blur: 18,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: -130 - 48 * slowDrift,
              top: 220 + 54 * slowDrift,
              child: Opacity(
                opacity: 0.66 + pulse * 0.28,
                child: Transform.rotate(
                  angle: -0.06 * counterDrift,
                  child: Transform.scale(
                    scale: 0.92 + pulse * 0.18,
                    child: _MusicGlow(
                      width: 330,
                      height: 300,
                      radius: 150,
                      color: const Color(0x5018C6C0),
                      blur: 18,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: -150 + 72 * counterDrift,
              bottom: -118 + 46 * slowDrift,
              child: Opacity(
                opacity: 0.50 + pulse * 0.28,
                child: Transform.scale(
                  scale: 0.92 + pulse * 0.17,
                  child: _MusicGlow(
                    width: 360,
                    height: 320,
                    radius: 170,
                    color: const Color(0x3CFFBE3D),
                    blur: 24,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 18 + 34 * slowDrift,
              right: 28 - 26 * counterDrift,
              bottom: 78 - 42 * slowDrift,
              child: Opacity(
                opacity: 0.36 + pulse * 0.28,
                child: Transform.scale(
                  scale: 0.98 + pulse * 0.10,
                  child: _MusicGlow(
                    width: 340,
                    height: 210,
                    radius: 120,
                    color: const Color(0x4611DCC4),
                    blur: 26,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MusicGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += 44) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += 68) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MusicGlow extends StatelessWidget {
  const _MusicGlow({
    required this.width,
    required this.height,
    required this.radius,
    required this.color,
    required this.blur,
  });

  final double width;
  final double height;
  final double radius;
  final Color color;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, const Color(0x2418C6C0), Colors.transparent],
          ),
        ),
      ),
    );
  }
}

class _MusicActions extends StatelessWidget {
  const _MusicActions({required this.onBack, required this.onShare});

  final VoidCallback onBack;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _AppNavCircleButton(
          icon: CupertinoIcons.chevron_left,
          onPressed: onBack,
        ),
        const Spacer(),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: onShare,
          child: const _MusicGlassButton(
            width: 84,
            height: 48,
            radius: 19,
            child: Text(
              '发聊天',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MusicHeader extends StatelessWidget {
  const _MusicHeader({required this.agentName});

  final String agentName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SHARED RHYTHM',
            style: TextStyle(
              color: Color(0xFF7DE7FF),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 9),
          const Text(
            '一起听一首随机歌',
            style: TextStyle(
              color: Color(0xFFF7FBFF),
              fontSize: 29,
              height: 1.03,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '选一个类别，$agentName会陪你随机播一首。收藏后，下次也能把这段旋律找回来。',
            style: const TextStyle(
              color: Color(0xA8FFFFFF),
              fontSize: 13.5,
              height: 1.62,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _MusicLibrarySelector extends StatelessWidget {
  const _MusicLibrarySelector({
    required this.libraries,
    required this.selectedLibrary,
    required this.onSelected,
  });

  final List<MusicLibrary> libraries;
  final String selectedLibrary;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = math.max(libraries.length, 1);
        const railPadding = 5.0;
        final available = constraints.maxWidth - railPadding * 2;
        final slotWidth = math.max(78.0, available / count);
        final contentWidth = slotWidth * count;
        final selectedIndex = libraries.indexWhere(
          (library) => library.id == selectedLibrary,
        );
        final activeIndex = selectedIndex < 0 ? 0 : selectedIndex;
        return ClipRRect(
          borderRadius: BorderRadius.circular(23),
          child: RouteSettledBlur.backdrop(
            sigma: 24,
            child: Container(
              height: 54,
              padding: const EdgeInsets.all(railPadding),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(23),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.24),
                    blurRadius: 34,
                    offset: const Offset(0, 16),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.05),
                    blurRadius: 0,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                clipBehavior: Clip.none,
                child: SizedBox(
                  width: contentWidth,
                  height: 44,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        left: activeIndex * slotWidth,
                        top: 3,
                        width: slotWidth,
                        height: 38,
                        child: const _MusicLibraryIndicator(),
                      ),
                      Row(
                        children: [
                          for (final library in libraries)
                            SizedBox(
                              width: slotWidth,
                              height: 44,
                              child: CupertinoButton(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                onPressed: () => onSelected(library.id),
                                child: Text(
                                  library.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: library.id == selectedLibrary
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.60),
                                    fontSize: 13,
                                    fontWeight: library.id == selectedLibrary
                                        ? FontWeight.w900
                                        : FontWeight.w800,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
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

class _MusicLibraryIndicator extends StatelessWidget {
  const _MusicLibraryIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: RouteSettledBlur.backdrop(
          sigma: 18,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.18),
                  const Color(0xFF1F6FFF).withValues(alpha: 0.52),
                  const Color(0xFF18C6C0).withValues(alpha: 0.72),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF18C6C0).withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MusicInlineError extends StatelessWidget {
  const _MusicInlineError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xDFFFFFFF),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            onPressed: () => unawaited(onRetry()),
            child: const Text(
              '重试',
              style: TextStyle(
                color: Color(0xFF7DE7FF),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
