import 'package:companion_flutter/src/games/chinese_checkers_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('standard star contains 121 cells and ten pieces per player', () {
    final engine = ChineseCheckersEngine();
    expect(ChineseCheckersEngine.cells, hasLength(121));
    expect(engine.board.where((piece) => piece == 0), hasLength(10));
    expect(engine.board.where((piece) => piece == 1), hasLength(10));
    expect(engine.stateJson()['status'], ChineseCheckersStatus.playing.name);
  });

  test('opening player has legal steps and jumps', () {
    final engine = ChineseCheckersEngine();
    final movable = <List<int>>[];
    for (var index = 0; index < engine.board.length; index++) {
      movable.addAll(engine.legalPathsFrom(index));
    }
    expect(movable, isNotEmpty);
    expect(movable.every((path) => path.length >= 2), isTrue);
  });

  test('move updates turn, hash and replay record', () {
    final engine = ChineseCheckersEngine();
    final before = engine.stateHash;
    final path = [
      for (var index = 0; index < engine.board.length; index++)
        ...engine.legalPathsFrom(index),
    ].first;
    final result = engine.playPath(path);
    expect(result.move.stateBeforeHash, before);
    expect(result.move.stateAfterHash, isNot(before));
    expect(engine.turn, ChineseCheckersActor.agent);
    expect(engine.moves, hasLength(1));
  });

  test('agent returns a legal searched move with diagnostics', () async {
    final engine = ChineseCheckersEngine();
    final userMove = [
      for (var index = 0; index < engine.board.length; index++)
        ...engine.legalPathsFrom(index),
    ].first;
    engine.playPath(userMove);
    final decision = await engine.chooseAiMove();
    expect(decision.nodes, greaterThan(0));
    expect(decision.depth, greaterThan(0));
    expect(
      engine
          .legalPathsFrom(decision.path.first)
          .any((path) => path.join(',') == decision.path.join(',')),
      isTrue,
    );
  });

  test('single hop is recorded as a jump rather than an adjacent step', () {
    final cells = ChineseCheckersEngine.cells;
    int at(int x, int row) =>
        cells.firstWhere((cell) => cell.x == x && cell.row == row).index;
    final board = List<int>.filled(121, -1);
    final from = at(0, 8);
    final middle = at(2, 8);
    final to = at(4, 8);
    board[from] = ChineseCheckersActor.user.index;
    board[middle] = ChineseCheckersActor.agent.index;
    final engine = ChineseCheckersEngine.debug(board);

    final path = engine
        .legalPathsFrom(from)
        .firstWhere((candidate) => candidate.last == to);
    final move = engine.playPath(path).move;

    expect(move.isJump, isTrue);
    expect(move.toJson()['jump_count'], 1);
  });

  test('a piece that entered its target camp cannot leave it again', () {
    final cells = ChineseCheckersEngine.cells;
    final board = List<int>.filled(121, -1);
    final targetCell = cells.firstWhere((cell) => cell.row == 3);
    board[targetCell.index] = ChineseCheckersActor.user.index;
    final engine = ChineseCheckersEngine.debug(board);
    final targetCamp = cells
        .where((cell) => cell.row <= 3)
        .map((cell) => cell.index);

    final paths = engine.legalPathsFrom(targetCell.index);

    expect(paths, isNotEmpty);
    expect(paths.every((path) => targetCamp.contains(path.last)), isTrue);
  });
}
