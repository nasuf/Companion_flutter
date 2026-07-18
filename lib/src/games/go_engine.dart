import 'dart:math' as math;

import 'package:flutter/foundation.dart';

enum GoActor { user, agent }

enum GoStatus { playing, userWon, agentWon, draw }

class GoPoint {
  const GoPoint(this.index);

  final int index;

  int get row => index ~/ GoEngine.boardSize;
  int get col => index % GoEngine.boardSize;
  String get coordinate => '${_goColumns[col]}${GoEngine.boardSize - row}';

  Map<String, dynamic> toJson() => {
    'index': index,
    'row': row,
    'col': col,
    'coordinate': coordinate,
  };
}

class GoScore {
  const GoScore({
    required this.userStones,
    required this.agentStones,
    required this.userTerritory,
    required this.agentTerritory,
    required this.neutralPoints,
    required this.komi,
  });

  final int userStones;
  final int agentStones;
  final int userTerritory;
  final int agentTerritory;
  final int neutralPoints;
  final double komi;

  double get userTotal => userStones + userTerritory.toDouble();
  double get agentTotal => agentStones + agentTerritory + komi;
  double get margin => (userTotal - agentTotal).abs();
  GoStatus get status => userTotal > agentTotal
      ? GoStatus.userWon
      : agentTotal > userTotal
      ? GoStatus.agentWon
      : GoStatus.draw;

  Map<String, dynamic> toJson() => {
    'rules': 'chinese_area_scoring',
    'user_stones': userStones,
    'agent_stones': agentStones,
    'user_territory': userTerritory,
    'agent_territory': agentTerritory,
    'neutral_points': neutralPoints,
    'komi': komi,
    'user_total': userTotal,
    'agent_total': agentTotal,
    'margin': margin,
    'winner': status.name,
  };
}

class GoAiCandidate {
  const GoAiCandidate({
    required this.index,
    required this.visits,
    required this.winRate,
    required this.prior,
  });

  final int? index;
  final int visits;
  final double winRate;
  final double prior;

  factory GoAiCandidate.fromJson(Map<String, dynamic> json) => GoAiCandidate(
    index: json['index'] as int?,
    visits: json['visits']! as int,
    winRate: (json['win_rate']! as num).toDouble(),
    prior: (json['prior']! as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'move': index == null ? 'pass' : GoPoint(index!).toJson(),
    'visits': visits,
    'win_rate': winRate,
    'prior': prior,
  };
}

class GoAiDecision {
  const GoAiDecision({
    required this.index,
    required this.simulations,
    required this.nodes,
    required this.elapsedMilliseconds,
    required this.winRate,
    required this.reason,
    required this.candidates,
  });

  final int? index;
  final int simulations;
  final int nodes;
  final int elapsedMilliseconds;
  final double winRate;
  final String reason;
  final List<GoAiCandidate> candidates;

  factory GoAiDecision.fromJson(Map<String, dynamic> json) => GoAiDecision(
    index: json['index'] as int?,
    simulations: json['simulations']! as int,
    nodes: json['nodes']! as int,
    elapsedMilliseconds: json['elapsed_milliseconds']! as int,
    winRate: (json['win_rate']! as num).toDouble(),
    reason: json['reason']! as String,
    candidates: [
      for (final item in json['top_candidates']! as List)
        GoAiCandidate.fromJson(Map<String, dynamic>.from(item as Map)),
    ],
  );

  Map<String, dynamic> toJson() => {
    'move': index == null ? 'pass' : GoPoint(index!).toJson(),
    'simulations': simulations,
    'nodes_searched': nodes,
    'elapsed_milliseconds': elapsedMilliseconds,
    'estimated_win_rate': winRate,
    'reason': reason,
    'top_candidates': [for (final item in candidates) item.toJson()],
    'algorithm': 'uct_mcts_pattern_capture_rollout',
  };
}

class GoMove {
  const GoMove({
    required this.number,
    required this.actor,
    required this.index,
    required this.captured,
    required this.libertiesAfter,
    required this.consecutivePasses,
    required this.stateBeforeHash,
    required this.stateAfterHash,
    required this.moment,
    this.decision,
  });

  final int number;
  final GoActor actor;
  final int? index;
  final List<int> captured;
  final int libertiesAfter;
  final int consecutivePasses;
  final int stateBeforeHash;
  final int stateAfterHash;
  final Map<String, dynamic>? moment;
  final GoAiDecision? decision;

