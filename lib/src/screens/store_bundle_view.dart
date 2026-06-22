part of 'package:companion_flutter/main.dart';

enum _BundleBillingCycle {
  monthly('月付', '/月'),
  yearly('年付', '/年');

  const _BundleBillingCycle(this.label, this.suffix);

  final String label;
  final String suffix;
}

class _BundleStoreView extends StatefulWidget {
  const _BundleStoreView({required this.onBuy, required this.bottomSpace});

  final void Function(_StoreProduct product, _BundleBillingCycle cycle) onBuy;
  final double bottomSpace;

  @override
  State<_BundleStoreView> createState() => _BundleStoreViewState();
}

class _BundleStoreViewState extends State<_BundleStoreView> {
  late final List<_BundleBillingCycle> _selectedCycles;

  @override
  void initState() {
    super.initState();
    _selectedCycles = List.filled(
      _bundleProducts.length,
      _BundleBillingCycle.yearly,
    );
  }

  void _selectCycle(int index, _BundleBillingCycle cycle) {
    setState(() {
      _selectedCycles[index] = cycle;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(18, 18, 18, widget.bottomSpace),
      itemCount: _bundleProducts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final product = _bundleProducts[index];
        final cycle = _selectedCycles[index];
        return _BundleCard(
          product: product,
          selectedCycle: cycle,
          onCycleChanged: (value) => _selectCycle(index, value),
          onBuy: () => widget.onBuy(product, cycle),
        );
      },
    );
  }
}

class _BundleCard extends StatelessWidget {
  const _BundleCard({
    required this.product,
    required this.selectedCycle,
    required this.onCycleChanged,
    required this.onBuy,
  });

