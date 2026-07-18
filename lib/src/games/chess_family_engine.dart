import 'dart:math' as math;

import 'package:bishop/bishop.dart' as bishop;
import 'package:flutter/foundation.dart';

enum ChessFamilyKind { chess, xiangqi }

enum ChessFamilyActor { user, agent }

enum ChessFamilyStatus { playing, userWon, agentWon, draw }

class ChessBoardPiece {
  const ChessBoardPiece({
    required this.square,
    required this.file,
    required this.rank,
    required this.symbol,
    required this.actor,
    required this.type,
  });

  final int square;
  final int file;
  final int rank;
  final String symbol;
  final ChessFamilyActor actor;
  final int type;
}

class ChessPositionAnalysis {
  const ChessPositionAnalysis({
    required this.fen,
    required this.boardHash,
    required this.legalMoveCount,
    required this.inCheck,
    required this.materialBalance,
    required this.turn,
  });

  final String fen;
  final int boardHash;
  final int legalMoveCount;
  final bool inCheck;
  final int materialBalance;
  final ChessFamilyActor turn;

  Map<String, dynamic> toJson() => {
    'fen': fen,
    'board_hash': boardHash.toString(),
    'legal_move_count': legalMoveCount,
    'in_check': inCheck,
    'material_balance': materialBalance,
    'turn': turn.name,
  };
}

class ChessFamilyAiDecision {
  const ChessFamilyAiDecision({
    required this.algebraic,
    required this.score,
    required this.depth,
    required this.nodes,
    required this.elapsedMilliseconds,
    required this.principalVariation,
    required this.candidatesConsidered,
  });

  final String algebraic;
  final int score;
  final int depth;
  final int nodes;
  final int elapsedMilliseconds;
  final List<String> principalVariation;
  final int candidatesConsidered;

  factory ChessFamilyAiDecision.fromJson(Map<String, dynamic> json) =>
      ChessFamilyAiDecision(
        algebraic: json['algebraic']! as String,
        score: json['score']! as int,
        depth: json['depth']! as int,
        nodes: json['nodes']! as int,
        elapsedMilliseconds: json['elapsed_milliseconds']! as int,
        principalVariation: List<String>.from(
          json['principal_variation']! as List,
        ),
        candidatesConsidered: json['candidates_considered']! as int,
      );

  Map<String, dynamic> toJson() => {
    'algebraic': algebraic,
    'score': score,
    'search_depth': depth,
    'nodes_searched': nodes,
    'elapsed_milliseconds': elapsedMilliseconds,
    'principal_variation': principalVariation,
    'candidates_considered': candidatesConsidered,
    'algorithm':
        'iterative_deepening_pvs_alpha_beta_quiescence_tt_killer_history',
  };
}

class ChessFamilyMove {
  const ChessFamilyMove({
    required this.number,
    required this.actor,
    required this.from,
    required this.to,
    required this.algebraic,
    required this.notation,
    required this.piece,
    required this.capturedPiece,
    required this.fenBefore,
    required this.analysis,
    required this.moment,
    this.decision,
  });

  final int number;
  final ChessFamilyActor actor;
  final String from;
  final String to;
  final String algebraic;
  final String notation;
  final String piece;
  final String? capturedPiece;
  final String fenBefore;
  final ChessPositionAnalysis analysis;
  final Map<String, dynamic>? moment;
  final ChessFamilyAiDecision? decision;

  Map<String, dynamic> toJson() => {
    'move_number': number,
    'actor': actor.name,
    'from': from,
    'to': to,
    'algebraic': algebraic,
    'notation': notation,
    'piece': piece,
    if (capturedPiece != null) 'captured_piece': capturedPiece,
    'fen_before': fenBefore,
    'analysis': analysis.toJson(),
    if (moment != null) 'moment': moment,
    if (decision != null) 'decision': decision!.toJson(),
  };
}

class ChessFamilyMoveResult {
  const ChessFamilyMoveResult({required this.move, required this.status});

  final ChessFamilyMove move;
  final ChessFamilyStatus status;
}

class ChessFamilyAiConfig {
  const ChessFamilyAiConfig({
    this.searchTimeMs = 390,
    this.maxDepth = 5,
    this.quiescenceDepth = 5,
    this.nearBestProbability = 0.14,
    this.nearBestTolerance = 18,
  });

