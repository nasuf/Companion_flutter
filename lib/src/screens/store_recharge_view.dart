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
    // 钞票黄 / 积分蓝：背景方块网格与余额徽标都跟随它。
    final accent = currency == _StoreCurrency.ticket
        ? const Color(0xFFFFC83D)
        : _kStoreBlue;
    // 不滚动、一屏铺满、且按钮永远在底部导航栏之上：
    // - 用 Column 填满可视高度，余额区放进 Expanded 吸收多余空间（内容不足时它变大、
    //   显得更透气；内容偏多时它收缩，绝不把别的组件挤出屏幕）。
    // - 余额再套 FittedBox(scaleDown)，极端窄屏也只会等比缩小、不会溢出重叠。
    // - 底部留白 = bottomSpace - 16，让按钮落在导航栏上方约 16px 处。
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 6, 20, bottomSpace - 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StoreSegmentedLabelBar<_StoreCurrency>(
            values: const [_StoreCurrency.ticket, _StoreCurrency.point],
            selected: currency,
            labelFor: (value) =>
                value == _StoreCurrency.ticket ? '我的钞票' : '我的积分',
            onSelected: onCurrencyChanged,
          ),
          Expanded(
            child: Stack(
              children: [
                // 方块网格只铺在余额区（跟随该区域高度）。
                Positioned.fill(
                  child: CustomPaint(
                    painter: _RechargePatternPainter(color: accent),
                  ),
                ),
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _RechargeBalance(
                      currency: currency,
                      balance: balance,
                      accent: accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 两个入口都固定在套餐上方，位置在两个 tab 之间保持一致。
          if (currency == _StoreCurrency.ticket)
            _StoreActionRow(
              icon: CupertinoIcons.play_rectangle_fill,
              label: '看广告得免费钞票',
              onTap: () {},
            )
          else if (onConvertGamePoints != null)
            _StoreActionRow(
              icon: CupertinoIcons.gamecontroller_fill,
              label: '用游戏积分兑换积分',
              onTap: onConvertGamePoints!,
            ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: packs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.32,
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
          const SizedBox(height: 18),
          _StorePrimaryButton(
            label: currency == _StoreCurrency.ticket ? '立即充值' : '立即兑换',
            onPressed: onSubmit,
          ),
        ],
      ),
    );
  }
}

/// 居中的余额区：大徽标 + 「余额」标题 + 加粗数字 + 明细清单药丸。不用卡片。
class _RechargeBalance extends StatelessWidget {
  const _RechargeBalance({
    required this.currency,
    required this.balance,
    required this.accent,
  });

  final _StoreCurrency currency;
  final int balance;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    final label = currency == _StoreCurrency.ticket ? '钞票余额' : '积分余额';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RechargeBalanceBadge(currency: currency, accent: accent),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            color: w.isDark ? w.ink : const Color(0xFF16181C),
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
            color: w.isDark ? w.ink : Colors.black,
            fontSize: 46,
            height: 1.02,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
            decoration: TextDecoration.none,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// 余额上方的大徽标：柔光圆底 + 大图标（钞票堆叠 / 积分金币）。
class _RechargeBalanceBadge extends StatelessWidget {
  const _RechargeBalanceBadge({required this.currency, required this.accent});

  final _StoreCurrency currency;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return Container(
      width: 112,
      height: 84,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            accent.withValues(alpha: w.isDark ? 0.18 : 0.13),
            accent.withValues(alpha: 0),
          ],
        ),
      ),
      child: currency == _StoreCurrency.ticket
          ? SizedBox(
              width: 92,
              height: 72,
              child: CustomPaint(
                painter: _TicketStackPainter(
                  labelColor: w.isDark ? w.ink : null,
                  glowColor: accent,
                ),
              ),
            )
          : Image.asset(
              'assets/store/icons/point_coin.png',
              width: 66,
              height: 66,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
    );
  }
}

/// 改版前的方块网格背景，按币种上色（钞票黄 / 积分蓝）。
class _RechargePatternPainter extends CustomPainter {
  const _RechargePatternPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.08);
    for (var y = 18.0; y < size.height; y += 44) {
      for (var x = 8.0; x < size.width; x += 44) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, 24, 30),
            const Radius.circular(8),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RechargePatternPainter oldDelegate) {
    return oldDelegate.color != color;
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
        // 与其它页一致的玻璃卡：中性玻璃底 + 玻璃描边 + 面板投影；选中改深蓝描边。
        decoration: BoxDecoration(
          color: w.glass,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? _kStoreBlue : w.glassBorder,
            width: selected ? 2.3 : 1,
          ),
          boxShadow: w.panelShadow,
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
                // 选中只改边框，金额/价格颜色保持不变。
                color: w.inkSoft,
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
