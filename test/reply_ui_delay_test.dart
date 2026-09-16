import 'package:companion_flutter/models.dart';
import 'package:companion_flutter/src/chat/reply_ui_delay.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _userDraft({
  required String clientId,
  required String content,
  bool read = false,
}) {
  return ChatMessage.draft(
    conversationId: 'conv-1',
    role: 'user',
    content: content,
    clientId: clientId,
  ).copyWith(read: read, pending: !read);
}

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

  test('applyReadReceiptCascade marks earlier unread streak messages', () {
    final messages = [
      _userDraft(clientId: 'c1', content: '没有'),
      _userDraft(clientId: 'c2', content: '无聊'),
      _userDraft(clientId: 'c3', content: '就是很闷'),
    ];

    final updated = applyReadReceiptCascade(
      messages,
      clientId: 'c3',
    );

    expect(updated.every((message) => message.read), isTrue);
    expect(updated.every((message) => !message.pending), isTrue);
  });

  test('applyReadReceiptCascade stops at assistant boundary', () {
    final messages = [
      _userDraft(clientId: 'c0', content: '上一轮'),
      ChatMessage(
        id: 'a1',
        conversationId: 'conv-1',
        role: 'assistant',
        content: '在呢',
        createdAt: DateTime.now(),
        read: true,
      ),
      _userDraft(clientId: 'c1', content: '没有'),
      _userDraft(clientId: 'c2', content: '无聊'),
    ];

    final updated = applyReadReceiptCascade(
      messages,
      clientId: 'c2',
    );

    expect(updated[0].read, isFalse);
    expect(updated[2].read, isTrue);
    expect(updated[3].read, isTrue);
  });
}
