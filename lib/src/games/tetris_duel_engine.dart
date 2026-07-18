import 'dart:math' as math;

enum TetrisTetromino { i, j, l, o, s, t, z }

enum TetrisDuelActor { user, agent }

enum TetrisDuelStatus { playing, userWon, agentWon, draw }

class TetrisCell {
  const TetrisCell(this.x, this.y);

  final int x;
  final int y;
}

class TetrisActivePiece {
  const TetrisActivePiece({
    required this.type,
    required this.rotation,
    required this.x,
    required this.y,
  });

  final TetrisTetromino type;
  final int rotation;
  final int x;
  final int y;

  TetrisActivePiece copyWith({int? rotation, int? x, int? y}) =>
      TetrisActivePiece(
        type: type,
        rotation: rotation ?? this.rotation,
        x: x ?? this.x,
        y: y ?? this.y,
      );

  List<TetrisCell> get cells => [
    for (final cell in _tetrisShape(type, rotation))
      TetrisCell(x + cell.x, y + cell.y),
  ];
}

class TetrisLockResult {
  const TetrisLockResult({
    required this.actor,
    required this.piece,
    required this.linesCleared,
    required this.scoreGained,
    required this.combo,
    required this.backToBack,
    required this.attack,
    required this.dropDistance,
    required this.boardHash,
    required this.topOut,
  });

  final TetrisDuelActor actor;
  final TetrisTetromino piece;
  final int linesCleared;
  final int scoreGained;
  final int combo;
  final bool backToBack;
  final int attack;
  final int dropDistance;
  final int boardHash;
  final bool topOut;

  Map<String, dynamic> toJson() => {
    'actor': actor.name,
    'piece': piece.name,
    'lines_cleared': linesCleared,
    'score_gained': scoreGained,
    'combo': combo,
    'back_to_back': backToBack,
    'attack_sent': attack,
    'drop_distance': dropDistance,
    'board_hash': boardHash.toString(),
    'top_out': topOut,
  };
}

class TetrisAiPlacement {
  const TetrisAiPlacement({
    required this.rotation,
    required this.x,
    required this.evaluation,
    required this.completedLines,
    required this.aggregateHeight,
    required this.holes,
    required this.bumpiness,
  });

  final int rotation;
  final int x;
  final double evaluation;
  final int completedLines;
  final int aggregateHeight;
  final int holes;
  final int bumpiness;

  Map<String, dynamic> toJson() => {
    'rotation': rotation,
    'x': x,
    'evaluation': evaluation,
    'completed_lines': completedLines,
    'aggregate_height': aggregateHeight,
    'holes': holes,
    'bumpiness': bumpiness,
    'algorithm': 'weighted_surface_height_holes_bumpiness_line_value',
  };
}

class TetrisDuelConfig {
  const TetrisDuelConfig({
    this.durationSeconds = 90,
    this.agentMoveMs = 760,
    this.nearBestProbability = 0,
    this.nearBestTolerance = 0,
  });

  factory TetrisDuelConfig.fromJson(Map<String, dynamic> json) =>
      TetrisDuelConfig(
        durationSeconds: (json['duration_seconds'] as num?)?.round() ?? 90,
        agentMoveMs: (json['agent_move_ms'] as num?)?.round() ?? 760,
        nearBestProbability:
            (json['near_best_probability'] as num?)?.toDouble() ?? 0,
        nearBestTolerance:
            (json['near_best_tolerance'] as num?)?.toDouble() ?? 0,
      );

  final int durationSeconds;
  final int agentMoveMs;
  final double nearBestProbability;
  final double nearBestTolerance;
}

