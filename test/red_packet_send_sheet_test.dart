import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void _useDesignCanvas(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('red packet send sheet is a half-screen bottom sheet', (
    tester,
  ) async {
    _useDesignCanvas(tester);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) => Center(
            child: CupertinoButton(
              onPressed: () => RedPacketSendSheet.push(
                context,
                ticketBalance: 80,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('发红包'), findsOneWidget);
    expect(find.textContaining('当前余额'), findsOneWidget);
    expect(find.byKey(const Key('red-packet-send-sheet')), findsOneWidget);
    expect(find.byKey(const Key('red-packet-send-amount')), findsOneWidget);
    expect(find.byKey(const Key('red-packet-send-blessing')), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('red-packet-send-sheet'))).height,
        closeTo(422, 1));
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sheet background extends through the keyboard inset', (
    tester,
  ) async {
    _useDesignCanvas(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) => Center(
            child: CupertinoButton(
              onPressed: () => RedPacketSendSheet.push(
                context,
                ticketBalance: 80,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final sheetSize =
        tester.getSize(find.byKey(const Key('red-packet-send-sheet')));
    expect(sheetSize.height, closeTo(722, 1));
    expect(sheetSize.width, closeTo(390, 1));
    expect(find.text('发送'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('red packet send sheet returns amount and blessing', (
    tester,
  ) async {
    _useDesignCanvas(tester);
    RedPacketSendDraft? draft;

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) => Center(
            child: CupertinoButton(
              onPressed: () async {
                draft = await RedPacketSendSheet.push(
                  context,
                  ticketBalance: 80,
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

    await tester.enterText(
      find.byKey(const Key('red-packet-send-amount')),
      '18',
    );
    await tester.enterText(
      find.byKey(const Key('red-packet-send-blessing')),
      '  早点休息呀  ',
    );
    await tester.tap(find.byKey(const Key('red-packet-send-submit')));
    await tester.pumpAndSettle();

    expect(draft?.ticketAmount, 18);
    expect(draft?.blessing, '早点休息呀');
    expect(find.byType(RedPacketSendSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('red packet send sheet rejects amount above balance', (
    tester,
  ) async {
    _useDesignCanvas(tester);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) => Center(
            child: CupertinoButton(
              onPressed: () => RedPacketSendSheet.push(
                context,
                ticketBalance: 10,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('red-packet-send-amount')),
      '18',
    );
    await tester.tap(find.byKey(const Key('red-packet-send-submit')));
    await tester.pump();

    expect(find.textContaining('余额不足'), findsOneWidget);
    expect(find.byType(RedPacketSendSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
