part of 'package:companion_flutter/main.dart';

// ---------------------------------------------------------------------------
// Admin · VIP 订阅 & 充值管理
//
// 两个只读审计视图（可搜索 / 可过滤 / 分页）：
//   * VIP 订阅 — 当前有 VIP 的用户：套餐、过期时间、下次续期、开通/到账时间、状态。
//   * 充值记录 — 商城充值 tab 的实际钞票充值：到账钞票、实付金额、发起/到账时间、状态。
// 数据来源：/admin-api/payments/vip-members 与 /admin-api/payments/recharges。
// 与「支付管理」里的按用户 VIP 设置（_VipBalancesTab）互补——那边是操作，这边是审计。
// ---------------------------------------------------------------------------

const _vipSubPageSize = 20;

// 充值状态 → 中文标签（iap_transactions.status）。
const _rechargeStatusLabels = {
  'granted': '已到账',
  'pending': '处理中',
  'refunded': '已退款',
  'revoked': '已撤销',
  'failed': '失败',
};

String _rechargeStatusLabel(String status) =>
    _rechargeStatusLabels[status] ?? status;

// 订阅状态（iap_subscription_state.status）中文标签。
const _subStatusLabels = {
  'active': '续订生效中',
  'in_grace': '宽限期',
  'expired': '已到期',
  'revoked': '已撤销',
  'refunded': '已退款',
};

String _subStatusLabel(String? status) {
  if (status == null || status.isEmpty) return '—';
  return _subStatusLabels[status] ?? status;
}

/// 货币代码 → 符号（仅用于展示实付金额）。
String _currencySymbol(String? currency) {
  switch ((currency ?? '').toUpperCase()) {
    case 'CNY':
    case 'RMB':
      return '¥';
    case 'USD':
      return r'$';
    case 'HKD':
      return r'HK$';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    case 'JPY':
      return '¥';
    default:
      return '';
  }
}

/// 实付金额展示：'¥29.00'；未记录（旧交易 Apple 未回价）显示占位。
String _rechargeAmountText(double? amount, String? currency) {
  if (amount == null) return '未记录';
  final symbol = _currencySymbol(currency);
  final value = amount.toStringAsFixed(2);
  if (symbol.isEmpty) {
    final code = (currency ?? '').trim();
    return code.isEmpty ? value : '$value $code';
  }
  return '$symbol$value';
}

// ===========================================================================
// API
// ===========================================================================

extension _AdminVipSubApi on CompanionApi {
  Future<_AdminVipMembersResponse> fetchVipMembers({
    String? q,
    String? status,
    String? productId,
    int limit = _vipSubPageSize,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (q != null && q.trim().isNotEmpty) params['q'] = q.trim();
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (productId != null && productId.isNotEmpty) {
      params['product_id'] = productId;
    }
    final path = Uri(
      path: '/admin-api/payments/vip-members',
      queryParameters: params,
    ).toString();
    final json =
        await _adminHttpRequest(this, 'GET', path) as Map<String, dynamic>;
    return _AdminVipMembersResponse.fromJson(json);
  }

  Future<_AdminRechargesResponse> fetchRecharges({
    String? q,
    String? status,
    String? environment,
    int limit = _vipSubPageSize,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (q != null && q.trim().isNotEmpty) params['q'] = q.trim();
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (environment != null && environment.isNotEmpty) {
      params['environment'] = environment;
    }
    final path = Uri(
      path: '/admin-api/payments/recharges',
      queryParameters: params,
    ).toString();
    final json =
        await _adminHttpRequest(this, 'GET', path) as Map<String, dynamic>;
    return _AdminRechargesResponse.fromJson(json);
  }
}

// ===========================================================================
// Models
// ===========================================================================

class _AdminVipMemberItem {
  const _AdminVipMemberItem({
    required this.userId,
    this.username,
    this.nickname,
    required this.isActive,
    required this.planLabel,
    this.productId,
    required this.isAutoRenew,
    this.subscriptionStatus,
    this.vipUntil,
    this.nextRenewalDate,
    this.gracePeriodExpiresDate,
    this.vipTrialUsed = false,
    this.environment,
    this.startedAt,
    this.creditedAt,
    this.lastTransactionId,
  });

  final String userId;
  final String? username;
  final String? nickname;
  final bool isActive;
  final String planLabel;
  final String? productId;
  final bool isAutoRenew;
  final String? subscriptionStatus;
  final String? vipUntil;
  final String? nextRenewalDate;
  final String? gracePeriodExpiresDate;
  final bool vipTrialUsed;
  final String? environment;
  final String? startedAt;
  final String? creditedAt;
  final String? lastTransactionId;

  String get displayName =>
      _walletDisplayName(username: username, nickname: nickname);

  factory _AdminVipMemberItem.fromJson(Map<String, dynamic> json) {
    return _AdminVipMemberItem(
      userId: json['user_id']?.toString() ?? '',
      username: json['username']?.toString(),
      nickname: json['nickname']?.toString(),
      isActive: json['is_active'] == true,
      planLabel: json['plan_label']?.toString() ?? '—',
      productId: json['product_id']?.toString(),
      isAutoRenew: json['is_auto_renew'] == true,
      subscriptionStatus: json['subscription_status']?.toString(),
      vipUntil: json['vip_until']?.toString(),
      nextRenewalDate: json['next_renewal_date']?.toString(),
      gracePeriodExpiresDate: json['grace_period_expires_date']?.toString(),
      vipTrialUsed: json['vip_trial_used'] == true,
      environment: json['environment']?.toString(),
      startedAt: json['started_at']?.toString(),
      creditedAt: json['credited_at']?.toString(),
      lastTransactionId: json['last_transaction_id']?.toString(),
    );
  }
}

class _AdminVipMembersResponse {
  const _AdminVipMembersResponse({
    required this.items,
    required this.total,
    required this.activeCount,
  });

  final List<_AdminVipMemberItem> items;
  final int total;
  final int activeCount;

  factory _AdminVipMembersResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return _AdminVipMembersResponse(
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) => _AdminVipMemberItem.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
      total: _adminInt(json['total']),
      activeCount: _adminInt(json['active_count']),
    );
  }
}

