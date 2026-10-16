import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:companion_flutter/offline_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api extends CompanionApi {
  _Api({this.shipping = false, this.duplicates = false, this.single = false})
    : super(baseUrl: 'https://example.test');
  final bool shipping;
  final bool duplicates;
  final bool single;
  bool trackingFails = false;
  int trackingCalls = 0;
  RealWorldGift gift(int i, {bool transit = false}) => RealWorldGift.fromJson({
    'id': 'gift-$i',
    'gift_name': ['冬日暖手礼', '桂花乌龙', '随身手账'][i % 3],
    'gift_note': ['天冷了，记得把手焐暖。', '给忙碌的一天，留一点茶香。', '把值得记住的日子写下来。'][i % 3],
    'status': transit ? 'shipping' : 'delivered',
    'last_tracking_synced_at': '2026-10-11T13:00:00+08:00',
    'created_at': '2026-10-0${i + 1}T12:00:00+08:00',
  });
  @override
  Future<GiftsHome> fetchOfflineGifts({String? workspaceId}) async => GiftsHome(
    shippingGift: shipping ? gift(2, transit: true) : null,
    groups: [
      GiftYearGroup(
        year: 2026,
        gifts: [
          gift(0),
          if (!single) gift(1),
          if (duplicates) gift(0),
          if (duplicates && shipping) gift(2, transit: true),
        ],
      ),
    ],
  );
  @override
  Future<GiftTracking> fetchGiftTracking(String giftId) async {
    trackingCalls++;
    if (trackingFails) throw const ApiException(503, 'unavailable');
    return GiftTracking(
      giftId: giftId,
      events: const [
        GiftTrackingEvent(
          id: 'event',
          status: 'shipping',
          title: '包裹已到达上海转运中心',
          occurredAt: '2026-10-11T09:00:00+08:00',
        ),
      ],
    );
  }
}

const _session = AuthSession(
  token: 'test',
  userId: 'synthetic',
  username: 'test',
  role: UserRole.user,
  hasAgent: true,
);
void main() {
  testWidgets(
    'latest received gift is featured once, even with unsorted data',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: OfflineGiftPage(api: _Api(), session: _session),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('gift-spotlight-gift-1')),
        findsOneWidget,
      );
      expect(find.text('桂花乌龙'), findsOneWidget);
      expect(find.text('暂无在途礼物'), findsNothing);
      await t.scrollUntilVisible(find.text('冬日暖手礼'), 200);
      expect(find.byKey(const ValueKey('gift-history-gift-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('gift-history-gift-1')), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'duplicates and in-transit entries never inflate received history',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: OfflineGiftPage(
            api: _Api(shipping: true, duplicates: true),
            session: _session,
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text('冬日暖手礼'), 200);
      expect(find.text('2 份'), findsOneWidget);
      expect(find.text('冬日暖手礼'), findsOneWidget);
      expect(find.byKey(const ValueKey('gift-history-gift-2')), findsNothing);
      await t.ensureVisible(find.text('冬日暖手礼'));
      await t.pumpAndSettle();
      await t.tap(find.text('冬日暖手礼'));
      await t.pumpAndSettle();
      expect(find.text('礼物详情'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('single gift opens detail without an empty history section', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: OfflineGiftPage(api: _Api(single: true), session: _session),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('以往的礼物'), findsNothing);
    expect(find.text('还没有收到礼物'), findsNothing);
    await t.ensureVisible(find.text('冬日暖手礼'));
    await t.pumpAndSettle();
    await t.tap(find.text('冬日暖手礼'));
    await t.pumpAndSettle();
    expect(find.text('礼物详情'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'in-transit tracking failure retries inside hero without opening detail',
    (t) async {
      final api = _Api(shipping: true)..trackingFails = true;
      await t.pumpWidget(
        MaterialApp(
          home: OfflineGiftPage(api: api, session: _session),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('物流同步失败'), findsOneWidget);
      expect(find.text('暂时还没有物流更新'), findsNothing);
      api.trackingFails = false;
      await t.ensureVisible(find.text('重试'));
      await t.pumpAndSettle();
      await t.tap(find.text('重试'));
      await t.pumpAndSettle();
      expect(find.text('包裹已到达上海转运中心'), findsNothing);
      expect(find.text('礼物详情'), findsNothing);
      expect(api.trackingCalls, 2);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'shipping hero is quiet, equal-sized steps retain detailed tracking in sheet',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          home: OfflineGiftPage(api: _Api(shipping: true), session: _session),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('运输中'), findsNothing);
      expect(find.text('包裹已到达上海转运中心'), findsNothing);
      final sizes = ['下单', '运输', '派送', '签收']
          .map(
            (label) => t.getSize(find.byKey(ValueKey('gift-progress-$label'))),
          )
          .toSet();
      expect(sizes.length, 1);
      final labelSizes = ['下单', '运输', '派送', '签收']
          .map((label) => t.widget<Text>(find.text(label)).style!.fontSize)
          .toSet();
      expect(labelSizes.length, 1);
      await t.ensureVisible(find.text('查看配送详情'));
      await t.pumpAndSettle();
      await t.tap(find.text('查看配送详情'));
      await t.pumpAndSettle();
      final scroll = find.byKey(const ValueKey('offline-detail-scroll-礼物详情'));
      await t.scrollUntilVisible(
        find.text('包裹已到达上海转运中心'),
        150,
        scrollable: find
            .descendant(of: scroll, matching: find.byType(Scrollable))
            .first,
      );
      expect(find.text('包裹已到达上海转运中心'), findsOneWidget);
      expect(find.textContaining('上次同步'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  for (final dark in [false, true]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets(
        'spotlight and history stay reachable dark=$dark scale=$scale',
        (t) async {
          t.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          await t.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: OfflineGiftPage(
                api: _Api(shipping: true),
                session: _session,
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(find.text('包裹已到达上海转运中心'), findsNothing);
          expect(
            find.byKey(const ValueKey('gift-spotlight-gift-2')),
            findsOneWidget,
          );
          expect(find.text('随身手账'), findsOneWidget);
          await t.scrollUntilVisible(find.text('冬日暖手礼'), 200);
          await t.ensureVisible(find.text('冬日暖手礼'));
          await t.pumpAndSettle();
          expect(find.text('冬日暖手礼').hitTestable(), findsOneWidget);
          await t.ensureVisible(find.text('桂花乌龙'));
          expect(t.takeException(), isNull);
        },
      );
    }
  }
}
