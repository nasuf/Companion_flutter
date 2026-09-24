part of 'package:companion_flutter/main.dart';

// ===========================================================================
// Tab · 会员管理
// ===========================================================================

class _VipBalanceCard extends StatelessWidget {
  const _VipBalanceCard({required this.item, required this.onSetVip});

  final _AdminWalletBalanceItem item;
  final VoidCallback? onSetVip;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.text : const Color(0xFF12171B);
    final accent = AppColors.of(context).accent;
    final shortId = item.userId.length > 8
        ? item.userId.substring(0, 8)
        : item.userId;

    return _AdminCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        color: textColor,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.username} · $shortId',
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
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: item.isVip
                      ? const Color(0xFFE8B54A).withValues(alpha: 0.18)
                      : AppColors.muted.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.isVip ? 'VIP' : '非 VIP',
                  style: TextStyle(
                    color: item.isVip
                        ? const Color(0xFFC08A1E)
                        : AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '到期时间 ${_vipFormatDate(item.vipUntil)}',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '限时钞票 ${item.giftTicketBalance}',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              minimumSize: Size.zero,
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              onPressed: onSetVip,
              child: Text(
                '设置',
                style: TextStyle(
                  color: accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VipBalancesTab extends StatefulWidget {
  const _VipBalancesTab({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_VipBalancesTab> createState() => _VipBalancesTabState();
}

class _VipBalancesTabState extends State<_VipBalancesTab> {
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

  // 会员管理复用钞票余额接口 — 服务端同一份 /admin-api/wallet/balances 响应
  // 已经带上 is_vip/vip_until/gift_ticket_balance，不需要单独的列表接口。
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

  Future<void> _openSetVip({_AdminWalletBalanceItem? item}) async {
    final message = await showAdminDialog<String>(
      context: context,
      builder: (_) => _SetVipDialog(
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
                  '查看所有用户的 VIP 状态，并可手动设置 / 延长 / 结束 VIP。设置后不会补发'
                  '当月的每月赠送（限时钞票 / 音乐畅听券 / 补签卡），那部分仍由夜间'
                  '定时任务按 VIP 生效时间的锚点发放。',
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
                  label: '设置 VIP',
                  onPressed: _loading ? null : () => _openSetVip(),
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
                    _VipBalanceCard(
                      item: item,
                      onSetVip: _loading
                          ? null
                          : () => _openSetVip(item: item),
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
// Tab · 会员发放流水
// ===========================================================================

class _VipLedgerTab extends StatefulWidget {
  const _VipLedgerTab({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_VipLedgerTab> createState() => _VipLedgerTabState();
}

class _VipLedgerTabState extends State<_VipLedgerTab> {
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
      final items = await widget.api.fetchGiftTicketLedger(
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
                  '限时钞票（VIP 每月赠送）的变更审计记录：每月发放 / VIP 过期清零 / '
                  '后台手动调整。',
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
                    '暂无会员发放流水',
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
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
                            '${_vipSourceLabel(item.source)} · '
                            '${_walletFormatTimestamp(item.createdAt)}',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 11.5,
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
