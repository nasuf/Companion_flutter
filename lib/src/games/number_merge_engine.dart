import 'dart:isolate';
import 'dart:math' as math;

enum NumberMergeActor { user, agent }

enum NumberMergeDirection { up, right, down, left }

enum NumberMergeStatus { playing, completed, failed }

class NumberMergePoint {
  const NumberMergePoint(this.row, this.column);

  final int row;
  final int column;

  int get index => row * NumberMergeEngine.size + column;

  Map<String, dynamic> toJson() => {'row': row, 'column': column};

  @override
  bool operator ==(Object other) =>
      other is NumberMergePoint && row == other.row && column == other.column;

  @override
  int get hashCode => Object.hash(row, column);
}

class NumberMergeTransition {
  const NumberMergeTransition({
    required this.from,
    required this.to,
    required this.value,
    required this.resultValue,
    required this.merged,
  });

  final NumberMergePoint from;
  final NumberMergePoint to;
  final int value;
  final int resultValue;
  final bool merged;

  Map<String, dynamic> toJson() => {
    'from': from.toJson(),
    'to': to.toJson(),
    'value': value,
    'result_value': resultValue,
    'merged': merged,
  };
}

class NumberMergeSpawn {
  const NumberMergeSpawn(this.point, this.value);

  final NumberMergePoint point;
  final int value;

  Map<String, dynamic> toJson() => {'at': point.toJson(), 'value': value};
}

class NumberMergeKeyMoment {
  const NumberMergeKeyMoment(this.type, this.label, this.data);

  final String type;
  final String label;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => {'type': type, 'label': label, ...data};
}

class NumberMergeMove {
  const NumberMergeMove({
    required this.number,
    required this.actor,
    required this.direction,
    required this.transitions,
    required this.mergedValues,
    required this.spawn,
    required this.scoreGained,
    required this.emptyBefore,
    required this.emptyAfter,
    required this.maxTile,
    required this.stateBeforeHash,
    required this.stateAfterHash,
    required this.moments,
    this.decision,
  });

  final int number;
  final NumberMergeActor actor;
  final NumberMergeDirection direction;
  final List<NumberMergeTransition> transitions;
  final List<int> mergedValues;
  final NumberMergeSpawn spawn;
  final int scoreGained;
  final int emptyBefore;
  final int emptyAfter;
  final int maxTile;
  final int stateBeforeHash;
  final int stateAfterHash;
  final List<NumberMergeKeyMoment> moments;
  final NumberMergeAiDecision? decision;

  Map<String, dynamic> toJson() => {
    'move_number': number,
    'actor': actor.name,
    'action': 'slide',
    'direction': direction.name,
    'transitions': transitions.map((item) => item.toJson()).toList(),
    'merged_values': mergedValues,
    'merge_count': mergedValues.length,
    'spawn': spawn.toJson(),
    'score_gained': scoreGained,
    'empty_before': emptyBefore,
    'empty_after': emptyAfter,
    'max_tile': maxTile,
    'state_before_hash': stateBeforeHash.toString(),
    'state_after_hash': stateAfterHash.toString(),
    'moments': moments.map((moment) => moment.toJson()).toList(),
    if (decision != null) 'decision': decision!.toJson(),
  };
}

class NumberMergeMoveResult {
  const NumberMergeMoveResult(this.move, this.status);

  final NumberMergeMove move;
  final NumberMergeStatus status;
}

class NumberMergeAiDecision {
  const NumberMergeAiDecision({
    required this.direction,
    required this.expectedValue,
    required this.depth,
    required this.nodes,
    required this.reason,
    required this.alternatives,
    required this.algorithm,
  });

  final NumberMergeDirection direction;
  final double expectedValue;
  final int depth;
  final int nodes;
  final String reason;
  final Map<String, double> alternatives;
  final String algorithm;

  Map<String, dynamic> toJson() => {
    'direction': direction.name,
    'expected_value': expectedValue,
    'depth': depth,
    'nodes': nodes,
    'reason': reason,
    'alternatives': alternatives,
    'algorithm': algorithm,
  };
}

class NumberMergeGameConfig {
  const NumberMergeGameConfig({
    this.target = 2048,
    this.searchDepthOffset = 0,
    this.nearBestProbability = 0,
    this.nearBestToleranceRatio = 0,
  });

