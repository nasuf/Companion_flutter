part of 'package:companion_flutter/main.dart';

class _BundleStoreView extends StatefulWidget {
  const _BundleStoreView({
    required this.ticketBalance,
    required this.vipTrialAvailable,
    required this.onBuy,
    required this.isBuying,
    required this.onRechargeTickets,
    required this.bottomSpace,
  });

  final int ticketBalance;
  final bool vipTrialAvailable;
  final void Function(_BundleOffer offer, _BundleTier? tier) onBuy;
  final bool Function(_BundleOffer offer) isBuying;
  final VoidCallback onRechargeTickets;
  final double bottomSpace;

  @override
  State<_BundleStoreView> createState() => _BundleStoreViewState();
}

class _BundleStoreViewState extends State<_BundleStoreView> {
  late final List<int> _selectedTiers;

  @override
  void initState() {
    super.initState();
    _selectedTiers = [for (final _ in _bundleOffers) 0];
  }

  @override
  Widget build(BuildContext context) {
    final offers = [
      for (final offer in _bundleOffers)
        if (!offer.isVipTrial || widget.vipTrialAvailable) offer,
    ];
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(18, 12, 18, widget.bottomSpace),
      itemCount: offers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final offer = offers[index];
        final sourceIndex = _bundleOffers.indexOf(offer);
        final tierIndex = offer.tiers.isEmpty
            ? 0
            : _selectedTiers[sourceIndex].clamp(0, offer.tiers.length - 1);
        final tier = offer.tiers.isEmpty ? null : offer.tiers[tierIndex];
        return _BundleCard(
          offer: offer,
          selectedTier: tier,
          ticketBalance: widget.ticketBalance,
          onTierChanged: (value) {
            setState(() {
              _selectedTiers[sourceIndex] = offer.tiers.indexOf(value);
            });
          },
          onBuy: () => widget.onBuy(offer, tier),
          onRechargeTickets: widget.onRechargeTickets,
          busy: widget.isBuying(offer),
        );
      },
    );
  }
}

class _BundleCard extends StatelessWidget {
  const _BundleCard({
    required this.offer,
    required this.selectedTier,
    required this.ticketBalance,
    required this.onTierChanged,
    required this.onBuy,
    required this.onRechargeTickets,
    required this.busy,
  });

  final _BundleOffer offer;
  final _BundleTier? selectedTier;
  final int ticketBalance;
  final ValueChanged<_BundleTier> onTierChanged;
  final VoidCallback onBuy;
  final VoidCallback onRechargeTickets;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    final accent = offer.accent;
    final affordable =
        offer.isVipTrial ||
        (selectedTier != null && selectedTier!.ticketPrice <= ticketBalance);
    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _BundleThumb(offer: offer, accent: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.title,
                      style: TextStyle(
                        color: w.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      offer.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: w.inkSoft,
                        fontSize: 11,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (offer.tiers.isNotEmpty) ...[
            const SizedBox(height: 12),
            _BundleTierSelector(
              tiers: offer.tiers,
              selected: selectedTier,
              onSelected: onTierChanged,
            ),
          ],
          const SizedBox(height: 12),
          _BundleBuyButton(
            offer: offer,
            tier: selectedTier,
            affordable: affordable,
            busy: busy,
            onPressed: affordable ? onBuy : onRechargeTickets,
          ),
        ],
      ),
    );
  }
}

class _BundleThumb extends StatelessWidget {
  const _BundleThumb({required this.offer, required this.accent});

  final _BundleOffer offer;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return Container(
      width: 58,
      height: 58,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: w.isDark
            ? accent.withValues(alpha: 0.16)
            : const Color(0xFFF4F7FC),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: offer.imageAsset == null
            ? Icon(CupertinoIcons.sparkles, color: accent, size: 26)
            : Image.asset(
                offer.imageAsset!,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) =>
                    Icon(CupertinoIcons.gift_fill, color: accent, size: 24),
              ),
      ),
    );
  }
}

class _BundleTierSelector extends StatelessWidget {
  const _BundleTierSelector({
    required this.tiers,
    required this.selected,
    required this.onSelected,
  });

  final List<_BundleTier> tiers;
  final _BundleTier? selected;
  final ValueChanged<_BundleTier> onSelected;

  @override
  Widget build(BuildContext context) {
    return _StoreSegmentedLabelBar<_BundleTier>(
      values: tiers,
      selected: selected ?? tiers.first,
      labelFor: (tier) => tier.label,
      onSelected: onSelected,
      height: 36,
      fontSize: 13,
    );
  }
}

class _BundleBuyButton extends StatelessWidget {
  const _BundleBuyButton({
    required this.offer,
    required this.tier,
    required this.affordable,
    required this.busy,
    required this.onPressed,
  });

  final _BundleOffer offer;
  final _BundleTier? tier;
  final bool affordable;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    final label = offer.isVipTrial ? '¥${offer.yuanPrice} 立即体验' : '购买';
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: busy ? null : onPressed,
      child: Container(
        height: 44,
        decoration: affordable
            ? _storeAccentButtonDecoration(radius: 16)
            : BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: w.isDark
                    ? const Color(0x14FFFFFF)
                    : const Color(0xFFEAF1F8),
              ),
        child: Center(
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CupertinoActivityIndicator(color: Colors.white),
                )
              : offer.isVipTrial
              ? Text(
                  affordable ? label : '去充值',
                  style: TextStyle(
                    color: affordable ? Colors.white : w.inkFaint,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      affordable ? '购买' : '去充值',
                      style: TextStyle(
                        color: affordable ? Colors.white : w.inkFaint,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    if (affordable && tier != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 1,
                        height: 12,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                      const SizedBox(width: 8),
                      const _CurrencyIcon(
                        currency: _StoreCurrency.ticket,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${tier!.ticketPrice}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
