part of 'package:companion_flutter/main.dart';

enum _DailyShareTab { photo, link }

class DailySharePage extends StatefulWidget {
  const DailySharePage({super.key, required this.api});

  final CompanionApi api;

  @override
  State<DailySharePage> createState() => _DailySharePageState();
}

class _DailySharePageState extends State<DailySharePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathController;
  late final ScrollController _scrollController;
  late Future<DailySharePhotosResponse> _photosFuture;
  late Future<DailyShareLinksResponse> _linksFuture;
  _DailyShareTab _tab = _DailyShareTab.photo;
  double _heroFade = 0;
  final GlobalKey _titleKey = GlobalKey();
  double _extraPinSpace = 0;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 13000),
    )..repeat(reverse: true);
    _scrollController = ScrollController()..addListener(_syncHeroFade);
    _photosFuture = widget.api.listDailySharePhotos();
    _linksFuture = widget.api.listDailyShareLinks();
  }

  @override
  Widget build(BuildContext context) {
    // 每帧结束后核一次 tab 吸顶所需的底部补偿(收敛后不再 setState)。
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncTabPinSpace());
    return _buildScaffold(context);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_syncHeroFade);
    _scrollController.dispose();
    _breathController.dispose();
    super.dispose();
  }

  void _syncHeroFade() {
    final next = ((_scrollController.offset - 138) / 170).clamp(0.0, 1.0);
    if ((next - _heroFade).abs() < 0.01) return;
    setState(() => _heroFade = next);
  }

  Future<void> _refresh() async {
    final nextPhotos = widget.api.listDailySharePhotos();
    final nextLinks = widget.api.listDailyShareLinks();
    setState(() {
      _photosFuture = nextPhotos;
      _linksFuture = nextLinks;
    });
    await Future.wait([nextPhotos, nextLinks]);
  }

  Future<void> _openLink(DailyShareLink link) async {
    await _openExternalLinkPayload(
      link.componentCard.payload,
      fallbackFinalUrl: link.finalUrl,
      fallbackSourceUrl: link.sourceUrl,
    );
  }

  Future<void> _previewPhoto(
    BuildContext context,
    ChatAttachment _,
    DailySharePhotoGroup group,
    int index,
  ) async {
    final headers = widget.api.authToken?.isNotEmpty == true
        ? {'Authorization': 'Bearer ${widget.api.authToken}'}
        : null;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'daily-photo-preview',
      barrierColor: Colors.black.withValues(alpha: 0.78),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, _, __) {
        return _DailyPhotoPreviewDialog(
          group: group,
          initialIndex: index,
          headers: headers,
          onClose: () => Navigator.of(context).pop(),
        );
      },
      transitionBuilder: (context, animation, _, child) {
        final curved = Curves.easeOutCubic.transform(animation.value);
        return Opacity(
          opacity: curved,
          child: Transform.scale(scale: 1.02 - 0.02 * curved, child: child),
        );
      },
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return FutureBuilder<DailySharePhotosResponse>(
      future: _photosFuture,
      builder: (context, snapshot) {
        final photos = snapshot.data;
        // 呼吸动画不再包整页：背景自带 AnimatedBuilder，卡片各自带本地呼吸，
        // 整个 scrollview 不用每帧重建。
        return Scaffold(
          backgroundColor: _W2b.resolve(context).base,
          body: Stack(
            children: [
              _DailyBreathingBackground(controller: _breathController),
              RefreshIndicator(
                color: AppColors.accentDeep,
                onRefresh: _refresh,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        key: _titleKey,
                        padding: EdgeInsets.fromLTRB(
                          24,
                          MediaQuery.paddingOf(context).top + 34,
                          24,
                          0,
                        ),
                        child: _DailyHeader(
                          loading:
                              snapshot.connectionState ==
                              ConnectionState.waiting,
                          onBack: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _DailyTabsHeaderDelegate(
                        activeTab: _tab,
                        topInset: MediaQuery.paddingOf(context).top,
                        onChanged: (tab) => setState(() => _tab = tab),
                      ),
                    ),
                    if (_tab == _DailyShareTab.photo)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                        sliver: SliverToBoxAdapter(
                          child: _DailyHeroCard(
                            photos: photos,
                            fade: _heroFade,
                            authToken: widget.api.authToken,
                          ),
                        ),
                      ),
                    if (_tab == _DailyShareTab.photo)
                      _DailyPhotoContent(
                        snapshot: snapshot,
                        authToken: widget.api.authToken,
                        onRetry: _refresh,
                        onPreview: _previewPhoto,
                      )
                    else
                      _DailyLinkContent(
                        future: _linksFuture,
                        authToken: widget.api.authToken,
                        onRetry: _refresh,
                        onOpen: _openLink,
                      ),
                    // 底部留白 = 固定 116 + 自适应补偿(_extraPinSpace)，保证
                    // 内容再少也能把上方标题区整段滑走、让 pinned tab 停到顶部；
                    // 内容足够时补偿为 0，不产生多余空白。见 _syncTabPinSpace。
                    SliverToBoxAdapter(
                      child: SizedBox(height: 116 + _extraPinSpace),
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

  /// 自适应底部补偿：量出标题区高度(需要被滑走的部分)与"没有补偿时"的
  /// maxScrollExtent，补足到刚好能把标题区滑完、让 tab 吸顶。>1px 才写回，
  /// 内容稳定时一两帧内收敛，不会反复 setState。
  void _syncTabPinSpace() {
    if (!mounted || !_scrollController.hasClients) return;
    final box = _titleKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final titleHeight = box.size.height;
    final baseMaxScroll =
        _scrollController.position.maxScrollExtent - _extraPinSpace;
    final needed = math.max(0.0, titleHeight - baseMaxScroll);
    if ((needed - _extraPinSpace).abs() > 1) {
      setState(() => _extraPinSpace = needed);
    }
  }
}

class _DailyPhotoContent extends StatelessWidget {
  const _DailyPhotoContent({
    required this.snapshot,
    required this.authToken,
    required this.onRetry,
    required this.onPreview,
  });

  final AsyncSnapshot<DailySharePhotosResponse> snapshot;
  final String? authToken;
  final Future<void> Function() onRetry;
  final Future<void> Function(
    BuildContext context,
    ChatAttachment photo,
    DailySharePhotoGroup group,
    int index,
  )
  onPreview;

  @override
  Widget build(BuildContext context) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const SliverToBoxAdapter(child: _DailyLoadingState());
    }
    if (snapshot.hasError) {
      return SliverToBoxAdapter(child: _DailyErrorState(onRetry: onRetry));
    }
    final groups = snapshot.data?.groups ?? const <DailySharePhotoGroup>[];
    if (groups.isEmpty) {
      return const SliverToBoxAdapter(child: _DailyEmptyState());
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 28, 0, 0),
      sliver: SliverList.builder(
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _DailyPhotoGroupSection(
              group: group,
              authToken: authToken,
              onPreview: (photo, photoIndex) =>
                  onPreview(context, photo, group, photoIndex),
            ),
          );
        },
      ),
    );
  }
}

