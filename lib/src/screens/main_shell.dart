part of 'package:companion_flutter/main.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.api,
    required this.session,
    required this.onLogout,
  });

  final CompanionApi api;
  final AuthSession session;
  final VoidCallback onLogout;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  bool _chatSidebarOpen = false;

  void _setChatSidebarOpen(bool value) {
    if (_chatSidebarOpen == value) return;
    setState(() => _chatSidebarOpen = value);
  }

  void _openSidebarDestination(_SidebarDestination destination) {
    _setChatSidebarOpen(false);
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => _SidebarDestinationPage(destination: destination),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final chatPage = widget.session.conversationId == null
        ? NoAgentPage(session: widget.session)
        : ChatPage(
            api: widget.api,
            session: widget.session,
            onOpenSidebar: () => _setChatSidebarOpen(true),
          );
    final pages = [
      chatPage,
      const OnlineInteractionPage(),
      OfflineInteractionPage(agentName: widget.session.agentName ?? '伴生'),
      PlaceholderPage(
        title: '我的',
        icon: CupertinoIcons.person_crop_circle,
        action: TextButton(onPressed: widget.onLogout, child: const Text('退出')),
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
                  Positioned(
                    left: 28,
                    right: 28,
                    bottom: math.max(10, safeBottom - 2),
                    child: _FloatingTabBar(
                      selectedIndex: _index,
                      onSelected: (value) => setState(() => _index = value),
                    ),
                  ),
                ],
              ),
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

class NoAgentPage extends StatelessWidget {
  const NoAgentPage({super.key, required this.session});

  final AuthSession session;

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
                    session.hasAgent ? '还没有可用会话' : '这个账号还没有创建 Agent',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '请先在 Web 端完成 Agent 创建；Flutter 端会直接接入已有会话。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, height: 1.45),
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
