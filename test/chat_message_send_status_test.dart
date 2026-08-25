import 'package:companion_flutter/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a fresh draft starts pending and not failed', () {
    final draft = ChatMessage.draft(
      conversationId: 'conversation-1',
      role: 'user',
      content: '你好',
      clientId: 'client-1',
    );

    expect(draft.pending, isTrue);
    expect(draft.failed, isFalse);
  });

  test('copyWith can flip a pending draft into a failed one', () {
    final draft = ChatMessage.draft(
      conversationId: 'conversation-1',
      role: 'user',
      content: '发不出去的消息',
      clientId: 'client-2',
    );

    // 这正是发送超时 / error 事件兜底路径要做的事: 服务端彻底沉默时,
    // 把草稿从"发送中"翻成"失败", 而不是让它永久停在 pending 状态。
    final failed = draft.copyWith(pending: false, failed: true);

    expect(failed.pending, isFalse);
    expect(failed.failed, isTrue);
    // 其余字段原样保留, 尤其是 content —— 重试要用它把文本还给输入框。
    expect(failed.content, '发不出去的消息');
    expect(failed.clientId, 'client-2');
  });

  test('server-loaded history messages default to not failed', () {
    final message = ChatMessage.fromJson({
      'id': 'msg-1',
      'conversation_id': 'conversation-1',
      'role': 'user',
      'content': '历史消息',
      'created_at': DateTime.now().toIso8601String(),
    });

    expect(message.failed, isFalse);
    expect(message.pending, isFalse);
  });
}
