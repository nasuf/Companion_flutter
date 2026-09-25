part of 'package:companion_flutter/main.dart';

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.controller,
    required this.messages,
    required this.isLoadingOlder,
    required this.bottomGap,
    required this.typingVisible,
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
    this.trackPlaybackUpdates = true,
    this.stationMessageId,
    this.stationMessageKey,
    this.highlightMessageId,
    this.highlightVisible = false,
    this.highlightQuery,
    this.highlightMessageKey,
    this.agentAvatarUrl,
    this.userAvatarUrl,
    this.authToken,
    this.apiBaseUrl,
    this.onRetryFailed,
  });

  final ScrollController controller;
  final List<ChatMessage> messages;
  final bool isLoadingOlder;
  final Widget bottomGap;
  final ValueListenable<bool> typingVisible;
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
  final bool trackPlaybackUpdates;
  final String? stationMessageId;
  final GlobalKey? stationMessageKey;

  /// The message a search-result tap just jumped to. [highlightMessageKey]
  /// attaches to whichever row matches this id (same conditional-GlobalKey
  /// idiom [stationMessageKey] already uses) as long as this is non-null —
  /// *not* only while [highlightVisible] is also true, so the key (and thus
  /// the ability to `Scrollable.ensureVisible` it) stays available through
  /// the whole flash sequence, not just its "on" half.
  final String? highlightMessageId;

  /// The flash's current on/off phase — the target row's own text only
  /// actually shows the background highlight (see [_MessageTextBubble])
  /// when this is also true.
  final bool highlightVisible;

  /// The search query whose matches (inside the target message's text) get
  /// the background highlight — the rest of the text, and every other
  /// message, is untouched (same font/size/weight/spacing throughout).
  final String? highlightQuery;
  final GlobalKey? highlightMessageKey;
  final String? agentAvatarUrl;
  final String? userAvatarUrl;
  final String? authToken;
  final String? apiBaseUrl;
  final ValueChanged<ChatMessage>? onRetryFailed;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return ValueListenableBuilder<bool>(
        valueListenable: typingVisible,
        builder: (context, typing, _) {
          if (!typing) {
            return Center(
              child: Text(
                '还没有聊天记录，发一句话开始吧。',
                style: TextStyle(color: AppColors.muted),
              ),
            );
          }
          return _buildConversationList();
        },
      );
    }
    return _buildConversationList();
  }

  Widget _buildConversationList() {
    final processed = preprocessTimelineActivityMessages(messages);
    final visibleMessages = processed.$1;
    final chronologicalIds = [
      for (final message in visibleMessages) message.id,
    ];
    // reverse: true pins short transcripts to the composer and keeps offset 0
    // at the newest message. IME height is NOT in these slivers — the page
    // translates the whole view so keyboard frames never relayout bubbles.
    return CustomScrollView(
      reverse: true,
      controller: controller,
      physics: ChatScrollPolicy.listPhysics,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      scrollCacheExtent: const ScrollCacheExtent.pixels(800),
      slivers: [
        SliverToBoxAdapter(child: bottomGap),
        SliverToBoxAdapter(
          child: ValueListenableBuilder<bool>(
            valueListenable: typingVisible,
            builder: (context, typing, _) {
              if (!typing) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: RepaintBoundary(
                  child: _TypingIndicatorRow(agentAvatarUrl: agentAvatarUrl),
                ),
              );
            },
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, topPadding),
          sliver: SliverList(
            delegate: _ChatMessageChildDelegate(
              childCount: visibleMessages.length,
              findChildIndexCallback: (key) =>
                  ChatScrollPolicy.childIndexForKey(key, chronologicalIds),
              builder: (context, index) {
                return _buildKeyedMessageRow(
                  visibleMessages[visibleMessages.length - 1 - index],
                );
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: AnimatedSwitcher(
            key: const ValueKey(ChatScrollPolicy.headerKey),
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
          ),
        ),
      ],
    );
  }

  Widget _buildKeyedMessageRow(ChatMessage message) {
    final isHighlightTarget =
        highlightMessageId != null && message.id == highlightMessageId;
    final highlighted = isHighlightTarget && highlightVisible;
    Widget row = _MessageRow(
      message: message,
      highlighted: highlighted,
      highlightQuery: highlightQuery,
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
      trackPlaybackUpdates: trackPlaybackUpdates,
      authToken: authToken,
      apiBaseUrl: apiBaseUrl,
      onRetryFailed: onRetryFailed,
    );
    if (isHighlightTarget && highlightMessageKey != null) {
      row = KeyedSubtree(key: highlightMessageKey, child: row);
    } else if (message.id == stationMessageId && stationMessageKey != null) {
      row = KeyedSubtree(key: stationMessageKey, child: row);
    }
    return RepaintBoundary(
      key: ValueKey(ChatScrollPolicy.messageKey(message.id)),
      child: row,
    );
  }
}

class _ChatMessageChildDelegate extends SliverChildBuilderDelegate {
  _ChatMessageChildDelegate({
    required NullableIndexedWidgetBuilder builder,
    required int childCount,
    ChildIndexGetter? findChildIndexCallback,
  }) : super(
         builder,
         childCount: childCount,
         findChildIndexCallback: findChildIndexCallback,
         addRepaintBoundaries: false,
       );
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.message,
    this.highlighted = false,
    this.highlightQuery,
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
    this.trackPlaybackUpdates = true,
    this.agentAvatarUrl,
    this.userAvatarUrl,
    this.authToken,
    this.apiBaseUrl,
    this.onRetryFailed,
  });

  final ChatMessage message;

  /// True for exactly the one message a search-result tap just jumped to —
  /// gives its own [highlightQuery] matches a background highlight via
  /// [_Bubble]/[_MessageTextBubble], then fades back to normal.
  final bool highlighted;

  /// The query to highlight matches of, while [highlighted].
  final String? highlightQuery;
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
  final bool trackPlaybackUpdates;
  final String? agentAvatarUrl;
  final String? userAvatarUrl;
  final String? authToken;
  final String? apiBaseUrl;
  final ValueChanged<ChatMessage>? onRetryFailed;
  static const _avatarSize = 40.0;
  static const _avatarGap = 10.0;

  bool get _splitTextAndCard => _messageShowsSplitTextAndCard(message);

  Widget _buildAvatar({
    required bool isMine,
    required String? agentAvatarUrl,
    required String? userAvatarUrl,
  }) {
    return _Avatar(
      size: _avatarSize,
      label: isMine ? '我' : '伴',
      imageUrl: isMine ? userAvatarUrl : agentAvatarUrl,
      gradient: isMine
          ? const [Color(0xFFE8F3FF), Color(0xFFF8FBFF)]
          : const [Color(0xFFE8F3FF), Color(0xFFDDEBFF)],
    );
  }

  Widget _buildAvatarBubbleRow(
    BuildContext context, {
    required _BubbleSegment segment,
    required bool showTimestamp,
    bool showSendStatus = true,
  }) {
    final avatar = _buildAvatar(
      isMine: message.isMine,
      agentAvatarUrl: agentAvatarUrl,
      userAvatarUrl: userAvatarUrl,
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
            highlighted: highlighted,
            highlightQuery: highlightQuery,
            segment: segment,
            showTimestamp: showTimestamp,
            showSendStatus: showSendStatus,
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
            trackPlaybackUpdates: trackPlaybackUpdates,
            authToken: authToken,
            apiBaseUrl: apiBaseUrl,
            onRetryFailed: onRetryFailed,
          ),
          if (message.isMine) ...[const SizedBox(width: _avatarGap), avatar],
        ],
      ),
    );
  }

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
    if (message.isMusicActivityTimeline) {
      return MusicActivityBurstRow(message: message);
    }
    if (message.isGameActivityTimeline) {
      return GameActivityBurstRow(message: message);
    }
    if (message.isOfferingReceived) {
      return _OfferingReceivedTimelineRow(message: message);
    }
    final thoughtFragment = message.offlineThoughtFragment;
    if (thoughtFragment != null) {
      return _ThoughtFragmentRow(
        message: message,
        fragment: thoughtFragment,
        agentAvatarUrl: agentAvatarUrl,
      );
    }

    if (_splitTextAndCard) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAvatarBubbleRow(
            context,
            segment: _BubbleSegment.textOnly,
            showTimestamp: false,
            showSendStatus: false,
          ),
          const SizedBox(height: 8),
          _buildAvatarBubbleRow(
            context,
            segment: _BubbleSegment.cardOnly,
            showTimestamp: true,
            showSendStatus: true,
          ),
        ],
      );
    }

    return _buildAvatarBubbleRow(
      context,
      segment: _BubbleSegment.all,
      showTimestamp: true,
    );
  }
}

