part of 'package:companion_flutter/main.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.api,
    required this.session,
    required this.onSessionChanged,
    required this.onLogout,
  });

  final CompanionApi api;
  final AuthSession session;
  final ValueChanged<AuthSession> onSessionChanged;
  final VoidCallback onLogout;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with RouteAware {
  int _index = 0;
  bool _chatSidebarOpen = false;
  bool _routeCovered = false;
  AchievementItem? _activeAchievement;
  AppNotificationEvent? _activeNotification;
  final _chatPageKey = GlobalKey<_ChatPageState>();
  PageRoute<dynamic>? _subscribedRoute;
  OverlayEntry? _notificationOverlay;
  Timer? _notificationTimer;
  StreamSubscription<CheckinNotificationPayload>? _notificationSub;
  StreamSubscription<AppNotificationEvent>? _appNotificationSub;

  bool get _chatContentActive =>
      _index == 0 &&
      !_chatSidebarOpen &&
      !_routeCovered &&
      _activeAchievement == null;

  @override
  void initState() {
    super.initState();
    _notificationSub = CheckinNotificationService.instance.payloads.listen(
      _openCheckinFromNotification,
    );
    _appNotificationSub = AppNotificationService.instance.events.listen(
      _handleAppNotification,
    );
    PushNotificationService.instance.setRouteContext(widget.session);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final payload = CheckinNotificationService.instance.takePendingPayload();
      if (payload != null && mounted) _openCheckinFromNotification(payload);
      final notification = AppNotificationService.instance.takePendingEvent();
      if (notification != null && mounted) _handleAppNotification(notification);
    });
  }

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      PushNotificationService.instance.setRouteContext(widget.session);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is! PageRoute<dynamic> || route == _subscribedRoute) return;
    appRouteObserver.unsubscribe(this);
    _subscribedRoute = route;
    appRouteObserver.subscribe(this, route);
  }

  @override
  void didPushNext() {
    _setRouteCovered(true);
  }

  @override
  void didPopNext() {
    _setRouteCovered(false);
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _removeNotificationOverlay();
    appRouteObserver.unsubscribe(this);
    _notificationSub?.cancel();
    _appNotificationSub?.cancel();
    super.dispose();
  }

  void _setRouteCovered(bool value) {
    if (_routeCovered == value) return;
    setState(() => _routeCovered = value);
  }

  void _setChatSidebarOpen(bool value) {
    if (_chatSidebarOpen == value) return;
    setState(() => _chatSidebarOpen = value);
  }

  void _setAchievementOverlayOpen(bool value) {
    if (value || _activeAchievement == null) return;
    setState(() => _activeAchievement = null);
  }

  void _openAchievementOverlay(AchievementItem item) {
    setState(() => _activeAchievement = item);
  }

  void _closeAchievementOverlay() {
    if (_activeAchievement == null) return;
    setState(() => _activeAchievement = null);
  }

  Future<void> _openSidebarDestination(_SidebarDestination destination) async {
    _setChatSidebarOpen(false);
    final result = await Navigator.of(context).push<CapsuleChatDraft>(
      CupertinoPageRoute<CapsuleChatDraft>(
        builder: (_) => _SidebarDestinationPage(
          destination: destination,
          api: widget.api,
          session: widget.session,
        ),
      ),
    );
    if (!mounted) return;
    _chatPageKey.currentState?.refreshReadyCapsules();
    if (result == null) return;
    setState(() => _index = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatPageKey.currentState?.sendComponentMessage(
        result.agentText,
        result.card,
      );
    });
  }

  Future<void> _openCheckinFromNotification(
    CheckinNotificationPayload payload,
  ) async {
    if (!mounted) return;
    _setChatSidebarOpen(false);
    final result = await Navigator.of(context).push<CapsuleChatDraft>(
      CupertinoPageRoute<CapsuleChatDraft>(
        builder: (_) => CheckinPage(
          api: widget.api,
          session: widget.session,
          initialReminderId:
              payload.memoryId != null && payload.memoryId!.isNotEmpty
              ? payload.memoryId
              : payload.triggerId,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _index = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatPageKey.currentState?.sendComponentMessage(
        result.agentText,
        result.card,
      );
    });
  }

  void _handleAppNotification(AppNotificationEvent event) {
    if (!mounted) return;
    if (event.isRemotePush) {
      _openAppNotification(event);
      return;
    }
    if (event.isChat && !_chatContentActive) {
      _showInAppNotification(event);
    }
  }

  void _showInAppNotification(AppNotificationEvent event) {
    _notificationTimer?.cancel();
    _removeNotificationOverlay();
    _activeNotification = event;
    _notificationOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.paddingOf(context).top + 10,
        left: 18,
        right: 18,
        child: _InAppNotificationBanner(
          event: event,
          onTap: () => _openAppNotification(event),
          onDismiss: _dismissInAppNotification,
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_notificationOverlay!);
    _notificationTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted || _activeNotification?.id != event.id) return;
      _dismissInAppNotification();
    });
  }

  void _dismissInAppNotification() {
    _notificationTimer?.cancel();
    _notificationTimer = null;
    _activeNotification = null;
    _removeNotificationOverlay();
  }

  void _removeNotificationOverlay() {
    _notificationOverlay?.remove();
    _notificationOverlay = null;
  }

  void _openAppNotification(AppNotificationEvent event) {
    if (!mounted) return;
    _dismissInAppNotification();
    _setChatSidebarOpen(false);
    Navigator.of(context).popUntil((route) => route.isFirst);
    if (event.isCheckin) {
      unawaited(
        _openCheckinFromNotification(
          CheckinNotificationPayload(
            triggerId: event.triggerId ?? '',
            memoryId: event.memoryId,
          ),
        ),
      );
      return;
    }
    if (event.isCapsule) {
      unawaited(_openSidebarDestination(_SidebarDestination.capsule));
      return;
    }
    if (event.isAchievement) {
      unawaited(_openSidebarDestination(_SidebarDestination.achievement));
      return;
    }
    setState(() => _index = 0);
    _chatPageKey.currentState?.scrollToLatest();
  }

  void _sendDraftToChat(CapsuleChatDraft draft) {
    setState(() => _index = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatPageKey.currentState?.sendComponentMessage(
        draft.agentText,
        draft.card,
      );
    });
  }

  void _handleAgentDeleted(AuthSession session) {
    _setChatSidebarOpen(false);
    setState(() => _index = 0);
    widget.onSessionChanged(session);
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final chatPage = widget.session.conversationId == null
        ? NoAgentPage(
            api: widget.api,
            session: widget.session,
            onSessionChanged: widget.onSessionChanged,
          )
        : ChatPage(
            key: _chatPageKey,
            api: widget.api,
            session: widget.session,
            isActive: _chatContentActive,
            onOpenSidebar: () => _setChatSidebarOpen(true),
            onAchievementDetailRequested: _openAchievementOverlay,
            onAchievementOverlayChanged: _setAchievementOverlayOpen,
          );
    final pages = [
      chatPage,
      OnlineInteractionPage(
        api: widget.api,
        session: widget.session,
        onSendToChat: _sendDraftToChat,
      ),
      OfflineInteractionPage(agentName: widget.session.agentName ?? '伴生'),
      ProfilePage(
        api: widget.api,
        session: widget.session,
        onAgentDeleted: _handleAgentDeleted,
        onLogout: widget.onLogout,
      ),
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          AnimatedScale(
            scale: _chatSidebarOpen ? 0.985 : 1,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: _chatSidebarOpen ? 9 : 0,
                sigmaY: _chatSidebarOpen ? 9 : 0,
              ),
              child: Stack(
                children: [
                  IndexedStack(index: _index, children: pages),
                  AnimatedPositioned(
                    left: 28,
                    right: 28,
                    bottom: _activeAchievement != null
                        ? -92
                        : math.max(10, safeBottom - 2),
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    child: IgnorePointer(
                      ignoring: _activeAchievement != null,
                      child: AnimatedOpacity(
                        opacity: _activeAchievement != null ? 0 : 1,
                        duration: const Duration(milliseconds: 180),
                        child: _FloatingTabBar(
                          selectedIndex: _index,
                          onSelected: (value) => setState(() => _index = value),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_activeAchievement != null)
            Positioned.fill(
              child: _AchievementDetailOverlay(
                item: _activeAchievement!,
                onDismiss: _closeAchievementOverlay,
              ),
            ),
          _ChatSidebarOverlay(
            visible: _chatSidebarOpen,
            onDismiss: () => _setChatSidebarOpen(false),
            onSelected: _openSidebarDestination,
          ),
        ],
      ),
    );
  }
}

class _InAppNotificationBanner extends StatelessWidget {
  const _InAppNotificationBanner({
    required this.event,
    required this.onTap,
    required this.onDismiss,
  });

  final AppNotificationEvent? event;
  final VoidCallback? onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final visible = event != null;
    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle.merge(
        style: const TextStyle(decoration: TextDecoration.none),
        child: IgnorePointer(
          ignoring: !visible,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            offset: visible ? Offset.zero : const Offset(0, -0.7),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              opacity: visible ? 1 : 0,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 370),
                  child: GestureDetector(
                    onTap: onTap,
                    onVerticalDragEnd: (details) {
                      if ((details.primaryVelocity ?? 0) < -80) {
                        onDismiss();
                      }
                    },
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.98),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.hairline),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.11),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                CupertinoIcons.chat_bubble_2_fill,
                                color: AppColors.accent,
                                size: 19,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event?.title ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.text,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    event?.body ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.muted,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: onDismiss,
                              child: Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(
                                  CupertinoIcons.xmark,
                                  color: AppColors.muted,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingTabBar extends StatelessWidget {
  const _FloatingTabBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = [
    (
      icon: CupertinoIcons.chat_bubble_2_fill,
      selectedIcon: CupertinoIcons.chat_bubble_2_fill,
      label: '聊天',
    ),
    (
      icon: CupertinoIcons.antenna_radiowaves_left_right,
      selectedIcon: CupertinoIcons.antenna_radiowaves_left_right,
      label: '线上交互',
    ),
    (
      icon: CupertinoIcons.map_pin_ellipse,
      selectedIcon: CupertinoIcons.map_pin_ellipse,
      label: '线下交互',
    ),
    (
      icon: CupertinoIcons.person_crop_circle,
      selectedIcon: CupertinoIcons.person_crop_circle_fill,
      label: '我的',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 180) return;
        final next = velocity < 0 ? selectedIndex + 1 : selectedIndex - 1;
        onSelected(next.clamp(0, _items.length - 1).toInt());
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xCC121A24)
                  : Colors.white.withValues(alpha: 0.66),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.72),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.52)
                      : const Color(0xFF315B88).withValues(alpha: 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.70),
                  blurRadius: 1,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Stack(
              children: [
                AnimatedAlign(
                  alignment: Alignment(
                    -1 + (selectedIndex * 2 / (_items.length - 1)),
                    0,
                  ),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: FractionallySizedBox(
                    widthFactor: 1 / _items.length,
                    heightFactor: 1,
                    child: Center(
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              isDark
                                  ? const Color(0xFF172231)
                                  : Colors.white.withValues(alpha: 0.96),
                              isDark
                                  ? const Color(0xFF101820)
                                  : Colors.white.withValues(alpha: 0.56),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.16),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < _items.length; i += 1)
                      Expanded(
                        child: _TabBarItem(
                          icon: _items[i].icon,
                          selectedIcon: _items[i].selectedIcon,
                          label: _items[i].label,
                          selected: selectedIndex == i,
                          onTap: () => onSelected(i),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabBarItem extends StatelessWidget {
  const _TabBarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? selectedIcon : icon,
                size: 23,
                color: selected
                    ? AppColors.accent
                    : AppColors.muted.withValues(alpha: 0.64),
              ),
              const SizedBox(height: 5),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: selected ? 5 : 0,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.api,
    required this.session,
    required this.onAgentDeleted,
    required this.onLogout,
  });

  final CompanionApi api;
  final AuthSession session;
  final ValueChanged<AuthSession> onAgentDeleted;
  final VoidCallback onLogout;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  static const _deleteStages = [
    '正在删除对话记录...',
    '正在删除聊天消息...',
    '正在删除记忆库...',
    '正在删除记忆向量索引...',
    '正在删除用户画像...',
    '正在删除作息表与情绪状态...',
    '正在删除主动消息日志与触发器...',
    '正在清理缓存与会话状态...',
    '正在删除 Agent 主记录...',
  ];

  static const _statLabels = {
    'messages': '聊天消息',
    'conversations': '对话',
    'embeddings': '记忆向量',
    'user_memories': '用户记忆',
    'ai_memories': 'AI 记忆',
    'profiles': '用户档案',
    'changelogs': '记忆变更日志',
    'workspaces': '工作区',
    'intimacy': '亲密度',
    'emotion_states': '情绪状态',
    'schedules': '作息表',
    'trait_logs': '性格反馈日志',
    'proactive_logs': '主动消息日志',
    'proactive_counters': '主动消息计数器',
    'proactive_event_logs': '主动事件日志',
    'proactive_states': '主动状态',
    'triggers': '时间触发器',
    'portraits': '用户画像',
    'schedule_logs': '作息调整日志',
    'orphan_user_memories': '孤立用户记忆',
    'redis': 'Redis 缓存',
    'postgres': '运行时状态',
  };

  Timer? _deleteStageTimer;
  late final AnimationController _motionController;
  bool _deleting = false;
  int _deleteStage = 0;
  Map<String, int>? _deleteStats;
  ProfileStats? _profileStats;
  bool _profileStatsLoading = false;
  String? _profileStatsError;
  int _profileStatsRequestId = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9600),
    )..repeat();
    _loadProfileStats();
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.workspaceId != widget.session.workspaceId ||
        oldWidget.session.agentId != widget.session.agentId ||
        oldWidget.session.token != widget.session.token) {
      _loadProfileStats();
    }
  }

  @override
  void dispose() {
    _deleteStageTimer?.cancel();
    _profileStatsRequestId += 1;
    _motionController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileStats() async {
    if (widget.session.agentId == null || widget.session.agentId!.isEmpty) {
      setState(() {
        _profileStats = null;
        _profileStatsLoading = false;
        _profileStatsError = null;
      });
      return;
    }
    final requestId = ++_profileStatsRequestId;
    setState(() {
      _profileStats = null;
      _profileStatsLoading = true;
      _profileStatsError = null;
    });
    try {
      widget.api.authToken = widget.session.token;
      final stats = await widget.api.fetchProfileStats(
        workspaceId: widget.session.workspaceId,
      );
      if (!mounted || requestId != _profileStatsRequestId) return;
      setState(() {
        _profileStats = stats;
        _profileStatsLoading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _profileStatsRequestId) return;
      setState(() {
        _profileStats = null;
        _profileStatsLoading = false;
        _profileStatsError = _asMessage(error);
      });
    }
  }

  Future<void> _confirmDeleteAgent() async {
    final agentId = widget.session.agentId;
    if (_deleting || agentId == null || agentId.isEmpty) return;
    final agentName = widget.session.agentName ?? '当前 Agent';
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('删除 Agent'),
          content: Text(
            '确定要彻底删除「$agentName」的全部数据吗？\n\n包括所有对话、消息、记忆、画像等，此操作不可恢复。',
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
    if (confirmed == true) {
      await _deleteAgent(agentId);
    }
  }

  Future<void> _confirmLogout() async {
    if (_deleting) return;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('退出登录'),
          content: const Text('确定要退出当前账号吗？'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('退出'),
            ),
          ],
        );
      },
    );
    if (confirmed == true && mounted) {
      widget.onLogout();
    }
  }

  Future<void> _deleteAgent(String agentId) async {
    setState(() {
      _deleting = true;
      _deleteStage = 0;
      _deleteStats = null;
      _error = null;
    });
    _deleteStageTimer?.cancel();
    _deleteStageTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (!mounted) return;
      setState(() {
        _deleteStage = math.min(_deleteStage + 1, _deleteStages.length - 2);
      });
    });

    try {
      final result = await widget.api.deleteAgent(agentId);
      _deleteStageTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _deleteStage = _deleteStages.length - 1;
        _deleteStats = result.stats;
      });
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      widget.onAgentDeleted(
        AuthSession(
          token: widget.session.token,
          userId: widget.session.userId,
          username: widget.session.username,
          userDisplayName: widget.session.userDisplayName,
          userAvatarUrl: widget.session.userAvatarUrl,
          role: widget.session.role,
          hasAgent: false,
        ),
      );
    } catch (error) {
      _deleteStageTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _error = _asMessage(error);
        _deleting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userName = _displayName(
      widget.session.userDisplayName ?? widget.session.username,
      fallback: '山木',
    );
    final agentName = _displayName(widget.session.agentName, fallback: '小芜');
    final hasAgent =
        widget.session.agentId != null && widget.session.agentId!.isNotEmpty;
    final topPadding = media.padding.top + 48;
    return AnimatedBuilder(
      animation: _motionController,
      builder: (context, _) {
        final motion = _motionController.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _ProfileBackgroundPainter(
                progress: motion,
                isDark: isDark,
              ),
            ),
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(18, topPadding, 18, 126),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfileHeroV6(
                    progress: motion,
                    userName: userName,
                    agentName: agentName,
                    userAvatarUrl: widget.session.userAvatarUrl,
                    agentAvatarUrl: widget.session.agentAvatarUrl,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 20),
                  _ProfileStatusSectionV6(
                    stats: _profileStats,
                    loading: _profileStatsLoading,
                    error: _profileStatsError,
                  ),
                  const SizedBox(height: 20),
                  const _ProfileThemeSectionV6(),
                  const SizedBox(height: 20),
                  _ProfileSettingsSectionV6(
                    hasAgent: hasAgent,
                    deleting: _deleting,
                    onDeleteAgent: _confirmDeleteAgent,
                    onLogout: _confirmLogout,
                  ),
                  if (_deleting) ...[
                    const SizedBox(height: 16),
                    _DeleteProgressPanel(
                      stage: _deleteStages[_deleteStage],
                      stats: _deleteStats,
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFE35B6F),
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
        );
      },
    );
  }

  static String _displayName(String? value, {required String fallback}) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return fallback;
    return trimmed;
  }
}

