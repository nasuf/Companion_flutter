import 'dart:async';

import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/models.dart';
import 'package:companion_flutter/offline_models.dart';
import 'package:companion_flutter/takeover_inbox.dart';
import 'package:companion_flutter/takeover_unread.dart';
import 'package:flutter/cupertino.dart';
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

  final published = <String>[];
  @override
  Future<OfflineActivity> createTakeoverActivityRecommendation(String id) =>
      throw StateError('The automatic single-invitation flow must not run');
  @override
  Future<List<TakeoverActivityPreview>> previewTakeoverActivities(
    String id,
  ) async {
    generationCalls++;
    await gate?.future;
    if (failGeneration) throw const ApiException(503, '暂时没找到合适的新去处');
    return [
      for (var i = 0; i < 5; i++)
        TakeoverActivityPreview.fromJson({
          'id': 'preview-$i',
          'preview_id': 'preview-$i',
          'status': 'pending',
          'title': '候选活动$i',
          'summary': '候选摘要$i',
          'description': '详细地点介绍$i',
          'recommendation_message': '推荐寄语$i',
          'location_name': '地点$i',
          'image_urls': <String>[],
        }),
    ];
  }

  @override
  Future<void> publishTakeoverActivity(String id, String previewId) async {
    published.add(previewId);
    scriptedHistory = generatedHistory;
  }
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
    'full-width 72 percent sheet previews five complete candidates and only publishes a choice',
    (tester) async {
      final api = GeneratingApi()..gate = Completer<void>();
      await takeover.chat(tester, api);
      await generate(tester);
      await takeover.drain(tester);
      final sheet = find.byKey(const ValueKey('takeover-activity-sheet'));
      expect(tester.getSize(sheet).width, closeTo(390, 1));
      expect(tester.getSize(sheet).height, closeTo(844 * .72, 1));
      expect(tester.getBottomLeft(sheet).dy, closeTo(844, 1));
      expect(api.published, isEmpty);
      api.gate!.complete();
      await takeover.drain(tester);
      for (var i = 0; i < 5; i++) {
        expect(find.text('候选活动$i'), findsOneWidget);
      }
      expect(api.published, isEmpty);
      await tester.tap(find.text('候选活动2'));
      await takeover.drain(tester);
      expect(find.text('推荐寄语2'), findsOneWidget);
      expect(find.text('详细地点介绍2'), findsOneWidget);
      expect(find.text('想去看看'), findsNothing);
      expect(find.text('先放一放'), findsNothing);
      expect(api.published, isEmpty);
      final push = find.text('推送给用户');
      await tester.ensureVisible(push);
      await takeover.drain(tester);
      await tester.tap(push);
      await takeover.drain(tester);
      expect(api.published, ['preview-2']);
      expect(sheet, findsNothing);
      expect(find.text('公园走走'), findsOneWidget);
      await tester.tap(find.text('公园走走'));
      await takeover.drain(tester);
      detail.expectReadOnly();
      expect(api.writes, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await takeover.drain(tester);
    },
  );

  testWidgets('closing or refreshing candidates never sends an invitation', (
    tester,
  ) async {
    final api = GeneratingApi();
    await takeover.chat(tester, api);
    await generate(tester);
    await takeover.drain(tester);
    await tester.tap(find.byIcon(CupertinoIcons.refresh));
    await takeover.drain(tester);
    expect(api.generationCalls, 2);
    expect(api.published, isEmpty);
    await tester.tap(find.byTooltip('关闭活动推荐'));
    await takeover.drain(tester);
    expect(find.byKey(const ValueKey('takeover-activity-sheet')), findsNothing);
    expect(api.published, isEmpty);
    expect(find.text('公园走走'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'generation failure retains the full sheet and retries only on a tap',
    (tester) async {
      final api = GeneratingApi()..failGeneration = true;
      await takeover.chat(tester, api);
      await generate(tester);
      await takeover.drain(tester);
      expect(api.generationCalls, 1);
      expect(find.text('暂时没找到合适的新去处'), findsOneWidget);
      expect(api.published, isEmpty);
      api.failGeneration = false;
      await tester.tap(find.text('重试'));
      await takeover.drain(tester);
      expect(api.generationCalls, 2);
      expect(find.text('候选活动0'), findsOneWidget);
      expect(api.published, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
