part of 'package:companion_flutter/main.dart';

class _TakeoverActivitySheet extends StatefulWidget {
  const _TakeoverActivitySheet({required this.api, required this.takeoverId});

  final CompanionApi api;
  final String takeoverId;

  @override
  State<_TakeoverActivitySheet> createState() => _TakeoverActivitySheetState();
}

class _TakeoverActivitySheetState extends State<_TakeoverActivitySheet> {
  bool _loading = true;
  bool _publishing = false;
  String? _error;
  List<TakeoverActivityPreview> _items = const [];
  TakeoverActivityPreview? _detail;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _detail = null;
    });
    try {
      final items = await widget.api.previewTakeoverActivities(
        widget.takeoverId,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _items = items;
        if (items.isEmpty) _error = '暂时没找到合适的新去处，请稍后再试。';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _asMessage(error);
      });
    }
  }

  Future<void> _publish(TakeoverActivityPreview item) async {
    if (_publishing) return;
    setState(() => _publishing = true);
    try {
      await widget.api.publishTakeoverActivity(
        widget.takeoverId,
        item.previewId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _publishing = false;
        _error = _asMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.72;
    final detail = _detail;
    return PopScope(
      canPop: !_publishing,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            key: const ValueKey('takeover-activity-sheet'),
            width: double.infinity,
            height: height,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.hairline,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  child: Row(
                    children: [
                      if (detail != null)
                        IconButton(
                          onPressed: _publishing
                              ? null
                              : () => setState(() => _detail = null),
                          icon: const Icon(CupertinoIcons.chevron_left),
                        )
                      else
                        const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          detail == null ? '活动推荐' : '活动详情',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (detail == null)
                        IconButton(
                          onPressed: _loading || _publishing ? null : _load,
                          icon: const Icon(CupertinoIcons.refresh),
                        ),
                      IconButton(
                        tooltip: '关闭活动推荐',
                        onPressed: _publishing
                            ? null
                            : () => Navigator.of(context).pop(false),
                        icon: const Icon(CupertinoIcons.xmark),
                      ),
                    ],
                  ),
                ),
                if (!_loading &&
                    detail == null &&
                    _items.length < 5 &&
                    _items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 4,
                    ),
                    child: Text(
                      '当前找到 ${_items.length} 条可用活动，可刷新再试',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFFE24B4B)),
                    ),
                  ),
                Expanded(
                  child: _loading
                      ? const Center(child: CupertinoActivityIndicator())
                      : _items.isEmpty
                      ? Center(
                          child: CupertinoButton.filled(
                            onPressed: _load,
                            child: const Text('重试'),
                          ),
                        )
                      : detail != null
                      ? _detailView(detail)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return _previewTile(
                              item,
                              onTap: () => setState(() {
                                _error = null;
                                _detail = item;
                              }),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailView(TakeoverActivityPreview item) {
    final activity =
        item.activity ??
        OfflineActivity.fromJson({
          'id': item.previewId,
          'status': 'pending',
          'title': item.title,
          'summary': item.summary,
          'description': item.description,
          'location_name': item.locationName,
          'address': item.address,
          'city': item.city,
          'suitable': item.suitable,
        });
    return ListView(
      padding: EdgeInsets.fromLTRB(
        18,
        4,
        18,
        24 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      children: [
        _ActivityImageGallery(
          imageUrls: activity.imageUrls,
          category: activity.category,
          authToken: widget.api.authToken,
        ),
        const SizedBox(height: 18),
        Text(activity.title, style: _activityTitleStyle(context)),
        const SizedBox(height: 10),
        Text(
          activity.summary,
          style: _activityBodyStyle(context, secondary: true),
        ),
        if ((activity.recommendationMessage ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          _ActivityRecommendationMessage(
            message: activity.recommendationMessage!,
          ),
        ],
        if (activity.description.isNotEmpty &&
            activity.description != activity.summary) ...[
          const SizedBox(height: 16),
          _ActivityDescription(text: activity.description),
        ],
        const SizedBox(height: 16),
        _MetaLine(activity: activity),
        const SizedBox(height: 22),
        CupertinoButton.filled(
          onPressed: _publishing ? null : () => _publish(item),
          child: Text(_publishing ? '正在推送...' : '推送给用户'),
        ),
      ],
    );
  }

  Widget _previewTile(
    TakeoverActivityPreview item, {
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFF6FDFC),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.summary.isNotEmpty
                          ? item.summary
                          : item.locationName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(CupertinoIcons.chevron_right, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