  factory ChessFamilyAiConfig.defaultsFor(ChessFamilyKind kind) =>
      kind == ChessFamilyKind.chess
      ? const ChessFamilyAiConfig(
          searchTimeMs: 360,
          maxDepth: 5,
          quiescenceDepth: 5,
          nearBestProbability: 0.14,
          nearBestTolerance: 18,
        )
      : const ChessFamilyAiConfig(
          searchTimeMs: 420,
          maxDepth: 4,
          quiescenceDepth: 4,
          nearBestProbability: 0.14,
          nearBestTolerance: 18,
        );

  factory ChessFamilyAiConfig.fromJson(
    Map<String, dynamic> json, {
    required ChessFamilyKind kind,
  }) {
    final defaults = ChessFamilyAiConfig.defaultsFor(kind);
    return ChessFamilyAiConfig(
      searchTimeMs:
          (json['search_time_ms'] as num?)?.round() ?? defaults.searchTimeMs,
      maxDepth: (json['max_depth'] as num?)?.round() ?? defaults.maxDepth,
      quiescenceDepth:
          (json['quiescence_depth'] as num?)?.round() ??
          defaults.quiescenceDepth,
      nearBestProbability:
          (json['near_best_probability'] as num?)?.toDouble() ??
          defaults.nearBestProbability,
      nearBestTolerance:
          (json['near_best_tolerance'] as num?)?.round() ??
          defaults.nearBestTolerance,
    );
  }

  final int searchTimeMs;
  final int maxDepth;
  final int quiescenceDepth;
  final double nearBestProbability;
  final int nearBestTolerance;
}

class ChessFamilyEngine {
  ChessFamilyEngine({
    required this.kind,
    String? fen,
    ChessFamilyAiConfig? aiConfig,
  }) : aiConfig = aiConfig ?? ChessFamilyAiConfig.defaultsFor(kind),
       _game = bishop.Game(variant: _variant(kind), fen: fen);

  final ChessFamilyKind kind;
  final ChessFamilyAiConfig aiConfig;
  final bishop.Game _game;
  final List<ChessFamilyMove> _moves = [];

  static bishop.Variant _variant(ChessFamilyKind kind) =>
      kind == ChessFamilyKind.chess
      ? bishop.Variant.standard()
      : bishop.Xiangqi.xiangqi();

  int get files => _game.size.h;
  int get ranks => _game.size.v;
  bool get isFinished => _game.gameOver;
  int get moveCount => _moves.length;
  bool get isAgentTurn => _game.turn == bishop.Bishop.black;
  String get fen => _game.fen;
  List<ChessFamilyMove> get moves => List.unmodifiable(_moves);
  ChessFamilyStatus get status => _statusFromResult(_game.result);
  int squareAt(int file, int rank) => _game.size.square(file, rank);

  List<ChessBoardPiece> get pieces {
    final result = <ChessBoardPiece>[];
    for (var square = 0; square < _game.size.numIndices; square += 1) {
      if (!_game.size.onBoard(square)) continue;
      final piece = _game.board[square];
      if (piece.isEmpty) continue;
      result.add(
        ChessBoardPiece(
          square: square,
          file: _game.size.file(square),
          rank: _game.size.rank(square),
          symbol: _game.variant.pieceSymbol(piece.type, piece.colour),
          actor: piece.colour == bishop.Bishop.white
              ? ChessFamilyActor.user
              : ChessFamilyActor.agent,
          type: piece.type,
        ),
      );
    }
    return result;
  }

  List<int> legalDestinations(int from) => [
    for (final move in _game.generateLegalMoves())
      if (move.from == from) move.to,
  ];

