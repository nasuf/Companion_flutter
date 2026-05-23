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

  @override
  Widget build(BuildContext context) {
    final chatPage = widget.session.conversationId == null
        ? NoAgentPage(session: widget.session)
        : ChatPage(api: widget.api, session: widget.session);
    final pages = [
      chatPage,
      const PlaceholderPage(title: '日常', icon: CupertinoIcons.sun_max),
      const PlaceholderPage(title: '记忆', icon: CupertinoIcons.book),
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
          IndexedStack(index: _index, children: pages),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _FloatingTabBar(
              selectedIndex: _index,
              onSelected: (value) => setState(() => _index = value),
            ),
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
    (CupertinoIcons.chat_bubble_2_fill, '聊天'),
    (CupertinoIcons.square_grid_2x2, '日常'),
    (CupertinoIcons.book, '记忆'),
    (CupertinoIcons.person_crop_circle, '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      height: 64 + safeBottom,
      padding: EdgeInsets.fromLTRB(24, 8, 24, math.max(8, safeBottom)),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i += 1)
            Expanded(
              child: _TabBarItem(
                icon: _items[i].$1,
                label: _items[i].$2,
                selected: selectedIndex == i,
                onTap: () => onSelected(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabBarItem extends StatelessWidget {
  const _TabBarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: 52,
            height: 28,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFE7F7EE) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 22,
              color: selected
                  ? const Color(0xFF123B25)
                  : const Color(0xFF48514C),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? const Color(0xFF123B25)
                  : const Color(0xFF48514C),
            ),
          ),
        ],
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
