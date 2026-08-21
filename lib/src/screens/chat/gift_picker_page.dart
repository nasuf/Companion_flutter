part of 'package:companion_flutter/main.dart';

class GiftPickerPage extends StatefulWidget {
  const GiftPickerPage({
    super.key,
    required this.api,
    required this.session,
    required this.conversationId,
  });

  final CompanionApi api;
  final AuthSession session;
  final String conversationId;

  static Future<GiftSendResult?> push(
    BuildContext context, {
    required CompanionApi api,
    required AuthSession session,
    required String conversationId,
  }) {
    return Navigator.of(context).push<GiftSendResult>(
      CupertinoPageRoute<GiftSendResult>(
        fullscreenDialog: true,
        builder: (_) => GiftPickerPage(
          api: api,
          session: session,
          conversationId: conversationId,
        ),
      ),
    );
  }

  @override
  State<GiftPickerPage> createState() => _GiftPickerPageState();
}

class _GiftPickerPageState extends State<GiftPickerPage> {
  late Future<StoreInventoryResponse> _future;
  _GiftSubcategory? _selectedSubcategory;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<StoreInventoryResponse> _load() => widget.api.listStoreInventory();

  void _retry() {
    setState(() => _future = _load());
  }

  Future<void> _onTapProduct(_StoreProduct product, int quantity) async {
    if (_sending) return;
    setState(() => _sending = true);
    var unlock = true;
    try {
      if (product.category != _ExchangeCategory.gift) {
        await showCupertinoDialog<void>(
          context: context,
          builder: (dialogContext) {
            return CupertinoAlertDialog(
              title: const Text('还不能赠送'),
              content: const Text('请选择一份礼物。'),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('知道了'),
                ),
              ],
            );
          },
        );
        return;
      }
      if (quantity <= 0) return;
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return CupertinoAlertDialog(
            title: const Text('赠送礼物'),
            content: Text('确定把「${product.title}」送给 TA？'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('赠送'),
              ),
            ],
          );
        },
      );
      if (!mounted || confirmed != true) return;
      final result = await widget.api.sendGift(
        conversationId: widget.conversationId,
        productKind: product.productKind,
      );
      if (!mounted) return;
      unlock = false;
      Navigator.of(context).pop(result);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 409) {
        _showToast('背包里没有这个礼物了');
        _retry();
        return;
      }
      _showToast('礼物发送失败：${error.message}');
    } catch (error) {
      if (!mounted) return;
      _showToast('礼物发送失败：$error');
    } finally {
      if (mounted && unlock) {
        setState(() => _sending = false);
      }
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1400),
      ),
    );
  }

  String _emptyCopy({required List<_StoreProduct> ownedProducts}) {
    if (ownedProducts.isEmpty) {
      return '背包里还没有礼物，点右上角「积分兑换」获取';
    }
    return '这个分类还没有礼物';
  }

  Future<void> _openStore() async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => StorePage(
          api: widget.api,
          session: widget.session,
          openExchange: true,
        ),
      ),
    );
    if (!mounted) return;
    _retry();
  }

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    final isDark = w.isDark;
    final ink = isDark ? const Color(0xFFFFF6EE) : const Color(0xFF4A2A1A);
    final inkSoft = isDark ? const Color(0xB3FFD8C2) : const Color(0xFF8A6754);
    const accent = _giftAccent;
    return Scaffold(
      key: const Key('gift-picker-page'),
      backgroundColor: isDark
          ? const Color(0xFF1A120E)
          : const Color(0xFFFFF7F1),
      body: Stack(
        children: [
          Positioned(
            right: -48,
            top: -36,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: isDark ? 0.18 : 0.10),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                  child: SizedBox(
                    height: 44,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Center(
                            child: Text(
                              '礼物',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: ink,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: _GiftSheetCloseButton(
                              onTap: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: _GiftExchangeButton(onTap: _openStore),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                  child: _StoreScrollableSegmentedLabelBar<_GiftSubcategory?>(
                    key: const Key('gift-picker-category-tabs'),
                    scrollKey: const Key('gift-picker-category-scroll'),
                    values: [null, ..._GiftSubcategory.values],
                    selected: _selectedSubcategory,
                    labelFor: (category) => category?.label ?? '全部',
                    onSelected: (subcategory) {
                      setState(() => _selectedSubcategory = subcategory);
                    },
                    itemKeyFor: (category) => ValueKey(
                      'gift-category-${category?.name ?? 'all'}',
                    ),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<StoreInventoryResponse>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(
                          child: CupertinoActivityIndicator(),
                        );
                      }
                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                          child: Column(
                            children: [
                              Text(
                                '背包同步失败：${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: const Color(0xFFFF4D5F),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              CupertinoButton(
                                color: _giftAccent,
                                borderRadius: BorderRadius.circular(14),
                                onPressed: _retry,
                                child: const Text('重新同步'),
                              ),
                            ],
                          ),
                        );
                      }

                      final data = snapshot.data;
                      final inventory = {
                        for (final item
                            in data?.items ?? const <StoreInventoryItem>[])
                          if (item.productKind.isNotEmpty && item.quantity > 0)
                            item.productKind: item,
                      };
                      final ownedProducts = _exchangeProducts
                          .where(
                            (product) =>
                                product.category == _ExchangeCategory.gift &&
                                inventory.containsKey(product.productKind),
                          )
                          .toList();
                      final visibleProducts = _selectedSubcategory == null
                          ? ownedProducts
                          : ownedProducts
                                .where(
                                  (item) =>
                                      item.giftSubcategory ==
                                      _selectedSubcategory,
                                )
                                .toList();

                      if (visibleProducts.isEmpty) {
                        return Padding(
                          padding: EdgeInsets.fromLTRB(
                            30,
                            48,
                            30,
                            24 + MediaQuery.paddingOf(context).bottom,
                          ),
                          child: Text(
                            _emptyCopy(ownedProducts: ownedProducts),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: inkSoft,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                            ),
                          ),
                        );
                      }

                      return GridView.builder(
                        key: const Key('gift-picker-grid'),
                        padding: EdgeInsets.fromLTRB(
                          18,
                          4,
                          18,
                          24 + MediaQuery.paddingOf(context).bottom,
                        ),
                        physics: const BouncingScrollPhysics(),
                        itemCount: visibleProducts.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.82,
                            ),
                        itemBuilder: (context, index) {
                          final product = visibleProducts[index];
                          final item = inventory[product.productKind]!;
                          return GestureDetector(
                            onTap: _sending
                                ? null
                                : () => unawaited(
                                    _onTapProduct(product, item.quantity),
                                  ),
                            child: _ExchangeProductCard(
                              product: product,
                              affordable: true,
                              compact: true,
                              showPrice: false,
                              quantity: item.quantity,
                            ),
                          );
                        },
                      );
                    },
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

class _GiftExchangeButton extends StatelessWidget {
  const _GiftExchangeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return CupertinoButton(
      key: const Key('gift-picker-exchange-button'),
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: w.glass,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: w.glassBorder),
          boxShadow: [w.pillShadow],
        ),
        child: const Text(
          '积分兑换',
          style: TextStyle(
            color: _giftAccent,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
