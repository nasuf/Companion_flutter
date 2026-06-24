part of 'package:companion_flutter/main.dart';

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.controller,
    required this.messages,
    required this.isLoadingOlder,
    required this.bottomPadding,
    required this.topPadding,
    required this.onComponentCardTap,
    required this.onAchievementTap,
    required this.onResolveMusicTrack,
    required this.onMusicCardActivated,
    required this.onMusicPrevious,
    required this.onMusicNext,
    required this.onMusicFavorite,
    required this.onAttachmentTap,
    required this.activeMusicMessageId,
    required this.musicCardPositions,
    required this.favoriteMusicTrackIds,
    required this.busyMusicFavoriteIds,
    required this.canGoMusicPrevious,
    required this.isMusicBusy,
    this.stationMessageId,
    this.stationMessageKey,
    this.agentAvatarUrl,
    this.userAvatarUrl,
    this.authToken,
    this.apiBaseUrl,
  });

  final ScrollController controller;
  final List<ChatMessage> messages;
  final bool isLoadingOlder;
  final double bottomPadding;
  final double topPadding;
  final ValueChanged<ChatComponentCard> onComponentCardTap;
  final ValueChanged<AchievementItem> onAchievementTap;
  final Future<MusicTrack?> Function(MusicTrack track) onResolveMusicTrack;
  final void Function(ChatComponentCard card, String messageId)
  onMusicCardActivated;
  final VoidCallback onMusicPrevious;
  final VoidCallback onMusicNext;
  final ValueChanged<MusicTrack> onMusicFavorite;
  final ValueChanged<ChatAttachment> onAttachmentTap;
  final String? activeMusicMessageId;
  final Map<String, Duration> musicCardPositions;
  final Set<String> favoriteMusicTrackIds;
  final Set<String> busyMusicFavoriteIds;
  final bool canGoMusicPrevious;
  final bool isMusicBusy;
  final String? stationMessageId;
  final GlobalKey? stationMessageKey;
  final String? agentAvatarUrl;
  final String? userAvatarUrl;
  final String? authToken;
  final String? apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        child: Text(
          '还没有聊天记录，发一句话开始吧。',
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }
    return ListView.builder(
      controller: controller,
      padding: EdgeInsets.fromLTRB(12, topPadding, 12, bottomPadding),
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
        final row = _MessageRow(
          message: message,
          agentAvatarUrl: agentAvatarUrl,
          userAvatarUrl: userAvatarUrl,
          onComponentCardTap: onComponentCardTap,
          onAchievementTap: onAchievementTap,
          onResolveMusicTrack: onResolveMusicTrack,
          onMusicCardActivated: onMusicCardActivated,
          onMusicPrevious: onMusicPrevious,
          onMusicNext: onMusicNext,
          onMusicFavorite: onMusicFavorite,
          onAttachmentTap: onAttachmentTap,
          activeMusicMessageId: activeMusicMessageId,
          musicCardPositions: musicCardPositions,
          favoriteMusicTrackIds: favoriteMusicTrackIds,
          busyMusicFavoriteIds: busyMusicFavoriteIds,
          canGoMusicPrevious: canGoMusicPrevious,
          isMusicBusy: isMusicBusy,
          authToken: authToken,
          apiBaseUrl: apiBaseUrl,
        );
        final keyedRow = KeyedSubtree(
          key: ValueKey('chat-message-${message.id}'),
          child: row,
        );
        if (message.id == stationMessageId && stationMessageKey != null) {
          return KeyedSubtree(key: stationMessageKey, child: keyedRow);
        }
        return keyedRow;
      },
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.message,
    required this.onComponentCardTap,
    required this.onAchievementTap,
    required this.onResolveMusicTrack,
    required this.onMusicCardActivated,
    required this.onMusicPrevious,
    required this.onMusicNext,
    required this.onMusicFavorite,
    required this.onAttachmentTap,
    required this.activeMusicMessageId,
    required this.musicCardPositions,
    required this.favoriteMusicTrackIds,
    required this.busyMusicFavoriteIds,
    required this.canGoMusicPrevious,
    required this.isMusicBusy,
    this.agentAvatarUrl,
    this.userAvatarUrl,
    this.authToken,
    this.apiBaseUrl,
  });

  final ChatMessage message;
  final ValueChanged<ChatComponentCard> onComponentCardTap;
  final ValueChanged<AchievementItem> onAchievementTap;
  final Future<MusicTrack?> Function(MusicTrack track) onResolveMusicTrack;
  final void Function(ChatComponentCard card, String messageId)
  onMusicCardActivated;
  final VoidCallback onMusicPrevious;
  final VoidCallback onMusicNext;
  final ValueChanged<MusicTrack> onMusicFavorite;
  final ValueChanged<ChatAttachment> onAttachmentTap;
  final String? activeMusicMessageId;
  final Map<String, Duration> musicCardPositions;
  final Set<String> favoriteMusicTrackIds;
  final Set<String> busyMusicFavoriteIds;
  final bool canGoMusicPrevious;
  final bool isMusicBusy;
  final String? agentAvatarUrl;
  final String? userAvatarUrl;
  final String? authToken;
  final String? apiBaseUrl;
  static const _avatarSize = 40.0;
  static const _avatarGap = 10.0;

  @override
  Widget build(BuildContext context) {
    if (message.isAchievement) {
      final item = message.achievementItem;
      if (item == null) return const SizedBox.shrink();
      return _AchievementTimelineRow(
        item: item,
        onTap: () => onAchievementTap(item),
      );
    }
    if (message.isMusicStatus) {
      return _MusicStatusTimelineRow(message: message);
    }
    if (message.isGameStatus) {
      return _GameStatusTimelineRow(message: message);
    }

    final avatar = _Avatar(
      size: _avatarSize,
      label: message.isMine ? '我' : '伴',
      imageUrl: message.isMine ? userAvatarUrl : agentAvatarUrl,
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
          _Bubble(
            message: message,
            onComponentCardTap: onComponentCardTap,
            onResolveMusicTrack: onResolveMusicTrack,
            onMusicCardActivated: onMusicCardActivated,
            onMusicPrevious: onMusicPrevious,
            onMusicNext: onMusicNext,
            onMusicFavorite: onMusicFavorite,
            onAttachmentTap: onAttachmentTap,
            activeMusicMessageId: activeMusicMessageId,
            musicCardPositions: musicCardPositions,
            favoriteMusicTrackIds: favoriteMusicTrackIds,
            busyMusicFavoriteIds: busyMusicFavoriteIds,
            canGoMusicPrevious: canGoMusicPrevious,
            isMusicBusy: isMusicBusy,
            authToken: authToken,
            apiBaseUrl: apiBaseUrl,
          ),
          if (message.isMine) ...[const SizedBox(width: _avatarGap), avatar],
        ],
      ),
    );
  }
}

