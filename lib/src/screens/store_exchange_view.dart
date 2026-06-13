part of 'package:companion_flutter/main.dart';

class _ExchangeStoreView extends StatelessWidget {
  const _ExchangeStoreView({
    required this.points,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.onRechargePoints,
    required this.onExchange,
    required this.bottomSpace,
  });

  final int points;
  final _ExchangeCategory selectedCategory;
  final ValueChanged<_ExchangeCategory> onCategoryChanged;
  final VoidCallback onRechargePoints;
  final ValueChanged<_StoreProduct> onExchange;
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
    final selectedIndex = _ExchangeCategory.values.indexOf(selected);
    return ClipRRect(
      borderRadius: BorderRadius.circular(23),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.64),
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width =
                  constraints.maxWidth / _ExchangeCategory.values.length;
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
                        color: Colors.white.withValues(alpha: 0.98),
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
                      for (final category in _ExchangeCategory.values)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onSelected(category),
                            child: Center(
                              child: Text(
                                category.label,
                                style: TextStyle(
                                  color: category == selected
                                      ? AppColors.text
                                      : const Color(0xFF596979),
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
    required this.onTap,
    required this.onRechargePoints,
  });

  final _StoreProduct product;
  final bool affordable;
  final VoidCallback onTap;
  final VoidCallback onRechargePoints;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      radius: 18,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.82),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                _ExchangeProductIcon(product: product),
                if (product.badge != null)
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
          const SizedBox(height: 10),
          Text(
            product.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            product.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF6A7784),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 10),
          CupertinoButton(
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            onPressed: affordable ? onTap : onRechargePoints,
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: affordable ? AppColors.text : const Color(0xFFEAF1F8),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: product.price == 0
                    ? const Text(
                        '免费',
                        style: TextStyle(
                          color: Colors.white,
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
                              color: affordable
                                  ? Colors.white
                                  : const Color(0xFF7B8792),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7FF).withValues(alpha: 0.86),
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
  const _ExchangeProductIcon({required this.product});

  final _StoreProduct product;

  @override
  Widget build(BuildContext context) {
    final url = product.imageUrl;
    if (url == null) {
      return _ExchangeProductIconFallback(product: product);
    }
    return SizedBox(
      width: 76,
      height: 76,
      child: Image.network(
        url,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) =>
            _ExchangeProductIconFallback(product: product),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return _ExchangeProductIconFallback(product: product);
        },
      ),
    );
  }
}

class _ExchangeProductIconFallback extends StatelessWidget {
  const _ExchangeProductIconFallback({required this.product});

  final _StoreProduct product;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(70, 70),
      painter: _StoreItemIconPainter(
        kind: product.kind,
        accent: AppColors.accent,
      ),
    );
  }
}
