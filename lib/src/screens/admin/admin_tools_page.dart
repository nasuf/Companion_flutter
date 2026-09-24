part of 'package:companion_flutter/main.dart';

class _ProfileAdminButton extends StatelessWidget {
  const _ProfileAdminButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppColors.of(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(96, 36),
      borderRadius: BorderRadius.circular(999),
      onPressed: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfaceMuted.withValues(alpha: 0.70)
                  : Colors.white.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.76),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: isDark ? 0.52 : 0.10),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Text(
              '管理员入口',
              maxLines: 1,
              style: TextStyle(
                color: isDark ? colors.accentDeep : colors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension _AdminUserApi on CompanionApi {
  Future<_AdminUsersResponse> fetchAdminUsers({
    String search = '',
    int limit = 100,
    int offset = 0,
  }) async {
    final query = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (search.trim().isNotEmpty) 'search': search.trim(),
    };
    final path = Uri(
      path: '/admin-api/users',
      queryParameters: query,
    ).toString();
    final json = await _adminRequest('GET', path) as Map<String, dynamic>;
    return _AdminUsersResponse.fromJson(json);
  }

  Future<_AdminUserDetail> fetchAdminUserDetail(String userId) async {
    final encoded = Uri.encodeComponent(userId);
    final json =
        await _adminRequest('GET', '/admin-api/users/$encoded/detail')
            as Map<String, dynamic>;
    return _AdminUserDetail.fromJson(json);
  }

  Future<String> updateAdminUserRole({
    required String userId,
    required String role,
  }) async {
    final encoded = Uri.encodeComponent(userId);
    final json =
        await _adminRequest(
              'PATCH',
              '/admin-api/users/$encoded/role',
              body: {'role': role},
            )
            as Map<String, dynamic>;
    return json['role']?.toString() ?? role;
  }

  // Delegates to the shared _adminHttpRequest (admin_dashboard_page.dart) so the
  // /admin-api/* transport lives in exactly one place.
  Future<dynamic> _adminRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) {
    return _adminHttpRequest(this, method, path, body: body);
  }
}

class _AdminUsersResponse {
  const _AdminUsersResponse({required this.users, required this.total});

  final List<_AdminUserSummary> users;
  final int total;

  factory _AdminUsersResponse.fromJson(Map<String, dynamic> json) {
    return _AdminUsersResponse(
      users: _jsonList(
        json['users'],
      ).map(_AdminUserSummary.fromJson).toList(growable: false),
      total: _jsonInt(json['total']),
    );
  }
}

class _AdminUserSummary {
  const _AdminUserSummary({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.createdAt,
    required this.status,
    required this.archivedAt,
    required this.signupSource,
    required this.agentCount,
    required this.wechat,
    required this.phone,
    required this.authMethods,
  });

  final String id;
  final String username;
  final String? email;
  final String role;
  final String? createdAt;
  final String status;
  final String? archivedAt;
  final String? signupSource;
  final int agentCount;
  final _AdminWechatIdentity? wechat;
  final _AdminPhoneIdentity? phone;
  final List<_AdminAuthMethod> authMethods;

  bool get isAdmin => role == 'admin';

  String get displayName {
    final nickname = wechat?.nickname?.trim();
    if (nickname != null && nickname.isNotEmpty) return nickname;
    return username.isEmpty ? id : username;
  }

  factory _AdminUserSummary.fromJson(Map<String, dynamic> json) {
    final wechat = _jsonMapOrNull(json['wechat']);
    final phone = _jsonMapOrNull(json['phone']);
    return _AdminUserSummary(
      id: _jsonString(json['id']),
      username: _jsonString(json['username']),
      email: _jsonNullableString(json['email']),
      role: _jsonString(json['role'], fallback: 'user'),
      createdAt: _jsonNullableString(json['created_at']),
      status: _jsonString(json['status'], fallback: 'active'),
      archivedAt: _jsonNullableString(json['archived_at']),
      signupSource: _jsonNullableString(json['signup_source']),
      agentCount: _jsonInt(json['agent_count']),
      wechat: wechat == null ? null : _AdminWechatIdentity.fromJson(wechat),
      phone: phone == null ? null : _AdminPhoneIdentity.fromJson(phone),
      authMethods: _jsonList(
        json['auth_methods'],
      ).map(_AdminAuthMethod.fromJson).toList(growable: false),
    );
  }
}

