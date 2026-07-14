import 'package:companion_flutter/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native game session parses without any SUD fields', () {
    final session = GameSession.fromJson({
      'id': 'session-1',
      'provider': 'native',
      'game_key': 'gomoku',
      'status': 'playing',
      'user_id': 'user-1',
      'agent_id': 'agent-1',
      'room_id': 'gomoku-room',
      'difficulty': 'normal',
      'ai_level': 2,
      'user_player': {'uid': 'user-1', 'nick_name': '玩家'},
      'ai_player': {'uid': 'agent:agent-1', 'nick_name': '小芜', 'is_ai': 1},
      'result': {'user_outcome': 'win'},
    });

    expect(session.provider, 'native');
    expect(session.gameKey, 'gomoku');
    expect(session.difficulty, 'normal');
    expect(session.aiPlayer.nickName, '小芜');
    expect(session.result?['user_outcome'], 'win');
  });

  test('native event response exposes duplicate delivery state', () {
    final response = GameEventResponse.fromJson({
      'session': {
        'id': 'session-1',
        'provider': 'native',
        'game_key': 'match3',
        'status': 'settled',
        'user_id': 'user-1',
        'agent_id': 'agent-1',
        'room_id': 'match3-room',
        'difficulty': 'normal',
        'ai_level': 2,
        'user_player': {'uid': 'user-1', 'nick_name': '玩家'},
        'ai_player': {'uid': 'agent:agent-1', 'nick_name': '小芜'},
      },
      'persisted_event_id': 'event-1',
      'duplicate': true,
    });

    expect(response.persistedEventId, 'event-1');
    expect(response.duplicate, isTrue);
  });
}
