import 'dart:math' as math;

enum GomokuStone { empty, black, white }

enum GomokuActor { user, agent }

enum GomokuGameStatus { playing, userWon, agentWon, draw }

class GomokuPoint {
  const GomokuPoint(this.row, this.col);

  final int row;
  final int col;

  String get coordinate {
    const letters = 'ABCDEFGHJKLMNOP';
    return '${letters[col]}${row + 1}';
  }

  Map<String, int> toJson() => {'row': row, 'col': col, 'x': col, 'y': row};

  @override
  bool operator ==(Object other) =>
      other is GomokuPoint && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);
}

class GomokuBoardAnalysis {
  const GomokuBoardAnalysis({
    required this.userLongestChain,
    required this.agentLongestChain,
    required this.userOpenThrees,
    required this.agentOpenThrees,
    required this.userOpenFours,
    required this.agentOpenFours,
    required this.userWinningMoves,
    required this.agentWinningMoves,
    required this.boardHash,
  });

  final int userLongestChain;
  final int agentLongestChain;
  final int userOpenThrees;
  final int agentOpenThrees;
  final int userOpenFours;
  final int agentOpenFours;
  final List<GomokuPoint> userWinningMoves;
  final List<GomokuPoint> agentWinningMoves;
  final String boardHash;

  Map<String, dynamic> toJson() => {
    'user_longest_chain': userLongestChain,
    'agent_longest_chain': agentLongestChain,
    'user_open_threes': userOpenThrees,
    'agent_open_threes': agentOpenThrees,
    'user_open_fours': userOpenFours,
    'agent_open_fours': agentOpenFours,
    'user_winning_moves': [
      for (final point in userWinningMoves) point.toJson(),
    ],
    'agent_winning_moves': [
      for (final point in agentWinningMoves) point.toJson(),
    ],
    'board_hash': boardHash,
  };
}

class GomokuAiDecision {
  const GomokuAiDecision({
    required this.point,
    required this.reason,
    required this.score,
    required this.candidatesConsidered,
    this.searchDepth = 0,
    this.nodesSearched = 0,
    this.elapsedMilliseconds = 0,
    this.principalVariation = const [],
  });

  final GomokuPoint point;
  final String reason;
  final int score;
  final int candidatesConsidered;
  final int searchDepth;
  final int nodesSearched;
  final int elapsedMilliseconds;
  final List<GomokuPoint> principalVariation;

  Map<String, dynamic> toJson() => {
    'row': point.row,
    'col': point.col,
    'coordinate': point.coordinate,
    'reason': reason,
    'score': score,
    'candidates_considered': candidatesConsidered,
    'search_depth': searchDepth,
    'nodes_searched': nodesSearched,
    'elapsed_milliseconds': elapsedMilliseconds,
    'principal_variation': [
      for (final move in principalVariation)
        {...move.toJson(), 'coordinate': move.coordinate},
    ],
    'algorithm': 'iterative_deepening_alpha_beta_tss',
  };
}

class GomokuMove {
  const GomokuMove({
    required this.number,
    required this.actor,
    required this.point,
    required this.analysis,
    required this.moment,
    this.decision,
  });

  final int number;
  final GomokuActor actor;
  final GomokuPoint point;
  final GomokuBoardAnalysis analysis;
  final Map<String, dynamic>? moment;
  final GomokuAiDecision? decision;

  GomokuStone get stone =>
      actor == GomokuActor.user ? GomokuStone.black : GomokuStone.white;

  Map<String, dynamic> toJson() => {
    'move_number': number,
    'actor': actor.name,
    'stone': stone.name,
    'row': point.row,
    'col': point.col,
    'x': point.col,
    'y': point.row,
    'coordinate': point.coordinate,
    'analysis': analysis.toJson(),
    if (moment != null) 'moment': moment,
    if (decision != null) 'decision': decision!.toJson(),
  };
}

