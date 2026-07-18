import 'dart:collection';
import 'dart:isolate';
import 'dart:math' as math;

enum MinesweeperActor { user, agent }

enum MinesweeperStatus { awaitingFirstMove, playing, completed, failed }

enum MinesweeperActionKind { reveal, flag, unflag }

class MinePoint {
  const MinePoint(this.row, this.column);

  final int row;
  final int column;

  int index(int columns) => row * columns + column;

  Map<String, dynamic> toJson() => {'row': row, 'column': column};

  @override
  bool operator ==(Object other) =>
      other is MinePoint && row == other.row && column == other.column;

  @override
  int get hashCode => Object.hash(row, column);
}

class MinesweeperKeyMoment {
  const MinesweeperKeyMoment(this.type, this.label, this.data);

  final String type;
  final String label;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => {'type': type, 'label': label, ...data};
}

class MinesweeperAction {
  const MinesweeperAction({
    required this.number,
    required this.actor,
    required this.kind,
    required this.point,
    required this.revealed,
    required this.flagged,
    required this.hitMine,
    required this.safeStreak,
    required this.stateBeforeHash,
    required this.stateAfterHash,
    required this.moments,
    this.decision,
  });

  final int number;
  final MinesweeperActor actor;
  final MinesweeperActionKind kind;
  final MinePoint point;
  final List<MinePoint> revealed;
  final bool flagged;
  final bool hitMine;
  final int safeStreak;
  final int stateBeforeHash;
  final int stateAfterHash;
  final List<MinesweeperKeyMoment> moments;
  final MinesweeperAiDecision? decision;

  Map<String, dynamic> toJson() => {
    'action_number': number,
    'actor': actor.name,
    'action': kind.name,
    'at': point.toJson(),
    'revealed_cells': revealed.map((point) => point.toJson()).toList(),
    'revealed_count': revealed.length,
    'flagged': flagged,
    'hit_mine': hitMine,
    'safe_streak': safeStreak,
    'state_before_hash': stateBeforeHash.toString(),
    'state_after_hash': stateAfterHash.toString(),
    'moments': moments.map((moment) => moment.toJson()).toList(),
    if (decision != null) 'decision': decision!.toJson(),
  };
}

class MinesweeperActionResult {
  const MinesweeperActionResult(this.action, this.status);

  final MinesweeperAction action;
  final MinesweeperStatus status;
}

class MinesweeperAiDecision {
  const MinesweeperAiDecision({
    required this.kind,
    required this.point,
    required this.mineProbability,
    required this.reason,
    required this.algorithm,
    required this.constraintCount,
    required this.candidatesConsidered,
    required this.forcedSafeCount,
    required this.forcedMineCount,
    required this.probabilities,
  });

  final MinesweeperActionKind kind;
  final MinePoint point;
  final double mineProbability;
  final String reason;
  final String algorithm;
  final int constraintCount;
  final int candidatesConsidered;
  final int forcedSafeCount;
  final int forcedMineCount;
  final Map<int, double> probabilities;

  Map<String, dynamic> toJson() => {
    'action': kind.name,
    'at': point.toJson(),
    'mine_probability': mineProbability,
    'reason': reason,
    'algorithm': algorithm,
    'constraint_count': constraintCount,
    'candidates_considered': candidatesConsidered,
    'forced_safe_count': forcedSafeCount,
    'forced_mine_count': forcedMineCount,
    'probability_sample': probabilities.entries
        .take(18)
        .map((entry) => {'index': entry.key, 'mine_probability': entry.value})
        .toList(),
  };
}

class MinesweeperGameConfig {
  const MinesweeperGameConfig({
    this.rows = 9,
    this.columns = 9,
    this.mineCount = 12,
    this.requireNoGuess = true,
    this.generationAttempts = 360,
  });

  factory MinesweeperGameConfig.fromJson(Map<String, dynamic> json) {
    final rows = ((json['rows'] as num?)?.round() ?? 9).clamp(6, 20);
    final columns = ((json['columns'] as num?)?.round() ?? 9).clamp(6, 20);
    // The first click clears up to a 3x3 safe zone, so a playable board
    // needs at least that many mine-free cells regardless of the config.
    final maxMines = rows * columns - 10;
    return MinesweeperGameConfig(
      rows: rows,
      columns: columns,
      mineCount: ((json['mine_count'] as num?)?.round() ?? 12).clamp(
        1,
        maxMines,
      ),
      requireNoGuess: json['require_no_guess'] as bool? ?? true,
      generationAttempts: (json['generation_attempts'] as num?)?.round() ?? 360,
    );
  }

