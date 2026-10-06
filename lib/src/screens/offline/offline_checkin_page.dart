part of 'package:companion_flutter/main.dart';

/// 打卡任务页（spec §5.4-6）。玻璃风格对齐天气/胶囊（_W2b 令牌）。
/// 三截：顶栏「‹ 打卡任务」 / 中部相册+地点信息卡 / 底部操作坞。
/// 未到达坞：我已经抵达这里 · 抽一句此行小预言 · 出门小说明。
/// 已到达坞：✓ 已确认到达 · 收好这次旅途回忆 · 出门小说明。
class OfflineCheckinPage extends StatefulWidget {
  const OfflineCheckinPage({
    super.key,
    required this.api,
    required this.session,
    required this.activityId,
    this.initialActivity,
    this.onChanged,
    this.onNavigateToChat,
  });

  final CompanionApi api;
  final AuthSession session;
  final String activityId;
  final OfflineActivity? initialActivity;
  final VoidCallback? onChanged;

  /// Shell navigation after a successful arrive (pop routes + chat tab).
  final VoidCallback? onNavigateToChat;

  @override
  State<OfflineCheckinPage> createState() => _OfflineCheckinPageState();
}

class _OfflineCheckinPageState extends State<OfflineCheckinPage> {
  OfflineActivity? _activity;
  bool _loading = true;
  String? _error;
  bool _arriving = false;
  bool _drawing = false;
  bool _archiving = false;

  @override
  void initState() {
    super.initState();
    _activity = widget.initialActivity;
    _loading = widget.initialActivity == null;
    _load();
  }

  Future<void> _load() async {
    try {
      final activity = await widget.api.fetchOfflineActivity(widget.activityId);
      if (!mounted) return;
      setState(() {
        _activity = activity;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException ? error.message : error.toString();
      });
    }
  }

  Future<void> _onArrive() async {
    if (_arriving) return;
    setState(() => _arriving = true);
    try {
      final manual = !(_activity?.arrivalVerificationAvailable ?? false);
      if (manual) {
        final confirmed = await _confirmOfflineAction(
          context,
          title: '手动记录到达',
          message: '这个地点暂无可靠坐标，无法核验距离。这次将记录为你手动确认到达。',
          action: '确认记录',
        );
        if (!confirmed || !mounted) return;
      }
      // Native GPS is free; an unavailable fix cannot pass verified arrival.
      DeviceLocationSnapshot? snapshot;
      try {
        if (!manual) {
          snapshot = await requestCurrentDeviceLocation(
            api: widget.api,
            openSettingsWhenBlocked: false,
          );
        }
      } catch (_) {
        snapshot = null;
      }
      if (!manual && snapshot == null) {
        if (mounted) _showActivityToast(context, '需要当前位置才能确认到达，请开启定位后重试');
        return;
      }
      final updated = await widget.api.arriveOfflineActivity(
        widget.activityId,
        lat: snapshot?.latitude,
        lng: snapshot?.longitude,
        accuracyMeters: snapshot?.accuracyMeters,
        manualConfirmation: manual,
      );
      if (!mounted) return;
      setState(() => _activity = updated);
      widget.onChanged?.call();
      if (!mounted) return;
      if (widget.onNavigateToChat != null) {
        widget.onNavigateToChat!();
      } else {
        Navigator.of(context).pop();
      }
    } on ApiException catch (error) {
      if (mounted) _showActivityToast(context, error.message);
    } finally {
      if (mounted) setState(() => _arriving = false);
    }
  }

