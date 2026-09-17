part of 'package:companion_flutter/main.dart';

const _vipActivationPageSize = 20;

const _vipActivationRedeemErrorLabels = {
  'invalid_code': '激活码无效',
  'code_disabled': '激活码已停用',
  'code_expired': '激活码已过期',
  'code_exhausted': '激活码已被兑完',
  'already_redeemed': '你已兑换过此激活码',
};

String _vipActivationErrorText(Object error) {
  if (error is ApiException) {
    return _vipActivationRedeemErrorLabels[error.message] ?? error.message;
  }
  return _asMessage(error);
}

String _formatVipActivationCodeDisplay(String code) {
  final cleaned = code.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  if (cleaned.length == 8) {
    return '${cleaned.substring(0, 4)}-${cleaned.substring(4)}';
  }
  if (cleaned.startsWith('VIP') && cleaned.length == 11) {
    final body = cleaned.substring(3);
    return 'VIP-${body.substring(0, 4)}-${body.substring(4)}';
  }
  return code;
}

String _vipActivationRedemptionLimitLabel(_AdminVipCodeItem item) {
  if (item.maxRedemptions == null) return '无限次';
  if (item.maxRedemptions == 1) return '一次性';
  return '最多 ${item.maxRedemptions} 次';
}

extension _AdminVipActivationApi on CompanionApi {
  Future<_AdminVipCodeListResponse> fetchVipActivationCodes({
    String? q,
    bool? enabled,
    int limit = _vipActivationPageSize,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
    };
    if (q != null && q.trim().isNotEmpty) params['q'] = q.trim();
    if (enabled != null) params['enabled'] = enabled.toString();
    final path = Uri(
      path: '/admin-api/vip-activation/codes',
      queryParameters: params,
    ).toString();
    final json =
        await _adminHttpRequest(this, 'GET', path) as Map<String, dynamic>;
    return _AdminVipCodeListResponse.fromJson(json);
  }

  Future<List<_AdminVipCodeItem>> createVipActivationCodes({
    required int durationDays,
    int count = 1,
    int? maxRedemptions,
    bool unlimitedRedemptions = false,
    String? note,
  }) async {
    final json =
        await _adminHttpRequest(
              this,
              'POST',
              '/admin-api/vip-activation/codes',
              body: {
                'duration_days': durationDays,
                'count': count,
                if (!unlimitedRedemptions) 'max_redemptions': maxRedemptions ?? 1,
                'unlimited_redemptions': unlimitedRedemptions,
                if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
              },
            )
            as List<dynamic>;
    return json
        .map((e) => _AdminVipCodeItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<_AdminVipCodeItem> patchVipActivationCode({
    required String codeId,
    required bool enabled,
  }) async {
    final json =
        await _adminHttpRequest(
              this,
              'PATCH',
              '/admin-api/vip-activation/codes/$codeId',
              body: {'enabled': enabled},
            )
            as Map<String, dynamic>;
    return _AdminVipCodeItem.fromJson(json);
  }

  Future<_AdminVipRedemptionListResponse> fetchVipActivationRedemptions({
    String? userId,
    String? codeQ,
    String? status,
    int limit = _vipActivationPageSize,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
    };
    if (userId != null && userId.trim().isNotEmpty) {
      params['user_id'] = userId.trim();
    }
    if (codeQ != null && codeQ.trim().isNotEmpty) params['code_q'] = codeQ.trim();
    if (status != null && status.trim().isNotEmpty) params['status'] = status.trim();
    final path = Uri(
      path: '/admin-api/vip-activation/redemptions',
      queryParameters: params,
    ).toString();
    final json =
        await _adminHttpRequest(this, 'GET', path) as Map<String, dynamic>;
    return _AdminVipRedemptionListResponse.fromJson(json);
  }

  Future<void> revokeVipActivationRedemption(String redemptionId) async {
    await _adminHttpRequest(
      this,
      'POST',
      '/admin-api/vip-activation/redemptions/$redemptionId/revoke',
    );
  }
}

class _AdminVipCodeItem {
  const _AdminVipCodeItem({
    required this.id,
    required this.code,
    required this.durationDays,
    required this.maxRedemptions,
    required this.redemptionCount,
    required this.enabled,
    this.note,
  });

  final String id;
  final String code;
  final int durationDays;
  final int? maxRedemptions;
  final int redemptionCount;
  final bool enabled;
  final String? note;

  factory _AdminVipCodeItem.fromJson(Map<String, dynamic> json) {
    return _AdminVipCodeItem(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      durationDays: (json['duration_days'] as num?)?.round() ?? 0,
      maxRedemptions: json['max_redemptions'] == null
          ? null
          : (json['max_redemptions'] as num).round(),
      redemptionCount: (json['redemption_count'] as num?)?.round() ?? 0,
      enabled: json['enabled'] == true,
      note: json['note']?.toString(),
    );
  }
}

class _AdminVipCodeListResponse {
  const _AdminVipCodeListResponse({required this.items, required this.total});

  final List<_AdminVipCodeItem> items;
  final int total;

  factory _AdminVipCodeListResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    return _AdminVipCodeListResponse(
      items: raw
          .map((e) => _AdminVipCodeItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num?)?.round() ?? raw.length,
    );
  }
}

class _AdminVipRedemptionItem {
  const _AdminVipRedemptionItem({
    required this.id,
    required this.userId,
    required this.userDisplayName,
    required this.codePreview,
    required this.durationDays,
    required this.status,
    this.redeemedAt,
  });