class _AdminRechargeItem {
  const _AdminRechargeItem({
    required this.transactionId,
    required this.userId,
    this.username,
    this.nickname,
    required this.productId,
    required this.productLabel,
    required this.tickets,
    required this.quantity,
    this.amount,
    this.currency,
    this.storefront,
    required this.environment,
    required this.status,
    this.initiatedAt,
    this.creditedAt,
    this.updatedAt,
  });

  final String transactionId;
  final String userId;
  final String? username;
  final String? nickname;
  final String productId;
  final String productLabel;
  final int tickets;
  final int quantity;
  final double? amount;
  final String? currency;
  final String? storefront;
  final String environment;
  final String status;
  final String? initiatedAt;
  final String? creditedAt;
  final String? updatedAt;

  String get displayName =>
      _walletDisplayName(username: username, nickname: nickname);

  factory _AdminRechargeItem.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount'];
    return _AdminRechargeItem(
      transactionId: json['transaction_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      username: json['username']?.toString(),
      nickname: json['nickname']?.toString(),
      productId: json['product_id']?.toString() ?? '',
      productLabel: json['product_label']?.toString() ?? '',
      tickets: _adminInt(json['tickets']),
      quantity: _adminInt(json['quantity'], 1),
      amount: rawAmount is num ? rawAmount.toDouble() : null,
      currency: json['currency']?.toString(),
      storefront: json['storefront']?.toString(),
      environment: json['environment']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      initiatedAt: json['initiated_at']?.toString(),
      creditedAt: json['credited_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }
}

class _AdminRechargesResponse {
  const _AdminRechargesResponse({
    required this.items,
    required this.total,
    required this.totalTickets,
    required this.distinctUsers,
  });

  final List<_AdminRechargeItem> items;
  final int total;
  final int totalTickets;
  final int distinctUsers;

  factory _AdminRechargesResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return _AdminRechargesResponse(
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) => _AdminRechargeItem.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
      total: _adminInt(json['total']),
      totalTickets: _adminInt(json['total_tickets']),
      distinctUsers: _adminInt(json['distinct_users']),
    );
  }
}

// ===========================================================================
// Entry page: VIP 订阅 / 充值记录 两级 tab
// ===========================================================================

class _AdminVipSubscriptionPage extends StatefulWidget {
  const _AdminVipSubscriptionPage({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_AdminVipSubscriptionPage> createState() =>
      _AdminVipSubscriptionPageState();
}

class _AdminVipSubscriptionPageState extends State<_AdminVipSubscriptionPage> {
  int _tab = 0; // 0 = VIP 订阅, 1 = 充值记录

  @override
  Widget build(BuildContext context) {
    return _AdminScaffold(
      title: '会员与充值',
      subtitle: _tab == 0 ? 'VIP 订阅用户' : '钞票充值记录',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _tab,
                children: const {
                  0: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('VIP 订阅', style: TextStyle(fontSize: 13)),
                  ),
                  1: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('充值记录', style: TextStyle(fontSize: 13)),
                  ),
                },
                onValueChanged: (value) {
                  if (value != null) setState(() => _tab = value);
                },
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                _VipSubscribersTab(api: widget.api, session: widget.session),
                _RechargeRecordsTab(api: widget.api, session: widget.session),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Tab · VIP 订阅用户
// ===========================================================================

// VIP 套餐过滤项（label, product_id）；product_id 为空=全部。
const _vipPlanFilters = <(String, String?)>[
  ('全部', null),
  ('连续包月', 'com.bansheng.vip.monthly.auto'),
  ('月卡', 'com.bansheng.vip.month'),
  ('季卡', 'com.bansheng.vip.quarter'),
  ('年卡', 'com.bansheng.vip.year'),
  ('体验', 'com.bansheng.vip.trial'),
];

class _VipSubscribersTab extends StatefulWidget {
  const _VipSubscribersTab({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_VipSubscribersTab> createState() => _VipSubscribersTabState();
}

class _VipSubscribersTabState extends State<_VipSubscribersTab> {
  final _searchCtrl = TextEditingController();
  int _page = 0;
  int _total = 0;
  int _activeCount = 0;
  String _appliedSearch = '';
  String _status = ''; // '' 全部 | 'active' | 'expired'
  String? _plan; // product_id 或 null 全部
  bool _loading = true;
  String? _error;
  List<_AdminVipMemberItem> _items = const [];

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
      final result = await widget.api.fetchVipMembers(
        q: _appliedSearch.isEmpty ? null : _appliedSearch,
        status: _status.isEmpty ? null : _status,
        productId: _plan,
        limit: _vipSubPageSize,
        offset: _page * _vipSubPageSize,
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _total = result.total;
        _activeCount = result.activeCount;
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
      _status = '';
      _plan = null;
      _page = 0;
    });
    _load();
  }

  void _setStatus(String status) {
    if (_status == status) return;
    setState(() {
      _status = status;
      _page = 0;
    });
    _load();
  }

  void _setPlan(String? plan) {
    if (_plan == plan) return;
    setState(() {
      _plan = plan;
      _page = 0;
    });
    _load();
  }

  int get _totalPages => math.max(1, (_total / _vipSubPageSize).ceil());

  Future<void> _openDetail(_AdminVipMemberItem item) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _VipMemberDetailDialog(item: item),
    );
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
                  '所有当前或曾经拥有 VIP 的用户。「连续包月」为自动续订，会显示下次续期'
                  '时间；月/季/年卡与 ¥1 体验为一次性时长包，无续期。管理员手动设置的 '
                  'VIP 也会出现，套餐显示「手动设置」。',
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
                        label: '搜索用户名 / 显示名 / ID / 微信昵称',
                        controller: _searchCtrl,
                      ),
                      const SizedBox(height: 10),
                      _AdminFilterSegmented(
                        label: '状态',
                        value: _status,
                        options: const [
                          ('全部', ''),
                          ('生效中', 'active'),
                          ('已过期', 'expired'),
                        ],
                        onChanged: _loading ? null : _setStatus,
                      ),
                      const SizedBox(height: 10),
                      _AdminFilterChips(
                        label: '套餐',
                        selected: _plan,
                        options: _vipPlanFilters,
                        onChanged: _loading ? null : _setPlan,
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
                              label: '重置',
                              onPressed: _loading ? null : _resetSearch,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _AdminStatStrip(
                  stats: [
                    ('总计', '$_total'),
                    ('生效中', '$_activeCount'),
                  ],
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
                    '暂无会员',
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
                    _VipMemberCard(
                      item: item,
                      onTap: () => _openDetail(item),
                    ),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
          ),
        ),
        _vipSubPager(
          page: _page,
          totalPages: _totalPages,
          total: _total,
          unit: '人',
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

class _VipMemberCard extends StatelessWidget {
  const _VipMemberCard({required this.item, required this.onTap});

  final _AdminVipMemberItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: _AdminCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${item.planLabel} · ${_shortId(item.userId)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '到期 ${_vipFormatDate(item.vipUntil)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _StatusPill(
                  text: item.isActive ? '生效中' : '已过期',
                  positive: item.isActive,
                ),
                if (item.isAutoRenew) ...[
                  const SizedBox(height: 6),
                  Text(
                    '自动续订',
                    style: TextStyle(
                      color: AppColors.of(context).accent,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VipMemberDetailDialog extends StatelessWidget {
  const _VipMemberDetailDialog({required this.item});

  final _AdminVipMemberItem item;

  @override
  Widget build(BuildContext context) {
    return _AdminDetailDialog(
      title: item.displayName,
      rows: [
        ('用户 ID', item.userId),
        ('用户名', item.username ?? '—'),
        ('微信昵称', item.nickname ?? '—'),
        ('当前状态', item.isActive ? '生效中' : '已过期'),
        ('套餐', item.planLabel),
        ('续订方式', item.isAutoRenew ? '自动续订' : '一次性 / 手动'),
        ('订阅状态', _subStatusLabel(item.subscriptionStatus)),
        ('过期时间', _vipFormatDate(item.vipUntil)),
        ('下次续期', _vipFormatDate(item.nextRenewalDate)),
        if (item.gracePeriodExpiresDate != null)
          ('宽限期至', _vipFormatDate(item.gracePeriodExpiresDate)),
        ('发起时间', _vipFormatDate(item.startedAt)),
        ('到账时间', _vipFormatDate(item.creditedAt)),
        ('环境', item.environment ?? '—'),
        ('¥1 体验已用', item.vipTrialUsed ? '是' : '否'),
        ('最近交易号', item.lastTransactionId ?? '—'),
      ],
    );
  }
}

// ===========================================================================
// Tab · 钞票充值记录
// ===========================================================================

class _RechargeRecordsTab extends StatefulWidget {
  const _RechargeRecordsTab({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_RechargeRecordsTab> createState() => _RechargeRecordsTabState();
}

class _RechargeRecordsTabState extends State<_RechargeRecordsTab> {
  final _searchCtrl = TextEditingController();
  int _page = 0;
  int _total = 0;
  int _totalTickets = 0;
  int _distinctUsers = 0;
  String _appliedSearch = '';
  String _status = ''; // '' 全部 | granted | pending | refunded
  String _environment = ''; // '' 全部 | Sandbox | Production
  bool _loading = true;
  String? _error;
  List<_AdminRechargeItem> _items = const [];

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
      final result = await widget.api.fetchRecharges(
        q: _appliedSearch.isEmpty ? null : _appliedSearch,
        status: _status.isEmpty ? null : _status,
        environment: _environment.isEmpty ? null : _environment,
        limit: _vipSubPageSize,
        offset: _page * _vipSubPageSize,
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _total = result.total;
        _totalTickets = result.totalTickets;
        _distinctUsers = result.distinctUsers;
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
      _status = '';
      _environment = '';
      _page = 0;
    });
    _load();
  }

  void _setStatus(String status) {
    if (_status == status) return;
    setState(() {
      _status = status;
      _page = 0;
    });
    _load();
  }

  void _setEnvironment(String environment) {
    if (_environment == environment) return;
    setState(() {
      _environment = environment;
      _page = 0;
    });
    _load();
  }

  int get _totalPages => math.max(1, (_total / _vipSubPageSize).ceil());

  Future<void> _openDetail(_AdminRechargeItem item) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _RechargeDetailDialog(item: item),
    );
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
                  '商城「充值」tab 里真实付费购买钞票的记录。到账钞票以钱包流水为准；'
                  '实付金额来自 Apple 交易信息（仅新交易记录，历史交易可能为「未记录」）。',
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
                        label: '搜索用户名 / ID / 昵称 / 交易号',
                        controller: _searchCtrl,
                      ),
                      const SizedBox(height: 10),
                      _AdminFilterSegmented(
                        label: '状态',
                        value: _status,
                        options: const [
                          ('全部', ''),
                          ('已到账', 'granted'),
                          ('处理中', 'pending'),
                          ('已退款', 'refunded'),
                        ],
                        onChanged: _loading ? null : _setStatus,
                      ),
                      const SizedBox(height: 10),
                      _AdminFilterSegmented(
                        label: '环境',
                        value: _environment,
                        options: const [
                          ('全部', ''),
                          ('Sandbox', 'Sandbox'),
                          ('Production', 'Production'),
                        ],
                        onChanged: _loading ? null : _setEnvironment,
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
                              label: '重置',
                              onPressed: _loading ? null : _resetSearch,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _AdminStatStrip(
                  stats: [
                    ('笔数', '$_total'),
                    ('到账钞票', '$_totalTickets'),
                    ('用户数', '$_distinctUsers'),
                  ],
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
                    '暂无充值记录',
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
                    _RechargeCard(item: item, onTap: () => _openDetail(item)),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
          ),
        ),
        _vipSubPager(
          page: _page,
          totalPages: _totalPages,
          total: _total,
          unit: '笔',
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

class _RechargeCard extends StatelessWidget {
  const _RechargeCard({required this.item, required this.onTap});

  final _AdminRechargeItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final granted = item.status == 'granted';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: _AdminCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${item.productLabel} · ${_shortId(item.userId)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '到账 ${_vipFormatDate(item.creditedAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+${item.tickets}',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _rechargeAmountText(item.amount, item.currency),
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 5),
                _StatusPill(
                  text: _rechargeStatusLabel(item.status),
                  positive: granted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RechargeDetailDialog extends StatelessWidget {
  const _RechargeDetailDialog({required this.item});

  final _AdminRechargeItem item;

  @override
  Widget build(BuildContext context) {
    return _AdminDetailDialog(
      title: '${item.displayName} · ${item.productLabel}',
      rows: [
        ('用户 ID', item.userId),
        ('用户名', item.username ?? '—'),
        ('微信昵称', item.nickname ?? '—'),
        ('商品', '${item.productLabel}（${item.productId}）'),
        ('到账钞票', '+${item.tickets}'),
        ('数量', '${item.quantity}'),
        ('实付金额', _rechargeAmountText(item.amount, item.currency)),
        if (item.storefront != null && item.storefront!.isNotEmpty)
          ('storefront', item.storefront!),
        ('状态', _rechargeStatusLabel(item.status)),
        ('环境', item.environment),
        ('发起时间', _vipFormatDate(item.initiatedAt)),
        ('到账时间', _vipFormatDate(item.creditedAt)),
        ('更新时间', _vipFormatDate(item.updatedAt)),
        ('交易号', item.transactionId),
      ],
    );
  }
}

// ===========================================================================
// Shared small widgets (local to this admin screen)
// ===========================================================================

/// 底部分页条（复用 _adminWalletBalancePager 的样式，但单位可配「人/笔」）。
Widget _vipSubPager({
  required int page,
  required int totalPages,
  required int total,
  required String unit,
  required VoidCallback? onPrev,
  required VoidCallback? onNext,
}) {
  return SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
      child: Row(
        children: [
          Expanded(
            child: _AdminGamesSecondaryButton(label: '上一页', onPressed: onPrev),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '第 ${page + 1} / $totalPages 页 · 共 $total $unit',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _AdminGamesSecondaryButton(label: '下一页', onPressed: onNext),
          ),
        ],
      ),
    ),
  );
}

/// 状态胶囊：生效/到账=绿，过期/其它=灰。
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.positive});

  final String text;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF1FA97A);
    final color = positive ? green : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

/// 小统计条：一行若干「标题 + 数值」，放在过滤卡片下方。
class _AdminStatStrip extends StatelessWidget {
  const _AdminStatStrip({required this.stats});

  final List<(String, String)> stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _AdminCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stats[i].$1,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stats[i].$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 分段过滤器（少量互斥选项，如状态 / 环境）。value 空串=第一个「全部」。
class _AdminFilterSegmented extends StatelessWidget {
  const _AdminFilterSegmented({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<(String, String)> options; // (label, value)
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AdminGamesFieldLabel(label),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: CupertinoSlidingSegmentedControl<String>(
            groupValue: value,
            children: {
              for (final option in options)
                option.$2: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Text(option.$1, style: const TextStyle(fontSize: 12)),
                ),
            },
            // onValueChanged 必须非空；加载中（onChanged==null）时忽略点击。
            onValueChanged: (v) {
              if (onChanged != null && v != null) onChanged!(v);
            },
          ),
        ),
      ],
    );
  }
}

/// 横向可滚动的过滤芯片（选项较多时用，如 VIP 套餐）。
class _AdminFilterChips extends StatelessWidget {
  const _AdminFilterChips({
    required this.label,
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? selected;
  final List<(String, String?)> options; // (label, product_id|null)
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.of(context).accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AdminGamesFieldLabel(label),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final option in options) ...[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onChanged == null
                      ? null
                      : () => onChanged!(option.$2),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected == option.$2
                          ? accent
                          : accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      option.$1,
                      style: TextStyle(
                        color: selected == option.$2 ? Colors.white : accent,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 只读详情弹窗：一列「标签 + 值」，chrome 与 _SetVipDialog 对齐。
class _AdminDetailDialog extends StatelessWidget {
  const _AdminDetailDialog({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          color: isDark ? const Color(0xFF1B2024) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AdminGamesSectionHeader(title),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final row in rows) ...[
                      _AdminDetailRow(label: row.$1, value: row.$2),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: _AdminGamesSecondaryButton(
                label: '关闭',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminDetailRow extends StatelessWidget {
  const _AdminDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.35,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }
}
