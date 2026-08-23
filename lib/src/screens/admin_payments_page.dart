part of 'package:companion_flutter/main.dart';

// ---------------------------------------------------------------------------
// Admin · 支付管理 (mobile port of web 后台管理「支付管理」→ CashWorkspace)
//
// Mirrors the web surface:
//   * 钞票管理 — paginated balance list, search, manual grant/deduct.
//   * 钞票流水 — read-only ticket ledger audit with user_id filter.
// ---------------------------------------------------------------------------

const _walletPageSize = 20;

const _walletGrantErrorLabels = {
  'no_change': '余额已是 0，无法再扣减',
  'invalid_amount': '调整数量无效（须为非零整数，单次不超过 1000000）',
  'user_not_found': '用户不存在',
  'wallet_not_found': '钱包不存在',
};

const _walletSourceLabels = {
  'admin_grant': '后台发放',
  'red_packet': '发红包',
  'store_bundle': '商店礼包',
  'ticket_to_point_exchange': '兑换商城积分',
};

const _walletPointSourceLabels = {
  'admin_grant': '后台发放',
  'ticket_to_point_exchange': '钞票兑换',
  'achievement_sync': '成就同步',
  'store_exchange': '商城兑换',
  'game_point_conversion': '游戏积分兑换',
};

String _walletAdminErrorText(Object error) {
  if (error is ApiException) {
    return _walletGrantErrorLabels[error.message] ?? error.message;
  }
  return _asMessage(error);
}

String _walletDisplayName({
  String? username,
  String? nickname,
  String? displayName,
}) {
  final nick = nickname?.trim();
  if (nick != null && nick.isNotEmpty) return nick;
  final display = displayName?.trim();
  if (display != null && display.isNotEmpty) return display;
  final name = username?.trim();
  if (name != null && name.isNotEmpty) return name;
  return '(未知)';
}

String _walletSourceLabel(String source) =>
    _walletSourceLabels[source] ?? source;

String _walletPointSourceLabel(String source) =>
    _walletPointSourceLabels[source] ?? source;

String _walletLedgerNote(Map<String, dynamic> metadata) {
  final parts = <String>[];
  final note = metadata['note']?.toString().trim() ?? '';
  if (note.isNotEmpty) parts.add(note);
  final adminId = metadata['admin_id']?.toString() ?? '';
  if (adminId.isNotEmpty) parts.add('操作人 ${adminId.length > 8 ? adminId.substring(0, 8) : adminId}');
  return parts.isEmpty ? '--' : parts.join(' · ');
}

String _walletFormatTimestamp(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '--';
  return raw.replaceFirst('T', ' ').split('.').first;
}

// ===========================================================================
// API
// ===========================================================================

