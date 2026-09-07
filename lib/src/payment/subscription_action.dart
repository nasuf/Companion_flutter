/// Store subscription tab: button label, hint, and action kind from VIP + plan state.
library;

import '../../models.dart';
import 'iap_service.dart';

enum StoreSubscribeAction { purchase, manageSubscription }

class StoreSubscribeUiState {
  const StoreSubscribeUiState({
    required this.buttonLabel,
    required this.action,
    this.hintText,
    this.needsAutoRenewWarning = false,
  });

  final String buttonLabel;
  final String? hintText;
  final StoreSubscribeAction action;
  final bool needsAutoRenewWarning;
}

const kAppleSubscriptionsUrl = 'https://apps.apple.com/account/subscriptions';

String formatVipDisplayDate(DateTime date) {
  final local = date.toLocal();
  return '${local.year}年${local.month}月${local.day}日';
}

String formatVipDisplayDateTime(DateTime date) {
  final local = date.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  final s = local.second.toString().padLeft(2, '0');
  return '${local.year}年${local.month}月${local.day}日 $h:$m:$s';
}

int? planIndexForProductId(String? productId) {
  if (productId == null) return null;
  final idx = IapProducts.subscriptionPlans.indexOf(productId);
  return idx >= 0 ? idx : null;
}

String? resolveActiveProductId({
  required IapSubscriptionStatus? subscription,
  required List<IapHistoryItem> history,
}) {
  final sub = subscription;
  if (sub != null &&
      (sub.status == 'active' || sub.status == 'in_grace') &&
      planIndexForProductId(sub.productId) != null) {
    return sub.productId;
  }
  for (final item in history) {
    if (item.status != 'granted') continue;
    if (planIndexForProductId(item.productId) != null) {
      return item.productId;
    }
  }
  return null;
}

String membershipTierLabel(String? productId) {
  switch (productId) {
    case IapProducts.vipMonthlyAuto:
      return '连续包月会员';
    case IapProducts.vipMonth:
      return '月度会员';
    case IapProducts.vipQuarter:
      return '季度会员';
    case IapProducts.vipYear:
      return '年度会员';
    case IapProducts.vipTrial:
      return '体验会员';
    default:
      return '会员';
  }
}

/// Primary status headline for subscription tab / history card.
String buildMembershipHeadline({
  required bool isVip,
  required String? activeProductId,
}) {
  if (!isVip) return '尚未开通会员 · 选择套餐立即开通';
  return '${membershipTierLabel(activeProductId)}生效中';
}

/// Secondary line: expiry, next renewal, or plan-selection hint.
String? buildMembershipDetailLine({
  required bool isVip,
  required DateTime? vipUntil,
  required DateTime? subscriptionExpires,
  required bool autoRenewEnabled,
  required bool autoRenewActive,
  required int selectedPlanIndex,
  String? planHint,
}) {
  if (!isVip) {
    return selectedPlanIndex == 0
        ? '到期按所选周期自动续费，可随时在 Apple 订阅管理中关闭'
        : '一次性购买，到期不自动续费';
  }

  final parts = <String>[];
  if (vipUntil != null) {
    parts.add('有效期至 ${formatVipDisplayDate(vipUntil)}');
  }
  if (autoRenewEnabled && subscriptionExpires != null) {
    parts.add('下次自动续费 ${formatVipDisplayDateTime(subscriptionExpires)}');
  } else if (autoRenewActive && subscriptionExpires != null) {
    parts.add('本期至 ${formatVipDisplayDateTime(subscriptionExpires)}');
  }

  if (isVip && !autoRenewActive && selectedPlanIndex == 0 && planHint != null) {
    if (parts.isNotEmpty) {
      return '${parts.join(' · ')}\n$planHint';
    }
    return planHint;
  }

  if (parts.isNotEmpty) return parts.join(' · ');

  // Fall back to selected-plan hint when membership detail is sparse.
  return planHint;
}