class TetrisBoardEngine {
  TetrisBoardEngine({
    required this.actor,
    required int seed,
    List<int>? initialBoard,
    List<TetrisTetromino>? initialQueue,
  }) : _random = math.Random(seed) {
    if (initialBoard != null) {
      if (initialBoard.length != width * height ||
          initialBoard.any((cell) => cell < 0 || cell > 8)) {
        throw ArgumentError.value(
          initialBoard,
          'initialBoard',
          'must contain exactly ${width * height} cells in the range 0...8',
        );
      }
      _board.setAll(0, initialBoard);
    }
    if (initialQueue != null) {
      _queue.addAll(initialQueue);
    }
    _fillQueue();
    _spawn();
  }

  static const width = 10;
  static const height = 20;

  final TetrisDuelActor actor;
  final math.Random _random;
  final List<int> _board = List.filled(width * height, 0);
  final List<TetrisTetromino> _queue = [];
  final List<TetrisTetromino> _bag = [];

  TetrisActivePiece? current;
  TetrisTetromino? hold;
  bool canHold = true;
  bool topOut = false;
  int score = 0;
  int lines = 0;
  int piecesPlaced = 0;
  int combo = -1;
  int maxCombo = 0;
  int tetrises = 0;
  int attackSent = 0;
  int attackReceived = 0;
  int maxHeight = 0;
  bool _backToBack = false;
  int _scoreAtLastLock = 0;

  List<int> get board => List<int>.unmodifiable(_board);
  List<TetrisTetromino> get next => List.unmodifiable(_queue.take(5));
  int get level => 1 + lines ~/ 10;
  int get stateHash => Object.hashAll([
    ..._board,
    current?.type.index ?? -1,
    current?.rotation ?? 0,
    current?.x ?? 0,
    current?.y ?? 0,
    score,
    lines,
  ]);

  bool moveHorizontal(int delta) {
    final piece = current;
    if (piece == null || topOut) return false;
    final candidate = piece.copyWith(x: piece.x + delta);
    if (_collides(candidate)) return false;
    current = candidate;
    return true;
  }

  bool rotate({bool clockwise = true}) {
    final piece = current;
    if (piece == null || topOut || piece.type == TetrisTetromino.o) {
      return false;
    }
    final from = piece.rotation;
    final to = (from + (clockwise ? 1 : 3)) % 4;
    for (final kick in _tetrisKicks(piece.type, from, to)) {
      final candidate = piece.copyWith(
        rotation: to,
        x: piece.x + kick.x,
        y: piece.y - kick.y,
      );
      if (!_collides(candidate)) {
        current = candidate;
        return true;
      }
    }
    return false;
  }

  TetrisLockResult? softDrop() {
    final piece = current;
    if (piece == null || topOut) return null;
    final candidate = piece.copyWith(y: piece.y + 1);
    if (_collides(candidate)) return _lock(dropDistance: 0);
    current = candidate;
    score += 1;
    return null;
  }

  TetrisLockResult hardDrop() {
    final piece = current!;
    var candidate = piece;
    var distance = 0;
    while (!_collides(candidate.copyWith(y: candidate.y + 1))) {
      candidate = candidate.copyWith(y: candidate.y + 1);
      distance += 1;
    }
    current = candidate;
    score += distance * 2;
    return _lock(dropDistance: distance);
  }

  bool swapHold() {
    final piece = current;
    if (piece == null || topOut || !canHold) return false;
    final previous = hold;
    hold = piece.type;
    canHold = false;
    if (previous == null) {
      _spawn();
    } else {
      current = TetrisActivePiece(type: previous, rotation: 0, x: 3, y: -1);
      if (_collides(current!)) topOut = true;
    }
    return true;
  }

  List<TetrisCell> ghostCells() {
    final piece = current;
    if (piece == null) return const [];
    var ghost = piece;
    while (!_collides(ghost.copyWith(y: ghost.y + 1))) {
      ghost = ghost.copyWith(y: ghost.y + 1);
    }
    return ghost.cells;
  }

