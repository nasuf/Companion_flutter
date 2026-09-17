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
  bool _redemptionsLoading = true;
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
    final durationCtrl = TextEditingController(text: '30');
    final countCtrl = TextEditingController(text: '1');
    final maxCtrl = TextEditingController(text: '1');
    final noteCtrl = TextEditingController();
    var unlimited = false;

    final created = await showCupertinoModalPopup<List<_AdminVipCodeItem>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.72,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground.resolveFrom(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '生成 VIP 激活码',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _W2b.resolve(context).ink,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('VIP 时长（天）', style: TextStyle(fontSize: 12)),
                  CupertinoTextField(
                    controller: durationCtrl,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  const Text('生成数量', style: TextStyle(fontSize: 12)),
                  CupertinoTextField(
                    controller: countCtrl,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      CupertinoSwitch(
                        value: unlimited,
                        onChanged: (v) => setSheetState(() => unlimited = v),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('无限次兑换（多人可用同一码）')),
                    ],
                  ),
                  if (!unlimited) ...[
                    const SizedBox(height: 10),
                    const Text('最大兑换次数（1=一次性）', style: TextStyle(fontSize: 12)),
                    CupertinoTextField(
                      controller: maxCtrl,
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  const SizedBox(height: 10),
                  const Text('备注（可选）', style: TextStyle(fontSize: 12)),
                  CupertinoTextField(controller: noteCtrl),
                  const Spacer(),
                  CupertinoButton.filled(
                    onPressed: () async {
                      widget.api.authToken = widget.session.token;
                      final durationDays = int.tryParse(durationCtrl.text.trim()) ?? 30;
                      final count = int.tryParse(countCtrl.text.trim()) ?? 1;
                      final maxRedemptions = int.tryParse(maxCtrl.text.trim()) ?? 1;
                      try {
                        final codes = await widget.api.createVipActivationCodes(
                          durationDays: durationDays,
                          count: count,
                          unlimitedRedemptions: unlimited,
                          maxRedemptions: unlimited ? null : maxRedemptions,
                          note: noteCtrl.text,
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop(codes);
                      } catch (error) {
                        if (!ctx.mounted) return;
                        await showCupertinoDialog<void>(
                          context: ctx,
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
                    },
                    child: const Text('生成'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    durationCtrl.dispose();
    countCtrl.dispose();
    maxCtrl.dispose();
    noteCtrl.dispose();

    if (created != null && created.isNotEmpty && mounted) {
      setState(() {
        _codesNotice = '已生成 ${created.length} 个激活码';
        _codesPage = 0;
      });
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('生成成功'),
          content: Text(created.map((c) => c.code).join('\n')),
          actions: [
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
          child: CupertinoSlidingSegmentedControl<int>(
            groupValue: _subTab,
            onValueChanged: (v) {
              if (v == null) return;
              setState(() => _subTab = v);
              if (v == 1 && _redemptions.isEmpty) _loadRedemptions();
            },
            children: const {
              0: Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('激活码', style: TextStyle(fontSize: 13)),
              ),
              1: Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('兑换记录', style: TextStyle(fontSize: 13)),
              ),
            },
          ),
        ),
        Expanded(
          child: _subTab == 0 ? _buildCodesPanel() : _buildRedemptionsPanel(),
        ),
      ],
    );
  }

  Widget _buildCodesPanel() {
    final totalPages = (_codesTotal / _vipActivationPageSize).ceil().clamp(1, 9999);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
          child: Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: _codesSearchCtrl,
                  placeholder: '搜索激活码 / 备注',
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                onPressed: () {
                  setState(() {
                    _codesSearch = _codesSearchCtrl.text.trim();
                    _codesPage = 0;
                  });
                  _loadCodes();
                },
                child: const Text('查询'),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                onPressed: _openCreateSheet,
                child: const Text('生成'),
              ),
            ],
          ),
        ),
        if (_codesNotice != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_codesNotice!, style: const TextStyle(color: CupertinoColors.activeGreen)),
          ),
        if (_codesError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_codesError!, style: const TextStyle(color: CupertinoColors.destructiveRed)),
          ),
        Expanded(
          child: _codesLoading
              ? const Center(child: CupertinoActivityIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.all(18),
                  itemCount: _codes.length,
                  itemBuilder: (context, index) {
                    final item = _codes[index];
                    final limit = item.maxRedemptions == null
                        ? '∞'
                        : '${item.redemptionCount}/${item.maxRedemptions}';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CupertinoColors.secondarySystemGroupedBackground
                            .resolveFrom(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.code,
                            style: const TextStyle(
                              fontFamily: 'Menlo',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('${item.durationDays} 天 · 已兑 $limit'),
                          if (item.note != null && item.note!.isNotEmpty)
                            Text(item.note!, style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(item.enabled ? '启用' : '停用'),
                              const Spacer(),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () => _toggleCode(item),
                                child: Text(item.enabled ? '停用' : '启用'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        _adminWalletBalancePager(
          page: _codesPage,
          totalPages: totalPages,
          total: _codesTotal,
          onPrev: _codesPage > 0
              ? () {
                  setState(() => _codesPage -= 1);
                  _loadCodes();
                }
              : null,
          onNext: _codesPage + 1 < totalPages
              ? () {
                  setState(() => _codesPage += 1);
                  _loadCodes();
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildRedemptionsPanel() {
    final totalPages =
        (_redemptionsTotal / _vipActivationPageSize).ceil().clamp(1, 9999);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
          child: Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: _userIdCtrl,
                  placeholder: '用户 ID',
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CupertinoTextField(
                  controller: _codeQCtrl,
                  placeholder: '激活码',
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                onPressed: () {
                  setState(() => _redemptionsPage = 0);
                  _loadRedemptions();
                },
                child: const Text('查询'),
              ),
            ],
          ),
        ),
        if (_redemptionsNotice != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _redemptionsNotice!,
              style: const TextStyle(color: CupertinoColors.activeGreen),
            ),
          ),
        if (_redemptionsError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _redemptionsError!,
              style: const TextStyle(color: CupertinoColors.destructiveRed),
            ),
          ),
        Expanded(
          child: _redemptionsLoading
              ? const Center(child: CupertinoActivityIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.all(18),
                  itemCount: _redemptions.length,
                  itemBuilder: (context, index) {
                    final item = _redemptions[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CupertinoColors.secondarySystemGroupedBackground
                            .resolveFrom(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.userDisplayName ?? item.userId,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${item.codePreview} · ${item.durationDays} 天',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            _vipFormatDate(item.redeemedAt),
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (item.status == 'granted')
                            Align(
                              alignment: Alignment.centerRight,
                              child: CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () => _revoke(item),
                                child: const Text(
                                  '撤销',
                                  style: TextStyle(color: CupertinoColors.destructiveRed),
                                ),
                              ),
                            )
                          else
                            const Text('已撤销', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    );
                  },
                ),
        ),
        _adminWalletBalancePager(
          page: _redemptionsPage,
          totalPages: totalPages,
          total: _redemptionsTotal,
          onPrev: _redemptionsPage > 0
              ? () {
                  setState(() => _redemptionsPage -= 1);
                  _loadRedemptions();
                }
              : null,
          onNext: _redemptionsPage + 1 < totalPages
              ? () {
                  setState(() => _redemptionsPage += 1);
                  _loadRedemptions();
                }
              : null,
        ),
      ],
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
