import 'package:companion_flutter/src/games/go_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new 9x9 game exposes every point as a legal opening', () {
    final engine = GoEngine();

    expect(engine.board, hasLength(81));
    expect(engine.legalMoves(), hasLength(81));
    expect(engine.turn, GoActor.user);
    expect(GoPoint(0).coordinate, 'A9');
    expect(GoPoint(80).coordinate, 'J1');
  });

  test('placing the last liberty captures an opposing group', () {
    final board = List<int>.filled(81, 0)
      ..[1] = 1
      ..[9] = 1
      ..[11] = 1
      ..[10] = 2;
    final engine = GoEngine.debug(board);

    final result = engine.play(19);

    expect(result.move.captured, [10]);
    expect(engine.board[10], 0);
    expect(engine.userCaptures, 1);
    expect(result.move.moment?['type'], 'capture');
  });

  test('suicide is illegal when the move captures nothing', () {
    final board = List<int>.filled(81, 0)
      ..[1] = 2
      ..[9] = 2
      ..[11] = 2
      ..[19] = 2;
    final engine = GoEngine.debug(board);

    expect(engine.isLegal(10), isFalse);
    expect(() => engine.play(10), throwsStateError);
  });

  test('two consecutive passes end the game and calculate area score', () {
    final board = List<int>.filled(81, 0)..[40] = 1;
    final engine = GoEngine.debug(board, komi: 0);

    expect(engine.play(null).status, GoStatus.playing);
    final result = engine.play(null);

    expect(result.status, GoStatus.userWon);
    expect(engine.score.userTotal, 81);
    expect(engine.score.agentTotal, 0);
    expect(result.move.moment?['type'], 'scoring_started');
    expect(engine.stateJson()['status'], GoStatus.userWon.name);
  });

  test('state and summary preserve detailed action history', () {
    final engine = GoEngine();
    engine.play(40);
    engine.play(39);

    final summary = engine.summaryJson();

    expect(summary['game_key'], 'go');
    expect(summary['move_count'], 2);
    expect(summary['actions'], hasLength(2));
    expect(summary['rules'], contains('positional_superko'));
    expect((summary['analysis'] as Map)['legal_move_count'], greaterThan(0));
  });

  test('MCTS agent returns a legal move and search diagnostics', () async {
    final engine = GoEngine();
    engine.play(40);
    final legal = engine.legalMoves().toSet();

    final decision = await engine.chooseAiMove();

    expect(decision.index, isNotNull);
    expect(legal, contains(decision.index));
    expect(decision.simulations, greaterThanOrEqualTo(96));
    expect(decision.nodes, greaterThan(1));
    expect(decision.candidates, isNotEmpty);
    expect(decision.toJson()['algorithm'], 'uct_mcts_pattern_capture_rollout');
  });
}
