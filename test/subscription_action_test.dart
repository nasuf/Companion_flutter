import 'package:companion_flutter/models.dart';
import 'package:companion_flutter/src/payment/subscription_action.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = DateTime.utc(2026, 9, 6);

  test('formatTicketAmount shows fractional tickets', () {
    expect(formatTicketAmount(-0.5, withSign: true), '-0.5');
    expect(formatTicketAmount(0.5, withSign: true), '+0.5');
    expect(formatTicketAmount(9), '9');
    expect(formatTicketAmount(9.5), '9.5');
  });

  test('compact status line merges tier and expiry', () {
    expect(
      buildMembershipCompactStatusLine(
        isVip: true,
        activeProductId: 'com.bansheng.vip.monthly.auto',
        vipUntil: DateTime.utc(2027, 1, 8, 10, 7, 40),
      ),
      '连续包月会员生效中 · 有效期至 2027年1月8日',
    );
  });

  test('membership headline uses tier label', () {
    expect(
      buildMembershipHeadline(
        isVip: true,
        activeProductId: 'com.bansheng.vip.monthly.auto',
      ),
      '连续包月会员生效中',
    );
  });

  test('detail line includes next renewal datetime', () {
    final line = buildMembershipDetailLine(
      isVip: true,
      vipUntil: DateTime.utc(2027, 1, 8, 10, 7, 40),
      subscriptionExpires: DateTime.utc(2026, 9, 6, 10, 7, 40),
      autoRenewEnabled: true,
      autoRenewActive: true,
      selectedPlanIndex: 0,
    );
    expect(line, contains('下次自动续费'));
    expect(line, contains('2026年9月6日'));
  });

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

  test('groupMembershipHistory folds subscription renewals', () {
    final t1 = DateTime.utc(2026, 9, 1);
    final t2 = DateTime.utc(2026, 9, 2);
    final month = DateTime.utc(2026, 8, 20);
    final nodes = groupMembershipHistory([
      IapHistoryItem(
        transactionId: 'r2',
        originalTransactionId: 'otxn-1',
        productId: 'com.bansheng.vip.monthly.auto',
        productLabel: '连续包月',
        kind: 'subscription',
        status: 'granted',
        renewalSequence: 2,
        purchaseDate: t2,
      ),
      IapHistoryItem(
        transactionId: 'm1',
        originalTransactionId: 'm1',
        productId: 'com.bansheng.vip.month',
        productLabel: '月卡',
        kind: 'consumable',
        status: 'granted',
        renewalSequence: 1,
        purchaseDate: month,
      ),
      IapHistoryItem(
        transactionId: 'r1',
        originalTransactionId: 'otxn-1',
        productId: 'com.bansheng.vip.monthly.auto',
        productLabel: '连续包月',
        kind: 'subscription',
        status: 'granted',
        renewalSequence: 1,
        purchaseDate: t1,
      ),
    ]);

    expect(nodes.length, 2);
    expect(nodes.first.isRenewalGroup, isTrue);
    expect(nodes.first.renewalItems.length, 2);
    expect(nodes.last.isRenewalGroup, isFalse);
    expect(nodes.last.item?.productLabel, '月卡');
  });

  test('renewal history line is single compact row', () {
    final start = DateTime.utc(2026, 9, 6, 23, 16, 28);
    final end = DateTime.utc(2026, 9, 6, 23, 21, 28);
    final line = formatRenewalHistoryLine(
      item: IapHistoryItem(
        transactionId: 'r1',
        originalTransactionId: 'otxn',
        productId: 'com.bansheng.vip.monthly.auto',
        productLabel: '连续包月',
        kind: 'subscription',
        status: 'granted',
        renewalSequence: 3,
        purchaseDate: start,
        expiresDate: end,
      ),
      sequence: 3,
    );
    expect(line, contains('#3'));
    expect(line, contains('→'));
    expect(line, contains('已到账'));
    expect(line.split('\n').length, 1);
  });
}
