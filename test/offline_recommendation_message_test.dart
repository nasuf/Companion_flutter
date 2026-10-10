import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/offline_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'offline_journey_flow_test.dart' as journey;

const message =
    '你提过喜欢找咖啡馆看书，这家小岛咖啡可以先放进下次出门的备选里。'
    '想换一条路线走走的话，可以把它作为一站。'
    '不过不用特意给自己排个满满的行程，先看看介绍，感兴趣再决定。'
    '带不带书、待多久，都按你当天的心情来，具体安排也以现场规则为准。'
    '出发前看看当天的开放信息就好。要不要找个方便的时候去看看？'
    '暂时没空也没关系，先留着这个选择。';

OfflineActivity notedActivity({
  String status = 'accepted',
  String? note = message,
}) => OfflineActivity.fromJson({
  'id': 'activity',
  'status': status,
  'title': '小岛咖啡(伯先路店)',
  'summary': '把这家咖啡馆作为下次散步的一站。',
  'description': '地点介绍保持独立，不会被寄语覆盖。',
  'recommendation_message': note,
  'category': '咖啡与茶饮',
  'location_name': '小岛咖啡(伯先路店)',
  'address': '伯先路12号',
});

void main() {
  test(
    'API normalization retains notes and old payloads remain compatible',
    () {
      expect(
        notedActivity().copyWith(imageUrls: []).recommendationMessage,
        message,
      );
      expect(
        OfflineActivity.fromJson({'id': 'old'}).recommendationMessage,
        isNull,
      );
    },
  );

  for (final pending in [true, false]) {
    testWidgets(
      'note expands and collapses in ${pending ? 'detail' : 'checkin'}',
      (tester) async {
        final api = journey.FakeApi(
          notedActivity(status: pending ? 'pending' : 'accepted'),
        );
        if (pending) {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => openOfflineActivityDetail(
                      context,
                      api: api,
                      session: journey.session,
                      activity: api.current,
                    ),
                    child: const Text('打开活动'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('打开活动'));
          await tester.pumpAndSettle();
        } else {
          await journey.showCheckin(tester, api);
        }
        expect(find.text('想推荐给你'), findsOneWidget);
        expect(find.text('地点介绍保持独立，不会被寄语覆盖。'), findsOneWidget);
        expect(tester.widget<Text>(find.text(message)).maxLines, 5);
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -420),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('展开全文'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('展开全文'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(SelectableText, message), findsOneWidget);
        await tester.ensureVisible(find.text('收起'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('收起'));
        await tester.pumpAndSettle();
        expect(tester.widget<Text>(find.text(message)).maxLines, 5);
        expect(find.textContaining('user_relevance'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final note in [null, '', '   ']) {
    testWidgets('legacy/empty note does not render an empty panel: $note', (
      tester,
    ) async {
      await journey.showCheckin(
        tester,
        journey.FakeApi(notedActivity(note: note)),
      );
      expect(find.text('想推荐给你'), findsNothing);
      expect(
        find.byKey(const ValueKey('activity-recommendation-message')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('dark theme and large text keep the note readable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = journey.FakeApi(notedActivity());
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: OfflineCheckinPage(
          api: api,
          session: journey.session,
          activityId: 'activity',
          initialActivity: api.current,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('展开全文'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('展开全文'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(SelectableText, message), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
