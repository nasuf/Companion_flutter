part of 'package:companion_flutter/companion_api.dart';

mixin _CompanionApiGames on _CompanionApiCore {
  Future<List<GameSession>> listNativeGameSessions({
    String? gameKey,
    int limit = 50,
  }) async {
    final query = <String, String>{'limit': '$limit'};
    if (gameKey != null && gameKey.isNotEmpty) query['game_key'] = gameKey;
    final suffix = Uri(queryParameters: query).query;
    final json =
        await _request('GET', '/games/native/sessions?$suffix') as List;
    return json
        .map((item) => GameSession.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Aggregate play counters for the hub header. Computed server-side so the
  /// totals aren't capped by a session page size.
  Future<NativePlayStats> getNativePlayStats() async {
    final json =
        await _request('GET', '/games/native/stats', debugLabel: 'game.stats')
            as Map<String, dynamic>;
    return NativePlayStats.fromJson(json);
  }

  /// Lifetime record for one game's home screen (总对局 / 胜利局 / 胜率 / 时长).
  Future<NativeGameRecordStats> getNativeGameRecordStats(String gameKey) async {
    final suffix = Uri(
      queryParameters: {'game_key': gameKey},
    ).query;
    final json =
        await _request(
              'GET',
              '/games/native/record-stats?$suffix',
              debugLabel: 'game.recordStats',
            )
            as Map<String, dynamic>;
    return NativeGameRecordStats.fromJson(json);
  }

  Future<GameSession> createNativeGameSession({
    required String agentId,
    required String gameKey,
    String? workspaceId,
    String? conversationId,
  }) async {
    final json =
        await _request(
              'POST',
              '/games/native/sessions',
              body: {
                'agent_id': agentId,
                'workspace_id': workspaceId,
                'conversation_id': conversationId,
                'game_key': gameKey,
              },
            )
            as Map<String, dynamic>;
    return GameSession.fromJson(json);
  }

  Future<void> deleteNativeGameSession(String sessionId) async {
    await _request(
      'DELETE',
      '/games/native/sessions/${Uri.encodeComponent(sessionId)}',
    );
  }

  Future<GameEventResponse> sendNativeGameEvent({
    required String sessionId,
    required String eventType,
    String? state,
    Map<String, dynamic> payload = const {},
    String source = 'client',
    String? clientEventId,
  }) async {
    final json =
        await _request(
              'POST',
              '/games/native/sessions/$sessionId/events',
              body: {
                'event_type': eventType,
                'state': state,
                'payload': payload,
                'source': source,
                'client_event_id': clientEventId,
              },
            )
            as Map<String, dynamic>;
    return GameEventResponse.fromJson(json);
  }

  /// Latest terminal game session's status for the game hub header, or null if
  /// there is no finished round yet. Lightweight (no full session payload).
  Future<String?> getLatestNativeGameSession({String? agentId}) async {
    final query = (agentId != null && agentId.isNotEmpty)
        ? '?${Uri(queryParameters: {'agent_id': agentId}).query}'
        : '';
    try {
      final result = await _request(
        'GET',
        '/games/native/sessions/latest$query',
        debugLabel: 'game.latest',
      );
      if (result is Map) {
        final status = result['status']?.toString();
        return (status != null && status.isNotEmpty) ? status : null;
      }
      return null;
    } on ApiException catch (error) {
      // Tolerate the endpoint being unavailable (e.g. server not yet deployed):
      // treat as "no recent game" rather than surfacing an error on the hub.
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Per-game client visibility for the hub. Tolerates 404 (older server /
  /// deploy window) by returning an empty list so every game stays visible.
  Future<List<GameCatalogEntry>> getNativeGameCatalog() async {
    try {
      final result = await _request(
        'GET',
        '/games/native/catalog',
        debugLabel: 'game.catalog',
      );
      if (result is List) {
        return result
            .whereType<Map>()
            .map(
              (item) =>
                  GameCatalogEntry.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      }
      return const [];
    } on ApiException catch (error) {
      if (error.statusCode == 404) return const [];
      rethrow;
    }
  }

  Future<GameWallet> getGameWallet({String? gameKey}) async {
    final query = (gameKey != null && gameKey.isNotEmpty)
        ? '?${Uri(queryParameters: {'game_key': gameKey}).query}'
        : '';
    final json =
        await _request('GET', '/game-wallet$query', debugLabel: 'game.wallet')
            as Map<String, dynamic>;
    return GameWallet.fromJson(json);
  }

  /// The full level ladder, for the level-explanation sheet on the game hub.
  Future<List<GameLevelTier>> listGameLevelTiers() async {
    final json =
        await _request('GET', '/game-wallet/levels', debugLabel: 'game.levels')
            as List;
    return json
        .map((item) => GameLevelTier.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<GamePointConvertResult> convertGamePointsToShop({
    required int amount,
  }) async {
    final json =
        await _request(
              'POST',
              '/game-wallet/convert',
              body: {'amount': amount},
              debugLabel: 'game.wallet.convert',
            )
            as Map<String, dynamic>;
    return GamePointConvertResult.fromJson(json);
  }
}
