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
  static const _tabCount = 4;

  int _index = 0;
  final Set<int> _visitedTabs = {0};
  final _onlineTabKey = GlobalKey();
  final _offlineTabKey = GlobalKey();
  final _profileTabKey = GlobalKey();
  bool _chatSidebarOpen = false;
  bool _routeCovered = false;
  bool _composerPanelOpen = false;
  AchievementItem? _activeAchievement;
  VoiceRecordingOverlaySnapshot? _voiceRecordingOverlay;
  AppNotificationEvent? _activeNotification;
  final _chatPageKey = GlobalKey<_ChatPageState>();
  PageRoute<dynamic>? _subscribedRoute;
  OverlayEntry? _notificationOverlay;
  Timer? _notificationTimer;
  Timer? _routeUncoverTimer;
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
    if (oldWidget.session.conversationId != widget.session.conversationId) {
      _voiceRecordingOverlay = null;
    }
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
    _routeUncoverTimer?.cancel();
    DisplayRefreshRate.suppressRecover(
      DisplayRefreshPolicy.routeRecoverSuppress,
    );
    _setRouteCovered(true);
  }

  @override
  void didPopNext() {
    _routeUncoverTimer?.cancel();
    DisplayRefreshRate.suppressRecover(
      DisplayRefreshPolicy.routeRecoverSuppress,
    );
    // Cupertino pop is still on screen. Restoring Chat (viewport bump,
    // transcript publish, capsule scan) in the same frames as the transition
    // is what made chat → weather/capsule → back feel like a low refresh rate.
    _routeUncoverTimer = Timer(DisplayRefreshPolicy.routeUncoverDelay, () {
      if (!mounted) return;
      _setRouteCovered(false);
    });
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _routeUncoverTimer?.cancel();
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

  void _selectTab(int index) {
    if (index < 0 || index >= _tabCount) return;
    final changed = _index != index;
    final leavingOnline = changed && _index == 1;
    final nextTabs = nextVisitedTabs(
      current: _visitedTabs,
      selectedIndex: index,
    );
    setState(() {
      _index = index;
      _visitedTabs
        ..clear()
        ..addAll(nextTabs);
    });
    if (leavingOnline) evictOnlinePortalImages();
    if (changed) {
      DisplayRefreshRate.suppressRecover(
        DisplayRefreshPolicy.routeRecoverSuppress,
      );
      DisplayRefreshRate.onTabBecameVisible();
    }
  }

  void _goToChatTab({bool userInteraction = false}) {
    final leavingOnline = _index == 1;
    final nextTabs = nextVisitedTabs(
      current: _visitedTabs,
      selectedIndex: chatTabIndex,
    );
    setState(() {
      _index = chatTabIndex;
      _visitedTabs
        ..clear()
        ..addAll(nextTabs);
    });
    if (leavingOnline) evictOnlinePortalImages();
    if (userInteraction) {
      DisplayRefreshRate.suppressRecover(
        DisplayRefreshPolicy.routeRecoverSuppress,
      );
      DisplayRefreshRate.onTabBecameVisible();
    }
  }

  void _setChatSidebarOpen(bool value) {
    if (_chatSidebarOpen == value) return;
    if (value) {
      // The sidebar overlay sits in the same Stack as the chat page (this
      // Scaffold is resizeToAvoidBottomInset: false), so it doesn't get
      // pushed up above the keyboard the way the composer does — the OS
      // keyboard would otherwise render on top of it, covering its bottom
      // portion. Dismiss whatever has focus before it opens.
      FocusManager.instance.primaryFocus?.unfocus();
    }
    setState(() => _chatSidebarOpen = value);
  }

  void _setAchievementOverlayOpen(bool value) {
    if (value || _activeAchievement == null) return;
    setState(() => _activeAchievement = null);
  }

  void _setVoiceRecordingOverlay(VoiceRecordingOverlaySnapshot? overlay) {
    if (!mounted || identical(_voiceRecordingOverlay, overlay)) return;
    setState(() => _voiceRecordingOverlay = overlay);
  }

  void _setComposerPanelOpen(bool value) {
    if (!mounted || _composerPanelOpen == value) return;
    setState(() => _composerPanelOpen = value);
  }

  void _openAchievementOverlay(AchievementItem item) {
    setState(() => _activeAchievement = item);
  }

  void _closeAchievementOverlay({int? id}) {
    final active = _activeAchievement;
    if (active == null) return;
    if (id != null && active.id != id) return;
    setState(() => _activeAchievement = null);
  }

  Future<void> _openSidebarDestination(_SidebarDestination destination) async {
    _setChatSidebarOpen(false);
    final result = await Navigator.of(context).push<CapsuleChatDraft>(
      CompanionPageRoute<CapsuleChatDraft>(
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
    _goToChatTab();
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
      CompanionPageRoute<CapsuleChatDraft>(
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
    _goToChatTab();
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
        top: MediaQuery.viewPaddingOf(context).top + 10,
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
    _goToChatTab();
    _chatPageKey.currentState?.scrollToLatest();
  }

  void _sendDraftToChat(CapsuleChatDraft draft) {
    _goToChatTab();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatPageKey.currentState?.sendComponentMessage(
        draft.agentText,
        draft.card,
      );
    });
  }

  void _handleAgentDeleted(AuthSession session) {
    _setChatSidebarOpen(false);
    _goToChatTab();
    widget.onSessionChanged(session);
  }

  @override
  Widget build(BuildContext context) {
    // viewPadding (not padding): an open keyboard collapses padding.bottom to
    // 0, which would slide the floating tab bar down ~one safe-area height and
    // back as the keyboard opens/closes. viewPadding stays constant, so the tab
    // bar holds still through keyboard/panel transitions. Aspect-specific
    // access is critical here: MediaQuery.of subscribes MainShell to
    // viewInsets and rebuilds every tab, ChatPage, and visible message on each
    // IME frame.
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    final tabBarWidth = math.min(
      336.0,
      MediaQuery.sizeOf(context).width - 54.0,
    );
    final voiceRecordingActive = _voiceRecordingOverlay != null;
    // The chat composer panel and the IME both dock to the screen bottom,
    // so the floating tab bar slides away while either is up and returns
    // when the dock is gone.
    final activeAchievement = _activeAchievement;
    final hideTabBar =
        activeAchievement != null ||
        voiceRecordingActive ||
        (_composerPanelOpen && _index == 0);
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
            onVoiceRecordingOverlayChanged: _setVoiceRecordingOverlay,
            onComposerPanelChanged: _setComposerPanelOpen,
          );
    Widget tabPlaceholder(int index) {
      if (!_visitedTabs.contains(index)) {
        return const SizedBox.shrink();
      }
      final Widget child;
      switch (index) {
        case 0:
          child = chatPage;
        case 1:
          child = OnlineInteractionPage(
            key: _onlineTabKey,
            api: widget.api,
            session: widget.session,
            active: tabTickersEnabled(
              selected: _index == 1,
              routeCovered: _routeCovered,
            ),
            onSendToChat: _sendDraftToChat,
          );
        case 2:
          child = OfflineInteractionPage(
            key: _offlineTabKey,
            api: widget.api,
            session: widget.session,
            agentName: widget.session.agentName ?? '伴生',
            active: tabTickersEnabled(
              selected: _index == 2,
              routeCovered: _routeCovered,
            ),
          );
        case 3:
          child = ProfilePage(
            key: _profileTabKey,
            api: widget.api,
            session: widget.session,
            active: tabTickersEnabled(
              selected: _index == 3,
              routeCovered: _routeCovered,
            ),
            onAgentDeleted: _handleAgentDeleted,
            onSessionChanged: widget.onSessionChanged,
            onLogout: widget.onLogout,
          );
        default:
          child = const SizedBox.shrink();
      }
      return RepaintBoundary(
        child: TickerMode(
          enabled: tabTickersEnabled(
            selected: _index == index,
            routeCovered: _routeCovered,
          ),
          child: child,
        ),
      );
    }

    final pages = List<Widget>.generate(_tabCount, tabPlaceholder);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          PlatformSidebarDim(
            enabled: _chatSidebarOpen,
            scale: _chatSidebarOpen ? 0.985 : 1,
            child: Stack(
              children: [
                IndexedStack(index: _index, children: pages),
                AnimatedPositioned(
                  left: 0,
                  right: 0,
                  bottom: hideTabBar ? -92 : math.max(10, safeBottom - 2),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: IgnorePointer(
                    ignoring: hideTabBar,
                    child: AnimatedOpacity(
                      opacity: hideTabBar ? 0 : 1,
                      duration: const Duration(milliseconds: 180),
                      child: Center(
                        child: SizedBox(
                          width: tabBarWidth,
                          child: _FloatingTabBar(
                            selectedIndex: _index,
                            onSelected: _selectTab,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (activeAchievement != null)
            Positioned.fill(
              child: _AchievementDetailOverlay(
                key: ValueKey(activeAchievement.id),
                item: activeAchievement,
                onDismiss: () =>
                    _closeAchievementOverlay(id: activeAchievement.id),
              ),
            ),
          _ChatSidebarOverlay(
            visible: _chatSidebarOpen,
            onDismiss: () => _setChatSidebarOpen(false),
            onSelected: _openSidebarDestination,
          ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !voiceRecordingActive,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: _voiceRecordingOverlay == null
                    ? const SizedBox.shrink()
                    : VoiceRecordingOverlay(
                        key: const ValueKey('voice-recording-overlay'),
                        action: _voiceRecordingOverlay!.action,
                        seconds: _voiceRecordingOverlay!.seconds,
                        preparing: _voiceRecordingOverlay!.preparing,
                        amplitude: _voiceRecordingOverlay!.amplitude,
                      ),
              ),
            ),
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
      activeIcon: 'assets/navigation/tab-chat-active.png',
      inactiveIcon: 'assets/navigation/tab-chat-inactive.png',
      label: '聊天',
    ),
    (
      activeIcon: 'assets/navigation/tab-interaction-active.png',
      inactiveIcon: 'assets/navigation/tab-interaction-inactive.png',
      label: '互动',
    ),
    (
      activeIcon: 'assets/navigation/tab-companion-active.png',
      inactiveIcon: 'assets/navigation/tab-companion-inactive.png',
      label: '陪伴',
    ),
    (
      activeIcon: 'assets/navigation/tab-profile-active.png',
      inactiveIcon: 'assets/navigation/tab-profile-inactive.png',
      label: '我的',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 180) return;
        final next = velocity < 0 ? selectedIndex + 1 : selectedIndex - 1;
        onSelected(next.clamp(0, _items.length - 1).toInt());
      },
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Center(
          child: SizedBox(
            width: 272,
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < _items.length; i += 1)
                  _TabBarItem(
                    activeIcon: _items[i].activeIcon,
                    inactiveIcon: _items[i].inactiveIcon,
                    label: _items[i].label,
                    selected: selectedIndex == i,
                    onTap: () => onSelected(i),
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
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String activeIcon;
  final String inactiveIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: 28,
          height: 44,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox.square(
                dimension: 24,
                child: Image.asset(
                  selected ? activeIcon : inactiveIcon,
                  width: 24,
                  height: 24,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                width: 28,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  textAlign: TextAlign.center,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontSize: 10,
                    color: selected
                        ? const Color(0xFF06C893)
                        : const Color(0xFFC7C7C7),
                    fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                    decoration: TextDecoration.none,
                  ),
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
    _deleteStageTimer?.cancel();
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

  Future<void> _confirmDeleteAgent() async {
    final agentId = widget.session.agentId;
    if (_deleting || agentId == null || agentId.isEmpty) return;
    final agentName = widget.session.agentName ?? '当前 Agent';
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('删除好友'),
          content: Text('确定要删除「$agentName」吗？\n\n该操作将永久删除所有聊天记录、关系数据和记忆，且无法恢复。'),
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
          // 删的是 agent，不是账号 —— 绑定状态照旧带上，否则删完 agent 个人资料页
          // 的「登录方式」会变成「账号密码」。（这里刻意逐字段构造而不用 copyWith:
          // 需要把 agent 相关字段清空，而 copyWith 的 null 表示"保持原值"。）
          phone: widget.session.phone,
          wechatBound: widget.session.wechatBound,
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

  Future<void> _showDeleteAccountDialog() async {
    await _showPlainDialog(
      title: '注销账号',
      message: '账号注销会永久删除账号、AI伙伴及关系记录。该能力暂未开放，请先通过意见反馈联系我们处理。',
      confirmText: '知道了',
      destructive: true,
    );
  }

  Future<void> _showPlainDialog({
    required String title,
    required String message,
    required String confirmText,
    bool destructive = false,
  }) async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              isDestructiveAction: destructive,
              onPressed: () => Navigator.of(context).pop(),
              child: Text(confirmText),
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
                            _SettingsAccountActions(
                              onLogout: _confirmLogout,
                              onDeleteFriend: _confirmDeleteAgent,
                              onDeleteAccount: _showDeleteAccountDialog,
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

class _SettingsColors {
  const _SettingsColors._();

  static bool get isDark => AppColors.current.page == AppColors.dark.page;

  static Color get page =>
      isDark ? const Color(0xFF080D14) : const Color(0xFFE8ECF1);
  static Color get bg =>
      isDark ? const Color(0xFF0D141D) : const Color(0xFFF0F4F8);
  static Color get headerA =>
      isDark ? const Color(0xFF101B27) : const Color(0xFFE3F0FA);
  static Color get headerB =>
      isDark ? const Color(0xFF261D1B) : const Color(0xFFFFF7F2);
  static Color get headerC =>
      isDark ? const Color(0xFF1A1721) : const Color(0xFFFDF0E8);
  static Color get card =>
      isDark ? const Color(0xFF101820) : const Color(0xFFFFFFFF);
  static Color get text =>
      isDark ? const Color(0xFFF2F7FB) : const Color(0xFF1C1C1E);
  static Color get tertiary =>
      isDark ? const Color(0xFF9AA8B8) : const Color(0xFF8E8E93);
  static Color get separator =>
      isDark ? const Color(0xFF263445) : const Color(0xFFE5E5EA);
  static Color get blueLight =>
      isDark ? const Color(0xFF17324C) : const Color(0xFFE8F2FB);
  static Color get blue =>
      isDark ? const Color(0xFF4BA3FF) : const Color(0xFF7AB8E0);
  static Color get blueDark =>
      isDark ? const Color(0xFF6CB6FF) : const Color(0xFF5A9CC8);
  static Color get orangeLight =>
      isDark ? const Color(0xFF3B2A21) : const Color(0xFFFFF0E8);
  static Color get orange =>
      isDark ? const Color(0xFFF3A66E) : const Color(0xFFF5B78A);
  static Color get orangeDark =>
      isDark ? const Color(0xFFFFB783) : const Color(0xFFE8945C);
  static Color get gold =>
      isDark ? const Color(0xFFF1C864) : const Color(0xFFD4A843);
  static Color get goldLight =>
      isDark ? const Color(0xFF3D3218) : const Color(0xFFFDF3D0);
  static Color get red =>
      isDark ? const Color(0xFFFF7777) : const Color(0xFFE8553D);
}

TextStyle _settingsRowTitleStyle() => TextStyle(
  color: _SettingsColors.text,
  fontSize: 15,
  fontWeight: FontWeight.w600,
  letterSpacing: 0,
);

TextStyle _settingsRowValueStyle(Color color) => TextStyle(
  color: color,
  fontSize: 13,
  fontWeight: FontWeight.w500,
  letterSpacing: 0,
);

BoxDecoration _settingsCardDecoration({double radius = 16}) {
  return BoxDecoration(
    color: _SettingsColors.card,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: _SettingsColors.isDark
          ? Colors.white.withValues(alpha: 0.07)
          : Colors.transparent,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(
          alpha: _SettingsColors.isDark ? 0.30 : 0.06,
        ),
        blurRadius: _SettingsColors.isDark ? 10 : 3,
        offset: Offset(0, _SettingsColors.isDark ? 5 : 1),
      ),
    ],
  );
}

class _SettingsRelationHeader extends StatelessWidget {
  const _SettingsRelationHeader({
    required this.progress,
    required this.topPadding,
    required this.userName,
    required this.agentName,
    required this.onUserTap,
    required this.onAgentTap,
    this.userAvatarUrl,
    this.agentAvatarUrl,
    this.memberActive = false,
    this.showAdminEntry = false,
    this.onAdminTap,
  });

  final double progress;
  final double topPadding;
  final String userName;
  final String agentName;
  final String? userAvatarUrl;
  final String? agentAvatarUrl;
  final bool memberActive;
  final bool showAdminEntry;
  final VoidCallback onUserTap;
  final VoidCallback onAgentTap;
  final VoidCallback? onAdminTap;

  /// 头像直径。原为 64，2026-08-12 放大 —— 这是「我的」页的主视觉，64 在手机上偏小。
  ///
  /// 上限受横向空间约束：一行是 16 边距 + 头像列 + 58 连接区 + 头像列 + 16 边距，
  /// 即每列 `(宽 - 90) / 2`，320pt 屏上是 115pt，所以 88 仍有余量。
  /// 再往上调要重新算这个式子，并跑 test/profile_header_test.dart 的多尺寸用例。
  static const _headerAvatarSize = 88.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      // 高度跟着头像走: 内容区 = 高度 - 30(上) - 20(下), 需容纳
      // 头像 + 间距 + 名字(约18) + 14 + 标语(约18)。240 让 Spacer 仍留约 42,
      // 与放大前的留白一致。
      height: topPadding + 240,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _SettingsColors.headerA,
            _SettingsColors.headerB,
            _SettingsColors.headerC,
            _SettingsColors.headerB,
            _SettingsColors.headerA,
          ],
          stops: [0, 0.25, 0.5, 0.75, 1],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: _SettingsColors.isDark
                ? Colors.black.withValues(alpha: 0.34)
                : const Color(0x1A7AB8E0),
            blurRadius: _SettingsColors.isDark ? 18 : 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, topPadding + 30, 16, 20),
            child: Column(
              children: [
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _SettingsAvatarColumn(
                        progress: progress,
                        phase: 0,
                        name: agentName,
                        assetPath: 'assets/prototype/agent-avatar.png',
                        imageUrl: agentAvatarUrl,
                        accent: _SettingsColors.orangeDark,
                        avatarSize: _headerAvatarSize,
                        onTap: onAgentTap,
                      ),
                    ),
                    SizedBox(
                      width: 58,
                      height: _headerAvatarSize,
                      child: _SettingsConnectionBridge(progress: progress),
                    ),
                    Expanded(
                      child: _SettingsAvatarColumn(
                        progress: progress,
                        phase: 0.28,
                        name: userName,
                        assetPath: 'assets/prototype/user-avatar-shanmu.jpg',
                        imageUrl: userAvatarUrl,
                        accent: memberActive
                            ? _SettingsColors.gold
                            : _SettingsColors.blueDark,
                        showCrown: memberActive,
                        showEditDot: true,
                        avatarSize: _headerAvatarSize,
                        onTap: onUserTap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '✦ 故事从这里开始 ✦',
                  style: TextStyle(
                    color: _SettingsColors.isDark
                        ? _SettingsColors.orangeDark
                        : const Color(0xFF9A8C82),
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          if (showAdminEntry && onAdminTap != null)
            Positioned(
              top: topPadding,
              right: 18,
              child: _ProfileAdminButton(onTap: onAdminTap!),
            ),
        ],
      ),
    );
  }
}

class _SettingsAvatarColumn extends StatelessWidget {
  const _SettingsAvatarColumn({
    required this.progress,
    required this.phase,
    required this.name,
    required this.assetPath,
    required this.accent,
    required this.onTap,
    this.imageUrl,
    this.showCrown = false,
    this.showEditDot = false,
    this.avatarSize = 64,
  });

  final double progress;
  final double phase;
  final String name;
  final String assetPath;
  final String? imageUrl;
  final Color accent;
  final bool showCrown;

  /// 头像直径。角标与皇冠都按它等比摆放，见 build 里的说明。
  final double avatarSize;

  /// 只有用户头像可编辑 — AI 头像由后台素材决定, 不给用户改的入口.
  final bool showEditDot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lift = math.sin((progress + phase) * math.pi * 2) * 4;
    final breath = (math.sin((progress + phase) * math.pi * 4) + 1) / 2;
    final dotSize = avatarSize * 23 / 64;
    // 角标圆心落在头像圆周的右下 45° 上。直接沿用固定的 right/bottom 偏移在放大后
    // 会离圆边越来越远 —— 圆的右下角比外接方框的角内缩 r(1-1/√2), 那个量随 r 增长。
    final dotEdge = avatarSize / 2 * (1 - 1 / math.sqrt2) - dotSize / 2;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Transform.translate(
        offset: Offset(0, lift),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: 1 + breath * 0.018,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _SettingsAvatarImage(
                    assetPath: assetPath,
                    imageUrl: imageUrl,
                    accent: accent,
                    size: avatarSize,
                  ),
                  if (showEditDot)
                    Positioned(
                      right: dotEdge,
                      bottom: dotEdge,
                      child: _AvatarEditDot(size: dotSize),
                    ),
                  if (showCrown)
                    Positioned(
                      right: avatarSize * -5 / 64,
                      top: avatarSize * -12 / 64,
                      child: Text(
                        '👑',
                        style: TextStyle(fontSize: avatarSize * 18 / 64),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: avatarSize * 7 / 64),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _SettingsColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsAvatarImage extends StatelessWidget {
  const _SettingsAvatarImage({
    required this.assetPath,
    required this.accent,
    this.imageUrl,
    this.size = 64,
  });

  final String assetPath;
  final String? imageUrl;
  final Color accent;

  /// 直径。默认 64 供「个人资料 / AI 形象」两个二级页的行内小头像用；「我的」
  /// 页顶部的关系头图传更大的值。
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset(assetPath, fit: BoxFit.cover);
    final image = AgentAvatarImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      fallback: fallback,
    );
    return Container(
      width: size,
      height: size,
      // 描边随直径走, 否则放大后那圈渐变边会显得过细。
      padding: EdgeInsets.all(size * 3 / 64),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: _SettingsColors.isDark ? 0.64 : 0.72),
            _SettingsColors.isDark ? _SettingsColors.card : Colors.white,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(child: image),
    );
  }
}

class _AvatarEditDot extends StatelessWidget {
  const _AvatarEditDot({this.size = 23});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _SettingsColors.isDark ? _SettingsColors.card : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: _SettingsColors.isDark ? 0.24 : 0.08,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        CupertinoIcons.pencil,
        size: size * 12 / 23,
        color: _SettingsColors.blueDark,
      ),
    );
  }
}

class _SettingsConnectionBridge extends StatelessWidget {
  const _SettingsConnectionBridge({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final rotation = progress * math.pi * 2;
    final pulse = 1 + math.sin(progress * math.pi * 4) * 0.08;
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.rotate(
          angle: rotation,
          child: CustomPaint(
            size: const Size(40, 40),
            painter: _DashedOrbitPainter(
              color:
                  (_SettingsColors.isDark
                          ? _SettingsColors.orangeDark
                          : const Color(0xFFE0C8B0))
                      .withValues(alpha: 0.82),
            ),
          ),
        ),
        Transform.rotate(
          angle: rotation,
          child: Transform.translate(
            offset: const Offset(0, -18),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _SettingsColors.orange,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        Transform.scale(
          scale: pulse,
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            child: const Text('💫', style: TextStyle(fontSize: 20)),
          ),
        ),
      ],
    );
  }
}

class _DashedOrbitPainter extends CustomPainter {
  const _DashedOrbitPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.butt;
    const dashCount = 12;
    const sweep = math.pi / 12;
    for (var i = 0; i < dashCount; i += 1) {
      canvas.drawArc(
        rect.deflate(2),
        i * math.pi * 2 / dashCount,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedOrbitPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _SettingsDashboardGrid extends StatelessWidget {
  const _SettingsDashboardGrid({
    required this.stats,
    required this.loading,
    required this.error,
  });

  final ProfileStats? stats;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _DashboardCardData(
        glyph: _SettingsGlyph.heart,
        iconAccent: _SettingsColors.orange,
        label: '亲密度',
        accent: _SettingsColors.orange,
        value: stats == null
            ? (loading ? '...' : '--')
            : stats!.topicIntimacy.round().toString(),
        subtext: stats?.intimacySubtitle ?? (loading ? '同步中' : '暂无数据'),
      ),
      _DashboardCardData(
        glyph: _SettingsGlyph.calendar,
        iconAccent: _SettingsColors.blue,
        label: '相识时间',
        accent: _SettingsColors.blue,
        value: stats == null
            ? (loading ? '...' : '--')
            : stats!.companionDays.toString(),
        subtext: stats?.companionStartedOn == null
            ? (loading ? '后台同步中' : '暂无开始日期')
            : '始于 ${stats!.companionStartedOn}',
      ),
      _DashboardCardData(
        glyph: _SettingsGlyph.stopwatch,
        iconAccent: const Color(0xFFA0C8E8),
        label: '相处时光',
        accent: const Color(0xFFA0C8E8),
        value: stats == null
            ? (loading ? '...' : '--')
            : stats!.chatDurationLabel,
        subtext: stats?.chatDurationSubtitle ?? '累计聊天时长',
      ),
      _DashboardCardData(
        glyph: _SettingsGlyph.chat,
        iconAccent: const Color(0xFFD4B89C),
        label: '讯息总数',
        accent: const Color(0xFFD4B89C),
        value: stats == null
            ? (loading ? '...' : '--')
            : stats!.messageCount.toString(),
        subtext: stats?.recent7dMessageLabel ?? '来自后台真实数据',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.72,
          ),
          itemBuilder: (context, index) => _SettingsDashboardCard(cards[index]),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            '后台数据暂不可用：$error',
            style: TextStyle(
              color: _SettingsColors.red,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );
  }
}

class _DashboardCardData {
  const _DashboardCardData({
    required this.glyph,
    required this.iconAccent,
    required this.label,
    required this.accent,
    required this.value,
    required this.subtext,
  });

  final _SettingsGlyph glyph;
  final Color iconAccent;
  final String label;
  final Color accent;
  final String value;
  final String subtext;
}

class _SettingsDashboardCard extends StatelessWidget {
  const _SettingsDashboardCard(this.data);

  final _DashboardCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 78),
      decoration: _settingsCardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _SettingsDashboardLeftBorderPainter(color: data.accent),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 13, 11),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _SettingsFlatIcon(
                      glyph: data.glyph,
                      accent: data.iconAccent,
                      size: 28,
                    ),
                    const SizedBox(width: 6),
                    // Expanded + 右对齐, 而不是 Spacer + 裸 Text: 裸 Text 会按自然
                    // 宽度铺开, 它上面的 maxLines/ellipsis 只在宽度被约束时才生效,
                    // 所以长数值 (如 "48h32m") 在 375pt 宽的机型上是直接溢出而不是
                    // 省略号。视觉不变 —— 放得下时仍然贴右。
                    Expanded(
                      child: Text(
                        data.value,
                        maxLines: 1,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _SettingsColors.isDark
                              ? _SettingsColors.text
                              : const Color(0xFF2A2A2C),
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _SettingsColors.tertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.subtext,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _SettingsColors.orangeDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                    letterSpacing: 0,
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

class _SettingsDashboardLeftBorderPainter extends CustomPainter {
  const _SettingsDashboardLeftBorderPainter({required this.color});

  final Color color;

  // 与卡片圆角一致，让彩色沿着卡片左侧圆角边缘走。
  static const double _radius = 16;
  // 描边宽度（对齐 HTML `border-left: 3px`）。
  static const double _strokeWidth = 3;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= 0 || size.width <= 0) return;
    final r = math.min(_radius, size.height / 2);
    const half = _strokeWidth / 2;
    final effectiveRadius = r - half;
    final topCenter = Offset(r, r);
    final bottomCenter = Offset(r, size.height - r);

    // 完整包住左上/左下圆角：从上切点绕左侧到下切点，
    // 对齐 CSS 单边圆角 border 的走向（沿边缘、在两端绕角）。
    final path = Path()
      ..moveTo(r, half)
      ..arcTo(
        Rect.fromCircle(center: topCenter, radius: effectiveRadius),
        -math.pi / 2,
        -math.pi / 2,
        false,
      )
      ..lineTo(half, size.height - r)
      ..arcTo(
        Rect.fromCircle(center: bottomCenter, radius: effectiveRadius),
        math.pi,
        -math.pi / 2,
        false,
      );

    // 竖直渐变：中段实色最粗，越靠近上下两端（绕角处）越淡直至透明，
    // 还原 HTML 的"由粗到细直至消失"。
    final shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withValues(alpha: 0),
        color,
        color,
        color.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.10, 0.90, 1.0],
    ).createShader(Offset.zero & size);

    final paint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(
    covariant _SettingsDashboardLeftBorderPainter oldDelegate,
  ) {
    return oldDelegate.color != color;
  }
}

class _SettingsBackpackCard extends StatelessWidget {
  const _SettingsBackpackCard({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SettingsTappableCard(
      onTap: onTap,
      child: Row(
        children: [
          _SettingsFlatIcon(
            glyph: _SettingsGlyph.bag,
            accent: _SettingsColors.blue,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('我的背包', style: _settingsRowTitleStyle())),
          Container(
            constraints: const BoxConstraints(minWidth: 30),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: _SettingsColors.orange,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              count.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const _SettingsArrow(),
        ],
      ),
    );
  }
}

class _SettingsMemberCard extends StatelessWidget {
  const _SettingsMemberCard({required this.membership, required this.onTap});

  final IapMembership? membership;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = membership?.vip.isVip ?? false;
    final status = membership == null
        ? '成为会员'
        : membershipPlanBadgeFromMembership(membership!);
    return _SettingsTappableCard(
      onTap: onTap,
      decoration: BoxDecoration(
        color: _SettingsColors.goldLight.withValues(
          alpha: active ? 0.72 : 0.38,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _SettingsColors.gold.withValues(alpha: active ? 0.35 : 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: _SettingsColors.isDark ? 0.24 : 0.05,
            ),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          _SettingsFlatIcon(
            glyph: _SettingsGlyph.star,
            accent: _SettingsColors.gold,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('我的会员 · 尊享特权', style: _settingsRowTitleStyle())),
          Text(
            status,
            style: _settingsRowValueStyle(
              active ? const Color(0xFFA89050) : _SettingsColors.gold,
            ),
          ),
          const SizedBox(width: 8),
          const _SettingsArrow(),
        ],
      ),
    );
  }
}

class _SettingsSectionCard extends StatelessWidget {
  const _SettingsSectionCard({required this.label, required this.rows});

  final String label;
  final List<_SettingsRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _settingsCardDecoration(radius: 22),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 5),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: TextStyle(
                  color: _SettingsColors.tertiary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
          for (var i = 0; i < rows.length; i += 1)
            _SettingsRow(data: rows[i], showDivider: i < rows.length - 1),
        ],
      ),
    );
  }
}

class _SettingsRowData {
  const _SettingsRowData({
    required this.glyph,
    required this.iconAccent,
    required this.title,
    this.value,
    this.secondaryAction,
    this.trailing,
    this.onTap,
  });

  final _SettingsGlyph glyph;
  final Color iconAccent;
  final String title;
  final String? value;
  final String? secondaryAction;
  final Widget? trailing;
  final VoidCallback? onTap;
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.data, required this.showDivider});

  final _SettingsRowData data;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: _SettingsColors.separator,
                  width: 0.8,
                ),
              )
            : null,
      ),
      child: Row(
        children: [
          _SettingsFlatIcon(glyph: data.glyph, accent: data.iconAccent),
          const SizedBox(width: 12),
          Expanded(child: Text(data.title, style: _settingsRowTitleStyle())),
          if (data.value != null) ...[
            Text(
              data.value!,
              style: _settingsRowValueStyle(_SettingsColors.tertiary),
            ),
            const SizedBox(width: 8),
          ],
          if (data.secondaryAction != null)
            Text(
              data.secondaryAction!,
              style: TextStyle(
                color: _SettingsColors.blueDark,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            )
          else if (data.trailing != null)
            data.trailing!
          else
            const _SettingsArrow(),
        ],
      ),
    );
    if (data.onTap == null) return content;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.zero,
      onPressed: data.onTap,
      child: content,
    );
  }
}