  TetrisAiPlacement chooseAiPlacement({
    TetrisDuelConfig config = const TetrisDuelConfig(),
  }) {
    final piece = current!;
    final placements = <TetrisAiPlacement>[];
    final rotations = piece.type == TetrisTetromino.o ? 1 : 4;
    for (var rotation = 0; rotation < rotations; rotation++) {
      for (var x = -2; x < width + 2; x++) {
        var candidate = TetrisActivePiece(
          type: piece.type,
          rotation: rotation,
          x: x,
          y: -3,
        );
        if (_collides(candidate)) continue;
        while (!_collides(candidate.copyWith(y: candidate.y + 1))) {
          candidate = candidate.copyWith(y: candidate.y + 1);
        }
        if (candidate.cells.any((cell) => cell.y < 0)) continue;
        final simulated = List<int>.of(_board);
        for (final cell in candidate.cells) {
          simulated[cell.y * width + cell.x] = piece.type.index + 1;
        }
        final completed = _countCompleteLines(simulated);
        final metrics = _surfaceMetrics(simulated);
        final evaluation =
            completed * 9.2 -
            metrics.aggregateHeight * .46 -
            metrics.holes * 7.8 -
            metrics.bumpiness * .62 -
            metrics.maxHeight * .82 +
            _wellPotential(simulated) * .16;
        final placement = TetrisAiPlacement(
          rotation: rotation,
          x: x,
          evaluation: evaluation,
          completedLines: completed,
          aggregateHeight: metrics.aggregateHeight,
          holes: metrics.holes,
          bumpiness: metrics.bumpiness,
        );
        placements.add(placement);
      }
    }
    placements.sort((a, b) => b.evaluation.compareTo(a.evaluation));
    if (placements.isNotEmpty) {
      final best = placements.first;
      final near = placements
          .where(
            (item) =>
                best.evaluation - item.evaluation <= config.nearBestTolerance,
          )
          .take(6)
          .toList();
      if (near.length > 1 &&
          _random.nextDouble() < config.nearBestProbability) {
        return near[1 + _random.nextInt(near.length - 1)];
      }
      return best;
    }
    return TetrisAiPlacement(
      rotation: piece.rotation,
      x: piece.x,
      evaluation: -999,
      completedLines: 0,
      aggregateHeight: height * width,
      holes: width * height,
      bumpiness: height * width,
    );
  }

  TetrisLockResult playAiPlacement(TetrisAiPlacement placement) {
    final piece = current!;
    var candidate = TetrisActivePiece(
      type: piece.type,
      rotation: placement.rotation,
      x: placement.x,
      y: -3,
    );
    while (!_collides(candidate.copyWith(y: candidate.y + 1))) {
      candidate = candidate.copyWith(y: candidate.y + 1);
    }
    current = candidate;
    final dropDistance = math.max(0, candidate.y - piece.y);
    score += dropDistance * 2;
    return _lock(dropDistance: dropDistance);
  }

  void receiveGarbage(int count) {
    if (count <= 0 || topOut) return;
    final amount = math.min(4, count);
    if (_board.take(amount * width).any((cell) => cell != 0)) {
      topOut = true;
      return;
    }
    for (var row = 0; row < height - amount; row++) {
      for (var col = 0; col < width; col++) {
        _board[row * width + col] = _board[(row + amount) * width + col];
      }
    }
    for (var row = height - amount; row < height; row++) {
      final hole = _random.nextInt(width);
      for (var col = 0; col < width; col++) {
        _board[row * width + col] = col == hole ? 0 : 8;
      }
    }
    final active = current;
    if (active != null) {
      final lifted = active.copyWith(y: active.y - amount);
      if (_collides(lifted)) {
        topOut = true;
      } else {
        current = lifted;
      }
    }
    attackReceived += amount;
    maxHeight = math.max(maxHeight, _surfaceMetrics(_board).maxHeight);
  }