  ChessFamilyMoveResult play({
    required int from,
    required int to,
    ChessFamilyAiDecision? decision,
  }) {
    if (isFinished) throw StateError('game_finished');
    final actor = isAgentTurn ? ChessFamilyActor.agent : ChessFamilyActor.user;
    final legal = _game
        .generateLegalMoves()
        .where((move) => move.from == from && move.to == to)
        .toList();
    if (legal.isEmpty) throw StateError('invalid_move');
    final move = _preferredPromotion(legal);
    final fenBefore = _game.fen;
    final algebraic = _game.toAlgebraic(move);
    final notation = _game.toSan(move);
    final piece = _game.board[move.from];
    final pieceSymbol = _game.variant.pieceSymbol(piece.type, piece.colour);
    final capturedSymbol = move.capture && move.capturedPiece != null
        ? _game.variant.pieceSymbol(
            move.capturedPiece!.type,
            move.capturedPiece!.colour,
          )
        : null;
    final fromName = _game.size.squareName(move.from);
    final toName = _game.size.squareName(move.to);
    if (!_game.makeMove(move)) throw StateError('invalid_move');
    final analysis = analyze();
    final moment = _momentFor(
      move: move,
      actor: actor,
      capturedPiece: capturedSymbol,
      notation: notation,
    );
    final record = ChessFamilyMove(
      number: _moves.length + 1,
      actor: actor,
      from: fromName,
      to: toName,
      algebraic: algebraic,
      notation: notation,
      piece: pieceSymbol,
      capturedPiece: capturedSymbol,
      fenBefore: fenBefore,
      analysis: analysis,
      moment: moment,
      decision: decision,
    );
    _moves.add(record);
    return ChessFamilyMoveResult(move: record, status: status);
  }

  ChessFamilyMoveResult playAlgebraic(
    String algebraic, {
    ChessFamilyAiDecision? decision,
  }) {
    final move = _game.getMove(algebraic);
    if (move == null) throw StateError('invalid_move');
    return play(from: move.from, to: move.to, decision: decision);
  }

  Future<ChessFamilyAiDecision> chooseAiMove() async {
    if (!isAgentTurn) throw StateError('not_agent_turn');
    if (isFinished) throw StateError('game_finished');
    final json = await compute(_searchChessFamilyMove, {
      'kind': kind.name,
      'fen': _game.fen,
      'budget_ms': aiConfig.searchTimeMs,
      'max_depth': aiConfig.maxDepth,
      'quiescence_depth': aiConfig.quiescenceDepth,
      'near_best_probability': aiConfig.nearBestProbability,
      'near_best_tolerance': aiConfig.nearBestTolerance,
    });
    return ChessFamilyAiDecision.fromJson(json);
  }

  ChessPositionAnalysis analyze() {
    final material = _game.evaluate(bishop.Bishop.white);
    return ChessPositionAnalysis(
      fen: _game.fen,
      boardHash: _game.state.hash,
      legalMoveCount: _game.gameOver ? 0 : _game.generateLegalMoves().length,
      inCheck: _game.gameOver ? false : _game.inCheck,
      materialBalance: material,
      turn: _game.turn == bishop.Bishop.white
          ? ChessFamilyActor.user
          : ChessFamilyActor.agent,
    );
  }

  Map<String, dynamic> summaryJson() => {
    'variant': kind.name,
    'status': status.name,
    'move_count': moveCount,
    'final_fen': _game.fen,
    'result': _game.result?.readable,
    'moves': [for (final move in _moves) move.toJson()],
    'analysis': analyze().toJson(),
    'key_moments': [
      for (final move in _moves)
        if (move.moment != null) {...move.moment!, 'move_number': move.number},
    ],
  };

  bishop.Move _preferredPromotion(List<bishop.Move> moves) {
    if (moves.length == 1) return moves.first;
    return moves.reduce((best, move) {
      final bestValue = best.promoPiece == null
          ? -1
          : _game.variant.pieces[best.promoPiece!].value;
      final value = move.promoPiece == null
          ? -1
          : _game.variant.pieces[move.promoPiece!].value;
      return value > bestValue ? move : best;
    });
  }

  Map<String, dynamic>? _momentFor({
    required bishop.Move move,
    required ChessFamilyActor actor,
    required String? capturedPiece,
    required String notation,
  }) {
    if (_game.gameOver) {
      return {
        'type': _game.drawn ? 'draw' : 'decisive_finish',
        'actor': actor.name,
        'description': _game.result?.readable,
      };
    }
    if (_game.inCheck) {
      return {'type': 'check', 'actor': actor.name, 'notation': notation};
    }
    if (capturedPiece != null) {
      return {
        'type': 'capture',
        'actor': actor.name,
        'captured_piece': capturedPiece,
      };
    }
    if (move.promotion) {
      return {'type': 'promotion', 'actor': actor.name};
    }
    if (move.castling) {
      return {'type': 'castling', 'actor': actor.name};
    }
    return null;
  }

