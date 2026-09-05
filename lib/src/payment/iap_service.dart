import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../../models.dart';

/// Apple IAP 商品 id（与后端 `app/services/payments/catalog.py::APPLE_PRODUCTS`
/// 和 App Store Connect 后台三处 lockstep，改这里必须同步另两处）。
class IapProducts {
  IapProducts._();

  static const _prefix = 'com.bansheng.companion';

  // VIP：连续包月=自动续订订阅；月/季/年卡=消耗型时长包（到期不自动扣）。
  static const vipMonthlyAuto = '$_prefix.vip.monthly.auto';
  static const vipMonth = '$_prefix.vip.month';
  static const vipQuarter = '$_prefix.vip.quarter';
  static const vipYear = '$_prefix.vip.year';
  static const vipTrial = '$_prefix.vip.trial'; // ¥1 体验（消耗型 30 天）

  /// 订阅页 4 个套餐（_plans 顺序：连续包月/月卡/季卡/年卡）→ product id。
  static const subscriptionPlans = <String>[
    vipMonthlyAuto,
    vipMonth,
    vipQuarter,
    vipYear,
  ];

  /// 只有连续包月是自动续订订阅，其余是消耗型（购买方式不同）。
  static bool isAutoRenew(String productId) => productId == vipMonthlyAuto;

  static String ticket(int amount) => '$_prefix.ticket.$amount';

  /// 需要向 StoreKit 查询本地化价格的全部 product id。
  static const Set<String> all = <String>{
    vipMonthlyAuto,
    vipMonth,
    vipQuarter,
    vipYear,
    vipTrial,
    '$_prefix.ticket.10',
    '$_prefix.ticket.80',
    '$_prefix.ticket.180',
    '$_prefix.ticket.300',
    '$_prefix.ticket.980',
    '$_prefix.ticket.1980',
  };
}

enum IapEventType { pending, verifying, success, canceled, error, verifyFailed }

class IapEvent {
  const IapEvent(this.type, {this.productId, this.result, this.message});

  final IapEventType type;
  final String? productId;
  final IapVerifyResponse? result;
  final String? message;
}

/// 购买成功后交给后端校验+到账。返回到账结果=可 completePurchase；抛异常=不
/// complete（钱扣了没到账，交易留在队列下次重发，后端幂等补发）。
/// 用命名参数而非直接传 PurchaseDetails，避免 in_app_purchase 类型泄漏到 UI 层
/// （store_page 是 part of main.dart，不引 in_app_purchase 包）。
typedef IapVerifyCallback = Future<IapVerifyResponse> Function({
  required String productId,
  required String transactionId,
  required String signedTransaction,
});

/// Apple 内购封装（官方 in_app_purchase / StoreKit 2 默认开启）。构造注入
/// [InAppPurchase] 以便测试替身。**安全核心：verify 成功前绝不 completePurchase。**
class IapService {
  IapService({InAppPurchase? iap, required this.onVerify})
      : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;
  final IapVerifyCallback onVerify;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  final Map<String, ProductDetails> _products = {};
  final StreamController<IapEvent> _events = StreamController<IapEvent>.broadcast();

  Stream<IapEvent> get events => _events.stream;

  bool _available = false;
  bool get available => _available;

  /// 必须在任何购买前调用：订阅 purchaseStream（app 重启后未 complete 的交易
  /// 会在这里重发，配合后端幂等补发到账）。
  Future<bool> init() async {
    _available = await _iap.isAvailable();
    if (!_available) return false;
    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (Object e) =>
          _emit(IapEvent(IapEventType.error, message: e.toString())),
    );
    return true;
  }

  Future<void> queryProducts(Set<String> ids) async {
    final resp = await _iap.queryProductDetails(ids);
    for (final p in resp.productDetails) {
      _products[p.id] = p;
    }
  }

  /// StoreKit 本地化价格字符串（含币种符号，如 "¥29.00"）；未拉到返回 null。
  String? priceLabel(String id) => _products[id]?.price;

  /// 是否已成功拉到任一商品（用于 UI 判断是否展示真实价格）。
  bool get hasProducts => _products.isNotEmpty;

  Future<void> buyConsumable(String productId) async {
    final p = _products[productId];
    if (p == null) {
      _emit(IapEvent(IapEventType.error, productId: productId, message: '商品未就绪'));
      return;
    }
    await _iap.buyConsumable(purchaseParam: PurchaseParam(productDetails: p));
  }

  Future<void> buySubscription(String productId) async {
    final p = _products[productId];
    if (p == null) {
      _emit(IapEvent(IapEventType.error, productId: productId, message: '商品未就绪'));
      return;
    }
    // 订阅在 in_app_purchase 里走 buyNonConsumable。
    await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: p));
  }

  Future<void> restore() => _iap.restorePurchases();

  void dispose() {
    _sub?.cancel();
    _events.close();
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> list) async {
    for (final d in list) {
      switch (d.status) {
        case PurchaseStatus.pending:
          _emit(IapEvent(IapEventType.pending, productId: d.productID));
        case PurchaseStatus.canceled:
          _emit(IapEvent(IapEventType.canceled, productId: d.productID));
          await _complete(d);
        case PurchaseStatus.error:
          _emit(IapEvent(
            IapEventType.error,
            productId: d.productID,
            message: d.error?.message ?? '购买失败',
          ));
          await _complete(d); // 失败也要出队，否则卡住 payment queue
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _handleVerified(d);
      }
    }
  }

  Future<void> _handleVerified(PurchaseDetails d) async {
    _emit(IapEvent(IapEventType.verifying, productId: d.productID));
    try {
      final result = await onVerify(
        productId: d.productID,
        transactionId: d.purchaseID ?? '',
        signedTransaction: d.verificationData.serverVerificationData,
      );
      await _complete(d); // 只有 verify+到账都成功才 complete
      _emit(IapEvent(IapEventType.success, productId: d.productID, result: result));
    } catch (e) {
      // verify 失败：绝不 complete。交易滞留队列，下次 init/restore 重发，
      // 后端按 transactionId 幂等补发到账。
      _emit(IapEvent(
        IapEventType.verifyFailed,
        productId: d.productID,
        message: e.toString(),
      ));
    }
  }

  Future<void> _complete(PurchaseDetails d) async {
    if (d.pendingCompletePurchase) {
      await _iap.completePurchase(d);
    }
  }

  void _emit(IapEvent event) {
    if (!_events.isClosed) _events.add(event);
  }
}
