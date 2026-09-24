part of 'package:companion_flutter/main.dart';

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
