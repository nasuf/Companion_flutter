import 'package:companion_flutter/src/widgets/chat/chat_timeline_timestamp.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'midnight relabels idle history without rebuilding message bodies',
    (tester) async {
      var now = DateTime(2026, 10, 20, 23, 59, 59);
      final clock = ChatCalendarClock(now: () => now);
      var bodyBuilds = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ChatTimelineTimestamp(
                  key: const ValueKey('label'),
                  timestamp: DateTime(2026, 10, 20, 10, 25),
                  clock: clock,
                  style: const TextStyle(fontSize: 11),
                ),
                Builder(
                  builder: (context) {
                    bodyBuilds++;
                    return const SizedBox(
                      key: ValueKey('message-body'),
                      height: 80,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
      final before = tester.getTopLeft(
        find.byKey(const ValueKey('message-body')),
      );
      expect(find.text('10:25'), findsOneWidget);
      now = DateTime(2026, 10, 21);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('昨天 10:25'), findsOneWidget);
      expect(bodyBuilds, 1);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('message-body'))),
        before,
      );
      await tester.pumpWidget(const SizedBox());
      clock.dispose();
    },
  );

  testWidgets('resume catches up multiple days and background polling stops', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 20, 10, 25);
    final clock = ChatCalendarClock(now: () => now);
    await tester.pumpWidget(
      MaterialApp(
        home: ChatTimelineTimestamp(
          timestamp: now,
          clock: clock,
          style: const TextStyle(fontSize: 11),
        ),
      ),
    );
    clock.didChangeAppLifecycleState(AppLifecycleState.paused);
    now = DateTime(2026, 10, 22, 9, 30);
    await tester.pump(const Duration(minutes: 2));
    expect(find.text('10:25'), findsOneWidget);
    clock.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('10月20日 10:25'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    clock.dispose();
    // A lifecycle observer snapshot may deliver a final callback after removal.
    clock.didChangeAppLifecycleState(AppLifecycleState.resumed);
    now = DateTime(2026, 10, 23);
    await tester.pump(const Duration(minutes: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('active OS date changes refresh within one minute', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 20, 10, 25);
    final clock = ChatCalendarClock(now: () => now);
    var changes = 0;
    clock.addListener(() => changes++);
    await tester.pump(const Duration(minutes: 1));
    expect(changes, 0);
    now = DateTime(2026, 10, 21, 9, 30);
    await tester.pump(const Duration(minutes: 1));
    expect(changes, 1);
    clock.dispose();
  });
}
