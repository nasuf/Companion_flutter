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

  // Apple IAP：真实内购（订阅 + 充值消耗型）。价格从 StoreKit 拉本地化值。
  late final IapService _iap;
  StreamSubscription<IapEvent>? _iapSub;
  bool _iapReady = false; // 商品价格已拉到，可用本地化价渲染
  bool _subscribing = false; // 订阅购买+校验进行中
  bool _rechargeSubmitting = false; // 充值购买+校验进行中

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
    _iap = IapService(onVerify: _verifyPurchase);
    _iapSub = _iap.events.listen(_onIapEvent);
    _initIap();
  }

  @override
  void dispose() {
    _sectionController.dispose();
    _iapSub?.cancel();
    _iap.dispose();
    super.dispose();
  }

  Future<void> _initIap() async {
    final ok = await _iap.init();
    if (!ok) return; // 模拟器无 StoreKit / 设备不支持：价格回退营销价，按钮点了给提示
    await _iap.queryProducts(IapProducts.all);
    if (!mounted) return;
    setState(() => _iapReady = _iap.hasProducts);
  }

  /// 购买成功回调：把 transactionId 交后端校验+到账。抛异常 = 不 complete。
  Future<IapVerifyResponse> _verifyPurchase({
    required String productId,
    required String transactionId,
    required String signedTransaction,
  }) {
    return widget.api.verifyAppleIap(
      productId: productId,
      transactionId: transactionId,
      signedTransaction: signedTransaction,
      agentId: widget.session.agentId,
    );
  }

  void _onIapEvent(IapEvent event) {
    if (!mounted) return;
    switch (event.type) {
      case IapEventType.pending:
      case IapEventType.verifying:
        // 保持按钮 loading（在发起处已置位），无需额外处理。
        break;
      case IapEventType.success:
        final r = event.result;
        setState(() {
          _subscribing = false;
          _rechargeSubmitting = false;
          if (r != null) {
            _walletFuture = Future.value(r.wallet);
            _isVip = r.vip.isVip;
            _vipTrialAvailable = r.vip.vipTrialAvailable;
          }
        });
        _showToast('已到账');
      case IapEventType.canceled:
        setState(() {
          _subscribing = false;
          _rechargeSubmitting = false;
        });
      case IapEventType.error:
        setState(() {
          _subscribing = false;
          _rechargeSubmitting = false;
        });
        _showToast(event.message ?? '购买失败');
      case IapEventType.verifyFailed:
        setState(() {
          _subscribing = false;
          _rechargeSubmitting = false;
        });
        // 钱可能已扣、到账在重试中——不报"失败"以免误导。
        _showToast('支付成功，正在到账，请稍候');
    }
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

  Future<void> _handleSubscribe() async {
    if (_subscribing) return;
    final productId =
        (_selectedPlan >= 0 && _selectedPlan < IapProducts.subscriptionPlans.length)
        ? IapProducts.subscriptionPlans[_selectedPlan]
        : IapProducts.vipMonthlyAuto;
    if (!_iap.available || _iap.priceLabel(productId) == null) {
      _showToast('内购暂不可用，请稍后再试');
      return;
    }
    setState(() => _subscribing = true);
    try {
      if (IapProducts.isAutoRenew(productId)) {
        await _iap.buySubscription(productId);
      } else {
        await _iap.buyConsumable(productId);
      }
      // 后续 success/canceled/error 由 _onIapEvent 处理并清 _subscribing。
    } catch (e) {
      if (mounted) {
        setState(() => _subscribing = false);
        _showToast('发起购买失败：$e');
      }
    }
  }

  Future<void> _handleRestore() async {
    if (!_iap.available) {
      _showToast('内购暂不可用');
      return;
    }
    await _iap.restore();
    _showToast('正在恢复购买…');
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

  Future<void> _handleRecharge() async {
    final pack = _activeRechargePacks[_selectedRecharge];
    if (_rechargeCurrency == _StoreCurrency.point) {
      // 兑换积分实际花的是永久钞票 (exchangeTicketsToPoints 服务端只查
      // ticket_balance, 不含 VIP 限时赠送的那部分), 先按这个字段判断余额
      // 是否够, 够就弹确认框, 不够直接弹"去充值" —— 之前这里完全没有确认
      // 步骤, 点一下就真扣钞票了。
      WalletBalance? wallet;
      try {
        wallet = await _walletFuture;
      } catch (_) {
        wallet = null; // 加载失败就跳过预检, 交给下面的 409 兜底
      }
      if (!mounted) return;
      if (wallet != null && wallet.ticketBalance < pack.cost) {
        _showInsufficientTickets();
        return;
      }
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) {
          return CupertinoAlertDialog(
            title: const Text('确认兑换'),
            content: Text('将消耗 ${pack.cost} 钞票兑换 ${pack.amount} 积分，是否继续？'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('确认兑换'),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !mounted) return;
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

    // 钞票充值 = Apple IAP 消耗型商品（App Store 规定虚拟货币必须走 IAP）。
    if (_rechargeSubmitting) return;
    final productId = IapProducts.ticket(pack.amount);
    final priceLabel = _iap.priceLabel(productId);
    if (!_iap.available || priceLabel == null) {
      _showToast('内购暂不可用，请稍后再试');
      return;
    }
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('确认充值'),
          content: Text('将支付 $priceLabel 获得 ${pack.amount} 钞票，是否继续？'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('去支付'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    setState(() => _rechargeSubmitting = true);
    try {
      await _iap.buyConsumable(productId);
      // 后续 success/canceled/error 由 _onIapEvent 处理并清 _rechargeSubmitting。
    } catch (e) {
      if (mounted) {
        setState(() => _rechargeSubmitting = false);
        _showToast('发起支付失败：$e');
      }
    }
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
        onSubscribe: _handleSubscribe,
        onRestore: _handleRestore,
        subscribing: _subscribing,
        planPrices: _iapReady
            ? [
                for (final id in IapProducts.subscriptionPlans)
                  _iap.priceLabel(id),
              ]
            : const [],
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
        submitting: _rechargeSubmitting,
        priceLabelFor: (pack) => pack.currency == _StoreCurrency.ticket
            ? _iap.priceLabel(IapProducts.ticket(pack.amount))
            : null,
        bottomSpace: bottomSpace,
      ),
    };
  }

  Future<void> _handleBuyBundle(_BundleOffer offer, _BundleTier? tier) async {
    if (offer.isVipTrial) {
      // ¥1 体验 = Apple IAP 消耗型商品，到账后端记 30 天 VIP（账号限购一次）。
      if (_subscribing) return;
      const productId = IapProducts.vipTrial;
      final priceLabel = _iap.priceLabel(productId);
      if (!_iap.available || priceLabel == null) {
        _showToast('内购暂不可用，请稍后再试');
        return;
      }
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) {
          return CupertinoAlertDialog(
            title: const Text('月度 VIP 体验'),
            content: Text(
              '将支付 $priceLabel 获得 30 天会员权益（账号限购一次）。到期不自动续费。',
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('去支付'),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !mounted) return;
      setState(() => _subscribing = true);
      try {
        await _iap.buyConsumable(productId);
      } catch (e) {
        if (mounted) {
          setState(() => _subscribing = false);
          _showToast('发起支付失败：$e');
        }
      }
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
