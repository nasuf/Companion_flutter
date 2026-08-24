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

const _vipSourceLabels = {
  'vip_monthly_grant': 'VIP 每月发放',
  'vip_expire_clear': 'VIP 过期清零',
  'admin_grant': '后台发放',
};

String _vipSourceLabel(String source) => _vipSourceLabels[source] ?? source;

String _vipFormatDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '--';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return _walletFormatTimestamp(raw);
  final local = parsed.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

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

  Future<List<_AdminWalletLedgerItem>> fetchGiftTicketLedger({
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
      path: '/admin-api/wallet/gift-ticket-ledger',
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

  Future<_AdminVipSetResult> setVip({
    required String userId,
    required String? vipUntilIso,
    String? note,
  }) async {
    final body = <String, dynamic>{
      'user_id': userId,
      'vip_until': vipUntilIso,
    };
    final trimmedNote = note?.trim();
    if (trimmedNote != null && trimmedNote.isNotEmpty) {
      body['note'] = trimmedNote;
    }
    final json =
        await _adminHttpRequest(
              this,
              'POST',
              '/admin-api/wallet/vip-set',
              body: body,
            )
            as Map<String, dynamic>;
    return _AdminVipSetResult.fromJson(json);
  }

  Future<_AdminChatQuotaStatus> fetchChatQuotaStatus(String userId) async {
    final path = Uri(
      path: '/admin-api/chat-quota/status',
      queryParameters: {'user_id': userId},
    ).toString();
    final json =
        await _adminHttpRequest(this, 'GET', path) as Map<String, dynamic>;
    return _AdminChatQuotaStatus.fromJson(json);
  }

  Future<_AdminChatQuotaStatus> resetChatQuota({
    required String userId,
    String? note,
  }) async {
    final body = <String, dynamic>{'user_id': userId};
    final trimmedNote = note?.trim();
    if (trimmedNote != null && trimmedNote.isNotEmpty) {
      body['note'] = trimmedNote;
    }
    final json =
        await _adminHttpRequest(
              this,
              'POST',
              '/admin-api/chat-quota/reset',
              body: body,
            )
            as Map<String, dynamic>;
    return _AdminChatQuotaStatus.fromJson(json);
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
    this.giftTicketBalance = 0,
    this.isVip = false,
    this.vipUntil,
  });

  final String userId;
  final String username;
  final String? displayName;
  final String? nickname;
  final int ticketBalance;
  final int pointBalance;
  final String? updatedAt;

  /// CLAUDE.md 权益项 3: VIP 每月赠送的限时钞票，随 VIP 存续结转、过期清零。
  final int giftTicketBalance;
  final bool isVip;
  final String? vipUntil;

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
      giftTicketBalance: _adminInt(json['gift_ticket_balance']),
      isVip: json['is_vip'] == true,
      vipUntil: json['vip_until']?.toString(),
    );
  }
}

class _AdminVipSetResult {
  const _AdminVipSetResult({
    required this.userId,
    required this.isVip,
    this.vipUntil,
  });

  final String userId;
  final bool isVip;
  final String? vipUntil;

  factory _AdminVipSetResult.fromJson(Map<String, dynamic> json) {
    return _AdminVipSetResult(
      userId: json['user_id']?.toString() ?? '',
      isVip: json['is_vip'] == true,
      vipUntil: json['vip_until']?.toString(),
    );
  }
}

class _AdminChatQuotaStatus {
  const _AdminChatQuotaStatus({
    required this.userId,
    required this.isVip,
    required this.periodScope,
    required this.periodKey,
    required this.used,
    required this.limit,
    required this.freeRemaining,
    required this.mode,
    required this.perMsgCost,
    required this.spendableTickets,
  });

  final String userId;
  final bool isVip;
  final String periodScope; // 'day' | 'month'
  final String periodKey;
  final int used;
  final int limit;
  final int freeRemaining;
  final String mode; // 'free' | 'paid' | 'blocked'
  final num perMsgCost;
  final num spendableTickets;