class _SettingsAccountActions extends StatelessWidget {
  const _SettingsAccountActions({
    required this.onLogout,
    required this.onDeleteFriend,
    required this.onDeleteAccount,
  });

  final VoidCallback onLogout;
  final VoidCallback onDeleteFriend;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SettingsActionButton(label: '退出登录', onTap: onLogout),
        const SizedBox(height: 10),
        _SettingsActionButton(
          label: '删除好友',
          destructive: true,
          onTap: onDeleteFriend,
        ),
        const SizedBox(height: 10),
        _SettingsActionButton(
          label: '注销账号',
          destructive: true,
          enabled: false,
          onTap: onDeleteAccount,
        ),
      ],
    );
  }
}

class _SettingsActionButton extends StatelessWidget {
  const _SettingsActionButton({
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(14),
      onPressed: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          width: double.infinity,
          height: 50,
          alignment: Alignment.center,
          decoration: destructive
              ? _settingsDangerButtonDecoration(radius: 14)
              : _settingsCardDecoration(radius: 14),
          child: Text(
            label,
            style: TextStyle(
              color: destructive
                  ? (_SettingsColors.isDark
                        ? const Color(0xFFFF8F8A)
                        : const Color(0xFFD43D2E))
                  : _SettingsColors.blueDark,
              fontSize: 15,
              fontWeight: destructive ? FontWeight.w800 : FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration _settingsDangerButtonDecoration({double radius = 16}) {
  final isDark = _SettingsColors.isDark;
  return BoxDecoration(
    color: isDark ? const Color(0xFF331618) : const Color(0xFFFFF5F5),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: isDark
          ? const Color(0xFFFF7777).withValues(alpha: 0.24)
          : const Color(0xFFFFD6D2),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
        blurRadius: isDark ? 10 : 3,
        offset: Offset(0, isDark ? 5 : 1),
      ),
    ],
  );
}

class _SettingsTappableCard extends StatelessWidget {
  const _SettingsTappableCard({
    required this.onTap,
    required this.child,
    this.decoration,
  });

  final VoidCallback onTap;
  final Widget child;
  final BoxDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(16),
      onPressed: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: decoration ?? _settingsCardDecoration(),
        child: child,
      ),
    );
  }
}

