part of 'package:companion_flutter/main.dart';

/// 顶部只保留 VIP PASS 大标题（原来那张带光环徽标的大卡片已移除）。
class _VipTitle extends StatelessWidget {
  const _VipTitle();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      // 沿用改版前的蓝→青渐变。
      shaderCallback: (rect) => const LinearGradient(
        colors: [_kStoreBlue, Color(0xFF16C6D4)],
      ).createShader(rect),
      child: const Text(
        'VIP PASS',
        maxLines: 1,
        style: TextStyle(
          // ShaderMask 用源图的 alpha 取色，字身填白即可让渐变透出。
          color: Colors.white,
          fontSize: 34,
          height: 1.1,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _MemberBenefitGrid extends StatelessWidget {
  const _MemberBenefitGrid();

  // 图标是 design 导出的白色字形（assets/store/vip/benefit_N.png），配 css 里的
  // #2692FF 纯色圆底；顺序与 css 一致（38→43 依次对应下面六条）。
  static const _benefits = [
    ('自由畅聊', '5200轮聊天/月', 'assets/store/vip/benefit_1.png'),
    ('积分商城折扣', '商城畅享会员价', 'assets/store/vip/benefit_2.png'),
    ('钞票礼包', '40钞票/月（会员期内有效）', 'assets/store/vip/benefit_3.png'),
    ('补签卡赠礼', '每月赠2张补签卡', 'assets/store/vip/benefit_4.png'),
    ('游戏成长加速', '1.5倍游戏积分奖励', 'assets/store/vip/benefit_5.png'),
    ('音乐畅听礼包', '当月限时20小时音乐券', 'assets/store/vip/benefit_6.png'),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _benefits.length,
      // css：卡片 60 高，行距 12、列距 10。
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 10,
        mainAxisExtent: 60,
      ),
      itemBuilder: (context, index) {
        final item = _benefits[index];
        return _BenefitMetricCard(
          title: item.$1,
          caption: item.$2,
          asset: item.$3,
        );
      },
    );
  }
}

class _BenefitMetricCard extends StatelessWidget {
  const _BenefitMetricCard({
    required this.title,
    required this.caption,
    required this.asset,
  });

  final String title;
  final String caption;
  final String asset;

  // css：36px 圆底、纯色 #2692FF。
  static const _iconBlue = Color(0xFF2692FF);

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return Container(
      height: 60,
      // 左内边距贴 css，右侧只留 4：把最长副标题「40钞票/月（会员期内有效）」需要
      // 的宽度全让给文字。
      padding: const EdgeInsets.only(left: 12, right: 4),
      // 与天气页指标卡同一套：中性玻璃底（不带淡蓝渐变）+ 玻璃描边 + 面板投影。
      decoration: BoxDecoration(
        color: w.glass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: w.glassBorder),
        boxShadow: w.panelShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _iconBlue,
            ),
            child: Image.asset(asset, width: 20, height: 20, fit: BoxFit.contain),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: w.ink,
                    fontSize: 14,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 3),
                // 统一 css 的 10px，不缩放；卡片已加宽到能放下最长副标题。
                // clip 而非 ellipsis：万一极端窄屏仍放不下，也不弹省略号。
                Text(
                  caption,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    color: w.inkSoft,
                    fontSize: 10,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
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
