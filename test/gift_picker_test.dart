import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _session = AuthSession(
  token: 'test-token',
  userId: 'user-1',
  username: 'tester',
  role: UserRole.user,
  hasAgent: true,
  agentId: 'agent-1',
  agentName: '小芜',
  workspaceId: 'ws-1',
  conversationId: 'conv-1',
);

ChatComponentCard _giftCard() {
  return ChatComponentCard(
    type: 'gift',
    title: '美式咖啡',
    subtitle: '待接收',
    body: '饮品',
    footer: '点击查看',
    accent: '#FF8A3D',
    payload: {
      'offering_id': 'off-1',
      'kind': 'gift',
      'product_kind': 'gift_1',
      'status': 'sent',
    },
  );
}

GiftSendResult _sendResult() {
  return GiftSendResult(
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
    ),
    componentCard: _giftCard(),
  );
}

class _FakeGiftPickerApi extends CompanionApi {
  _FakeGiftPickerApi({
    required this.inventory,
    this.sendResult,
  }) : super(baseUrl: 'https://example.test') {
    authToken = 'test-token';
  }

  final StoreInventoryResponse inventory;
  final GiftSendResult? sendResult;
  int sendCalls = 0;
  String? sentProductKind;

  @override
  Future<StoreInventoryResponse> listStoreInventory() async => inventory;

  @override
  Future<GiftSendResult> sendGift({
    required String conversationId,
    required String productKind,
  }) async {
    sendCalls += 1;
    sentProductKind = productKind;
    expect(conversationId, 'conv-1');
    return sendResult!;
  }
}

void _useDesignCanvas(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('empty backpack offers the mall from the gift picker', (
    tester,
  ) async {
    _useDesignCanvas(tester);
    final api = _FakeGiftPickerApi(
      inventory: const StoreInventoryResponse(items: []),
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: GiftPickerPage(
          api: api,
          session: _session,
          conversationId: 'conv-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('gift-picker-page')), findsOneWidget);
    expect(find.text('礼物'), findsWidgets);
    expect(find.text('背包里还没有礼物，去商城兑换后再送'), findsOneWidget);
    expect(find.text('去商城兑换'), findsOneWidget);
    expect(find.byKey(const Key('gift-picker-grid')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirming a gift sends it and pops the picker', (tester) async {
    _useDesignCanvas(tester);
    final api = _FakeGiftPickerApi(
      inventory: const StoreInventoryResponse(
        items: [StoreInventoryItem(productKind: 'gift_1', quantity: 2)],
      ),
      sendResult: _sendResult(),
    );
    GiftSendResult? popped;

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) => Center(
            child: CupertinoButton(
              onPressed: () async {
                popped = await GiftPickerPage.push(
                  context,
                  api: api,
                  session: _session,
                  conversationId: 'conv-1',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('美式咖啡'), findsOneWidget);
    await tester.tap(find.text('美式咖啡'));
    await tester.pumpAndSettle();

    expect(find.text('确定把「美式咖啡」送给 TA？'), findsOneWidget);
    await tester.tap(find.text('赠送'));
    await tester.pumpAndSettle();

    expect(api.sendCalls, 1);
    expect(api.sentProductKind, 'gift_1');
    expect(popped?.offering.id, 'off-1');
    expect(find.byType(GiftPickerPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling the confirm dialog does not send the gift', (
    tester,
  ) async {
    _useDesignCanvas(tester);
    final api = _FakeGiftPickerApi(
      inventory: const StoreInventoryResponse(
        items: [StoreInventoryItem(productKind: 'gift_1', quantity: 1)],
      ),
      sendResult: _sendResult(),
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: GiftPickerPage(
          api: api,
          session: _session,
          conversationId: 'conv-1',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('美式咖啡'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(api.sendCalls, 0);
    expect(find.byType(GiftPickerPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
