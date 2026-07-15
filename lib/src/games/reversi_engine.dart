import 'dart:math' as math;

import 'package:flutter/foundation.dart';

enum ReversiActor { user, agent }

enum ReversiStatus { playing, userWon, agentWon, draw }

class ReversiPoint {
  const ReversiPoint(this.index);

  final int index;

  int get row => index ~/ ReversiEngine.size;
  int get col => index % ReversiEngine.size;
  String get coordinate => '${String.fromCharCode(65 + col)}${row + 1}';

  Map<String, dynamic> toJson() => {
    'index': index,
    'row': row,
    'col': col,
    'coordinate': coordinate,
  };
}

class ReversiAiDecision {
  const ReversiAiDecision({
    required this.point,
    required this.score,
    required this.depth,
    required this.nodes,
    required this.elapsedMs,
    required this.candidatesConsidered,
    required this.principalVariation,
    required this.candidateScores,
    required this.solvedToEnd,
  });

  final ReversiPoint point;
  final int score;
  final int depth;
  final int nodes;
  final int elapsedMs;
  final int candidatesConsidered;
  final List<ReversiPoint> principalVariation;
  final List<Map<String, dynamic>> candidateScores;
  final bool solvedToEnd;

  Map<String, dynamic> toJson() => {
    'move': point.toJson(),
    'score': score,
    'depth': depth,
    'nodes_searched': nodes,
    'elapsed_ms': elapsedMs,
    'candidates_considered': candidatesConsidered,
    'principal_variation': [
      for (final point in principalVariation) point.toJson(),
    ],
    'candidate_scores': candidateScores,
    'solved_to_end': solvedToEnd,
    'algorithm':
        'iterative_deepening_pvs_alpha_beta_tt_mobility_stability_parity',
  };
}

class ReversiMove {
  const ReversiMove({
    required this.number,
    required this.actor,
    required this.point,
    required this.flipped,
    required this.stateBeforeHash,
    required this.stateAfterHash,
    required this.boardBefore,
    required this.boardAfter,
    required this.userCount,
    required this.agentCount,
    required this.userMobility,
    required this.agentMobility,
    required this.cornerCaptured,
    required this.leadChanged,
    required this.forcedPass,
    required this.moments,
    this.decision,
  });

  final int number;
  final ReversiActor actor;
  final ReversiPoint point;
  final List<ReversiPoint> flipped;
  final int stateBeforeHash;
  final int stateAfterHash;
  final List<int> boardBefore;
  final List<int> boardAfter;
  final int userCount;
  final int agentCount;
  final int userMobility;
  final int agentMobility;
  final bool cornerCaptured;
  final bool leadChanged;
  final ReversiActor? forcedPass;
  final List<Map<String, dynamic>> moments;
  final ReversiAiDecision? decision;

  Map<String, dynamic> toJson() => {
    'move_number': number,
    'actor': actor.name,
    'move': point.toJson(),
    'at': point.toJson(),
    'flipped_count': flipped.length,
    'flipped': [for (final point in flipped) point.toJson()],
    'state_before_hash': stateBeforeHash.toString(),
    'state_after_hash': stateAfterHash.toString(),
    'user_count': userCount,
    'agent_count': agentCount,
    'user_mobility': userMobility,
    'agent_mobility': agentMobility,
    'corner_captured': cornerCaptured,
    'lead_changed': leadChanged,
    if (forcedPass != null) 'forced_pass': forcedPass!.name,
    'moments': moments,
    if (decision != null) 'decision': decision!.toJson(),
  };
}

class ReversiMoveResult {
  const ReversiMoveResult({required this.move, required this.status});

  final ReversiMove move;
  final ReversiStatus status;
}

class ReversiEngine {
  ReversiEngine() : _board = _initialBoard();

  ReversiEngine.debug(List<int> board, {this.turn = ReversiActor.user})
    : assert(board.length == size * size),
      assert(board.every((value) => value >= -1 && value <= 1)),
      _board = List<int>.from(board) {
    _updateStatus();
  }

  factory ReversiEngine.restore(
    Map<String, dynamic> state, {
    int moveCount = 0,
  }) {
    final board = (state['board'] as List? ?? const [])
        .whereType<num>()
        .map((item) => item.round())
        .toList(growable: false);
    if (board.length != size * size) {
      throw const FormatException('invalid_board');
    }
    final engine = ReversiEngine.debug(
      board,
      turn: ReversiActor.values.firstWhere(
        (item) => item.name == state['turn'],
        orElse: () => ReversiActor.user,
      ),
    );
    engine._moveOffset = moveCount;
    return engine;
  }