  factory NumberMergeGameConfig.fromJson(Map<String, dynamic> json) =>
      NumberMergeGameConfig(
        target: (json['target'] as num?)?.round() ?? 2048,
        searchDepthOffset: (json['search_depth_offset'] as num?)?.round() ?? 0,
        nearBestProbability:
            (json['near_best_probability'] as num?)?.toDouble() ?? 0,
        nearBestToleranceRatio:
            (json['near_best_tolerance_ratio'] as num?)?.toDouble() ?? 0,
      );

  final int target;
  final int searchDepthOffset;
  final double nearBestProbability;
  final double nearBestToleranceRatio;
}

class NumberMergeEngine {
  NumberMergeEngine({
    int seed = 20260715,
    this.target = 2048,
    this.searchDepthOffset = 0,
    this.nearBestProbability = 0,
    this.nearBestToleranceRatio = 0,
  }) : _random = math.Random(seed),
       _board = List<int>.filled(size * size, 0) {
    _spawnInitialTile();
    _spawnInitialTile();
  }

  NumberMergeEngine.withBoard(
    List<int> board, {
    int seed = 20260715,
    this.target = 2048,
    this.searchDepthOffset = 0,
    this.nearBestProbability = 0,
    this.nearBestToleranceRatio = 0,
    NumberMergeActor firstActor = NumberMergeActor.user,
  }) : assert(board.length == size * size),
       assert(board.every((value) => value == 0 || _isPowerOfTwo(value))),
       _random = math.Random(seed),
       _board = List<int>.of(board) {
    turn = firstActor;
    _refreshStatus();
  }

  static const int size = 4;

  final int target;
  final int searchDepthOffset;
  final double nearBestProbability;
  final double nearBestToleranceRatio;
  final math.Random _random;
  final List<int> _board;
  final List<NumberMergeMove> moves = [];
  final List<NumberMergeKeyMoment> keyMoments = [];

  NumberMergeActor turn = NumberMergeActor.user;
  int get moveCount => moves.length;
  NumberMergeStatus status = NumberMergeStatus.playing;
  int score = 0;
  int userScore = 0;
  int agentScore = 0;
  int totalMerges = 0;
  int bestCombo = 0;

  List<int> get board => List.unmodifiable(_board);
  int get emptyCount => _board.where((value) => value == 0).length;
  int get maxTile => _board.reduce(math.max);
  bool get isFinished => status != NumberMergeStatus.playing;

  int get stateHash => _hashNumberMergeBoard(_board, turn.index);

  NumberMergePoint pointFor(int index) =>
      NumberMergePoint(index ~/ size, index % size);

  int valueAt(int index) => _board[index];

  bool canMove(NumberMergeDirection direction) =>
      _simulateNumberMergeMove(_board, direction).changed;

  List<NumberMergeDirection> get legalDirections => [
    for (final direction in NumberMergeDirection.values)
      if (canMove(direction)) direction,
  ];

  NumberMergeMoveResult move(
    NumberMergeDirection direction, {
    NumberMergeActor? actor,
    NumberMergeAiDecision? decision,
  }) {
    final activeActor = actor ?? turn;
    if (isFinished) throw StateError('The game has already ended.');
    if (activeActor != turn) {
      throw StateError('It is not ${activeActor.name} turn.');
    }
    final simulation = _simulateNumberMergeMove(_board, direction);
    if (!simulation.changed) {
      throw StateError('The slide does not change the board.');
    }
    final beforeHash = stateHash;
    final emptyBefore = emptyCount;
    _board.setAll(0, simulation.board);
    score += simulation.scoreGained;
    if (activeActor == NumberMergeActor.user) {
      userScore += simulation.scoreGained;
    } else {
      agentScore += simulation.scoreGained;
    }
    totalMerges += simulation.mergedValues.length;
    bestCombo = math.max(bestCombo, simulation.mergedValues.length);
    final spawn = _spawnTile();
    final moments = _detectMoments(
      moveNumber: moves.length + 1,
      mergedValues: simulation.mergedValues,
      emptyBefore: emptyBefore,
      emptyAfter: emptyCount,
    );
    _refreshStatus();
    if (!isFinished) {
      turn = activeActor == NumberMergeActor.user
          ? NumberMergeActor.agent
          : NumberMergeActor.user;
    }
    final move = NumberMergeMove(
      number: moves.length + 1,
      actor: activeActor,
      direction: direction,
      transitions: simulation.transitions,
      mergedValues: simulation.mergedValues,
      spawn: spawn,
      scoreGained: simulation.scoreGained,
      emptyBefore: emptyBefore,
      emptyAfter: emptyCount,
      maxTile: maxTile,
      stateBeforeHash: beforeHash,
      stateAfterHash: stateHash,
      moments: moments,
      decision: decision,
    );
    moves.add(move);
    keyMoments.addAll(moments);
    return NumberMergeMoveResult(move, status);
  }

