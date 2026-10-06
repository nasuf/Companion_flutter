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

OfflineActivity activity({bool known = false, String status = 'accepted'}) =>
    OfflineActivity.fromJson({
      'id': 'activity',
      'status': status,
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
