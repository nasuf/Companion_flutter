part of 'package:companion_flutter/main.dart';

class _OfflineActivityComponentCard extends StatelessWidget {
  const _OfflineActivityComponentCard({
    required this.card,
    required this.isMine,
    required this.onTap,
    this.authToken,
    this.apiBaseUrl,
  });

  final ChatComponentCard card;
  final bool isMine;
  final VoidCallback onTap;
  final String? authToken;
  final String? apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = AppColors.isDark(context);
    final imageUrl = _absoluteUrl(card.payload['image_url']?.toString());
    final status = card.payload['status_label']?.toString().trim();
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 292),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(isMine ? 20 : 5),
              topRight: Radius.circular(isMine ? 5 : 20),
              bottomLeft: const Radius.circular(20),
              bottomRight: const Radius.circular(20),
            ),
            border: Border.all(
              color: colors.accentCyan.withValues(alpha: 0.22),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.accentCyan.withValues(
                  alpha: isDark ? 0.20 : 0.12,
                ),
                blurRadius: 24,
                offset: const Offset(0, 12),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 110,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imageUrl != null)
                        Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          headers: authToken?.isNotEmpty == true
                              ? {'Authorization': 'Bearer $authToken'}
                              : null,
                          errorBuilder: (_, __, ___) =>
                              _activityImageFallback(),
                        )
                      else
                        _activityImageFallback(),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.10),
                              Colors.black.withValues(alpha: 0.28),
                            ],
                          ),
                        ),
                      ),
                      if (status != null && status.isNotEmpty)
                        Positioned(
                          left: 12,
                          top: 10,
                          child: _ActivityChatStatusPill(status: status),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          height: 1.18,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      if (card.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          card.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                      if (card.footer.isNotEmpty) ...[
                        const SizedBox(height: 11),
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.doc_text_search,
                              size: 16,
                              color: colors.accent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              card.footer,
                              style: TextStyle(
                                color: colors.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              CupertinoIcons.chevron_right,
                              size: 15,
                              color: colors.accent,
                            ),
                          ],
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

  Widget _activityImageFallback() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE4F8FF), Color(0xFFFFF2DB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          CupertinoIcons.location_solid,
          size: 30,
          color: Color(0xFF61BCD5),
        ),
      ),
    );
  }

  String? _absoluteUrl(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final base = apiBaseUrl?.trim();
    if (base == null || base.isEmpty || !raw.startsWith('/')) return raw;
    return '${base.replaceFirst(RegExp(r'/$'), '')}$raw';
  }
}

class _ActivityChatStatusPill extends StatelessWidget {
  const _ActivityChatStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4DE).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFE7B259).withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          status,
          style: const TextStyle(
            color: Color(0xFFA66B1E),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            height: 1,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
