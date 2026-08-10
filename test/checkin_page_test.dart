import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:flutter/cupertino.dart' show CupertinoButton;
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

/// Mirrors the light-theme accent so a token change surfaces here.
const Color _accent = Color(0xFF496CFC);
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
  final List<String> deleted = <String>[];
  final List<String> pinned = <String>[];
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
  Future<void> deleteReminder(
    String reminderId, {
    String? conversationId,
  }) async {
    deleted.add(reminderId);
  }

  @override
  Future<ReminderItem> updateReminder(
    String reminderId, {
    String? summary,
    String? note,
    DateTime? triggerTime,
    String? recurrence,
    List<int>? habitWeekdays,
    bool? pinned,
    bool? sentToAi,
    String? conversationId,
  }) async {
    if (pinned != null) this.pinned.add(reminderId);
    return items.firstWhere((it) => it.id == reminderId);
  }

  @override
  Future<ReminderItem> completeReminder(
    String reminderId, {
    String? conversationId,
    DateTime? occurrenceDate,
  }) async {
    final item = items.firstWhere((it) => it.id == reminderId);
    return ReminderItem(
      id: item.id,
      summary: item.summary,
      note: item.note,
      triggerTime: item.triggerTime,
      recurrence: item.recurrence,
      status: item.status,
      agentId: item.agentId,
      createdAt: item.createdAt,
      habitWeekdays: item.habitWeekdays,
      completedAt: item.isHabit ? null : DateTime.now(),
      completedDates: item.isHabit
          ? [...item.completedDates, _dayKey(occurrenceDate ?? DateTime.now())]
          : item.completedDates,
    );
  }

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

      final calendar = tester.getRect(
        find.byKey(const Key('checkin-calendar')),
      );
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

    testWidgets('today keeps the filled pill and selection is an outline', (
      tester,
    ) async {
      _useDesignCanvas(tester);

      await tester.pumpWidget(_app(_FakeReminderApi(const [])));
      await tester.pumpAndSettle();

      BoxDecoration pill(DateTime day) {
        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byKey(Key('checkin-week-day-${_key(day)}')),
                matching: find.byType(Container),
              )
              .first,
        );
        return container.decoration! as BoxDecoration;
      }

      // Today starts selected: filled, no outline — the outline is reserved
      // for "the day you tapped".
      expect(pill(_today).color, _accent);
      expect(pill(_today).border, isNull);

      // Pick another day in the same week; today has to keep its fill.
      final other = _today.weekday == DateTime.monday
          ? _today.add(const Duration(days: 1))
          : _today.subtract(const Duration(days: 1));
      await tester.tap(find.byKey(Key('checkin-week-day-${_key(other)}')));
      await tester.pumpAndSettle();

      expect(pill(_today).color, _accent);
      expect(pill(_today).border, isNull);
      expect(pill(other).color, isNot(_accent));
      expect(pill(other).border, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a swiped row reveals one flush action, not a loose button', (
      tester,
    ) async {
      _useDesignCanvas(tester);

      await tester.pumpWidget(_app(_FakeReminderApi([_once('a', '测试一')])));
      await tester.pumpAndSettle();

      final row = tester.getRect(find.byKey(const Key('checkin-task-a')));
      await tester.drag(find.text('测试一'), const Offset(120, 0));
      await tester.pumpAndSettle();

      expect(find.text('置顶'), findsOneWidget);
      // The action sits inside the row's own bounds and starts at its edge —
      // a detached button would be outside it or inset from it.
      final action = tester.getRect(find.text('置顶'));
      expect(action.left, greaterThan(row.left));
      expect(action.right, lessThan(row.right));
      expect(tester.getRect(find.byKey(const Key('checkin-task-a'))), row);

      // Swiping the other way swaps in delete on the trailing end.
      await tester.drag(find.text('测试一'), const Offset(-240, 0));
      await tester.pumpAndSettle();
      expect(find.text('置顶'), findsNothing);
      expect(find.text('删除'), findsOneWidget);
      expect(tester.getRect(find.text('删除')).right, lessThan(row.right));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a closed row absorbs taps instead of the parked actions', (
      tester,
    ) async {
      _useDesignCanvas(tester);
      final api = _FakeReminderApi([_once('a', '短')]);

      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();

      // Pin and delete sit under the card at both ends even when the row is
      // shut. Tapping over either one — or over blank card space — has to open
      // the row, never fire the action underneath.
      final row = tester.getRect(find.byKey(const Key('checkin-task-a')));
      for (final x in [row.left + 44, row.center.dx + 40, row.right - 60]) {
        await tester.tapAt(Offset(x, row.center.dy));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('checkin-sheet')), findsOneWidget);
        Navigator.of(tester.element(find.byType(CheckinPage))).pop();
        await tester.pumpAndSettle();
      }
      expect(api.pinned, isEmpty);
      expect(api.deleted, isEmpty);
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

      expect(
        tester.getRect(find.byKey(const Key('checkin-calendar'))).top,
        115,
      );
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

      final calendar = tester.getRect(
        find.byKey(const Key('checkin-calendar')),
      );
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

      // The panel is sized to its content, so the design's offsets are
      // asserted against its own top edge rather than the 390x844 frame.
      final sheet = tester.getRect(find.byKey(const Key('checkin-sheet')));
      expect(sheet.bottom, _canvasHeight);
      expect(_offsetIn(tester, sheet, 'checkin-name'), 36);
      expect(_offsetIn(tester, sheet, 'checkin-mode'), 104);
      expect(_offsetIn(tester, sheet, 'checkin-reminder'), 172);
      expect(_offsetIn(tester, sheet, 'checkin-note'), 260);
      // Save keeps the design's gap to the bottom edge.
      final save = tester.getRect(find.byKey(const Key('checkin-save')));
      expect(sheet.bottom - save.bottom, 36 + _safeBottom);

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

      final sheet = tester.getRect(find.byKey(const Key('checkin-sheet')));
      expect(_offsetIn(tester, sheet, 'checkin-weekdays'), 172);
      expect(_offsetIn(tester, sheet, 'checkin-reminder'), 312);
      expect(_offsetIn(tester, sheet, 'checkin-note'), 400);
      expect(find.text('重复频率'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a finished plan opens as a summary, not a dead form', (
      tester,
    ) async {
      _useDesignCanvas(tester);
      final done = _once('a', '阅读30分钟', done: true);

      await tester.pumpWidget(_app(_FakeReminderApi([done])));
      await tester.pumpAndSettle();
      await tester.tap(find.text('阅读30分钟'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('checkin-detail')), findsOneWidget);
      expect(find.byKey(const Key('checkin-sheet')), findsNothing);
      expect(find.text('已完成'), findsOneWidget);
      expect(find.text('计划类型'), findsOneWidget);
      expect(find.text('删除计划'), findsOneWidget);
      // Nothing editable is on screen.
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('deleting a finished plan asks first', (tester) async {
      _useDesignCanvas(tester);
      final api = _FakeReminderApi([_once('a', '阅读30分钟', done: true)]);

      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();
      await tester.tap(find.text('阅读30分钟'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('删除计划'));
      await tester.pumpAndSettle();
      expect(find.text('删除这个计划？'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(api.deleted, isEmpty);
      expect(find.byKey(const Key('checkin-detail')), findsOneWidget);

      await tester.tap(find.text('删除计划'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(api.deleted, ['a']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a habit ticked today is still editable', (tester) async {
      _useDesignCanvas(tester);
      final habit = _habit('h', '晨跑', [_today.weekday]);

      await tester.pumpWidget(_app(_FakeReminderApi([habit])));
      await tester.pumpAndSettle();
      // Tick it, then reopen.
      // The tick sits last in the row; the earlier buttons are the swipe
      // actions hidden behind it.
      await tester.tap(
        find
            .descendant(
              of: find.byKey(const Key('checkin-task-h')),
              matching: find.byType(CupertinoButton),
            )
            .last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('晨跑'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('checkin-sheet')), findsOneWidget);
      expect(find.byKey(const Key('checkin-detail')), findsNothing);
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
      final closed = tester.getRect(find.byKey(const Key('checkin-sheet')));

      const keyboard = 336.0;
      _useDesignCanvas(tester, keyboard: keyboard);
      await tester.pumpAndSettle();

      final sheet = tester.getRect(find.byKey(const Key('checkin-sheet')));
      final save = tester.getRect(find.byKey(const Key('checkin-save')));
      final note = tester.getRect(find.byKey(const Key('checkin-note')));
      // While typing the panel grows to the safe area at the top and all the
      // way to the screen edge at the bottom, so its background carries on
      // behind the keyboard: no scrim above it, no seam under it.
      expect(sheet.top, _safeTop);
      expect(sheet.top, lessThan(closed.top));
      expect(sheet.bottom, _canvasHeight);
      // The form and the button stay in the part the keyboard does not cover.
      expect(save.bottom, lessThanOrEqualTo(_canvasHeight - keyboard));
      expect(note.bottom, lessThanOrEqualTo(_canvasHeight - keyboard));
      expect(find.text('输入计划名称'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('closing the keyboard does not bring it straight back', (
      tester,
    ) async {
      _useDesignCanvas(tester, keyboard: 336);

      await tester.pumpWidget(_app(_FakeReminderApi(const [])));
      await tester.pumpAndSettle();
      await _openEditor(tester);
      expect(tester.testTextInput.isVisible, isTrue);

      // The keyboard's own done key: the field gives up focus, then the
      // platform reports the inset going away.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      _useDesignCanvas(tester);
      await tester.pumpAndSettle();

      // The panel changes shape when the keyboard leaves. If that rebuilds the
      // field's element rather than updating it, autofocus fires a second time
      // and the keyboard pops right back up.
      expect(
        tester.testTextInput.isVisible,
        isFalse,
        reason: 'the keyboard must stay down after the done key',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('scrolling the form does not dismiss the keyboard', (
      tester,
    ) async {
      _useDesignCanvas(tester);

      await tester.pumpWidget(_app(_FakeReminderApi(const [])));
      await tester.pumpAndSettle();
      await _openEditor(tester);
      await tester.tap(find.text('周期习惯'));
      _useDesignCanvas(tester, keyboard: 336);
      await tester.pumpAndSettle();

      // iOS scroll views default to keeping the keyboard while you scroll
      // (.interactive at most lets you drag it away deliberately). Dropping it
      // the moment a drag starts is what makes picking a field feel hostile.
      await tester.drag(find.text('重复频率'), const Offset(0, -80));
      await tester.pumpAndSettle();

      expect(
        tester.testTextInput.isVisible,
        isTrue,
        reason: 'a scroll must not close the keyboard',
      );
      expect(tester.takeException(), isNull);
    });
  });
}

/// Mirrors the private layout constant so a drift shows up as a test failure.
const double _kCheckinCalendarCollapsedForTest = 164;

String _dayKey(DateTime value) => _key(value);

String _key(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

DateTime _weekMonday(DateTime value) => DateTime(
  value.year,
  value.month,
  value.day,
).subtract(Duration(days: value.weekday - 1));

DateTime _monthOf(DateTime value) => DateTime(value.year, value.month);

/// Offset of a keyed block from the sheet's own top edge.
double _offsetIn(WidgetTester tester, Rect sheet, String key) =>
    tester.getRect(find.byKey(Key(key))).top - sheet.top;