  static ChessFamilyStatus _statusFromResult(bishop.GameResult? result) {
    if (result == null) return ChessFamilyStatus.playing;
    if (result is bishop.DrawnGame) return ChessFamilyStatus.draw;
    if (result is bishop.WonGame) {
      return result.winner == bishop.Bishop.white
          ? ChessFamilyStatus.userWon
          : ChessFamilyStatus.agentWon;
    }
    return ChessFamilyStatus.draw;
  }
}

Map<String, dynamic> _searchChessFamilyMove(Map<String, dynamic> input) {
  final kind = ChessFamilyKind.values.byName(input['kind']! as String);
  final game = bishop.Game(
    variant: kind == ChessFamilyKind.chess
        ? bishop.Variant.standard()
        : bishop.Xiangqi.xiangqi(),
    fen: input['fen']! as String,
  );
  return _ChessFamilySearch(
    game: game,
    kind: kind,
    budgetMilliseconds: input['budget_ms']! as int,
    maxDepth: input['max_depth']! as int,
    quiescenceDepth: input['quiescence_depth']! as int,
    nearBestProbability: (input['near_best_probability']! as num).toDouble(),
    nearBestTolerance: input['near_best_tolerance']! as int,
  ).search();
}

enum _Bound { exact, lower, upper }

class _TranspositionEntry {
  const _TranspositionEntry({
    required this.depth,
    required this.score,
    required this.bound,
    required this.bestMove,
  });

  final int depth;
  final int score;
  final _Bound bound;
  final String? bestMove;
}

class _SearchLine {
  const _SearchLine({
    required this.score,
    required this.nodes,
    this.moves = const [],
    this.timedOut = false,
  });

  final int score;
  final int nodes;
  final List<String> moves;
  final bool timedOut;
}

class _RootLine {
  const _RootLine({required this.move, required this.line});

  final bishop.Move move;
  final _SearchLine line;
}

class _ChessFamilySearch {
  _ChessFamilySearch({
    required this.game,
    required this.kind,
    required this.budgetMilliseconds,
    required this.maxDepth,
    required this.quiescenceDepth,
    required this.nearBestProbability,
    required this.nearBestTolerance,
  });

  static const int _mate = 10000000;
  static const int _infinity = 100000000;

  final bishop.Game game;
  final ChessFamilyKind kind;
  final int budgetMilliseconds;
  final int maxDepth;
  final int quiescenceDepth;
  final double nearBestProbability;
  final int nearBestTolerance;
  final math.Random _random = math.Random();
  final Map<int, _TranspositionEntry> _table = {};
  final Map<int, List<String>> _killers = {};
  final Map<String, int> _history = {};
  final Stopwatch _stopwatch = Stopwatch();
  var _nodes = 0;

  Map<String, dynamic> search() {
    _stopwatch.start();
    final rootMoves = game.generateLegalMoves();
    if (rootMoves.isEmpty) throw StateError('no_legal_move');
    var completedDepth = 0;
    var completed = <_RootLine>[];
    for (var depth = 1; depth <= maxDepth; depth += 1) {
      final iteration = <_RootLine>[];
      final ordered = _orderedMoves(rootMoves, 0, game.state.hash);
      var timedOut = false;
      for (final move in ordered) {
        if (_timedOut) {
          timedOut = true;
          break;
        }
        final algebraic = game.toAlgebraic(move);
        game.makeMove(move, false);
        final child = _negamax(
          depth: depth - 1,
          alpha: -_infinity,
          beta: _infinity,
          ply: 1,
        );
        game.undo();
        if (child.timedOut) {
          timedOut = true;
          break;
        }
        iteration.add(
          _RootLine(
            move: move,
            line: _SearchLine(
              score: -child.score,
              nodes: child.nodes,
              moves: [algebraic, ...child.moves],
            ),
          ),
        );
      }
      if (timedOut || iteration.length != rootMoves.length) break;
      iteration.sort((a, b) => b.line.score.compareTo(a.line.score));
      completed = iteration;
      completedDepth = depth;
    }
    if (completed.isEmpty) {
      final ordered = _orderedMoves(rootMoves, 0, game.state.hash);
      completed = [
        for (final move in ordered)
          _RootLine(
            move: move,
            line: _SearchLine(
              score: _moveOrderingScore(move, 0, null),
              nodes: 1,
              moves: [game.toAlgebraic(move)],
            ),
          ),
      ];
    }
    final chosen = _chooseNatural(completed);
    _stopwatch.stop();
    return {
      'algebraic': game.toAlgebraic(chosen.move),
      'score': chosen.line.score,
      'depth': math.max(1, completedDepth),
      'nodes': math.max(1, _nodes),
      'elapsed_milliseconds': _stopwatch.elapsedMilliseconds,
      'principal_variation': chosen.line.moves,
      'candidates_considered': rootMoves.length,
    };
  }

