import 'package:companion_flutter/src/chat/usage_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 11, 12, 10);

  test('reminds once per two hours of foreground use', () {
    final clock = UsageReminderClock()..resume(t0);
    expect(clock.due(t0.add(const Duration(minutes: 119))), isFalse);
    expect(clock.due(t0.add(const Duration(hours: 2))), isTrue);
    expect(clock.due(t0.add(const Duration(hours: 2, minutes: 5))), isFalse);
    expect(clock.due(t0.add(const Duration(hours: 4))), isTrue);
  });

  test('short breaks keep counting, long breaks start over', () {
    final clock = UsageReminderClock()..resume(t0);
    clock.pause(t0.add(const Duration(hours: 1)));
    // 5 分钟后回来：仍算同一段连续使用，后台时间不计入
    clock.resume(t0.add(const Duration(hours: 1, minutes: 5)));
    expect(
      clock.usedAt(t0.add(const Duration(hours: 2))),
      const Duration(hours: 1, minutes: 55),
    );
    expect(clock.due(t0.add(const Duration(hours: 2, minutes: 5))), isTrue);
    // 离开 30 分钟：重新计时
    clock.pause(t0.add(const Duration(hours: 3)));
    clock.resume(t0.add(const Duration(hours: 3, minutes: 30)));
    expect(
      clock.usedAt(t0.add(const Duration(hours: 3, minutes: 30))),
      Duration.zero,
    );
    expect(
      clock.untilNext(t0.add(const Duration(hours: 3, minutes: 30))),
      const Duration(hours: 2),
    );
  });

  test('repeated resume or pause is harmless', () {
    final clock = UsageReminderClock()
      ..resume(t0)
      ..resume(t0.add(const Duration(hours: 1)));
    expect(
      clock.usedAt(t0.add(const Duration(hours: 1))),
      const Duration(hours: 1),
    );
    clock
      ..pause(t0.add(const Duration(hours: 1)))
      ..pause(t0.add(const Duration(hours: 1, minutes: 1)));
    expect(
      clock.usedAt(t0.add(const Duration(hours: 3))),
      const Duration(hours: 1),
    );
  });
}
