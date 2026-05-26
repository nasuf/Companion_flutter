part of 'package:companion_flutter/main.dart';

class OnlineInteractionPage extends StatefulWidget {
  const OnlineInteractionPage({super.key});

  @override
  State<OnlineInteractionPage> createState() => _OnlineInteractionPageState();
}

class _OnlineInteractionPageState extends State<OnlineInteractionPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 18000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openPortal(_OnlinePortal portal) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => _OnlinePortalDetailPage(portal: portal),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = Curves.easeInOut.transform(_controller.value);
        return Stack(
          children: [
            _OnlineBackground(progress: progress),
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      34,
                      MediaQuery.paddingOf(context).top + 50,
                      20,
                      0,
                    ),
                    child: _OnlineHero(progress: progress),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 126),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          mainAxisExtent: 232,
                        ),
                    itemCount: _onlinePortals.length,
                    itemBuilder: (context, index) {
                      final portal = _onlinePortals[index];
                      return Transform.translate(
                        offset: Offset(0, index.isOdd ? 12 : 0),
                        child: _OnlinePortalCard(
                          portal: portal,
                          index: index,
                          progress: progress,
                          onTap: () => _openPortal(portal),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _OnlineBackground extends StatelessWidget {
  const _OnlineBackground({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFAF4), Color(0xFFFBFBFF), Color(0xFFEEF9F8)],
          stops: [0, 0.44, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _OnlineGridPainter())),
          Positioned(
            right: -88 + 10 * progress,
            top: -4 + 8 * progress,
            child: _OnlineAura(
              size: const Size(290, 250),
              color: const Color(0x5797D0FF),
              blur: 34,
            ),
          ),
          Positioned(
            left: -126 - 5 * progress,
            top: 108 + 9 * progress,
            child: _OnlineAura(
              size: const Size(280, 250),
              color: const Color(0x4DFFD6B9),
              blur: 38,
            ),
          ),
          Positioned(
            right: -72,
            top: 408 - 10 * progress,
            child: _OnlineAura(
              size: const Size(320, 270),
              color: const Color(0x3DD9CFFF),
              blur: 42,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.70, -0.58),
                  radius: 0.72 + 0.025 * progress,
                  colors: [
                    Colors.white.withValues(alpha: 0.62),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnlineAura extends StatelessWidget {
  const _OnlineAura({
    required this.size,
    required this.color,
    required this.blur,
  });

  final Size size;
  final Color color;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: color,
        ),
      ),
    );
  }
}

class _OnlineGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0C202D3A)
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += 36) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += 36) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OnlineHero extends StatelessWidget {
  const _OnlineHero({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -2 + math.cos(progress * math.pi * 2) * 5,
            top: 4 + math.sin(progress * math.pi * 2) * 4,
            child: Transform.rotate(
              angle:
                  (13 + math.sin(progress * math.pi * 2) * 1.4) * math.pi / 180,
              child: const _OnlinePrimaryFloater(),
            ),
          ),
          Positioned(
            right: 50 + math.cos(progress * math.pi * 2 + 0.6) * 3,
            top: 108 - math.sin(progress * math.pi * 2 + 0.6) * 3,
            child: Transform.rotate(
              angle:
                  (10 + math.sin(progress * math.pi * 2 + 0.6) * 1.2) *
                  math.pi /
                  180,
              child: const _OnlineGlassTile(),
            ),
          ),
          Positioned(
            right: 60 + math.cos(progress * math.pi * 2 + 1.2) * 3,
            top: 86 + math.sin(progress * math.pi * 2 + 1.2) * 2.5,
            child: Transform.rotate(
              angle:
                  (8 - math.sin(progress * math.pi * 2) * 2.2) * math.pi / 180,
              child: const _OnlineGlassOrb(),
            ),
          ),
          const Positioned(
            left: 0,
            top: 12,
            child: Text(
              'ONLINE ROOM',
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 14,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const Positioned(
            left: 0,
            top: 58,
            child: Text(
              '我想和你做的事情\n有很多',
              style: TextStyle(
                color: Color(0xFF11161A),
                fontSize: 34,
                height: 1.04,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnlinePrimaryFloater extends StatelessWidget {
  const _OnlinePrimaryFloater();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 204,
      height: 172,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(56),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x8F3D9EFF), Color(0x4718C6C0)],
          stops: [0, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B8FDE).withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(56),
        gradient: const RadialGradient(
          center: Alignment(-0.30, -0.52),
          radius: 0.38,
          colors: [Color(0xCCFFFFFF), Color(0x2EFFFFFF), Colors.transparent],
          stops: [0, 0.62, 1],
        ),
      ),
    );
  }
}

class _OnlineGlassTile extends StatelessWidget {
  const _OnlineGlassTile();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.56),
                Colors.white.withValues(alpha: 0.12),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.50)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5184BE).withValues(alpha: 0.20),
                blurRadius: 26,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const RadialGradient(
              center: Alignment(-0.36, -0.56),
              radius: 0.42,
              colors: [
                Color(0xC7FFFFFF),
                Color(0x2EFFFFFF),
                Colors.transparent,
              ],
              stops: [0, 0.62, 1],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnlineGlassOrb extends StatelessWidget {
  const _OnlineGlassOrb();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(36),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.48),
                const Color(0xFFE8FEFF).withValues(alpha: 0.18),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.58)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF548BC4).withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.36),
                    ),
                  ),
                ),
              ),
              const _OrbitDot(left: 22, top: 20, size: 12, opacity: 1),
              const _OrbitDot(left: 72, top: 40, size: 10, opacity: 0.82),
              const _OrbitDot(left: 46, top: 72, size: 12, opacity: 0.88),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrbitDot extends StatelessWidget {
  const _OrbitDot({
    required this.left,
    required this.top,
    required this.size,
    required this.opacity,
  });

  final double left;
  final double top;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFE8FEFF).withValues(alpha: opacity),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.24),
              blurRadius: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _OnlinePortalCard extends StatelessWidget {
  const _OnlinePortalCard({
    required this.portal,
    required this.index,
    required this.progress,
    required this.onTap,
  });

  final _OnlinePortal portal;
  final int index;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      borderRadius: BorderRadius.circular(32),
      onPressed: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF40546A).withValues(alpha: 0.14),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: portal.accent.withValues(alpha: 0.12),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _BreathingPortalImage(
                portal: portal,
                progress: progress,
                phaseOffset: index * 0.72,
              ),
              const _PortalBottomBlur(),
              _PortalText(portal: portal),
            ],
          ),
        ),
      ),
    );
  }
}