class _GameStatusTimelineRow extends StatelessWidget {
  const _GameStatusTimelineRow({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final status = message.metadata?['game_status']?.toString().trim();
    final isEnded = status == 'ended';
    final gameTitle = message.metadata?['game_title']?.toString().trim();
    final actorName = message.metadata?['game_status_actor_name']
        ?.toString()
        .trim();
    final prefix = actorName?.isNotEmpty == true ? '$actorName 和你' : '你们';
    final title = gameTitle?.isNotEmpty == true ? gameTitle! : '游戏';
    final label = '$prefix已${isEnded ? '退出' : '进入'}游戏《$title》';
    final isDark = AppColors.isDark(context);
    final accent = isEnded
        ? (isDark ? const Color(0xFF9AA8B8) : const Color(0xFF64748B))
        : (isDark ? AppColors.accent : const Color(0xFF177DDC));
    final fill = isDark
        ? AppColors.surfaceMuted.withValues(alpha: 0.76)
        : (isEnded ? const Color(0xFFF1F5F9) : const Color(0xFFEAF4FF));
    final border = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : (isEnded ? const Color(0xFFD5DEE9) : const Color(0xFFBFDDFF));
    final iconFill = isDark
        ? accent.withValues(alpha: 0.16)
        : (isEnded ? const Color(0xFFE2E8F0) : const Color(0xFFDCEEFF));
    final maxBubbleWidth = math.min(
      320.0,
      MediaQuery.sizeOf(context).width - 72,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxBubbleWidth),
          child: IntrinsicWidth(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: border),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 7, 12, 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: iconFill,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isEnded
                                ? CupertinoIcons.game_controller
                                : CupertinoIcons.game_controller_solid,
                            size: 12,
                            color: accent,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 2,
                            softWrap: true,
                            overflow: TextOverflow.visible,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              height: 1.12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(message.createdAt),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: accent.withValues(alpha: 0.56),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MusicStatusTimelineRow extends StatelessWidget {
  const _MusicStatusTimelineRow({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final status = message.metadata?['music_status']?.toString().trim();
    final isEnded = status == 'ended';
    final actor = message.metadata?['music_status_actor']?.toString().trim();
    final actorName = message.metadata?['music_status_actor_name']
        ?.toString()
        .trim();
    final prefix = switch (actor) {
      'user' => '你',
      'agent' => (actorName?.isNotEmpty == true ? actorName! : '对方'),
      _ => '',
    };
    final label = '$prefix${isEnded ? '已退出共听' : '已加入共听'}';
    final isDark = AppColors.isDark(context);
    final accent = isEnded
        ? (isDark ? const Color(0xFF9AA8B8) : const Color(0xFF64748B))
        : (isDark ? const Color(0xFF35D487) : const Color(0xFF149249));
    final fill = isDark
        ? AppColors.surfaceMuted.withValues(alpha: 0.76)
        : (isEnded ? const Color(0xFFF1F5F9) : const Color(0xFFEAF8EF));
    final border = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : (isEnded ? const Color(0xFFD5DEE9) : const Color(0xFFBDEBCB));
    final iconFill = isDark
        ? accent.withValues(alpha: 0.16)
        : (isEnded ? const Color(0xFFE2E8F0) : const Color(0xFFD9F5E4));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 190),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 7, 12, 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: iconFill,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isEnded
                              ? CupertinoIcons.music_note_list
                              : CupertinoIcons.music_note_2,
                          size: 12,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            height: 1.08,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(message.createdAt),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: accent.withValues(alpha: 0.56),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.onComponentCardTap,
    required this.onResolveMusicTrack,
    required this.onMusicCardActivated,
    required this.onMusicPrevious,
    required this.onMusicNext,
    required this.onMusicFavorite,
    required this.onAttachmentTap,
    required this.activeMusicMessageId,
    required this.musicCardPositions,
    required this.favoriteMusicTrackIds,
    required this.busyMusicFavoriteIds,
    required this.canGoMusicPrevious,
    required this.isMusicBusy,
    this.authToken,
    this.apiBaseUrl,
  });

  final ChatMessage message;
  final ValueChanged<ChatComponentCard> onComponentCardTap;
  final Future<MusicTrack?> Function(MusicTrack track) onResolveMusicTrack;
  final void Function(ChatComponentCard card, String messageId)
  onMusicCardActivated;
  final VoidCallback onMusicPrevious;
  final VoidCallback onMusicNext;
  final ValueChanged<MusicTrack> onMusicFavorite;
  final ValueChanged<ChatAttachment> onAttachmentTap;
  final String? activeMusicMessageId;
  final Map<String, Duration> musicCardPositions;
  final Set<String> favoriteMusicTrackIds;
  final Set<String> busyMusicFavoriteIds;
  final bool canGoMusicPrevious;
  final bool isMusicBusy;
  final String? authToken;
  final String? apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    final componentCard = message.componentCard;
    final attachments = message.attachments
        .where((item) => item.isImage)
        .toList();
    final shouldHideExternalLinkText =
        componentCard?.type == 'external_link' &&
        _isShareTextRepresentedByExternalLinkCard(
          message.content,
          componentCard!,
        );
    final showTextWithCard =
        (componentCard?.type == 'music_track' ||
            (componentCard?.type == 'external_link' &&
                !shouldHideExternalLinkText)) &&
        message.content.trim().isNotEmpty;
    final showTextWithAttachments =
        attachments.isNotEmpty && message.content.trim().isNotEmpty;
    return Flexible(
      child: Column(
        crossAxisAlignment: message.isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (showTextWithCard) ...[
            _MessageTextBubble(message: message),
            const SizedBox(height: 8),
          ],
          if (componentCard != null)
            _ComponentCardBubble(
              card: componentCard,
              isMine: message.isMine,
              onTap: () {
                if (componentCard.type == 'music_track') {
                  onMusicCardActivated(componentCard, message.id);
                }
                onComponentCardTap(componentCard);
              },
              onResolveMusicTrack: onResolveMusicTrack,
              onMusicCardActivated: () =>
                  onMusicCardActivated(componentCard, message.id),
              onMusicPrevious: () {
                onMusicCardActivated(componentCard, message.id);
                onMusicPrevious();
              },
              onMusicNext: () {
                onMusicCardActivated(componentCard, message.id);
                onMusicNext();
              },
              onMusicFavorite: onMusicFavorite,
              isActiveMusicCard: activeMusicMessageId == message.id,
              initialMusicPosition:
                  musicCardPositions[message.id] ?? Duration.zero,
              favoriteMusicTrackIds: favoriteMusicTrackIds,
              busyMusicFavoriteIds: busyMusicFavoriteIds,
              canGoMusicPrevious:
                  activeMusicMessageId == message.id && canGoMusicPrevious,
              isMusicBusy: isMusicBusy,
              authToken: authToken,
              apiBaseUrl: apiBaseUrl,
            )
          else if (attachments.isNotEmpty) ...[
            _ImageAttachmentBubble(
              attachments: attachments,
              isMine: message.isMine,
              authToken: authToken,
              onTap: onAttachmentTap,
            ),
            if (showTextWithAttachments) ...[
              const SizedBox(height: 8),
              _MessageTextBubble(message: message),
            ],
          ] else
            _MessageTextBubble(message: message),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTime(message.createdAt),
                style: TextStyle(color: AppColors.muted, fontSize: 10),
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

class _MessageTextBubble extends StatelessWidget {
  const _MessageTextBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
    );
  }
}

class _ImageAttachmentBubble extends StatelessWidget {
  const _ImageAttachmentBubble({
    required this.attachments,
    required this.isMine,
    required this.onTap,
    this.authToken,
  });

  final List<ChatAttachment> attachments;
  final bool isMine;
  final ValueChanged<ChatAttachment> onTap;
  final String? authToken;

  @override
  Widget build(BuildContext context) {
    final headers = authToken?.isNotEmpty == true
        ? {'Authorization': 'Bearer $authToken'}
        : null;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 270),
      child: Wrap(
        alignment: isMine ? WrapAlignment.end : WrapAlignment.start,
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final attachment in attachments)
            GestureDetector(
              onTap: () => onTap(attachment),
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isMine ? 17 : 3),
                  topRight: Radius.circular(isMine ? 3 : 17),
                  bottomLeft: const Radius.circular(17),
                  bottomRight: const Radius.circular(17),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Image.network(
                    attachment.url,
                    headers: headers,
                    width: _imageWidthFor(attachment),
                    height: _imageHeightFor(attachment),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imageFallback,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return SizedBox(
                        width: _imageWidthFor(attachment),
                        height: _imageHeightFor(attachment),
                        child: const Center(
                          child: CupertinoActivityIndicator(radius: 10),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _imageWidthFor(ChatAttachment attachment) {
    final width = (attachment.width ?? 180).toDouble();
    final height = (attachment.height ?? 180).toDouble();
    if (width <= 0 || height <= 0) return 180;
    final ratio = width / height;
    return ratio >= 1 ? 210 : math.max(128, 168 * ratio);
  }

  double _imageHeightFor(ChatAttachment attachment) {
    final width = (attachment.width ?? 180).toDouble();
    final height = (attachment.height ?? 180).toDouble();
    if (width <= 0 || height <= 0) return 180;
    final ratio = width / height;
    return ratio >= 1 ? math.max(118, 210 / ratio) : 168;
  }

  Widget get _imageFallback {
    return SizedBox(
      width: 180,
      height: 150,
      child: Center(child: Icon(CupertinoIcons.photo, color: AppColors.muted)),
    );
  }
}

class _ComponentCardBubble extends StatelessWidget {
  const _ComponentCardBubble({
    required this.card,
    required this.isMine,
    required this.onTap,
    required this.onResolveMusicTrack,
    required this.onMusicCardActivated,
    required this.onMusicPrevious,
    required this.onMusicNext,
    required this.onMusicFavorite,
    required this.isActiveMusicCard,
    required this.initialMusicPosition,
    required this.favoriteMusicTrackIds,
    required this.busyMusicFavoriteIds,
    required this.canGoMusicPrevious,
    required this.isMusicBusy,
    this.authToken,
    this.apiBaseUrl,
  });

  final ChatComponentCard card;
  final bool isMine;
  final VoidCallback onTap;
  final Future<MusicTrack?> Function(MusicTrack track) onResolveMusicTrack;
  final VoidCallback onMusicCardActivated;
  final VoidCallback onMusicPrevious;
  final VoidCallback onMusicNext;
  final ValueChanged<MusicTrack> onMusicFavorite;
  final bool isActiveMusicCard;
  final Duration initialMusicPosition;
  final Set<String> favoriteMusicTrackIds;
  final Set<String> busyMusicFavoriteIds;
  final bool canGoMusicPrevious;
  final bool isMusicBusy;
  final String? authToken;
  final String? apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    if (card.type == 'music_track') {
      return _MusicComponentCard(
        card: card,
        isMine: isMine,
        onTap: onTap,
        onResolveTrack: onResolveMusicTrack,
        onPlaybackActivated: onMusicCardActivated,
        onPrevious: onMusicPrevious,
        onNext: onMusicNext,
        onFavorite: onMusicFavorite,
        isActiveCard: isActiveMusicCard,
        initialPosition: initialMusicPosition,
        favoriteMusicTrackIds: favoriteMusicTrackIds,
        busyMusicFavoriteIds: busyMusicFavoriteIds,
        canGoPrevious: canGoMusicPrevious,
        isBusy: isMusicBusy,
      );
    }
    if (card.type == 'offline_activity') {
      return _OfflineActivityComponentCard(
        card: card,
        isMine: isMine,
        onTap: onTap,
        authToken: authToken,
        apiBaseUrl: apiBaseUrl,
      );
    }
    final accent = _parseColor(card.accent);
    final isTimeCapsule = card.type == 'time_capsule';
    final timeCapsuleContent = _timeCapsuleContent(card);
    final isDark = AppColors.isDark(context);
    final capsuleSkin = isTimeCapsule
        ? _CapsuleSkin.byId(
            _effectiveCapsuleSkinId(
              context,
              card.payload['skin']?.toString(),
              useThemeDefaultForPaper: true,
            ),
          )
        : null;
    final cardSurface = isTimeCapsule
        ? capsuleSkin!.paper
        : (isDark ? AppColors.surface : Colors.white);
    final borderColor = isTimeCapsule
        ? capsuleSkin!.accent.withValues(alpha: isDark ? 0.34 : 0.24)
        : accent.withValues(alpha: isDark ? 0.20 : 0.24);
    final titleColor = isTimeCapsule ? capsuleSkin!.text : AppColors.text;
    final mutedColor = isTimeCapsule ? capsuleSkin!.muted : AppColors.muted;
    final glowColor = isTimeCapsule ? capsuleSkin!.accent : accent;
    final isExternalLink = card.type == 'external_link';
    final platform = card.payload['platform']?.toString();
    final displayTitle = isExternalLink
        ? _externalLinkPlatformName(card)
        : card.title;
    final displaySubtitle = isExternalLink ? '' : card.subtitle;
    final displayBody = isExternalLink
        ? _externalLinkOriginalText(card)
        : card.body;
    final displayFooter = isExternalLink
        ? _externalLinkFooter(card)
        : card.footer;
    final icon = switch (card.type) {
      'weather' => CupertinoIcons.cloud_sun_fill,
      'external_link' => CupertinoIcons.link_circle_fill,
      'checkin_reminder' ||
      'checkin_habit' => CupertinoIcons.check_mark_circled_solid,
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
            color: cardSurface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(isMine ? 20 : 5),
              topRight: Radius.circular(isMine ? 5 : 20),
              bottomLeft: const Radius.circular(20),
              bottomRight: const Radius.circular(20),
            ),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: isDark ? 0.22 : 0.14),
                blurRadius: isDark ? 26 : 22,
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
                      color: glowColor.withValues(alpha: isDark ? 0.16 : 0.12),
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
                            label: platform == 'B站' ? 'B' : null,
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
                                    style: TextStyle(
                                      color: mutedColor,
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
                                        displayTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: titleColor,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          height: 1.15,
                                        ),
                                      ),
                                      if (displaySubtitle.isNotEmpty)
                                        Text(
                                          displaySubtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: mutedColor,
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
                      if ((isTimeCapsule ? timeCapsuleContent : displayBody)
                          .isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          isTimeCapsule ? timeCapsuleContent : displayBody,
                          maxLines: isTimeCapsule ? 2 : 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 14,
                            height: 1.42,
                          ),
                        ),
                      ],
                      if (displayFooter.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          displayFooter,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isTimeCapsule ? capsuleSkin!.accent : accent,
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

String _externalLinkPlatformName(ChatComponentCard card) {
  final platform = card.payload['platform']?.toString().trim();
  if (platform != null && platform.isNotEmpty) return platform;
  final subtitle = card.subtitle.trim();
  if (subtitle.isNotEmpty) return subtitle.split(' · ').first.trim();
  final title = card.title.trim();
  return title.isEmpty ? '链接' : title;
}

String _externalLinkOriginalText(ChatComponentCard card) {
  for (final value in [
    card.payload['original_text'],
    card.payload['content_text'],
    card.body,
  ]) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _externalLinkFooter(ChatComponentCard card) {
  final platform = _externalLinkPlatformName(card);
  return '点击打开${platform == '链接' ? '原' : platform}app/网页';
}

bool _isShareTextRepresentedByExternalLinkCard(
  String value,
  ChatComponentCard card,
) {
  final text = value.trim();
  if (text.isEmpty) return true;
  final urls = RegExp(r'https?://[^\s，。；：）】》]+')
      .allMatches(text)
      .map((match) => match.group(0) ?? '')
      .where((url) => url.isNotEmpty)
      .toList();
  if (urls.isEmpty) return false;
  var remainder = text;
  for (final url in urls) {
    remainder = remainder.replaceAll(url, ' ');
  }
  remainder = remainder
      .replaceAll(RegExp(r'【[^】]*】'), ' ')
      .replaceAll(RegExp(r'B站|哔哩哔哩|小红书|微博|抖音|知乎|今日头条'), ' ')
      .replaceAll(RegExp(r'[-_｜|]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (remainder.isEmpty) return true;

  final title = card.title.trim();
  final body = card.body.trim();
  bool closeToCardText(String candidate) {
    if (candidate.isEmpty) return false;
    final normalizedRemainder = _normalizeShareComparableText(remainder);
    final normalizedCandidate = _normalizeShareComparableText(candidate);
    return normalizedCandidate.contains(normalizedRemainder) ||
        normalizedRemainder.contains(normalizedCandidate);
  }

  return closeToCardText(title) || closeToCardText(body);
}

String _normalizeShareComparableText(String value) {
  return value
      .replaceAll(RegExp(r'[\s，。；：、,.!?！？【】\[\]()（）\-_|｜「」『』]+'), '')
      .toLowerCase();
}

class _MusicComponentCard extends StatefulWidget {
  const _MusicComponentCard({
    required this.card,
    required this.isMine,
    required this.onTap,
    required this.onResolveTrack,
    required this.onPlaybackActivated,
    required this.onPrevious,
    required this.onNext,
    required this.onFavorite,
    required this.isActiveCard,
    required this.initialPosition,
    required this.favoriteMusicTrackIds,
    required this.busyMusicFavoriteIds,
    required this.canGoPrevious,
    required this.isBusy,
  });

  final ChatComponentCard card;
  final bool isMine;
  final VoidCallback onTap;
  final Future<MusicTrack?> Function(MusicTrack track) onResolveTrack;
  final VoidCallback onPlaybackActivated;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<MusicTrack> onFavorite;
  final bool isActiveCard;
  final Duration initialPosition;
  final Set<String> favoriteMusicTrackIds;
  final Set<String> busyMusicFavoriteIds;
  final bool canGoPrevious;
  final bool isBusy;

  @override
  State<_MusicComponentCard> createState() => _MusicComponentCardState();
}

class _MusicComponentCardState extends State<_MusicComponentCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _discController;
  final _playback = MusicPlaybackController.instance;
  MusicTrack? _resolvedTrack;
  bool _loadingPlayback = false;
  String? _lastPlaybackSignature;

  @override
  void initState() {
    super.initState();
    _discController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 18000),
    );
    _lastPlaybackSignature = _playbackSignature;
    _playback.addListener(_handlePlaybackChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncDiscAnimation());
  }

  @override
  void didUpdateWidget(covariant _MusicComponentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _lastPlaybackSignature = _playbackSignature;
    _syncDiscAnimation();
  }

  @override
  void dispose() {
    _playback.removeListener(_handlePlaybackChanged);
    _discController.dispose();
    super.dispose();
  }

  void _handlePlaybackChanged() {
    final signature = _playbackSignature;
    if (signature == _lastPlaybackSignature) return;
    _lastPlaybackSignature = signature;
    _syncDiscAnimation();
    if (mounted) setState(() {});
  }

  String get _playbackSignature {
    final track = _displayTrack;
    final isCurrent = widget.isActiveCard && _playback.isCurrentTrack(track);
    final isPlaying = isCurrent && _playback.isPlaying;
    final isLoading = isCurrent && _playback.isLoadingTrack(track);
    return [
      widget.isActiveCard,
      track?.id ?? '',
      isCurrent,
      isPlaying,
      isLoading,
    ].join('|');
  }

  void _syncDiscAnimation() {
    if (!mounted) return;
    if (!widget.isActiveCard ||
        !_playback.isCurrentTrack(_displayTrack) ||
        !_playback.isPlaying) {
      if (_discController.isAnimating) {
        _discController.stop(canceled: false);
      }
      return;
    }
    if (!_discController.isAnimating) _discController.repeat();
  }

  Future<void> _toggleCardPlayback(MusicTrack? track) async {
    if (track == null || _loadingPlayback) return;
    setState(() => _loadingPlayback = true);
    try {
      if (widget.isActiveCard && _playback.isCurrentTrack(track)) {
        if (_playback.isPlaying) {
          final toggled = await _playback.toggle(track);
          if (toggled) widget.onPlaybackActivated();
          return;
        }
        final resumed = await _playback.toggle(track);
        if (resumed) {
          widget.onPlaybackActivated();
          return;
        }
        final resolved = await widget.onResolveTrack(track);
        if (!mounted) return;
        final playable = resolved ?? track;
        setState(() => _resolvedTrack = playable);
        final played = await _playback.playTrack(
          playable,
          position: _playback.position,
        );
        if (played) widget.onPlaybackActivated();
        return;
      }
      final resolved = await widget.onResolveTrack(track);
      if (!mounted) return;
      final playable = resolved ?? track;
      setState(() => _resolvedTrack = playable);
      final played = await _playback.playTrack(
        playable,
        position: widget.initialPosition,
      );
      if (played) widget.onPlaybackActivated();
    } catch (_) {
      // Chat card controls should stay silent; the player page can show errors.
    } finally {
      if (mounted) setState(() => _loadingPlayback = false);
    }
  }

  void _toggleFavorite(MusicTrack? track) {
    if (track == null || widget.busyMusicFavoriteIds.contains(track.id)) return;
    widget.onFavorite(track);
  }

  @override
  Widget build(BuildContext context) {
    final displayTrack = _displayTrack;
    final track = _resolvedTrack?.id == displayTrack?.id
        ? _resolvedTrack
        : displayTrack;
    final title = track?.title ?? widget.card.title;
    final artist = track?.artist ?? widget.card.subtitle;
    final library = _musicLibraryTitle(track?.library ?? _stationLibrary);
    final accent = _musicAccentForTrack(track);
    final isCurrent = widget.isActiveCard && _playback.isCurrentTrack(track);
    final isPlaying = isCurrent && _playback.isPlaying;
    final isPlaybackLoading =
        _loadingPlayback || (isCurrent && _playback.isLoadingTrack(track));
    final isFavorite =
        track != null && widget.favoriteMusicTrackIds.contains(track.id);
    final isFavoriteBusy =
        track != null && widget.busyMusicFavoriteIds.contains(track.id);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 292),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF101A27),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(widget.isMine ? 22 : 6),
              topRight: Radius.circular(widget.isMine ? 6 : 22),
              bottomLeft: const Radius.circular(22),
              bottomRight: const Radius.circular(22),
            ),
            border: Border.all(color: accent.withValues(alpha: 0.32)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                _MusicCardDisc(
                  track: track,
                  animation: _discController,
                  isPlaying: isPlaying,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LoopingMarqueeText(
                        text: title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.68),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            ' · ',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.50),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          _MusicCountdownText(
                            track: track,
                            isActiveCard: widget.isActiveCard,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.68),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.music_note_2,
                            color: accent,
                            size: 15,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              library,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _MusicCardIconButton(
                            icon: isFavorite
                                ? CupertinoIcons.heart_fill
                                : CupertinoIcons.heart,
                            enabled: track != null && !isFavoriteBusy,
                            color: isFavorite
                                ? const Color(0xFF5ED8FF)
                                : Colors.white.withValues(alpha: 0.70),
                            onPressed: () => _toggleFavorite(track),
                          ),
                          _MusicCardIconButton(
                            icon: CupertinoIcons.backward_fill,
                            enabled: widget.canGoPrevious && !widget.isBusy,
                            color: Colors.white.withValues(alpha: 0.70),
                            onPressed: widget.onPrevious,
                          ),
                          _MusicCardIconButton(
                            icon: isPlaying
                                ? CupertinoIcons.pause_fill
                                : CupertinoIcons.play_fill,
                            emphasized: true,
                            enabled:
                                track != null &&
                                !widget.isBusy &&
                                !isPlaybackLoading,
                            loading: isPlaybackLoading,
                            color: accent,
                            onPressed: () =>
                                unawaited(_toggleCardPlayback(track)),
                          ),
                          _MusicCardIconButton(
                            icon: CupertinoIcons.forward_fill,
                            enabled: !widget.isBusy,
                            color: Colors.white.withValues(alpha: 0.70),
                            onPressed: widget.onNext,
                          ),
                        ],
                      ),
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

  MusicTrack? get _currentCardTrack {
    final rawTrack = widget.card.payload['track'];
    return rawTrack is Map
        ? MusicTrack.fromJson(Map<String, dynamic>.from(rawTrack))
        : null;
  }

  MusicTrack? get _displayTrack {
    final library = _stationLibrary;
    final liveTrack = _playback.track;
    if (widget.isActiveCard &&
        library != null &&
        liveTrack != null &&
        liveTrack.library == library) {
      return liveTrack;
    }
    return _currentCardTrack;
  }

  String? get _stationLibrary {
    final payloadLibrary = widget.card.payload['library']?.toString().trim();
    if (payloadLibrary != null && payloadLibrary.isNotEmpty) {
      return payloadLibrary;
    }
    final cardLibrary = _currentCardTrack?.library.trim();
    return cardLibrary == null || cardLibrary.isEmpty ? null : cardLibrary;
  }
}

class _MusicCardIconButton extends StatelessWidget {
  const _MusicCardIconButton({
    required this.icon,
    required this.enabled,
    required this.color,
    required this.onPressed,
    this.emphasized = false,
    this.loading = false,
  });

  final IconData icon;
  final bool enabled;
  final Color color;
  final VoidCallback onPressed;
  final bool emphasized;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final size = emphasized ? 30.0 : 25.0;
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: enabled && !loading ? onPressed : null,
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: emphasized && (enabled || loading)
                ? color
                : Colors.transparent,
          ),
          child: Center(
            child: loading
                ? const CupertinoActivityIndicator(
                    radius: 6.5,
                    color: Colors.white,
                  )
                : Transform.translate(
                    offset: emphasized && icon == CupertinoIcons.play_fill
                        ? const Offset(1.0, 0)
                        : Offset.zero,
                    child: Icon(
                      icon,
                      size: emphasized ? 14 : 13,
                      color: enabled
                          ? (emphasized ? _musicButtonForeground(color) : color)
                          : Colors.white.withValues(alpha: 0.24),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _MusicCountdownText extends StatefulWidget {
  const _MusicCountdownText({
    required this.track,
    required this.isActiveCard,
    required this.style,
  });

  final MusicTrack? track;
  final bool isActiveCard;
  final TextStyle style;

  @override
  State<_MusicCountdownText> createState() => _MusicCountdownTextState();
}

class _MusicCountdownTextState extends State<_MusicCountdownText> {
  final _playback = MusicPlaybackController.instance;
  String? _lastLabel;

  @override
  void initState() {
    super.initState();
    _lastLabel = _label;
    _playback.addListener(_handlePlaybackChanged);
  }

  @override
  void didUpdateWidget(covariant _MusicCountdownText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _lastLabel = _label;
  }

  @override
  void dispose() {
    _playback.removeListener(_handlePlaybackChanged);
    super.dispose();
  }

  void _handlePlaybackChanged() {
    final label = _label;
    if (label == _lastLabel) return;
    _lastLabel = label;
    if (mounted) setState(() {});
  }

  String get _label {
    final track = widget.track;
    if (track == null) return '--:--';
    final duration = _durationFor(track);
    if (!widget.isActiveCard || !_playback.isCurrentTrack(track)) {
      return _formatMusicClock(duration);
    }
    final remaining = duration - _playback.position;
    return _formatMusicClock(remaining.isNegative ? Duration.zero : remaining);
  }

  Duration _durationFor(MusicTrack track) {
    final playbackDuration = _playback.duration;
    if (_playback.isCurrentTrack(track) && playbackDuration.inSeconds > 0) {
      return playbackDuration;
    }
    return Duration(seconds: math.max(track.durationSec, 0));
  }

  @override
  Widget build(BuildContext context) {
    return Text(_label, maxLines: 1, style: widget.style);
  }
}

class _MusicCardDisc extends StatelessWidget {
  const _MusicCardDisc({
    required this.track,
    required this.animation,
    required this.isPlaying,
  });

  final MusicTrack? track;
  final Animation<double> animation;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: 58,
        height: 58,
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final angle = animation.value * math.pi * 2;
            return Transform.rotate(angle: angle, child: child);
          },
          child: _MusicDisc(track: track, size: 58),
        ),
      ),
    );
  }
}

