import 'dart:async';

import 'package:companion_flutter/models.dart';
import 'package:companion_flutter/src/payment/iap_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// 只实现 IapService 用到的 InAppPurchase 成员；其余走 noSuchMethod（测试不触及）。
class _FakeIap implements InAppPurchase {
  final StreamController<List<PurchaseDetails>> controller =
      StreamController<List<PurchaseDetails>>.broadcast();
  final List<String> completed = [];

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => controller.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed.add(purchase.purchaseID ?? '');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

PurchaseDetails _details(
  PurchaseStatus status, {
  String id = 'txn-1',
  String product = 'com.bansheng.companion.ticket.10',
}) {
  return PurchaseDetails(
    purchaseID: id,
    productID: product,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local',
      serverVerificationData: 'jws-$id',
      source: 'app_store',
    ),
    transactionDate: null,
    status: status,
  )..pendingCompletePurchase = true;
}

WalletBalance _wallet() => const WalletBalance(
      ticketBalance: 90,
      pointBalance: 0,
      achievementPointsSynced: 0,
    );

VipStatus _vip() => const VipStatus(
      isVip: false,
      vipUntil: null,
      vipTrialAvailable: true,
      giftTicketBalance: 0,
      ticketBalance: 90,
      pointBalance: 0,
      spendableTickets: 90,
    );

void main() {
  test('verify 成功后 completePurchase 被调用并发 success 事件', () async {
    final fake = _FakeIap();
    final service = IapService(
      iap: fake,
      onVerify: ({
        required String productId,
        required String transactionId,
        required String signedTransaction,
      }) async =>
          IapVerifyResponse(
            status: 'granted',
            kind: 'consumable',
            wallet: _wallet(),
            vip: _vip(),
          ),
    );
    final events = <IapEvent>[];
    service.events.listen(events.add);
    await service.init();

    fake.controller.add([_details(PurchaseStatus.purchased)]);
    await pumpEventQueue();

    expect(fake.completed, contains('txn-1'));
    expect(events.map((e) => e.type), contains(IapEventType.success));
    service.dispose();
  });

  test('verify 失败时绝不 completePurchase（钱扣了必到账，交易留队列重试）', () async {
    final fake = _FakeIap();
    final service = IapService(
      iap: fake,
      onVerify: ({
        required String productId,
        required String transactionId,
        required String signedTransaction,
      }) async =>
          throw Exception('server 500'),
    );
    final events = <IapEvent>[];
    service.events.listen(events.add);
    await service.init();

    fake.controller.add([_details(PurchaseStatus.purchased)]);
    await pumpEventQueue();

    expect(fake.completed, isEmpty); // 关键回归：未 complete
    expect(events.map((e) => e.type), contains(IapEventType.verifyFailed));
    service.dispose();
  });

  test('用户取消发 canceled 事件并出队', () async {
    final fake = _FakeIap();
    final service = IapService(
      iap: fake,
      onVerify: ({
        required String productId,
        required String transactionId,
        required String signedTransaction,
      }) async =>
          throw StateError('should not verify on cancel'),
    );
    final events = <IapEvent>[];
    service.events.listen(events.add);
    await service.init();

    fake.controller.add([_details(PurchaseStatus.canceled)]);
    await pumpEventQueue();

    expect(events.map((e) => e.type), contains(IapEventType.canceled));
    expect(fake.completed, contains('txn-1'));
    service.dispose();
  });

  test('IapVerifyResponse.fromJson 解析钱包与 VIP', () {
    final r = IapVerifyResponse.fromJson({
      'status': 'granted',
      'kind': 'subscription',
      'wallet': {'ticket_balance': 5, 'point_balance': 1, 'gift_ticket_balance': 2},
      'vip': {'is_vip': true, 'vip_until': '2027-01-01T00:00:00Z', 'spendable_tickets': 7},
    });
    expect(r.kind, 'subscription');
    expect(r.wallet.ticketBalance, 5);
    expect(r.vip.isVip, isTrue);
  });

  test('IapProducts.ticket 生成正确 product id', () {
    expect(IapProducts.ticket(80), 'com.bansheng.companion.ticket.80');
    expect(IapProducts.isAutoRenew(IapProducts.vipMonthlyAuto), isTrue);
    expect(IapProducts.isAutoRenew(IapProducts.vipYear), isFalse);
  });
}