/// Settings row glyphs — solid white filled PNGs (weather/capsule flat style).
/// Main silhouette is filled white; 面线 uses tiny cut-outs only (bell stripes,
/// calendar dots, chat dots) — never a hollow body that shows the accent circle.
/// 设置项圆标里的白色字形。
///
/// 用矢量 [IconData] 而非位图 PNG: 原来的 glyph_*.png 是 0.7-1.6KB 的低分辨率
/// 位图, 每张内部留白/线宽各不相同, 放到统一尺寸的圆里就显得"不精致、大小不一"。
/// 矢量图标任意尺寸都清晰, 且视觉重量天然一致 —— 跟天气页度量圆标同一套做法。
enum _SettingsGlyph {
  bell(CupertinoIcons.bell_fill),
  moon(CupertinoIcons.moon_fill),
  lock(CupertinoIcons.lock_fill),
  tray(CupertinoIcons.tray_fill),
  info(CupertinoIcons.info),
  cube(CupertinoIcons.cube_box_fill),
  heart(CupertinoIcons.heart_fill),
  calendar(CupertinoIcons.calendar),
  stopwatch(CupertinoIcons.stopwatch_fill),
  chat(CupertinoIcons.chat_bubble_2_fill),
  bag(CupertinoIcons.bag_fill),
  star(CupertinoIcons.star_fill);

