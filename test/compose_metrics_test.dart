import 'package:companion_flutter/src/chat/compose_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  late ComposeMetrics metrics;

  setUp(() {
    now = DateTime(2026, 11, 3, 12);
    metrics = ComposeMetrics(clock: () => now);
  });

  test('typing reports duration, edits and the largest insertion', () {
    metrics.textChanged('', '你');
    now = now.add(const Duration(seconds: 2));
    metrics.textChanged('你', '你好');
    metrics.textChanged('你好', '你好呀');
    now = now.add(const Duration(milliseconds: 500));
    expect(metrics.take(), {'compose_ms': 2500, 'max_insert_chars': 1, 'edit_count': 3});
    expect(metrics.take(), isNull);
  });

  test('a paste is one large insertion', () {
    metrics.textChanged('', '嗨嗨，我是小麦，19岁，大一在读～喜欢看动画');
    now = now.add(const Duration(milliseconds: 800));
    expect(metrics.take(), {'compose_ms': 800, 'max_insert_chars': 22, 'edit_count': 1});
  });

  test('emptying the composer or restoring a draft ends the session', () {
    metrics.textChanged('', 'abc');
    metrics.textChanged('abc', '');
    expect(metrics.take(), isNull);
    metrics.textChanged('', 'restored draft');
    metrics.discard();
    metrics.textChanged('restored draft', 'restored draft!');
    expect(metrics.take(), isNull);
  });

  test('deletions do not count as insertions', () {
    metrics.textChanged('', 'nihao');
    metrics.textChanged('nihao', '你好');
    expect(metrics.take()!['max_insert_chars'], 5);
  });
}