class GomokuMoveResult {
  const GomokuMoveResult({
    required this.move,
    required this.status,
    required this.winningLine,
  });

  final GomokuMove move;
  final GomokuGameStatus status;
  final List<GomokuPoint> winningLine;
}

class GomokuEngine {
  GomokuEngine({math.Random? random}) : _random = random ?? math.Random();

  static const int boardSize = 15;
  static const List<(int, int)> _directions = [(0, 1), (1, 0), (1, 1), (1, -1)];

  final math.Random _random;
  final Map<String, _SearchEntry> _transposition = {};
  final List<List<GomokuStone>> _board = List.generate(
    boardSize,
    (_) => List.filled(boardSize, GomokuStone.empty),
  );
  final List<GomokuMove> _moves = [];
  GomokuGameStatus _status = GomokuGameStatus.playing;
  List<GomokuPoint> _winningLine = const [];

  List<List<GomokuStone>> get board => _board;
  List<GomokuMove> get moves => List.unmodifiable(_moves);
  GomokuGameStatus get status => _status;
  List<GomokuPoint> get winningLine => List.unmodifiable(_winningLine);
  bool get isFinished => _status != GomokuGameStatus.playing;
  GomokuActor get currentActor =>
      _moves.length.isEven ? GomokuActor.user : GomokuActor.agent;

  GomokuMoveResult place(
    GomokuPoint point,
    GomokuActor actor, {
    GomokuAiDecision? decision,
  }) {
    if (isFinished) throw StateError('game_finished');
    if (!_inside(point)) throw StateError('outside_board');
    if (actor != currentActor) throw StateError('invalid_turn');
    if (_board[point.row][point.col] != GomokuStone.empty) {
      throw StateError('occupied_position');
    }

    final blockedUserWin =
        actor == GomokuActor.agent &&
        immediateWinningMoves(GomokuStone.black).contains(point);
    _board[point.row][point.col] = _stoneFor(actor);
    final line = _winningLineFrom(point, _stoneFor(actor));
    if (line.isNotEmpty) {
      _winningLine = line;
      _status = actor == GomokuActor.user
          ? GomokuGameStatus.userWon
          : GomokuGameStatus.agentWon;
    } else if (_moves.length + 1 == boardSize * boardSize) {
      _status = GomokuGameStatus.draw;
    }

    final analysis = analyze();
    final moment = _momentFor(
      actor: actor,
      blockedUserWin: blockedUserWin,
      analysis: analysis,
    );
    final move = GomokuMove(
      number: _moves.length + 1,
      actor: actor,
      point: point,
      analysis: analysis,
      moment: moment,
      decision: decision,
    );
    _moves.add(move);
    return GomokuMoveResult(
      move: move,
      status: _status,
      winningLine: _winningLine,
    );
  }

