import 'dart:math' as math;

enum Match3Actor { user, agent }

enum Match3Special { none, row, column, bomb, color }

enum Match3Status { playing, completed, failed }

class Match3Point {
  const Match3Point(this.row, this.col);
  final int row;
  final int col;
  int get index => row * Match3Engine.size + col;

  Map<String, dynamic> toJson() => {'row': row, 'col': col};
  @override
  bool operator ==(Object other) =>
      other is Match3Point && row == other.row && col == other.col;
  @override
  int get hashCode => Object.hash(row, col);
}

class Match3Tile {
  const Match3Tile({required this.color, this.special = Match3Special.none});
  final int color;
  final Match3Special special;

  Match3Tile copyWith({int? color, Match3Special? special}) =>
      Match3Tile(color: color ?? this.color, special: special ?? this.special);
  Map<String, dynamic> toJson() => {'color': color, 'special': special.name};
}

class Match3Swap {
  const Match3Swap(this.a, this.b);
  final Match3Point a;
  final Match3Point b;
  Map<String, dynamic> toJson() => {'a': a.toJson(), 'b': b.toJson()};
}

class Match3CascadeWave {
  const Match3CascadeWave({
    required this.index,
    required this.cleared,
    required this.score,
    required this.createdSpecials,
    required this.triggeredSpecials,
    required this.boardHash,
    required this.boardBefore,
    required this.boardAfterClear,
    required this.boardAfter,
  });
  final int index;
  final List<Match3Point> cleared;
  final int score;
  final List<Map<String, dynamic>> createdSpecials;
  final List<Map<String, dynamic>> triggeredSpecials;
  final int boardHash;
  final List<Match3Tile> boardBefore;
  final List<Match3Tile> boardAfterClear;
  final List<Match3Tile> boardAfter;

  Map<String, dynamic> toJson() => {
    'cascade_index': index,
    'cleared_count': cleared.length,
    'cleared': [for (final point in cleared) point.toJson()],
    'score': score,
    'created_specials': createdSpecials,
    'triggered_specials': triggeredSpecials,
    'board_hash': boardHash.toString(),
  };
}

class Match3Turn {
  const Match3Turn({
    required this.number,
    required this.actor,
    required this.swap,
    required this.stateBeforeHash,
    required this.stateAfterHash,
    required this.score,
    required this.cascades,
    required this.shuffled,
    required this.moment,
    required this.boardBefore,
    required this.boardAfter,
    this.decision,
  });
  final int number;
  final Match3Actor actor;
  final Match3Swap swap;
  final int stateBeforeHash;
  final int stateAfterHash;
  final int score;
  final List<Match3CascadeWave> cascades;
  final bool shuffled;
  final Map<String, dynamic>? moment;
  final List<Match3Tile> boardBefore;
  final List<Match3Tile> boardAfter;
  final Match3AiDecision? decision;

  Map<String, dynamic> toJson() => {
    'move_number': number,
    'actor': actor.name,
    'swap': swap.toJson(),
    'from': swap.a.toJson(),
    'to': swap.b.toJson(),
    'state_before_hash': stateBeforeHash.toString(),
    'state_after_hash': stateAfterHash.toString(),
    'score': score,
    'cascade_count': cascades.length,
    'cascades': [for (final cascade in cascades) cascade.toJson()],
    'shuffled': shuffled,
    if (moment != null) 'moment': moment,
    if (decision != null) 'decision': decision!.toJson(),
  };
}

class Match3AiDecision {
  const Match3AiDecision({
    required this.swap,
    required this.score,
    required this.projectedClears,
    required this.projectedSpecials,
    required this.candidatesConsidered,
    required this.nodes,
    required this.projectedCascades,
    required this.futureMobility,
  });
  final Match3Swap swap;
  final double score;
  final int projectedClears;
  final int projectedSpecials;
  final int candidatesConsidered;
  final int nodes;
  final int projectedCascades;
  final int futureMobility;

