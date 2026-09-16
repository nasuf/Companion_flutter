import 'package:companion_flutter/models.dart';
import 'package:companion_flutter/src/chat/game_activity_logic.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _gameStatusMessage({
  required String id,
  required DateTime createdAt,
  required String status,
  String gameKey = 'reversi',
}) {
  return ChatMessage(
    id: id,
    conversationId: 'conversation-1',
    role: 'assistant',
    content: 'status',
    createdAt: createdAt,
    metadata: {
      'game_status': status,
      'game_key': gameKey,
      'game_title': '黑白棋',
      'game_status_actor_name': '小伴',
      'session_id': id,
    },
    read: true,
  );
}

void main() {
  test('collapses adjacent legacy game status rows within five minutes', () {
    final base = DateTime(2026, 9, 16, 14, 42);
    final messages = [
      _gameStatusMessage(id: 'm1', createdAt: base, status: 'started'),
      _gameStatusMessage(
        id: 'm2',
        createdAt: base.add(const Duration(seconds: 20)),
        status: 'ended',
      ),
      _gameStatusMessage(
        id: 'm3',
        createdAt: base.add(const Duration(seconds: 40)),
        status: 'started',
      ),
      _gameStatusMessage(
        id: 'm4',
        createdAt: base.add(const Duration(minutes: 1)),
        status: 'ended',
      ),
    ];

    final processed = preprocessGameActivityMessages(messages);

    expect(processed.$1.length, 1);
    expect(processed.$2, {'m1', 'm2', 'm3'});
    expect(processed.$1.first.metadata?['kind'], 'game_activity_burst');
    expect(
      gameActivitySegmentsFromMetadata(processed.$1.first.metadata).length,
      4,
    );
    expect(
      processed.$1.first.content,
      contains('《黑白棋》进出 4 次'),
    );
  });

  test('keeps separate bursts when gap exceeds five minutes', () {
    final base = DateTime(2026, 9, 16, 14, 42);
    final messages = [
      _gameStatusMessage(id: 'm1', createdAt: base, status: 'started'),
      _gameStatusMessage(
        id: 'm2',
        createdAt: base.add(const Duration(minutes: 6)),
        status: 'ended',
      ),
    ];

    final processed = preprocessGameActivityMessages(messages);

    expect(processed.$1.length, 2);
    expect(processed.$2, isEmpty);
  });

  test('does not merge legacy rows from different game titles', () {
    final base = DateTime(2026, 9, 16, 14, 42);
    final messages = [
      _gameStatusMessage(
        id: 'm1',
        createdAt: base,
        status: 'started',
        gameKey: '',
      ).copyWith(
        metadata: {
          'game_status': 'started',
          'game_title': '黑白棋',
          'game_status_actor_name': '小伴',
          'session_id': 'm1',
        },
      ),
      _gameStatusMessage(
        id: 'm2',
        createdAt: base.add(const Duration(seconds: 20)),
        status: 'started',
        gameKey: '',
      ).copyWith(
        metadata: {
          'game_status': 'started',
          'game_title': '围棋',
          'game_status_actor_name': '小伴',
          'session_id': 'm2',
        },
      ),
    ];

    final processed = preprocessGameActivityMessages(messages);

    expect(processed.$1.length, 2);
    expect(processed.$2, isEmpty);
  });
}