  static const int size = 8;
  static const int userDisc = 1;
  static const int agentDisc = -1;

  List<int> _board;
  final List<ReversiMove> _moves = [];
  int _moveOffset = 0;
  ReversiActor turn = ReversiActor.user;
  ReversiStatus _status = ReversiStatus.playing;

  List<int> get board => List<int>.unmodifiable(_board);
  List<ReversiMove> get moves => List<ReversiMove>.unmodifiable(_moves);
  ReversiStatus get status => _status;
  bool get isFinished => _status != ReversiStatus.playing;
  int get moveCount => _moveOffset + _moves.length;
  int get userCount => _board.where((value) => value == userDisc).length;
  int get agentCount => _board.where((value) => value == agentDisc).length;
  int get emptyCount => _board.where((value) => value == 0).length;
  int get stateHash => _reversiHash(_board, _actorValue(turn));

  Map<int, List<int>> legalMovesFor(ReversiActor actor) =>
      _reversiLegalMoves(_board, _actorValue(actor));

  Map<int, List<int>> get legalMoves => legalMovesFor(turn);

  bool isLegal(int index) => legalMoves.containsKey(index);

  Future<ReversiAiDecision> chooseAiMove() async {
    if (turn != ReversiActor.agent) throw StateError('not_agent_turn');
    if (isFinished) throw StateError('game_finished');
    final legal = legalMoves;
    if (legal.isEmpty) throw StateError('no_legal_move');
    final maxDepth = emptyCount <= 14
        ? emptyCount
        : emptyCount <= 24
        ? 9
        : 7;
    final result = await compute(_searchReversiMove, {
      'board': _board,
      'time_ms': emptyCount <= 16 ? 1050 : 760,
      'max_depth': maxDepth,
    });
    return ReversiAiDecision(
      point: ReversiPoint(result['move'] as int),
      score: result['score'] as int,
      depth: result['depth'] as int,
      nodes: result['nodes'] as int,
      elapsedMs: result['elapsed_ms'] as int,
      candidatesConsidered: result['candidates_considered'] as int,
      principalVariation: [
        for (final value in result['principal_variation'] as List<dynamic>)
          ReversiPoint(value as int),
      ],
      candidateScores: [
        for (final value in result['candidate_scores'] as List<dynamic>)
          Map<String, dynamic>.from(value as Map<dynamic, dynamic>),
      ],
      solvedToEnd: result['solved_to_end'] as bool,
    );
  }

  ReversiMoveResult play(int index, {ReversiAiDecision? decision}) {
    if (isFinished) throw StateError('game_finished');
    final legal = legalMoves;
    final flips = legal[index];
    if (flips == null || flips.isEmpty) throw StateError('invalid_move');
    final actor = turn;
    final actorValue = _actorValue(actor);
    final before = List<int>.unmodifiable(_board);
    final beforeHash = stateHash;
    final beforeLead = userCount.compareTo(agentCount);
    final next = List<int>.from(_board)..[index] = actorValue;
    for (final flip in flips) {
      next[flip] = actorValue;
    }
    _board = next;

    final opponent = _opponent(actor);
    ReversiActor? forcedPass;
    if (_reversiLegalMoves(_board, _actorValue(opponent)).isNotEmpty) {
      turn = opponent;
    } else if (_reversiLegalMoves(_board, actorValue).isNotEmpty) {
      turn = actor;
      forcedPass = opponent;
    }
    _updateStatus();

    final cornerCaptured = _reversiCorners.contains(index);
    final afterLead = userCount.compareTo(agentCount);
    final leadChanged =
        beforeLead != 0 && afterLead != 0 && beforeLead != afterLead;
    final userMobility = legalMovesFor(ReversiActor.user).length;
    final agentMobility = legalMovesFor(ReversiActor.agent).length;
    final moments = <Map<String, dynamic>>[
      if (cornerCaptured)
        {'type': 'corner_captured', 'at': ReversiPoint(index).toJson()},
      if (flips.length >= 8)
        {'type': 'big_flip', 'flipped_count': flips.length},
      if (forcedPass != null) {'type': 'forced_pass', 'actor': forcedPass.name},
      if (!isFinished &&
          ((turn == ReversiActor.user ? userMobility : agentMobility) <= 2))
        {
          'type': 'mobility_squeeze',
          'actor': turn.name,
          'legal_moves': turn == ReversiActor.user
              ? userMobility
              : agentMobility,
        },
      if (leadChanged)
        {
          'type': 'lead_changed',
          'leader': afterLead > 0
              ? ReversiActor.user.name
              : ReversiActor.agent.name,
        },
    ];
    final move = ReversiMove(
      number: _moveOffset + _moves.length + 1,
      actor: actor,
      point: ReversiPoint(index),
      flipped: [for (final value in flips) ReversiPoint(value)],
      stateBeforeHash: beforeHash,
      stateAfterHash: stateHash,
      boardBefore: before,
      boardAfter: List<int>.unmodifiable(_board),
      userCount: userCount,
      agentCount: agentCount,
      userMobility: userMobility,
      agentMobility: agentMobility,
      cornerCaptured: cornerCaptured,
      leadChanged: leadChanged,
      forcedPass: forcedPass,
      moments: moments,
      decision: decision,
    );
    _moves.add(move);
    return ReversiMoveResult(move: move, status: status);
  }

