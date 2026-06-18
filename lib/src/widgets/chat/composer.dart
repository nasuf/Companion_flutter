part of 'package:companion_flutter/main.dart';

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.height,
    required this.activePanel,
    required this.sending,
    required this.pendingImages,
    required this.onFocusInput,
    required this.onToggleEmoji,
    required this.onShowKeyboard,
    required this.onToggleMore,
    required this.onSend,
    required this.onRemoveImage,
    required this.onPreviewImage,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final double height;
  final ComposerPanel activePanel;
  final bool sending;
  final List<_PendingChatImage> pendingImages;
  final VoidCallback onFocusInput;
  final VoidCallback onToggleEmoji;
  final VoidCallback onShowKeyboard;
  final VoidCallback onToggleMore;
  final VoidCallback onSend;
  final ValueChanged<String> onRemoveImage;
  final ValueChanged<_PendingChatImage> onPreviewImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: const BoxDecoration(
        color: AppColors.page,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pendingImages.isNotEmpty) ...[
            _ComposerImageStrip(
              images: pendingImages,
              onRemove: onRemoveImage,
              onPreview: onPreviewImage,
            ),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _RoundIconButton(
                tooltip: '语音',
                icon: CupertinoIcons.mic,
                onTap: () {},
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: 38,
                    maxHeight: 86,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: 3,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    onTap: onFocusInput,
                    decoration: const InputDecoration(
                      hintText: '发消息...',
                      hintStyle: TextStyle(color: AppColors.muted),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.fromLTRB(14, 8, 14, 8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _RoundIconButton(
                tooltip: activePanel == ComposerPanel.emoji ? '键盘' : '表情',
                icon: activePanel == ComposerPanel.emoji
                    ? CupertinoIcons.keyboard
                    : CupertinoIcons.smiley,
                selected: activePanel == ComposerPanel.emoji,
                onTap: activePanel == ComposerPanel.emoji
                    ? onShowKeyboard
                    : onToggleEmoji,
              ),
              const SizedBox(width: 8),
              AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  final canSend =
                      controller.text.trim().isNotEmpty ||
                      pendingImages.isNotEmpty;
                  if (canSend) {
                    return FilledButton(
                      onPressed: sending ? null : onSend,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(58, 38),
                        padding: EdgeInsets.zero,
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(19),
                        ),
                      ),
                      child: Text(sending ? '...' : '发送'),
                    );
                  }
                  return _RoundIconButton(
                    tooltip: '更多',
                    icon: activePanel == ComposerPanel.more
                        ? CupertinoIcons.xmark
                        : CupertinoIcons.plus,
                    selected: activePanel == ComposerPanel.more,
                    onTap: onToggleMore,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComposerImageStrip extends StatelessWidget {
  const _ComposerImageStrip({
    required this.images,
    required this.onRemove,
    required this.onPreview,
  });

  final List<_PendingChatImage> images;
  final ValueChanged<String> onRemove;
  final ValueChanged<_PendingChatImage> onPreview;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final image = images[index];
          return Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: () => onPreview(image),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(image.localPath),
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: () => onRemove(image.attachment.id),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xE6000000),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(
                      CupertinoIcons.xmark,
                      color: Colors.white,
                      size: 13,
                    ),
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

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 23,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? null : AppColors.surface,
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.accentDeep, AppColors.accentCyan],
                  )
                : null,
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.28)
                  : AppColors.hairline,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 21,
            color: selected ? Colors.white : AppColors.text,
          ),
        ),
      ),
    );
  }
}