/// 思绪碎片气泡（spec §5.2）：识图命中后入场的特殊 AI 气泡。磨砂玻璃 + 等级色描边
/// + 淡入上移，区别于普通聊天气泡，呼应「偶遇一缕思绪」的仪式感。
class _ThoughtFragmentRow extends StatelessWidget {
  const _ThoughtFragmentRow({
    required this.message,
    required this.fragment,
    this.agentAvatarUrl,
  });

  final ChatMessage message;
  final Map<String, dynamic> fragment;
  final String? agentAvatarUrl;

  // tier -> (emoji, 标签, 主调色)
  static const Map<String, (String, String, Color)> _tierMeta = {
    'rare': ('💭', '片刻感想', Color(0xFF5FB6AE)),
    'epic': ('📜', '心底独白', Color(0xFFB07FD0)),
    'legendary': ('🔮', '秘密念想', Color(0xFFD79A2E)),
  };

  @override
  Widget build(BuildContext context) {
    final tier = fragment['tier']?.toString() ?? 'rare';
    final (icon, label, accent) = _tierMeta[tier] ?? _tierMeta['rare']!;
    final lead = fragment['lead_in']?.toString() ?? '';
    final w = _W2b.resolve(context);
    // 跟普通 AI 气泡完全同位：外层 SliverList 已给左右各 12 的水平内边距，这里只补
    // 与普通气泡一致的垂直间距，不再额外加水平内边距（否则会比普通消息多缩进一截）。
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(
            size: 40,
            label: '伴',
            imageUrl: agentAvatarUrl,
            gradient: const [Color(0xFFE8F3FF), Color(0xFFDDEBFF)],
          ),
          const SizedBox(width: 10),
          // 跟普通文字气泡同宽（maxWidth 270），shrink-wrap 而非用 Flexible 撑满整行，
          // 否则思绪卡片会比其他聊天卡片明显更宽。
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 270),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0, 1),
          child: Transform.translate(offset: Offset(0, (1 - t) * 10), child: child),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: w.glass,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: accent.withValues(alpha: 0.55)),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.16),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('✨', style: TextStyle(fontSize: 12, color: accent)),
                      const SizedBox(width: 4),
                      Text(
                        '偶遇一缕思绪',
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                  if (lead.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      lead,
                      style: TextStyle(
                        color: w.inkSoft,
                        fontSize: 13,
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    message.content,
                    style: TextStyle(
                      color: w.ink,
                      fontSize: 15,
                      height: 1.6,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$icon $label',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
                // 时间戳：与普通 AI 气泡一致（卡片下方、左对齐、10px muted）。
                const SizedBox(height: 3),
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(color: AppColors.muted, fontSize: 10),
                ),
              ],
            ),
            ),
          ],
        ),
    );
  }
}

