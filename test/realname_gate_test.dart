import 'package:companion_flutter/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// 实名门槛步骤由服务端给出（REALNAME_MODE），客户端只负责解析和按顺序引导。
void main() {
  Map<String, dynamic> json(Object? steps) => {
    'token': 't',
    'user_id': 'u',
    'username': 'n',
    'role': 'user',
    'has_agent': true,
    if (steps != null) 'realname_required': steps,
  };

  test('older servers without the field never gate', () {
    final session = AuthSession.fromJson(json(null));
    expect(session.realnameRequired, isEmpty);
    expect(session.realnameComplete, isTrue);
  });

  test('keeps server order and drops malformed entries', () {
    final session = AuthSession.fromJson(json(['phone', 3, 'id_card']));
    expect(session.realnameRequired, ['phone', 'id_card']);
    expect(session.realnameComplete, isFalse);
  });

  test('minor lock survives profile edits', () {
    final session = AuthSession.fromJson(json(['minor_blocked']));
    expect(session.copyWith(userDisplayName: '山木').realnameRequired, [
      'minor_blocked',
    ]);
  });

  test('non-list payload is treated as no steps', () {
    expect(parseRealnameSteps('phone'), isEmpty);
  });
}