  final int rows;
  final int columns;
  final int mineCount;
  final bool requireNoGuess;
  final int generationAttempts;
}

class MinesweeperEngine {
  MinesweeperEngine({
    this.rows = 9,
    this.columns = 9,
    this.mineCount = 12,
    this.requireNoGuess = true,
    this.generationAttempts = 360,
    int seed = 20260715,
  }) : assert(rows >= 6),
       assert(columns >= 6),
       assert(mineCount > 0 && mineCount < rows * columns - 9),
       _seed = seed,
       _adjacentMines = List<int>.filled(rows * columns, 0);

  MinesweeperEngine.withMineLayout({
    required this.rows,
    required this.columns,
    required Set<int> mineIndices,
    Set<int> revealedIndices = const {},
    Set<int> flaggedIndices = const {},
    MinesweeperActor firstActor = MinesweeperActor.user,
    this.requireNoGuess = true,
    this.generationAttempts = 360,
  }) : assert(rows >= 3),
       assert(columns >= 3),
       assert(mineIndices.isNotEmpty),
       mineCount = mineIndices.length,
       _seed = 0,
       _adjacentMines = List<int>.filled(rows * columns, 0) {
    if ({
      ...mineIndices,
      ...revealedIndices,
      ...flaggedIndices,
    }.any((index) => index < 0 || index >= rows * columns)) {
      throw ArgumentError.value(mineIndices, 'mineIndices');
    }
    if (revealedIndices.any(mineIndices.contains) ||
        revealedIndices.any(flaggedIndices.contains)) {
      throw ArgumentError('Revealed cells cannot be mines or flags.');
    }
    turn = firstActor;
    status = MinesweeperStatus.playing;
    _installBoard(mineIndices, _buildNumbers(mineIndices));
    _revealed.addAll(revealedIndices);
    _flags.addAll(flaggedIndices);
  }

  final int rows;
  final int columns;
  final int mineCount;
  final bool requireNoGuess;
  final int generationAttempts;
  final int _seed;
  final Set<int> _mines = {};
  final Set<int> _revealed = {};
  final Set<int> _flags = {};
  final List<int> _adjacentMines;
  final List<MinesweeperAction> actions = [];
  final List<MinesweeperKeyMoment> keyMoments = [];

  MinesweeperActor turn = MinesweeperActor.user;
  int get actionCount => actions.length;
  MinesweeperStatus status = MinesweeperStatus.awaitingFirstMove;
  int safeStreak = 0;
  int deductions = 0;
  int guesses = 0;
  int largestReveal = 0;
  int generatedAttempts = 0;
  bool noGuessVerified = false;
  int? explodedIndex;

  int get cellCount => rows * columns;
  int get revealedCount => _revealed.length;
  int get flagCount => _flags.length;
  int get safeCellCount => cellCount - mineCount;
  int get safeRemaining => math.max(0, safeCellCount - revealedCount);
  int get estimatedMinesRemaining => math.max(0, mineCount - flagCount);
  bool get isFinished =>
      status == MinesweeperStatus.completed ||
      status == MinesweeperStatus.failed;
  bool get isGenerated => _mines.isNotEmpty;

  Set<int> get revealedIndices => Set.unmodifiable(_revealed);
  Set<int> get flaggedIndices => Set.unmodifiable(_flags);

  bool isRevealed(int index) => _revealed.contains(index);
  bool isFlagged(int index) => _flags.contains(index);
  bool isMine(int index) => isFinished && _mines.contains(index);
  int adjacentMineCount(int index) => _adjacentMines[index];
  MinePoint pointFor(int index) => MinePoint(index ~/ columns, index % columns);