  final String id;
  final String userId;
  final String? userDisplayName;
  final String codePreview;
  final int durationDays;
  final String status;
  final String? redeemedAt;

  factory _AdminVipRedemptionItem.fromJson(Map<String, dynamic> json) {
    return _AdminVipRedemptionItem(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userDisplayName: json['user_display_name']?.toString(),
      codePreview: json['code_preview']?.toString() ?? json['code']?.toString() ?? '',
      durationDays: (json['duration_days'] as num?)?.round() ?? 0,
      status: json['status']?.toString() ?? '',
      redeemedAt: json['redeemed_at']?.toString(),
    );
  }
}

class _AdminVipRedemptionListResponse {
  const _AdminVipRedemptionListResponse({required this.items, required this.total});

  final List<_AdminVipRedemptionItem> items;
  final int total;

  factory _AdminVipRedemptionListResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    return _AdminVipRedemptionListResponse(
      items: raw
          .map((e) => _AdminVipRedemptionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num?)?.round() ?? raw.length,
    );
  }
}

class _VipActivationCodesTab extends StatefulWidget {
  const _VipActivationCodesTab({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_VipActivationCodesTab> createState() => _VipActivationCodesTabState();
}

class _VipActivationCodesTabState extends State<_VipActivationCodesTab> {
  int _subTab = 0;
  int _codesPage = 0;
  int _codesTotal = 0;
  bool _codesLoading = true;
  String? _codesError;
  String? _codesNotice;
  String _codesSearch = '';
  final _codesSearchCtrl = TextEditingController();
  List<_AdminVipCodeItem> _codes = const [];

  int _redemptionsPage = 0;
  int _redemptionsTotal = 0;
  bool _redemptionsLoading = false;
  bool _redemptionsLoadedOnce = false;
  String? _redemptionsError;
  String? _redemptionsNotice;
  final _userIdCtrl = TextEditingController();
  final _codeQCtrl = TextEditingController();
  List<_AdminVipRedemptionItem> _redemptions = const [];

  @override
  void initState() {
    super.initState();
    _loadCodes();
  }

  @override
  void dispose() {
    _codesSearchCtrl.dispose();
    _userIdCtrl.dispose();
    _codeQCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCodes() async {
    setState(() {
      _codesLoading = true;
      _codesError = null;
    });
    widget.api.authToken = widget.session.token;
    try {
      final result = await widget.api.fetchVipActivationCodes(
        q: _codesSearch.isEmpty ? null : _codesSearch,
        limit: _vipActivationPageSize,
        offset: _codesPage * _vipActivationPageSize,
      );
      if (!mounted) return;
      setState(() {
        _codes = result.items;
        _codesTotal = result.total;
        _codesLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _codesError = _vipActivationErrorText(error);
        _codesLoading = false;
      });
    }
  }

  Future<void> _loadRedemptions() async {
    setState(() {
      _redemptionsLoading = true;
      _redemptionsError = null;
    });
    widget.api.authToken = widget.session.token;
    try {
      final result = await widget.api.fetchVipActivationRedemptions(
        userId: _userIdCtrl.text.trim().isEmpty ? null : _userIdCtrl.text.trim(),
        codeQ: _codeQCtrl.text.trim().isEmpty ? null : _codeQCtrl.text.trim(),
        limit: _vipActivationPageSize,
        offset: _redemptionsPage * _vipActivationPageSize,
      );
      if (!mounted) return;
      setState(() {
        _redemptions = result.items;
        _redemptionsTotal = result.total;
        _redemptionsLoading = false;
        _redemptionsLoadedOnce = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _redemptionsError = _vipActivationErrorText(error);
        _redemptionsLoading = false;
      });
    }
  }

  Future<void> _openCreateSheet() async {
    final created = await _VipActivationCreateSheet.show(
      context,
      api: widget.api,
      session: widget.session,
    );

    if (created != null && created.isNotEmpty && mounted) {
      final formatted = created
          .map((c) => _formatVipActivationCodeDisplay(c.code))
          .toList();
      setState(() {
        _codesNotice = '已生成 ${created.length} 个激活码';
        _codesPage = 0;
      });
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('生成成功'),
          content: SingleChildScrollView(
            child: Text(
              formatted.join('\n'),
              style: const TextStyle(
                fontFamily: 'Menlo',
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: formatted.join('\n')));
                Navigator.of(ctx).pop();
              },
              child: const Text('复制全部'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      _loadCodes();
    }
  }

  Future<void> _copyCode(String code) async {
    final display = _formatVipActivationCodeDisplay(code);
    await Clipboard.setData(ClipboardData(text: display));
    if (!mounted) return;
    setState(() => _codesNotice = '已复制 $display');
  }

  int get _codesEnabledCount => _codes.where((c) => c.enabled).length;

  Future<void> _toggleCode(_AdminVipCodeItem item) async {
    widget.api.authToken = widget.session.token;
    try {
      await widget.api.patchVipActivationCode(codeId: item.id, enabled: !item.enabled);
      if (!mounted) return;
      setState(() => _codesNotice = item.enabled ? '已停用' : '已启用');
      _loadCodes();
    } catch (error) {
      if (!mounted) return;
      setState(() => _codesError = _vipActivationErrorText(error));
    }
  }

  Future<void> _revoke(_AdminVipRedemptionItem item) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('撤销兑换'),
        content: Text(
          '撤销 ${item.userDisplayName ?? item.userId} 的 ${item.durationDays} 天兑换？',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('撤销'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    widget.api.authToken = widget.session.token;
    try {
      await widget.api.revokeVipActivationRedemption(item.id);
      if (!mounted) return;
      setState(() => _redemptionsNotice = '已撤销并重新计算 VIP');
      _loadRedemptions();
    } catch (error) {
      if (!mounted) return;
      setState(() => _redemptionsError = _vipActivationErrorText(error));
    }
  }

  void _switchSubTab(int tab) {
    setState(() => _subTab = tab);
    if (tab == 1 && !_redemptionsLoadedOnce && !_redemptionsLoading) {
      _loadRedemptions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
          child: _AdminFilterSegmented(
            label: '视图',
            value: _subTab == 0 ? 'codes' : 'redemptions',
            options: const [
              ('激活码', 'codes'),
              ('兑换记录', 'redemptions'),
            ],
            onChanged: (v) => _switchSubTab(v == 'codes' ? 0 : 1),
          ),
        ),
        Expanded(
          child: _subTab == 0 ? _buildCodesPanel() : _buildRedemptionsPanel(),
        ),
      ],
    );
  }

  Widget _buildCodesPanel() {
    final totalPages =
        (_codesTotal / _vipActivationPageSize).ceil().clamp(1, 9999);
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadCodes,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              children: [
                _AdminCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AdminGamesTextField(
                        label: '搜索激活码 / 备注',
                        controller: _codesSearchCtrl,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _AdminGamesSecondaryButton(
                              label: _codesLoading ? '查询中…' : '查询',
                              onPressed: _codesLoading
                                  ? null
                                  : () {
                                      setState(() {
                                        _codesSearch =
                                            _codesSearchCtrl.text.trim();
                                        _codesPage = 0;
                                      });
                                      _loadCodes();
                                    },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _AdminRoleActionButton(
                              color: AppColors.of(context).accent,
                              icon: CupertinoIcons.add_circled_solid,
                              label: '生成',
                              loading: false,
                              onTap: _openCreateSheet,
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
                    ('总计', '$_codesTotal'),
                    ('启用中', '$_codesEnabledCount'),
                  ],
                ),
                if (_codesNotice != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _codesNotice!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF1FA97A),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
                if (_codesError != null) ...[
                  const SizedBox(height: 12),
                  _AdminGamesErrorText(_codesError!),
                ],
                const SizedBox(height: 12),
                if (_codesLoading && _codes.isEmpty)
                  const Center(child: CupertinoActivityIndicator(radius: 14))
                else if (_codes.isEmpty)
                  Text(
                    '暂无激活码',
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
                  for (final item in _codes) ...[
                    _VipActivationCodeCard(
                      item: item,
                      onCopy: () => _copyCode(item.code),
                      onToggle: () => _toggleCode(item),
                    ),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
          ),
        ),
        _vipSubPager(
          page: _codesPage,
          totalPages: totalPages,
          total: _codesTotal,
          unit: '条',
          onPrev: (_codesPage == 0 || _codesLoading)
              ? null
              : () {
                  setState(() => _codesPage -= 1);
                  _loadCodes();
                },
          onNext: (_codesPage + 1 >= totalPages || _codesLoading)
              ? null
              : () {
                  setState(() => _codesPage += 1);
                  _loadCodes();
                },
        ),
      ],
    );
  }

  Widget _buildRedemptionsPanel() {
    final totalPages =
        (_redemptionsTotal / _vipActivationPageSize).ceil().clamp(1, 9999);
    final grantedCount =
        _redemptions.where((r) => r.status == 'granted').length;
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadRedemptions,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              children: [
                _AdminCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AdminGamesTextField(
                        label: '用户 ID（可选）',
                        controller: _userIdCtrl,
                      ),
                      const SizedBox(height: 10),
                      _AdminGamesTextField(
                        label: '激活码 XXXX-XXXX',
                        controller: _codeQCtrl,
                      ),
                      const SizedBox(height: 10),
                      _AdminGamesSecondaryButton(
                        label: _redemptionsLoading ? '查询中…' : '查询',
                        onPressed: _redemptionsLoading
                            ? null
                            : () {
                                setState(() => _redemptionsPage = 0);
                                _loadRedemptions();
                              },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _AdminStatStrip(
                  stats: [
                    ('总计', '$_redemptionsTotal'),
                    ('生效中', '$grantedCount'),
                  ],
                ),
                if (_redemptionsNotice != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _redemptionsNotice!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF1FA97A),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
                if (_redemptionsError != null) ...[
                  const SizedBox(height: 12),
                  _AdminGamesErrorText(_redemptionsError!),
                ],
                const SizedBox(height: 12),
                if (_redemptionsLoading && _redemptions.isEmpty)
                  const Center(child: CupertinoActivityIndicator(radius: 14))
                else if (_redemptions.isEmpty)
                  Text(
                    '暂无兑换记录',
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
                  for (final item in _redemptions) ...[
                    _VipActivationRedemptionCard(
                      item: item,
                      onRevoke: item.status == 'granted'
                          ? () => _revoke(item)
                          : null,
                    ),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
          ),
        ),
        _vipSubPager(
          page: _redemptionsPage,
          totalPages: totalPages,
          total: _redemptionsTotal,
          unit: '笔',
          onPrev: (_redemptionsPage == 0 || _redemptionsLoading)
              ? null
              : () {
                  setState(() => _redemptionsPage -= 1);
                  _loadRedemptions();
                },
          onNext: (_redemptionsPage + 1 >= totalPages || _redemptionsLoading)
              ? null
              : () {
                  setState(() => _redemptionsPage += 1);
                  _loadRedemptions();
                },
        ),
      ],
    );
  }
}

class _VipActivationCodeCard extends StatelessWidget {
  const _VipActivationCodeCard({
    required this.item,
    required this.onCopy,
    required this.onToggle,
  });

  final _AdminVipCodeItem item;
  final VoidCallback onCopy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final display = _formatVipActivationCodeDisplay(item.code);
    final redeemed = item.maxRedemptions == null
        ? '${item.redemptionCount} 次'
        : '${item.redemptionCount}/${item.maxRedemptions}';
    return _AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onCopy,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        display,
                        style: TextStyle(
                          color: AppColors.text,
                          fontFamily: 'Menlo',
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          decoration: TextDecoration.none,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '点击复制',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _StatusPill(
                text: item.enabled ? '启用' : '停用',
                positive: item.enabled,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _VipActivationMetaChip(
                icon: CupertinoIcons.calendar,
                label: '${item.durationDays} 天',
              ),
              const SizedBox(width: 8),
              _VipActivationMetaChip(
                icon: CupertinoIcons.ticket,
                label: _vipActivationRedemptionLimitLabel(item),
              ),
              const SizedBox(width: 8),
              _VipActivationMetaChip(
                icon: CupertinoIcons.person_2,
                label: '已兑 $redeemed',
              ),
            ],
          ),
          if (item.note != null && item.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.note!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: _AdminGamesSecondaryButton(
              label: item.enabled ? '停用' : '启用',
              onPressed: onToggle,
            ),
          ),
        ],
      ),
    );
  }
}