class _AdminUserDetail {
  const _AdminUserDetail({
    required this.user,
    required this.workspaces,
    required this.agents,
  });

  final _AdminUserSummary user;
  final List<_AdminWorkspaceSummary> workspaces;
  final List<_AdminAgentSummary> agents;

  factory _AdminUserDetail.fromJson(Map<String, dynamic> json) {
    return _AdminUserDetail(
      user: _AdminUserSummary.fromJson(_jsonMap(json['user'])),
      workspaces: _jsonList(
        json['workspaces'],
      ).map(_AdminWorkspaceSummary.fromJson).toList(growable: false),
      agents: _jsonList(
        json['agents'],
      ).map(_AdminAgentSummary.fromJson).toList(growable: false),
    );
  }
}

class _AdminWechatIdentity {
  const _AdminWechatIdentity({
    this.nickname,
    this.avatarUrl,
    this.openid,
    this.unionid,
    this.province,
    this.city,
    this.country,
    this.lastLoginAt,
  });

  final String? nickname;
  final String? avatarUrl;
  final String? openid;
  final String? unionid;
  final String? province;
  final String? city;
  final String? country;
  final String? lastLoginAt;

  String? get location {
    final parts = <String>[];
    for (final part in [country, province, city]) {
      final text = part?.trim();
      if (text != null && text.isNotEmpty) parts.add(text);
    }
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  factory _AdminWechatIdentity.fromJson(Map<String, dynamic> json) {
    return _AdminWechatIdentity(
      nickname: _jsonNullableString(json['nickname']),
      avatarUrl: _jsonNullableString(json['avatar_url']),
      openid: _jsonNullableString(json['openid']),
      unionid: _jsonNullableString(json['unionid']),
      province: _jsonNullableString(json['province']),
      city: _jsonNullableString(json['city']),
      country: _jsonNullableString(json['country']),
      lastLoginAt: _jsonNullableString(json['last_login_at']),
    );
  }
}

class _AdminPhoneIdentity {
  const _AdminPhoneIdentity({this.phone, this.phoneMasked, this.lastLoginAt});

  final String? phone;
  final String? phoneMasked;
  final String? lastLoginAt;

  factory _AdminPhoneIdentity.fromJson(Map<String, dynamic> json) {
    return _AdminPhoneIdentity(
      phone: _jsonNullableString(json['phone']),
      phoneMasked: _jsonNullableString(json['phone_masked']),
      lastLoginAt: _jsonNullableString(json['last_login_at']),
    );
  }
}

class _AdminAuthMethod {
  const _AdminAuthMethod({
    required this.type,
    required this.label,
    this.identifier,
    this.phone,
    this.phoneMasked,
    this.email,
    this.lastLoginAt,
  });

  final String type;
  final String label;
  final String? identifier;
  final String? phone;
  final String? phoneMasked;
  final String? email;
  final String? lastLoginAt;

  factory _AdminAuthMethod.fromJson(Map<String, dynamic> json) {
    return _AdminAuthMethod(
      type: _jsonString(json['type'], fallback: 'password'),
      label: _jsonString(json['label'], fallback: '账号密码'),
      identifier: _jsonNullableString(json['identifier']),
      phone: _jsonNullableString(json['phone']),
      phoneMasked: _jsonNullableString(json['phone_masked']),
      email: _jsonNullableString(json['email']),
      lastLoginAt: _jsonNullableString(json['last_login_at']),
    );
  }
}

class _AdminWorkspaceSummary {
  const _AdminWorkspaceSummary({
    required this.id,
    required this.status,
    required this.agentName,
    required this.conversationCount,
    required this.messageCount,
    required this.createdAt,
  });

  final String id;
  final String status;
  final String? agentName;
  final int conversationCount;
  final int messageCount;
  final String? createdAt;

