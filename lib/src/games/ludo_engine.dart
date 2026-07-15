import 'dart:math' as math;

enum LudoActor { user, agent }

enum LudoStatus { playing, userWon, agentWon }

class LudoPiece {
  const LudoPiece({
    required this.actor,
    required this.index,
    required this.progress,
  });
  final LudoActor actor;
  final int index;
  final int progress;
  bool get inYard => progress < 0;
  bool get finished => progress == LudoEngine.finishProgress;

  Map<String, dynamic> toJson() => {
    'actor': actor.name,
    'piece_index': index,
    'progress': progress,
    'zone': inYard
        ? 'yard'
        : finished
        ? 'finished'
        : progress >= 52
        ? 'home_lane'
        : 'track',
  };
}

class LudoRoll {
  const LudoRoll({
    required this.number,
    required this.actor,
    required this.value,
    required this.legalPieces,
    required this.consecutiveSixes,
    required this.forfeited,
    required this.stateHash,
  });
  final int number;
  final LudoActor actor;
  final int value;
  final List<int> legalPieces;
  final int consecutiveSixes;
  final bool forfeited;
  final int stateHash;

  Map<String, dynamic> toJson() => {
    'roll_number': number,
    'actor': actor.name,
    'value': value,
    'legal_pieces': legalPieces,
    'consecutive_sixes': consecutiveSixes,
    'forfeited': forfeited,
    'state_hash': stateHash.toString(),
  };
}

class LudoMove {
  const LudoMove({
    required this.number,
    required this.actor,
    required this.pieceIndex,
    required this.roll,
    required this.fromProgress,
    required this.rolledToProgress,
    required this.toProgress,
    required this.jumpDistance,
    required this.shortcutUsed,
    required this.rollStateBeforeHash,
    required this.captured,
    required this.extraTurn,
    required this.stateBeforeHash,
    required this.stateAfterHash,
    required this.moment,
    this.decision,
  });
  final int number;
  final LudoActor actor;
  final int pieceIndex;
  final int roll;
  final int fromProgress;
  final int rolledToProgress;
  final int toProgress;
  final int jumpDistance;
  final bool shortcutUsed;
  final int rollStateBeforeHash;
  final List<Map<String, dynamic>> captured;
  final bool extraTurn;
  final int stateBeforeHash;
  final int stateAfterHash;
  final Map<String, dynamic>? moment;
  final LudoAiDecision? decision;

  Map<String, dynamic> toJson() => {
    'move_number': number,
    'actor': actor.name,
    'piece': {'actor': actor.name, 'piece_index': pieceIndex},
    'from': {'progress': fromProgress},
    'to': {'progress': toProgress},
    'roll': roll,
    'captured': captured,
    'rolled_to_progress': rolledToProgress,
    'jump_distance': jumpDistance,
    'shortcut_used': shortcutUsed,
    'roll_state_before_hash': rollStateBeforeHash.toString(),
    'extra_turn': extraTurn,
    'state_before_hash': stateBeforeHash.toString(),
    'state_after_hash': stateAfterHash.toString(),
    if (moment != null) 'moment': moment,
    if (decision != null) 'decision': decision!.toJson(),
  };
}

class LudoAiDecision {
  const LudoAiDecision({
    required this.pieceIndex,
    required this.score,
    required this.expectedFutureScore,
    required this.nodes,
    required this.candidatesConsidered,
  });
  final int pieceIndex;
  final double score;
  final double expectedFutureScore;
  final int nodes;
  final int candidatesConsidered;

  Map<String, dynamic> toJson() => {
    'piece_index': pieceIndex,
    'score': score,
    'expected_future_score': expectedFutureScore,
    'nodes_searched': nodes,
    'candidates_considered': candidatesConsidered,
    'algorithm': 'stochastic_expectimax_with_safety_and_capture_model',
  };
}

class LudoMoveResult {
  const LudoMoveResult({required this.move, required this.status});
  final LudoMove move;
  final LudoStatus status;
}

