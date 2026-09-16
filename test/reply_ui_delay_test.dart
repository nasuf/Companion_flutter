import 'package:companion_flutter/src/chat/reply_ui_delay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('schedule applies immediately when delay is zero', () {
    final applied = <String>[];
    final controller = ReplyUiDelayController(
      onApply: ({required clientId, messageId}) {
        applied.add(clientId);
      },
    );
    addTearDown(controller.dispose);

    controller.schedule(
      clientId: 'c1',
      messageId: 'm1',
      delaySeconds: 0,
    );

    expect(applied, ['c1']);
  });

  test('schedule waits before applying feedback', () async {
    final applied = <String>[];
    final controller = ReplyUiDelayController(
      onApply: ({required clientId, messageId}) {
        applied.add(clientId);
      },
    );
    addTearDown(controller.dispose);

    controller.schedule(
      clientId: 'c1',
      messageId: 'm1',
      delaySeconds: 0.05,
    );
    expect(applied, isEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(applied, ['c1']);
  });

  test('replyUiDelaySeconds parses numeric payload values', () {
    expect(replyUiDelaySeconds(3), 3);
    expect(replyUiDelaySeconds(2.5), 2.5);
    expect(replyUiDelaySeconds('4'), 4);
    expect(replyUiDelaySeconds(null), 0);
  });
}
