import 'package:companion_flutter/models.dart';
import 'package:companion_flutter/socket_ticket.dart';
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

  test('chat ticket rejection carries the real-name reason', () {
    const blocked = SocketTicketException(403, reason: 'realname_required');
    expect(blocked.realnameRequired, isTrue);
    expect(blocked.toString(), '请先完成实名认证');
    const denied = SocketTicketException(403);
    expect(denied.realnameRequired, isFalse);
    expect(denied.toString(), '无权访问此会话');
  });

  test('ID number check tells the user what is wrong', () {
    final today = DateTime(2026, 11, 13);
    String? check(String id) => idNumberProblem(id, today: today);
    expect(check('11010519491231002X'), isNull);
    expect(check('11010519491231002x'), isNull);
    expect(check(''), contains('18 位'));
    expect(check('11010519491231002'), contains('18 位'));
    expect(check('110105194913310021'), contains('出生日期')); // 13 月
    expect(check('110105202502300011'), contains('出生日期')); // 2 月 30 日
    expect(check('110105202701010011'), contains('出生日期')); // 未来
    expect(check('110105194912310021'), contains('逐位核对')); // 校验位不对
  });

  test('privacy center reads the masked real-name record', () {
    final verified = RealnameRecord.fromJson({
      'record': {
        'status': 'verified',
        'masked_name': '张*',
        'masked_id_number': '1****************X',
        'verified_at': '2026-11-13T12:00:00+00:00',
      },
    });
    expect(verified.verified, isTrue);
    expect(verified.statusLabel, '已认证');
    expect(verified.maskedName, '张*');
    expect(verified.maskedIdNumber, '1****************X');
    expect(verified.verifiedAt, isNotNull);

    // 从未提交 / 旧服务端没有 record 字段 / 被后台重置
    final none = RealnameRecord.fromJson({'record': null});
    expect(none.statusLabel, '未认证');
    expect(none.maskedName, isNull);
    expect(RealnameRecord.fromJson({}).statusLabel, '未认证');
    expect(
      RealnameRecord.fromJson({
        'record': {'status': 'minor'},
      }).statusLabel,
      '未成年，已限制使用',
    );
  });
}
