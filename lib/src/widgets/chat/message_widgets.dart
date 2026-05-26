part of 'package:companion_flutter/main.dart';

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.controller,
    required this.messages,
    required this.isLoadingOlder,
    required this.bottomPadding,
    this.agentAvatarUrl,
  });

  final ScrollController controller;
  final List<ChatMessage> messages;
  final bool isLoadingOlder;
  final double bottomPadding;
  final String? agentAvatarUrl;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(
        child: Text(
          '还没有聊天记录，发一句话开始吧。',
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }
    return ListView.builder(
      controller: controller,
      padding: EdgeInsets.fromLTRB(12, 10, 12, bottomPadding),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: messages.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: isLoadingOlder
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : const SizedBox(height: 4),
          );
        }
        final message = messages[index - 1];
        return _MessageRow(message: message, agentAvatarUrl: agentAvatarUrl);
      },
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message, this.agentAvatarUrl});

  final ChatMessage message;
  final String? agentAvatarUrl;
  static const _avatarSize = 40.0;
  static const _avatarGap = 10.0;

  @override
  Widget build(BuildContext context) {
    final avatar = _Avatar(
      size: _avatarSize,
      label: message.isMine ? '我' : '伴',
      imageUrl: message.isMine ? null : agentAvatarUrl,
      gradient: message.isMine
          ? const [Color(0xFFE8F3FF), Color(0xFFF8FBFF)]
          : const [Color(0xFFE8F3FF), Color(0xFFDDEBFF)],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: message.isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!message.isMine) ...[avatar, const SizedBox(width: _avatarGap)],
          _Bubble(message: message),
          if (message.isMine) ...[const SizedBox(width: _avatarGap), avatar],
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Column(
        crossAxisAlignment: message.isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 270),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: message.isMine ? AppColors.accent : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(message.isMine ? 17 : 3),
                  topRight: Radius.circular(message.isMine ? 3 : 17),
                  bottomLeft: const Radius.circular(17),
                  bottomRight: const Radius.circular(17),
                ),
                border: Border.all(
                  color: message.isMine ? AppColors.accent : AppColors.hairline,
                ),
                boxShadow: [
                  BoxShadow(
                    color: message.isMine
                        ? AppColors.accent.withValues(alpha: 0.18)
                        : const Color(0xFF24344A).withValues(alpha: 0.08),
                    blurRadius: message.isMine ? 18 : 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                child: Text(
                  message.content,
                  style: TextStyle(
                    color: message.isMine ? Colors.white : AppColors.text,
                    fontSize: 15,
                    height: 1.42,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTime(message.createdAt),
                style: const TextStyle(color: AppColors.muted, fontSize: 10),
              ),
              if (message.isMine && message.read) ...[
                const SizedBox(width: 5),
                const Text(
                  '✓✓',
                  style: TextStyle(color: Color(0xFFFFA726), fontSize: 10),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.size,
    required this.label,
    required this.gradient,
    this.imageUrl,
  });

  final double size;
  final String label;
  final List<Color> gradient;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: gradient),
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.10),
            blurRadius: size * 0.42,
            offset: Offset(0, size * 0.14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _hasImage
          ? Image.network(
              imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return _fallback;
              },
            )
          : _fallback,
    );
  }

  bool get _hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  Widget get _fallback {
    return Center(
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.accent,
          fontSize: math.max(12, size * 0.42),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
