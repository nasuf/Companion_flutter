part of 'package:companion_flutter/models.dart';

class WalletBalance {
  const WalletBalance({
    required this.ticketBalance,
    required this.pointBalance,
    required this.achievementPointsSynced,
    this.giftTicketBalance = 0,
  });

  final num ticketBalance;
  final int pointBalance;
  final int achievementPointsSynced;

  /// VIP 每月赠送的限时钞票（随 VIP 存续结转，过期即清零）。花费时优先扣
  /// 这部分而非 [ticketBalance]，见 companion_api.dart:getVipStatus 附近说明。
  final num giftTicketBalance;

  /// 可花费的钞票总额 = 限时赠送 + 永久，跟商城/聊天/音乐超额提示保持一致。
  num get spendableTickets => ticketBalance + giftTicketBalance;

  factory WalletBalance.fromJson(Map<String, dynamic> json) {
    return WalletBalance(
      ticketBalance: (json['ticket_balance'] as num?) ?? 0,
      pointBalance: (json['point_balance'] as num?)?.round() ?? 0,
      achievementPointsSynced:
          (json['achievement_points_synced'] as num?)?.round() ?? 0,
      giftTicketBalance: (json['gift_ticket_balance'] as num?) ?? 0,
    );
  }
}

/// `GET /wallet/ledger` — 钞票/积分流水（充值 tab 明细页）。
class WalletLedgerItem {
  const WalletLedgerItem({
    required this.id,
    required this.currency,
    required this.delta,
    required this.balanceAfter,
    required this.source,
    this.sourceId,
    this.metadata = const {},
    this.createdAt,
  });

  final String id;
  final String currency;
  final num delta;
  final num balanceAfter;
  final String source;
  final String? sourceId;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;

  factory WalletLedgerItem.fromJson(Map<String, dynamic> json) {
    DateTime? parse(String? key) {
      final raw = json[key];
      if (raw == null) return null;
      return DateTime.tryParse(raw.toString());
    }

    final rawMeta = json['metadata'];
    final metadata = rawMeta is Map
        ? Map<String, dynamic>.from(rawMeta)
        : const <String, dynamic>{};

    return WalletLedgerItem(
      id: json['id']?.toString() ?? '',
      currency: json['currency']?.toString() ?? '',
      delta: (json['delta'] as num?) ?? 0,
      balanceAfter: (json['balance_after'] as num?) ?? 0,
      source: json['source']?.toString() ?? '',
      sourceId: json['source_id']?.toString(),
      metadata: metadata,
      createdAt: parse('created_at'),
    );
  }
}


class StoreCatalogStatus {
  const StoreCatalogStatus({
    required this.isVip,
    required this.vipTrialAvailable,
  });

  final bool isVip;
  final bool vipTrialAvailable;

  factory StoreCatalogStatus.fromJson(Map<String, dynamic> json) {
    return StoreCatalogStatus(
      isVip: json['is_vip'] == true,
      vipTrialAvailable: json['vip_trial_available'] != false,
    );
  }
}

/// `POST /me/vip/redeem-code` — activation code redemption result.
class VipCodeRedeemResult {
  const VipCodeRedeemResult({required this.vip, required this.redemption});

  final VipStatus vip;
  final VipCodeRedemptionInfo redemption;

  factory VipCodeRedeemResult.fromJson(Map<String, dynamic> json) {
    return VipCodeRedeemResult(
      vip: VipStatus.fromJson(json['vip'] as Map<String, dynamic>),
      redemption: VipCodeRedemptionInfo.fromJson(
        json['redemption'] as Map<String, dynamic>,
      ),
    );
  }
}

class VipCodeRedemptionInfo {
  const VipCodeRedemptionInfo({
    required this.id,
    required this.durationDays,
    this.codeId,
    this.redeemedAt,
    this.effectiveStart,
    this.effectiveEnd,
  });

  final String id;
  final String? codeId;
  final int durationDays;
  final DateTime? redeemedAt;
  final DateTime? effectiveStart;
  final DateTime? effectiveEnd;

  factory VipCodeRedemptionInfo.fromJson(Map<String, dynamic> json) {
    DateTime? parse(String? key) {
      final raw = json[key]?.toString();
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    return VipCodeRedemptionInfo(
      id: json['id']?.toString() ?? '',
      codeId: json['code_id']?.toString(),
      durationDays: (json['duration_days'] as num?)?.round() ?? 0,
      redeemedAt: parse('redeemed_at'),
      effectiveStart: parse('effective_start'),
      effectiveEnd: parse('effective_end'),
    );
  }
}

/// 统一 VIP 状态：`GET /me/vip`，供 Store/Profile/Chat/Music 共用一个来源，
/// 避免各屏各自查一遍 (见后端 CLAUDE.md 权益项总览)。
class VipStatus {
  const VipStatus({
    required this.isVip,
    required this.vipUntil,
    required this.vipTrialAvailable,
    required this.giftTicketBalance,
    required this.ticketBalance,
    required this.pointBalance,
    required this.spendableTickets,
  });

