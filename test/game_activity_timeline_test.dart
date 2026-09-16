import 'package:companion_flutter/models.dart';
import 'package:companion_flutter/src/chat/game_activity_logic.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _gameStatusMessage({
  required String id,
  required DateTime createdAt,
  required String status,
  String gameKey = 'reversi',
  String gameTitle = '黑白棋',
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
      'game_title': gameTitle,
      'game_status_actor_name': '小伴',
      'session_id': id,
    },
    read: true,
  );
}

void main() {
  test('collapses same-game status rows into one quiet digest', () {
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
    expect(processed.$1.first.content, '刚才点开了《黑白棋》');
    expect(
      summarizeGameActivity(
        gameActivitySegmentsFromMetadata(processed.$1.first.metadata),
      ).single.visitCount,
      2,
    );
  });

  test('collapses a browsing streak across games into one digest', () {
    final base = DateTime(2026, 8, 9, 10, 10);
    final games = [
      ('reversi', '黑白棋'),
      ('go', '围棋'),
      ('gomoku', '五子棋'),
      ('xiangqi', '中国象棋'),
      ('chess', '国际象棋'),
      ('chinese_checkers', '跳棋'),
      ('minesweeper', '协作扫雷'),
      ('number_merge', '数字合并'),
    ];
    final messages = <ChatMessage>[];
    for (var i = 0; i < games.length; i++) {
      final at = base.add(Duration(seconds: i * 40));
      messages.add(
        _gameStatusMessage(
          id: 'enter-$i',
          createdAt: at,
          status: 'started',
          gameKey: games[i].$1,
          gameTitle: games[i].$2,
        ),
      );
      messages.add(
        _gameStatusMessage(
          id: 'exit-$i',
          createdAt: at.add(const Duration(seconds: 8)),
          status: 'ended',
          gameKey: games[i].$1,
          gameTitle: games[i].$2,
        ),
      );
    }

    final processed = preprocessGameActivityMessages(messages);

    expect(processed.$1.length, 1);
    expect(processed.$1.first.content, '刚才点开了 8 款游戏');
    expect(
      summarizeGameActivity(
        gameActivitySegmentsFromMetadata(processed.$1.first.metadata),
      ).map((item) => item.gameTitle),
      ['黑白棋', '围棋', '五子棋', '中国象棋', '国际象棋', '跳棋', '协作扫雷', '数字合并'],
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

  test('played digest uses 一起玩了 instead of 点开了', () {
    final summaries = summarizeGameActivity([
      GameActivitySegment(
        at: DateTime(2026, 9, 16, 14, 42),
        action: 'played',
        sessionId: 's1',
        gameKey: 'number_merge',
        gameTitle: '数字合并',
      ),
    ]);
    expect(collapsedGameActivityLabel(summaries), '一起玩了《数字合并》');
  });
}
