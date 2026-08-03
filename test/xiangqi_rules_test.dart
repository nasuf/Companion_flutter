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

    test('困毙 loses for the side with no move, unlike chess', () {
      // Red to move: not in check, but every palace square is covered.
      final engine = ChessFamilyEngine(
        kind: ChessFamilyKind.xiangqi,
        fen: '3r1r3/4k4/9/9/9/9/9/4p4/9/4K4 w - - 0 1',
      );
      expect(engine.isFinished, isTrue);
      expect(
        engine.status,
        ChessFamilyStatus.agentWon,
        reason: 'the stalemated side loses in xiangqi',
      );
    });

    test('a repeated position is drawn instead of running forever', () {
      // Two bare generals can never mate; without a repetition rule the game
      // has no way to end.
      final engine = ChessFamilyEngine(
        kind: ChessFamilyKind.xiangqi,
        fen: '4k4/9/9/9/9/9/9/9/9/4K4 w - - 0 1',
      );
      var plies = 0;
      while (!engine.isFinished && plies < 200) {
        final options = <List<int>>[];
        for (final piece in engine.pieces) {
          if ((piece.actor == ChessFamilyActor.agent) != engine.isAgentTurn) {
            continue;
          }
          for (final to in engine.legalDestinations(piece.square)) {
            options.add([piece.square, to]);
          }
        }
        if (options.isEmpty) break;
        engine.play(from: options.first[0], to: options.first[1]);
        plies += 1;
      }
      expect(engine.isFinished, isTrue);
      expect(engine.status, ChessFamilyStatus.draw);
    });

    test('the search plays under the same rules as the board', () {
      // A mismatch here would have the agent evaluating stalemates and
      // repetitions differently to the game actually being played.
      final variant = bishop.Xiangqi.xiangqi();
      expect(variant.repetitionDraw, isNull);
      expect(
        variant.gameEndConditions.white.stalemate,
        bishop.EndType.draw,
        reason: 'guards the assumption that the packaged variant needs fixing',
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

    test('converts a won game instead of grinding it out', () async {
      // Against careless play the agent used to collect every last piece
      // before mating: 110/74/54/56 plies over these seeds, leaving the loser
      // with 1-2 pieces. With the finishing search it lands around 50.
      final lengths = <int>[];
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
        expect(
          engine.status,
          ChessFamilyStatus.agentWon,
          reason: 'seed $seed: a winning position must not peter out',
        );
        lengths.add(plies);
      }
      final average = lengths.reduce((a, b) => a + b) / lengths.length;
      expect(
        average,
        lessThan(80),
        reason: 'games ran $lengths, averaging $average plies',
      );
    }, timeout: const Timeout(Duration(minutes: 10)));
  });
}