class LudoEngine {
  LudoEngine({int seed = 20260714})
    : _random = math.Random(seed),
      _user = List<int>.filled(pieceCount, -1),
      _agent = List<int>.filled(pieceCount, -1);

  LudoEngine.debug({
    required List<int> user,
    required List<int> agent,
    this.turn = LudoActor.user,
    int seed = 7,
  }) : assert(user.length == pieceCount),
       assert(agent.length == pieceCount),
       _random = math.Random(seed),
       _user = List<int>.from(user),
       _agent = List<int>.from(agent);

  factory LudoEngine.restore(
    Map<String, dynamic> state, {
    int moveCount = 0,
    int rollCount = 0,
    int seed = 20260714,
  }) {
    final user = List<int>.filled(pieceCount, -1);
    final agent = List<int>.filled(pieceCount, -1);
    final pieces = state['pieces'];
    if (pieces is! List) throw const FormatException('missing_pieces');
    for (final raw in pieces.whereType<Map>()) {
      final piece = Map<String, dynamic>.from(raw);
      final index = (piece['piece_index'] as num?)?.round();
      final progress = (piece['progress'] as num?)?.round();
      if (index == null ||
          progress == null ||
          index < 0 ||
          index >= pieceCount) {
        throw const FormatException('invalid_piece');
      }
      if (piece['actor'] == LudoActor.user.name) {
        user[index] = progress;
      } else if (piece['actor'] == LudoActor.agent.name) {
        agent[index] = progress;
      } else {
        throw const FormatException('invalid_actor');
      }
    }
    final engine = LudoEngine.debug(
      user: user,
      agent: agent,
      turn: LudoActor.values.firstWhere(
        (item) => item.name == state['turn'],
        orElse: () => LudoActor.user,
      ),
      seed: seed,
    );
    engine._moveOffset = moveCount;
    engine._rollOffset = rollCount;
    engine._consecutiveSixes =
        (state['consecutive_sixes'] as num?)?.round() ?? 0;
    final pending = state['pending_roll'];
    if (pending is Map) {
      final json = Map<String, dynamic>.from(pending);
      engine.pendingRoll = LudoRoll(
        number: (json['roll_number'] as num?)?.round() ?? rollCount,
        actor: LudoActor.values.firstWhere(
          (item) => item.name == json['actor'],
          orElse: () => engine.turn,
        ),
        value: (json['value'] as num?)?.round() ?? 1,
        legalPieces: (json['legal_pieces'] as List? ?? const [])
            .whereType<num>()
            .map((item) => item.round())
            .toList(growable: false),
        consecutiveSixes: (json['consecutive_sixes'] as num?)?.round() ?? 0,
        forfeited: json['forfeited'] == true,
        stateHash: int.tryParse('${json['state_hash']}') ?? engine.stateHash,
      );
    }
    return engine;
  }

  static const int pieceCount = 4;
  static const int outerTrackLength = 52;
  static const int finishProgress = 57;
  static const int shortcutEntryProgress = 18;
  static const int shortcutExitProgress = 30;
  static const Set<int> safeGlobalCells = {0, 8, 13, 21, 26, 34, 39, 47};

  final math.Random _random;
  final List<int> _user;
  final List<int> _agent;
  final List<LudoMove> _moves = [];
  final List<LudoRoll> _rolls = [];
  int _moveOffset = 0;
  int _rollOffset = 0;
  LudoActor turn = LudoActor.user;
  LudoRoll? pendingRoll;
  int _consecutiveSixes = 0;

  List<LudoMove> get moves => List.unmodifiable(_moves);
  List<LudoRoll> get rolls => List.unmodifiable(_rolls);
  List<LudoPiece> get pieces => [
    for (var i = 0; i < pieceCount; i++)
      LudoPiece(actor: LudoActor.user, index: i, progress: _user[i]),
    for (var i = 0; i < pieceCount; i++)
      LudoPiece(actor: LudoActor.agent, index: i, progress: _agent[i]),
  ];
  int get stateHash => _hashLudo(
    _user,
    _agent,
    turn.index,
    pendingRoll?.value ?? 0,
    _consecutiveSixes,
  );
  LudoStatus get status {
    if (_user.every((value) => value == finishProgress)) {
      return LudoStatus.userWon;
    }
    if (_agent.every((value) => value == finishProgress)) {
      return LudoStatus.agentWon;
    }
    return LudoStatus.playing;
  }