  _SearchLine _negamax({
    required int depth,
    required int alpha,
    required int beta,
    required int ply,
  }) {
    _nodes += 1;
    if (_timedOut) {
      return const _SearchLine(score: 0, nodes: 1, timedOut: true);
    }
    final result = game.result;
    if (result is bishop.DrawnGame) {
      return const _SearchLine(score: 0, nodes: 1);
    }
    if (result is bishop.WonGame) {
      final score = result.winner == game.turn ? _mate - ply : -_mate + ply;
      return _SearchLine(score: score, nodes: 1);
    }
    if (depth <= 0) {
      return _quiescence(alpha: alpha, beta: beta, ply: ply, depth: 0);
    }

    final originalAlpha = alpha;
    var a = alpha;
    final tt = _table[game.state.hash];
    if (tt != null && tt.depth >= depth) {
      if (tt.bound == _Bound.exact) {
        return _SearchLine(
          score: tt.score,
          nodes: 1,
          moves: tt.bestMove == null ? const [] : [tt.bestMove!],
        );
      }
      if (tt.bound == _Bound.lower) a = math.max(a, tt.score);
      if (tt.bound == _Bound.upper && tt.score <= a) {
        return _SearchLine(score: tt.score, nodes: 1);
      }
      if (a >= beta) return _SearchLine(score: tt.score, nodes: 1);
    }

    final moves = game.generateLegalMoves();
    if (moves.isEmpty) return _SearchLine(score: -_mate + ply, nodes: 1);
    final ordered = _orderedMoves(moves, ply, game.state.hash);
    var best = -_infinity;
    var bestMove = '';
    var bestLine = <String>[];
    var nodes = 1;
    for (var index = 0; index < ordered.length; index += 1) {
      final move = ordered[index];
      final algebraic = game.toAlgebraic(move);
      game.makeMove(move, false);
      _SearchLine child;
      if (index == 0) {
        child = _negamax(
          depth: depth - 1,
          alpha: -beta,
          beta: -a,
          ply: ply + 1,
        );
      } else {
        child = _negamax(
          depth: depth - 1,
          alpha: -a - 1,
          beta: -a,
          ply: ply + 1,
        );
        final score = -child.score;
        if (!child.timedOut && score > a && score < beta) {
          child = _negamax(
            depth: depth - 1,
            alpha: -beta,
            beta: -a,
            ply: ply + 1,
          );
        }
      }
      game.undo();
      nodes += child.nodes;
      if (child.timedOut) {
        return _SearchLine(
          score: best,
          nodes: nodes,
          moves: bestLine,
          timedOut: true,
        );
      }
      final score = -child.score;
      if (score > best) {
        best = score;
        bestMove = algebraic;
        bestLine = [algebraic, ...child.moves];
      }
      if (score > a) a = score;
      if (a >= beta) {
        if (!move.capture) {
          final killers = _killers.putIfAbsent(ply, () => []);
          killers.remove(algebraic);
          killers.insert(0, algebraic);
          if (killers.length > 2) killers.removeLast();
          _history[algebraic] = (_history[algebraic] ?? 0) + depth * depth;
        }
        break;
      }
    }
    final bound = best <= originalAlpha
        ? _Bound.upper
        : best >= beta
        ? _Bound.lower
        : _Bound.exact;
    _table[game.state.hash] = _TranspositionEntry(
      depth: depth,
      score: best,
      bound: bound,
      bestMove: bestMove.isEmpty ? null : bestMove,
    );
    return _SearchLine(score: best, nodes: nodes, moves: bestLine);
  }

