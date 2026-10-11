import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:companion_flutter/offline_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api extends CompanionApi {
  _Api({this.shipping = false}) : super(baseUrl: 'https://example.test');
  final bool shipping;
  RealWorldGift gift(int i, {bool transit = false}) => RealWorldGift.fromJson({
    'id': 'gift-$i',
    'gift_name': ['冬日暖手礼', '桂花乌龙', '随身手账'][i % 3],
    'gift_note': ['天冷了，记得把手焐暖。', '给忙碌的一天，留一点茶香。', '把值得记住的日子写下来。'][i % 3],
    'status': transit ? 'shipping' : 'delivered',
    'created_at': '2026-10-0${i + 1}T12:00:00+08:00',
  });
  @override
  Future<GiftsHome> fetchOfflineGifts({String? workspaceId}) async => GiftsHome(
    shippingGift: shipping ? gift(2, transit: true) : null,
    groups: [
      GiftYearGroup(year: 2026, gifts: [gift(0), gift(1)]),
    ],
  );
  @override
  Future<GiftTracking> fetchGiftTracking(String giftId) async => GiftTracking(
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

const _session = AuthSession(
  token: 'test',
  userId: 'synthetic',
  username: 'test',
  role: UserRole.user,
  hasAgent: true,
);
void main() {
  for (final dark in [false, true]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('collection layout dark=$dark scale=$scale', (t) async {
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
            home: OfflineGiftPage(api: _Api(shipping: true), session: _session),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('包裹已到达上海转运中心'), findsOneWidget);
        await t.scrollUntilVisible(find.text('冬日暖手礼'), 200);
        await t.ensureVisible(find.text('冬日暖手礼'));
        await t.pumpAndSettle();
        expect(find.text('冬日暖手礼').hitTestable(), findsOneWidget);
        if (scale == 1) {
          expect(
            t.getTopLeft(find.text('冬日暖手礼')).dy,
            t.getTopLeft(find.text('桂花乌龙')).dy,
          );
        }
        await t.ensureVisible(find.text('桂花乌龙'));
        expect(t.takeException(), isNull);
      });
    }
  }
}