  bool get isFinished => status != LudoStatus.playing;

  LudoRoll roll({int? forcedValue}) {
    if (isFinished) throw StateError('game_finished');
    if (pendingRoll != null) throw StateError('roll_pending');
    final beforeHash = stateHash;
    final value = forcedValue ?? _random.nextInt(6) + 1;
    if (value < 1 || value > 6) throw ArgumentError.value(value, 'forcedValue');
    _consecutiveSixes = value == 6 ? _consecutiveSixes + 1 : 0;
    final forfeited = _consecutiveSixes >= 3;
    final legal = forfeited ? <int>[] : legalPieces(value);
    final record = LudoRoll(
      number: _rollOffset + _rolls.length + 1,
      actor: turn,
      value: value,
      legalPieces: legal,
      consecutiveSixes: _consecutiveSixes,
      forfeited: forfeited,
      stateHash: beforeHash,
    );
    _rolls.add(record);
    if (forfeited || legal.isEmpty) {
      pendingRoll = null;
      _endTurn();
    } else {
      pendingRoll = record;
    }
    return record;
  }

  List<int> legalPieces(int roll) {
    final values = turn == LudoActor.user ? _user : _agent;
    final result = <int>[];
    for (var index = 0; index < values.length; index++) {
      final progress = values[index];
      if (progress == finishProgress) continue;
      if (progress < 0) {
        if (roll == 6) result.add(index);
      } else if (progress + roll <= finishProgress) {
        result.add(index);
      }
    }
    return result;
  }

  LudoAiDecision chooseAgentPiece() {
    final roll = pendingRoll;
    if (turn != LudoActor.agent || roll == null) {
      throw StateError('no_agent_choice');
    }
    final candidates = roll.legalPieces;
    if (candidates.isEmpty) throw StateError('no_legal_move');
    var nodes = 0;
    final scored = <(int, double, double)>[];
    for (final piece in candidates) {
      final simulation = _simulateMove(
        _user,
        _agent,
        LudoActor.agent,
        piece,
        roll.value,
      );
      final immediate = _evaluateLudo(simulation.$1, simulation.$2);
      var expected = 0.0;
      for (var futureRoll = 1; futureRoll <= 6; futureRoll++) {
        final legal = _legalFor(simulation.$2, futureRoll);
        nodes += math.max(1, legal.length);
        if (legal.isEmpty) {
          expected += immediate / 6;
          continue;
        }
        var bestFuture = -double.infinity;
        for (final nextPiece in legal) {
          final next = _simulateMove(
            simulation.$1,
            simulation.$2,
            LudoActor.agent,
            nextPiece,
            futureRoll,
          );
          bestFuture = math.max(bestFuture, _evaluateLudo(next.$1, next.$2));
        }
        expected += bestFuture / 6;
      }
      scored.add((piece, immediate, expected));
    }
    scored.sort(
      (a, b) => (b.$2 * .64 + b.$3 * .36).compareTo(a.$2 * .64 + a.$3 * .36),
    );
    final selected = scored.first;
    return LudoAiDecision(
      pieceIndex: selected.$1,
      score: selected.$2,
      expectedFutureScore: selected.$3,
      nodes: nodes,
      candidatesConsidered: candidates.length,
    );
  }

