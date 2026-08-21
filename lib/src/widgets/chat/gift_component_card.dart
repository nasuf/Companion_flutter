part of 'package:companion_flutter/main.dart';

const _giftAccent = Color(0xFFFF8A3D);

class _GiftComponentCard extends StatelessWidget {
  const _GiftComponentCard({
    required this.card,
    required this.isMine,
    required this.onTap,
  });

  final ChatComponentCard card;
  final bool isMine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = _giftAccent;
    final colors = AppColors.of(context);
    final isDark = AppColors.isDark(context);
    final title = card.title.isEmpty
        ? (card.payload['product_title']?.toString() ?? '礼物')
        : card.title;
    final body = card.body.isEmpty
        ? (card.payload['product_subcategory']?.toString() ?? '心意')
        : card.body;
    final radius = BorderRadius.only(
      topLeft: Radius.circular(isMine ? 20 : 5),
      topRight: Radius.circular(isMine ? 5 : 20),
      bottomLeft: const Radius.circular(20),
      bottomRight: const Radius.circular(20),
    );
    final background = isDark
        ? const [Color(0xFF2A1C14), Color(0xFF181410)]
        : const [Color(0xFFFFF6EE), Color(0xFFFFFFFF)];

    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 292),
        child: DecoratedBox(
          key: const Key('gift-card'),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: background,
            ),
            borderRadius: radius,
            border: Border.all(
              color: accent.withValues(alpha: isDark ? 0.36 : 0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: isDark ? 0.22 : 0.14),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              children: [
                Positioned(
                  right: -30,
                  top: -38,
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: isDark ? 0.18 : 0.10),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 14, 15, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _GiftCardThumb(card: card, size: 38),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  ),
                                ),
                                Text(
                                  body,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFFD0B49A)
                                        : const Color(0xFF9D7A5E),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            card.footer.isEmpty ? '点击查看' : card.footer,
                            style: const TextStyle(
                              color: accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Icon(
                            CupertinoIcons.chevron_forward,
                            color: accent,
                            size: 15,
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
}

class _GiftCardThumb extends StatelessWidget {
  const _GiftCardThumb({required this.card, this.size = 38});

  final ChatComponentCard card;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = _giftImageAsset(card);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _giftAccent.withValues(alpha: 0.12),
      ),
      child: asset == null
          ? Icon(CupertinoIcons.gift_fill, color: _giftAccent, size: size * 0.52)
          : Padding(
              padding: const EdgeInsets.all(4),
              child: Image.asset(
                asset,
                width: size - 8,
                height: size - 8,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  CupertinoIcons.gift_fill,
                  color: _giftAccent,
                  size: size * 0.52,
                ),
              ),
            ),
    );
  }
}

String? _giftImageAsset(ChatComponentCard card) {
  final key = card.payload['product_asset_key']?.toString().trim() ?? '';
  if (key.isEmpty) return null;
  return '$_storeGiftPath/$key.png';
}
