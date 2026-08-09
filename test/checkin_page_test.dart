import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The check-in screens are a 1:1 build of a 390x844 Figma frame, so the test
/// pins that canvas and asserts the block offsets the design specifies. Golden
/// images would be a better fit but the calendar renders the real current date,
/// which would make them expire overnight.
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

const double _safeTop = 47;
const double _safeBottom = 34;
const double _canvasWidth = 390;
const double _canvasHeight = 844;

DateTime get _today {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

ReminderItem _once(String id, String summary, {bool done = false}) {
  final trigger = _today.add(const Duration(hours: 21));
  return ReminderItem(
    id: id,
    summary: summary,
    triggerTime: trigger,
    recurrence: 'once',
    status: 'active',
    agentId: 'agent-1',
    createdAt: _today.subtract(const Duration(days: 3)),
    completedAt: done ? trigger : null,
  );
}

ReminderItem _habit(String id, String summary, List<int> weekdays) {
  return ReminderItem(
    id: id,
    summary: summary,
    triggerTime: _today.add(const Duration(hours: 8)),
    recurrence: 'weekly',
    status: 'active',
    agentId: 'agent-1',
    createdAt: _today.subtract(const Duration(days: 10)),
    habitWeekdays: weekdays,
  );
}

class _FakeReminderApi extends CompanionApi {
  _FakeReminderApi(this.items) : super(baseUrl: 'https://example.test') {
    authToken = 'test-token';
  }

  final List<ReminderItem> items;
  String? createdSummary;
  String? createdNote;
  String? createdRecurrence;

  @override
  Future<RemindersResponse> listReminders({
    required String userId,
    String? agentId,
    String status = 'active',
    int limit = 200,
    int offset = 0,
  }) async => RemindersResponse(items: items, total: items.length, dlqCount: 0);

  @override
  Future<ReminderItem> createReminder({
    required String agentId,
    required String summary,
    required DateTime triggerTime,
    String? note,
    String recurrence = 'once',
    List<int>? habitWeekdays,
    bool sentToAi = false,
    String? workspaceId,
    String? conversationId,
  }) async {
    createdSummary = summary;
    createdNote = note;
    createdRecurrence = recurrence;
    return ReminderItem(
      id: 'new',
      summary: summary,
      note: (note ?? '').isEmpty ? null : note,
      triggerTime: triggerTime,
      recurrence: recurrence,
      status: 'active',
      agentId: agentId,
      createdAt: DateTime.now(),
      habitWeekdays: habitWeekdays ?? const [],
    );
  }
}

void _useDesignCanvas(WidgetTester tester, {double keyboard = 0}) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(_canvasWidth, _canvasHeight);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  tester.view.padding = const FakeViewPadding(
    top: _safeTop,
    bottom: _safeBottom,
  );
  addTearDown(tester.view.reset);
}

Widget _app(CompanionApi api) => MaterialApp(
  debugShowCheckedModeBanner: false,
  home: CheckinPage(api: api, session: _session),
);

Future<void> _openEditor(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('checkin-fab')));
  await tester.pumpAndSettle();
}

