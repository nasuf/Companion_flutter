part of 'package:companion_flutter/models.dart';

class GameLevel {
  const GameLevel({
    required this.stageName,
    required this.stageCaption,
    required this.tierName,
    required this.cumulativePoints,
  });

  /// `皮革手套` — the glove itself.
  final String stageName;

  /// `初学起步` — the descriptive line shown under the name.
  final String stageCaption;

  /// `白` — the colour ranking this step inside the stage.
  final String tierName;
  final int cumulativePoints;

  factory GameLevel.fromJson(Map<String, dynamic> json) {
    return GameLevel(
      stageName: json['stage_name']?.toString() ?? '',
      stageCaption: json['stage_caption']?.toString() ?? '',
      tierName: json['tier_name']?.toString() ?? '',
      cumulativePoints: (json['cumulative_points'] as num?)?.round() ?? 0,
    );
  }
}

/// Aggregate play counters for the game hub header.
class NativePlayStats {
  const NativePlayStats({
    required this.totalRounds,
    required this.totalSeconds,
    required this.todaySeconds,
  });

  /// Every native session the player started, finished or not.
  final int totalRounds;
  final int totalSeconds;
  final int todaySeconds;

  factory NativePlayStats.fromJson(Map<String, dynamic> json) {
    return NativePlayStats(
      totalRounds: (json['total_rounds'] as num?)?.round() ?? 0,
      totalSeconds: (json['total_seconds'] as num?)?.round() ?? 0,
      todaySeconds: (json['today_seconds'] as num?)?.round() ?? 0,
    );
  }
}

/// Lifetime record for one native game's home screen
/// (总对局 / 胜利局 / 胜率 / 时长).
class NativeGameRecordStats {
  const NativeGameRecordStats({
    required this.totalRounds,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.aborted,
    required this.totalSeconds,
    this.winRate = 0,
  });

  static const empty = NativeGameRecordStats(
    totalRounds: 0,
    wins: 0,
    losses: 0,
    draws: 0,
    aborted: 0,
    totalSeconds: 0,
  );

  final int totalRounds;
  final int wins;
  final int losses;
  final int draws;
  final int aborted;
  final int totalSeconds;

  /// 胜率 = 胜 ÷ 总对局 × 100。中途退出算进分母（退出会扣分）。
  final double winRate;

  /// Integer percent used on illustrated home screens.
  String get homeWinRateLabel => '${winRate.round()}%';

  factory NativeGameRecordStats.fromJson(Map<String, dynamic> json) {
    final wins = (json['wins'] as num?)?.round() ?? 0;
    final total = (json['total_rounds'] as num?)?.round() ?? 0;
    final parsedRate = (json['win_rate'] as num?)?.toDouble();
    return NativeGameRecordStats(
      totalRounds: total,
      wins: wins,
      losses: (json['losses'] as num?)?.round() ?? 0,
      draws: (json['draws'] as num?)?.round() ?? 0,
      aborted: (json['aborted'] as num?)?.round() ?? 0,
      totalSeconds: (json['total_seconds'] as num?)?.round() ?? 0,
      winRate: parsedRate ?? (total > 0 ? wins / total * 100 : 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_rounds': totalRounds,
      'wins': wins,
      'losses': losses,
      'draws': draws,
      'aborted': aborted,
      'win_rate': winRate,
      'total_seconds': totalSeconds,
    };
  }

  /// Client fallback when the record-stats endpoint is unavailable: same
  /// win-rate rule, but only over the sessions the caller already loaded.
  factory NativeGameRecordStats.fromSessions(Iterable<GameSession> sessions) {
    var total = 0;
    var wins = 0;
    var losses = 0;
    var draws = 0;
    var aborted = 0;
    var seconds = 0;
    for (final session in sessions) {
      final result = session.result;
      if (result == null ||
          !const {'settled', 'aborted'}.contains(session.status)) {
        continue;
      }
      total += 1;
      seconds += session.playSeconds;
      final outcome = (result['user_outcome'] ?? session.status).toString();
      if (outcome == 'aborted' || session.status == 'aborted') {
        aborted += 1;
      } else if (outcome == 'win') {
        wins += 1;
      } else if (outcome == 'lose') {
        losses += 1;
      } else if (outcome == 'draw') {
        draws += 1;
      }
    }
    return NativeGameRecordStats(
      totalRounds: total,
      wins: wins,
      losses: losses,
      draws: draws,
      aborted: aborted,
      totalSeconds: seconds,
      winRate: total > 0 ? wins / total * 100 : 0,
    );
  }
}

/// One rung of the admin-editable level ladder (`game_level_tiers`).
class GameLevelTier {
  const GameLevelTier({
    required this.sortOrder,
    required this.stageName,
    required this.stageCaption,
    required this.tierName,
    required this.upgradePoints,
    required this.cumulativePoints,
  });

