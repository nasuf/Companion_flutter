import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:companion_flutter/offline_models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _session = AuthSession(
  token: 'test',
  userId: 'user',
  username: 'tester',
  role: UserRole.user,
  hasAgent: true,
);

// 服务端在签收前返回的就是这个样子：名称已脱敏，没有图片和寄语。
RealWorldGift _mystery({bool atDoor = false}) => RealWorldGift.fromJson({
  'id': 'gift',
  'status': atDoor ? 'out_for_delivery' : 'shipping',
  'revealed': false,
  'can_confirm_receipt': atDoor,
  'gift_name': '神秘礼物',
  'tracking_number': 'SF123',
  'logistics_provider': '顺丰',
  'created_at': '2026-10-12T10:00:00+08:00',
});

RealWorldGift _revealed() => RealWorldGift.fromJson({
  'id': 'gift',
  'status': 'delivered',
  'revealed': true,
  'gift_name': '桂花乌龙茶',
  'gift_note': '泡一杯，给自己几分钟发呆。',
  'created_at': '2026-10-12T10:00:00+08:00',
});

class _Api extends CompanionApi {
  _Api({required this.gift}) : super(baseUrl: 'https://example.test') {
    authToken = 'synthetic';
  }

  RealWorldGift gift;
  int receipts = 0;
  Object? receiptError;

  @override
  Future<GiftsHome> fetchOfflineGifts({String? workspaceId}) async => GiftsHome(
    shippingGift: gift.revealed ? null : gift,
    shippingGifts: gift.revealed ? const [] : [gift],
    groups: [
      if (gift.revealed) GiftYearGroup(year: 2026, gifts: [gift]),
    ],
  );

  @override
  Future<RealWorldGift> fetchOfflineGift(String giftId) async => gift;

  @override
  Future<GiftTracking> fetchGiftTracking(String giftId) async => GiftTracking(
    giftId: giftId,
    events: const [
      GiftTrackingEvent(
        id: 'e1',
        status: 'out_for_delivery',
        title: '快递员正在派送',
        occurredAt: '2026-10-15T09:00:00+08:00',
      ),
    ],
  );

  @override
  Future<GiftReceiptResult> confirmGiftReceipt(String giftId) async {
    receipts++;
    final error = receiptError;
    if (error != null) throw error;
    gift = _revealed();
    return GiftReceiptResult(gift: gift, assistantMessage: '是桂花乌龙茶！');
  }
}

Future<void> _open(WidgetTester t, _Api api) async {
  t.view.physicalSize = const Size(430, 1000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      home: OfflineGiftPage(api: api, session: _session),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  group('model', () {
    test('older servers: delivered means revealed, door means signable', () {
      final delivered = RealWorldGift.fromJson({
        'id': 'a',
        'status': 'delivered',
      });
      final door = RealWorldGift.fromJson({
        'id': 'b',
        'status': 'out_for_delivery',
      });
      expect(delivered.revealed, isTrue);
      expect(door.revealed, isFalse);
      expect(door.canConfirmReceipt, isTrue);
      expect(door.isInTransit, isTrue);
    });

    test('explicit server flags win and home falls back to single gift', () {
      final gift = RealWorldGift.fromJson({
        'id': 'a',
        'status': 'out_for_delivery',
        'revealed': false,
        'can_confirm_receipt': false,
      });
      expect(gift.canConfirmReceipt, isFalse);
      final legacy = GiftsHome.fromJson({
        'shipping_gift': {'id': 'a', 'status': 'shipping'},
        'groups': [],
      });
      expect(legacy.inTransit.map((g) => g.id), ['a']);
      final current = GiftsHome.fromJson({
        'shipping_gift': {'id': 'a', 'status': 'shipping'},
        'shipping_gifts': [
          {'id': 'a', 'status': 'shipping'},
          {'id': 'b', 'status': 'ordered'},
        ],
        'groups': [],
      });
      expect(current.inTransit.map((g) => g.id), ['a', 'b']);
    });
  });

  testWidgets('in-transit gift stays a mystery without a sign button', (
    t,
  ) async {
    final api = _Api(gift: _mystery());
    await _open(t, api);
    expect(find.text('神秘礼物'), findsOneWidget);
    expect(find.text('签收后揭晓'), findsOneWidget);
    expect(find.text('礼物还在路上，签收后揭晓'), findsOneWidget);
    expect(find.text('已收到快递，确认签收'), findsNothing);
    expect(find.byType(Image), findsNothing);
    // 物流只展示四个节点：下单 → 运输 → 派送 → 签收。
    for (final label in ['下单', '运输', '派送', '签收']) {
      expect(find.byKey(ValueKey('gift-progress-$label')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('gift-progress-打包')), findsNothing);

    await t.tap(find.text('查看配送详情'));
    await t.pumpAndSettle();
    expect(find.text('快递进入派送后，就可以在这里确认签收'), findsOneWidget);
    expect(find.text('向 TA 说声谢谢'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('signing an out-for-delivery gift reveals it in the sheet', (
    t,
  ) async {
    final api = _Api(gift: _mystery(atDoor: true));
    await _open(t, api);
    expect(find.text('快递正在派送，收到后签收就能揭晓'), findsOneWidget);

    final cta = find.byKey(const ValueKey('gift-confirm-receipt-gift'));
    await t.ensureVisible(cta);
    await t.tap(cta);
    await t.pumpAndSettle();
    expect(find.text('确认已经收到礼物了吗？'), findsOneWidget);

    // 先点「还没收到」：不会签收。
    await t.tap(find.text('还没收到'));
    await t.pumpAndSettle();
    expect(api.receipts, 0);

    await t.tap(cta);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('gift-confirm-receipt-dialog-ok')));
    await t.pumpAndSettle();

    expect(api.receipts, 1);
    expect(find.byKey(const ValueKey('gift-revealed-banner')), findsOneWidget);
    expect(find.text('桂花乌龙茶'), findsWidgets);
    expect(find.text('泡一杯，给自己几分钟发呆。'), findsWidgets);
    final scroll = find.byKey(const ValueKey('offline-detail-scroll-礼物详情'));
    await t.scrollUntilVisible(
      find.text('向 TA 说声谢谢'),
      150,
      scrollable: find
          .descendant(of: scroll, matching: find.byType(Scrollable))
          .first,
    );
    expect(find.text('向 TA 说声谢谢'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('sign failure explains why and keeps the gift sealed', (t) async {
    final api = _Api(gift: _mystery(atDoor: true))
      ..receiptError = const ApiException(409, '礼物还没到派送环节，收到快递后再来签收吧');
    await _open(t, api);
    await t.tap(find.text('查看配送详情'));
    await t.pumpAndSettle();
    final button = find.byKey(
      const ValueKey('gift-sheet-confirm-receipt-gift'),
    );
    final scroll = find.byKey(const ValueKey('offline-detail-scroll-礼物详情'));
    await t.scrollUntilVisible(
      button,
      150,
      scrollable: find
          .descendant(of: scroll, matching: find.byType(Scrollable))
          .first,
    );
    await t.tap(button);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('gift-confirm-receipt-dialog-ok')));
    await t.pumpAndSettle();
    expect(find.text('签收没有成功'), findsOneWidget);
    expect(find.text('礼物还没到派送环节，收到快递后再来签收吧'), findsOneWidget);
    await t.tap(find.text('知道了'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('gift-revealed-banner')), findsNothing);
    expect(find.text('桂花乌龙茶'), findsNothing);
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(t.takeException(), isNull);
  });
}
