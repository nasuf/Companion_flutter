part of 'package:companion_flutter/companion_api.dart';

mixin _CompanionApiStore on _CompanionApiCore {
  Future<WalletBalance> getWallet({String? agentId}) async {
    final params = <String, String>{};
    if (agentId != null && agentId.isNotEmpty) {
      params['agent_id'] = agentId;
    }
    final query = params.isEmpty
        ? ''
        : '?${Uri(queryParameters: params).query}';
    final json =
        await _request('GET', '/wallet$query', debugLabel: 'wallet.balance')
            as Map<String, dynamic>;
    return WalletBalance.fromJson(json);
  }

  /// 钞票/积分流水：`GET /wallet/ledger`。
  Future<List<WalletLedgerItem>> getWalletLedger({
    String? currency,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, String>{'limit': '$limit', 'offset': '$offset'};
    if (currency != null && currency.isNotEmpty) {
      params['currency'] = currency;
    }
    final query = Uri(queryParameters: params).query;
    final json =
        await _request(
              'GET',
              '/wallet/ledger?$query',
              debugLabel: 'wallet.ledger',
            )
            as List<dynamic>;
    return json
        .map(
          (item) =>
              WalletLedgerItem.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<WalletBalance> exchangeTicketsToPoints({
    required int ticketAmount,
  }) async {
    final json =
        await _request(
              'POST',
              '/wallet/exchange',
              body: {
                'from_currency': 'ticket',
                'to_currency': 'point',
                'ticket_amount': ticketAmount,
              },
              debugLabel: 'wallet.exchange',
            )
            as Map<String, dynamic>;
    return WalletBalance.fromJson(json);
  }

  /// 统一 VIP 状态（CLAUDE.md 权益项总览）。`MainShell` 启动时拉取一次并下发，
  /// 商城/聊天/音乐/我的 都读同一份，避免每屏各查一遍。
  Future<VipStatus> getVipStatus() async {
    final json =
        await _request('GET', '/me/vip', debugLabel: 'vip.status')
            as Map<String, dynamic>;
    return VipStatus.fromJson(json);
  }

  /// Redeem a VIP activation code; duration stacks after paid subscription.
  Future<VipCodeRedeemResult> redeemVipCode(String code) async {
    final json =
        await _request(
              'POST',
              '/me/vip/redeem-code',
              body: {'code': code.trim()},
              debugLabel: 'vip.redeem_code',
            )
            as Map<String, dynamic>;
    return VipCodeRedeemResult.fromJson(json);
  }

  /// 会员中心：`GET /me/iap/membership`（VIP + 连续包月 + 购买历史）。
  Future<IapMembership> getIapMembership({int historyLimit = 50}) async {
    final json =
        await _request(
              'GET',
              '/me/iap/membership?history_limit=$historyLimit',
              debugLabel: 'iap.membership',
            )
            as Map<String, dynamic>;
    return IapMembership.fromJson(json);
  }

  /// 发送前预检对话额度（权益项 1）：决定要不要弹"继续扣费/订阅VIP"确认框。
  Future<ChatQuota> getChatQuota() async {
    final json =
        await _request('GET', '/chat/quota', debugLabel: 'chat.quota')
            as Map<String, dynamic>;
    return ChatQuota.fromJson(json);
  }

  Future<StoreCatalogStatus> getStoreCatalog() async {
    final json =
        await _request('GET', '/store/catalog', debugLabel: 'store.catalog')
            as Map<String, dynamic>;
    return StoreCatalogStatus.fromJson(json);
  }

  /// Apple IAP 校验 + 到账。服务端只信 transactionId（向 Apple 校验为准），
  /// 按 transactionId 幂等去重（app 重启 purchaseStream 会重放未 complete 的交易，
  /// 重复提交只到账一次）。返回到账后的新钱包 + VIP 状态。
  Future<IapVerifyResponse> verifyAppleIap({
    required String productId,
    required String transactionId,
    required String signedTransaction,
    String? agentId,
  }) async {
    final json =
        await _request(
              'POST',
              '/iap/apple/verify',
              body: {
                'transaction_id': transactionId,
                'product_id': productId,
                'signed_transaction': signedTransaction,
                if (agentId != null && agentId.isNotEmpty) 'agent_id': agentId,
              },
              debugLabel: 'iap.apple.verify',
            )
            as Map<String, dynamic>;
    return IapVerifyResponse.fromJson(json);
  }

  Future<StoreInventoryResponse> listStoreInventory() async {
    final json =
        await _request('GET', '/store/inventory', debugLabel: 'store.inventory')
            as Map<String, dynamic>;
    return StoreInventoryResponse.fromJson(json);
  }

  Future<StoreExchangeResponse> exchangeStoreProduct({
    required String productKind,
  }) async {
    final json =
        await _request(
              'POST',
              '/store/exchange',
              body: {'product_kind': productKind},
              debugLabel: 'store.exchange',
            )
            as Map<String, dynamic>;
    return StoreExchangeResponse.fromJson(json);
  }

  Future<StoreBundlePurchaseResponse> purchaseStoreBundle({
    required String bundleKind,
    String? tierId,
  }) async {
    final json =
        await _request(
              'POST',
              '/store/bundles',
              body: {
                'bundle_kind': bundleKind,
                if (tierId != null) 'tier_id': tierId,
              },
              debugLabel: 'store.bundle',
            )
            as Map<String, dynamic>;
    return StoreBundlePurchaseResponse.fromJson(json);
  }
}