  const _SettingsGlyph(this.icon);

  final IconData icon;
}

class _SettingsFlatIcon extends StatelessWidget {
  const _SettingsFlatIcon({
    required this.glyph,
    required this.accent,
    this.size = 40,
    double? glyphSize,
  }) : glyphSize = glyphSize ?? size * 0.50;

  final _SettingsGlyph glyph;
  final Color accent;
  final double size;

  /// 白色字形直径。统一取圆直径的 0.50 —— 与天气页度量圆标 (24pt / 48pt) 同比,
  /// 让所有圆标里的图标看起来一样大。矢量图标边到边, 不像旧 PNG 自带留白, 所以
  /// 从 0.60 收到 0.50 才不会显得过大。
  final double glyphSize;

  @override
  Widget build(BuildContext context) {
    final dark = _SettingsColors.isDark;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent,
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: accent.withValues(alpha: 0.30),
                  blurRadius: size >= 36 ? 8 : 6,
                  offset: Offset(0, size >= 36 ? 3 : 2),
                ),
              ],
      ),
      child: Icon(glyph.icon, size: glyphSize, color: Colors.white),
    );
  }
}

class _SettingsArrow extends StatelessWidget {
  const _SettingsArrow();

  @override
  Widget build(BuildContext context) {
    return Text(
      '›',
      style: TextStyle(
        color: _SettingsColors.isDark
            ? const Color(0xFF5F6F82)
            : const Color(0xFFC7C7CC),
        fontSize: 24,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1,
      ),
    );
  }
}

