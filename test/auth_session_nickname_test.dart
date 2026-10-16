import 'package:companion_flutter/models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json({String? nickname}) => {
  'token': 't',
  'user_id': 'u1',
  'username': 'ph_x',
  'role': 'user',
  'has_agent': true,
  'agent_id': 'a1',
  'agent_name': '陈砚',
  'agent_nickname': nickname,
};

void main() {
  test('聊天页标题优先显示姓名库昵称', () {
    final session = AuthSession.fromJson(_json(nickname: '阿砚'));
    expect(session.agentNickname, '阿砚');
    expect(session.agentDisplayName, '阿砚');
  });

  test('没有昵称（含空白）时回落到全名', () {
    expect(AuthSession.fromJson(_json()).agentDisplayName, '陈砚');
    expect(AuthSession.fromJson(_json(nickname: '  ')).agentDisplayName, '陈砚');
  });

  test('copyWith 不会丢掉昵称', () {
    final session = AuthSession.fromJson(_json(nickname: '阿砚'));
    expect(session.copyWith(conversationId: 'c1').agentNickname, '阿砚');
  });

  test('AgentProfile 解析 nickname', () {
    final agent = AgentProfile.fromJson({
      'id': 'a1',
      'name': '陈砚',
      'nickname': '阿砚',
      'user_id': 'u1',
    });
    expect(agent.nickname, '阿砚');
  });
}