  Map<String, dynamic> toJson() => {
    'swap': swap.toJson(),
    'score': score,
    'projected_clears': projectedClears,
    'projected_specials': projectedSpecials,
    'candidates_considered': candidatesConsidered,
    'nodes_searched': nodes,
    'projected_cascades': projectedCascades,
    'future_mobility': futureMobility,
    'algorithm': 'exhaustive_full_cascade_projection_with_mobility',
  };
}

class Match3TurnResult {
  const Match3TurnResult({required this.turn, required this.status});
  final Match3Turn turn;
  final Match3Status status;
}

class Match3Engine {
  Match3Engine({
    int seed = 20260714,
    this.turnLimit = 30,
    this.targetScore = 12000,
  }) : _seed = seed,
       _random = math.Random(seed) {
    _board = _generatePlayableBoard(_random);
  }

  Match3Engine.debug(
    List<Match3Tile> board, {
    int seed = 7,
    this.turnLimit = 30,
    this.targetScore = 12000,
  }) : assert(board.length == size * size),
       _seed = seed,
       _random = math.Random(seed),
       _board = List<Match3Tile>.from(board);

  factory Match3Engine.restore(
    Map<String, dynamic> state, {
    int actionCount = 0,
    int seed = 20260714,
    int turnLimit = 30,
    int targetScore = 12000,
  }) {
    final rawBoard = state['board'];
    if (rawBoard is! List || rawBoard.length != size * size) {
      throw const FormatException('invalid_board');
    }
    final board = rawBoard
        .map((raw) {
          final tile = Map<String, dynamic>.from(raw as Map);
          return Match3Tile(
            color: (tile['color'] as num).round(),
            special: Match3Special.values.firstWhere(
              (item) => item.name == tile['special'],
              orElse: () => Match3Special.none,
            ),
          );
        })
        .toList(growable: false);
    final engine = Match3Engine.debug(
      board,
      seed: seed,
      turnLimit: turnLimit,
      targetScore: targetScore,
    );
    engine.turn = Match3Actor.values.firstWhere(
      (item) => item.name == state['turn'],
      orElse: () => Match3Actor.user,
    );
    engine.userScore = (state['user_score'] as num?)?.round() ?? 0;
    engine.agentScore = (state['agent_score'] as num?)?.round() ?? 0;
    engine._turnOffset = actionCount;
    return engine;
  }

  static const int size = 8;
  static const int colorCount = 6;

  final int _seed;
  final math.Random _random;
  final int turnLimit;
  final int targetScore;
  late List<Match3Tile> _board;
  final List<Match3Turn> _turns = [];
  int _turnOffset = 0;
  Match3Actor turn = Match3Actor.user;
  int userScore = 0;
  int agentScore = 0;

  List<Match3Tile> get board => List.unmodifiable(_board);
  List<Match3Turn> get turns => List.unmodifiable(_turns);
  int get totalScore => userScore + agentScore;
  int get turnsRemaining =>
      math.max(0, turnLimit - _turnOffset - _turns.length);
  int get stateHash =>
      _hashMatch3(_board, turn.index, totalScore, turnsRemaining);
  Match3Status get status {
    if (totalScore >= targetScore) return Match3Status.completed;
    if (turnsRemaining <= 0) return Match3Status.failed;
    return Match3Status.playing;
  }

  bool get isFinished => status != Match3Status.playing;

  Match3Tile tileAt(Match3Point point) => _board[point.index];

  List<Match3Swap> availableSwaps() => _availableSwaps(_board);

