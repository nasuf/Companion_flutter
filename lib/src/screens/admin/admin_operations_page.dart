part of 'package:companion_flutter/main.dart';

// ===========================================================================
// 运营管理 (Operations)
// ===========================================================================

class _AdminOperationsPage extends StatefulWidget {
  const _AdminOperationsPage({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_AdminOperationsPage> createState() => _AdminOperationsPageState();
}

class _AdminOperationsPageState extends State<_AdminOperationsPage> {
  int _days = 7;
  bool _loading = false;
  String? _error;
  _TokenUsageStats? _token;
  _OperationsStats? _ops;
  _MediaUsageStats? _media;
  int _loadSeq = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final seq = ++_loadSeq;
    setState(() => _loading = true);
    try {
      widget.api.authToken = widget.session.token;
      final results = await Future.wait([
        widget.api.fetchTokenUsage(days: _days),
        widget.api.fetchOperationsStats(days: _days),
        widget.api.fetchMediaUsage(days: _days),
      ]);
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _token = results[0] as _TokenUsageStats;
        _ops = results[1] as _OperationsStats;
        _media = results[2] as _MediaUsageStats;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _error = _asMessage(error);
        _loading = false;
      });
    }
  }

  void _changeWindow(int days) {
    if (days == _days) return;
    setState(() => _days = days);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return _AdminScaffold(
      title: '运营管理',
      subtitle: 'LLM 成本与系统健康',
      trailing: _loading
          ? const Padding(
              padding: EdgeInsets.only(right: 4),
              child: CupertinoActivityIndicator(radius: 10),
            )
          : _AppNavCircleButton(icon: CupertinoIcons.refresh, onPressed: _load),
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    final token = _token;
    final ops = _ops;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
      children: [
        _AdminSegment<int>(
          value: _days,
          options: const [
            MapEntry(3, '近3天'),
            MapEntry(7, '近7天'),
            MapEntry(30, '近30天'),
            MapEntry(0, '全部'),
          ],
          onChanged: _changeWindow,
        ),
        const SizedBox(height: 16),
        if (_error != null && token == null)
          _AdminStatePanel(
            title: '加载失败',
            message: _error!,
            actionText: '重试',
            onTap: _load,
          )
        else if (token == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CupertinoActivityIndicator(radius: 14)),
          )
        else ...[
          _buildCostKpis(token, _media),
          ...() {
            final nonToken = _buildNonTokenCost(token, _media);
            return nonToken == null
                ? const <Widget>[]
                : <Widget>[
                    const SizedBox(height: 12),
                    _AdminCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _AdminSectionTitle(
                            title: '非 Token 计费项 (按次 / 按时长)',
                          ),
                          nonToken,
                        ],
                      ),
                    ),
                  ];
          }(),
          const SizedBox(height: 16),
          _AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AdminSectionTitle(
                  title: '每日费用走势',
                  trailing:
                      token.window.start != null && token.window.end != null
                      ? Text(
                          '${_fmtMmDd(token.window.start!)} → ${_fmtMmDd(token.window.end!)}',
                          style: TextStyle(
                            color: AppColors.of(context).muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        )
                      : null,
                ),
                _AdminAreaChart(points: token.daily, color: _chartColors[3]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _AdminSectionTitle(title: '模型分布 (按实际计费)'),
                _AdminDonut(byModel: token.byModel),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _AdminSectionTitle(title: '媒体用量 (语音 / 图片)'),
                if (_media == null)
                  const _AdminInlineHint(text: '暂无媒体用量数据', height: 80)
                else
                  _buildMediaUsage(_media!),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _AdminSectionTitle(title: '系统健康'),
                if (ops == null)
                  const _AdminInlineHint(text: '暂无运营指标', height: 80)
                else
                  _buildSystemHealth(ops),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Aggregate tiles only — per-user breakdown lives in the web admin
  // console (paginated table), per product decision 2026-07-23.
  Widget _buildMediaUsage(_MediaUsageStats media) {
    return _AdminStatGrid(
      tiles: [
        _AdminStatTile(
          label: '用户语音消息',
          value: _fmtFull(media.voiceCount),
          sub: '条',
        ),
        _AdminStatTile(
          label: '用户语音时长',
          value: _fmtMediaDuration(media.voiceSeconds),
          sub: '发出语音 · 共 ${_fmtFull(media.voiceSeconds)} 秒',
        ),
        _AdminStatTile(
          label: '语音转文字时长',
          value: _fmtMediaDuration(media.voiceTextSeconds),
          sub:
              '${_fmtFull(media.voiceTextCount)} 次 · 共 ${_fmtFull(media.voiceTextSeconds)} 秒',
        ),
        _AdminStatTile(label: '语音总大小', value: _fmtMediaBytes(media.voiceBytes)),
        _AdminStatTile(
          label: '图片消息',
          value: _fmtFull(media.imageCount),
          sub: '张',
        ),
        _AdminStatTile(
          label: '图片总大小',
          value: _fmtMediaBytes(media.imageBytes),
          sub: '图片理解按 token 计费',
        ),
        _AdminStatTile(
          label: 'Agent 语音输出',
          value: _fmtFull(media.ttsCount),
          sub: '条',
        ),
        _AdminStatTile(
          label: 'Agent 语音时长',
          value: _fmtMediaDuration((media.ttsMilliseconds / 1000).round()),
          sub: '${_fmtFull(media.ttsBillableCharacters)} 计费字符',
        ),
        _AdminStatTile(
          label: 'Agent 语音费用',
          value: '¥${media.ttsCostCny.toStringAsFixed(4)}',
          sub: _fmtMediaBytes(media.ttsBytes),
          accent: media.ttsCostCny > 0,
        ),
      ],
    );
  }

  /// 联网插件 (按次) + 语音识别 (按秒) — 两项都不在 token 价目表里.
  ///
  /// 插件的免费额度按自然月重置, 所以它的次数和费用是本月累计, 不跟随时间窗,
  /// 也因此没有并进上面的合计; 语音识别跟时间窗一致, 已并入合计.
  /// 图片理解虽然同属曾经漏记的支出, 但它本身按 token 计价, 已并入模型分布,
  /// 这里不重复展示.
  Widget? _buildNonTokenCost(_TokenUsageStats token, _MediaUsageStats? media) {
    final search = token.webSearch;
    final hasSearch = search != null && search.monthCalls > 0;
    final hasAsr = media != null && media.asrSeconds > 0;
    final hasTts = media != null && media.ttsCount > 0;
    if (!hasSearch && !hasAsr && !hasTts) return null;

    return _AdminStatGrid(
      tiles: [
        if (hasSearch) ...[
          _AdminStatTile(
            label: '联网搜索 (本月累计)',
            value: _fmtFull(search.monthCalls),
            sub:
                '本窗口 ${_fmtFull(search.windowCalls)} 次 · 免费额度剩 ${_fmtFull(search.freeRemaining)} 次',
          ),
          _AdminStatTile(
            label: '联网搜索费用 (本月)',
            value: '¥${search.costCny.toStringAsFixed(4)}',
            sub: search.billableCalls > 0
                ? '超额 ${_fmtFull(search.billableCalls)} 次 · ¥${search.pricePerK}/千次 · 按月结算不计入合计'
                : '未超免费额度 · ¥${search.pricePerK}/千次',
            accent: search.billableCalls > 0,
          ),
        ],
        if (hasAsr) ...[
          _AdminStatTile(
            label: '语音识别时长',
            value: _fmtMediaDuration(media.asrSeconds),
            sub: '${_fmtFull(media.asrCount)} 次转写',
          ),
          _AdminStatTile(
            label: '语音识别费用',
            value: media.asrCostCny == null
                ? '未配置单价'
                : '¥${media.asrCostCny!.toStringAsFixed(4)}',
            sub: media.asrCostCny == null
                ? '配置 ASR_PRICE_CNY_PER_SECOND 后显示'
                : '¥${media.asrPricePerSecond}/秒 · 估算',
            accent: (media.asrCostCny ?? 0) > 0,
          ),
        ],
        if (hasTts) ...[
          _AdminStatTile(
            label: 'Agent 语音输出时长',
            value: _fmtMediaDuration((media.ttsMilliseconds / 1000).round()),
            sub: '${_fmtFull(media.ttsCount)} 条',
          ),
          _AdminStatTile(
            label: 'Agent 语音输出费用',
            value: '¥${media.ttsCostCny.toStringAsFixed(4)}',
            sub: '${_fmtFull(media.ttsBillableCharacters)} 计费字符',
            accent: media.ttsCostCny > 0,
          ),
        ],
      ],
    );
  }

  Widget _buildCostKpis(_TokenUsageStats token, _MediaUsageStats? media) {
    final totals = token.totals;
    final avgPerRequest = totals.requestCount > 0
        ? totals.costCny / totals.requestCount
        : 0.0;
    // 语音识别按秒计价, 跟 token 用的是同一个时间窗, 可以直接加进合计.
    // 联网插件**不能**加 —— 它的免费额度按自然月重置, 费用只能按本月累计算,
    // 混进窗口口径的合计里会得到一个两种时间尺度相加的数字.
    final asrCost = media?.asrCostCny ?? 0;
    final ttsCost = media?.ttsCostCny ?? 0;
    final extraCost = asrCost + ttsCost;
    return _AdminStatGrid(
      tiles: [
        _AdminStatTile(label: '请求次数', value: _fmtFull(totals.requestCount)),
        _AdminStatTile(label: 'LLM 调用次数', value: _fmtFull(totals.callCount)),
        _AdminStatTile(
          label: '输入 token',
          value: _fmtCompact(totals.inputTokens),
        ),
        _AdminStatTile(
          label: '输出 token',
          value: _fmtCompact(totals.outputTokens),
        ),
        _AdminStatTile(
          label: '缓存命中率',
          value: totals.cacheHitRate != null
              ? '${(totals.cacheHitRate! * 100).toStringAsFixed(1)}%'
              : '—',
          sub: totals.cachedInputTokens > 0
              ? '命中 ${_fmtCompact(totals.cachedInputTokens)} tok'
              : 'provider prefix cache',
        ),
        _AdminStatTile(
          label: '合计费用 (元)',
          value: '¥${(totals.costCny + extraCost).toStringAsFixed(4)}',
          sub: extraCost > 0
              ? 'Token ¥${totals.costCny.toStringAsFixed(4)} + ASR ¥${asrCost.toStringAsFixed(4)} + TTS ¥${ttsCost.toStringAsFixed(4)}'
              : totals.requestCount > 0
              ? '均 ¥${avgPerRequest.toStringAsFixed(6)}/请求'
              : null,
          accent: true,
        ),
      ],
    );
  }

  Widget _buildSystemHealth(_OperationsStats ops) {
    final visibleRate = (ops.avgVisibleUseRate * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AdminStatGrid(
          tiles: [
            _AdminStatTile(
              label: '记忆写入',
              value: _fmtFull(ops.memoryStored),
              sub: '召回 ${_fmtFull(ops.memoryRetrieval)}',
            ),
            _AdminStatTile(
              label: 'LLM fallback',
              value: _fmtFull(ops.fallbackCount),
              sub: '均延迟 ${_fmtMs(ops.avgLatencyMs)}',
              warn: ops.hasLlmRisk,
            ),
            _AdminStatTile(
              label: '主动消息',
              value: _fmtFull(ops.proactiveSent),
              sub: '跳过 ${_fmtFull(ops.proactiveSkipped)}',
            ),
            _AdminStatTile(
              label: '可见使用率',
              value: '$visibleRate%',
              sub:
                  '${_fmtFull(ops.visiblyUsed)} / ${_fmtFull(ops.visibleInjected)} 条',
              warn: ops.unsupportedReference > 0,
            ),
            _AdminStatTile(
              label: '危机事件',
              value: _fmtFull(ops.crisisCreated),
              sub: '高危 ${_fmtFull(ops.crisisHigh)}',
              warn: ops.crisisHigh > 0,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _AdminHealthBlock(
          title: 'LLM 运行',
          warn: ops.hasLlmRisk,
          rows: [
            MapEntry('平均延迟', _fmtMs(ops.avgLatencyMs)),
            MapEntry('失败次数', _fmtFull(ops.failureCount)),
            MapEntry('熔断次数', _fmtFull(ops.circuitOpenCount)),
          ],
        ),
        const SizedBox(height: 10),
        _AdminHealthBlock(
          title: '主动交流',
          rows: [
            MapEntry('等待用户', _fmtFull(ops.proactiveWaiting)),
            MapEntry('已发送', _fmtFull(ops.proactiveSent)),
            MapEntry('已跳过', _fmtFull(ops.proactiveSkipped)),
          ],
        ),
        const SizedBox(height: 10),
        _AdminHealthBlock(
          title: '运行队列',
          warn: !ops.redisAvailable,
          rows: [
            MapEntry('Redis', ops.redisAvailable ? '正常' : '不可用'),
            MapEntry('待执行', _fmtFull(ops.jobsReady)),
            MapEntry('延迟中', _fmtFull(ops.jobsDelayed)),
            MapEntry('执行中', _fmtFull(ops.jobsRunning)),
          ],
        ),
      ],
    );
  }
}

class _AdminHealthBlock extends StatelessWidget {
  const _AdminHealthBlock({
    required this.title,
    required this.rows,
    this.warn = false,
  });

  final String title;
  final List<MapEntry<String, String>> rows;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: warn
              ? colors.danger.withValues(alpha: 0.28)
              : isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0x14181F2A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isDark ? AppColors.text : const Color(0xFF12171B),
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 8),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3.5),
              child: Row(
                children: [
                  Text(
                    row.key,
                    style: TextStyle(
                      color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    row.value,
                    style: TextStyle(
                      color: isDark ? AppColors.text : const Color(0xFF12171B),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ===========================================================================
// 全局模块开关 (offline modules / web search / TTS / achievement)
// ===========================================================================

class _AdminGlobalModuleSettingsPage extends StatefulWidget {
  const _AdminGlobalModuleSettingsPage({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_AdminGlobalModuleSettingsPage> createState() =>
      _AdminGlobalModuleSettingsPageState();
}

class _AdminGlobalModuleSettingsPageState
    extends State<_AdminGlobalModuleSettingsPage> {
  bool _loading = true;
  String? _error;
  _OfflineSettings? _offline;
  _AchievementSettings? _achievement;
  // Runtime config bundle (from /admin-api/runtime-config) — carries the
  // web_search_enabled flag managed on this page.
  _RuntimeConfigBundle? _runtime;
  String? _savingKey; // activity | gift | achievement | websearch | tts

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
    // Independent groups: one failing must not blank the others.
    final results = await Future.wait([
      widget.api
          .fetchOfflineSettings()
          .then<Object?>((v) => v)
          .catchError((e) => e),
      widget.api
          .fetchAchievementSettings()
          .then<Object?>((v) => v)
          .catchError((e) => e),
      widget.api
          .fetchAdminRuntimeConfig()
          .then<Object?>((v) => v)
          .catchError((e) => e),
    ]);
    if (!mounted) return;
    final offlineResult = results[0];
    final achievementResult = results[1];
    final runtimeResult = results[2];
    String? error;
    setState(() {
      if (offlineResult is _OfflineSettings) {
        _offline = offlineResult;
      } else {
        error = _asMessage(offlineResult as Object);
      }
      if (achievementResult is _AchievementSettings) {
        _achievement = achievementResult;
      } else {
        error ??= _asMessage(achievementResult as Object);
      }
      if (runtimeResult is _RuntimeConfigBundle) {
        _runtime = runtimeResult;
      } else {
        error ??= _asMessage(runtimeResult as Object);
      }
      _error = error;
      _loading = false;
    });
  }

  bool get _webSearchEnabled {
    final runtime = _runtime;
    if (runtime == null) return false;
    final configured = runtime.config['web_search_enabled'];
    if (configured is bool) return configured;
    return runtime.resolved['web_search_enabled'] == true;
  }

  int get _ttsOutputProbability {
    final runtime = _runtime;
    if (runtime == null) return 0;
    final configured = runtime.config['tts_output_probability'];
    if (configured is num) return configured.round().clamp(0, 100).toInt();
    final resolved = runtime.resolved['tts_output_probability'];
    return resolved is num ? resolved.round().clamp(0, 100).toInt() : 0;
  }

  Future<void> _patchRuntimeConfig(
    Map<String, dynamic> patch, {
    required String savingKey,
  }) async {
    final runtime = _runtime;
    if (runtime == null || _savingKey != null) return;
    setState(() {
      _savingKey = savingKey;
      _error = null;
    });
    try {
      widget.api.authToken = widget.session.token;
      final updated = await widget.api.updateAdminRuntimeConfig(patch);
      if (!mounted) return;
      setState(() {
        _runtime = updated;
        _savingKey = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _asMessage(error);
        _savingKey = null;
      });
    }
  }

  Future<void> _toggleWebSearch(bool next) async {
    await _patchRuntimeConfig(
      {'web_search_enabled': next},
      savingKey: 'websearch',
    );
  }

  Future<void> _changeTtsProbability(int next) async {
    final runtime = _runtime;
    if (runtime == null || _savingKey != null) return;
    final probability = next.clamp(0, 100).toInt();
    final previous = runtime;
    setState(() {
      _savingKey = 'tts';
      _error = null;
      _runtime = _RuntimeConfigBundle(
        config: {...runtime.config, 'tts_output_probability': probability},
        resolved: {...runtime.resolved, 'tts_output_probability': probability},
      );
    });
    try {
      widget.api.authToken = widget.session.token;
      final updated = await widget.api.updateAdminTtsProbability(probability);
      if (!mounted) return;
      setState(() {
        _runtime = updated;
        _savingKey = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _runtime = previous;
        _error = _asMessage(error);
        _savingKey = null;
      });
    }
  }

  Future<void> _toggleOffline({
    required bool isActivity,
    required bool next,
  }) async {
    final current = _offline;
    if (current == null || _savingKey != null) return;
    final key = isActivity ? 'activity' : 'gift';
    final previous = current;
    setState(() {
      _savingKey = key;
      _error = null;
      _offline = isActivity
          ? current.copyWith(activityEnabled: next)
          : current.copyWith(giftEnabled: next);
    });
    try {
      widget.api.authToken = widget.session.token;
      final updated = await widget.api.updateOfflineSettings(
        activityEnabled: isActivity ? next : null,
        giftEnabled: isActivity ? null : next,
      );
      if (!mounted) return;
      setState(() {
        _offline = updated;
        _savingKey = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _offline = previous; // revert on failure
        _error = _asMessage(error);
        _savingKey = null;
      });
    }
  }

  Future<void> _changeAchievement(String next) async {
    final current = _achievement;
    if (current == null ||
        _savingKey != null ||
        current.effectiveMode == next) {
      return;
    }
    final previous = current;
    setState(() {
      _savingKey = 'achievement';
      _error = null;
      _achievement = _AchievementSettings(
        mode: next,
        envMode: current.envMode,
        effectiveMode: next,
      );
    });
    try {
      widget.api.authToken = widget.session.token;
      final updated = await widget.api.updateAchievementSettings(next);
      if (!mounted) return;
      setState(() {
        _achievement = updated;
        _savingKey = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _achievement = previous; // revert on failure
        _error = _asMessage(error);
        _savingKey = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AdminScaffold(
      title: '全局模块开关',
      subtitle: '线下 / 联网 / 语音 / 成就 · 切换即保存',
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _offline == null && _achievement == null) {
      return const Center(child: CupertinoActivityIndicator(radius: 14));
    }
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
      children: [
        _AdminCard(
          child: Text(
            '控制线下模块主动推送、联网搜索、语音输出与成就系统运行模式，切换后即时保存。'
            '已产生的条目及其查看 / 操作不受影响。',
            style: TextStyle(
              color: AppColors.isDark(context)
                  ? const Color(0x9EEBF2EE)
                  : AppColors.muted,
              fontSize: 12.5,
              height: 1.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _AdminFlagCard(
          marker: '活',
          title: '线下活动推荐',
          badge: '主动推送',
          description: '定时向用户推送线下活动邀约与活动卡片。关闭后不再主动生成推荐，手动触发接口也会拒绝创建。',
          scope: '定时任务 · 邀约消息 · 活动卡片',
          enabled: _offline?.activityEnabled ?? false,
          saving: _savingKey == 'activity',
          disabled:
              _offline == null ||
              (_savingKey != null && _savingKey != 'activity'),
          onChanged: (next) => _toggleOffline(isActivity: true, next: next),
        ),
        const SizedBox(height: 12),
        _AdminFlagCard(
          marker: '礼',
          title: '礼物推荐',
          badge: '主动推送',
          description: '定时触发礼物赠送并推进物流卡片。关闭后不再生成新礼物、暂停到货刷新，管理端 mock 接口也会被拒绝。',
          scope: '定时任务 · 礼物生成 · 物流卡片',
          enabled: _offline?.giftEnabled ?? false,
          saving: _savingKey == 'gift',
          disabled:
              _offline == null || (_savingKey != null && _savingKey != 'gift'),
          onChanged: (next) => _toggleOffline(isActivity: false, next: next),
        ),
        const SizedBox(height: 12),
        _AdminFlagCard(
          marker: '网',
          title: '联网搜索',
          badge: '豆包主回复',
          description:
              '开启后豆包主回复自动联网获取时效信息（天气、新闻等），模型按需触发、按次计费；闲聊不触发搜索。搜索失败自动回退普通回复。仅当大模型路由为火山方舟/豆包时生效。',
          scope: '主回复生成 · 方舟 Responses API · 实时信息',
          enabled: _webSearchEnabled,
          saving: _savingKey == 'websearch',
          disabled:
              _runtime == null ||
              (_savingKey != null && _savingKey != 'websearch'),
          onChanged: _toggleWebSearch,
        ),
        const SizedBox(height: 12),
        _AdminTtsProbabilityCard(
          value: _ttsOutputProbability,
          saving: _savingKey == 'tts',
          disabled:
              _runtime == null || (_savingKey != null && _savingKey != 'tts'),
          onChanged: _changeTtsProbability,
        ),
        const SizedBox(height: 12),
        _AdminAchievementCard(
          settings: _achievement,
          saving: _savingKey == 'achievement',
          disabled:
              _achievement == null ||
              (_savingKey != null && _savingKey != 'achievement'),
          onChanged: _changeAchievement,
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(
            _error!,
            style: TextStyle(
              color: AppColors.of(context).danger,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ],
    );
  }
}

class _AdminTtsProbabilityCard extends StatefulWidget {
  const _AdminTtsProbabilityCard({
    required this.value,
    required this.saving,
    required this.disabled,
    required this.onChanged,
  });

  final int value;
  final bool saving;
  final bool disabled;
  final ValueChanged<int> onChanged;

  @override
  State<_AdminTtsProbabilityCard> createState() =>
      _AdminTtsProbabilityCardState();
}

class _AdminTtsProbabilityCardState extends State<_AdminTtsProbabilityCard> {
  late double _draft = widget.value.toDouble();

  @override
  void didUpdateWidget(covariant _AdminTtsProbabilityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _draft = widget.value.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = _draft.round().clamp(0, 100).toInt();
    return _AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4A843).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '声',
                  style: TextStyle(
                    color: Color(0xFFD4A843),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _adminModelsTitle(context, 'Agent 语音输出概率'),
                    const SizedBox(height: 3),
                    _adminModelsCaption(
                      context,
                      '0% 全部文字，100% 所有允许的普通/主动聊天都输出语音。',
                    ),
                  ],
                ),
              ),
              Text(
                widget.saving ? '保存中…' : '$value%',
                style: const TextStyle(
                  color: Color(0xFFD4A843),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CupertinoSlider(
            value: _draft.clamp(0, 100).toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            onChanged: widget.disabled || widget.saving
                ? null
                : (next) => setState(() => _draft = next),
            onChangeEnd: widget.disabled || widget.saving
                ? null
                : (next) => widget.onChanged(next.round()),
          ),
          _adminModelsCaption(context, '提醒、危机、安全、边界、系统状态与组件卡片始终保留文字。'),
        ],
      ),
    );
  }
}

class _AdminFlagCard extends StatelessWidget {
  const _AdminFlagCard({
    required this.marker,
    required this.title,
    required this.badge,
    required this.description,
    required this.scope,
    required this.enabled,
    required this.saving,
    required this.disabled,
    required this.onChanged,
  });

  final String marker;
  final String title;
  final String badge;
  final String description;
  final String scope;
  final bool enabled;
  final bool saving;
  final bool disabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppColors.of(context);
    return _AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  marker,
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.text
                                  : const Color(0xFF12171B),
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _AdminMiniBadge(text: badge),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      saving ? '保存中…' : (enabled ? '已开启' : '已关闭'),
                      style: TextStyle(
                        color: saving
                            ? colors.accent
                            : enabled
                            ? const Color(0xFF1FA97A)
                            : AppColors.muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              CupertinoSwitch(
                value: enabled,
                onChanged: disabled || saving ? null : onChanged,
                activeTrackColor: const Color(0xFF1FA97A),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            scope,
            style: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.36)
                  : const Color(0x6612171B),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminAchievementCard extends StatelessWidget {
  const _AdminAchievementCard({
    required this.settings,
    required this.saving,
    required this.disabled,
    required this.onChanged,
  });

  final _AchievementSettings? settings;
  final bool saving;
  final bool disabled;
  final ValueChanged<String> onChanged;

  static const _options = [
    _AchievementOption(
      value: 'on',
      label: '全量开启',
      hint: '实时解锁并提示：聊天弹窗 / 时间线 / 系统推送 / 成就页 / 积分全部开启。',
    ),
    _AchievementOption(
      value: 'silent',
      label: '静默计算',
      hint: 'H5 期间推荐：照常计算并落库，成就页与积分正常可见；仅关闭聊天内成就达成提示与系统推送。',
    ),
    _AchievementOption(
      value: 'off',
      label: '完全停算',
      hint: '应急开关：停止评估与日终任务（checkpoint 冻结），成就页隐藏。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppColors.of(context);
    final effective = settings?.effectiveMode ?? 'on';
    final hint = settings == null
        ? '加载失败，无法读取当前模式。'
        : _options
              .firstWhere(
                (o) => o.value == effective,
                orElse: () => _options.first,
              )
              .hint;
    return _AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '成',
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '成就系统',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.text
                                : const Color(0xFF12171B),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const _AdminMiniBadge(text: '全局模式'),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      saving ? '保存中…' : _achievementBadge(effective),
                      style: TextStyle(
                        color: saving
                            ? colors.accent
                            : _achievementColor(effective, colors),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AdminSegment<String>(
            value: effective,
            options: [for (final o in _options) MapEntry(o.value, o.label)],
            onChanged: disabled || saving ? (_) {} : onChanged,
          ),
          const SizedBox(height: 12),
          Text(
            hint,
            style: TextStyle(
              color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
          if (settings != null && settings!.mode == null) ...[
            const SizedBox(height: 8),
            Text(
              '当前跟随 .env (${settings!.envMode})',
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.36)
                    : const Color(0x6612171B),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _achievementBadge(String mode) {
    return switch (mode) {
      'on' => '全量运行中',
      'silent' => '静默计算中',
      'off' => '已停算',
      _ => mode,
    };
  }

  Color _achievementColor(String mode, AppPalette colors) {
    return switch (mode) {
      'on' => const Color(0xFF1FA97A),
      'silent' => const Color(0xFFD4A843),
      'off' => colors.danger,
      _ => colors.muted,
    };
  }
}

class _AchievementOption {
  const _AchievementOption({
    required this.value,
    required this.label,
    required this.hint,
  });

  final String value;
  final String label;
  final String hint;
}

class _AdminMiniBadge extends StatelessWidget {
  const _AdminMiniBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0x0F181F2A),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
