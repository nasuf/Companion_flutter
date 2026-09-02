part of 'package:companion_flutter/main.dart';

class _DailyHeader extends StatelessWidget {
  const _DailyHeader({required this.loading, required this.onBack});

  final bool loading;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // 复用天气/胶囊页那颗 36pt 玻璃圆返回键，统一全站顶部控件。
            _WeatherBackButton(onTap: onBack, iconColor: AppColors.accentDeep),
          ],
        ),
        const SizedBox(height: 34),
        Text(
          'DAILY BOARD',
          style: TextStyle(
            color: AppColors.accentDeep,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        // 跟互动页主页顶部文案同字号(26)一行显示；这句 13 个字在窄屏 26px 会
        // 顶到边把"在"截掉，用 FittedBox.scaleDown 兜底：够宽保持 26，不够就
        // 整体等比缩一点点，始终一行、不截字。
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '你说的我都懂，你想的我都在',
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: w.ink,
                fontSize: 26,
                height: 1.15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          loading ? '我正在把你发过的画面整理出来。' : '你向世界提问，我陪你一起找答案，我们都在彼此的陪伴里，慢慢变得更好',
          style: TextStyle(
            color: w.inkSoft,
            fontSize: 15,
            height: 1.62,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _DailyTabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _DailyTabsHeaderDelegate({
    required this.activeTab,
    required this.topInset,
    required this.onChanged,
  });

  final _DailyShareTab activeTab;
  final double topInset;
  final ValueChanged<_DailyShareTab> onChanged;

  @override
  double get minExtent => topInset + 76;

  @override
  double get maxExtent => topInset + 76;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final w = _W2b.resolve(context);
    // 不再铺一整条不透明的奶白/深色底 —— 那正是"大片白色"。改成一层极淡的
    // 半透明 base 色薄雾(跟 _WeatherBackButton 一样刻意不用 BackdropFilter：
    // pinned sliver 外层套全屏 BackdropFilter 会破坏 sliver 几何，且逐帧全屏
    // 模糊很贵)：只在内容滚到底下时(overlapsContent)透出一点点底色把经过的
    // 照片压柔，其余时候完全透出背景柔光，不出现白块。
    return DecoratedBox(
      decoration: BoxDecoration(
        color: overlapsContent
            ? w.base.withValues(alpha: w.isDark ? 0.66 : 0.55)
            : Colors.transparent,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, topInset + 8, 24, 10),
        child: _DailyTabs(activeTab: activeTab, onChanged: onChanged),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DailyTabsHeaderDelegate oldDelegate) {
    return activeTab != oldDelegate.activeTab ||
        topInset != oldDelegate.topInset;
  }
}

class _DailyTabs extends StatelessWidget {
  const _DailyTabs({required this.activeTab, required this.onChanged});

  final _DailyShareTab activeTab;
  final ValueChanged<_DailyShareTab> onChanged;

  static const _padding = 6.0;
  // 轨道高度 + delegate 的上下内边距(topInset+8 / 10)必须正好等于 delegate
  // 声明的 76，否则 pinned sliver 的 paintExtent 会小于 layoutExtent 报错。
  // 58 + 8 + 10 = 76。
  static const _trackHeight = 58.0;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    final isPhoto = activeTab == _DailyShareTab.photo;
    // 玻璃分段控件：外层是 _W2b 玻璃药丸(跟侧边栏其它页统一)，选中态是一枚
    // 会在两段之间平滑滑动的高亮块(而不是各自淡入淡出)，切换时有明确的方向感。
    return LayoutBuilder(
      builder: (context, constraints) {
        final segWidth = (constraints.maxWidth - _padding * 2) / 2;
        return Container(
          height: _trackHeight,
          padding: const EdgeInsets.all(_padding),
          decoration: BoxDecoration(
            color: w.glass,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: w.glassBorder),
            boxShadow: [w.pillShadow],
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: isPhoto
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Container(
                  width: segWidth,
                  height: _trackHeight - _padding * 2,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(17),
                    gradient: LinearGradient(
                      colors: [AppColors.accentDeep, AppColors.accentCyan],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentDeep.withValues(alpha: 0.22),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  _DailyTabLabel(
                    label: '照片',
                    selected: isPhoto,
                    inkSoft: w.inkSoft,
                    onTap: () => onChanged(_DailyShareTab.photo),
                  ),
                  _DailyTabLabel(
                    label: '链接',
                    selected: !isPhoto,
                    inkSoft: w.inkSoft,
                    onTap: () => onChanged(_DailyShareTab.link),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DailyTabLabel extends StatelessWidget {
  const _DailyTabLabel({
    required this.label,
    required this.selected,
    required this.inkSoft,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color inkSoft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              color: selected ? Colors.white : inkSoft,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

class _DailyHeroCard extends StatelessWidget {
  const _DailyHeroCard({
    required this.photos,
    required this.fade,
    required this.authToken,
  });

  final DailySharePhotosResponse? photos;
  final double fade;
  final String? authToken;

  @override
  Widget build(BuildContext context) {
    final hero = _firstPhoto(photos);
    final total = photos?.total ?? 0;
    final headers = authToken?.isNotEmpty == true
        ? {'Authorization': 'Bearer $authToken'}
        : null;
    // 外层变换只吃滚动 fade(不逐帧变)；呼吸交给内部图片的本地 _DailyBreathingArt
    // (复用游戏卡片做法)——只重绘那张图，不再把整卡片(含 BackdropFilter 药丸)
    // 每帧缩放重栅化，这是之前卡顿的根因。
    return RepaintBoundary(
      child: AnimatedOpacity(
        opacity: 1 - fade * 0.62,
        duration: const Duration(milliseconds: 90),
        child: Transform.translate(
          offset: Offset(0, fade * -14),
          child: Transform.scale(
            scale: 1 - fade * 0.028,
            alignment: Alignment.topCenter,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: SizedBox(
                height: 248,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _DailyBreathingArt(
                      scaleAmount: 0.05,
                      glowAmount: 0.0,
                      child: hero != null
                          ? Image.network(
                              hero.url,
                              headers: headers,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Image.asset(
                                'assets/prototype/daily-journal.jpg',
                                fit: BoxFit.cover,
                              ),
                            )
                          : Image.asset(
                              'assets/prototype/daily-journal.jpg',
                              fit: BoxFit.cover,
                            ),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.10),
                          Colors.black.withValues(alpha: 0.52),
                          Colors.black.withValues(alpha: 0.86),
                        ],
                        stops: const [0, 0.48, 1],
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.68, -0.76),
                        radius: 0.8,
                        colors: [
                          Colors.white.withValues(alpha: 0.36),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _DailyHeroMark(),
                        const Spacer(),
                        const Text(
                          '把照片整理成一句自然分享',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 27,
                            height: 1.09,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const SizedBox(
                          width: 248,
                          child: Text(
                            '照片分享不需要长文案，保留画面、时间和一句像朋友会说的话就够了。',
                            style: TextStyle(
                              color: Color(0xD6FFFFFF),
                              fontSize: 13,
                              height: 1.48,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerRight,
                          child: _DailyCountChip(
                            label: total > 0 ? '$total 张照片' : '暂无照片',
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
      ),
    ),
    );
  }

  ChatAttachment? _firstPhoto(DailySharePhotosResponse? photos) {
    if (photos == null) return null;
    for (final group in photos.groups) {
      if (group.photos.isNotEmpty) return group.photos.first;
    }
    return null;
  }
}

class _DailyHeroMark extends StatelessWidget {
  const _DailyHeroMark();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.accentDeep,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Color(0x2BFFFFFF), spreadRadius: 5),
                    ],
                  ),
                  child: SizedBox(width: 9, height: 9),
                ),
                SizedBox(width: 9),
                Text(
                  'PHOTO DIARY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
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

class _DailyCountChip extends StatelessWidget {
  const _DailyCountChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