  Match3AiDecision chooseAgentSwap() {
    if (turn != Match3Actor.agent) throw StateError('not_agent_turn');
    final swaps = availableSwaps();
    if (swaps.isEmpty) throw StateError('no_legal_swap');
    var nodes = 0;
    final scored = <(Match3Swap, double, _Match3Projection)>[];
    for (final swap in swaps) {
      final simulation = _simulateSwapPotential(_board, swap);
      nodes += simulation.nodes;
      final center = 7 - ((swap.b.row - 3.5).abs() + (swap.b.col - 3.5).abs());
      final score =
          simulation.score.toDouble() +
          simulation.specialsCreated * 140 +
          simulation.cascades * 85 +
          simulation.futureMobility * 1.6 +
          center;
      scored.add((swap, score, simulation));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final selected = scored.first;
    return Match3AiDecision(
      swap: selected.$1,
      score: selected.$2,
      projectedClears: selected.$3.cleared,
      projectedSpecials: selected.$3.specialsCreated,
      candidatesConsidered: swaps.length,
      nodes: nodes,
      projectedCascades: selected.$3.cascades,
      futureMobility: selected.$3.futureMobility,
    );
  }

  Match3TurnResult swap(Match3Swap swap, {Match3AiDecision? decision}) {
    if (isFinished) throw StateError('game_finished');
    if (!_adjacent(swap.a, swap.b)) throw StateError('not_adjacent');
    if (!availableSwaps().containsSwap(swap)) throw StateError('invalid_swap');
    final actor = turn;
    final beforeHash = stateHash;
    final boardBefore = List<Match3Tile>.unmodifiable(_board);
    _swapTiles(_board, swap.a.index, swap.b.index);
    final swapActivation = _swapActivation(_board, swap);
    final waves = <Match3CascadeWave>[];
    var turnScore = 0;
    Match3Point? preferredSpecialPoint = swap.b;
    for (var cascade = 1; cascade <= 20; cascade++) {
      final groups = _matchGroups(_board);
      final activation = cascade == 1
          ? swapActivation
          : const _SwapActivation();
      if (groups.isEmpty && activation.isEmpty) break;
      final resolution = _resolveWave(
        _board,
        groups,
        activation,
        cascade,
        preferredSpecialPoint,
      );
      preferredSpecialPoint = null;
      turnScore += resolution.score;
      _board = resolution.board;
      waves.add(
        Match3CascadeWave(
          index: cascade,
          cleared: [
            for (final index in resolution.cleared)
              Match3Point(index ~/ size, index % size),
          ],
          score: resolution.score,
          createdSpecials: resolution.createdSpecials,
          triggeredSpecials: resolution.triggeredSpecials,
          boardHash: _hashMatch3(
            _board,
            actor.index,
            totalScore + turnScore,
            turnsRemaining,
          ),
          boardBefore: List<Match3Tile>.unmodifiable(resolution.boardBefore),
          boardAfterClear: List<Match3Tile>.unmodifiable(
            resolution.boardAfterClear,
          ),
          boardAfter: List<Match3Tile>.unmodifiable(resolution.board),
        ),
      );
    }
    if (actor == Match3Actor.user) {
      userScore += turnScore;
    } else {
      agentScore += turnScore;
    }
    turn = actor == Match3Actor.user ? Match3Actor.agent : Match3Actor.user;
    var shuffled = false;
    if (_availableSwaps(_board).isEmpty) {
      _shuffleUntilPlayable();
      shuffled = true;
    }
    final moment = waves.length >= 3 || turnScore >= 1200
        ? {
            'type': 'big_cascade',
            'cascade_count': waves.length,
            'score': turnScore,
          }
        : waves.any((wave) => wave.createdSpecials.isNotEmpty)
        ? {'type': 'special_combo', 'score': turnScore}
        : null;
    final afterHash = _hashMatch3(
      _board,
      turn.index,
      totalScore,
      math.max(0, turnLimit - _turnOffset - _turns.length - 1),
    );
    final record = Match3Turn(
      number: _turnOffset + _turns.length + 1,
      actor: actor,
      swap: swap,
      stateBeforeHash: beforeHash,
      stateAfterHash: afterHash,
      score: turnScore,
      cascades: waves,
      shuffled: shuffled,
      moment: moment,
      boardBefore: boardBefore,
      boardAfter: List<Match3Tile>.unmodifiable(_board),
      decision: decision,
    );
    _turns.add(record);
    return Match3TurnResult(turn: record, status: status);
  }

  Map<String, dynamic> stateJson() => {
    'state_hash': stateHash.toString(),
    'turn': turn.name,
    'status': status.name,
    'turns_remaining': turnsRemaining,
    'user_score': userScore,
    'agent_score': agentScore,
    'total_score': totalScore,
    'board': [for (final tile in _board) tile.toJson()],
  };

  Map<String, dynamic> analysisJson() => {
    'state_hash': stateHash.toString(),
    'turn': turn.name,
    'turns_remaining': turnsRemaining,
    'target_score': targetScore,
    'total_score': totalScore,
    'progress': totalScore / targetScore,
    'legal_swap_count': availableSwaps().length,
    'special_count': _board
        .where((tile) => tile.special != Match3Special.none)
        .length,
  };

  Map<String, dynamic> summaryJson() => {
    'status': status.name,
    'turn_count': _turnOffset + _turns.length,
    'user_score': userScore,
    'agent_score': agentScore,
    'total_score': totalScore,
    'target_score': targetScore,
    'actions': [for (final turn in _turns) turn.toJson()],
    'key_moments': [
      for (final turn in _turns)
        if (turn.moment != null) {...turn.moment!, 'move_number': turn.number},
    ],
    'analysis': analysisJson(),
    'final_state': stateJson(),
    'seed': _seed,
  };

  void _shuffleUntilPlayable() {
    final tiles = List<Match3Tile>.from(_board);
    for (var attempt = 0; attempt < 80; attempt++) {
      tiles.shuffle(_random);
      if (_matchGroups(tiles).isEmpty && _availableSwaps(tiles).isNotEmpty) {
        _board = List<Match3Tile>.from(tiles);
        return;
      }
    }
    _board = _generatePlayableBoard(_random);
  }
}

class _WaveResolution {
  const _WaveResolution({
    required this.board,
    required this.boardBefore,
    required this.boardAfterClear,
    required this.cleared,
    required this.score,
    required this.createdSpecials,
    required this.triggeredSpecials,
  });
  final List<Match3Tile> board;
  final List<Match3Tile> boardBefore;
  final List<Match3Tile> boardAfterClear;
  final Set<int> cleared;
  final int score;
  final List<Map<String, dynamic>> createdSpecials;
  final List<Map<String, dynamic>> triggeredSpecials;
}

List<Match3Tile> _generatePlayableBoard(math.Random random) {
  for (var attempt = 0; attempt < 100; attempt++) {
    final board = <Match3Tile>[];
    for (var row = 0; row < Match3Engine.size; row++) {
      for (var col = 0; col < Match3Engine.size; col++) {
        final blocked = <int>{};
        if (col >= 2 &&
            board[row * Match3Engine.size + col - 1].color ==
                board[row * Match3Engine.size + col - 2].color) {
          blocked.add(board[row * Match3Engine.size + col - 1].color);
        }
        if (row >= 2 &&
            board[(row - 1) * Match3Engine.size + col].color ==
                board[(row - 2) * Match3Engine.size + col].color) {
          blocked.add(board[(row - 1) * Match3Engine.size + col].color);
        }
        final choices = [
          for (var color = 0; color < Match3Engine.colorCount; color++)
            if (!blocked.contains(color)) color,
        ];
        board.add(Match3Tile(color: choices[random.nextInt(choices.length)]));
      }
    }
    if (_availableSwaps(board).isNotEmpty) return board;
  }
  throw StateError('unable_to_generate_board');
}

List<Set<int>> _matchGroups(List<Match3Tile> board) {
  final groups = <Set<int>>[];
  for (var row = 0; row < Match3Engine.size; row++) {
    var start = 0;
    while (start < Match3Engine.size) {
      var end = start + 1;
      while (end < Match3Engine.size &&
          board[row * Match3Engine.size + end].color ==
              board[row * Match3Engine.size + start].color) {
        end++;
      }
      if (end - start >= 3) {
        groups.add({
          for (var col = start; col < end; col++) row * Match3Engine.size + col,
        });
      }
      start = end;
    }
  }
  for (var col = 0; col < Match3Engine.size; col++) {
    var start = 0;
    while (start < Match3Engine.size) {
      var end = start + 1;
      while (end < Match3Engine.size &&
          board[end * Match3Engine.size + col].color ==
              board[start * Match3Engine.size + col].color) {
        end++;
      }
      if (end - start >= 3) {
        groups.add({
          for (var row = start; row < end; row++) row * Match3Engine.size + col,
        });
      }
      start = end;
    }
  }
  return groups;
}

List<Match3Swap> _availableSwaps(List<Match3Tile> board) {
  final result = <Match3Swap>[];
  for (var row = 0; row < Match3Engine.size; row++) {
    for (var col = 0; col < Match3Engine.size; col++) {
      final a = Match3Point(row, col);
      for (final b in [
        if (col + 1 < Match3Engine.size) Match3Point(row, col + 1),
        if (row + 1 < Match3Engine.size) Match3Point(row + 1, col),
      ]) {
        final copy = List<Match3Tile>.from(board);
        _swapTiles(copy, a.index, b.index);
        final special =
            board[a.index].special != Match3Special.none ||
            board[b.index].special != Match3Special.none;
        if (special || _matchGroups(copy).isNotEmpty) {
          result.add(Match3Swap(a, b));
        }
      }
    }
  }
  return result;
}

class _SwapActivation {
  const _SwapActivation({
    this.specialIndices = const {},
    this.forcedClear = const {},
    this.colorTargets = const {},
    this.comboType,
  });

