import 'dart:async';

import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/models.dart';
import 'package:companion_flutter/offline_models.dart';
import 'package:companion_flutter/takeover_inbox.dart';
import 'package:companion_flutter/takeover_unread.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'takeover_flow_test.dart' as takeover;
import 'takeover_activity_detail_test.dart' as detail;

class GeneratingApi extends detail.ReadOnlyApi {
  GeneratingApi() : super('pending') {
    generatedHistory = scriptedHistory!;
    scriptedHistory = [];
  }
  late final List<ChatMessage> generatedHistory;
  int generationCalls = 0;
  int historyLoads = 0;
  bool failGeneration = false;
  Completer<void>? gate;

  @override
  Future<List<ChatMessage>> loadMessages(
    String id, {
    int limit = 100,
    int offset = 0,
  }) {
    historyLoads++;
    return super.loadMessages(id, limit: limit, offset: offset);
  }

  @override
  Future<OfflineActivity> createTakeoverActivityRecommendation(
    String takeoverId,
  ) async {
    expect(takeoverId, 'case');
    generationCalls++;
    await gate?.future;
    if (failGeneration) throw const ApiException(503, '暂时没找到合适的新去处');
    scriptedHistory = generatedHistory;
    return detail.activity('pending');
  }

  @override
  Future<List<TakeoverActivityPreview>> previewTakeoverActivities(String id) =>
      throw StateError('The sparse preview flow must not run');
  @override
  Future<void> publishTakeoverActivity(String id, String previewId) =>
      throw StateError('The sparse preview publication must not run');
}

Future<void> generate(WidgetTester tester) async {
  await tester.tap(find.byTooltip('更多'));
  await takeover.drain(tester);
  await tester.tap(find.text('活动'));
}

void main() {
  tearDown(() async {
    TakeoverUnreadController.instance.clear();
    await TakeoverInbox.instance.stop();
  });

  testWidgets(
    'activity action generates and sends directly, then opens full read-only detail',
    (tester) async {
      final api = GeneratingApi()..gate = Completer<void>();
      await takeover.chat(tester, api);
      final loadsBefore = api.historyLoads;
      await tester.tap(find.byTooltip('更多'));
      await takeover.drain(tester);
      // Rapid taps share one operation, even before the modal paints.
      final action = tester
          .widget<GestureDetector>(
            find
                .ancestor(
                  of: find.text('活动'),
                  matching: find.byType(GestureDetector),
                )
                .first,
          )
          .onTap!;
      action();
      action();
      await takeover.drain(tester);
      expect(api.generationCalls, 1);
      expect(find.text('正在为用户生成并发送活动…'), findsOneWidget);
      expect(find.text('推送给用户'), findsNothing);
      expect(find.text('公园走走'), findsNothing);
      // Generation remains open when the platform back action is attempted.
      final context = tester.element(find.text('正在为用户生成并发送活动…'));
      await Navigator.of(context).maybePop();
      await takeover.drain(tester);
      expect(find.text('正在为用户生成并发送活动…'), findsOneWidget);
      api.gate!.complete();
      await takeover.drain(tester);
      expect(find.text('正在为用户生成并发送活动…'), findsNothing);
      expect(api.historyLoads, greaterThan(loadsBefore));
      expect(find.text('公园走走'), findsOneWidget);
      await tester.tap(find.text('公园走走'));
      await takeover.drain(tester);
      expect(find.text('推荐寄语'), findsOneWidget);
      expect(find.text('详细地点介绍'), findsOneWidget);
      detail.expectReadOnly();
      expect(api.writes, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await takeover.drain(tester);
    },
  );

  testWidgets('generation failure shows its reason and only retries on a tap', (
    tester,
  ) async {
    final api = GeneratingApi()..failGeneration = true;
    await takeover.chat(tester, api);
    await generate(tester);
    await takeover.drain(tester);
    expect(api.generationCalls, 1);
    expect(find.text('暂时没找到合适的新去处'), findsOneWidget);
    expect(find.text('公园走走'), findsNothing);
    api.failGeneration = false;
    await tester.tap(find.text('重试'));
    await takeover.drain(tester);
    expect(api.generationCalls, 2);
    expect(find.text('公园走走'), findsOneWidget);
    expect(find.text('重试'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await takeover.drain(tester);
  });
}