class _BreathingPortalImage extends StatelessWidget {
  const _BreathingPortalImage({
    required this.portal,
    required this.progress,
    required this.phaseOffset,
  });

  final _OnlinePortal portal;
  final double progress;
  final double phaseOffset;

  @override
  Widget build(BuildContext context) {
    final wave = (math.sin(progress * math.pi * 2 + phaseOffset) + 1) / 2;
    final eased = Curves.easeInOut.transform(wave);
    final dx =
        lerpDouble(portal.motion.startX, portal.motion.endX, eased)! * 0.52;
    final dy =
        lerpDouble(portal.motion.startY, portal.motion.endY, eased)! * 0.52;
    final scale = lerpDouble(1.065, 1.085, eased)!;
    return Transform.translate(
      offset: Offset(dx, dy),
      child: Transform.scale(
        scale: scale,
        child: Image.asset(
          portal.asset,
          fit: BoxFit.cover,
          alignment: portal.alignment,
        ),
      ),
    );
  }
}

class _PortalBottomBlur extends StatelessWidget {
  const _PortalBottomBlur();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ShaderMask(
        shaderCallback: (rect) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Color(0x5C000000),
              Color(0xEA000000),
              Colors.black,
            ],
            stops: [0, 0.18, 0.46, 1],
          ).createShader(rect);
        },
        blendMode: BlendMode.dstIn,
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 174,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: 0.50),
                    Colors.white.withValues(alpha: 0.88),
                    Colors.white,
                  ],
                  stops: const [0, 0.30, 0.56, 1],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PortalText extends StatelessWidget {
  const _PortalText({required this.portal});

  final _OnlinePortal portal;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 20,
      right: 20,
      bottom: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            portal.title,
            style: const TextStyle(
              color: Color(0xFF11161A),
              fontSize: 21,
              height: 1.10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            portal.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF182026).withValues(alpha: 0.62),
              fontSize: 12,
              height: 1.34,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Text(
                portal.metric,
                style: const TextStyle(
                  color: Color(0xFF11161A),
                  fontSize: 12,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '›',
                style: TextStyle(
                  color: const Color(0xFF13191E).withValues(alpha: 0.58),
                  fontSize: 17,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OnlinePortalDetailPage extends StatelessWidget {
  const _OnlinePortalDetailPage({required this.portal});

  final _OnlinePortal portal;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.page,
        foregroundColor: AppColors.text,
        title: Text(portal.title),
      ),
      body: const SizedBox.expand(),
    );
  }
}

class _OnlinePortal {
  const _OnlinePortal({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.metric,
    required this.asset,
    required this.accent,
    required this.motion,
    this.alignment = Alignment.center,
  });

  final String id;
  final String title;
  final String subtitle;
  final String metric;
  final String asset;
  final Color accent;
  final _PortalMotion motion;
  final Alignment alignment;
}

class _PortalMotion {
  const _PortalMotion({
    required this.startX,
    required this.endX,
    required this.startY,
    required this.endY,
  });

  final double startX;
  final double endX;
  final double startY;
  final double endY;
}

const _onlinePortals = [
  _OnlinePortal(
    id: 'daily',
    title: '日常分享',
    subtitle: '照片、书影音和美食被整理成自然分享卡。',
    metric: '今日 5 张',
    asset: 'assets/prototype/daily-journal.jpg',
    accent: Color(0xFFFFB58C),
    motion: _PortalMotion(startX: 6, endX: -7, startY: 5, endY: -5),
  ),
  _OnlinePortal(
    id: 'movie',
    title: '一起看电影',
    subtitle: '海报轮播、同步进度、共同弹幕。',
    metric: '房间就绪',
    asset: 'assets/prototype/movie-bouquet.jpg',
    accent: Color(0xFFFFC936),
    motion: _PortalMotion(startX: -7, endX: 8, startY: 4, endY: -6),
    alignment: Alignment(0, -0.48),
  ),
  _OnlinePortal(
    id: 'game',
    title: '一起玩游戏',
    subtitle: '动态棋盘、低压力小游戏和语音同步。',
    metric: '16 个游戏',
    asset: 'assets/prototype/game-pieces.jpg',
    accent: Color(0xFF18C6C0),
    motion: _PortalMotion(startX: 8, endX: -6, startY: -5, endY: 6),
  ),
  _OnlinePortal(
    id: 'music',
    title: '一起听音乐',
    subtitle: '同步播放、共享乐评和轻聊天。',
    metric: '播放中',
    asset: 'assets/prototype/vinyl-record.jpg',
    accent: Color(0xFF7C3CFF),
    motion: _PortalMotion(startX: -5, endX: 7, startY: -4, endY: 5),
  ),
];
