part of 'package:companion_flutter/main.dart';

class _StoreTopBar extends StatelessWidget {
  const _StoreTopBar({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    // 用 Stack 让标题相对整条栏真正居中：左右两侧控件宽度不同（返回键 vs
    // 记录/余额），放在 Row 里居中会被挤偏。
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
      child: SizedBox(
        height: 46,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: Text(
                title,
                // Matches the check-in "打卡" title: 24 / w700, centred.
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 24,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: _StoreBackButton(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child:
                  trailing ??
                  Icon(
                    CupertinoIcons.doc_text,
                    color: AppColors.text,
                    size: 27,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreBackButton extends StatelessWidget {
  const _StoreBackButton();

  @override
  Widget build(BuildContext context) {
    // Same glass circle as weather; the chevron carries the store's blue theme.
    final w = _W2b.resolve(context);
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: () => Navigator.of(context).maybePop(),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: w.glass,
          shape: BoxShape.circle,
          border: Border.all(color: w.glassBorder),
          boxShadow: [w.pillShadow],
        ),
        child: const Icon(
          CupertinoIcons.chevron_left,
          color: _kStoreBlue,
          size: 20,
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
        // 固定宽度：钞票 / 积分两个药丸宽度一致，且默认容得下 6 位数不变形。
        width: 108,
        padding: const EdgeInsets.only(left: 7, right: 5),
        decoration: BoxDecoration(
          color: w.glass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: w.glassBorder),
          boxShadow: [w.pillShadow],
        ),
        child: Row(
          children: [
            _CurrencyIcon(currency: currency, size: 18),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '$amount',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: w.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            Icon(CupertinoIcons.add_circled_solid, size: 18, color: w.ink),
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
                        color: _kStoreBlue.withValues(alpha: 0.28),
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
                color: selected ? _kStoreBlue : inactive,
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
  const _StorePrimaryButton({
    required this.label,
    required this.onPressed,
    this.height = 50,
    this.loading = false,
  });

  final String label;

  /// null = 禁用（置灰不可点，如未勾选会员协议）。
  final VoidCallback? onPressed;
  final double height;

  /// 购买/校验进行中：显示转圈并禁用，防重复点击。
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final disabled = loading || onPressed == null;
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: disabled ? null : onPressed,
      child: Opacity(
        opacity: disabled ? 0.5 : 1,
        child: Container(
          height: height,
          decoration: _storeAccentButtonDecoration(),
          child: Center(
            child: loading
                ? const CupertinoActivityIndicator(color: Colors.white)
                : Text(
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
      ),
    );
  }
}

/// 会员/商城主蓝。玻璃改版一度把它调浅成 #4B9AFF，这里回到改版前的深蓝
/// （= AppColors.accent），图标 / 边框 / 角标 / 渐变深端都用它。
const Color _kStoreBlue = Color(0xFF0A84FF);

BoxDecoration _storeAccentButtonDecoration({double radius = 20}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    // 回到改版前的按钮渐变：青 → 深蓝，从左到右（LinearGradient 默认方向）。
    gradient: const LinearGradient(colors: [Color(0xFF55D7FF), _kStoreBlue]),
    boxShadow: [
      BoxShadow(
        color: _kStoreBlue.withValues(alpha: 0.32),
        blurRadius: 16,
        offset: const Offset(0, 8),
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
  static const _fill = _kStoreBlue;

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
    // 积分统一用金币素材（右上角药丸 / 兑换卡片 / 充值页都走这里）；钞票仍用画的。
    if (currency == _StoreCurrency.point) {
      return Image.asset(
        'assets/store/icons/point_coin.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
    }
    return CustomPaint(
      size: Size.square(size),
      painter: const _TicketMiniPainter(),
    );
  }
}
