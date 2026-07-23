part of 'package:companion_flutter/main.dart';

// ===========================================================================
// Admin model management — full parity with the web admin "系统设置" surface:
//   1. Runtime model routing (global SystemConfig): online/local switch,
//      chat + small remote provider/model, local Ollama models, and the
//      multimodal vision / ASR model identifiers.
//   2. Model registry CRUD: list / create / edit models with pricing
//      (input / output / cached-input per 1M tokens), context window, notes.
// Data flows through the same /admin-api/runtime-config and
// /admin-api/model-registry endpoints the web console uses.
// ===========================================================================

// ── API bindings ───────────────────────────────────────────────────────────

extension _AdminModelsApi on CompanionApi {
  Future<_RuntimeConfigBundle> fetchAdminRuntimeConfig() async {
    final json =
        await _adminHttpRequest(this, 'GET', '/admin-api/runtime-config')
            as Map<String, dynamic>;
    return _RuntimeConfigBundle.fromJson(json);
  }

  Future<_RuntimeConfigBundle> updateAdminRuntimeConfig(
    Map<String, dynamic> payload,
  ) async {
    final json = await _adminHttpRequest(
      this,
      'PUT',
      '/admin-api/runtime-config',
      body: payload,
    ) as Map<String, dynamic>;
    return _RuntimeConfigBundle.fromJson(json);
  }

  Future<_RuntimeOptions> fetchAdminRuntimeOptions() async {
    final json = await _adminHttpRequest(
      this,
      'GET',
      '/admin-api/runtime-config/options',
    ) as Map<String, dynamic>;
    return _RuntimeOptions.fromJson(json);
  }

  Future<List<_RegistryModel>> fetchAdminModelRegistry() async {
    final json = await _adminHttpRequest(this, 'GET', '/admin-api/model-registry')
        as Map<String, dynamic>;
    final models = json['models'];
    if (models is! List) return const [];
    return models
        .whereType<Map<String, dynamic>>()
        .map(_RegistryModel.fromJson)
        .toList();
  }

  Future<_RegistryModel> createAdminModel(Map<String, dynamic> payload) async {
    final json = await _adminHttpRequest(
      this,
      'POST',
      '/admin-api/model-registry',
      body: payload,
    ) as Map<String, dynamic>;
    return _RegistryModel.fromJson(json);
  }

  Future<_RegistryModel> updateAdminModel(
    String modelId,
    Map<String, dynamic> payload,
  ) async {
    final json = await _adminHttpRequest(
      this,
      'PATCH',
      '/admin-api/model-registry/${Uri.encodeComponent(modelId)}',
      body: payload,
    ) as Map<String, dynamic>;
    return _RegistryModel.fromJson(json);
  }
}

// ── Data models ────────────────────────────────────────────────────────────

/// Payload keys round-tripped verbatim between GET and PUT. Keeping the whole
/// map (instead of cherry-picking fields) preserves server-side semantics for
/// legacy fields like remote_provider exactly like the web console does.
const List<String> _kRuntimeConfigKeys = [
  'online_model',
  'remote_provider',
  'remote_chat_provider',
  'remote_small_provider',
  'local_chat_model',
  'local_small_model',
  'remote_chat_model',
  'remote_small_model',
  'vision_model',
  'asr_model',
];

class _RuntimeConfigBundle {
  const _RuntimeConfigBundle({required this.config, required this.resolved});

  /// Nullable configured values (null = inherit env / upstream).
  final Map<String, dynamic> config;

  /// Fully resolved effective values (never null).
  final Map<String, dynamic> resolved;

  factory _RuntimeConfigBundle.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> section(String key) {
      final raw = json[key];
      if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
      return <String, dynamic>{};
    }

    return _RuntimeConfigBundle(
      config: section('config'),
      resolved: section('resolved'),
    );
  }
}

class _ProviderOption {
  const _ProviderOption({
    required this.id,
    required this.displayName,
    required this.local,
    required this.configured,
    required this.credentialEnv,
    required this.preferredChatModels,
    required this.preferredSmallModels,
  });

  final String id;
  final String displayName;
  final bool local;
  final bool configured;
  final String? credentialEnv;
  final List<String> preferredChatModels;
  final List<String> preferredSmallModels;

  factory _ProviderOption.fromJson(Map<String, dynamic> json) {
    List<String> strings(dynamic raw) =>
        raw is List ? raw.map((e) => e.toString()).toList() : const [];
    return _ProviderOption(
      id: json['id']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      local: json['local'] == true,
      configured: json['configured'] == true,
      credentialEnv: json['credential_env']?.toString(),
      preferredChatModels: strings(json['preferred_chat_models']),
      preferredSmallModels: strings(json['preferred_small_models']),
    );
  }
}