class _ProfileHeroV6 extends StatelessWidget {
  const _ProfileHeroV6({
    required this.progress,
    required this.userName,
    required this.agentName,
    required this.isDark,
    this.userAvatarUrl,
    this.agentAvatarUrl,
  });

  final double progress;
  final String userName;
  final String agentName;
  final bool isDark;
  final String? userAvatarUrl;
  final String? agentAvatarUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 330,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _ProfileFloatingBlob(
            progress: progress,
            right: -52,
            top: 4,
            width: 218,
            height: 174,
            radius: 58,
            phase: 0,
            rotate: 12,
            xAmplitude: -20,
            yAmplitude: 17,
            begin: const Color(0x851F6FFF),
            end: const Color(0x2E18C6C0),
            highlight: true,
          ),
          _ProfileFloatingBlob(
            progress: progress,
            left: -34,
            bottom: 8,
            width: 156,
            height: 120,
            radius: 42,
            phase: 0.34,
            rotate: -10,
            xAmplitude: 14,
            yAmplitude: -12,
            begin: const Color(0x33FF8A3D),
            end: const Color(0x1A7C3CFF),
          ),
          Positioned(
            top: 54,
            left: 2,
            right: 112,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'personal space',
                  style: TextStyle(
                    color: Color(0xFF1F6FFF),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '$userName和$agentName',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? AppColors.text : const Color(0xFF12171B),
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    height: 1.04,
                  ),
                ),
                const SizedBox(height: 13),
                Text(
                  '我们一起走过的时光，都在这里慢慢沉淀。',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0x9EEBF2EE)
                        : const Color(0x94182026),
                    fontSize: 13.2,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 8,
            bottom: 36,
            width: 204,
            height: 132,
            child: _ProfileOrbitV6(
              progress: progress,
              userName: userName,
              agentName: agentName,
              userAvatarUrl: userAvatarUrl,
              agentAvatarUrl: agentAvatarUrl,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileFloatingBlob extends StatelessWidget {
  const _ProfileFloatingBlob({
    required this.progress,
    required this.width,
    required this.height,
    required this.radius,
    required this.rotate,
    required this.xAmplitude,
    required this.yAmplitude,
    required this.begin,
    required this.end,
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.phase = 0,
    this.highlight = false,
  });

  final double progress;
  final double width;
  final double height;
  final double radius;
  final double rotate;
  final double xAmplitude;
  final double yAmplitude;
  final Color begin;
  final Color end;
  final double? left;
  final double? top;
  final double? right;
  final double? bottom;
  final double phase;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final wave = (math.sin((progress + phase) * math.pi * 2) + 1) / 2;
    final turn = rotate + (highlight ? 5 : -5) * wave;
    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      child: Transform.translate(
        offset: Offset(xAmplitude * wave, yAmplitude * wave),
        child: Transform.rotate(
          angle: turn * math.pi / 180,
          child: Transform.scale(
            scale: 1 + 0.04 * wave,
            child: Opacity(
              opacity: highlight ? 0.68 : 1,
              child: Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [begin, end],
                  ),
                ),
                child: highlight
                    ? Align(
                        alignment: const Alignment(-0.34, -0.52),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileOrbitV6 extends StatelessWidget {
  const _ProfileOrbitV6({
    required this.progress,
    required this.userName,
    required this.agentName,
    required this.isDark,
    this.userAvatarUrl,
    this.agentAvatarUrl,
  });

  final double progress;
  final String userName;
  final String agentName;
  final bool isDark;
  final String? userAvatarUrl;
  final String? agentAvatarUrl;

  @override
  Widget build(BuildContext context) {
    final userDrift = -4 * _wave(progress, 0);
    final agentWave = _wave(progress, -0.36);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 58,
          top: 56,
          child: _ProfileLinkV6(progress: progress),
        ),
        Positioned(
          left: 0,
          bottom: 8 + userDrift,
          child: _ProfilePersonV6(
            progress: progress,
            label: userName,
            assetPath: 'assets/prototype/user-avatar-shanmu.jpg',
            imageUrl: userAvatarUrl,
            size: 72,
            radius: 24,
            isDark: isDark,
          ),
        ),
        Positioned(
          right: 0,
          top: agentWave * 3,
          child: Transform.translate(
            offset: Offset(agentWave * 2, 0),
            child: _ProfilePersonV6(
              progress: progress,
              label: agentName,
              assetPath: 'assets/prototype/agent-avatar.png',
              imageUrl: agentAvatarUrl,
              size: 82,
              radius: 28,
              delay: -0.26,
              isDark: isDark,
            ),
          ),
        ),
      ],
    );
  }

  static double _wave(double value, double phase) {
    return (math.sin((value + phase) * math.pi * 2) + 1) / 2;
  }
}

class _ProfileLinkV6 extends StatelessWidget {
  const _ProfileLinkV6({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final wave = (math.sin(progress * math.pi * 2) + 1) / 2;
    return Transform.translate(
      offset: Offset(2 * wave, -2 * wave),
      child: Transform.rotate(
        angle: (-18 + 2 * wave) * math.pi / 180,
        child: Transform.scale(
          scaleX: 1 + 0.035 * wave,
          child: CustomPaint(
            size: const Size(78, 34),
            painter: _ProfileLinkPainter(progress),
          ),
        ),
      ),
    );
  }
}

class _ProfilePersonV6 extends StatelessWidget {
  const _ProfilePersonV6({
    required this.progress,
    required this.label,
    required this.assetPath,
    required this.size,
    required this.radius,
    required this.isDark,
    this.imageUrl,
    this.delay = 0,
  });

  final double progress;
  final String label;
  final String assetPath;
  final String? imageUrl;
  final double size;
  final double radius;
  final double delay;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final breath = (math.sin((progress + delay) * math.pi * 2 * 2) + 1) / 2;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scale: 1 + 0.025 * breath,
          child: _ProfilePhotoV6(
            assetPath: assetPath,
            imageUrl: imageUrl,
            size: size,
            radius: radius,
          ),
        ),
        const SizedBox(height: 7),
        DecoratedBox(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF485F78).withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark
                    ? const Color(0xB3EBF2EE)
                    : const Color(0xAD12171B),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfilePhotoV6 extends StatelessWidget {
  const _ProfilePhotoV6({
    required this.assetPath,
    required this.size,
    required this.radius,
    this.imageUrl,
  });

  final String assetPath;
  final String? imageUrl;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset(assetPath, fit: BoxFit.cover);
    final trimmed = imageUrl?.trim();
    final image = trimmed == null || trimmed.isEmpty
        ? fallback
        : Image.network(
            trimmed,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => fallback,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return fallback;
            },
          );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFDCEFED),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF485F78).withValues(alpha: 0.16),
            blurRadius: 42,
            offset: const Offset(0, 22),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.88),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: image,
    );
  }
}

