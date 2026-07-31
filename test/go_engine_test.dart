import 'package:companion_flutter/src/games/go_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new 19x19 game exposes every point as a legal opening', () {
    final engine = GoEngine();

    expect(engine.board, hasLength(361));
    expect(engine.legalMoves(), hasLength(361));
    expect(engine.turn, GoActor.user);
    expect(GoPoint(0).coordinate, 'A19');
    expect(GoPoint(360).coordinate, 'T1');
  });

  test('placing the last liberty captures an opposing group', () {
    final board = List<int>.filled(361, 0)
      ..[181] = 1
      ..[199] = 1
      ..[201] = 1
      ..[200] = 2;
    final engine = GoEngine.debug(board);

    final result = engine.play(219);

    expect(result.move.captured, [200]);
    expect(engine.board[200], 0);
    expect(engine.userCaptures, 1);
    expect(result.move.moment?['type'], 'capture');
  });

  test('suicide is illegal when the move captures nothing', () {
    final board = List<int>.filled(361, 0)
      ..[181] = 2
      ..[199] = 2
      ..[201] = 2
      ..[219] = 2;
    final engine = GoEngine.debug(board);

    expect(engine.isLegal(200), isFalse);
    expect(() => engine.play(200), throwsStateError);
  });

  test('two consecutive passes end the game and calculate area score', () {
    final board = List<int>.filled(361, 0)..[180] = 1;
    final engine = GoEngine.debug(board, komi: 0);

    expect(engine.play(null).status, GoStatus.playing);
    final result = engine.play(null);

    expect(result.status, GoStatus.userWon);
    expect(engine.score.userTotal, 361);
    expect(engine.score.agentTotal, 0);
    expect(result.move.moment?['type'], 'scoring_started');
    expect(engine.stateJson()['status'], GoStatus.userWon.name);
  });

  test('state and summary preserve detailed action history', () {
    final engine = GoEngine();
    engine.play(180);
    engine.play(179);

    final summary = engine.summaryJson();

    expect(summary['game_key'], 'go');
    expect(summary['move_count'], 2);
    expect(summary['actions'], hasLength(2));
    expect(summary['rules'], contains('positional_superko'));
    expect((summary['analysis'] as Map)['legal_move_count'], greaterThan(0));
  });

  test('MCTS agent returns a legal move and search diagnostics', () async {
    final engine = GoEngine();
    engine.play(180);
    final legal = engine.legalMoves().toSet();

    final decision = await engine.chooseAiMove();

    expect(decision.index, isNotNull);
    expect(legal, contains(decision.index));
    expect(decision.simulations, greaterThanOrEqualTo(40));
    expect(decision.nodes, greaterThan(1));
    expect(decision.candidates, isNotEmpty);
    expect(decision.toJson()['algorithm'], 'uct_mcts_pattern_capture_rollout');
  });
}