  Map<String, dynamic> summaryJson() {
    final metrics = _surfaceMetrics(_board);
    return {
      'score': score,
      'lines': lines,
      'level': level,
      'pieces_placed': piecesPlaced,
      'tetrises': tetrises,
      'max_combo': maxCombo,
      'attack_sent': attackSent,
      'attack_received': attackReceived,
      'max_height': math.max(maxHeight, metrics.maxHeight),
      'holes': metrics.holes,
      'aggregate_height': metrics.aggregateHeight,
      'bumpiness': metrics.bumpiness,
      'top_out': topOut,
      'board': List<int>.of(_board),
      'state_hash': stateHash.toString(),
    };
  }

  TetrisLockResult _lock({required int dropDistance}) {
    final piece = current!;
    var lockedAbove = false;
    for (final cell in piece.cells) {
      if (cell.y < 0) {
        lockedAbove = true;
      } else if (cell.x >= 0 && cell.x < width && cell.y < height) {
        _board[cell.y * width + cell.x] = piece.type.index + 1;
      }
    }
    final cleared = _clearLines();
    final difficult = cleared == 4;
    final b2b = difficult && _backToBack;
    if (cleared > 0) {
      combo += 1;
      maxCombo = math.max(maxCombo, combo);
    } else {
      combo = -1;
    }
    final base = switch (cleared) {
      1 => 100,
      2 => 300,
      3 => 500,
      4 => 800,
      _ => 0,
    };
    final comboBonus = combo > 0 ? combo * 50 : 0;
    final gained = (base * level * (b2b ? 1.5 : 1)).round() + comboBonus;
    score += gained;
    lines += cleared;
    piecesPlaced += 1;
    if (cleared == 4) tetrises += 1;
    _backToBack = difficult || (cleared == 0 && _backToBack);
    final attack = _attackFor(cleared, combo, b2b);
    attackSent += attack;
    maxHeight = math.max(maxHeight, _surfaceMetrics(_board).maxHeight);
    topOut = topOut || lockedAbove;
    canHold = true;
    final scoreGained = score - _scoreAtLastLock;
    _scoreAtLastLock = score;
    _spawn();
    return TetrisLockResult(
      actor: actor,
      piece: piece.type,
      linesCleared: cleared,
      scoreGained: scoreGained,
      combo: math.max(0, combo),
      backToBack: b2b,
      attack: attack,
      dropDistance: dropDistance,
      boardHash: stateHash,
      topOut: topOut,
    );
  }

  void _spawn() {
    _fillQueue();
    final type = _queue.removeAt(0);
    _fillQueue();
    current = TetrisActivePiece(type: type, rotation: 0, x: 3, y: -1);
    if (_collides(current!)) topOut = true;
  }

  void _fillQueue() {
    while (_queue.length < 7) {
      if (_bag.isEmpty) {
        _bag.addAll(TetrisTetromino.values);
        _bag.shuffle(_random);
      }
      _queue.add(_bag.removeLast());
    }
  }

  bool _collides(TetrisActivePiece piece) {
    for (final cell in piece.cells) {
      if (cell.x < 0 || cell.x >= width || cell.y >= height) return true;
      if (cell.y >= 0 && _board[cell.y * width + cell.x] != 0) return true;
    }
    return false;
  }

  int _clearLines() {
    var write = height - 1;
    var cleared = 0;
    for (var read = height - 1; read >= 0; read--) {
      final full = List.generate(
        width,
        (col) => _board[read * width + col],
      ).every((cell) => cell != 0);
      if (full) {
        cleared += 1;
        continue;
      }
      if (write != read) {
        for (var col = 0; col < width; col++) {
          _board[write * width + col] = _board[read * width + col];
        }
      }
      write -= 1;
    }
    while (write >= 0) {
      for (var col = 0; col < width; col++) {
        _board[write * width + col] = 0;
      }
      write -= 1;
    }
    return cleared;
  }
}

class TetrisDuelEngine {
  TetrisDuelEngine({
    required int seed,
    TetrisDuelConfig? config,
    int? durationSeconds,
  }) : config =
           config ?? TetrisDuelConfig(durationSeconds: durationSeconds ?? 90),
       user = TetrisBoardEngine(actor: TetrisDuelActor.user, seed: seed),
       agent = TetrisBoardEngine(actor: TetrisDuelActor.agent, seed: seed);

