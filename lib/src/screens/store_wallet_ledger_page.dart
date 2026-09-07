part of 'package:companion_flutter/main.dart';

class StoreWalletLedgerPage extends StatefulWidget {
  const StoreWalletLedgerPage({
    super.key,
    required this.api,
    required this.currency,
  });

  final CompanionApi api;
  final _StoreCurrency currency;

  @override
  State<StoreWalletLedgerPage> createState() => _StoreWalletLedgerPageState();
}

class _StoreWalletLedgerPageState extends State<StoreWalletLedgerPage> {
  late Future<List<WalletLedgerItem>> _ledgerFuture;

  String get _apiCurrency =>
      widget.currency == _StoreCurrency.ticket ? 'ticket' : 'point';

  String get _pageTitle =>
      widget.currency == _StoreCurrency.ticket ? '钞票明细' : '积分明细';

  @override
  void initState() {
    super.initState();
    _ledgerFuture = widget.api.getWalletLedger(currency: _apiCurrency);
  }

  Future<void> _reload() async {
    setState(() {
      _ledgerFuture = widget.api.getWalletLedger(currency: _apiCurrency);
    });
    await _ledgerFuture;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: _W2b.resolve(context).base,
      body: Stack(
        children: [
          const Positioned.fill(child: _StoreBackground()),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
                  child: SizedBox(
                    height: 46,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          _pageTitle,
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 24,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: _StoreBackButton(),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<WalletLedgerItem>>(
                    future: _ledgerFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CupertinoActivityIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              '加载失败，请稍后重试',
                              style: TextStyle(color: _W2b.resolve(context).inkSoft),
                            ),
                          ),
                        );
                      }
                      final items = snapshot.data ?? const [];
                      return RefreshIndicator(
                        onRefresh: _reload,
                        color: _kStoreBlue,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 24),
                          children: [
                            if (items.isEmpty)
                              _GlassCard(
                                padding: const EdgeInsets.all(18),
                                child: Text(
                                  '暂无${_pageTitle.replaceAll('明细', '')}记录',
                                  style: TextStyle(
                                    color: _W2b.resolve(context).inkSoft,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              )
                            else
                              ...items.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _WalletLedgerTile(item: item),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              widget.currency == _StoreCurrency.ticket
                                  ? '仅展示永久钞票变动；VIP 限时赠送钞票不在此列表。'
                                  : '积分变动含商城兑换、游戏积分同步等来源。',
                              style: TextStyle(
                                color: _W2b.resolve(context).inkSoft,
                                fontSize: 12,
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
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

class _WalletLedgerTile extends StatelessWidget {
  const _WalletLedgerTile({required this.item});

  final WalletLedgerItem item;

  String get _sourceLabel => _walletLedgerSourceLabel(item.source);

  String get _deltaLabel {
    final sign = item.delta >= 0 ? '+' : '';
    return '$sign${item.delta}';
  }

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    final when = item.createdAt != null
        ? formatVipDisplayDateTime(item.createdAt!)
        : '—';
    final deltaColor = item.delta >= 0
        ? const Color(0xFF16A34A)
        : const Color(0xFFDC2626);
    return _GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 18,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _sourceLabel,
                  style: TextStyle(
                    color: w.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$when · 余额 ${item.balanceAfter}',
                  style: TextStyle(
                    color: w.inkSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _deltaLabel,
            style: TextStyle(
              color: deltaColor,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.none,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

String _walletLedgerSourceLabel(String source) {
  switch (source) {
    case 'iap_apple':
      return 'Apple 充值';
    case 'iap_apple_refund':
      return 'Apple 退款';
    case 'ticket_to_point_exchange':
      return '钞票兑换积分';
    case 'admin_grant':
      return '系统发放';
    case 'store_bundle':
      return '礼包购买';
    case 'purchase':
      return '商城消费';
    case 'chat_overage':
      return '聊天超额扣费';
    case 'music_overage':
      return '音乐超额扣费';
    case 'red_packet':
      return '发红包';
    case 'red_packet_unbound_refund':
      return '红包退回';
    case 'achievement_sync':
      return '游戏积分同步';
    case 'vip_monthly_grant':
      return 'VIP 每月赠送';
    case 'vip_expire_clear':
      return 'VIP 到期清零';
    default:
      return source;
  }
}
