part of 'package:companion_flutter/main.dart';

class _VipHeroCard extends StatefulWidget {
  const _VipHeroCard();

  @override
  State<_VipHeroCard> createState() => _VipHeroCardState();
}

class _VipHeroCardState extends State<_VipHeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathController;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breathController,
      builder: (context, child) {
        final breath = Curves.easeInOut.transform(_breathController.value);
        final isDark = AppColors.isDark(context);
        return Container(
          height: 236,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.10 + breath * 0.04),
                blurRadius: 32 + breath * 10,
                offset: Offset(0, 16 + breath * 4),
              ),
              BoxShadow(
                color: const Color(
                  0xFF7CE7D8,
                ).withValues(alpha: 0.12 + breath * 0.04),
                blurRadius: 50 + breath * 12,
                offset: const Offset(-22, 34),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(34),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.elevatedSurface(context, light: 0.72),
                        border: Border.all(
                          color: AppColors.glassBorder(context),
                        ),
                        borderRadius: BorderRadius.circular(34),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -44,
                    top: -50 - breath * 8,
                    child: Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(
                          0xFF72D6FF,
                        ).withValues(alpha: 0.16 + breath * 0.04),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -34,
                    bottom: -66 + breath * 7,
                    child: Container(
                      width: 230,
                      height: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(50),
                        color: const Color(
                          0xFF7BE7D8,
                        ).withValues(alpha: 0.13 + breath * 0.04),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 24,
                    top: 44 - breath * 9,
                    child: Transform.rotate(
                      angle: -0.018 + breath * 0.036,
                      child: Transform.scale(
                        scale: 0.985 + breath * 0.025,
                        child: _VipFloatingShape(breath: breath),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 28,
                    top: 28,
                    right: 160,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (rect) {
                            return const LinearGradient(
                              colors: [Color(0xFF0A84FF), Color(0xFF16C6D4)],
                            ).createShader(rect);
                          },
                          child: const Text(
                            'VIP PASS',
                            maxLines: 1,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '更完整的陪伴体验',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.text
                                : const Color(0xFF0B2237),
                            fontSize: 20,
                            height: 1.15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '畅聊、赠礼、装扮和活动券统一升级',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.muted
                                : const Color(0xFF6B7A86),
                            fontSize: 13,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 28,
                    right: 28,
                    bottom: 24,
                    child: Row(
                      children: const [
                        _VipMetric(label: '畅聊', value: '∞'),
                        SizedBox(width: 10),
                        _VipMetric(label: '赠票/月', value: '39'),
                        SizedBox(width: 10),
                        _VipMetric(label: '通话+', value: '30m'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VipFloatingShape extends StatelessWidget {
  const _VipFloatingShape({required this.breath});

  final double breath;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      height: 128,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -0.16,
            child: Container(
              width: 96,
              height: 108,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF8CEBFF),
                    Color(0xFF35B8FF),
                    Color(0xFF0A84FF),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(
                      alpha: 0.24 + breath * 0.08,
                    ),
                    blurRadius: 26 + breath * 8,
                    offset: Offset(0, 14 + breath * 5),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.50),
                    blurRadius: 10,
                    offset: const Offset(-5, -5),
                  ),
                ],
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(16 + breath * 2, -18 - breath * 3),
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.56),
                  width: 1.4,
                ),
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.34 + breath * 0.10),
                    Colors.white.withValues(alpha: 0.04),
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

class _VipMetric extends StatelessWidget {
  const _VipMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Expanded(
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.subtleFill(context, light: 0.58),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: AppColors.glassBorder(context)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? AppColors.muted : const Color(0xFF6D7984),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberBenefitGrid extends StatelessWidget {
  const _MemberBenefitGrid();

  static const _benefits = [
    ('对话畅聊', '不限次对话', CupertinoIcons.chat_bubble_2_fill),
    ('秒票赠礼', '每月赠送39秒票', Icons.extension),
    ('免广告', '无广告流畅体验', CupertinoIcons.rectangle_badge_xmark),
    ('活动券赠礼', '每月赠游戏&电影券', CupertinoIcons.phone_fill),
    ('更长通话', '每日时长+30分钟', CupertinoIcons.textformat_abc),
    ('VIP专属装扮', '解锁专属聊天皮肤', Icons.palette),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _benefits.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.48,
      ),
      itemBuilder: (context, index) {
        final item = _benefits[index];
        final isDark = AppColors.isDark(context);
        return _GlassCard(
          padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
          radius: 20,
          child: Row(
            children: [
              _CircleIcon(icon: item.$3, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.muted
                            : const Color(0xFF5D6873),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
