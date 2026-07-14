import 'package:companion_flutter/src/games/minesweeper_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MinesweeperEngine', () {
    test('first reveal is safe and live state never leaks mine locations', () {
      final engine = MinesweeperEngine(seed: 41);

      final result = engine.reveal(40);
      final state = engine.stateJson();

      expect(result.action.hitMine, isFalse);
      expect(result.action.revealed, isNotEmpty);
      expect(engine.isGenerated, isTrue);
      expect(engine.generatedAttempts, greaterThan(0));
      expect(engine.noGuessVerified, isTrue);
      for (final cell in state['cells']! as List<dynamic>) {
        expect((cell as Map<String, dynamic>).containsKey('is_mine'), isFalse);
      }
    });

    test('zero cells reveal their complete connected basin', () {
      final engine = MinesweeperEngine.withMineLayout(
        rows: 5,
        columns: 5,
        mineIndices: {24},
      );

      final result = engine.reveal(0);

      expect(result.status, MinesweeperStatus.completed);
      expect(result.action.revealed.length, 24);
      expect(engine.flagCount, 1);
      expect(engine.largestReveal, 24);
    });

    test('representative seeds produce solver-verified no-guess boards', () {
      for (var seed = 0; seed < 12; seed += 1) {
        final engine = MinesweeperEngine(seed: seed * 97 + 11);
        engine.reveal((seed * 7) % engine.cellCount);
        expect(
          engine.noGuessVerified,
          isTrue,
          reason: 'seed=$seed attempts=${engine.generatedAttempts}',
        );
      }
    });

    test('a mine ends the shared game and is present in final state', () {
      final engine = MinesweeperEngine.withMineLayout(
        rows: 4,
        columns: 4,
        mineIndices: {15},
      );

      final result = engine.reveal(15);
      final finalState = engine.stateJson(revealMines: true);

      expect(result.status, MinesweeperStatus.failed);
      expect(result.action.hitMine, isTrue);
      expect(engine.explodedIndex, 15);
      expect((finalState['cells']! as List<dynamic>)[15]['state'], 'exploded');
      expect(engine.keyMoments.single.type, 'mine_triggered');
    });

    test('flag action alternates turns and can be undone', () {
      final engine = MinesweeperEngine.withMineLayout(
        rows: 4,
        columns: 4,
        mineIndices: {15},
      );

      final flagged = engine.toggleFlag(15);
      final unflagged = engine.toggleFlag(15, actor: MinesweeperActor.agent);

      expect(flagged.action.kind, MinesweeperActionKind.flag);
      expect(flagged.action.flagged, isTrue);
      expect(unflagged.action.kind, MinesweeperActionKind.unflag);
      expect(engine.isFlagged(15), isFalse);
      expect(engine.turn, MinesweeperActor.user);
    });

    test(
      'constraint solver flags a forced mine without hidden-board access',
      () async {
        final engine = MinesweeperEngine.withMineLayout(
          rows: 4,
          columns: 4,
          mineIndices: {1},
          revealedIndices: {0, 4, 5},
          firstActor: MinesweeperActor.agent,
        );

        final decision = await engine.chooseAiAction();

        expect(decision.kind, MinesweeperActionKind.flag);
        expect(decision.point, const MinePoint(0, 1));
        expect(decision.mineProbability, 1);
        expect(decision.forcedMineCount, 1);
        expect(decision.algorithm, contains('constraint_propagation'));
      },
    );

    test('constraint solver chooses a provably safe cell', () async {
      final engine = MinesweeperEngine.withMineLayout(
        rows: 4,
        columns: 4,
        mineIndices: {1},
        revealedIndices: {0},
        flaggedIndices: {1},
        firstActor: MinesweeperActor.agent,
      );

      final safeDecision = await engine.chooseAiAction();

      expect(safeDecision.kind, MinesweeperActionKind.reveal);
      expect(safeDecision.mineProbability, 0);
      expect(safeDecision.forcedSafeCount, greaterThan(0));
    });

    test(
      'summary retains actions, deductions, moments and final debug data',
      () async {
        final engine = MinesweeperEngine.withMineLayout(
          rows: 4,
          columns: 4,
          mineIndices: {1, 4, 5},
        );
        engine.reveal(0);
        final decision = await engine.chooseAiAction();
        engine.toggleFlag(
          decision.point.index(engine.columns),
          actor: MinesweeperActor.agent,
          decision: decision,
        );

        final summary = engine.summaryJson();

        expect(summary['game_key'], 'minesweeper');
        expect(summary['action_count'], 2);
        expect(summary['deductions'], 1);
        expect(summary['actions'], hasLength(2));
        expect(summary['key_moments'], isNotEmpty);
        expect(
          ((summary['final_state'] as Map<String, dynamic>)['cells'] as List)
              .every((cell) => (cell as Map).containsKey('is_mine')),
          isTrue,
        );
      },
    );
  });
}