  Map<String, dynamic> stateJson() => {
    'state_hash': stateHash.toString(),
    'turn': turn.name,
    'status': status.name,
    'board': _board,
    'user_count': userCount,
    'agent_count': agentCount,
    'empty_count': emptyCount,
    'move_count': moveCount,
  };

  Map<String, dynamic> analysisJson() {
    final userLegal = legalMovesFor(ReversiActor.user);
    final agentLegal = legalMovesFor(ReversiActor.agent);
    return {
      'state_hash': stateHash.toString(),
      'turn': turn.name,
      'user_count': userCount,
      'agent_count': agentCount,
      'disc_difference': userCount - agentCount,
      'empty_count': emptyCount,
      'user_mobility': userLegal.length,
      'agent_mobility': agentLegal.length,
      'user_corner_count': _cornerCount(_board, userDisc),
      'agent_corner_count': _cornerCount(_board, agentDisc),
      'user_frontier_count': _frontierCount(_board, userDisc),
      'agent_frontier_count': _frontierCount(_board, agentDisc),
      'legal_moves': [
        for (final index in legalMoves.keys) ReversiPoint(index).toJson(),
      ],
    };
  }

  Map<String, dynamic> summaryJson() => {
    'status': status.name,
    'user_outcome': switch (status) {
      ReversiStatus.userWon => 'win',
      ReversiStatus.agentWon => 'lose',
      ReversiStatus.draw => 'draw',
      ReversiStatus.playing => 'aborted',
    },
    'move_count': moveCount,
    'user_count': userCount,
    'agent_count': agentCount,
    'margin': (userCount - agentCount).abs(),
    'actions': [for (final move in _moves) move.toJson()],
    'key_moments': [
      for (final move in _moves)
        for (final moment in move.moments)
          {...moment, 'move_number': move.number, 'actor': move.actor.name},
    ],
    'analysis': analysisJson(),
    'final_state': stateJson(),
  };

  void _updateStatus() {
    final userMoves = _reversiLegalMoves(_board, userDisc);
    final agentMoves = _reversiLegalMoves(_board, agentDisc);
    if (emptyCount > 0 && (userMoves.isNotEmpty || agentMoves.isNotEmpty)) {
      _status = ReversiStatus.playing;
      return;
    }
    _status = userCount > agentCount
        ? ReversiStatus.userWon
        : agentCount > userCount
        ? ReversiStatus.agentWon
        : ReversiStatus.draw;
  }
}

List<int> _initialBoard() {
  final board = List<int>.filled(ReversiEngine.size * ReversiEngine.size, 0);
  board[3 * ReversiEngine.size + 3] = ReversiEngine.agentDisc;
  board[3 * ReversiEngine.size + 4] = ReversiEngine.userDisc;
  board[4 * ReversiEngine.size + 3] = ReversiEngine.userDisc;
  board[4 * ReversiEngine.size + 4] = ReversiEngine.agentDisc;
  return board;
}

int _actorValue(ReversiActor actor) => actor == ReversiActor.user
    ? ReversiEngine.userDisc
    : ReversiEngine.agentDisc;

ReversiActor _opponent(ReversiActor actor) =>
    actor == ReversiActor.user ? ReversiActor.agent : ReversiActor.user;

const _reversiDirections = [
  (-1, -1),
  (-1, 0),
  (-1, 1),
  (0, -1),
  (0, 1),
  (1, -1),
  (1, 0),
  (1, 1),
];

const _reversiCorners = {0, 7, 56, 63};

