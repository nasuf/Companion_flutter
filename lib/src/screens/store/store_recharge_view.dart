part of 'package:companion_flutter/main.dart';

class _RechargeStoreView extends StatelessWidget {
  const _RechargeStoreView({
    required this.paymentsEnabled,
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
    this.priceLabelFor,
    this.submitting = false,
  });

  final bool paymentsEnabled;
  final _StoreCurrency currency;
  final num ticketBalance;
  final int pointBalance;
  final int selectedIndex;
  final List<_RechargePack> packs;
  final ValueChanged<_StoreCurrency> onCurrencyChanged;
  final ValueChanged<int> onSelectPack;
  final VoidCallback onSubmit;
  final VoidCallback? onConvertGamePoints;
  final double bottomSpace;

  /// 钞票档位的 StoreKit 本地化价格（缺失回退营销价）；积分档不用。
  final String? Function(_RechargePack pack)? priceLabelFor;

  /// 充值购买进行中：按钮转圈禁用，防重复下单。
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final balance = currency == _StoreCurrency.ticket
        ? ticketBalance
        : pointBalance;
    // 钞票黄 / 积分蓝：背景方块网格与余额徽标都跟随它。
    final accent = currency == _StoreCurrency.ticket
        ? const Color(0xFFFFC83D)
        : _kStoreBlue;
    // 一屏铺满、且按钮永远在底部导航栏之上：
    // - 用 Column 填满可视高度，余额区放进 Expanded 吸收多余空间（内容不足时它变大、
    //   显得更透气；内容偏多时它收缩到最小高度，余额 FittedBox 等比缩小）。
    // - 矮屏或系统字体调大，收缩到底也放不下时，由 FitOrScroll 整页滚动。
    // - 底部留白 = bottomSpace - 16，让按钮落在导航栏上方约 16px 处。
    return FitOrScroll(
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
            child: FitOrScrollFloor(
              minHeight: 96,
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
          ),
          // 两个入口都固定在套餐上方，位置在两个 tab 之间保持一致。
          if (currency == _StoreCurrency.ticket)
            _StoreActionRow(
              icon: CupertinoIcons.play_rectangle_fill,
              label: '看广告得免费钞票',
              enabled: false,
              onTap: () {},
            )
          else if (onConvertGamePoints != null)
            _StoreActionRow(
              icon: CupertinoIcons.gamecontroller_fill,
              label: '用游戏积分兑换积分',
              onTap: onConvertGamePoints!,
            ),
          const SizedBox(height: 14),
          FitOrScrollGrid(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.32,
            children: [
              for (var index = 0; index < packs.length; index += 1)
                _RechargePackCard(
                  pack: packs[index],
                  selected: selectedIndex == index,
                  priceLabel: priceLabelFor?.call(packs[index]),
                  onTap: () => onSelectPack(index),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _StorePrimaryButton(
            label: currency == _StoreCurrency.ticket ? '立即充值' : '立即兑换',
            onPressed: currency == _StoreCurrency.ticket && !paymentsEnabled
                ? null
                : onSubmit,
            loading: submitting,
            loadingLabel: submitting ? kIapCreditingLabel : null,
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
  final num balance;
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
          currency == _StoreCurrency.ticket
              ? formatTicketAmount(balance)
              : '$balance',
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
              width: 53,
              height: 53,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
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
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    final child = _GlassCard(
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
                color: enabled ? w.ink : w.inkSoft,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          if (enabled)
            Icon(CupertinoIcons.chevron_right, color: w.inkFaint, size: 16)
          else
            Text(
              '即将上线',
              style: TextStyle(
                color: w.inkFaint,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
        ],
      ),
    );
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: CupertinoButton(
        minimumSize: Size.zero,
        padding: EdgeInsets.zero,
        onPressed: enabled ? onTap : null,
        child: child,
      ),
    );
  }
}

class _RechargePackCard extends StatelessWidget {
  const _RechargePackCard({
    required this.pack,
    required this.selected,
    required this.onTap,
    this.priceLabel,
  });

  final _RechargePack pack;
  final bool selected;
  final VoidCallback onTap;

  /// StoreKit 本地化价格（钞票档位）；null 回退到营销价 `¥cost`。
  final String? priceLabel;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        // CupertinoButton 给的是宽松约束，这里显式撑满网格格子。
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
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
        // 卡片按宽高比定高；系统字体调大后整组等比缩小，不撑破卡片。
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CurrencyIcon(currency: pack.currency, size: 16),
                  const SizedBox(width: 4),
                  // 外层 FittedBox 宽度不设限，这里不能用 Flexible；过长时整组缩小。
                  Text(
                    '${pack.amount}',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: w.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                pack.currency == _StoreCurrency.ticket
                    ? (priceLabel ?? '¥${pack.cost}')
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
      ),
    );
  }
}
