part of 'package:companion_flutter/main.dart';

Future<void> _showGiftSheet({
  required BuildContext context,
  required CompanionApi api,
  required ChatComponentCard card,
}) {
  return GiftSheetPage.push(context, api: api, card: card);
}

/// Full-screen status page for a sent / received backpack gift.
class GiftSheetPage extends StatefulWidget {
  const GiftSheetPage({
    super.key,
    required this.api,
    required this.card,
  });

  final CompanionApi api;
  final ChatComponentCard card;

  static Future<void> push(
    BuildContext context, {
    required CompanionApi api,
    required ChatComponentCard card,
  }) {
    return Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => GiftSheetPage(api: api, card: card),
      ),
    );
  }

  @override
  State<GiftSheetPage> createState() => _GiftSheetPageState();
}

class _GiftSheetPageState extends State<GiftSheetPage> {
  late ChatComponentCard _card;
  bool _loading = true;

  String get _offeringId =>
      _card.payload['offering_id']?.toString().trim() ?? '';

  bool get _received => _card.payload['status']?.toString() == 'received';

  String get _title {
    final fromCard = _card.title.trim();
    if (fromCard.isNotEmpty) return fromCard;
    return _card.payload['product_title']?.toString() ?? '礼物';
  }

  String get _subtitle {
    final fromCard = _card.body.trim();
    if (fromCard.isNotEmpty) return fromCard;
    return _card.payload['product_subcategory']?.toString() ?? '心意';
  }

  @override
  void initState() {
    super.initState();
    _card = widget.card;
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final offeringId = _offeringId;
    if (offeringId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final result = await widget.api.getGift(offeringId);
      if (!mounted) return;
      setState(() {
        _card = result.componentCard;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    final isDark = w.isDark;
    final glass = isDark ? const Color(0x33FFFFFF) : const Color(0xB3FFFFFF);
    final glassBorder = isDark
        ? const Color(0x3DFFFFFF)
        : const Color(0x66FFFFFF);
    final ink = isDark ? const Color(0xFFFFF6EE) : const Color(0xFF4A2A1A);
    final inkSoft = isDark
        ? const Color(0xB3FFD8C2)
        : const Color(0xFF8A6754);
    const accent = _giftAccent;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF1A120E)
          : const Color(0xFFFFF7F1),
      body: Stack(
        children: [
          Positioned(
            right: -48,
            top: -36,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: isDark ? 0.18 : 0.10),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                  child: SizedBox(
                    height: 44,
                    child: Stack(
                      children: [
                        const Positioned.fill(
                          child: Center(
                            child: Text(
                              '礼物',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: _GiftSheetCloseButton(
                              onTap: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      24 + MediaQuery.paddingOf(context).bottom,
                    ),
                    child: Column(
                      children: [
                        _GiftCardThumb(card: _card, size: 88),
                        const SizedBox(height: 18),
                        Text(
                          _received ? '已经收下了' : '还没收下',
                          style: TextStyle(
                            color: ink,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _received ? '这份礼物已被接收' : '发出去了，等对方收下',
                          style: TextStyle(
                            color: inkSoft,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          key: const Key('gift-sheet'),
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                          decoration: BoxDecoration(
                            color: glass,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: glassBorder),
                          ),
                          child: _loading
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 18),
                                  child: Center(
                                    child: CupertinoActivityIndicator(),
                                  ),
                                )
                              : Column(
                                  children: [
                                    Text(
                                      _title,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: ink,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        height: 1.15,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _subtitle,
                                      style: TextStyle(
                                        color: inkSoft,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: accent.withValues(
                                          alpha: _received ? 0.10 : 0.14,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        _received ? '已接收' : '待接收',
                                        style: TextStyle(
                                          color: _received
                                              ? inkSoft
                                              : accent,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GiftSheetCloseButton extends StatelessWidget {
  const _GiftSheetCloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: w.glass,
          shape: BoxShape.circle,
          border: Border.all(color: w.glassBorder),
          boxShadow: [w.pillShadow],
        ),
        alignment: Alignment.center,
        child: const Icon(
          CupertinoIcons.xmark,
          color: _giftAccent,
          size: 20,
        ),
      ),
    );
  }
}
