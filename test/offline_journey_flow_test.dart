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
  bool verified = false,
  String status = 'accepted',
  String description = '按自己的节奏看看湖边',
}) => OfflineActivity.fromJson({
  'id': 'activity',
  'status': status,
  'reached': reached,
  'arrival_verified': verified,
  'title': '莲湖公园走走',
  'summary': '沿湖慢慢走走',
  'description': description,
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
  Map<String, dynamic> reviewOverrides = {};
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
    DateTime? observedAt,
    bool manualConfirmation = false,
  }) async {
    arrived++;
    manual = manualConfirmation;
    current = activity(
      known: current.arrivalVerificationAvailable,
      reached: true,
      verified: !manualConfirmation,
    );
    return current;
  }

  @override
  Future<OfflineActivityReview> fetchOfflineActivityReview(String id) async =>
      OfflineActivityReview.fromJson({
        'id': id,
        'title': current.title,
        'image_urls': current.imageUrls,
        'cover_url': current.imageUrls.isEmpty ? null : current.imageUrls.first,
        'address': current.address,
        'story': '你确认到了莲湖公园，随后收好了这次旅途。还没有留下照片或感想。',
        'can_generate_memory_note': false,
        'has_memory_note': false,
        ...reviewOverrides,
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
  testWidgets('event detail displays the canonical session without midnight', (
    tester,
  ) async {
    final event = OfflineActivity.fromJson({
      'id': 'activity',
      'status': 'accepted',
      'title': '秋日市集',
      'location_name': '莲湖公园',
      'kind': 'event',
      'time_precision': 'date',
      'schedule_label': '2026/10/24—10/25 每日10:00—18:00',
    });
    await showCheckin(tester, FakeApi(event));
    expect(find.text('2026/10/24—10/25 每日10:00—18:00'), findsOneWidget);
    expect(find.textContaining('00:00'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review swipes all original photos even across title overlay', (
    tester,
  ) async {
    final api = FakeApi(activity(status: 'completed', reached: true))
      ..authToken = 'test'
      ..reviewOverrides = {
        'image_urls': [
          for (var i = 1; i <= 3; i++)
            'https://example.test/offline/media/place_$i.jpg',
        ],
        'gallery': ['https://example.test/offline/media/user.jpg'],
      };
    tester.view.physicalSize = const Size(390, 844);
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
    final pager = find.byType(PageView);
    for (var i = 1; i <= 3; i++) {
      expect(find.text('$i / 3'), findsOneWidget);
      expect(find.text('莲湖公园走走'), findsOneWidget);
      expect(find.text('📍 桥头镇莲湖路'), findsOneWidget);
      final photos = tester
          .widgetList<Image>(
            find.descendant(of: pager, matching: find.byType(Image)),
          )
          .map((image) => image.image as NetworkImage)
          .toList();
      expect(photos.any((image) => image.url.endsWith('place_$i.jpg')), isTrue);
      expect(
        photos.every(
          (image) => image.headers?['Authorization'] == 'Bearer test',
        ),
        isTrue,
      );
      expect(photos.every((image) => !image.url.endsWith('user.jpg')), isTrue);
      if (i < 3) {
        await tester.dragFrom(
          tester.getCenter(find.text('莲湖公园走走')),
          const Offset(-300, 0),
        );
        await tester.pumpAndSettle();
      }
    }
    await tester.drag(pager, const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('素材画廊'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final cover in <String?>[null, 'https://example.com/legacy.jpg']) {
    testWidgets('review supports legacy cover and empty album: $cover', (
      tester,
    ) async {
      final api = FakeApi(activity())
        ..reviewOverrides = {'image_urls': [], 'cover_url': cover};
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
      expect(find.text('莲湖公园走走'), findsOneWidget);
      expect(find.text('1 / 1'), findsNothing);
      expect(
        find.byType(PageView),
        cover == null ? findsNothing : findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

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

  testWidgets('arrival without place coordinates completes in one tap', (
    tester,
  ) async {
    final api = FakeApi(activity());
    await showCheckin(tester, api);
    await tester.tap(find.text('我已经抵达这里'));
    await tester.pumpAndSettle();
    expect(api.arrived, 1);
    expect(api.manual, isTrue);
    expect(api.current.arrivalVerified, isFalse);
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(find.text('已确认到达'), findsOneWidget);
    expect(find.text('收好这次旅途回忆'), findsOneWidget);
    expect(find.textContaining('手动'), findsNothing);
    expect(find.textContaining('核验'), findsNothing);
    expect(find.textContaining('坐标'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final verified in [false, true]) {
    testWidgets(
      'arrival status has the same copy regardless of verification: $verified',
      (tester) async {
        await showCheckin(
          tester,
          FakeApi(activity(reached: true, known: verified, verified: verified)),
        );
        expect(find.text('已确认到达'), findsOneWidget);
        expect(find.textContaining('手动'), findsNothing);
        expect(find.textContaining('定位'), findsNothing);
        expect(find.textContaining('核验'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('arrival button is unchanged when coordinates are available', (
    tester,
  ) async {
    await showCheckin(tester, FakeApi(activity(known: true)));
    expect(find.text('我已经抵达这里'), findsOneWidget);
    expect(find.textContaining('手动'), findsNothing);
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
    testWidgets(
      'first upward content swipe folds once per visit, reached=$reached',
      (tester) async {
        final api = FakeApi(
          activity(
            reached: reached,
            description: List.filled(20, '沿着湖边走走，看看树影和水面。').join('\n'),
          ),
        );
        await showCheckin(tester, api);
        final dock = find.byKey(const ValueKey('offlineActivityDock'));
        final handle = find.byKey(const ValueKey('offlineActivityDockHandle'));
        final body = find.byType(SingleChildScrollView).first;
        final expandedHeight = tester.getSize(dock).height;

        // Horizontal photos and a downward body swipe must not consume the rule.
        await tester.drag(find.byType(PageView), const Offset(-250, 0));
        await tester.pumpAndSettle();
        expect(find.text('2 / 3'), findsOneWidget);
        await tester.drag(body, const Offset(0, 100));
        await tester.pumpAndSettle();
        expect(tester.getSize(dock).height, closeTo(expandedHeight, 1));

        await tester.drag(body, const Offset(0, -100));
        await tester.pumpAndSettle();
        expect(tester.getSize(dock).height, closeTo(44, 1));
        expect(handle.hitTestable(), findsOneWidget);
        for (final dy in [100.0, -100.0, 100.0]) {
          await tester.drag(body, Offset(0, dy));
          await tester.pumpAndSettle();
          expect(tester.getSize(dock).height, closeTo(44, 1));
        }

        // Manual expansion stays open after the one automatic collapse.
        await tester.tap(handle);
        await tester.pumpAndSettle();
        for (final dy in [-100.0, 100.0]) {
          await tester.drag(body, Offset(0, dy));
          await tester.pumpAndSettle();
          expect(tester.getSize(dock).height, closeTo(expandedHeight, 1));
        }
        expect(api.arrived, 0);
        expect(api.deleted, 0);
        expect(tester.takeException(), isNull);

        // A newly mounted visit starts expanded and gets its own first swipe.
        await tester.pumpWidget(const SizedBox());
        await showCheckin(tester, api);
        expect(tester.getSize(dock).height, closeTo(expandedHeight, 1));
        await tester.drag(body, const Offset(0, -100));
        await tester.pumpAndSettle();
        expect(tester.getSize(dock).height, closeTo(44, 1));
        expect(tester.takeException(), isNull);
      },
    );

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
      final action = find.text(reached ? '收好这次旅途回忆' : '我已经抵达这里');
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
    await tester.drag(find.text('我已经抵达这里'), Offset(0, originalHeight));
    await tester.pumpAndSettle();
    expect(tester.getSize(dock).height, closeTo(44, 1));
    expect(api.arrived, 0);
    expect(find.text('确认记录'), findsNothing);
    await tester.tap(handle);
    await tester.pumpAndSettle();
    expect(tester.getSize(dock).height, closeTo(originalHeight, 1));
    await tester.tap(find.text('我已经抵达这里'));
    await tester.pumpAndSettle();
    expect(api.arrived, 1);
    expect(find.text('已确认到达'), findsOneWidget);
    expect(find.byType(CupertinoAlertDialog), findsNothing);
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
