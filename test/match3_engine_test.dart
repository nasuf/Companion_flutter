import 'package:companion_flutter/src/games/match3_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generated board starts stable and always has a legal swap', () {
    final engine = Match3Engine(seed: 42);
    expect(engine.board, hasLength(64));
    expect(engine.availableSwaps(), isNotEmpty);
    expect(engine.stateJson()['status'], Match3Status.playing.name);
  });

  test('a legal swap resolves score, cascades and turn record', () {
    final engine = Match3Engine(seed: 9);
    final before = engine.stateHash;
    final result = engine.swap(engine.availableSwaps().first);
    expect(result.turn.score, greaterThan(0));
    expect(result.turn.cascades, isNotEmpty);
    expect(result.turn.stateBeforeHash, before);
    expect(result.turn.stateAfterHash, isNot(before));
    expect(engine.turn, Match3Actor.agent);
  });

  test('agent exhaustively evaluates all currently legal swaps', () {
    final engine = Match3Engine(seed: 17);
    engine.swap(engine.availableSwaps().first);
    final legal = engine.availableSwaps();
    final decision = engine.chooseAgentSwap();
    expect(decision.candidatesConsidered, legal.length);
    expect(decision.nodes, greaterThanOrEqualTo(legal.length));
    expect(decision.projectedCascades, greaterThan(0));
    expect(decision.futureMobility, greaterThan(0));
    expect(
      legal.any(
        (swap) =>
            (swap.a == decision.swap.a && swap.b == decision.swap.b) ||
            (swap.a == decision.swap.b && swap.b == decision.swap.a),
      ),
      isTrue,
    );
  });

  test('summary preserves every swap and cascade wave', () {
    final engine = Match3Engine(seed: 33);
    engine.swap(engine.availableSwaps().first);
    final decision = engine.chooseAgentSwap();
    engine.swap(decision.swap, decision: decision);
    final summary = engine.summaryJson();
    expect(summary['actions'], hasLength(2));
    expect((summary['final_state'] as Map)['board'], hasLength(64));
  });

  test('non-adjacent and non-matching swaps are rejected', () {
    final engine = Match3Engine(seed: 91);
    expect(
      () => engine.swap(const Match3Swap(Match3Point(0, 0), Match3Point(2, 0))),
      throwsStateError,
    );
    Match3Swap? invalidAdjacent;
    for (var row = 0; row < Match3Engine.size; row++) {
      for (var col = 0; col + 1 < Match3Engine.size; col++) {
        final candidate = Match3Swap(
          Match3Point(row, col),
          Match3Point(row, col + 1),
        );
        final legal = engine.availableSwaps().any(
          (swap) =>
              (swap.a == candidate.a && swap.b == candidate.b) ||
              (swap.a == candidate.b && swap.b == candidate.a),
        );
        if (!legal) invalidAdjacent ??= candidate;
      }
    }
    expect(invalidAdjacent, isNotNull);
    expect(() => engine.swap(invalidAdjacent!), throwsStateError);
  });

  test('four or more matched tiles create a tracked special tile', () {
    Match3TurnResult? specialResult;
    for (var seed = 1; seed <= 40 && specialResult == null; seed++) {
      final source = Match3Engine(seed: seed);
      for (final swap in source.availableSwaps()) {
        final candidate = Match3Engine.debug(source.board, seed: seed);
        final result = candidate.swap(swap);
        if (result.turn.cascades.any(
          (wave) => wave.createdSpecials.isNotEmpty,
        )) {
          specialResult = result;
          break;
        }
      }
    }

    expect(specialResult, isNotNull);
    expect(
      specialResult!.turn.cascades
          .expand((wave) => wave.createdSpecials)
          .toList(),
      isNotEmpty,
    );
  });

  test(
    'cascade waves preserve presentation snapshots for phased animation',
    () {
      final engine = Match3Engine(seed: 19);
      final result = engine.swap(engine.availableSwaps().first);
      final firstWave = result.turn.cascades.first;

      expect(result.turn.boardBefore, hasLength(64));
      expect(result.turn.boardAfter, hasLength(64));
      expect(firstWave.boardBefore, hasLength(64));
      expect(firstWave.boardAfterClear, hasLength(64));
      expect(firstWave.boardAfter, hasLength(64));
      expect(
        firstWave.cleared.any(
          (point) => firstWave.boardAfterClear[point.index].color < 0,
        ),
        isTrue,
      );
    },
  );

  test('swapping two color specials clears the complete board in one wave', () {
    final source = Match3Engine(seed: 51);
    final board = List<Match3Tile>.from(source.board);
    board[0] = const Match3Tile(color: 0, special: Match3Special.color);
    board[1] = const Match3Tile(color: 1, special: Match3Special.color);
    final engine = Match3Engine.debug(board, seed: 51);

    final result = engine.swap(
      const Match3Swap(Match3Point(0, 0), Match3Point(0, 1)),
    );

    expect(result.turn.cascades.first.cleared, hasLength(64));
    expect(
      result.turn.cascades.first.triggeredSpecials,
      contains(containsPair('combo', 'double_color_clear')),
    );
  });

  test('color special targets the swapped partner color', () {
    final source = Match3Engine(seed: 73);
    final board = List<Match3Tile>.from(source.board);
    board[0] = const Match3Tile(color: 0, special: Match3Special.color);
    board[1] = const Match3Tile(color: 4);
    final expectedColorCount = board.where((tile) => tile.color == 4).length;
    final engine = Match3Engine.debug(board, seed: 73);

    final result = engine.swap(
      const Match3Swap(Match3Point(0, 0), Match3Point(0, 1)),
    );

    expect(
      result.turn.cascades.first.cleared.length,
      greaterThanOrEqualTo(expectedColorCount),
    );
    expect(
      result.turn.cascades.first.triggeredSpecials,
      contains(containsPair('combo', 'color_clear')),
    );
  });
}
