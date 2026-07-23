part of 'package:companion_flutter/main.dart';

// ---------------------------------------------------------------------------
// 霸王餐管理 (meal / free-meal campaign admin) — 1:1 port of the web
// MealWorkspace: 扫码校验管理 / 商家管理 / 数据统计.
//
// 13 endpoints under /admin-api/meal/*. All polling timers are torn down on
// dispose / tab switch / app-background so they never touch a normal user's
// battery or bandwidth (this whole surface is admin-only).
// ---------------------------------------------------------------------------

extension _AdminMealApi on CompanionApi {
  Future<_MealOverview> fetchMealOverview() async {
    final json =
        await _adminHttpRequest(this, 'GET', '/admin-api/meal/overview')
            as Map<String, dynamic>;
    return _MealOverview.fromJson(json);
  }

  Future<List<_MealActivation>> fetchMealActivations({int limit = 50}) async {
    final path = Uri(
      path: '/admin-api/meal/activations',
      queryParameters: {'limit': limit.toString()},
    ).toString();
    final json = await _adminHttpRequest(this, 'GET', path) as List;
    return json
        .whereType<Map>()
        .map((e) => _MealActivation.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<bool> setMealCodeEnabled(bool enabled) async {
    final json =
        await _adminHttpRequest(
              this,
              'PUT',
              '/admin-api/meal/code-enabled',
              body: {'enabled': enabled},
            )
            as Map<String, dynamic>;
    return _jsonBool(json['enabled']);
  }

  Future<List<_MealMerchant>> fetchMealMerchants() async {
    final json =
        await _adminHttpRequest(this, 'GET', '/admin-api/meal/merchants')
            as List;
    return json
        .whereType<Map>()
        .map((e) => _MealMerchant.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<_MealMerchant> createMealMerchant({
    required String name,
    String? contactName,
    String? contactPhone,
    bool qwycMember = false,
    bool qwycGroup = false,
  }) async {
    final json =
        await _adminHttpRequest(
              this,
              'POST',
              '/admin-api/meal/merchants',
              body: {
                'name': name,
                'contact_name': contactName,
                'contact_phone': contactPhone,
                'qwyc_member': qwycMember,
                'qwyc_group': qwycGroup,
              },
            )
            as Map<String, dynamic>;
    return _MealMerchant.fromJson(json);
  }

  Future<_MealMerchant> updateMealMerchant(
    String merchantId, {
    String? name,
    String? contactName,
    String? contactPhone,
    bool? codeActive,
    bool? qwycMember,
    bool? qwycGroup,
    bool includeContacts = false,
  }) async {
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      // Contacts are nullable-clearable, so send them (incl. null) only when
      // the caller is editing the profile form.
      if (includeContacts) 'contact_name': contactName,
      if (includeContacts) 'contact_phone': contactPhone,
      if (codeActive != null) 'code_active': codeActive,
      if (qwycMember != null) 'qwyc_member': qwycMember,
      if (qwycGroup != null) 'qwyc_group': qwycGroup,
    };
    final encoded = Uri.encodeComponent(merchantId);
    final json =
        await _adminHttpRequest(
              this,
              'PUT',
              '/admin-api/meal/merchants/$encoded',
              body: body,
            )
            as Map<String, dynamic>;
    return _MealMerchant.fromJson(json);
  }

  Future<void> deleteMealMerchant(String merchantId) async {
    final encoded = Uri.encodeComponent(merchantId);
    await _adminHttpRequest(
      this,
      'DELETE',
      '/admin-api/meal/merchants/$encoded',
    );
  }

  Future<_MealRedemptionDetail> fetchMealMerchantRedemptions(
    String merchantId, {
    int limit = 100,
  }) async {
    final encoded = Uri.encodeComponent(merchantId);
    final path = Uri(
      path: '/admin-api/meal/merchants/$encoded/redemptions',
      queryParameters: {'limit': limit.toString()},
    ).toString();
    final json =
        await _adminHttpRequest(this, 'GET', path) as Map<String, dynamic>;
    return _MealRedemptionDetail.fromJson(json);
  }

  Future<_MealRangeStats> fetchMealStats({
    required String start,
    required String end,
  }) async {
    final path = Uri(
      path: '/admin-api/meal/stats',
      queryParameters: {'start': start, 'end': end},
    ).toString();
    final json =
        await _adminHttpRequest(this, 'GET', path) as Map<String, dynamic>;
    return _MealRangeStats.fromJson(json);
  }

  Future<List<_MealExpiredRow>> fetchMealExpired({int limit = 200}) async {
    final path = Uri(
      path: '/admin-api/meal/expired',
      queryParameters: {'limit': limit.toString()},
    ).toString();
    final json = await _adminHttpRequest(this, 'GET', path) as List;
    return json
        .whereType<Map>()
        .map((e) => _MealExpiredRow.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<_MealRedemptionFailures> fetchMealRedemptionFailures({
    String? date,
    int limit = 200,
  }) async {
    final path = Uri(
      path: '/admin-api/meal/redemption-failures',
      queryParameters: {
        'limit': limit.toString(),
        if (date != null) 'date': date,
      },
    ).toString();
    final json =
        await _adminHttpRequest(this, 'GET', path) as Map<String, dynamic>;
    return _MealRedemptionFailures.fromJson(json);
  }

  Future<void> clearMealActivation(String voucherId) async {
    final encoded = Uri.encodeComponent(voucherId);
    await _adminHttpRequest(
      this,
      'DELETE',
      '/admin-api/meal/vouchers/$encoded/activation',
    );
  }

  Future<void> clearMealRedemption(String voucherId) async {
    final encoded = Uri.encodeComponent(voucherId);
    await _adminHttpRequest(
      this,
      'DELETE',
      '/admin-api/meal/vouchers/$encoded/redemption',
    );
  }
}

// ===========================================================================
// Models
// ===========================================================================

class _MealOverview {
  const _MealOverview({
    required this.enabled,
    required this.totalActivated,
    required this.totalRedeemed,
    required this.todayActivated,
    required this.todayRedeemed,
    required this.dailyRedeemCap,
    required this.totalExpired,
    required this.todayFailed,
  });

  final bool enabled;
  final int totalActivated;
  final int totalRedeemed;
  final int todayActivated;
  final int todayRedeemed;
  final int dailyRedeemCap;
  final int totalExpired;
  final int todayFailed;

  factory _MealOverview.fromJson(Map<String, dynamic> json) {
    return _MealOverview(
      enabled: _jsonBool(json['enabled']),
      totalActivated: _jsonInt(json['total_activated']),
      totalRedeemed: _jsonInt(json['total_redeemed']),
      todayActivated: _jsonInt(json['today_activated']),
      todayRedeemed: _jsonInt(json['today_redeemed']),
      dailyRedeemCap: _jsonInt(json['daily_redeem_cap']),
      totalExpired: _jsonInt(json['total_expired']),
      todayFailed: _jsonInt(json['today_failed']),
    );
  }
}

class _MealActivation {
  const _MealActivation({
    required this.voucherId,
    required this.userDisplay,
    required this.status,
    required this.activatedAt,
    required this.redeemedAt,
    required this.merchantName,
  });

  final String voucherId;
  final String userDisplay;
  final String status;
  final String? activatedAt;
  final String? redeemedAt;
  final String? merchantName;

  bool get isRedeemed => status == 'redeemed';

  factory _MealActivation.fromJson(Map<String, dynamic> json) {
    return _MealActivation(
      voucherId: _jsonString(json['voucher_id']),
      userDisplay: _jsonString(json['user_display'], fallback: '用户'),
      status: _jsonString(json['status'], fallback: 'activated'),
      activatedAt: _jsonNullableString(json['activated_at']),
      redeemedAt: _jsonNullableString(json['redeemed_at']),
      merchantName: _jsonNullableString(json['merchant_name']),
    );
  }
}

class _MealMerchant {
  const _MealMerchant({
    required this.id,
    required this.name,
    required this.contactName,
    required this.contactPhone,
    required this.codeActive,
    required this.qwycMember,
    required this.qwycGroup,
    required this.redeemedCount,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String? contactName;
  final String? contactPhone;
  final bool codeActive;
  final bool qwycMember;
  final bool qwycGroup;
  final int redeemedCount;
  final String? createdAt;

  factory _MealMerchant.fromJson(Map<String, dynamic> json) {
    return _MealMerchant(
      id: _jsonString(json['id']),
      name: _jsonString(json['name'], fallback: '未命名商家'),
      contactName: _jsonNullableString(json['contact_name']),
      contactPhone: _jsonNullableString(json['contact_phone']),
      codeActive: _jsonBool(json['code_active']),
      qwycMember: _jsonBool(json['qwyc_member']),
      qwycGroup: _jsonBool(json['qwyc_group']),
      redeemedCount: _jsonInt(json['redeemed_count']),
      createdAt: _jsonNullableString(json['created_at']),
    );
  }
}

class _MealRedemptionItem {
  const _MealRedemptionItem({
    required this.voucherId,
    required this.userId,
    required this.username,
    required this.userDisplay,
    required this.phoneMasked,
    required this.wechatNickname,
    required this.wechatAvatarUrl,
    required this.wechatOpenid,
    required this.wechatUnionid,
    required this.activatedAt,
    required this.expiresAt,
    required this.redeemedAt,
  });

  final String voucherId;
  final String userId;
  final String username;
  final String userDisplay;
  final String? phoneMasked;
  final String? wechatNickname;
  final String? wechatAvatarUrl;
  final String? wechatOpenid;
  final String? wechatUnionid;
  final String? activatedAt;
  final String? expiresAt;
  final String? redeemedAt;

  factory _MealRedemptionItem.fromJson(Map<String, dynamic> json) {
    return _MealRedemptionItem(
      voucherId: _jsonString(json['voucher_id']),
      userId: _jsonString(json['user_id']),
      username: _jsonString(json['username']),
      userDisplay: _jsonString(json['user_display'], fallback: '用户'),
      phoneMasked: _jsonNullableString(json['phone_masked']),
      wechatNickname: _jsonNullableString(json['wechat_nickname']),
      wechatAvatarUrl: _jsonNullableString(json['wechat_avatar_url']),
      wechatOpenid: _jsonNullableString(json['wechat_openid']),
      wechatUnionid: _jsonNullableString(json['wechat_unionid']),
      activatedAt: _jsonNullableString(json['activated_at']),
      expiresAt: _jsonNullableString(json['expires_at']),
      redeemedAt: _jsonNullableString(json['redeemed_at']),
    );
  }
}

class _MealRedemptionDetail {
  const _MealRedemptionDetail({
    required this.merchantName,
    required this.total,
    required this.items,
  });

  final String merchantName;
  final int total;
  final List<_MealRedemptionItem> items;

  factory _MealRedemptionDetail.fromJson(Map<String, dynamic> json) {
    return _MealRedemptionDetail(
      merchantName: _jsonString(json['merchant_name']),
      total: _jsonInt(json['total']),
      items: _jsonList(
        json['items'],
      ).map(_MealRedemptionItem.fromJson).toList(growable: false),
    );
  }
}

class _MealStatsDay {
  const _MealStatsDay({
    required this.date,
    required this.activated,
    required this.redeemed,
  });

  final String date;
  final int activated;
  final int redeemed;
}

class _MealRangeStats {
  const _MealRangeStats({
    required this.start,
    required this.end,
    required this.activatedTotal,
    required this.redeemedTotal,
    required this.days,
  });

  final String start;
  final String end;
  final int activatedTotal;
  final int redeemedTotal;
  final List<_MealStatsDay> days;

  factory _MealRangeStats.fromJson(Map<String, dynamic> json) {
    return _MealRangeStats(
      start: _jsonString(json['start']),
      end: _jsonString(json['end']),
      activatedTotal: _jsonInt(json['activated_total']),
      redeemedTotal: _jsonInt(json['redeemed_total']),
      days: _jsonList(json['days'])
          .map(
            (item) => _MealStatsDay(
              date: _jsonString(item['date']),
              activated: _jsonInt(item['activated']),
              redeemed: _jsonInt(item['redeemed']),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _MealExpiredRow {
  const _MealExpiredRow({
    required this.voucherId,
    required this.userDisplay,
    required this.activatedAt,
    required this.expiredAt,
  });

  final String voucherId;
  final String userDisplay;
  final String? activatedAt;
  final String? expiredAt;

  factory _MealExpiredRow.fromJson(Map<String, dynamic> json) {
    return _MealExpiredRow(
      voucherId: _jsonString(json['voucher_id']),
      userDisplay: _jsonString(json['user_display'], fallback: '用户'),
      activatedAt: _jsonNullableString(json['activated_at']),
      expiredAt: _jsonNullableString(json['expired_at']),
    );
  }
}

class _MealFailureItem {
  const _MealFailureItem({
    required this.userDisplay,
    required this.merchantName,
    required this.failedAt,
  });

  final String userDisplay;
  final String? merchantName;
  final String? failedAt;

  factory _MealFailureItem.fromJson(Map<String, dynamic> json) {
    return _MealFailureItem(
      userDisplay: _jsonString(json['user_display'], fallback: '用户'),
      merchantName: _jsonNullableString(json['merchant_name']),
      failedAt: _jsonNullableString(json['failed_at']),
    );
  }
}

class _MealRedemptionFailures {
  const _MealRedemptionFailures({
    required this.date,
    required this.total,
    required this.items,
  });

  final String date;
  final int total;
  final List<_MealFailureItem> items;

  factory _MealRedemptionFailures.fromJson(Map<String, dynamic> json) {
    return _MealRedemptionFailures(
      date: _jsonString(json['date']),
      total: _jsonInt(json['total']),
      items: _jsonList(
        json['items'],
      ).map(_MealFailureItem.fromJson).toList(growable: false),
    );
  }
}

// ===========================================================================
// Formatting + shared meal widgets
// ===========================================================================

String _pad2(int n) => n.toString().padLeft(2, '0');

String _mealTime(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return '—';
  final local = parsed.toLocal();
  return '${local.month}/${local.day} ${_pad2(local.hour)}:${_pad2(local.minute)}:${_pad2(local.second)}';
}

String _mealDetailTime(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return '—';
  final local = parsed.toLocal();
  return '${local.year}-${_pad2(local.month)}-${_pad2(local.day)} '
      '${_pad2(local.hour)}:${_pad2(local.minute)}:${_pad2(local.second)}';
}

String _mealLocalDate([int offsetDays = 0]) {
  final now = DateTime.now().subtract(Duration(days: offsetDays));
  return '${now.year}-${_pad2(now.month)}-${_pad2(now.day)}';
}

/// Transient top toast (mirrors the web MealWorkspace toast, 3s auto-dismiss).
void _showMealToast(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late OverlayEntry entry;
  var removed = false;
  void dismiss() {
    if (removed) return;
    removed = true;
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (ctx) {
      final media = MediaQuery.of(ctx);
      return Positioned(
        top: media.padding.top + 66,
        left: 18,
        right: 18,
        child: IgnorePointer(
          child: Center(
            child: _MealToastCard(message: message, isError: isError),
          ),
        ),
      );
    },
  );
  overlay.insert(entry);
  Timer(const Duration(seconds: 3), dismiss);
}

class _MealToastCard extends StatelessWidget {
  const _MealToastCard({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFE35B6F) : const Color(0xFF1FA97A);
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2430),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isError
                ? CupertinoIcons.exclamationmark_circle_fill
                : CupertinoIcons.checkmark_circle_fill,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MealBadge extends StatelessWidget {
  const _MealBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

/// Small circular avatar with an initial fallback (used in feeds / detail).
class _MealAvatar extends StatelessWidget {
  const _MealAvatar({required this.label, this.avatarUrl, this.size = 30});

  final String label;
  final String? avatarUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final initial = label.isEmpty ? '?' : label.characters.first;
    final fallback = Container(
      color: colors.accent.withValues(alpha: 0.16),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: colors.accent,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          decoration: TextDecoration.none,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: SizedBox(
        width: size,
        height: size,
        child: (avatarUrl == null || avatarUrl!.isEmpty)
            ? fallback
            : Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : fallback,
              ),
      ),
    );
  }
}

// ===========================================================================
// 霸王餐管理 shell — three tabs
// ===========================================================================

class _AdminMealPage extends StatefulWidget {
  const _AdminMealPage({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_AdminMealPage> createState() => _AdminMealPageState();
}

class _AdminMealPageState extends State<_AdminMealPage> {
  String _tab = 'code';

  @override
  void initState() {
    super.initState();
    widget.api.authToken = widget.session.token;
  }

  @override
  Widget build(BuildContext context) {
    // Only the active tab is mounted, so polling panels (code / stats) stop
    // their timers the moment you switch away.
    final Widget panel = switch (_tab) {
      'merchants' => _MealMerchantsPanel(
        key: const ValueKey('meal-merchants'),
        api: widget.api,
        session: widget.session,
      ),
      'stats' => _MealStatsPanel(
        key: const ValueKey('meal-stats'),
        api: widget.api,
        session: widget.session,
      ),
      _ => _MealCodePanel(
        key: const ValueKey('meal-code'),
        api: widget.api,
        session: widget.session,
      ),
    };
    return _AdminScaffold(
      title: '霸王餐管理',
      subtitle: '扫码校验 · 商家 · 数据统计',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
            child: _AdminSegment<String>(
              value: _tab,
              options: const [
                MapEntry('code', '扫码校验'),
                MapEntry('merchants', '商家'),
                MapEntry('stats', '数据统计'),
              ],
              onChanged: (value) => setState(() => _tab = value),
            ),
          ),
          Expanded(child: panel),
        ],
      ),
    );
  }
}

// ===========================================================================
// Tab A — 扫码校验管理
// ===========================================================================

class _MealCodePanel extends StatefulWidget {
  const _MealCodePanel({super.key, required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_MealCodePanel> createState() => _MealCodePanelState();
}

class _MealCodePanelState extends State<_MealCodePanel>
    with WidgetsBindingObserver {
  static const _overviewInterval = Duration(seconds: 10);
  static const _feedInterval = Duration(seconds: 5);

  _MealOverview? _overview;
  List<_MealActivation> _feed = const [];
  bool _toggling = false;
  Timer? _overviewTimer;
  Timer? _feedTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshOverview();
    _refreshFeed();
    _startTimers();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimers();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimers();
      _refreshOverview();
      _refreshFeed();
    } else {
      _stopTimers();
    }
  }

  void _startTimers() {
    _overviewTimer ??= Timer.periodic(
      _overviewInterval,
      (_) => _refreshOverview(),
    );
    _feedTimer ??= Timer.periodic(_feedInterval, (_) => _refreshFeed());
  }

  void _stopTimers() {
    _overviewTimer?.cancel();
    _overviewTimer = null;
    _feedTimer?.cancel();
    _feedTimer = null;
  }

  Future<void> _refreshOverview() async {
    try {
      widget.api.authToken = widget.session.token;
      final overview = await widget.api.fetchMealOverview();
      if (!mounted) return;
      setState(() => _overview = overview);
    } catch (_) {
      // Transient poll failure — keep last state.
    }
  }

  Future<void> _refreshFeed() async {
    try {
      widget.api.authToken = widget.session.token;
      final feed = await widget.api.fetchMealActivations(limit: 50);
      if (!mounted) return;
      setState(() => _feed = feed);
    } catch (_) {
      // Transient.
    }
  }

  Future<void> _toggle(bool enabled) async {
    setState(() => _toggling = true);
    try {
      widget.api.authToken = widget.session.token;
      await widget.api.setMealCodeEnabled(enabled);
      if (!mounted) return;
      _showMealToast(context, enabled ? '服务员扫码校验已开启' : '服务员扫码校验已关闭');
      await _refreshOverview();
    } catch (error) {
      if (!mounted) return;
      _showMealToast(context, _asMessage(error), isError: true);
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _confirmDisable() async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('关闭服务员扫码校验'),
        content: const Text('关闭后，待校验用户将无法生成服务员校验二维码。已校验 / 已核销的券不受影响。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认关闭'),
          ),
        ],
      ),
    );
    if (ok == true) _toggle(false);
  }

  Future<void> _confirmClear(_MealActivation row) async {
    final extra = row.isRedeemed ? '（其核销记录也会一并清除）' : '';
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('清除校验记录'),
        content: Text(
          '确定清除「${row.userDisplay}」的校验记录？该用户的券将回到「待校验」状态$extra，之后可由服务员重新扫码校验。',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认清除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      widget.api.authToken = widget.session.token;
      await widget.api.clearMealActivation(row.voucherId);
      if (!mounted) return;
      _showMealToast(context, '已清除「${row.userDisplay}」的校验记录');
      await _refreshFeed();
    } catch (error) {
      if (!mounted) return;
      _showMealToast(context, _asMessage(error), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final overview = _overview;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 40),
      children: [
        _AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const _MealSectionLabel('服务员扫码校验'),
                  const SizedBox(width: 8),
                  if (overview == null)
                    const _MealBadge(text: '…', color: Color(0xFF7D8790))
                  else
                    _MealBadge(
                      text: overview.enabled ? '生效中' : '已关闭',
                      color: overview.enabled
                          ? const Color(0xFF1FA97A)
                          : const Color(0xFFE35B6F),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (overview == null)
                const _AdminInlineHint(text: '加载中…', height: 60)
              else ...[
                Text(
                  overview.enabled ? '扫码校验已开启' : '服务员扫码校验已关闭',
                  style: TextStyle(
                    color: overview.enabled
                        ? const Color(0xFF1FA97A)
                        : AppColors.of(context).muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  overview.enabled
                      ? '用户「我的」页展示动态校验二维码；服务员登录专用 H5 后扫码，券即更新为已校验，并自动切换为商家核销二维码。'
                      : '待校验用户暂时无法生成校验二维码；已校验 / 已核销的券不受影响。',
                  style: TextStyle(
                    color: AppColors.isDark(context)
                        ? const Color(0x9EEBF2EE)
                        : AppColors.muted,
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 14),
                _AdminRoleActionButton(
                  color: overview.enabled
                      ? AppColors.of(context).danger
                      : const Color(0xFF1FA97A),
                  icon: overview.enabled
                      ? CupertinoIcons.pause_circle_fill
                      : CupertinoIcons.checkmark_seal_fill,
                  label: overview.enabled ? '关闭扫码校验' : '开启扫码校验',
                  loading: _toggling,
                  onTap: () =>
                      overview.enabled ? _confirmDisable() : _toggle(true),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const _MealSectionLabel('实时校验动态'),
                  const Spacer(),
                  _AppNavCircleButton(
                    icon: CupertinoIcons.refresh,
                    onPressed: () {
                      _refreshFeed();
                      _refreshOverview();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '最近 ${_feed.length} 条 · 每 5 秒自动刷新',
                style: TextStyle(
                  color: AppColors.isDark(context)
                      ? const Color(0x9EEBF2EE)
                      : AppColors.muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 12),
              if (_feed.isEmpty)
                const _AdminInlineHint(
                  text: '暂无校验记录，服务员扫码成功后会实时出现在这里',
                  height: 90,
                )
              else
                for (final row in _feed) _buildFeedRow(row),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeedRow(_MealActivation row) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          _MealAvatar(label: row.userDisplay),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        row.userDisplay,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark
                              ? AppColors.text
                              : const Color(0xFF12171B),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _MealBadge(
                      text: row.isRedeemed ? '已核销' : '已校验',
                      color: row.isRedeemed
                          ? const Color(0xFF2D73FF)
                          : const Color(0xFF1FA97A),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_mealTime(row.activatedAt)}'
                  '${row.merchantName != null ? ' · ${row.merchantName}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(40, 40),
            onPressed: row.voucherId.isEmpty ? null : () => _confirmClear(row),
            child: Icon(
              CupertinoIcons.trash,
              size: 18,
              color: AppColors.of(
                context,
              ).danger.withValues(alpha: row.voucherId.isEmpty ? 0.35 : 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _MealSectionLabel extends StatelessWidget {
  const _MealSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        color: isDark ? AppColors.text : const Color(0xFF12171B),
        fontSize: 14.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        decoration: TextDecoration.none,
      ),
    );
  }
}

// ===========================================================================
// Tab B — 商家管理
// ===========================================================================

class _MealMerchantsPanel extends StatefulWidget {
  const _MealMerchantsPanel({
    super.key,
    required this.api,
    required this.session,
  });

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_MealMerchantsPanel> createState() => _MealMerchantsPanelState();
}

class _MealMerchantsPanelState extends State<_MealMerchantsPanel> {
  bool _loading = true;
  String? _error;
  List<_MealMerchant> _merchants = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      widget.api.authToken = widget.session.token;
      final merchants = await widget.api.fetchMealMerchants();
      if (!mounted) return;
      setState(() {
        _merchants = merchants;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _asMessage(error);
        _loading = false;
      });
      _showMealToast(context, _asMessage(error), isError: true);
    }
  }

  int get _totalRedeemed =>
      _merchants.fold<int>(0, (sum, m) => sum + m.redeemedCount);

  Future<void> _openEditor({_MealMerchant? merchant}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MealMerchantEditorSheet(
        api: widget.api,
        session: widget.session,
        merchant: merchant,
      ),
    );
    if (saved == true && mounted) {
      _showMealToast(context, merchant == null ? '商家已创建' : '商家信息已更新');
      _refresh();
    }
  }

  Future<void> _toggleRedemption(_MealMerchant merchant) async {
    try {
      widget.api.authToken = widget.session.token;
      await widget.api.updateMealMerchant(
        merchant.id,
        codeActive: !merchant.codeActive,
      );
      if (!mounted) return;
      _showMealToast(
        context,
        merchant.codeActive
            ? '已停用「${merchant.name}」扫码核销'
            : '已开启「${merchant.name}」扫码核销',
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      _showMealToast(context, _asMessage(error), isError: true);
    }
  }

  Future<void> _confirmDelete(_MealMerchant merchant) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('删除商家'),
        content: Text(
          '确定删除商家「${merchant.name}」？其核销码将立即失效；已核销的 ${merchant.redeemedCount} 条记录会保留但不再关联该商家。',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      widget.api.authToken = widget.session.token;
      await widget.api.deleteMealMerchant(merchant.id);
      if (!mounted) return;
      _showMealToast(context, '商家「${merchant.name}」已删除');
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      _showMealToast(context, _asMessage(error), isError: true);
    }
  }

  Future<void> _openActions(_MealMerchant merchant) async {
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(merchant.name),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop('detail'),
            child: const Text('核销详情'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop('edit'),
            child: const Text('编辑'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop('toggle'),
            child: Text(merchant.codeActive ? '停用扫码核销' : '开启扫码核销'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop('delete'),
            child: const Text('删除商家'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'detail':
        _openDetail(merchant);
      case 'edit':
        _openEditor(merchant: merchant);
      case 'toggle':
        _toggleRedemption(merchant);
      case 'delete':
        _confirmDelete(merchant);
    }
  }

  Future<void> _openDetail(_MealMerchant merchant) async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => _MealRedemptionDetailPage(
          api: widget.api,
          session: widget.session,
          merchant: merchant,
        ),
      ),
    );
    // A cleared redemption changes the merchant's redeemed_count — refresh.
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 40),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _loading
                    ? '商家列表'
                    : '共 ${_merchants.length} 家 · 累计核销 $_totalRedeemed 张',
                style: TextStyle(
                  color: AppColors.isDark(context)
                      ? AppColors.text
                      : const Color(0xFF12171B),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            _AppNavCircleButton(
              icon: CupertinoIcons.refresh,
              onPressed: _refresh,
            ),
            const SizedBox(width: 8),
            _AppNavCircleButton(
              icon: CupertinoIcons.add,
              onPressed: () => _openEditor(),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_loading && _merchants.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CupertinoActivityIndicator(radius: 14)),
          )
        else if (_error != null && _merchants.isEmpty)
          _AdminStatePanel(
            title: '加载失败',
            message: _error!,
            actionText: '重试',
            onTap: _refresh,
          )
        else if (_merchants.isEmpty)
          const _AdminStatePanel(title: '暂无商家', message: '点击右上角「+」创建第一个商家。')
        else
          for (final merchant in _merchants) ...[
            _buildMerchantCard(merchant),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _buildMerchantCard(_MealMerchant merchant) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _AdminCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      merchant.name,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.text
                            : const Color(0xFF12171B),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    if (merchant.qwycGroup)
                      const _MealBadge(
                        text: '千味央厨总账号',
                        color: Color(0xFF2D73FF),
                      ),
                    if (merchant.qwycMember)
                      const _MealBadge(text: '千味央厨', color: Color(0xFFD4A843)),
                  ],
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(36, 36),
                onPressed: () => _openActions(merchant),
                child: Icon(
                  CupertinoIcons.ellipsis,
                  size: 20,
                  color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _MealBadge(
                text: merchant.codeActive ? '启用中' : '已停用',
                color: merchant.codeActive
                    ? const Color(0xFF1FA97A)
                    : const Color(0xFFE35B6F),
              ),
              const SizedBox(width: 8),
              Text(
                '已核销 ${merchant.redeemedCount} 张',
                style: TextStyle(
                  color: isDark ? AppColors.text : const Color(0xFF12171B),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
          if (merchant.contactName != null ||
              merchant.contactPhone != null) ...[
            const SizedBox(height: 8),
            Text(
              [
                if (merchant.contactName != null) '联系人 ${merchant.contactName}',
                if (merchant.contactPhone != null) merchant.contactPhone!,
              ].join(' · '),
              style: TextStyle(
                color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _MealOutlineButton(
            icon: CupertinoIcons.doc_text_search,
            label: '核销详情',
            onTap: () => _openDetail(merchant),
          ),
        ],
      ),
    );
  }
}

/// Outlined secondary button used inside meal cards.
class _MealOutlineButton extends StatelessWidget {
  const _MealOutlineButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.accent.withValues(alpha: 0.24)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: colors.accent),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: colors.accent,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Merchant create / edit bottom sheet
// ---------------------------------------------------------------------------

class _MealMerchantEditorSheet extends StatefulWidget {
  const _MealMerchantEditorSheet({
    required this.api,
    required this.session,
    this.merchant,
  });

  final CompanionApi api;
  final AuthSession session;
  final _MealMerchant? merchant;

  @override
  State<_MealMerchantEditorSheet> createState() =>
      _MealMerchantEditorSheetState();
}

class _MealMerchantEditorSheetState extends State<_MealMerchantEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _contactName;
  late final TextEditingController _contactPhone;
  late bool _qwycMember;
  late bool _qwycGroup;
  bool _saving = false;

  bool get _isNew => widget.merchant == null;

  @override
  void initState() {
    super.initState();
    final m = widget.merchant;
    _name = TextEditingController(text: m?.name ?? '');
    _contactName = TextEditingController(text: m?.contactName ?? '');
    _contactPhone = TextEditingController(text: m?.contactPhone ?? '');
    _qwycMember = m?.qwycMember ?? false;
    _qwycGroup = m?.qwycGroup ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _contactName.dispose();
    _contactPhone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      _showMealToast(context, '商家名称不能为空', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      widget.api.authToken = widget.session.token;
      final contactName = _contactName.text.trim();
      final contactPhone = _contactPhone.text.trim();
      if (_isNew) {
        await widget.api.createMealMerchant(
          name: name,
          contactName: contactName.isEmpty ? null : contactName,
          contactPhone: contactPhone.isEmpty ? null : contactPhone,
          qwycMember: _qwycMember,
          qwycGroup: _qwycGroup,
        );
      } else {
        await widget.api.updateMealMerchant(
          widget.merchant!.id,
          name: name,
          contactName: contactName.isEmpty ? null : contactName,
          contactPhone: contactPhone.isEmpty ? null : contactPhone,
          qwycMember: _qwycMember,
          qwycGroup: _qwycGroup,
          includeContacts: true,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMealToast(context, _asMessage(error), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141C26) : const Color(0xFFF7FAFC),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.18)
                          : const Color(0x22181F2A),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isNew ? '新增商家' : '编辑商家',
                  style: TextStyle(
                    color: isDark ? AppColors.text : const Color(0xFF12171B),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 16),
                _MealField(
                  label: '商家名称 *',
                  controller: _name,
                  placeholder: '如：张记食堂',
                ),
                const SizedBox(height: 12),
                _MealField(
                  label: '联系人姓名（与手机号二选一，可留空）',
                  controller: _contactName,
                  placeholder: '如：王老板',
                ),
                const SizedBox(height: 12),
                _MealField(
                  label: '联系人手机号（与姓名二选一，可留空）',
                  controller: _contactPhone,
                  placeholder: '如：13812345678',
                  keyboardType: TextInputType.phone,
                  digitsPhoneOnly: true,
                ),
                const SizedBox(height: 16),
                _MealSwitchRow(
                  title: '属于「千味央厨」商家',
                  subtitle: '勾选后计入千味央厨汇总的成员门店',
                  value: _qwycMember,
                  onChanged: (v) => setState(() => _qwycMember = v),
                ),
                const SizedBox(height: 8),
                _MealSwitchRow(
                  title: '这是「千味央厨」总账号',
                  subtitle: '该账号登录 H5 后查看各成员门店核销汇总，不扫码核销',
                  value: _qwycGroup,
                  onChanged: (v) => setState(() => _qwycGroup = v),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0x0F181F2A),
                        borderRadius: BorderRadius.circular(14),
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: Text(
                          '取消',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.text
                                : const Color(0xFF12171B),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AdminRoleActionButton(
                        color: AppColors.of(context).accent,
                        icon: CupertinoIcons.checkmark_alt,
                        label: '保存',
                        loading: _saving,
                        onTap: _save,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MealField extends StatelessWidget {
  const _MealField({
    required this.label,
    required this.controller,
    required this.placeholder,
    this.keyboardType,
    this.digitsPhoneOnly = false,
  });

  final String label;
  final TextEditingController controller;
  final String placeholder;
  final TextInputType? keyboardType;
  final bool digitsPhoneOnly;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 6),
        CupertinoTextField(
          controller: controller,
          placeholder: placeholder,
          keyboardType: keyboardType,
          inputFormatters: digitsPhoneOnly
              ? [FilteringTextInputFormatter.allow(RegExp(r'[\d\s-]'))]
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          style: TextStyle(
            color: isDark ? AppColors.text : const Color(0xFF12171B),
            fontSize: 14.5,
          ),
          placeholderStyle: TextStyle(
            color: isDark ? const Color(0x66EBF2EE) : const Color(0x66181F2A),
            fontSize: 14.5,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : const Color(0x14181F2A),
            ),
          ),
        ),
      ],
    );
  }
}

class _MealSwitchRow extends StatelessWidget {
  const _MealSwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0x14181F2A),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? AppColors.text : const Color(0xFF12171B),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
                    fontSize: 11.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          CupertinoSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Merchant redemption detail page
// ---------------------------------------------------------------------------

class _MealRedemptionDetailPage extends StatefulWidget {
  const _MealRedemptionDetailPage({
    required this.api,
    required this.session,
    required this.merchant,
  });

  final CompanionApi api;
  final AuthSession session;
  final _MealMerchant merchant;

  @override
  State<_MealRedemptionDetailPage> createState() =>
      _MealRedemptionDetailPageState();
}

class _MealRedemptionDetailPageState extends State<_MealRedemptionDetailPage> {
  bool _loading = true;
  String? _error;
  _MealRedemptionDetail? _detail;

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
      final detail = await widget.api.fetchMealMerchantRedemptions(
        widget.merchant.id,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
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

  Future<void> _confirmClear(_MealRedemptionItem item) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('清除核销记录'),
        content: Text(
          '确定清除「${item.userDisplay}」在「${widget.merchant.name}」的核销记录？该用户的券将回到「已校验」状态，可重新在任意商家核销。',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认清除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      widget.api.authToken = widget.session.token;
      await widget.api.clearMealRedemption(item.voucherId);
      if (!mounted) return;
      _showMealToast(context, '已清除「${item.userDisplay}」的核销记录，其券已回到已校验状态');
      await _load();
    } catch (error) {
      if (!mounted) return;
      _showMealToast(context, _asMessage(error), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return _AdminScaffold(
      title: '核销详情',
      subtitle: widget.merchant.name,
      trailing: _loading
          ? const Padding(
              padding: EdgeInsets.only(right: 4),
              child: CupertinoActivityIndicator(radius: 10),
            )
          : _AppNavCircleButton(icon: CupertinoIcons.refresh, onPressed: _load),
      child: _buildBody(detail),
    );
  }

  Widget _buildBody(_MealRedemptionDetail? detail) {
    if (_loading && detail == null) {
      return const Center(child: CupertinoActivityIndicator(radius: 14));
    }
    if (_error != null && detail == null) {
      return _AdminStatePanel(
        title: '加载失败',
        message: _error!,
        actionText: '重试',
        onTap: _load,
      );
    }
    if (detail == null || detail.items.isEmpty) {
      return const _AdminStatePanel(title: '暂无核销记录', message: '该商家还没有任何核销记录。');
    }
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 40),
      children: [
        _AdminCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                '累计核销 ${detail.total} 张',
                style: TextStyle(
                  color: AppColors.isDark(context)
                      ? AppColors.text
                      : const Color(0xFF12171B),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                  decoration: TextDecoration.none,
                ),
              ),
              const Spacer(),
              if (detail.total > detail.items.length)
                Text(
                  '仅展示最近 ${detail.items.length} 条',
                  style: TextStyle(
                    color: AppColors.isDark(context)
                        ? const Color(0x9EEBF2EE)
                        : AppColors.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < detail.items.length; i++) ...[
          _buildItemCard(detail.items[i], i + 1),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildItemCard(_MealRedemptionItem item, int rank) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _AdminCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MealAvatar(
                label: item.userDisplay,
                avatarUrl: item.wechatAvatarUrl,
                size: 40,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.userDisplay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.text
                            : const Color(0xFF12171B),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '账号 ${item.username.isEmpty ? '—' : item.username} · 手机 ${item.phoneMasked ?? '未绑定'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark
                            ? const Color(0x9EEBF2EE)
                            : AppColors.muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(36, 36),
                onPressed: item.voucherId.isEmpty
                    ? null
                    : () => _confirmClear(item),
                child: Icon(
                  CupertinoIcons.trash,
                  size: 18,
                  color: AppColors.of(
                    context,
                  ).danger.withValues(alpha: item.voucherId.isEmpty ? 0.35 : 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MealKvLine(label: '用户 ID', value: item.userId),
          _MealKvLine(label: '券 ID', value: item.voucherId),
          if (item.wechatNickname != null)
            _MealKvLine(label: '微信昵称', value: item.wechatNickname!),
          _MealKvLine(label: 'OpenID', value: item.wechatOpenid ?? '未绑定'),
          _MealKvLine(label: 'UnionID', value: item.wechatUnionid ?? '未绑定'),
          _MealKvLine(label: '服务员校验', value: _mealDetailTime(item.activatedAt)),
          _MealKvLine(
            label: '商家核销',
            value: _mealDetailTime(item.redeemedAt),
            valueColor: const Color(0xFF1FA97A),
          ),
        ],
      ),
    );
  }
}

class _MealKvLine extends StatelessWidget {
  const _MealKvLine({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color:
                    valueColor ??
                    (isDark ? AppColors.text : const Color(0xFF12171B)),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Tab C — 数据统计
// ===========================================================================

class _MealStatsPanel extends StatefulWidget {
  const _MealStatsPanel({super.key, required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_MealStatsPanel> createState() => _MealStatsPanelState();
}

class _MealStatsPanelState extends State<_MealStatsPanel>
    with WidgetsBindingObserver {
  static const _refreshInterval = Duration(seconds: 10);

  // mode: either a single day (_dayMode=true, _day set) or trailing N days.
  bool _dayMode = true;
  String _day = _mealLocalDate();
  int _rangeDays = 7;
  final TextEditingController _customN = TextEditingController();

  bool _loading = false;
  _MealRangeStats? _stats;
  _MealOverview? _overview;
  List<_MealExpiredRow>? _expired;
  _MealRedemptionFailures? _failures;
  Timer? _timer;
  int _loadSeq = 0;

  // _rangeDays == 0 means 「全部」. The /stats endpoint caps spans at < 366
  // days, so 全部 uses the widest allowed window (365 days back). The meal
  // campaign is well under a year old, so this covers all data; leading
  // all-zero days are trimmed from the daily table below.
  static const int _allWindowDays = 365;

  bool get _isAllMode => !_dayMode && _rangeDays == 0;

  ({String start, String end}) get _range {
    if (_dayMode) return (start: _day, end: _day);
    if (_rangeDays == 0) {
      return (start: _mealLocalDate(_allWindowDays), end: _mealLocalDate());
    }
    return (start: _mealLocalDate(_rangeDays - 1), end: _mealLocalDate());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _loadExtras();
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _customN.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      _load(silent: true);
      _loadExtras();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _startTimer() {
    _timer ??= Timer.periodic(_refreshInterval, (_) {
      _load(silent: true);
      _loadExtras();
    });
  }

  Future<void> _load({bool silent = false}) async {
    final seq = ++_loadSeq;
    if (!silent) setState(() => _loading = true);
    final range = _range;
    try {
      widget.api.authToken = widget.session.token;
      final results = await Future.wait([
        widget.api.fetchMealStats(start: range.start, end: range.end),
        widget.api.fetchMealOverview(),
      ]);
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _stats = results[0] as _MealRangeStats;
        _overview = results[1] as _MealOverview;
        if (!silent) _loading = false;
      });
    } catch (error) {
      if (!mounted || seq != _loadSeq) return;
      if (!silent) {
        setState(() => _loading = false);
        _showMealToast(context, _asMessage(error), isError: true);
      }
    }
  }

  Future<void> _loadExtras() async {
    final range = _range;
    try {
      widget.api.authToken = widget.session.token;
      final results = await Future.wait([
        widget.api.fetchMealExpired(),
        widget.api.fetchMealRedemptionFailures(date: range.end),
      ]);
      if (!mounted) return;
      setState(() {
        _expired = results[0] as List<_MealExpiredRow>;
        _failures = results[1] as _MealRedemptionFailures;
      });
    } catch (_) {
      // Soft-fail: keep last data (deploy-skew tolerant).
    }
  }

  void _selectDay(String date) {
    setState(() {
      _dayMode = true;
      _day = date;
    });
    _load();
    _loadExtras();
  }

  void _selectRange(int n) {
    setState(() {
      _dayMode = false;
      _rangeDays = n;
    });
    _load();
    _loadExtras();
  }

  void _applyCustom() {
    final n = int.tryParse(_customN.text.trim());
    if (n == null || n < 1 || n > 365) {
      _showMealToast(context, '自定义天数请输入 1-365', isError: true);
      return;
    }
    _selectRange(n);
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    var picked =
        DateTime.tryParse('${_dayMode ? _day : _mealLocalDate()}T00:00:00') ??
        now;
    if (picked.isAfter(now)) picked = now;
    final result = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (ctx) {
        var temp = picked;
        return Container(
          height: 300,
          color: AppColors.isDark(ctx)
              ? const Color(0xFF141C26)
              : const Color(0xFFF7FAFC),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('取消'),
                    ),
                    CupertinoButton(
                      onPressed: () => Navigator.of(ctx).pop(temp),
                      child: const Text('确定'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: picked,
                  maximumDate: now,
                  onDateTimeChanged: (value) => temp = value,
                ),
              ),
            ],
          ),
        );
      },
    );
    if (result != null) {
      _selectDay('${result.year}-${_pad2(result.month)}-${_pad2(result.day)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = _range;
    final rangeLabel = _isAllMode
        ? '全部'
        : (range.start == range.end
              ? range.start
              : '${range.start} ~ ${range.end}');
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 40),
      children: [
        _buildRangeBar(),
        const SizedBox(height: 12),
        _buildSummary(rangeLabel),
        const SizedBox(height: 12),
        _buildDailyTable(),
        const SizedBox(height: 12),
        _buildExpired(),
        const SizedBox(height: 12),
        _buildFailures(range.end),
      ],
    );
  }

  Widget _buildRangeBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '按日查看',
                style: TextStyle(
                  color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _pickDay,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _dayMode
                            ? AppColors.of(
                                context,
                              ).accent.withValues(alpha: 0.5)
                            : (isDark
                                  ? Colors.white.withValues(alpha: 0.10)
                                  : const Color(0x14181F2A)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.calendar,
                          size: 16,
                          color: isDark
                              ? const Color(0x9EEBF2EE)
                              : AppColors.muted,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _dayMode ? _day : '选择日期',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.text
                                : const Color(0xFF12171B),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final entry in const [
                MapEntry(3, '近3天'),
                MapEntry(7, '近7天'),
                MapEntry(30, '近30天'),
                MapEntry(0, '全部'),
              ]) ...[
                Expanded(
                  child: _MealRangeChip(
                    label: entry.value,
                    selected: !_dayMode && _rangeDays == entry.key,
                    onTap: () => _selectRange(entry.key),
                  ),
                ),
                if (entry.key != 0) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: _customN,
                  placeholder: '自定义天数',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onSubmitted: (_) => _applyCustom(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  style: TextStyle(
                    color: isDark ? AppColors.text : const Color(0xFF12171B),
                    fontSize: 14,
                  ),
                  placeholderStyle: TextStyle(
                    color: isDark
                        ? const Color(0x66EBF2EE)
                        : const Color(0x66181F2A),
                    fontSize: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : const Color(0x14181F2A),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                color: AppColors.of(context).accent,
                borderRadius: BorderRadius.circular(12),
                onPressed: _applyCustom,
                child: const Text(
                  '应用',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(String rangeLabel) {
    final stats = _stats;
    final overview = _overview;
    return _AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _MealSectionLabel('统计范围：$rangeLabel')),
              if (_loading)
                const CupertinoActivityIndicator(radius: 9)
              else
                _AppNavCircleButton(
                  icon: CupertinoIcons.refresh,
                  onPressed: () {
                    _load();
                    _loadExtras();
                  },
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '「校验」= 服务员扫码成功；「核销」= 商家扫码完成（按 UTC+8 自然日）',
            style: TextStyle(
              color: AppColors.isDark(context)
                  ? const Color(0x9EEBF2EE)
                  : AppColors.muted,
              fontSize: 11,
              height: 1.4,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 12),
          _AdminStatGrid(
            tiles: [
              _AdminStatTile(
                label: '校验数',
                value: stats == null ? '—' : _fmtFull(stats.activatedTotal),
                accent: true,
              ),
              _AdminStatTile(
                label: '核销数',
                value: stats == null ? '—' : _fmtFull(stats.redeemedTotal),
              ),
            ],
          ),
          if (overview != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.isDark(context)
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0x0A181F2A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '今日核销量 ${overview.todayRedeemed} / ${overview.dailyRedeemCap} 份（先到先得，超出后用户核销会被拒）',
                style: TextStyle(
                  color: AppColors.isDark(context)
                      ? const Color(0x9EEBF2EE)
                      : AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          _AdminStatGrid(
            tiles: [
              _AdminStatTile(
                label: '已过期券（累计）',
                value: overview == null ? '—' : _fmtFull(overview.totalExpired),
              ),
              _AdminStatTile(
                label: '核销失败（${_failures?.date ?? _range.end}）',
                value: _failures == null ? '—' : _fmtFull(_failures!.total),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTable() {
    final stats = _stats;
    // In 全部 mode the window is a full year — drop the leading all-zero days
    // so the table starts at the first day with activity.
    List<_MealStatsDay> days = stats?.days ?? const [];
    if (_isAllMode && days.isNotEmpty) {
      final firstIdx = days.indexWhere(
        (d) => d.activated > 0 || d.redeemed > 0,
      );
      days = firstIdx == -1 ? const [] : days.sublist(firstIdx);
    }
    return _AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _MealSectionLabel('按日明细'),
          const SizedBox(height: 12),
          if (stats == null)
            const _AdminInlineHint(text: '加载中…', height: 60)
          else if (days.isEmpty)
            const _AdminInlineHint(text: '暂无数据', height: 60)
          else ...[
            _mealTableHeader(const ['日期', '激活数', '核销数']),
            for (final day in days.reversed)
              _mealTableRow([day.date, '${day.activated}', '${day.redeemed}']),
          ],
        ],
      ),
    );
  }

  Widget _buildExpired() {
    final expired = _expired;
    return _AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _MealSectionLabel('已过期券'),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '校验后未在有效期内核销 · 共 ${expired?.length ?? 0} 张',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.isDark(context)
                        ? const Color(0x9EEBF2EE)
                        : AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (expired == null)
            const _AdminInlineHint(text: '加载中…', height: 60)
          else if (expired.isEmpty)
            const _AdminInlineHint(text: '暂无过期券（活动开启满有效期后才会出现）', height: 60)
          else ...[
            _mealTableHeader(const ['#', '用户', '激活时间', '过期时间']),
            for (var i = 0; i < expired.length; i++)
              _mealTableRow(
                [
                  '${i + 1}',
                  expired[i].userDisplay,
                  _mealTime(expired[i].activatedAt),
                  _mealTime(expired[i].expiredAt),
                ],
                flex: const [1, 3, 3, 3],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildFailures(String fallbackDate) {
    final failures = _failures;
    return _AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _MealSectionLabel('核销失败'),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${failures?.date ?? fallbackDate} 因当日已抢完被拒 · 共 ${failures?.total ?? 0} 人',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.isDark(context)
                        ? const Color(0x9EEBF2EE)
                        : AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (failures == null)
            const _AdminInlineHint(text: '加载中…', height: 60)
          else if (failures.items.isEmpty)
            const _AdminInlineHint(text: '当日暂无核销失败记录', height: 60)
          else ...[
            _mealTableHeader(const ['#', '用户', '尝试商家', '失败时间']),
            for (var i = 0; i < failures.items.length; i++)
              _mealTableRow(
                [
                  '${i + 1}',
                  failures.items[i].userDisplay,
                  failures.items[i].merchantName ?? '—',
                  _mealTime(failures.items[i].failedAt),
                ],
                flex: const [1, 3, 3, 3],
              ),
          ],
        ],
      ),
    );
  }

  Widget _mealTableHeader(List<String> cols, {List<int>? flex}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final flexes = flex ?? List<int>.filled(cols.length, 1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          for (var i = 0; i < cols.length; i++)
            Expanded(
              flex: flexes[i],
              child: Text(
                cols[i],
                style: TextStyle(
                  color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _mealTableRow(List<String> cells, {List<int>? flex}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final flexes = flex ?? List<int>.filled(cells.length, 1);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: flexes[i],
              child: Text(
                cells[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? AppColors.text : const Color(0xFF12171B),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MealRangeChip extends StatelessWidget {
  const _MealRangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? colors.accent
              : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.9)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? colors.accent
                : (isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : const Color(0x14181F2A)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.white
                : (isDark ? const Color(0xB0EBF2EE) : AppColors.muted),
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
