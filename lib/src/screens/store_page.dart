part of 'package:companion_flutter/main.dart';

class StorePage extends StatefulWidget {
  const StorePage({
    super.key,
    required this.api,
    required this.session,
    this.openTicketRecharge = false,
    this.openExchange = false,
    this.openBundle = false,
  });

  final CompanionApi api;
  final AuthSession session;
  final bool openTicketRecharge;
  final bool openExchange;

  /// 从聊天/音乐额度弹框跳转购买礼包（音乐畅听券/补签卡）时打开「礼包」tab。
  final bool openBundle;

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  _StoreSection _section = _StoreSection.subscription;
  _ExchangeCategory _exchangeCategory = _ExchangeCategory.gift;
  _GiftSubcategory _giftSubcategory = _GiftSubcategory.drink;
  _StoreCurrency _rechargeCurrency = _StoreCurrency.ticket;
  int _selectedPlan = 0; // 默认选中「连续包月（特惠推荐）」
  int _selectedRecharge = 0;
  bool _isVip = false;
  bool _vipTrialAvailable = true;
  final Set<String> _exchangingKinds = {};
  final Set<_BundleKind> _buyingBundles = {};
  late final PageController _sectionController;
  late Future<WalletBalance> _walletFuture;

  @override
  void initState() {
    super.initState();
    if (widget.openTicketRecharge) {
      _section = _StoreSection.recharge;
      _rechargeCurrency = _StoreCurrency.ticket;
    } else if (widget.openExchange) {
      _section = _StoreSection.exchange;
      _exchangeCategory = _ExchangeCategory.gift;
    } else if (widget.openBundle) {
      _section = _StoreSection.bundle;
    }
    _sectionController = PageController(initialPage: _sectionIndex(_section));
    _walletFuture = _loadWallet();
    _loadCatalog();
  }

  @override
  void dispose() {
    _sectionController.dispose();
    super.dispose();
  }

  Future<WalletBalance> _loadWallet() {
    return widget.api.getWallet(agentId: widget.session.agentId);
  }

  Future<void> _loadCatalog() async {
    try {
      final catalog = await widget.api.getStoreCatalog();
      if (!mounted) return;
      setState(() {
        _isVip = catalog.isVip;
        _vipTrialAvailable = catalog.vipTrialAvailable;
      });
    } catch (_) {
      // Local catalog still renders; prices default to non-member until retry.
    }
  }

  void _openRechargeTickets() {
    setState(() {
      _rechargeCurrency = _StoreCurrency.ticket;
      _selectedRecharge = 0;
    });
    _selectSection(_StoreSection.recharge);
  }

  void _openRechargePoints() {
    setState(() {
      _rechargeCurrency = _StoreCurrency.point;
      _selectedRecharge = 0;
    });
    _selectSection(_StoreSection.recharge);
  }

  int _sectionIndex(_StoreSection section) {
    return _StoreSection.values.indexOf(section);
  }

  void _selectSection(_StoreSection section) {
    if (_section == section) {
      return;
    }

    setState(() => _section = section);
    if (!_sectionController.hasClients) {
      return;
    }

    _sectionController.jumpToPage(_sectionIndex(section));
  }

  void _showComingSoon(String title) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text(title),
          content: const Text('商城后端和支付订单接口接好后，这里会完成真实购买和发放。'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleRecharge() async {
    final pack = _activeRechargePacks[_selectedRecharge];
    if (_rechargeCurrency == _StoreCurrency.point) {
      try {
        final balance = await widget.api.exchangeTicketsToPoints(
          ticketAmount: pack.cost,
        );
        if (!mounted) return;
        setState(() => _walletFuture = Future.value(balance));
        _showToast('已兑换 ${pack.amount} 积分');
      } on ApiException catch (error) {
        if (!mounted) return;
        if (error.statusCode == 409) {
          _showInsufficientTickets();
          return;
        }
        _showToast('兑换失败：${error.message}');
      }
      return;
    }

    showCupertinoDialog<void>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('微信支付待接入'),
          content: Text(
            '已选 ${pack.amount} 钞票，价格 ¥${pack.cost}。\n\n下一步需要服务端返回微信预支付参数，前端再通过 fluwx 调起支付。',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('好的'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openGamePointConvert() async {
    GameWallet wallet;
    try {
      wallet = await widget.api.getGameWallet();
    } on ApiException catch (error) {
      if (!mounted) return;
      _showToast('无法获取游戏积分：${error.message}');
      return;
    }
    if (!mounted) return;
    final convertible = wallet.convertible;
    if (convertible <= 0) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) {
          return CupertinoAlertDialog(
            title: const Text('暂无可兑换积分'),
            content: Text(
              '游戏积分超过 ${wallet.convertFloor} 的部分才能按 1:1 兑换为商城积分，'
              '当前可兑换 0（需保留 ${wallet.convertFloor} 分继续玩游戏）。',
            ),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('知道了'),
              ),
            ],
          );
        },
      );
      return;
    }