extension _AdminWalletApi on CompanionApi {
  Future<_AdminWalletBalancesResponse> fetchWalletBalances({
    String? search,
    int limit = _walletPageSize,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    final path = Uri(
      path: '/admin-api/wallet/balances',
      queryParameters: params,
    ).toString();
    final json =
        await _adminHttpRequest(this, 'GET', path) as Map<String, dynamic>;
    return _AdminWalletBalancesResponse.fromJson(json);
  }

  Future<List<_AdminWalletLedgerItem>> fetchWalletLedger({
    String? userId,
    int limit = _walletPageSize,
    int offset = 0,
  }) async {
    final params = <String, String>{'limit': limit.toString()};
    if (userId != null && userId.trim().isNotEmpty) {
      params['user_id'] = userId.trim();
    }
    if (offset > 0) params['offset'] = offset.toString();
    final path = Uri(
      path: '/admin-api/wallet/ledger',
      queryParameters: params,
    ).toString();
    final json = await _adminHttpRequest(this, 'GET', path) as List<dynamic>;
    return json
        .whereType<Map>()
        .map(
          (item) => _AdminWalletLedgerItem.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<List<_AdminUserSearchItem>> searchWalletUsers(
    String query, {
    int limit = 20,
  }) async {
    final path = Uri(
      path: '/admin-api/wallet/users',
      queryParameters: {'q': query, 'limit': limit.toString()},
    ).toString();
    final json = await _adminHttpRequest(this, 'GET', path) as List<dynamic>;
    return json
        .whereType<Map>()
        .map(
          (item) =>
              _AdminUserSearchItem.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<_AdminTicketGrantResult> grantTickets({
    required String userId,
    required int amount,
    String? note,
  }) async {
    final body = <String, dynamic>{
      'user_id': userId,
      'amount': amount,
    };
    final trimmedNote = note?.trim();
    if (trimmedNote != null && trimmedNote.isNotEmpty) {
      body['note'] = trimmedNote;
    }
    final json =
        await _adminHttpRequest(
              this,
              'POST',
              '/admin-api/wallet/grant',
              body: body,
            )
            as Map<String, dynamic>;
    return _AdminTicketGrantResult.fromJson(json);
  }

  Future<List<_AdminWalletLedgerItem>> fetchWalletPointLedger({
    String? userId,
    int limit = _walletPageSize,
    int offset = 0,
  }) async {
    final params = <String, String>{'limit': limit.toString()};
    if (userId != null && userId.trim().isNotEmpty) {
      params['user_id'] = userId.trim();
    }
    if (offset > 0) params['offset'] = offset.toString();
    final path = Uri(
      path: '/admin-api/wallet/point-ledger',
      queryParameters: params,
    ).toString();
    final json = await _adminHttpRequest(this, 'GET', path) as List<dynamic>;
    return json
        .whereType<Map>()
        .map(
          (item) => _AdminWalletLedgerItem.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<_AdminTicketGrantResult> grantPoints({
    required String userId,
    required int amount,
    String? note,
  }) async {
    final body = <String, dynamic>{
      'user_id': userId,
      'amount': amount,
    };
    final trimmedNote = note?.trim();
    if (trimmedNote != null && trimmedNote.isNotEmpty) {
      body['note'] = trimmedNote;
    }
    final json =
        await _adminHttpRequest(
              this,
              'POST',
              '/admin-api/wallet/point-grant',
              body: body,
            )
            as Map<String, dynamic>;
    return _AdminTicketGrantResult.fromJson(json);
  }
}

// ===========================================================================
// Models
// ===========================================================================

class _AdminWalletBalanceItem {
  const _AdminWalletBalanceItem({
    required this.userId,
    required this.username,
    this.displayName,
    this.nickname,
    required this.ticketBalance,
    required this.pointBalance,
    this.updatedAt,
  });

  final String userId;
  final String username;
  final String? displayName;
  final String? nickname;
  final int ticketBalance;
  final int pointBalance;
  final String? updatedAt;

  String get label => _walletDisplayName(
    username: username,
    nickname: nickname,
    displayName: displayName,
  );

  _AdminUserSearchItem get asSearchItem => _AdminUserSearchItem(
    userId: userId,
    username: username,
    nickname: nickname,
  );

  factory _AdminWalletBalanceItem.fromJson(Map<String, dynamic> json) {
    return _AdminWalletBalanceItem(
      userId: json['user_id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      displayName: json['display_name']?.toString(),
      nickname: json['nickname']?.toString(),
      ticketBalance: _adminInt(json['ticket_balance']),
      pointBalance: _adminInt(json['point_balance']),
      updatedAt: json['updated_at']?.toString(),
    );
  }
}

class _AdminWalletBalancesResponse {
  const _AdminWalletBalancesResponse({
    required this.items,
    required this.total,
  });

  final List<_AdminWalletBalanceItem> items;
  final int total;

  factory _AdminWalletBalancesResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return _AdminWalletBalancesResponse(
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) => _AdminWalletBalanceItem.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
      total: _adminInt(json['total']),
    );
  }
}

class _AdminWalletLedgerItem {
  const _AdminWalletLedgerItem({
    required this.id,
    required this.userId,
    this.username,
    this.displayName,
    this.nickname,
    required this.delta,
    required this.balanceAfter,
    required this.source,
    required this.metadata,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String? username;
  final String? displayName;
  final String? nickname;
  final int delta;
  final int balanceAfter;
  final String source;
  final Map<String, dynamic> metadata;
  final String createdAt;

  String get label => _walletDisplayName(
    username: username,
    nickname: nickname,
    displayName: displayName,
  );

  factory _AdminWalletLedgerItem.fromJson(Map<String, dynamic> json) {
    return _AdminWalletLedgerItem(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      username: json['username']?.toString(),
      displayName: json['display_name']?.toString(),
      nickname: json['nickname']?.toString(),
      delta: _adminInt(json['delta']),
      balanceAfter: _adminInt(json['balance_after']),
      source: json['source']?.toString() ?? '',
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : <String, dynamic>{},
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class _AdminTicketGrantResult {
  const _AdminTicketGrantResult({
    required this.ticketBalance,
    required this.pointBalance,
    required this.delta,
  });

  final int ticketBalance;
  final int pointBalance;
  final int delta;

  factory _AdminTicketGrantResult.fromJson(Map<String, dynamic> json) {
    return _AdminTicketGrantResult(
      ticketBalance: _adminInt(json['ticket_balance']),
      pointBalance: _adminInt(json['point_balance']),
      delta: _adminInt(json['delta']),
    );
  }
}

// ===========================================================================
// Entry page: 钞票管理 / 钞票流水
// ===========================================================================

class _AdminPaymentsPage extends StatefulWidget {
  const _AdminPaymentsPage({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends State<_AdminPaymentsPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return _AdminScaffold(
      title: '支付管理',
      subtitle: '钞票 · 商城积分 · 手动发放 · 流水审计',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _tab,
                onValueChanged: (value) {
                  if (value != null) setState(() => _tab = value);
                },
                children: const {
                  0: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('钞票', style: TextStyle(fontSize: 11)),
                  ),
                  1: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('钞流', style: TextStyle(fontSize: 11)),
                  ),
                  2: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('积分', style: TextStyle(fontSize: 11)),
                  ),
                  3: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('分流', style: TextStyle(fontSize: 11)),
                  ),
                },
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                _WalletBalancesTab(api: widget.api, session: widget.session),
                _WalletLedgerTab(api: widget.api, session: widget.session),
                _PointBalancesTab(api: widget.api, session: widget.session),
                _PointLedgerTab(api: widget.api, session: widget.session),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Tab · 钞票管理
// ===========================================================================

class _WalletBalancesTab extends StatefulWidget {
  const _WalletBalancesTab({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_WalletBalancesTab> createState() => _WalletBalancesTabState();
}

class _WalletBalancesTabState extends State<_WalletBalancesTab> {
  final _searchCtrl = TextEditingController();
  int _page = 0;
  int _total = 0;
  String _appliedSearch = '';
  bool _loading = true;
  String? _error;
  String? _notice;
  List<_AdminWalletBalanceItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    widget.api.authToken = widget.session.token;
    try {
      final result = await widget.api.fetchWalletBalances(
        search: _appliedSearch.isEmpty ? null : _appliedSearch,
        limit: _walletPageSize,
        offset: _page * _walletPageSize,
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _total = result.total;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _walletAdminErrorText(error);
        _loading = false;
      });
    }
  }

  void _applySearch() {
    setState(() {
      _appliedSearch = _searchCtrl.text.trim();
      _page = 0;
    });
    _load();
  }

  void _resetSearch() {
    _searchCtrl.clear();
    setState(() {
      _appliedSearch = '';
      _page = 0;
    });
    _load();
  }

  int get _totalPages => math.max(1, (_total / _walletPageSize).ceil());

  Future<void> _openGrant({_AdminWalletBalanceItem? item}) async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) => _GrantTicketsDialog(
        api: widget.api,
        session: widget.session,
        preselect: item?.asSearchItem,
      ),
    );
    if (!mounted || message == null) return;
    setState(() => _notice = message);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
              children: [
                Text(
                  '查看所有用户的钞票余额，并可手动增加或扣减（正数增加，负数扣减，最低为 0）。每次调整都会写入流水。',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 12),
                _AdminGamesPrimaryButton(
                  label: '手动发放钞票',
                  onPressed: _loading ? null : () => _openGrant(),
                ),
                const SizedBox(height: 12),
                _AdminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AdminGamesTextField(
                        label: '搜索用户名 / 显示名 / ID / 微信昵称',
                        controller: _searchCtrl,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _AdminGamesSecondaryButton(
                              label: _loading ? '查询中…' : '查询',
                              onPressed: _loading ? null : _applySearch,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _AdminGamesSecondaryButton(
                              label: '全部',
                              onPressed: _loading ? null : _resetSearch,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _AdminGamesErrorText(_error!),
                ],
                if (_notice != null) ...[
                  const SizedBox(height: 12),
                  _AdminGamesNoticeText(_notice!),
                ],
                const SizedBox(height: 12),
                if (_loading && _items.isEmpty)
                  const Center(child: CupertinoActivityIndicator(radius: 14))
                else if (_items.isEmpty)
                  Text(
                    '暂无用户',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  )
                else
                  for (final item in _items) ...[
                    _AdminCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDark
                                        ? AppColors.text
                                        : const Color(0xFF12171B),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${item.username} · ${item.userId.length > 8 ? item.userId.substring(0, 8) : item.userId}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '钞票 ${item.ticketBalance} · 商城积分 ${item.pointBalance}',
                                  style: TextStyle(
                                    color: isDark
                                        ? AppColors.text
                                        : const Color(0xFF12171B),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '更新 ${_walletFormatTimestamp(item.updatedAt)}',
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _AdminGamesSecondaryButton(
                            label: '调整',
                            onPressed: _loading
                                ? null
                                : () => _openGrant(item: item),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
            child: Row(
              children: [
                Expanded(
                  child: _AdminGamesSecondaryButton(
                    label: '上一页',
                    onPressed: (_page == 0 || _loading)
                        ? null
                        : () {
                            setState(() => _page -= 1);
                            _load();
                          },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '第 ${_page + 1} / $_totalPages 页 · 共 $_total 人',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                Expanded(
                  child: _AdminGamesSecondaryButton(
                    label: '下一页',
                    onPressed: (_page + 1 >= _totalPages || _loading)
                        ? null
                        : () {
                            setState(() => _page += 1);
                            _load();
                          },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Tab · 钞票流水
// ===========================================================================

class _WalletLedgerTab extends StatefulWidget {
  const _WalletLedgerTab({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_WalletLedgerTab> createState() => _WalletLedgerTabState();
}

class _WalletLedgerTabState extends State<_WalletLedgerTab> {
  final _filterCtrl = TextEditingController();
  int _page = 0;
  String _appliedFilter = '';
  bool _loading = true;
  String? _error;
  List<_AdminWalletLedgerItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    widget.api.authToken = widget.session.token;
    try {
      final items = await widget.api.fetchWalletLedger(
        userId: _appliedFilter.isEmpty ? null : _appliedFilter,
        limit: _walletPageSize,
        offset: _page * _walletPageSize,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _walletAdminErrorText(error);
        _loading = false;
      });
    }
  }

  void _applyFilter() {
    setState(() {
      _appliedFilter = _filterCtrl.text.trim();
      _page = 0;
    });
    _load();
  }

  void _resetFilter() {
    _filterCtrl.clear();
    setState(() {
      _appliedFilter = '';
      _page = 0;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
              children: [
                Text(
                  '所有钞票变更的审计记录（后台发放 / 发红包 / 商店礼包 / 兑换商城积分）。',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 12),
                _AdminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AdminGamesTextField(
                        label: '按用户 ID 过滤流水（留空看全部）',
                        controller: _filterCtrl,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _AdminGamesSecondaryButton(
                              label: _loading ? '查询中…' : '查询',
                              onPressed: _loading ? null : _applyFilter,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _AdminGamesSecondaryButton(
                              label: '全部',
                              onPressed: _loading ? null : _resetFilter,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _AdminGamesErrorText(_error!),
                ],
                const SizedBox(height: 12),
                if (_loading && _items.isEmpty)
                  const Center(child: CupertinoActivityIndicator(radius: 14))
                else if (_items.isEmpty)
                  Text(
                    '暂无钞票流水',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  )
                else
                  for (final item in _items) ...[
                    _AdminCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isDark
                                            ? AppColors.text
                                            : const Color(0xFF12171B),
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      item.userId.length > 8
                                          ? item.userId.substring(0, 8)
                                          : item.userId,
                                      style: TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    item.delta >= 0
                                        ? '+${item.delta}'
                                        : '${item.delta}',
                                    style: TextStyle(
                                      color: item.delta >= 0
                                          ? const Color(0xFF1FA97A)
                                          : AppColors.of(context).danger,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '余额 ${item.balanceAfter}',
                                    style: TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_walletSourceLabel(item.source)} · ${_walletFormatTimestamp(item.createdAt)}',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _walletLedgerNote(item.metadata),
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
            child: Row(
              children: [
                Expanded(
                  child: _AdminGamesSecondaryButton(
                    label: '上一页',
                    onPressed: (_page == 0 || _loading)
                        ? null
                        : () {
                            setState(() => _page -= 1);
                            _load();
                          },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    '第 ${_page + 1} 页',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                Expanded(
                  child: _AdminGamesSecondaryButton(
                    label: '下一页',
                    onPressed: (_items.length < _walletPageSize || _loading)
                        ? null
                        : () {
                            setState(() => _page += 1);
                            _load();
                          },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Tab · 积分管理
// ===========================================================================

class _PointBalancesTab extends StatefulWidget {
  const _PointBalancesTab({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_PointBalancesTab> createState() => _PointBalancesTabState();
}

class _PointBalancesTabState extends State<_PointBalancesTab> {
  final _searchCtrl = TextEditingController();
  int _page = 0;
  int _total = 0;
  String _appliedSearch = '';
  bool _loading = true;
  String? _error;
  String? _notice;
  List<_AdminWalletBalanceItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    widget.api.authToken = widget.session.token;
    try {
      final result = await widget.api.fetchWalletBalances(
        search: _appliedSearch.isEmpty ? null : _appliedSearch,
        limit: _walletPageSize,
        offset: _page * _walletPageSize,
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _total = result.total;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _walletAdminErrorText(error);
        _loading = false;
      });
    }
  }

  void _applySearch() {
    setState(() {
      _appliedSearch = _searchCtrl.text.trim();
      _page = 0;
    });
    _load();
  }

  void _resetSearch() {
    _searchCtrl.clear();
    setState(() {
      _appliedSearch = '';
      _page = 0;
    });
    _load();
  }

  int get _totalPages => math.max(1, (_total / _walletPageSize).ceil());

  Future<void> _openGrant({_AdminWalletBalanceItem? item}) async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) => _GrantShopPointsDialog(
        api: widget.api,
        session: widget.session,
        preselect: item?.asSearchItem,
      ),
    );
    if (!mounted || message == null) return;
    setState(() => _notice = message);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
              children: [
                Text(
                  '查看所有用户的商城积分余额，并可手动增加或扣减（正数增加，负数扣减，最低为 0）。每次调整都会写入流水。',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 12),
                _AdminGamesPrimaryButton(
                  label: '手动发放积分',
                  onPressed: _loading ? null : () => _openGrant(),
                ),
                const SizedBox(height: 12),
                _AdminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AdminGamesTextField(
                        label: '搜索用户名 / 显示名 / ID / 微信昵称',
                        controller: _searchCtrl,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _AdminGamesSecondaryButton(
                              label: _loading ? '查询中…' : '查询',
                              onPressed: _loading ? null : _applySearch,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _AdminGamesSecondaryButton(
                              label: '全部',
                              onPressed: _loading ? null : _resetSearch,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _AdminGamesErrorText(_error!),
                ],
                if (_notice != null) ...[
                  const SizedBox(height: 12),
                  _AdminGamesNoticeText(_notice!),
                ],
                const SizedBox(height: 12),
                if (_loading && _items.isEmpty)
                  const Center(child: CupertinoActivityIndicator(radius: 14))
                else if (_items.isEmpty)
                  Text(
                    '暂无用户',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  )
                else
                  for (final item in _items) ...[
                    _AdminCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDark
                                        ? AppColors.text
                                        : const Color(0xFF12171B),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${item.username} · ${item.userId.length > 8 ? item.userId.substring(0, 8) : item.userId}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '商城积分 ${item.pointBalance} · 钞票 ${item.ticketBalance}',
                                  style: TextStyle(
                                    color: isDark
                                        ? AppColors.text
                                        : const Color(0xFF12171B),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '更新 ${_walletFormatTimestamp(item.updatedAt)}',
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _AdminGamesSecondaryButton(
                            label: '调整',
                            onPressed: _loading
                                ? null
                                : () => _openGrant(item: item),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
            child: Row(
              children: [
                Expanded(
                  child: _AdminGamesSecondaryButton(
                    label: '上一页',
                    onPressed: (_page == 0 || _loading)
                        ? null
                        : () {
                            setState(() => _page -= 1);
                            _load();
                          },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '第 ${_page + 1} / $_totalPages 页 · 共 $_total 人',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                Expanded(
                  child: _AdminGamesSecondaryButton(
                    label: '下一页',
                    onPressed: (_page + 1 >= _totalPages || _loading)
                        ? null
                        : () {
                            setState(() => _page += 1);
                            _load();
                          },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Tab · 积分流水
// ===========================================================================

class _PointLedgerTab extends StatefulWidget {
  const _PointLedgerTab({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_PointLedgerTab> createState() => _PointLedgerTabState();
}

class _PointLedgerTabState extends State<_PointLedgerTab> {
  final _filterCtrl = TextEditingController();
  int _page = 0;
  String _appliedFilter = '';
  bool _loading = true;
  String? _error;
  List<_AdminWalletLedgerItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    widget.api.authToken = widget.session.token;
    try {
      final items = await widget.api.fetchWalletPointLedger(
        userId: _appliedFilter.isEmpty ? null : _appliedFilter,
        limit: _walletPageSize,
        offset: _page * _walletPageSize,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _walletAdminErrorText(error);
        _loading = false;
      });
    }
  }

  void _applyFilter() {
    setState(() {
      _appliedFilter = _filterCtrl.text.trim();
      _page = 0;
    });
    _load();
  }

  void _resetFilter() {
    _filterCtrl.clear();
    setState(() {
      _appliedFilter = '';
      _page = 0;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
              children: [
                Text(
                  '所有商城积分变更的审计记录（后台发放 / 钞票兑换 / 成就同步 / 商城兑换 / 游戏积分兑换）。',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 12),
                _AdminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AdminGamesTextField(
                        label: '按用户 ID 过滤流水（留空看全部）',
                        controller: _filterCtrl,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _AdminGamesSecondaryButton(
                              label: _loading ? '查询中…' : '查询',
                              onPressed: _loading ? null : _applyFilter,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _AdminGamesSecondaryButton(
                              label: '全部',
                              onPressed: _loading ? null : _resetFilter,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _AdminGamesErrorText(_error!),
                ],
                const SizedBox(height: 12),
                if (_loading && _items.isEmpty)
                  const Center(child: CupertinoActivityIndicator(radius: 14))
                else if (_items.isEmpty)
                  Text(
                    '暂无积分流水',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  )
                else
                  for (final item in _items) ...[
                    _AdminCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isDark
                                            ? AppColors.text
                                            : const Color(0xFF12171B),
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      item.userId.length > 8
                                          ? item.userId.substring(0, 8)
                                          : item.userId,
                                      style: TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    item.delta >= 0
                                        ? '+${item.delta}'
                                        : '${item.delta}',
                                    style: TextStyle(
                                      color: item.delta >= 0
                                          ? const Color(0xFF2E9B57)
                                          : const Color(0xFFD64545),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                  Text(
                                    '余额 ${item.balanceAfter}',
                                    style: TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_walletPointSourceLabel(item.source)} · ${_walletFormatTimestamp(item.createdAt)}',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _walletLedgerNote(item.metadata),
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
            child: Row(
              children: [
                Expanded(
                  child: _AdminGamesSecondaryButton(
                    label: '上一页',
                    onPressed: (_page == 0 || _loading)
                        ? null
                        : () {
                            setState(() => _page -= 1);
                            _load();
                          },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    '第 ${_page + 1} 页',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                Expanded(
                  child: _AdminGamesSecondaryButton(
                    label: '下一页',
                    onPressed: (_items.length < _walletPageSize || _loading)
                        ? null
                        : () {
                            setState(() => _page += 1);
                            _load();
                          },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// 手动发放 modal — fuzzy user search + signed amount + note (mirrors web)
// ===========================================================================

class _GrantTicketsDialog extends StatefulWidget {
  const _GrantTicketsDialog({
    required this.api,
    required this.session,
    this.preselect,
  });

  final CompanionApi api;
  final AuthSession session;
  final _AdminUserSearchItem? preselect;

  @override
  State<_GrantTicketsDialog> createState() => _GrantTicketsDialogState();
}

class _GrantTicketsDialogState extends State<_GrantTicketsDialog> {
  final _queryCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  Timer? _debounce;
  int _searchSeq = 0;
  List<_AdminUserSearchItem> _results = const [];
  bool _searching = false;
  bool _granting = false;
  _AdminUserSearchItem? _selected;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = widget.preselect;
    _queryCtrl.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    if (_selected != null) return;
    _debounce?.cancel();
    final query = _queryCtrl.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _runSearch(query),
    );
  }

  Future<void> _runSearch(String query) async {
    final seq = ++_searchSeq;
    widget.api.authToken = widget.session.token;
    try {
      final rows = await widget.api.searchWalletUsers(query);
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _results = rows;
        _searching = false;
      });
    } catch (error) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _error = _walletAdminErrorText(error);
        _searching = false;
      });
    }
  }

  void _select(_AdminUserSearchItem item) {
    setState(() {
      _selected = item;
      _results = const [];
      _error = null;
    });
  }

  void _clearSelected() {
    setState(() {
      _selected = null;
      _queryCtrl.clear();
      _results = const [];
    });
  }

  Future<void> _grant() async {
    if (_granting) return;
    final selected = _selected;
    final parsed = int.tryParse(_amountCtrl.text.trim());
    if (selected == null) {
      setState(() => _error = '请先选择用户');
      return;
    }
    if (parsed == null || parsed == 0) {
      setState(() => _error = '调整数量必须是非零整数（正数增加，负数扣减）');
      return;
    }
    if (parsed.abs() > 1000000) {
      setState(() => _error = '单次调整不能超过 1000000 钞票');
      return;
    }
    setState(() {
      _granting = true;
      _error = null;
    });
    widget.api.authToken = widget.session.token;
    try {
      final result = await widget.api.grantTickets(
        userId: selected.userId,
        amount: parsed,
        note: _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      final verb = result.delta >= 0 ? '增加' : '扣减';
      Navigator.of(context).pop(
        '已为 ${selected.displayName} $verb ${result.delta.abs()} 钞票，当前余额 ${result.ticketBalance}。',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _granting = false;
        _error = _walletAdminErrorText(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: media.size.height * 0.82,
        ),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1B2024)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _AdminGamesSectionHeader('手动发放钞票'),
            const SizedBox(height: 4),
            Text(
              '搜索并选择用户后调整钞票；正数增加，负数扣减，余额最低为 0。此操作会记入钞票流水。',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11.5,
                height: 1.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 12),
            if (_selected == null) ...[
              _AdminGamesTextField(
                label: '搜索用户（用户名 / ID / 微信昵称 / 手机号）',
                controller: _queryCtrl,
              ),
              const SizedBox(height: 10),
            ],
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_selected != null)
                      _SelectedUserChip(
                        item: _selected!,
                        onClear: _clearSelected,
                      )
                    else
                      _UserSearchResults(
                        searching: _searching,
                        results: _results,
                        query: _queryCtrl.text.trim(),
                        onSelect: _select,
                      ),
                    const SizedBox(height: 12),
                    _AdminGamesNumberField(
                      label: '调整数量（正数增加，负数扣减）',
                      controller: _amountCtrl,
                      signed: true,
                    ),
                    const SizedBox(height: 10),
                    _AdminGamesTextField(
                      label: '备注（可选）',
                      controller: _noteCtrl,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      _AdminGamesErrorText(_error!),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _AdminGamesSecondaryButton(
                    label: '取消',
                    onPressed: _granting
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AdminGamesPrimaryButton(
                    label: _granting ? '提交中…' : '确认调整',
                    onPressed: (_granting || _selected == null) ? null : _grant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GrantShopPointsDialog extends StatefulWidget {
  const _GrantShopPointsDialog({
    required this.api,
    required this.session,
    this.preselect,
  });

  final CompanionApi api;
  final AuthSession session;
  final _AdminUserSearchItem? preselect;

  @override
  State<_GrantShopPointsDialog> createState() => _GrantShopPointsDialogState();
}

class _GrantShopPointsDialogState extends State<_GrantShopPointsDialog> {
  final _queryCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  Timer? _debounce;
  int _searchSeq = 0;
  List<_AdminUserSearchItem> _results = const [];
  bool _searching = false;
  bool _granting = false;
  _AdminUserSearchItem? _selected;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = widget.preselect;
    _queryCtrl.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    if (_selected != null) return;
    _debounce?.cancel();
    final query = _queryCtrl.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _runSearch(query),
    );
  }

  Future<void> _runSearch(String query) async {
    final seq = ++_searchSeq;
    widget.api.authToken = widget.session.token;
    try {
      final rows = await widget.api.searchWalletUsers(query);
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _results = rows;
        _searching = false;
      });
    } catch (error) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _error = _walletAdminErrorText(error);
        _searching = false;
      });
    }
  }

  void _select(_AdminUserSearchItem item) {
    setState(() {
      _selected = item;
      _results = const [];
      _error = null;
    });
  }

  void _clearSelected() {
    setState(() {
      _selected = null;
      _queryCtrl.clear();
      _results = const [];
    });
  }

  Future<void> _grant() async {
    if (_granting) return;
    final selected = _selected;
    final parsed = int.tryParse(_amountCtrl.text.trim());
    if (selected == null) {
      setState(() => _error = '请先选择用户');
      return;
    }
    if (parsed == null || parsed == 0) {
      setState(() => _error = '调整数量必须是非零整数（正数增加，负数扣减）');
      return;
    }
    if (parsed.abs() > 1000000) {
      setState(() => _error = '单次调整不能超过 1000000 积分');
      return;
    }
    setState(() {
      _granting = true;
      _error = null;
    });
    widget.api.authToken = widget.session.token;
    try {
      final result = await widget.api.grantPoints(
        userId: selected.userId,
        amount: parsed,
        note: _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      final verb = result.delta >= 0 ? '增加' : '扣减';
      Navigator.of(context).pop(
        '已为 ${selected.displayName} $verb ${result.delta.abs()} 积分，当前余额 ${result.pointBalance}。',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _granting = false;
        _error = _walletAdminErrorText(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: media.size.height * 0.82,
        ),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1B2024)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _AdminGamesSectionHeader('手动发放积分'),
            const SizedBox(height: 4),
            Text(
              '搜索并选择用户后调整商城积分；正数增加，负数扣减，余额最低为 0。此操作会记入积分流水。',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11.5,
                height: 1.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 12),
            if (_selected == null) ...[
              _AdminGamesTextField(
                label: '搜索用户（用户名 / ID / 微信昵称 / 手机号）',
                controller: _queryCtrl,
              ),
              const SizedBox(height: 10),
            ],
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_selected != null)
                      _SelectedUserChip(
                        item: _selected!,
                        onClear: _clearSelected,
                      )
                    else
                      _UserSearchResults(
                        searching: _searching,
                        results: _results,
                        query: _queryCtrl.text.trim(),
                        onSelect: _select,
                      ),
                    const SizedBox(height: 12),
                    _AdminGamesNumberField(
                      label: '调整数量（正数增加，负数扣减）',
                      controller: _amountCtrl,
                      signed: true,
                    ),
                    const SizedBox(height: 10),
                    _AdminGamesTextField(
                      label: '备注（可选）',
                      controller: _noteCtrl,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      _AdminGamesErrorText(_error!),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _AdminGamesSecondaryButton(
                    label: '取消',
                    onPressed: _granting
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AdminGamesPrimaryButton(
                    label: _granting ? '提交中…' : '确认调整',
                    onPressed: (_granting || _selected == null) ? null : _grant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
