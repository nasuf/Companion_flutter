import 'package:companion_flutter/src/games/tetris_duel_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('seven-bag emits every tetromino before repeating', () {
    final board = TetrisBoardEngine(actor: TetrisDuelActor.user, seed: 42);
    final firstBag = <TetrisTetromino>{};

    for (var index = 0; index < TetrisTetromino.values.length; index++) {
      firstBag.add(board.current!.type);
      board.hardDrop();
    }

    expect(firstBag, TetrisTetromino.values.toSet());
  });

  test('duel boards receive the same fair piece sequence', () {
    final duel = TetrisDuelEngine(seed: 31415);

    for (var piece = 0; piece < 20; piece++) {
      expect(duel.user.current!.type, duel.agent.current!.type);
      duel.user.hardDrop();
      duel.agent.hardDrop();
      expect(duel.user.next, duel.agent.next);
    }
  });

  test('prepared horizontal I placement clears a complete line', () {
    final cells = List<int>.filled(
      TetrisBoardEngine.width * TetrisBoardEngine.height,
      0,
    );
    final bottom = (TetrisBoardEngine.height - 1) * TetrisBoardEngine.width;
    for (var column = 0; column < TetrisBoardEngine.width; column++) {
      if (column < 3 || column > 6) cells[bottom + column] = 1;
    }
    final board = TetrisBoardEngine(
      actor: TetrisDuelActor.user,
      seed: 7,
      initialBoard: cells,
      initialQueue: const [TetrisTetromino.i],
    );

    final result = board.hardDrop();

    expect(result.linesCleared, 1);
    expect(board.lines, 1);
    expect(board.board.take(TetrisBoardEngine.width), everyElement(0));
  });

  test('SRS rotation enables a vertical I tetris and sends attack', () {
    final cells = List<int>.filled(
      TetrisBoardEngine.width * TetrisBoardEngine.height,
      0,
    );
    for (
      var row = TetrisBoardEngine.height - 4;
      row < TetrisBoardEngine.height;
      row++
    ) {
      for (var column = 0; column < TetrisBoardEngine.width; column++) {
        if (column != 5) {
          cells[row * TetrisBoardEngine.width + column] = 2;
        }
      }
    }
    final attacker = TetrisBoardEngine(
      actor: TetrisDuelActor.user,
      seed: 9,
      initialBoard: cells,
      initialQueue: const [TetrisTetromino.i],
    );

    expect(attacker.rotate(), isTrue);
    final result = attacker.hardDrop();

    expect(result.linesCleared, 4);
    expect(result.attack, 4);
    expect(attacker.tetrises, 1);

    final duel = TetrisDuelEngine(seed: 13);
    duel.applyAttack(result);
    expect(duel.agent.attackReceived, 4);
  });

  test('AI surface search returns a legal lock placement', () {
    final board = TetrisBoardEngine(actor: TetrisDuelActor.agent, seed: 21);

    final placement = board.chooseAiPlacement();
    final result = board.playAiPlacement(placement);

    expect(result.actor, TetrisDuelActor.agent);
    expect(board.piecesPlaced, 1);
    expect(board.topOut, isFalse);
    expect(placement.evaluation, greaterThan(-999));
    expect(result.scoreGained, board.score);
    expect(board.score, greaterThan(0));
  });

  test('garbage rows each preserve exactly one playable hole', () {
    final board = TetrisBoardEngine(actor: TetrisDuelActor.agent, seed: 84);

    board.receiveGarbage(3);

    for (
      var row = TetrisBoardEngine.height - 3;
      row < TetrisBoardEngine.height;
      row++
    ) {
      final values = board.board.skip(row * TetrisBoardEngine.width).take(10);
      expect(values.where((value) => value == 0), hasLength(1));
      expect(values.where((value) => value == 8), hasLength(9));
    }
  });

  test('timed duel resolves the higher score as winner', () {
    final duel = TetrisDuelEngine(seed: 101, durationSeconds: 1);
    duel.user.hardDrop();
    duel.user.hardDrop();
    duel.agent.hardDrop();

    expect(duel.user.score, greaterThan(duel.agent.score));
    duel.advanceClock(1000);

    expect(duel.status, TetrisDuelStatus.userWon);
    expect(duel.summaryJson()['winner'], 'user');
  });

  test('invalid debug board is rejected at construction', () {
    expect(
      () => TetrisBoardEngine(
        actor: TetrisDuelActor.user,
        seed: 1,
        initialBoard: const [9],
      ),
      throwsArgumentError,
    );
  });
}