  factory _AdminChatQuotaStatus.fromJson(Map<String, dynamic> json) {
    return _AdminChatQuotaStatus(
      userId: json['user_id']?.toString() ?? '',
      isVip: json['is_vip'] == true,
      periodScope: json['period_scope']?.toString() ?? '',
      periodKey: json['period_key']?.toString() ?? '',
      used: _adminInt(json['used']),
      limit: _adminInt(json['limit']),
      freeRemaining: _adminInt(json['free_remaining']),
      mode: json['mode']?.toString() ?? '',
      perMsgCost: (json['per_msg_cost'] as num?) ?? 0,
      spendableTickets: (json['spendable_tickets'] as num?) ?? 0,
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
// Shared balance list widgets (Row + full-width button breaks layout)
// ===========================================================================

class _AdminWalletAdjustButton extends StatelessWidget {
  const _AdminWalletAdjustButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.of(context).accent;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      minimumSize: Size.zero,
      color: accent.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
      onPressed: onPressed,
      child: Text(
        '调整',
        style: TextStyle(
          color: accent,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _AdminWalletBalanceCard extends StatelessWidget {
  const _AdminWalletBalanceCard({
    required this.item,
    required this.primaryLabel,
    required this.primaryValue,
    required this.secondaryLine,
    required this.onAdjust,
  });

  final _AdminWalletBalanceItem item;
  final String primaryLabel;
  final int primaryValue;
  final String secondaryLine;
  final VoidCallback? onAdjust;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.text : const Color(0xFF12171B);
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    primaryLabel,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$primaryValue',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            secondaryLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
            '更新 ${_walletFormatTimestamp(item.updatedAt)}',
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
            child: _AdminWalletAdjustButton(onPressed: onAdjust),
          ),
        ],
      ),
    );
  }
}

Widget _adminWalletBalancePager({
  required int page,
  required int totalPages,
  required int total,
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
            child: _AdminGamesSecondaryButton(
              label: '上一页',
              onPressed: onPrev,
            ),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '第 ${page + 1} / $totalPages 页 · 共 $total 人',
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
            child: _AdminGamesSecondaryButton(
              label: '下一页',
              onPressed: onNext,
            ),
          ),
        ],
      ),
    ),
  );
}

// ===========================================================================
// Entry page: 钞票管理 / 钞票流水
// ===========================================================================

/// 支付管理下的三种资源类型，各自都有"管理"(余额/设置) 和"流水"(审计) 两个
/// 视图 —— 6 个页面按 3×2 两级选择器组织，而不是塞进一整行 6 个缩写 tab
/// (钞票管理新增会员管理前就已经因为放不下而把标签缩成"钞票/钞流/积分/分流"
/// 这种单看无法确定意思的两字缩写；再加两个会员 tab 只会更挤更难点准)。
enum _PaymentResource {
  ticket('钞票'),
  point('积分'),
  vip('会员'),
  quota('额度');

  const _PaymentResource(this.label);
  final String label;
}

enum _PaymentView {
  manage('管理'),
  ledger('流水');

  const _PaymentView(this.label);
  final String label;
}

