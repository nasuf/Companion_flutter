import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:companion_flutter/offline_models.dart';
import 'package:companion_flutter/takeover_inbox.dart';
import 'package:companion_flutter/takeover_unread.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'takeover_flow_test.dart' as takeover;
import 'offline_journey_flow_test.dart' as journey;

OfflineActivity activity(String status) => OfflineActivity.fromJson({
  'id': 'activity',
  'status': status,
  'title': '公园走走',
  'summary': '沿湖慢慢走',
  'description': '详细地点介绍',
  'recommendation_message': '推荐寄语',
  'location_name': '莲湖公园',
  'address': '湖边路一号',
  'reached': status == 'completed',
});

class ReadOnlyApi extends takeover.FakeTakeoverApi {
  ReadOnlyApi(this.status) {
    scriptedHistory = [
      ChatMessage(
        id: 'card',
        conversationId: 'conv',
        role: 'assistant',
        content: '',
        createdAt: DateTime.utc(2026, 10, 13),
        metadata: const {
          'component_card': {
            'type': 'offline_activity',
            'title': '公园走走',
            'subtitle': '待确定',
            'payload': {'activity_id': 'activity'},
          },
        },
      ),
    ];
  }
  final String status;
  final detailReads = <String>[];
  final reviewReads = <String>[];
  final writes = <String>[];

  Future<T> rejectWrite<T>(String action) async {
    writes.add(action);
    throw StateError('Read-only activity attempted $action');
  }

  @override
  Future<OfflineActivity> acceptOfflineActivity(String id) =>
      rejectWrite('accept');
  @override
  Future<OfflineActivity> ignoreOfflineActivity(String id) =>
      rejectWrite('ignore');
  @override
  Future<OfflineActivity> arriveOfflineActivity(
    String id, {
    double? lat,
    double? lng,
    double? accuracyMeters,
    DateTime? observedAt,
    bool manualConfirmation = false,
  }) => rejectWrite('arrive');
  @override
  Future<OfflineActivity> drawOfflineActivityProphecy(String id) =>
      rejectWrite('prophecy');
  @override
  Future<OfflineActivity> archiveOfflineActivity(String id) =>
      rejectWrite('archive');
  @override
  Future<void> deleteOfflineActivity(String id) => rejectWrite('delete');
  @override
  Future<OfflineMemoryNote> generateOfflineMemoryNote(String id) =>
      rejectWrite('memory-note');

  bool fail = false;
  @override
  Future<OfflineActivity> fetchTakeoverActivity(
    String takeoverId,
    String id,
  ) async {
    detailReads.add('$takeoverId/$id');
    if (fail) throw const ApiException(404, '活动不存在或已无权查看');
    return activity(status);
  }

  @override
  Future<OfflineActivityReview> fetchTakeoverActivityReview(
    String takeoverId,
    String id,
  ) async {
    reviewReads.add('$takeoverId/$id');
    return OfflineActivityReview.fromJson({
      'id': id,
      'title': '公园走走',
      'story': '已有旅途故事',
      'can_generate_memory_note': true,
      'has_memory_note': true,
      'arrival_message_id': 'card',
    });
  }

  @override
  Future<OfflineActivity> fetchOfflineActivity(String id) async =>
      throw StateError('Takeover must not read the admin own activity');
  @override
  Future<OfflineActivityReview> fetchOfflineActivityReview(String id) async =>
      throw StateError('Takeover must not read the admin own review');
}

class OwnActivityApi extends journey.FakeApi {
  OwnActivityApi(String status) : super(activity(status));
  final responses = <String>[];
  @override
  Future<OfflineActivity> acceptOfflineActivity(String id) async {
    responses.add('accept/$id');
    return current = activity('accepted');
  }

  @override
  Future<OfflineActivity> ignoreOfflineActivity(String id) async {
    responses.add('ignore/$id');
    return current = activity('ignored');
  }
}

void expectReadOnly() {
  for (final label in [
    '想去看看',
    '先放一放',
    '重新接受邀请',
    '我已经抵达这里',
    '抽一句此行小预言',
    '收好这次旅途回忆',
    '删除该活动',
    '生成记忆手札',
    '查看记忆手札',
  ]) {
    expect(find.text(label), findsNothing, reason: label);
  }
}

