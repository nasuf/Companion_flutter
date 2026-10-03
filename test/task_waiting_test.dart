import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:companion_flutter/models.dart';
import 'package:companion_flutter/task_waiting.dart';
import 'package:companion_flutter/src/widgets/chat/task_waiting_card.dart';

void main() {
  final now = DateTime.utc(2026, 10, 2);
  WsEnvelope wait([Map<String, dynamic> extra = const {}]) => WsEnvelope(
    type: 'task_waiting',
    data: {
      'agent_run_id': 'run',
      'event_sequence': 10,
      'pending_action_id': 'pending',
      'revision': 2,
      'run_status': 'waiting',
      'actionable': true,
      'expires_at': '2026-10-03T00:00:00Z',
      'question': '日期？',
      ...extra,
    },
  );
  test(
    'late waiting cannot revive resumed work; expired or malformed confirmations stay inactive',
    () {
      final waiting = taskEvent(null, wait(), now: now);
      expect(waiting!.waiting!.pendingId, 'pending');
      final resumed = taskEvent(
        waiting,
        const WsEnvelope(
          type: 'task_state',
          data: {
            'agent_run_id': 'run',
            'event_sequence': 11,
            'status': 'queued',
          },
        ),
        now: now,
      );
      expect(resumed!.waiting, isNull);
      expect(taskEvent(resumed, wait(), now: now), same(resumed));
      for (final extra in [
        <String, dynamic>{'actionable': false},
        {'expires_at': 'invalid'},
        {'expires_at': '2026-10-01T00:00:00Z'},
        {'revision': 0},
        {'revision': 1.5},
        {'cancel_requested': true},
        {'run_status': 'queued'},
      ]) {
        expect(taskEvent(null, wait(extra), now: now)!.waiting, isNull);
      }
    },
  );

  WaitingTask task({String? preview, DateTime? expiresAt, int revision = 2}) =>
      WaitingTask(
        runId: 'run',
        pendingId: 'pending',
        revision: revision,
        sequence: 10,
        expiresAt: expiresAt ?? DateTime.now().add(const Duration(minutes: 1)),
        question: '补充信息',
        preview: preview,
      );

  testWidgets(
    'confirmation shows the grounded action and blocks duplicate submission until the ACK',
    (tester) async {
      final pending = task(preview: '接受活动“散步”。');
      final gate = Completer<void>();
      final responses = <Map<String, dynamic>>[];
      var accepted = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskWaitingCard(
              task: pending,
              resume: (actual, response) {
                expect(actual.pendingId, 'pending');
                expect(actual.revision, 2);
                responses.add(response);
                return gate.future;
              },
              cancel: (_) async {},
              onAccepted: (_) => accepted++,
            ),
          ),
        ),
      );
      expect(find.text('接受活动“散步”。'), findsOneWidget);
      await tester.tap(find.text('确认操作'));
      await tester.pump();
      await tester.tap(find.text('提交中…'));
      await tester.pump();
      expect(responses, [
        {'approved': true},
      ]);
      expect(accepted, 0);
      gate.complete();
      await tester.pump();
      expect(accepted, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'supplemental text never grants implicit approval and a lost reply remains retryable',
    (tester) async {
      final pending = task();
      final responses = <Map<String, dynamic>>[];
      var accepted = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskWaitingCard(
              task: pending,
              resume: (_, response) async {
                responses.add(response);
                throw StateError('网络失败');
              },
              cancel: (_) async {},
              onAccepted: (_) => accepted++,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), ' 明天 ');
      await tester.pump();
      await tester.tap(find.text('继续'));
      await tester.pump();
      expect(responses, [
        {'text': '明天'},
      ]);
      expect(accepted, 0);
      expect(find.textContaining('网络失败'), findsOneWidget);
      await tester.tap(find.text('继续'));
      await tester.pump();
      expect(responses.length, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('an expired confirmation exposes no approval button', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskWaitingCard(
            task: task(
              preview: '更新提醒备注。',
              expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
            ),
            resume: (_, __) async => fail('expired action'),
            cancel: (_) async {},
            onAccepted: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('确认操作'), findsNothing);
    expect(find.textContaining('这项确认已过期'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  test('a confirmed wait cannot be revived by the same sequence', () {
    const accepted = TaskViewState(10);
    expect(taskEvent(accepted, wait(), now: now), same(accepted));
    expect(taskEvent(null, wait({'agent_run_id': ''}), now: now), isNull);
  });

  testWidgets(
    'a late confirmation response cannot accept a replacement revision',
    (tester) async {
      final gate = Completer<void>();
      final accepted = <int>[];
      Widget card(int revision) => MaterialApp(
        home: Scaffold(
          body: TaskWaitingCard(
            task: task(preview: '修订 $revision', revision: revision),
            resume: (_, response) => gate.future,
            cancel: (_) async {},
            onAccepted: (value) => accepted.add(value.revision),
          ),
        ),
      );
      await tester.pumpWidget(card(2));
      await tester.tap(find.text('确认操作'));
      await tester.pump();
      await tester.pumpWidget(card(3));
      expect(find.text('修订 3'), findsOneWidget);
      expect(find.text('确认操作'), findsOneWidget);
      gate.complete();
      await tester.pump();
      expect(accepted, isEmpty);
      expect(find.text('修订 3'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('a confirmation becomes unavailable when its timer expires', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskWaitingCard(
            task: task(
              preview: '等待确认',
              expiresAt: DateTime.now().add(const Duration(seconds: 1)),
            ),
            resume: (_, response) async => fail('expired submission'),
            cancel: (_) async {},
            onAccepted: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('确认操作'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('确认操作'), findsNothing);
    expect(find.textContaining('这项确认已过期'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
