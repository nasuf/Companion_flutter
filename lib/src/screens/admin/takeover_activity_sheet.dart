part of 'package:companion_flutter/main.dart';

class _TakeoverActivitySheet extends StatefulWidget {
  const _TakeoverActivitySheet({
    required this.api,
    required this.takeoverId,
  });

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
      final items = await widget.api.previewTakeoverActivities(widget.takeoverId);
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
      await widget.api.publishTakeoverActivity(widget.takeoverId, item.previewId);
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
    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
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
                        onPressed: _loading ? null : _load,
                        icon: const Icon(CupertinoIcons.refresh),
                      ),
                  ],
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
                    : detail != null
                    ? _detailView(detail)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
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
    );
  }

  Widget _detailView(TakeoverActivityPreview item) {
    final place = [
      item.city,
      item.locationName,
      item.address,
    ].where((part) => part.trim().isNotEmpty).join(' · ');
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      children: [
        Text(
          item.title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        if (place.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(place, style: TextStyle(color: AppColors.muted)),
        ],
        if (item.suitable.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(item.suitable),
        ],
        const SizedBox(height: 14),
        Text(
          item.description.isNotEmpty ? item.description : item.summary,
          style: const TextStyle(fontSize: 15, height: 1.45),
        ),
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
