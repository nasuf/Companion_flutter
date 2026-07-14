import 'package:companion_flutter/src/games/number_merge_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NumberMergeEngine', () {
    test('starts with exactly two legal power-of-two tiles', () {
      final engine = NumberMergeEngine(seed: 7);

      final tiles = engine.board.where((value) => value != 0).toList();

      expect(tiles, hasLength(2));
      expect(tiles.every((value) => value == 2 || value == 4), isTrue);
      expect(engine.status, NumberMergeStatus.playing);
    });

    test('each tile merges at most once in a single slide', () {
      final engine = NumberMergeEngine.withBoard([
        2,
        2,
        2,
        2,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
      ], seed: 3);

      final result = engine.move(NumberMergeDirection.left);

      expect(engine.board[0], 4);
      expect(engine.board[1], 4);
      expect(result.move.mergedValues, [4, 4]);
      expect(result.move.scoreGained, 8);
      expect(
        result.move.transitions.where((item) => item.merged),
        hasLength(4),
      );
    });

    test('an invalid slide does not mutate or spawn', () {
      final engine = NumberMergeEngine.withBoard([
        2,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
      ]);
      final before = engine.board;

      expect(() => engine.move(NumberMergeDirection.left), throwsStateError);
      expect(engine.board, before);
      expect(engine.moves, isEmpty);
    });

    test('reaching 2048 completes the shared run', () {
      final engine = NumberMergeEngine.withBoard([
        1024,
        1024,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
      ], seed: 2);

      final result = engine.move(NumberMergeDirection.left);

      expect(result.status, NumberMergeStatus.completed);
      expect(engine.maxTile, 2048);
      expect(
        result.move.moments.map((moment) => moment.type),
        contains('target_reached'),
      );
    });

    test('a full board with no adjacent pair is terminal', () {
      final engine = NumberMergeEngine.withBoard([
        2,
        4,
        2,
        4,
        4,
        2,
        4,
        2,
        2,
        4,
        2,
        4,
        4,
        2,
        4,
        2,
      ]);

      expect(engine.status, NumberMergeStatus.failed);
      expect(engine.legalDirections, isEmpty);
    });

    test(
      'expectimax returns a legal move with probability diagnostics',
      () async {
        final engine = NumberMergeEngine.withBoard([
          2,
          4,
          8,
          16,
          0,
          2,
          4,
          8,
          0,
          0,
          2,
          4,
          0,
          0,
          0,
          2,
        ], firstActor: NumberMergeActor.agent);

        final decision = await engine.chooseAiMove();

        expect(engine.canMove(decision.direction), isTrue);
        expect(decision.depth, greaterThanOrEqualTo(4));
        expect(decision.nodes, greaterThan(0));
        expect(decision.alternatives, isNotEmpty);
        expect(decision.algorithm, contains('expectimax'));
      },
    );

    test('evaluation rewards an ordered edge over a jagged row', () {
      final ordered = NumberMergeEngine.withBoard([
        16,
        8,
        4,
        2,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
      ]);
      final jagged = NumberMergeEngine.withBoard([
        16,
        2,
        8,
        4,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
      ]);

      expect(
        ordered.analysisJson()['monotonicity'] as double,
        greaterThan(jagged.analysisJson()['monotonicity'] as double),
      );
    });

    test('summary preserves transitions, contributions and shared moments', () {
      final engine = NumberMergeEngine.withBoard([
        2,
        2,
        2,
        2,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
      ], seed: 4);
      engine.move(NumberMergeDirection.left);

      final summary = engine.summaryJson();

      expect(summary['game_key'], 'number_merge');
      expect(summary['score'], 8);
      expect(summary['user_score'], 8);
      expect(summary['total_merges'], 2);
      expect(summary['best_combo'], 2);
      expect(summary['actions'], hasLength(1));
      expect(summary['key_moments'], isNotEmpty);
      expect(
        ((summary['actions'] as List).first as Map)['transitions'],
        hasLength(4),
      );
    });
  });
}
