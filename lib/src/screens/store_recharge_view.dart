part of 'package:companion_flutter/main.dart';

class _RechargeStoreView extends StatelessWidget {
  const _RechargeStoreView({
    required this.currency,
    required this.ticketBalance,
    required this.pointBalance,
    required this.selectedIndex,
    required this.packs,
    required this.onCurrencyChanged,
    required this.onSelectPack,
    required this.onSubmit,
    required this.bottomSpace,
  });

  final _StoreCurrency currency;
  final int ticketBalance;
  final int pointBalance;
  final int selectedIndex;
  final List<_RechargePack> packs;
  final ValueChanged<_StoreCurrency> onCurrencyChanged;
  final ValueChanged<int> onSelectPack;
  final VoidCallback onSubmit;
  final double bottomSpace;

  @override
  Widget build(BuildContext context) {
    final balance = currency == _StoreCurrency.ticket
        ? ticketBalance
        : pointBalance;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomSpace),
      children: [
        _RechargeTabs(currency: currency, onChanged: onCurrencyChanged),
        const SizedBox(height: 16),
        _RechargeHero(
          currency: currency,
          balance: balance,
          onAdRewardTap: currency == _StoreCurrency.ticket ? () {} : null,
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: packs.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.28,
          ),
          itemBuilder: (context, index) {
            final pack = packs[index];
            return _RechargePackCard(
              pack: pack,
              selected: selectedIndex == index,
              onTap: () => onSelectPack(index),
            );
          },
        ),
        const SizedBox(height: 24),
        _StorePrimaryButton(
          label: currency == _StoreCurrency.ticket ? '立即充值' : '立即兑换',
          onPressed: onSubmit,
        ),
      ],
    );
  }
}

class _RechargeTabs extends StatelessWidget {
  const _RechargeTabs({required this.currency, required this.onChanged});

  final _StoreCurrency currency;
  final ValueChanged<_StoreCurrency> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RechargeTabLabel(
          label: '我的钞票',
          selected: currency == _StoreCurrency.ticket,
          onTap: () => onChanged(_StoreCurrency.ticket),
        ),
        const SizedBox(width: 36),
        _RechargeTabLabel(
          label: '我的积分',
          selected: currency == _StoreCurrency.point,
          onTap: () => onChanged(_StoreCurrency.point),
        ),
      ],
    );
  }
}

class _RechargeTabLabel extends StatelessWidget {
  const _RechargeTabLabel({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: selected ? 42 : 0,
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.text,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _RechargeHero extends StatelessWidget {
  const _RechargeHero({
    required this.currency,
    required this.balance,
    this.onAdRewardTap,
  });

  final _StoreCurrency currency;
  final int balance;
  final VoidCallback? onAdRewardTap;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final accent = currency == _StoreCurrency.ticket
        ? const Color(0xFFFFC83D)
        : AppColors.accent;
    final label = currency == _StoreCurrency.ticket ? '钞票余额' : '积分余额';
    final detailColor = isDark
        ? AppColors.muted.withValues(alpha: 0.86)
        : const Color(0xFF8B938F);
    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _RechargePatternPainter(color: accent)),
          ),
          Align(
            alignment: Alignment(0, onAdRewardTap == null ? 0.02 : -0.10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RechargeBalanceBadge(currency: currency, accent: accent),
                const SizedBox(height: 14),
                Text(
                  label,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.text.withValues(alpha: 0.82)
                        : AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$balance',
                  style: TextStyle(
                    color: isDark ? AppColors.text : Colors.black,
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.white.withValues(alpha: 0.36),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.white.withValues(alpha: 0.52),
                    ),
                  ),
                  child: Text(
                    '明细清单 ›',
                    style: TextStyle(
                      color: detailColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (onAdRewardTap != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _AdRewardRow(onTap: onAdRewardTap!),
            ),
        ],
      ),
    );
  }
}

class _RechargeBalanceBadge extends StatelessWidget {
  const _RechargeBalanceBadge({required this.currency, required this.accent});

  final _StoreCurrency currency;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Container(
      width: 128,
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            accent.withValues(alpha: isDark ? 0.18 : 0.13),
            accent.withValues(alpha: 0),
          ],
        ),
      ),
      child: SizedBox(
        width: 104,
        height: 82,
        child: CustomPaint(
          painter: currency == _StoreCurrency.ticket
              ? _TicketStackPainter(
                  labelColor: isDark ? AppColors.text : null,
                  glowColor: accent,
                )
              : _PointCrystalPainter(
                  sizeScale: 1.16,
                  labelColor: isDark ? AppColors.text : null,
                  glowColor: accent,
                ),
        ),
      ),
    );
  }
}

class _AdRewardRow extends StatelessWidget {
  const _AdRewardRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.elevatedSurface(context, light: 0.72),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.glassBorder(context)),
        ),
        child: Row(
          children: [
            _CircleIcon(
              icon: CupertinoIcons.play_rectangle_fill,
              color: AppColors.accent,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '看广告得免费钞票',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              color: isDark ? AppColors.muted : const Color(0xFF7E8891),
            ),
          ],
        ),
      ),
    );
  }
}

class _RechargePackCard extends StatelessWidget {
  const _RechargePackCard({
    required this.pack,
    required this.selected,
    required this.onTap,
  });

  final _RechargePack pack;
  final bool selected;
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.elevatedSurface(context, light: 0.96)
              : AppColors.subtleFill(context, light: 0.62),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.glassBorder(context),
            width: selected ? 2.3 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CurrencyIcon(currency: pack.currency, size: 20),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${pack.amount}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? AppColors.text : const Color(0xFF3A4350),
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (pack.currency == _StoreCurrency.point)
                  const _CurrencyIcon(
                    currency: _StoreCurrency.ticket,
                    size: 14,
                  ),
                Text(
                  pack.currency == _StoreCurrency.ticket
                      ? '¥${pack.cost}'
                      : '${pack.cost}',
                  style: TextStyle(
                    color: isDark ? AppColors.muted : const Color(0xFF7C858F),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
