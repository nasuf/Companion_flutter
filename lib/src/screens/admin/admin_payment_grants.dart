part of 'package:companion_flutter/main.dart';

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
    return _AdminDialogHost(
      child: _AdminFormDialogFrame(
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
    return _AdminDialogHost(
      child: _AdminFormDialogFrame(
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
    final danger = AppColors.of(context).danger;
    return _AdminDialogHost(
      child: _AdminFormDialogFrame(
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
