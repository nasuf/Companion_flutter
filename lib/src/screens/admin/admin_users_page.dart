part of 'package:companion_flutter/main.dart';

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
  // Quick client-side filters over the loaded page.
  String? _roleFilter; // null = 全部 | 'admin' | 'user'
  String? _methodFilter; // null = 全部 | 'wechat' | 'phone' | 'password'

  List<_AdminUserSummary> get _filteredUsers {
    return _users
        .where((user) {
          if (_roleFilter != null && user.role != _roleFilter) return false;
          if (_methodFilter != null &&
              !_adminAuthMethods(user).any((m) => m.type == _methodFilter)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  bool get _hasFilter => _roleFilter != null || _methodFilter != null;

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
        limit: 200,
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
      CompanionPageRoute<void>(
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

  Widget _buildUserFilters(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AdminFilterRow(
          label: '角色',
          options: const [
            MapEntry(null, '全部'),
            MapEntry('admin', '管理员'),
            MapEntry('user', '普通用户'),
          ],
          value: _roleFilter,
          onChanged: (value) => setState(() => _roleFilter = value),
        ),
        const SizedBox(height: 10),
        _AdminFilterRow(
          label: '登录',
          options: const [
            MapEntry(null, '全部'),
            MapEntry('wechat', '微信'),
            MapEntry('phone', '手机号'),
            MapEntry('password', '账号密码'),
          ],
          value: _methodFilter,
          onChanged: (value) => setState(() => _methodFilter = value),
        ),
      ],
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
                      const SizedBox(height: 14),
                      _buildUserFilters(isDark),
                      const SizedBox(height: 16),
                      _ProfileSectionV6(
                        title: '用户列表',
                        trailing: _loading && _users.isEmpty
                            ? '加载中'
                            : _hasFilter
                            ? '筛选 ${_filteredUsers.length} / $_total 人'
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
                            else if (_filteredUsers.isEmpty)
                              const _AdminStatePanel(
                                title: '无匹配用户',
                                message: '当前筛选条件下没有用户，试试调整筛选。',
                              )
                            else
                              for (final user in _filteredUsers)
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
            );
          },
        ),
      ),
    );
  }
}

/// A labeled row of single-select filter chips (角色 / 登录方式).
class _AdminFilterRow extends StatelessWidget {
  const _AdminFilterRow({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<MapEntry<String?, String>> options;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 34,
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
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                _AdminFilterChip(
                  label: option.value,
                  selected: option.key == value,
                  onTap: () => onChanged(option.key),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminFilterChip extends StatelessWidget {
  const _AdminFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? colors.accent
              : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.82)),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? colors.accent
                : (isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : const Color(0x14181F2A)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.white
                : (isDark ? const Color(0xD0EBF2EE) : const Color(0xFF12171B)),
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
            decoration: TextDecoration.none,
          ),
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
      CompanionPageRoute<void>(
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
      CompanionPageRoute<void>(
        builder: (_) => _AdminConversationPage(
          api: api,
          session: session,
          agentName: agent.name,
          conversation: conversation,
        ),
      ),
    );
  }

  void _openTtsConfig(BuildContext context) {
    Navigator.of(context).push(
      CompanionPageRoute<void>(
        builder: (_) =>
            _AdminAgentTtsPage(api: api, session: session, agent: agent),
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
          _AdminCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: _AdminNavRow(
              title: '语音配置',
              subtitle: '音色 · 语速 · 音调 · 情绪 · 即时试听',
              onTap: () => _openTtsConfig(context),
            ),
          ),
          const SizedBox(height: 12),
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

int _ttsInstructionCharacters(String value) {
  var total = 0;
  for (final rune in value.trim().runes) {
    final isHan =
        (rune >= 0x3400 && rune <= 0x4DBF) ||
        (rune >= 0x4E00 && rune <= 0x9FFF) ||
        (rune >= 0xF900 && rune <= 0xFAFF) ||
        (rune >= 0x20000 && rune <= 0x323AF);
    total += isHan ? 2 : 1;
  }
  return total;
}
