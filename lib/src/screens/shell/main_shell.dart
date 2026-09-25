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

  /// Offline check-in "I've arrived": dismiss any pushed routes (activity list,
  /// check-in page) then land on the chat tab.
  void _openChatAfterOfflineArrive() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    _goToChatTab();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatPageKey.currentState?.scrollToLatest();
    });
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

  /// 跨 Tab：从「陪伴→活动回顾→查看原始聊天」切到聊天 Tab 并滚动到到达卡。
  /// 调用前，上层活动列表页已自行 pop（露出 Tab 骨架）。
  void _openChatAtMessage(String messageId) {
    if (messageId.isEmpty) return;
    _goToChatTab();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatPageKey.currentState?.jumpToActivityMessage(messageId);
    });
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
            onReturnToChatAfterOfflineArrive: _openChatAfterOfflineArrive,
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
            onOpenChatAtMessage: _openChatAtMessage,
            onGoToChat: _openChatAfterOfflineArrive,
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
    final dark = AppColors.isDark(context);
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
          color: dark ? AppColors.surface : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: dark
              ? Border.all(color: Colors.white.withValues(alpha: 0.10))
              : null,
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

/// Inactive tab art is a #D8D8D8 body with a #F8F8F8 glyph, drawn for a white
/// pill. On a dark pill those two grays collapse into one pale sticker.
/// Stretch them apart: body → neutral gray, glyph → the app's light ink.
/// Translation is in 0–255 space (see ColorFilter.matrix).
const _darkInactiveTabIcon = ColorFilter.matrix(<double>[
  3.8125, 0, 0, 0, -703.5,
  0, 3.71875, 0, 0, -675.25,
  0, 0, 3.59375, 0, -640.25,
  0, 0, 0, 1, 0,
]);

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
    final dark = AppColors.isDark(context);
    Widget icon = Image.asset(
      selected ? activeIcon : inactiveIcon,
      width: 24,
      height: 24,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
    );
    if (dark && !selected) {
      icon = ColorFiltered(colorFilter: _darkInactiveTabIcon, child: icon);
    }
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
              SizedBox.square(dimension: 24, child: icon),
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
                        : (dark ? AppColors.muted : const Color(0xFFC7C7C7)),
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