  final bool isVip;
  final DateTime? vipUntil;
  final bool vipTrialAvailable;
  final num giftTicketBalance;
  final num ticketBalance;
  final int pointBalance;
  final num spendableTickets;

  factory VipStatus.fromJson(Map<String, dynamic> json) {
    return VipStatus(
      isVip: json['is_vip'] == true,
      vipUntil: json['vip_until'] == null
          ? null
          : DateTime.tryParse(json['vip_until'].toString()),
      vipTrialAvailable: json['vip_trial_available'] == true,
      giftTicketBalance: (json['gift_ticket_balance'] as num?) ?? 0,
      ticketBalance: (json['ticket_balance'] as num?) ?? 0,
      pointBalance: (json['point_balance'] as num?)?.round() ?? 0,
      spendableTickets: (json['spendable_tickets'] as num?) ?? 0,
    );
  }
}

/// Apple IAP 校验+到账结果：`POST /iap/apple/verify` 返回到账后的新钱包 + VIP。
class IapVerifyResponse {
  const IapVerifyResponse({
    required this.status,
    required this.kind,
    required this.wallet,
    required this.vip,
    this.replay = false,
  });

  final String status; // 'granted'
  final String kind; // 'subscription' | 'consumable'
  final WalletBalance wallet;
  final VipStatus vip;
  final bool replay;

  factory IapVerifyResponse.fromJson(Map<String, dynamic> json) {
    return IapVerifyResponse(
      status: json['status']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      wallet: WalletBalance.fromJson(
        Map<String, dynamic>.from(json['wallet'] as Map? ?? const {}),
      ),
      vip: VipStatus.fromJson(
        Map<String, dynamic>.from(json['vip'] as Map? ?? const {}),
      ),
      replay: json['replay'] == true,
    );
  }
}

/// `GET /me/iap/membership` — VIP + 连续包月态 + 购买历史（订阅页 / 会员记录）。
class IapMembership {
  const IapMembership({
    required this.vip,
    required this.autoRenewActive,
    required this.history,
    this.subscription,
  });

  final VipStatus vip;
  final IapSubscriptionStatus? subscription;
  final bool autoRenewActive;
  final List<IapHistoryItem> history;

