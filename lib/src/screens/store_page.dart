part of 'package:companion_flutter/main.dart';

class StorePage extends StatefulWidget {
  const StorePage({super.key, required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  _StoreSection _section = _StoreSection.subscription;
  _ExchangeCategory _exchangeCategory = _ExchangeCategory.gift;
  _StoreCurrency _rechargeCurrency = _StoreCurrency.ticket;
  int _selectedPlan = 1;
  int _selectedRecharge = 0;
  late final PageController _sectionController;
  late Future<WalletBalance> _walletFuture;

  @override
  void initState() {
    super.initState();
    _sectionController = PageController(initialPage: _sectionIndex(_section));
    _walletFuture = _loadWallet();
  }

  @override
  void dispose() {
    _sectionController.dispose();
    super.dispose();
  }

  Future<WalletBalance> _loadWallet() {
    return widget.api.getWallet(agentId: widget.session.agentId);
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

  void _showInsufficientTickets() {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('钞票不足'),
          content: const Text('请先在“我的钞票”里充值，再兑换积分。'),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => _rechargeCurrency = _StoreCurrency.ticket);
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
      backgroundColor: AppColors.page,
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
                      title: _section == _StoreSection.subscription
                          ? '会员中心'
                          : '商城',
                      trailing: _section == _StoreSection.exchange
                          ? _StoreBalancePill(
                              points: wallet.pointBalance,
                              onTap: _openRechargePoints,
                            )
                          : null,
                    ),
                    Expanded(
                      child: PageView(
                        controller: _sectionController,
                        physics: const BouncingScrollPhysics(),
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
        onBuy: (product, cycle) => _showComingSoon(
          '${product.title}${cycle == _BundleBillingCycle.monthly ? '月付' : '年付'}',
        ),
        bottomSpace: bottomSpace,
      ),
      _StoreSection.exchange => _ExchangeStoreView(
        points: wallet.pointBalance,
        selectedCategory: _exchangeCategory,
        onCategoryChanged: (value) => setState(() => _exchangeCategory = value),
        onRechargePoints: _openRechargePoints,
        onExchange: _handleExchangeProduct,
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
        bottomSpace: bottomSpace,
      ),
    };
  }

  void _handleExchangeProduct(_StoreProduct product) {
    if (product.category == _ExchangeCategory.outfit) {
      _showOutfitPicker(product);
      return;
    }
    _showComingSoon(product.title);
  }

  void _showOutfitPicker(_StoreProduct product) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _OutfitPickerSheet(product: product);
      },
    );
  }
}