  final int sortOrder;

  /// `皮革手套` — the glove itself.
  final String stageName;

  /// `初学起步` — the descriptive line shown under the name.
  final String stageCaption;

  /// `白` — the colour ranking this step inside the stage.
  final String tierName;
  final int upgradePoints;
  final int cumulativePoints;

  factory GameLevelTier.fromJson(Map<String, dynamic> json) {
    return GameLevelTier(
      sortOrder: (json['sort_order'] as num?)?.round() ?? 0,
      stageName: json['stage_name']?.toString() ?? '',
      stageCaption: json['stage_caption']?.toString() ?? '',
      tierName: json['tier_name']?.toString() ?? '',
      upgradePoints: (json['upgrade_points'] as num?)?.round() ?? 0,
      cumulativePoints: (json['cumulative_points'] as num?)?.round() ?? 0,
    );
  }
}

class GameWallet {
  const GameWallet({
    required this.balance,
    required this.lifetimeEarned,
    required this.canPlay,
    required this.convertFloor,
    required this.convertRate,
    required this.convertible,
    this.level,
    this.nextTier,
    this.gamePointsForGame,
  });

  final int balance;
  final int lifetimeEarned;
  final bool canPlay;
  final int convertFloor;
  final int convertRate;
  final int convertible;
  final GameLevel? level;
  final GameLevel? nextTier;
  // Net points settled for a specific game (only when the request scoped to a
  // game_key); null for the global wallet fetch.
  final int? gamePointsForGame;

  factory GameWallet.fromJson(Map<String, dynamic> json) {
    GameLevel? parseLevel(Object? value) {
      if (value is Map) {
        return GameLevel.fromJson(Map<String, dynamic>.from(value));
      }
      return null;
    }

    return GameWallet(
      balance: (json['balance'] as num?)?.round() ?? 0,
      lifetimeEarned: (json['lifetime_earned'] as num?)?.round() ?? 0,
      canPlay: json['can_play'] == true,
      convertFloor: (json['convert_floor'] as num?)?.round() ?? 20,
      convertRate: (json['convert_rate'] as num?)?.round() ?? 1,
      convertible: (json['convertible'] as num?)?.round() ?? 0,
      level: parseLevel(json['level']),
      nextTier: parseLevel(json['next_tier']),
      gamePointsForGame: (json['game_points_for_game'] as num?)?.round(),
    );
  }
}

/// Per-game scoring rules, mirroring `game_point_rules.rules` on the server.
///
/// Two shapes: most games score by outcome (win / lose / draw / quit), while
/// 数字合并 scores by the highest tile reached, with its own quit penalty.
///
/// These only label the result screen — the ledger is always settled by the
/// server. Both sides therefore carry the same table, each pinned by its own
/// test, rather than the client fetching it.
class GamePointRules {
  const GamePointRules({
    required this.isMilestone,
    required this.win,
    required this.lose,
    required this.draw,
    required this.quit,
    required this.milestones,
    required this.quitThreshold,
    required this.quitBelow,
    required this.quitAtOrAbove,
  });

  final bool isMilestone;
  final int win;
  final int lose;
  final int draw;
  final int quit;

  /// Tile → points, ascending.
  final List<MapEntry<int, int>> milestones;
  final int quitThreshold;
  final int quitBelow;
  final int quitAtOrAbove;

  factory GamePointRules.fromJson(Map<String, dynamic> json) {
    int asInt(Object? value) => (value as num?)?.round() ?? 0;
    final quit = json['quit_below_threshold'];
    final quitMap = quit is Map ? Map<String, dynamic>.from(quit) : const {};
    final raw = json['milestones'];
    final milestones = <MapEntry<int, int>>[
      if (raw is List)
        for (final entry in raw)
          if (entry is Map)
            MapEntry(asInt(entry['tile']), asInt(entry['points'])),
    ]..sort((a, b) => a.key.compareTo(b.key));
    return GamePointRules(
      isMilestone: json['type']?.toString() == 'milestone',
      win: asInt(json['win']),
      lose: asInt(json['lose']),
      draw: asInt(json['draw']),
      quit: asInt(json['quit']),
      milestones: milestones,
      quitThreshold: asInt(quitMap['threshold']),
      quitBelow: asInt(quitMap['below']),
      quitAtOrAbove: asInt(quitMap['at_or_above']),
    );
  }

