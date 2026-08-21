import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ChatComponentCard _card({
  required String offeringId,
  required String status,
  String title = '美式咖啡',
}) {
  return ChatComponentCard(
    type: 'gift',
    title: title,
    subtitle: status == 'received' ? '已接收' : '待接收',
    body: '饮品',
    footer: '点击查看',
    accent: '#FF8A3D',
    payload: {
      'offering_id': offeringId,
      'kind': 'gift',
      'product_kind': 'gift_1',
      'product_title': title,
      'product_subcategory': '饮品',
      'product_asset_key': '1',
      'status': status,
      'status_label': status == 'received' ? '已接收' : '待接收',
    },
  );
}

class _FakeGiftApi extends CompanionApi {
  _FakeGiftApi(this.result) : super(baseUrl: 'https://example.test') {
    authToken = 'test-token';
  }

  final GiftSendResult result;
  int getCalls = 0;

  @override
  Future<GiftSendResult> getGift(String offeringId) async {
    getCalls += 1;
    expect(offeringId, result.offering.id);
    return result;
  }
}

void _useDesignCanvas(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('gift status page is a fullscreen X sheet', (tester) async {
    _useDesignCanvas(tester);

    final card = _card(offeringId: 'off-1', status: 'sent');
    final api = _FakeGiftApi(
      GiftSendResult(
        offering: RedPacketOffering(
          id: 'off-1',
          kind: 'gift',
          ticketAmount: 25,
          agentValueYuan: 25,
          status: 'sent',
          agentId: 'agent-1',
          createdAt: '2026-08-21T08:00:00Z',
          productKind: 'gift_1',
          productTitle: '美式咖啡',
          productSubcategory: '饮品',
          productAssetKey: '1',
        ),
        componentCard: card,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: GiftSheetPage(api: api, card: card),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('礼物'), findsWidgets);
    expect(find.byIcon(CupertinoIcons.xmark), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(CupertinoIcons.xmark)).color,
      const Color(0xFFFF8A3D),
    );
    expect(find.byKey(const Key('gift-sheet')), findsOneWidget);
    expect(find.text('美式咖啡'), findsOneWidget);
    expect(find.text('待接收'), findsOneWidget);
    expect(find.text('还没收下'), findsOneWidget);
    expect(api.getCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the X closes the fullscreen gift page', (tester) async {
    _useDesignCanvas(tester);

    final card = _card(offeringId: 'off-2', status: 'received');
    final api = _FakeGiftApi(
      GiftSendResult(
        offering: RedPacketOffering(
          id: 'off-2',
          kind: 'gift',
          ticketAmount: 25,
          agentValueYuan: 25,
          status: 'received',
          agentId: 'agent-1',
          createdAt: '2026-08-21T08:00:00Z',
          receivedAt: '2026-08-21T08:01:00Z',
          productKind: 'gift_1',
          productTitle: '美式咖啡',
        ),
        componentCard: card,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) => Center(
            child: CupertinoButton(
              onPressed: () => GiftSheetPage.push(
                context,
                api: api,
                card: card,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(GiftSheetPage), findsOneWidget);
    expect(find.text('已经收下了'), findsOneWidget);
    expect(find.text('已接收'), findsOneWidget);
    expect(find.text('这份礼物已被接收'), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.xmark));
    await tester.pumpAndSettle();

    expect(find.byType(GiftSheetPage), findsNothing);
    expect(find.text('open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
