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
  _DailyShareTab _tab = _DailyShareTab.photo;
  double _heroFade = 0;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 13000),
    )..repeat(reverse: true);
    _scrollController = ScrollController()..addListener(_syncHeroFade);
    _photosFuture = widget.api.listDailySharePhotos();
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
    final next = widget.api.listDailySharePhotos();
    setState(() => _photosFuture = next);
    await next;
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DailySharePhotosResponse>(
      future: _photosFuture,
      builder: (context, snapshot) {
        final photos = snapshot.data;
        return AnimatedBuilder(
          animation: _breathController,
          builder: (context, _) {
            final breath = Curves.easeInOut.transform(_breathController.value);
            return Scaffold(
              backgroundColor: const Color(0xFFFFFCF8),
              body: Stack(
                children: [
                  _DailyBreathingBackground(progress: breath),
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
                                breath: _breathController.value,
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
                            breath: _breathController.value,
                          )
                        else
                          const SliverToBoxAdapter(child: _DailyLinkStub()),
                        const SliverToBoxAdapter(child: SizedBox(height: 116)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _DailyPhotoContent extends StatelessWidget {
  const _DailyPhotoContent({
    required this.snapshot,
    required this.authToken,
    required this.onRetry,
    required this.onPreview,
    required this.breath,
  });

  final AsyncSnapshot<DailySharePhotosResponse> snapshot;
  final String? authToken;
  final double breath;
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
              breath: breath,
              onPreview: (photo, photoIndex) =>
                  onPreview(context, photo, group, photoIndex),
            ),
          );
        },
      ),
    );
  }
}

class _DailyPhotoGroupSection extends StatefulWidget {
  const _DailyPhotoGroupSection({
    required this.group,
    required this.authToken,
    required this.breath,
    required this.onPreview,
  });

  final DailySharePhotoGroup group;
  final String? authToken;
  final double breath;
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
                      style: const TextStyle(
                        color: AppColors.text,
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
                      style: const TextStyle(
                        color: Color(0x99707A85),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${widget.group.count} 张',
                style: const TextStyle(
                  color: Color(0x99707A85),
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
                        breath: widget.breath,
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
    required this.breath,
    required this.headers,
    required this.onTap,
  });

  final ChatAttachment photo;
  final int index;
  final double breath;
  final Map<String, String>? headers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final wave = math.sin((breath + index * 0.18) * math.pi * 2);
    return Transform.translate(
      offset: Offset(0, wave * 2.8),
      child: Transform.scale(
        scale: 1 + wave * 0.012,
        child: GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: SizedBox(
              width: _DailyRailMetrics.tileWidth,
              height: 104,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.54),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF22364A).withValues(alpha: 0.12),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
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
      ),
    );
  }
}
