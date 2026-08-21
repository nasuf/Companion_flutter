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
  _BackpackFilter _selectedFilter = _BackpackFilter.gift;
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
              content: const Text('装扮和盲盒还不能赠送给 TA，请选择礼物。'),
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

  String _emptyCopy({
    required List<_StoreProduct> ownedProducts,
    required _BackpackFilter filter,
  }) {
    if (ownedProducts.isEmpty) {
      return '背包里还没有礼物，去商城兑换后再送';
    }
    if (filter == _BackpackFilter.gift) {
      return '背包里还没有可以赠送的礼物，去商城兑换后再送';
    }
    return '这个分类还没有物品';
  }

  bool _shouldOfferStore({
    required List<_StoreProduct> ownedProducts,
    required _BackpackFilter filter,
  }) {
    return ownedProducts.isEmpty || filter == _BackpackFilter.gift;
  }

  Future<void> _openStore() async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => StorePage(api: widget.api, session: widget.session),
      ),
    );
    if (!mounted) return;
    _retry();
  }

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return Scaffold(
      key: const Key('gift-picker-page'),
      backgroundColor: w.base,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
              child: SizedBox(
                height: 44,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: Center(
                        child: Text(
                          '礼物',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
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
                  ],
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<StoreInventoryResponse>(
                future: _future,
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  final inventory = {
                    for (final item
                        in data?.items ?? const <StoreInventoryItem>[])
                      if (item.productKind.isNotEmpty && item.quantity > 0)
                        item.productKind: item,
                  };
                  final ownedProducts = [
                    for (final kind in inventory.keys)
                      _productForKind(kind) ??
                          _StoreProduct(
                            title: kind,
                            subtitle: '已下架',
                            productKind: kind,
                            memberPrice: 0,
                            listPrice: 0,
                          ),
                  ];
                  final visibleProducts = _selectedFilter.category == null
                      ? ownedProducts
                      : ownedProducts
                            .where(
                              (item) => item.category == _selectedFilter.category,
                            )
                            .toList();
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CupertinoActivityIndicator());
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
                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      18,
                      4,
                      18,
                      24 + MediaQuery.paddingOf(context).bottom,
                    ),
                    children: [
                      _StoreSegmentedLabelBar<_BackpackFilter>(
                        values: _BackpackFilter.values,
                        selected: _selectedFilter,
                        labelFor: (filter) => filter.label,
                        onSelected: (filter) {
                          setState(() => _selectedFilter = filter);
                        },
                      ),
                      const SizedBox(height: 12),
                      if (visibleProducts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 48, 12, 12),
                          child: Column(
                            children: [
                              Text(
                                _emptyCopy(
                                  ownedProducts: ownedProducts,
                                  filter: _selectedFilter,
                                ),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: w.inkSoft,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                ),
                              ),
                              if (_shouldOfferStore(
                                ownedProducts: ownedProducts,
                                filter: _selectedFilter,
                              )) ...[
                                const SizedBox(height: 16),
                                CupertinoButton(
                                  color: _giftAccent,
                                  borderRadius: BorderRadius.circular(14),
                                  onPressed: _openStore,
                                  child: const Text('去商城兑换'),
                                ),
                              ],
                            ],
                          ),
                        )
                      else
                        GridView.builder(
                          key: const Key('gift-picker-grid'),
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
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
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
