import 'dart:math' as math;

import 'package:companion_flutter/src/games/gomoku_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('user wins with five horizontal stones', () {
    final engine = GomokuEngine(random: math.Random(1));
    GomokuMoveResult? result;
    for (var col = 3; col <= 7; col += 1) {
      result = engine.place(GomokuPoint(7, col), GomokuActor.user);
      if (col < 7) {
        engine.place(GomokuPoint(9, col), GomokuActor.agent);
      }
    }

    expect(result!.status, GomokuGameStatus.userWon);
    expect(result.winningLine.length, 5);
    expect(engine.moves.length, 9);
    expect(engine.analyze().userLongestChain, 5);
  });

  test('user wins with five diagonal stones', () {
    final engine = GomokuEngine(random: math.Random(6));
    GomokuMoveResult? result;
    for (var offset = 0; offset < 5; offset += 1) {
      result = engine.place(
        GomokuPoint(3 + offset, 4 + offset),
        GomokuActor.user,
      );
      if (offset < 4) {
        engine.place(GomokuPoint(12, offset * 2), GomokuActor.agent);
      }
    }

    expect(result!.status, GomokuGameStatus.userWon);
    expect(result.winningLine, [
      const GomokuPoint(3, 4),
      const GomokuPoint(4, 5),
      const GomokuPoint(5, 6),
      const GomokuPoint(6, 7),
      const GomokuPoint(7, 8),
    ]);
  });

  test('occupied points and wrong turns are rejected', () {
    final engine = GomokuEngine(random: math.Random(2));
    engine.place(const GomokuPoint(7, 7), GomokuActor.user);

    expect(
      () => engine.place(const GomokuPoint(7, 8), GomokuActor.user),
      throwsA(isA<StateError>()),
    );
    expect(
      () => engine.place(const GomokuPoint(7, 7), GomokuActor.agent),
      throwsA(isA<StateError>()),
    );
  });

  test('AI blocks an immediate user win', () {
    final engine = GomokuEngine(random: math.Random(3));
    for (var col = 4; col <= 7; col += 1) {
      engine.place(GomokuPoint(7, col), GomokuActor.user);
      engine.place(GomokuPoint(9, col * 2), GomokuActor.agent);
    }
    engine.place(const GomokuPoint(13, 13), GomokuActor.user);

    final decision = engine.chooseAiMoveSync();

    expect(decision.reason, 'block_win');
    expect(
      decision.point,
      anyOf(const GomokuPoint(7, 3), const GomokuPoint(7, 8)),
    );
  });

  test('AI always takes its own winning move first', () {
    final engine = GomokuEngine(random: math.Random(4));
    for (var col = 4; col <= 7; col += 1) {
      engine.place(GomokuPoint(2, col), GomokuActor.user);
      engine.place(GomokuPoint(9, col), GomokuActor.agent);
    }
    engine.place(const GomokuPoint(13, 13), GomokuActor.user);

    final decision = engine.chooseAiMoveSync();

    expect(decision.reason, 'finish_win');
    expect(
      decision.point,
      anyOf(const GomokuPoint(9, 3), const GomokuPoint(9, 8)),
    );
  });

  test('AI decision records professional search diagnostics', () {
    final engine = GomokuEngine(random: math.Random(8));
    engine.place(const GomokuPoint(7, 7), GomokuActor.user);

    final decision = engine.chooseAiMoveSync();
    final json = decision.toJson();

    expect(decision.searchDepth, greaterThanOrEqualTo(1));
    expect(decision.nodesSearched, greaterThanOrEqualTo(1));
    expect(decision.principalVariation, isNotEmpty);
    expect(json['algorithm'], 'iterative_deepening_alpha_beta_tss');
  });

  test('move payload contains analysis and stable coordinates', () {
    final engine = GomokuEngine(random: math.Random(5));
    final result = engine.place(const GomokuPoint(7, 7), GomokuActor.user);
    final json = result.move.toJson();

    expect(json['coordinate'], 'H8');
    expect(json['actor'], 'user');
    expect(json['analysis'], isA<Map<String, dynamic>>());
    expect(
      (json['analysis'] as Map<String, dynamic>)['board_hash'],
      hasLength(GomokuEngine.boardSize * GomokuEngine.boardSize),
    );
  });
}
