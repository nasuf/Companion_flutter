import 'package:companion_flutter/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('copyWith keeps the cooling-period cancellation flag for the notice', () {
    final session = AuthSession.fromJson({
      'token': 'synthetic',
      'user_id': 'user',
      'username': 'user',
      'role': 'user',
      'has_agent': true,
      'agent_id': 'agent',
      'deletion_cancelled': true,
    });
    expect(session.deletionCancelled, isTrue);
    // ensureConversation 返回的是 copyWith 结果，登录后的提示依赖这个值。
    final ready = session.copyWith(conversationId: 'conversation');
    expect(ready.deletionCancelled, isTrue);
    expect(ready.conversationId, 'conversation');
  });
}