  bool get isPass => index == null;

  Map<String, dynamic> toJson() => {
    'move_number': number,
    'actor': actor.name,
    'move': isPass ? {'type': 'pass'} : GoPoint(index!).toJson(),
    'action': isPass ? 'pass' : 'place',
    'captured': [for (final point in captured) GoPoint(point).toJson()],
    'capture_count': captured.length,
    'liberties_after': libertiesAfter,
    'consecutive_passes': consecutivePasses,
    'state_before_hash': stateBeforeHash.toString(),
    'state_after_hash': stateAfterHash.toString(),
    if (moment != null) 'moment': moment,
    if (decision != null) 'decision': decision!.toJson(),
  };
}

class GoMoveResult {
  const GoMoveResult({required this.move, required this.status});

  final GoMove move;
  final GoStatus status;
}

class GoAiConfig {
  const GoAiConfig({
    this.searchTimeMs = 600,
    this.minimumSimulations = 40,
    this.explorationConstant = 1.32,
    this.branchLimit = 16,
    this.rolloutDepth = 30,
    this.moveTemperature = 0,
  });

  factory GoAiConfig.fromJson(Map<String, dynamic> json) => GoAiConfig(
    searchTimeMs: (json['search_time_ms'] as num?)?.round() ?? 600,
    minimumSimulations: (json['minimum_simulations'] as num?)?.round() ?? 40,
    explorationConstant:
        (json['exploration_constant'] as num?)?.toDouble() ?? 1.32,
    branchLimit: (json['branch_limit'] as num?)?.round() ?? 16,
    rolloutDepth: (json['rollout_depth'] as num?)?.round() ?? 30,
    moveTemperature: (json['move_temperature'] as num?)?.toDouble() ?? 0,
  );

  final int searchTimeMs;
  final int minimumSimulations;
  final double explorationConstant;
  final int branchLimit;
  final int rolloutDepth;
  final double moveTemperature;
}

class GoEngine {
  GoEngine({this.komi = 6.5, this.aiConfig = const GoAiConfig()})
    : _board = List<int>.filled(boardArea, _empty),
      _positionHistory = <int>{
        _goBoardHash(List<int>.filled(boardArea, _empty)),
      };

  GoEngine.debug(
    List<int> board, {
    this.turn = GoActor.user,
    this.komi = 6.5,
    this.consecutivePasses = 0,
    this.userCaptures = 0,
    this.agentCaptures = 0,
    this.aiConfig = const GoAiConfig(),
    Set<int>? positionHistory,
  }) : assert(board.length == boardArea),
       _board = List<int>.from(board),
       _positionHistory = {...?positionHistory, _goBoardHash(board)};

  static const int boardSize = 9;
  static const int boardArea = boardSize * boardSize;
  static const int _empty = 0;
  static const int _userStone = 1;
  static const int _agentStone = 2;

  final double komi;
  final GoAiConfig aiConfig;
  final List<int> _board;
  final Set<int> _positionHistory;
  final List<GoMove> _moves = [];
  GoActor turn = GoActor.user;
  int consecutivePasses = 0;
  int userCaptures = 0;
  int agentCaptures = 0;

  List<int> get board => List.unmodifiable(_board);
  List<GoMove> get moves => List.unmodifiable(_moves);
  int get moveCount => _moves.length;
  bool get isFinished => status != GoStatus.playing;
  int get stateHash => _goStateHash(_board, turn.index, consecutivePasses);
  GoScore get score => _scoreGoBoard(_board, komi);
  GoStatus get status =>
      consecutivePasses >= 2 ? score.status : GoStatus.playing;

  List<int> legalMoves() {
    if (isFinished) return const [];
    final actorStone = _stoneFor(turn);
    return [
      for (var index = 0; index < boardArea; index += 1)
        if (_board[index] == _empty &&
            _tryGoPlacement(
                  _board,
                  index,
                  actorStone,
                  forbiddenHashes: _positionHistory,
                ) !=
                null)
          index,
    ];
  }

  bool isLegal(int index) => legalMoves().contains(index);