Map<int, List<int>> _reversiLegalMoves(List<int> board, int actor) {
  final moves = <int, List<int>>{};
  for (var index = 0; index < board.length; index++) {
    if (board[index] != 0) continue;
    final flips = _reversiFlips(board, actor, index);
    if (flips.isNotEmpty) moves[index] = flips;
  }
  return moves;
}

List<int> _reversiFlips(List<int> board, int actor, int index) {
  if (index < 0 || index >= board.length || board[index] != 0) return const [];
  final row = index ~/ ReversiEngine.size;
  final col = index % ReversiEngine.size;
  final result = <int>[];
  for (final (dr, dc) in _reversiDirections) {
    var r = row + dr;
    var c = col + dc;
    final line = <int>[];
    while (r >= 0 &&
        r < ReversiEngine.size &&
        c >= 0 &&
        c < ReversiEngine.size &&
        board[r * ReversiEngine.size + c] == -actor) {
      line.add(r * ReversiEngine.size + c);
      r += dr;
      c += dc;
    }
    if (line.isNotEmpty &&
        r >= 0 &&
        r < ReversiEngine.size &&
        c >= 0 &&
        c < ReversiEngine.size &&
        board[r * ReversiEngine.size + c] == actor) {
      result.addAll(line);
    }
  }
  return result;
}

List<int> _applyReversiMove(
  List<int> board,
  int actor,
  int index,
  List<int> flips,
) {
  final next = List<int>.from(board)..[index] = actor;
  for (final flip in flips) {
    next[flip] = actor;
  }
  return next;
}

int _reversiHash(List<int> board, int actor) {
  var hash = 0x14650FB0739D0383 ^ (actor + 2);
  for (final value in board) {
    hash ^= value + 2;
    hash = (hash * 0x100000001B3) & 0x7FFFFFFFFFFFFFFF;
  }
  return hash;
}

int _cornerCount(List<int> board, int actor) =>
    _reversiCorners.where((index) => board[index] == actor).length;

int _frontierCount(List<int> board, int actor) {
  var count = 0;
  for (var index = 0; index < board.length; index++) {
    if (board[index] != actor) continue;
    final row = index ~/ ReversiEngine.size;
    final col = index % ReversiEngine.size;
    var frontier = false;
    for (final (dr, dc) in _reversiDirections) {
      final r = row + dr;
      final c = col + dc;
      if (r >= 0 &&
          r < ReversiEngine.size &&
          c >= 0 &&
          c < ReversiEngine.size &&
          board[r * ReversiEngine.size + c] == 0) {
        frontier = true;
        break;
      }
    }
    if (frontier) count++;
  }
  return count;
}

const _positionWeights = [
  160,
  -38,
  18,
  8,
  8,
  18,
  -38,
  160,
  -38,
  -72,
  -8,
  -4,
  -4,
  -8,
  -72,
  -38,
  18,
  -8,
  14,
  4,
  4,
  14,
  -8,
  18,
  8,
  -4,
  4,
  2,
  2,
  4,
  -4,
  8,
  8,
  -4,
  4,
  2,
  2,
  4,
  -4,
  8,
  18,
  -8,
  14,
  4,
  4,
  14,
  -8,
  18,
  -38,
  -72,
  -8,
  -4,
  -4,
  -8,
  -72,
  -38,
  160,
  -38,
  18,
  8,
  8,
  18,
  -38,
  160,
];

class _ReversiSearchTimeout implements Exception {}

class _ReversiTtEntry {
  const _ReversiTtEntry(this.depth, this.score, this.flag, this.bestMove);

  final int depth;
  final int score;
  final int flag;
  final int? bestMove;
}

class _ReversiSearcher {
  _ReversiSearcher({required this.timeMs, required this.maxDepth});

  static const _infinity = 100000000;
  static const _exact = 0;
  static const _lower = 1;
  static const _upper = 2;

  final int timeMs;
  final int maxDepth;
  final Stopwatch stopwatch = Stopwatch();
  final Map<int, _ReversiTtEntry> table = {};
  final Map<int, int> history = {};
  final List<List<int>> killers = List.generate(66, (_) => <int>[]);
  int nodes = 0;