  LudoMoveResult movePiece(int pieceIndex, {LudoAiDecision? decision}) {
    final roll = pendingRoll;
    if (roll == null) throw StateError('roll_required');
    if (!roll.legalPieces.contains(pieceIndex)) {
      throw StateError('invalid_move');
    }
    final actor = turn;
    final own = actor == LudoActor.user ? _user : _agent;
    final opponent = actor == LudoActor.user ? _agent : _user;
    final beforeHash = stateHash;
    final from = own[pieceIndex];
    final flight = _resolveFlightProgress(from, roll.value);
    final rolledTo = flight.$1;
    final to = flight.$2;
    final jumpDistance = to - rolledTo;
    final shortcutUsed = flight.$3;
    own[pieceIndex] = to;
    final captured = <Map<String, dynamic>>[];
    if (to >= 0 && to < outerTrackLength) {
      final global = globalCell(actor, to);
      if (!safeGlobalCells.contains(global)) {
        for (var index = 0; index < opponent.length; index++) {
          final otherProgress = opponent[index];
          if (otherProgress >= 0 &&
              otherProgress < outerTrackLength &&
              globalCell(_other(actor), otherProgress) == global) {
            captured.add({
              'actor': _other(actor).name,
              'piece_index': index,
              'progress': otherProgress,
            });
            opponent[index] = -1;
          }
        }
      }
    }
    final finished = to == finishProgress;
    final extraTurn = roll.value == 6;
    pendingRoll = null;
    final moment = finished
        ? {'type': 'piece_finished', 'piece_index': pieceIndex}
        : captured.isNotEmpty
        ? {'type': 'capture', 'count': captured.length}
        : shortcutUsed
        ? {
            'type': 'flight_shortcut',
            'piece_index': pieceIndex,
            'jump_distance': jumpDistance,
          }
        : jumpDistance > 0
        ? {
            'type': 'color_jump',
            'piece_index': pieceIndex,
            'jump_distance': jumpDistance,
          }
        : to >= 52
        ? {'type': 'home_stretch', 'piece_index': pieceIndex}
        : null;
    if (!extraTurn) {
      _endTurn();
    } else if (roll.value != 6) {
      _consecutiveSixes = 0;
    }
    final move = LudoMove(
      number: _moveOffset + _moves.length + 1,
      actor: actor,
      pieceIndex: pieceIndex,
      roll: roll.value,
      fromProgress: from,
      rolledToProgress: rolledTo,
      toProgress: to,
      jumpDistance: jumpDistance,
      shortcutUsed: shortcutUsed,
      rollStateBeforeHash: roll.stateHash,
      captured: captured,
      extraTurn: extraTurn,
      stateBeforeHash: beforeHash,
      stateAfterHash: stateHash,
      moment: moment,
      decision: decision,
    );
    _moves.add(move);
    return LudoMoveResult(move: move, status: status);
  }

  static int globalCell(LudoActor actor, int progress) {
    final offset = actor == LudoActor.user ? 0 : 26;
    return (offset + progress) % outerTrackLength;
  }

  Map<String, dynamic> stateJson() => {
    'state_hash': stateHash.toString(),
    'turn': turn.name,
    'status': status.name,
    'pending_roll': pendingRoll?.toJson(),
    'consecutive_sixes': _consecutiveSixes,
    'pieces': [for (final piece in pieces) piece.toJson()],
  };

  Map<String, dynamic> analysisJson() => {
    'state_hash': stateHash.toString(),
    'turn': turn.name,
    'user_finished': _user.where((value) => value == finishProgress).length,
    'agent_finished': _agent.where((value) => value == finishProgress).length,
    'user_in_yard': _user.where((value) => value < 0).length,
    'agent_in_yard': _agent.where((value) => value < 0).length,
    'roll_count': _rollOffset + _rolls.length,
    'move_count': _moveOffset + _moves.length,
  };

  Map<String, dynamic> summaryJson() => {
    'status': status.name,
    'roll_count': _rollOffset + _rolls.length,
    'move_count': _moveOffset + _moves.length,
    'rolls': [for (final roll in _rolls) roll.toJson()],
    'actions': [for (final move in _moves) move.toJson()],
    'key_moments': [
      for (final move in _moves)
        if (move.moment != null) {...move.moment!, 'move_number': move.number},
    ],
    'analysis': analysisJson(),
    'final_state': stateJson(),
  };