  factory _AdminWorkspaceSummary.fromJson(Map<String, dynamic> json) {
    return _AdminWorkspaceSummary(
      id: _jsonString(json['id']),
      status: _jsonString(json['status'], fallback: 'unknown'),
      agentName: _jsonNullableString(json['agent_name']),
      conversationCount: _jsonInt(json['conversation_count']),
      messageCount: _jsonInt(json['message_count']),
      createdAt: _jsonNullableString(json['created_at']),
    );
  }
}

class _AdminAgentSummary {
  const _AdminAgentSummary({
    required this.id,
    required this.name,
    required this.gender,
    required this.status,
    required this.conversationCount,
    required this.messageCount,
    required this.createdAt,
    required this.conversations,
  });

  final String id;
  final String name;
  final String? gender;
  final String status;
  final int conversationCount;
  final int messageCount;
  final String? createdAt;
  final List<_AdminConversation> conversations;

  factory _AdminAgentSummary.fromJson(Map<String, dynamic> json) {
    return _AdminAgentSummary(
      id: _jsonString(json['id']),
      name: _jsonString(json['name'], fallback: '未命名 AI'),
      gender: _jsonNullableString(json['gender']),
      status: _jsonString(json['status'], fallback: 'unknown'),
      conversationCount: _jsonInt(json['conversation_count']),
      messageCount: _jsonInt(json['message_count']),
      createdAt: _jsonNullableString(json['created_at']),
      conversations: _jsonList(
        json['conversations'],
      ).map(_AdminConversation.fromJson).toList(growable: false),
    );
  }
}

class _AdminConversation {
  const _AdminConversation({
    required this.id,
    required this.messageCount,
    required this.isDeleted,
    required this.workspaceId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final int messageCount;
  final bool isDeleted;
  final String? workspaceId;
  final String? createdAt;
  final String? updatedAt;

  factory _AdminConversation.fromJson(Map<String, dynamic> json) {
    return _AdminConversation(
      id: _jsonString(json['id']),
      messageCount: _jsonInt(json['message_count']),
      isDeleted: json['is_deleted'] == true,
      workspaceId: _jsonNullableString(json['workspace_id']),
      createdAt: _jsonNullableString(json['created_at']),
      updatedAt: _jsonNullableString(json['updated_at']),
    );
  }
}

List<Map<String, dynamic>> _jsonList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

Map<String, dynamic> _jsonMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

Map<String, dynamic>? _jsonMapOrNull(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

String _jsonString(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}

String? _jsonNullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int _jsonInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String _adminRoleLabel(String role) {
  return role == 'admin' ? '管理员' : '普通用户';
}

String _adminDateLabel(String? value) {
  if (value == null || value.trim().isEmpty) return '暂无';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}.$month.$day $hour:$minute';
}

List<_AdminAuthMethod> _adminAuthMethods(_AdminUserSummary user) {
  if (user.authMethods.isNotEmpty) return user.authMethods;
  final methods = <_AdminAuthMethod>[];
  if (user.email != null) {
    methods.add(
      _AdminAuthMethod(
        type: 'password',
        label: '邮箱密码',
        identifier: user.email,
        email: user.email,
      ),
    );
  }
  if (user.wechat != null) {
    methods.add(
      _AdminAuthMethod(
        type: 'wechat',
        label: '微信',
        identifier:
            user.wechat!.nickname ?? user.wechat!.openid ?? user.displayName,
        lastLoginAt: user.wechat!.lastLoginAt,
      ),
    );
  }
  if (user.phone != null) {
    methods.add(
      _AdminAuthMethod(
        type: 'phone',
        label: '手机号',
        identifier: user.phone!.phoneMasked ?? user.phone!.phone,
        phone: user.phone!.phone,
        phoneMasked: user.phone!.phoneMasked,
        lastLoginAt: user.phone!.lastLoginAt,
      ),
    );
  }
  if (methods.isEmpty) {
    methods.add(
      _AdminAuthMethod(
        type: 'password',
        label: '账号密码',
        identifier: user.username,
      ),
    );
  }
  return methods;
}

Color _adminAuthMethodColor(String type) {
  return switch (type) {
    'wechat' => const Color(0xFF1FA97A),
    'phone' => const Color(0xFF2D73FF),
    _ => const Color(0xFFD4A843),
  };
}

class _AdminProactiveTestOptions {
  const _AdminProactiveTestOptions({
    required this.useWebSearch,
    required this.useLinkCard,
  });

  final bool useWebSearch;
  final bool useLinkCard;
}

class AdminToolsPage extends StatefulWidget {
  const AdminToolsPage({super.key, required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<AdminToolsPage> createState() => _AdminToolsPageState();
}

class _AdminToolsPageState extends State<AdminToolsPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motionController;
  bool _injectingGift = false;
  bool _triggeringProactive = false;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  Future<void> _openUserManagement() async {
    await Navigator.of(context).push(
      CompanionPageRoute<void>(
        builder: (_) =>
            _AdminUsersPage(api: widget.api, session: widget.session),
      ),
    );
  }

  void _openActivityTestPage() {
    widget.api.authToken = widget.session.token;
    Navigator.of(context).push(
      CompanionPageRoute<void>(
        builder: (_) =>
            _OfflineActivityTestPage(api: widget.api, session: widget.session),
      ),
    );
  }

  void _openMonitoring() {
    widget.api.authToken = widget.session.token;
    Navigator.of(context).push(
      CompanionPageRoute<void>(
        builder: (_) =>
            _AdminMonitoringPage(api: widget.api, session: widget.session),
      ),
    );
  }

  void _openOperations() {
    widget.api.authToken = widget.session.token;
    Navigator.of(context).push(
      CompanionPageRoute<void>(
        builder: (_) =>
            _AdminOperationsPage(api: widget.api, session: widget.session),
      ),
    );
  }

  void _openResourceMonitoring() {
    widget.api.authToken = widget.session.token;
    Navigator.of(context).push(
      CompanionPageRoute<void>(
        builder: (_) =>
            _AdminResourcePage(api: widget.api, session: widget.session),
      ),
    );
  }

  void _openUserFeedbackAdmin() {
    widget.api.authToken = widget.session.token;
    Navigator.of(context).push(
      CompanionPageRoute<void>(
        builder: (_) =>
            AdminUserFeedbackPage(api: widget.api, session: widget.session),
      ),
    );
  }

  void _openGlobalModuleSettings() {
    widget.api.authToken = widget.session.token;
    Navigator.of(context).push(
      CompanionPageRoute<void>(
        builder: (_) => _AdminGlobalModuleSettingsPage(
          api: widget.api,
          session: widget.session,
        ),
      ),
    );
  }

  void _openChatManagementSettings() {
    widget.api.authToken = widget.session.token;
    Navigator.of(context).push(
      CompanionPageRoute<void>(
        builder: (_) => _AdminChatManagementPage(
          api: widget.api,
          session: widget.session,
        ),
      ),
    );
  }

  void _openModelManagement() {
    widget.api.authToken = widget.session.token;
    Navigator.of(context).push(
      CompanionPageRoute<void>(
        builder: (_) =>
            _AdminModelsPage(api: widget.api, session: widget.session),
      ),
    );
  }

  void _openGameManagement() {
    widget.api.authToken = widget.session.token;
    Navigator.of(context).push(
      CompanionPageRoute<void>(
        builder: (_) =>
            _AdminGamesPage(api: widget.api, session: widget.session),
      ),
    );
  }

  void _openPaymentManagement() {
    widget.api.authToken = widget.session.token;
    Navigator.of(context).push(
      CompanionPageRoute<void>(
        builder: (_) =>
            _AdminPaymentsPage(api: widget.api, session: widget.session),
      ),
    );
  }

  void _openLastWillSmsTest() {
    widget.api.authToken = widget.session.token;
    Navigator.of(context).push(
      CompanionPageRoute<void>(
        builder: (_) => AdminLastWillSmsTestPage(
          api: widget.api,
          session: widget.session,
        ),
      ),
    );
  }

  void _openVipSubscriptionManagement() {
    widget.api.authToken = widget.session.token;
    Navigator.of(context).push(
      CompanionPageRoute<void>(
        builder: (_) => _AdminVipSubscriptionPage(
          api: widget.api,
          session: widget.session,
        ),
      ),
    );
  }

  void _openVipActivationManagement() {
    widget.api.authToken = widget.session.token;
    Navigator.of(context).push(
      CompanionPageRoute<void>(
        builder: (_) => _AdminVipActivationPage(
          api: widget.api,
          session: widget.session,
        ),
      ),
    );
  }

  Future<void> _pickProactiveTriggerType() async {
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
    final options = await _pickProactiveTestOptions(triggerType: selected);
    if (options == null || !mounted) return;
    await _triggerProactiveChat(
      triggerType: selected,
      useWebSearch: options.useWebSearch,
      useLinkCard: options.useLinkCard,
    );
  }

  Future<_AdminProactiveTestOptions?> _pickProactiveTestOptions({
    required String triggerType,
  }) async {
    var useWebSearch = false;
    var useLinkCard = false;
    return showCupertinoDialog<_AdminProactiveTestOptions>(
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
                    '类型：$triggerType',
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
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () => Navigator.of(context).pop(
                    _AdminProactiveTestOptions(
                      useWebSearch: useWebSearch,
                      useLinkCard: useLinkCard,
                    ),
                  ),
                  child: const Text('确认触发'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _proactiveTriggerReasonLabel(String? reason) {
    // 与后端 sender._generate_message / _log_skip 的 skip_reason 词表对齐.
    // 未识别 reason 原样返, 兜底 empty_or_skip 保持向后兼容.
    switch (reason) {
      case 'conversation_missing':
        return '缺少聊天会话：请先进入与该 Agent 的聊天页后再试（或更新 App 后重试，系统会自动创建会话）。';
      case 'workspace_missing':
      case 'workspace_or_state_missing':
        return '找不到有效的 workspace / 主动消息状态，请确认 Agent ID 正确且 workspace 处于 active。';
      case 'empty_or_skip':
        return 'LLM 未生成有效回复（可能主动消息模板被停用，或模型返回过短 / SKIP）。';
      case 'llm_skip_literal':
        return 'LLM 主动返回了 SKIP —— 通常代表模型认为当前上下文不适合发起主动消息。';
      case 'memory_source_empty':
        return '记忆主动消息抽不到可用记忆，请换 silence_wakeup 或 scheduled_scene 测试。';
      case 'music_source_not_idle':
        return '当前 AI 不在空闲状态，音乐类主动消息被跳过。';
      case 'silence_exhausted':
        return '该会话主动消息已进入衰减永久停止状态。';
      case 'generation_or_limit_blocked':
        return '生成或限流被拦截，请查看具体 reason 字段或后端日志。';
      default:
        if (reason == null || reason.isEmpty) {
          return 'generation_or_limit_blocked';
        }
        if (reason.startsWith('state_not_sendable:')) {
          return '主动消息状态不可发送（${reason.substring('state_not_sendable:'.length)}），请稍后重试或更新后端。';
        }
        if (reason.startsWith('prompt_disabled:')) {
          return '主动消息 prompt 被停用（${reason.substring('prompt_disabled:'.length)}），请到后台提示词管理开启。';
        }
        if (reason.startsWith('llm_response_too_short:')) {
          return 'LLM 返回过短（${reason.substring('llm_response_too_short:'.length)}），已判定为无效回复。若持续出现请检查模型健康。';
        }
        if (reason.startsWith('llm_error:')) {
          return 'LLM 调用失败（${reason.substring('llm_error:'.length)}），请查看后端日志排查网络或配额。';
        }
        return reason;
    }
  }

  Future<void> _triggerProactiveChat({
    required String triggerType,
    required bool useWebSearch,
    required bool useLinkCard,
  }) async {
    if (_triggeringProactive) return;
    final workspaceId = widget.session.workspaceId?.trim();
    final agentId = widget.session.agentId?.trim();
    if ((workspaceId == null || workspaceId.isEmpty) &&
        (agentId == null || agentId.isEmpty)) {
      await _showActivityResult(
        title: '无法触发',
        message: '当前登录会话缺少 workspaceId / agentId，请先进入聊天页后再试。',
      );
      return;
    }

    setState(() => _triggeringProactive = true);
    var progressOpen = true;
    unawaited(
      showCupertinoDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _AdminProgressDialog(
          title: '正在触发主动聊天',
          message: '正在生成并推送一条 AI 主动消息...',
        ),
      ).whenComplete(() {
        progressOpen = false;
      }),
    );

    try {
      widget.api.authToken = widget.session.token;
      final result = await widget.api.triggerAdminProactiveChat(
        workspaceId: workspaceId,
        agentId: agentId,
        triggerType: triggerType,
        useWebSearch: useWebSearch,
        useLinkCard: useLinkCard,
      );
      if (!mounted) return;
      if (progressOpen) Navigator.of(context, rootNavigator: true).pop();
      setState(() => _triggeringProactive = false);
      if (!result.ok) {
        await _showActivityResult(
          title: '主动聊天未发出',
          message: _proactiveTriggerReasonLabel(result.reason),
        );
        return;
      }
      final preview = (result.message ?? '').trim();
      final skipReasonStr = (result.linkCardSkipReason ?? '').trim();
      final cardLine = result.linkCardUsed
          ? '链接卡片：已附带'
          : (skipReasonStr.isEmpty
              ? '链接卡片：未附带'
              : '链接卡片：未附带（原因：$skipReasonStr）');
      final flags = [
        '联网搜索：${result.webSearchUsed ? '已注入' : '未注入'}',
        cardLine,
      ].join('\n');
      await _showActivityResult(
        title: '主动聊天已触发',
        message: preview.isEmpty
            ? '消息已发送，请到聊天页查看。\n类型：${result.triggerType}\n$flags'
            : '类型：${result.triggerType}\n$flags\n\n$preview',
      );
    } catch (error) {
      if (!mounted) return;
      if (progressOpen) Navigator.of(context, rootNavigator: true).pop();
      setState(() => _triggeringProactive = false);
      await _showActivityResult(title: '触发失败', message: _asMessage(error));
    }
  }

  Future<void> _injectMockGift({required bool delivered}) async {
    if (_injectingGift) return;
    setState(() => _injectingGift = true);

    var progressOpen = true;
    unawaited(
      showCupertinoDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _AdminProgressDialog(
          title: delivered ? '正在注入已送达礼物' : '正在注入运输中礼物',
          message: '正在走 mock 链路下单并生成物流轨迹...',
        ),
      ).whenComplete(() {
        progressOpen = false;
      }),
    );

    try {
      widget.api.authToken = widget.session.token;
      final gift = await widget.api.createMockGift(
        workspaceId: widget.session.workspaceId,
        delivered: delivered,
      );
      if (!mounted) return;
      if (progressOpen) Navigator.of(context, rootNavigator: true).pop();
      setState(() => _injectingGift = false);
      await _showGiftResult(
        title: '测试礼物已注入',
        message: delivered
            ? '已生成「${gift.giftName}」并标记为已送达，可去赠礼页查看历史礼物分组与感谢交互。'
            : '已生成「${gift.giftName}」（运输中），可去赠礼页查看礼物卡与物流时间线。',
      );
    } catch (error) {
      if (!mounted) return;
      if (progressOpen) Navigator.of(context, rootNavigator: true).pop();
      setState(() => _injectingGift = false);
      await _showGiftResult(title: '注入失败', message: _asMessage(error));
    }
  }

  Future<void> _showGiftResult({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    final action = await showCupertinoDialog<String>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop('ok'),
              child: const Text('知道了'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop('open'),
              child: const Text('去赠礼页'),
            ),
          ],
        );
      },
    );
    if (!mounted || action != 'open') return;
    await Navigator.of(context).push(
      CompanionPageRoute<void>(
        builder: (_) =>
            OfflineGiftPage(api: widget.api, session: widget.session),
      ),
    );
  }

  Future<void> _showActivityResult({
    required String title,
    required String message,
    bool activityCreated = false,
    String? activityId,
  }) async {
    if (!mounted) return;
    final action = await showCupertinoDialog<String>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop('ok'),
              child: const Text('知道了'),
            ),
            if (activityCreated)
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.of(context).pop('open'),
                child: const Text('查看详情'),
              ),
          ],
        );
      },
    );
    if (!mounted || action != 'open') return;
    // 重构后：新生成的推荐是 pending 态，只作为聊天推荐卡存在、不在活动列表里。
    // 用 initialActivityId 深链进入 → 直接弹出地点详情（想去看看 / 先放一放），
    // 让测试者立即能三选一，而不是打开空的活动列表。
    await Navigator.of(context).push(
      CompanionPageRoute<void>(
        builder: (_) => OfflineActivityPage(
          api: widget.api,
          session: widget.session,
          hasLocation: true,
          initialActivityId: activityId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _adminPageHost(
      body: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: _motionController,
          builder: (context, _) {
            return _buildAdminKeyboardAwareStack(
              context: context,
              motionProgress: _motionController.value,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  18,
                  media.padding.top + 12,
                  18,
                  126,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 48,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _AppNavCircleButton(
                              icon: CupertinoIcons.chevron_left,
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                          Text(
                            'Admin',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.text
                                    : const Color(0xFF12171B),
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _ProfileSectionV6(
                        title: '数据与运营',
                        trailing: '实时统计',
                        child: Column(
                          children: [
                            _ProfileSettingRowV6(
                              icon: CupertinoIcons.chart_bar_alt_fill,
                              title: '数据监控',
                              subtitle: '实时在线、活跃、注册与聊天量走势',
                              accent: const Color(0xFF2D73FF),
                              onTap: _openMonitoring,
                            ),
                            _ProfileSettingRowV6(
                              icon: CupertinoIcons.gauge,
                              title: '运营管理',
                              subtitle: 'LLM 成本、模型分布与系统健康',
                              accent: const Color(0xFF7A5BE3),
                              onTap: _openOperations,
                            ),
                            _ProfileSettingRowV6(
                              icon: CupertinoIcons.desktopcomputer,
                              title: '资源监控',
                              subtitle: '服务器 CPU/内存/磁盘/网络与数据库健康',
                              accent: const Color(0xFF2FA9A0),
                              onTap: _openResourceMonitoring,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ProfileSectionV6(
                        title: '用户与权限',
                        trailing: '账号管理',
                        child: Column(
                          children: [
                            _ProfileSettingRowV6(
                              icon: CupertinoIcons.person_2_fill,
                              title: '用户管理',
                              subtitle: '查看用户详情、对话记录与管理员权限',
                              accent: const Color(0xFF1FA97A),
                              onTap: _openUserManagement,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ProfileSectionV6(
                        title: '支付管理',
                        trailing: '钞票钱包',
                        child: Column(
                          children: [
                            _ProfileSettingRowV6(
                              icon: CupertinoIcons.money_dollar_circle_fill,
                              title: '支付管理',
                              subtitle: '钞票 / 商城积分 · 余额 / 发放 / 流水',
                              accent: const Color(0xFFE8A317),
                              onTap: _openPaymentManagement,
                            ),
                            _ProfileSettingRowV6(
                              icon: CupertinoIcons.star_circle_fill,
                              title: 'VIP 订阅管理',
                              subtitle: 'VIP 订阅用户 / 钞票充值记录 · 详情审计',
                              accent: const Color(0xFF7C5CFF),
                              onTap: _openVipSubscriptionManagement,
                            ),
                            _ProfileSettingRowV6(
                              icon: CupertinoIcons.tickets_fill,
                              title: 'VIP 激活码',
                              subtitle: '生成 / 启停 · 兑换记录与撤销',
                              accent: const Color(0xFF5B8DEF),
                              onTap: _openVipActivationManagement,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ProfileSectionV6(
                        title: '游戏管理',
                        trailing: '难度 · 积分',
                        child: Column(
                          children: [
                            _ProfileSettingRowV6(
                              icon: CupertinoIcons.gamecontroller_fill,
                              title: '游戏管理',
                              subtitle: '难度平衡 / 积分等级 / 每局积分规则',
                              accent: const Color(0xFF2D73FF),
                              onTap: _openGameManagement,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ProfileSectionV6(
                        title: '用户反馈',
                        trailing: '客户意见',
                        child: Column(
                          children: [
                            _ProfileSettingRowV6(
                              icon: CupertinoIcons.envelope_fill,
                              title: '意见反馈',
                              subtitle: '查看用户提交的问题、建议与截图',
                              accent: const Color(0xFF2D73FF),
                              onTap: _openUserFeedbackAdmin,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ProfileSectionV6(
                        title: '系统设置',
                        trailing: '全局 · 聊天 · 模型',
                        child: Column(
                          children: [
                            _ProfileSettingRowV6(
                              icon: CupertinoIcons.slider_horizontal_3,
                              title: '全局模块开关',
                              subtitle: '线下活动 / 礼物 / 联网搜索 / 语音 / 成就',
                              accent: const Color(0xFFD4A843),
                              onTap: _openGlobalModuleSettings,
                            ),
                            _ProfileSettingRowV6(
                              icon: CupertinoIcons.chat_bubble_text_fill,
                              title: '聊天管理',
                              subtitle: '主动消息热点参考 · 链接卡概率 · 缓存 TTL',
                              accent: const Color(0xFF2D73FF),
                              onTap: _openChatManagementSettings,
                            ),
                            _ProfileSettingRowV6(
                              icon: CupertinoIcons.cube_box_fill,
                              title: '模型管理',
                              subtitle: '模型路由 / 多模态模型 / 模型库与价格',
                              accent: const Color(0xFF7A5BE3),
                              onTap: _openModelManagement,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ProfileSectionV6(
                        title: '测试工具',
                        trailing: '仅用于本地测试',
                        child: Column(
                          children: [
                            _ProfileSettingRowV6(
                              icon: CupertinoIcons.bolt_fill,
                              title: '测试生成活动',
                              subtitle: '进入测试页：生成活动 / 查看任务 / 清理活动',
                              accent: const Color(0xFF2D73FF),
                              onTap: _openActivityTestPage,
                            ),
                            _ProfileSettingRowV6(
                              icon: CupertinoIcons.chat_bubble_2_fill,
                              title: _triggeringProactive
                                  ? '正在触发主动聊天'
                                  : '测试主动聊天',
                              subtitle: '立即推送一条 AI 主动消息（沉默/情景/特殊日期）',
                              accent: const Color(0xFF7A5BE3),
                              enabled: !_triggeringProactive,
                              onTap: _pickProactiveTriggerType,
                            ),
                            _ProfileSettingRowV6(
                              icon: CupertinoIcons.gift_fill,
                              title: _injectingGift ? '正在注入礼物' : '注入运输中礼物',
                              subtitle: '为当前用户生成一份礼物卡，附 mock 物流轨迹',
                              accent: const Color(0xFF2D73FF),
                              enabled: !_injectingGift,
                              onTap: () => _injectMockGift(delivered: false),
                            ),
                            _ProfileSettingRowV6(
                              icon: CupertinoIcons.cube_box_fill,
                              title: _injectingGift ? '正在注入礼物' : '注入已送达礼物',
                              subtitle: '生成一份已送达礼物并推送送达消息，验证感谢交互',
                              accent: const Color(0xFF1FA97A),
                              enabled: !_injectingGift,
                              onTap: () => _injectMockGift(delivered: true),
                            ),
                            _ProfileSettingRowV6(
                              icon: CupertinoIcons.chat_bubble_text_fill,
                              title: '遗言短信测试',
                              subtitle: '向指定手机号发送一条遗言通知测试短信',
                              accent: const Color(0xFF7A5BE3),
                              onTap: _openLastWillSmsTest,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            );
          },
        ),
      ),
    );
  }
}