class _VipActivationMetaChip extends StatelessWidget {
  const _VipActivationMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.muted.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.muted),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _VipActivationRedemptionCard extends StatelessWidget {
  const _VipActivationRedemptionCard({
    required this.item,
    required this.onRevoke,
  });

  final _AdminVipRedemptionItem item;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final granted = item.status == 'granted';
    return _AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.userDisplayName ?? item.userId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              _StatusPill(
                text: granted ? '生效中' : '已撤销',
                positive: granted,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatVipActivationCodeDisplay(item.codePreview)} · ${item.durationDays} 天',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'Menlo',
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _vipFormatDate(item.redeemedAt),
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
          if (onRevoke != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: _AdminGamesSecondaryButton(
                label: '撤销兑换',
                onPressed: onRevoke,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ===========================================================================
// Create sheet: generate VIP activation codes
// ===========================================================================

class _VipActivationCreateSheet extends StatefulWidget {
  const _VipActivationCreateSheet({
    required this.api,
    required this.session,
  });

  final CompanionApi api;
  final AuthSession session;

  static Future<List<_AdminVipCodeItem>?> show(
    BuildContext context, {
    required CompanionApi api,
    required AuthSession session,
  }) {
    return showModalBottomSheet<List<_AdminVipCodeItem>>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (_) => _adminSheetHost(
        child: _VipActivationCreateSheet(api: api, session: session),
      ),
    );
  }

  @override
  State<_VipActivationCreateSheet> createState() =>
      _VipActivationCreateSheetState();
}

class _VipActivationCreateSheetState extends State<_VipActivationCreateSheet> {
  final _durationCtrl = TextEditingController(text: '30');
  final _countCtrl = TextEditingController(text: '1');
  final _maxCtrl = TextEditingController(text: '1');
  final _noteCtrl = TextEditingController();
  var _unlimited = false;
  var _submitting = false;

  @override
  void dispose() {
    _durationCtrl.dispose();
    _countCtrl.dispose();
    _maxCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    widget.api.authToken = widget.session.token;
    final durationDays = int.tryParse(_durationCtrl.text.trim()) ?? 30;
    final count = int.tryParse(_countCtrl.text.trim()) ?? 1;
    final maxRedemptions = int.tryParse(_maxCtrl.text.trim()) ?? 1;
    try {
      final codes = await widget.api.createVipActivationCodes(
        durationDays: durationDays,
        count: count,
        unlimitedRedemptions: _unlimited,
        maxRedemptions: _unlimited ? null : maxRedemptions,
        note: _noteCtrl.text,
      );
      if (mounted) Navigator.of(context).pop(codes);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      await showCupertinoDialog<void>(
        context: context,
        builder: (dCtx) => CupertinoAlertDialog(
          title: const Text('生成失败'),
          content: Text(_vipActivationErrorText(error)),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dCtx).pop(),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.text : const Color(0xFF12171B);
    final accent = AppColors.of(context).accent;
    final sheetBg = isDark ? const Color(0xFF141820) : const Color(0xFFF4F6FA);

    return _AdminSheetLayout(
      backgroundColor: sheetBg,
      heightFraction: 0.58,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _AdminSheetGrabber(),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '生成 VIP 激活码（XXXX-XXXX）',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: Size.zero,
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AdminCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: _AdminGamesNumberField(
                            label: 'VIP 时长（天）',
                            controller: _durationCtrl,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _AdminGamesNumberField(
                            label: '生成数量',
                            controller: _countCtrl,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AdminCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '无限次兑换',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '开启后多人可使用同一激活码',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          ),
                        ),
                        CupertinoSwitch(
                          value: _unlimited,
                          onChanged: _submitting
                              ? null
                              : (v) => setState(() => _unlimited = v),
                        ),
                      ],
                    ),
                  ),
                  if (!_unlimited) ...[
                    const SizedBox(height: 12),
                    _AdminCard(
                      padding: const EdgeInsets.all(14),
                      child: _AdminGamesNumberField(
                        label: '最大兑换次数',
                        controller: _maxCtrl,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Text(
                        '填 1 表示一次性码，仅可被兑换一次',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _AdminCard(
                    padding: const EdgeInsets.all(14),
                    child: _AdminGamesTextField(
                      label: '备注（可选）',
                      controller: _noteCtrl,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _AdminRoleActionButton(
            color: accent,
            icon: CupertinoIcons.tickets_fill,
            label: '生成激活码',
            loading: _submitting,
            onTap: _submit,
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Entry page: VIP 激活码管理（与 VIP 订阅管理同级独立入口）
// ===========================================================================

class _AdminVipActivationPage extends StatelessWidget {
  const _AdminVipActivationPage({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return _AdminScaffold(
      title: 'VIP 激活码',
      subtitle: '生成 / 启停 · 兑换记录与撤销',
      child: _VipActivationCodesTab(api: api, session: session),
    );
  }
}
