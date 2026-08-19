import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The 失联倒计时 ruler has two properties that break silently: the tick under
/// the marker must be highlighted the most *at every offset*, not just when
/// the list is at rest, and the list must only ever come to rest on a whole
/// tick — a fraction of a tick off and the marker no longer sits on any line.
///
/// Label colour is the probe for both: `ink` and `inkFaint` share the same hue
/// and differ only in alpha (`ink` opaque, `inkFaint` ~50%), and the label's
/// colour is `Color.lerp(inkFaint, ink, emphasis)` — so alpha 1.0 means
/// emphasis 1.0, which only happens when that tick is exactly under the
/// marker. Size used to be a second probe (the tick and its label grew toward
/// the marker too), but that read as jitter while scrolling and was dropped —
/// colour is the only signal now.
const _session = AuthSession(
  token: 'test-token',
  userId: 'user-1',
  username: 'tester',
  role: UserRole.user,
  hasAgent: true,
  agentId: 'agent-1',
  workspaceId: 'ws-1',
  conversationId: 'conv-1',
);

const double _canvasWidth = 390;
const double _canvasHeight = 844;
const double _maxAlpha = 1;

/// The ruler auto-confirms on settle now (no more "确认" button), so every
/// test here that lands on a new day exercises a real `updateLastWill` call —
/// this needs a working fake for it rather than letting that hit the network
/// and fall back on `_persistDraftSettings`'s error handling.
class _FakeWillApi extends CompanionApi {
  _FakeWillApi() : super(baseUrl: 'https://example.test') {
    authToken = 'test-token';
  }

  LastWill _will = LastWill(
    id: 'will-1',
    userId: 'user-1',
    content: '记得给阳台那盆兰花浇水。',
    inactivityDays: 30,
    contacts: const [LastWillContact(name: '张三', phone: '13800001111')],
    status: 'draft',
    createdAt: DateTime(2026, 8, 5),
    updatedAt: DateTime(2026, 8, 5),
  );

  @override
  Future<List<LastWill>> listLastWills({
    String? agentId,
    String? workspaceId,
  }) async => [_will];

  @override
  Future<LastWill> updateLastWill(
    String willId, {
    String? content,
    int? inactivityDays,
    List<LastWillContact>? contacts,
    String? status,
  }) async {
    _will = LastWill(
      id: _will.id,
      userId: _will.userId,
      agentId: _will.agentId,
      workspaceId: _will.workspaceId,
      content: content ?? _will.content,
      inactivityDays: inactivityDays ?? _will.inactivityDays,
      contacts: contacts ?? _will.contacts,
      status: status ?? _will.status,
      lastSeenAt: _will.lastSeenAt,
      startedAt: _will.startedAt,
      triggeredAt: _will.triggeredAt,
      deliveredAt: _will.deliveredAt,
      createdAt: _will.createdAt,
      updatedAt: _will.updatedAt,
    );
    return _will;
  }
}

/// A ballistic simulation stops within the scroll tolerance of its target, so
/// it rests up to ~0.5px off the tick at devicePixelRatio 1 — enough to leave
/// emphasis just under 1.0 (alpha ~0.995) rather than exactly at it. That is
/// invisible; the misalignment worth catching was ~5px, which shows up here
/// as an alpha noticeably below that.
const _restingSlack = 0.01;

double _labelAlpha(WidgetTester tester, int day) {
  final text = tester.widget<Text>(find.byKey(Key('legacy-day-label-$day')));
  return text.style!.color!.a;
}

/// The most emphasised label currently built, i.e. the one under the marker.
({int day, double alpha}) _peakLabel(WidgetTester tester) {
  var day = 0;
  var alpha = 0.0;
  for (var candidate = 1; candidate <= 90; candidate++) {
    final finder = find.byKey(Key('legacy-day-label-$candidate'));
    if (finder.evaluate().isEmpty) continue;
    final current = _labelAlpha(tester, candidate);
    if (current > alpha) {
      alpha = current;
      day = candidate;
    }
  }
  return (day: day, alpha: alpha);
}

/// The page runs a 12s glow loop, so it never settles — advance a fixed span.
Future<void> _settle(WidgetTester tester, {int frames = 10}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _pumpPage(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(_canvasWidth, _canvasHeight);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LastWillPage(api: _FakeWillApi(), session: _session),
    ),
  );
  await _settle(tester);
}

void main() {
  group('失联倒计时 ruler', () {
    testWidgets('emphasis peaks on the selected day and falls off outwards', (
      tester,
    ) async {
      await _pumpPage(tester);

      expect(_labelAlpha(tester, 30), closeTo(_maxAlpha, _restingSlack));
      expect(_labelAlpha(tester, 31), lessThan(_labelAlpha(tester, 30)));
      expect(_labelAlpha(tester, 32), lessThan(_labelAlpha(tester, 31)));
      expect(_labelAlpha(tester, 29), _labelAlpha(tester, 31));
      expect(tester.takeException(), isNull);
    });

    testWidgets('emphasis tracks the drag instead of stepping between ticks', (
      tester,
    ) async {
      await _pumpPage(tester);

      // Hold the ruler half a tick off centre. Neither neighbour is selected
      // yet, so the two straddling the marker have to be equally emphasised;
      // a build that only reacts to whole-tick changes would leave 30 at 1.0.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('legacy-day-label-30'))),
      );
      await gesture.moveBy(const Offset(-16, 0));
      await tester.pump();

      expect(_labelAlpha(tester, 30), lessThan(_maxAlpha));
      expect(_labelAlpha(tester, 30), closeTo(_labelAlpha(tester, 31), 0.01));

      await gesture.up();
      await _settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a preset chip carries the ruler to that day', (tester) async {
      await _pumpPage(tester);

      // The scroll animation reports every day it passes, which lands straight
      // back in didUpdateWidget — if that feedback fought the animation the
      // ruler would stall somewhere short of 60.
      await tester.tap(find.text('60天'));
      await _settle(tester, frames: 40);

      final peak = _peakLabel(tester);
      expect(peak.day, 60);
      expect(peak.alpha, closeTo(_maxAlpha, _restingSlack));
      expect(find.text('60'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a drag that ends between ticks settles onto a whole tick', (
      tester,
    ) async {
      await _pumpPage(tester);

      // Released a tick and a quarter along, so the list has to travel on to a
      // whole tick. How far the fling carries is the platform's business — what
      // matters is that wherever it stops, a tick is exactly under the marker.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('legacy-day-label-30'))),
      );
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();
      await gesture.up();
      await _settle(tester, frames: 40);

      final peak = _peakLabel(tester);
      expect(peak.alpha, closeTo(_maxAlpha, _restingSlack));
      expect(peak.day, isNot(30));
      // The readout follows the ruler, so the card and the ruler cannot disagree.
      expect(find.text('${peak.day}'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });
}
