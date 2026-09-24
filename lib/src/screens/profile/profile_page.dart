part of 'package:companion_flutter/main.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.api,
    required this.session,
    required this.active,
    required this.onAgentDeleted,
    required this.onSessionChanged,
    required this.onLogout,
  });

  final CompanionApi api;
  final AuthSession session;
  final bool active;
  final ValueChanged<AuthSession> onAgentDeleted;

  /// 昵称 / 头像改动的回传口。与 [onAgentDeleted] 分开是因为后者还要顺带把
  /// 界面切回聊天页，这里只更新 session。
  final ValueChanged<AuthSession> onSessionChanged;
  final VoidCallback onLogout;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motionController;
  bool _deleting = false;
  ProfileStats? _profileStats;
  bool _profileStatsLoading = false;
  String? _profileStatsError;
  int _profileStatsRequestId = 0;
  int? _backpackItemCount;
  IapMembership? _membership;
  String? _error;
  String _appVersionLabel = '...';

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9600),
    );
    _syncTabMotion();
    _loadMePageData();
    _loadAppVersionLabel();
  }

  void _syncTabMotion() {
    if (!mounted) return;
    if (widget.active) {
      if (!_motionController.isAnimating) {
        _motionController.repeat();
      }
    } else {
      _motionController.stop();
    }
  }

  Future<void> _loadAppVersionLabel() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final label = info.buildNumber.isEmpty
          ? 'v${info.version}'
          : 'v${info.version} (${info.buildNumber})';
      if (!mounted) return;
      setState(() => _appVersionLabel = label);
    } catch (_) {
      if (!mounted) return;
      setState(() => _appVersionLabel = 'v?');
    }
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _syncTabMotion();
    }
    if (oldWidget.session.workspaceId != widget.session.workspaceId ||
        oldWidget.session.agentId != widget.session.agentId ||
        oldWidget.session.token != widget.session.token) {
      _loadMePageData();
    }
  }

  @override
  void dispose() {
    _profileStatsRequestId += 1;
    _motionController.dispose();
    super.dispose();
  }

  int _totalBackpackItems(StoreInventoryResponse inventory) {
    return inventory.items
        .where((item) => item.productKind.isNotEmpty && item.quantity > 0)
        .fold<int>(0, (sum, item) => sum + item.quantity);
  }

  Future<void> _loadMePageData() async {
    if (widget.session.agentId == null || widget.session.agentId!.isEmpty) {
      setState(() {
        _profileStats = null;
        _profileStatsLoading = false;
        _profileStatsError = null;
        _backpackItemCount = null;
        _membership = null;
      });
      return;
    }
    final requestId = ++_profileStatsRequestId;
    setState(() {
      _profileStats = null;
      _profileStatsLoading = true;
      _profileStatsError = null;
      _backpackItemCount = null;
      _membership = null;
    });
    try {
      widget.api.authToken = widget.session.token;
      final results = await Future.wait<Object?>([
        widget.api.fetchProfileStats(workspaceId: widget.session.workspaceId),
        widget.api.listStoreInventory(),
        widget.api.getIapMembership(),
      ]);
      if (!mounted || requestId != _profileStatsRequestId) return;
      final stats = results[0]! as ProfileStats;
      final inventory = results[1]! as StoreInventoryResponse;
      final membership = results[2]! as IapMembership;
      setState(() {
        _profileStats = stats;
        _profileStatsLoading = false;
        _backpackItemCount = _totalBackpackItems(inventory);
        _membership = membership;
      });
    } catch (error) {
      if (!mounted || requestId != _profileStatsRequestId) return;
      setState(() {
        _profileStats = null;
        _profileStatsLoading = false;
        _profileStatsError = _asMessage(error);
        _backpackItemCount = null;
        _membership = null;
      });
    }
  }

  Future<void> _confirmDeleteAgent({bool popOverlayRoute = false}) async {
    final agentId = widget.session.agentId;
    if (_deleting || agentId == null || agentId.isEmpty) return;
    final agentName = widget.session.agentName ?? '当前 Agent';
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('删除好友'),
          content: Text(
            '确定要删除「$agentName」吗？\n\n该操作将永久删除聊天记录、关系数据、记忆，以及和这位好友一起玩过的游戏对局，且无法恢复。',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    final confirmedAgain = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('再次确认删除'),
          content: Text(
            '删除「$agentName」后，聊天记录、关系数据、记忆和游戏对局会被永久清除，且无法恢复。\n\n请再次确认是否继续。',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认删除'),
            ),
          ],
        );
      },
    );
    if (confirmedAgain != true || !mounted) return;

    await _deleteAgent(
      agentId,
      agentName: agentName,
      popOverlayRoute: popOverlayRoute,
    );
  }

  Future<void> _confirmLogout() async {
    if (_deleting) return;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('退出登录'),
          content: const Text('退出后不会删除您的数据和AI伙伴，但需要重新登录。'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('再想想'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('退出登录'),
            ),
          ],
        );
      },
    );
    if (confirmed == true && mounted) {
      widget.onLogout();
    }
  }

  Future<void> _deleteAgent(
    String agentId, {
    required String agentName,
    required bool popOverlayRoute,
  }) async {
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      final result = await showGeneralDialog<AgentDeleteResult>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _AgentDeleteGlassOverlay(
            agentName: agentName,
            delete: () => widget.api.deleteAgent(agentId),
          );
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      );
      if (!mounted) return;
      if (result == null) {
        setState(() => _deleting = false);
        return;
      }
      if (popOverlayRoute && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      if (!mounted) return;
      setState(() => _deleting = false);
      widget.onAgentDeleted(
        AuthSession(
          token: widget.session.token,
          userId: widget.session.userId,
          username: widget.session.username,
          userDisplayName: widget.session.userDisplayName,
          userAvatarUrl: widget.session.userAvatarUrl,
          role: widget.session.role,
          hasAgent: false,
          // 删的是 agent，不是账号 —— 绑定状态照旧带上，否则删完 agent 个人资料页
          // 的「登录方式」会变成「账号密码」。（这里刻意逐字段构造而不用 copyWith:
          // 需要把 agent 相关字段清空，而 copyWith 的 null 表示"保持原值"。）
          phone: widget.session.phone,
          wechatBound: widget.session.wechatBound,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _asMessage(error));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _openAdminPanel() async {
    if (_deleting) return;
    await Navigator.of(context).push(
      CompanionPageRoute<void>(
        builder: (_) =>
            AdminToolsPage(api: widget.api, session: widget.session),
      ),
    );
  }

  Future<void> _pushPage(
    Widget page, {
    bool refreshStatsOnReturn = false,
  }) async {
    if (_deleting) return;
    await Navigator.of(
      context,
    ).push(CompanionPageRoute<void>(builder: (_) => page));
    if (refreshStatsOnReturn && mounted) {
      await _loadMePageData();
    }
  }

  Future<void> _showMemberInfo() async {
    await _pushPage(
      StorePage(api: widget.api, session: widget.session),
      refreshStatsOnReturn: true,
    );
  }

  Future<void> _showVersionDialog() async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('版本信息'),
          content: Text('当前版本 $_appVersionLabel\n已经是最新版本。'),
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

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final userName = widget.session.displayNameOr('小星辰');
    final agentName = _displayName(widget.session.agentName, fallback: '小明');
    final topPadding = viewPadding.top + 14;
    final mode = AppThemeScope.of(context).mode;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: _SettingsColors.page),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          // 让内容视口在浮动导航栏上方截止，滚动内容不再显示在导航栏后面。
          bottom: math.max(10, viewPadding.bottom - 2) + 74,
          child: ClipRect(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 8),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _motionController,
                          builder: (context, _) {
                            return _SettingsRelationHeader(
                              progress: _motionController.value,
                              topPadding: topPadding,
                              userName: userName,
                              agentName: agentName,
                              userAvatarUrl: widget.session.userAvatarUrl,
                              agentAvatarUrl: widget.session.agentAvatarUrl,
                              memberActive: _membership?.vip.isVip ?? false,
                              showAdminEntry:
                                  widget.session.role == UserRole.admin,
                              onUserTap: () => _pushPage(
                                _ProfileInfoPage(
                                  api: widget.api,
                                  session: widget.session,
                                  onSessionChanged: widget.onSessionChanged,
                                ),
                              ),
                              onAgentTap: () => _pushPage(
                                _AiAppearancePage(
                                  agentName: agentName,
                                  agentAvatarUrl: widget.session.agentAvatarUrl,
                                ),
                              ),
                              onAdminTap: _openAdminPanel,
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SettingsDashboardGrid(
                              stats: _profileStats,
                              loading: _profileStatsLoading,
                              error: _profileStatsError,
                            ),
                            const SizedBox(height: 14),
                            _SettingsMemberCard(
                              membership: _membership,
                              onTap: _showMemberInfo,
                            ),
                            const SizedBox(height: 12),
                            _SettingsBackpackCard(
                              count:
                                  _backpackItemCount ??
                                  _profileStats?.backpackCount ??
                                  0,
                              onTap: () => _pushPage(
                                _BackpackPage(
                                  api: widget.api,
                                  session: widget.session,
                                ),
                                refreshStatsOnReturn: true,
                              ),
                            ),
                            const SizedBox(height: 18),
                            _SettingsSectionCard(
                              label: '消息与互动',
                              rows: [
                                _SettingsRowData(
                                  glyph: _SettingsGlyph.bell,
                                  iconAccent: _SettingsColors.blue,
                                  title: '通知设置',
                                  onTap: () => _pushPage(
                                    _NotificationSettingsPage(
                                      api: widget.api,
                                      session: widget.session,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _SettingsSectionCard(
                              label: '个性化与显示',
                              rows: [
                                _SettingsRowData(
                                  glyph: _SettingsGlyph.moon,
                                  iconAccent: const Color(0xFF5856D6),
                                  title: '显示模式',
                                  value: _themeModeLabel(mode),
                                  trailing: CupertinoSwitch(
                                    value: mode == ThemeMode.dark,
                                    activeTrackColor: _SettingsColors.blueDark,
                                    onChanged: (value) =>
                                        AppThemeScope.of(context).setMode(
                                          value
                                              ? ThemeMode.dark
                                              : ThemeMode.light,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _SettingsSectionCard(
                              label: '隐私与安全',
                              rows: [
                                _SettingsRowData(
                                  glyph: _SettingsGlyph.lock,
                                  iconAccent: const Color(0xFF34C759),
                                  title: '隐私与安全中心',
                                  onTap: () => _pushPage(
                                    _PrivacySecurityPage(
                                      api: widget.api,
                                      session: widget.session,
                                      initialStats: _profileStats,
                                      onDeleteFriend: () => _confirmDeleteAgent(
                                        popOverlayRoute: true,
                                      ),
                                    ),
                                    refreshStatsOnReturn: true,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _SettingsSectionCard(
                              label: '其他与信息',
                              rows: [
                                _SettingsRowData(
                                  glyph: _SettingsGlyph.tray,
                                  iconAccent: const Color(0xFF64B5F6),
                                  title: '缓存清理',
                                  onTap: () =>
                                      _pushPage(const _CacheCleanupPage()),
                                ),
                                _SettingsRowData(
                                  glyph: _SettingsGlyph.info,
                                  iconAccent: _SettingsColors.blue,
                                  title: '关于我们',
                                  onTap: () => _pushPage(
                                    _AboutCompanionPage(
                                      onContact: () => _pushPage(
                                        _ContactFeedbackPage(
                                          api: widget.api,
                                          session: widget.session,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                _SettingsRowData(
                                  glyph: _SettingsGlyph.cube,
                                  iconAccent: const Color(0xFF90A4AE),
                                  title: '版本信息',
                                  value: _appVersionLabel,
                                  secondaryAction: '检查更新',
                                  onTap: _showVersionDialog,
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            _SettingsAccountActions(onLogout: _confirmLogout),
                            if (_error != null) ...[
                              const SizedBox(height: 14),
                              Text(
                                _error!,
                                style: TextStyle(
                                  color: _SettingsColors.red,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Agent 名字的兜底。用户名字走 [AuthSession.displayNameOr] —— 那条链的优先级
  /// 在服务端，不要把用户名字重新引到这里来拼来源。
  static String _displayName(String? value, {required String fallback}) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return fallback;
    return trimmed;
  }

  static String _themeModeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.dark => '深色',
      ThemeMode.light => '浅色',
      ThemeMode.system => '跟随系统',
    };
  }
}
