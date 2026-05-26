part of 'package:companion_flutter/main.dart';

class OfflineInteractionPage extends StatefulWidget {
  const OfflineInteractionPage({super.key, required this.agentName});

  final String agentName;

  @override
  State<OfflineInteractionPage> createState() => _OfflineInteractionPageState();
}

class _OfflineInteractionPageState extends State<OfflineInteractionPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 21000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openDestination(String title) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => _OfflineDestinationPage(title: title),
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
            _OfflineBackground(progress: progress),
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      28,
                      MediaQuery.paddingOf(context).top + 52,
                      28,
                      0,
                    ),
                    child: _OfflineHero(progress: progress),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _OfflineFeatureCard(
                            icon: CupertinoIcons.location_solid,
                            iconColor: const Color(0xFFFF7047),
                            title: '线下活动邀请',
                            subtitle: '周六 19:30 · 电影预约\nB612',
                            status: '已出票',
                            gradient: const [
                              Color(0xFFFFB695),
                              Color(0xFFFFD98D),
                              Color(0xFFFFF0BF),
                            ],
                            onTap: () => _openDestination('线下活动邀请'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _OfflineFeatureCard(
                            icon: CupertinoIcons.arrow_up_right,
                            iconColor: const Color(0xFF2D73FF),
                            title: '动态进程显示',
                            subtitle: '外卖、包裹和任务集中追踪',
                            status: '3 进行中',
                            gradient: const [
                              Color(0xFF88B7FF),
                              Color(0xFF63CEEA),
                              Color(0xFFBDF7E3),
                            ],
                            onTap: () => _openDestination('动态进程显示'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 26)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: _OfflineWaitingPanel(
                      agentName: widget.agentName,
                      onTap: (title) => _openDestination(title),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 140)),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _OfflineBackground extends StatelessWidget {
  const _OfflineBackground({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFCF7), Color(0xFFF7FCFF), Color(0xFFF0FBF7)],
          stops: [0, 0.52, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _OnlineGridPainter())),
          Positioned(
            right: -78 + 12 * progress,
            top: 88 + 8 * progress,
            child: Transform.rotate(
              angle:
                  (-7 + math.sin(progress * math.pi * 2) * 1.2) * math.pi / 180,
              child: const _OfflineBreathingPlate(),
            ),
          ),
          Positioned(
            left: -76 - 6 * progress,
            top: 388 + 9 * progress,
            child: _OnlineAura(
              size: const Size(270, 230),
              color: const Color(0x34FFD3AA),
              blur: 42,
            ),
          ),
          Positioned(
            right: -32 + 6 * progress,
            bottom: 78 - 8 * progress,
            child: _OnlineAura(
              size: const Size(230, 210),
              color: const Color(0x35D7D7FF),
              blur: 38,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.76, -0.62),
                  radius: 0.78 + 0.02 * progress,
                  colors: [
                    Colors.white.withValues(alpha: 0.66),
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

class _OfflineBreathingPlate extends StatelessWidget {
  const _OfflineBreathingPlate();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      height: 214,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(72),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x6E8DB8FF), Color(0x4B78D6FF), Color(0x3845D4C5)],
          stops: [0, 0.58, 1],
        ),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(72),
        gradient: const RadialGradient(
          center: Alignment(-0.10, -0.40),
          radius: 0.56,
          colors: [Color(0xAAFFFFFF), Color(0x2EFFFFFF), Colors.transparent],
          stops: [0, 0.50, 1],
        ),
      ),
    );
  }
}

