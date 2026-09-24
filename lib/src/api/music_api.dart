part of 'package:companion_flutter/companion_api.dart';

mixin _CompanionApiMusic on _CompanionApiCore {
  Future<MusicTracksResponse> listMusicTracks({
    required String agentId,
    String? workspaceId,
    String? library,
    String? excludeTrackId,
    int limit = 1,
    bool refresh = false,
  }) async {
    final params = <String, String>{'agent_id': agentId, 'limit': '$limit'};
    if (workspaceId != null && workspaceId.isNotEmpty) {
      params['workspace_id'] = workspaceId;
    }
    if (library != null && library.isNotEmpty) {
      params['library'] = library;
    }
    if (excludeTrackId != null && excludeTrackId.isNotEmpty) {
      params['exclude_track_id'] = excludeTrackId;
    }
    if (refresh) {
      params['refresh'] = 'true';
    }
    final query = Uri(queryParameters: params).query;
    final json =
        await _request('GET', '/music/tracks?$query', debugLabel: 'music.list')
            as Map<String, dynamic>;
    return _normalizeMusicTracksResponse(MusicTracksResponse.fromJson(json));
  }

  Future<MusicLibrariesResponse> listMusicLibraries() async {
    final json =
        await _request('GET', '/music/libraries', debugLabel: 'music.libs')
            as Map<String, dynamic>;
    return MusicLibrariesResponse.fromJson(json);
  }

  Future<MusicTracksResponse> listMusicFavorites({
    required String agentId,
  }) async {
    final query = Uri(queryParameters: {'agent_id': agentId}).query;
    final json =
        await _request(
              'GET',
              '/music/favorites?$query',
              debugLabel: 'music.favorites',
            )
            as Map<String, dynamic>;
    return _normalizeMusicTracksResponse(MusicTracksResponse.fromJson(json));
  }

  Future<MusicTrackPlayUrl> getMusicTrackPlayUrl({
    required String agentId,
    required String trackId,
  }) async {
    final query = Uri(queryParameters: {'agent_id': agentId}).query;
    final encodedTrackId = Uri.encodeComponent(trackId);
    final json =
        await _request(
              'GET',
              '/music/tracks/$encodedTrackId/play-url?$query',
              debugLabel: 'music.play-url',
            )
            as Map<String, dynamic>;
    final playUrl = MusicTrackPlayUrl.fromJson(json);
    return MusicTrackPlayUrl(
      trackId: playUrl.trackId,
      url: _absoluteUrl(playUrl.url),
      expiresAt: playUrl.expiresAt,
    );
  }

  Future<MusicTrack> addMusicFavorite({
    required String agentId,
    String? workspaceId,
    required MusicTrack track,
  }) async {
    final json =
        await _request(
              'POST',
              '/music/favorites',
              body: {
                'agent_id': agentId,
                'workspace_id': workspaceId,
                'track': track.toJson(),
              },
              debugLabel: 'music.favorite.add',
            )
            as Map<String, dynamic>;
    return _normalizeMusicTrack(
      MusicTrack.fromJson(
        Map<String, dynamic>.from(json['track'] as Map? ?? const {}),
      ),
    );
  }

  Future<void> removeMusicFavorite({
    required String agentId,
    required String trackId,
  }) async {
    final query = Uri(queryParameters: {'agent_id': agentId}).query;
    await _request(
      'DELETE',
      '/music/favorites/$trackId?$query',
      debugLabel: 'music.favorite.remove',
    );
  }

  Future<MusicPlayback> getMusicNowPlaying({required String agentId}) async {
    final query = Uri(queryParameters: {'agent_id': agentId}).query;
    final json =
        await _request(
              'GET',
              '/music/now-playing?$query',
              debugLabel: 'music.now',
            )
            as Map<String, dynamic>;
    return _normalizeMusicPlayback(MusicPlayback.fromJson(json));
  }

  Future<MusicPlayback> updateMusicNowPlaying({
    required String agentId,
    String? workspaceId,
    String? conversationId,
    required MusicTrack track,
    required int positionSeconds,
    required bool isPlaying,
    String changeSource = 'sync',
  }) async {
    final json =
        await _request(
              'POST',
              '/music/now-playing',
              body: {
                'agent_id': agentId,
                'workspace_id': workspaceId,
                'conversation_id': conversationId,
                'track': track.toJson(),
                'position_seconds': positionSeconds,
                'is_playing': isPlaying,
                'change_source': changeSource,
              },
              debugLabel: 'music.now.update',
            )
            as Map<String, dynamic>;
    return _normalizeMusicPlayback(MusicPlayback.fromJson(json));
  }

  Future<void> endMusicCoListening({
    required String agentId,
    required String conversationId,
    String reason = 'user_exit',
  }) async {
    await _request(
      'POST',
      '/music/co-listening/end',
      body: {
        'agent_id': agentId,
        'conversation_id': conversationId,
        'reason': reason,
      },
      debugLabel: 'music.co.end',
    );
  }

  /// 音乐陪伴时长上报（权益项 6）。播放中每 ~15s 调一次；返回的 action 决定
  /// 是否要暂停播放弹"消耗钞票/买券/订阅VIP"框。`paidConfirmed=true` 时才会
  /// 真正扣费，否则只返回预检结果。
  Future<MusicQuotaReport> reportMusicQuota({
    required int deltaSeconds,
    bool paidConfirmed = false,
  }) async {
    final json =
        await _request(
              'POST',
              '/music/quota/report',
              body: {
                'delta_seconds': deltaSeconds,
                'paid_confirmed': paidConfirmed,
              },
              debugLabel: 'music.quota.report',
            )
            as Map<String, dynamic>;
    return MusicQuotaReport.fromJson(json);
  }
}