  _SearchLine _quiescence({
    required int alpha,
    required int beta,
    required int ply,
    required int depth,
  }) {
    _nodes += 1;
    if (_timedOut) {
      return const _SearchLine(score: 0, nodes: 1, timedOut: true);
    }
    final standPat = _evaluateFor(game.turn);
    if (standPat >= beta) return _SearchLine(score: beta, nodes: 1);
    var a = math.max(alpha, standPat);
    if (depth >= quiescenceDepth) return _SearchLine(score: a, nodes: 1);
    final captures = game.generateLegalMoves().where((move) => move.capture);
    final ordered = _orderedMoves(captures.toList(), ply, game.state.hash);
    var nodes = 1;
    var bestLine = <String>[];
    for (final move in ordered) {
      final algebraic = game.toAlgebraic(move);
      game.makeMove(move, false);
      final child = _quiescence(
        alpha: -beta,
        beta: -a,
        ply: ply + 1,
        depth: depth + 1,
      );
      game.undo();
      nodes += child.nodes;
      if (child.timedOut) {
        return _SearchLine(
          score: a,
          nodes: nodes,
          moves: bestLine,
          timedOut: true,
        );
      }
      final score = -child.score;
      if (score >= beta) return _SearchLine(score: beta, nodes: nodes);
      if (score > a) {
        a = score;
        bestLine = [algebraic, ...child.moves];
      }
    }
    return _SearchLine(score: a, nodes: nodes, moves: bestLine);
  }

  List<bishop.Move> _orderedMoves(List<bishop.Move> moves, int ply, int hash) {
    final ttMove = _table[hash]?.bestMove;
    moves.sort((a, b) {
      return _moveOrderingScore(
        b,
        ply,
        ttMove,
      ).compareTo(_moveOrderingScore(a, ply, ttMove));
    });
    return moves;
  }

  int _moveOrderingScore(bishop.Move move, int ply, String? ttMove) {
    final algebraic = game.toAlgebraic(move);
    if (algebraic == ttMove) return 2000000;
    if (move.capture && move.capturedPiece != null) {
      final victim = game.variant.pieces[move.capturedPiece!.type].value;
      final attacker = game.variant.pieces[game.board[move.from].type].value;
      return 1000000 + victim * 16 - attacker;
    }
    final killers = _killers[ply] ?? const [];
    final killerIndex = killers.indexOf(algebraic);
    if (killerIndex >= 0) return 800000 - killerIndex * 1000;
    return _history[algebraic] ?? 0;
  }

  int _evaluateFor(int player) {
    var score = game.evaluate(player);
    final centreFile = (game.size.h - 1) / 2;
    final centreRank = (game.size.v - 1) / 2;
    for (var square = 0; square < game.size.numIndices; square += 1) {
      if (!game.size.onBoard(square)) continue;
      final piece = game.board[square];
      if (piece.isEmpty) continue;
      final sign = piece.colour == player ? 1 : -1;
      final distance =
          (game.size.file(square) - centreFile).abs() +
          (game.size.rank(square) - centreRank).abs();
      final centreBonus = math.max(0, 8 - (distance * 2).round());
      score += sign * centreBonus;
      final symbol = game.variant.pieceSymbol(piece.type).toUpperCase();
      if (symbol == 'P') {
        final advancement = piece.colour == bishop.Bishop.white
            ? game.size.rank(square)
            : game.size.maxRank - game.size.rank(square);
        score += sign * advancement * (kind == ChessFamilyKind.chess ? 5 : 3);
      }
    }
    if (game.inCheck) {
      score += game.turn == player ? -38 : 38;
    }
    return score;
  }

  _RootLine _chooseNatural(List<_RootLine> lines) {
    if (lines.length < 2) return lines.first;
    final best = lines.first;
    final second = lines[1];
    if (best.line.score - second.line.score <= nearBestTolerance &&
        best.line.score.abs() < _mate ~/ 2 &&
        _random.nextDouble() < nearBestProbability) {
      return second;
    }
    return best;
  }

  bool get _timedOut =>
      (_nodes & 127) == 0 &&
      _stopwatch.elapsedMilliseconds >= budgetMilliseconds;
}
