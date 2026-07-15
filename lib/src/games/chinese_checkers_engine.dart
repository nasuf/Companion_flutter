import 'dart:math' as math;

import 'package:flutter/foundation.dart';

enum ChineseCheckersActor { user, agent }

enum ChineseCheckersStatus { playing, userWon, agentWon }

class ChineseCheckersCell {
  const ChineseCheckersCell(this.index, this.x, this.row);

  final int index;
  final int x;
  final int row;

  Map<String, dynamic> toJson() => {'index': index, 'x': x, 'row': row};
}

class ChineseCheckersMove {
  const ChineseCheckersMove({
    required this.number,
    required this.actor,
    required this.path,
    required this.stateBeforeHash,
    required this.stateAfterHash,
    required this.progressDelta,
    required this.targetPieces,
    required this.moment,
    this.decision,
  });

  final int number;
  final ChineseCheckersActor actor;
  final List<int> path;
  final int stateBeforeHash;
  final int stateAfterHash;
  final int progressDelta;
  final int targetPieces;
  final Map<String, dynamic>? moment;
  final ChineseCheckersAiDecision? decision;

  bool get isJump => path.length > 2 || !_areAdjacent(path.first, path.last);

  Map<String, dynamic> toJson() => {
    'move_number': number,
    'actor': actor.name,
    'from': _boardCells[path.first].toJson(),
    'to': _boardCells[path.last].toJson(),
    'path': [for (final index in path) _boardCells[index].toJson()],
    'jump_count': isJump ? math.max(1, path.length - 1) : 0,
    'state_before_hash': stateBeforeHash.toString(),
    'state_after_hash': stateAfterHash.toString(),
    'progress_delta': progressDelta,
    'target_pieces': targetPieces,
    if (moment != null) 'moment': moment,
    if (decision != null) 'decision': decision!.toJson(),
  };
}

class ChineseCheckersAiDecision {
  const ChineseCheckersAiDecision({
    required this.path,
    required this.score,
    required this.depth,
    required this.nodes,
    required this.elapsedMilliseconds,
    required this.candidatesConsidered,
    required this.principalVariation,
  });

  final List<int> path;
  final int score;
  final int depth;
  final int nodes;
  final int elapsedMilliseconds;
  final int candidatesConsidered;
  final List<List<int>> principalVariation;

  factory ChineseCheckersAiDecision.fromJson(Map<String, dynamic> json) =>
      ChineseCheckersAiDecision(
        path: List<int>.from(json['path']! as List),
        score: json['score']! as int,
        depth: json['depth']! as int,
        nodes: json['nodes']! as int,
        elapsedMilliseconds: json['elapsed_milliseconds']! as int,
        candidatesConsidered: json['candidates_considered']! as int,
        principalVariation: [
          for (final item in json['principal_variation']! as List)
            List<int>.from(item as List),
        ],
      );

  Map<String, dynamic> toJson() => {
    'path': path,
    'score': score,
    'search_depth': depth,
    'nodes_searched': nodes,
    'elapsed_milliseconds': elapsedMilliseconds,
    'candidates_considered': candidatesConsidered,
    'principal_variation': principalVariation,
    'algorithm': 'iterative_deepening_alpha_beta_beam_tt',
  };
}

class ChineseCheckersMoveResult {
  const ChineseCheckersMoveResult({required this.move, required this.status});

  final ChineseCheckersMove move;
  final ChineseCheckersStatus status;
}

class ChineseCheckersEngine {
  ChineseCheckersEngine() : _board = List<int>.filled(_boardCells.length, -1) {
    for (final index in _bottomCamp) {
      _board[index] = ChineseCheckersActor.user.index;
    }
    for (final index in _topCamp) {
      _board[index] = ChineseCheckersActor.agent.index;
    }
  }

  ChineseCheckersEngine.debug(
    List<int> board, {
    this.turn = ChineseCheckersActor.user,
  }) : assert(board.length == 121),
       _board = List<int>.from(board);

