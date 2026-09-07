part of 'package:companion_flutter/main.dart';

class AdminUserFeedbackPage extends StatefulWidget {
  const AdminUserFeedbackPage({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<AdminUserFeedbackPage> createState() => _AdminUserFeedbackPageState();
}

class _AdminUserFeedbackPageState extends State<AdminUserFeedbackPage> {
  bool _loading = true;
  String? _error;
  String _statusFilter = 'open';
  AdminUserFeedbackList? _data;
  AdminUserFeedbackItem? _selected;
  String? _pendingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      widget.api.authToken = widget.session.token;
      final data = await widget.api.listAdminUserFeedback(
        status: _statusFilter == 'all' ? null : _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _selected = data.items.isEmpty
            ? null
            : data.items.firstWhere(
                (item) => item.id == _selected?.id,
                orElse: () => data.items.first,
              );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _asMessage(error);
        _loading = false;
      });
    }
  }

  Future<void> _updateStatus(AdminUserFeedbackItem item, String status) async {
    if (_pendingId != null) return;
    setState(() => _pendingId = item.id);
    try {
      widget.api.authToken = widget.session.token;
      final updated = await widget.api.updateAdminUserFeedbackStatus(
        feedbackId: item.id,
        status: status,
      );
      if (!mounted) return;
      setState(() {
        _selected = updated;
        _pendingId = null;
      });
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _pendingId = null);
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('更新失败'),
          content: Text(_asMessage(error)),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    }
  }

  String _mediaUrl(String path) {
    if (path.startsWith('http')) return path;
    return '${widget.api.baseUrl}$path';
  }

  Map<String, String> get _authHeaders {
    final token = widget.session.token;
    if (token.isEmpty) return const {};
    return {'Authorization': 'Bearer $token'};
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CupertinoPageScaffold(
      backgroundColor: isDark ? AppColors.page : const Color(0xFFF0F4F8),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  _WeatherBackButton(
                    onTap: () => Navigator.of(context).pop(),
                    iconColor: const Color(0xFF2D73FF),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '客户意见反馈',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _loading ? null : _load,
                    child: Icon(
                      CupertinoIcons.refresh,
                      color: _loading
                          ? AppColors.muted
                          : const Color(0xFF2D73FF),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CupertinoSlidingSegmentedControl<String>(
                groupValue: _statusFilter,
                children: const {
                  'open': Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text('待处理'),
                  ),
                  'read': Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text('已读'),
                  ),
                  'resolved': Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text('已解决'),
                  ),
                  'all': Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text('全部'),
                  ),
                },
                onValueChanged: (value) {
                  if (value == null) return;
                  setState(() => _statusFilter = value);
                  unawaited(_load());
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: TextStyle(color: AppColors.danger),
                      ),
                    )
                  : (_data?.items.isEmpty ?? true)
                  ? const Center(child: Text('暂无反馈'))
                  : Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _data!.items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = _data!.items[index];
                              final selected = item.id == _selected?.id;
                              return CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () =>
                                    setState(() => _selected = item),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? const Color(0xFFE8F2FB)
                                        : (isDark
                                              ? AppColors.surface
                                              : Colors.white),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: selected
                                          ? const Color(0xFF7AB8E0)
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.displayName ??
                                            item.username ??
                                            item.userId,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.content,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        item.createdAt
                                            .toLocal()
                                            .toString()
                                            .substring(0, 16),
                                        style: TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Expanded(
                          flex: 7,
                          child: _selected == null
                              ? const SizedBox.shrink()
                              : _FeedbackDetailPanel(
                                  item: _selected!,
                                  pending: _pendingId == _selected!.id,
                                  mediaUrlBuilder: _mediaUrl,
                                  headers: _authHeaders,
                                  onMarkRead: () => _updateStatus(
                                    _selected!,
                                    'read',
                                  ),
                                  onResolve: () => _updateStatus(
                                    _selected!,
                                    'resolved',
                                  ),
                                ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackDetailPanel extends StatelessWidget {
  const _FeedbackDetailPanel({
    required this.item,
    required this.pending,
    required this.mediaUrlBuilder,
    required this.headers,
    required this.onMarkRead,
    required this.onResolve,
  });

  final AdminUserFeedbackItem item;
  final bool pending;
  final String Function(String path) mediaUrlBuilder;
  final Map<String, String> headers;
  final VoidCallback onMarkRead;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 16, 24),
      children: [
        Text(
          item.displayName ?? item.username ?? item.userId,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text('联系方式：${item.contact}', style: TextStyle(color: AppColors.muted)),
        if (item.occurredAt != null && item.occurredAt!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '发生时间：${item.occurredAt}',
            style: TextStyle(color: AppColors.muted),
          ),
        ],
        if (item.appVersion != null) ...[
          const SizedBox(height: 4),
          Text(
            'App 版本：${item.appVersion}',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.surface
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(item.content),
        ),
        if (item.imageUrls.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final url in item.imageUrls)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ChatCachedImage(
                    url: mediaUrlBuilder(url),
                    headers: headers,
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CupertinoButton(
                color: const Color(0xFF2D73FF),
                padding: const EdgeInsets.symmetric(vertical: 12),
                onPressed: pending || item.status == 'read'
                    ? null
                    : onMarkRead,
                child: pending
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : const Text('标记已读'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: CupertinoButton(
                color: const Color(0xFF1FA97A),
                padding: const EdgeInsets.symmetric(vertical: 12),
                onPressed: pending || item.status == 'resolved'
                    ? null
                    : onResolve,
                child: const Text('标记已解决'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