class _AdminPaymentsPage extends StatefulWidget {
  const _AdminPaymentsPage({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends State<_AdminPaymentsPage> {
  _PaymentResource _resource = _PaymentResource.ticket;
  _PaymentView _view = _PaymentView.manage;

  static const _subtitles = {
    _PaymentResource.ticket: '钞票余额 · 手动发放 · 流水审计',
    _PaymentResource.point: '商城积分余额 · 手动发放 · 流水审计',
    _PaymentResource.vip: 'VIP 状态 · 设置/延长/结束 · 限时钞票流水',
    _PaymentResource.quota: '对话额度 · 查看用量 · 重置当前周期',
  };

  // quota 没有"管理/流水"两种视图，只有一个统一页面 —— 与其为它硬凑一对
  // 空的流水 tab，不如让视图选择器本身在这个资源下不出现。
  bool get _resourceHasViews => _resource != _PaymentResource.quota;

  // 沿用现有 IndexedStack 让已切换过的 tab 保留状态 (搜索词/翻页/已加载数据)
  // 不因为切资源而重置; quota 没有 view 维度, 单独占最后一个位置, 不参与
  // resource*2+view 的既有算式 (避免打乱 ticket/point/vip 现成的 0-5 下标)。
  int get _stackIndex {
    if (_resource == _PaymentResource.quota) {
      // quota 是唯一没有 view 维度的资源，追加在既有 6 个 (3 资源 × 2 视图)
      // 之后成为第 7 个 child，下标固定为 6。
      return (_PaymentResource.values.length - 1) * _PaymentView.values.length;
    }
    return _resource.index * _PaymentView.values.length + _view.index;
  }

  @override
  Widget build(BuildContext context) {
    return _AdminScaffold(
      title: '支付管理',
      subtitle: _subtitles[_resource],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<_PaymentResource>(
                groupValue: _resource,
                onValueChanged: (value) {
                  if (value != null) setState(() => _resource = value);
                },
                children: {
                  for (final resource in _PaymentResource.values)
                    resource: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        resource.label,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                },
              ),
            ),
          ),
          if (_resourceHasViews)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 4),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<_PaymentView>(
                  groupValue: _view,
                  onValueChanged: (value) {
                    if (value != null) setState(() => _view = value);
                  },
                  children: {
                    for (final view in _PaymentView.values)
                      view: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Text(
                          view.label,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                  },
                ),
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _stackIndex,
              children: [
                _WalletBalancesTab(api: widget.api, session: widget.session),
                _WalletLedgerTab(api: widget.api, session: widget.session),
                _PointBalancesTab(api: widget.api, session: widget.session),
                _PointLedgerTab(api: widget.api, session: widget.session),
                _VipBalancesTab(api: widget.api, session: widget.session),
                _VipLedgerTab(api: widget.api, session: widget.session),
                _ChatQuotaTab(api: widget.api, session: widget.session),
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
    final message = await showDialog<String>(
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

// ===========================================================================
// 设置 VIP modal — fuzzy user search + 延长(天) / 立即结束 (mirrors web)
// ===========================================================================

const _vipExtendOptions = [
  (label: '+7 天', days: 7),
  (label: '+30 天', days: 30),
  (label: '+90 天', days: 90),
  (label: '+365 天', days: 365),
];

class _SetVipDialog extends StatefulWidget {
  const _SetVipDialog({
    required this.api,
    required this.session,
    this.preselect,
  });

  final CompanionApi api;
  final AuthSession session;
  final _AdminUserSearchItem? preselect;

  @override
  State<_SetVipDialog> createState() => _SetVipDialogState();
}

class _SetVipDialogState extends State<_SetVipDialog> {
  final _queryCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  Timer? _debounce;
  int _searchSeq = 0;
  List<_AdminUserSearchItem> _results = const [];
  bool _searching = false;
  bool _saving = false;
  _AdminUserSearchItem? _selected;
  String? _error;

  // 选中用户当前的到期时间，用来算"延长"的起点。不能假设 preselect 里带着
  // 准确数据 —— 从搜索里选中一个用户时压根没有这份数据，会把延长基准错算
  // 成"现在"而不是其真实到期时间。选中后统一自己查一次，两条入口都准确。
  String? _resolvedVipUntil;
  bool _resolvingVipUntil = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.preselect;
    _queryCtrl.addListener(_onQueryChanged);
    if (_selected != null) unawaited(_resolveVipUntil(_selected!));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryCtrl.dispose();
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

  Future<void> _resolveVipUntil(_AdminUserSearchItem user) async {
    setState(() {
      _resolvedVipUntil = null;
      _resolvingVipUntil = true;
    });
    widget.api.authToken = widget.session.token;
    try {
      final result = await widget.api.fetchWalletBalances(
        search: user.userId,
        limit: 1,
      );
      if (!mounted) return;
      final match = result.items.where((i) => i.userId == user.userId);
      setState(() {
        _resolvedVipUntil = match.isEmpty ? null : match.first.vipUntil;
        _resolvingVipUntil = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _walletAdminErrorText(error);
        _resolvingVipUntil = false;
      });
    }
  }

  void _select(_AdminUserSearchItem item) {
    setState(() {
      _selected = item;
      _results = const [];
      _error = null;
    });
    unawaited(_resolveVipUntil(item));
  }

  void _clearSelected() {
    setState(() {
      _selected = null;
      _resolvedVipUntil = null;
      _queryCtrl.clear();
      _results = const [];
    });
  }

  Future<void> _save(String? vipUntilIso) async {
    if (_saving) return;
    final selected = _selected;
    if (selected == null) {
      setState(() => _error = '请先选择用户');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    widget.api.authToken = widget.session.token;
    try {
      final result = await widget.api.setVip(
        userId: selected.userId,
        vipUntilIso: vipUntilIso,
        note: _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      final message = result.isVip
          ? '已将 ${selected.displayName} 设为 VIP，到期时间 '
              '${_vipFormatDate(result.vipUntil)}。'
          : '已结束 ${selected.displayName} 的 VIP。';
      Navigator.of(context).pop(message);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _walletAdminErrorText(error);
      });
    }
  }

  void _extendBy(int days) {
    // 从"当前到期时间"和"现在"两者中较晚的一个开始延长 —— 已过期就从现在
    // 起算，还在有效期内就在原到期时间上累加，不会因为延长反而缩短时长。
    final now = DateTime.now();
    final current = _resolvedVipUntil == null
        ? null
        : DateTime.tryParse(_resolvedVipUntil!);
    final base = (current != null && current.isAfter(now)) ? current : now;
    final next = base.add(Duration(days: days));
    unawaited(_save(next.toUtc().toIso8601String()));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final danger = AppColors.of(context).danger;
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
            const _AdminGamesSectionHeader('设置 VIP'),
            const SizedBox(height: 4),
            Text(
              '搜索并选择用户后设置 / 延长 / 结束 VIP。延长会从"当前到期时间"和'
              '"现在"中较晚的一个开始累加。',
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
                    if (_selected != null) ...[
                      _SelectedUserChip(
                        item: _selected!,
                        onClear: _clearSelected,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '当前到期时间：'
                        '${_resolvingVipUntil ? "查询中…" : (_resolvedVipUntil == null ? "非 VIP" : _vipFormatDate(_resolvedVipUntil))}',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ] else
                      _UserSearchResults(
                        searching: _searching,
                        results: _results,
                        query: _queryCtrl.text.trim(),
                        onSelect: _select,
                      ),
                    const SizedBox(height: 12),
                    _AdminGamesTextField(
                      label: '备注（可选）',
                      controller: _noteCtrl,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '延长',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in _vipExtendOptions)
                          _AdminGamesSecondaryButton(
                            label: _saving ? '提交中…' : option.label,
                            onPressed:
                                (_saving ||
                                    _selected == null ||
                                    _resolvingVipUntil)
                                ? null
                                : () => _extendBy(option.days),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '结束',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      minimumSize: Size.zero,
                      color: danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      onPressed: (_saving || _selected == null)
                          ? null
                          : () => _save(null),
                      child: Text(
                        '立即结束 VIP（限时钞票与礼包同步清零，不结转）',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: danger,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                          decoration: TextDecoration.none,
                        ),
                      ),
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
            _AdminGamesSecondaryButton(
              label: '关闭',
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Tab · 对话额度重置
// ===========================================================================

const _chatQuotaModeLabels = {
  'free': '免费额度内',
  'paid': '已进入超额扣费',
  'blocked': '已耗尽（钞票不足）',
};

class _ChatQuotaTab extends StatefulWidget {
  const _ChatQuotaTab({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_ChatQuotaTab> createState() => _ChatQuotaTabState();
}

class _ChatQuotaTabState extends State<_ChatQuotaTab> {
  final _queryCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  Timer? _debounce;
  int _searchSeq = 0;
  List<_AdminUserSearchItem> _results = const [];
  bool _searching = false;
  _AdminUserSearchItem? _selected;
  _AdminChatQuotaStatus? _status;
  bool _loadingStatus = false;
  bool _confirming = false;
  bool _resetting = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _queryCtrl.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryCtrl.dispose();
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
      _status = null;
      _notice = null;
      _error = null;
      _confirming = false;
      _noteCtrl.clear();
      _loadingStatus = true;
    });
    widget.api.authToken = widget.session.token;
    widget.api
        .fetchChatQuotaStatus(item.userId)
        .then((result) {
          if (!mounted) return;
          setState(() {
            _status = result;
            _loadingStatus = false;
          });
        })
        .catchError((Object error) {
          if (!mounted) return;
          setState(() {
            _error = _walletAdminErrorText(error);
            _loadingStatus = false;
          });
        });
  }

  void _clearSelected() {
    setState(() {
      _selected = null;
      _status = null;
      _confirming = false;
      _notice = null;
      _queryCtrl.clear();
      _noteCtrl.clear();
      _results = const [];
    });
  }

  Future<void> _reset() async {
    final selected = _selected;
    if (selected == null || _resetting) return;
    setState(() {
      _resetting = true;
      _error = null;
    });
    widget.api.authToken = widget.session.token;
    try {
      final result = await widget.api.resetChatQuota(
        userId: selected.userId,
        note: _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _status = result;
        _confirming = false;
        _resetting = false;
        _notice = '已重置 ${selected.displayName} 当前周期的对话额度。';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _resetting = false;
        _error = _walletAdminErrorText(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final danger = AppColors.of(context).danger;
    final status = _status;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
      children: [
        Text(
          '搜索用户后可查看其当前周期（非 VIP 按天 / VIP 按月）的对话额度使用'
          '情况，并一键重置为未使用状态。仅清零已用条数，不影响已经产生的超额'
          '扣费（钞票不退回）。',
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
              if (_selected != null) ...[
                _SelectedUserChip(item: _selected!, onClear: _clearSelected),
              ] else ...[
                _AdminGamesTextField(
                  label: '搜索用户（用户名 / ID / 微信昵称 / 手机号）',
                  controller: _queryCtrl,
                ),
                const SizedBox(height: 10),
                _UserSearchResults(
                  searching: _searching,
                  results: _results,
                  query: _queryCtrl.text.trim(),
                  onSelect: _select,
                ),
              ],
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
        if (_selected != null) ...[
          const SizedBox(height: 12),
          if (_loadingStatus)
            const Center(child: CupertinoActivityIndicator(radius: 14))
          else if (status != null)
            _AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: status.isVip
                              ? const Color(0xFFE8B54A).withValues(alpha: 0.18)
                              : AppColors.muted.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status.isVip ? 'VIP' : '非 VIP',
                          style: TextStyle(
                            color: status.isVip
                                ? const Color(0xFFC08A1E)
                                : AppColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      Text(
                        _chatQuotaModeLabels[status.mode] ?? status.mode,
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      Text(
                        '周期：${status.periodScope == 'day' ? '按天' : '按月'} '
                        '· ${status.periodKey}',
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
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 18,
                    runSpacing: 8,
                    children: [
                      _ChatQuotaStat(
                        label: '已用 / 免费额度',
                        value: '${status.used} / ${status.limit}',
                      ),
                      _ChatQuotaStat(
                        label: '剩余免费',
                        value: '${status.freeRemaining}',
                      ),
                      _ChatQuotaStat(
                        label: '超额单价',
                        value: '${status.perMsgCost} 钞票/句',
                      ),
                      _ChatQuotaStat(
                        label: '可用钞票',
                        value: '${status.spendableTickets}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _AdminGamesTextField(
                    label: '备注（可选）',
                    controller: _noteCtrl,
                  ),
                  const SizedBox(height: 12),
                  if (_confirming) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8B54A).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '确定要将 ${_selected!.displayName} 当前周期已用的 '
                            '${status.used} 条重置为 0 吗？',
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _AdminGamesPrimaryButton(
                                  label: _resetting ? '重置中…' : '确认重置',
                                  onPressed: _resetting ? null : _reset,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _AdminGamesSecondaryButton(
                                  label: '取消',
                                  onPressed: _resetting
                                      ? null
                                      : () =>
                                          setState(() => _confirming = false),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      minimumSize: Size.zero,
                      color: danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      onPressed: status.used == 0
                          ? null
                          : () => setState(() => _confirming = true),
                      child: Text(
                        '重置对话额度',
                        style: TextStyle(
                          color: danger,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _ChatQuotaStat extends StatelessWidget {
  const _ChatQuotaStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: AppColors.text,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}
