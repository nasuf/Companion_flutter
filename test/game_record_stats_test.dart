import 'package:companion_flutter/models.dart';
import 'package:flutter_test/flutter_test.dart';

GameSession _session({
  required String status,
  required String outcome,
  int? durationSeconds,
  DateTime? startedAt,
  DateTime? endedAt,
}) {
  return GameSession(
    id: 's-$outcome-$status',
    provider: 'native',
    gameKey: 'gomoku',
    status: status,
    userId: 'u1',
    agentId: 'a1',
    roomId: 'r1',
    difficulty: 'normal',
    aiLevel: 1,
    userPlayer: const GamePlayerInfo(
      uid: 'u1',
      nickName: '玩家',
      avatarUrl: '',
      gender: '',
      isAi: 0,
      aiLevel: 0,
    ),
    aiPlayer: const GamePlayerInfo(
      uid: 'a1',
      nickName: 'AI',
      avatarUrl: '',
      gender: '',
      isAi: 1,
      aiLevel: 1,
    ),
    result: {'user_outcome': outcome, 'duration_seconds': durationSeconds},
    durationSeconds: durationSeconds,
    startedAt: startedAt,
    endedAt: endedAt,
  );
}

void main() {
  test('win rate keeps mid-game quits in the denominator', () {
    final stats = NativeGameRecordStats.fromSessions([
      _session(status: 'settled', outcome: 'win', durationSeconds: 60),
      _session(status: 'aborted', outcome: 'aborted', durationSeconds: 20),
    ]);
    expect(stats.totalRounds, 2);
    expect(stats.wins, 1);
    expect(stats.aborted, 1);
    expect(stats.winRate, 50);
    expect(stats.homeWinRateLabel, '50%');
  });

  test('fromJson uses server win_rate including quits', () {
    final stats = NativeGameRecordStats.fromJson({
      'total_rounds': 20,
      'wins': 8,
      'losses': 7,
      'draws': 2,
      'aborted': 3,
      'win_rate': 40.0,
      'total_seconds': 5400,
    });
    expect(stats.totalRounds, 20);
    expect(stats.wins, 8);
    expect(stats.winRate, 40);
    expect(stats.homeWinRateLabel, '40%');
    expect(NativeGameRecordStats.fromJson(stats.toJson()).totalSeconds, 5400);
    expect(NativeGameRecordStats.fromJson(stats.toJson()).winRate, 40);
  });

  test('playSeconds falls back to started/ended span', () {
    final start = DateTime.utc(2026, 9, 18, 2, 0);
    final session = _session(
      status: 'settled',
      outcome: 'lose',
      startedAt: start,
      endedAt: start.add(const Duration(minutes: 3, seconds: 20)),
    );
    expect(session.playSeconds, 200);
  });
}