void main() {
  group('check-in home', () {
    testWidgets('blocks land on the Figma offsets', (tester) async {
      _useDesignCanvas(tester);

      await tester.pumpWidget(_app(_FakeReminderApi([_once('a', '阅读30分钟')])));
      await tester.pumpAndSettle();

      final calendar = tester.getRect(find.byKey(const Key('checkin-calendar')));
      expect(calendar.top, 115);
      expect(calendar.height, 164);
      expect(calendar.left, 16);
      expect(calendar.right, _canvasWidth - 16);

      // Section title at 315, list 24 + 16 below it.
      expect(tester.getRect(find.text('今日任务')).top, 315);
      final row = tester.getRect(find.byKey(const Key('checkin-task-a')));
      expect(row.top, 355);
      expect(row.height, 75);

      final fab = tester.getRect(find.byKey(const Key('checkin-fab')));
      expect(fab.left, 318);
      expect(fab.top, 730);
      expect(fab.width, 56);

      expect(find.text('阅读30分钟'), findsOneWidget);
      expect(find.text('单次计划'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a habit row is labelled with its weekdays', (tester) async {
      _useDesignCanvas(tester);
      // Whatever today is, the habit repeats on it.
      final habit = _habit('h', '晨跑', [_today.weekday]);

      await tester.pumpWidget(_app(_FakeReminderApi([habit])));
      await tester.pumpAndSettle();

      const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      expect(find.text('晨跑'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('checkin-task-h')),
          matching: find.text(labels[_today.weekday - 1]),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty day shows the placeholder card', (tester) async {
      _useDesignCanvas(tester);

      await tester.pumpWidget(_app(_FakeReminderApi(const [])));
      await tester.pumpAndSettle();

      expect(find.text('这一天没有打卡任务'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dark mode renders the same layout', (tester) async {
      _useDesignCanvas(tester);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: CheckinPage(
            api: _FakeReminderApi([_once('a', '阅读30分钟')]),
            session: _session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getRect(find.byKey(const Key('checkin-calendar'))).top, 115);
      expect(tester.getRect(find.byKey(const Key('checkin-task-a'))).top, 355);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dragging the handle opens the month grid', (tester) async {
      _useDesignCanvas(tester);

      await tester.pumpWidget(_app(_FakeReminderApi(const [])));
      await tester.pumpAndSettle();

      // The handle is the bottom strip of the collapsed card (115 + 164).
      await tester.dragFrom(const Offset(195, 268), const Offset(0, 200));
      await tester.pumpAndSettle();

      final calendar = tester.getRect(find.byKey(const Key('checkin-calendar')));
      // Five- and six-row months differ; both are taller than the strip.
      expect(calendar.height, greaterThan(_kCheckinCalendarCollapsedForTest));
      expect(calendar.top, 115);
      expect(tester.takeException(), isNull);

      // Collapsing again returns the card to the one-week strip.
      await tester.dragFrom(
        Offset(195, calendar.bottom - 10),
        const Offset(0, -260),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const Key('checkin-calendar'))).height,
        _kCheckinCalendarCollapsedForTest,
      );
    });

    testWidgets('the month grid follows weeks paged while collapsed', (
      tester,
    ) async {
      _useDesignCanvas(tester);

      await tester.pumpWidget(_app(_FakeReminderApi(const [])));
      await tester.pumpAndSettle();

      // Page the week strip four weeks on, far enough to cross a month edge.
      // Dragged by coordinate: the strip pages away, so a key from the first
      // week is gone by the second swipe. y=210 is inside the day row.
      for (var i = 0; i < 4; i += 1) {
        await tester.dragFrom(const Offset(195, 210), const Offset(-320, 0));
        await tester.pumpAndSettle();
      }

      await tester.dragFrom(const Offset(195, 268), const Offset(0, 200));
      await tester.pumpAndSettle();

      // The open grid has to start on the month the strip walked to, not on
      // the month the page controller was first built with. Checking the cell
      // before the grid start is what separates the two: the earlier month's
      // grid would still contain it.
      final shownWeek = _weekMonday(_today).add(const Duration(days: 28));
      final shownMonth = _monthOf(shownWeek.add(const Duration(days: 3)));
      final gridStart = _weekMonday(shownMonth);
      expect(
        find.byKey(Key('checkin-month-day-${_key(gridStart)}')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          Key(
            'checkin-month-day-'
            '${_key(gridStart.subtract(const Duration(days: 1)))}',
          ),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('check-in editor', () {
    testWidgets('single plan sheet stacks on the Figma offsets', (
      tester,
    ) async {
      _useDesignCanvas(tester);

      await tester.pumpWidget(_app(_FakeReminderApi(const [])));
      await tester.pumpAndSettle();
      await _openEditor(tester);

      expect(tester.getRect(find.byKey(const Key('checkin-sheet'))).top, 164);
      expect(tester.getRect(find.byKey(const Key('checkin-name'))).top, 200);
      expect(tester.getRect(find.byKey(const Key('checkin-mode'))).top, 268);
      expect(tester.getRect(find.byKey(const Key('checkin-reminder'))).top, 336);
      expect(tester.getRect(find.byKey(const Key('checkin-note'))).top, 424);
      expect(tester.getRect(find.byKey(const Key('checkin-save'))).top, 722);

      expect(find.text('输入计划名称'), findsOneWidget);
      expect(find.text('备注（可选）'), findsOneWidget);
      expect(find.text('保存计划'), findsOneWidget);
      expect(find.byKey(const Key('checkin-weekdays')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('habit mode inserts the weekday card and shifts the rest', (
      tester,
    ) async {
      _useDesignCanvas(tester);

      await tester.pumpWidget(_app(_FakeReminderApi(const [])));
      await tester.pumpAndSettle();
      await _openEditor(tester);

      await tester.tap(find.text('周期习惯'));
      await tester.pumpAndSettle();

      expect(tester.getRect(find.byKey(const Key('checkin-weekdays'))).top, 336);
      expect(tester.getRect(find.byKey(const Key('checkin-reminder'))).top, 476);
      expect(tester.getRect(find.byKey(const Key('checkin-note'))).top, 564);
      expect(find.text('重复频率'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('saving sends the note along with the plan', (tester) async {
      _useDesignCanvas(tester);
      final api = _FakeReminderApi(const []);

      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();
      await _openEditor(tester);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('checkin-name')),
          matching: find.byType(TextField),
        ),
        '阅读30分钟',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('checkin-note')),
          matching: find.byType(TextField),
        ),
        '睡前读，不刷手机',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('checkin-save')));
      await tester.pumpAndSettle();

      expect(api.createdSummary, '阅读30分钟');
      expect(api.createdNote, '睡前读，不刷手机');
      expect(api.createdRecurrence, 'once');
      expect(tester.takeException(), isNull);
    });

    testWidgets('the keyboard lifts the sheet and keeps save reachable', (
      tester,
    ) async {
      _useDesignCanvas(tester);

      await tester.pumpWidget(_app(_FakeReminderApi(const [])));
      await tester.pumpAndSettle();
      await _openEditor(tester);

      const keyboard = 336.0;
      _useDesignCanvas(tester, keyboard: keyboard);
      await tester.pumpAndSettle();

      final sheet = tester.getRect(find.byKey(const Key('checkin-sheet')));
      final save = tester.getRect(find.byKey(const Key('checkin-save')));
      // The sheet sits on the keyboard without sliding under the status bar,
      // and the save button stays above the keyboard line.
      expect(sheet.bottom, _canvasHeight - keyboard);
      expect(sheet.top, greaterThanOrEqualTo(_safeTop));
      expect(save.bottom, lessThanOrEqualTo(_canvasHeight - keyboard));
      // Every field is still reachable by scrolling rather than being clipped.
      expect(find.text('输入计划名称'), findsOneWidget);
      expect(find.byKey(const Key('checkin-note')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// Mirrors the private layout constant so a drift shows up as a test failure.
const double _kCheckinCalendarCollapsedForTest = 164;

String _key(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

DateTime _weekMonday(DateTime value) =>
    DateTime(value.year, value.month, value.day)
        .subtract(Duration(days: value.weekday - 1));

DateTime _monthOf(DateTime value) => DateTime(value.year, value.month);