  Map<String, dynamic> search(List<int> board) {
    stopwatch.start();
    final rootMoves = _reversiLegalMoves(board, ReversiEngine.agentDisc);
    var bestMove = rootMoves.keys.first;
    var bestScore = -_infinity;
    var completedDepth = 0;
    var completedScores = <int, int>{};
    for (var depth = 1; depth <= maxDepth; depth++) {
      try {
        final scores = <int, int>{};
        var alpha = -_infinity;
        final ordered = _orderMoves(
          board,
          ReversiEngine.agentDisc,
          rootMoves,
          depth,
          table[_reversiHash(board, ReversiEngine.agentDisc)]?.bestMove,
        );
        var depthBest = ordered.first;
        var depthScore = -_infinity;
        for (var i = 0; i < ordered.length; i++) {
          final move = ordered[i];
          final next = _applyReversiMove(
            board,
            ReversiEngine.agentDisc,
            move,
            rootMoves[move]!,
          );
          int score;
          if (i == 0) {
            score = -_negamax(
              next,
              ReversiEngine.userDisc,
              depth - 1,
              -_infinity,
              -alpha,
              false,
              1,
            );
          } else {
            score = -_negamax(
              next,
              ReversiEngine.userDisc,
              depth - 1,
              -alpha - 1,
              -alpha,
              false,
              1,
            );
            if (score > alpha) {
              score = -_negamax(
                next,
                ReversiEngine.userDisc,
                depth - 1,
                -_infinity,
                -alpha,
                false,
                1,
              );
            }
          }
          scores[move] = score;
          if (score > depthScore) {
            depthScore = score;
            depthBest = move;
          }
          alpha = math.max(alpha, score);
          _checkTime();
        }
        bestMove = depthBest;
        bestScore = depthScore;
        completedDepth = depth;
        completedScores = scores;
        table[_reversiHash(board, ReversiEngine.agentDisc)] = _ReversiTtEntry(
          depth,
          bestScore,
          _exact,
          bestMove,
        );
        if (depth >= board.where((value) => value == 0).length) break;
      } on _ReversiSearchTimeout {
        break;
      }
    }
    stopwatch.stop();
    final ranked = completedScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {
      'move': bestMove,
      'score': bestScore,
      'depth': completedDepth,
      'nodes': nodes,
      'elapsed_ms': stopwatch.elapsedMilliseconds,
      'candidates_considered': rootMoves.length,
      'principal_variation': _principalVariation(
        board,
        ReversiEngine.agentDisc,
        completedDepth,
      ),
      'candidate_scores': [
        for (final entry in ranked.take(6))
          {'move': ReversiPoint(entry.key).toJson(), 'score': entry.value},
      ],
      'solved_to_end':
          completedDepth >= board.where((value) => value == 0).length,
    };
  }

  int _negamax(
    List<int> board,
    int actor,
    int depth,
    int alpha,
    int beta,
    bool passed,
    int ply,
  ) {
    nodes++;
    if ((nodes & 127) == 0) _checkTime();
    final moves = _reversiLegalMoves(board, actor);
    if (moves.isEmpty) {
      if (passed) return _terminalScore(board, actor);
      return -_negamax(board, -actor, depth, -beta, -alpha, true, ply + 1);
    }
    if (depth <= 0) return _evaluate(board, actor);

    final key = _reversiHash(board, actor);
    final cached = table[key];
    final alphaOriginal = alpha;
    if (cached != null && cached.depth >= depth) {
      if (cached.flag == _exact) return cached.score;
      if (cached.flag == _lower) alpha = math.max(alpha, cached.score);
      if (cached.flag == _upper && cached.score < beta) beta = cached.score;
      if (alpha >= beta) return cached.score;
    }
    final ordered = _orderMoves(board, actor, moves, ply, cached?.bestMove);
    var best = -_infinity;
    int? bestMove;
    for (var i = 0; i < ordered.length; i++) {
      final move = ordered[i];
      final next = _applyReversiMove(board, actor, move, moves[move]!);
      int score;
      if (i == 0) {
        score = -_negamax(
          next,
          -actor,
          depth - 1,
          -beta,
          -alpha,
          false,
          ply + 1,
        );
      } else {
        score = -_negamax(
          next,
          -actor,
          depth - 1,
          -alpha - 1,
          -alpha,
          false,
          ply + 1,
        );
        if (score > alpha && score < beta) {
          score = -_negamax(
            next,
            -actor,
            depth - 1,
            -beta,
            -alpha,
            false,
            ply + 1,
          );
        }
      }
      if (score > best) {
        best = score;
        bestMove = move;
      }
      alpha = math.max(alpha, score);
      if (alpha >= beta) {
        history[move] = (history[move] ?? 0) + depth * depth;
        final list = killers[math.min(killers.length - 1, ply)];
        if (!list.contains(move)) {
          list.insert(0, move);
          if (list.length > 2) list.removeLast();
        }
        break;
      }
    }
    final flag = best <= alphaOriginal
        ? _upper
        : best >= beta
        ? _lower
        : _exact;
    table[key] = _ReversiTtEntry(depth, best, flag, bestMove);
    return best;
  }

