part of 'package:companion_flutter/main.dart';

/// The attachment an image search hit actually matched on, falling back to
/// the message's first image attachment. Null only if the message somehow
/// carries no image attachments at all (shouldn't happen for match_type
/// "image", but avoids a throwing `.first` on a defensive empty list).
ChatAttachment? matchedImageAttachment(MessageSearchHit hit) {
  final attachments = hit.message.attachments;
  if (attachments.isEmpty) return null;
  for (final attachment in attachments) {
    if (attachment.id == hit.matchedAttachmentId) return attachment;
  }
  return attachments.first;
}

/// Result rows for [ChatSearchPage]. Each one renders through the exact same
/// bubble/card widgets chat itself uses (`_MessageTextBubble`,
/// `_ComponentCardBubble`, `ChatCachedImage`) so a search result looks and
/// (for cards/images) behaves identically to the live chat bubble it mirrors.

/// Small "who said it, when" header shown above a result bubble.
class _SearchResultMeta extends StatelessWidget {
  const _SearchResultMeta({
    required this.isMine,
    required this.createdAt,
    required this.agentName,
  });

  final bool isMine;
  final DateTime createdAt;
  final String agentName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '${isMine ? '我' : agentName} · ${_formatTime(createdAt)}',
        style: TextStyle(
          color: AppColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class SearchTextResultRow extends StatelessWidget {
  const SearchTextResultRow({
    super.key,
    required this.hit,
    required this.agentName,
    required this.onTap,
  });

  final MessageSearchHit hit;
  final String agentName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isMine = hit.message.isMine;
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          _SearchResultMeta(
            isMine: isMine,
            createdAt: hit.message.createdAt,
            agentName: agentName,
          ),
          Align(
            alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
            child: _MessageTextBubble(message: hit.message),
          ),
        ],
      ),
    );
  }
}

class SearchCardResultRow extends StatelessWidget {
  const SearchCardResultRow({
    super.key,
    required this.hit,
    required this.agentName,
    required this.onTap,
    this.authToken,
    this.apiBaseUrl,
  });

  final MessageSearchHit hit;
  final String agentName;
  final VoidCallback onTap;
  final String? authToken;
  final String? apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    final card = hit.message.componentCard;
    if (card == null) return const SizedBox.shrink();
    final isMine = hit.message.isMine;
    return Column(
      crossAxisAlignment: isMine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        _SearchResultMeta(
          isMine: isMine,
          createdAt: hit.message.createdAt,
          agentName: agentName,
        ),
        Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          // The card renders with full visual fidelity (same widget chat
          // uses), but its own interactive bits (music mini-player controls,
          // favorite button, ...) only make sense in a live chat — here the
          // whole card is a single "open" tap target instead. IgnorePointer
          // silences the card's own internal CupertinoButton (and its
          // press-fade feedback), so the wrapper is a CupertinoButton too —
          // otherwise tapping the card gave no visual acknowledgment at all.
          child: CupertinoButton(
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            onPressed: onTap,
            child: IgnorePointer(
              child: _ComponentCardBubble(
                card: card,
                isMine: isMine,
                onTap: () {},
                onResolveMusicTrack: (track) async => track,
                onMusicCardActivated: () {},
                onMusicPrevious: () {},
                onMusicNext: () {},
                onMusicFavorite: (_) {},
                isActiveMusicCard: false,
                initialMusicPosition: Duration.zero,
                favoriteMusicTrackIds: const {},
                busyMusicFavoriteIds: const {},
                canGoMusicPrevious: false,
                isMusicBusy: false,
                authToken: authToken,
                apiBaseUrl: apiBaseUrl,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Square image thumbnail used both in the "全部" section's horizontal
/// preview strip and the dedicated image grid.
class SearchImageThumb extends StatelessWidget {
  const SearchImageThumb({
    super.key,
    required this.attachment,
    required this.onTap,
    this.authToken,
    this.size = 96,
  });

  final ChatAttachment attachment;
  final VoidCallback onTap;
  final String? authToken;

  /// Fixed square side length (used in the horizontal preview strip). Leave
  /// null to fill the parent's own bounds instead (grid cells, which already
  /// give a tight square constraint via [SliverGridDelegateWithFixedCrossAxisCount]).
  final double? size;

  @override
  Widget build(BuildContext context) {
    final headers = authToken?.isNotEmpty == true
        ? {'Authorization': 'Bearer $authToken'}
        : null;
    final iconSize = size == null ? 24.0 : size! * 0.35;
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ChatCachedImage(
          url: chatMediaThumbUrl(attachment.url),
          headers: headers,
          width: size,
          height: size,
          fit: BoxFit.cover,
          memCacheWidth: 220,
          placeholder: (_) => DecoratedBox(
            decoration: BoxDecoration(color: AppColors.surfaceMuted),
          ),
          error: (_) => DecoratedBox(
            decoration: BoxDecoration(color: AppColors.surfaceMuted),
            child: Icon(
              CupertinoIcons.photo,
              color: AppColors.muted,
              size: iconSize,
            ),
          ),
        ),
      ),
    );
  }
}
