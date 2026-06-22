part of 'package:companion_flutter/main.dart';

class OfflineActivityPage extends StatefulWidget {
  const OfflineActivityPage({
    super.key,
    required this.api,
    required this.session,
    required this.hasLocation,
    this.onChanged,
  });

  final CompanionApi api;
  final AuthSession session;
  final bool hasLocation;
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
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept(OfflineActivity activity) async {
    setState(() => _working = true);
    try {
      final updated = await widget.api.acceptOfflineActivity(activity.id);
      await _load();
      widget.onChanged?.call();
      if (mounted) _showActivityDetail(updated);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _ignore(OfflineActivity activity) async {
    setState(() => _working = true);
    try {
      await widget.api.ignoreOfflineActivity(activity.id);
      await _load();
      widget.onChanged?.call();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showActivityDetail(OfflineActivity activity) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => _ActivityDetailSheet(
        api: widget.api,
        activity: activity,
        onCompleted: () {
          _load();
          widget.onChanged?.call();
        },
      ),
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
    final pending = (data?.pending ?? const <OfflineActivity>[])
        .where((activity) => activity.status == 'pending')
        .where((activity) => activity.id != latest?.id)
        .toList();
    final completed = data?.completed ?? const <OfflineActivity>[];
    final hasAnyActivity =
        latest != null || pending.isNotEmpty || completed.isNotEmpty;
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
                                  if (latest != null)
                                    _ActivityHeroCard(
                                      activity: latest,
                                      working: _working,
                                      onAccept: () => _accept(latest),
                                      onIgnore: () => _ignore(latest),
                                      onOpen: () => _showActivityDetail(latest),
                                    ),
                                  const SizedBox(height: 24),
                                  _SectionTitle(
                                    title: '待确定',
                                    trailing: '${pending.length}个',
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (hasAnyActivity) ...[
                          if (pending.isEmpty)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
                                child: _SoftEmptyPanel(
                                  icon: CupertinoIcons.doc_text,
                                  title: '暂无待确定活动',
                                  subtitle: '有活动我第一时间发给你',
                                ),
                              ),
                            )
                          else
                            SliverList.separated(
                              itemCount: pending.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: _ActivityMiniCard(
                                  activity: pending[index],
                                  onTap: () =>
                                      _showActivityDetail(pending[index]),
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

class _ActivityBalloonHero extends StatelessWidget {
  const _ActivityBalloonHero();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      width: 176,
      height: 176,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
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
              boxShadow: [
                BoxShadow(
                  color: colors.accent.withValues(alpha: 0.08),
                  blurRadius: 38,
                  offset: const Offset(0, 18),
                ),
                BoxShadow(
                  color: const Color(0xFFFFB48E).withValues(alpha: 0.14),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
          ),
          CustomPaint(
            size: const Size(176, 176),
            painter: _ActivityBalloonRingPainter(
              color: colors.accentCyan.withValues(alpha: 0.24),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -6),
            child: const Text(
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
          ),
        ],
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
    final child = Container(
      padding: EdgeInsets.fromLTRB(18, 18, onTap == null ? 18 : 14, 18),
      decoration: _softCardDecoration(context, radius: 22).copyWith(
        border: Border.all(
          color: onTap == null
              ? colors.hairline.withValues(alpha: 0.70)
              : colors.accent.withValues(alpha: 0.20),
          style: BorderStyle.solid,
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
    required this.working,
    required this.onAccept,
    required this.onIgnore,
    required this.onOpen,
  });

  final OfflineActivity activity;
  final bool working;
  final VoidCallback onAccept;
  final VoidCallback onIgnore;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isAccepted = activity.status == 'accepted';
    final isCompleted = activity.status == 'completed';
    return Container(
      decoration: _softCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              _ActivityImage(activity: activity, height: 176),
              Positioned(
                left: 16,
                top: 14,
                child: _ActivityStateBadge(
                  label: isAccepted
                      ? '已接受'
                      : isCompleted
                      ? '已完成'
                      : '待回复',
                  color: isAccepted || isCompleted
                      ? const Color(0xFF70C995)
                      : const Color(0xFFFFB66D),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: _titleStyle(context, 22),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
                const SizedBox(height: 16),
                if (isAccepted || isCompleted)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF70C995).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isCompleted ? '✅ 已完成活动' : '✅ 已接受邀请',
                        style: const TextStyle(
                          color: Color(0xFF358A5B),
                          fontWeight: FontWeight.w900,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          borderRadius: BorderRadius.circular(18),
                          color: const Color(0xFF72CBE6),
                          onPressed: working ? null : onAccept,
                          child: const Text(
                            '✨ 接受邀请',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          borderRadius: BorderRadius.circular(18),
                          color: colors.surfaceMuted,
                          onPressed: working ? null : onIgnore,
                          child: Text(
                            '暂不考虑',
                            style: TextStyle(
                              color: colors.text,
                              fontWeight: FontWeight.w800,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: onOpen,
                  child: const Text(
                    '查看详情 →',
                    style: TextStyle(decoration: TextDecoration.none),
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

class _ActivityStateBadge extends StatelessWidget {
  const _ActivityStateBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Color.lerp(color, AppColors.of(context).text, 0.35),
          fontSize: 12,
          fontWeight: FontWeight.w900,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _ActivityImage extends StatelessWidget {
  const _ActivityImage({required this.activity, required this.height});

  final OfflineActivity activity;
  final double height;

  @override
  Widget build(BuildContext context) {
    final image = activity.imageUrls.isNotEmpty
        ? activity.imageUrls.first
        : null;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
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
  const _ActivityMiniCard({required this.activity, required this.onTap});

  final OfflineActivity activity;
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
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE0C5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  _categoryEmoji(activity.category),
                  style: const TextStyle(fontSize: 26),
                ),
              ),
            ),
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

class _ActivityDetailSheet extends StatefulWidget {
  const _ActivityDetailSheet({
    required this.api,
    required this.activity,
    required this.onCompleted,
  });

  final CompanionApi api;
  final OfflineActivity activity;
  final VoidCallback onCompleted;

  @override
  State<_ActivityDetailSheet> createState() => _ActivityDetailSheetState();
}

class _ActivityDetailSheetState extends State<_ActivityDetailSheet> {
  final _controller = TextEditingController();
  bool _working = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    setState(() => _working = true);
    try {
      await widget.api.completeOfflineActivity(
        widget.activity.id,
        text: _controller.text.trim(),
      );
      widget.onCompleted();
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final task = widget.activity.easterEggTask;
    return _BottomSheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetGrabber(context),
          Text(widget.activity.title, style: _titleStyle(context, 22)),
          const SizedBox(height: 10),
          Text(widget.activity.description, style: _mutedStyle(context, 15)),
          const SizedBox(height: 14),
          _MetaLine(activity: widget.activity),
          if (task != null) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE8BC72)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🥚 ${task['title'] ?? '秘密彩蛋任务'}',
                    style: const TextStyle(
                      color: Color(0xFFB16B2A),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (task['body'] ?? '').toString(),
                    style: const TextStyle(
                      color: Color(0xFF87562A),
                      fontSize: 15,
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          CupertinoTextField(
            controller: _controller,
            minLines: 2,
            maxLines: 4,
            placeholder: '分享一点完成情况、文字感想或照片说明...',
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              borderRadius: BorderRadius.circular(18),
              color: const Color(0xFFFFA83E),
              onPressed: _working ? null : _complete,
              child: Text(
                _working ? '发送中...' : '📷 分享完成情况',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