  factory ChineseCheckersEngine.restore(
    Map<String, dynamic> state, {
    int actionCount = 0,
  }) {
    final board = List<int>.filled(_boardCells.length, -1);
    final pieces = state['pieces'];
    if (pieces is! List) throw const FormatException('missing_pieces');
    for (final raw in pieces.whereType<Map>()) {
      final piece = Map<String, dynamic>.from(raw);
      final index = (piece['index'] as num?)?.round();
      final actor = ChineseCheckersActor.values.firstWhere(
        (item) => item.name == piece['actor'],
        orElse: () => throw const FormatException('invalid_actor'),
      );
      if (index == null || index < 0 || index >= board.length) {
        throw const FormatException('invalid_piece');
      }
      board[index] = actor.index;
    }
    final engine = ChineseCheckersEngine.debug(
      board,
      turn: ChineseCheckersActor.values.firstWhere(
        (item) => item.name == state['turn'],
        orElse: () => ChineseCheckersActor.user,
      ),
    );
    engine._moveOffset = actionCount;
    return engine;
  }

  final List<int> _board;
  final List<ChineseCheckersMove> _moves = [];
  int _moveOffset = 0;
  ChineseCheckersActor turn = ChineseCheckersActor.user;

  static List<ChineseCheckersCell> get cells => _boardCells;
  List<int> get board => List.unmodifiable(_board);
  List<ChineseCheckersMove> get moves => List.unmodifiable(_moves);
  int get stateHash => _hashBoard(_board, turn.index);
  bool get isFinished => status != ChineseCheckersStatus.playing;
  int get moveCount => _moveOffset + _moves.length;
  ChineseCheckersStatus get status {
    if (_topCamp.every(
      (index) => _board[index] == ChineseCheckersActor.user.index,
    )) {
      return ChineseCheckersStatus.userWon;
    }
    if (_bottomCamp.every(
      (index) => _board[index] == ChineseCheckersActor.agent.index,
    )) {
      return ChineseCheckersStatus.agentWon;
    }
    return ChineseCheckersStatus.playing;
  }

  List<List<int>> legalPathsFrom(int from) {
    if (from < 0 || from >= _board.length || _board[from] != turn.index) {
      return const [];
    }
    return _legalMoves(
      _board,
      turn.index,
    ).where((path) => path.first == from).toList(growable: false);
  }

  ChineseCheckersMoveResult playPath(
    List<int> path, {
    ChineseCheckersAiDecision? decision,
  }) {
    if (isFinished) throw StateError('game_finished');
    final legal = legalPathsFrom(path.first);
    final selected = legal.firstWhere(
      (candidate) => _samePath(candidate, path),
      orElse: () => throw StateError('invalid_move'),
    );
    final actor = turn;
    final beforeHash = stateHash;
    final beforeProgress = _progressFor(_board, actor.index);
    _board[selected.last] = _board[selected.first];
    _board[selected.first] = -1;
    final afterProgress = _progressFor(_board, actor.index);
    final target = actor == ChineseCheckersActor.user ? _topCamp : _bottomCamp;
    final targetPieces = target
        .where((index) => _board[index] == actor.index)
        .length;
    final moment = _momentFor(
      selected,
      targetPieces,
      afterProgress - beforeProgress,
    );
    turn = actor == ChineseCheckersActor.user
        ? ChineseCheckersActor.agent
        : ChineseCheckersActor.user;
    final move = ChineseCheckersMove(
      number: _moveOffset + _moves.length + 1,
      actor: actor,
      path: List.unmodifiable(selected),
      stateBeforeHash: beforeHash,
      stateAfterHash: stateHash,
      progressDelta: afterProgress - beforeProgress,
      targetPieces: targetPieces,
      moment: moment,
      decision: decision,
    );
    _moves.add(move);
    return ChineseCheckersMoveResult(move: move, status: status);
  }

  Future<ChineseCheckersAiDecision> chooseAiMove() async {
    if (turn != ChineseCheckersActor.agent) throw StateError('not_agent_turn');
    if (isFinished) throw StateError('game_finished');
    final json = await compute(_searchChineseCheckers, {
      'board': _board,
      'budget_ms': 300,
      'seed': _moves.length * 97 + stateHash,
    });
    return ChineseCheckersAiDecision.fromJson(json);
  }

