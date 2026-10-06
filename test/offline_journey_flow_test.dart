import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:companion_flutter/offline_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

const session = AuthSession(
  token: 'test',
  userId: 'user',
  username: 'tester',
  role: UserRole.user,
  hasAgent: true,
);

OfflineActivity activity({
  bool known = false,
  bool reached = false,
  String status = 'accepted',
}) => OfflineActivity.fromJson({
  'id': 'activity',
  'status': status,
  'reached': reached,
  'title': '莲湖公园走走',
  'summary': '沿湖慢慢走走',
  'description': '按自己的节奏看看湖边',
  'location_name': '莲湖公园',
  'address': '桥头镇莲湖路',
  'official_url': 'https://example.com/place',
  'image_urls': [
    'https://example.com/1.jpg',
    'https://example.com/2.jpg',
    'https://example.com/3.jpg',
  ],
  'arrival_verification_available': known,
});

class FakeApi extends CompanionApi {
  FakeApi(this.current) : super(baseUrl: 'https://example.test');
  OfflineActivity current;
  int arrived = 0;
  int deleted = 0;
  bool? manual;
  @override
  Future<OfflineActivity> fetchOfflineActivity(String id) async => current;
  @override
  Future<void> deleteOfflineActivity(String id) async {
    deleted++;
  }

  @override
  Future<OfflineActivity> arriveOfflineActivity(
    String id, {
    double? lat,
    double? lng,
    double? accuracyMeters,
    bool manualConfirmation = false,
  }) async {
    arrived++;
    manual = manualConfirmation;
    return current;
  }

  @override
  Future<OfflineActivityReview> fetchOfflineActivityReview(String id) async =>
      OfflineActivityReview.fromJson({
        'id': id,
        'title': current.title,
        'story': '你确认到了莲湖公园，随后收好了这次旅途。还没有留下照片或感想。',
        'can_generate_memory_note': false,
        'has_memory_note': false,
      });
}

Future<void> showCheckin(WidgetTester tester, FakeApi api) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: OfflineCheckinPage(
        api: api,
        session: session,
        activityId: 'activity',
        onNavigateToChat: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'detail shows full gallery and recommendation without source actions',
    (tester) async {
      final api = FakeApi(activity());
      await showCheckin(tester, api);
      expect(find.text('莲湖公园走走'), findsOneWidget);
      expect(find.text('沿湖慢慢走走'), findsOneWidget);
      expect(find.text('按自己的节奏看看湖边'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
      await tester.drag(
        find.byType(PageView),
        Offset(-tester.getSize(find.byType(PageView)).width * .8, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('查看来源'), findsNothing);
      expect(find.text('复制链接'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unverified arrival requires an explicit confirmation', (
    tester,
  ) async {
    final api = FakeApi(activity());
    await showCheckin(tester, api);
    await tester.tap(find.text('手动记录到达'));
    await tester.pumpAndSettle();
    expect(api.arrived, 0);
    expect(find.textContaining('不代表定位'), findsNothing);
    expect(find.textContaining('无法核验距离'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(api.arrived, 0);
    await tester.tap(find.text('手动记录到达'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认记录'));
    await tester.pumpAndSettle();
    expect(api.arrived, 1);
    expect(api.manual, isTrue);
  });

  testWidgets('pending departure can be deleted after confirmation', (
    tester,
  ) async {
    final api = FakeApi(activity());
    await showCheckin(tester, api);
    final guide = tester.getCenter(find.text('出门小说明'));
    final separator = tester.getCenter(find.text('｜'));
    final deletion = tester.getCenter(find.text('删除该活动'));
    expect(guide.dy, closeTo(deletion.dy, 1));
    expect(guide.dx, lessThan(separator.dx));
    expect(separator.dx, lessThan(deletion.dx));
    await tester.tap(find.text('删除该活动'));
    await tester.pumpAndSettle();
    expect(api.deleted, 0);
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '删除'));
    await tester.pumpAndSettle();
    expect(api.deleted, 1);
  });

  for (final reached in [false, true]) {
    testWidgets('dock drags to a visible peek and expands, reached=$reached', (
      tester,
    ) async {
      final api = FakeApi(activity(reached: reached));
      await showCheckin(tester, api);
      tester.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.resetPadding);
      await tester.pumpAndSettle();
      final dock = find.byKey(const ValueKey('offlineActivityDock'));
      final handle = find.byKey(const ValueKey('offlineActivityDockHandle'));
      final grip = find.byKey(const ValueKey('offlineActivityDockGrip'));
      final action = find.text(reached ? '收好这次旅途回忆' : '手动记录到达');
      final originalHeight = tester.getSize(dock).height;
      final expandedColor =
          (tester.widget<Container>(grip).decoration! as BoxDecoration).color!;
      expect(action.hitTestable(), findsOneWidget);

      await tester.drag(handle, Offset(0, originalHeight));
      await tester.pumpAndSettle();
      expect(tester.getSize(dock).height, closeTo(44 + 34, 1));
      expect(handle.hitTestable(), findsOneWidget);
      expect(action.hitTestable(), findsNothing);
      expect(find.text('删除该活动').hitTestable(), findsNothing);
      final collapsedColor =
          (tester.widget<Container>(grip).decoration! as BoxDecoration).color!;
      expect(collapsedColor.a, lessThan(expandedColor.a));
      expect(api.arrived, 0);
      expect(api.deleted, 0);

      // The content above stays scrollable while the dock is folded away.
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(dock).height, closeTo(78, 1));
      await tester.drag(handle, Offset(0, -originalHeight));
      await tester.pumpAndSettle();
      expect(tester.getSize(dock).height, closeTo(originalHeight, 1));
      expect(action.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('dock settles after a short drag and handle can toggle it', (
    tester,
  ) async {
    final api = FakeApi(activity());
    await showCheckin(tester, api);
    final dock = find.byKey(const ValueKey('offlineActivityDock'));
    final handle = find.byKey(const ValueKey('offlineActivityDockHandle'));
    final originalHeight = tester.getSize(dock).height;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getSize(dock).height, closeTo(originalHeight, 1));

    // Dragging from a button must move the sheet, without triggering arrival.
    await tester.drag(find.text('手动记录到达'), Offset(0, originalHeight));
    await tester.pumpAndSettle();
    expect(tester.getSize(dock).height, closeTo(44, 1));
    expect(api.arrived, 0);
    expect(find.text('确认记录'), findsNothing);
    await tester.tap(handle);
    await tester.pumpAndSettle();
    expect(tester.getSize(dock).height, closeTo(originalHeight, 1));
    await tester.tap(find.text('手动记录到达'));
    await tester.pumpAndSettle();
    expect(find.text('确认记录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('arrival-only review cannot generate an invented notebook', (
    tester,
  ) async {
    final api = FakeApi(activity());
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: OfflineReviewPage(
          api: api,
          session: session,
          activityId: 'activity',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('还没有留下照片'), findsOneWidget);
    expect(find.text('暂无可整理的旅途内容'), findsOneWidget);
    expect(find.text('生成记忆手札'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