class _LoopingMarqueeText extends StatefulWidget {
  const _LoopingMarqueeText({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<_LoopingMarqueeText> createState() => _LoopingMarqueeTextState();
}

class _LoopingMarqueeTextState extends State<_LoopingMarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _overflow = 0;
  bool _shouldScroll = false;
  bool _scrolling = false;
  bool _looping = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(covariant _LoopingMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text == widget.text && oldWidget.style == widget.style) {
      return;
    }
    _controller.stop();
    _controller.reset();
    _overflow = 0;
    _shouldScroll = false;
    _scrolling = false;
    _looping = false;
  }

  @override
  void dispose() {
    _looping = false;
    _controller.dispose();
    super.dispose();
  }

  void _measureAndStart(double maxWidth) {
    if (!mounted || !maxWidth.isFinite || maxWidth <= 0) return;
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    final overflow = painter.width - maxWidth;
    final shouldScroll = overflow > 6;
    if (_shouldScroll != shouldScroll ||
        (shouldScroll && (_overflow - overflow).abs() > 1)) {
      setState(() {
        _shouldScroll = shouldScroll;
        _overflow = math.max(0, overflow);
      });
    }
    if (shouldScroll && !_looping) {
      _looping = true;
      unawaited(_runLoop());
    }
  }

  Future<void> _runLoop() async {
    while (mounted && _looping && _shouldScroll) {
      await Future<void>.delayed(const Duration(seconds: 5));
      if (!mounted || !_looping || !_shouldScroll) break;
      final durationMs = ((_overflow + 36) * 18).clamp(2200, 5200).round();
      _controller.duration = Duration(milliseconds: durationMs);
      setState(() => _scrolling = true);
      await _controller.forward(from: 0);
      if (!mounted) break;
      _controller.reset();
      setState(() => _scrolling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lineHeight =
        (widget.style.fontSize ?? 15) * (widget.style.height ?? 1.2);
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _measureAndStart(constraints.maxWidth),
        );
        if (!_shouldScroll || !_scrolling) {
          return Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: widget.style,
          );
        }
        return SizedBox(
          height: lineHeight,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final offset =
                    -(_overflow + 20) *
                    Curves.easeInOutCubic.transform(_controller.value);
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: child,
                );
              },
              child: OverflowBox(
                maxWidth: double.infinity,
                minHeight: lineHeight,
                maxHeight: lineHeight,
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.text,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                  style: widget.style,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ComponentCardIcon extends StatelessWidget {
  const _ComponentCardIcon({
    required this.type,
    required this.accent,
    required this.fallbackIcon,
    this.label,
  });

  final String type;
  final Color accent;
  final IconData fallbackIcon;
  final String? label;

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
      child: label == null
          ? Icon(fallbackIcon, color: accent, size: 19)
          : Center(
              child: Text(
                label!,
                style: TextStyle(
                  color: accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
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
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.hairline),
      ),
      child: ClipOval(
        child: _hasImage
            ? Image.network(
                imageUrl!.trim(),
                key: ValueKey(imageUrl!.trim()),
                width: size,
                height: size,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => _fallback,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _fallback;
                },
              )
            : _fallback,
      ),
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
