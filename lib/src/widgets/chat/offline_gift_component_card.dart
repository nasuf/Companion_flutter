part of 'package:companion_flutter/main.dart';

class _OfflineGiftComponentCard extends StatelessWidget {
  const _OfflineGiftComponentCard({
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
    final radius = BorderRadius.only(
      topLeft: Radius.circular(isMine ? 20 : 5),
      topRight: Radius.circular(isMine ? 5 : 20),
      bottomLeft: const Radius.circular(20),
      bottomRight: const Radius.circular(20),
    );

    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 292),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface : Colors.white,
            borderRadius: radius,
            border: Border.all(
              color: const Color(0xFFF4C98B).withValues(alpha: 0.42),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFFF0A44E,
                ).withValues(alpha: isDark ? 0.22 : 0.14),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 120,
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
                          errorBuilder: (_, __, ___) => _giftFallback(),
                        )
                      else
                        _giftFallback(),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.04),
                              Colors.black.withValues(alpha: 0.30),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        top: 10,
                        child: _GiftChatRibbon(status: status ?? '小心意'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              card.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.text,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                height: 1.18,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF4E1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              CupertinoIcons.gift_fill,
                              size: 17,
                              color: Color(0xFFF08A47),
                            ),
                          ),
                        ],
                      ),
                      if (card.body.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          card.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.cube_box,
                            size: 16,
                            color: const Color(0xFFF08A47),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            card.footer.isEmpty ? '查看礼物详情' : card.footer,
                            style: const TextStyle(
                              color: Color(0xFFF08A47),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              decoration: TextDecoration.none,
                            ),
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

  Widget _giftFallback() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFF7E8), Color(0xFFFFE1ED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          CupertinoIcons.gift_fill,
          size: 34,
          color: Color(0xFFF08A47),
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

class _GiftChatRibbon extends StatelessWidget {
  const _GiftChatRibbon({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1D9).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFE8AD55).withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          status,
          style: const TextStyle(
            color: Color(0xFFA36519),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            height: 1,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
