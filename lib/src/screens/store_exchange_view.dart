part of 'package:companion_flutter/main.dart';

class _ExchangeStoreView extends StatelessWidget {
  const _ExchangeStoreView({
    required this.points,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.onRechargePoints,
    required this.onExchange,
    required this.isExchanging,
    required this.bottomSpace,
  });

  final int points;
  final _ExchangeCategory selectedCategory;
  final ValueChanged<_ExchangeCategory> onCategoryChanged;
  final VoidCallback onRechargePoints;
  final ValueChanged<_StoreProduct> onExchange;
  final bool Function(_StoreProduct product) isExchanging;
  final double bottomSpace;

  @override
  Widget build(BuildContext context) {
    final products = _exchangeProducts
        .where((item) => item.category == selectedCategory)
        .toList();
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _ExchangeCategoryHeaderDelegate(
            selected: selectedCategory,
            onSelected: onCategoryChanged,
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, bottomSpace),
          sliver: SliverGrid.builder(
            itemCount: products.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (context, index) {
              final product = products[index];
              return _ExchangeProductCard(
                product: product,
                affordable: product.price <= points,
                onTap: () => onExchange(product),
                onRechargePoints: onRechargePoints,
                busy: isExchanging(product),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ExchangeCategoryBar extends StatelessWidget {
  const _ExchangeCategoryBar({
    required this.selected,
    required this.onSelected,
  });

  final _ExchangeCategory selected;
  final ValueChanged<_ExchangeCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return _StoreSegmentedLabelBar<_ExchangeCategory>(
      values: _ExchangeCategory.values,
      selected: selected,
      labelFor: (category) => category.label,
      onSelected: onSelected,
    );
  }
}

class _StoreSegmentedLabelBar<T> extends StatelessWidget {
  const _StoreSegmentedLabelBar({
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelFor;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = math.max(0, values.indexOf(selected));
    final isDark = AppColors.isDark(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(23),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.subtleFill(context, light: 0.64),
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: AppColors.glassBorder(context)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth / values.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 230),
                    curve: Curves.easeOutCubic,
                    left: selectedIndex * width + 3,
                    top: 3,
                    bottom: 3,
                    width: width - 6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceMuted.withValues(alpha: 0.94)
                            : Colors.white.withValues(alpha: 0.98),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.16),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (final value in values)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onSelected(value),
                            child: Center(
                              child: Text(
                                labelFor(value),
                                style: TextStyle(
                                  color: value == selected
                                      ? AppColors.text
                                      : (isDark
                                            ? AppColors.muted
                                            : const Color(0xFF596979)),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ExchangeProductCard extends StatelessWidget {
  const _ExchangeProductCard({
    required this.product,
    required this.affordable,
    this.onTap,
    this.onRechargePoints,
    this.busy = false,
    this.compact = false,
    this.showPrice = true,
    this.quantity,
  });

  final _StoreProduct product;
  final bool affordable;
  final VoidCallback? onTap;
  final VoidCallback? onRechargePoints;
  final bool busy;
  final bool compact;
  final bool showPrice;
  final int? quantity;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final priceBackground = affordable
        ? (isDark
              ? Color.lerp(AppColors.surfaceMuted, AppColors.accent, 0.18)!
              : AppColors.text)
        : (isDark
              ? AppColors.surfaceMuted.withValues(alpha: 0.72)
              : const Color(0xFFEAF1F8));
    final priceBorder = isDark
        ? (affordable
              ? AppColors.accent.withValues(alpha: 0.38)
              : Colors.white.withValues(alpha: 0.10))
        : Colors.transparent;
    final priceTextColor = affordable
        ? (isDark ? AppColors.text : Colors.white)
        : (isDark
              ? AppColors.muted.withValues(alpha: 0.76)
              : const Color(0xFF7B8792));
    final iconHaloSize = compact ? 58.0 : 100.0;
    final iconSize = compact ? 42.0 : 76.0;
    return _GlassCard(
      padding: compact
          ? const EdgeInsets.fromLTRB(10, 12, 10, 10)
          : const EdgeInsets.fromLTRB(12, 14, 12, 12),
      radius: compact ? 16 : 18,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: iconHaloSize,
                  height: iconHaloSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.subtleFill(context, light: 0.82),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : AppColors.accent.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                _ExchangeProductIcon(product: product, size: iconSize),
                if (product.badge != null && !compact)
                  Positioned(
                    top: 4,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF8A8A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        product.badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: compact ? 8 : 10),
          Text(
            product.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.text,
              fontSize: compact ? 13 : 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
          SizedBox(height: compact ? 3 : 4),
          Text(
            compact && quantity != null ? 'x$quantity' : product.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? AppColors.muted : const Color(0xFF6A7784),
              fontSize: compact ? 12 : 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
          if (showPrice) ...[
            const SizedBox(height: 10),
            CupertinoButton(
              minimumSize: Size.zero,
              padding: EdgeInsets.zero,
              onPressed: busy ? null : (affordable ? onTap : onRechargePoints),
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: priceBackground,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: priceBorder),
                  boxShadow: [
                    if (affordable)
                      BoxShadow(
                        color: AppColors.accent.withValues(
                          alpha: isDark ? 0.18 : 0.10,
                        ),
                        blurRadius: 14,
                        offset: const Offset(0, 7),
                      ),
                  ],
                ),
                child: Center(
                  child: busy
                      ? CupertinoActivityIndicator(color: priceTextColor)
                      : product.price == 0
                      ? Text(
                          '免费',
                          style: TextStyle(
                            color: priceTextColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                            decoration: TextDecoration.none,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _CurrencyIcon(
                              currency: _StoreCurrency.point,
                              size: 16,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${product.price}',
                              style: TextStyle(
                                color: priceTextColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExchangeCategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _ExchangeCategoryHeaderDelegate({
    required this.selected,
    required this.onSelected,
  });

  final _ExchangeCategory selected;
  final ValueChanged<_ExchangeCategory> onSelected;

  @override
  double get minExtent => 64;

  @override
  double get maxExtent => 64;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final isDark = AppColors.isDark(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.lerp(
          AppColors.page,
          AppColors.accent,
          isDark ? 0.08 : 0.05,
        )!.withValues(alpha: isDark ? 0.94 : 0.86),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
        child: _ExchangeCategoryBar(selected: selected, onSelected: onSelected),
      ),
    );
  }

  @override
  bool shouldRebuild(_ExchangeCategoryHeaderDelegate oldDelegate) {
    return selected != oldDelegate.selected ||
        onSelected != oldDelegate.onSelected;
  }
}

class _ExchangeProductIcon extends StatelessWidget {
  const _ExchangeProductIcon({required this.product, this.size = 76});

  final _StoreProduct product;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = product.imageAsset;
    if (asset == null) {
      return _ExchangeProductIconFallback(product: product);
    }
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) =>
            _ExchangeProductIconFallback(product: product, size: size),
      ),
    );
  }
}

class _ExchangeProductIconFallback extends StatelessWidget {
  const _ExchangeProductIconFallback({required this.product, this.size = 70});

  final _StoreProduct product;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _StoreItemIconPainter(
        kind: product.kind,
        accent: AppColors.accent,
      ),
    );
  }
}