  GomokuAiDecision chooseAiMove() {
    if (isFinished) throw StateError('game_finished');
    if (currentActor != GomokuActor.agent) throw StateError('not_agent_turn');

    final candidates = _candidatePoints();
    final stopwatch = Stopwatch()..start();
    final aiWins = immediateWinningMoves(GomokuStone.white);
    if (aiWins.isNotEmpty) {
      stopwatch.stop();
      return GomokuAiDecision(
        point: _closestToCenter(aiWins),
        reason: 'finish_win',
        score: _mateScore,
        candidatesConsidered: candidates.length,
        searchDepth: 1,
        nodesSearched: aiWins.length,
        elapsedMilliseconds: stopwatch.elapsedMilliseconds,
        principalVariation: [_closestToCenter(aiWins)],
      );
    }

    final userWins = immediateWinningMoves(GomokuStone.black);
    if (userWins.isNotEmpty) {
      final point = _bestForcedBlock(userWins);
      stopwatch.stop();
      return GomokuAiDecision(
        point: point,
        reason: 'block_win',
        score: _mateScore - 1,
        candidatesConsidered: candidates.length,
        searchDepth: 1,
        nodesSearched: userWins.length,
        elapsedMilliseconds: stopwatch.elapsedMilliseconds,
        principalVariation: [point],
      );
    }

    final ordered = _orderedCandidates(GomokuStone.white, limit: 14);
    if (ordered.isEmpty) {
      return const GomokuAiDecision(
        point: GomokuPoint(7, 7),
        reason: 'take_center',
        score: 0,
        candidatesConsidered: 1,
      );
    }

    _transposition.clear();
    var completedDepth = 0;
    var nodes = 0;
    var rootResults = <_RootSearchResult>[];
    final maxDepth = _moves.length < 12 ? 3 : 4;
    for (var depth = 1; depth <= maxDepth; depth += 1) {
      final iteration = <_RootSearchResult>[];
      var timedOut = false;
      for (final candidate in ordered) {
        if (stopwatch.elapsedMilliseconds >= _searchBudgetMilliseconds) {
          timedOut = true;
          break;
        }
        _board[candidate.point.row][candidate.point.col] = GomokuStone.white;
        final search = _alphaBeta(
          depth: depth - 1,
          alpha: -_mateScore,
          beta: _mateScore,
          player: GomokuStone.black,
          lastMove: candidate.point,
          lastStone: GomokuStone.white,
          stopwatch: stopwatch,
          ply: 1,
        );
        _board[candidate.point.row][candidate.point.col] = GomokuStone.empty;
        nodes += search.nodes + 1;
        if (search.timedOut) {
          timedOut = true;
          break;
        }
        iteration.add(
          _RootSearchResult(
            candidate: candidate,
            score: search.score,
            principalVariation: [candidate.point, ...search.principalVariation],
          ),
        );
      }
      if (timedOut || iteration.length != ordered.length) break;
      iteration.sort(_compareRootResults);
      rootResults = iteration;
      completedDepth = depth;
    }

    if (rootResults.isEmpty) {
      rootResults = [
        for (final candidate in ordered)
          _RootSearchResult(
            candidate: candidate,
            score: candidate.score,
            principalVariation: [candidate.point],
          ),
      ]..sort(_compareRootResults);
    }
    final selectedResult = _naturalSelection(rootResults);
    final selected = selectedResult.candidate;
    final reason = selected.attack >= 90000
        ? 'build_win'
        : selected.forkDirections >= 2
        ? 'create_fork'
        : selected.defense > selected.attack
        ? 'defend_threat'
        : _moves.length <= 3
        ? 'shape_opening'
        : 'extend_line';
    stopwatch.stop();
    return GomokuAiDecision(
      point: selected.point,
      reason: reason,
      score: selectedResult.score,
      candidatesConsidered: candidates.length,
      searchDepth: math.max(1, completedDepth),
      nodesSearched: nodes,
      elapsedMilliseconds: stopwatch.elapsedMilliseconds,
      principalVariation: selectedResult.principalVariation,
    );
  }

  GomokuBoardAnalysis analyze() {
    final userPattern = _patternSummary(GomokuStone.black);
    final agentPattern = _patternSummary(GomokuStone.white);
    return GomokuBoardAnalysis(
      userLongestChain: userPattern.longest,
      agentLongestChain: agentPattern.longest,
      userOpenThrees: userPattern.openThrees,
      agentOpenThrees: agentPattern.openThrees,
      userOpenFours: userPattern.openFours,
      agentOpenFours: agentPattern.openFours,
      userWinningMoves: immediateWinningMoves(GomokuStone.black),
      agentWinningMoves: immediateWinningMoves(GomokuStone.white),
      boardHash: _boardHash(),
    );
  }

  List<GomokuPoint> immediateWinningMoves(GomokuStone stone) {
    if (stone == GomokuStone.empty) return const [];
    final points = <GomokuPoint>[];
    for (final point in _candidatePoints()) {
      _board[point.row][point.col] = stone;
      final wins = _winningLineFrom(point, stone).isNotEmpty;
      _board[point.row][point.col] = GomokuStone.empty;
      if (wins) points.add(point);
    }
    return points;
  }

