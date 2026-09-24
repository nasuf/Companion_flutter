part of 'package:companion_flutter/main.dart';

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
    final message = await showAdminDialog<String>(
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
                    _AdminWalletBalanceCard(
                      item: item,
                      primaryLabel: '钞票',
                      primaryValue: item.ticketBalance,
                      secondaryLine: '商城积分 ${item.pointBalance}',
                      onAdjust: _loading
                          ? null
                          : () => _openGrant(item: item),
                    ),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
          ),
        ),
        _adminWalletBalancePager(
          page: _page,
          totalPages: _totalPages,
          total: _total,
          onPrev: (_page == 0 || _loading)
              ? null
              : () {
                  setState(() => _page -= 1);
                  _load();
                },
          onNext: (_page + 1 >= _totalPages || _loading)
              ? null
              : () {
                  setState(() => _page += 1);
                  _load();
                },
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
    final message = await showAdminDialog<String>(
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
                    _AdminWalletBalanceCard(
                      item: item,
                      primaryLabel: '商城积分',
                      primaryValue: item.pointBalance,
                      secondaryLine: '钞票 ${item.ticketBalance}',
                      onAdjust: _loading
                          ? null
                          : () => _openGrant(item: item),
                    ),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
          ),
        ),
        _adminWalletBalancePager(
          page: _page,
          totalPages: _totalPages,
          total: _total,
          onPrev: (_page == 0 || _loading)
              ? null
              : () {
                  setState(() => _page -= 1);
                  _load();
                },
          onNext: (_page + 1 >= _totalPages || _loading)
              ? null
              : () {
                  setState(() => _page += 1);
                  _load();
                },
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
