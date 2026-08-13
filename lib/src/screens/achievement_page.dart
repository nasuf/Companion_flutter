part of 'package:companion_flutter/main.dart';

class AchievementPage extends StatefulWidget {
  const AchievementPage({super.key, required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<AchievementPage> createState() => _AchievementPageState();
}

class _AchievementPageState extends State<AchievementPage> {
  late Future<AchievementsResponse> _future;
  final ScrollController _scrollController = ScrollController();
  final Set<int> _flipped = <int>{};

  /// tab 条是否已经吸顶。吸顶后要把状态栏那条也铺成面板色，否则面板上沿会
  /// 跟页面渐变切出一条横线。
  final ValueNotifier<bool> _tabsPinned = ValueNotifier<bool>(false);

  _AchievementLevelTab _selectedLevel = _achievementLevelTabs.first;
  int _tabSlideDirection = 1;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabsPinned.dispose();
    super.dispose();
  }

  /// 由 header delegate 在帧末回调（delegate 的 build 跑在 layout 期，
  /// 当场改 notifier 会变成 layout 中途触发重建）。
  void _setTabsPinned(bool value) {
    if (!mounted || _tabsPinned.value == value) return;
    _tabsPinned.value = value;
  }

  Future<AchievementsResponse> _load() {
    final agentId = widget.session.agentId;
    if (agentId == null || agentId.isEmpty) {
      throw const ApiException(400, '尚未创建 AI');
    }
    return widget.api.listAchievements(agentId: agentId);
  }

  void _retry() {
    setState(() => _future = _load());
  }

  void _selectLevel(_AchievementLevelTab value) {
    if (value == _selectedLevel) return;
    final previousOffset = _scrollController.hasClients
        ? _scrollController.offset
        : null;
    final oldIndex = _achievementLevelTabs.indexOf(_selectedLevel);
    final newIndex = _achievementLevelTabs.indexOf(value);
    setState(() {
      _tabSlideDirection = newIndex >= oldIndex ? 1 : -1;
      _selectedLevel = value;
    });
    if (previousOffset == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      final target = previousOffset.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((_scrollController.offset - target).abs() > 0.5) {
        _scrollController.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final topInset = MediaQuery.paddingOf(context).top;
    final levelTint = _selectedLevel.color;
    return Scaffold(
      backgroundColor: AppColors.page,
      body: FutureBuilder<AchievementsResponse>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return SafeArea(
              bottom: false,
              child: _AchievementError(
                message: '${snapshot.error}',
                onRetry: _retry,
              ),
            );
          }
          final data = snapshot.data!;
          final unlocked = _unlockedAchievements(data.items);
          final visible = _achievementsForLevel(unlocked, _selectedLevel);
          final panel = _achievementPanelColor(context, levelTint);
          final Widget levelContent;
          if (unlocked.isEmpty) {
            levelContent = _AchievementEmptyState(
              tint: levelTint,
              message: '还没有被点亮的里程碑。继续自然地聊天，惊喜会在某个时刻出现。',
            );
          } else if (visible.isEmpty) {
            levelContent = _AchievementEmptyState(
              tint: levelTint,
              message: '这一类还没有被点亮的里程碑。继续自然聊天，未来会在这里亮起。',
            );
          } else {
            // 网格自己撑高（shrinkWrap），不再手算行高、也不再按「最长的那个
            // tab」预留高度——卡片少的层级就该是一屏装得下、不用滚。
            levelContent = Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, safeBottom + 34),
              child: GridView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visible.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.88,
                ),
                itemBuilder: (context, index) {
                  final item = visible[index];
                  return TweenAnimationBuilder<double>(
                    key: ValueKey('${_selectedLevel.keyword}-$index'),
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(
                            (1 - value) * 16 * _tabSlideDirection,
                            0,
                          ),
                          child: child,
                        ),
                      );
                    },
                    child: _AchievementCard(
                      item: item,
                      flipped: _flipped.contains(item.id),
                      onTap: () {
                        setState(() {
                          if (!_flipped.add(item.id)) {
                            _flipped.remove(item.id);
                          }
                        });
                      },
                    ),
                  );
                },
              ),
            );
          }
          return Stack(
            children: [
              Positioned.fill(
                child: _AchievementPageBackground(tint: levelTint),
              ),
              SafeArea(
                bottom: false,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _AchievementHeader(
                        items: unlocked,
                        score: _achievementUnlockedScore(unlocked),
                        tint: levelTint,
                      ),
                    ),
                    // tab 条是这张面板的顶边（带上圆角），内容区接着同色往下铺，
                    // 两者之间刻意不画任何分界线。
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _AchievementLevelTabsHeaderDelegate(
                        selected: _selectedLevel,
                        tint: levelTint,
                        onSelected: _selectLevel,
                        onPinnedChanged: _setTabsPinned,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: ColoredBox(color: panel, child: levelContent),
                    ),
                    // 内容不足一屏时把面板补到屏幕底，避免下方露出页面渐变。
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: ColoredBox(
                        color: panel,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              ),
              // 滚动区起点在状态栏之下（SafeArea），所以 tab 吸顶时只能贴到状态栏
              // 下沿，上面那条仍是页面渐变，于是切出一条横线。这里在吸顶的同时
              // 把状态栏那条补成同一个面板色，面板看上去就是一直连到屏幕顶。
              //
              // 不做淡入淡出：切换恰好发生在面板边缘抵达顶端的那一帧，直接换色
              // 反而被面板自身的移动盖住，加动画只会露出一个过渡窗口。
              if (topInset > 0)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: topInset,
                  child: IgnorePointer(
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _tabsPinned,
                      builder: (context, pinned, _) => ColoredBox(
                        color: pinned ? panel : Colors.transparent,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AchievementLevelTab {
  const _AchievementLevelTab({
    required this.label,
    required this.keyword,
    required this.color,
  });

  final String label;
  final String keyword;
  final Color color;
}

const List<_AchievementLevelTab> _achievementLevelTabs = [
  _AchievementLevelTab(label: '微光', keyword: '微光', color: Color(0xFF72C9BE)),
  _AchievementLevelTab(label: '清响', keyword: '清响', color: Color(0xFF4F9CF7)),
  _AchievementLevelTab(label: '深潜', keyword: '深潜', color: Color(0xFF7C4DFF)),
  _AchievementLevelTab(label: '心澜', keyword: '心澜', color: Color(0xFFFF8A42)),
  _AchievementLevelTab(label: '魂刻', keyword: '魂刻', color: Color(0xFFD4A03C)),
];

List<AchievementItem> _achievementsForLevel(
  List<AchievementItem> items,
  _AchievementLevelTab tab,
) {
  return items.where((item) => item.levelName.contains(tab.keyword)).toList();
}

List<AchievementItem> _unlockedAchievements(List<AchievementItem> items) {
  final unlocked = items.where((item) => item.unlocked).toList();
  unlocked.sort((a, b) {
    final left = a.unlockedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final right = b.unlockedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final byTime = right.compareTo(left);
    return byTime == 0 ? a.id.compareTo(b.id) : byTime;
  });
  return unlocked;
}

int _achievementUnlockedScore(List<AchievementItem> items) {
  return items.fold<int>(0, (sum, item) => sum + item.score);
}

/// 选中态药丸的底色。药丸上是白字，五个层级色直接配白字只有「深潜」够深
/// （4.81:1），微光 1.94、心澜 2.34、魂刻 2.36 全都不可读。
///
/// 所以：够深的原样保留，不够的按 HSL 压亮度，而且**只压到刚好达标为止**——
/// 一刀切压到同一个亮度会把本来就合格的深潜也拖暗，白白丢掉原本的颜色。
/// 压暗会让色相发闷，顺带补一点饱和度拉回来。
Color _achievementTabPillColor(Color tint) {
  // 白字 4.5:1 对应的相对亮度上限。
  const maxLuminance = 0.183;
  if (tint.computeLuminance() <= maxLuminance) return tint;
  final base = HSLColor.fromColor(tint);
  final hsl = base.withSaturation(math.min(1, base.saturation * 1.12));
  var lo = 0.0;
  var hi = hsl.lightness;
  var result = hsl.withLightness(lo).toColor();
  // 二分找「仍然达标的最亮那档」，12 步足够收敛到肉眼无差。
  for (var i = 0; i < 12; i += 1) {
    final mid = (lo + hi) / 2;
    final candidate = hsl.withLightness(mid).toColor();
    if (candidate.computeLuminance() <= maxLuminance) {
      result = candidate;
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return result;
}

/// tab 条与其下方内容区共用的面板底色。刻意不透明：面板要跟顶部的渐变头区
/// 干净分开，靠上圆角自己形成边界，而不是靠一条描边。
///
/// 浅色下带 8% 层级色而不是接近纯白——卡片是纯白且没有描边，全靠这点色差
/// 加投影浮起来；面板再白一点卡片就消失了。
Color _achievementPanelColor(BuildContext context, Color tint) {
  final colors = AppColors.of(context);
  return AppColors.isDark(context)
      ? Color.lerp(colors.surface, tint, 0.05)!
      : Color.lerp(Colors.white, tint, 0.08)!;
}

class _AchievementPageBackground extends StatelessWidget {
  const _AchievementPageBackground({required this.tint});

  final Color tint;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: tint),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        final color = value ?? tint;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.72, -0.34),
              radius: 0.92,
              colors: [
                color.withValues(alpha: 0.20),
                // 外圈直接取面板色（同样用未动画的 tint）：滚到底或回弹时露出来
                // 的是同一个颜色，面板下沿就不会切出一条边。
                _achievementPanelColor(context, tint),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AchievementLevelTabsHeaderDelegate
    extends SliverPersistentHeaderDelegate {
  const _AchievementLevelTabsHeaderDelegate({
    required this.selected,
    required this.tint,
    required this.onSelected,
    required this.onPinnedChanged,
  });

  final _AchievementLevelTab selected;
  final Color tint;
  final ValueChanged<_AchievementLevelTab> onSelected;
  final ValueChanged<bool> onPinnedChanged;

  // 16 上留白 + 40 药丸 + 10 下留白，上留白要撑得住 28 的顶部圆角。
  @override
  double get minExtent => 66;

  @override
  double get maxExtent => 66;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final pinned = overlapsContent || shrinkOffset > 0;
    // 这里跑在 layout 期，直接通知会在布局中途触发重建，推到帧末。
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => onPinnedChanged(pinned),
    );
    return _AchievementLevelTabsBar(
      selected: selected,
      tint: tint,
      onSelected: onSelected,
      elevated: pinned,
    );
  }

  @override
  bool shouldRebuild(
    covariant _AchievementLevelTabsHeaderDelegate oldDelegate,
  ) {
    return selected != oldDelegate.selected ||
        tint != oldDelegate.tint ||
        onSelected != oldDelegate.onSelected ||
        onPinnedChanged != oldDelegate.onPinnedChanged;
  }
}

class _AchievementLevelTabsBar extends StatelessWidget {
  const _AchievementLevelTabsBar({
    required this.selected,
    required this.tint,
    required this.onSelected,
    required this.elevated,
  });

  final _AchievementLevelTab selected;
  final Color tint;
  final ValueChanged<_AchievementLevelTab> onSelected;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _achievementLevelTabs.indexOf(selected);
    final isDark = AppColors.isDark(context);
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: tint),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        final color = value ?? tint;
        final pill = _achievementTabPillColor(color);
        // 顶部圆角只在面板停在原位时存在；一旦吸顶就压平，读起来才像一条
        // 真正的固定栏，而不是一张卡在半路的卡片。
        //
        // 这里刻意不加任何 boxShadow：吸顶的 header 画在下方内容之上，投影哪怕
        // 只往上偏，高斯模糊照样会往下溢出十几像素，在面板中间落出一条横线。
        // 面板与渐变头区之间靠上圆角和色差分开就够了。
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          decoration: BoxDecoration(
            // 面板色一律取未动画的 tint：内容区、状态栏补条、页面渐变外圈都用
            // 同一个值，切 tab 的 420ms 里三者才不会因为各自的动画进度错开而
            // 露出接缝。动画只用在药丸/轨道这些真正需要过渡的地方。
            color: _achievementPanelColor(context, tint),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(elevated ? 0 : 28),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth =
                  constraints.maxWidth / _achievementLevelTabs.length;
              const indicatorInset = 3.0;
              const tabBarHeight = 40.0;
              final isLastTab =
                  selectedIndex == _achievementLevelTabs.length - 1;
              return Container(
                height: tabBarHeight,
                decoration: ShapeDecoration(
                  // 轨道要比面板（8% 层级色）更深一档才看得出来，不然就糊在一起。
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Color.lerp(Colors.white, color, 0.18)!,
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : color.withValues(alpha: 0.26),
                    ),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      left: isLastTab
                          ? null
                          : tabWidth * selectedIndex + indicatorInset,
                      right: isLastTab ? indicatorInset : null,
                      top: indicatorInset,
                      bottom: indicatorInset,
                      width: tabWidth - indicatorInset * 2,
                      // 选中态改成层级色实心药丸：面板变成不透明浅色之后，
                      // 原来的白色药丸会跟底色糊在一起看不出选中。
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              pill,
                              Color.lerp(pill, Colors.black, 0.10)!,
                            ],
                          ),
                          shape: const StadiumBorder(),
                          shadows: [
                            BoxShadow(
                              color: pill.withValues(alpha: 0.34),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (final tab in _achievementLevelTabs)
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onSelected(tab),
                              child: Center(
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOutCubic,
                                  style: TextStyle(
                                    color: tab == selected
                                        ? Colors.white
                                        : (isDark
                                              ? AppColors.muted
                                              : const Color(0xFF7E8784)),
                                    fontSize: 13,
                                    fontWeight: tab == selected
                                        ? FontWeight.w900
                                        : FontWeight.w700,
                                    letterSpacing: 0,
                                    decoration: TextDecoration.none,
                                  ),
                                  child: Text(tab.label),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _AchievementEmptyState extends StatelessWidget {
  const _AchievementEmptyState({required this.tint, required this.message});

  final Color tint;
  final String message;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: tint),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        final color = value ?? tint;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
            decoration: BoxDecoration(
              // 跟成就卡同一套：浅色纯白无描边，靠面板色差 + 柔光投影浮起来。
              color: isDark
                  ? AppColors.elevatedSurface(context)
                  : AppColors.of(context).surface,
              borderRadius: BorderRadius.circular(26),
              border: isDark
                  ? Border.all(color: Colors.white.withValues(alpha: 0.07))
                  : null,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: isDark ? 0.18 : 0.14),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? AppColors.muted : const Color(0xFF7C8582),
                fontSize: 14,
                height: 1.48,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        );
      },
    );
  }
}
