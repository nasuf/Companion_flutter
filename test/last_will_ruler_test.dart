import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The 失联倒计时 ruler has two properties that break silently: the tick under
/// the marker must be scaled the most *at every offset*, not just when the list
/// is at rest, and the list must only ever come to rest on a whole tick — a
/// fraction of a tick off and the marker no longer sits on any line.
///
/// Label font size is the probe for both: it is `12 + 3 * emphasis`, so a label
/// at 15.0 means emphasis 1.0, which only happens when that tick is exactly
/// under the marker.
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
const double _maxLabelSize = 15;

/// A ballistic simulation stops within the scroll tolerance of its target, so it
/// rests up to ~0.5px off the tick at devicePixelRatio 1 (~0.1px on a 3x screen).
/// That is invisible; the misalignment worth catching was ~5px, which shows up
/// here as a label around 14.7.
const _restingSlack = 0.05;

class _FakeWillApi extends CompanionApi {
  _FakeWillApi() : super(baseUrl: 'https://example.test') {
    authToken = 'test-token';
  }

  @override
  Future<List<LastWill>> listLastWills({
    String? agentId,
    String? workspaceId,
  }) async => [
    LastWill(
      id: 'will-1',
      userId: 'user-1',
      content: '记得给阳台那盆兰花浇水。',
      inactivityDays: 30,
      contacts: const [LastWillContact(name: '张三', phone: '13800001111')],
      status: 'draft',
      createdAt: DateTime(2026, 8, 5),
      updatedAt: DateTime(2026, 8, 5),
    ),
  ];
}

double _labelSize(WidgetTester tester, int day) {
  final text = tester.widget<Text>(find.byKey(Key('legacy-day-label-$day')));
  return text.style!.fontSize!;
}

/// The most emphasised label currently built, i.e. the one under the marker.
({int day, double size}) _peakLabel(WidgetTester tester) {
  var day = 0;
  var size = 0.0;
  for (var candidate = 1; candidate <= 90; candidate++) {
    final finder = find.byKey(Key('legacy-day-label-$candidate'));
    if (finder.evaluate().isEmpty) continue;
    final current = _labelSize(tester, candidate);
    if (current > size) {
      size = current;
      day = candidate;
    }
  }
  return (day: day, size: size);
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

      expect(_labelSize(tester, 30), _maxLabelSize);
      expect(_labelSize(tester, 31), lessThan(_labelSize(tester, 30)));
      expect(_labelSize(tester, 32), lessThan(_labelSize(tester, 31)));
      expect(_labelSize(tester, 29), _labelSize(tester, 31));
      expect(tester.takeException(), isNull);
    });

    testWidgets('emphasis tracks the drag instead of stepping between ticks', (
      tester,
    ) async {
      await _pumpPage(tester);

      // Hold the ruler half a tick off centre. Neither neighbour is selected
      // yet, so the two straddling the marker have to be equally emphasised;
      // a build that only reacts to whole-tick changes would leave 30 at 15.0.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('legacy-day-label-30'))),
      );
      await gesture.moveBy(const Offset(-16, 0));
      await tester.pump();

      expect(_labelSize(tester, 30), lessThan(_maxLabelSize));
      expect(_labelSize(tester, 30), closeTo(_labelSize(tester, 31), 0.01));

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
      expect(peak.size, closeTo(_maxLabelSize, _restingSlack));
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
      expect(peak.size, closeTo(_maxLabelSize, _restingSlack));
      expect(peak.day, isNot(30));
      // The readout follows the ruler, so the card and the ruler cannot disagree.
      expect(find.text('${peak.day}'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });
}