  Future<NumberMergeAiDecision> chooseAiMove() async {
    if (isFinished || turn != NumberMergeActor.agent) {
      throw StateError('The agent cannot move now.');
    }
    final snapshot = List<int>.of(_board);
    final seed = stateHash ^ (moveCount * 7919);
    final result = await Isolate.run(
      () => _chooseNumberMergeMove(
        snapshot,
        depthOffset: searchDepthOffset,
        nearBestProbability: nearBestProbability,
        nearBestToleranceRatio: nearBestToleranceRatio,
        seed: seed,
      ),
    );
    return NumberMergeAiDecision(
      direction: result.direction,
      expectedValue: result.expectedValue,
      depth: result.depth,
      nodes: result.nodes,
      reason: result.reason,
      alternatives: result.alternatives,
      algorithm: 'expectimax_chance_nodes_monotonicity_smoothness_mobility',
    );
  }

  Map<String, dynamic> stateJson() => {
    'size': size,
    'target': target,
    'board': _board,
    'turn': turn.name,
    'status': status.name,
    'score': score,
    'user_score': userScore,
    'agent_score': agentScore,
    'move_count': moveCount,
    'empty_count': emptyCount,
    'max_tile': maxTile,
    'legal_directions': legalDirections.map((item) => item.name).toList(),
    'state_hash': stateHash.toString(),
  };

  Map<String, dynamic> analysisJson() {
    final evaluation = _numberMergeEvaluationDetails(_board);
    return {
      ...evaluation,
      'score': score,
      'max_tile': maxTile,
      'empty_count': emptyCount,
      'legal_move_count': legalDirections.length,
      'total_merges': totalMerges,
      'best_combo': bestCombo,
      'target_progress': (maxTile / target).clamp(0.0, 1.0),
      'solver': 'expectimax_chance_nodes_monotonicity_smoothness_mobility',
    };
  }

  Map<String, dynamic> summaryJson() => {
    'game_key': 'number_merge',
    'rules': 'standard_4x4_single_merge_per_move_spawn_90_10',
    'cooperative': true,
    'target': target,
    'status': status.name,
    'score': score,
    'user_score': userScore,
    'agent_score': agentScore,
    'move_count': moveCount,
    'action_count': moveCount,
    'max_tile': maxTile,
    'total_merges': totalMerges,
    'best_combo': bestCombo,
    'user_action_count': moves
        .where((move) => move.actor == NumberMergeActor.user)
        .length,
    'agent_action_count': moves
        .where((move) => move.actor == NumberMergeActor.agent)
        .length,
    'key_moments': keyMoments.map((moment) => moment.toJson()).toList(),
    'actions': moves.map((move) => move.toJson()).toList(),
    'analysis': analysisJson(),
    'final_state': stateJson(),
  };

  List<NumberMergeKeyMoment> _detectMoments({
    required int moveNumber,
    required List<int> mergedValues,
    required int emptyBefore,
    required int emptyAfter,
  }) {
    final moments = <NumberMergeKeyMoment>[];
    if (mergedValues.isNotEmpty && totalMerges == mergedValues.length) {
      moments.add(
        NumberMergeKeyMoment('first_merge', '第一次合并', {
          'created_value': mergedValues.reduce(math.max),
        }),
      );
    }
    if (mergedValues.length >= 2) {
      moments.add(
        NumberMergeKeyMoment('multi_merge', '一手完成多次合并', {
          'merge_count': mergedValues.length,
          'created_values': mergedValues,
        }),
      );
    }
    final milestone = mergedValues
        .where((value) => value >= 128 && _isPowerOfTwo(value))
        .fold<int>(0, math.max);
    if (milestone > 0 &&
        !_boardBeforeMoveHadMilestone(milestone, moveNumber: moveNumber)) {
      moments.add(
        NumberMergeKeyMoment('milestone_tile', '合成新的里程碑数字', {
          'value': milestone,
        }),
      );
    }
    if (emptyBefore <= 2 && emptyAfter >= 3) {
      moments.add(
        NumberMergeKeyMoment('board_recovered', '从拥挤盘面中腾出了空间', {
          'empty_before': emptyBefore,
          'empty_after': emptyAfter,
        }),
      );
    }
    if (emptyAfter <= 2 && legalDirections.length <= 2) {
      moments.add(
        NumberMergeKeyMoment('near_stuck', '盘面接近没有空间', {
          'empty_count': emptyAfter,
          'legal_move_count': legalDirections.length,
        }),
      );
    }
    if (maxTile >= target) {
      moments.add(
        NumberMergeKeyMoment('target_reached', '合成了目标数字', {
          'value': maxTile,
          'score': score,
        }),
      );
    }
    return moments;
  }