  Map<String, dynamic> analysisJson() {
    final userTarget = _topCamp.where((index) => _board[index] == 0).length;
    final agentTarget = _bottomCamp.where((index) => _board[index] == 1).length;
    return {
      'state_hash': stateHash.toString(),
      'turn': turn.name,
      'user_progress': _progressFor(_board, 0),
      'agent_progress': _progressFor(_board, 1),
      'user_target_pieces': userTarget,
      'agent_target_pieces': agentTarget,
      'legal_move_count': isFinished
          ? 0
          : _legalMoves(_board, turn.index).length,
    };
  }

  Map<String, dynamic> stateJson() => {
    'state_hash': stateHash.toString(),
    'turn': turn.name,
    'status': status.name,
    'pieces': [
      for (var index = 0; index < _board.length; index++)
        if (_board[index] >= 0)
          {
            ..._boardCells[index].toJson(),
            'actor': ChineseCheckersActor.values[_board[index]].name,
          },
    ],
  };

  Map<String, dynamic> summaryJson() => {
    'status': status.name,
    'move_count': moveCount,
    'actions': [for (final move in _moves) move.toJson()],
    'key_moments': [
      for (final move in _moves)
        if (move.moment != null) {...move.moment!, 'move_number': move.number},
    ],
    'analysis': analysisJson(),
    'final_state': stateJson(),
  };

  Map<String, dynamic>? _momentFor(
    List<int> path,
    int targetPieces,
    int progressDelta,
  ) {
    if (targetPieces == 10) return {'type': 'decisive_finish'};
    if (targetPieces >= 8) {
      return {'type': 'near_finish', 'target_pieces': targetPieces};
    }
    if (path.length >= 4) {
      return {'type': 'long_jump', 'jump_count': path.length - 1};
    }
    if (progressDelta >= 6) {
      return {'type': 'breakthrough', 'progress': progressDelta};
    }
    return null;
  }
}

const _rowLengths = [1, 2, 3, 4, 13, 12, 11, 10, 9, 10, 11, 12, 13, 4, 3, 2, 1];
final List<ChineseCheckersCell> _boardCells = _buildCells();
final Map<(int, int), int> _cellByCoordinate = {
  for (final cell in _boardCells) (cell.x, cell.row): cell.index,
};
final Set<int> _topCamp = {
  for (final cell in _boardCells)
    if (cell.row <= 3) cell.index,
};
final Set<int> _bottomCamp = {
  for (final cell in _boardCells)
    if (cell.row >= 13) cell.index,
};
const _directions = [(2, 0), (-2, 0), (1, 1), (-1, 1), (1, -1), (-1, -1)];

bool _areAdjacent(int from, int to) {
  final source = _boardCells[from];
  final target = _boardCells[to];
  return _directions.contains((target.x - source.x, target.row - source.row));
}

List<ChineseCheckersCell> _buildCells() {
  final result = <ChineseCheckersCell>[];
  for (var row = 0; row < _rowLengths.length; row++) {
    final length = _rowLengths[row];
    final start = -(length - 1);
    for (var col = 0; col < length; col++) {
      result.add(ChineseCheckersCell(result.length, start + col * 2, row));
    }
  }
  return List.unmodifiable(result);
}

List<List<int>> _legalMoves(List<int> board, int actor) {
  final moves = <List<int>>[];
  for (var from = 0; from < board.length; from++) {
    if (board[from] != actor) continue;
    final cell = _boardCells[from];
    for (final (dx, dy) in _directions) {
      final target = _cellByCoordinate[(cell.x + dx, cell.row + dy)];
      if (target != null &&
          board[target] < 0 &&
          _campMoveAllowed(actor, from, target)) {
        moves.add([from, target]);
      }
    }
    final bestPaths = <int, List<int>>{};
    _collectJumps(board, actor, from, from, {from}, [from], bestPaths);
    moves.addAll(bestPaths.values);
  }
  return moves;
}

