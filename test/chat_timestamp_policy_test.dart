import 'package:companion_flutter/src/utils/chat_timestamp_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = DateTime(2026, 10, 20, 10, 25);

  test('groups by adjacent silence, not elapsed time since first label', () {
    final messages = [
      for (var i = 0; i <= 20; i++) base.add(Duration(minutes: i)),
    ];
    final labels = [
      for (var i = 0; i < messages.length; i++)
        if (ChatTimestampPolicy.startsGroup(
          messages[i],
          previous: i == 0 ? null : messages[i - 1],
        ))
          messages[i],
    ];
    expect(labels, [base]);
    expect(ChatTimestampPolicy.startsGroup(base), isTrue);
    expect(ChatTimestampPolicy.startsGroup(base, previous: base), isFalse);
    expect(
      ChatTimestampPolicy.startsGroup(
        base.add(const Duration(minutes: 4, seconds: 59)),
        previous: base,
      ),
      isFalse,
    );
    expect(
      ChatTimestampPolicy.startsGroup(
        base.add(const Duration(minutes: 5)),
        previous: base,
      ),
      isTrue,
    );
  });

  test('crossing the local calendar day always starts a group', () {
    expect(
      ChatTimestampPolicy.startsGroup(
        DateTime(2026, 10, 21, 0, 0, 1),
        previous: DateTime(2026, 10, 20, 23, 59, 59),
      ),
      isTrue,
    );
  });

  test('prepended history recomputes the seam from adjacent messages', () {
    final current = [base, base.add(const Duration(minutes: 1))];
    expect(ChatTimestampPolicy.startsGroup(current.first), isTrue);
    final older = base.subtract(const Duration(minutes: 1));
    expect(
      ChatTimestampPolicy.startsGroup(current.first, previous: older),
      isFalse,
    );
    expect(
      ChatTimestampPolicy.startsGroup(current.last, previous: current.first),
      isFalse,
    );
  });

  test(
    'today and yesterday are calendar-relative; all older days use dates',
    () {
      String format(DateTime at) => ChatTimestampPolicy.format(at, now: base);
      expect(format(DateTime(2026, 10, 20, 10, 25)), '10:25');
      expect(format(DateTime(2026, 10, 19, 10, 25)), '昨天 10:25');
      expect(format(DateTime(2026, 10, 18, 10, 25)), '10月18日 10:25');
      expect(format(DateTime(2026, 10, 13, 10, 25)), '10月13日 10:25');
      expect(format(DateTime(2025, 10, 20, 10, 25)), '2025年10月20日 10:25');
      expect(format(DateTime(2026, 10, 21, 10, 25)), '10月21日 10:25');
    },
  );

  test('month/year changes and DST do not change yesterday into a date', () {
    expect(
      ChatTimestampPolicy.format(
        DateTime(2025, 12, 31, 10, 25),
        now: DateTime(2026, 1, 1, 9, 30),
      ),
      '昨天 10:25',
    );
    for (final (at, now) in [
      (DateTime(2026, 3, 8, 0, 30), DateTime(2026, 3, 9, 0, 5)),
      (DateTime(2026, 11, 1, 0, 30), DateTime(2026, 11, 2, 23, 59)),
    ]) {
      expect(ChatTimestampPolicy.format(at, now: now), '昨天 00:30');
    }
  });

  test('UTC wire times render and group in the device local calendar', () {
    final at = DateTime(2026, 10, 20, 0, 5);
    expect(ChatTimestampPolicy.format(at.toUtc(), now: base), '00:05');
    expect(
      ChatTimestampPolicy.startsGroup(
        at.toUtc(),
        previous: at.subtract(const Duration(minutes: 1)).toUtc(),
      ),
      isFalse,
    );
  });
}