enum _BubbleSegment { all, textOnly, cardOnly }

bool _messageShowsSplitTextAndCard(ChatMessage message) {
  final componentCard = message.componentCard;
  if (componentCard == null) return false;
  final shouldHideExternalLinkText =
      componentCard.type == 'external_link' &&
      _isShareTextRepresentedByExternalLinkCard(message.content, componentCard);
  final showTextWithCard =
      (componentCard.type == 'music_track' ||
          (componentCard.type == 'external_link' &&
              !shouldHideExternalLinkText)) &&
      message.content.trim().isNotEmpty;
  return showTextWithCard;
}

class _OfferingReceivedTimelineRow extends StatelessWidget {
  const _OfferingReceivedTimelineRow({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final kind = message.metadata?['offering_kind']?.toString() ?? '';
    final isGift = kind == 'gift';
    final label = message.content.trim().isNotEmpty
        ? message.content.trim()
        : (isGift ? '对方收下了你的礼物' : '对方领取了你的红包');
    final isDark = AppColors.isDark(context);
    final textColor = isDark
        ? const Color(0xFF8B95A1)
        : const Color(0xFF888888);
    final iconColor = isGift
        ? (isDark ? const Color(0xFFC48A62) : const Color(0xFFC47A3A))
        : (isDark ? const Color(0xFFC97A82) : const Color(0xFFC45C66));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width - 72,
          ),
          child: Row(
            key: const Key('offering-received-notice'),
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isGift)
                Icon(CupertinoIcons.gift_fill, size: 13, color: iconColor)
              else
                SizedBox(
                  width: 13,
                  height: 13,
                  child: _HongbaoGlyph(size: 13, bodyColor: iconColor),
                ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    this.highlighted = false,
    this.highlightQuery,
    this.segment = _BubbleSegment.all,
    this.showTimestamp = true,
    this.showSendStatus = true,
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
    this.trackPlaybackUpdates = true,
    this.authToken,
    this.apiBaseUrl,
    this.onRetryFailed,
  });