StoreSubscribeUiState resolveStoreSubscribeUi({
  required bool isVip,
  required DateTime? vipUntil,
  required int selectedPlanIndex,
  required bool autoRenewActive,
  DateTime? subscriptionExpires,
  DateTime? now,
}) {
  final clock = (now ?? DateTime.now()).toUtc();
  final isAutoRenewPlan = selectedPlanIndex == 0;
  final expires = subscriptionExpires ?? vipUntil;

  if (autoRenewActive && isAutoRenewPlan) {
    return StoreSubscribeUiState(
      buttonLabel: '管理订阅',
      hintText: expires != null
          ? '当前连续包月生效中，到期日 ${formatVipDisplayDate(expires)}'
          : '当前连续包月生效中',
      action: StoreSubscribeAction.manageSubscription,
    );
  }

  if (autoRenewActive && !isAutoRenewPlan) {
    return StoreSubscribeUiState(
      buttonLabel: '叠加购买',
      hintText: '连续包月仍会自动扣款；如需停止请先在会员记录中管理自动续费',
      action: StoreSubscribeAction.purchase,
      needsAutoRenewWarning: true,
    );
  }

  if (isVip && !isAutoRenewPlan) {
    final expiringSoon =
        vipUntil != null && vipUntil.toUtc().difference(clock).inDays <= 7;
    return StoreSubscribeUiState(
      buttonLabel: expiringSoon ? '立即续费' : '叠加购买',
      hintText: vipUntil != null
          ? '新时长将接在 ${formatVipDisplayDate(vipUntil)} 之后生效'
          : '时长包为一次性购买，到期不自动续费',
      action: StoreSubscribeAction.purchase,
    );
  }

  if (isVip && isAutoRenewPlan) {
    return StoreSubscribeUiState(
      buttonLabel: '开通自动续费',
      hintText: '现有时长保留；之后按所选周期自动续费，可随时在 Apple 订阅管理中关闭',
      action: StoreSubscribeAction.purchase,
    );
  }

  return StoreSubscribeUiState(
    buttonLabel: '立即开通',
    hintText: isAutoRenewPlan
        ? '到期按所选周期自动续费，可随时在 Apple 订阅管理中关闭'
        : '一次性购买，到期不自动续费',
    action: StoreSubscribeAction.purchase,
  );
}

/// One row in membership history: a duration pack or a folded renewal group.
class MembershipHistoryNode {
  const MembershipHistoryNode._({
    required this.isRenewalGroup,
    this.item,
    this.renewalItems = const [],
  });

  factory MembershipHistoryNode.single(IapHistoryItem item) =>
      MembershipHistoryNode._(isRenewalGroup: false, item: item);

  factory MembershipHistoryNode.renewalGroup(List<IapHistoryItem> items) =>
      MembershipHistoryNode._(isRenewalGroup: true, renewalItems: items);

  final bool isRenewalGroup;
  final IapHistoryItem? item;
  final List<IapHistoryItem> renewalItems;

  DateTime? get sortDate {
    if (isRenewalGroup) {
      final dates = renewalItems.map((e) => e.purchaseDate).whereType<DateTime>();
      if (dates.isEmpty) return null;
      return dates.reduce((a, b) => a.isAfter(b) ? a : b);
    }
    return item?.purchaseDate;
  }
}

/// Fold subscription renewals by ``original_transaction_id``; keep duration packs flat.
List<MembershipHistoryNode> groupMembershipHistory(List<IapHistoryItem> history) {
  final consumables = <IapHistoryItem>[];
  final renewalGroups = <String, List<IapHistoryItem>>{};

  for (final entry in history) {
    if (entry.kind == 'subscription') {
      final key = entry.originalTransactionId.isNotEmpty
          ? entry.originalTransactionId
          : entry.productId;
      renewalGroups.putIfAbsent(key, () => []).add(entry);
    } else {
      consumables.add(entry);
    }
  }

  final nodes = <MembershipHistoryNode>[
    ...consumables.map(MembershipHistoryNode.single),
    ...renewalGroups.values.map((items) {
      final sorted = [...items]
        ..sort((a, b) {
          final ap = a.purchaseDate ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bp = b.purchaseDate ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bp.compareTo(ap);
        });
      return MembershipHistoryNode.renewalGroup(sorted);
    }),
  ];

  nodes.sort((a, b) {
    final ad = a.sortDate;
    final bd = b.sortDate;
    if (ad == null && bd == null) return 0;
    if (ad == null) return 1;
    if (bd == null) return -1;
    return bd.compareTo(ad);
  });
  return nodes;
}
