part of 'package:companion_flutter/main.dart';

class StoreSubscriptionHistoryPage extends StatefulWidget {
  const StoreSubscriptionHistoryPage({super.key, required this.api});

  final CompanionApi api;

  @override
  State<StoreSubscriptionHistoryPage> createState() =>
      _StoreSubscriptionHistoryPageState();
}

class _StoreSubscriptionHistoryPageState
    extends State<StoreSubscriptionHistoryPage> {
  late Future<IapMembership> _membershipFuture;

  @override
  void initState() {
    super.initState();
    _membershipFuture = widget.api.getIapMembership();
  }

  Future<void> _reload() async {
    setState(() {
      _membershipFuture = widget.api.getIapMembership();
    });
    await _membershipFuture;
  }

  Future<void> _openAppleSubscriptions() async {
    final uri = Uri.parse(kAppleSubscriptionsUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showToast('无法打开订阅管理，请前往 设置 → Apple ID → 订阅');
    }
  }

  Future<void> _confirmManageAutoRenew(DateTime? expires) async {
    final dateText =
        expires != null ? formatVipDisplayDate(expires) : '当前周期结束';
    final proceed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('管理自动续费'),
        content: Text(
          '关闭自动续费后，当前会员权益保留至 $dateText，到期后不再自动扣款。\n\n'
          '将在 Apple 订阅管理中继续操作，本 App 无法代您取消扣款。',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('前往管理'),
          ),
        ],
      ),
    );
    if (proceed == true) {
      await _openAppleSubscriptions();
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1800),
      ),
    );
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
                          '会员记录',
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
                  child: FutureBuilder<IapMembership>(
                    future: _membershipFuture,
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
                      final membership = snapshot.data!;
                      return RefreshIndicator(
                        onRefresh: _reload,
                        color: _kStoreBlue,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 24),
                          children: [
                            _MembershipStatusCard(membership: membership),
                            if (membership.autoRenewActive) ...[
                              const SizedBox(height: 12),
                              _StorePrimaryButton(
                                label: '管理自动续费',
                                onPressed: () => _confirmManageAutoRenew(
                                  membership.subscription?.expiresDate ??
                                      membership.vip.vipUntil,
                                ),
                                height: 48,
                              ),
                            ],
                            const SizedBox(height: 20),
                            Text(
                              '购买记录',
                              style: TextStyle(
                                color: AppColors.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (membership.history.isEmpty)
                              _GlassCard(
                                padding: const EdgeInsets.all(18),
                                child: Text(
                                  '暂无会员购买记录',
                                  style: TextStyle(
                                    color: _W2b.resolve(context).inkSoft,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              )
                            else
                              ...membership.history.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _MembershipHistoryTile(item: item),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              '时长包为一次性购买，到期不自动续费；连续包月请在 Apple 订阅管理中关闭自动续费。',
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

class _MembershipStatusCard extends StatelessWidget {
  const _MembershipStatusCard({required this.membership});

  final IapMembership membership;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    final vip = membership.vip;
    final sub = membership.subscription;
    final statusLine = vip.isVip
        ? (vip.vipUntil != null
              ? '会员生效中 · 有效期至 ${formatVipDisplayDate(vip.vipUntil!)}'
              : '会员生效中')
        : '尚未开通会员';

    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            statusLine,
            style: TextStyle(
              color: vip.isVip ? w.ink : w.inkSoft,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.none,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 10),
            Text(
              '连续包月 · ${sub.productLabel}',
              style: TextStyle(
                color: w.ink,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sub.autoRenewEnabled
                  ? '自动续费已开启${sub.expiresDate != null ? ' · 本期至 ${formatVipDisplayDate(sub.expiresDate!)}' : ''}'
                  : '自动续费已关闭${sub.expiresDate != null ? ' · 权益至 ${formatVipDisplayDate(sub.expiresDate!)}' : ''}',
              style: TextStyle(
                color: w.inkSoft,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MembershipHistoryTile extends StatelessWidget {
  const _MembershipHistoryTile({required this.item});

  final IapHistoryItem item;

  String get _kindLabel => item.kind == 'subscription' ? '自动续费' : '时长包';

  String get _statusLabel {
    switch (item.status) {
      case 'refunded':
        return '已退款';
      case 'revoked':
        return '已撤销';
      default:
        return '已到账';
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    final when = item.purchaseDate != null
        ? formatVipDisplayDate(item.purchaseDate!)
        : '—';
    return _GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 18,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productLabel,
                  style: TextStyle(
                    color: w.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$when · $_kindLabel · $_statusLabel',
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
        ],
      ),
    );
  }
}
