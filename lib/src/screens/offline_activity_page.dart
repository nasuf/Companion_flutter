part of 'package:companion_flutter/main.dart';

class OfflineActivityPage extends StatefulWidget {
  const OfflineActivityPage({
    super.key,
    required this.api,
    required this.session,
    required this.hasLocation,
    this.initialActivityId,
    this.onChanged,
  });

  final CompanionApi api;
  final AuthSession session;
  final bool hasLocation;
  final String? initialActivityId;
  final VoidCallback? onChanged;

  @override
  State<OfflineActivityPage> createState() => _OfflineActivityPageState();
}

class _OfflineActivityPageState extends State<OfflineActivityPage> {
  OfflineActivities? _data;
  bool _loading = true;
  bool _working = false;
  bool _hasLocation = false;
  bool _requestingLocation = false;
  bool _initialActivityOpened = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _hasLocation = widget.hasLocation;
    _load();
  }

  @override
  void didUpdateWidget(covariant OfflineActivityPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hasLocation != widget.hasLocation) {
      _hasLocation = widget.hasLocation;
    }
    if (oldWidget.initialActivityId != widget.initialActivityId) {
      _initialActivityOpened = false;
      _scheduleInitialActivityOpen();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.fetchOfflineActivities(
        workspaceId: widget.session.workspaceId,
      );
      if (!mounted) return;
      setState(() => _data = data);
      _scheduleInitialActivityOpen();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scheduleInitialActivityOpen() {
    final activityId = widget.initialActivityId?.trim();
    if (activityId == null || activityId.isEmpty || _initialActivityOpened) {
      return;
    }
    _initialActivityOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_openInitialActivity(activityId));
    });
  }

  Future<void> _openInitialActivity(String activityId) async {
    OfflineActivity? activity = _findLoadedActivity(activityId);
    try {
      activity ??= await widget.api.fetchOfflineActivity(activityId);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
      return;
    }
    if (!mounted) return;
    _showActivityDetail(activity);
  }

  OfflineActivity? _findLoadedActivity(String activityId) {
    final data = _data;
    if (data == null) return null;
    final candidates = <OfflineActivity>[
      if (data.latest != null) data.latest!,
      ...data.pending,
      ...data.ignored,
      ...data.completed,
    ];
    for (final activity in candidates) {
      if (activity.id == activityId) return activity;
    }
    return null;
  }

  Future<OfflineActivity?> _accept(
    OfflineActivity activity, {
    bool openDetail = true,
  }) async {
    setState(() => _working = true);
    try {
      final updated = await widget.api.acceptOfflineActivity(activity.id);
      await _load();
      widget.onChanged?.call();
      if (mounted && openDetail) _showActivityDetail(updated);
      return updated;
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
      return null;
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<bool> _ignore(OfflineActivity activity) async {
    setState(() => _working = true);
    try {
      await widget.api.ignoreOfflineActivity(activity.id);
      await _load();
      widget.onChanged?.call();
      return true;
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
      return false;
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showActivityDetail(OfflineActivity activity) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 1.0,
          minChildSize: 1.0,
          maxChildSize: 1.0,
          snap: false,
          expand: false,
          builder: (context, scrollController) => _ActivityDetailSheetShell(
            api: widget.api,
            activity: activity,
            scrollController: scrollController,
            fullscreen: true,
            onAccept: () => _accept(activity, openDetail: false),
            onIgnore: () => _ignore(activity),
            onCompleted: () {
              _load();
              widget.onChanged?.call();
            },
          ),
        );
      },
    );
  }

  Future<void> _requestLocationFromEmptyCard() async {
    if (_requestingLocation) return;
    setState(() => _requestingLocation = true);
    final hasLocation = await _requestAndSaveUserLocation(
      widget.api,
      openSettingsWhenBlocked: true,
    );
    if (!mounted) return;
    setState(() {
      _hasLocation = hasLocation || _hasLocation;
      _requestingLocation = false;
    });
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final latest = data?.latest;
    final activeActivities = _dedupeActivities([
      if (latest != null) latest,
      ...(data?.pending ?? const <OfflineActivity>[]),
    ]);
    final pendingDeck = activeActivities
        .where((activity) => activity.status == 'pending')
        .toList();
    final accepted = activeActivities
        .where((activity) => activity.status == 'accepted')
        .toList();
    final ignored = data?.ignored ?? const <OfflineActivity>[];
    final completed = data?.completed ?? const <OfflineActivity>[];
    final hasAnyActivity =
        activeActivities.isNotEmpty ||
        ignored.isNotEmpty ||
        completed.isNotEmpty;
    final colors = AppColors.of(context);
    return CupertinoPageScaffold(
      backgroundColor: colors.page,
      child: DefaultTextStyle(
        style: TextStyle(
          color: colors.text,
          fontSize: 15,
          decoration: TextDecoration.none,
        ),
        child: Stack(
          children: [
            const _ActivityPageBackdrop(),
            SafeArea(
              bottom: false,
              child: _loading
                  ? const Center(child: CupertinoActivityIndicator())
                  : CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                            child: _OfflineSubpageTopBar(
                              title: '活动',
                              onBack: () => Navigator.of(context).maybePop(),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_error != null) ...[
                                  _OfflineErrorBlock(
                                    message: _error!,
                                    onRetry: _load,
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                if (!hasAnyActivity)
                                  _ActivityEmptyLanding(
                                    hasLocation: _hasLocation,
                                    onRequestLocation:
                                        _requestLocationFromEmptyCard,
                                  )
                                else ...[
                                  if (pendingDeck.isNotEmpty)
                                    _ActivitySwipeDeck(
                                      activities: pendingDeck,
                                      authToken: widget.api.authToken,
                                      working: _working,
                                      onAccept: (activity) =>
                                          _accept(activity, openDetail: false),
                                      onIgnore: _ignore,
                                      onOpen: _showActivityDetail,
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (hasAnyActivity) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                20,
                                pendingDeck.isEmpty ? 20 : 26,
                                20,
                                0,
                              ),
                              child: _SectionTitle(
                                title: '待出行',
                                trailing: '${accepted.length}个',
                              ),
                            ),
                          ),
                          if (accepted.isEmpty)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
                                child: _SoftEmptyPanel(
                                  icon: CupertinoIcons.location_solid,
                                  title: '暂无待出行活动',
                                  subtitle: '接受邀请后，我会在这里陪你等出发',
                                ),
                              ),
                            )
                          else
                            SliverList.separated(
                              itemCount: accepted.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: _ActivityMiniCard(
                                  activity: accepted[index],
                                  authToken: widget.api.authToken,
                                  onTap: () =>
                                      _showActivityDetail(accepted[index]),
                                ),
                              ),
                            ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                              child: _SectionTitle(
                                title: '暂不考虑',
                                trailing: '${ignored.length}个',
                              ),
                            ),
                          ),
                          if (ignored.isEmpty)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
                                child: _SoftEmptyPanel(
                                  icon: CupertinoIcons.archivebox,
                                  title: '暂无暂不考虑活动',
                                  subtitle: '你暂时跳过的活动会放在这里',
                                ),
                              ),
                            )
                          else
                            SliverList.separated(
                              itemCount: ignored.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: _ActivityMiniCard(
                                  activity: ignored[index],
                                  authToken: widget.api.authToken,
                                  onTap: () =>
                                      _showActivityDetail(ignored[index]),
                                ),
                              ),
                            ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                              child: _SectionTitle(
                                title: '已完成',
                                trailing: '${completed.length}个',
                              ),
                            ),
                          ),
                          if (completed.isEmpty)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
                                child: _SoftEmptyPanel(
                                  icon: CupertinoIcons.checkmark_seal,
                                  title: '暂无已完成活动',
                                  subtitle: '参加完活动可以来这分享照片',
                                ),
                              ),
                            )
                          else
                            SliverList.separated(
                              itemCount: completed.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: _ActivityMiniCard(
                                  activity: completed[index],
                                  authToken: widget.api.authToken,
                                  onTap: () =>
                                      _showActivityDetail(completed[index]),
                                ),
                              ),
                            ),
                        ],
                        const SliverToBoxAdapter(child: SizedBox(height: 36)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

List<OfflineActivity> _dedupeActivities(List<OfflineActivity> activities) {
  final seen = <String>{};
  final deduped = <OfflineActivity>[];
  for (final activity in activities) {
    if (activity.id.isEmpty || !seen.add(activity.id)) continue;
    deduped.add(activity);
  }
  return deduped;
}

class _ActivityEmptyLanding extends StatelessWidget {
  const _ActivityEmptyLanding({
    required this.hasLocation,
    required this.onRequestLocation,
  });

  final bool hasLocation;
  final VoidCallback onRequestLocation;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 34),
        const Center(child: _ActivityBalloonHero()),
        const SizedBox(height: 22),
        Text('还没有活动记录', style: _titleStyle(context, 22)),
        const SizedBox(height: 8),
        Text(
          '我会帮你留意附近好玩的活动\n到时候跟你说～',
          textAlign: TextAlign.center,
          style: _mutedStyle(context, 15).copyWith(height: 1.55),
        ),
        const SizedBox(height: 30),
        const _ActivityInfoTile(
          icon: '💡',
          title: '活动怎么来？',
          body: '咱们聊天的时候，我会记住你的喜好，看到合适的活动就发给你，你只要告诉我有没有兴趣就行。',
        ),
        const SizedBox(height: 14),
        _ActivityInfoTile(
          icon: hasLocation ? '🎁' : '📍',
          title: hasLocation ? '小惊喜一会儿不定时有' : '让我知道你在哪',
          body: hasLocation
              ? '除了活动，我还会偶尔给你寄点小礼物，记得去看看礼物页面哦。'
              : '若不开启定位，本地景点与美食推荐将无法为你呈现',
          onTap: hasLocation ? null : onRequestLocation,
        ),
      ],
    );
  }
}