  Map<String, dynamic> summaryJson() {
    final finalAnalysis = analyze();
    return {
      'board_size': boardSize,
      'move_count': _moves.length,
      'status': _status.name,
      'moves': [for (final move in _moves) move.toJson()],
      'winning_line': [for (final point in _winningLine) point.toJson()],
      'analysis': finalAnalysis.toJson(),
      'key_moments': [
        for (final move in _moves)
          if (move.moment != null)
            {...move.moment!, 'move_number': move.number},
      ],
    };
  }

  static const int _mateScore = 100000000;
  static const int _searchBudgetMilliseconds = 220;

  _ScoredPoint _scoreCandidate(GomokuPoint point, GomokuStone player) {
    final opponent = _opponent(player);
    final attack = _scorePoint(point, player);
    final defense = _scorePoint(point, opponent);
    final forkDirections = _forkDirections(point, player);
    final center = math.max(0, 14 - _centerDistance(point).round()) * 7;
    final forkBonus = forkDirections >= 2 ? 42000 : forkDirections * 2400;
    return _ScoredPoint(
      point: point,
      attack: attack,
      defense: defense,
      forkDirections: forkDirections,
      score: attack * 12 + defense * 11 + forkBonus + center,
    );
  }

  List<_ScoredPoint> _orderedCandidates(
    GomokuStone player, {
    required int limit,
  }) {
    final candidates = [
      for (final point in _candidatePoints()) _scoreCandidate(point, player),
    ];
    candidates.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return _centerDistance(a.point).compareTo(_centerDistance(b.point));
    });
    final forcing = candidates.where(
      (candidate) =>
          candidate.attack >= 52000 ||
          candidate.defense >= 52000 ||
          candidate.forkDirections >= 2,
    );
    if (forcing.isNotEmpty) return forcing.take(limit).toList();
    return candidates.take(limit).toList();
  }

  _SearchResult _alphaBeta({
    required int depth,
    required int alpha,
    required int beta,
    required GomokuStone player,
    required GomokuPoint lastMove,
    required GomokuStone lastStone,
    required Stopwatch stopwatch,
    required int ply,
  }) {
    if (stopwatch.elapsedMilliseconds >= _searchBudgetMilliseconds) {
      return const _SearchResult.timedOut();
    }
    if (_winningLineFrom(lastMove, lastStone).isNotEmpty) {
      final score = lastStone == GomokuStone.white
          ? _mateScore - ply
          : -_mateScore + ply;
      return _SearchResult(score: score, nodes: 1);
    }
    if (depth <= 0) {
      return _SearchResult(score: _evaluateBoard(), nodes: 1);
    }

    final key = '${_compactBoardHash()}:${player.name}:$depth';
    final cached = _transposition[key];
    if (cached != null && cached.depth >= depth) {
      return _SearchResult(
        score: cached.score,
        nodes: 1,
        principalVariation: cached.principalVariation,
      );
    }

    final ordered = _orderedCandidates(player, limit: depth >= 3 ? 9 : 11);
    if (ordered.isEmpty) return const _SearchResult(score: 0, nodes: 1);
    final maximizing = player == GomokuStone.white;
    var best = maximizing ? -_mateScore : _mateScore;
    var a = alpha;
    var b = beta;
    var nodes = 1;
    var bestLine = <GomokuPoint>[];
    for (final candidate in ordered) {
      _board[candidate.point.row][candidate.point.col] = player;
      final child = _alphaBeta(
        depth: depth - 1,
        alpha: a,
        beta: b,
        player: _opponent(player),
        lastMove: candidate.point,
        lastStone: player,
        stopwatch: stopwatch,
        ply: ply + 1,
      );
      _board[candidate.point.row][candidate.point.col] = GomokuStone.empty;
      nodes += child.nodes;
      if (child.timedOut) {
        return _SearchResult(
          score: best,
          nodes: nodes,
          timedOut: true,
          principalVariation: bestLine,
        );
      }
      final improves = maximizing ? child.score > best : child.score < best;
      if (improves) {
        best = child.score;
        bestLine = [candidate.point, ...child.principalVariation];
      }
      if (maximizing) {
        a = math.max(a, best);
      } else {
        b = math.min(b, best);
      }
      if (a >= b) break;
    }
    _transposition[key] = _SearchEntry(
      depth: depth,
      score: best,
      principalVariation: bestLine,
    );
    return _SearchResult(
      score: best,
      nodes: nodes,
      principalVariation: bestLine,
    );
  }

  int _evaluateBoard() {
    final agent = _patternSummary(GomokuStone.white);
    final user = _patternSummary(GomokuStone.black);
    var score =
        (agent.longest - user.longest) * 160 +
        (agent.openThrees - user.openThrees) * 4200 +
        (agent.openFours - user.openFours) * 28000;
    final agentCandidates = _orderedCandidates(GomokuStone.white, limit: 4);
    final userCandidates = _orderedCandidates(GomokuStone.black, limit: 4);
    if (agentCandidates.isNotEmpty) score += agentCandidates.first.score ~/ 5;
    if (userCandidates.isNotEmpty) score -= userCandidates.first.score ~/ 5;
    return score;
  }

  String _compactBoardHash() {
    final buffer = StringBuffer();
    for (final row in _board) {
      for (final stone in row) {
        buffer.write(stone.index);
      }
    }
    return buffer.toString();
  }

  GomokuPoint _bestForcedBlock(List<GomokuPoint> blocks) {
    final ordered = [
      for (final point in blocks) _scoreCandidate(point, GomokuStone.white),
    ]..sort((a, b) => b.score.compareTo(a.score));
    return ordered.first.point;
  }

  _RootSearchResult _naturalSelection(List<_RootSearchResult> results) {
    if (results.length < 2) return results.first;
    final best = results.first;
    final second = results[1];
    final tolerance = math.max(260, best.score.abs() ~/ 40);
    final nearlyEquivalent = best.score - second.score <= tolerance;
    if (nearlyEquivalent && _random.nextDouble() < 0.18) return second;
    return best;
  }

  int _compareRootResults(_RootSearchResult a, _RootSearchResult b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    return _centerDistance(
      a.candidate.point,
    ).compareTo(_centerDistance(b.candidate.point));
  }

  GomokuStone _opponent(GomokuStone stone) =>
      stone == GomokuStone.white ? GomokuStone.black : GomokuStone.white;

  int _scorePoint(GomokuPoint point, GomokuStone stone) {
    _board[point.row][point.col] = stone;
    var total = 0;
    for (final (dr, dc) in _directions) {
      final pattern = _linePattern(point, stone, dr, dc);
      total += _patternScore(pattern.count, pattern.openEnds);
    }
    _board[point.row][point.col] = GomokuStone.empty;
    return total;
  }

  int _forkDirections(GomokuPoint point, GomokuStone stone) {
    _board[point.row][point.col] = stone;
    var threatening = 0;
    for (final (dr, dc) in _directions) {
      final pattern = _linePattern(point, stone, dr, dc);
      if ((pattern.count >= 3 && pattern.openEnds == 2) || pattern.count >= 4) {
        threatening += 1;
      }
    }
    _board[point.row][point.col] = GomokuStone.empty;
    return threatening;
  }

  int _patternScore(int count, int openEnds) {
    if (count >= 5) return 100000;
    if (count == 4 && openEnds == 2) return 18000;
    if (count == 4 && openEnds == 1) return 5200;
    if (count == 3 && openEnds == 2) return 2400;
    if (count == 3 && openEnds == 1) return 480;
    if (count == 2 && openEnds == 2) return 180;
    if (count == 2 && openEnds == 1) return 42;
    return openEnds == 2 ? 10 : 2;
  }

  _PatternSummary _patternSummary(GomokuStone stone) {
    var longest = 0;
    var openThrees = 0;
    var openFours = 0;
    for (var row = 0; row < boardSize; row += 1) {
      for (var col = 0; col < boardSize; col += 1) {
        if (_board[row][col] != stone) continue;
        for (final (dr, dc) in _directions) {
          final previous = GomokuPoint(row - dr, col - dc);
          if (_inside(previous) &&
              _board[previous.row][previous.col] == stone) {
            continue;
          }
          var count = 0;
          var rr = row;
          var cc = col;
          while (_inside(GomokuPoint(rr, cc)) && _board[rr][cc] == stone) {
            count += 1;
            rr += dr;
            cc += dc;
          }
          var openEnds = 0;
          if (_inside(previous) &&
              _board[previous.row][previous.col] == GomokuStone.empty) {
            openEnds += 1;
          }
          final next = GomokuPoint(rr, cc);
          if (_inside(next) &&
              _board[next.row][next.col] == GomokuStone.empty) {
            openEnds += 1;
          }
          longest = math.max(longest, count);
          if (count == 3 && openEnds == 2) openThrees += 1;
          if (count == 4 && openEnds == 2) openFours += 1;
        }
      }
    }
    return _PatternSummary(
      longest: longest,
      openThrees: openThrees,
      openFours: openFours,
    );
  }

  _LinePattern _linePattern(
    GomokuPoint point,
    GomokuStone stone,
    int dr,
    int dc,
  ) {
    var count = 1;
    var openEnds = 0;
    var row = point.row - dr;
    var col = point.col - dc;
    while (_inside(GomokuPoint(row, col)) && _board[row][col] == stone) {
      count += 1;
      row -= dr;
      col -= dc;
    }
    if (_inside(GomokuPoint(row, col)) &&
        _board[row][col] == GomokuStone.empty) {
      openEnds += 1;
    }
    row = point.row + dr;
    col = point.col + dc;
    while (_inside(GomokuPoint(row, col)) && _board[row][col] == stone) {
      count += 1;
      row += dr;
      col += dc;
    }
    if (_inside(GomokuPoint(row, col)) &&
        _board[row][col] == GomokuStone.empty) {
      openEnds += 1;
    }
    return _LinePattern(count: count, openEnds: openEnds);
  }

  List<GomokuPoint> _winningLineFrom(GomokuPoint point, GomokuStone stone) {
    for (final (dr, dc) in _directions) {
      final points = <GomokuPoint>[point];
      var row = point.row - dr;
      var col = point.col - dc;
      while (_inside(GomokuPoint(row, col)) && _board[row][col] == stone) {
        points.insert(0, GomokuPoint(row, col));
        row -= dr;
        col -= dc;
      }
      row = point.row + dr;
      col = point.col + dc;
      while (_inside(GomokuPoint(row, col)) && _board[row][col] == stone) {
        points.add(GomokuPoint(row, col));
        row += dr;
        col += dc;
      }
      if (points.length >= 5) {
        final index = points.indexOf(point);
        final start = math.min(math.max(index - 4, 0), points.length - 5);
        return points.sublist(start, start + 5);
      }
    }
    return const [];
  }

  List<GomokuPoint> _candidatePoints() {
    final points = <GomokuPoint>{};
    var hasStone = false;
    for (var row = 0; row < boardSize; row += 1) {
      for (var col = 0; col < boardSize; col += 1) {
        if (_board[row][col] == GomokuStone.empty) continue;
        hasStone = true;
        for (var dr = -2; dr <= 2; dr += 1) {
          for (var dc = -2; dc <= 2; dc += 1) {
            final point = GomokuPoint(row + dr, col + dc);
            if (_inside(point) &&
                _board[point.row][point.col] == GomokuStone.empty) {
              points.add(point);
            }
          }
        }
      }
    }
    if (!hasStone) return const [GomokuPoint(7, 7)];
    if (points.isEmpty) {
      for (var row = 0; row < boardSize; row += 1) {
        for (var col = 0; col < boardSize; col += 1) {
          final point = GomokuPoint(row, col);
          if (_inside(point) &&
              _board[point.row][point.col] == GomokuStone.empty) {
            points.add(point);
          }
        }
      }
    }
    return points.toList();
  }

  GomokuPoint _closestToCenter(List<GomokuPoint> points) {
    return points.reduce(
      (a, b) => _centerDistance(a) <= _centerDistance(b) ? a : b,
    );
  }

  double _centerDistance(GomokuPoint point) {
    return math.sqrt(math.pow(point.row - 7, 2) + math.pow(point.col - 7, 2));
  }

  Map<String, dynamic>? _momentFor({
    required GomokuActor actor,
    required bool blockedUserWin,
    required GomokuBoardAnalysis analysis,
  }) {
    if (isFinished) {
      return {
        'type': 'winning_move',
        'actor': actor.name,
        'description': actor == GomokuActor.user ? '用户完成五连' : 'AI 完成五连',
      };
    }
    if (blockedUserWin) {
      return {
        'type': 'blocked_win',
        'actor': actor.name,
        'description': 'AI 挡住了用户下一手即可获胜的位置',
      };
    }
    if (actor == GomokuActor.user && analysis.userWinningMoves.length >= 2) {
      return {
        'type': 'double_threat',
        'actor': actor.name,
        'description': '用户同时制造两个直接胜点',
      };
    }
    if (actor == GomokuActor.user && analysis.userOpenFours > 0) {
      return {
        'type': 'open_four',
        'actor': actor.name,
        'description': '用户形成活四',
      };
    }
    return null;
  }

  String _boardHash() {
    final buffer = StringBuffer();
    for (final row in _board) {
      for (final stone in row) {
        buffer.write(switch (stone) {
          GomokuStone.empty => '.',
          GomokuStone.black => 'B',
          GomokuStone.white => 'W',
        });
      }
    }
    return buffer.toString();
  }

  GomokuStone _stoneFor(GomokuActor actor) =>
      actor == GomokuActor.user ? GomokuStone.black : GomokuStone.white;

  bool _inside(GomokuPoint point) =>
      point.row >= 0 &&
      point.row < boardSize &&
      point.col >= 0 &&
      point.col < boardSize;
}

