import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _session = AuthSession(
  token: 'test-token',
  userId: 'user-1',
  username: 'tester',
  role: UserRole.user,
  hasAgent: true,
  agentId: 'agent-1',
  agentName: '小芜',
  workspaceId: 'ws-1',
  conversationId: 'conv-1',
);

WorkspaceInteractionOverview _overview({
  int streak = 0,
  int cards = 2,
  bool todayMarked = false,
  List<WorkspaceInteractionDay>? days,
}) {
  return WorkspaceInteractionOverview(
    currentStreak: streak,
    today: '2026-09-16',
    todayMarked: todayMarked,
    makeupCards: cards,
    lookbackDays: 30,
    workspaceCreatedOn: '2026-08-01',
    month: '2026-09',
    days:
        days ??
        const [
          WorkspaceInteractionDay(date: '2026-09-15', makeupEligible: true),
          WorkspaceInteractionDay(date: '2026-09-16', makeupEligible: false),
        ],
  );
}

class _FakeInteractionApi extends CompanionApi {
  _FakeInteractionApi(this.overview) : super(baseUrl: 'https://example.test') {
    authToken = 'test-token';
  }

  WorkspaceInteractionOverview overview;
  String? makeupDate;
  ApiException? makeupError;

  @override
  Future<WorkspaceInteractionOverview> getWorkspaceInteraction(
    String workspaceId, {
    int? year,
    int? month,
  }) async {
    return overview;
  }

  @override
  Future<void> applyWorkspaceInteractionMakeup(
    String workspaceId, {
    required String date,
  }) async {
    if (makeupError != null) throw makeupError!;
    makeupDate = date;
    overview = WorkspaceInteractionOverview(
      currentStreak: 2,
      today: overview.today,
      todayMarked: overview.todayMarked,
      makeupCards: overview.makeupCards - 1,
      lookbackDays: overview.lookbackDays,
      workspaceCreatedOn: overview.workspaceCreatedOn,
      month: overview.month,
      days: [
        for (final day in overview.days)
          if (day.date == date)
            WorkspaceInteractionDay(
              date: date,
              source: 'makeup',
              makeupEligible: false,
            )
          else
            day,
      ],
    );
  }
}

void _usePhoneCanvas(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double topInset = 0,
  double bottomInset = 0,
}) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  tester.view.padding = FakeViewPadding(top: topInset, bottom: bottomInset);
  tester.view.viewPadding = FakeViewPadding(top: topInset, bottom: bottomInset);
  addTearDown(tester.view.reset);
}

Widget _app(_FakeInteractionApi api) {
  return MaterialApp(
    home: InteractionStreakPage(
      api: api,
      session: _session,
      workspaceId: 'ws-1',
      agentAvatarUrl: null,
      userAvatarUrl: null,
    ),
  );
}

