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
          activeMusicMessageId: activeMusicMessageId,
          musicCardPositions: musicCardPositions,
          favoriteMusicTrackIds: favoriteMusicTrackIds,
          busyMusicFavoriteIds: busyMusicFavoriteIds,
          canGoMusicPrevious: canGoMusicPrevious,
          isMusicBusy: isMusicBusy,
        );
        if (message.id == stationMessageId && stationMessageKey != null) {
          return KeyedSubtree(key: stationMessageKey, child: row);
        }
        return row;
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
    required this.activeMusicMessageId,
    required this.musicCardPositions,
    required this.favoriteMusicTrackIds,
    required this.busyMusicFavoriteIds,
    required this.canGoMusicPrevious,
    required this.isMusicBusy,
    this.agentAvatarUrl,
    this.userAvatarUrl,
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
  final String? activeMusicMessageId;
  final Map<String, Duration> musicCardPositions;
  final Set<String> favoriteMusicTrackIds;
  final Set<String> busyMusicFavoriteIds;
  final bool canGoMusicPrevious;
  final bool isMusicBusy;
  final String? agentAvatarUrl;
  final String? userAvatarUrl;
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
            activeMusicMessageId: activeMusicMessageId,
            musicCardPositions: musicCardPositions,
            favoriteMusicTrackIds: favoriteMusicTrackIds,
            busyMusicFavoriteIds: busyMusicFavoriteIds,
            canGoMusicPrevious: canGoMusicPrevious,
            isMusicBusy: isMusicBusy,
          ),
          if (message.isMine) ...[const SizedBox(width: _avatarGap), avatar],
        ],
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
    final accent = isEnded ? const Color(0xFF64748B) : const Color(0xFF149249);
    final fill = isEnded ? const Color(0xFFF1F5F9) : const Color(0xFFEAF8EF);
    final border = isEnded ? const Color(0xFFD5DEE9) : const Color(0xFFBDEBCB);
    final iconFill = isEnded
        ? const Color(0xFFE2E8F0)
        : const Color(0xFFD9F5E4);
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
    required this.activeMusicMessageId,
    required this.musicCardPositions,
    required this.favoriteMusicTrackIds,
    required this.busyMusicFavoriteIds,
    required this.canGoMusicPrevious,
    required this.isMusicBusy,
  });

  final ChatMessage message;
  final ValueChanged<ChatComponentCard> onComponentCardTap;
  final Future<MusicTrack?> Function(MusicTrack track) onResolveMusicTrack;
  final void Function(ChatComponentCard card, String messageId)
  onMusicCardActivated;
  final VoidCallback onMusicPrevious;
  final VoidCallback onMusicNext;
  final ValueChanged<MusicTrack> onMusicFavorite;
  final String? activeMusicMessageId;
  final Map<String, Duration> musicCardPositions;
  final Set<String> favoriteMusicTrackIds;
  final Set<String> busyMusicFavoriteIds;
  final bool canGoMusicPrevious;
  final bool isMusicBusy;

  @override
  Widget build(BuildContext context) {
    final componentCard = message.componentCard;
    final showTextWithCard =
        componentCard?.type == 'music_track' &&
        message.content.trim().isNotEmpty;
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
            )
          else
            _MessageTextBubble(message: message),
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
    final accent = _parseColor(card.accent);
    final isTimeCapsule = card.type == 'time_capsule';
    final timeCapsuleContent = _timeCapsuleContent(card);
    final icon = switch (card.type) {
      'weather' => CupertinoIcons.cloud_sun_fill,
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