class _RuntimeOptions {
  const _RuntimeOptions({
    required this.byProvider,
    required this.providers,
    required this.localChat,
    required this.localSmall,
  });

  final Map<String, List<String>> byProvider;
  final List<_ProviderOption> providers;
  final List<String> localChat;
  final List<String> localSmall;

  factory _RuntimeOptions.fromJson(Map<String, dynamic> json) {
    final byProvider = <String, List<String>>{};
    final rawBuckets = json['by_provider'];
    if (rawBuckets is Map) {
      rawBuckets.forEach((key, value) {
        if (value is List) {
          byProvider[key.toString()] =
              value.map((e) => e.toString()).toList();
        }
      });
    }
    List<String> bucket(String key) {
      final raw = json[key];
      return raw is List ? raw.map((e) => e.toString()).toList() : const [];
    }

    final providers = <_ProviderOption>[];
    final rawProviders = json['providers'];
    if (rawProviders is List) {
      providers.addAll(
        rawProviders
            .whereType<Map<String, dynamic>>()
            .map(_ProviderOption.fromJson),
      );
    }
    return _RuntimeOptions(
      byProvider: byProvider,
      providers: providers,
      localChat: bucket('local_chat'),
      localSmall: bucket('local_small'),
    );
  }

  List<_ProviderOption> get remoteProviders =>
      providers.where((p) => !p.local).toList();

  _ProviderOption? providerById(String id) {
    for (final p in providers) {
      if (p.id == id) return p;
    }
    return null;
  }

  String providerLabel(String id) => providerById(id)?.displayName ?? id;
}

class _RegistryModel {
  const _RegistryModel({
    required this.id,
    required this.identifier,
    required this.displayName,
    required this.provider,
    required this.enabled,
    required this.contextWindow,
    required this.inputCostPerMillion,
    required this.outputCostPerMillion,
    required this.cachedInputCostPerMillion,
    required this.notes,
  });

  final String id;
  final String identifier;
  final String? displayName;
  final String provider;
  final bool enabled;
  final int? contextWindow;
  final double? inputCostPerMillion;
  final double? outputCostPerMillion;
  final double? cachedInputCostPerMillion;
  final String? notes;

  factory _RegistryModel.fromJson(Map<String, dynamic> json) {
    double? asDouble(dynamic v) =>
        v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
    int? asInt(dynamic v) =>
        v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
    String? asText(dynamic v) {
      final text = v?.toString();
      return (text == null || text.isEmpty) ? null : text;
    }

    return _RegistryModel(
      id: json['id']?.toString() ?? '',
      identifier: json['identifier']?.toString() ?? '',
      displayName: asText(json['display_name']),
      provider: json['provider']?.toString() ?? '',
      enabled: json['enabled'] == true,
      contextWindow: asInt(json['context_window']),
      inputCostPerMillion: asDouble(json['input_cost_per_million']),
      outputCostPerMillion: asDouble(json['output_cost_per_million']),
      cachedInputCostPerMillion: asDouble(json['cached_input_cost_per_million']),
      notes: asText(json['notes']),
    );
  }
}

// ── Page ───────────────────────────────────────────────────────────────────