  GoMoveResult play(int? index, {GoAiDecision? decision}) {
    if (isFinished) throw StateError('game_finished');
    final actor = turn;
    final beforeHash = stateHash;
    List<int> captured = const [];
    var liberties = 0;
    if (index == null) {
      consecutivePasses += 1;
    } else {
      if (index < 0 || index >= boardArea) throw StateError('invalid_move');
      final placement = _tryGoPlacement(
        _board,
        index,
        _stoneFor(actor),
        forbiddenHashes: _positionHistory,
      );
      if (placement == null) throw StateError('invalid_move');
      _board.setAll(0, placement.board);
      captured = List.unmodifiable(placement.captured);
      liberties = placement.liberties;
      if (actor == GoActor.user) {
        userCaptures += captured.length;
      } else {
        agentCaptures += captured.length;
      }
      _positionHistory.add(_goBoardHash(_board));
      consecutivePasses = 0;
    }
    turn = actor == GoActor.user ? GoActor.agent : GoActor.user;
    final moment = _goMoment(
      board: _board,
      actorStone: _stoneFor(actor),
      index: index,
      captured: captured,
      liberties: liberties,
      consecutivePasses: consecutivePasses,
    );
    final move = GoMove(
      number: _moves.length + 1,
      actor: actor,
      index: index,
      captured: captured,
      libertiesAfter: liberties,
      consecutivePasses: consecutivePasses,
      stateBeforeHash: beforeHash,
      stateAfterHash: stateHash,
      moment: moment,
      decision: decision,
    );
    _moves.add(move);
    return GoMoveResult(move: move, status: status);
  }

  Future<GoAiDecision> chooseAiMove() async {
    if (turn != GoActor.agent) throw StateError('not_agent_turn');
    if (isFinished) throw StateError('game_finished');
    final json = await compute(_searchGoMove, {
      'board': _board,
      'turn': turn.index,
      'consecutive_passes': consecutivePasses,
      'komi': komi,
      'position_history': _positionHistory.toList(growable: false),
      'budget_ms': aiConfig.searchTimeMs,
      'minimum_simulations': aiConfig.minimumSimulations,
      'exploration_constant': aiConfig.explorationConstant,
      'branch_limit': aiConfig.branchLimit,
      'rollout_depth': aiConfig.rolloutDepth,
      'move_temperature': aiConfig.moveTemperature,
      'seed': stateHash ^ (_moves.length * 7919),
    });
    return GoAiDecision.fromJson(json);
  }

  Map<String, dynamic> stateJson() => {
    'board_size': boardSize,
    'board': _board,
    'turn': turn.name,
    'status': status.name,
    'move_count': moveCount,
    'consecutive_passes': consecutivePasses,
    'user_captures': userCaptures,
    'agent_captures': agentCaptures,
    'position_history': _positionHistory.toList(growable: false),
    'state_hash': stateHash.toString(),
  };

  Map<String, dynamic> analysisJson() {
    final currentScore = score;
    final legal = isFinished ? const <int>[] : legalMoves();
    return {
      'state_hash': stateHash.toString(),
      'turn': turn.name,
      'legal_move_count': legal.length,
      'occupied_points': _board.where((value) => value != _empty).length,
      'empty_points': _board.where((value) => value == _empty).length,
      'user_captures': userCaptures,
      'agent_captures': agentCaptures,
      'score_estimate': currentScore.toJson(),
      'last_move': _moves.isEmpty ? null : _moves.last.toJson(),
    };
  }

  Map<String, dynamic> summaryJson() => {
    'game_key': 'go',
    'board_size': boardSize,
    'rules': 'chinese_area_scoring_positional_superko',
    'komi': komi,
    'move_count': moveCount,
    'actions': [for (final move in _moves) move.toJson()],
    'user_moves': _moves.where((move) => move.actor == GoActor.user).length,
    'agent_moves': _moves.where((move) => move.actor == GoActor.agent).length,
    'user_captures': userCaptures,
    'agent_captures': agentCaptures,
    'score': score.toJson(),
    'key_moments': [
      for (final move in _moves)
        if (move.moment != null)
          {
            ...move.moment!,
            'move_number': move.number,
            'actor': move.actor.name,
          },
    ],
    'final_state': stateJson(),
    'analysis': analysisJson(),
  };

  static int stoneFor(GoActor actor) => _stoneFor(actor);
}

class _GoPlacement {
  const _GoPlacement(this.board, this.captured, this.liberties);

