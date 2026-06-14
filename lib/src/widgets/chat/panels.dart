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

class _EmojiPanel extends StatefulWidget {
  const _EmojiPanel({required this.onEmojiTap, this.compact = false});

  final ValueChanged<String> onEmojiTap;
  final bool compact;

  @override
  State<_EmojiPanel> createState() => _EmojiPanelState();
}

class _EmojiPanelState extends State<_EmojiPanel> {
  static const _columns = 8;
  static const _rows = 4;
  static const _perPage = _columns * _rows;

  late final PageController _pageController;
  int _page = 0;

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
    '❤️',
    '💕',
    '🥰',
    '😘',
    '😆',
    '😎',
    '🤔',
    '😴',
    '🥳',
    '😤',
    '😇',
    '🤗',
    '😋',
    '🤩',
    '🙈',
    '🤝',
    '💪',
    '👏',
    '🙏',
    '👌',
    '✌️',
    '🔥',
    '⭐',
    '🌈',
    '🌸',
    '🍀',
    '🍵',
    '🍜',
    '🍭',
    '🎁',
    '🎵',
    '🎬',
    '🏖️',
    '🛋️',
    '📝',
    '📷',
    '💡',
    '💤',
    '💭',
    '🔆',
  ];

  List<List<String>> get _pages {
    return [
      for (var index = 0; index < _emojis.length; index += _perPage)
        _emojis.sublist(index, math.min(index + _perPage, _emojis.length)),
    ];
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget emojiTile(String emoji) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onEmojiTap(emoji),
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

    Widget pageGrid(List<String> emojis) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final tileWidth =
              (constraints.maxWidth - (_columns - 1) * 8) / _columns;
          final tileHeight = (constraints.maxHeight - (_rows - 1) * 8) / _rows;
          final childAspectRatio =
              tileWidth / math.max(1.0, math.min(tileWidth, tileHeight));
          return GridView.builder(
            padding: EdgeInsets.zero,
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: emojis.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _columns,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: childAspectRatio,
            ),
            itemBuilder: (context, index) => emojiTile(emojis[index]),
          );
        },
      );
    }

    final pages = _pages;

    return Padding(
      key: const ValueKey('emoji'),
      padding: EdgeInsets.fromLTRB(
        16,
        widget.compact ? 6 : 14,
        16,
        widget.compact ? 10 : 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '常用表情',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: widget.compact ? 12 : 14),
          if (widget.compact)
            LayoutBuilder(
              builder: (context, constraints) {
                final tileSize = (constraints.maxWidth - 56) / 8;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final emoji in _emojis.take(24))
                      SizedBox(
                        width: tileSize,
                        height: tileSize,
                        child: emojiTile(emoji),
                      ),
                  ],
                );
              },
            )
          else ...[
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                itemCount: pages.length,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (context, index) => pageGrid(pages[index]),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < pages.length; index++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: index == _page ? 13 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: index == _page
                          ? AppColors.accent
                          : AppColors.hairline,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToolRow(tools: _tools.take(3).toList()),
            const SizedBox(height: 26),
            _ToolRow(tools: _tools.skip(3).take(3).toList()),
          ],
        ),
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({required this.tools});

  final List<_ToolSpec> tools;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final tool in tools)
          Expanded(
            child: Center(child: _ToolButton(tool: tool)),
          ),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.tool});

  final _ToolSpec tool;

  @override
  Widget build(BuildContext context) {
    return Column(
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
    );
  }
}

class _ToolSpec {
  const _ToolSpec(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}
