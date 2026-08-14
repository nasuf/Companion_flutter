part of 'package:companion_flutter/main.dart';

class _VipHeroCard extends StatelessWidget {
  const _VipHeroCard();

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 18),
      decoration: BoxDecoration(
        color: w.glass,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: w.glassBorder),
        boxShadow: w.panelShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VIP PASS',
                      style: TextStyle(
                        color: w.inkSoft,
                        fontSize: 12,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '更完整的陪伴体验',
                      style: TextStyle(
                        color: w.ink,
                        fontSize: 20,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '畅聊、赠礼、装扮和活动券统一升级',
                      style: TextStyle(
                        color: w.inkSoft,
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const _VipHaloMark(),
            ],
          ),
          const SizedBox(height: 16),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _VipMetric(label: '畅聊', value: '∞'),
              _VipMetric(label: '赠票/月', value: '39'),
              _VipMetric(label: '通话+', value: '30m'),
            ],
          ),
        ],
      ),
    );
  }
}

class _VipHaloMark extends StatelessWidget {
  const _VipHaloMark();

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [w.heroHalo, w.heroHalo.withValues(alpha: 0)],
              ),
            ),
            child: const SizedBox.expand(),
          ),
          Icon(
            CupertinoIcons.star_fill,
            size: 56,
            color: const Color(0xFF4B9AFF),
            shadows: w.isDark
                ? null
                : const [
                    Shadow(
                      color: Color(0x4D4C9BFF),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
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
    final w = _W2b.resolve(context);
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: w.heroChipBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: w.heroChipBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value  $label',
            style: TextStyle(
              color: w.ink,
              fontSize: 12,
              height: 1,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberBenefitGrid extends StatelessWidget {
  const _MemberBenefitGrid();

  static const _benefits = [
    ('对话畅聊', '不限次对话', CupertinoIcons.chat_bubble_2_fill),
    ('秒票赠礼', '每月39秒票', CupertinoIcons.tickets_fill),
    ('免广告', '无广告更流畅', CupertinoIcons.rectangle_badge_xmark),
    ('活动券赠礼', '每月活动券', CupertinoIcons.gift_fill),
    ('更长通话', '每日+30分钟', CupertinoIcons.phone_fill),
    ('VIP专属装扮', '专属聊天皮肤', Icons.palette),
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
        mainAxisExtent: 88,
      ),
      itemBuilder: (context, index) {
        final item = _benefits[index];
        return _BenefitMetricCard(
          title: item.$1,
          caption: item.$2,
          icon: item.$3,
        );
      },
    );
  }
}

class _BenefitMetricCard extends StatelessWidget {
  const _BenefitMetricCard({
    required this.title,
    required this.caption,
    required this.icon,
  });

  final String title;
  final String caption;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return Container(
      height: 88,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        color: w.glass,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: w.glassBorder),
        boxShadow: w.panelShadow,
      ),
      child: Row(
        children: [
          _CircleIcon(icon: icon, size: 40),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: TextStyle(
                    color: w.ink,
                    fontSize: 15,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  caption,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: TextStyle(
                    color: w.inkSoft,
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w400,
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
  }
}
