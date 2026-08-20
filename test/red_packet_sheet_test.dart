import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ChatComponentCard _card({
  required String offeringId,
  required int amount,
  required String status,
}) {
  return ChatComponentCard(
    type: 'red_packet',
    title: '红包',
    subtitle: status == 'received' ? '已领取' : '待领取',
    body: '给你的一点心意',
    footer: '点击查看',
    accent: '#FF4D5F',
    payload: {
      'offering_id': offeringId,
      'ticket_amount': amount,
      'status': status,
    },
  );
}

class _FakeRedPacketApi extends CompanionApi {
  _FakeRedPacketApi(this.result) : super(baseUrl: 'https://example.test') {
    authToken = 'test-token';
  }

  final RedPacketSendResult result;
  int getCalls = 0;

  @override
  Future<RedPacketSendResult> getRedPacket(String offeringId) async {
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
  testWidgets('red packet status page is a fullscreen X sheet', (tester) async {
    _useDesignCanvas(tester);

    final card = _card(offeringId: 'off-1', amount: 100, status: 'sent');
    final api = _FakeRedPacketApi(
      RedPacketSendResult(
        offering: RedPacketOffering(
          id: 'off-1',
          kind: 'red_packet',
          ticketAmount: 100,
          agentValueYuan: 100,
          status: 'sent',
          agentId: 'agent-1',
          createdAt: '2026-08-20T08:00:00Z',
        ),
        componentCard: card,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RedPacketSheetPage(api: api, card: card),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('红包'), findsWidgets);
    expect(find.byIcon(CupertinoIcons.xmark), findsOneWidget);
    expect(find.text('好的'), findsNothing);
    expect(find.text('封'), findsNothing);
    expect(find.byKey(const Key('red-packet-icon')), findsOneWidget);
    expect(find.byKey(const Key('red-packet-sheet')), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(find.text('待领取'), findsOneWidget);
    expect(find.text('还没拆开'), findsOneWidget);
    expect(api.getCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the X closes the fullscreen red packet page', (
    tester,
  ) async {
    _useDesignCanvas(tester);

    final card = _card(offeringId: 'off-2', amount: 18, status: 'received');
    final api = _FakeRedPacketApi(
      RedPacketSendResult(
        offering: RedPacketOffering(
          id: 'off-2',
          kind: 'red_packet',
          ticketAmount: 18,
          agentValueYuan: 18,
          status: 'received',
          agentId: 'agent-1',
          createdAt: '2026-08-20T08:00:00Z',
          receivedAt: '2026-08-20T08:01:00Z',
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
              onPressed: () => RedPacketSheetPage.push(
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

    expect(find.byType(RedPacketSheetPage), findsOneWidget);
    expect(find.text('已经收下了'), findsOneWidget);
    expect(find.text('已领取'), findsOneWidget);
    expect(find.text('这份心意已被接收'), findsOneWidget);
    expect(find.text('这份心意已经到账'), findsNothing);
    expect(find.text('封'), findsNothing);

    await tester.tap(find.byIcon(CupertinoIcons.xmark));
    await tester.pumpAndSettle();

    expect(find.byType(RedPacketSheetPage), findsNothing);
    expect(find.text('open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
