part of 'package:companion_flutter/main.dart';

class _ChatPanel extends StatefulWidget {
  const _ChatPanel({
    required this.panel,
    required this.onEmojiTap,
    required this.onPickPhoto,
    required this.onTakePhoto,
    this.bottomInset = 0,
  });

  final ComposerPanel panel;
  final ValueChanged<String> onEmojiTap;
  final VoidCallback onPickPhoto;
  final VoidCallback onTakePhoto;

  /// Bottom safe-area height. The panel docks to the screen bottom (like the
  /// keyboard), so it owns the home-indicator strip and keeps content above it.
  final double bottomInset;

  @override
  State<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<_ChatPanel> {
  // True only for emoji <-> more swaps (both panels non-none). The whole panel
  // surface already slides up/down when opening/closing, so the content should
  // slide up only when switching between two panels while the surface is
  // stationary — otherwise the two slides would stack.
  bool _slideSwitch = false;

  @override
  void didUpdateWidget(covariant _ChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _slideSwitch =
        oldWidget.panel != ComposerPanel.none &&
        widget.panel != ComposerPanel.none &&
        oldWidget.panel != widget.panel;
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: widget.bottomInset),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          transitionBuilder: (child, animation) {
            // Opening/closing the whole surface handles its own slide, so those
            // just crossfade the content. Switching emoji <-> more slides the
            // content up from below (fast then slow, no bounce).
            if (!_slideSwitch) {
              return FadeTransition(opacity: animation, child: child);
            }
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
          child: switch (widget.panel) {
            ComposerPanel.emoji => _EmojiPanel(onEmojiTap: widget.onEmojiTap),
            ComposerPanel.more => _MorePanel(
              onPickPhoto: widget.onPickPhoto,
              onTakePhoto: widget.onTakePhoto,
            ),
            ComposerPanel.none => const SizedBox.shrink(),
          },
        ),
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
  const _MorePanel({required this.onPickPhoto, required this.onTakePhoto});

  final VoidCallback onPickPhoto;
  final VoidCallback onTakePhoto;

  static const _tools = [
    _ToolSpec('图片', CupertinoIcons.photo, Color(0xFF1F6FFF), _ToolAction.photo),
    _ToolSpec(
      '拍摄',
      CupertinoIcons.camera,
      Color(0xFF18C6C0),
      _ToolAction.camera,
    ),
    _ToolSpec('红包', CupertinoIcons.gift, Color(0xFFFF4D5F), _ToolAction.none),
    _ToolSpec(
      '位置',
      CupertinoIcons.location,
      Color(0xFF22C66B),
      _ToolAction.none,
    ),
    _ToolSpec('查找', CupertinoIcons.search, Color(0xFF7C3CFF), _ToolAction.none),
    _ToolSpec('电话', CupertinoIcons.phone, Color(0xFFFF8A3D), _ToolAction.none),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      key: const ValueKey('more'),
      builder: (context, constraints) {
        if (constraints.maxHeight < 170) {
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            scrollDirection: Axis.horizontal,
            itemCount: _tools.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final tool = _tools[index];
              return SizedBox(
                width: 62,
                child: Center(
                  child: _ToolButton(
                    tool: tool,
                    compact: true,
                    onTap: switch (tool.action) {
                      _ToolAction.photo => onPickPhoto,
                      _ToolAction.camera => onTakePhoto,
                      _ToolAction.none => null,
                    },
                  ),
                ),
              );
            },
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ToolRow(
                  tools: _tools.take(3).toList(),
                  onPickPhoto: onPickPhoto,
                  onTakePhoto: onTakePhoto,
                ),
                const SizedBox(height: 26),
                _ToolRow(
                  tools: _tools.skip(3).take(3).toList(),
                  onPickPhoto: onPickPhoto,
                  onTakePhoto: onTakePhoto,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({
    required this.tools,
    required this.onPickPhoto,
    required this.onTakePhoto,
  });

  final List<_ToolSpec> tools;
  final VoidCallback onPickPhoto;
  final VoidCallback onTakePhoto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final tool in tools)
          Expanded(
            child: Center(
              child: _ToolButton(
                tool: tool,
                onTap: switch (tool.action) {
                  _ToolAction.photo => onPickPhoto,
                  _ToolAction.camera => onTakePhoto,
                  _ToolAction.none => null,
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.tool, this.onTap, this.compact = false});

  final _ToolSpec tool;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 40.0 : 50.0;
    final iconRadius = compact ? 13.0 : 16.0;
    final iconGlyphSize = compact ? 21.0 : 24.0;
    final labelGap = compact ? 3.0 : 5.0;
    final labelSize = compact ? 10.0 : 11.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                color: tool.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(iconRadius),
              ),
              child: Icon(tool.icon, color: tool.color, size: iconGlyphSize),
            ),
            SizedBox(height: labelGap),
            Text(
              tool.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.muted, fontSize: labelSize),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolSpec {
  const _ToolSpec(this.label, this.icon, this.color, this.action);

  final String label;
  final IconData icon;
  final Color color;
  final _ToolAction action;
}

enum _ToolAction { photo, camera, none }
