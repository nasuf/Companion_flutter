import 'dart:math';

import 'package:bishop/bishop.dart' as bishop;
import 'package:companion_flutter/src/games/chess_family_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('xiangqi end conditions', () {
    test('checkmate ends the game', () {
      // Black general boxed in on e10 by three red chariots.
      final engine = ChessFamilyEngine(
        kind: ChessFamilyKind.xiangqi,
        fen: 'R3k4/R8/9/9/9/9/9/9/9/3KR4 b - - 0 1',
      );
      expect(engine.isFinished, isTrue);
      expect(engine.status, ChessFamilyStatus.userWon);
    });

    test('plain check does not end the game', () {
      final engine = ChessFamilyEngine(
        kind: ChessFamilyKind.xiangqi,
        fen: '4k4/9/9/9/9/9/9/9/9/3KR4 b - - 0 1',
      );
      expect(engine.isFinished, isFalse);
      expect(engine.analyze().inCheck, isTrue);
    });

    test('the checked general is reported so the board can flag it', () {
      // Black chariot down the open e-file onto the red general.
      final checked = ChessFamilyEngine(
        kind: ChessFamilyKind.xiangqi,
        fen: '3kr4/9/9/9/9/9/9/9/9/3AKA3 w - - 0 1',
      );
      final general = checked.pieces.singleWhere(
        (piece) =>
            piece.symbol.toUpperCase() == 'K' &&
            piece.actor == ChessFamilyActor.user,
      );
      expect(checked.analyze().inCheck, isTrue);
      expect(checked.checkedRoyalSquare, general.square);

      final quiet = ChessFamilyEngine(kind: ChessFamilyKind.xiangqi);
      expect(quiet.checkedRoyalSquare, isNull);
    });

    test('being in check does not lock the other pieces', () {
      // Standard xiangqi would only allow moves that answer the check. Here any
      // move is playable — walking into the check just loses the general.
      final engine = ChessFamilyEngine(
        kind: ChessFamilyKind.xiangqi,
        fen: '3kr4/9/9/9/P8/9/9/9/9/3AKA3 w - - 0 1',
      );
      expect(engine.analyze().inCheck, isTrue);
      final pawn = engine.pieces.singleWhere(
        (piece) => piece.symbol.toUpperCase() == 'P',
      );
      expect(
        engine.legalDestinations(pawn.square),
        isNotEmpty,
        reason: 'a pawn far from the action must still be movable',
      );
    });

    test('walking into check loses the general on the reply', () {
      final engine = ChessFamilyEngine(
        kind: ChessFamilyKind.xiangqi,
        fen: '3kr4/9/9/9/P8/9/9/9/9/3AKA3 w - - 0 1',
      );
      final pawn = engine.pieces.singleWhere(
        (piece) => piece.symbol.toUpperCase() == 'P',
      );
      // Ignore the check and push the pawn instead.
      final ignored = engine.play(
        from: pawn.square,
        to: engine.legalDestinations(pawn.square).first,
      );
      expect(ignored.status, ChessFamilyStatus.playing);

      // The chariot now simply takes the general.
      final chariot = engine.pieces.singleWhere(
        (piece) => piece.symbol.toUpperCase() == 'R',
      );
      final general = engine.pieces.singleWhere(
        (piece) =>
            piece.symbol.toUpperCase() == 'K' &&
            piece.actor == ChessFamilyActor.user,
      );
      expect(
        engine.legalDestinations(chariot.square),
        contains(general.square),
        reason: 'the general is there for the taking',
      );
      final result = engine.play(from: chariot.square, to: general.square);
      expect(result.move.capturedPiece, isNotNull);
      expect(result.status, ChessFamilyStatus.agentWon);
      expect(engine.isFinished, isTrue);
    });

    test('白脸将: exposing the generals to each other loses', () {
      // The advisor on e2 is all that stands between the two generals.
      final engine = ChessFamilyEngine(
        kind: ChessFamilyKind.xiangqi,
        fen: '4k4/9/9/9/9/9/9/9/4A4/4K4 w - - 0 1',
      );
      final advisor = engine.pieces.singleWhere(
        (piece) => piece.symbol.toUpperCase() == 'A',
      );
      final result = engine.play(
        from: advisor.square,
        to: engine.legalDestinations(advisor.square).first,
      );
      expect(result.status, ChessFamilyStatus.agentWon);
      expect(engine.isFinished, isTrue);
    });

    test('chess keeps the standard rules', () {
      // Only xiangqi is played capture-the-king.
      final engine = ChessFamilyEngine(kind: ChessFamilyKind.chess);
      expect(engine.analyze().legalMoveCount, 20);
    });

    test('a repeated position is drawn instead of running forever', () {
      // A chariot shuffling on the back rank can never mate a lone general;
      // without a repetition rule the game has no way to end. The generals sit
      // on different files so the face-off rule stays out of it.
      final engine = ChessFamilyEngine(
        kind: ChessFamilyKind.xiangqi,
        fen: '3k5/9/9/9/9/9/9/9/9/R4K3 w - - 0 1',
      );
      const cycle = ['a1a2', 'd10d9', 'a2a1', 'd9d10'];
      var plies = 0;
      while (!engine.isFinished && plies < 40) {
        engine.playAlgebraic(cycle[plies % cycle.length]);
        plies += 1;
      }
      expect(engine.isFinished, isTrue);
      expect(engine.status, ChessFamilyStatus.draw);
    });

    test('the packaged variant still needs every one of our overrides', () {
      // Each of these is corrected in _xiangqiVariant; if a future version of
      // the package fixes one, the override can go.
      final variant = bishop.Xiangqi.xiangqi();
      expect(variant.repetitionDraw, isNull, reason: 'no repetition draw');
      expect(variant.halfMoveDraw, isNull, reason: 'no move-limit draw');
      expect(
        variant.gameEndConditions.white.stalemate,
        bishop.EndType.draw,
        reason: '困毙 is scored as a draw',
      );
      expect(
        variant.actions,
        isNotEmpty,
        reason: '白脸将 ships as an action that rejects the move outright',
      );
    });
  });

  group('xiangqi agent', () {
    test('plays an available mate in 1', () async {
      for (var attempt = 0; attempt < 5; attempt += 1) {
        final engine = ChessFamilyEngine(
          kind: ChessFamilyKind.xiangqi,
          fen: '3k5/9/9/9/9/8r/9/9/r8/4K4 b - - 0 1',
        );
        final decision = await engine.chooseAiMove();
        engine.playAlgebraic(decision.algebraic);
        expect(engine.isFinished, isTrue);
        expect(engine.status, ChessFamilyStatus.agentWon);
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    test(
      'every move the agent returns can actually be played',
      () async {
        // In a lost position the agent picks a move that walks into the check,
        // which is legal here but absent from bishop's strict move list. Looking
        // it up there threw, the turn stayed with the agent, and the whole board
        // stopped responding with nothing shown to the player.
        const fen = '4k4/9/4R4/9/9/9/9/9/9/3AKA3 b - - 0 1';
        for (var attempt = 0; attempt < 4; attempt += 1) {
          final engine = ChessFamilyEngine(
            kind: ChessFamilyKind.xiangqi,
            fen: fen,
          );
          expect(engine.isFinished, isFalse);
          final decision = await engine.chooseAiMove();
          expect(
            () => engine.playAlgebraic(decision.algebraic),
            returnsNormally,
            reason: 'the agent chose ${decision.algebraic}',
          );
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'converts a won game instead of grinding it out',
      () async {
        // Against careless play the agent used to collect every last piece
        // before mating: 110/74/54/56 plies over these seeds, leaving the loser
        // with 1-2 pieces. With the finishing search it lands around 50.
        final lengths = <int>[];
        var wins = 0;
        for (var seed = 0; seed < 3; seed += 1) {
          final random = Random(seed);
          final engine = ChessFamilyEngine(kind: ChessFamilyKind.xiangqi);
          var plies = 0;
          while (!engine.isFinished && plies < 300) {
            if (engine.isAgentTurn) {
              final decision = await engine.chooseAiMove();
              engine.playAlgebraic(decision.algebraic);
            } else {
              final options = <List<int>>[];
              for (final piece in engine.pieces.where(
                (p) => p.actor == ChessFamilyActor.user,
              )) {
                for (final to in engine.legalDestinations(piece.square)) {
                  options.add([piece.square, to]);
                }
              }
              if (options.isEmpty) break;
              final pick = options[random.nextInt(options.length)];
              engine.play(from: pick[0], to: pick[1]);
            }
            plies += 1;
          }
          expect(engine.isFinished, isTrue, reason: 'seed $seed never ended');
          if (engine.status == ChessFamilyStatus.agentWon) wins += 1;
          lengths.add(plies);
        }
        final average = lengths.reduce((a, b) => a + b) / lengths.length;
        expect(
          average,
          lessThan(80),
          reason: 'games ran $lengths, averaging $average plies',
        );
        // The agent picks its second-best move 14% of the time by design, so the
        // odd game drifts into a repetition draw. Most should still be converted.
        expect(
          wins,
          greaterThanOrEqualTo(2),
          reason: 'only $wins of ${lengths.length} won; lengths $lengths',
        );
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );
  });
}