void main() {
  test('interactionFlameStage matches the badge ranges', () {
    expect(interactionFlameStage(0), 0);
    expect(interactionFlameStage(7), 0);
    expect(interactionFlameStage(8), 1);
    expect(interactionFlameStage(31), 2);
    expect(interactionFlameStage(32), 3);
    expect(interactionFlameStage(60), 3);
    expect(interactionFlameStage(61), 4);
  });

  test('interactionUtc8Date folds UTC midnight into Shanghai', () {
    expect(
      interactionUtc8Date(DateTime.utc(2026, 9, 16, 3)),
      DateTime(2026, 9, 16),
    );
    expect(
      interactionUtc8Date(DateTime.utc(2026, 9, 15, 17)),
      DateTime(2026, 9, 16),
    );
  });

  testWidgets('shows consecutive copy, zero days, and the glass back button', (
    tester,
  ) async {
    _usePhoneCanvas(tester);
    await tester.pumpWidget(_app(_FakeInteractionApi(_overview(streak: 0))));
    await tester.pumpAndSettle();

    expect(find.text('已互动'), findsNothing);
    expect(find.text('连续互动'), findsWidgets);
    expect(find.text('0'), findsOneWidget);
    expect(find.byKey(const Key('interaction-back')), findsOneWidget);
    expect(find.byKey(const Key('interaction-calendar')), findsOneWidget);
    expect(find.text('32-60天'), findsOneWidget);
    expect(find.text('31-60天'), findsNothing);
    expect(find.text('连续互动标识'), findsOneWidget);
    expect(find.text('补签卡 x2'), findsOneWidget);
  });

  testWidgets('collapsed layout fits a notched phone without scrolling', (
    tester,
  ) async {
    _usePhoneCanvas(tester, topInset: 59, bottomInset: 34);
    await tester.pumpWidget(
      _app(_FakeInteractionApi(_overview(streak: 3, cards: 2))),
    );
    await tester.pumpAndSettle();

    expect(find.text('连续互动标识'), findsOneWidget);
    expect(find.text('100天以上'), findsOneWidget);
    expect(find.text('补签卡 x2'), findsOneWidget);
    expect(find.text('32-60天'), findsOneWidget);

    final list = tester.widget<ListView>(
      find.byKey(const Key('interaction-scroll')),
    );
    expect(list.physics, isA<NeverScrollableScrollPhysics>());
  });

  testWidgets('collapsed layout fits a short phone without scrolling', (
    tester,
  ) async {
    _usePhoneCanvas(
      tester,
      size: const Size(375, 667),
      topInset: 20,
      bottomInset: 0,
    );
    await tester.pumpWidget(
      _app(_FakeInteractionApi(_overview(streak: 0, cards: 0))),
    );
    await tester.pumpAndSettle();

    expect(find.text('连续互动标识'), findsOneWidget);
    expect(find.text('补签卡 x0'), findsOneWidget);
    final list = tester.widget<ListView>(
      find.byKey(const Key('interaction-scroll')),
    );
    expect(list.physics, isA<NeverScrollableScrollPhysics>());
  });

  testWidgets('expanded calendar scrolls instead of compressing the marks card', (
    tester,
  ) async {
    _usePhoneCanvas(tester, topInset: 59, bottomInset: 34);
    await tester.pumpWidget(
      _app(_FakeInteractionApi(_overview(streak: 9, cards: 34))),
    );
    await tester.pumpAndSettle();

    final collapsedList = tester.widget<ListView>(
      find.byKey(const Key('interaction-scroll')),
    );
    expect(collapsedList.physics, isA<NeverScrollableScrollPhysics>());

    await tester.drag(find.byKey(const Key('interaction-calendar')), const Offset(0, 180));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final expandedList = tester.widget<ListView>(
      find.byKey(const Key('interaction-scroll')),
    );
    expect(expandedList.physics, isA<BouncingScrollPhysics>());
    expect(find.text('100天以上'), findsOneWidget);
  });

  testWidgets('tapping a missable day confirms and consumes a makeup card', (
    tester,
  ) async {
    _usePhoneCanvas(tester);
    final api = _FakeInteractionApi(_overview(streak: 0, cards: 2));
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('interaction-week-day-2026-09-15')));
    await tester.pumpAndSettle();

    expect(find.text('使用 1 张补签卡补签 9月15日？'), findsOneWidget);
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '补签'));
    await tester.pumpAndSettle();

    expect(api.makeupDate, '2026-09-15');
    expect(find.text('补签卡 x1', skipOffstage: false), findsOneWidget);
  });

  testWidgets('zero makeup cards on a gap opens the store prompt', (
    tester,
  ) async {
    _usePhoneCanvas(tester);
    await tester.pumpWidget(
      _app(_FakeInteractionApi(_overview(streak: 0, cards: 0))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('interaction-week-day-2026-09-15')));
    await tester.pumpAndSettle();

    expect(find.text('暂无补签卡'), findsOneWidget);
    expect(find.text('补签卡已用完，可前往商城购买补签卡礼包。'), findsOneWidget);
  });

  testWidgets('confirming store prompt opens the bundle tab', (tester) async {
    _usePhoneCanvas(
      tester,
      size: const Size(390, 844),
    );
    await tester.pumpWidget(
      _app(_FakeInteractionApi(_overview(streak: 0, cards: 0))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('interaction-week-day-2026-09-15')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '去商城'));
    await tester.pumpAndSettle();

    expect(find.byType(StorePage), findsOneWidget);
    final store = tester.widget<StorePage>(find.byType(StorePage));
    expect(store.openBundle, isTrue);
    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.controller!.initialPage, 1);
  });

  testWidgets('dark mode streak labels stay light', (tester) async {
    _usePhoneCanvas(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: InteractionStreakPage(
          api: _FakeInteractionApi(_overview(streak: 0)),
          session: _session,
          workspaceId: 'ws-1',
          agentAvatarUrl: null,
          userAvatarUrl: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in ['连续互动', '天', '0-7天', '连续互动标识']) {
      final texts = tester.widgetList<Text>(find.text(label));
      expect(texts, isNotEmpty, reason: label);
      for (final text in texts) {
        final color = text.style?.color;
        expect(color, isNotNull, reason: label);
        expect(color!.computeLuminance(), greaterThan(0.55), reason: label);
      }
    }
    final idle = tester.widget<Text>(find.text('8-15天'));
    final idleLum = idle.style!.color!.computeLuminance();
    expect(idleLum, greaterThan(0.2));
    expect(idleLum, lessThan(0.55));
  });
}