  List<int> _orderMoves(
    List<int> board,
    int actor,
    Map<int, List<int>> moves,
    int ply,
    int? ttMove,
  ) {
    final ordered = moves.keys.toList();
    final killerList = killers[math.min(killers.length - 1, ply)];
    ordered.sort((a, b) {
      int priority(int move) {
        var score = _positionWeights[move] * 30 + (history[move] ?? 0);
        if (move == ttMove) score += 1000000;
        if (_reversiCorners.contains(move)) score += 400000;
        final killerIndex = killerList.indexOf(move);
        if (killerIndex >= 0) score += 80000 - killerIndex * 1000;
        final next = _applyReversiMove(board, actor, move, moves[move]!);
        score -= _reversiLegalMoves(next, -actor).length * 90;
        score += moves[move]!.length * 4;
        return score;
      }

      return priority(b).compareTo(priority(a));
    });
    return ordered;
  }

  List<int> _principalVariation(List<int> board, int actor, int depth) {
    final variation = <int>[];
    var current = List<int>.from(board);
    var side = actor;
    var passed = false;
    for (var ply = 0; ply < depth; ply++) {
      final legal = _reversiLegalMoves(current, side);
      if (legal.isEmpty) {
        if (passed) break;
        passed = true;
        side = -side;
        continue;
      }
      passed = false;
      final move = table[_reversiHash(current, side)]?.bestMove;
      if (move == null || !legal.containsKey(move)) break;
      variation.add(move);
      current = _applyReversiMove(current, side, move, legal[move]!);
      side = -side;
    }
    return variation;
  }

  void _checkTime() {
    if (stopwatch.elapsedMilliseconds >= timeMs) throw _ReversiSearchTimeout();
  }
}

int _evaluate(List<int> board, int actor) {
  var positional = 0;
  var myDiscs = 0;
  var opponentDiscs = 0;
  var empty = 0;
  for (var index = 0; index < board.length; index++) {
    if (board[index] == actor) {
      positional += _positionWeights[index];
      myDiscs++;
    } else if (board[index] == -actor) {
      positional -= _positionWeights[index];
      opponentDiscs++;
    } else {
      empty++;
    }
  }
  final mobility =
      _reversiLegalMoves(board, actor).length -
      _reversiLegalMoves(board, -actor).length;
  final corners = _cornerCount(board, actor) - _cornerCount(board, -actor);
  final frontier = _frontierCount(board, actor) - _frontierCount(board, -actor);
  final stable =
      _stableEdgeCount(board, actor) - _stableEdgeCount(board, -actor);
  final discWeight = empty > 36
      ? 1
      : empty > 16
      ? 4
      : 18;
  final mobilityWeight = empty > 18 ? 22 : 12;
  final parity = empty.isOdd ? 10 : -10;
  return positional * 3 +
      mobility * mobilityWeight +
      corners * 900 +
      stable * 70 -
      frontier * 14 +
      (myDiscs - opponentDiscs) * discWeight +
      parity;
}

int _stableEdgeCount(List<int> board, int actor) {
  final stable = <int>{};
  const corners = [(0, 1, 8), (7, -1, 8), (56, 1, -8), (63, -1, -8)];
  for (final (corner, horizontal, vertical) in corners) {
    if (board[corner] != actor) continue;
    stable.add(corner);
    var value = corner + horizontal;
    while (value >= 0 && value < board.length && board[value] == actor) {
      stable.add(value);
      value += horizontal;
    }
    value = corner + vertical;
    while (value >= 0 && value < board.length && board[value] == actor) {
      stable.add(value);
      value += vertical;
    }
  }
  return stable.length;
}

int _terminalScore(List<int> board, int actor) {
  final my = board.where((value) => value == actor).length;
  final opponent = board.where((value) => value == -actor).length;
  final difference = my - opponent;
  if (difference > 0) return 1000000 + difference * 1000;
  if (difference < 0) return -1000000 + difference * 1000;
  return 0;
}

Map<String, dynamic> _searchReversiMove(Map<String, dynamic> input) {
  final board = List<int>.from(input['board'] as List<dynamic>);
  return _ReversiSearcher(
    timeMs: input['time_ms'] as int,
    maxDepth: input['max_depth'] as int,
  ).search(board);
}