  int get stateHash {
    var hash = 0x811C9DC5;
    for (var index = 0; index < cellCount; index += 1) {
      var value = 0;
      if (_revealed.contains(index)) value |= 1;
      if (_flags.contains(index)) value |= 2;
      if (_mines.contains(index)) value |= 4;
      if (index == explodedIndex) value |= 8;
      hash = ((hash ^ (value + index * 17)) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  bool canReveal(int index) =>
      !isFinished &&
      turn == MinesweeperActor.user &&
      index >= 0 &&
      index < cellCount &&
      !_revealed.contains(index) &&
      !_flags.contains(index);

  MinesweeperActionResult reveal(
    int index, {
    MinesweeperActor? actor,
    MinesweeperAiDecision? decision,
  }) {
    final activeActor = actor ?? turn;
    _validateAction(index, activeActor, requireCovered: true);
    if (_flags.contains(index)) {
      throw StateError('A flagged cell cannot be revealed.');
    }
    if (!isGenerated) _generateBoard(index);
    final beforeHash = stateHash;
    final revealed = <int>[];
    final hitMine = _mines.contains(index);
    final moments = <MinesweeperKeyMoment>[];
    if (hitMine) {
      explodedIndex = index;
      _revealed.add(index);
      revealed.add(index);
      safeStreak = 0;
      status = MinesweeperStatus.failed;
      moments.add(
        MinesweeperKeyMoment('mine_triggered', '踩到了雷', {
          'at': pointFor(index).toJson(),
          'safe_cells_remaining': safeRemaining,
        }),
      );
    } else {
      _floodReveal(index, revealed);
      safeStreak += revealed.length;
      largestReveal = math.max(largestReveal, revealed.length);
      final probability = decision?.mineProbability;
      if (decision != null && probability == 0) {
        deductions += 1;
      } else if (probability != null && probability > 0) {
        guesses += 1;
      }
      if (revealed.length >= 8) {
        moments.add(
          MinesweeperKeyMoment('zero_expansion', '一下打开了一大片', {
            'revealed_count': revealed.length,
            'origin': pointFor(index).toJson(),
          }),
        );
      }
      if (decision != null && decision.mineProbability == 0) {
        moments.add(
          MinesweeperKeyMoment('forced_deduction', '通过数字约束找到了安全格', {
            'constraint_count': decision.constraintCount,
            'at': pointFor(index).toJson(),
          }),
        );
      } else if (decision != null && decision.mineProbability > 0) {
        moments.add(
          MinesweeperKeyMoment('calculated_risk', '在没有必然解时选了最低风险', {
            'mine_probability': decision.mineProbability,
            'candidates_considered': decision.candidatesConsidered,
          }),
        );
      }
      if (safeRemaining == 0) {
        status = MinesweeperStatus.completed;
        _flags.addAll(_mines);
      } else {
        status = MinesweeperStatus.playing;
        if (safeRemaining <= 8) {
          moments.add(
            MinesweeperKeyMoment('near_clear', '已经接近清场', {
              'safe_cells_remaining': safeRemaining,
            }),
          );
        }
      }
    }
    final action = _recordAction(
      actor: activeActor,
      kind: MinesweeperActionKind.reveal,
      index: index,
      revealed: revealed,
      flagged: false,
      hitMine: hitMine,
      beforeHash: beforeHash,
      moments: moments,
      decision: decision,
    );
    return MinesweeperActionResult(action, status);
  }

  MinesweeperActionResult toggleFlag(
    int index, {
    MinesweeperActor? actor,
    MinesweeperAiDecision? decision,
  }) {
    final activeActor = actor ?? turn;
    _validateAction(index, activeActor, requireCovered: true);
    if (_revealed.contains(index)) {
      throw StateError('A revealed cell cannot be flagged.');
    }
    final beforeHash = stateHash;
    final wasFlagged = _flags.remove(index);
    if (!wasFlagged) {
      if (_flags.length >= mineCount) {
        throw StateError('All available flags are already placed.');
      }
      _flags.add(index);
    }
    if (status == MinesweeperStatus.awaitingFirstMove) {
      status = MinesweeperStatus.playing;
    }
    final moments = <MinesweeperKeyMoment>[];
    if (!wasFlagged && decision?.mineProbability == 1) {
      deductions += 1;
      moments.add(
        MinesweeperKeyMoment('forced_deduction', '锁定了一颗必然是雷的格子', {
          'at': pointFor(index).toJson(),
          'constraint_count': decision!.constraintCount,
        }),
      );
    }
    final action = _recordAction(
      actor: activeActor,
      kind: wasFlagged
          ? MinesweeperActionKind.unflag
          : MinesweeperActionKind.flag,
      index: index,
      revealed: const [],
      flagged: !wasFlagged,
      hitMine: false,
      beforeHash: beforeHash,
      moments: moments,
      decision: decision,
    );
    return MinesweeperActionResult(action, status);
  }

  MinesweeperAction _recordAction({
    required MinesweeperActor actor,
    required MinesweeperActionKind kind,
    required int index,
    required List<int> revealed,
    required bool flagged,
    required bool hitMine,
    required int beforeHash,
    required List<MinesweeperKeyMoment> moments,
    required MinesweeperAiDecision? decision,
  }) {
    if (!isFinished) {
      turn = actor == MinesweeperActor.user
          ? MinesweeperActor.agent
          : MinesweeperActor.user;
    }
    final action = MinesweeperAction(
      number: actions.length + 1,
      actor: actor,
      kind: kind,
      point: pointFor(index),
      revealed: revealed.map(pointFor).toList(growable: false),
      flagged: flagged,
      hitMine: hitMine,
      safeStreak: safeStreak,
      stateBeforeHash: beforeHash,
      stateAfterHash: stateHash,
      moments: moments,
      decision: decision,
    );
    actions.add(action);
    keyMoments.addAll(moments);
    return action;
  }

  void _validateAction(
    int index,
    MinesweeperActor actor, {
    required bool requireCovered,
  }) {
    if (isFinished) throw StateError('The game has already ended.');
    if (actor != turn) throw StateError('It is not ${actor.name} turn.');
    if (index < 0 || index >= cellCount) {
      throw RangeError.index(index, _adjacentMines, 'index');
    }
    if (requireCovered && _revealed.contains(index)) {
      throw StateError('The cell is already revealed.');
    }
  }

  Future<MinesweeperAiDecision> chooseAiAction() async {
    if (isFinished || turn != MinesweeperActor.agent) {
      throw StateError('The agent cannot act now.');
    }
    if (!isGenerated) {
      final center = (rows ~/ 2) * columns + columns ~/ 2;
      return MinesweeperAiDecision(
        kind: MinesweeperActionKind.reveal,
        point: pointFor(center),
        mineProbability: 0,
        reason: '第一步选择中心区域，保证安全并尽量打开更大的信息面。',
        algorithm: 'first_move_safe_center',
        constraintCount: 0,
        candidatesConsidered: cellCount,
        forcedSafeCount: 1,
        forcedMineCount: 0,
        probabilities: {center: 0},
      );
    }
    final snapshot = _solverSnapshot();
    final raw = await Isolate.run(() => _solveMinesweeper(snapshot));
    final point = pointFor(raw.index);
    return MinesweeperAiDecision(
      kind: raw.kind,
      point: point,
      mineProbability: raw.probability,
      reason: raw.reason,
      algorithm: raw.algorithm,
      constraintCount: raw.constraintCount,
      candidatesConsidered: raw.candidatesConsidered,
      forcedSafeCount: raw.forcedSafeCount,
      forcedMineCount: raw.forcedMineCount,
      probabilities: raw.probabilities,
    );
  }

  _MineSolverSnapshot _solverSnapshot() => _MineSolverSnapshot(
    rows: rows,
    columns: columns,
    mineCount: mineCount,
    revealed: _revealed.toList(),
    flags: _flags.toList(),
    numbers: [
      for (var index = 0; index < cellCount; index += 1)
        _revealed.contains(index) ? _adjacentMines[index] : -1,
    ],
  );

  Map<String, dynamic> stateJson({bool revealMines = false}) => {
    'rows': rows,
    'columns': columns,
    'mine_count': mineCount,
    'status': status.name,
    'turn': turn.name,
    'action_count': actionCount,
    'revealed_count': revealedCount,
    'flag_count': flagCount,
    'safe_remaining': safeRemaining,
    'safe_streak': safeStreak,
    'cells': [
      for (var index = 0; index < cellCount; index += 1)
        _cellJson(index, revealMines: revealMines || isFinished),
    ],
    'state_hash': stateHash.toString(),
  };

  Map<String, dynamic> _cellJson(int index, {required bool revealMines}) {
    final revealed = _revealed.contains(index);
    final flagged = _flags.contains(index);
    final mine = _mines.contains(index);
    return {
      'index': index,
      ...pointFor(index).toJson(),
      'state': index == explodedIndex
          ? 'exploded'
          : revealed && mine
          ? 'mine'
          : revealed
          ? 'revealed'
          : flagged
          ? 'flagged'
          : revealMines && mine
          ? 'mine'
          : 'covered',
      if (revealed && !mine) 'adjacent_mines': _adjacentMines[index],
      if (revealMines) 'is_mine': mine,
    };
  }

  Map<String, dynamic> analysisJson() {
    final analysis = isGenerated
        ? _analyzeMinesweeper(_solverSnapshot())
        : const _MineSolverAnalysis.empty();
    return {
      'safe_cells_remaining': safeRemaining,
      'estimated_mines_remaining': estimatedMinesRemaining,
      'constraint_count': analysis.constraintCount,
      'frontier_size': analysis.frontierSize,
      'forced_safe_count': analysis.safe.length,
      'forced_mine_count': analysis.mines.length,
      'lowest_mine_probability': analysis.probabilities.values.isEmpty
          ? null
          : analysis.probabilities.values.reduce(math.min),
      'deductions': deductions,
      'guesses': guesses,
      'largest_reveal': largestReveal,
      'generation_attempts': generatedAttempts,
      'solver': 'constraint_propagation_subset_bounded_component_probability',
      'no_guess_verified': noGuessVerified,
    };
  }

  Map<String, dynamic> summaryJson() => {
    'game_key': 'minesweeper',
    'rules': '9x9_12_mines_first_move_safe_bounded_no_guess_generation',
    'cooperative': true,
    'status': status.name,
    'action_count': actionCount,
    'revealed_count': revealedCount,
    'safe_cell_count': safeCellCount,
    'flag_count': flagCount,
    'safe_streak': safeStreak,
    'deductions': deductions,
    'guesses': guesses,
    'largest_reveal': largestReveal,
    'generation_attempts': generatedAttempts,
    'no_guess_verified': noGuessVerified,
    'user_action_count': actions
        .where((action) => action.actor == MinesweeperActor.user)
        .length,
    'agent_action_count': actions
        .where((action) => action.actor == MinesweeperActor.agent)
        .length,
    'key_moments': keyMoments.map((moment) => moment.toJson()).toList(),
    'actions': actions.map((action) => action.toJson()).toList(),
    'analysis': analysisJson(),
    'final_state': stateJson(revealMines: true),
  };

  void _generateBoard(int firstIndex) {
    final safeZone = {firstIndex, ..._neighbors(firstIndex)};
    final candidates = [
      for (var index = 0; index < cellCount; index += 1)
        if (!safeZone.contains(index)) index,
    ];
    Set<int>? fallback;
    for (var attempt = 0; attempt < generationAttempts; attempt += 1) {
      final random = math.Random(_seed + attempt * 7919 + firstIndex * 97);
      final shuffled = List<int>.of(candidates)..shuffle(random);
      final mines = shuffled.take(mineCount).toSet();
      fallback ??= mines;
      final numbers = _buildNumbers(mines);
      generatedAttempts = attempt + 1;
      if (!requireNoGuess) {
        noGuessVerified = false;
        _installBoard(mines, numbers);
        return;
      }
      if (_isNoGuessSolvable(firstIndex, mines, numbers)) {
        noGuessVerified = true;
        _installBoard(mines, numbers);
        return;
      }
    }
    noGuessVerified = false;
    _installBoard(fallback!, _buildNumbers(fallback));
  }

  void _installBoard(Set<int> mines, List<int> numbers) {
    _mines
      ..clear()
      ..addAll(mines);
    for (var index = 0; index < cellCount; index += 1) {
      _adjacentMines[index] = numbers[index];
    }
  }

  List<int> _buildNumbers(Set<int> mines) => [
    for (var index = 0; index < cellCount; index += 1)
      _neighbors(index).where(mines.contains).length,
  ];

  bool _isNoGuessSolvable(int firstIndex, Set<int> mines, List<int> numbers) {
    final revealed = <int>{};
    final flags = <int>{};
    _simulateFlood(firstIndex, mines, numbers, revealed);
    while (revealed.length < cellCount - mineCount) {
      final snapshot = _MineSolverSnapshot(
        rows: rows,
        columns: columns,
        mineCount: mineCount,
        revealed: revealed.toList(),
        flags: flags.toList(),
        numbers: [
          for (var index = 0; index < cellCount; index += 1)
            revealed.contains(index) ? numbers[index] : -1,
        ],
      );
      final analysis = _analyzeMinesweeper(
        snapshot,
        includeProbabilities: false,
      );
      var progressed = false;
      for (final mine in analysis.mines) {
        if (mines.contains(mine) && flags.add(mine)) progressed = true;
      }
      for (final safe in analysis.safe) {
        if (!mines.contains(safe) && !revealed.contains(safe)) {
          _simulateFlood(safe, mines, numbers, revealed);
          progressed = true;
        }
      }
      if (!progressed) return false;
    }
    return true;
  }

  void _simulateFlood(
    int origin,
    Set<int> mines,
    List<int> numbers,
    Set<int> revealed,
  ) {
    final queue = Queue<int>()..add(origin);
    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (mines.contains(current) || !revealed.add(current)) continue;
      if (numbers[current] == 0) {
        for (final neighbor in _neighbors(current)) {
          if (!revealed.contains(neighbor) && !mines.contains(neighbor)) {
            queue.add(neighbor);
          }
        }
      }
    }
  }

  void _floodReveal(int origin, List<int> order) {
    final queue = Queue<int>()..add(origin);
    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (_mines.contains(current) ||
          _flags.contains(current) ||
          !_revealed.add(current)) {
        continue;
      }
      order.add(current);
      if (_adjacentMines[current] == 0) {
        for (final neighbor in _neighbors(current)) {
          if (!_revealed.contains(neighbor) &&
              !_flags.contains(neighbor) &&
              !_mines.contains(neighbor)) {
            queue.add(neighbor);
          }
        }
      }
    }
  }

  Iterable<int> _neighbors(int index) sync* {
    final row = index ~/ columns;
    final column = index % columns;
    for (var dr = -1; dr <= 1; dr += 1) {
      for (var dc = -1; dc <= 1; dc += 1) {
        if (dr == 0 && dc == 0) continue;
        final nextRow = row + dr;
        final nextColumn = column + dc;
        if (nextRow >= 0 &&
            nextRow < rows &&
            nextColumn >= 0 &&
            nextColumn < columns) {
          yield nextRow * columns + nextColumn;
        }
      }
    }
  }
}

class _MineConstraint {
  const _MineConstraint(this.cells, this.required);

