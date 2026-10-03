import 'package:flutter_test/flutter_test.dart';
import 'package:companion_flutter/models.dart';

void main() {
  test(
    'a committed reply carries the persisted id and timestamp instead of a pending draft',
    () {
      final reply = ChatMessage.fromReply(
        conversationId: 'conv',
        content: '好',
        payload: {'message_id': 'm1', 'created_at': '2026-10-01T12:00:00Z'},
        metadata: {'display_mode': 'voice'},
      );
      expect(reply.id, 'm1');
      expect(reply.pending, isFalse);
      expect(reply.clientId, isNull);
      expect(reply.createdAt, DateTime.utc(2026, 10, 1, 12));
      expect(reply.metadata?['display_mode'], 'voice');
    },
  );
  test('legacy replies without ids retain a transient draft', () {
    final reply = ChatMessage.fromReply(
      conversationId: 'conv',
      content: '好',
      payload: {},
    );
    expect(reply.isDraft, isTrue);
  });
}