  final ChatMessage message;
  final bool highlighted;
  final String? highlightQuery;
  final _BubbleSegment segment;
  final bool showTimestamp;
  final bool showSendStatus;
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
  final bool trackPlaybackUpdates;
  final String? authToken;
  final String? apiBaseUrl;
  final ValueChanged<ChatMessage>? onRetryFailed;

  @override
  Widget build(BuildContext context) {
    final componentCard = message.componentCard;
    final imageAttachments = message.attachments
        .where((item) => item.isImage)
        .toList();
    final audioAttachments = message.attachments
        .where((item) => item.showsAsVoice)
        .toList();
    final audioAttachment = audioAttachments.isEmpty
        ? null
        : audioAttachments.first;
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
        imageAttachments.isNotEmpty && message.content.trim().isNotEmpty;
    final includeText =
        segment != _BubbleSegment.cardOnly &&
        (showTextWithCard ||
            showTextWithAttachments ||
            (segment == _BubbleSegment.all &&
                componentCard == null &&
                !message.isVoiceTranscriptionPending &&
                !message.isVoiceUploadPending &&
                audioAttachment == null &&
                imageAttachments.isEmpty));
    final includeCard =
        segment != _BubbleSegment.textOnly && componentCard != null;

    final Widget bubbleColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: message.isMine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (includeText &&
            showTextWithCard &&
            segment != _BubbleSegment.all) ...[
          _MessageTextBubble(
            message: message,
            highlighted: highlighted,
            highlightQuery: highlightQuery,
          ),
        ] else if (includeText &&
            showTextWithCard &&
            segment == _BubbleSegment.all) ...[
          _MessageTextBubble(
            message: message,
            highlighted: highlighted,
            highlightQuery: highlightQuery,
          ),
          const SizedBox(height: 8),
        ],
        if (message.isVoiceTranscriptionPending &&
            segment != _BubbleSegment.cardOnly)
          const _VoiceTranscriptionPendingBubble()
        else if (message.isVoiceUploadPending &&
            segment != _BubbleSegment.cardOnly)
          _VoiceUploadPendingBubble(
            durationSeconds: message.voicePendingDurationSeconds ?? 1,
          )
        else if (includeCard)
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
            trackPlaybackUpdates: trackPlaybackUpdates,
            authToken: authToken,
            apiBaseUrl: apiBaseUrl,
          )
        else if (audioAttachment != null && segment != _BubbleSegment.cardOnly)
          _VoiceMessageBubble(
            attachment: audioAttachment,
            isMine: message.isMine,
            transcript: message.isMine ? null : message.content,
            authToken: authToken,
            apiBaseUrl: apiBaseUrl,
          )
        else if (imageAttachments.isNotEmpty &&
            segment != _BubbleSegment.cardOnly) ...[
          _ImageAttachmentBubble(
            attachments: imageAttachments,
            isMine: message.isMine,
            authToken: authToken,
            onTap: onAttachmentTap,
            recognized: message.offlineRecognized,
          ),
          if (showTextWithAttachments) ...[
            const SizedBox(height: 8),
            _MessageTextBubble(
              message: message,
              highlighted: highlighted,
              highlightQuery: highlightQuery,
            ),
          ],
        ] else if (includeText &&
            segment != _BubbleSegment.cardOnly &&
            !showTextWithCard)
          _MessageTextBubble(
            message: message,
            highlighted: highlighted,
            highlightQuery: highlightQuery,
          ),
      ],
    );

    return Flexible(
      child: Column(
        crossAxisAlignment: message.isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Own messages carry a read/unread status circle to the left of the
          // bubble (Figma 281:1509); AI messages render the bubble alone.
          if (message.isMine && showSendStatus)
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _SendStatusIndicator(
                  read: message.read,
                  failed: message.failed,
                  onRetry: message.failed && onRetryFailed != null
                      ? () => onRetryFailed!(message)
                      : null,
                ),
                const SizedBox(width: 8),
                bubbleColumn,
              ],
            )
          else if (message.isMine)
            bubbleColumn
          else
            bubbleColumn,
          if (showTimestamp) ...[
            const SizedBox(height: 3),
            Text(
              _formatTime(message.createdAt),
              style: TextStyle(color: AppColors.muted, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}

/// Read (checkmark-in-circle) / unread (empty circle) / failed (red "!",
/// tappable to retry) indicator shown to the left of the current user's own
/// message bubbles. Read/unread matches Figma 281:1513; failed is a new
/// state — a message the client gave up waiting a response for (send
/// timeout / socket down / server error) — that previously had no visual
/// distinction from "still sending" at all.
class _SendStatusIndicator extends StatelessWidget {
  const _SendStatusIndicator({
    required this.read,
    this.failed = false,
    this.onRetry,
  });

  final bool read;
  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final danger = AppColors.of(context).danger;
    const color = Color(0xFFA5A5A5);
    final indicator = Semantics(
      label: failed ? '发送失败，点击重试' : (read ? '已读' : '未读'),
      child: Container(
        width: 12,
        height: 12,
        // Keep a small gap between the circle and the bubble's bottom edge so
        // the shrunken indicator still reads as vertically anchored to it.
        margin: const EdgeInsets.only(bottom: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: failed ? danger : color, width: 1),
        ),
        child: failed
            ? Icon(Icons.priority_high_rounded, size: 8, color: danger)
            : (read
                  ? const Icon(Icons.check_rounded, size: 8, color: color)
                  : null),
      ),
    );
    if (!failed || onRetry == null) return indicator;
    return GestureDetector(onTap: onRetry, child: indicator);
  }
}