class _ActivityBalloonHero extends StatefulWidget {
  const _ActivityBalloonHero();

  @override
  State<_ActivityBalloonHero> createState() => _ActivityBalloonHeroState();
}

class _ActivityBalloonHeroState extends State<_ActivityBalloonHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _breath;

  @override
  void initState() {
    super.initState();
    // 跟本项目其它呼吸动画同一套：本地 ticker + RepaintBoundary 隔离，只重绘
    // 这一小块，流畅不牵连整页。
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4600),
    )..repeat(reverse: true);
    _breath = CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // 关键：被逐帧缩放的子树里绝不能有高斯模糊(boxShadow / 文字投影)。动画中
    // 的 Transform.scale 会让 Flutter 的光栅缓存失效，缓存里那张含模糊的图片
    // 就得每帧按新缩放重新栅化、把两条大模糊重跑一遍——这才是卡顿根因。日常
    // 分享页流畅，是因为它缩放的是一张解码好的图片(纯 GPU 贴图)、没有模糊要
    // 重算。所以这里把外发光的 boxShadow 换成"便宜"的径向渐变光晕(无模糊滤镜)；
    // 气球连同它自己的文字投影只做平移(不缩放)、并单独缓存——平移只是挪动现成
    // 图层，不会重跑那条投影模糊。
    final halo = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            colors.accent.withValues(alpha: 0.12),
            const Color(0xFFFFB48E).withValues(alpha: 0.12),
            Colors.transparent,
          ],
          stops: const [0.5, 0.76, 1],
        ),
      ),
    );
    final circle = Container(
      width: 156,
      height: 156,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.18, -0.24),
          radius: 0.82,
          colors: [
            Colors.white.withValues(alpha: 0.92),
            const Color(0xFFE9F8FF).withValues(alpha: 0.72),
            const Color(0xFFFFE6D7).withValues(alpha: 0.34),
            Colors.transparent,
          ],
          stops: const [0, 0.43, 0.72, 1],
        ),
        border: Border.all(
          color: colors.accentCyan.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
    );
    final ring = CustomPaint(
      size: const Size(176, 176),
      painter: _ActivityBalloonRingPainter(
        color: colors.accentCyan.withValues(alpha: 0.24),
      ),
    );
    // 气球单独缓存：它含一条文字投影模糊，缓存后平移只挪图层、不重跑模糊。
    const balloon = RepaintBoundary(
      child: Text(
        '🎈',
        style: TextStyle(
          fontSize: 58,
          decoration: TextDecoration.none,
          shadows: [
            Shadow(
              color: Color(0x33000000),
              blurRadius: 16,
              offset: Offset(0, 10),
            ),
          ],
        ),
      ),
    );
    return RepaintBoundary(
      child: SizedBox(
        width: 176,
        height: 176,
        child: AnimatedBuilder(
          animation: _breath,
          builder: (context, _) {
            final v = _breath.value; // 0→1→0
            return Stack(
              alignment: Alignment.center,
              children: [
                // 光晕/圆/外圈都是渐变+描边(无模糊)，逐帧缩放很便宜。
                Positioned.fill(
                  child: Transform.scale(scale: 1 + v * 0.06, child: halo),
                ),
                Transform.scale(scale: 1 + v * 0.045, child: circle),
                Transform.scale(scale: 1 + v * 0.03, child: ring),
                // 气球只上下轻浮(平移)，投影不重算。
                Transform.translate(
                  offset: Offset(0, -6 - v * 8),
                  child: balloon,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ActivityBalloonRingPainter extends CustomPainter {
  const _ActivityBalloonRingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = color;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x66FFFFFF);
    canvas.drawCircle(center, 74, outer);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 58),
      -2.55,
      1.35,
      false,
      arc,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 66),
      0.35,
      0.92,
      false,
      outer..color = color.withValues(alpha: 0.58),
    );
  }

  @override
  bool shouldRepaint(covariant _ActivityBalloonRingPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _ActivityInfoTile extends StatelessWidget {
  const _ActivityInfoTile({
    required this.icon,
    required this.title,
    required this.body,
    this.onTap,
  });

  final String icon;
  final String title;
  final String body;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final base = _softCardDecoration(context, radius: 22);
    // 保留 _softCardDecoration 的玻璃描边(亮白边缘正是玻璃感的关键)；只有可
    // 点击的 tile 才把描边换成主题色以示可交互。之前这里无脑 copyWith 一个暗
    // 灰 hairline，把玻璃边缘覆盖没了，卡片就读成一块灰底。
    final child = Container(
      padding: EdgeInsets.fromLTRB(18, 18, onTap == null ? 18 : 14, 18),
      decoration: onTap == null
          ? base
          : base.copyWith(
              border: Border.all(
                color: colors.accent.withValues(alpha: 0.30),
              ),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colors.surfaceMuted.withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 21)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _titleStyle(context, 16)),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: _mutedStyle(context, 13).copyWith(height: 1.45),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(top: 13),
              child: Icon(
                CupertinoIcons.chevron_right,
                size: 18,
                color: colors.accent.withValues(alpha: 0.76),
              ),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return child;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      borderRadius: BorderRadius.circular(22),
      onPressed: onTap,
      child: child,
    );
  }
}

class _ActivityHeroCard extends StatelessWidget {
  const _ActivityHeroCard({
    required this.activity,
    required this.authToken,
    required this.working,
    required this.onAccept,
    required this.onIgnore,
    required this.onOpen,
  });

  final OfflineActivity activity;
  final String? authToken;
  final bool working;
  final VoidCallback onAccept;
  final VoidCallback onIgnore;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final canRespond = activity.status == 'pending';
    return Container(
      decoration: _softCardDecoration(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ActivityImage(
            activity: activity,
            height: 176,
            authToken: authToken,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onOpen,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              activity.title,
                              style: _titleStyle(context, 22),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const _ActivityDetailCue(),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        activity.summary.isEmpty
                            ? activity.description
                            : activity.summary,
                        style: _mutedStyle(context, 14),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 14),
                      _MetaLine(activity: activity),
                      if ((activity.taskHint ?? '').isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEAD9),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '🎁 ${activity.taskHint}',
                            style: const TextStyle(
                              color: Color(0xFFC57342),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (canRespond) ...[
                  const SizedBox(height: 16),
                  _ActivityResponseButtons(
                    working: working,
                    onAccept: onAccept,
                    onIgnore: onIgnore,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityStateBadge extends StatelessWidget {
  const _ActivityStateBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.48)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.96),
          fontSize: 12,
          fontWeight: FontWeight.w900,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _ActivityImage extends StatelessWidget {
  const _ActivityImage({
    required this.activity,
    required this.height,
    required this.authToken,
    this.borderRadius,
  });

  final OfflineActivity activity;
  final double height;
  final String? authToken;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final image = activity.imageUrls.isNotEmpty
        ? activity.imageUrls.first
        : null;
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(18),
      child: Container(
        height: height,
        width: double.infinity,
        color: const Color(0xFFFFC098),
        child: image == null
            ? Center(
                child: Text(
                  _categoryEmoji(activity.category),
                  style: const TextStyle(fontSize: 58),
                ),
              )
            : Image.network(
                image,
                fit: BoxFit.cover,
                headers: _mediaHeadersForUrl(image, authToken),
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    _categoryEmoji(activity.category),
                    style: const TextStyle(fontSize: 58),
                  ),
                ),
              ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.activity});

  final OfflineActivity activity;

  @override
  Widget build(BuildContext context) {
    final parts = [
      if ((activity.startsAt ?? '').isNotEmpty)
        '🗓 ${_shortDate(activity.startsAt!)}',
      if ((activity.endsAt ?? '').isNotEmpty)
        '⏰ ${_shortTimeRange(activity.startsAt, activity.endsAt)}',
      if ((activity.locationName ?? activity.address ?? '').isNotEmpty)
        '📍 ${activity.locationName ?? activity.address}',
    ];
    return Text(
      parts.join('  ·  '),
      style: _mutedStyle(context, 13).copyWith(fontWeight: FontWeight.w700),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _ActivityMiniCard extends StatelessWidget {
  const _ActivityMiniCard({
    required this.activity,
    required this.authToken,
    required this.onTap,
  });

  final OfflineActivity activity;
  final String? authToken;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _softCardDecoration(context, radius: 20),
        child: Row(
          children: [
            _ActivityMiniThumb(activity: activity, authToken: authToken),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: _titleStyle(context, 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    activity.locationName ?? activity.summary,
                    style: _mutedStyle(context, 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 18,
              color: Color(0x8897A3AD),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityMiniThumb extends StatelessWidget {
  const _ActivityMiniThumb({required this.activity, required this.authToken});

  final OfflineActivity activity;
  final String? authToken;

  @override
  Widget build(BuildContext context) {
    final image = activity.imageUrls.isNotEmpty
        ? activity.imageUrls.first.trim()
        : '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: const Color(0xFFFFE0C5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: image.isEmpty
            ? Center(
                child: Text(
                  _categoryEmoji(activity.category),
                  style: const TextStyle(fontSize: 26),
                ),
              )
            : Image.network(
                image,
                fit: BoxFit.cover,
                width: 58,
                height: 58,
                headers: _mediaHeadersForUrl(image, authToken),
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    _categoryEmoji(activity.category),
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
              ),
      ),
    );
  }
}
