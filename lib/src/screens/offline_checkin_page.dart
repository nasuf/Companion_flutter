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
  });

  final CompanionApi api;
  final AuthSession session;
  final String activityId;
  final OfflineActivity? initialActivity;
  final VoidCallback? onChanged;

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
      // 尽力取一次定位（用于服务端可选的 ≤200m 校验）；取不到也不拦，允许直接到达。
      DeviceLocationSnapshot? snapshot;
      try {
        snapshot = await requestCurrentDeviceLocation(
          api: widget.api,
          openSettingsWhenBlocked: false,
        );
      } catch (_) {
        snapshot = null;
      }
      final updated = await widget.api.arriveOfflineActivity(
        widget.activityId,
        lat: snapshot?.latitude,
        lng: snapshot?.longitude,
      );
      if (!mounted) return;
      setState(() => _activity = updated);
      widget.onChanged?.call();
      _showActivityToast(context, '到啦～我在聊天里等你，随手拍点有意思的发我');
    } on ApiException catch (error) {
      if (mounted) _showActivityToast(context, error.message);
    } finally {
      if (mounted) setState(() => _arriving = false);
    }
  }

  Future<void> _onDrawProphecy() async {
    if (_drawing) return;
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

  Future<void> _onCancel() async {
    final confirmed = await showOfflineCancelConfirm(context);
    if (!confirmed || !mounted) return;
    try {
      await widget.api.cancelOfflineActivity(widget.activityId);
      widget.onChanged?.call();
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) _showActivityToast(context, error.message);
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
    final hasProphecy = (activity.prophecyText ?? '').isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: w.glass,
        border: Border(top: BorderSide(color: w.glassBorder)),
        boxShadow: w.panelShadow,
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.paddingOf(context).bottom + 14,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (reached) ...[
            _ArrivedStatusRow(color: w.ink),
            const SizedBox(height: 10),
            // spec §5.4-(6) 已到达坞：「收好这次旅途回忆」为描边按钮（区别于未到达的实心主按钮）。
            SizedBox(
              width: double.infinity,
              child: _SecondaryActivityPillButton(
                label: _archiving ? '收好中...' : '收好这次旅途回忆',
                enabled: !_archiving,
                onPressed: _onArchive,
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: _PrimaryActivityPillButton(
                label: _arriving ? '定位中...' : '我已经抵达这里',
                icon: '📍',
                enabled: !_arriving,
                onPressed: _onArrive,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: _SecondaryActivityPillButton(
                label: hasProphecy ? '已抽过此行小预言' : '抽一句此行小预言',
                enabled: !hasProphecy && !_drawing,
                onPressed: _onDrawProphecy,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
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
              Text('·', style: _mutedStyle(context, 13)),
              // spec §4.2 取消进行中活动（打卡页常驻入口，等同任务条的取消能力）。
              CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                minimumSize: Size.zero,
                onPressed: _onCancel,
                child: Text(
                  '取消这次行程',
                  style: _mutedStyle(context, 13).copyWith(
                    decoration: TextDecoration.underline,
                    decorationColor: w.inkSoft,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArrivedStatusRow extends StatelessWidget {
  const _ArrivedStatusRow({required this.color});

  final Color color;

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
          child: const Icon(CupertinoIcons.check_mark,
              size: 13, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Text(
          '已确认到达',
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
              Expanded(child: Text(activity.title, style: _titleStyle(context, 19))),
              if ((activity.category ?? '').isNotEmpty) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            Text(theme, style: _mutedStyle(context, 14).copyWith(height: 1.65)),
          ],
        ],
      ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