  bool _boardBeforeMoveHadMilestone(int milestone, {required int moveNumber}) =>
      moves.take(moveNumber - 1).any((move) => move.maxTile >= milestone);

  void _spawnInitialTile() {
    _spawnTile();
  }

  NumberMergeSpawn _spawnTile() {
    final empty = <int>[
      for (var index = 0; index < _board.length; index += 1)
        if (_board[index] == 0) index,
    ];
    if (empty.isEmpty) {
      throw StateError('Cannot spawn a tile on a full board.');
    }
    final index = empty[_random.nextInt(empty.length)];
    final value = _random.nextDouble() < 0.9 ? 2 : 4;
    _board[index] = value;
    return NumberMergeSpawn(pointFor(index), value);
  }

  void _refreshStatus() {
    if (maxTile >= target) {
      status = NumberMergeStatus.completed;
      return;
    }
    final movable = NumberMergeDirection.values.any(
      (direction) => _simulateNumberMergeMove(_board, direction).changed,
    );
    status = movable ? NumberMergeStatus.playing : NumberMergeStatus.failed;
  }
}

class _NumberMergeSimulation {
  const _NumberMergeSimulation({
    required this.board,
    required this.transitions,
    required this.mergedValues,
    required this.scoreGained,
    required this.changed,
  });

  final List<int> board;
  final List<NumberMergeTransition> transitions;
  final List<int> mergedValues;
  final int scoreGained;
  final bool changed;
}

class _IndexedTile {
  const _IndexedTile(this.index, this.value);

  final int index;
  final int value;
}

_NumberMergeSimulation _simulateNumberMergeMove(
  List<int> board,
  NumberMergeDirection direction,
) {
  final next = List<int>.filled(
    NumberMergeEngine.size * NumberMergeEngine.size,
    0,
  );
  final transitions = <NumberMergeTransition>[];
  final mergedValues = <int>[];
  var score = 0;
  for (var lineIndex = 0; lineIndex < NumberMergeEngine.size; lineIndex += 1) {
    final line = _numberMergeLine(direction, lineIndex);
    final tiles = <_IndexedTile>[
      for (final index in line)
        if (board[index] != 0) _IndexedTile(index, board[index]),
    ];
    var source = 0;
    var destination = 0;
    while (source < tiles.length) {
      final first = tiles[source];
      final target = line[destination];
      if (source + 1 < tiles.length && tiles[source + 1].value == first.value) {
        final second = tiles[source + 1];
        final resultValue = first.value * 2;
        next[target] = resultValue;
        score += resultValue;
        mergedValues.add(resultValue);
        transitions.addAll([
          NumberMergeTransition(
            from: _pointForNumberMergeIndex(first.index),
            to: _pointForNumberMergeIndex(target),
            value: first.value,
            resultValue: resultValue,
            merged: true,
          ),
          NumberMergeTransition(
            from: _pointForNumberMergeIndex(second.index),
            to: _pointForNumberMergeIndex(target),
            value: second.value,
            resultValue: resultValue,
            merged: true,
          ),
        ]);
        source += 2;
      } else {
        next[target] = first.value;
        transitions.add(
          NumberMergeTransition(
            from: _pointForNumberMergeIndex(first.index),
            to: _pointForNumberMergeIndex(target),
            value: first.value,
            resultValue: first.value,
            merged: false,
          ),
        );
        source += 1;
      }
      destination += 1;
    }
  }
  var changed = false;
  for (var index = 0; index < board.length; index += 1) {
    if (board[index] != next[index]) {
      changed = true;
      break;
    }
  }
  return _NumberMergeSimulation(
    board: next,
    transitions: transitions,
    mergedValues: mergedValues,
    scoreGained: score,
    changed: changed,
  );
}

List<int> _numberMergeLine(NumberMergeDirection direction, int line) =>
    switch (direction) {
      NumberMergeDirection.left => [
        for (var column = 0; column < 4; column += 1) line * 4 + column,
      ],
      NumberMergeDirection.right => [
        for (var column = 3; column >= 0; column -= 1) line * 4 + column,
      ],
      NumberMergeDirection.up => [
        for (var row = 0; row < 4; row += 1) row * 4 + line,
      ],
      NumberMergeDirection.down => [
        for (var row = 3; row >= 0; row -= 1) row * 4 + line,
      ],
    };