class _OfflineHero extends StatelessWidget {
  const _OfflineHero({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            left: 0,
            top: 10,
            child: Text(
              'REAL WORLD BOARD',
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 14,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const Positioned(
            left: 0,
            top: 54,
            child: Text(
              '我想，参与你的每\n一个真实时刻',
              style: TextStyle(
                color: Color(0xFF11161A),
                fontSize: 34,
                height: 1.06,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 168,
            child: Text(
              '那些你说过的约定、期待和小事，我都记得。',
              style: TextStyle(
                color: const Color(0xFF1A2229).withValues(alpha: 0.48),
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 190,
            child: SizedBox(
              width: 210,
              height: 116,
              child: CustomPaint(
                painter: _OfflineLivePainter(progress: progress),
                child: Stack(
                  children: [
                    _OfflineLiveDot(
                      left: 22,
                      top: 74 + math.sin(progress * math.pi * 2) * 2,
                      color: const Color(0xFFFF7047),
                    ),
                    _OfflineLiveDot(
                      left: 118,
                      top: 52 - math.sin(progress * math.pi * 2 + 0.7) * 2,
                      color: const Color(0xFF2D73FF),
                    ),
                    _OfflineLiveDot(
                      left: 174,
                      top: 22 + math.sin(progress * math.pi * 2 + 1.2) * 2,
                      color: const Color(0xFF58C87B),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 12,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
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

class _OfflineLivePainter extends CustomPainter {
  const _OfflineLivePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final orange = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4
      ..color = const Color(0xFFFF8152);
    final gray = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4
      ..color = const Color(0xFFD9E1DE);

    final lift = math.sin(progress * math.pi * 2) * 3;
    final first = Path()
      ..moveTo(0, 72 + lift)
      ..cubicTo(42, 15 - lift, 84, 12 + lift, 122, 55 - lift);
    final second = Path()
      ..moveTo(126, 58 - lift)
      ..cubicTo(158, 92 + lift, 190, 70 - lift, 202, 18 + lift);
    canvas.drawPath(first, orange);
    canvas.drawPath(second, gray);
  }

  @override
  bool shouldRepaint(covariant _OfflineLivePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _OfflineLiveDot extends StatelessWidget {
  const _OfflineLiveDot({
    required this.left,
    required this.top,
    required this.color,
  });

  final double left;
  final double top;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.13),
        ),
        child: Center(
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflineFeatureCard extends StatelessWidget {
  const _OfflineFeatureCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String status;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      borderRadius: BorderRadius.circular(28),
      onPressed: onTap,
      child: Container(
        height: 182,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _OfflineCardLinePainter()),
              ),
              Positioned(
                left: 18,
                top: 18,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
              ),
              Positioned(
                right: 16,
                top: 18,
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.58),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Center(
                    child: Text(
                      status,
                      style: const TextStyle(
                        color: Color(0xFF31414C),
                        fontSize: 12,
                        height: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                top: 92,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF11161A),
                        fontSize: 20,
                        height: 1.08,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 9),
                    SizedBox(
                      height: 34,
                      child: Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(
                            0xFF16212B,
                          ).withValues(alpha: 0.58),
                          fontSize: 13,
                          height: 1.28,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '进入 ›',
                      style: TextStyle(
                        color: Color(0xFF11161A),
                        fontSize: 13,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineCardLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.26)
      ..strokeWidth = 1.2;
    for (var x = size.width * 0.50; x < size.width + 40; x += 16) {
      canvas.drawLine(
        Offset(x, size.height * 0.68),
        Offset(x + 22, size.height + 20),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OfflineWaitingPanel extends StatelessWidget {
  const _OfflineWaitingPanel({required this.agentName, required this.onTap});

  final String agentName;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              '陪你一起等',
              style: TextStyle(
                color: Color(0xFF11161A),
                fontSize: 24,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 178),
                child: Text(
                  '$agentName 只在需要你行动时提醒你',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF1A2229).withValues(alpha: 0.42),
                    fontSize: 12,
                    height: 1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _OfflineWaitRow(
          value: '19:30',
          title: '影院 B612',
          state: '已出票',
          onTap: () => onTap('影院 B612'),
        ),
        _OfflineWaitRow(
          value: '18m',
          title: '奶茶配送',
          state: '路上',
          onTap: () => onTap('奶茶配送'),
        ),
        _OfflineWaitRow(
          value: '11m',
          title: '专注计时',
          state: '进行中',
          onTap: () => onTap('专注计时'),
        ),
      ],
    );
  }
}

class _OfflineWaitRow extends StatelessWidget {
  const _OfflineWaitRow({
    required this.value,
    required this.title,
    required this.state,
    required this.onTap,
  });

  final String value;
  final String title;
  final String state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: const Color(0xFF1A2229).withValues(alpha: 0.07),
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 76,
              child: Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF11161A),
                  fontSize: 22,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF11161A),
                  fontSize: 16,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              state,
              style: TextStyle(
                color: const Color(0xFF1A2229).withValues(alpha: 0.42),
                fontSize: 14,
                height: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineDestinationPage extends StatelessWidget {
  const _OfflineDestinationPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.page,
        foregroundColor: AppColors.text,
        title: Text(title),
      ),
      body: const SizedBox.expand(),
    );
  }
}
