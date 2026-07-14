import 'package:companion_flutter/src/games/ludo_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a six launches a piece and grants an extra turn', () {
    final engine = LudoEngine(seed: 1);
    final roll = engine.roll(forcedValue: 6);
    expect(roll.legalPieces, [0, 1, 2, 3]);
    final result = engine.movePiece(0);
    expect(result.move.toProgress, 0);
    expect(result.move.extraTurn, isTrue);
    expect(engine.turn, LudoActor.user);
    expect(engine.stateJson()['status'], LudoStatus.playing.name);
  });

  test('non-six cannot launch and passes the turn', () {
    final engine = LudoEngine(seed: 1);
    final roll = engine.roll(forcedValue: 3);
    expect(roll.legalPieces, isEmpty);
    expect(engine.turn, LudoActor.agent);
    expect(engine.pendingRoll, isNull);
  });

  test('agent expectimax chooses a legal piece with diagnostics', () {
    final engine = LudoEngine(seed: 2);
    engine.roll(forcedValue: 2);
    final roll = engine.roll(forcedValue: 6);
    expect(engine.turn, LudoActor.agent);
    final decision = engine.chooseAgentPiece();
    expect(roll.legalPieces, contains(decision.pieceIndex));
    expect(decision.nodes, greaterThan(0));
    final result = engine.movePiece(decision.pieceIndex, decision: decision);
    expect(result.move.decision?.toJson()['algorithm'], contains('expectimax'));
  });

  test('three consecutive sixes forfeit the turn', () {
    final engine = LudoEngine(seed: 3);
    engine.roll(forcedValue: 6);
    engine.movePiece(0);
    engine.roll(forcedValue: 6);
    engine.movePiece(0);
    final third = engine.roll(forcedValue: 6);
    expect(third.forfeited, isTrue);
    expect(engine.turn, LudoActor.agent);
  });

  test('roll snapshots distinguish consecutive-six rule state', () {
    final engine = LudoEngine(seed: 3);
    final firstBefore = engine.stateHash;
    final first = engine.roll(forcedValue: 6);

    expect(first.stateHash, firstBefore);
    expect(engine.stateJson()['consecutive_sixes'], 1);
    expect(engine.stateHash, isNot(firstBefore));

    engine.movePiece(0);
    final secondBefore = engine.stateHash;
    final second = engine.roll(forcedValue: 6);
    expect(second.stateHash, secondBefore);
    expect(engine.stateJson()['consecutive_sixes'], 2);
  });

  test('landing on an unsafe occupied cell captures the opponent', () {
    final engine = LudoEngine.debug(
      user: [6, -1, -1, -1],
      agent: [35, -1, -1, -1],
    );

    engine.roll(forcedValue: 3);
    final result = engine.movePiece(0);

    expect(result.move.captured, hasLength(1));
    expect(
      engine.pieces
          .firstWhere(
            (piece) => piece.actor == LudoActor.agent && piece.index == 0,
          )
          .inYard,
      isTrue,
    );
    expect(result.move.moment?['type'], 'capture');
    expect(result.move.extraTurn, isFalse);
    expect(engine.turn, LudoActor.agent);
  });

  test('landing on an own-color flight cell jumps four extra spaces', () {
    final engine = LudoEngine.debug(
      user: [8, -1, -1, -1],
      agent: [-1, -1, -1, -1],
    );

    final roll = engine.roll(forcedValue: 2);
    final result = engine.movePiece(0);

    expect(result.move.rolledToProgress, 10);
    expect(result.move.toProgress, 14);
    expect(result.move.jumpDistance, 4);
    expect(result.move.shortcutUsed, isFalse);
    expect(result.move.moment?['type'], 'color_jump');
    expect(result.move.rollStateBeforeHash, roll.stateHash);
    expect(result.move.toJson()['roll_state_before_hash'], isNotEmpty);
  });

  test('a color jump can continue through the cross-board shortcut', () {
    final engine = LudoEngine.debug(
      user: [12, -1, -1, -1],
      agent: [-1, -1, -1, -1],
    );

    engine.roll(forcedValue: 2);
    final result = engine.movePiece(0);

    expect(result.move.rolledToProgress, 14);
    expect(result.move.toProgress, LudoEngine.shortcutExitProgress);
    expect(result.move.jumpDistance, 16);
    expect(result.move.shortcutUsed, isTrue);
    expect(result.move.moment?['type'], 'flight_shortcut');
  });

  test('home lane movement never triggers a color jump', () {
    final engine = LudoEngine.debug(
      user: [51, -1, -1, -1],
      agent: [-1, -1, -1, -1],
    );

    engine.roll(forcedValue: 2);
    final result = engine.movePiece(0);

    expect(result.move.rolledToProgress, 53);
    expect(result.move.toProgress, 53);
    expect(result.move.jumpDistance, 0);
    expect(result.move.moment?['type'], 'home_stretch');
  });

  test('safe cells protect an opponent from capture', () {
    final engine = LudoEngine.debug(
      user: [5, -1, -1, -1],
      agent: [34, -1, -1, -1],
    );

    engine.roll(forcedValue: 3);
    final result = engine.movePiece(0);

    expect(result.move.captured, isEmpty);
    expect(
      engine.pieces
          .firstWhere(
            (piece) => piece.actor == LudoActor.agent && piece.index == 0,
          )
          .progress,
      34,
    );
  });

  test('home lane requires an exact roll and completes the game', () {
    final blocked = LudoEngine.debug(
      user: [55, 57, 57, 57],
      agent: [-1, -1, -1, -1],
    );
    expect(blocked.legalPieces(3), isEmpty);
    expect(blocked.legalPieces(2), [0]);

    blocked.roll(forcedValue: 2);
    final result = blocked.movePiece(0);
    expect(result.status, LudoStatus.userWon);
    expect(result.move.moment?['type'], 'piece_finished');
  });
}