NumberMergePoint _pointForNumberMergeIndex(int index) => NumberMergePoint(
  index ~/ NumberMergeEngine.size,
  index % NumberMergeEngine.size,
);

bool _isPowerOfTwo(int value) => value > 0 && (value & (value - 1)) == 0;

int _hashNumberMergeBoard(List<int> board, int turn) {
  var hash = 0x811C9DC5 ^ turn;
  for (var index = 0; index < board.length; index += 1) {
    hash = ((hash ^ (board[index] + index * 31)) * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

class _NumberMergeSearchResult {
  const _NumberMergeSearchResult({
    required this.direction,
    required this.expectedValue,
    required this.depth,
    required this.nodes,
    required this.reason,
    required this.alternatives,
  });

  final NumberMergeDirection direction;
  final double expectedValue;
  final int depth;
  final int nodes;
  final String reason;
  final Map<String, double> alternatives;
}

_NumberMergeSearchResult _chooseNumberMergeMove(
  List<int> board, {
  int depthOffset = 0,
  double nearBestProbability = 0,
  double nearBestToleranceRatio = 0,
  int seed = 0,
}) {
  final emptyCount = board.where((value) => value == 0).length;
  final baseDepth = emptyCount >= 8
      ? 4
      : emptyCount >= 4
      ? 5
      : 6;
  final depth = math.max(2, math.min(8, baseDepth + depthOffset));
  final search = _NumberMergeExpectimax();
  final alternatives = <String, double>{};
  NumberMergeDirection? bestDirection;
  var bestValue = double.negativeInfinity;
  final ranked = <(NumberMergeDirection, double)>[];
  for (final direction in const [
    NumberMergeDirection.up,
    NumberMergeDirection.left,
    NumberMergeDirection.right,
    NumberMergeDirection.down,
  ]) {
    final move = _simulateNumberMergeMove(board, direction);
    if (!move.changed) continue;
    final value =
        move.scoreGained * 1.8 + search.chanceValue(move.board, depth - 1);
    alternatives[direction.name] = value;
    ranked.add((direction, value));
    if (value > bestValue) {
      bestValue = value;
      bestDirection = direction;
    }
  }
  ranked.sort((a, b) => b.$2.compareTo(a.$2));
  var chosen = bestDirection ?? NumberMergeDirection.up;
  if (ranked.length > 1 && nearBestProbability > 0) {
    final tolerance = ranked.first.$2.abs() * nearBestToleranceRatio;
    final near = ranked
        .where((item) => ranked.first.$2 - item.$2 <= tolerance)
        .toList();
    final random = math.Random(seed);
    if (near.length > 1 && random.nextDouble() < nearBestProbability) {
      chosen = near[1 + random.nextInt(near.length - 1)].$1;
      bestValue = alternatives[chosen.name]!;
    }
  }
  final details = _numberMergeEvaluationDetails(
    _simulateNumberMergeMove(board, chosen).board,
  );
  final reason = (details['empty_cells'] as int) >= 6
      ? '这一步能保留较多空位，同时维持大数字沿边单调排列。'
      : (details['max_in_corner'] as bool)
      ? '盘面已经拥挤，先把最大数字稳定在角落并保留后续合并路线。'
      : '综合新方块的出生概率后，这个方向的后续可移动空间最大。';
  return _NumberMergeSearchResult(
    direction: chosen,
    expectedValue: bestValue,
    depth: depth,
    nodes: search.nodes,
    reason: reason,
    alternatives: alternatives,
  );
}

class _NumberMergeExpectimax {
  int nodes = 0;
  final Map<String, double> _cache = {};

  double maxValue(List<int> board, int depth) {
    nodes += 1;
    if (depth <= 0) return _evaluateNumberMergeBoard(board);
    final key = 'm:$depth:${_compactBoardKey(board)}';
    final cached = _cache[key];
    if (cached != null) return cached;
    var best = double.negativeInfinity;
    for (final direction in NumberMergeDirection.values) {
      final move = _simulateNumberMergeMove(board, direction);
      if (!move.changed) continue;
      best = math.max(
        best,
        move.scoreGained * 1.8 + chanceValue(move.board, depth - 1),
      );
    }
    if (best == double.negativeInfinity) {
      best = _evaluateNumberMergeBoard(board) - 100000;
    }
    _cache[key] = best;
    return best;
  }

  double chanceValue(List<int> board, int depth) {
    nodes += 1;
    if (depth <= 0) return _evaluateNumberMergeBoard(board);
    final key = 'c:$depth:${_compactBoardKey(board)}';
    final cached = _cache[key];
    if (cached != null) return cached;
    final empty = <int>[
      for (var index = 0; index < board.length; index += 1)
        if (board[index] == 0) index,
    ];
    if (empty.isEmpty) return maxValue(board, depth - 1);
    var expected = 0.0;
    final locationWeight = 1 / empty.length;
    for (final index in empty) {
      final withTwo = List<int>.of(board)..[index] = 2;
      final withFour = List<int>.of(board)..[index] = 4;
      expected +=
          locationWeight *
          (0.9 * maxValue(withTwo, depth - 1) +
              0.1 * maxValue(withFour, depth - 1));
    }
    _cache[key] = expected;
    return expected;
  }
}

String _compactBoardKey(List<int> board) =>
    board.map((value) => value == 0 ? 0 : _log2(value)).join(',');

int _log2(int value) {
  var current = value;
  var exponent = 0;
  while (current > 1) {
    current ~/= 2;
    exponent += 1;
  }
  return exponent;
}

double _evaluateNumberMergeBoard(List<int> board) {
  final details = _numberMergeEvaluationDetails(board);
  return (details['empty_cells'] as int) * 330.0 +
      (details['monotonicity'] as double) * 48.0 +
      (details['smoothness'] as double) * 18.0 +
      (details['merge_potential'] as int) * 115.0 +
      (details['mobility'] as int) * 95.0 +
      ((details['max_in_corner'] as bool) ? 780.0 : 0.0) +
      (details['snake_weight'] as double) * 4.2;
}

Map<String, dynamic> _numberMergeEvaluationDetails(List<int> board) {
  final logs = board.map((value) => value == 0 ? 0 : _log2(value)).toList();
  var smoothness = 0.0;
  var mergePotential = 0;
  for (var row = 0; row < 4; row += 1) {
    for (var column = 0; column < 4; column += 1) {
      final index = row * 4 + column;
      if (board[index] == 0) continue;
      for (final neighbor in [
        if (column < 3) index + 1,
        if (row < 3) index + 4,
      ]) {
        if (board[neighbor] == 0) continue;
        smoothness -= (logs[index] - logs[neighbor]).abs();
        if (board[index] == board[neighbor]) mergePotential += 1;
      }
    }
  }
  var monotonicity = 0.0;
  for (var line = 0; line < 4; line += 1) {
    var rowIncreasingPenalty = 0.0;
    var rowDecreasingPenalty = 0.0;
    var colIncreasingPenalty = 0.0;
    var colDecreasingPenalty = 0.0;
    for (var offset = 0; offset < 3; offset += 1) {
      final rowA = logs[line * 4 + offset];
      final rowB = logs[line * 4 + offset + 1];
      rowIncreasingPenalty += math.max(0, rowA - rowB);
      rowDecreasingPenalty += math.max(0, rowB - rowA);
      final colA = logs[offset * 4 + line];
      final colB = logs[(offset + 1) * 4 + line];
      colIncreasingPenalty += math.max(0, colA - colB);
      colDecreasingPenalty += math.max(0, colB - colA);
    }
    monotonicity -=
        math.min(rowIncreasingPenalty, rowDecreasingPenalty) +
        math.min(colIncreasingPenalty, colDecreasingPenalty);
  }
  const snakeWeights = <double>[
    16,
    15,
    14,
    13,
    9,
    10,
    11,
    12,
    8,
    7,
    6,
    5,
    1,
    2,
    3,
    4,
  ];
  var snake = 0.0;
  for (var index = 0; index < board.length; index += 1) {
    snake += logs[index] * snakeWeights[index];
  }
  final maximum = board.reduce(math.max);
  final corners = {board[0], board[3], board[12], board[15]};
  final mobility = NumberMergeDirection.values
      .where((direction) => _simulateNumberMergeMove(board, direction).changed)
      .length;
  return {
    'empty_cells': board.where((value) => value == 0).length,
    'smoothness': smoothness,
    'monotonicity': monotonicity,
    'merge_potential': mergePotential,
    'mobility': mobility,
    'max_in_corner': corners.contains(maximum),
    'snake_weight': snake,
  };
}
