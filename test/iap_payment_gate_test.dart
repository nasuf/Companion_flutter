import 'dart:async';
import 'package:companion_flutter/src/payment/iap_service.dart';
import 'package:companion_flutter/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class _Iap extends Fake implements InAppPurchase {
  final stream = StreamController<List<PurchaseDetails>>.broadcast();
  int consumables = 0, subscriptions = 0, restorations = 0, completed = 0;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => stream.stream;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse(
        productDetails: [
          for (final id in ids)
            ProductDetails(
              id: id,
              title: id,
              description: id,
              price: '¥1',
              rawPrice: 1,
              currencyCode: 'CNY',
            ),
        ],
        notFoundIDs: [],
      );
  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async {
    consumables++;
    return true;
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    subscriptions++;
    return true;
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restorations++;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed++;
  }
}

Future<IapVerifyResponse> _verify({
  required String productId,
  required String transactionId,
  required String signedTransaction,
}) async => const IapVerifyResponse(
  status: 'granted',
  kind: 'subscription',
  wallet: WalletBalance(
    ticketBalance: 0,
    pointBalance: 0,
    achievementPointsSynced: 0,
  ),
  vip: VipStatus(
    isVip: true,
    vipUntil: null,
    vipTrialAvailable: false,
    giftTicketBalance: 0,
    ticketBalance: 0,
    pointBalance: 0,
    spendableTickets: 0,
  ),
);

void main() {
  test(
    'policy is checked before every StoreKit charge, not cached with products',
    () async {
      final sdk = _Iap();
      var enabled = true;
      var checks = 0;
      final service = IapService(
        iap: sdk,
        onVerify: _verify,
        beforePurchase: (_) async {
          checks++;
          if (!enabled) throw const IapPurchaseUnavailable('closed');
        },
      );
      await service.init();
      await service.queryProducts(IapProducts.all);
      enabled = false;
      await expectLater(
        service.buyConsumable(IapProducts.vipTrial),
        throwsA(isA<IapPurchaseUnavailable>()),
      );
      await expectLater(
        service.buySubscription(IapProducts.vipMonthlyAuto),
        throwsA(isA<IapPurchaseUnavailable>()),
      );
      expect(sdk.consumables + sdk.subscriptions, 0);
      enabled = true;
      await service.buyConsumable(IapProducts.ticket(10));
      await service.buySubscription(IapProducts.vipMonthlyAuto);
      expect(checks, 4);
      expect(sdk.consumables, 1);
      expect(sdk.subscriptions, 1);
      service.dispose();
      await sdk.stream.close();
    },
  );
  test(
    'missing policy and failed permission requests cannot initiate payment',
    () async {
      for (final authorize in <Future<void> Function(String)?>[
        null,
        (_) async => throw TimeoutException('offline'),
      ]) {
        final sdk = _Iap();
        final service = IapService(
          iap: sdk,
          onVerify: _verify,
          beforePurchase: authorize,
        );
        await service.init();
        await service.queryProducts(IapProducts.all);
        await expectLater(
          service.buyConsumable(IapProducts.ticket(10)),
          throwsA(anything),
        );
        expect(sdk.consumables + sdk.subscriptions, 0);
        service.dispose();
        await sdk.stream.close();
      }
    },
  );
  test(
    'restoration and paid transaction replay settle even with gate closed',
    () async {
      final sdk = _Iap();
      var checks = 0;
      final service = IapService(
        iap: sdk,
        onVerify: _verify,
        beforePurchase: (_) async {
          checks++;
          throw const IapPurchaseUnavailable('closed');
        },
      );
      await service.init();
      await service.restore();
      sdk.stream.add([
        PurchaseDetails(
          purchaseID: 'already-paid',
          productID: IapProducts.vipMonthlyAuto,
          verificationData: PurchaseVerificationData(
            localVerificationData: '',
            serverVerificationData: 'synthetic',
            source: 'app_store',
          ),
          transactionDate: null,
          status: PurchaseStatus.restored,
        )..pendingCompletePurchase = true,
      ]);
      await pumpEventQueue();
      expect(checks, 0);
      expect(sdk.restorations, 1);
      expect(sdk.completed, 1);
      service.dispose();
      await sdk.stream.close();
    },
  );
  test(
    'a purchase the server refused to grant is completed but not a success',
    () async {
      // 重复购买体验：服务端记 failed、不发权益。交易已有终态，必须出队，
      // 但不能当作购买成功。
      final sdk = _Iap();
      final service = IapService(
        iap: sdk,
        onVerify: ({
          required String productId,
          required String transactionId,
          required String signedTransaction,
        }) async {
          final granted = await _verify(
            productId: productId,
            transactionId: transactionId,
            signedTransaction: signedTransaction,
          );
          return IapVerifyResponse(
            status: 'failed',
            kind: 'consumable',
            wallet: granted.wallet,
            vip: granted.vip,
          );
        },
        beforePurchase: (_) async {},
      );
      final events = <IapEvent>[];
      final sub = service.events.listen(events.add);
      await service.init();
      sdk.stream.add([
        PurchaseDetails(
          purchaseID: 'repeat-trial',
          productID: IapProducts.vipTrial,
          verificationData: PurchaseVerificationData(
            localVerificationData: '',
            serverVerificationData: 'synthetic',
            source: 'app_store',
          ),
          transactionDate: null,
          status: PurchaseStatus.purchased,
        )..pendingCompletePurchase = true,
      ]);
      await pumpEventQueue();
      expect(sdk.completed, 1);
      expect(events.map((e) => e.type), [
        IapEventType.verifying,
        IapEventType.error,
      ]);
      expect(events.last.message, kIapNotGrantedMessage);
      await sub.cancel();
      service.dispose();
      await sdk.stream.close();
    },
  );
}
