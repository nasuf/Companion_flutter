import 'package:companion_flutter/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// The client mirrors the server's settlement maths so a result screen can name
/// the round's value without waiting on a round-trip. These lock that mirror to
/// the PM rules table (2026-08-08) — if the server's `game_point_rules` seed
/// changes, these should be updated in the same breath.
void main() {
  GamePointRules outcome({
    required int win,
    required int lose,
    required int quit,
  }) => GamePointRules.fromJson({
    'type': 'outcome',
    'win': win,
    'lose': lose,
    'draw': 0,
    'quit': quit,
  });

  group('outcome games follow the rules table', () {
    // 游戏: (赢, 输, 中途退出)
    const table = <String, List<int>>{
      '黑白棋': [4, -3, -3],
      '五子棋': [3, -2, -2],
      '象棋': [4, -3, -3],
      '围棋': [5, -4, -4],
      '跳棋': [5, -4, -4],
      '国际象棋': [4, -3, -3],
      '扫雷': [3, -2, -2],
    };

    table.forEach((name, values) {
      test(name, () {
        final rules = outcome(
          win: values[0],
          lose: values[1],
          quit: values[2],
        );
        expect(rules.deltaFor(GameOutcome.win), values[0]);
        expect(rules.deltaFor(GameOutcome.lose), values[1]);
        expect(rules.deltaFor(GameOutcome.aborted), values[2]);
        expect(rules.deltaFor(GameOutcome.draw), 0);
      });
    });
  });

  group('数字合并 scores by milestone', () {
    final rules = GamePointRules.fromJson({
      'type': 'milestone',
      'milestones': [
        {'tile': 128, 'points': 2},
        {'tile': 256, 'points': 5},
        {'tile': 512, 'points': 6},
        {'tile': 1024, 'points': 15},
        {'tile': 2048, 'points': 25},
      ],
      'quit_below_threshold': {
        'threshold': 128,
        'below': -2,
        'at_or_above': 0,
      },
    });

    test('a finished board pays the highest tile reached, win or lose', () {
      expect(rules.deltaFor(GameOutcome.win, maxTile: 2048), 25);
      expect(rules.deltaFor(GameOutcome.lose, maxTile: 1024), 15);
      expect(rules.deltaFor(GameOutcome.lose, maxTile: 300), 5);
    });

    test('short of the first tile the round is a loss however it ended', () {
      expect(rules.deltaFor(GameOutcome.lose, maxTile: 64), -2);
      expect(rules.deltaFor(GameOutcome.aborted, maxTile: 64), -2);
      expect(rules.deltaFor(GameOutcome.win, maxTile: 0), -2);
    });

    test('at or past it, quitting forfeits the payout but is not penalised', () {
      expect(rules.deltaFor(GameOutcome.aborted, maxTile: 128), 0);
      expect(rules.deltaFor(GameOutcome.aborted, maxTile: 2048), 0);
    });
  });

  test('missing rules parse to a harmless zero', () {
    final rules = GamePointRules.fromJson(const {});
    expect(rules.isMilestone, isFalse);
    for (final o in GameOutcome.values) {
      expect(rules.deltaFor(o), 0);
    }
  });

  group('factory seed matches the rules table', () {
    // game_key: (赢, 输, 中途退出)
    const table = <String, List<int>>{
      'reversi': [4, -3, -3],
      'gomoku': [3, -2, -2],
      'xiangqi': [4, -3, -3],
      'go': [5, -4, -4],
      'chinese_checkers': [5, -4, -4],
      'chess': [4, -3, -3],
      'minesweeper': [3, -2, -2],
      'match3': [3, -2, -2],
      'tetris_duel': [3, -3, -3],
    };

    table.forEach((key, values) {
      test(key, () {
        final rules = seedGamePointRules(key);
        expect(rules, isNotNull, reason: '$key 缺少出厂规则');
        expect(rules!.deltaFor(GameOutcome.win), values[0]);
        expect(rules.deltaFor(GameOutcome.lose), values[1]);
        expect(rules.deltaFor(GameOutcome.aborted), values[2]);
      });
    });

    test('number_merge', () {
      final rules = seedGamePointRules('number_merge')!;
      expect(rules.isMilestone, isTrue);
      expect(rules.deltaFor(GameOutcome.win, maxTile: 2048), 25);
      expect(rules.deltaFor(GameOutcome.lose, maxTile: 512), 6);
      expect(rules.deltaFor(GameOutcome.lose, maxTile: 64), -2);
      expect(rules.deltaFor(GameOutcome.aborted, maxTile: 256), 0);
    });

    test('an unknown game has no seed rather than a wrong one', () {
      expect(seedGamePointRules('not_a_game'), isNull);
    });
  });

}
