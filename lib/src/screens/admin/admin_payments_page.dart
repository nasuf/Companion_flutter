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

  // quota 没有"管理/流水"两种视图。
  bool get _resourceHasViews => _resource != _PaymentResource.quota;

  int get _stackIndex {
    if (_resource == _PaymentResource.quota) {
      // quota 追加在 ticket/point/vip 的 6 个 (3×2) 视图之后，下标固定为 6。
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
