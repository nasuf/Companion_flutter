part of 'package:companion_flutter/main.dart';

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.controller,
    required this.messages,
    required this.isLoadingOlder,
    required this.bottomPadding,
    required this.onComponentCardTap,
    this.agentAvatarUrl,
  });

  final ScrollController controller;
  final List<ChatMessage> messages;
  final bool isLoadingOlder;
  final double bottomPadding;
  final ValueChanged<ChatComponentCard> onComponentCardTap;
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
        return _MessageRow(
          message: message,
          agentAvatarUrl: agentAvatarUrl,
          onComponentCardTap: onComponentCardTap,
        );
      },
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.message,
    required this.onComponentCardTap,
    this.agentAvatarUrl,
  });

  final ChatMessage message;
  final ValueChanged<ChatComponentCard> onComponentCardTap;
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
          _Bubble(message: message, onComponentCardTap: onComponentCardTap),
          if (message.isMine) ...[const SizedBox(width: _avatarGap), avatar],
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.onComponentCardTap});

  final ChatMessage message;
  final ValueChanged<ChatComponentCard> onComponentCardTap;

  @override
  Widget build(BuildContext context) {
    final componentCard = message.componentCard;
    return Flexible(
      child: Column(
        crossAxisAlignment: message.isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (componentCard != null)
            _ComponentCardBubble(
              card: componentCard,
              isMine: message.isMine,
              onTap: () => onComponentCardTap(componentCard),
            )
          else
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
                    color: message.isMine
                        ? AppColors.accent
                        : AppColors.hairline,
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

class _ComponentCardBubble extends StatelessWidget {
  const _ComponentCardBubble({
    required this.card,
    required this.isMine,
    required this.onTap,
  });

  final ChatComponentCard card;
  final bool isMine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _parseColor(card.accent);
    final isTimeCapsule = card.type == 'time_capsule';
    final timeCapsuleContent = _timeCapsuleContent(card);
    final icon = switch (card.type) {
      'weather' => CupertinoIcons.cloud_sun_fill,
      _ => CupertinoIcons.square_grid_2x2_fill,
    };

    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 292),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(isMine ? 20 : 5),
              topRight: Radius.circular(isMine ? 5 : 20),
              bottomLeft: const Radius.circular(20),
              bottomRight: const Radius.circular(20),
            ),
            border: Border.all(color: accent.withValues(alpha: 0.24)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.14),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(isMine ? 20 : 5),
              topRight: Radius.circular(isMine ? 5 : 20),
              bottomLeft: const Radius.circular(20),
              bottomRight: const Radius.circular(20),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -26,
                  top: -26,
                  child: Container(
                    width: 102,
                    height: 102,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 14, 15, 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _ComponentCardIcon(
                            type: card.type,
                            accent: accent,
                            fallbackIcon: icon,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: isTimeCapsule
                                ? Text(
                                    card.subtitle.isEmpty
                                        ? '时间胶囊'
                                        : card.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      height: 1.25,
                                    ),
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        card.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.text,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          height: 1.15,
                                        ),
                                      ),
                                      if (card.subtitle.isNotEmpty)
                                        Text(
                                          card.subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.muted,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 11,
                                            height: 1.35,
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                      if ((isTimeCapsule ? timeCapsuleContent : card.body)
                          .isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          isTimeCapsule ? timeCapsuleContent : card.body,
                          maxLines: isTimeCapsule ? 2 : 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 14,
                            height: 1.42,
                          ),
                        ),
                      ],
                      if (card.footer.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          card.footer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _parseColor(String value) {
    final hex = value.replaceFirst('#', '').trim();
    if (hex.length != 6) return const Color(0xFF7C3CFF);
    final intValue = int.tryParse(hex, radix: 16);
    if (intValue == null) return const Color(0xFF7C3CFF);
    return Color(0xFF000000 | intValue);
  }

  String _timeCapsuleContent(ChatComponentCard card) {
    final body = card.body.trim();
    if (body.isNotEmpty) return body;
    final payloadContent = card.payload['content']?.toString().trim();
    if (payloadContent != null && payloadContent.isNotEmpty) {
      return payloadContent;
    }
    return card.title.trim();
  }
}

class _ComponentCardIcon extends StatelessWidget {
  const _ComponentCardIcon({
    required this.type,
    required this.accent,
    required this.fallbackIcon,
  });

  final String type;
  final Color accent;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    if (type == 'time_capsule') {
      return SizedBox(
        width: 34,
        height: 34,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.22),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: CustomPaint(
              size: const Size(23, 23),
              painter: _CapsuleSidebarIconPainter(accent: accent),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(fallbackIcon, color: accent, size: 19),
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
