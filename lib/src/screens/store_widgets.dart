part of 'package:companion_flutter/main.dart';

class _StoreTopBar extends StatelessWidget {
  const _StoreTopBar({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
      child: SizedBox(
        height: 46,
        child: Row(
          children: [
            _AppNavCircleButton(
              icon: CupertinoIcons.chevron_left,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Center(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 58),
              child: Align(
                alignment: Alignment.centerRight,
                widthFactor: 1,
                child:
                    trailing ??
                    Icon(
                      CupertinoIcons.doc_text,
                      color: AppColors.text,
                      size: 27,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreBalancePill extends StatelessWidget {
  const _StoreBalancePill({
    required this.amount,
    required this.currency,
    required this.onTap,
  });

  final int amount;
  final _StoreCurrency currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        height: 30,
        constraints: const BoxConstraints(minWidth: 44),
        padding: const EdgeInsets.only(left: 7, right: 5),
        decoration: BoxDecoration(
          color: w.glass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: w.glassBorder),
          boxShadow: [w.pillShadow],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CurrencyIcon(currency: currency, size: 18),
            const SizedBox(width: 5),
            Text(
              '$amount',
              style: TextStyle(
                color: w.ink,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              CupertinoIcons.add_circled_solid,
              size: 18,
              color: w.ink,
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreBottomBar extends StatelessWidget {
  const _StoreBottomBar({required this.selected, required this.onSelected});

  final _StoreSection selected;
  final ValueChanged<_StoreSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    final values = _StoreSection.values;
    final selectedIndex = values.indexOf(selected);
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: w.isDark ? const Color(0xFF121A26) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: w.panelShadow,
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: Alignment(
              -1 + (selectedIndex * 2 / (values.length - 1)),
              0,
            ),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: FractionallySizedBox(
              widthFactor: 1 / values.length,
              heightFactor: 1,
              child: Center(
                child: Container(
                  width: 58,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    color: w.isDark
                        ? const Color(0x24FFFFFF)
                        : Colors.white.withValues(alpha: 0.94),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x474E9BFF),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final item in values)
                Expanded(
                  child: _StoreNavItem(
                    item: item,
                    selected: item == selected,
                    onTap: () => onSelected(item),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StoreNavItem extends StatelessWidget {
  const _StoreNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _StoreSection item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    final inactive = w.inkSoft;
    return Tooltip(
      message: item.label,
      child: InkResponse(
        onTap: onTap,
        radius: 30,
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                size: 23,
                color: selected ? const Color(0xFF4B9AFF) : inactive,
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? w.ink : inactive,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StorePrimaryButton extends StatelessWidget {
  const _StorePrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        height: 50,
        decoration: _storeAccentButtonDecoration(),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration _storeAccentButtonDecoration({double radius = 20}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF4B9AFF), Color(0xFF8ABAFF)],
    ),
    boxShadow: const [
      BoxShadow(
        color: Color(0x474E9BFF),
        blurRadius: 16,
        offset: Offset(0, 8),
      ),
    ],
  );
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    required this.padding,
    this.radius = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: w.glass,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: w.glassBorder),
        boxShadow: w.panelShadow,
      ),
      child: child,
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon, this.size = _diameter});

  static const _diameter = 48.0;
  static const _fill = Color(0xFF4C9BFF);

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = _W2b.resolve(context).isDark;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _fill,
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: _fill.withValues(alpha: 0.30),
                  blurRadius: 9,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }
}

class _CurrencyIcon extends StatelessWidget {
  const _CurrencyIcon({required this.currency, required this.size});

  final _StoreCurrency currency;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: currency == _StoreCurrency.ticket
          ? const _TicketMiniPainter()
          : const _PointMiniPainter(),
    );
  }
}
