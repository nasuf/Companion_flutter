/// Store subscription tab: button label, hint, and action kind from VIP + plan state.
library;

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