  final Set<int> cells;
  final int required;
}

class _MineSolverSnapshot {
  const _MineSolverSnapshot({
    required this.rows,
    required this.columns,
    required this.mineCount,
    required this.revealed,
    required this.flags,
    required this.numbers,
  });

  final int rows;
  final int columns;
  final int mineCount;
  final List<int> revealed;
  final List<int> flags;
  final List<int> numbers;
}

class _MineSolverAnalysis {
  const _MineSolverAnalysis({
    required this.safe,
    required this.mines,
    required this.probabilities,
    required this.constraintCount,
    required this.frontierSize,
  });

  const _MineSolverAnalysis.empty()
    : safe = const {},
      mines = const {},
      probabilities = const {},
      constraintCount = 0,
      frontierSize = 0;

  final Set<int> safe;
  final Set<int> mines;
  final Map<int, double> probabilities;
  final int constraintCount;
  final int frontierSize;
}

class _MineSolverResult {
  const _MineSolverResult({
    required this.kind,
    required this.index,
    required this.probability,
    required this.reason,
    required this.algorithm,
    required this.constraintCount,
    required this.candidatesConsidered,
    required this.forcedSafeCount,
    required this.forcedMineCount,
    required this.probabilities,
  });

  final MinesweeperActionKind kind;
  final int index;
  final double probability;
  final String reason;
  final String algorithm;
  final int constraintCount;
  final int candidatesConsidered;
  final int forcedSafeCount;
  final int forcedMineCount;
  final Map<int, double> probabilities;
}

_MineSolverResult _solveMinesweeper(_MineSolverSnapshot snapshot) {
  final analysis = _analyzeMinesweeper(snapshot);
  final flags = snapshot.flags.toSet();
  final covered = <int>[
    for (var index = 0; index < snapshot.rows * snapshot.columns; index += 1)
      if (snapshot.numbers[index] < 0 && !flags.contains(index)) index,
  ];
  if (analysis.mines.isNotEmpty) {
    final index = analysis.mines.first;
    return _MineSolverResult(
      kind: MinesweeperActionKind.flag,
      index: index,
      probability: 1,
      reason: '相邻数字的剩余雷数正好等于未知格数量，这一格可以确定是雷。',
      algorithm: 'constraint_propagation_subset_bounded_component_probability',
      constraintCount: analysis.constraintCount,
      candidatesConsidered: covered.length,
      forcedSafeCount: analysis.safe.length,
      forcedMineCount: analysis.mines.length,
      probabilities: analysis.probabilities,
    );
  }
  if (analysis.safe.isNotEmpty) {
    final index = analysis.safe.reduce((a, b) {
      final aInformation = _coveredNeighborCount(snapshot, a);
      final bInformation = _coveredNeighborCount(snapshot, b);
      return bInformation > aInformation ? b : a;
    });
    return _MineSolverResult(
      kind: MinesweeperActionKind.reveal,
      index: index,
      probability: 0,
      reason: '由已揭示数字的约束可以严格推出这格安全，并优先选择能带来更多信息的位置。',
      algorithm: 'constraint_propagation_subset_bounded_component_probability',
      constraintCount: analysis.constraintCount,
      candidatesConsidered: covered.length,
      forcedSafeCount: analysis.safe.length,
      forcedMineCount: analysis.mines.length,
      probabilities: analysis.probabilities,
    );
  }
  final probabilities = analysis.probabilities;
  final fallbackProbability = covered.isEmpty
      ? 1.0
      : ((snapshot.mineCount - flags.length) / covered.length).clamp(0.0, 1.0);
  final index = covered.reduce((a, b) {
    final aRisk = probabilities[a] ?? fallbackProbability;
    final bRisk = probabilities[b] ?? fallbackProbability;
    if ((aRisk - bRisk).abs() > 0.000001) return bRisk < aRisk ? b : a;
    return _coveredNeighborCount(snapshot, b) >
            _coveredNeighborCount(snapshot, a)
        ? b
        : a;
  });
  return _MineSolverResult(
    kind: MinesweeperActionKind.reveal,
    index: index,
    probability: probabilities[index] ?? fallbackProbability,
    reason: '当前没有必然安全格，枚举前沿的可行布雷组合后选择了风险最低、信息量更高的位置。',
    algorithm: 'constraint_propagation_subset_bounded_component_probability',
    constraintCount: analysis.constraintCount,
    candidatesConsidered: covered.length,
    forcedSafeCount: 0,
    forcedMineCount: 0,
    probabilities: probabilities,
  );
}

int _coveredNeighborCount(_MineSolverSnapshot snapshot, int index) {
  final row = index ~/ snapshot.columns;
  final column = index % snapshot.columns;
  var count = 0;
  for (var dr = -1; dr <= 1; dr += 1) {
    for (var dc = -1; dc <= 1; dc += 1) {
      if (dr == 0 && dc == 0) continue;
      final r = row + dr;
      final c = column + dc;
      if (r >= 0 &&
          r < snapshot.rows &&
          c >= 0 &&
          c < snapshot.columns &&
          snapshot.numbers[r * snapshot.columns + c] < 0) {
        count += 1;
      }
    }
  }
  return count;
}

_MineSolverAnalysis _analyzeMinesweeper(
  _MineSolverSnapshot snapshot, {
  bool includeProbabilities = true,
}) {
  final revealed = snapshot.revealed.toSet();
  final flags = snapshot.flags.toSet();
  final constraints = <_MineConstraint>[];
  final allCovered = <int>{};
  for (var index = 0; index < snapshot.rows * snapshot.columns; index += 1) {
    if (!revealed.contains(index) && !flags.contains(index)) {
      allCovered.add(index);
    }
    if (!revealed.contains(index) || snapshot.numbers[index] <= 0) continue;
    final neighbors = _snapshotNeighbors(snapshot, index);
    final unknown = neighbors
        .where(
          (neighbor) =>
              !revealed.contains(neighbor) && !flags.contains(neighbor),
        )
        .toSet();
    final flaggedCount = neighbors.where(flags.contains).length;
    final required = snapshot.numbers[index] - flaggedCount;
    if (unknown.isNotEmpty && required >= 0 && required <= unknown.length) {
      constraints.add(_MineConstraint(unknown, required));
    }
  }
  final safe = <int>{};
  final mines = <int>{};
  var changed = true;
  while (changed) {
    changed = false;
    final normalized = <_MineConstraint>[];
    for (final constraint in constraints) {
      final cells = constraint.cells.difference(safe).difference(mines);
      final required =
          constraint.required - constraint.cells.intersection(mines).length;
      if (cells.isEmpty) continue;
      normalized.add(_MineConstraint(cells, required));
      if (required == 0) {
        if (safe.addAllAndReport(cells)) changed = true;
      } else if (required == cells.length) {
        if (mines.addAllAndReport(cells)) changed = true;
      }
    }
    for (var i = 0; i < normalized.length; i += 1) {
      for (var j = 0; j < normalized.length; j += 1) {
        if (i == j) continue;
        final smaller = normalized[i];
        final larger = normalized[j];
        if (smaller.cells.length >= larger.cells.length ||
            !larger.cells.containsAll(smaller.cells)) {
          continue;
        }
        final difference = larger.cells.difference(smaller.cells);
        final required = larger.required - smaller.required;
        if (difference.isEmpty ||
            required < 0 ||
            required > difference.length) {
          continue;
        }
        if (required == 0 && safe.addAllAndReport(difference)) changed = true;
        if (required == difference.length &&
            mines.addAllAndReport(difference)) {
          changed = true;
        }
      }
    }
  }
  safe.removeAll(flags);
  mines.removeAll(flags);
  final frontier = constraints.expand((constraint) => constraint.cells).toSet()
    ..removeAll(safe)
    ..removeAll(mines);
  final probabilities = <int, double>{
    for (final index in safe) index: 0,
    for (final index in mines) index: 1,
  };
  if (includeProbabilities && frontier.isNotEmpty) {
    probabilities.addAll(
      _enumerateFrontierProbabilities(constraints, frontier, knownMines: mines),
    );
  }
  final unknownOutside = allCovered
      .difference(frontier)
      .difference(safe)
      .difference(mines);
  final remainingMines = math.max(
    0,
    snapshot.mineCount - flags.length - mines.length,
  );
  if (unknownOutside.isNotEmpty) {
    final frontierExpected = frontier.fold<double>(
      0,
      (sum, index) => sum + (probabilities[index] ?? 0),
    );
    final outsideProbability =
        ((remainingMines - frontierExpected) / unknownOutside.length).clamp(
          0.0,
          1.0,
        );
    for (final index in unknownOutside) {
      probabilities[index] = outsideProbability;
    }
  }
  return _MineSolverAnalysis(
    safe: safe,
    mines: mines,
    probabilities: probabilities,
    constraintCount: constraints.length,
    frontierSize: frontier.length,
  );
}

Map<int, double> _enumerateFrontierProbabilities(
  List<_MineConstraint> constraints,
  Set<int> frontier, {
  required Set<int> knownMines,
}) {
  final relevant = <_MineConstraint>[];
  for (final constraint in constraints) {
    final cells = constraint.cells.intersection(frontier);
    final required =
        constraint.required - constraint.cells.intersection(knownMines).length;
    if (cells.isNotEmpty && required >= 0 && required <= cells.length) {
      relevant.add(_MineConstraint(cells, required));
    }
  }
  final pending = frontier.toSet();
  final probabilities = <int, double>{};
  while (pending.isNotEmpty) {
    final seed = pending.first;
    final component = <int>{seed};
    var expanded = true;
    while (expanded) {
      expanded = false;
      for (final constraint in relevant) {
        if (constraint.cells.any(component.contains)) {
          for (final cell in constraint.cells) {
            if (component.add(cell)) expanded = true;
          }
        }
      }
    }
    pending.removeAll(component);
    if (component.length > 22) {
      final local = relevant.where(
        (constraint) => constraint.cells.any(component.contains),
      );
      for (final cell in component) {
        final estimates = <double>[];
        for (final constraint in local) {
          if (constraint.cells.contains(cell)) {
            estimates.add(constraint.required / constraint.cells.length);
          }
        }
        probabilities[cell] = estimates.isEmpty
            ? 0.5
            : estimates.reduce((a, b) => a + b) / estimates.length;
      }
      continue;
    }
    final cells = component.toList(growable: false);
    final localConstraints = relevant
        .where((constraint) => constraint.cells.any(component.contains))
        .toList(growable: false);
    var validAssignments = 0;
    final mineFrequency = <int, int>{for (final cell in cells) cell: 0};
    final assignment = <int, bool>{};

    bool canContinue() {
      for (final constraint in localConstraints) {
        var assignedMines = 0;
        var unassigned = 0;
        for (final cell in constraint.cells) {
          final value = assignment[cell];
          if (value == true) assignedMines += 1;
          if (value == null) unassigned += 1;
        }
        if (assignedMines > constraint.required ||
            assignedMines + unassigned < constraint.required) {
          return false;
        }
      }
      return true;
    }

    void enumerate(int offset) {
      if (offset == cells.length) {
        if (!canContinue()) return;
        validAssignments += 1;
        for (final cell in cells) {
          if (assignment[cell] == true) {
            mineFrequency[cell] = mineFrequency[cell]! + 1;
          }
        }
        return;
      }
      final cell = cells[offset];
      assignment[cell] = false;
      if (canContinue()) enumerate(offset + 1);
      assignment[cell] = true;
      if (canContinue()) enumerate(offset + 1);
      assignment.remove(cell);
    }

    enumerate(0);
    if (validAssignments == 0) continue;
    for (final cell in cells) {
      probabilities[cell] = mineFrequency[cell]! / validAssignments;
    }
  }
  return probabilities;
}

Iterable<int> _snapshotNeighbors(
  _MineSolverSnapshot snapshot,
  int index,
) sync* {
  final row = index ~/ snapshot.columns;
  final column = index % snapshot.columns;
  for (var dr = -1; dr <= 1; dr += 1) {
    for (var dc = -1; dc <= 1; dc += 1) {
      if (dr == 0 && dc == 0) continue;
      final nextRow = row + dr;
      final nextColumn = column + dc;
      if (nextRow >= 0 &&
          nextRow < snapshot.rows &&
          nextColumn >= 0 &&
          nextColumn < snapshot.columns) {
        yield nextRow * snapshot.columns + nextColumn;
      }
    }
  }
}

extension on Set<int> {
  bool addAllAndReport(Iterable<int> values) {
    final before = length;
    addAll(values);
    return length != before;
  }
}