  final List<int> board;
  final List<int> captured;
  final int liberties;
}

class _GoGroup {
  const _GoGroup(this.stones, this.liberties);

  final Set<int> stones;
  final Set<int> liberties;
}

class _GoSearchState {
  _GoSearchState({
    required this.board,
    required this.turnStone,
    required this.consecutivePasses,
    required this.komi,
    required this.history,
    this.ply = 0,
  });

  final List<int> board;
  final int turnStone;
  final int consecutivePasses;
  final double komi;
  final Set<int> history;
  final int ply;

  bool get terminal => consecutivePasses >= 2 || ply >= 150;

  List<int> legalActions() {
    final result = <int>[];
    for (var index = 0; index < GoEngine.boardArea; index += 1) {
      if (board[index] != 0) continue;
      if (_tryGoPlacement(board, index, turnStone, forbiddenHashes: history) !=
          null) {
        result.add(index);
      }
    }
    result.add(-1);
    return result;
  }

  _GoSearchState apply(int action) {
    if (action == -1) {
      return _GoSearchState(
        board: List<int>.from(board),
        turnStone: _opponentStone(turnStone),
        consecutivePasses: consecutivePasses + 1,
        komi: komi,
        history: Set<int>.from(history),
        ply: ply + 1,
      );
    }
    final placement = _tryGoPlacement(
      board,
      action,
      turnStone,
      forbiddenHashes: history,
    );
    if (placement == null) throw StateError('invalid_search_move');
    return _GoSearchState(
      board: placement.board,
      turnStone: _opponentStone(turnStone),
      consecutivePasses: 0,
      komi: komi,
      history: {...history, _goBoardHash(placement.board)},
      ply: ply + 1,
    );
  }
}

class _GoMctsNode {
  _GoMctsNode({
    required this.state,
    required this.parent,
    required this.action,
    required this.prior,
    required this.branchLimit,
  }) : untried = state.terminal ? [] : _rankGoActions(state, branchLimit);

  final _GoSearchState state;
  final _GoMctsNode? parent;
  final int? action;
  final double prior;
  final int branchLimit;
  final List<int> untried;
  final List<_GoMctsNode> children = [];
  int visits = 0;
  double reward = 0;

