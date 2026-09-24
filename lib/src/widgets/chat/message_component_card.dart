part of 'package:companion_flutter/main.dart';

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
    this.trackPlaybackUpdates = true,
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
  final bool trackPlaybackUpdates;
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
        trackPlaybackUpdates: trackPlaybackUpdates,
      );
    }
    if (card.type == 'meal_voucher') {
      return const SizedBox.shrink();
    }
    if (card.type == 'red_packet') {
      return _RedPacketComponentCard(card: card, isMine: isMine, onTap: onTap);
    }
    if (card.type == 'gift') {
      return _GiftComponentCard(card: card, isMine: isMine, onTap: onTap);
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
    if (card.type == 'location') {
      return _LocationComponentCard(card: card, isMine: isMine, onTap: onTap);
    }
    if (card.type == 'offline_gift') {
      return _OfflineGiftComponentCard(
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
  // 2026-09-14 顺序调整: page_title (真实视频/帖子标题) 优先.
  // 之前 summary (页面描述) 排第一, 导致 B站视频卡片主体位显示的是长段描述而不是
  // 视频真名 (用户截图: "上海浦东机场与虹桥机场各有特色..." 其实是描述, 真名
  // 反被埋在 page_title). 帖子/视频真名短、具体、指向性强, 是"这条卡在讲什么"
  // 的核心信息; summary 是补充上下文, 应作次要.
  // 对全部 6 个支持平台 (微博/小红书/B站/知乎/抖音/头条) 一视同仁.
  for (final value in [
    card.payload['page_title'],
    card.payload['summary'],
    card.payload['content_text'],
    card.payload['original_text'],
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