  /// Points this round settles for. [maxTile] only matters for 数字合并.
  ///
  /// Mirrors `_outcome_delta` / `_milestone_delta` on the server: a milestone
  /// game charges the quit penalty below the first tile no matter how the
  /// round ended, and above it awards the highest tile reached unless the
  /// player walked away.
  int deltaFor(GameOutcome outcome, {int maxTile = 0}) {
    if (!isMilestone) {
      return switch (outcome) {
        GameOutcome.win => win,
        GameOutcome.lose => lose,
        GameOutcome.draw => draw,
        GameOutcome.aborted => quit,
      };
    }
    // Short of the first milestone the round counts as a loss however it
    // ended: filling the grid without ever reaching 128 is no better than
    // walking away from it.
    if (maxTile < quitThreshold) return quitBelow;
    if (outcome == GameOutcome.aborted) return quitAtOrAbove;
    var points = 0;
    for (final entry in milestones) {
      if (maxTile >= entry.key) points = entry.value;
    }
    return points;
  }
}

enum GameOutcome { win, lose, draw, aborted }

/// Scoring rules per game, matching the server's `game_point_rules` seed.
///
/// A result screen needs its number the moment it appears, and these values are
/// product constants, so they live here instead of arriving over the wire.
/// Pinned to the server's table by test/game_point_rules_test.dart — change one
/// side and the other has to follow.
GamePointRules? seedGamePointRules(String gameKey) {
  Map<String, dynamic> outcome(int win, int lose, int quit) => {
    'type': 'outcome',
    'win': win,
    'lose': lose,
    'draw': 0,
    'quit': quit,
  };
  final raw = switch (gameKey) {
    'go' || 'chinese_checkers' => outcome(5, -4, -4),
    'reversi' || 'xiangqi' || 'chess' => outcome(4, -3, -3),
    'gomoku' || 'minesweeper' || 'match3' => outcome(3, -2, -2),
    'tetris_duel' => outcome(3, -3, -3),
    'number_merge' => {
      'type': 'milestone',
      'milestones': [
        {'tile': 128, 'points': 2},
        {'tile': 256, 'points': 5},
        {'tile': 512, 'points': 6},
        {'tile': 1024, 'points': 15},
        {'tile': 2048, 'points': 25},
      ],
      'quit_below_threshold': {'threshold': 128, 'below': -2, 'at_or_above': 0},
    },
    _ => null,
  };
  return raw == null ? null : GamePointRules.fromJson(raw);
}

class GamePointConvertResult {
  const GamePointConvertResult({
    required this.gameBalance,
    required this.shopPointBalance,
    required this.converted,
    required this.shopPointDelta,
  });

  final int gameBalance;
  final int shopPointBalance;
  final int converted;
  final int shopPointDelta;

  factory GamePointConvertResult.fromJson(Map<String, dynamic> json) {
    return GamePointConvertResult(
      gameBalance: (json['game_balance'] as num?)?.round() ?? 0,
      shopPointBalance: (json['shop_point_balance'] as num?)?.round() ?? 0,
      converted: (json['converted'] as num?)?.round() ?? 0,
      shopPointDelta: (json['shop_point_delta'] as num?)?.round() ?? 0,
    );
  }
}

/// One native game's client visibility (from GET /games/native/catalog).
/// The client keeps its own tile catalog; this only says whether to show it.
class GameCatalogEntry {
  const GameCatalogEntry({
    required this.gameKey,
    required this.title,
    required this.enabled,
  });

  final String gameKey;
  final String title;
  final bool enabled;

  factory GameCatalogEntry.fromJson(Map<String, dynamic> json) {
    return GameCatalogEntry(
      gameKey: json['game_key']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      // Default to visible so a malformed/missing flag never hides a game.
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
    );
  }
}

class GamePlayerInfo {
  const GamePlayerInfo({
    required this.uid,
    required this.nickName,
    required this.avatarUrl,
    required this.gender,
    required this.isAi,
    required this.aiLevel,
  });