  final TetrisBoardEngine user;
  final TetrisBoardEngine agent;
  final TetrisDuelConfig config;
  int get durationSeconds => config.durationSeconds;
  int elapsedMilliseconds = 0;
  TetrisDuelStatus status = TetrisDuelStatus.playing;

  int get remainingSeconds =>
      math.max(0, durationSeconds - elapsedMilliseconds ~/ 1000);
  bool get isFinished => status != TetrisDuelStatus.playing;

  void advanceClock(int milliseconds) {
    if (isFinished) return;
    elapsedMilliseconds += milliseconds;
    _resolveStatus();
  }

  void applyAttack(TetrisLockResult result) {
    if (result.attack <= 0) return;
    final receiver = result.actor == TetrisDuelActor.user ? agent : user;
    receiver.receiveGarbage(result.attack);
    _resolveStatus();
  }

  void _resolveStatus() {
    if (user.topOut && agent.topOut) {
      status = TetrisDuelStatus.draw;
    } else if (user.topOut) {
      status = TetrisDuelStatus.agentWon;
    } else if (agent.topOut) {
      status = TetrisDuelStatus.userWon;
    } else if (elapsedMilliseconds >= durationSeconds * 1000) {
      status = user.score == agent.score
          ? TetrisDuelStatus.draw
          : user.score > agent.score
          ? TetrisDuelStatus.userWon
          : TetrisDuelStatus.agentWon;
    }
  }

  Map<String, dynamic> summaryJson() => {
    'mode': 'timed_duel',
    'duration_limit_seconds': durationSeconds,
    'elapsed_seconds': elapsedMilliseconds ~/ 1000,
    'winner': switch (status) {
      TetrisDuelStatus.userWon => 'user',
      TetrisDuelStatus.agentWon => 'agent',
      _ => 'draw',
    },
    'user': user.summaryJson(),
    'agent': agent.summaryJson(),
  };
}

class _TetrisSurfaceMetrics {
  const _TetrisSurfaceMetrics({
    required this.aggregateHeight,
    required this.holes,
    required this.bumpiness,
    required this.maxHeight,
  });

  final int aggregateHeight;
  final int holes;
  final int bumpiness;
  final int maxHeight;
}

_TetrisSurfaceMetrics _surfaceMetrics(List<int> board) {
  final heights = List<int>.filled(TetrisBoardEngine.width, 0);
  var holes = 0;
  for (var col = 0; col < TetrisBoardEngine.width; col++) {
    var found = false;
    for (var row = 0; row < TetrisBoardEngine.height; row++) {
      final occupied = board[row * TetrisBoardEngine.width + col] != 0;
      if (occupied && !found) {
        heights[col] = TetrisBoardEngine.height - row;
        found = true;
      } else if (!occupied && found) {
        holes += 1;
      }
    }
  }
  var bumpiness = 0;
  for (var col = 0; col < heights.length - 1; col++) {
    bumpiness += (heights[col] - heights[col + 1]).abs();
  }
  return _TetrisSurfaceMetrics(
    aggregateHeight: heights.fold(0, (sum, value) => sum + value),
    holes: holes,
    bumpiness: bumpiness,
    maxHeight: heights.fold(0, math.max),
  );
}

int _countCompleteLines(List<int> board) {
  var count = 0;
  for (var row = 0; row < TetrisBoardEngine.height; row++) {
    if (List.generate(
      TetrisBoardEngine.width,
      (col) => board[row * TetrisBoardEngine.width + col],
    ).every((cell) => cell != 0)) {
      count += 1;
    }
  }
  return count;
}

double _wellPotential(List<int> board) {
  final metrics = _surfaceMetrics(board);
  return math.max(0, 12 - metrics.bumpiness - metrics.holes * 2).toDouble();
}

