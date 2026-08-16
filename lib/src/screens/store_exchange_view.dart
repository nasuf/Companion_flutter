part of 'package:companion_flutter/main.dart';

const _exchangeTabs = [
  _ExchangeCategory.gift,
  _ExchangeCategory.blind,
  _ExchangeCategory.outfit,
];

const _storeListFade = 28.0;

class _ExchangeStoreView extends StatelessWidget {
  const _ExchangeStoreView({
    required this.points,
    required this.isVip,
    required this.selectedCategory,
    required this.selectedGiftSubcategory,
    required this.onCategoryChanged,
    required this.onGiftSubcategoryChanged,
    required this.onInsufficientPoints,
    required this.onExchange,
    required this.isExchanging,
    required this.bottomSpace,
  });

  final int points;
  final bool isVip;
  final _ExchangeCategory selectedCategory;
  final _GiftSubcategory selectedGiftSubcategory;
  final ValueChanged<_ExchangeCategory> onCategoryChanged;
  final ValueChanged<_GiftSubcategory> onGiftSubcategoryChanged;
  final VoidCallback onInsufficientPoints;
  final ValueChanged<_StoreProduct> onExchange;
  final bool Function(_StoreProduct product) isExchanging;
  final double bottomSpace;

  @override
  Widget build(BuildContext context) {
    final products = _exchangeProducts.where((item) {
      if (item.category != selectedCategory) return false;
      if (selectedCategory == _ExchangeCategory.gift) {
        return item.giftSubcategory == selectedGiftSubcategory;
      }
      return true;
    }).toList();
    return Column(
      children: [
        Padding(
          // top 与充值页的顶部 tab 对齐（同为 8），切换 tab 时第一级分段栏不上下跳。
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                _ExchangeCategoryBar(
                  selected: selectedCategory,
                  onSelected: onCategoryChanged,
                ),
                if (selectedCategory == _ExchangeCategory.gift) ...[
                  const SizedBox(height: 8),
                  _GiftSubcategoryScroller(
                    key: const ValueKey('gift-subs'),
                    selected: selectedGiftSubcategory,
                    onSelected: onGiftSubcategoryChanged,
                  ),
                ],
              ],
            ),
          ),
        ),
        Expanded(
          child: _StoreEdgeFade(
            top: _storeListFade,
            child: products.isEmpty
                ? SizedBox.expand(
                    child: Center(
                      child: Text(
                        '这个分类还没有商品',
                        style: TextStyle(
                          color: _W2b.resolve(context).inkSoft,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  )
                : GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      20,
                      8,
                      20,
                      bottomSpace,
                    ),
                    itemCount: products.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.70,
                        ),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final price = product.priceFor(isVip: isVip);
                      return _ExchangeProductCard(
                        product: product,
                        isVip: isVip,
                        affordable: price <= points,
                        onTap: () => onExchange(product),
                        onInsufficient: onInsufficientPoints,
                        busy: isExchanging(product),
                      );
                    },
                  ),
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
      values: _exchangeTabs,
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
    this.height = 46,
    this.fontSize = 16,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelFor;
  final ValueChanged<T> onSelected;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = math.max(0, values.indexOf(selected));
    final w = _W2b.resolve(context);
    final radius = height / 2;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: w.glass,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: w.glassBorder),
        boxShadow: [w.pillShadow],
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
                    color: w.isDark
                        ? const Color(0x24FFFFFF)
                        : Colors.white.withValues(alpha: 0.98),
                    borderRadius: BorderRadius.circular(radius - 3),
                    // 纯白药丸，只留一层中性淡影提升，不再叠蓝色发光。
                    boxShadow: [
                      BoxShadow(
                        color: w.isDark
                            ? const Color(0x33000000)
                            : const Color(0x14243040),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
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
                              color: value == selected ? w.ink : w.inkSoft,
                              fontSize: fontSize,
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
    );
  }
}

class _ExchangeProductCard extends StatelessWidget {
  const _ExchangeProductCard({
    required this.product,
    required this.affordable,
    this.isVip = false,
    this.onTap,
    this.onInsufficient,
    this.busy = false,
    this.compact = false,
    this.showPrice = true,
    this.quantity,
  });