class _DailyLinkContent extends StatelessWidget {
  const _DailyLinkContent({
    required this.future,
    required this.authToken,
    required this.onRetry,
    required this.onOpen,
  });

  final Future<DailyShareLinksResponse> future;
  final String? authToken;
  final Future<void> Function() onRetry;
  final ValueChanged<DailyShareLink> onOpen;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DailyShareLinksResponse>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(child: _DailyLoadingState());
        }
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: _DailyErrorState(
              title: '链接暂时没拿到',
              subtitle: '网络恢复后再整理一次。',
              onRetry: onRetry,
            ),
          );
        }
        final groups = snapshot.data?.groups ?? const <DailyShareLinkGroup>[];
        if (groups.isEmpty) {
          return const SliverToBoxAdapter(
            child: _DailyEmptyState(
              icon: CupertinoIcons.link,
              title: '还没有链接',
              subtitle: '聊天里分享过的链接会按时间收在这里。',
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          sliver: SliverList.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: _DailyLinkGroupSection(
                  group: groups[index],
                  authToken: authToken,
                  onOpen: onOpen,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _DailyLinkGroupSection extends StatelessWidget {
  const _DailyLinkGroupSection({
    required this.group,
    required this.authToken,
    required this.onOpen,
  });

  final DailyShareLinkGroup group;
  final String? authToken;
  final ValueChanged<DailyShareLink> onOpen;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group.title,
          style: TextStyle(
            color: w.ink,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${group.count} 条 · ${group.subtitle}',
          style: TextStyle(
            color: w.inkSoft,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        for (final link in group.links) ...[
          _DailyLinkCard(
            link: link,
            authToken: authToken,
            onTap: () => onOpen(link),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _DailyLinkCard extends StatelessWidget {
  const _DailyLinkCard({
    required this.link,
    required this.authToken,
    required this.onTap,
  });

  final DailyShareLink link;
  final String? authToken;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _parseColor(link.componentCard.accent);
    final imageUrl = link.imageUrl?.trim().isNotEmpty == true
        ? link.imageUrl!.trim()
        : link.componentCard.payload['image_url']?.toString().trim();
    final body = _dailyLinkOriginalText(link);
    final w = _W2b.resolve(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          // 玻璃卡片：跟侧边栏其它页统一走 _W2b.glass/glassBorder/panelShadow。
          color: w.glass,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: w.glassBorder),
          boxShadow: w.panelShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrl?.isNotEmpty == true
                    ? Image.network(
                        imageUrl!,
                        headers: _mediaHeadersForUrl(imageUrl, authToken),
                        width: 68,
                        height: 68,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _DailyLinkIcon(accent: accent),
                      )
                    : _DailyLinkIcon(accent: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link.platform,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        body,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: w.ink,
                          fontSize: 13,
                          height: 1.34,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Text(
                      '点击打开${link.platform}app/网页',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
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

  Color _parseColor(String value) {
    final hex = value.replaceFirst('#', '').trim();
    final parsed = hex.length == 6 ? int.tryParse(hex, radix: 16) : null;
    return parsed == null ? AppColors.accent : Color(0xFF000000 | parsed);
  }

  String _dailyLinkOriginalText(DailyShareLink link) {
    for (final value in [
      link.componentCard.payload['original_text'],
      link.componentCard.payload['content_text'],
      link.componentCard.body,
      link.summary,
      link.description,
      link.title,
    ]) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }
}

class _DailyLinkIcon extends StatelessWidget {
  const _DailyLinkIcon({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      color: accent.withValues(alpha: 0.10),
      child: Icon(CupertinoIcons.link, color: accent, size: 24),
    );
  }
}

class _DailyPhotoGroupSection extends StatefulWidget {
  const _DailyPhotoGroupSection({
    required this.group,
    required this.authToken,
    required this.onPreview,
  });

  final DailySharePhotoGroup group;
  final String? authToken;
  final void Function(ChatAttachment photo, int index) onPreview;

  @override
  State<_DailyPhotoGroupSection> createState() =>
      _DailyPhotoGroupSectionState();
}

class _DailyPhotoGroupSectionState extends State<_DailyPhotoGroupSection> {
  final ScrollController _railController = ScrollController();
  double _railViewportWidth = 0;
  bool _arrowStateReady = false;
  bool _showPreviousArrow = false;
  bool _showNextArrow = false;

  @override
  void initState() {
    super.initState();
    _railController.addListener(_syncArrowVisibility);
    _scheduleArrowVisibilitySync();
  }

  @override
  void didUpdateWidget(covariant _DailyPhotoGroupSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group.photos.length != widget.group.photos.length) {
      _scheduleArrowVisibilitySync();
    }
  }

  @override
  void dispose() {
    _railController.removeListener(_syncArrowVisibility);
    _railController.dispose();
    super.dispose();
  }

  void _scheduleArrowVisibilitySync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncArrowVisibility();
    });
  }

  void _syncArrowVisibility() {
    if (!_railController.hasClients || widget.group.photos.length <= 2) {
      final estimatedMaxScrollExtent = _estimatedMaxScrollExtent;
      _setArrowVisibility(
        previous: false,
        next: estimatedMaxScrollExtent > 0.5,
      );
      return;
    }
    final position = _railController.position;
    final maxScrollExtent = math.max(
      position.maxScrollExtent,
      _estimatedMaxScrollExtent,
    );
    _setArrowVisibility(
      previous: position.pixels > 0.5,
      next: position.pixels < maxScrollExtent - 0.5,
    );
  }

  double get _estimatedMaxScrollExtent {
    return _estimatedMaxScrollExtentFor(_railViewportWidth);
  }

  double _estimatedMaxScrollExtentFor(double viewportWidth) {
    if (viewportWidth <= 0 || widget.group.photos.length <= 2) return 0;
    final photoCount = widget.group.photos.length;
    final contentWidth =
        photoCount * _DailyRailMetrics.tileWidth +
        (photoCount - 1) * _DailyRailMetrics.tileGap +
        _DailyRailMetrics.trailingPadding;
    return math.max(0, contentWidth - viewportWidth);
  }

  void _setArrowVisibility({required bool previous, required bool next}) {
    if (_arrowStateReady &&
        _showPreviousArrow == previous &&
        _showNextArrow == next) {
      return;
    }
    setState(() {
      _arrowStateReady = true;
      _showPreviousArrow = previous;
      _showNextArrow = next;
    });
  }

  void _scrollBy(int direction) {
    if (!_railController.hasClients) return;
    final position = _railController.position;
    final maxScrollExtent = math.max(
      position.maxScrollExtent,
      _estimatedMaxScrollExtent,
    );
    final target = (position.pixels + direction * 278).clamp(
      position.minScrollExtent,
      maxScrollExtent,
    );
    _setArrowVisibility(
      previous: target > 0.5,
      next: target < maxScrollExtent - 0.5,
    );
    _railController.animateTo(
      target.toDouble(),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final headers = widget.authToken?.isNotEmpty == true
        ? {'Authorization': 'Bearer ${widget.authToken}'}
        : null;
    final w = _W2b.resolve(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.group.title,
                      style: TextStyle(
                        color: w.ink,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.group.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: w.inkSoft,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${widget.group.count} 张',
                style: TextStyle(
                  color: w.inkSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 104,
          child: LayoutBuilder(
            builder: (context, constraints) {
              _railViewportWidth = constraints.maxWidth;
              _scheduleArrowVisibilitySync();
              final controllerMaxScrollExtent = _railController.hasClients
                  ? _railController.position.maxScrollExtent
                  : 0.0;
              final maxScrollExtent = math.max(
                controllerMaxScrollExtent,
                _estimatedMaxScrollExtentFor(constraints.maxWidth),
              );
              final scrollOffset = _railController.hasClients
                  ? _railController.position.pixels
                  : 0.0;
              final canScrollBack = scrollOffset > 0.5;
              final canScrollForward =
                  maxScrollExtent > 0.5 && scrollOffset < maxScrollExtent - 0.5;
              final showPreviousArrow = _arrowStateReady
                  ? _showPreviousArrow
                  : canScrollBack;
              final showNextArrow = _arrowStateReady
                  ? _showNextArrow
                  : canScrollForward;
              final leftArrowLeft = math.min(
                _DailyRailMetrics.arrowInset,
                constraints.maxWidth - _DailyRailMetrics.arrowSize,
              );
              final visibleThirdRight = math.min(
                _DailyRailMetrics.tileWidth * 3 + _DailyRailMetrics.tileGap * 2,
                constraints.maxWidth,
              );
              final rightArrowLeft = math.max(
                leftArrowLeft,
                visibleThirdRight -
                    _DailyRailMetrics.arrowInset -
                    _DailyRailMetrics.arrowSize,
              );
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  ListView.separated(
                    controller: _railController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(
                      right: _DailyRailMetrics.trailingPadding,
                    ),
                    itemCount: widget.group.photos.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: _DailyRailMetrics.tileGap),
                    itemBuilder: (context, index) {
                      final photo = widget.group.photos[index];
                      return _DailyPhotoTile(
                        photo: photo,
                        index: index,
                        headers: headers,
                        onTap: () => widget.onPreview(photo, index),
                      );
                    },
                  ),
                  if (showPreviousArrow)
                    Positioned(
                      left: leftArrowLeft,
                      top: _DailyRailMetrics.arrowTop,
                      child: _DailyRailArrow(
                        key: const ValueKey('daily-photo-rail-previous'),
                        direction: -1,
                        onPressed: () => _scrollBy(-1),
                      ),
                    ),
                  if (showNextArrow)
                    Positioned(
                      left: rightArrowLeft,
                      top: _DailyRailMetrics.arrowTop,
                      child: _DailyRailArrow(
                        key: const ValueKey('daily-photo-rail-next'),
                        direction: 1,
                        onPressed: () => _scrollBy(1),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DailyRailMetrics {
  const _DailyRailMetrics._();

  static const tileWidth = 128.0;
  static const tileGap = 11.0;
  static const arrowSize = 48.0;
  static const arrowInset = 14.0;
  static const arrowTop = 28.0;
  static const trailingPadding = 24.0;
}

class _DailyPhotoTile extends StatelessWidget {
  const _DailyPhotoTile({
    required this.photo,
    required this.index,
    required this.headers,
    required this.onTap,
  });

  final ChatAttachment photo;
  final int index;
  final Map<String, String>? headers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 呼吸交给本地 _DailyBreathingArt(复用游戏卡片做法，各图用 index 做 seed
    // 错开相位)，不再由页面级动画逐帧驱动整条 rail。
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: SizedBox(
          width: _DailyRailMetrics.tileWidth,
          height: 104,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.subtleFill(context, light: 0.54),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow.withValues(
                    alpha: AppColors.isDark(context) ? 0.48 : 0.12,
                  ),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: _DailyBreathingArt(
              seed: photo.url.hashCode ^ (index * 131),
              scaleAmount: 0.045,
              glowAmount: 0.0,
              child: Image.network(
                photo.url,
                headers: headers,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _DailyImageFallback(),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CupertinoActivityIndicator(radius: 10),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