  final Set<int> specialIndices;
  final Set<int> forcedClear;
  final Map<int, int> colorTargets;
  final String? comboType;

  bool get isEmpty => specialIndices.isEmpty && forcedClear.isEmpty;
}

_SwapActivation _swapActivation(List<Match3Tile> board, Match3Swap swap) {
  final a = board[swap.a.index];
  final b = board[swap.b.index];
  final aSpecial = a.special != Match3Special.none;
  final bSpecial = b.special != Match3Special.none;
  if (!aSpecial && !bSpecial) return const _SwapActivation();

  if (a.special == Match3Special.color && b.special == Match3Special.color) {
    return _SwapActivation(
      specialIndices: {swap.a.index, swap.b.index},
      forcedClear: {for (var index = 0; index < board.length; index++) index},
      comboType: 'double_color_clear',
    );
  }

  if (a.special == Match3Special.color || b.special == Match3Special.color) {
    final colorIndex = a.special == Match3Special.color
        ? swap.a.index
        : swap.b.index;
    final partnerIndex = colorIndex == swap.a.index
        ? swap.b.index
        : swap.a.index;
    final partner = board[partnerIndex];
    return _SwapActivation(
      specialIndices: {
        colorIndex,
        if (partner.special != Match3Special.none) partnerIndex,
      },
      colorTargets: {colorIndex: partner.color},
      comboType: partner.special == Match3Special.none
          ? 'color_clear'
          : 'color_special_combo',
    );
  }

  if (a.special == Match3Special.bomb && b.special == Match3Special.bomb) {
    return _SwapActivation(
      specialIndices: {swap.a.index, swap.b.index},
      forcedClear: {
        ..._areaAround(swap.a.index, radius: 2),
        ..._areaAround(swap.b.index, radius: 2),
      },
      comboType: 'double_bomb_clear',
    );
  }

  return _SwapActivation(
    specialIndices: {if (aSpecial) swap.a.index, if (bSpecial) swap.b.index},
    comboType: aSpecial && bSpecial ? 'double_special_clear' : 'special_clear',
  );
}

Set<int> _areaAround(int index, {required int radius}) {
  final row = index ~/ Match3Engine.size;
  final col = index % Match3Engine.size;
  return {
    for (
      var r = math.max(0, row - radius);
      r <= math.min(Match3Engine.size - 1, row + radius);
      r++
    )
      for (
        var c = math.max(0, col - radius);
        c <= math.min(Match3Engine.size - 1, col + radius);
        c++
      )
        r * Match3Engine.size + c,
  };
}

_WaveResolution _resolveWave(
  List<Match3Tile> input,
  List<Set<int>> groups,
  _SwapActivation activation,
  int cascade,
  Match3Point? preferred,
) {
  final board = List<Match3Tile>.from(input);
  final clear = <int>{...activation.specialIndices, ...activation.forcedClear};
  for (final group in groups) {
    clear.addAll(group);
  }
  final created = <int, Match3Tile>{};
  final overlaps = <int, int>{};
  for (final group in groups) {
    for (final index in group) {
      overlaps[index] = (overlaps[index] ?? 0) + 1;
    }
  }
  for (final group in groups) {
    if (group.length < 4 && !group.any((index) => (overlaps[index] ?? 0) > 1)) {
      continue;
    }
    var at = preferred?.index;
    if (at == null || !group.contains(at)) {
      at = group.first;
    }
    final horizontal =
        group.map((index) => index ~/ Match3Engine.size).toSet().length == 1;
    final special = group.any((index) => (overlaps[index] ?? 0) > 1)
        ? Match3Special.bomb
        : group.length >= 5
        ? Match3Special.color
        : horizontal
        ? Match3Special.row
        : Match3Special.column;
    created[at] = board[at].copyWith(special: special);
    clear.remove(at);
  }
  final triggered = <Map<String, dynamic>>[
    if (activation.comboType != null)
      {'combo': activation.comboType, 'cleared': activation.forcedClear.length},
  ];
  final queue = [...clear];
  final seenSpecials = <int>{};
  while (queue.isNotEmpty) {
    final index = queue.removeLast();
    final tile = board[index];
    if (tile.special == Match3Special.none || !seenSpecials.add(index)) {
      continue;
    }
    final expanded = _specialArea(
      board,
      index,
      tile,
      targetColor: activation.colorTargets[index],
    );
    for (final target in expanded) {
      if (clear.add(target)) queue.add(target);
    }
    triggered.add({
      'at': Match3Point(
        index ~/ Match3Engine.size,
        index % Match3Engine.size,
      ).toJson(),
      'special': tile.special.name,
      'cleared': expanded.length,
    });
  }
  for (final index in clear) {
    board[index] = const Match3Tile(color: -1);
  }
  for (final entry in created.entries) {
    board[entry.key] = entry.value;
  }
  final boardAfterClear = List<Match3Tile>.from(board);
  _applyGravityAndRefill(
    board,
    math.Random(_hashMatch3(input, cascade, clear.length, created.length)),
  );
  final score = clear.length * 50 * cascade + created.length * 120;
  return _WaveResolution(
    board: board,
    boardBefore: List<Match3Tile>.from(input),
    boardAfterClear: boardAfterClear,
    cleared: clear,
    score: score,
    createdSpecials: [
      for (final entry in created.entries)
        {
          'at': Match3Point(
            entry.key ~/ Match3Engine.size,
            entry.key % Match3Engine.size,
          ).toJson(),
          'special': entry.value.special.name,
        },
    ],
    triggeredSpecials: triggered,
  );
}

Set<int> _specialArea(
  List<Match3Tile> board,
  int index,
  Match3Tile tile, {
  int? targetColor,
}) {
  final row = index ~/ Match3Engine.size;
  final col = index % Match3Engine.size;
  return switch (tile.special) {
    Match3Special.row => {
      for (var c = 0; c < Match3Engine.size; c++) row * Match3Engine.size + c,
    },
    Match3Special.column => {
      for (var r = 0; r < Match3Engine.size; r++) r * Match3Engine.size + col,
    },
    Match3Special.bomb => {
      for (
        var r = math.max(0, row - 1);
        r <= math.min(Match3Engine.size - 1, row + 1);
        r++
      )
        for (
          var c = math.max(0, col - 1);
          c <= math.min(Match3Engine.size - 1, col + 1);
          c++
        )
          r * Match3Engine.size + c,
    },
    Match3Special.color => {
      for (var i = 0; i < board.length; i++)
        if (board[i].color == (targetColor ?? tile.color)) i,
    },
    Match3Special.none => {index},
  };
}

void _applyGravityAndRefill(List<Match3Tile> board, math.Random random) {
  for (var col = 0; col < Match3Engine.size; col++) {
    final kept = <Match3Tile>[];
    for (var row = Match3Engine.size - 1; row >= 0; row--) {
      final tile = board[row * Match3Engine.size + col];
      if (tile.color >= 0) kept.add(tile);
    }
    var cursor = 0;
    for (var row = Match3Engine.size - 1; row >= 0; row--) {
      board[row * Match3Engine.size + col] = cursor < kept.length
          ? kept[cursor++]
          : Match3Tile(color: random.nextInt(Match3Engine.colorCount));
    }
  }
}

class _Match3Projection {
  const _Match3Projection({
    required this.score,
    required this.cleared,
    required this.specialsCreated,
    required this.cascades,
    required this.futureMobility,
    required this.nodes,
  });