class _AdminModelsPage extends StatefulWidget {
  const _AdminModelsPage({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_AdminModelsPage> createState() => _AdminModelsPageState();
}

class _AdminModelsPageState extends State<_AdminModelsPage> {
  int _tab = 0; // 0 = 模型配置, 1 = 模型库
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _config;
  Map<String, dynamic>? _savedConfig;
  Map<String, dynamic>? _resolved;
  _RuntimeOptions? _options;
  bool _saving = false;

  List<_RegistryModel> _models = const [];
  String? _togglingModelId;

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
      final results = await Future.wait([
        widget.api.fetchAdminRuntimeConfig(),
        widget.api.fetchAdminRuntimeOptions(),
        widget.api.fetchAdminModelRegistry(),
      ]);
      if (!mounted) return;
      final bundle = results[0] as _RuntimeConfigBundle;
      setState(() {
        _config = Map<String, dynamic>.from(bundle.config);
        _savedConfig = Map<String, dynamic>.from(bundle.config);
        _resolved = bundle.resolved;
        _options = results[1] as _RuntimeOptions;
        _models = results[2] as List<_RegistryModel>;
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

  // ── Runtime config helpers ──

  bool get _dirty {
    final config = _config;
    final saved = _savedConfig;
    if (config == null || saved == null) return false;
    for (final key in _kRuntimeConfigKeys) {
      if (config[key] != saved[key]) return true;
    }
    return false;
  }

  /// Configured value if set, otherwise the resolved (effective) value —
  /// mirrors the web console's valueFor helper.
  String _effectiveText(String key) {
    final configured = _config?[key];
    if (configured is String && configured.isNotEmpty) return configured;
    return _resolved?[key]?.toString() ?? '';
  }

  bool get _effectiveOnline {
    final configured = _config?['online_model'];
    if (configured is bool) return configured;
    return _resolved?['online_model'] == true;
  }

  void _setConfig(String key, Object? value) {
    final config = _config;
    if (config == null) return;
    setState(() => config[key] = value);
  }

  Future<void> _saveRuntimeConfig() async {
    final config = _config;
    if (config == null || !_dirty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    widget.api.authToken = widget.session.token;
    try {
      final payload = <String, dynamic>{
        for (final key in _kRuntimeConfigKeys) key: config[key],
      };
      final bundle = await widget.api.updateAdminRuntimeConfig(payload);
      if (!mounted) return;
      setState(() {
        _config = Map<String, dynamic>.from(bundle.config);
        _savedConfig = Map<String, dynamic>.from(bundle.config);
        _resolved = bundle.resolved;
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _asMessage(error);
        _saving = false;
      });
    }
  }

  /// Provider switch keeps the model consistent: when the current model does
  /// not exist under the new provider, fall back to the provider's preferred
  /// model (chat/small) or the first available one — same as the web console.
  void _changeRemoteProvider({required bool isChat, required String next}) {
    final options = _options;
    if (options == null) return;
    final providerKey = isChat ? 'remote_chat_provider' : 'remote_small_provider';
    final modelKey = isChat ? 'remote_chat_model' : 'remote_small_model';
    _setConfig('online_model', true);
    _setConfig(providerKey, next);
    final models = options.byProvider[next] ?? const [];
    if (models.isEmpty) return;
    final currentModel = _effectiveText(modelKey);
    if (models.contains(currentModel)) return;
    final option = options.providerById(next);
    final preferred = isChat
        ? option?.preferredChatModels
        : option?.preferredSmallModels;
    String fallback = models.first;
    if (preferred != null) {
      for (final candidate in preferred) {
        if (models.contains(candidate)) {
          fallback = candidate;
          break;
        }
      }
    }
    _setConfig(modelKey, fallback);
  }

  Future<void> _pickRemoteProvider({required bool isChat}) async {
    final options = _options;
    if (options == null) return;
    final providerKey = isChat ? 'remote_chat_provider' : 'remote_small_provider';
    final current = _effectiveText(providerKey);
    final selected = await _showChoiceSheet(
      title: isChat ? '大模型平台' : '小模型平台',
      options: [
        for (final p in options.remoteProviders)
          _ChoiceOption(
            value: p.id,
            label: p.displayName,
            detail: !p.configured
                ? '缺少 ${p.credentialEnv ?? '平台凭据'}'
                : '${(options.byProvider[p.id] ?? const []).length} 个可用模型',
            // Selectable when usable (configured + has models); the current
            // provider stays selectable so the sheet can always show it.
            enabled: (p.configured &&
                    (options.byProvider[p.id] ?? const []).isNotEmpty) ||
                p.id == current,
            selected: p.id == current,
          ),
      ],
    );
    if (selected != null && selected != current) {
      _changeRemoteProvider(isChat: isChat, next: selected);
    }
  }

  Future<void> _pickRemoteModel({required bool isChat}) async {
    final options = _options;
    if (options == null) return;
    final providerKey = isChat ? 'remote_chat_provider' : 'remote_small_provider';
    final modelKey = isChat ? 'remote_chat_model' : 'remote_small_model';
    final provider = _effectiveText(providerKey);
    final current = _effectiveText(modelKey);
    final models = List<String>.from(options.byProvider[provider] ?? const []);
    if (current.isNotEmpty && !models.contains(current)) {
      models.insert(0, current);
    }
    if (models.isEmpty) return;
    final selected = await _showChoiceSheet(
      title: isChat ? '大模型' : '小模型',
      options: [
        for (final m in models)
          _ChoiceOption(value: m, label: m, selected: m == current),
      ],
    );
    if (selected != null && selected != current) {
      _setConfig('online_model', true);
      _setConfig(modelKey, selected);
    }
  }

  Future<void> _pickLocalModel({required bool isChat}) async {
    final options = _options;
    if (options == null) return;
    final modelKey = isChat ? 'local_chat_model' : 'local_small_model';
    final current = _effectiveText(modelKey);
    final models = List<String>.from(
      isChat ? options.localChat : options.localSmall,
    );
    if (current.isNotEmpty && !models.contains(current)) {
      models.insert(0, current);
    }
    if (models.isEmpty) return;
    final selected = await _showChoiceSheet(
      title: isChat ? '本地大模型' : '本地小模型',
      options: [
        for (final m in models)
          _ChoiceOption(value: m, label: m, selected: m == current),
      ],
    );
    if (selected != null && selected != current) {
      _setConfig(modelKey, selected);
    }
  }

  Future<String?> _showChoiceSheet({
    required String title,
    required List<_ChoiceOption> options,
  }) {
    return showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(title),
        actions: [
          for (final option in options)
            CupertinoActionSheetAction(
              onPressed: option.enabled
                  ? () => Navigator.of(ctx).pop(option.value)
                  : () {},
              isDefaultAction: option.selected,
              child: Opacity(
                opacity: option.enabled ? 1 : 0.4,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${option.selected ? '✓ ' : ''}${option.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (option.detail != null)
                      Text(
                        option.detail!,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          isDestructiveAction: true,
          child: const Text('取消'),
        ),
      ),
    );
  }

  // ── Registry helpers ──

  Future<void> _toggleModelEnabled(_RegistryModel model, bool next) async {
    if (_togglingModelId != null) return;
    setState(() => _togglingModelId = model.id);
    widget.api.authToken = widget.session.token;
    try {
      final updated =
          await widget.api.updateAdminModel(model.id, {'enabled': next});
      if (!mounted) return;
      setState(() {
        _models = [
          for (final m in _models) m.id == updated.id ? updated : m,
        ];
        _togglingModelId = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _asMessage(error);
        _togglingModelId = null;
      });
    }
  }

  Future<void> _openModelEditor({_RegistryModel? model}) async {
    final options = _options;
    if (options == null) return;
    final changed = await Navigator.of(context).push<bool>(
      CupertinoPageRoute<bool>(
        builder: (_) => _AdminModelEditPage(
          api: widget.api,
          session: widget.session,
          providers: options.providers,
          existing: model,
          takenKeys: {
            for (final m in _models) '${m.provider}/${m.identifier}': m.id,
          },
        ),
      ),
    );
    if (changed == true) {
      await _load();
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return _AdminScaffold(
      title: '模型管理',
      subtitle: '模型路由 · 模型库与价格',
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator(radius: 14));
    }
    final isDark = AppColors.isDark(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: _tab,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              children: const {
                0: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('模型配置', style: TextStyle(fontSize: 13)),
                ),
                1: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('模型库', style: TextStyle(fontSize: 13)),
                ),
              },
              onValueChanged: (value) => setState(() => _tab = value ?? 0),
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
            child: _AdminCard(
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFE35B6F),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        Expanded(
          child: _tab == 0 ? _buildRuntimeTab(context) : _buildRegistryTab(context),
        ),
      ],
    );
  }

  // ── Runtime config tab ──

  Widget _buildRuntimeTab(BuildContext context) {
    final config = _config;
    final resolved = _resolved;
    final options = _options;
    if (config == null || resolved == null || options == null) {
      return Center(
        child: Text(
          _error ?? '加载失败',
          style: const TextStyle(fontSize: 13, decoration: TextDecoration.none),
        ),
      );
    }
    final online = _effectiveOnline;
    final chatProvider = _effectiveText('remote_chat_provider');
    final smallProvider = _effectiveText('remote_small_provider');
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
      children: [
        _AdminCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _adminModelsTitle(context, online ? '云端模型路由' : '本地 Ollama 模式'),
                    const SizedBox(height: 4),
                    _adminModelsCaption(
                      context,
                      online ? '主回复与辅助任务走云端平台，保存后立即生效。' : '所有任务走本地 Ollama 模型。',
                    ),
                  ],
                ),
              ),
              CupertinoSwitch(
                value: online,
                onChanged: (next) => _setConfig('online_model', next),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ModelRouteCard(
          marker: '大',
          title: '大模型',
          badge: '核心对话',
          description: '负责面向用户的主要回复，决定对话质量与角色表达。',
          enabled: online,
          providerLabel: options.providerLabel(chatProvider),
          model: _effectiveText('remote_chat_model'),
          resolvedText:
              '${options.providerLabel(resolved['remote_chat_provider']?.toString() ?? '')} → ${resolved['remote_chat_model'] ?? ''}',
          onPickProvider: () => _pickRemoteProvider(isChat: true),
          onPickModel: () => _pickRemoteModel(isChat: true),
        ),
        const SizedBox(height: 12),
        _ModelRouteCard(
          marker: '小',
          title: '小模型',
          badge: '辅助任务',
          description: '负责意图识别、记忆抽取等高频后台判断。',
          enabled: online,
          providerLabel: options.providerLabel(smallProvider),
          model: _effectiveText('remote_small_model'),
          resolvedText:
              '${options.providerLabel(resolved['remote_small_provider']?.toString() ?? '')} → ${resolved['remote_small_model'] ?? ''}',
          onPickProvider: () => _pickRemoteProvider(isChat: false),
          onPickModel: () => _pickRemoteModel(isChat: false),
        ),
        const SizedBox(height: 12),
        _AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _adminModelsTitle(context, '多模态模型'),
              const SizedBox(height: 4),
              _adminModelsCaption(
                context,
                '图片理解与语音转写的模型 ID。留空表示使用服务器环境变量默认值。',
              ),
              const SizedBox(height: 12),
              _MediaModelField(
                label: '视觉理解模型 · 火山方舟',
                value: (config['vision_model'] as String?) ?? '',
                placeholder: '${resolved['vision_model'] ?? ''}（环境默认）',
                onChanged: (text) => _setConfig(
                  'vision_model',
                  text.trim().isEmpty ? null : text,
                ),
              ),
              const SizedBox(height: 10),
              _MediaModelField(
                label: '语音转写模型 · 阿里云百炼',
                value: (config['asr_model'] as String?) ?? '',
                placeholder: '${resolved['asr_model'] ?? ''}（环境默认）',
                onChanged: (text) => _setConfig(
                  'asr_model',
                  text.trim().isEmpty ? null : text,
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
              _adminModelsTitle(context, '本地 Ollama 模型'),
              const SizedBox(height: 10),
              _PickerRow(
                label: '本地大模型',
                value: _effectiveText('local_chat_model'),
                onTap: () => _pickLocalModel(isChat: true),
              ),
              const SizedBox(height: 8),
              _PickerRow(
                label: '本地小模型',
                value: _effectiveText('local_small_model'),
                onTap: () => _pickLocalModel(isChat: false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _adminModelsTitle(context, '当前生效配置'),
              const SizedBox(height: 8),
              for (final entry in [
                ('云端路由', resolved['online_model'] == true ? '开启' : '关闭'),
                (
                  '大模型',
                  '${options.providerLabel(resolved['remote_chat_provider']?.toString() ?? '')} / ${resolved['remote_chat_model'] ?? ''}',
                ),
                (
                  '小模型',
                  '${options.providerLabel(resolved['remote_small_provider']?.toString() ?? '')} / ${resolved['remote_small_model'] ?? ''}',
                ),
                ('本地大模型', '${resolved['local_chat_model'] ?? ''}'),
                ('本地小模型', '${resolved['local_small_model'] ?? ''}'),
                ('视觉理解', '${resolved['vision_model'] ?? ''}'),
                ('语音转写', '${resolved['asr_model'] ?? ''}'),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 76,
                        child: _adminModelsCaption(context, entry.$1),
                      ),
                      Expanded(
                        child: Text(
                          entry.$2,
                          style: TextStyle(
                            color: AppColors.isDark(context)
                                ? AppColors.text
                                : const Color(0xFF12171B),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CupertinoButton(
          color: const Color(0xFF2D73FF),
          borderRadius: BorderRadius.circular(14),
          onPressed: (_dirty && !_saving) ? _saveRuntimeConfig : null,
          child: Text(
            _saving ? '应用中...' : (_dirty ? '保存并应用' : '配置已同步'),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  // ── Registry tab ──

  Widget _buildRegistryTab(BuildContext context) {
    final options = _options;
    final sorted = List<_RegistryModel>.from(_models)
      ..sort((a, b) {
        final byProvider = a.provider.compareTo(b.provider);
        if (byProvider != 0) return byProvider;
        return a.identifier.compareTo(b.identifier);
      });
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
      children: [
        _AdminCard(
          child: Row(
            children: [
              Expanded(
                child: _adminModelsCaption(
                  context,
                  '共 ${_models.length} 个模型 · 价格单位 元/百万 tokens。禁用后不再出现在模型配置下拉里。',
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: const Color(0xFF2D73FF),
                borderRadius: BorderRadius.circular(999),
                minimumSize: const Size(0, 30),
                onPressed: () => _openModelEditor(),
                child: const Text(
                  '+ 新增',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final model in sorted) ...[
          _RegistryModelCard(
            model: model,
            providerLabel: options?.providerLabel(model.provider) ?? model.provider,
            toggling: _togglingModelId == model.id,
            onToggleEnabled: (next) => _toggleModelEnabled(model, next),
            onTap: () => _openModelEditor(model: model),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ChoiceOption {
  const _ChoiceOption({
    required this.value,
    required this.label,
    this.detail,
    this.enabled = true,
    this.selected = false,
  });

  final String value;
  final String label;
  final String? detail;
  final bool enabled;
  final bool selected;
}

// ── Shared small widgets ───────────────────────────────────────────────────

Widget _adminModelsTitle(BuildContext context, String text) {
  return Text(
    text,
    style: TextStyle(
      color: AppColors.isDark(context) ? AppColors.text : const Color(0xFF12171B),
      fontSize: 15,
      fontWeight: FontWeight.w900,
      letterSpacing: 0,
      decoration: TextDecoration.none,
    ),
  );
}

Widget _adminModelsCaption(BuildContext context, String text) {
  return Text(
    text,
    style: TextStyle(
      color: AppColors.isDark(context)
          ? const Color(0x9EEBF2EE)
          : AppColors.muted,
      fontSize: 11.5,
      height: 1.45,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      decoration: TextDecoration.none,
    ),
  );
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value.isEmpty ? '未设置' : value,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? AppColors.text : const Color(0xFF12171B),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                CupertinoIcons.chevron_down,
                size: 14,
                color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelRouteCard extends StatelessWidget {
  const _ModelRouteCard({
    required this.marker,
    required this.title,
    required this.badge,
    required this.description,
    required this.enabled,
    required this.providerLabel,
    required this.model,
    required this.resolvedText,
    required this.onPickProvider,
    required this.onPickModel,
  });

  final String marker;
  final String title;
  final String badge;
  final String description;
  final bool enabled;
  final String providerLabel;
  final String model;
  final String resolvedText;
  final VoidCallback onPickProvider;
  final VoidCallback onPickModel;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
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
                child: Text(
                  marker,
                  style: const TextStyle(
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
                    Row(
                      children: [
                        _adminModelsTitle(context, title),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0x9EEBF2EE)
                                  : AppColors.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    _adminModelsCaption(context, description),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Opacity(
            opacity: enabled ? 1 : 0.55,
            child: Column(
              children: [
                _PickerRow(
                  label: '平台',
                  value: providerLabel,
                  enabled: enabled,
                  onTap: onPickProvider,
                ),
                const SizedBox(height: 8),
                _PickerRow(
                  label: '模型',
                  value: model,
                  enabled: enabled,
                  onTap: onPickModel,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _adminModelsCaption(context, '生效中：$resolvedText'),
        ],
      ),
    );
  }
}

class _MediaModelField extends StatefulWidget {
  const _MediaModelField({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onChanged,
  });

  final String label;
  final String value;
  final String placeholder;
  final ValueChanged<String> onChanged;

  @override
  State<_MediaModelField> createState() => _MediaModelFieldState();
}

class _MediaModelFieldState extends State<_MediaModelField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _MediaModelField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync external resets (e.g. reload after save) without clobbering typing.
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _adminModelsCaption(context, widget.label),
        const SizedBox(height: 6),
        CupertinoTextField(
          controller: _controller,
          placeholder: widget.placeholder,
          onChanged: widget.onChanged,
          autocorrect: false,
          enableSuggestions: false,
          style: TextStyle(
            color: isDark ? AppColors.text : const Color(0xFF12171B),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  }
}

class _RegistryModelCard extends StatelessWidget {
  const _RegistryModelCard({
    required this.model,
    required this.providerLabel,
    required this.toggling,
    required this.onToggleEnabled,
    required this.onTap,
  });

  final _RegistryModel model;
  final String providerLabel;
  final bool toggling;
  final ValueChanged<bool> onToggleEnabled;
  final VoidCallback onTap;

  String _price(double? value) =>
      value == null ? '—' : '¥${value.toStringAsFixed(value < 1 ? 3 : 2)}';

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: _AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.displayName?.isNotEmpty == true
                            ? model.displayName!
                            : model.identifier,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark
                              ? AppColors.text
                              : const Color(0xFF12171B),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$providerLabel · ${model.identifier}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark
                              ? const Color(0x9EEBF2EE)
                              : AppColors.muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
                if (toggling)
                  const CupertinoActivityIndicator(radius: 8)
                else
                  CupertinoSwitch(
                    value: model.enabled,
                    onChanged: onToggleEnabled,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chip(context, '输入 ${_price(model.inputCostPerMillion)}/M'),
                _chip(context, '输出 ${_price(model.outputCostPerMillion)}/M'),
                _chip(
                  context,
                  '缓存 ${_price(model.cachedInputCostPerMillion)}/M',
                ),
                if (model.contextWindow != null)
                  _chip(context, '上下文 ${model.contextWindow}'),
                if (!model.enabled) _chip(context, '已禁用', danger: true),
              ],
            ),
            if (model.notes?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              _adminModelsCaption(context, model.notes!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String text, {bool danger = false}) {
    final isDark = AppColors.isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: danger
            ? const Color(0xFFE35B6F).withValues(alpha: 0.14)
            : isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: danger
              ? const Color(0xFFE35B6F)
              : isDark
                  ? const Color(0x9EEBF2EE)
                  : AppColors.muted,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

// ── Model create / edit form ───────────────────────────────────────────────

class _AdminModelEditPage extends StatefulWidget {
  const _AdminModelEditPage({
    required this.api,
    required this.session,
    required this.providers,
    required this.takenKeys,
    this.existing,
  });

  final CompanionApi api;
  final AuthSession session;
  final List<_ProviderOption> providers;

  /// provider/identifier → model id, for client-side uniqueness checks.
  final Map<String, String> takenKeys;
  final _RegistryModel? existing;

  @override
  State<_AdminModelEditPage> createState() => _AdminModelEditPageState();
}

class _AdminModelEditPageState extends State<_AdminModelEditPage> {
  late final TextEditingController _identifier;
  late final TextEditingController _displayName;
  late final TextEditingController _contextWindow;
  late final TextEditingController _inputCost;
  late final TextEditingController _outputCost;
  late final TextEditingController _cachedInputCost;
  late final TextEditingController _notes;
  late String _provider;
  late bool _enabled;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _identifier = TextEditingController(text: existing?.identifier ?? '');
    _displayName = TextEditingController(text: existing?.displayName ?? '');
    _contextWindow = TextEditingController(
      text: existing?.contextWindow?.toString() ?? '',
    );
    _inputCost = TextEditingController(
      text: existing?.inputCostPerMillion?.toString() ?? '',
    );
    _outputCost = TextEditingController(
      text: existing?.outputCostPerMillion?.toString() ?? '',
    );
    _cachedInputCost = TextEditingController(
      text: existing?.cachedInputCostPerMillion?.toString() ?? '',
    );
    _notes = TextEditingController(text: existing?.notes ?? '');
    _provider = existing?.provider ??
        (widget.providers.isNotEmpty ? widget.providers.first.id : 'ollama');
    _enabled = existing?.enabled ?? true;
  }

  @override
  void dispose() {
    _identifier.dispose();
    _displayName.dispose();
    _contextWindow.dispose();
    _inputCost.dispose();
    _outputCost.dispose();
    _cachedInputCost.dispose();
    _notes.dispose();
    super.dispose();
  }

  String _providerLabel(String id) {
    for (final p in widget.providers) {
      if (p.id == id) return p.displayName;
    }
    return id;
  }

  Future<void> _pickProvider() async {
    final selected = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('模型平台'),
        actions: [
          for (final p in widget.providers)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop(p.id),
              isDefaultAction: p.id == _provider,
              child: Text('${p.id == _provider ? '✓ ' : ''}${p.displayName}'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          isDestructiveAction: true,
          child: const Text('取消'),
        ),
      ),
    );
    if (selected != null && selected != _provider) {
      setState(() => _provider = selected);
    }
  }

  /// Parse a positive number field; empty text = null; invalid text = error.
  ({double? value, String? error}) _parseCost(
    TextEditingController controller,
    String label,
  ) {
    final text = controller.text.trim();
    if (text.isEmpty) return (value: null, error: null);
    final value = double.tryParse(text);
    if (value == null || value < 0) {
      return (value: null, error: '$label 需要是不小于 0 的数字');
    }
    return (value: value, error: null);
  }

  Future<void> _save() async {
    if (_saving) return;
    final identifier = _identifier.text.trim();
    if (identifier.isEmpty) {
      setState(() => _error = 'Identifier 不能为空');
      return;
    }
    // Client-side uniqueness pre-check (mirrors the web console) to avoid
    // a guaranteed 409 round-trip.
    final key = '$_provider/$identifier';
    final takenBy = widget.takenKeys[key];
    if (takenBy != null && takenBy != widget.existing?.id) {
      setState(() => _error = '平台 $_provider 下已存在同名 Identifier');
      return;
    }
    final input = _parseCost(_inputCost, '输入价');
    final output = _parseCost(_outputCost, '输出价');
    final cached = _parseCost(_cachedInputCost, '缓存输入价');
    final firstCostError = input.error ?? output.error ?? cached.error;
    if (firstCostError != null) {
      setState(() => _error = firstCostError);
      return;
    }
    int? contextWindow;
    final contextText = _contextWindow.text.trim();
    if (contextText.isNotEmpty) {
      contextWindow = int.tryParse(contextText);
      if (contextWindow == null || contextWindow < 1) {
        setState(() => _error = '上下文窗口需要是正整数');
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    widget.api.authToken = widget.session.token;
    final displayName = _displayName.text.trim();
    final notes = _notes.text.trim();
    try {
      if (_isEdit) {
        await widget.api.updateAdminModel(widget.existing!.id, {
          'display_name': displayName.isEmpty ? null : displayName,
          'provider': _provider,
          'enabled': _enabled,
          'context_window': contextWindow,
          'input_cost_per_million': input.value,
          'output_cost_per_million': output.value,
          'cached_input_cost_per_million': cached.value,
          'notes': notes.isEmpty ? null : notes,
        });
      } else {
        await widget.api.createAdminModel({
          'identifier': identifier,
          'display_name': displayName.isEmpty ? null : displayName,
          'provider': _provider,
          'enabled': _enabled,
          'context_window': contextWindow,
          'input_cost_per_million': input.value,
          'output_cost_per_million': output.value,
          'cached_input_cost_per_million': cached.value,
          'notes': notes.isEmpty ? null : notes,
        });
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _asMessage(error);
        _saving = false;
      });
    }
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: _adminModelsCaption(context, text),
    );
  }

  Widget _textField(
    TextEditingController controller, {
    String? placeholder,
    bool numeric = false,
    bool readOnly = false,
    int maxLines = 1,
  }) {
    final isDark = AppColors.isDark(context);
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      readOnly: readOnly,
      maxLines: maxLines,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: TextStyle(
        color: isDark ? AppColors.text : const Color(0xFF12171B),
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: readOnly ? 0.03 : 0.06)
            : Colors.black.withValues(alpha: readOnly ? 0.02 : 0.035),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _AdminScaffold(
      title: _isEdit ? '编辑模型' : '新增模型',
      subtitle: _isEdit ? widget.existing!.identifier : '登记到模型库后可在模型配置中选用',
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        children: [
          _AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('Identifier（调用时的模型 ID${_isEdit ? '，创建后只读' : ''}）'),
                _textField(
                  _identifier,
                  placeholder: '如 qwen3.5-plus',
                  readOnly: _isEdit,
                ),
                const SizedBox(height: 12),
                _fieldLabel('显示名称（可选）'),
                _textField(_displayName, placeholder: '如 通义千问 Plus'),
                const SizedBox(height: 12),
                _fieldLabel('平台'),
                _PickerRow(
                  label: '平台',
                  value: _providerLabel(_provider),
                  onTap: _pickProvider,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _adminModelsTitle(context, '价格 · 元/百万 tokens'),
                const SizedBox(height: 10),
                _fieldLabel('输入单价'),
                _textField(_inputCost, placeholder: '如 0.8', numeric: true),
                const SizedBox(height: 12),
                _fieldLabel('输出单价'),
                _textField(_outputCost, placeholder: '如 2.0', numeric: true),
                const SizedBox(height: 12),
                _fieldLabel('缓存命中输入单价（留空 = 按未命中价估算）'),
                _textField(_cachedInputCost, placeholder: '如 0.16', numeric: true),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('上下文窗口（tokens，可选）'),
                _textField(_contextWindow, placeholder: '如 131072', numeric: true),
                const SizedBox(height: 12),
                _fieldLabel('备注（可选）'),
                _textField(_notes, placeholder: '内部备注', maxLines: 3),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _adminModelsTitle(context, '启用该模型')),
                    CupertinoSwitch(
                      value: _enabled,
                      onChanged: (v) => setState(() => _enabled = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _AdminCard(
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFE35B6F),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          CupertinoButton(
            color: const Color(0xFF2D73FF),
            borderRadius: BorderRadius.circular(14),
            onPressed: _saving ? null : _save,
            child: Text(
              _saving ? '保存中...' : (_isEdit ? '保存修改' : '创建模型'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