  factory IapMembership.fromJson(Map<String, dynamic> json) {
    return IapMembership(
      vip: VipStatus.fromJson(
        Map<String, dynamic>.from(json['vip'] as Map? ?? const {}),
      ),
      subscription: json['subscription'] == null
          ? null
          : IapSubscriptionStatus.fromJson(
              Map<String, dynamic>.from(json['subscription'] as Map),
            ),
      autoRenewActive: json['auto_renew_active'] == true,
      history: (json['history'] as List? ?? const [])
          .map(
            (item) =>
                IapHistoryItem.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }
}

class IapSubscriptionStatus {
  const IapSubscriptionStatus({
    required this.productId,
    required this.productLabel,
    required this.status,
    required this.autoRenewEnabled,
    this.autoRenewProductId,
    this.expiresDate,
    this.gracePeriodExpiresDate,
    required this.updatedAt,
  });

  final String productId;
  final String productLabel;
  final String status;
  final bool autoRenewEnabled;
  final String? autoRenewProductId;
  final DateTime? expiresDate;
  final DateTime? gracePeriodExpiresDate;
  final DateTime? updatedAt;

  factory IapSubscriptionStatus.fromJson(Map<String, dynamic> json) {
    DateTime? parse(String? key) {
      final raw = json[key];
      if (raw == null) return null;
      return DateTime.tryParse(raw.toString());
    }

    return IapSubscriptionStatus(
      productId: json['product_id']?.toString() ?? '',
      productLabel: json['product_label']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      autoRenewEnabled: json['auto_renew_enabled'] == true,
      autoRenewProductId: json['auto_renew_product_id']?.toString(),
      expiresDate: parse('expires_date'),
      gracePeriodExpiresDate: parse('grace_period_expires_date'),
      updatedAt: parse('updated_at'),
    );
  }
}

class IapHistoryItem {
  const IapHistoryItem({
    required this.transactionId,
    required this.originalTransactionId,
    required this.productId,
    required this.productLabel,
    required this.kind,
    required this.status,
    required this.renewalSequence,
    this.purchaseDate,
    this.expiresDate,
  });

  final String transactionId;
  final String originalTransactionId;
  final String productId;
  final String productLabel;
  final String kind;
  final String status;
  final int renewalSequence;
  final DateTime? purchaseDate;
  final DateTime? expiresDate;

  factory IapHistoryItem.fromJson(Map<String, dynamic> json) {
    DateTime? parse(String? key) {
      final raw = json[key];
      if (raw == null) return null;
      return DateTime.tryParse(raw.toString());
    }

    return IapHistoryItem(
      transactionId: json['transaction_id']?.toString() ?? '',
      originalTransactionId: json['original_transaction_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productLabel: json['product_label']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      renewalSequence: (json['renewal_sequence'] as num?)?.round() ?? 1,
      purchaseDate: parse('purchase_date'),
      expiresDate: parse('expires_date'),
    );
  }
}

/// 对话额度预检：`GET /chat/quota`。发送前用它判断要不要弹确认框。
enum ChatQuotaMode { free, paid, blocked }

class ChatQuota {
  const ChatQuota({
    required this.mode,
    required this.freeRemaining,
    required this.perMsgCost,
    required this.spendableTickets,
  });

  final ChatQuotaMode mode;
  final int freeRemaining;
  final double perMsgCost;
  final num spendableTickets;

  factory ChatQuota.fromJson(Map<String, dynamic> json) {
    return ChatQuota(
      mode: _parseChatQuotaMode(json['mode']?.toString()),
      freeRemaining: (json['free_remaining'] as num?)?.round() ?? 0,
      perMsgCost: (json['per_msg_cost'] as num?)?.toDouble() ?? 0,
      spendableTickets: (json['spendable_tickets'] as num?) ?? 0,
    );
  }
}

ChatQuotaMode _parseChatQuotaMode(String? value) {
  switch (value) {
    case 'paid':
      return ChatQuotaMode.paid;
    case 'blocked':
      return ChatQuotaMode.blocked;
    default:
      return ChatQuotaMode.free;
  }
}

/// 服务端对一次 WS 发送的拒绝：额度耗尽后未确认付费，或余额不足。
enum ChatQuotaBlockReason { paidConfirm, noTicket }

class ChatQuotaBlocked {
  const ChatQuotaBlocked({
    required this.reason,
    required this.perMsgCost,
    required this.spendableTickets,
    this.clientId,
  });

  final ChatQuotaBlockReason reason;
  final double perMsgCost;
  final int spendableTickets;

  /// 被拒消息的 client_id，用于精确摘掉对应草稿（用户连发多条时，"摘最后
  /// 一条待发消息" 这个启发式可能摘错）。旧版服务端可能不带这个字段。
  final String? clientId;

  factory ChatQuotaBlocked.fromJson(Map<String, dynamic> json) {
    return ChatQuotaBlocked(
      reason: json['reason'] == 'no_ticket'
          ? ChatQuotaBlockReason.noTicket
          : ChatQuotaBlockReason.paidConfirm,
      perMsgCost: (json['per_msg_cost'] as num?)?.toDouble() ?? 0,
      spendableTickets: (json['spendable_tickets'] as num?)?.round() ?? 0,
      clientId: json['client_id']?.toString(),
    );
  }
}


class StoreBundlePurchaseResponse {
  const StoreBundlePurchaseResponse({
    required this.wallet,
    this.inventoryItem,
    this.gameBalance,
  });

  final WalletBalance wallet;
  final StoreInventoryItem? inventoryItem;
  final int? gameBalance;

  factory StoreBundlePurchaseResponse.fromJson(Map<String, dynamic> json) {
    final inventory = json['inventory_item'];
    return StoreBundlePurchaseResponse(
      wallet: WalletBalance.fromJson(
        Map<String, dynamic>.from(json['wallet'] as Map? ?? const {}),
      ),
      inventoryItem: inventory is Map
          ? StoreInventoryItem.fromJson(Map<String, dynamic>.from(inventory))
          : null,
      gameBalance: (json['game_balance'] as num?)?.round(),
    );
  }
}

class StoreInventoryItem {
  const StoreInventoryItem({
    required this.productKind,
    required this.quantity,
    this.acquiredAt,
    this.updatedAt,
    this.expiresAt,
    this.isGift = false,
  });

  final String productKind;
  final int quantity;
  final DateTime? acquiredAt;
  final DateTime? updatedAt;

  /// 音乐畅听券/补签卡的最早到期时间；普通装扮/礼物永远为 null（无过期）。
  final DateTime? expiresAt;

  /// true 表示这份数量里含 VIP 每月赠送的部分（会随 VIP 过期失效，不结转）。
  final bool isGift;

  factory StoreInventoryItem.fromJson(Map<String, dynamic> json) {
    return StoreInventoryItem(
      productKind: json['product_kind']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.round() ?? 0,
      acquiredAt: DateTime.tryParse(json['acquired_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
      isGift: json['is_gift'] == true,
    );
  }
}

class StoreInventoryResponse {
  const StoreInventoryResponse({required this.items});

  final List<StoreInventoryItem> items;

  factory StoreInventoryResponse.fromJson(Map<String, dynamic> json) {
    return StoreInventoryResponse(
      items: (json['items'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                StoreInventoryItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }
}

class StoreExchangeResponse {
  const StoreExchangeResponse({
    required this.wallet,
    required this.inventoryItem,
  });

  final WalletBalance wallet;
  final StoreInventoryItem inventoryItem;

  factory StoreExchangeResponse.fromJson(Map<String, dynamic> json) {
    return StoreExchangeResponse(
      wallet: WalletBalance.fromJson(
        Map<String, dynamic>.from(json['wallet'] as Map? ?? const {}),
      ),
      inventoryItem: StoreInventoryItem.fromJson(
        Map<String, dynamic>.from(json['inventory_item'] as Map? ?? const {}),
      ),
    );
  }
}
