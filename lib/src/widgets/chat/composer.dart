part of 'package:companion_flutter/main.dart';

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.activePanel,
    required this.sending,
    required this.onFocusInput,
    required this.onToggleEmoji,
    required this.onToggleMore,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ComposerPanel activePanel;
  final bool sending;
  final VoidCallback onFocusInput;
  final VoidCallback onToggleEmoji;
  final VoidCallback onToggleMore;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _ChatPageState._composerHeight,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: const BoxDecoration(
        color: AppColors.page,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          _RoundIconButton(
            tooltip: '语音',
            icon: CupertinoIcons.mic,
            onTap: () {},
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(21),
                border: Border.all(color: AppColors.hairline),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onTap: onFocusInput,
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: '发消息...',
                  hintStyle: TextStyle(color: AppColors.muted),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.fromLTRB(14, 10, 14, 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _RoundIconButton(
            tooltip: '表情',
            icon: activePanel == ComposerPanel.emoji
                ? CupertinoIcons.keyboard
                : CupertinoIcons.smiley,
            selected: activePanel == ComposerPanel.emoji,
            onTap: onToggleEmoji,
          ),
          const SizedBox(width: 8),
          AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final hasText = controller.text.trim().isNotEmpty;
              if (hasText) {
                return FilledButton(
                  onPressed: sending ? null : onSend,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(58, 38),
                    padding: EdgeInsets.zero,
                    backgroundColor: AppColors.wechatGreen,
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
            color: selected ? const Color(0xFFE8F7EE) : AppColors.surface,
            border: Border.all(
              color: selected ? AppColors.wechatGreen : AppColors.hairline,
            ),
          ),
          child: Icon(icon, size: 21, color: AppColors.text),
        ),
      ),
    );
  }
}