  double get mean => visits == 0 ? 0.5 : reward / visits;
}

Map<String, dynamic> _searchGoMove(Map<String, dynamic> input) {
  final stopwatch = Stopwatch()..start();
  final budgetMs = input['budget_ms']! as int;
  final minimumSimulations = input['minimum_simulations']! as int;
  final explorationConstant = (input['exploration_constant']! as num)
      .toDouble();
  final branchLimit = input['branch_limit']! as int;
  final rolloutDepth = input['rollout_depth']! as int;
  final moveTemperature = (input['move_temperature']! as num).toDouble();
  final random = math.Random(input['seed']! as int);
  final rootState = _GoSearchState(
    board: List<int>.from(input['board']! as List),
    turnStone: (input['turn']! as int) == GoActor.agent.index ? 2 : 1,
    consecutivePasses: input['consecutive_passes']! as int,
    komi: (input['komi']! as num).toDouble(),
    history: Set<int>.from(input['position_history']! as List),
  );
  final root = _GoMctsNode(
    state: rootState,
    parent: null,
    action: null,
    prior: 1,
    branchLimit: branchLimit,
  );
  var simulations = 0;
  var nodes = 1;
  while (stopwatch.elapsedMilliseconds < budgetMs ||
      simulations < minimumSimulations) {
    var node = root;
    while (!node.state.terminal &&
        node.untried.isEmpty &&
        node.children.isNotEmpty) {
      node = _selectGoChild(node, random, explorationConstant);
    }
    if (!node.state.terminal && node.untried.isNotEmpty) {
      final action = _chooseGoExpansion(node, random);
      node.untried.remove(action);
      final next = node.state.apply(action);
      final child = _GoMctsNode(
        state: next,
        parent: node,
        action: action,
        prior: _goMovePrior(node.state, action),
        branchLimit: branchLimit,
      );
      node.children.add(child);
      node = child;
      nodes += 1;
    }
    final reward = _rolloutGo(node.state, random, rolloutDepth);
    while (true) {
      node.visits += 1;
      node.reward += reward;
      final parent = node.parent;
      if (parent == null) break;
      node = parent;
    }
    simulations += 1;
  }
  stopwatch.stop();
  if (root.children.isEmpty) {
    return {
      'index': null,
      'simulations': simulations,
      'nodes': nodes,
      'elapsed_milliseconds': stopwatch.elapsedMilliseconds,
      'win_rate': 0.5,
      'reason': 'no_legal_placement',
      'top_candidates': <Map<String, dynamic>>[],
    };
  }
  root.children.sort((a, b) => b.visits.compareTo(a.visits));
  var best = _chooseGoRootMove(root.children, random, moveTemperature);
  final occupied = rootState.board.where((stone) => stone != 0).length;
  if (best.action == -1 && occupied < 61) {
    best = root.children.firstWhere(
      (child) => child.action != -1,
      orElse: () => best,
    );
  }
  final placement = best.action == -1
      ? null
      : _tryGoPlacement(
          rootState.board,
          best.action!,
          2,
          forbiddenHashes: rootState.history,
        );
  final reason = best.action == -1
      ? 'close_scoring'
      : placement != null && placement.captured.isNotEmpty
      ? 'capture_and_shape'
      : best.mean >= 0.62
      ? 'territory_and_influence'
      : 'balanced_shape';
  return {
    'index': best.action == -1 ? null : best.action,
    'simulations': simulations,
    'nodes': nodes,
    'elapsed_milliseconds': stopwatch.elapsedMilliseconds,
    'win_rate': best.mean,
    'reason': reason,
    'top_candidates': [
      for (final child in root.children.take(6))
        {
          'index': child.action == -1 ? null : child.action,
          'visits': child.visits,
          'win_rate': child.mean,
          'prior': child.prior,
        },
    ],
  };
}

_GoMctsNode _selectGoChild(
  _GoMctsNode node,
  math.Random random,
  double explorationConstant,
) {
  final logParent = math.log(math.max(2, node.visits));
  final maximizing = node.state.turnStone == GoEngine._agentStone;
  var bestScore = -double.infinity;
  var best = node.children.first;
  for (final child in node.children) {
    final exploitation = maximizing ? child.mean : 1 - child.mean;
    final exploration =
        explorationConstant *
        math.sqrt(logParent / math.max(1, child.visits)) *
        (0.84 + child.prior * 0.16);
    final jitter = random.nextDouble() * 0.00001;
    final score = exploitation + exploration + jitter;
    if (score > bestScore) {
      bestScore = score;
      best = child;
    }
  }
  return best;
}

int _chooseGoExpansion(_GoMctsNode node, math.Random random) {
  if (node.untried.length == 1) return node.untried.first;
  final pool = node.untried
      .take(math.min(8, node.untried.length))
      .toList(growable: false);
  if (random.nextDouble() < 0.72) return pool.first;
  return pool[random.nextInt(pool.length)];
}

List<int> _rankGoActions(_GoSearchState state, int branchLimit) {
  final actions = state.legalActions();
  final priors = <int, double>{
    for (final action in actions) action: _goMovePrior(state, action),
  };
  actions.sort((a, b) => priors[b]!.compareTo(priors[a]!));
  final passIncluded = actions.remove(-1);
  final limit = state.ply < 8 ? branchLimit : math.min(branchLimit, 14);
  final ranked = actions.take(limit).toList(growable: true);
  if (passIncluded) ranked.add(-1);
  return ranked;
}

double _rolloutGo(_GoSearchState start, math.Random random, int rolloutDepth) {
  var state = start;
  var guard = 0;
  while (!state.terminal && guard++ < rolloutDepth) {
    final occupied = state.board.where((stone) => stone != 0).length;
    final int action;
    if (occupied > 66 && random.nextDouble() < 0.22) {
      action = -1;
    } else {
      action = _chooseGoRolloutAction(state, random) ?? -1;
    }
    state = state.apply(action);
  }
  final score = _scoreGoBoard(state.board, state.komi);
  return switch (score.status) {
    GoStatus.agentWon => 1,
    GoStatus.draw => 0.5,
    _ => 0,
  };
}

_GoMctsNode _chooseGoRootMove(
  List<_GoMctsNode> ranked,
  math.Random random,
  double temperature,
) {
  if (ranked.length < 2 || temperature <= 0.01) return ranked.first;
  final candidates = ranked.take(math.min(6, ranked.length)).toList();
  final exponent = 1 / temperature.clamp(0.05, 3.0);
  final weights = [
    for (final child in candidates)
      math.pow(math.max(1, child.visits), exponent).toDouble(),
  ];
  final total = weights.fold<double>(0, (sum, value) => sum + value);
  var cursor = random.nextDouble() * total;
  for (var index = 0; index < candidates.length; index += 1) {
    cursor -= weights[index];
    if (cursor <= 0) return candidates[index];
  }
  return candidates.first;
}

int? _chooseGoRolloutAction(_GoSearchState state, math.Random random) {
  final nearby = <int>{};
  final empty = <int>[];
  for (var index = 0; index < state.board.length; index += 1) {
    if (state.board[index] == GoEngine._empty) {
      empty.add(index);
      continue;
    }
    for (final neighbor in _goNeighbors(index)) {
      if (state.board[neighbor] == GoEngine._empty) nearby.add(neighbor);
    }
  }
  empty.shuffle(random);
  final candidates = <int>{...nearby.take(8), ...empty.take(6)};
  final ranked = <(int, double)>[];
  for (final action in candidates) {
    final placement = _tryGoPlacement(
      state.board,
      action,
      state.turnStone,
      forbiddenHashes: state.history,
    );
    if (placement == null) continue;
    final row = action ~/ GoEngine.boardSize;
    final col = action % GoEngine.boardSize;
    final edge = math.min(math.min(row, col), math.min(8 - row, 8 - col));
    var value = placement.captured.length * 8.0;
    value += placement.liberties * 0.22;
    value += edge == 2 ? 1.1 : (edge == 0 ? -0.7 : 0.45);
    value += random.nextDouble() * 0.35;
    ranked.add((action, value));
  }
  if (ranked.isEmpty) return null;
  ranked.sort((a, b) => b.$2.compareTo(a.$2));
  final poolSize = math.min(4, ranked.length);
  return ranked[random.nextInt(poolSize)].$1;
}

double _goMovePrior(_GoSearchState state, int action) {
  if (action == -1) {
    final occupied = state.board.where((stone) => stone != 0).length;
    return occupied > 68 ? 0.72 : 0.01;
  }
  final placement = _tryGoPlacement(
    state.board,
    action,
    state.turnStone,
    forbiddenHashes: state.history,
  );
  if (placement == null) return -1000;
  final row = action ~/ GoEngine.boardSize;
  final col = action % GoEngine.boardSize;
  final edge = math.min(math.min(row, col), math.min(8 - row, 8 - col));
  var score = placement.captured.length * 8.0 + placement.liberties * 0.22;
  score += switch (edge) {
    0 => -0.7,
    1 => 0.4,
    2 => 1.1,
    _ => 0.7,
  };
  for (final neighbor in _goNeighbors(action)) {
    if (state.board[neighbor] == state.turnStone) score += 0.34;
    if (state.board[neighbor] == _opponentStone(state.turnStone)) score += 0.2;
  }
  return score;
}

_GoPlacement? _tryGoPlacement(
  List<int> source,
  int index,
  int stone, {
  Set<int> forbiddenHashes = const {},
}) {
  if (index < 0 || index >= source.length || source[index] != GoEngine._empty) {
    return null;
  }
  final board = List<int>.from(source)..[index] = stone;
  final opponent = _opponentStone(stone);
  final captured = <int>[];
  final checked = <int>{};
  for (final neighbor in _goNeighbors(index)) {
    if (board[neighbor] != opponent || checked.contains(neighbor)) continue;
    final group = _goGroup(board, neighbor);
    checked.addAll(group.stones);
    if (group.liberties.isEmpty) {
      captured.addAll(group.stones);
      for (final point in group.stones) {
        board[point] = GoEngine._empty;
      }
    }
  }
  final ownGroup = _goGroup(board, index);
  if (ownGroup.liberties.isEmpty) return null;
  if (forbiddenHashes.contains(_goBoardHash(board))) return null;
  captured.sort();
  return _GoPlacement(board, captured, ownGroup.liberties.length);
}

_GoGroup _goGroup(List<int> board, int start) {
  final stone = board[start];
  final stones = <int>{start};
  final liberties = <int>{};
  final stack = <int>[start];
  while (stack.isNotEmpty) {
    final current = stack.removeLast();
    for (final neighbor in _goNeighbors(current)) {
      final value = board[neighbor];
      if (value == GoEngine._empty) {
        liberties.add(neighbor);
      } else if (value == stone && stones.add(neighbor)) {
        stack.add(neighbor);
      }
    }
  }
  return _GoGroup(stones, liberties);
}

List<int> _goNeighbors(int index) {
  final row = index ~/ GoEngine.boardSize;
  final col = index % GoEngine.boardSize;
  return [
    if (row > 0) index - GoEngine.boardSize,
    if (row + 1 < GoEngine.boardSize) index + GoEngine.boardSize,
    if (col > 0) index - 1,
    if (col + 1 < GoEngine.boardSize) index + 1,
  ];
}

GoScore _scoreGoBoard(List<int> board, double komi) {
  final visited = <int>{};
  var userTerritory = 0;
  var agentTerritory = 0;
  var neutral = 0;
  for (var index = 0; index < board.length; index += 1) {
    if (board[index] != GoEngine._empty || visited.contains(index)) continue;
    final region = <int>{index};
    final borders = <int>{};
    final stack = <int>[index];
    visited.add(index);
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      for (final neighbor in _goNeighbors(current)) {
        final value = board[neighbor];
        if (value == GoEngine._empty && visited.add(neighbor)) {
          region.add(neighbor);
          stack.add(neighbor);
        } else if (value != GoEngine._empty) {
          borders.add(value);
        }
      }
    }
    if (borders.length == 1 && borders.first == GoEngine._userStone) {
      userTerritory += region.length;
    } else if (borders.length == 1 && borders.first == GoEngine._agentStone) {
      agentTerritory += region.length;
    } else {
      neutral += region.length;
    }
  }
  return GoScore(
    userStones: board.where((stone) => stone == GoEngine._userStone).length,
    agentStones: board.where((stone) => stone == GoEngine._agentStone).length,
    userTerritory: userTerritory,
    agentTerritory: agentTerritory,
    neutralPoints: neutral,
    komi: komi,
  );
}