  final _StoreProduct product;
  final _BundleBillingCycle selectedCycle;
  final ValueChanged<_BundleBillingCycle> onCycleChanged;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final accent = _bundleAccent(product.kind);
    final yearly = product.yearlyPrice ?? product.price;
    final selectedPrice = selectedCycle == _BundleBillingCycle.monthly
        ? product.price
        : yearly;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: _GlassCard(
        padding: EdgeInsets.zero,
        radius: 28,
        child: Stack(
          children: [
            Positioned(
              right: -42,
              top: -54,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.10),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 20,
              bottom: 20,
              child: _BundleAccentRail(color: accent),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                children: [
                  _BundleIconMedallion(product: product, accent: accent),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                product.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.text,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _BundleValueTag(
                              label: selectedCycle.label,
                              color: accent,
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          product.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.isDark(context)
                                ? AppColors.muted
                                : const Color(0xFF61707C),
                            fontSize: 12,
                            height: 1.34,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 13),
                        Row(
                          children: [
                            Expanded(
                              child: _BundleCycleButton(
                                label: '月',
                                price: product.price,
                                suffix: _BundleBillingCycle.monthly.suffix,
                                selected:
                                    selectedCycle ==
                                    _BundleBillingCycle.monthly,
                                color: accent,
                                onTap: () =>
                                    onCycleChanged(_BundleBillingCycle.monthly),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _BundleCycleButton(
                                label: '年',
                                price: yearly,
                                suffix: _BundleBillingCycle.yearly.suffix,
                                selected:
                                    selectedCycle == _BundleBillingCycle.yearly,
                                color: accent,
                                onTap: () =>
                                    onCycleChanged(_BundleBillingCycle.yearly),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _BundleBuyButton(
                    price: selectedPrice,
                    suffix: selectedCycle.suffix,
                    onPressed: onBuy,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BundleIconMedallion extends StatelessWidget {
  const _BundleIconMedallion({required this.product, required this.accent});

  final _StoreProduct product;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return SizedBox(
      width: 104,
      height: 104,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  isDark
                      ? AppColors.surfaceMuted.withValues(alpha: 0.88)
                      : Colors.white.withValues(alpha: 0.98),
                  accent.withValues(alpha: isDark ? 0.14 : 0.06),
                ],
              ),
              border: Border.all(color: accent.withValues(alpha: 0.18)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.13),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
          ),
          Container(
            width: 88,
            height: 88,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  isDark
                      ? AppColors.surface.withValues(alpha: 0.88)
                      : Colors.white.withValues(alpha: 0.98),
                  accent.withValues(alpha: isDark ? 0.16 : 0.08),
                ],
              ),
            ),
            child: _BundleIconPlate(product: product, accent: accent),
          ),
          Positioned(
            right: 6,
            top: 11,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.elevatedSurface(context, light: 0.92),
                border: Border.all(color: accent.withValues(alpha: 0.22)),
              ),
              child: Icon(
                product.kind == _StoreItemKind.musicBundle
                    ? CupertinoIcons.music_note_2
                    : product.kind == _StoreItemKind.gameBundle
                    ? CupertinoIcons.game_controller_solid
                    : CupertinoIcons.film_fill,
                size: 10,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BundleCycleButton extends StatelessWidget {
  const _BundleCycleButton({
    required this.label,
    required this.price,
    required this.suffix,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final int price;
  final String suffix;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.16)
              : AppColors.subtleFill(context, light: 0.70),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.50)
                : AppColors.glassBorder(context),
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? color
                        : (isDark ? AppColors.muted : const Color(0xFF6B7580)),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  '¥$price$suffix',
                  style: TextStyle(
                    color: selected
                        ? color
                        : (isDark ? AppColors.text : const Color(0xFF4B5660)),
                    fontSize: 12,
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
    );
  }
}

class _BundleBuyButton extends StatelessWidget {
  const _BundleBuyButton({
    required this.price,
    required this.suffix,
    required this.onPressed,
  });

  final int price;
  final String suffix;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0D141B),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.text.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '购买',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '¥$price$suffix',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.66),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BundleValueTag extends StatelessWidget {
  const _BundleValueTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _BundleAccentRail extends StatelessWidget {
  const _BundleAccentRail({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          Positioned(
            left: 0,
            top: 8,
            bottom: 8,
            child: Container(
              width: 2.5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.08),
                    color.withValues(alpha: 0.62),
                    color.withValues(alpha: 0.08),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 2,
            top: 0,
            bottom: 0,
            child: Container(
              width: 12,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(18),
                ),
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.10),
                    color.withValues(alpha: 0.00),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 2,
            top: 34,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.92),
                border: Border.all(color: color.withValues(alpha: 0.34)),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BundleIconPlate extends StatelessWidget {
  const _BundleIconPlate({required this.product, required this.accent});

  final _StoreProduct product;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final imageAsset = product.imageAsset;
    final isDark = AppColors.isDark(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark
                ? AppColors.surfaceMuted.withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.96),
            Color.lerp(
              accent,
              isDark ? AppColors.surfaceMuted : Colors.white,
              0.72,
            )!.withValues(alpha: isDark ? 0.62 : 0.58),
          ],
        ),
        border: Border.all(color: AppColors.glassBorder(context)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
          if (!isDark)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.72),
              blurRadius: 8,
              offset: const Offset(-3, -3),
            ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: -8,
            top: -8,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.34),
              ),
            ),
          ),
          if (imageAsset == null)
            _BundleIconFallback(product: product, accent: accent)
          else
            SizedBox(
              width: 58,
              height: 58,
              child: Image.asset(
                imageAsset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) =>
                    _BundleIconFallback(product: product, accent: accent),
              ),
            ),
        ],
      ),
    );
  }
}

class _BundleIconFallback extends StatelessWidget {
  const _BundleIconFallback({required this.product, required this.accent});

  final _StoreProduct product;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(58, 58),
      painter: _StoreItemIconPainter(
        kind: product.kind,
        accent: Color.lerp(accent, const Color(0xFF26384A), 0.10)!,
      ),
    );
  }
}

Color _bundleAccent(_StoreItemKind kind) {
  return switch (kind) {
    _StoreItemKind.musicBundle => const Color(0xFF20B5FF),
    _StoreItemKind.gameBundle => const Color(0xFF6E83FF),
    _StoreItemKind.movieBundle => const Color(0xFFFF6CA8),
    _ => AppColors.accent,
  };
}