int _attackFor(int lines, int combo, bool backToBack) {
  final base = switch (lines) {
    2 => 1,
    3 => 2,
    4 => 4,
    _ => 0,
  };
  return base + (backToBack ? 1 : 0) + (combo >= 4 ? 1 : 0);
}

List<TetrisCell> _tetrisShape(TetrisTetromino type, int rotation) {
  final shapes = _tetrisShapes[type]!;
  return shapes[rotation % shapes.length];
}

List<TetrisCell> _tetrisKicks(TetrisTetromino type, int from, int to) {
  if (type == TetrisTetromino.o) return const [TetrisCell(0, 0)];
  final table = type == TetrisTetromino.i ? _iKickTable : _jlstzKickTable;
  return table['$from>$to'] ?? const [TetrisCell(0, 0)];
}

const _tetrisShapes = <TetrisTetromino, List<List<TetrisCell>>>{
  TetrisTetromino.i: [
    [TetrisCell(0, 1), TetrisCell(1, 1), TetrisCell(2, 1), TetrisCell(3, 1)],
    [TetrisCell(2, 0), TetrisCell(2, 1), TetrisCell(2, 2), TetrisCell(2, 3)],
    [TetrisCell(0, 2), TetrisCell(1, 2), TetrisCell(2, 2), TetrisCell(3, 2)],
    [TetrisCell(1, 0), TetrisCell(1, 1), TetrisCell(1, 2), TetrisCell(1, 3)],
  ],
  TetrisTetromino.j: [
    [TetrisCell(0, 0), TetrisCell(0, 1), TetrisCell(1, 1), TetrisCell(2, 1)],
    [TetrisCell(1, 0), TetrisCell(2, 0), TetrisCell(1, 1), TetrisCell(1, 2)],
    [TetrisCell(0, 1), TetrisCell(1, 1), TetrisCell(2, 1), TetrisCell(2, 2)],
    [TetrisCell(1, 0), TetrisCell(1, 1), TetrisCell(0, 2), TetrisCell(1, 2)],
  ],
  TetrisTetromino.l: [
    [TetrisCell(2, 0), TetrisCell(0, 1), TetrisCell(1, 1), TetrisCell(2, 1)],
    [TetrisCell(1, 0), TetrisCell(1, 1), TetrisCell(1, 2), TetrisCell(2, 2)],
    [TetrisCell(0, 1), TetrisCell(1, 1), TetrisCell(2, 1), TetrisCell(0, 2)],
    [TetrisCell(0, 0), TetrisCell(1, 0), TetrisCell(1, 1), TetrisCell(1, 2)],
  ],
  TetrisTetromino.o: [
    [TetrisCell(1, 0), TetrisCell(2, 0), TetrisCell(1, 1), TetrisCell(2, 1)],
  ],
  TetrisTetromino.s: [
    [TetrisCell(1, 0), TetrisCell(2, 0), TetrisCell(0, 1), TetrisCell(1, 1)],
    [TetrisCell(1, 0), TetrisCell(1, 1), TetrisCell(2, 1), TetrisCell(2, 2)],
    [TetrisCell(1, 1), TetrisCell(2, 1), TetrisCell(0, 2), TetrisCell(1, 2)],
    [TetrisCell(0, 0), TetrisCell(0, 1), TetrisCell(1, 1), TetrisCell(1, 2)],
  ],
  TetrisTetromino.t: [
    [TetrisCell(1, 0), TetrisCell(0, 1), TetrisCell(1, 1), TetrisCell(2, 1)],
    [TetrisCell(1, 0), TetrisCell(1, 1), TetrisCell(2, 1), TetrisCell(1, 2)],
    [TetrisCell(0, 1), TetrisCell(1, 1), TetrisCell(2, 1), TetrisCell(1, 2)],
    [TetrisCell(1, 0), TetrisCell(0, 1), TetrisCell(1, 1), TetrisCell(1, 2)],
  ],
  TetrisTetromino.z: [
    [TetrisCell(0, 0), TetrisCell(1, 0), TetrisCell(1, 1), TetrisCell(2, 1)],
    [TetrisCell(2, 0), TetrisCell(1, 1), TetrisCell(2, 1), TetrisCell(1, 2)],
    [TetrisCell(0, 1), TetrisCell(1, 1), TetrisCell(1, 2), TetrisCell(2, 2)],
    [TetrisCell(1, 0), TetrisCell(0, 1), TetrisCell(1, 1), TetrisCell(0, 2)],
  ],
};