class _SettingsSubScaffold extends StatelessWidget {
  const _SettingsSubScaffold({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    return Scaffold(
      backgroundColor: _SettingsColors.page,
      body: Column(
        children: [
          SizedBox(
            height: padding.top + 56,
            child: Padding(
              padding: EdgeInsets.only(top: padding.top),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _WeatherBackButton(
                        onTap: () => Navigator.of(context).pop(),
                        iconColor: _SettingsColors.blueDark,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 72),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _SettingsColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  if (trailing != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: trailing,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SubPageContent extends StatelessWidget {
  const _SubPageContent({required this.children, this.center = false});

  final List<Widget> children;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 36),
      children: [
        if (center)
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: children),
          )
        else
          ...children,
      ],
    );
  }
}

class _SubCard extends StatelessWidget {
  const _SubCard({required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(15),
      decoration: _settingsCardDecoration(),
      child: Column(children: children),
    );
  }
}

class _SubCardRow extends StatelessWidget {
  const _SubCardRow({
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.showDivider = true,
  });

  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: _SettingsColors.separator,
                  width: 0.8,
                ),
              )
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: destructive ? _SettingsColors.red : _SettingsColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
          if (value != null)
            Text(
              value!,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: _SettingsColors.tertiary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          if (trailing != null) trailing!,
        ],
      ),
    );
    if (onTap == null) return content;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.zero,
      onPressed: onTap,
      child: content,
    );
  }
}

/// 账号类型胶囊，跟后台用户管理的 AuthMethodBadges 同一个表达方式：一个账号可能
/// 同时绑了微信和手机号，所以是并排的多个而不是单一文案。
class _LoginMethodBadges extends StatelessWidget {
  const _LoginMethodBadges({required this.methods});

  final List<LoginMethodInfo> methods;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final method in methods)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: _LoginMethodBadge(method),
          ),
      ],
    );
  }
}

class _LoginMethodBadge extends StatelessWidget {
  const _LoginMethodBadge(this.method);

  final LoginMethodInfo method;

