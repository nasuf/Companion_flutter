import 'package:companion_flutter/src/games/chess_family_engine.dart';
import 'package:companion_flutter/src/games/chinese_checkers_engine.dart';
import 'package:companion_flutter/src/games/go_engine.dart';
import 'package:companion_flutter/src/games/gomoku_engine.dart';
import 'package:companion_flutter/src/games/match3_engine.dart';
import 'package:companion_flutter/src/games/minesweeper_engine.dart';
import 'package:companion_flutter/src/games/number_merge_engine.dart';
import 'package:companion_flutter/src/games/reversi_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('native game state restoration', () {
    test('restores gomoku from its canonical move stream', () {
      final original = GomokuEngine()
        ..place(const GomokuPoint(7, 7), GomokuActor.user)
        ..place(const GomokuPoint(7, 8), GomokuActor.agent);

      final restored = GomokuEngine.restore(
        (original.summaryJson()['moves'] as List).cast<Map<String, dynamic>>(),
      );

      expect(restored.summaryJson()['moves'], original.summaryJson()['moves']);
      expect(restored.currentActor, GomokuActor.user);
    });

    test('restores chess-family FEN and move numbering', () {
      final original = ChessFamilyEngine(kind: ChessFamilyKind.chess)
        ..play(from: 100, to: 68);
      final restored = ChessFamilyEngine.restore(
        kind: ChessFamilyKind.chess,
        state: original.analyze().toJson(),
        moveCount: 1,
      );

      expect(restored.fen, original.fen);
      final reply = restored.play(from: 20, to: 52);
      expect(reply.move.number, 2);
    });

    test('restores chinese checkers board and next action number', () {
      final original = ChineseCheckersEngine();
      final from = original.board.indexWhere((value) => value == 0);
      final path = original.legalPathsFrom(from).first;
      original.playPath(path);
      final restored = ChineseCheckersEngine.restore(
        original.stateJson(),
        actionCount: 1,
      );

      expect(restored.board, original.board);
      expect(restored.stateHash, original.stateHash);
      final agentFrom = List<int>.generate(restored.board.length, (i) => i)
          .firstWhere(
            (index) =>
                restored.board[index] == 1 &&
                restored.legalPathsFrom(index).isNotEmpty,
          );
      final agentMove = restored.playPath(
        restored.legalPathsFrom(agentFrom).first,
      );
      expect(agentMove.move.number, 2);
    });

    test('restores match3 score, board, turn, and remaining turns', () {
      final original = Match3Engine(seed: 31);
      original.swap(original.availableSwaps().first);
      final restored = Match3Engine.restore(
        original.stateJson(),
        actionCount: 1,
        seed: 31,
      );

      expect(restored.stateHash, original.stateHash);
      expect(restored.userScore, original.userScore);
      expect(restored.turnsRemaining, original.turnsRemaining);
      final next = restored.swap(restored.availableSwaps().first);
      expect(next.turn.stateAfterHash, restored.stateHash);
      expect(next.turn.number, 2);
    });

    test('restores go board, ko history, captures, and turn', () {
      final original = GoEngine()..play(40);
      final restored = GoEngine.restore(original.stateJson(), moveCount: 1);

      expect(restored.stateHash, original.stateHash);
      expect(restored.board, original.board);
      expect(restored.turn, GoActor.agent);
    });

    test('restores reversi board and next move number', () {
      final original = ReversiEngine();
      original.play(original.legalMoves.keys.first);
      final restored = ReversiEngine.restore(
        original.stateJson(),
        moveCount: 1,
      );

      expect(restored.stateHash, original.stateHash);
      final result = restored.play(restored.legalMoves.keys.first);
      expect(result.move.number, 2);
    });

    test('restores the private minesweeper layout and visible progress', () {
      final original = MinesweeperEngine(seed: 41)..reveal(40);
      final restored = MinesweeperEngine.restore(
        original.stateJson(revealMines: true),
        actionCount: 1,
      );

      expect(restored.stateHash, original.stateHash);
      expect(restored.revealedIndices, original.revealedIndices);
      expect(restored.turn, original.turn);
    });

    test('restores number merge board, scores, and next move number', () {
      final original = NumberMergeEngine(seed: 19);
      original.move(original.legalDirections.first);
      final restored = NumberMergeEngine.restore(
        original.stateJson(),
        moveCount: 1,
        seed: 19,
      );

      expect(restored.stateHash, original.stateHash);
      expect(restored.board, original.board);
      expect(restored.score, original.score);
      final result = restored.move(restored.legalDirections.first);
      expect(result.move.number, 2);
    });
  });
}
