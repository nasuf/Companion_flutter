part of 'package:companion_flutter/main.dart';

const _storeListFade = 28.0;

class _ExchangeStoreView extends StatelessWidget {
  const _ExchangeStoreView({
    required this.points,
    required this.isVip,
    required this.selectedGiftSubcategory,
    required this.onGiftSubcategoryChanged,
    required this.onInsufficientPoints,
    required this.onExchange,
    required this.isExchanging,
    required this.bottomSpace,
  });

  final int points;
  final bool isVip;
  final _GiftSubcategory selectedGiftSubcategory;
  final ValueChanged<_GiftSubcategory> onGiftSubcategoryChanged;
  final VoidCallback onInsufficientPoints;
  final ValueChanged<_StoreProduct> onExchange;
  final bool Function(_StoreProduct product) isExchanging;
  final double bottomSpace;

  @override
  Widget build(BuildContext context) {
    // 兑换页只卖礼物：礼物的子分类直接作为顶层 tab。
    final products = _exchangeProducts
        .where(
          (item) =>
              item.category == _ExchangeCategory.gift &&
              item.giftSubcategory == selectedGiftSubcategory,
        )
        .toList();
    return Column(
      children: [
        Padding(
          // top 与充值页的顶部 tab 对齐（同为 8），切换 tab 时顶部栏不上下跳。
          // 不加左右内边距：tab 栏铺满屏宽，"没露全"就是被屏幕边缘截断。
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: _GiftSubcategoryScroller(
            selected: selectedGiftSubcategory,
            onSelected: onGiftSubcategoryChanged,
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
                    padding: EdgeInsets.fromLTRB(20, 8, 20, bottomSpace),
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

BoxDecoration _storeSegmentedSelectionDecoration(_W2b w, double height) {
  final radius = height / 2;
  return BoxDecoration(
    color: w.isDark
        ? const Color(0x24FFFFFF)
        : Colors.white.withValues(alpha: 0.98),
    borderRadius: BorderRadius.circular(radius - 3),
    // Neutral pill lift — shared by fixed and scrollable store segment bars.
    boxShadow: [
      BoxShadow(
        color: w.isDark ? const Color(0x33000000) : const Color(0x14243040),
        blurRadius: 8,
        offset: const Offset(0, 3),
      ),
    ],
  );
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

  static const _segmentInset = 3.0;
  static const _slideDuration = Duration(milliseconds: 230);

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
                duration: _slideDuration,
                curve: Curves.easeOutCubic,
                left: selectedIndex * width + _segmentInset,
                top: _segmentInset,
                bottom: _segmentInset,
                width: width - _segmentInset * 2,
                child: DecoratedBox(
                  decoration: _storeSegmentedSelectionDecoration(w, height),
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

class _StoreScrollableSegmentedLabelBar<T> extends StatefulWidget {
  const _StoreScrollableSegmentedLabelBar({
    super.key,
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.onSelected,
    this.height = 46,
    this.fontSize = 16,
    this.itemWidth = 70,
    this.scrollKey,
    this.itemKeyFor,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelFor;
  final ValueChanged<T> onSelected;
  final double height;
  final double fontSize;
  final double itemWidth;
  final Key? scrollKey;
  final Key? Function(T value)? itemKeyFor;

  @override
  State<_StoreScrollableSegmentedLabelBar<T>> createState() =>
      _StoreScrollableSegmentedLabelBarState<T>();
}

class _StoreScrollableSegmentedLabelBarState<T>
    extends State<_StoreScrollableSegmentedLabelBar<T>> {
  final _controller = ScrollController();
  late final List<GlobalKey> _itemKeys;

  @override
  void initState() {
    super.initState();
    _itemKeys = [for (final _ in widget.values) GlobalKey()];
  }

  @override
  void didUpdateWidget(
    covariant _StoreScrollableSegmentedLabelBar<T> oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _revealSelected() {
    if (!mounted) return;
    final index = widget.values.indexOf(widget.selected);
    if (index < 0) return;
    final itemContext = _itemKeys[index].currentContext;
    if (itemContext == null) return;
    Scrollable.ensureVisible(
      itemContext,
      alignment: 0.5,
      duration: _StoreSegmentedLabelBar._slideDuration,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = math.max(0, widget.values.indexOf(widget.selected));
    final w = _W2b.resolve(context);
    final radius = widget.height / 2;
    final inset = _StoreSegmentedLabelBar._segmentInset;
    final trackWidth = widget.values.length * widget.itemWidth + inset * 2;
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: w.glass,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: w.glassBorder),
        boxShadow: [w.pillShadow],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SingleChildScrollView(
          key: widget.scrollKey,
          controller: _controller,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: SizedBox(
            width: trackWidth,
            height: widget.height,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: _StoreSegmentedLabelBar._slideDuration,
                  curve: Curves.easeOutCubic,
                  left: selectedIndex * widget.itemWidth + inset,
                  top: inset,
                  bottom: inset,
                  width: widget.itemWidth - inset * 2,
                  child: DecoratedBox(
                    decoration: _storeSegmentedSelectionDecoration(
                      w,
                      widget.height,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(inset),
                  child: Row(
                    children: [
                      for (var index = 0; index < widget.values.length; index++)
                        GestureDetector(
                          key: _itemKeys[index],
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.onSelected(widget.values[index]),
                          child: SizedBox(
                            key: widget.itemKeyFor?.call(widget.values[index]),
                            width: widget.itemWidth,
                            child: Center(
                              child: Text(
                                widget.labelFor(widget.values[index]),
                                style: TextStyle(
                                  color: widget.values[index] == widget.selected
                                      ? w.ink
                                      : w.inkSoft,
                                  fontSize: widget.fontSize,
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
                ),
              ],
            ),
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
    this.isVip = false,
    this.onTap,
    this.onInsufficient,
    this.busy = false,
    this.compact = false,
    this.showPrice = true,
    this.quantity,
    this.expiresAt,
    this.isGift = false,
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

  /// 音乐畅听券/补签卡的最早到期时间；普通装扮/礼物为 null（背包卡片专用）。
  final DateTime? expiresAt;

  /// true 表示这份数量里含 VIP 赠送部分（背包卡片专用，随 VIP 过期失效）。
  final bool isGift;

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
          if (compact && (expiresAt != null || isGift)) ...[
            const SizedBox(height: 2),
            Text(
              [
                if (isGift) '赠',
                if (expiresAt != null)
                  '${expiresAt!.month}/${expiresAt!.day}到期',
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: w.inkSoft.withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
          ],
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
                padding: const EdgeInsets.symmetric(horizontal: 8),
                // 系统字体调大时价格等比缩小，不在窄卡片里溢出。
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
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
    // 系统字体调大时整行等比缩小，不在窄卡片里溢出。
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
      ),
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

/// 兑换页顶层 tab：礼物子分类，可左右滑动。点到贴边、没露全的 tab 时，
/// 把它旁边那个也滚进来，用户能看出那一侧还有更多分类。
class _GiftSubcategoryScroller extends StatefulWidget {
  const _GiftSubcategoryScroller({
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
  // 首个 tab 的文字与下方商品网格左边对齐（10 + tab 内边距 10 = 20）。
  static const double _edgePadding = 10;
  // 露出邻居时在它外侧再多留的距离，避免它正好贴着屏幕边缘。
  static const double _revealMargin = 12;

  final _controller = ScrollController();
  final _itemKeys = [
    for (var i = 0; i < _GiftSubcategory.values.length; i++) GlobalKey(),
  ];

  @override
  void initState() {
    super.initState();
    // 从别的商城页切回来时保留上次选中项：首帧直接定位，不做动画。
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reveal(animate: false),
    );
  }

  @override
  void didUpdateWidget(covariant _GiftSubcategoryScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _reveal(animate: true),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// tab [index] 在滚动内容里的起止位置；还没布局时返回 null。
  (double, double)? _extentOf(int index, RenderBox viewportBox) {
    final box = _itemKeys[index].currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final dx = box.localToGlobal(Offset.zero, ancestor: viewportBox).dx;
    final start = _controller.offset + dx;
    return (start, start + box.size.width);
  }

  void _reveal({required bool animate}) {
    if (!mounted || !_controller.hasClients) return;
    final position = _controller.position;
    final viewportBox = context.findRenderObject();
    if (!position.hasViewportDimension || viewportBox is! RenderBox) return;

    final index = _GiftSubcategory.values.indexOf(widget.selected);
    final last = _GiftSubcategory.values.length - 1;
    // 要完整可见的区间：选中项连同左右各一个邻居（到头了就只算自己）。
    final left = _extentOf(index > 0 ? index - 1 : index, viewportBox);
    final right = _extentOf(index < last ? index + 1 : index, viewportBox);
    if (left == null || right == null) return;

    final viewport = position.viewportDimension;
    var target = position.pixels;
    final wantEnd = right.$2 + _revealMargin;
    final wantStart = left.$1 - _revealMargin;
    if (wantEnd > target + viewport) target = wantEnd - viewport;
    if (wantStart < target) target = wantStart;
    target = target.clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((target - position.pixels).abs() < 0.5) return;
    if (animate) {
      _controller.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _controller.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    const fontSize = 16.0;
    // 文字 + 间距 + 下划线 + 上下留白；系统字体调大时跟着变高，不溢出。
    final height = math.max(
      40.0,
      MediaQuery.textScalerOf(context).scale(fontSize) + 6 + 3 + 12,
    );
    return SizedBox(
      height: height,
      child: SingleChildScrollView(
        key: const ValueKey('exchange-gift-tabs'),
        controller: _controller,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: _edgePadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, category)
                in _GiftSubcategory.values.indexed) ...[
              if (index > 0) const SizedBox(width: 6),
              GestureDetector(
                key: _itemKeys[index],
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onSelected(category),
                // 纯文字 + 底部横线高亮：选中黑字，未选灰字，下方蓝色短横线。
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        category.label,
                        style: TextStyle(
                          color: category == widget.selected
                              ? (w.isDark
                                    ? Colors.white
                                    : const Color(0xFF16181C))
                              : w.inkSoft,
                          fontSize: fontSize,
                          height: 1,
                          fontWeight: category == widget.selected
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
                          color: category == widget.selected
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