/// "Agent is typing" row — an AI-styled bubble with three animated dots.
/// Mirrors the H5 typing indicator (ChatView `.m-typing`), refined for native.
class _TypingIndicatorRow extends StatelessWidget {
  const _TypingIndicatorRow({this.agentAvatarUrl});

  final String? agentAvatarUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(
            size: 40,
            label: '伴',
            imageUrl: agentAvatarUrl,
            gradient: const [Color(0xFFE8F3FF), Color(0xFFDDEBFF)],
          ),
          const SizedBox(width: 10),
          const _TypingBubble(),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Wave envelope matching the H5 keyframes: rise to a peak at 35% of the
  // cycle, settle back by 70%, then rest until the loop restarts.
  double _wave(double phase) {
    const peak = 0.35;
    const settle = 0.7;
    if (phase <= peak) {
      return Curves.easeOut.transform((phase / peak).clamp(0.0, 1.0));
    }
    if (phase <= settle) {
      return Curves.easeIn.transform(
        (1 - (phase - peak) / (settle - peak)).clamp(0.0, 1.0),
      );
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '对方正在输入',
      liveRegion: true,
      child: DecoratedBox(
        decoration: _chatBubbleDecoration(context, isMine: false),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: SizedBox(
            height: 8,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final phase = (_controller.value - i * 0.16) % 1.0;
                    final wave = _wave(phase);
                    return Padding(
                      padding: EdgeInsets.only(right: i == 2 ? 0 : 6),
                      child: Transform.translate(
                        offset: Offset(0, -5 * wave),
                        child: Transform.scale(
                          scale: 0.7 + 0.3 * wave,
                          child: Opacity(
                            opacity: 0.35 + 0.65 * wave,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                // Brand green gradient (same family as the
                                // composer accents), not the global blue.
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFF24D7D3), chatVoiceAccent],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ),
      ),
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
              painter: _CapsuleSidebarIconPainter(
                accent: accent,
                showDot: false,
              ),
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
        child: AgentAvatarImage(
          imageUrl: imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          fallback: _fallback,
        ),
      ),
    );
  }

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
