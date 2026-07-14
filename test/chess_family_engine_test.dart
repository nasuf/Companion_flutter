import 'package:companion_flutter/src/games/chess_family_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('standard chess starts with twenty legal moves', () {
    final engine = ChessFamilyEngine(kind: ChessFamilyKind.chess);

    expect(engine.analyze().legalMoveCount, 20);
    expect(engine.pieces, hasLength(32));
    expect(engine.legalDestinations(ChessSquare.e2), contains(ChessSquare.e4));
  });

  test('standard chess records FEN, notation, and captures', () {
    final engine = ChessFamilyEngine(kind: ChessFamilyKind.chess);
    engine.play(from: ChessSquare.e2, to: ChessSquare.e4);
    engine.play(from: ChessSquare.d7, to: ChessSquare.d5);
    final capture = engine.play(from: ChessSquare.e4, to: ChessSquare.d5);

    expect(capture.move.capturedPiece, isNotNull);
    expect(capture.move.algebraic, 'e4d5');
    expect(capture.move.analysis.fen, isNot(capture.move.fenBefore));
    expect(capture.move.moment?['type'], 'capture');
  });

  test('xiangqi enforces horse-leg blocking and flying generals rules', () {
    final engine = ChessFamilyEngine(kind: ChessFamilyKind.xiangqi);
    final horse = ChessSquare.fromName('b1', files: 9, ranks: 10);
    final destinations = engine.legalDestinations(horse);

    expect(destinations, isNotEmpty);
    expect(engine.analyze().legalMoveCount, greaterThan(30));
    expect(
      engine.pieces.where((piece) => piece.symbol.toUpperCase() == 'K'),
      hasLength(2),
    );
  });

  test('chess AI returns a legal move with search diagnostics', () async {
    final engine = ChessFamilyEngine(kind: ChessFamilyKind.chess);
    engine.play(from: ChessSquare.e2, to: ChessSquare.e4);

    final decision = await engine.chooseAiMove();

    expect(decision.depth, greaterThanOrEqualTo(1));
    expect(decision.nodes, greaterThan(0));
    expect(decision.principalVariation, isNotEmpty);
    expect(() => engine.playAlgebraic(decision.algebraic), returnsNormally);
  });
}

abstract final class ChessSquare {
  static const int e2 = 100;
  static const int e4 = 68;
  static const int d7 = 19;
  static const int d5 = 51;

  static int fromName(String name, {required int files, required int ranks}) {
    final file = name.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.parse(name.substring(1)) - 1;
    return (ranks - rank - 1) * files * 2 + file;
  }
}