  final _StoreProduct product;
  final bool affordable;
  final bool isVip;
  final VoidCallback? onTap;
  final VoidCallback? onInsufficient;
  final bool busy;
  final bool compact;
  final bool showPrice;
  final int? quantity;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    final price = product.priceFor(isVip: isVip);
    // 金额按钮始终保持「可兑换」的高亮样式且可点；积分不足在点击后弹去充值确认框。
    final priceBackground = w.isDark
        ? Color.lerp(const Color(0xFF1A2430), const Color(0xFF4B9AFF), 0.28)!
        : const Color(0xFF12283F);
    final priceBorder = w.isDark
        ? const Color(0xFF4B9AFF).withValues(alpha: 0.38)
        : Colors.transparent;
    final priceTextColor = w.isDark ? w.ink : Colors.white;
    final iconHaloSize = compact ? 58.0 : 88.0;
    final iconPad = compact ? 8.0 : 12.0;
    return _GlassCard(
      padding: compact
          ? const EdgeInsets.fromLTRB(10, 12, 10, 10)
          : const EdgeInsets.fromLTRB(12, 14, 12, 12),
      radius: compact ? 16 : 22,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: iconHaloSize,
                  height: iconHaloSize,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: w.isDark
                        ? const Color(0x14FFFFFF)
                        : const Color(0xFFF4F7FC),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(iconPad),
                    child: _ExchangeProductIcon(
                      product: product,
                      size: iconHaloSize - iconPad * 2,
                    ),
                  ),
                ),
                if (!compact &&
                    product.giftSubcategory == _GiftSubcategory.luxury)
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
                      child: const Text(
                        '奢享',
                        style: TextStyle(
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
          SizedBox(height: compact ? 8 : 8),
          Text(
            product.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: w.ink,
              fontSize: compact ? 13 : 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
          SizedBox(height: compact ? 3 : 4),
          if (compact && quantity != null)
            Text(
              'x$quantity',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: w.inkSoft,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            )
          else if (showPrice)
            _ExchangePriceCaption(product: product, isVip: isVip)
          else
            Text(
              product.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: w.inkSoft,
                fontSize: 11,
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
              onPressed: busy ? null : (affordable ? onTap : onInsufficient),
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: priceBackground,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: priceBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x334B9AFF),
                      blurRadius: 14,
                      offset: Offset(0, 7),
                    ),
                  ],
                ),
                child: Center(
                  child: busy
                      ? CupertinoActivityIndicator(color: priceTextColor)
                      : price == 0
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
                              '$price',
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

class _ExchangePriceCaption extends StatelessWidget {
  const _ExchangePriceCaption({required this.product, required this.isVip});

  final _StoreProduct product;
  final bool isVip;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    if (product.memberPrice == product.listPrice) {
      return Text(
        product.subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: w.inkSoft,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          decoration: TextDecoration.none,
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isVip ? '会员' : '会员价',
          style: TextStyle(
            color: const Color(0xFF4B9AFF),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          '${product.memberPrice}',
          style: TextStyle(
            color: isVip ? w.ink : const Color(0xFF4B9AFF),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${product.listPrice}',
          style: TextStyle(
            color: w.inkFaint,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
            decoration: TextDecoration.lineThrough,
            decorationColor: w.inkFaint,
          ),
        ),
      ],
    );
  }
}

class _StoreEdgeFade extends StatelessWidget {
  const _StoreEdgeFade({required this.child, required this.top});

  final Widget child;
  final double top;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        final height = math.max(rect.height, 1.0);
        final t = (top / height).clamp(0.0, 0.45);
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0x00000000),
            Color(0x59000000),
            Color(0xFF000000),
            Color(0xFF000000),
          ],
          stops: [0, t * 0.45, t, 1],
        ).createShader(rect);
      },
      child: child,
    );
  }
}

