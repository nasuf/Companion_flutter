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

class _MainShellState extends State<MainShell> {
  int _index = 0;
  bool _chatSidebarOpen = false;
  AchievementItem? _activeAchievement;
  final _chatPageKey = GlobalKey<_ChatPageState>();
  StreamSubscription<CheckinNotificationPayload>? _notificationSub;

  @override
  void initState() {
    super.initState();
    _notificationSub = CheckinNotificationService.instance.payloads.listen(
      _openCheckinFromNotification,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final payload = CheckinNotificationService.instance.takePendingPayload();
      if (payload != null && mounted) _openCheckinFromNotification(payload);
    });
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    super.dispose();
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
              color: Colors.white.withValues(alpha: 0.66),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF315B88).withValues(alpha: 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.70),
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
                              Colors.white.withValues(alpha: 0.96),
                              Colors.white.withValues(alpha: 0.56),
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
                    : const Color(0xFF1B2733).withValues(alpha: 0.42),
              ),
              const SizedBox(height: 5),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: selected ? 5 : 0,
                height: 5,
                decoration: const BoxDecoration(
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

class _ProfilePageState extends State<ProfilePage> {
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
  bool _deleting = false;
  int _deleteStage = 0;
  Map<String, int>? _deleteStats;
  String? _error;

  @override
  void dispose() {
    _deleteStageTimer?.cancel();
    super.dispose();
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
    final agentName = widget.session.agentName ?? '未创建';
    final hasAgent =
        widget.session.agentId != null && widget.session.agentId!.isNotEmpty;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '我的',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _deleting ? null : widget.onLogout,
                  child: const Text('退出'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _ProfileAgentCard(
              agentName: agentName,
              username: widget.session.username,
              hasAgent: hasAgent,
            ),
            const SizedBox(height: 18),
            if (_deleting) ...[
              _DeleteProgressPanel(
                stage: _deleteStages[_deleteStage],
                stats: _deleteStats,
              ),
              const SizedBox(height: 18),
            ],
            if (_error != null) ...[
              Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFD95B5B),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: hasAgent && !_deleting ? _confirmDeleteAgent : null,
                icon: const Icon(CupertinoIcons.delete, size: 19),
                label: Text(_deleting ? '正在删除...' : 'Delete Agent'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD95B5B),
                  side: const BorderSide(color: Color(0x33D95B5B)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAgentCard extends StatelessWidget {
  const _ProfileAgentCard({
    required this.agentName,
    required this.username,
    required this.hasAgent,
  });

  final String agentName;
  final String username;
  final bool hasAgent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF315B88).withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.accentDeep, AppColors.accentCyan],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentDeep.withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                CupertinoIcons.person_crop_circle_fill,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0x82181F26),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasAgent ? agentName : '还没有 Agent',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
                    style: const TextStyle(
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

class NoAgentPage extends StatelessWidget {
  const NoAgentPage({
    super.key,
    required this.api,
    required this.session,
    required this.onSessionChanged,
  });

  final CompanionApi api;
  final AuthSession session;
  final ValueChanged<AuthSession> onSessionChanged;

  void _openCreatePage(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => AgentCreatePage(
          api: api,
          session: session,
          onCreated: onSessionChanged,
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
                  const Icon(
                    CupertinoIcons.person_2_square_stack,
                    color: AppColors.muted,
                    size: 56,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    session.hasAgent ? '还没有可用会话' : '创建你的 AI 伙伴',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
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
