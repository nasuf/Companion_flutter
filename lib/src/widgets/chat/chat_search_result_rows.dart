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

/// One month's worth of consecutive hits. Assumes the input list is already
/// newest-first (true of every search response this app makes), so a simple
/// single pass is enough — no re-sorting needed.
class MonthGroup {
  const MonthGroup(this.label, this.hits);

  final String label;
  final List<MessageSearchHit> hits;
}

List<MonthGroup> groupHitsByMonth(List<MessageSearchHit> hits) {
  final groups = <MonthGroup>[];
  String? currentLabel;
  List<MessageSearchHit>? currentHits;
  for (final hit in hits) {
    final createdAt = hit.message.createdAt;
    final label = '${createdAt.year}-${createdAt.month}';
    if (label != currentLabel) {
      currentHits = <MessageSearchHit>[];
      groups.add(MonthGroup(label, currentHits));
      currentLabel = label;
    }
    currentHits!.add(hit);
  }
  return groups;
}

/// A month section header that stays pinned to the top of its
/// `CustomScrollView` until the next month's header pushes it off — the
/// standard "sticky section header" recipe (one `SliverPersistentHeader`
/// per section) rather than a plain inline label, so scrolling through a
/// long result list always shows which month you're currently looking at.
class MonthHeaderDelegate extends SliverPersistentHeaderDelegate {
  const MonthHeaderDelegate({
    required this.label,
    required this.background,
    this.horizontalPadding = 14,
  });

  final String label;
  final Color background;
  final double horizontalPadding;

  static const double height = 30;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: background,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant MonthHeaderDelegate oldDelegate) {
    return oldDelegate.label != label ||
        oldDelegate.background != background ||
        oldDelegate.horizontalPadding != horizontalPadding;
  }
}

/// Result rows for [ChatSearchPage]: WeChat-style — avatar + sender name +
/// date on one line, the actual content below, no left/right split by
/// sender. Cards still render through the exact same [_ComponentCardBubble]
/// chat itself uses (real `isMine` preserved there for its own corner
/// shape/fidelity) so a card result looks and behaves identically to the
/// live chat bubble it mirrors; only the *row*'s layout stopped caring who
/// sent it.
class _SearchResultHeader extends StatelessWidget {
  const _SearchResultHeader({
    required this.isMine,
    required this.createdAt,
    required this.agentName,
    this.agentAvatarUrl,
    this.userAvatarUrl,
  });

  final bool isMine;
  final DateTime createdAt;
  final String agentName;
  final String? agentAvatarUrl;
  final String? userAvatarUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          _Avatar(
            size: 28,
            label: isMine ? '我' : '伴',
            imageUrl: isMine ? userAvatarUrl : agentAvatarUrl,
            gradient: isMine
                ? const [Color(0xFFE8F3FF), Color(0xFFF8FBFF)]
                : const [Color(0xFFE8F3FF), Color(0xFFDDEBFF)],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isMine ? '我' : agentName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatTime(createdAt),
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Splits [text] into spans, coloring every case-insensitive occurrence of
/// [query] in [highlightColor]. Falls back to one plain span for an empty
/// query — a search result should never render fewer results than what it
/// matched on, but an empty/whitespace query is a legitimate "browse all of
/// this category" call with nothing to highlight.
List<TextSpan> highlightedSpans({
  required String text,
  required String query,
  required TextStyle baseStyle,
  required TextStyle highlightStyle,
}) {
  final needle = query.trim();
  if (needle.isEmpty) return [TextSpan(text: text, style: baseStyle)];
  final lowerText = text.toLowerCase();
  final lowerNeedle = needle.toLowerCase();
  final spans = <TextSpan>[];
  var start = 0;
  while (true) {
    final index = lowerText.indexOf(lowerNeedle, start);
    if (index < 0) {
      if (start < text.length) {
        spans.add(TextSpan(text: text.substring(start), style: baseStyle));
      }
      break;
    }
    if (index > start) {
      spans.add(TextSpan(text: text.substring(start, index), style: baseStyle));
    }
    spans.add(
      TextSpan(
        text: text.substring(index, index + needle.length),
        style: highlightStyle,
      ),
    );
    start = index + needle.length;
  }
  return spans;
}

class SearchTextResultRow extends StatelessWidget {
  const SearchTextResultRow({
    super.key,
    required this.hit,
    required this.agentName,
    required this.onTap,
    this.agentAvatarUrl,
    this.userAvatarUrl,
    this.highlightQuery,
  });

  final MessageSearchHit hit;
  final String agentName;
  final VoidCallback onTap;
  final String? agentAvatarUrl;
  final String? userAvatarUrl;

  /// The current search text — matched occurrences render in the app's
  /// accent blue. Null/empty (quick-filter browsing with no typed query)
  /// renders the content as plain text.
  final String? highlightQuery;

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(color: AppColors.text, fontSize: 14, height: 1.4);
    final highlightStyle = baseStyle.copyWith(
      color: AppColors.accent,
      fontWeight: FontWeight.w700,
    );
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SearchResultHeader(
            isMine: hit.message.isMine,
            createdAt: hit.message.createdAt,
            agentName: agentName,
            agentAvatarUrl: agentAvatarUrl,
            userAvatarUrl: userAvatarUrl,
          ),
          Text.rich(
            TextSpan(
              children: highlightedSpans(
                text: hit.message.content,
                query: highlightQuery ?? '',
                baseStyle: baseStyle,
                highlightStyle: highlightStyle,
              ),
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
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
    this.agentAvatarUrl,
    this.userAvatarUrl,
  });

  final MessageSearchHit hit;
  final String agentName;
  final VoidCallback onTap;
  final String? authToken;
  final String? apiBaseUrl;
  final String? agentAvatarUrl;
  final String? userAvatarUrl;

  @override
  Widget build(BuildContext context) {
    final card = hit.message.componentCard;
    if (card == null) return const SizedBox.shrink();
    final isMine = hit.message.isMine;
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SearchResultHeader(
            isMine: isMine,
            createdAt: hit.message.createdAt,
            agentName: agentName,
            agentAvatarUrl: agentAvatarUrl,
            userAvatarUrl: userAvatarUrl,
          ),
          // The card's own interactive bits (mini music player, favorite
          // button, ...) only make sense in a live chat — IgnorePointer
          // silences them so the outer CupertinoButton is the single "open"
          // target for the whole row (header included).
          IgnorePointer(
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
        ],
      ),
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
