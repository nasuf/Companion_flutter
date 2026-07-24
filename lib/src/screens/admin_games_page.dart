part of 'package:companion_flutter/main.dart';

// ---------------------------------------------------------------------------
// Admin · 游戏管理 (mobile port of the web 后台管理「游戏管理」workspace)
//
// Full parity with the web surface:
//   * 难度平衡   — per-game AI strength / target win-rate / adaptive window /
//                  algorithm overrides + version history & restore.
//   * 积分等级   — the game-point level ladder (stage / tier / thresholds).
//   * 积分规则   — per-game win/lose/draw/quit scoring; number_merge uses the
//                  tile "milestone" shape.
//
// All requests go through the shared `_adminHttpRequest` helper defined in
// admin_dashboard_page.dart, so auth + error handling stay consistent.
// ---------------------------------------------------------------------------

// ===========================================================================
// API
// ===========================================================================

extension _AdminGamesApi on CompanionApi {
  Future<List<_AdminGameConfig>> fetchGameConfigs() async {
    final json =
        await _adminHttpRequest(this, 'GET', '/admin-api/game-configs')
            as List<dynamic>;
    return json
        .whereType<Map>()
        .map((item) => _AdminGameConfig.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<_AdminGameConfig> updateGameConfig(
    String gameKey,
    Map<String, dynamic> payload,
  ) async {
    final json =
        await _adminHttpRequest(
              this,
              'PUT',
              '/admin-api/game-configs/${Uri.encodeComponent(gameKey)}',
              body: payload,
            )
            as Map<String, dynamic>;
    return _AdminGameConfig.fromJson(json);
  }

  Future<List<_AdminGameConfigVersion>> fetchGameConfigVersions(
    String gameKey, {
    int limit = 20,
  }) async {
    final path = Uri(
      path: '/admin-api/game-configs/${Uri.encodeComponent(gameKey)}/versions',
      queryParameters: {'limit': limit.toString()},
    ).toString();
    final json = await _adminHttpRequest(this, 'GET', path) as List<dynamic>;
    return json
        .whereType<Map>()
        .map(
          (item) =>
              _AdminGameConfigVersion.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<_AdminGameConfig> restoreGameConfigVersion(
    String gameKey,
    int version,
  ) async {
    final json =
        await _adminHttpRequest(
              this,
              'POST',
              '/admin-api/game-configs/${Uri.encodeComponent(gameKey)}'
                  '/versions/$version/restore',
            )
            as Map<String, dynamic>;
    return _AdminGameConfig.fromJson(json);
  }

  Future<List<_GameLevelTier>> fetchGameLevels() async {
    final json =
        await _adminHttpRequest(this, 'GET', '/admin-api/game-points/levels')
            as List<dynamic>;
    return json
        .whereType<Map>()
        .map((item) => _GameLevelTier.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<_GameLevelTier>> updateGameLevels(
    List<Map<String, dynamic>> tiers,
  ) async {
    final json =
        await _adminHttpRequest(
              this,
              'PUT',
              '/admin-api/game-points/levels',
              body: {'tiers': tiers},
            )
            as List<dynamic>;
    return json
        .whereType<Map>()
        .map((item) => _GameLevelTier.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<_GamePointRule>> fetchGamePointRules() async {
    final json =
        await _adminHttpRequest(this, 'GET', '/admin-api/game-points/rules')
            as List<dynamic>;
    return json
        .whereType<Map>()
        .map((item) => _GamePointRule.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<_GamePointRule> updateGamePointRule(
    String gameKey,
    Map<String, dynamic> rules,
  ) async {
    final json =
        await _adminHttpRequest(
              this,
              'PUT',
              '/admin-api/game-points/rules/${Uri.encodeComponent(gameKey)}',
              body: {'rules': rules},
            )
            as Map<String, dynamic>;
    return _GamePointRule.fromJson(json);
  }

  Future<List<_AdminGamePointLedgerItem>> fetchGamePointLedger({
    String? userId,
    int limit = 20,
    int offset = 0,
  }) async {
    final params = <String, String>{'limit': limit.toString()};
    if (userId != null && userId.isNotEmpty) params['user_id'] = userId;
    if (offset > 0) params['offset'] = offset.toString();
    final path = Uri(
      path: '/admin-api/game-points/ledger',
      queryParameters: params,
    ).toString();
    final json = await _adminHttpRequest(this, 'GET', path) as List<dynamic>;
    return json
        .whereType<Map>()
        .map(
          (item) => _AdminGamePointLedgerItem.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<List<_AdminUserSearchItem>> searchGamePointUsers(
    String query, {
    int limit = 20,
  }) async {
    final path = Uri(
      path: '/admin-api/game-points/users',
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

  Future<int> grantGamePoints({
    required String userId,
    required int amount,
    String? note,
  }) async {
    final json =
        await _adminHttpRequest(
              this,
              'POST',
              '/admin-api/game-points/grant',
              body: {
                'user_id': userId,
                'amount': amount,
                if (note != null && note.isNotEmpty) 'note': note,
              },
            )
            as Map<String, dynamic>;
    return _adminInt(json['balance']);
  }
}

// ===========================================================================
// Models
// ===========================================================================

int _adminInt(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

class _GameConfigMetrics {
  const _GameConfigMetrics({
    required this.completed30d,
    required this.wins30d,
    required this.losses30d,
    required this.draws30d,
    required this.userRate30d,
  });

  final int completed30d;
  final int wins30d;
  final int losses30d;
  final int draws30d;
  final double? userRate30d;

  factory _GameConfigMetrics.fromJson(Map<String, dynamic> json) {
    final rate = json['user_rate_30d'];
    return _GameConfigMetrics(
      completed30d: _adminInt(json['completed_30d']),
      wins30d: _adminInt(json['wins_30d']),
      losses30d: _adminInt(json['losses_30d']),
      draws30d: _adminInt(json['draws_30d']),
      userRate30d: rate == null ? null : _jsonDouble(rate),
    );
  }
}

class _AdminGameConfig {
  const _AdminGameConfig({
    required this.gameKey,
    required this.title,
    required this.playMode,
    required this.mode,
    required this.baseStrength,
    required this.minStrength,
    required this.maxStrength,
    required this.targetUserRate,
    required this.adjustmentWindow,
    required this.minimumGames,
    required this.maximumStep,
    required this.algorithmOverrides,
    required this.version,
    required this.previewEngineConfig,
    required this.metrics,
  });

  final String gameKey;
  final String title;
  final String playMode;
  final String mode;
  final int baseStrength;
  final int minStrength;
  final int maxStrength;
  final double targetUserRate;
  final int adjustmentWindow;
  final int minimumGames;
  final int maximumStep;
  final Map<String, dynamic> algorithmOverrides;
  final int version;
  final Map<String, dynamic> previewEngineConfig;
  final _GameConfigMetrics metrics;

  factory _AdminGameConfig.fromJson(Map<String, dynamic> json) {
    return _AdminGameConfig(
      gameKey: json['game_key']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      playMode: json['play_mode']?.toString() ?? 'versus',
      mode: json['mode']?.toString() ?? 'adaptive',
      baseStrength: _adminInt(json['base_strength'], 50),
      minStrength: _adminInt(json['min_strength'], 20),
      maxStrength: _adminInt(json['max_strength'], 85),
      targetUserRate: _jsonDouble(json['target_user_rate']),
      adjustmentWindow: _adminInt(json['adjustment_window'], 10),
      minimumGames: _adminInt(json['minimum_games'], 3),
      maximumStep: _adminInt(json['maximum_step'], 5),
      algorithmOverrides: json['algorithm_overrides'] is Map
          ? Map<String, dynamic>.from(json['algorithm_overrides'] as Map)
          : <String, dynamic>{},
      version: _adminInt(json['version'], 1),
      previewEngineConfig: json['preview_engine_config'] is Map
          ? Map<String, dynamic>.from(json['preview_engine_config'] as Map)
          : <String, dynamic>{},
      metrics: _GameConfigMetrics.fromJson(
        json['metrics'] is Map
            ? Map<String, dynamic>.from(json['metrics'] as Map)
            : <String, dynamic>{},
      ),
    );
  }
}

class _AdminGameConfigVersion {
  const _AdminGameConfigVersion({
    required this.version,
    required this.config,
    required this.publishedAt,
  });

  final int version;
  final Map<String, dynamic> config;
  final String? publishedAt;

  factory _AdminGameConfigVersion.fromJson(Map<String, dynamic> json) {
    return _AdminGameConfigVersion(
      version: _adminInt(json['version']),
      config: json['config'] is Map
          ? Map<String, dynamic>.from(json['config'] as Map)
          : <String, dynamic>{},
      publishedAt: json['published_at']?.toString(),
    );
  }
}

class _GameLevelTier {
  _GameLevelTier({
    required this.stageName,
    required this.tierName,
    required this.upgradePoints,
    required this.cumulativePoints,
  });

  String stageName;
  String tierName;
  int upgradePoints;
  int cumulativePoints;

  factory _GameLevelTier.fromJson(Map<String, dynamic> json) {
    return _GameLevelTier(
      stageName: json['stage_name']?.toString() ?? '',
      tierName: json['tier_name']?.toString() ?? '',
      upgradePoints: _adminInt(json['upgrade_points']),
      cumulativePoints: _adminInt(json['cumulative_points']),
    );
  }

  Map<String, dynamic> toPayload() => {
    'stage_name': stageName,
    'tier_name': tierName,
    'upgrade_points': upgradePoints,
    'cumulative_points': cumulativePoints,
  };
}

class _GamePointRule {
  const _GamePointRule({
    required this.gameKey,
    required this.title,
    required this.rules,
  });

  final String gameKey;
  final String title;
  final Map<String, dynamic> rules;

  bool get isMilestone => rules['type']?.toString() == 'milestone';
  bool get pendingPm => rules['pending_pm'] == true;

  factory _GamePointRule.fromJson(Map<String, dynamic> json) {
    return _GamePointRule(
      gameKey: json['game_key']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      rules: json['rules'] is Map
          ? Map<String, dynamic>.from(json['rules'] as Map)
          : <String, dynamic>{},
    );
  }
}

class _AdminUserSearchItem {
  const _AdminUserSearchItem({
    required this.userId,
    required this.username,
    required this.nickname,
  });

  final String userId;
  final String username;
  final String? nickname;

  String get displayName {
    final nick = nickname?.trim();
    if (nick != null && nick.isNotEmpty) return nick;
    return username.trim().isNotEmpty ? username.trim() : '(未知)';
  }

  factory _AdminUserSearchItem.fromJson(Map<String, dynamic> json) {
    return _AdminUserSearchItem(
      userId: json['user_id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      nickname: json['nickname']?.toString(),
    );
  }
}

class _AdminGamePointLedgerItem {
  const _AdminGamePointLedgerItem({
    required this.id,
    required this.userId,
    required this.username,
    this.nickname,
    required this.delta,
    required this.balanceAfter,
    required this.source,
    required this.metadata,
    required this.createdAt,
    required this.levelName,
    required this.levelUp,
  });

  final String id;
  final String userId;
  final String? username;
  final String? nickname;
  final int delta;
  final int balanceAfter;
  final String source;
  final Map<String, dynamic> metadata;
  final String createdAt;
  final String? levelName;
  final bool levelUp;

  String get displayName {
    final nick = nickname?.trim();
    if (nick != null && nick.isNotEmpty) return nick;
    final name = username?.trim();
    if (name != null && name.isNotEmpty) return name;
    return '(未知)';
  }

  factory _AdminGamePointLedgerItem.fromJson(Map<String, dynamic> json) {
    return _AdminGamePointLedgerItem(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      username: json['username']?.toString(),
      nickname: json['nickname']?.toString(),
      delta: _adminInt(json['delta']),
      balanceAfter: _adminInt(json['balance_after']),
      source: json['source']?.toString() ?? '',
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : <String, dynamic>{},
      createdAt: json['created_at']?.toString() ?? '',
      levelName: json['level_name']?.toString(),
      levelUp: json['level_up'] == true,
    );
  }

  String get sourceLabel {
    const labels = {
      'daily_grant': '每日赠送',
      'game_settle': '游戏结算',
      'convert_to_shop': '兑换商城积分',
      'admin_grant': '官方赠送',
      'admin_adjust': '官方调整',
    };
    final base = labels[source] ?? source;
    if (source == 'game_settle') {
      const outcomes = {
        'win': '赢',
        'lose': '输',
        'draw': '平',
        'aborted': '中途退出',
      };
      final outcome = metadata['outcome']?.toString();
      final gameKey = metadata['game_key']?.toString();
      return [base, gameKey, outcomes[outcome] ?? outcome]
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .join(' · ');
    }
    return base;
  }
}

// ===========================================================================
// Entry page: 难度平衡 / 积分等级 / 积分规则 / 积分管理
// ===========================================================================

class _AdminGamesPage extends StatefulWidget {
  const _AdminGamesPage({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_AdminGamesPage> createState() => _AdminGamesPageState();
}

class _AdminGamesPageState extends State<_AdminGamesPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return _AdminScaffold(
      title: '游戏管理',
      subtitle: '难度 · 积分等级 · 规则 · 积分管理',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _tab,
                onValueChanged: (value) {
                  if (value != null) setState(() => _tab = value);
                },
                children: const {
                  0: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('难度平衡', style: TextStyle(fontSize: 12)),
                  ),
                  1: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('积分等级', style: TextStyle(fontSize: 12)),
                  ),
                  2: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('积分规则', style: TextStyle(fontSize: 12)),
                  ),
                  3: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('积分管理', style: TextStyle(fontSize: 12)),
                  ),
                },
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                _GameBalanceTab(api: widget.api, session: widget.session),
                _GameLevelsTab(api: widget.api, session: widget.session),
                _GameRulesTab(api: widget.api, session: widget.session),
                _GamePointsLedgerTab(api: widget.api, session: widget.session),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Tab 1 · 难度平衡
// ===========================================================================

class _GameBalanceTab extends StatefulWidget {
  const _GameBalanceTab({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_GameBalanceTab> createState() => _GameBalanceTabState();
}

class _GameBalanceTabState extends State<_GameBalanceTab> {
  bool _loading = true;
  String? _error;
  List<_AdminGameConfig> _configs = const [];

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
    widget.api.authToken = widget.session.token;
    try {
      final configs = await widget.api.fetchGameConfigs();
      if (!mounted) return;
      setState(() {
        _configs = configs;
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

  Future<void> _openEditor(_AdminGameConfig config) async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => _GameConfigEditorPage(
          api: widget.api,
          session: widget.session,
          config: config,
        ),
      ),
    );
    // Publishing bumps the version; refresh the list so cards reflect it.
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _configs.isEmpty) {
      return const Center(child: CupertinoActivityIndicator(radius: 14));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        children: [
          if (_error != null) ...[
            _AdminGamesErrorText(_error!),
            const SizedBox(height: 12),
          ],
          for (final config in _configs) ...[
            _GameBalanceCard(config: config, onTap: () => _openEditor(config)),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _GameBalanceCard extends StatelessWidget {
  const _GameBalanceCard({required this.config, required this.onTap});

  final _AdminGameConfig config;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: _AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  config.title,
                  style: TextStyle(
                    color: isDark ? AppColors.text : const Color(0xFF12171B),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(width: 8),
                _AdminMiniBadge(
                  text: config.playMode == 'cooperate' ? '合作' : '对战',
                ),
                const Spacer(),
                Text(
                  'v${config.version}',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 16,
                  color: AppColors.muted,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _GameStatChip(
                  label: '强度',
                  value: '${config.baseStrength}',
                ),
                const SizedBox(width: 8),
                _GameStatChip(
                  label: '目标胜率',
                  value: _formatRate(config.targetUserRate),
                ),
                const SizedBox(width: 8),
                _GameStatChip(
                  label: '30日胜率',
                  value: _formatRate(config.metrics.userRate30d),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GameStatChip extends StatelessWidget {
  const _GameStatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                color: isDark ? AppColors.text : const Color(0xFF12171B),
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 难度平衡 editor
// ---------------------------------------------------------------------------

class _GameConfigEditorPage extends StatefulWidget {
  const _GameConfigEditorPage({
    required this.api,
    required this.session,
    required this.config,
  });

  final CompanionApi api;
  final AuthSession session;
  final _AdminGameConfig config;

  @override
  State<_GameConfigEditorPage> createState() => _GameConfigEditorPageState();
}

class _GameConfigEditorPageState extends State<_GameConfigEditorPage> {
  late String _mode;
  late final TextEditingController _baseCtrl;
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;
  late final TextEditingController _targetCtrl; // percent
  late final TextEditingController _windowCtrl;
  late final TextEditingController _minGamesCtrl;
  late final TextEditingController _maxStepCtrl;
  late final TextEditingController _overridesCtrl;

  bool _saving = false;
  String? _error;
  String? _notice;

  bool _versionsLoading = false;
  List<_AdminGameConfigVersion> _versions = const [];
  int? _restoring;
  int _currentVersion = 1;

  @override
  void initState() {
    super.initState();
    final c = widget.config;
    _mode = c.mode;
    _currentVersion = c.version;
    _baseCtrl = TextEditingController(text: '${c.baseStrength}');
    _minCtrl = TextEditingController(text: '${c.minStrength}');
    _maxCtrl = TextEditingController(text: '${c.maxStrength}');
    _targetCtrl = TextEditingController(
      text: (c.targetUserRate * 100).toStringAsFixed(1),
    );
    _windowCtrl = TextEditingController(text: '${c.adjustmentWindow}');
    _minGamesCtrl = TextEditingController(text: '${c.minimumGames}');
    _maxStepCtrl = TextEditingController(text: '${c.maximumStep}');
    _overridesCtrl = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(c.algorithmOverrides),
    );
    _loadVersions();
  }

  @override
  void dispose() {
    _baseCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _targetCtrl.dispose();
    _windowCtrl.dispose();
    _minGamesCtrl.dispose();
    _maxStepCtrl.dispose();
    _overridesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVersions() async {
    setState(() => _versionsLoading = true);
    widget.api.authToken = widget.session.token;
    try {
      final versions = await widget.api.fetchGameConfigVersions(
        widget.config.gameKey,
      );
      if (!mounted) return;
      setState(() {
        _versions = versions;
        _versionsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _versionsLoading = false);
    }
  }

  Map<String, dynamic>? _buildPayload() {
    final base = int.tryParse(_baseCtrl.text.trim());
    final min = int.tryParse(_minCtrl.text.trim());
    final max = int.tryParse(_maxCtrl.text.trim());
    final targetPercent = double.tryParse(_targetCtrl.text.trim());
    final window = int.tryParse(_windowCtrl.text.trim());
    final minGames = int.tryParse(_minGamesCtrl.text.trim());
    final maxStep = int.tryParse(_maxStepCtrl.text.trim());
    if (base == null ||
        min == null ||
        max == null ||
        targetPercent == null ||
        window == null ||
        minGames == null ||
        maxStep == null) {
      setState(() => _error = '请填写有效的数字');
      return null;
    }
    if (!(min <= base && base <= max)) {
      setState(() => _error = '基础强度必须在最低与最高强度之间');
      return null;
    }
    Map<String, dynamic> overrides;
    final overridesText = _overridesCtrl.text.trim();
    if (overridesText.isEmpty) {
      overrides = <String, dynamic>{};
    } else {
      try {
        final parsed = jsonDecode(overridesText);
        if (parsed is! Map) {
          setState(() => _error = '算法覆盖项必须是 JSON 对象');
          return null;
        }
        overrides = Map<String, dynamic>.from(parsed);
      } catch (_) {
        setState(() => _error = '算法覆盖项 JSON 格式错误');
        return null;
      }
    }
    return {
      'mode': _mode,
      'base_strength': base,
      'min_strength': min,
      'max_strength': max,
      'target_user_rate': targetPercent / 100,
      'adjustment_window': window,
      'minimum_games': minGames,
      'maximum_step': maxStep,
      'algorithm_overrides': overrides,
    };
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _error = null;
      _notice = null;
    });
    final payload = _buildPayload();
    if (payload == null) return;
    setState(() => _saving = true);
    widget.api.authToken = widget.session.token;
    try {
      final updated = await widget.api.updateGameConfig(
        widget.config.gameKey,
        payload,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _currentVersion = updated.version;
        _notice = '已发布 v${updated.version}，新对局开始时生效。';
        _overridesCtrl.text = const JsonEncoder.withIndent(
          '  ',
        ).convert(updated.algorithmOverrides);
      });
      _loadVersions();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _asMessage(error);
      });
    }
  }

  Future<void> _restore(int version) async {
    if (_restoring != null) return;
    setState(() {
      _restoring = version;
      _error = null;
      _notice = null;
    });
    widget.api.authToken = widget.session.token;
    try {
      final updated = await widget.api.restoreGameConfigVersion(
        widget.config.gameKey,
        version,
      );
      if (!mounted) return;
      setState(() {
        _restoring = null;
        _mode = updated.mode;
        _currentVersion = updated.version;
        _baseCtrl.text = '${updated.baseStrength}';
        _minCtrl.text = '${updated.minStrength}';
        _maxCtrl.text = '${updated.maxStrength}';
        _targetCtrl.text = (updated.targetUserRate * 100).toStringAsFixed(1);
        _windowCtrl.text = '${updated.adjustmentWindow}';
        _minGamesCtrl.text = '${updated.minimumGames}';
        _maxStepCtrl.text = '${updated.maximumStep}';
        _overridesCtrl.text = const JsonEncoder.withIndent(
          '  ',
        ).convert(updated.algorithmOverrides);
        _notice = '已恢复并发布为 v${updated.version}。';
      });
      _loadVersions();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _restoring = null;
        _error = _asMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AdminScaffold(
      title: widget.config.title,
      subtitle: '难度配置 · 当前 v$_currentVersion',
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        children: [
          _AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _AdminGamesFieldLabel('生效模式'),
                const SizedBox(height: 8),
                CupertinoSlidingSegmentedControl<String>(
                  groupValue: _mode,
                  onValueChanged: (value) {
                    if (value != null) setState(() => _mode = value);
                  },
                  children: const {
                    'adaptive': Padding(
                      padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      child: Text('自适应', style: TextStyle(fontSize: 13)),
                    ),
                    'fixed': Padding(
                      padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      child: Text('固定', style: TextStyle(fontSize: 13)),
                    ),
                  },
                ),
                const SizedBox(height: 16),
                _AdminGamesNumberField(label: '基础强度 (0-100)', controller: _baseCtrl),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _AdminGamesNumberField(
                        label: '最低强度',
                        controller: _minCtrl,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AdminGamesNumberField(
                        label: '最高强度',
                        controller: _maxCtrl,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _AdminGamesNumberField(
                  label: '目标用户胜率 (%)',
                  controller: _targetCtrl,
                  decimal: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _AdminGamesSectionHeader('自适应窗口'),
                const SizedBox(height: 12),
                _AdminGamesNumberField(
                  label: '观察窗口局数',
                  controller: _windowCtrl,
                ),
                const SizedBox(height: 12),
                _AdminGamesNumberField(
                  label: '启动所需局数',
                  controller: _minGamesCtrl,
                ),
                const SizedBox(height: 12),
                _AdminGamesNumberField(
                  label: '单次最大调整',
                  controller: _maxStepCtrl,
                ),
                const SizedBox(height: 8),
                Text(
                  '自适应只根据同一用户与同一 agent 在该游戏里已结算的对局调整，且只在新对局创建时读取。',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _AdminGamesSectionHeader('算法覆盖 (JSON)'),
                const SizedBox(height: 4),
                Text(
                  '空对象 {} 表示按强度曲线自动生成；保存时后端会校验参数名、类型和范围。',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 10),
                _AdminGamesMultilineField(controller: _overridesCtrl),
                const SizedBox(height: 12),
                _AdminGamesReadonlyJson(
                  label: '基础强度预览',
                  value: widget.config.previewEngineConfig,
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
          const SizedBox(height: 16),
          _AdminGamesPrimaryButton(
            label: _saving ? '发布中…' : '发布配置',
            onPressed: _saving ? null : _save,
          ),
          const SizedBox(height: 20),
          _AdminGamesSectionHeader('版本历史'),
          const SizedBox(height: 10),
          if (_versionsLoading)
            const Center(child: CupertinoActivityIndicator())
          else if (_versions.isEmpty)
            Text(
              '暂无历史版本',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            )
          else
            for (final version in _versions) ...[
              _GameVersionRow(
                version: version,
                isCurrent: version.version == _currentVersion,
                restoring: _restoring == version.version,
                onRestore: () => _restore(version.version),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _GameVersionRow extends StatelessWidget {
  const _GameVersionRow({
    required this.version,
    required this.isCurrent,
    required this.restoring,
    required this.onRestore,
  });

  final _AdminGameConfigVersion version;
  final bool isCurrent;
  final bool restoring;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final config = version.config;
    final mode = config['mode']?.toString() == 'fixed' ? '固定' : '自适应';
    final base = _adminInt(config['base_strength']);
    final rate = config['target_user_rate'];
    return _AdminCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'v${version.version}',
                style: TextStyle(
                  color: AppColors.of(context).accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$mode · 强度 $base · 目标 ${_formatRate(rate == null ? null : _jsonDouble(rate))}',
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
          const Spacer(),
          if (isCurrent)
            _AdminMiniBadge(text: '当前')
          else
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: Size.zero,
              color: AppColors.of(context).accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              onPressed: restoring ? null : onRestore,
              child: Text(
                restoring ? '恢复中…' : '恢复',
                style: TextStyle(
                  color: AppColors.of(context).accent,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
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

// ===========================================================================
// Tab 2 · 积分等级
// ===========================================================================

class _GameLevelsTab extends StatefulWidget {
  const _GameLevelsTab({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_GameLevelsTab> createState() => _GameLevelsTabState();
}

class _GameLevelsTabState extends State<_GameLevelsTab> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _notice;
  List<_GameLevelTier> _tiers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });
    widget.api.authToken = widget.session.token;
    try {
      final tiers = await widget.api.fetchGameLevels();
      if (!mounted) return;
      setState(() {
        _tiers = tiers;
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

  String? _validate() {
    if (_tiers.isEmpty) return '至少保留一个等级';
    var previous = -1;
    for (final tier in _tiers) {
      if (tier.stageName.trim().isEmpty || tier.tierName.trim().isEmpty) {
        return '大阶段和等级全称不能为空';
      }
      if (tier.upgradePoints < 0 || tier.cumulativePoints < 0) {
        return '积分不能为负数';
      }
      if (tier.cumulativePoints < previous) {
        return '累计总积分必须随等级递增';
      }
      previous = tier.cumulativePoints;
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;
    final invalid = _validate();
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    widget.api.authToken = widget.session.token;
    try {
      final tiers = await widget.api.updateGameLevels(
        _tiers.map((tier) => tier.toPayload()).toList(),
      );
      if (!mounted) return;
      setState(() {
        _tiers = tiers;
        _saving = false;
        _notice = '已保存 ${tiers.length} 个等级。';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _asMessage(error);
      });
    }
  }

  void _addTier() {
    final last = _tiers.isNotEmpty ? _tiers.last : null;
    setState(() {
      _tiers = [
        ..._tiers,
        _GameLevelTier(
          stageName: last?.stageName ?? '',
          tierName: '',
          upgradePoints: 0,
          cumulativePoints: last?.cumulativePoints ?? 0,
        ),
      ];
    });
  }

  void _removeTier(int index) {
    setState(() => _tiers = [..._tiers]..removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _tiers.isEmpty) {
      return const Center(child: CupertinoActivityIndicator(radius: 14));
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
            children: [
              _AdminCard(
                child: Text(
                  '等级按玩家「通过游戏实际获得」的累计积分判定（不含每日赠送与扣减）。'
                  '「累计总积分」是达到该等级所需的累计获得积分门槛，必须随等级递增。',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _tiers.length; i++) ...[
                _LevelTierEditorCard(
                  // ObjectKey ties each row's controllers to the tier instance
                  // so removing a row cannot shift stale text onto other rows.
                  key: ObjectKey(_tiers[i]),
                  index: i,
                  tier: _tiers[i],
                  onChanged: () => setState(() {}),
                  onRemove: () => _removeTier(i),
                ),
                const SizedBox(height: 10),
              ],
              _AdminGamesSecondaryButton(
                label: '+ 添加等级',
                onPressed: _addTier,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _AdminGamesErrorText(_error!),
              ],
              if (_notice != null) ...[
                const SizedBox(height: 12),
                _AdminGamesNoticeText(_notice!),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
            child: _AdminGamesPrimaryButton(
              label: _saving ? '保存中…' : '保存等级',
              onPressed: _saving ? null : _save,
            ),
          ),
        ),
      ],
    );
  }
}

class _LevelTierEditorCard extends StatefulWidget {
  const _LevelTierEditorCard({
    super.key,
    required this.index,
    required this.tier,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _GameLevelTier tier;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  State<_LevelTierEditorCard> createState() => _LevelTierEditorCardState();
}

class _LevelTierEditorCardState extends State<_LevelTierEditorCard> {
  late final TextEditingController _stageCtrl;
  late final TextEditingController _tierCtrl;
  late final TextEditingController _upgradeCtrl;
  late final TextEditingController _cumulativeCtrl;

  @override
  void initState() {
    super.initState();
    _stageCtrl = TextEditingController(text: widget.tier.stageName)
      ..addListener(() {
        widget.tier.stageName = _stageCtrl.text;
        widget.onChanged();
      });
    _tierCtrl = TextEditingController(text: widget.tier.tierName)
      ..addListener(() {
        widget.tier.tierName = _tierCtrl.text;
        widget.onChanged();
      });
    _upgradeCtrl = TextEditingController(text: '${widget.tier.upgradePoints}')
      ..addListener(() {
        widget.tier.upgradePoints = int.tryParse(_upgradeCtrl.text.trim()) ?? 0;
        widget.onChanged();
      });
    _cumulativeCtrl =
        TextEditingController(text: '${widget.tier.cumulativePoints}')
          ..addListener(() {
            widget.tier.cumulativePoints =
                int.tryParse(_cumulativeCtrl.text.trim()) ?? 0;
            widget.onChanged();
          });
  }

  @override
  void dispose() {
    _stageCtrl.dispose();
    _tierCtrl.dispose();
    _upgradeCtrl.dispose();
    _cumulativeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AdminCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AdminMiniBadge(text: '#${widget.index + 1}'),
              const Spacer(),
              GestureDetector(
                onTap: widget.onRemove,
                behavior: HitTestBehavior.opaque,
                child: Icon(
                  CupertinoIcons.delete,
                  size: 18,
                  color: AppColors.of(context).danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _AdminGamesTextField(label: '大阶段', controller: _stageCtrl),
          const SizedBox(height: 10),
          _AdminGamesTextField(label: '等级全称', controller: _tierCtrl),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _AdminGamesNumberField(
                  label: '升级所需积分',
                  controller: _upgradeCtrl,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AdminGamesNumberField(
                  label: '累计总积分',
                  controller: _cumulativeCtrl,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Tab 3 · 积分规则
// ===========================================================================

class _GameRulesTab extends StatefulWidget {
  const _GameRulesTab({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_GameRulesTab> createState() => _GameRulesTabState();
}

class _GameRulesTabState extends State<_GameRulesTab> {
  bool _loading = true;
  String? _error;
  List<_GamePointRule> _rules = const [];

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
    widget.api.authToken = widget.session.token;
    try {
      final rules = await widget.api.fetchGamePointRules();
      if (!mounted) return;
      setState(() {
        _rules = rules;
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

  Future<void> _openEditor(_GamePointRule rule) async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => _GameRuleEditorPage(
          api: widget.api,
          session: widget.session,
          rule: rule,
        ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _rules.isEmpty) {
      return const Center(child: CupertinoActivityIndicator(radius: 14));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        children: [
          if (_error != null) ...[
            _AdminGamesErrorText(_error!),
            const SizedBox(height: 12),
          ],
          for (final rule in _rules) ...[
            _GameRuleCard(rule: rule, onTap: () => _openEditor(rule)),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _GameRuleCard extends StatelessWidget {
  const _GameRuleCard({required this.rule, required this.onTap});

  final _GamePointRule rule;
  final VoidCallback onTap;

  String _summary() {
    if (rule.isMilestone) {
      final milestones = rule.rules['milestones'];
      final count = milestones is List ? milestones.length : 0;
      return '里程碑 · $count 档';
    }
    final win = _adminInt(rule.rules['win']);
    final lose = _adminInt(rule.rules['lose']);
    final quit = _adminInt(rule.rules['quit']);
    return '赢 $win · 输 $lose · 退出 $quit';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: _AdminCard(
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      rule.title,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.text
                            : const Color(0xFF12171B),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (rule.pendingPm) _AdminMiniBadge(text: '待PM设定'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _summary(),
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 积分规则 editor
// ---------------------------------------------------------------------------

class _GameRuleEditorPage extends StatefulWidget {
  const _GameRuleEditorPage({
    required this.api,
    required this.session,
    required this.rule,
  });

  final CompanionApi api;
  final AuthSession session;
  final _GamePointRule rule;

  @override
  State<_GameRuleEditorPage> createState() => _GameRuleEditorPageState();
}

class _GameRuleEditorPageState extends State<_GameRuleEditorPage> {
  bool _saving = false;
  String? _error;
  String? _notice;

  // Outcome fields.
  late final TextEditingController _winCtrl;
  late final TextEditingController _loseCtrl;
  late final TextEditingController _drawCtrl;
  late final TextEditingController _quitCtrl;

  // Milestone fields.
  late List<_MilestoneDraft> _milestones;
  late final TextEditingController _thresholdCtrl;
  late final TextEditingController _belowCtrl;
  late final TextEditingController _atOrAboveCtrl;

  bool get _isMilestone => widget.rule.isMilestone;

  @override
  void initState() {
    super.initState();
    final rules = widget.rule.rules;
    _winCtrl = TextEditingController(text: '${_adminInt(rules['win'])}');
    _loseCtrl = TextEditingController(text: '${_adminInt(rules['lose'])}');
    _drawCtrl = TextEditingController(text: '${_adminInt(rules['draw'])}');
    _quitCtrl = TextEditingController(text: '${_adminInt(rules['quit'])}');

    final milestones = rules['milestones'];
    _milestones = milestones is List
        ? milestones
              .whereType<Map>()
              .map(
                (item) => _MilestoneDraft(
                  tile: _adminInt(item['tile']),
                  points: _adminInt(item['points']),
                ),
              )
              .toList()
        : <_MilestoneDraft>[];
    final quit = rules['quit_below_threshold'];
    final quitMap = quit is Map ? Map<String, dynamic>.from(quit) : const {};
    _thresholdCtrl = TextEditingController(
      text: '${_adminInt(quitMap['threshold'])}',
    );
    _belowCtrl = TextEditingController(text: '${_adminInt(quitMap['below'])}');
    _atOrAboveCtrl = TextEditingController(
      text: '${_adminInt(quitMap['at_or_above'])}',
    );
  }

  @override
  void dispose() {
    _winCtrl.dispose();
    _loseCtrl.dispose();
    _drawCtrl.dispose();
    _quitCtrl.dispose();
    _thresholdCtrl.dispose();
    _belowCtrl.dispose();
    _atOrAboveCtrl.dispose();
    for (final milestone in _milestones) {
      milestone.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic>? _buildRules() {
    if (_isMilestone) {
      final milestones = <Map<String, dynamic>>[];
      var previousTile = -1;
      for (final milestone in _milestones) {
        final tile = int.tryParse(milestone.tileCtrl.text.trim());
        final points = int.tryParse(milestone.pointsCtrl.text.trim());
        if (tile == null || points == null || tile <= 0) {
          setState(() => _error = '里程碑的数字与积分必须为有效整数，且数字大于 0');
          return null;
        }
        if (tile <= previousTile) {
          setState(() => _error = '里程碑数字必须递增');
          return null;
        }
        previousTile = tile;
        milestones.add({'tile': tile, 'points': points});
      }
      if (milestones.isEmpty) {
        setState(() => _error = '至少保留一个里程碑');
        return null;
      }
      final threshold = int.tryParse(_thresholdCtrl.text.trim());
      final below = int.tryParse(_belowCtrl.text.trim());
      final atOrAbove = int.tryParse(_atOrAboveCtrl.text.trim());
      if (threshold == null || below == null || atOrAbove == null) {
        setState(() => _error = '中途退出规则必须为有效整数');
        return null;
      }
      final result = <String, dynamic>{
        'type': 'milestone',
        'milestones': milestones,
        'quit_below_threshold': {
          'threshold': threshold,
          'below': below,
          'at_or_above': atOrAbove,
        },
      };
      if (widget.rule.pendingPm) result['pending_pm'] = true;
      return result;
    }
    final win = int.tryParse(_winCtrl.text.trim());
    final lose = int.tryParse(_loseCtrl.text.trim());
    final draw = int.tryParse(_drawCtrl.text.trim());
    final quit = int.tryParse(_quitCtrl.text.trim());
    if (win == null || lose == null || draw == null || quit == null) {
      setState(() => _error = '请填写有效的整数');
      return null;
    }
    final result = <String, dynamic>{
      'type': 'outcome',
      'win': win,
      'lose': lose,
      'draw': draw,
      'quit': quit,
    };
    if (widget.rule.pendingPm) result['pending_pm'] = true;
    return result;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _error = null;
      _notice = null;
    });
    final rules = _buildRules();
    if (rules == null) return;
    setState(() => _saving = true);
    widget.api.authToken = widget.session.token;
    try {
      await widget.api.updateGamePointRule(widget.rule.gameKey, rules);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _notice = '积分规则已保存。';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _asMessage(error);
      });
    }
  }

  void _addMilestone() {
    final last = _milestones.isNotEmpty ? _milestones.last : null;
    final nextTile = last == null
        ? 128
        : (int.tryParse(last.tileCtrl.text.trim()) ?? 64) * 2;
    setState(() {
      _milestones = [..._milestones, _MilestoneDraft(tile: nextTile, points: 0)];
    });
  }

  void _removeMilestone(int index) {
    setState(() {
      final removed = _milestones[index];
      _milestones = [..._milestones]..removeAt(index);
      removed.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return _AdminScaffold(
      title: widget.rule.title,
      subtitle: _isMilestone ? '里程碑积分规则' : '每局积分规则',
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        children: [
          if (_isMilestone)
            ..._buildMilestoneEditor()
          else
            ..._buildOutcomeEditor(),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _AdminGamesErrorText(_error!),
          ],
          if (_notice != null) ...[
            const SizedBox(height: 12),
            _AdminGamesNoticeText(_notice!),
          ],
          const SizedBox(height: 16),
          _AdminGamesPrimaryButton(
            label: _saving ? '保存中…' : '保存规则',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOutcomeEditor() {
    return [
      _AdminCard(
        child: Column(
          children: [
            _AdminGamesNumberField(
              label: '赢（获胜获得的积分）',
              controller: _winCtrl,
              signed: true,
            ),
            const SizedBox(height: 12),
            _AdminGamesNumberField(
              label: '输（可为负）',
              controller: _loseCtrl,
              signed: true,
            ),
            const SizedBox(height: 12),
            _AdminGamesNumberField(
              label: '平局',
              controller: _drawCtrl,
              signed: true,
            ),
            const SizedBox(height: 12),
            _AdminGamesNumberField(
              label: '中途退出（可为负）',
              controller: _quitCtrl,
              signed: true,
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildMilestoneEditor() {
    return [
      _AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _AdminGamesSectionHeader('里程碑（达到的最大数字 → 积分）'),
            const SizedBox(height: 10),
            for (var i = 0; i < _milestones.length; i++) ...[
              Row(
                children: [
                  Expanded(
                    child: _AdminGamesNumberField(
                      label: '数字',
                      controller: _milestones[i].tileCtrl,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AdminGamesNumberField(
                      label: '积分',
                      controller: _milestones[i].pointsCtrl,
                      signed: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _removeMilestone(i),
                    behavior: HitTestBehavior.opaque,
                    child: Icon(
                      CupertinoIcons.delete,
                      size: 18,
                      color: AppColors.of(context).danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            _AdminGamesSecondaryButton(
              label: '+ 添加里程碑',
              onPressed: _addMilestone,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _AdminGamesSectionHeader('中途退出规则'),
            const SizedBox(height: 10),
            _AdminGamesNumberField(label: '分界数字', controller: _thresholdCtrl),
            const SizedBox(height: 12),
            _AdminGamesNumberField(
              label: '低于分界扣减（可为负）',
              controller: _belowCtrl,
              signed: true,
            ),
            const SizedBox(height: 12),
            _AdminGamesNumberField(
              label: '达到分界及以上',
              controller: _atOrAboveCtrl,
              signed: true,
            ),
          ],
        ),
      ),
    ];
  }
}

class _MilestoneDraft {
  _MilestoneDraft({required int tile, required int points})
    : tileCtrl = TextEditingController(text: '$tile'),
      pointsCtrl = TextEditingController(text: '$points');

  final TextEditingController tileCtrl;
  final TextEditingController pointsCtrl;

  void dispose() {
    tileCtrl.dispose();
    pointsCtrl.dispose();
  }
}

// ===========================================================================
// Tab 4 · 积分管理 (流水 + 官方赠送)
// ===========================================================================

class _GamePointsLedgerTab extends StatefulWidget {
  const _GamePointsLedgerTab({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_GamePointsLedgerTab> createState() => _GamePointsLedgerTabState();
}

class _GamePointsLedgerTabState extends State<_GamePointsLedgerTab> {
  static const int _pageSize = 20;
  final _filterCtrl = TextEditingController();

  int _page = 0;
  String _appliedFilter = '';
  bool _loading = true;
  String? _error;
  String? _notice;
  List<_AdminGamePointLedgerItem> _items = const [];

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
      final items = await widget.api.fetchGamePointLedger(
        userId: _appliedFilter.isEmpty ? null : _appliedFilter,
        limit: _pageSize,
        offset: _page * _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _openGrant() async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) =>
          _GrantPointsDialog(api: widget.api, session: widget.session),
    );
    if (!mounted || message == null) return;
    setState(() {
      _notice = message;
      _page = 0;
    });
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
                _AdminGamesPrimaryButton(label: '积分赠送', onPressed: _openGrant),
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
                              label: '查询',
                              onPressed: _applyFilter,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _AdminGamesSecondaryButton(
                              label: '全部',
                              onPressed: _resetFilter,
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
                    '暂无积分变更记录',
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
                    _LedgerRowCard(item: item),
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
                    onPressed: (_items.length < _pageSize || _loading)
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

class _LedgerRowCard extends StatelessWidget {
  const _LedgerRowCard({required this.item});

  final _AdminGamePointLedgerItem item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final positive = item.delta >= 0;
    final deltaColor = positive
        ? const Color(0xFF1FA97A)
        : AppColors.of(context).danger;
    return _AdminCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? AppColors.text : const Color(0xFF12171B),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (item.levelUp) _AdminMiniBadge(text: '升级'),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.sourceLabel} · ${item.createdAt.replaceFirst("T", " ").split(".").first}',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
                if (item.levelName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '等级 ${item.levelName}',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                positive ? '+${item.delta}' : '${item.delta}',
                style: TextStyle(
                  color: deltaColor,
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
    );
  }
}

// ===========================================================================
// 积分赠送 modal — fuzzy user search + amount + note (mirrors web modal)
// ===========================================================================

class _GrantPointsDialog extends StatefulWidget {
  const _GrantPointsDialog({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_GrantPointsDialog> createState() => _GrantPointsDialogState();
}

class _GrantPointsDialogState extends State<_GrantPointsDialog> {
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
    _debounce?.cancel();
    final query = _queryCtrl.text.trim();
    // Any keystroke clears the current selection so search + pick stay in sync.
    if (_selected != null) {
      setState(() => _selected = null);
    }
    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 300), () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    final seq = ++_searchSeq;
    widget.api.authToken = widget.session.token;
    try {
      final rows = await widget.api.searchGamePointUsers(query);
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _results = rows;
        _searching = false;
      });
    } catch (error) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _error = _asMessage(error);
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

  Future<void> _grant() async {
    if (_granting) return;
    final selected = _selected;
    final amount = int.tryParse(_amountCtrl.text.trim());
    if (selected == null) {
      setState(() => _error = '请先搜索并选择用户');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = '赠送积分必须是正整数');
      return;
    }
    setState(() {
      _granting = true;
      _error = null;
    });
    widget.api.authToken = widget.session.token;
    try {
      final balance = await widget.api.grantGamePoints(
        userId: selected.userId,
        amount: amount,
        note: _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        '已为 ${selected.displayName} 赠送 $amount 积分，当前余额 $balance（等级不变）。',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _granting = false;
        _error = _asMessage(error);
      });
    }
  }

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
            const _AdminGamesSectionHeader('积分赠送'),
            const SizedBox(height: 4),
            Text(
              '搜索并选择用户后赠送积分；仅增加余额，不改变游戏等级。',
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
            _AdminGamesTextField(
              label: '搜索用户（用户名 / ID / 微信昵称）',
              controller: _queryCtrl,
            ),
            const SizedBox(height: 10),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_selected != null)
                      _SelectedUserChip(
                        item: _selected!,
                        onClear: () => setState(() => _selected = null),
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
                      label: '赠送积分',
                      controller: _amountCtrl,
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
            const SizedBox(height: 14),
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
                    label: _granting ? '赠送中…' : '确认赠送',
                    onPressed: _granting ? null : _grant,
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

class _SelectedUserChip extends StatelessWidget {
  const _SelectedUserChip({required this.item, required this.onClear});

  final _AdminUserSearchItem item;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.of(context).accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
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
                    color: accent,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.userId,
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
          GestureDetector(
            onTap: onClear,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '重新选择',
                style: TextStyle(
                  color: accent,
                  fontSize: 12,
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

class _UserSearchResults extends StatelessWidget {
  const _UserSearchResults({
    required this.searching,
    required this.results,
    required this.query,
    required this.onSelect,
  });

  final bool searching;
  final List<_AdminUserSearchItem> results;
  final String query;
  final ValueChanged<_AdminUserSearchItem> onSelect;

  @override
  Widget build(BuildContext context) {
    if (searching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Center(child: CupertinoActivityIndicator(radius: 10)),
      );
    }
    if (query.isEmpty) {
      return _hint('输入关键字搜索用户');
    }
    if (results.isEmpty) {
      return _hint('未找到匹配的用户');
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < results.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            _UserResultRow(item: results[i], onTap: () => onSelect(results[i])),
          ],
        ],
      ),
    );
  }

  Widget _hint(String text) {
    return Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

class _UserResultRow extends StatelessWidget {
  const _UserResultRow({required this.item, required this.onTap});

  final _AdminUserSearchItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? AppColors.text : const Color(0xFF12171B),
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.userId,
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
    );
  }
}

// ===========================================================================
// Shared small widgets
// ===========================================================================

String _formatRate(double? rate) {
  if (rate == null) return '--';
  return '${(rate * 100).toStringAsFixed(1)}%';
}

class _AdminGamesFieldLabel extends StatelessWidget {
  const _AdminGamesFieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        decoration: TextDecoration.none,
      ),
    );
  }
}

class _AdminGamesSectionHeader extends StatelessWidget {
  const _AdminGamesSectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        color: isDark ? AppColors.text : const Color(0xFF12171B),
        fontSize: 14,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
        decoration: TextDecoration.none,
      ),
    );
  }
}

class _AdminGamesTextField extends StatelessWidget {
  const _AdminGamesTextField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AdminGamesFieldLabel(label),
        const SizedBox(height: 6),
        _AdminGamesInputBox(child: CupertinoTextField(
          controller: controller,
          decoration: const BoxDecoration(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          style: _adminInputStyle(context),
        )),
      ],
    );
  }
}

class _AdminGamesNumberField extends StatelessWidget {
  const _AdminGamesNumberField({
    required this.label,
    required this.controller,
    this.signed = false,
    this.decimal = false,
  });

  final String label;
  final TextEditingController controller;
  final bool signed;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    final field = CupertinoTextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(
        signed: signed,
        decimal: decimal,
      ),
      decoration: const BoxDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      style: _adminInputStyle(context),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AdminGamesFieldLabel(label),
        const SizedBox(height: 6),
        _AdminGamesInputBox(
          // iOS's numeric keypad has no minus key, so signed fields (输/中途退出/
          // 里程碑积分 等可为负) get a ± toggle that flips the leading sign.
          child: signed
              ? Row(
                  children: [
                    _SignToggleButton(controller: controller),
                    Expanded(child: field),
                  ],
                )
              : field,
        ),
      ],
    );
  }
}

class _SignToggleButton extends StatelessWidget {
  const _SignToggleButton({required this.controller});

  final TextEditingController controller;

  void _toggle() {
    final text = controller.text;
    final next = text.startsWith('-') ? text.substring(1) : '-$text';
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _toggle,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.10),
            ),
          ),
        ),
        child: Text(
          '±',
          style: TextStyle(
            color: AppColors.of(context).accent,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

class _AdminGamesMultilineField extends StatelessWidget {
  const _AdminGamesMultilineField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _AdminGamesInputBox(
      child: CupertinoTextField(
        controller: controller,
        maxLines: 8,
        minLines: 4,
        decoration: const BoxDecoration(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        style: _adminInputStyle(context).copyWith(
          fontFamily: 'monospace',
          fontSize: 12.5,
        ),
      ),
    );
  }
}

class _AdminGamesReadonlyJson extends StatelessWidget {
  const _AdminGamesReadonlyJson({required this.label, required this.value});

  final String label;
  final Map<String, dynamic> value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AdminGamesFieldLabel(label),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.24)
                : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            const JsonEncoder.withIndent('  ').convert(value),
            style: TextStyle(
              color: isDark ? const Color(0xC8EBF2EE) : const Color(0xFF3A4350),
              fontSize: 12,
              fontFamily: 'monospace',
              height: 1.4,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }
}

TextStyle _adminInputStyle(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return TextStyle(
    color: isDark ? AppColors.text : const Color(0xFF12171B),
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    decoration: TextDecoration.none,
  );
}

class _AdminGamesInputBox extends StatelessWidget {
  const _AdminGamesInputBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.10),
        ),
      ),
      child: child,
    );
  }
}

class _AdminGamesPrimaryButton extends StatelessWidget {
  const _AdminGamesPrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.of(context).accent;
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 14),
        color: accent,
        borderRadius: BorderRadius.circular(16),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

class _AdminGamesSecondaryButton extends StatelessWidget {
  const _AdminGamesSecondaryButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.of(context).accent;
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 12),
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        onPressed: onPressed,
        child: Text(
          label,
          style: TextStyle(
            color: accent,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

class _AdminGamesErrorText extends StatelessWidget {
  const _AdminGamesErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.of(context).danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.of(context).danger.withValues(alpha: 0.24),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.of(context).danger,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _AdminGamesNoticeText extends StatelessWidget {
  const _AdminGamesNoticeText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF1FA97A);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: green.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: green.withValues(alpha: 0.24)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: green,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