  final int score;
  final int cleared;
  final int specialsCreated;
  final int cascades;
  final int futureMobility;
  final int nodes;
}

_Match3Projection _simulateSwapPotential(
  List<Match3Tile> board,
  Match3Swap swap,
) {
  var projected = List<Match3Tile>.from(board);
  _swapTiles(projected, swap.a.index, swap.b.index);
  final activation = _swapActivation(projected, swap);
  var score = 0;
  var cleared = 0;
  var specials = 0;
  var cascades = 0;
  var nodes = 1;
  Match3Point? preferred = swap.b;
  for (var cascade = 1; cascade <= 20; cascade++) {
    final groups = _matchGroups(projected);
    final currentActivation = cascade == 1
        ? activation
        : const _SwapActivation();
    nodes += projected.length + groups.length;
    if (groups.isEmpty && currentActivation.isEmpty) break;
    final resolution = _resolveWave(
      projected,
      groups,
      currentActivation,
      cascade,
      preferred,
    );
    preferred = null;
    projected = resolution.board;
    score += resolution.score;
    cleared += resolution.cleared.length;
    specials += resolution.createdSpecials.length;
    cascades = cascade;
  }
  final mobility = _availableSwaps(projected).length;
  nodes += mobility;
  return _Match3Projection(
    score: score,
    cleared: cleared,
    specialsCreated: specials,
    cascades: cascades,
    futureMobility: mobility,
    nodes: nodes,
  );
}

bool _adjacent(Match3Point a, Match3Point b) =>
    (a.row - b.row).abs() + (a.col - b.col).abs() == 1;

void _swapTiles(List<Match3Tile> board, int a, int b) {
  final value = board[a];
  board[a] = board[b];
  board[b] = value;
}

extension _SwapListMatch on List<Match3Swap> {
  bool containsSwap(Match3Swap target) => any(
    (swap) =>
        (swap.a == target.a && swap.b == target.b) ||
        (swap.a == target.b && swap.b == target.a),
  );
}

int _hashMatch3(List<Match3Tile> board, int turn, int score, int remaining) {
  var hash = 0x811C9DC5 ^ turn ^ score ^ (remaining << 12);
  for (final tile in board) {
    hash ^= (tile.color + 2) * 31 + tile.special.index;
    hash = (hash * 0x01000193) & 0x7FFFFFFF;
  }
  return hash;
}