void _collectJumps(
  List<int> board,
  int actor,
  int origin,
  int current,
  Set<int> visited,
  List<int> path,
  Map<int, List<int>> bestPaths,
) {
  final cell = _boardCells[current];
  for (final (dx, dy) in _directions) {
    final middle = _cellByCoordinate[(cell.x + dx, cell.row + dy)];
    final target = _cellByCoordinate[(cell.x + dx * 2, cell.row + dy * 2)];
    if (middle == null ||
        target == null ||
        board[middle] < 0 ||
        board[target] >= 0 ||
        visited.contains(target)) {
      continue;
    }
    if (!_campMoveAllowed(actor, origin, target)) continue;
    final next = [...path, target];
    final previous = bestPaths[target];
    if (previous == null || next.length < previous.length) {
      bestPaths[target] = next;
    }
    visited.add(target);
    _collectJumps(board, actor, origin, target, visited, next, bestPaths);
    visited.remove(target);
  }
}

bool _campMoveAllowed(int actor, int from, int to) {
  final ownCamp = actor == 0 ? _bottomCamp : _topCamp;
  final targetCamp = actor == 0 ? _topCamp : _bottomCamp;
  if (targetCamp.contains(from) && !targetCamp.contains(to)) return false;
  if (!ownCamp.contains(from) && ownCamp.contains(to)) return false;
  return true;
}

