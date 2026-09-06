import 'package:companion_flutter/src/payment/subscription_action.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = DateTime.utc(2026, 9, 6);

  test('auto renew active + monthly auto plan shows manage', () {
    final ui = resolveStoreSubscribeUi(
      isVip: true,
      vipUntil: DateTime.utc(2027, 1, 8),
      selectedPlanIndex: 0,
      autoRenewActive: true,
      subscriptionExpires: DateTime.utc(2027, 2, 1),
      now: base,
    );
    expect(ui.buttonLabel, '管理订阅');
    expect(ui.action, StoreSubscribeAction.manageSubscription);
    expect(ui.needsAutoRenewWarning, isFalse);
    expect(ui.hintText, contains('2027年2月1日'));
  });

  test('auto renew active + consumable plan shows stack purchase warning', () {
    final ui = resolveStoreSubscribeUi(
      isVip: true,
      vipUntil: DateTime.utc(2027, 1, 8),
      selectedPlanIndex: 1,
      autoRenewActive: true,
      now: base,
    );
    expect(ui.buttonLabel, '叠加购买');
    expect(ui.action, StoreSubscribeAction.purchase);
    expect(ui.needsAutoRenewWarning, isTrue);
  });

  test('vip consumable only shows stack or renew', () {
    final ui = resolveStoreSubscribeUi(
      isVip: true,
      vipUntil: DateTime.utc(2026, 9, 10),
      selectedPlanIndex: 2,
      autoRenewActive: false,
      now: base,
    );
    expect(ui.buttonLabel, '立即续费');
    expect(ui.needsAutoRenewWarning, isFalse);
  });

  test('vip without auto renew selecting auto plan shows enable auto renew', () {
    final ui = resolveStoreSubscribeUi(
      isVip: true,
      vipUntil: DateTime.utc(2027, 1, 8),
      selectedPlanIndex: 0,
      autoRenewActive: false,
      now: base,
    );
    expect(ui.buttonLabel, '开通自动续费');
    expect(ui.action, StoreSubscribeAction.purchase);
  });

  test('non-vip default labels', () {
    final autoUi = resolveStoreSubscribeUi(
      isVip: false,
      vipUntil: null,
      selectedPlanIndex: 0,
      autoRenewActive: false,
      now: base,
    );
    expect(autoUi.buttonLabel, '立即开通');
    expect(autoUi.hintText, contains('自动续费'));

    final packUi = resolveStoreSubscribeUi(
      isVip: false,
      vipUntil: null,
      selectedPlanIndex: 1,
      autoRenewActive: false,
      now: base,
    );
    expect(packUi.hintText, contains('一次性'));
  });
}
