import 'package:companion_flutter/src/games/reversi_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('standard opening exposes the four legal black moves', () {
    final engine = ReversiEngine();

    expect(engine.userCount, 2);
    expect(engine.agentCount, 2);
    expect(
      engine.legalMoves.keys.map((index) => ReversiPoint(index).coordinate),
      unorderedEquals(['D3', 'C4', 'F5', 'E6']),
    );
  });

  test('a move flips every bracketed line in all eight directions', () {
    final board = List<int>.filled(64, 0);
    const centerRow = 3;
    const centerCol = 3;
    const directions = [
      (-1, -1),
      (-1, 0),
      (-1, 1),
      (0, -1),
      (0, 1),
      (1, -1),
      (1, 0),
      (1, 1),
    ];
    for (final (dr, dc) in directions) {
      board[(centerRow + dr) * 8 + centerCol + dc] = -1;
      board[(centerRow + dr * 2) * 8 + centerCol + dc * 2] = 1;
    }
    final engine = ReversiEngine.debug(board);

    final result = engine.play(centerRow * 8 + centerCol);

    expect(result.move.flipped, hasLength(8));
    expect(result.move.moments, contains(containsPair('type', 'big_flip')));
    expect(engine.board.where((disc) => disc == -1), isEmpty);
  });

  test('invalid empty square and occupied square are rejected', () {
    final engine = ReversiEngine();

    expect(() => engine.play(0), throwsStateError);
    expect(() => engine.play(27), throwsStateError);
  });

  test('the engine automatically keeps the turn when opponent must pass', () {
    final engine = ReversiEngine();
    ReversiMove? passMove;
    for (var step = 0; step < 60 && !engine.isFinished; step++) {
      final legal = engine.legalMoves.keys.toList()..sort();
      expect(legal, isNotEmpty);
      final actor = engine.turn;
      final result = engine.play(legal.first);
      if (result.move.forcedPass != null) {
        passMove = result.move;
        expect(engine.turn, actor);
        break;
      }
    }

    expect(passMove, isNotNull);
    expect(passMove!.moments, contains(containsPair('type', 'forced_pass')));
  });

  test('a full board is scored exactly including draws', () {
    final userWin = ReversiEngine.debug(List<int>.filled(64, 1));
    final draw = ReversiEngine.debug([
      for (var index = 0; index < 64; index++) index.isEven ? 1 : -1,
    ]);

    expect(userWin.status, ReversiStatus.userWon);
    expect(userWin.userCount, 64);
    expect(draw.status, ReversiStatus.draw);
    expect(draw.userCount, draw.agentCount);
  });

  test(
    'agent search returns a legal move with professional diagnostics',
    () async {
      final engine = ReversiEngine();
      engine.play(engine.legalMoves.keys.first);
      final legal = engine.legalMoves.keys.toSet();

      final decision = await engine.chooseAiMove();

      expect(legal, contains(decision.point.index));
      expect(decision.depth, greaterThanOrEqualTo(1));
      expect(decision.nodes, greaterThan(legal.length));
      expect(decision.candidatesConsidered, legal.length);
      expect(decision.candidateScores, isNotEmpty);
      expect(
        decision.toJson()['algorithm'],
        'iterative_deepening_pvs_alpha_beta_tt_mobility_stability_parity',
      );
    },
  );

  test('summary preserves actions, flips, analysis and final state', () {
    final engine = ReversiEngine();
    final result = engine.play(engine.legalMoves.keys.first);
    final summary = engine.summaryJson();

    expect(summary['actions'], hasLength(1));
    expect((summary['actions'] as List).first['flipped_count'], greaterThan(0));
    expect((summary['analysis'] as Map)['user_mobility'], isA<int>());
    expect((summary['final_state'] as Map)['board'], hasLength(64));
    expect(result.move.stateBeforeHash, isNot(result.move.stateAfterHash));
  });
}