  void _endTurn() {
    turn = _other(turn);
    _consecutiveSixes = 0;
  }
}

LudoActor _other(LudoActor actor) =>
    actor == LudoActor.user ? LudoActor.agent : LudoActor.user;

List<int> _legalFor(List<int> pieces, int roll) => [
  for (var index = 0; index < pieces.length; index++)
    if (pieces[index] != LudoEngine.finishProgress &&
        ((pieces[index] < 0 && roll == 6) ||
            (pieces[index] >= 0 &&
                pieces[index] + roll <= LudoEngine.finishProgress)))
      index,
];

(List<int>, List<int>) _simulateMove(
  List<int> user,
  List<int> agent,
  LudoActor actor,
  int pieceIndex,
  int roll,
) {
  final nextUser = List<int>.from(user);
  final nextAgent = List<int>.from(agent);
  final own = actor == LudoActor.user ? nextUser : nextAgent;
  final opponent = actor == LudoActor.user ? nextAgent : nextUser;
  final from = own[pieceIndex];
  final to = _resolveFlightProgress(from, roll).$2;
  own[pieceIndex] = to;
  if (to >= 0 && to < LudoEngine.outerTrackLength) {
    final global = LudoEngine.globalCell(actor, to);
    if (!LudoEngine.safeGlobalCells.contains(global)) {
      for (var index = 0; index < opponent.length; index++) {
        final progress = opponent[index];
        if (progress >= 0 &&
            progress < LudoEngine.outerTrackLength &&
            LudoEngine.globalCell(_other(actor), progress) == global) {
          opponent[index] = -1;
        }
      }
    }
  }
  return (nextUser, nextAgent);
}

(int, int, bool) _resolveFlightProgress(int from, int roll) {
  final rolledTo = from < 0 ? 0 : from + roll;
  if (from < 0 || rolledTo >= LudoEngine.outerTrackLength) {
    return (rolledTo, rolledTo, false);
  }

  var resolved = rolledTo;
  var shortcut = false;
  if (_isOwnColorFlightCell(resolved)) {
    resolved += 4;
  }
  if (resolved == LudoEngine.shortcutEntryProgress) {
    resolved = LudoEngine.shortcutExitProgress;
    shortcut = true;
  }
  return (rolledTo, resolved, shortcut);
}

bool _isOwnColorFlightCell(int progress) =>
    progress >= 2 &&
    progress < LudoEngine.outerTrackLength &&
    progress % 4 == 2 &&
    progress != LudoEngine.shortcutEntryProgress;

double _evaluateLudo(List<int> user, List<int> agent) {
  double side(List<int> own, List<int> opponent, LudoActor actor) {
    var score = 0.0;
    for (final progress in own) {
      if (progress < 0) {
        score -= 10;
      } else if (progress == LudoEngine.finishProgress) {
        score += 180;
      } else {
        score += progress * 2.2;
        if (progress >= 52) score += 36;
        if (progress < 52 &&
            LudoEngine.safeGlobalCells.contains(
              LudoEngine.globalCell(actor, progress),
            )) {
          score += 9;
        }
      }
    }
    for (final progress in opponent) {
      if (progress < 0 || progress >= 52) continue;
      final global = LudoEngine.globalCell(_other(actor), progress);
      for (final ownProgress in own) {
        if (ownProgress < 0 || ownProgress >= 52) continue;
        final distance =
            (global - LudoEngine.globalCell(actor, ownProgress)) % 52;
        if (distance >= 1 && distance <= 6) score += (7 - distance) * 2;
      }
    }
    return score;
  }

  return side(agent, user, LudoActor.agent) - side(user, agent, LudoActor.user);
}

int _hashLudo(
  List<int> user,
  List<int> agent,
  int turn,
  int roll,
  int consecutiveSixes,
) {
  var hash = 0x345678 ^ turn ^ (roll << 8) ^ (consecutiveSixes << 12);
  for (final value in [...user, ...agent]) {
    hash = ((hash * 1000003) ^ (value + 2)) & 0x7FFFFFFF;
  }
  return hash;
}
