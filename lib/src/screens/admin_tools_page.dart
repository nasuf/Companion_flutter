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

  Future<dynamic> _adminRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.openUrl(method, Uri.parse('$baseUrl$path'));
      request.headers.contentType = ContentType.json;
      if (authToken != null && authToken!.isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $authToken',
        );
      }
      if (body != null) request.write(jsonEncode(body));

      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(response.statusCode, _adminErrorFromText(text));
      }
      if (response.statusCode == 204 || text.isEmpty) return null;
      return jsonDecode(text);
    } on SocketException catch (error) {
      throw ApiException(0, '无法连接到后端：${error.message}');
    } on HandshakeException catch (error) {
      throw ApiException(0, '后端连接失败：${error.message}');
    } finally {
      client.close(force: true);
    }
  }

  String _adminErrorFromText(String text) {
    if (text.isEmpty) return '请求失败';
    try {
      final json = jsonDecode(text);
      final detail = json is Map ? json['detail'] : null;
      if (detail is String && detail.isNotEmpty) return detail;
      if (detail != null) return jsonEncode(detail);
      return text;
    } catch (_) {
      return text;
    }
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
    required this.role,
    required this.createdAt,
    required this.status,
    required this.archivedAt,
    required this.agentCount,
    required this.wechat,
  });

  final String id;
  final String username;
  final String role;
  final String? createdAt;
  final String status;
  final String? archivedAt;
  final int agentCount;
  final _AdminWechatIdentity? wechat;

  bool get isAdmin => role == 'admin';

  String get displayName {
    final nickname = wechat?.nickname?.trim();
    if (nickname != null && nickname.isNotEmpty) return nickname;
    return username.isEmpty ? id : username;
  }

  String get subtitle {
    final parts = <String>[
      if (username.isNotEmpty && username != displayName) username,
      '$agentCount 个 AI',
      status,
    ];
    return parts.join(' · ');
  }

  _AdminUserSummary copyWith({String? role}) {
    return _AdminUserSummary(
      id: id,
      username: username,
      role: role ?? this.role,
      createdAt: createdAt,
      status: status,
      archivedAt: archivedAt,
      agentCount: agentCount,
      wechat: wechat,
    );
  }

  factory _AdminUserSummary.fromJson(Map<String, dynamic> json) {
    final wechat = _jsonMapOrNull(json['wechat']);
    return _AdminUserSummary(
      id: _jsonString(json['id']),
      username: _jsonString(json['username']),
      role: _jsonString(json['role'], fallback: 'user'),
      createdAt: _jsonNullableString(json['created_at']),
      status: _jsonString(json['status'], fallback: 'active'),
      archivedAt: _jsonNullableString(json['archived_at']),
      agentCount: _jsonInt(json['agent_count']),
      wechat: wechat == null ? null : _AdminWechatIdentity.fromJson(wechat),
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
  });

  final String id;
  final String name;
  final String? gender;
  final String status;
  final int conversationCount;
  final int messageCount;
  final String? createdAt;

  factory _AdminAgentSummary.fromJson(Map<String, dynamic> json) {
    return _AdminAgentSummary(
      id: _jsonString(json['id']),
      name: _jsonString(json['name'], fallback: '未命名 AI'),
      gender: _jsonNullableString(json['gender']),
      status: _jsonString(json['status'], fallback: 'unknown'),
      conversationCount: _jsonInt(json['conversation_count']),
      messageCount: _jsonInt(json['message_count']),
      createdAt: _jsonNullableString(json['created_at']),
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
                        title: '管理员工具',
                        trailing: '仅用于本地测试',
                        child: Column(
                          children: [
                            _ProfileSettingRowV6(
                              icon: CupertinoIcons.person_2_fill,
                              title: '用户管理',
                              subtitle: '查看用户详情，并调整普通用户 / 管理员权限',
                              accent: const Color(0xFF1FA97A),
                              onTap: _openUserManagement,
                            ),
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ProfileSectionV6(
                        title: '礼物 / 快递测试',
                        trailing: '走 mock 链路',
                        child: Column(
                          children: [
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
  String? _updatingUserId;
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

  Future<void> _showUserActions(_AdminUserSummary user) async {
    final canChangeRole = user.id != widget.session.userId;
    final nextRole = user.isAdmin ? 'user' : 'admin';
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: Text(user.displayName),
          message: Text(
            canChangeRole ? user.id : '${user.id}\n当前登录账号不能修改自己的权限',
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop('detail'),
              child: const Text('查看详情'),
            ),
            if (canChangeRole)
              CupertinoActionSheetAction(
                isDestructiveAction: user.isAdmin,
                onPressed: () => Navigator.of(context).pop('role'),
                child: Text(user.isAdmin ? '改为普通用户' : '设为管理员'),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        );
      },
    );
    if (!mounted) return;
    if (action == 'detail') {
      await _showUserDetail(user);
    } else if (action == 'role') {
      await _confirmChangeRole(user, nextRole);
    }
  }

  Future<void> _showUserDetail(_AdminUserSummary user) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => _AdminUserDetailSheet(
        api: widget.api,
        session: widget.session,
        user: user,
      ),
    );
  }

  Future<void> _confirmChangeRole(
    _AdminUserSummary user,
    String nextRole,
  ) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text('修改权限为${_adminRoleLabel(nextRole)}？'),
          content: Text(
            nextRole == 'admin'
                ? '确认后，${user.displayName} 将获得管理员入口和后台管理权限。'
                : '确认后，${user.displayName} 将失去管理员权限。',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: user.isAdmin,
              isDefaultAction: !user.isAdmin,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认修改'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _updatingUserId = user.id);
    try {
      widget.api.authToken = widget.session.token;
      final updatedRole = await widget.api.updateAdminUserRole(
        userId: user.id,
        role: nextRole,
      );
      if (!mounted) return;
      setState(() {
        _users = [
          for (final item in _users)
            item.id == user.id ? item.copyWith(role: updatedRole) : item,
        ];
        _updatingUserId = null;
      });
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) {
          return CupertinoAlertDialog(
            title: const Text('权限已更新'),
            content: Text(
              '${user.displayName} 当前为${_adminRoleLabel(updatedRole)}。',
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('知道了'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _updatingUserId = null);
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
                                  updating: _updatingUserId == user.id,
                                  onTap: () => _showUserActions(user),
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
  const _AdminUserRow({
    required this.user,
    required this.updating,
    required this.onTap,
  });

  final _AdminUserSummary user;
  final bool updating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: updating ? null : onTap,
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
                        Expanded(
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
                        const SizedBox(width: 8),
                        _AdminRolePill(role: user.role),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      user.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark
                            ? const Color(0x9EEBF2EE)
                            : AppColors.muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID ${user.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.36)
                            : const Color(0x6612171B),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (updating)
                const CupertinoActivityIndicator(radius: 9)
              else
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

class _AdminUserDetailSheet extends StatefulWidget {
  const _AdminUserDetailSheet({
    required this.api,
    required this.session,
    required this.user,
  });

  final CompanionApi api;
  final AuthSession session;
  final _AdminUserSummary user;

  @override
  State<_AdminUserDetailSheet> createState() => _AdminUserDetailSheetState();
}

class _AdminUserDetailSheetState extends State<_AdminUserDetailSheet> {
  bool _loading = true;
  String? _error;
  _AdminUserDetail? _detail;

  @override
  void initState() {
    super.initState();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final height = MediaQuery.sizeOf(context).height * 0.78;
    final detail = _detail;
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Container(
              height: height,
              color: isDark ? const Color(0xFF101614) : const Color(0xFFF7FAFC),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
                    child: Row(
                      children: [
                        _AdminUserAvatar(user: widget.user),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.user.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.text
                                      : const Color(0xFF12171B),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              const SizedBox(height: 5),
                              _AdminRolePill(
                                role: detail?.user.role ?? widget.user.role,
                              ),
                            ],
                          ),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(44, 44),
                          onPressed: () => Navigator.of(context).pop(),
                          child: Icon(
                            CupertinoIcons.xmark_circle_fill,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.48)
                                : const Color(0x6612171B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: CupertinoActivityIndicator(radius: 12),
                          )
                        : _error != null
                        ? _AdminStatePanel(
                            title: '详情加载失败',
                            message: _error!,
                            actionText: '重试',
                            onTap: _loadDetail,
                          )
                        : detail == null
                        ? const _AdminStatePanel(
                            title: '暂无详情',
                            message: '后台没有返回该用户的详情数据。',
                          )
                        : SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                            child: Column(
                              children: [
                                _AdminDetailBlock(
                                  title: '基础信息',
                                  children: [
                                    _AdminDetailLine(
                                      label: '用户 ID',
                                      value: detail.user.id,
                                    ),
                                    _AdminDetailLine(
                                      label: '用户名',
                                      value: detail.user.username,
                                    ),
                                    _AdminDetailLine(
                                      label: '角色',
                                      value: _adminRoleLabel(detail.user.role),
                                    ),
                                    _AdminDetailLine(
                                      label: '状态',
                                      value: detail.user.status,
                                    ),
                                    _AdminDetailLine(
                                      label: '创建时间',
                                      value: _adminDateLabel(
                                        detail.user.createdAt,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _AdminWechatBlock(wechat: detail.user.wechat),
                                const SizedBox(height: 12),
                                _AdminDetailBlock(
                                  title: 'AI 伴侣',
                                  children: detail.agents.isEmpty
                                      ? const [
                                          _AdminDetailLine(
                                            label: '记录',
                                            value: '暂无 AI',
                                          ),
                                        ]
                                      : [
                                          for (final agent in detail.agents)
                                            _AdminDetailLine(
                                              label: agent.name,
                                              value:
                                                  '${agent.status} · ${agent.conversationCount} 会话 · ${agent.messageCount} 消息',
                                            ),
                                        ],
                                ),
                                const SizedBox(height: 12),
                                _AdminDetailBlock(
                                  title: '工作区',
                                  children: detail.workspaces.isEmpty
                                      ? const [
                                          _AdminDetailLine(
                                            label: '记录',
                                            value: '暂无工作区',
                                          ),
                                        ]
                                      : [
                                          for (final workspace
                                              in detail.workspaces)
                                            _AdminDetailLine(
                                              label:
                                                  workspace.agentName ??
                                                  workspace.id,
                                              value:
                                                  '${workspace.status} · ${workspace.conversationCount} 会话 · ${workspace.messageCount} 消息',
                                            ),
                                        ],
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