  @override
  Widget build(BuildContext context) {
    final dark = _SettingsColors.isDark;
    // 微信用它的品牌绿: 这是个品牌标识, 借用 app 的暖/冷强调色反而让人认不出。
    // 手机号走蓝、密码走中性灰 —— 两者都在既有色板内。
    final (Color bg, Color fg) = switch (method.kind) {
      LoginMethod.wechat =>
        dark
            ? (const Color(0xFF16301F), const Color(0xFF5FD08A))
            : (const Color(0xFFE6F6EC), const Color(0xFF2E9E5B)),
      LoginMethod.phone => (
        _SettingsColors.blueLight,
        _SettingsColors.blueDark,
      ),
      LoginMethod.password => (
        dark ? const Color(0xFF1B2430) : const Color(0xFFEFEFF4),
        _SettingsColors.tertiary,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.28)),
      ),
      child: Text(
        method.label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _SubSectionHeader extends StatelessWidget {
  const _SubSectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            color: _SettingsColors.text,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

/// 个人资料二级页 —— 头像与昵称在这里编辑。
///
/// 改完必须把新 session 通过 [onSessionChanged] 冒泡到 auth_gate: 用户头像除了
/// 这一页，还被顶部关系头图和各棋类对局页读取，只改本页 state 会让它们停在旧值
/// 直到下次冷启动。
class _ProfileInfoPage extends StatefulWidget {
  const _ProfileInfoPage({
    required this.api,
    required this.session,
    required this.onSessionChanged,
  });

  final CompanionApi api;
  final AuthSession session;
  final ValueChanged<AuthSession> onSessionChanged;

  @override
  State<_ProfileInfoPage> createState() => _ProfileInfoPageState();
}

class _ProfileInfoPageState extends State<_ProfileInfoPage> {
  /// 与服务端 `models/user.py: MAX_DISPLAY_NAME_LENGTH` 一致。输入框先挡一道，
  /// 服务端超长只会回 422 的原始校验体，用户看了没法理解。
  static const _maxNicknameLength = 32;

  final _imagePicker = ImagePicker();
  final _nicknameController = TextEditingController();
  bool _busy = false;
  String? _error;

  /// 本页自己持有一份 session。这一页是 push 出来的路由，父级 rebuild 不会重建
  /// 它 —— 只回传给 auth_gate 的话，本页的头像和昵称会停在改动前的值。
  late AuthSession _session = widget.session;

  @override
  void didUpdateWidget(covariant _ProfileInfoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) _session = widget.session;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    if (_busy) return;
    final source = await showCupertinoModalPopup<ImageSource>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(ImageSource.camera),
            child: const Text('拍照'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
            child: const Text('从相册选择'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ),
    );
    if (source == null || !mounted) return;
    await _pickAndUploadAvatar(source);
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    // 取图和上传分开 catch：权限被拒和服务端拒绝是两回事，混在一起会给出"需要
    // 相机权限"这种和实际原因无关的提示。
    final XFile? picked;
    final Uint8List bytes;
    try {
      // 1024 比聊天图的 1600 更小: 头像最终只存 512²，取一倍余量给裁剪留下
      // 放大空间，再大就只是白白拉长上传时间。
      picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      bytes = await picked.readAsBytes();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is MissingPluginException
            ? '图片功能需要完整重启 App 后才能使用。'
            : source == ImageSource.camera
            ? '打不开相机，请检查系统里的相机权限。'
            : '读不到这张图片，请检查系统里的相册权限。';
      });
      return;
    }

    if (!mounted) return;
    final crop = await Navigator.of(context).push<AvatarCropRect>(
      CompanionPageRoute<AvatarCropRect>(
        builder: (_) => AvatarCropPage(imageBytes: bytes),
      ),
    );
    if (crop == null || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      widget.api.authToken = _session.token;
      _applyResult(
        await widget.api.uploadUserAvatar(
          bytes: bytes,
          mime: picked.mimeType ?? _imageMimeFromPath(picked.path),
          crop: crop,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _asMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editNickname() async {
    if (_busy) return;
    // controller 归本页所有而不是每次新建：弹窗 pop 之后还有一段退场动画，
    // 那期间 CupertinoTextField 仍然挂在树上，就地 dispose 会抛"used after
    // being disposed"。
    _nicknameController.text = _session.displayNameOr('');
    final name = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('修改昵称'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: _nicknameController,
            autofocus: true,
            maxLength: _maxNicknameLength,
            placeholder: '想让 TA 怎么称呼你',
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () =>
                Navigator.of(context).pop(_nicknameController.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    final trimmed = name?.trim();
    if (trimmed == null || !mounted) return;
    if (trimmed.isEmpty) {
      setState(() => _error = '昵称不能为空。');
      return;
    }
    if (trimmed == _session.userDisplayName?.trim()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      widget.api.authToken = _session.token;
      _applyResult(await widget.api.updateUserDisplayName(trimmed));
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _asMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _applyResult(UserProfileUpdateResult result) {
    if (!mounted) return;
    final updated = _session.copyWith(
      userDisplayName: result.displayName,
      userAvatarUrl: result.avatarUrl,
    );
    setState(() {
      _session = updated;
      _error = null;
    });
    widget.onSessionChanged(updated);
  }

  String _imageMimeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _copyUserId() async {
    await Clipboard.setData(ClipboardData(text: _session.userId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('用户ID 已复制'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 1200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _session.displayNameOr('小星辰');
    final error = _error;
    return _SettingsSubScaffold(
      title: '个人资料',
      child: _SubPageContent(
        children: [
          _SubCard(
            children: [
              _SubCardRow(
                label: '头像',
                onTap: _busy ? null : _pickAvatar,
                trailing: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_busy)
                        const Padding(
                          padding: EdgeInsets.only(right: 10),
                          child: CupertinoActivityIndicator(radius: 8),
                        ),
                      _SettingsAvatarImage(
                        assetPath: 'assets/prototype/user-avatar-shanmu.jpg',
                        imageUrl: _session.userAvatarUrl,
                        accent: _SettingsColors.blueDark,
                      ),
                      const SizedBox(width: 6),
                      const _SettingsArrow(),
                    ],
                  ),
                ),
              ),
              _SubCardRow(
                label: '昵称',
                value: '$displayName ›',
                onTap: _busy ? null : _editNickname,
              ),
              // 原本这里是「登录账号」(wx_89b939bc004 之类的内部 hash) —— 对用户
              // 零信息量。换成账号类型, 数据来自服务端早就在发的 phone /
              // wechat_bound (AuthResponse 里那两个字段的注释写的就是 "for the
              // account-settings UI")。
              _SubCardRow(
                label: '账号类型',
                trailing: _LoginMethodBadges(methods: _session.loginMethods),
              ),
              _SubCardRow(
                label: '用户ID',
                // 只显示前 8 位: 完整 uuid 36 字符会把标签挤掉。点一下复制完整值 ——
                // 昵称现在可改且不唯一, 反馈问题时这串是唯一能定位账号的东西。
                value: '${_session.userId.split('-').first}… 复制',
                onTap: _copyUserId,
                showDivider: false,
              ),
            ],
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                error,
                style: TextStyle(color: _SettingsColors.red, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}

class _AiAppearancePage extends StatelessWidget {
  const _AiAppearancePage({required this.agentName, this.agentAvatarUrl});

  final String agentName;
  final String? agentAvatarUrl;

  @override
  Widget build(BuildContext context) {
    return _SettingsSubScaffold(
      title: '$agentName形象',
      child: _SubPageContent(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 18),
              child: _SettingsAvatarImage(
                assetPath: 'assets/prototype/agent-avatar.png',
                imageUrl: agentAvatarUrl,
                accent: _SettingsColors.orangeDark,
              ),
            ),
          ),
          _SubCard(
            children: [
              _SubCardRow(label: '名称', value: agentName),
              _SubCardRow(
                label: '头像来源',
                value: agentAvatarUrl?.trim().isNotEmpty == true
                    ? '后台头像'
                    : '默认头像',
              ),
              const _SubCardRow(
                label: '形象编辑',
                value: '等待素材与保存接口',
                showDivider: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackpackPage extends StatefulWidget {
  const _BackpackPage({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_BackpackPage> createState() => _BackpackPageState();
}

class _BackpackPageState extends State<_BackpackPage> {
  late Future<StoreInventoryResponse> _future;
  _BackpackFilter _selectedFilter = _BackpackFilter.all;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<StoreInventoryResponse> _load() => widget.api.listStoreInventory();

  void _retry() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StoreInventoryResponse>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final inventory = {
          for (final item in data?.items ?? const <StoreInventoryItem>[])
            if (item.productKind.isNotEmpty && item.quantity > 0)
              item.productKind: item,
        };
        final ownedProducts = [
          for (final kind in inventory.keys)
            _productForKind(kind) ??
                _StoreProduct(
                  title: kind,
                  subtitle: '已下架',
                  productKind: kind,
                  memberPrice: 0,
                  listPrice: 0,
                ),
        ];
        final visibleProducts = _selectedFilter.category == null
            ? ownedProducts
            : ownedProducts
                  .where((item) => item.category == _selectedFilter.category)
                  .toList();
        final totalCount = ownedProducts.fold<int>(
          0,
          (sum, product) => sum + inventory[product.productKind]!.quantity,
        );
        return _SettingsSubScaffold(
          title: '我的背包',
          trailing: Text(
            snapshot.connectionState == ConnectionState.done
                ? '共$totalCount件'
                : '同步中',
            style: TextStyle(
              color: _SettingsColors.tertiary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
          child: Builder(
            builder: (context) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Center(
                  child: CupertinoActivityIndicator(
                    color: _SettingsColors.blueDark,
                  ),
                );
              }
              if (snapshot.hasError) {
                return _SubPageContent(
                  center: true,
                  children: [
                    Text(
                      '背包同步失败：${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _SettingsColors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    CupertinoButton(
                      color: _SettingsColors.blueDark,
                      borderRadius: BorderRadius.circular(14),
                      onPressed: _retry,
                      child: const Text('重新同步'),
                    ),
                  ],
                );
              }
              return _SubPageContent(
                children: [
                  _StoreSegmentedLabelBar<_BackpackFilter>(
                    values: _BackpackFilter.values,
                    selected: _selectedFilter,
                    labelFor: (filter) => filter.label,
                    onSelected: (filter) {
                      setState(() => _selectedFilter = filter);
                    },
                  ),
                  const SizedBox(height: 12),
                  if (visibleProducts.isEmpty)
                    _SubCard(
                      padding: const EdgeInsets.fromLTRB(20, 34, 20, 34),
                      children: [
                        Text(
                          totalCount == 0 ? '还没有获得物品' : '这个分类还没有物品',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _SettingsColors.tertiary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                            height: 1.5,
                          ),
                        ),
                      ],
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: visibleProducts.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.82,
                          ),
                      itemBuilder: (context, index) {
                        final product = visibleProducts[index];
                        final item = inventory[product.productKind]!;
                        return _ExchangeProductCard(
                          product: product,
                          affordable: true,
                          compact: true,
                          showPrice: false,
                          quantity: item.quantity,
                          expiresAt: item.expiresAt,
                          isGift: item.isGift,
                        );
                      },
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

enum _BackpackFilter {
  all('全部', null),
  gift('礼物', _ExchangeCategory.gift),
  blind('盲盒', _ExchangeCategory.blind),
  outfit('装扮', _ExchangeCategory.outfit),
  bundle('礼包', _ExchangeCategory.bundle);

  const _BackpackFilter(this.label, this.category);

  final String label;
  final _ExchangeCategory? category;
}

class _NotificationSettingsPage extends StatefulWidget {
  const _NotificationSettingsPage({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<_NotificationSettingsPage> {
  bool _messageEnabled = true;
  bool _busy = false;

  Future<void> _toggleMessageNotifications(bool enabled) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (enabled) {
        await PushNotificationService.instance.configure(
          widget.api,
          widget.session,
        );
      } else {
        await PushNotificationService.instance.clear();
      }
      if (!mounted) return;
      setState(() => _messageEnabled = enabled);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enabled ? '已开启新消息提醒' : '已关闭新消息提醒'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1200),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('通知设置失败：$error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsSubScaffold(
      title: '通知设置',
      child: _SubPageContent(
        children: [
          _SubCard(
            children: [
              _SubCardRow(
                label: '新消息提醒',
                trailing: CupertinoSwitch(
                  value: _messageEnabled,
                  activeTrackColor: _SettingsColors.blueDark,
                  onChanged: _busy ? null : _toggleMessageNotifications,
                ),
              ),
              _SubCardRow(
                label: '提醒状态',
                value: _busy
                    ? '同步中'
                    : (_messageEnabled ? '声音 · 振动 · 通知栏' : '已关闭'),
              ),
              const _SubCardRow(
                label: '提示铃声',
                value: '系统默认',
                showDivider: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubTitle extends StatelessWidget {
  const _SubTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          color: _SettingsColors.text,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _PrivacySecurityPage extends StatefulWidget {
  const _PrivacySecurityPage({
    required this.api,
    required this.session,
    this.initialStats,
  });

  final CompanionApi api;
  final AuthSession session;
  final ProfileStats? initialStats;

  @override
  State<_PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends State<_PrivacySecurityPage> {
  ProfileStats? _stats;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _stats = widget.initialStats;
    _refreshStats();
  }

  Future<void> _refreshStats() async {
    if (widget.session.agentId == null || widget.session.agentId!.isEmpty) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      widget.api.authToken = widget.session.token;
      final stats = await widget.api.fetchProfileStats(
        workspaceId: widget.session.workspaceId,
      );
      if (!mounted) return;
      setState(() {
        _stats = stats;
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
    final messageCount = _stats?.messageCount;
    final messageLabel = _loading
        ? '同步中...'
        : messageCount == null
        ? (_error == null ? '--' : '暂不可用')
        : '$messageCount 条';
    return _SettingsSubScaffold(
      title: '隐私与安全中心',
      child: _SubPageContent(
        children: [
          _SubCard(
            children: [
              const _SubSectionHeader('绑定信息'),
              _SubCardRow(
                label: '绑定手机',
                value: _maskedPhone(widget.session.username),
              ),
              const _SubCardRow(label: '绑定微信', value: '未绑定 ›'),
              const _SubCardRow(
                label: '绑定邮箱',
                value: '未绑定 ›',
                showDivider: false,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _SubCard(
            children: [
              _SubSectionHeader('实名认证'),
              _SubCardRow(label: '认证状态', value: '未认证'),
              _SubCardRow(label: '姓名', value: '未填写'),
              _SubCardRow(label: '身份证号', value: '未填写', showDivider: false),
            ],
          ),
          const SizedBox(height: 12),
          const _SubCard(
            children: [
              _SubSectionHeader('适龄验证'),
              _SubCardRow(label: '适龄状态', value: '成年人（18+）', showDivider: false),
            ],
          ),
          const SizedBox(height: 12),
          _SubCard(
            children: [
              const _SubSectionHeader('聊天记录管理'),
              _SubCardRow(
                label: '当前消息数',
                value: messageLabel,
                showDivider: false,
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: _SettingsColors.red, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  static String _maskedPhone(String username) {
    final digits = username.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) return '未绑定 ›';
    return '${digits.substring(0, 3)}****${digits.substring(digits.length - 4)} ›';
  }
}

class _CacheCleanupPage extends StatefulWidget {
  const _CacheCleanupPage();

  @override
  State<_CacheCleanupPage> createState() => _CacheCleanupPageState();
}

class _CacheCleanupPageState extends State<_CacheCleanupPage> {
  late Future<int> _sizeFuture = _loadCacheSize();
  bool _cleaning = false;

  Future<int> _loadCacheSize() async {
    var total = 0;
    total += PaintingBinding.instance.imageCache.currentSizeBytes;
    final dirs = <Directory>[];
    try {
      dirs.add(await getTemporaryDirectory());
    } catch (_) {}
    try {
      dirs.add(await getApplicationCacheDirectory());
    } catch (_) {}
    for (final dir in dirs) {
      total += await _directorySize(dir);
    }
    return total;
  }

  Future<int> _directorySize(Directory directory) async {
    if (!await directory.exists()) return 0;
    var total = 0;
    try {
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }

  Future<void> _clearCache() async {
    if (_cleaning) return;
    setState(() => _cleaning = true);
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    try {
      await DefaultCacheManager().emptyCache();
    } catch (_) {}
    final dirs = <Directory>[];
    try {
      dirs.add(await getTemporaryDirectory());
    } catch (_) {}
    try {
      dirs.add(await getApplicationCacheDirectory());
    } catch (_) {}
    for (final dir in dirs) {
      if (!await dir.exists()) continue;
      try {
        await for (final entity in dir.list()) {
          await entity.delete(recursive: true);
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _cleaning = false;
      _sizeFuture = _loadCacheSize();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('缓存已清理'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 1200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsSubScaffold(
      title: '缓存清理',
      child: FutureBuilder<int>(
        future: _sizeFuture,
        builder: (context, snapshot) {
          final sizeLabel = snapshot.hasData
              ? _formatBytes(snapshot.data!)
              : '计算中';
          return _SubPageContent(
            children: [
              _SubCard(
                children: [
                  _SubCardRow(label: '缓存大小', value: sizeLabel),
                  _SubCardRow(
                    label: _cleaning ? '清理中' : '清理缓存',
                    value: '›',
                    showDivider: false,
                    onTap: _cleaning ? null : _clearCache,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  '仅清理本机图片与临时文件，不会删除服务端聊天记录',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _SettingsColors.isDark
                        ? _SettingsColors.tertiary
                        : const Color(0xFF999999),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)}KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)}MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(1)}GB';
  }
}

class _AboutCompanionPage extends StatelessWidget {
  const _AboutCompanionPage({required this.onContact});

  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    return _SettingsSubScaffold(
      title: '关于我们',
      child: _SubPageContent(
        center: true,
        children: [
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/prototype/logo.png',
              width: 88,
              height: 88,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '伴生·SoulMate',
            style: TextStyle(
              color: _SettingsColors.text,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '让每一次陪伴都有温度',
            style: TextStyle(
              color: _SettingsColors.tertiary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 16),
          _SubCard(
            children: [
              const _SubCardRow(label: '开发者团队', value: '启序科技'),
              _SubCardRow(label: '联系我们/意见反馈', value: '›', onTap: onContact),
              _SubCardRow(
                label: '用户协议',
                value: '›',
                onTap: () => Navigator.of(context).push(
                  CompanionPageRoute<void>(
                    builder: (_) => const _LegalDocumentPage(
                      title: '用户协议',
                      assetPath: 'assets/legal/service_agreement.txt',
                    ),
                  ),
                ),
              ),
              _SubCardRow(
                label: '隐私政策',
                value: '›',
                showDivider: false,
                onTap: () => Navigator.of(context).push(
                  CompanionPageRoute<void>(
                    builder: (_) => const _LegalDocumentPage(
                      title: '隐私政策',
                      assetPath: 'assets/legal/privacy_policy.txt',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '© 2026 启序科技',
            style: TextStyle(
              color: _SettingsColors.isDark
                  ? const Color(0xFF687789)
                  : const Color(0xFFBBBBBB),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactFeedbackPage extends StatefulWidget {
  const _ContactFeedbackPage({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_ContactFeedbackPage> createState() => _ContactFeedbackPageState();
}

class _ContactFeedbackPageState extends State<_ContactFeedbackPage> {
  final _contentController = TextEditingController();
  final _contactController = TextEditingController();
  final _occurredAtController = TextEditingController();
  final _picker = ImagePicker();
  final List<_FeedbackAttachmentDraft> _attachments = [];
  bool _submitting = false;

  @override
  void dispose() {
    _contentController.dispose();
    _contactController.dispose();
    _occurredAtController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = 3 - _attachments.length;
    if (remaining <= 0) return;

    if (remaining == 1) {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _attachments.add(
          _FeedbackAttachmentDraft(
            bytes: bytes,
            name: file.name,
            mime: 'image/jpeg',
          ),
        );
      });
      return;
    }

    final files = await _picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;
    if (files.length > remaining) {
      _showSnack('最多还能选择 $remaining 张图片');
    }
    for (final file in files.take(remaining)) {
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _attachments.add(
          _FeedbackAttachmentDraft(
            bytes: bytes,
            name: file.name,
            mime: 'image/jpeg',
          ),
        );
      });
    }
  }

  Future<void> _previewAttachment(int index) async {
    if (index < 0 || index >= _attachments.length) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'feedback-photo-preview',
      barrierColor: Colors.black.withValues(alpha: 0.78),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, _, __) {
        return _FeedbackAttachmentPreviewDialog(
          attachments: List<_FeedbackAttachmentDraft>.unmodifiable(
            _attachments,
          ),
          initialIndex: index,
          onClose: () => Navigator.of(context).pop(),
        );
      },
      transitionBuilder: (context, animation, _, child) {
        final curved = Curves.easeOutCubic.transform(animation.value);
        return Opacity(
          opacity: curved,
          child: Transform.scale(scale: 1.02 - 0.02 * curved, child: child),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final content = _contentController.text.trim();
    final contact = _contactController.text.trim();
    if (content.length < 5) {
      _showSnack('请至少输入 5 个字的反馈内容');
      return;
    }
    if (contact.isEmpty) {
      _showSnack('请填写联系方式');
      return;
    }
    setState(() => _submitting = true);
    try {
      widget.api.authToken = widget.session.token;
      final clientInfo = await ClientInfo.load();
      await widget.api.submitUserFeedback(
        content: content,
        contact: contact,
        occurredAt: _occurredAtController.text.trim(),
        appVersion: clientInfo.appVersion,
        platform: clientInfo.platform,
        imageBytes: _attachments.map((item) => item.bytes).toList(),
        imageNames: _attachments.map((item) => item.name).toList(),
        imageMimes: _attachments.map((item) => item.mime).toList(),
      );
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('提交成功'),
          content: const Text('感谢你的反馈，我们会尽快处理。'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      _showSnack('提交失败：${_asMessage(error)}');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsSubScaffold(
      title: '联系我们/意见反馈',
      child: _SubPageContent(
        children: [
          _SubCard(
            padding: const EdgeInsets.all(16),
            children: [
              const _SubTitle('问题与意见 *'),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: _contentController,
                maxLines: 5,
                minLines: 4,
                placeholder: '请详细描述您的问题或建议...',
                decoration: BoxDecoration(
                  color: _SettingsColors.page,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SubCard(
            padding: const EdgeInsets.all(16),
            children: [
              const _SubTitle('上传图片（选填）'),
              const SizedBox(height: 10),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _attachments.length >= 3 ? null : _pickImages,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _SettingsColors.separator),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _attachments.isEmpty
                        ? '点击上传截图（最多3张）'
                        : '已选 ${_attachments.length}/3，点击继续添加',
                    style: TextStyle(
                      color: _SettingsColors.tertiary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (_attachments.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < _attachments.length; i += 1)
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          GestureDetector(
                            onTap: () => _previewAttachment(i),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                _attachments[i].bytes,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: -6,
                            right: -6,
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              onPressed: () =>
                                  setState(() => _attachments.removeAt(i)),
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  color: Color(0x99000000),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  CupertinoIcons.xmark,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _SubCard(
            children: [
              _SubCardRow(
                label: '问题发生时间',
                value: '',
                trailing: SizedBox(
                  width: 160,
                  child: CupertinoTextField(
                    controller: _occurredAtController,
                    placeholder: '如：2026-06-22',
                    textAlign: TextAlign.right,
                    decoration: null,
                  ),
                ),
              ),
              _SubCardRow(
                label: '联系方式 *',
                value: '',
                showDivider: false,
                trailing: SizedBox(
                  width: 180,
                  child: CupertinoTextField(
                    controller: _contactController,
                    placeholder: '邮箱或手机号',
                    textAlign: TextAlign.right,
                    keyboardType: TextInputType.emailAddress,
                    decoration: null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CupertinoButton(
            color: _SettingsColors.blueDark,
            borderRadius: BorderRadius.circular(16),
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const CupertinoActivityIndicator(color: Colors.white)
                : const Text(
                    '提交反馈',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackAttachmentDraft {
  const _FeedbackAttachmentDraft({
    required this.bytes,
    required this.name,
    required this.mime,
  });

  final Uint8List bytes;
  final String name;
  final String mime;
}

class _FeedbackAttachmentPreviewDialog extends StatefulWidget {
  const _FeedbackAttachmentPreviewDialog({
    required this.attachments,
    required this.initialIndex,
    required this.onClose,
  });

  final List<_FeedbackAttachmentDraft> attachments;
  final int initialIndex;
  final VoidCallback onClose;

  @override
  State<_FeedbackAttachmentPreviewDialog> createState() =>
      _FeedbackAttachmentPreviewDialogState();
}

class _FeedbackAttachmentPreviewDialogState
    extends State<_FeedbackAttachmentPreviewDialog> {
  late final PageController _pageController;
  late final ScrollController _thumbController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.attachments.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _thumbController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerThumbnail());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbController.dispose();
    super.dispose();
  }

  void _handlePageChanged(int index) {
    setState(() => _currentIndex = index);
    _centerThumbnail();
  }

  void _selectPhoto(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
    _centerThumbnail(index);
  }

  void _centerThumbnail([int? index]) {
    if (!_thumbController.hasClients) return;
    final targetIndex = index ?? _currentIndex;
    final viewport = _thumbController.position.viewportDimension;
    final target =
        targetIndex * _DailyPreviewMetrics.thumbStride -
        viewport / 2 +
        _DailyPreviewMetrics.thumbWidth / 2;
    _thumbController.animateTo(
      target.clamp(
        _thumbController.position.minScrollExtent,
        _thumbController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final attachments = widget.attachments;
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: const SizedBox.expand(),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: _DailyCircleButton(
                      icon: CupertinoIcons.xmark,
                      onPressed: widget.onClose,
                      dark: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      onPageChanged: _handlePageChanged,
                      itemCount: attachments.length,
                      itemBuilder: (context, index) {
                        return Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(34),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.42),
                                    blurRadius: 80,
                                    offset: const Offset(0, 34),
                                  ),
                                ],
                              ),
                              child: InteractiveViewer(
                                minScale: 1,
                                maxScale: 4,
                                clipBehavior: Clip.none,
                                panEnabled: true,
                                scaleEnabled: true,
                                child: Image.memory(
                                  attachments[index].bytes,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (attachments.length > 1) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 66,
                      child: ListView.separated(
                        controller: _thumbController,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        itemCount: attachments.length,
                        separatorBuilder: (_, __) => const SizedBox(
                          width: _DailyPreviewMetrics.thumbGap,
                        ),
                        itemBuilder: (context, index) {
                          final selected = index == _currentIndex;
                          return GestureDetector(
                            onTap: () => _selectPhoto(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              width: selected
                                  ? _DailyPreviewMetrics.thumbWidth + 8
                                  : _DailyPreviewMetrics.thumbWidth,
                              height: _DailyPreviewMetrics.thumbHeight,
                              padding: EdgeInsets.all(selected ? 2 : 0),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withValues(
                                    alpha: selected ? 0.88 : 0,
                                  ),
                                  width: selected ? 2 : 0,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: AnimatedOpacity(
                                  opacity: selected ? 1 : 0.62,
                                  duration: const Duration(milliseconds: 180),
                                  child: Image.memory(
                                    attachments[index].bytes,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    '反馈截图 · 第 ${_currentIndex + 1} 张',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalDocumentPage extends StatefulWidget {
  const _LegalDocumentPage({required this.title, required this.assetPath});

  final String title;
  final String assetPath;

  @override
  State<_LegalDocumentPage> createState() => _LegalDocumentPageState();
}

class _LegalDocumentPageState extends State<_LegalDocumentPage> {
  late final Future<String> _textFuture = rootBundle.loadString(
    widget.assetPath,
  );

  @override
  Widget build(BuildContext context) {
    return _SettingsSubScaffold(
      title: widget.title,
      child: FutureBuilder<String>(
        future: _textFuture,
        builder: (context, snapshot) {
          final text = snapshot.data;
          if (text == null) {
            return Center(
              child: CupertinoActivityIndicator(
                color: _SettingsColors.blueDark,
              ),
            );
          }
          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _settingsCardDecoration(),
                child: Text(
                  text,
                  style: TextStyle(
                    color: _SettingsColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                    height: 1.62,
                  ),
                ),
              ),
            ],
          );
        },
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
    this.enabled = true,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
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
                          color: isDark
                              ? AppColors.text
                              : const Color(0xFF12171B),
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
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.32)
                        : const Color(0x52182026),
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
      CompanionPageRoute<void>(
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