  Future<void> _onProphecyAction() async {
    if (_drawing) return;
    final existing = (_activity?.prophecyText ?? '').trim();
    if (existing.isNotEmpty) {
      await showOfflineProphecyDialog(context, existing);
      return;
    }
    setState(() => _drawing = true);
    try {
      final updated = await widget.api.drawOfflineActivityProphecy(
        widget.activityId,
      );
      if (!mounted) return;
      setState(() => _activity = updated);
      final text = updated.prophecyText;
      if (text != null && text.isNotEmpty) {
        await showOfflineProphecyDialog(context, text);
      }
    } on ApiException catch (error) {
      if (mounted) _showActivityToast(context, error.message);
    } finally {
      if (mounted) setState(() => _drawing = false);
    }
  }

  Future<void> _onArchive() async {
    if (_archiving) return;
    final confirmed = await showOfflineArchiveConfirm(context);
    if (!confirmed || !mounted) return;
    setState(() => _archiving = true);
    try {
      await widget.api.archiveOfflineActivity(widget.activityId);
      widget.onChanged?.call();
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) _showActivityToast(context, error.message);
    } finally {
      if (mounted) setState(() => _archiving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final activity = _activity;
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
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                    child: _OfflineSubpageTopBar(
                      title: '打卡任务',
                      onBack: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(child: CupertinoActivityIndicator())
                        : activity == null
                        ? _buildError()
                        : _buildBody(activity),
                  ),
                  if (!_loading && activity != null) _buildDock(activity),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _OfflineErrorBlock(
          message: _error ?? '加载失败',
          onRetry: () {
            setState(() => _loading = true);
            _load();
          },
        ),
      ),
    );
  }

  Widget _buildBody(OfflineActivity activity) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CheckinGallery(
            imageUrls: activity.imageUrls,
            category: activity.category,
            authToken: widget.api.authToken,
          ),
          const SizedBox(height: 16),
          _CheckinPlaceCard(
            activity: activity,
            onViewLocation: () => showOfflineLocationSheet(
              context,
              name: activity.locationName ?? activity.title,
              address: activity.address,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDock(OfflineActivity activity) {
    final w = _W2b.resolve(context);
    final reached = activity.reached;
    final active = activity.status == 'accepted';
    final hasProphecy = (activity.prophecyText ?? '').isNotEmpty;
    return _CollapsibleActivityDock(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (reached) ...[
            _ArrivedStatusRow(color: w.ink, verified: activity.arrivalVerified),
            const SizedBox(height: 10),
            // spec §5.4-(6) 已到达坞：「收好这次旅途回忆」为描边按钮（区别于未到达的实心主按钮）。
            SizedBox(
              width: double.infinity,
              child: _SecondaryActivityPillButton(
                label: _archiving ? '收好中...' : '收好这次旅途回忆',
                enabled: active && !_archiving,
                onPressed: _onArchive,
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: _PrimaryActivityPillButton(
                label: _arriving
                    ? '确认中...'
                    : activity.arrivalVerificationAvailable
                    ? '我已经抵达这里'
                    : '手动记录到达',
                icon: '📍',
                enabled: active && !_arriving && !_loading,
                onPressed: _onArrive,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: _SecondaryActivityPillButton(
                label: hasProphecy ? '查看此行小预言' : '抽一句此行小预言',
                enabled: active && !_drawing,
                onPressed: _onProphecyAction,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 10,
                ),
                minimumSize: Size.zero,
                onPressed: () => showOfflinePlayGuideDialog(context),
                child: Text(
                  '出门小说明',
                  style: _mutedStyle(context, 13).copyWith(
                    decoration: TextDecoration.underline,
                    decorationColor: w.inkSoft,
                  ),
                ),
              ),
              if (!reached && active) ...[
                Text('｜', style: _mutedStyle(context, 13)),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 10,
                  ),
                  minimumSize: Size.zero,
                  onPressed: _arriving
                      ? null
                      : () async {
                          if (!await _confirmOfflineAction(
                            context,
                            title: '删除待出行活动',
                            message: '删除后会取消这次出行计划，已有聊天和真实回忆会保留。',
                            action: '删除',
                          )) {
                            return;
                          }
                          try {
                            await widget.api.deleteOfflineActivity(activity.id);
                            widget.onChanged?.call();
                            if (mounted) Navigator.of(context).pop();
                          } on ApiException catch (error) {
                            if (mounted) {
                              _showActivityToast(context, error.message);
                            }
                          }
                        },
                  child: const Text(
                    '删除该活动',
                    style: TextStyle(
                      color: CupertinoColors.destructiveRed,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Natural-height actions with two snap positions; the handle never dismisses.
class _CollapsibleActivityDock extends StatefulWidget {
  const _CollapsibleActivityDock({required this.child});

  final Widget child;

  @override
  State<_CollapsibleActivityDock> createState() =>
      _CollapsibleActivityDockState();
}

class _CollapsibleActivityDockState extends State<_CollapsibleActivityDock>
    with SingleTickerProviderStateMixin {
  final _contentKey = GlobalKey();
  late final AnimationController _expansion = AnimationController(
    vsync: this,
    value: 1,
    duration: const Duration(milliseconds: 240),
  );

  @override
  void dispose() {
    _expansion.dispose();
    super.dispose();
  }

  void _snapTo(double target) {
    _expansion.animateTo(
      target,
      duration: MediaQuery.of(context).disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  void _drag(DragUpdateDetails details) {
    // SizeTransition clips its child but retains the child's full layout size.
    // Header grows by 16 px when collapsed to keep a comfortable touch target.
    final travel = (_contentKey.currentContext?.size?.height ?? 0) - 16;
    if (travel <= 0) return;
    _expansion.value = (_expansion.value - details.delta.dy / travel)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  void _release(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    _snapTo(
      velocity.abs() >= 400
          ? (velocity < 0 ? 1 : 0)
          : (_expansion.value >= .5 ? 1 : 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return AnimatedBuilder(
      animation: _expansion,
      child: Padding(
        key: _contentKey,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: widget.child,
      ),
      builder: (context, child) {
        final value = _expansion.value;
        void toggle() => _snapTo(value >= .5 ? 0 : 1);
        return GestureDetector(
          key: const ValueKey('offlineActivityDock'),
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (_) => _expansion.stop(),
          onVerticalDragUpdate: _drag,
          onVerticalDragEnd: _release,
          onVerticalDragCancel: () => _snapTo(_expansion.value >= .5 ? 1 : 0),
          child: Container(
            decoration: BoxDecoration(
              color: w.glass,
              border: Border(top: BorderSide(color: w.glassBorder)),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: w.panelShadow,
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  button: true,
                  label: value >= .5 ? '收起活动操作' : '展开活动操作',
                  onTap: toggle,
                  child: GestureDetector(
                    key: const ValueKey('offlineActivityDockHandle'),
                    behavior: HitTestBehavior.opaque,
                    excludeFromSemantics: true,
                    onTap: toggle,
                    child: SizedBox(
                      // 28 px expanded replaces the old 14 px top/bottom insets.
                      height: 44 - 16 * value,
                      width: double.infinity,
                      child: Center(
                        child: Container(
                          key: const ValueKey('offlineActivityDockGrip'),
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: w.inkSoft.withValues(
                              alpha: .16 + .26 * value,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizeTransition(
                  sizeFactor: _expansion,
                  alignment: Alignment.topCenter,
                  child: IgnorePointer(
                    ignoring: value < 1,
                    child: ExcludeSemantics(
                      excluding: value < 1,
                      child: child!,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ArrivedStatusRow extends StatelessWidget {
  const _ArrivedStatusRow({required this.color, required this.verified});

  final Color color;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: Color(0xFF3D8A4F),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            CupertinoIcons.check_mark,
            size: 13,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          verified ? '已通过定位确认到达' : '已手动记录到达（未定位核验）',
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}

class _CheckinPlaceCard extends StatelessWidget {
  const _CheckinPlaceCard({
    required this.activity,
    required this.onViewLocation,
  });

  final OfflineActivity activity;
  final VoidCallback onViewLocation;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    final address = activity.address ?? activity.locationName ?? '';
    final theme = activity.summary.isNotEmpty
        ? activity.summary
        : activity.description;
    final vibe = (activity.vibe ?? '').trim();
    final suitable = (activity.suitable ?? '').trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _softCardDecoration(context, radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(activity.title, style: _titleStyle(context, 19)),
              ),
              if ((activity.category ?? '').isNotEmpty) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _kActivityAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    activity.category!,
                    style: const TextStyle(
                      color: _kActivityAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (address.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(CupertinoIcons.location_solid, size: 15, color: w.inkSoft),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    address,
                    style: _mutedStyle(context, 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  borderRadius: BorderRadius.circular(999),
                  color: _kActivityAccent.withValues(alpha: 0.12),
                  onPressed: onViewLocation,
                  child: const Text(
                    '查看位置',
                    style: TextStyle(
                      color: _kActivityAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (theme.isNotEmpty) ...[
            const SizedBox(height: 14),
            SelectableText(
              theme,
              style: _mutedStyle(context, 14).copyWith(height: 1.65),
            ),
            if (activity.description.isNotEmpty &&
                activity.description != theme) ...[
              const SizedBox(height: 12),
              SelectableText(
                activity.description,
                style: _mutedStyle(context, 14).copyWith(height: 1.65),
              ),
            ],
          ],
          // 氛围 / 适合（活动推荐大模型生成的短标签，图标对齐 demo）。
          if (vibe.isNotEmpty || suitable.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: w.glassBorder),
            const SizedBox(height: 12),
            if (vibe.isNotEmpty) _metaRow(context, '🎭', '氛围', vibe, w),
            if (vibe.isNotEmpty && suitable.isNotEmpty)
              const SizedBox(height: 8),
            if (suitable.isNotEmpty) _metaRow(context, '📷', '适合', suitable, w),
          ],
        ],
      ),
    );
  }

  Widget _metaRow(
    BuildContext context,
    String icon,
    String label,
    String value,
    _W2b w,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 14, height: 1.4)),
        const SizedBox(width: 6),
        Text(
          '$label：',
          style: _mutedStyle(
            context,
            13,
          ).copyWith(fontWeight: FontWeight.w600, color: w.ink),
        ),
        Expanded(child: Text(value, style: _mutedStyle(context, 13))),
      ],
    );
  }
}

/// 横滑相册 + 页码角标 + 圆点指示（spec §5.4-6）。
class _CheckinGallery extends StatefulWidget {
  const _CheckinGallery({
    required this.imageUrls,
    required this.category,
    required this.authToken,
  });

  final List<String> imageUrls;
  final String? category;
  final String? authToken;

  @override
  State<_CheckinGallery> createState() => _CheckinGalleryState();
}

class _CheckinGalleryState extends State<_CheckinGallery> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls.where((u) => u.trim().isNotEmpty).toList();
    final count = urls.isEmpty ? 1 : urls.length;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 200,
        child: Stack(
          children: [
            Positioned.fill(
              child: urls.isEmpty
                  ? _fallbackCover()
                  : PageView.builder(
                      controller: _controller,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemCount: urls.length,
                      itemBuilder: (_, i) => Image.network(
                        urls[i],
                        fit: BoxFit.cover,
                        headers: _mediaHeadersForUrl(urls[i], widget.authToken),
                        errorBuilder: (_, __, ___) => _fallbackCover(),
                      ),
                    ),
            ),
            if (count > 1) ...[
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_index + 1} / $count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < count; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        width: i == _index ? 14 : 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: i == _index ? 1 : 0.55,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fallbackCover() {
    return Container(
      color: const Color(0xFFB9D9F2),
      child: Center(
        child: Text(
          _categoryEmoji(widget.category),
          style: const TextStyle(fontSize: 58),
        ),
      ),
    );
  }
}
