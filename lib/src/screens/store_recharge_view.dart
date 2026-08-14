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
    this.onConvertGamePoints,
  });

  final _StoreCurrency currency;
  final int ticketBalance;
  final int pointBalance;
  final int selectedIndex;
  final List<_RechargePack> packs;
  final ValueChanged<_StoreCurrency> onCurrencyChanged;
  final ValueChanged<int> onSelectPack;
  final VoidCallback onSubmit;
  final VoidCallback? onConvertGamePoints;
  final double bottomSpace;

  @override
  Widget build(BuildContext context) {
    final balance = currency == _StoreCurrency.ticket
        ? ticketBalance
        : pointBalance;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottomSpace),
      children: [
        _StoreSegmentedLabelBar<_StoreCurrency>(
          values: const [_StoreCurrency.ticket, _StoreCurrency.point],
          selected: currency,
          labelFor: (value) =>
              value == _StoreCurrency.ticket ? '我的钞票' : '我的积分',
          onSelected: onCurrencyChanged,
        ),
        const SizedBox(height: 14),
        _RechargeBalanceCard(currency: currency, balance: balance),
        if (currency == _StoreCurrency.ticket) ...[
          const SizedBox(height: 10),
          _StoreActionRow(
            icon: CupertinoIcons.play_rectangle_fill,
            label: '看广告得免费钞票',
            onTap: () {},
          ),
        ],
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: packs.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.12,
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
        const SizedBox(height: 22),
        _StorePrimaryButton(
          label: currency == _StoreCurrency.ticket ? '立即充值' : '立即兑换',
          onPressed: onSubmit,
        ),
        if (currency == _StoreCurrency.point && onConvertGamePoints != null) ...[
          const SizedBox(height: 10),
          _StoreActionRow(
            icon: CupertinoIcons.gamecontroller_fill,
            label: '用游戏积分兑换积分',
            onTap: onConvertGamePoints!,
          ),
        ],
      ],
    );
  }
}

class _RechargeBalanceCard extends StatelessWidget {
  const _RechargeBalanceCard({required this.currency, required this.balance});

  final _StoreCurrency currency;
  final int balance;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    final accent = currency == _StoreCurrency.ticket
        ? const Color(0xFFFFC83D)
        : AppColors.accent;
    final label = currency == _StoreCurrency.ticket ? '钞票余额' : '积分余额';
    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      radius: 22,
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: w.isDark ? 0.16 : 0.12),
            ),
            child: SizedBox(
              width: 42,
              height: 42,
              child: CustomPaint(
                painter: currency == _StoreCurrency.ticket
                    ? _TicketStackPainter(
                        labelColor: w.isDark ? w.ink : null,
                        glowColor: accent,
                      )
                    : _PointCrystalPainter(
                        sizeScale: 1.05,
                        labelColor: w.isDark ? w.ink : null,
                        glowColor: accent,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: w.inkSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$balance',
                  style: TextStyle(
                    color: w.ink,
                    fontSize: 32,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '明细清单 ›',
                  style: TextStyle(
                    color: w.inkFaint,
                    fontSize: 12,
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
    );
  }
}

class _StoreActionRow extends StatelessWidget {
  const _StoreActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: _GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        radius: 18,
        child: Row(
          children: [
            _CircleIcon(icon: icon, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: w.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            Icon(CupertinoIcons.chevron_right, color: w.inkFaint, size: 16),
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
    final w = _W2b.resolve(context);
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
                _CurrencyIcon(currency: pack.currency, size: 16),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${pack.amount}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: w.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              pack.currency == _StoreCurrency.ticket
                  ? '¥${pack.cost}'
                  : '${pack.cost} 钞票',
              style: TextStyle(
                color: selected ? const Color(0xFF4B9AFF) : w.inkSoft,
                fontSize: 12,
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