class _LinePattern {
  const _LinePattern({required this.count, required this.openEnds});

  final int count;
  final int openEnds;
}

class _PatternSummary {
  const _PatternSummary({
    required this.longest,
    required this.openThrees,
    required this.openFours,
  });

  final int longest;
  final int openThrees;
  final int openFours;
}

class _ScoredPoint {
  const _ScoredPoint({
    required this.point,
    required this.attack,
    required this.defense,
    required this.forkDirections,
    required this.score,
  });

  final GomokuPoint point;
  final int attack;
  final int defense;
  final int forkDirections;
  final int score;
}

class _RootSearchResult {
  const _RootSearchResult({
    required this.candidate,
    required this.score,
    required this.principalVariation,
  });

  final _ScoredPoint candidate;
  final int score;
  final List<GomokuPoint> principalVariation;
}

class _SearchResult {
  const _SearchResult({
    required this.score,
    required this.nodes,
    this.timedOut = false,
    this.principalVariation = const [],
  });

  const _SearchResult.timedOut()
    : score = 0,
      nodes = 0,
      timedOut = true,
      principalVariation = const [];

  final int score;
  final int nodes;
  final bool timedOut;
  final List<GomokuPoint> principalVariation;
}

class _SearchEntry {
  const _SearchEntry({
    required this.depth,
    required this.score,
    required this.principalVariation,
  });

  final int depth;
  final int score;
  final List<GomokuPoint> principalVariation;
}