Map<String, dynamic>? _goMoment({
  required List<int> board,
  required int actorStone,
  required int? index,
  required List<int> captured,
  required int liberties,
  required int consecutivePasses,
}) {
  if (index == null) {
    return {
      'type': consecutivePasses >= 2 ? 'scoring_started' : 'pass',
      'label': consecutivePasses >= 2 ? '双方停着，开始数目' : '选择停一手',
    };
  }
  if (captured.length >= 4) {
    return {
      'type': 'large_capture',
      'label': '一手提掉 ${captured.length} 子',
      'capture_count': captured.length,
    };
  }
  if (captured.isNotEmpty) {
    return {
      'type': 'capture',
      'label': '提掉 ${captured.length} 子',
      'capture_count': captured.length,
    };
  }
  var atariGroups = 0;
  final checked = <int>{};
  for (final neighbor in _goNeighbors(index)) {
    if (board[neighbor] != _opponentStone(actorStone) ||
        checked.contains(neighbor)) {
      continue;
    }
    final group = _goGroup(board, neighbor);
    checked.addAll(group.stones);
    if (group.liberties.length == 1) atariGroups += 1;
  }
  if (atariGroups > 0) {
    return {'type': 'atari', 'label': '叫吃', 'groups_in_atari': atariGroups};
  }
  if (liberties == 1) {
    return {'type': 'self_atari', 'label': '紧气落子'};
  }
  return null;
}

int _stoneFor(GoActor actor) =>
    actor == GoActor.user ? GoEngine._userStone : GoEngine._agentStone;

int _opponentStone(int stone) =>
    stone == GoEngine._userStone ? GoEngine._agentStone : GoEngine._userStone;

int _goBoardHash(List<int> board) {
  var hash = 0x13579b;
  for (final stone in board) {
    hash = ((hash * 1000003) ^ (stone + 41)) & 0x7fffffff;
  }
  return hash;
}

int _goStateHash(List<int> board, int turn, int passes) {
  var hash = _goBoardHash(board);
  hash = ((hash * 37) ^ (turn + 17)) & 0x7fffffff;
  hash = ((hash * 37) ^ (passes + 23)) & 0x7fffffff;
  return hash;
}

const _goColumns = 'ABCDEFGHJ';