  final String uid;
  final String nickName;
  final String avatarUrl;
  final String gender;
  final int isAi;
  final int aiLevel;

  factory GamePlayerInfo.fromJson(Map<String, dynamic> json) {
    return GamePlayerInfo(
      uid: json['uid'] as String? ?? '',
      nickName: json['nick_name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      gender: json['gender'] as String? ?? '',
      isAi: (json['is_ai'] as num?)?.round() ?? 0,
      aiLevel: (json['ai_level'] as num?)?.round() ?? 0,
    );
  }
}

class GameSession {
  const GameSession({
    required this.id,
    required this.provider,
    this.gameKey,
    required this.status,
    required this.userId,
    required this.agentId,
    required this.roomId,
    required this.difficulty,
    required this.aiLevel,
    this.configVersion = 1,
    this.effectiveStrength = 50,
    this.engineConfig = const {},
    required this.userPlayer,
    required this.aiPlayer,
    this.workspaceId,
    this.conversationId,
    this.companionReply,
    this.result,
    this.durationSeconds,
    this.startedAt,
    this.endedAt,
    this.createdAt,
  });

  final String id;
  final String provider;
  final String? gameKey;
  final String status;
  final String userId;
  final String agentId;
  final String? workspaceId;
  final String? conversationId;
  final String roomId;
  final String difficulty;
  final int aiLevel;
  final int configVersion;
  final int effectiveStrength;
  final Map<String, dynamic> engineConfig;
  final GamePlayerInfo userPlayer;
  final GamePlayerInfo aiPlayer;
  final String? companionReply;
  final Map<String, dynamic>? result;
  final int? durationSeconds;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? createdAt;

  factory GameSession.fromJson(Map<String, dynamic> json) {
    return GameSession(
      id: json['id'] as String? ?? '',
      provider: json['provider'] as String? ?? 'native',
      gameKey: json['game_key'] as String?,
      status: json['status'] as String? ?? 'created',
      userId: json['user_id'] as String? ?? '',
      agentId: json['agent_id'] as String? ?? '',
      workspaceId: json['workspace_id'] as String?,
      conversationId: json['conversation_id'] as String?,
      roomId: json['room_id'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? 'normal',
      aiLevel: (json['ai_level'] as num?)?.round() ?? 0,
      configVersion: (json['config_version'] as num?)?.round() ?? 1,
      effectiveStrength: (json['effective_strength'] as num?)?.round() ?? 50,
      engineConfig:
          (json['engine_config'] as Map?)?.cast<String, dynamic>() ?? const {},
      userPlayer: GamePlayerInfo.fromJson(
        (json['user_player'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      aiPlayer: GamePlayerInfo.fromJson(
        (json['ai_player'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      companionReply: json['companion_reply'] as String?,
      result: json['result'] is Map
          ? Map<String, dynamic>.from(json['result'] as Map)
          : null,
      durationSeconds: (json['duration_seconds'] as num?)?.round(),
      startedAt: DateTime.tryParse(json['started_at'] as String? ?? ''),
      endedAt: DateTime.tryParse(json['ended_at'] as String? ?? ''),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }

  /// Seconds this round actually lasted. Prefer the stored client duration,
  /// then fall back to the started/ended span so older rows without
  /// ``duration_seconds`` still contribute to 时长.
  int get playSeconds {
    final stored = durationSeconds;
    if (stored != null) return stored < 0 ? 0 : stored;
    final fromResult = result?['duration_seconds'];
    if (fromResult is num) {
      final value = fromResult.round();
      return value < 0 ? 0 : value;
    }
    final start = startedAt;
    final end = endedAt;
    if (start != null && end != null) {
      final span = end.difference(start).inSeconds;
      return span < 0 ? 0 : span;
    }
    return 0;
  }
}

class GameEventResponse {
  const GameEventResponse({
    required this.session,
    this.companionReply,
    this.persistedEventId,
    this.duplicate = false,
  });

  final GameSession session;
  final String? companionReply;
  final String? persistedEventId;
  final bool duplicate;

  factory GameEventResponse.fromJson(Map<String, dynamic> json) {
    return GameEventResponse(
      session: GameSession.fromJson(
        (json['session'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      companionReply: json['companion_reply'] as String?,
      persistedEventId: json['persisted_event_id'] as String?,
      duplicate: json['duplicate'] as bool? ?? false,
    );
  }
}
