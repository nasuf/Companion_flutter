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
  const _StoreBalancePill({required this.points, required this.onTap});

  final int points;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            height: 30,
            constraints: const BoxConstraints(minWidth: 44),
            padding: const EdgeInsets.only(left: 7, right: 5),
            decoration: BoxDecoration(
              color: AppColors.subtleFill(context, light: 0.70),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder(context)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _CurrencyIcon(currency: _StoreCurrency.point, size: 18),
                const SizedBox(width: 5),
                Text(
                  '$points',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(CupertinoIcons.add_circled_solid, size: 18),
              ],
            ),
          ),
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
    final values = _StoreSection.values;
    final selectedIndex = values.indexOf(selected);
    final isDark = AppColors.isDark(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface(context, light: 0.68),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.glassBorder(context)),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withValues(alpha: isDark ? 0.72 : 0.12),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
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
                        color: isDark
                            ? AppColors.surfaceMuted.withValues(alpha: 0.92)
                            : Colors.white.withValues(alpha: 0.94),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            blurRadius: 16,
                            offset: const Offset(0, 7),
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
        ),
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
    final isDark = AppColors.isDark(context);
    final inactive = isDark
        ? AppColors.muted.withValues(alpha: 0.68)
        : const Color(0xFF1B2733).withValues(alpha: 0.42);
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
                color: selected ? AppColors.accent : inactive,
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? AppColors.text : inactive,
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
        height: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF55D7FF), Color(0xFF0A84FF)],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.24),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
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
    final isDark = AppColors.isDark(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface(context, light: 0.70),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: AppColors.glassBorder(context)),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withValues(alpha: isDark ? 0.62 : 0.10),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(color, Colors.white, 0.24)!, color],
        ),
      ),
      child: Icon(icon, color: Colors.white, size: 19),
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
