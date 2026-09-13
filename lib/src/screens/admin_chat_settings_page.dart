part of 'package:companion_flutter/main.dart';

// ===========================================================================
// Admin · 聊天管理 (mobile port of web 后台管理「系统设置 → 聊天管理」)
// ===========================================================================

class _AdminChatManagementPage extends StatefulWidget {
  const _AdminChatManagementPage({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_AdminChatManagementPage> createState() =>
      _AdminChatManagementPageState();
}

class _AdminChatManagementPageState extends State<_AdminChatManagementPage> {
  bool _loading = true;
  String? _error;
  _RuntimeConfigBundle? _runtime;
  String? _savingKey;
  bool _triggeringProactive = false;
  String? _proactiveTriggerFeedback;
  bool _proactiveTriggerOk = false;

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
      final runtime = await widget.api.fetchAdminRuntimeConfig();
      if (!mounted) return;
      setState(() {
        _runtime = runtime;
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

  bool _boolFromRuntime(String configKey, String resolvedKey, {bool fallback = false}) {
    final runtime = _runtime;
    if (runtime == null) return fallback;
    final configured = runtime.config[configKey];
    if (configured is bool) return configured;
    return runtime.resolved[resolvedKey] == true;
  }

  int _intFromRuntime(
    String configKey,
    String resolvedKey, {
    required int fallback,
    required int min,
    required int max,
  }) {
    final runtime = _runtime;
    if (runtime == null) return fallback;
    final configured = runtime.config[configKey];
    if (configured is num) {
      return configured.round().clamp(min, max).toInt();
    }
    final resolved = runtime.resolved[resolvedKey];
    return resolved is num
        ? resolved.round().clamp(min, max).toInt()
        : fallback;
  }

  bool get _replyDelayEnabled => _boolFromRuntime(
    'reply_delay_enabled',
    'reply_delay_enabled',
  );

  int get _replyDelayMaxSeconds => _intFromRuntime(
    'reply_delay_max_seconds',
    'reply_delay_max_seconds',
    fallback: 300,
    min: 1,
    max: 3600,
  );

  bool get _messageAggregationEnabled => _boolFromRuntime(
    'user_message_aggregation_enabled',
    'user_message_aggregation_enabled',
    fallback: true,
  );

  bool get _proactiveTrendingEnabled {
    final runtime = _runtime;
    if (runtime == null) return false;
    final configured = runtime.config['proactive_trending_enabled'];
    if (configured is bool) return configured;
    return runtime.resolved['proactive_trending_enabled'] == true;
  }

  int _percentFromProbability(String configKey, String resolvedKey) {
    final runtime = _runtime;
    if (runtime == null) return 0;
    final configured = runtime.config[configKey];
    final raw = configured is num
        ? configured.toDouble()
        : (runtime.resolved[resolvedKey] is num
            ? (runtime.resolved[resolvedKey] as num).toDouble()
            : 0.0);
    return (raw.clamp(0.0, 1.0) * 100).round();
  }

  int get _proactiveTrendingHitPercent => _percentFromProbability(
    'proactive_trending_probability',
    'proactive_trending_probability',
  );

  int get _proactiveTrendingLinkPercent => _percentFromProbability(
    'proactive_trending_link_probability',
    'proactive_trending_link_probability',
  );

  int get _proactiveTrendingCacheTtl {
    final runtime = _runtime;
    if (runtime == null) return 3600;
    final configured = runtime.config['proactive_trending_cache_ttl_s'];
    if (configured is num) {
      return configured.round().clamp(60, 86400).toInt();
    }
    final resolved = runtime.resolved['proactive_trending_cache_ttl_s'];
    return resolved is num ? resolved.round().clamp(60, 86400).toInt() : 3600;
  }

  Future<void> _patchRuntimeConfigWithKey(
    String savingKey,
    Map<String, dynamic> patch,
  ) async {
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

  Future<void> _patchRuntimeConfig(Map<String, dynamic> patch) =>
      _patchRuntimeConfigWithKey('proactive_trending', patch);

  Future<void> _pickAndTriggerProactive() async {
    if (_triggeringProactive) return;
    final selected = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: const Text('选择主动聊天类型'),
          message: const Text('会跳过日限/疲劳检查，方便连续测试'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop('silence_wakeup'),
              child: const Text('沉默唤醒 (silence_wakeup)'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop('scheduled_scene'),
              child: const Text('定时情景 (scheduled_scene)'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop('special_date'),
              child: const Text('特殊日期 (special_date)'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        );
      },
    );
    if (selected == null || !mounted) return;

    var useWebSearch = false;
    var useLinkCard = false;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return CupertinoAlertDialog(
              title: const Text('主动交流测试选项'),
              content: Column(
                children: [
                  const SizedBox(height: 12),
                  Text(
                    '类型：$selected',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '触发网络搜索',
                          style: TextStyle(fontSize: 15),
                        ),
                      ),
                      CupertinoSwitch(
                        value: useWebSearch,
                        onChanged: (value) {
                          setDialogState(() => useWebSearch = value);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '触发链接卡片',
                          style: TextStyle(fontSize: 15),
                        ),
                      ),
                      CupertinoSwitch(
                        value: useLinkCard,
                        onChanged: (value) {
                          setDialogState(() => useLinkCard = value);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('确认触发'),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true || !mounted) return;

    final workspaceId = widget.session.workspaceId?.trim();
    final agentId = widget.session.agentId?.trim();
    if ((workspaceId == null || workspaceId.isEmpty) &&
        (agentId == null || agentId.isEmpty)) {
      setState(() {
        _proactiveTriggerOk = false;
        _proactiveTriggerFeedback =
            '当前登录会话缺少 workspaceId / agentId，请先进入聊天页后再试。';
      });
      return;
    }

    setState(() {
      _triggeringProactive = true;
      _proactiveTriggerFeedback = null;
    });
    try {
      widget.api.authToken = widget.session.token;
      final result = await widget.api.triggerAdminProactiveChat(
        workspaceId: workspaceId,
        agentId: agentId,
        triggerType: selected,
        useWebSearch: useWebSearch,
        useLinkCard: useLinkCard,
      );
      if (!mounted) return;
      if (!result.ok) {
        setState(() {
          _triggeringProactive = false;
          _proactiveTriggerOk = false;
          _proactiveTriggerFeedback =
              result.reason ?? 'generation_or_limit_blocked';
        });
        return;
      }
      final preview = (result.message ?? '').trim();
      final flags = [
        '联网搜索：${result.webSearchUsed ? '已注入' : '未注入'}',
        '链接卡片：${result.linkCardUsed ? '已附带' : '未附带'}',
      ].join('\n');
      setState(() {
        _triggeringProactive = false;
        _proactiveTriggerOk = true;
        _proactiveTriggerFeedback = preview.isEmpty
            ? '消息已发送，请到聊天页查看。\n类型：${result.triggerType}\n$flags'
            : '类型：${result.triggerType}\n$flags\n\n$preview';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _triggeringProactive = false;
        _proactiveTriggerOk = false;
        _proactiveTriggerFeedback = _asMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AdminScaffold(
      title: '聊天管理',
      subtitle: '回复节奏 · 聚合 · 主动热点',
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _runtime == null) {
      return const Center(child: CupertinoActivityIndicator(radius: 14));
    }
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
      children: [
        _AdminCard(
          child: Text(
            '控制随机延迟回复、短消息聚合，以及沉默唤醒/定时情景/特殊日期的热点预取。'
            '修改后即时生效并持久化。',
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
        _AdminReplyDelayCard(
          enabled: _replyDelayEnabled,
          maxSeconds: _replyDelayMaxSeconds,
          saving: _savingKey == 'reply_delay',
          disabled: _runtime == null ||
              (_savingKey != null && _savingKey != 'reply_delay'),
          onToggleEnabled: (next) => _patchRuntimeConfigWithKey(
            'reply_delay',
            {'reply_delay_enabled': next},
          ),
          onCommitMaxSeconds: (seconds) => _patchRuntimeConfigWithKey(
            'reply_delay',
            {'reply_delay_max_seconds': seconds},
          ),
        ),
        const SizedBox(height: 12),
        _AdminMessageAggregationCard(
          enabled: _messageAggregationEnabled,
          saving: _savingKey == 'message_aggregation',
          disabled: _runtime == null ||
              (_savingKey != null && _savingKey != 'message_aggregation'),
          onToggleEnabled: (next) => _patchRuntimeConfigWithKey(
            'message_aggregation',
            {'user_message_aggregation_enabled': next},
          ),
        ),
        const SizedBox(height: 12),
        _AdminProactiveTrendingCard(
          enabled: _proactiveTrendingEnabled,
          hitPercent: _proactiveTrendingHitPercent,
          linkPercent: _proactiveTrendingLinkPercent,
          cacheTtlSeconds: _proactiveTrendingCacheTtl,
          linkGateEnabled: _runtime?.proactiveLinkRecommendationEnabled ?? true,
          saving: _savingKey == 'proactive_trending',
          disabled: _runtime == null ||
              (_savingKey != null && _savingKey != 'proactive_trending'),
          onToggleEnabled: (next) =>
              _patchRuntimeConfig({'proactive_trending_enabled': next}),
          onCommitHitPercent: (percent) => _patchRuntimeConfig({
            'proactive_trending_probability': percent / 100.0,
          }),
          onCommitLinkPercent: (percent) => _patchRuntimeConfig({
            'proactive_trending_link_probability': percent / 100.0,
          }),
          onCommitCacheTtl: (seconds) => _patchRuntimeConfig({
            'proactive_trending_cache_ttl_s': seconds,
          }),
        ),
        const SizedBox(height: 12),
        _AdminProactiveTriggerTestCard(
          triggering: _triggeringProactive,
          feedback: _proactiveTriggerFeedback,
          ok: _proactiveTriggerOk,
          disabled: _runtime == null || _savingKey != null,
          onTrigger: _pickAndTriggerProactive,
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

class _AdminReplyDelayCard extends StatefulWidget {
  const _AdminReplyDelayCard({
    required this.enabled,
    required this.maxSeconds,
    required this.saving,
    required this.disabled,
    required this.onToggleEnabled,
    required this.onCommitMaxSeconds,
  });

  final bool enabled;
  final int maxSeconds;
  final bool saving;
  final bool disabled;
  final ValueChanged<bool> onToggleEnabled;
  final ValueChanged<int> onCommitMaxSeconds;

  @override
  State<_AdminReplyDelayCard> createState() => _AdminReplyDelayCardState();
}

class _AdminReplyDelayCardState extends State<_AdminReplyDelayCard> {
  late int _maxDraft = widget.maxSeconds;
  late final TextEditingController _maxController = TextEditingController(
    text: '${widget.maxSeconds}',
  );

  @override
  void didUpdateWidget(covariant _AdminReplyDelayCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.maxSeconds != widget.maxSeconds) {
      _maxDraft = widget.maxSeconds;
      _maxController.text = '$_maxDraft';
    }
  }

  @override
  void dispose() {
    _maxController.dispose();
    super.dispose();
  }

  void _commitMax() {
    final next = _maxDraft.clamp(1, 3600);
    _maxDraft = next;
    if (next != widget.maxSeconds) widget.onCommitMaxSeconds(next);
  }

  @override
  Widget build(BuildContext context) {
    final controlsDisabled = widget.disabled || widget.saving || !widget.enabled;
    return _AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  '延',
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
                    _adminModelsTitle(context, '随机延迟回复'),
                    const SizedBox(height: 3),
                    _adminModelsCaption(
                      context,
                      '按情绪与作息随机等待后再回复；关闭则即时同步回复。',
                    ),
                  ],
                ),
              ),
              CupertinoSwitch(
                value: widget.enabled,
                onChanged: widget.disabled || widget.saving
                    ? null
                    : widget.onToggleEnabled,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _adminModelsCaption(context, '最大延迟（秒，1–3600）'),
          CupertinoTextField(
            keyboardType: TextInputType.number,
            enabled: !controlsDisabled,
            controller: _maxController,
            onChanged: (raw) {
              final parsed = int.tryParse(raw);
              if (parsed != null) setState(() => _maxDraft = parsed);
            },
            onSubmitted: (_) => _commitMax(),
            onEditingComplete: _commitMax,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ],
      ),
    );
  }
}

class _AdminMessageAggregationCard extends StatelessWidget {
  const _AdminMessageAggregationCard({
    required this.enabled,
    required this.saving,
    required this.disabled,
    required this.onToggleEnabled,
  });

  final bool enabled;
  final bool saving;
  final bool disabled;
  final ValueChanged<bool> onToggleEnabled;

  @override
  Widget build(BuildContext context) {
    return _AdminCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              '聚',
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
                _adminModelsTitle(context, '短消息聚合回复'),
                const SizedBox(height: 3),
                _adminModelsCaption(
                  context,
                  '开启时碎片/连发消息等待合并后再回复；关闭则每条立即处理。',
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: enabled,
            onChanged: disabled || saving ? null : onToggleEnabled,
          ),
        ],
      ),
    );
  }
}

class _AdminProactiveTriggerTestCard extends StatelessWidget {
  const _AdminProactiveTriggerTestCard({
    required this.triggering,
    required this.feedback,
    required this.ok,
    required this.disabled,
    required this.onTrigger,
  });

  final bool triggering;
  final String? feedback;
  final bool ok;
  final bool disabled;
  final VoidCallback onTrigger;

  @override
  Widget build(BuildContext context) {
    return _AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  '测',
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
                    _adminModelsTitle(context, '测试触发主动消息'),
                    const SizedBox(height: 3),
                    _adminModelsCaption(
                      context,
                      '立即推送一条 AI 主动消息（沉默/情景/特殊日期），'
                      '使用当前会话的 workspace / agent，跳过日限检查。',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          CupertinoButton.filled(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            onPressed: disabled || triggering ? null : onTrigger,
            child: Text(
              triggering ? '正在触发…' : '选择类型并触发',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          if (feedback != null) ...[
            const SizedBox(height: 12),
            Text(
              feedback!,
              style: TextStyle(
                color: ok
                    ? (AppColors.isDark(context)
                        ? const Color(0x9EEBF2EE)
                        : AppColors.muted)
                    : AppColors.of(context).danger,
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminProactiveTrendingCard extends StatefulWidget {
  const _AdminProactiveTrendingCard({
    required this.enabled,
    required this.hitPercent,
    required this.linkPercent,
    required this.cacheTtlSeconds,
    required this.linkGateEnabled,
    required this.saving,
    required this.disabled,
    required this.onToggleEnabled,
    required this.onCommitHitPercent,
    required this.onCommitLinkPercent,
    required this.onCommitCacheTtl,
  });

  final bool enabled;
  final int hitPercent;
  final int linkPercent;
  final int cacheTtlSeconds;
  final bool linkGateEnabled;
  final bool saving;
  final bool disabled;
  final ValueChanged<bool> onToggleEnabled;
  final ValueChanged<int> onCommitHitPercent;
  final ValueChanged<int> onCommitLinkPercent;
  final ValueChanged<int> onCommitCacheTtl;

  @override
  State<_AdminProactiveTrendingCard> createState() =>
      _AdminProactiveTrendingCardState();
}

class _AdminProactiveTrendingCardState extends State<_AdminProactiveTrendingCard> {
  late double _hitDraft = widget.hitPercent.toDouble();
  late double _linkDraft = widget.linkPercent.toDouble();
  late int _ttlDraft = widget.cacheTtlSeconds;
  late final TextEditingController _ttlController = TextEditingController(
    text: '${widget.cacheTtlSeconds}',
  );

  @override
  void didUpdateWidget(covariant _AdminProactiveTrendingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hitPercent != widget.hitPercent) {
      _hitDraft = widget.hitPercent.toDouble();
    }
    if (oldWidget.linkPercent != widget.linkPercent) {
      _linkDraft = widget.linkPercent.toDouble();
    }
    if (oldWidget.cacheTtlSeconds != widget.cacheTtlSeconds) {
      _ttlDraft = widget.cacheTtlSeconds;
      _ttlController.text = '$_ttlDraft';
    }
  }

  @override
  void dispose() {
    _ttlController.dispose();
    super.dispose();
  }

  void _commitHit() {
    final next = _hitDraft.round().clamp(0, 100);
    _hitDraft = next.toDouble();
    if (next != widget.hitPercent) widget.onCommitHitPercent(next);
  }

  void _commitLink() {
    final next = _linkDraft.round().clamp(0, 100);
    _linkDraft = next.toDouble();
    if (next != widget.linkPercent) widget.onCommitLinkPercent(next);
  }

  void _commitTtl() {
    final next = _ttlDraft.clamp(60, 86400);
    _ttlDraft = next;
    if (next != widget.cacheTtlSeconds) widget.onCommitCacheTtl(next);
  }

  @override
  Widget build(BuildContext context) {
    final controlsDisabled = widget.disabled || widget.saving || !widget.enabled;
    return _AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  '热',
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
                    _adminModelsTitle(context, '主动消息热点参考'),
                    const SizedBox(height: 3),
                    _adminModelsCaption(
                      context,
                      '沉默唤醒 / 定时情景 / 特殊日期按概率预取热搜并缓存；'
                      '命中后再按第二概率附加链接卡。记忆主动消息不参与。',
                    ),
                  ],
                ),
              ),
              CupertinoSwitch(
                value: widget.enabled,
                onChanged: widget.disabled || widget.saving
                    ? null
                    : widget.onToggleEnabled,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _adminModelsCaption(context, '热点命中率'),
          CupertinoSlider(
            value: _hitDraft,
            min: 0,
            max: 100,
            divisions: 100,
            onChanged: controlsDisabled ? null : (v) => setState(() => _hitDraft = v),
            onChangeEnd: controlsDisabled ? null : (_) => _commitHit(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_hitDraft.round()}%',
              style: TextStyle(
                color: AppColors.isDark(context)
                    ? const Color(0x9EEBF2EE)
                    : AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _adminModelsCaption(context, '热点后链接卡概率'),
          CupertinoSlider(
            value: _linkDraft,
            min: 0,
            max: 100,
            divisions: 100,
            onChanged: controlsDisabled ? null : (v) => setState(() => _linkDraft = v),
            onChangeEnd: controlsDisabled ? null : (_) => _commitLink(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_linkDraft.round()}%',
              style: TextStyle(
                color: AppColors.isDark(context)
                    ? const Color(0x9EEBF2EE)
                    : AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          if (!widget.linkGateEnabled) ...[
            const SizedBox(height: 6),
            Text(
              '服务端 PROACTIVE_LINK_RECOMMENDATION_ENABLED=false，链接卡概率不会生效。',
              style: TextStyle(
                color: AppColors.of(context).danger,
                fontSize: 11.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ],
          const SizedBox(height: 8),
          _adminModelsCaption(context, '热点缓存 TTL（秒）'),
          CupertinoTextField(
            keyboardType: TextInputType.number,
            enabled: !controlsDisabled,
            controller: _ttlController,
            onChanged: (raw) {
              final parsed = int.tryParse(raw);
              if (parsed != null) setState(() => _ttlDraft = parsed);
            },
            onSubmitted: (_) => _commitTtl(),
            onEditingComplete: _commitTtl,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ],
      ),
    );
  }
}
