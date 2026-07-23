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

int _jsonInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
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
  bool _generatingActivity = false;
  bool _clearingActivities = false;
  bool _injectingGift = false;

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
      CupertinoPageRoute<void>(
        builder: (_) =>
            _AdminUsersPage(api: widget.api, session: widget.session),
      ),
    );
  }

  void _openMonitoring() {
    widget.api.authToken = widget.session.token;
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) =>
            _AdminMonitoringPage(api: widget.api, session: widget.session),
      ),
    );
  }

  void _openOperations() {
    widget.api.authToken = widget.session.token;
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) =>
            _AdminOperationsPage(api: widget.api, session: widget.session),
      ),
    );
  }

  void _openSystemSettings() {
    widget.api.authToken = widget.session.token;
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) =>
            _AdminSystemSettingsPage(api: widget.api, session: widget.session),
      ),
    );
  }

  void _openMealAdmin() {
    widget.api.authToken = widget.session.token;
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) =>
            _AdminMealPage(api: widget.api, session: widget.session),
      ),
    );
  }

  void _openGameManagement() {
    widget.api.authToken = widget.session.token;
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) =>
            _AdminGamesPage(api: widget.api, session: widget.session),
      ),
    );
  }

  Future<void> _triggerActivityGeneration() async {
    if (_generatingActivity) return;
    setState(() => _generatingActivity = true);

    var progressOpen = true;
    unawaited(
      showCupertinoDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _AdminProgressDialog(
          title: '正在生成活动',
          message: '正在搜索附近活动并生成推荐卡...',
        ),
      ).whenComplete(() {
        progressOpen = false;
      }),
    );

    try {
      widget.api.authToken = widget.session.token;
      final activity = await widget.api.createOfflineActivityRecommendation(
        workspaceId: widget.session.workspaceId,
      );
      if (!mounted) return;
      if (progressOpen) Navigator.of(context, rootNavigator: true).pop();
      setState(() => _generatingActivity = false);
      if (activity == null) {
        await _showActivityResult(
          title: '暂时没有生成活动',
          message: '请确认当前账号已经授权定位，并且有可用的聊天会话。',
        );
        return;
      }
      await _showActivityResult(
        title: '活动已生成',
        message: '已主动生成「${activity.title}」，可以去活动页查看卡片效果。',
        activityCreated: true,
      );
    } catch (error) {
      if (!mounted) return;
      if (progressOpen) Navigator.of(context, rootNavigator: true).pop();
      setState(() => _generatingActivity = false);
      await _showActivityResult(title: '生成失败', message: _asMessage(error));
    }
  }

  Future<void> _clearActivities() async {
    if (_clearingActivities) return;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('清理所有活动？'),
          content: const Text('这会删除当前登录用户下的全部线下活动推荐记录和完成反馈，无法撤销。'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认清理'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _clearingActivities = true);
    var progressOpen = true;
    unawaited(
      showCupertinoDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _AdminProgressDialog(
          title: '正在清理活动',
          message: '正在删除当前用户的活动推荐记录...',
        ),
      ).whenComplete(() {
        progressOpen = false;
      }),
    );

    try {
      widget.api.authToken = widget.session.token;
      final result = await widget.api.clearOfflineActivitiesForCurrentUser();
      if (!mounted) return;
      if (progressOpen) Navigator.of(context, rootNavigator: true).pop();
      setState(() => _clearingActivities = false);
      await _showActivityResult(
        title: '活动已清理',
        message:
            '已删除 ${result.deletedActivities} 条活动记录和 ${result.deletedFeedback} 条反馈记录。',
      );
    } catch (error) {
      if (!mounted) return;
      if (progressOpen) Navigator.of(context, rootNavigator: true).pop();
      setState(() => _clearingActivities = false);
      await _showActivityResult(title: '清理失败', message: _asMessage(error));
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
      CupertinoPageRoute<void>(
        builder: (_) =>
            OfflineGiftPage(api: widget.api, session: widget.session),
      ),
    );
  }

  Future<void> _showActivityResult({
    required String title,
    required String message,
    bool activityCreated = false,
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
                child: const Text('去活动页'),
              ),
          ],
        );
      },
    );
    if (!mounted || action != 'open') return;
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => OfflineActivityPage(
          api: widget.api,
          session: widget.session,
          hasLocation: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CupertinoPageScaffold(
      backgroundColor: Colors.transparent,
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: _motionController,
          builder: (context, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _ProfileBackgroundPainter(
                    progress: _motionController.value,
                    isDark: isDark,
                  ),
                ),
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
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
                        title: '霸王餐',
                        trailing: '核销运营',
                        child: Column(
                          children: [
                            _ProfileSettingRowV6(
                              icon: CupertinoIcons.ticket_fill,
                              title: '霸王餐管理',
                              subtitle: '扫码校验、商家管理与核销数据统计',
                              accent: const Color(0xFFE8804C),
                              onTap: _openMealAdmin,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ProfileSectionV6(
                        title: '系统设置',
                        trailing: '全局开关',
                        child: Column(
                          children: [
                            _ProfileSettingRowV6(
                              icon: CupertinoIcons.slider_horizontal_3,
                              title: '全局模块开关',
                              subtitle: '线下活动 / 礼物推荐 / 成就系统运行模式',
                              accent: const Color(0xFFD4A843),
                              onTap: _openSystemSettings,
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
                              title: _generatingActivity
                                  ? '正在生成测试活动'
                                  : '测试主动生成活动',
                              subtitle: '为当前登录用户生成一张线下活动推荐卡',
                              accent: const Color(0xFF2D73FF),
                              enabled:
                                  !_generatingActivity && !_clearingActivities,
                              onTap: _triggerActivityGeneration,
                            ),
                            _ProfileSettingRowV6(
                              icon: CupertinoIcons.trash_fill,
                              title: _clearingActivities
                                  ? '正在清理活动'
                                  : '清理所有推荐活动',
                              subtitle: '删除当前登录用户下的全部线下活动推荐记录',
                              accent: const Color(0xFFE35B6F),
                              enabled:
                                  !_generatingActivity && !_clearingActivities,
                              onTap: _clearActivities,
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
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AdminUsersPage extends StatefulWidget {
  const _AdminUsersPage({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<_AdminUsersPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motionController;
  late final TextEditingController _searchController;
  Timer? _searchDebounce;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  int _total = 0;
  List<_AdminUserSummary> _users = const [];

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    _searchController = TextEditingController();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _motionController.dispose();
    super.dispose();
  }

  void _scheduleSearch(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 360), () {
      if (mounted) _loadUsers(showLoading: true);
    });
  }

  Future<void> _loadUsers({bool showLoading = false}) async {
    if (showLoading || _users.isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() {
        _refreshing = true;
        _error = null;
      });
    }
    try {
      widget.api.authToken = widget.session.token;
      final response = await widget.api.fetchAdminUsers(
        search: _searchController.text,
      );
      if (!mounted) return;
      setState(() {
        _users = response.users;
        _total = response.total;
        _loading = false;
        _refreshing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _asMessage(error);
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _openUserDetail(_AdminUserSummary user) async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => _AdminUserDetailPage(
          api: widget.api,
          session: widget.session,
          user: user,
        ),
      ),
    );
    // Reload so any role change made inside the detail page is reflected.
    if (mounted) _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CupertinoPageScaffold(
      backgroundColor: Colors.transparent,
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: _motionController,
          builder: (context, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _ProfileBackgroundPainter(
                    progress: _motionController.value,
                    isDark: isDark,
                  ),
                ),
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    18,
                    media.padding.top + 12,
                    18,
                    42,
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
                              '用户管理',
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
                            Align(
                              alignment: Alignment.centerRight,
                              child: _refreshing
                                  ? const CupertinoActivityIndicator(radius: 10)
                                  : _AppNavCircleButton(
                                      icon: CupertinoIcons.refresh,
                                      onPressed: () => _loadUsers(),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      CupertinoSearchTextField(
                        controller: _searchController,
                        placeholder: '搜索用户名',
                        onChanged: _scheduleSearch,
                        onSubmitted: (_) => _loadUsers(showLoading: true),
                        style: TextStyle(
                          color: isDark
                              ? AppColors.text
                              : const Color(0xFF12171B),
                          fontSize: 15,
                          letterSpacing: 0,
                        ),
                        itemColor: isDark
                            ? const Color(0x9EEBF2EE)
                            : AppColors.muted,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _ProfileSectionV6(
                        title: '用户列表',
                        trailing: _loading && _users.isEmpty
                            ? '加载中'
                            : '共 $_total 人',
                        child: Column(
                          children: [
                            if (_loading && _users.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 30),
                                child: CupertinoActivityIndicator(radius: 12),
                              )
                            else if (_error != null && _users.isEmpty)
                              _AdminStatePanel(
                                title: '加载失败',
                                message: _error!,
                                actionText: '重试',
                                onTap: () => _loadUsers(showLoading: true),
                              )
                            else if (_users.isEmpty)
                              const _AdminStatePanel(
                                title: '暂无用户',
                                message: '当前搜索条件下没有匹配用户。',
                              )
                            else
                              for (final user in _users)
                                _AdminUserRow(
                                  user: user,
                                  onTap: () => _openUserDetail(user),
                                ),
                            if (_error != null && _users.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Color(0xFFE35B6F),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0,
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
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AdminUserRow extends StatelessWidget {
  const _AdminUserRow({required this.user, required this.onTap});

  final _AdminUserSummary user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : const Color(0x14181F2A),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              _AdminUserAvatar(user: user),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.displayName,
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
                        if (user.isAdmin) ...[
                          const SizedBox(width: 8),
                          _AdminRolePill(role: user.role),
                        ],
                      ],
                    ),
                    const SizedBox(height: 7),
                    _AdminAuthMethodChips(user: user, compact: true),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '›',
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.32)
                      : const Color(0x52182026),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1,
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

class _AdminUserAvatar extends StatelessWidget {
  const _AdminUserAvatar({required this.user});

  final _AdminUserSummary user;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.wechat?.avatarUrl;
    final fallbackText = user.displayName.isEmpty ? '?' : user.displayName[0];
    final fallback = Container(
      color: user.isAdmin
          ? const Color(0xFF2D73FF).withValues(alpha: 0.16)
          : const Color(0xFF1FA97A).withValues(alpha: 0.14),
      alignment: Alignment.center,
      child: Text(
        fallbackText,
        style: TextStyle(
          color: user.isAdmin
              ? const Color(0xFF2D73FF)
              : const Color(0xFF1FA97A),
          fontSize: 17,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
          decoration: TextDecoration.none,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 44,
        height: 44,
        child: avatarUrl == null
            ? fallback
            : Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return fallback;
                },
              ),
      ),
    );
  }
}

class _AdminRolePill extends StatelessWidget {
  const _AdminRolePill({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final admin = role == 'admin';
    final color = admin ? const Color(0xFF2D73FF) : const Color(0xFF1FA97A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        _adminRoleLabel(role),
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _AdminAuthMethodChips extends StatelessWidget {
  const _AdminAuthMethodChips({required this.user, this.compact = false});

  final _AdminUserSummary user;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final methods = _adminAuthMethods(user);
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        for (final method in methods)
          _AdminAuthMethodChip(method: method, compact: compact),
      ],
    );
  }
}

class _AdminAuthMethodChip extends StatelessWidget {
  const _AdminAuthMethodChip({required this.method, required this.compact});

  final _AdminAuthMethod method;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = _adminAuthMethodColor(method.type);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        method.label,
        style: TextStyle(
          color: color,
          fontSize: compact ? 10 : 10.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _AdminStatePanel extends StatelessWidget {
  const _AdminStatePanel({
    required this.title,
    required this.message,
    this.actionText,
    this.onTap,
  });

  final String title;
  final String message;
  final String? actionText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: isDark ? AppColors.text : const Color(0xFF12171B),
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
          if (actionText != null && onTap != null) ...[
            const SizedBox(height: 12),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF2D73FF),
              borderRadius: BorderRadius.circular(999),
              onPressed: onTap,
              child: Text(actionText!),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminUserDetailPage extends StatefulWidget {
  const _AdminUserDetailPage({
    required this.api,
    required this.session,
    required this.user,
  });

  final CompanionApi api;
  final AuthSession session;
  final _AdminUserSummary user;

  @override
  State<_AdminUserDetailPage> createState() => _AdminUserDetailPageState();
}

class _AdminUserDetailPageState extends State<_AdminUserDetailPage> {
  bool _loading = true;
  String? _error;
  _AdminUserDetail? _detail;
  late String _role;
  bool _updatingRole = false;

  @override
  void initState() {
    super.initState();
    _role = widget.user.role;
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      widget.api.authToken = widget.session.token;
      final detail = await widget.api.fetchAdminUserDetail(widget.user.id);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _role = detail.user.role;
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

  bool get _isSelf => widget.user.id == widget.session.userId;

  Future<void> _toggleRole() async {
    if (_updatingRole || _isSelf) return;
    final nextRole = _role == 'admin' ? 'user' : 'admin';
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text('修改权限为${_adminRoleLabel(nextRole)}？'),
          content: Text(
            nextRole == 'admin'
                ? '确认后，${widget.user.displayName} 将获得管理员入口和后台管理权限。'
                : '确认后，${widget.user.displayName} 将失去管理员权限。',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: _role == 'admin',
              isDefaultAction: _role != 'admin',
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认修改'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    setState(() => _updatingRole = true);
    try {
      widget.api.authToken = widget.session.token;
      final updatedRole = await widget.api.updateAdminUserRole(
        userId: widget.user.id,
        role: nextRole,
      );
      if (!mounted) return;
      setState(() {
        _role = updatedRole;
        _updatingRole = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _updatingRole = false);
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) {
          return CupertinoAlertDialog(
            title: const Text('修改失败'),
            content: Text(_asMessage(error)),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('知道了'),
              ),
            ],
          );
        },
      );
    }
  }

  void _openAgentConversations(_AdminAgentSummary agent) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => _AdminAgentConversationsPage(
          api: widget.api,
          session: widget.session,
          agent: agent,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _AdminScaffold(
      title: '用户详情',
      subtitle: widget.user.displayName,
      trailing: _loading
          ? const Padding(
              padding: EdgeInsets.only(right: 4),
              child: CupertinoActivityIndicator(radius: 10),
            )
          : _AppNavCircleButton(
              icon: CupertinoIcons.refresh,
              onPressed: _loadDetail,
            ),
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    final detail = _detail;
    if (_loading && detail == null) {
      return const Center(child: CupertinoActivityIndicator(radius: 14));
    }
    if (_error != null && detail == null) {
      return _AdminStatePanel(
        title: '详情加载失败',
        message: _error!,
        actionText: '重试',
        onTap: _loadDetail,
      );
    }
    if (detail == null) {
      return const _AdminStatePanel(title: '暂无详情', message: '后台没有返回该用户的详情数据。');
    }
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
      children: [
        _AdminDetailBlock(
          title: '基础信息',
          children: [
            _AdminDetailLine(label: '用户 ID', value: detail.user.id),
            _AdminDetailLine(label: '用户名', value: detail.user.username),
            _AdminDetailLine(label: '角色', value: _adminRoleLabel(_role)),
            _AdminDetailWidgetLine(
              label: '登录方式',
              child: Align(
                alignment: Alignment.centerRight,
                child: _AdminAuthMethodChips(user: detail.user),
              ),
            ),
            _AdminDetailLine(label: '邮箱', value: detail.user.email ?? '暂无'),
            _AdminDetailLine(
              label: '手机号',
              value: detail.user.phone?.phone ?? '暂无',
            ),
            _AdminDetailLine(label: '状态', value: detail.user.status),
            _AdminDetailLine(
              label: '创建时间',
              value: _adminDateLabel(detail.user.createdAt),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _AdminWechatBlock(wechat: detail.user.wechat),
        const SizedBox(height: 12),
        _buildRoleCard(),
        const SizedBox(height: 12),
        _buildAgentsSection(detail),
        const SizedBox(height: 12),
        _buildWorkspacesSection(detail),
      ],
    );
  }

  Widget _buildRoleCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppColors.of(context);
    final isAdminRole = _role == 'admin';
    final toAdmin = !isAdminRole;
    final roleColor = isAdminRole
        ? const Color(0xFF2D73FF)
        : const Color(0xFF1FA97A);
    return _AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — deliberately w700 (not w900) so CJK glyphs like 「管」
          // stay crisp instead of rendering heavy/blurry.
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  CupertinoIcons.shield_lefthalf_fill,
                  color: colors.accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '权限管理',
                style: TextStyle(
                  color: isDark ? AppColors.text : const Color(0xFF12171B),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Current role row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: isDark ? 0.14 : 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: roleColor.withValues(alpha: 0.22)),
            ),
            child: Row(
              children: [
                Icon(
                  isAdminRole
                      ? CupertinoIcons.checkmark_seal_fill
                      : CupertinoIcons.person_fill,
                  color: roleColor,
                  size: 17,
                ),
                const SizedBox(width: 8),
                Text(
                  '当前角色',
                  style: TextStyle(
                    color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
                const Spacer(),
                Text(
                  _adminRoleLabel(_role),
                  style: TextStyle(
                    color: roleColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_isSelf)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0x0A181F2A),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.lock_fill,
                    size: 15,
                    color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '这是当前登录账号，无法修改自身权限',
                      style: TextStyle(
                        color: isDark
                            ? const Color(0x9EEBF2EE)
                            : AppColors.muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            _AdminRoleActionButton(
              color: toAdmin ? const Color(0xFF2D73FF) : colors.danger,
              icon: toAdmin
                  ? Icons.add_moderator_rounded
                  : Icons.remove_moderator_rounded,
              label: toAdmin ? '设为管理员' : '改为普通用户',
              loading: _updatingRole,
              onTap: _toggleRole,
            ),
        ],
      ),
    );
  }

  Widget _buildAgentsSection(_AdminUserDetail detail) {
    if (detail.agents.isEmpty) {
      return const _AdminDetailBlock(
        title: 'AI 伴侣',
        children: [_AdminDetailLine(label: '记录', value: '暂无 AI')],
      );
    }
    return _AdminDetailBlock(
      title: 'AI 伴侣 · 点击查看对话记录',
      children: [
        for (final agent in detail.agents)
          _AdminNavRow(
            title: agent.name,
            subtitle:
                '${agent.status} · ${agent.conversationCount} 会话 · ${agent.messageCount} 消息',
            onTap: () => _openAgentConversations(agent),
          ),
      ],
    );
  }

  Widget _buildWorkspacesSection(_AdminUserDetail detail) {
    return _AdminDetailBlock(
      title: '工作区',
      children: detail.workspaces.isEmpty
          ? const [_AdminDetailLine(label: '记录', value: '暂无工作区')]
          : [
              for (final workspace in detail.workspaces)
                _AdminDetailLine(
                  label: workspace.agentName ?? workspace.id,
                  value:
                      '${workspace.status} · ${workspace.conversationCount} 会话 · ${workspace.messageCount} 消息',
                ),
            ],
    );
  }
}

/// Tappable row (agent -> conversations, conversation -> messages).
/// Full-width filled action button with an explicit white label + icon, so the
/// text is always high-contrast on the colored fill (unlike a bare
/// CupertinoButton whose label color is inherited).
class _AdminRoleActionButton extends StatelessWidget {
  const _AdminRoleActionButton({
    required this.color,
    required this.icon,
    required this.label,
    required this.loading,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String label;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.32),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: loading
              ? const CupertinoActivityIndicator(
                  radius: 10,
                  color: Colors.white,
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 19),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
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

class _AdminNavRow extends StatelessWidget {
  const _AdminNavRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
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
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
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
            const SizedBox(width: 10),
            Text(
              '›',
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.32)
                    : const Color(0x52182026),
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminAgentConversationsPage extends StatelessWidget {
  const _AdminAgentConversationsPage({
    required this.api,
    required this.session,
    required this.agent,
  });

  final CompanionApi api;
  final AuthSession session;
  final _AdminAgentSummary agent;

  void _openConversation(
    BuildContext context,
    _AdminConversation conversation,
  ) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => _AdminConversationPage(
          api: api,
          session: session,
          agentName: agent.name,
          conversation: conversation,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversations = [...agent.conversations]
      ..sort((a, b) => (b.updatedAt ?? '').compareTo(a.updatedAt ?? ''));
    return _AdminScaffold(
      title: '对话记录',
      subtitle: '${agent.name} · ${conversations.length} 个会话',
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        children: [
          if (conversations.isEmpty)
            const _AdminStatePanel(title: '暂无对话', message: '该 AI 还没有任何会话记录。')
          else
            _AdminCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  for (final conversation in conversations)
                    _AdminNavRow(
                      title:
                          '#${_shortId(conversation.id)}'
                          '${conversation.isDeleted ? ' · 已删除' : ''}',
                      subtitle:
                          '${conversation.messageCount} 条消息 · ${_adminDateLabel(conversation.updatedAt)}',
                      onTap: () => _openConversation(context, conversation),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _shortId(String id) {
  if (id.length <= 8) return id;
  return id.substring(0, 8);
}

class _AdminConversationPage extends StatefulWidget {
  const _AdminConversationPage({
    required this.api,
    required this.session,
    required this.agentName,
    required this.conversation,
  });

  final CompanionApi api;
  final AuthSession session;
  final String agentName;
  final _AdminConversation conversation;

  @override
  State<_AdminConversationPage> createState() => _AdminConversationPageState();
}

class _AdminConversationPageState extends State<_AdminConversationPage> {
  bool _loading = true;
  String? _error;
  List<ChatMessage> _messages = const [];

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
      // API returns newest-first; reverse for a natural chronological transcript.
      final newestFirst = await widget.api.loadMessages(
        widget.conversation.id,
        limit: 200,
      );
      if (!mounted) return;
      setState(() {
        _messages = newestFirst.reversed
            .where((m) => m.isChatMessage)
            .toList(growable: false);
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

  @override
  Widget build(BuildContext context) {
    return _AdminScaffold(
      title: widget.agentName,
      subtitle: '${widget.conversation.messageCount} 条消息',
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
    if (_loading && _messages.isEmpty) {
      return const Center(child: CupertinoActivityIndicator(radius: 14));
    }
    if (_error != null && _messages.isEmpty) {
      return _AdminStatePanel(
        title: '加载失败',
        message: _error!,
        actionText: '重试',
        onTap: _load,
      );
    }
    if (_messages.isEmpty) {
      return const _AdminStatePanel(title: '暂无消息', message: '该会话没有可显示的聊天消息。');
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      itemCount: _messages.length,
      itemBuilder: (context, index) =>
          _AdminMessageBubble(message: _messages[index]),
    );
  }
}

class _AdminMessageBubble extends StatelessWidget {
  const _AdminMessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMine = message.isMine;
    final bubbleColor = isMine
        ? AppColors.of(context).accent
        : (isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.9));
    final textColor = isMine
        ? Colors.white
        : (isDark ? AppColors.text : const Color(0xFF12171B));
    final content = message.content.trim().isEmpty
        ? '（无文本内容）'
        : message.content;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.76,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(16),
              border: isMine
                  ? null
                  : Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0x14181F2A),
                    ),
            ),
            child: SelectableText(
              content,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _adminDateLabel(message.createdAt.toIso8601String()),
            style: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.34)
                  : const Color(0x6612171B),
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminWechatBlock extends StatelessWidget {
  const _AdminWechatBlock({required this.wechat});

  final _AdminWechatIdentity? wechat;

  @override
  Widget build(BuildContext context) {
    if (wechat == null) {
      return const _AdminDetailBlock(
        title: '微信信息',
        children: [_AdminDetailLine(label: '绑定状态', value: '未绑定微信')],
      );
    }
    return _AdminDetailBlock(
      title: '微信信息',
      children: [
        _AdminDetailLine(label: '昵称', value: wechat!.nickname ?? '暂无'),
        _AdminDetailLine(label: 'OpenID', value: wechat!.openid ?? '暂无'),
        _AdminDetailLine(label: 'UnionID', value: wechat!.unionid ?? '暂无'),
        _AdminDetailLine(label: '地区', value: wechat!.location ?? '暂无'),
        _AdminDetailLine(
          label: '最近登录',
          value: _adminDateLabel(wechat!.lastLoginAt),
        ),
      ],
    );
  }
}

class _AdminDetailBlock extends StatelessWidget {
  const _AdminDetailBlock({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.62),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isDark ? AppColors.text : const Color(0xFF12171B),
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }
}

class _AdminDetailLine extends StatelessWidget {
  const _AdminDetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
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
                color: isDark ? AppColors.text : const Color(0xFF12171B),
                fontSize: 12.5,
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

class _AdminDetailWidgetLine extends StatelessWidget {
  const _AdminDetailWidgetLine({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _AdminProgressDialog extends StatelessWidget {
  const _AdminProgressDialog({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text(title),
      content: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          children: [
            const CupertinoActivityIndicator(radius: 12),
            const SizedBox(height: 12),
            Text(message),
          ],
        ),
      ),
    );
  }
}
