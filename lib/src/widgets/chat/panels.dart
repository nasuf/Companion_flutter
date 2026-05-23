part of 'package:companion_flutter/main.dart';

class _ChatPanel extends StatelessWidget {
  const _ChatPanel({required this.panel, required this.onEmojiTap});

  final ComposerPanel panel;
  final ValueChanged<String> onEmojiTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: switch (panel) {
          ComposerPanel.emoji => _EmojiPanel(onEmojiTap: onEmojiTap),
          ComposerPanel.more => const _MorePanel(),
          ComposerPanel.none => const SizedBox.shrink(),
        },
      ),
    );
  }
}

class _EmojiPanel extends StatelessWidget {
  const _EmojiPanel({required this.onEmojiTap});

  final ValueChanged<String> onEmojiTap;

  static const _emojis = [
    '😊',
    '😂',
    '🥹',
    '🤍',
    '🙌',
    '🌧️',
    '☀️',
    '🎧',
    '🍿',
    '🎮',
    '📚',
    '🍰',
    '🧋',
    '🌙',
    '✨',
    '🫶',
    '😌',
    '😵‍💫',
    '😭',
    '👍',
    '👀',
    '💬',
    '🪄',
    '🌿',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('emoji'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '常用表情',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: _emojis.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 9,
                crossAxisSpacing: 9,
              ),
              itemBuilder: (context, index) {
                final emoji = _emojis[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(13),
                  onTap: () => onEmojiTap(emoji),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 21)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MorePanel extends StatelessWidget {
  const _MorePanel();

  static const _tools = [
    _ToolSpec('图片', CupertinoIcons.photo, Color(0xFF1F6FFF)),
    _ToolSpec('拍摄', CupertinoIcons.camera, Color(0xFF18C6C0)),
    _ToolSpec('红包', CupertinoIcons.gift, Color(0xFFFF4D5F)),
    _ToolSpec('位置', CupertinoIcons.location, Color(0xFF22C66B)),
    _ToolSpec('查找', CupertinoIcons.search, Color(0xFF7C3CFF)),
    _ToolSpec('电话', CupertinoIcons.phone, Color(0xFFFF8A3D)),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('more'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _tools.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 18,
          crossAxisSpacing: 18,
          childAspectRatio: 1.02,
        ),
        itemBuilder: (context, index) {
          final tool = _tools[index];
          return Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: tool.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(tool.icon, color: tool.color, size: 26),
              ),
              const SizedBox(height: 8),
              Text(
                tool.label,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ToolSpec {
  const _ToolSpec(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}
