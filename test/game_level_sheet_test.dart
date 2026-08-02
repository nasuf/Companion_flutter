import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

GameLevelTier _tier(String stage, String colour, int points) => GameLevelTier(
  sortOrder: points,
  stageName: stage,
  stageCaption: '初学起步',
  tierName: colour,
  upgradePoints: 50,
  cumulativePoints: points,
);

Future<void> _openSheet(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showHubLevelSheet(
                context,
                tiers: Future.value([
                  _tier('皮革手套', '白', 0),
                  _tier('皮革手套', '绿', 50),
                  _tier('尼龙手套', '白', 750),
                ]),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  // Pushes the route and builds its first frame at t=0; the transition only
  // starts advancing on the frames after that.
  await tester.pump();
}

double? _blurSigma(WidgetTester tester) {
  final filters = tester.widgetList<BackdropFilter>(find.byType(BackdropFilter));
  if (filters.isEmpty) return null;
  // ImageFilter has no public sigma getter; its description carries the value.
  final match = RegExp(
    r'blur\(([\d.]+)',
  ).firstMatch(filters.first.filter.toString());
  return match == null ? null : double.parse(match.group(1)!);
}

void main() {
  testWidgets('backdrop blur ramps up as the sheet opens', (tester) async {
    await _openSheet(tester);

    await tester.pump(const Duration(milliseconds: 60));
    final early = _blurSigma(tester);
    expect(early, isNotNull, reason: 'blur should be present while opening');

    await tester.pumpAndSettle();
    final settled = _blurSigma(tester);
    expect(settled, isNotNull);
    expect(
      settled,
      greaterThan(early!),
      reason: 'blur should deepen over the transition, not appear at once',
    );
  });

  testWidgets('backdrop blur eases back out as the sheet closes', (
    tester,
  ) async {
    await _openSheet(tester);
    await tester.pumpAndSettle();
    final open = _blurSigma(tester);

    final context = tester.element(find.text('等级说明'));
    Navigator.of(context).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));

    final closing = _blurSigma(tester);
    expect(closing, isNotNull, reason: 'closing should animate, not cut away');
    expect(closing, lessThan(open!));
  });

  testWidgets('backdrop is torn down once the sheet closes', (tester) async {
    await _openSheet(tester);
    await tester.pumpAndSettle();
    expect(_blurSigma(tester), isNotNull);

    // Barrier tap must still dismiss: the frosted layer sits above the barrier
    // and would otherwise swallow the tap.
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(find.text('等级说明'), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('every step renders at full strength', (tester) async {
    await _openSheet(tester);
    await tester.pumpAndSettle();

    // The ladder is a reference table; unreached steps used to be dimmed.
    final faded = tester
        .widgetList<Opacity>(find.byType(Opacity))
        .where((widget) => widget.opacity > 0 && widget.opacity < 1);
    expect(faded, isEmpty);
  });
}
