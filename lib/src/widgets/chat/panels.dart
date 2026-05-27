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
  const _EmojiPanel({required this.onEmojiTap, this.compact = false});

  final ValueChanged<String> onEmojiTap;
  final bool compact;

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
    Widget emojiTile(String emoji) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
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
    }

    final grid = GridView.builder(
      padding: EdgeInsets.zero,
      primary: false,
      physics: const BouncingScrollPhysics(),
      itemCount: _emojis.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (context, index) => emojiTile(_emojis[index]),
    );

    return Padding(
      key: const ValueKey('emoji'),
      padding: EdgeInsets.fromLTRB(16, compact ? 6 : 14, 16, compact ? 10 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '常用表情',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: compact ? 12 : 14),
          if (compact)
            LayoutBuilder(
              builder: (context, constraints) {
                final tileSize = (constraints.maxWidth - 56) / 8;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final emoji in _emojis)
                      SizedBox(
                        width: tileSize,
                        height: tileSize,
                        child: emojiTile(emoji),
                      ),
                  ],
                );
              },
            )
          else
            Expanded(child: grid),
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
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _tools.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 16,
          childAspectRatio: 1.36,
        ),
        itemBuilder: (context, index) {
          final tool = _tools[index];
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: tool.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(tool.icon, color: tool.color, size: 24),
                ),
                const SizedBox(height: 5),
                Text(
                  tool.label,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
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