bool _samePath(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

int _progressFor(List<int> board, int actor) {
  var score = 0;
  for (var index = 0; index < board.length; index++) {
    if (board[index] != actor) continue;
    final row = _boardCells[index].row;
    score += actor == 0 ? 16 - row : row;
    final target = actor == 0 ? _topCamp : _bottomCamp;
    if (target.contains(index)) score += 14;
  }
  return score;
}

int _hashBoard(List<int> board, int turn) {
  var hash = 0x811C9DC5 ^ turn;
  for (var i = 0; i < board.length; i++) {
    hash ^= (board[i] + 2) * (i + 17) * 0x45D9F3B;
    hash = (hash * 0x01000193) & 0x7FFFFFFF;
  }
  return hash;
}

Map<String, dynamic> _searchChineseCheckers(Map<String, dynamic> input) {
  final board = List<int>.from(input['board']! as List);
  final budgetMs = input['budget_ms']! as int;
  final random = math.Random(input['seed']! as int);
  final search = _ChineseCheckersSearch(budgetMs: budgetMs);
  final rootMoves = search.orderedMoves(board, 1, limit: 34);
  if (rootMoves.isEmpty) throw StateError('no_legal_move');
  var completed = <_CheckersScoredMove>[];
  var depthReached = 0;
  for (var depth = 1; depth <= 4; depth++) {
    final current = <_CheckersScoredMove>[];
    for (final move in rootMoves) {
      if (search.expired) break;
      final next = _applyCheckersMove(board, move, 1);
      final child = search.alphaBeta(
        next,
        depth - 1,
        -1000000,
        1000000,
        false,
        0,
      );
      current.add(_CheckersScoredMove(move, child.score, [move, ...child.pv]));
    }
    if (current.isEmpty || search.expired) break;
    current.sort((a, b) => b.score.compareTo(a.score));
    completed = current;
    depthReached = depth;
  }
  if (completed.isEmpty) {
    completed = [
      for (final move in rootMoves)
        _CheckersScoredMove(
          move,
          _evaluateCheckers(_applyCheckersMove(board, move, 1)),
          [move],
        ),
    ]..sort((a, b) => b.score.compareTo(a.score));
  }
  final best = completed.first.score;
  final near = completed
      .where((item) => best - item.score <= 3)
      .take(3)
      .toList();
  final selected = near.length > 1 && random.nextDouble() < .16
      ? near[random.nextInt(near.length)]
      : completed.first;
  return {
    'path': selected.move,
    'score': selected.score,
    'depth': math.max(1, depthReached),
    'nodes': search.nodes,
    'elapsed_milliseconds': search.elapsedMilliseconds,
    'candidates_considered': rootMoves.length,
    'principal_variation': selected.pv,
  };
}

class _ChineseCheckersSearch {
  _ChineseCheckersSearch({required this.budgetMs})
    : stopwatch = Stopwatch()..start();
  final int budgetMs;
  final Stopwatch stopwatch;
  final Map<int, (int, int)> table = {};
  int nodes = 0;
  bool get expired => stopwatch.elapsedMilliseconds >= budgetMs;
  int get elapsedMilliseconds => stopwatch.elapsedMilliseconds;

  _CheckersSearchResult alphaBeta(
    List<int> board,
    int depth,
    int alpha,
    int beta,
    bool maximizing,
    int ply,
  ) {
    nodes++;
    if (expired || depth <= 0 || _checkersWinner(board) != null) {
      return _CheckersSearchResult(_evaluateCheckers(board), const []);
    }
    final hash = _hashBoard(board, maximizing ? 1 : 0) ^ depth;
    final cached = table[hash];
    if (cached != null && cached.$1 >= depth) {
      return _CheckersSearchResult(cached.$2, const []);
    }
    final actor = maximizing ? 1 : 0;
    final moves = orderedMoves(board, actor, limit: ply < 2 ? 24 : 16);
    if (moves.isEmpty) {
      return _CheckersSearchResult(_evaluateCheckers(board), const []);
    }
    var best = maximizing ? -1000000 : 1000000;
    var bestPv = <List<int>>[];
    for (final move in moves) {
      if (expired) break;
      final next = _applyCheckersMove(board, move, actor);
      final child = alphaBeta(
        next,
        depth - 1,
        alpha,
        beta,
        !maximizing,
        ply + 1,
      );
      if (maximizing ? child.score > best : child.score < best) {
        best = child.score;
        bestPv = [move, ...child.pv];
      }
      if (maximizing) {
        alpha = math.max(alpha, best);
      } else {
        beta = math.min(beta, best);
      }
      if (alpha >= beta) break;
    }
    table[hash] = (depth, best);
    return _CheckersSearchResult(best, bestPv);
  }

  List<List<int>> orderedMoves(
    List<int> board,
    int actor, {
    required int limit,
  }) {
    final moves = _legalMoves(board, actor);
    moves.sort(
      (a, b) =>
          _moveOrder(board, b, actor).compareTo(_moveOrder(board, a, actor)),
    );
    return moves.take(limit).toList();
  }
}

class _CheckersSearchResult {
  const _CheckersSearchResult(this.score, this.pv);
  final int score;
  final List<List<int>> pv;
}

class _CheckersScoredMove {
  const _CheckersScoredMove(this.move, this.score, this.pv);
  final List<int> move;
  final int score;
  final List<List<int>> pv;
}

List<int> _applyCheckersMove(List<int> board, List<int> move, int actor) {
  final next = List<int>.from(board);
  next[move.first] = -1;
  next[move.last] = actor;
  return next;
}

int _moveOrder(List<int> board, List<int> move, int actor) {
  final from = _boardCells[move.first];
  final to = _boardCells[move.last];
  final progress = actor == 0 ? from.row - to.row : to.row - from.row;
  final target = actor == 0 ? _topCamp : _bottomCamp;
  return progress * 20 +
      (move.length - 2) * 5 +
      (target.contains(move.last) ? 60 : 0) -
      to.x.abs();
}

int _evaluateCheckers(List<int> board) {
  final winner = _checkersWinner(board);
  if (winner == 1) return 900000;
  if (winner == 0) return -900000;
  final agent = _progressFor(board, 1);
  final user = _progressFor(board, 0);
  final agentMobility = _legalMoves(board, 1).length;
  final userMobility = _legalMoves(board, 0).length;
  return (agent - user) * 12 + (agentMobility - userMobility);
}

int? _checkersWinner(List<int> board) {
  if (_topCamp.every((index) => board[index] == 0)) return 0;
  if (_bottomCamp.every((index) => board[index] == 1)) return 1;
  return null;
}
