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
    super.dispose();
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
          final maxLevelCount = _maxAchievementLevelCount(unlocked);
          final visibleContentHeight = _achievementLevelContentHeight(
            context: context,
            itemCount: visible.length,
            safeBottom: safeBottom,
          );
          final maxContentHeight = _achievementLevelContentHeight(
            context: context,
            itemCount: maxLevelCount,
            safeBottom: safeBottom,
          );
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
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _AchievementLevelTabsHeaderDelegate(
                        selected: _selectedLevel,
                        tint: levelTint,
                        onSelected: _selectLevel,
                      ),
                    ),
                    if (unlocked.isEmpty)
                      SliverToBoxAdapter(
                        child: _AchievementEmptyState(
                          tint: levelTint,
                          message: '还没有被点亮的里程碑。继续自然地聊天，惊喜会在某个时刻出现。',
                        ),
                      )
                    else if (visible.isEmpty)
                      SliverToBoxAdapter(
                        child: _AchievementLevelContentReserve(
                          minHeight: maxContentHeight,
                          child: _AchievementEmptyState(
                            tint: levelTint,
                            message: '这一类还没有被点亮的里程碑。继续自然聊天，未来会在这里亮起。',
                          ),
                        ),
                      )
                    else
                      SliverToBoxAdapter(
                        child: _AchievementLevelContentReserve(
                          minHeight: maxContentHeight,
                          child: SizedBox(
                            height: visibleContentHeight,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                20,
                                0,
                                20,
                                safeBottom + 34,
                              ),
                              child: GridView.builder(
                                padding: EdgeInsets.zero,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: visible.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 14,
                                      crossAxisSpacing: 14,
                                      childAspectRatio: 0.88,
                                    ),
                                itemBuilder: (context, index) {
                                  final item = visible[index];
                                  return TweenAnimationBuilder<double>(
                                    key: ValueKey(
                                      '${_selectedLevel.keyword}-$index',
                                    ),
                                    tween: Tween(begin: 0, end: 1),
                                    duration: const Duration(milliseconds: 260),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, value, child) {
                                      return Opacity(
                                        opacity: value,
                                        child: Transform.translate(
                                          offset: Offset(
                                            (1 - value) *
                                                16 *
                                                _tabSlideDirection,
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
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

int _maxAchievementLevelCount(List<AchievementItem> items) {
  var maxCount = 0;
  for (final tab in _achievementLevelTabs) {
    final count = _achievementsForLevel(items, tab).length;
    if (count > maxCount) maxCount = count;
  }
  return maxCount;
}

double _achievementLevelContentHeight({
  required BuildContext context,
  required int itemCount,
  required double safeBottom,
}) {
  if (itemCount <= 0) {
    return 142 + safeBottom + 34;
  }
  final width = MediaQuery.sizeOf(context).width;
  const horizontalPadding = 40.0;
  const crossAxisSpacing = 14.0;
  const mainAxisSpacing = 14.0;
  const childAspectRatio = 0.88;
  final tileWidth = (width - horizontalPadding - crossAxisSpacing) / 2;
  final tileHeight = tileWidth / childAspectRatio;
  final rows = (itemCount + 1) ~/ 2;
  return rows * tileHeight + (rows - 1) * mainAxisSpacing + safeBottom + 34;
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
        final colors = AppColors.of(context);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.72, -0.34),
              radius: 0.92,
              colors: [
                color.withValues(alpha: 0.20),
                Color.lerp(colors.page, color, 0.08)!,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AchievementLevelContentReserve extends StatelessWidget {
  const _AchievementLevelContentReserve({
    required this.minHeight,
    required this.child,
  });

  final double minHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: child,
    );
  }
}

class _AchievementLevelTabsHeaderDelegate
    extends SliverPersistentHeaderDelegate {
  const _AchievementLevelTabsHeaderDelegate({
    required this.selected,
    required this.tint,
    required this.onSelected,
  });

  final _AchievementLevelTab selected;
  final Color tint;
  final ValueChanged<_AchievementLevelTab> onSelected;

  @override
  double get minExtent => 58;

  @override
  double get maxExtent => 58;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return _AchievementLevelTabsBar(
      selected: selected,
      tint: tint,
      onSelected: onSelected,
      elevated: overlapsContent || shrinkOffset > 0,
    );
  }

  @override
  bool shouldRebuild(
    covariant _AchievementLevelTabsHeaderDelegate oldDelegate,
  ) {
    return selected != oldDelegate.selected ||
        tint != oldDelegate.tint ||
        onSelected != oldDelegate.onSelected;
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
        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color.lerp(
                  AppColors.page,
                  color,
                  isDark ? 0.10 : 0.06,
                )!.withValues(alpha: isDark ? 0.92 : 0.86),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(
                      alpha: elevated ? (isDark ? 0.18 : 0.10) : 0,
                    ),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
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
                        color: AppColors.subtleFill(context, light: 0.58),
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : color.withValues(alpha: 0.30),
                          ),
                        ),
                        shadows: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.14),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
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
                            child: DecoratedBox(
                              decoration: ShapeDecoration(
                                color: isDark
                                    ? Color.lerp(
                                        AppColors.surfaceMuted,
                                        color,
                                        0.18,
                                      )!.withValues(alpha: 0.94)
                                    : Colors.white.withValues(alpha: 0.96),
                                shape: StadiumBorder(
                                  side: BorderSide(
                                    color: color.withValues(
                                      alpha: isDark ? 0.42 : 0.48,
                                    ),
                                  ),
                                ),
                                shadows: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.24),
                                    blurRadius: 14,
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
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        style: TextStyle(
                                          color: tab == selected
                                              ? (isDark
                                                    ? AppColors.text
                                                    : const Color(0xFF11181D))
                                              : (isDark
                                                    ? AppColors.muted
                                                    : const Color(0xFF59625F)),
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
              ),
            ),
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
              color: AppColors.elevatedSurface(context, light: 0.84),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : color.withValues(alpha: 0.14),
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: isDark ? 0.18 : 0.10),
                  blurRadius: 28,
                  offset: const Offset(0, 18),
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