class _ProfileStatusSectionV6 extends StatelessWidget {
  const _ProfileStatusSectionV6({
    required this.stats,
    required this.loading,
    required this.error,
  });

  final ProfileStats? stats;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final rows = [
      (
        '亲密阶段',
        stats?.intimacyStage ?? (loading ? '...' : '--'),
        stats?.intimacyStageLabel ?? (loading ? '同步中' : '暂无数据'),
      ),
      (
        '陪伴天数',
        stats == null
            ? (loading ? '...' : '--')
            : _formatCount(stats!.companionDays),
        '天',
      ),
      (
        '累计聊天',
        stats == null
            ? (loading ? '...' : '--')
            : _formatCount(stats!.chatHours),
        '小时',
      ),
      (
        '消息总数',
        stats == null
            ? (loading ? '...' : '--')
            : _formatCount(stats!.messageCount),
        '条',
      ),
    ];
    return _ProfileSectionV6(
      title: '我们的时光',
      trailing:
          stats?.companionSummary ?? (error == null ? '正在同步后台数据' : '后台数据暂不可用'),
      child: Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < rows.length; i += 1)
              Expanded(
                child: _ProfileStatV6(
                  label: rows[i].$1,
                  value: rows[i].$2,
                  unit: rows[i].$3,
                  first: i == 0,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatCount(int value) {
    final text = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i += 1) {
      if (i > 0 && (text.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(text[i]);
    }
    return buffer.toString();
  }
}

class _ProfileStatV6 extends StatelessWidget {
  const _ProfileStatV6({
    required this.label,
    required this.value,
    required this.unit,
    required this.first,
  });

  final String label;
  final String value;
  final String unit;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: first ? Colors.transparent : const Color(0x14181F2A),
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(left: first ? 2 : 10, right: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 26,
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF55746F),
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
                height: 1,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              unit,
              style: const TextStyle(
                color: Color(0x70182026),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileThemeSectionV6 extends StatelessWidget {
  const _ProfileThemeSectionV6();

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeScope.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedMode = controller.mode;
    final isLightSelected =
        selectedMode == ThemeMode.light ||
        (selectedMode == ThemeMode.system && !isDark);
    final isDarkSelected =
        selectedMode == ThemeMode.dark ||
        (selectedMode == ThemeMode.system && isDark);
    return _ProfileSectionV6(
      title: '界面风格',
      trailing: isDark ? '当前 深色' : '当前 浅色',
      child: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Row(
          children: [
            Expanded(
              child: _ProfileThemeModeCardV6(
                label: '浅色',
                caption: '清透明亮',
                icon: CupertinoIcons.sun_max_fill,
                selected: isLightSelected,
                brightness: Brightness.light,
                mode: ThemeMode.light,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ProfileThemeModeCardV6(
                label: '深色',
                caption: '安静沉浸',
                icon: CupertinoIcons.moon_stars_fill,
                selected: isDarkSelected,
                brightness: Brightness.dark,
                mode: ThemeMode.dark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileThemePaletteV6 {
  const _ProfileThemePaletteV6({
    required this.page,
    required this.surface,
    required this.hairline,
    required this.text,
    required this.muted,
    required this.accent,
    required this.accentDeep,
    required this.accentSoft,
    required this.accentCyan,
  });

  final Color page;
  final Color surface;
  final Color hairline;
  final Color text;
  final Color muted;
  final Color accent;
  final Color accentDeep;
  final Color accentSoft;
  final Color accentCyan;

  static const light = _ProfileThemePaletteV6(
    page: Color(0xFFF7FAFF),
    surface: Color(0xFFFFFFFF),
    hairline: Color(0xFFE1E9F6),
    text: Color(0xFF101418),
    muted: Color(0xFF7D8790),
    accent: Color(0xFF0A84FF),
    accentDeep: Color(0xFF1F6FFF),
    accentSoft: Color(0xFFE8F3FF),
    accentCyan: Color(0xFF18C6C0),
  );

  static const dark = _ProfileThemePaletteV6(
    page: Color(0xFF080D14),
    surface: Color(0xFF101820),
    hairline: Color(0xFF263445),
    text: Color(0xFFF2F7FB),
    muted: Color(0xFF9AA8B8),
    accent: Color(0xFF4BA3FF),
    accentDeep: Color(0xFF5C93FF),
    accentSoft: Color(0xFF17324C),
    accentCyan: Color(0xFF2DD8D2),
  );

  static _ProfileThemePaletteV6 forBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }
}

class _ProfileThemeModeCardV6 extends StatelessWidget {
  const _ProfileThemeModeCardV6({
    required this.label,
    required this.caption,
    required this.icon,
    required this.selected,
    required this.brightness,
    required this.mode,
  });

  final String label;
  final String caption;
  final IconData icon;
  final bool selected;
  final Brightness brightness;
  final ThemeMode mode;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardSurface = isDark ? const Color(0xFF101820) : Colors.white;
    final hairline = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFE1E9F6);
    final textColor = isDark ? AppColors.text : const Color(0xFF101418);
    final mutedColor = isDark
        ? Colors.white.withValues(alpha: 0.56)
        : const Color(0xFF7D8790);
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.34)
        : const Color(0xFF315B88).withValues(alpha: 0.10);
    final preview = _ProfileThemePaletteV6.forBrightness(brightness);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(24),
      onPressed: () => AppThemeScope.of(context).setMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? Color.lerp(cardSurface, preview.accentSoft, 0.36)
              : cardSurface.withValues(alpha: 0.56),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? preview.accent.withValues(alpha: 0.74)
                : hairline.withValues(alpha: 0.82),
            width: selected ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? preview.accent.withValues(alpha: 0.16)
                  : shadowColor,
              blurRadius: selected ? 24 : 16,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProfileThemePreviewV6(colors: preview),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: preview.accent.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: preview.accent, size: 15),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: mutedColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? preview.accent : Colors.transparent,
                    border: Border.all(
                      color: selected
                          ? preview.accent
                          : mutedColor.withValues(alpha: 0.34),
                      width: 1.3,
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          CupertinoIcons.check_mark,
                          size: 12,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileThemePreviewV6 extends StatelessWidget {
  const _ProfileThemePreviewV6({required this.colors});

  final _ProfileThemePaletteV6 colors;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.page,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.hairline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [colors.accentDeep, colors.accentCyan],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: colors.text.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                height: 20,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.hairline),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: colors.muted.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.34),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSettingsSectionV6 extends StatelessWidget {
  const _ProfileSettingsSectionV6({
    required this.hasAgent,
    required this.deleting,
    required this.onDeleteAgent,
    required this.onLogout,
  });

  final bool hasAgent;
  final bool deleting;
  final VoidCallback onDeleteAgent;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return _ProfileSectionV6(
      title: '系统设置',
      trailing: '通知、隐私、订阅和数据',
      child: Column(
        children: [
          const SizedBox(height: 2),
          const _ProfileSettingRowV6(
            icon: CupertinoIcons.envelope_fill,
            title: '通知提醒',
            subtitle: '主动消息、任务提醒、免打扰时段',
            accent: Color(0xFF1F6FFF),
          ),
          const _ProfileSettingRowV6(
            icon: CupertinoIcons.location_solid,
            title: '隐私与安全',
            subtitle: '本机加密、登录设备、敏感内容保护',
            accent: Color(0xFF18C6C0),
          ),
          const _ProfileSettingRowV6(
            icon: CupertinoIcons.bag_fill,
            title: '订阅与账单',
            subtitle: 'VIP 至 2026/06/19，发票与续费',
            accent: Color(0xFFFF8A3D),
          ),
          const _ProfileSettingRowV6(
            icon: CupertinoIcons.check_mark,
            title: '字体与系统',
            subtitle: '字体大小、语言、缓存、帮助与反馈',
            accent: Color(0xFF22C66B),
          ),
          const _ProfileSettingRowV6(
            icon: CupertinoIcons.archivebox_fill,
            title: '数据导出',
            subtitle: '聊天记录与个人资料可随时导出',
            accent: Color(0xFF7C3CFF),
          ),
          _ProfileSettingRowV6(
            icon: CupertinoIcons.archivebox_fill,
            title: deleting ? '正在删除当前 agent' : '删除当前 agent',
            subtitle: '删除后才可以重新创建新的伴生对象',
            accent: const Color(0xFFE35B6F),
            danger: true,
            enabled: hasAgent && !deleting,
            onTap: onDeleteAgent,
          ),
          _ProfileSettingRowV6(
            icon: CupertinoIcons.square_arrow_right,
            title: '退出登录',
            subtitle: '退出当前账号，回到登录页',
            accent: const Color(0xFF5F6D7A),
            danger: true,
            enabled: !deleting,
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

class _ProfileSectionV6 extends StatelessWidget {
  const _ProfileSectionV6({
    required this.title,
    required this.trailing,
    required this.child,
  });

  final String title;
  final String trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
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
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? AppColors.text : const Color(0xFF12171B),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    trailing,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _ProfileSettingRowV6 extends StatelessWidget {
  const _ProfileSettingRowV6({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    this.danger = false,
    this.enabled = true,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final bool danger;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = enabled && onTap != null;
    return Tooltip(
      message: active ? title : '暂未开放',
      child: InkWell(
        onTap: active ? onTap : null,
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
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: enabled ? 1 : 0.45),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: danger
                              ? const Color(0xFFE35B6F)
                              : (isDark
                                    ? AppColors.text
                                    : const Color(0xFF12171B)),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark
                              ? const Color(0x9EEBF2EE)
                              : AppColors.muted,
                          fontSize: 11.2,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '›',
                  style: TextStyle(
                    color: danger
                        ? const Color(0xFFE35B6F)
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.32)
                              : const Color(0x52182026)),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileBackgroundPainter extends CustomPainter {
  const _ProfileBackgroundPainter({
    required this.progress,
    required this.isDark,
  });

  final double progress;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? const [Color(0xFF101614), Color(0xFF0D1211)]
            : const [Color(0xFFFFFAF4), Color(0xFFF9FBFF), Color(0xFFEEF9F8)],
        stops: isDark ? null : const [0, 0.5, 1],
      ).createShader(rect);
    canvas.drawRect(rect, basePaint);

    _drawRadial(
      canvas,
      center: Offset(size.width * 0.82, size.height * 0.08),
      radius: 280,
      color: const Color(0xFF1F6FFF).withValues(alpha: isDark ? 0.16 : 0.20),
    );
    _drawRadial(
      canvas,
      center: Offset(size.width * 0.08, size.height * 0.26),
      radius: 230,
      color: (isDark ? const Color(0xFF7C3CFF) : const Color(0xFFFF8A3D))
          .withValues(alpha: isDark ? 0.13 : 0.16),
    );
    if (!isDark) {
      _drawRadial(
        canvas,
        center: Offset(size.width * 0.78, size.height * 0.68),
        radius: 260,
        color: const Color(0xFF7C3CFF).withValues(alpha: 0.12),
      );
    }

    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : const Color(0xFF202D3A)).withValues(
        alpha: isDark ? 0.025 : 0.042,
      )
      ..strokeWidth = 1;
    const step = 36.0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (!isDark) {
      _drawRadial(
        canvas,
        center: Offset(size.width * 0.84, size.height * 0.18),
        radius: 280,
        color: Colors.white.withValues(alpha: 0.66),
      );
    }
  }

  void _drawRadial(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
      ).createShader(rect);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _ProfileBackgroundPainter oldDelegate) {
    return progress != oldDelegate.progress || isDark != oldDelegate.isDark;
  }
}

class _ProfileLinkPainter extends CustomPainter {
  const _ProfileLinkPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0x421F6FFF)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(0, 0.75), Offset(size.width, 0.75), linePaint);

    const nodes = [
      (Offset(0, 0.75), Color(0xFF18C6C0), 0.0),
      (Offset(34, 0.75), Color(0xFFFFBE3D), -0.32),
      (Offset(78, 0.75), Color(0xFF7C3CFF), -0.64),
    ];
    for (final node in nodes) {
      final wave = (math.sin((progress + node.$3) * math.pi * 2 * 2) + 1) / 2;
      final center = node.$1 + const Offset(0, -0.75);
      final radius = 4 * (0.92 + 0.22 * wave);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = node.$2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.8),
      );
      canvas.drawCircle(center, radius, Paint()..color = node.$2);
    }
  }

  @override
  bool shouldRepaint(covariant _ProfileLinkPainter oldDelegate) {
    return progress != oldDelegate.progress;
  }
}

class _DeleteProgressPanel extends StatelessWidget {
  const _DeleteProgressPanel({required this.stage, required this.stats});

  final String stage;
  final Map<String, int>? stats;

  @override
  Widget build(BuildContext context) {
    final stats = this.stats;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22D95B5B)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                stats == null
                    ? const CupertinoActivityIndicator()
                    : const Icon(
                        CupertinoIcons.check_mark_circled_solid,
                        color: Color(0xFF26A269),
                        size: 18,
                      ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    stats == null ? stage : '删除完成，正在刷新状态...',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            if (stats != null && stats.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry
                      in stats.entries.where((item) => item.value > 0).take(8))
                    _DeleteStatChip(
                      label:
                          _ProfilePageState._statLabels[entry.key] ?? entry.key,
                      value: entry.value,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeleteStatChip extends StatelessWidget {
  const _DeleteStatChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x14D95B5B)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          '$label $value',
          style: const TextStyle(
            color: Color(0x99181F26),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class NoAgentPage extends StatefulWidget {
  const NoAgentPage({
    super.key,
    required this.api,
    required this.session,
    required this.onSessionChanged,
  });

  final CompanionApi api;
  final AuthSession session;
  final ValueChanged<AuthSession> onSessionChanged;

  @override
  State<NoAgentPage> createState() => _NoAgentPageState();
}

class _NoAgentPageState extends State<NoAgentPage> {
  bool _openedCreatePage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _openedCreatePage || widget.session.hasAgent) return;
      _openedCreatePage = true;
      _openCreatePage(context);
    });
  }

  void _openCreatePage(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => AgentCreatePage(
          api: widget.api,
          session: widget.session,
          onCreated: widget.onSessionChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '聊天',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.person_2_square_stack,
                    color: AppColors.muted,
                    size: 56,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.session.hasAgent ? '还没有可用会话' : '创建你的 AI 伙伴',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '先设定TA的名字、性别和灵魂倾向，头像会在后端自动生成。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, height: 1.45),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: () => _openCreatePage(context),
                    child: const Text('进入 Agent 创建页'),
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