const _jlstzKickTable = <String, List<TetrisCell>>{
  '0>1': [
    TetrisCell(0, 0),
    TetrisCell(-1, 0),
    TetrisCell(-1, 1),
    TetrisCell(0, -2),
    TetrisCell(-1, -2),
  ],
  '1>0': [
    TetrisCell(0, 0),
    TetrisCell(1, 0),
    TetrisCell(1, -1),
    TetrisCell(0, 2),
    TetrisCell(1, 2),
  ],
  '1>2': [
    TetrisCell(0, 0),
    TetrisCell(1, 0),
    TetrisCell(1, -1),
    TetrisCell(0, 2),
    TetrisCell(1, 2),
  ],
  '2>1': [
    TetrisCell(0, 0),
    TetrisCell(-1, 0),
    TetrisCell(-1, 1),
    TetrisCell(0, -2),
    TetrisCell(-1, -2),
  ],
  '2>3': [
    TetrisCell(0, 0),
    TetrisCell(1, 0),
    TetrisCell(1, 1),
    TetrisCell(0, -2),
    TetrisCell(1, -2),
  ],
  '3>2': [
    TetrisCell(0, 0),
    TetrisCell(-1, 0),
    TetrisCell(-1, -1),
    TetrisCell(0, 2),
    TetrisCell(-1, 2),
  ],
  '3>0': [
    TetrisCell(0, 0),
    TetrisCell(-1, 0),
    TetrisCell(-1, -1),
    TetrisCell(0, 2),
    TetrisCell(-1, 2),
  ],
  '0>3': [
    TetrisCell(0, 0),
    TetrisCell(1, 0),
    TetrisCell(1, 1),
    TetrisCell(0, -2),
    TetrisCell(1, -2),
  ],
};

const _iKickTable = <String, List<TetrisCell>>{
  '0>1': [
    TetrisCell(0, 0),
    TetrisCell(-2, 0),
    TetrisCell(1, 0),
    TetrisCell(-2, -1),
    TetrisCell(1, 2),
  ],
  '1>0': [
    TetrisCell(0, 0),
    TetrisCell(2, 0),
    TetrisCell(-1, 0),
    TetrisCell(2, 1),
    TetrisCell(-1, -2),
  ],
  '1>2': [
    TetrisCell(0, 0),
    TetrisCell(-1, 0),
    TetrisCell(2, 0),
    TetrisCell(-1, 2),
    TetrisCell(2, -1),
  ],
  '2>1': [
    TetrisCell(0, 0),
    TetrisCell(1, 0),
    TetrisCell(-2, 0),
    TetrisCell(1, -2),
    TetrisCell(-2, 1),
  ],
  '2>3': [
    TetrisCell(0, 0),
    TetrisCell(2, 0),
    TetrisCell(-1, 0),
    TetrisCell(2, 1),
    TetrisCell(-1, -2),
  ],
  '3>2': [
    TetrisCell(0, 0),
    TetrisCell(-2, 0),
    TetrisCell(1, 0),
    TetrisCell(-2, -1),
    TetrisCell(1, 2),
  ],
  '3>0': [
    TetrisCell(0, 0),
    TetrisCell(1, 0),
    TetrisCell(-2, 0),
    TetrisCell(1, -2),
    TetrisCell(-2, 1),
  ],
  '0>3': [
    TetrisCell(0, 0),
    TetrisCell(-1, 0),
    TetrisCell(2, 0),
    TetrisCell(-1, 2),
    TetrisCell(2, -1),
  ],
};