    final controller = TextEditingController(text: '$convertible');
    final int? amount;
    try {
      amount = await showCupertinoDialog<int>(
        context: context,
        builder: (context) {
          return CupertinoAlertDialog(
            title: const Text('游戏积分兑换积分'),
            content: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '当前游戏积分 ${wallet.balance}，可兑换 $convertible。\n'
                    '按 1:1 兑换为商城积分，兑换不可逆。',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    placeholder: '兑换数量',
                    autofocus: true,
                  ),
                ],
              ),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () {
                  final value = int.tryParse(controller.text.trim());
                  Navigator.of(context).pop(value);
                },
                child: const Text('兑换'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
    if (!mounted || amount == null) return;
    if (amount <= 0 || amount > convertible) {
      _showToast('请输入 1 - $convertible 之间的数量');
      return;
    }
    try {
      final result = await widget.api.convertGamePointsToShop(amount: amount);
      if (!mounted) return;
      // Refresh the shop wallet so the credited points show immediately.
      setState(() => _walletFuture = _loadWallet());
      _showToast('已兑换 ${result.shopPointDelta} 积分');
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 409) {
        _showToast('可兑换积分不足');
        return;
      }
      _showToast('兑换失败：${error.message}');
    }
  }

  void _showInsufficientTickets() {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('钞票不足'),
          content: const Text('当前钞票余额不足，去充值后即可购买。'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                Navigator.of(context).pop();
                _openRechargeTickets();
              },
              child: const Text('去充值'),
            ),
          ],
        );
      },
    );
  }

  void _showInsufficientPoints() {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('积分不足'),
          content: const Text('当前积分余额不足，去充值后即可兑换。'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                Navigator.of(context).pop();
                _openRechargePoints();
              },
              child: const Text('去充值'),
            ),
          ],
        );
      },
    );
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1300),
      ),
    );
  }

  List<_RechargePack> get _activeRechargePacks {
    return _rechargeCurrency == _StoreCurrency.ticket
        ? _ticketRechargePacks
        : _pointRechargePacks;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: _W2b.resolve(context).base,
      resizeToAvoidBottomInset: false,
      body: FutureBuilder<WalletBalance>(
        future: _walletFuture,
        builder: (context, snapshot) {
          final wallet =
              snapshot.data ??
              const WalletBalance(
                ticketBalance: 0,
                pointBalance: 0,
                achievementPointsSynced: 0,
              );
          return Stack(
            children: [
              const Positioned.fill(child: _StoreBackground()),
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _StoreTopBar(
                      // 标题即当前底部 tab 的名字（订阅 / 礼包 / 兑换 / 充值）。
                      title: _section.label,
                      trailing: _section == _StoreSection.exchange
                          ? _StoreBalancePill(
                              amount: wallet.pointBalance,
                              currency: _StoreCurrency.point,
                              onTap: _openRechargePoints,
                            )
                          : _section == _StoreSection.bundle
                          ? _StoreBalancePill(
                              amount: wallet.ticketBalance,
                              currency: _StoreCurrency.ticket,
                              onTap: _openRechargeTickets,
                            )
                          : null,
                    ),
                    Expanded(
                      child: PageView(
                        controller: _sectionController,
                        // 分区只能靠底部 tab 点击切换，禁止左右滑动。
                        physics: const NeverScrollableScrollPhysics(),
                        onPageChanged: (index) {
                          final section = _StoreSection.values[index];
                          if (_section != section) {
                            setState(() => _section = section);
                          }
                        },
                        children: [
                          for (final section in _StoreSection.values)
                            KeyedSubtree(
                              key: ValueKey(section),
                              child: _buildSection(section, wallet, bottom),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 28,
                right: 28,
                bottom: math.max(10, bottom - 2),
                child: _StoreBottomBar(
                  selected: _section,
                  onSelected: _selectSection,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection(
    _StoreSection section,
    WalletBalance wallet,
    double safeBottom,
  ) {
    final bottomSpace = safeBottom + 98;
    return switch (section) {
      _StoreSection.subscription => _SubscriptionStoreView(
        selectedPlan: _selectedPlan,
        onSelectPlan: (value) => setState(() => _selectedPlan = value),
        onSubscribe: () => _showComingSoon('开通会员'),
        bottomSpace: bottomSpace,
      ),
      _StoreSection.bundle => _BundleStoreView(
        ticketBalance: wallet.ticketBalance,
        vipTrialAvailable: _vipTrialAvailable,
        onBuy: _handleBuyBundle,
        isBuying: (offer) => _buyingBundles.contains(offer.kind),
        onInsufficientTickets: _showInsufficientTickets,
        bottomSpace: bottomSpace,
      ),
      _StoreSection.exchange => _ExchangeStoreView(
        points: wallet.pointBalance,
        isVip: _isVip,
        selectedCategory: _exchangeCategory,
        selectedGiftSubcategory: _giftSubcategory,
        onCategoryChanged: (value) => setState(() => _exchangeCategory = value),
        onGiftSubcategoryChanged: (value) =>
            setState(() => _giftSubcategory = value),
        onInsufficientPoints: _showInsufficientPoints,
        onExchange: _handleExchangeProduct,
        isExchanging: (product) =>
            _exchangingKinds.contains(product.productKind),
        bottomSpace: bottomSpace,
      ),
      _StoreSection.recharge => _RechargeStoreView(
        currency: _rechargeCurrency,
        ticketBalance: wallet.ticketBalance,
        pointBalance: wallet.pointBalance,
        selectedIndex: _selectedRecharge,
        packs: _activeRechargePacks,
        onCurrencyChanged: (value) {
          setState(() {
            _rechargeCurrency = value;
            _selectedRecharge = 0;
          });
        },
        onSelectPack: (value) => setState(() => _selectedRecharge = value),
        onSubmit: _handleRecharge,
        onConvertGamePoints: _openGamePointConvert,
        bottomSpace: bottomSpace,
      ),
    };
  }

  Future<void> _handleBuyBundle(_BundleOffer offer, _BundleTier? tier) async {
    if (offer.isVipTrial) {
      showCupertinoDialog<void>(
        context: context,
        builder: (context) {
          return CupertinoAlertDialog(
            title: const Text('微信支付待接入'),
            content: const Text(
              '月度 VIP 体验 ¥1，账号终身限购 1 次。\n\n支付接口接好后会按月度会员权益发放，并立刻按会员积分计价。',
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('好的'),
              ),
            ],
          );
        },
      );
      return;
    }
    if (tier == null) {
      return;
    }
    if (_buyingBundles.contains(offer.kind)) return;
    final grantLabel = switch (offer.kind) {
      _BundleKind.music => '音乐畅听券 x${tier.grantAmount}',
      _BundleKind.makeup => '补签卡 x${tier.grantAmount}',
      _ => '${tier.grantAmount} 游戏积分',
    };
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text(offer.title),
          content: Text('将消耗 ${tier.ticketPrice} 钞票，获得 $grantLabel。'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('购买'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    setState(() => _buyingBundles.add(offer.kind));
    try {
      final result = await widget.api.purchaseStoreBundle(
        bundleKind: switch (offer.kind) {
          _BundleKind.music => 'music_coupon',
          _BundleKind.makeup => 'makeup_card',
          _ => 'game_points',
        },
        tierId: tier.id,
      );
      if (!mounted) return;
      setState(() => _walletFuture = Future.value(result.wallet));
      switch (offer.kind) {
        case _BundleKind.music:
          _showToast(
            '已放入背包：音乐畅听券 x${result.inventoryItem?.quantity ?? tier.grantAmount}',
          );
        case _BundleKind.makeup:
          _showToast(
            '已放入背包：补签卡 x${result.inventoryItem?.quantity ?? tier.grantAmount}',
          );
        default:
          _showToast('已发放 ${tier.grantAmount} 游戏积分');
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 409) {
        _showInsufficientTickets();
        return;
      }
      _showToast('购买失败：${error.message}');
    } finally {
      if (mounted) {
        setState(() => _buyingBundles.remove(offer.kind));
      }
    }
  }

  Future<void> _handleExchangeProduct(_StoreProduct product) async {
    if (_exchangingKinds.contains(product.productKind)) {
      return;
    }
    final price = product.priceFor(isVip: _isVip);
    final priceLine = _isVip
        ? '将消耗会员价 $price 积分（原价 ${product.listPrice}）'
        : '将消耗 $price 积分（会员价 ${product.memberPrice}）';
    final contents = product.contents;
    final body = contents == null || contents.isEmpty
        ? priceLine
        : '${_previewBlindContents(contents)}\n\n$priceLine';
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text(product.title),
          content: Text(body),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('兑换'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    setState(() => _exchangingKinds.add(product.productKind));
    try {
      final result = await widget.api.exchangeStoreProduct(
        productKind: product.productKind,
      );
      if (!mounted) return;
      setState(() => _walletFuture = Future.value(result.wallet));
      _showToast('已放入背包：${product.title} x${result.inventoryItem.quantity}');
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 409) {
        // 客户端已预检余额，这里是服务端兜底：仍走同一个「去充值」确认框。
        _showInsufficientPoints();
        return;
      }
      _showToast('兑换失败：${error.message}');
    } finally {
      if (mounted) {
        setState(() => _exchangingKinds.remove(product.productKind));
      }
    }
  }
}

String _previewBlindContents(String raw) {
  final parts = raw
      .split('、')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
  if (parts.length <= 4) {
    return '随机开出一份：$raw';
  }
  return '随机开出一份：${parts.take(4).join('、')} 等${parts.length}种';
}