void main() {
  tearDown(() async {
    TakeoverUnreadController.instance.clear();
    await TakeoverInbox.instance.stop();
  });
  for (final status in ['pending', 'ignored', 'accepted', 'completed']) {
    testWidgets('takeover activity card opens read-only $status detail', (
      tester,
    ) async {
      final api = ReadOnlyApi(status);
      await takeover.chat(tester, api);
      await tester.tap(find.text('公园走走'));
      await takeover.drain(tester);
      expect(api.detailReads, everyElement('case/activity'));
      expect(api.detailReads, isNotEmpty);
      expectReadOnly();
      if (status == 'completed') {
        expect(find.byType(OfflineReviewPage), findsOneWidget);
        expect(api.reviewReads, ['case/activity']);
        expect(find.text('已有旅途故事'), findsOneWidget);
      } else {
        expect(find.text('详细地点介绍'), findsOneWidget);
        expect(find.text('推荐寄语'), findsOneWidget);
        expect(find.text('活动详情'), findsOneWidget);
        if (status == 'accepted') {
          expect(find.byType(OfflineCheckinPage), findsOneWidget);
        }
      }
      // Closing the detail returns to the same takeover conversation.
      if (status == 'pending' || status == 'ignored') {
        await tester.tap(find.byIcon(CupertinoIcons.xmark));
      } else if (status == 'completed') {
        await tester.ensureVisible(find.text('查看原始聊天'));
        await tester.tap(find.text('查看原始聊天'));
      } else {
        final context = tester.element(
          find.byType(
            status == 'completed' ? OfflineReviewPage : OfflineCheckinPage,
          ),
        );
        Navigator.of(context).pop();
      }
      await takeover.drain(tester);
      expect(find.text('我的用户'), findsOneWidget);
      expect(api.sends, isEmpty);
      expect(api.writes, isEmpty);
      // Let the chat's two-second message highlight finish before teardown.
      if (status == 'completed') await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await takeover.drain(tester);
    });
  }

  testWidgets(
    'takeover detail access failure is visible and leaves chat usable',
    (tester) async {
      final api = ReadOnlyApi('pending')..fail = true;
      await takeover.chat(tester, api);
      await tester.tap(find.text('公园走走'));
      await takeover.drain(tester);
      expect(find.text('活动不存在或已无权查看'), findsOneWidget);
      expect(find.text('我的用户'), findsOneWidget);
      expect(api.detailReads, ['case/activity']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await takeover.drain(tester);
    },
  );

  for (final status in ['pending', 'ignored']) {
    testWidgets(
      'own user detail keeps $status actions even for an admin account',
      (tester) async {
        final api = journey.FakeApi(activity(status));
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => openOfflineActivityDetail(
                    context,
                    api: api,
                    session: takeover.adminSession(),
                    activity: activity(status),
                  ),
                  child: const Text('打开'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('打开'));
        await tester.pumpAndSettle();
        expect(
          find.text(status == 'pending' ? '想去看看' : '重新接受邀请'),
          findsOneWidget,
        );
        if (status == 'pending') expect(find.text('先放一放'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final scenario in [
    ('pending', '想去看看', 'accept'),
    ('ignored', '重新接受邀请', 'accept'),
    ('pending', '先放一放', 'ignore'),
  ]) {
    testWidgets('own activity ${scenario.$1} keeps ${scenario.$3} flow', (
      tester,
    ) async {
      final api = OwnActivityApi(scenario.$1);
      var changes = 0;
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
                  onChanged: () => changes++,
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(scenario.$2));
      await tester.tap(find.text(scenario.$2));
      await tester.pumpAndSettle();
      expect(api.responses, ['${scenario.$3}/activity']);
      if (scenario.$3 == 'accept') {
        expect(find.byType(OfflineCheckinPage), findsOneWidget);
        expect(find.text('我已经抵达这里'), findsOneWidget);
        expect(changes, 1);
      } else {
        expect(find.text('活动详情'), findsNothing);
        expect(find.byType(OfflineCheckinPage), findsNothing);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
