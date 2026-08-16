part of 'package:companion_flutter/main.dart';

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.selected,
    required this.title,
    required this.price,
    required this.origin,
    required this.onTap,
    this.badge,
  });

  final bool selected;
  final String title;
  final String price;
  final String origin;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    // 卡片始终是浅底：选中只把边框描成深蓝、加一圈蓝光，而不是整卡刷蓝。
    final titleColor = w.ink;
    final originColor = w.inkSoft;
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 124,
        height: 136,
        // 由容器自己按「边框内沿」裁剪，角标才能严丝合缝贴住内圆角；原来那层
        // 独立 ClipRRect(24) 的圆角中心跟边框内沿不重合，左上角会露月牙缝。
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          // 与天气页指标卡同一套中性玻璃底（不带淡蓝渐变）；选中只改描边。
          color: w.glass,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? _kStoreBlue : w.glassBorder,
            width: selected ? 2.4 : 1,
          ),
          // 选中只靠深蓝描边表达，不再叠蓝色光晕；投影始终用中性面板阴影。
          boxShadow: w.panelShadow,
        ),
        child: Stack(
          children: [
            if (badge != null)
              Positioned(
                left: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: const BoxDecoration(
                    color: _kStoreBlue,
                    // 取比边框内沿（≈21.6）更小的圆角，让容器裁剪把它修到内圆角，
                    // 保证两状态都无缝。
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            Center(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  badge == null ? 16 : 26,
                  12,
                  16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      price,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 32,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      origin,
                      style: TextStyle(
                        color: originColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: originColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