class _GiftSubcategoryScroller extends StatefulWidget {
  const _GiftSubcategoryScroller({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final _GiftSubcategory selected;
  final ValueChanged<_GiftSubcategory> onSelected;

  @override
  State<_GiftSubcategoryScroller> createState() =>
      _GiftSubcategoryScrollerState();
}

class _GiftSubcategoryScrollerState extends State<_GiftSubcategoryScroller> {
  final _controller = ScrollController();
  late final List<GlobalKey> _itemKeys;

  @override
  void initState() {
    super.initState();
    _itemKeys = [
      for (var i = 0; i < _GiftSubcategory.values.length; i++) GlobalKey(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScroll(peekNeighbors: true);
    });
  }

  @override
  void didUpdateWidget(covariant _GiftSubcategoryScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncScroll(peekNeighbors: true);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncScroll({required bool peekNeighbors}) {
    if (!mounted || !_controller.hasClients) return;
    final position = _controller.position;
    if (!position.hasViewportDimension) return;

    final listBox = context.findRenderObject() as RenderBox?;
    if (listBox == null) return;

    final viewport = position.viewportDimension;
    final n = _GiftSubcategory.values.length;
    final starts = List<double?>.filled(n, null);
    final widths = List<double?>.filled(n, null);
    for (var i = 0; i < n; i++) {
      final box = _itemKeys[i].currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final dx = box.localToGlobal(Offset.zero, ancestor: listBox).dx;
      starts[i] = position.pixels + dx;
      widths[i] = box.size.width;
    }

    bool mostlyVisible(int i) {
      final start = starts[i];
      final width = widths[i];
      if (start == null || width == null || width <= 0) return false;
      final localStart = start - position.pixels;
      final localEnd = localStart + width;
      final visible = math.min(localEnd, viewport) - math.max(localStart, 0);
      return visible >= width * 0.55;
    }

    int? firstVisible;
    int? lastVisible;
    for (var i = 0; i < n; i++) {
      if (!mostlyVisible(i)) continue;
      firstVisible ??= i;
      lastVisible = i;
    }

    final index = _GiftSubcategory.values.indexOf(widget.selected);
    if (index < 0 || starts[index] == null || widths[index] == null) return;

    final localStart = starts[index]! - position.pixels;
    int? revealIndex;
    var alignEnd = false;
    if (!mostlyVisible(index)) {
      final clippedLeft = localStart < 0;
      if (clippedLeft) {
        revealIndex = peekNeighbors && index > 0 ? index - 1 : index;
        alignEnd = false;
      } else {
        revealIndex = peekNeighbors && index < n - 1 ? index + 1 : index;
        alignEnd = true;
      }
    } else if (peekNeighbors) {
      if (lastVisible != null && index >= lastVisible && index < n - 1) {
        revealIndex = index + 1;
        alignEnd = true;
      } else if (firstVisible != null && index <= firstVisible && index > 0) {
        revealIndex = index - 1;
        alignEnd = false;
      }
    }
    if (revealIndex == null) return;
    final start = starts[revealIndex];
    final width = widths[revealIndex];
    if (start == null || width == null) return;

    const leadingPad = 10.0;
    const trailingPad = 10.0;
    final target = alignEnd
        ? start + width + trailingPad - viewport
        : start - leadingPad;
    _controller.animateTo(
      target.clamp(position.minScrollExtent, position.maxScrollExtent),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return SizedBox(
      height: 38,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < _GiftSubcategory.values.length; index++) ...[
              if (index > 0) const SizedBox(width: 6),
              GestureDetector(
                key: _itemKeys[index],
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    widget.onSelected(_GiftSubcategory.values[index]),
                // 二级子 tab：纯文字 + 底部横线高亮，不再用胶囊。选中黑字，
                // 未选灰字；底下一条蓝色短横线标记当前项。
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _GiftSubcategory.values[index].label,
                        style: TextStyle(
                          color:
                              _GiftSubcategory.values[index] == widget.selected
                              ? (w.isDark ? Colors.white : const Color(0xFF16181C))
                              : w.inkSoft,
                          fontSize: 15,
                          height: 1,
                          fontWeight:
                              _GiftSubcategory.values[index] == widget.selected
                              ? FontWeight.w900
                              : FontWeight.w700,
                          letterSpacing: 0,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        height: 3,
                        width: 20,
                        decoration: BoxDecoration(
                          color:
                              _GiftSubcategory.values[index] == widget.selected
                              ? _kStoreBlue
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
      return _ExchangeProductIconFallback(product: product, size: size);
    }
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) =>
          _ExchangeProductIconFallback(product: product, size: size),
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
        accent: AppColors.accent,
        icon: switch (product.category) {
          _ExchangeCategory.blind => CupertinoIcons.cube_box_fill,
          _ExchangeCategory.outfit => CupertinoIcons.paintbrush_fill,
          _ExchangeCategory.bundle => CupertinoIcons.music_note_2,
          _ => CupertinoIcons.gift_fill,
        },
      ),
    );
  }
}
