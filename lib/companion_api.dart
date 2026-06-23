import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'offline_models.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

class CompanionApi {
  CompanionApi({required this.baseUrl});

  final String baseUrl;
  String? authToken;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  String _absoluteUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty ||
        trimmed.startsWith('http://') ||
        trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (!trimmed.startsWith('/')) return trimmed;
    return '$baseUrl$trimmed';
  }

  String? _absoluteOptionalUrl(String? url) {
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) return trimmed;
    return _absoluteUrl(trimmed);
  }

  String? _agentAvatarUrl({String? url, String? key}) {
    final explicit = _absoluteOptionalUrl(url);
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final trimmedKey = key?.trim();
    if (trimmedKey == null || trimmedKey.isEmpty) return null;
    return _absoluteUrl(
      '/agents/avatar/${Uri.encodeComponent(trimmedKey)}.png',
    );
  }

  AuthSession _normalizeAuthSession(AuthSession session) {
    return AuthSession(
      token: session.token,
      userId: session.userId,
      username: session.username,
      userDisplayName: session.userDisplayName,
      userAvatarUrl: _absoluteOptionalUrl(session.userAvatarUrl),
      role: session.role,
      hasAgent: session.hasAgent,
      agentId: session.agentId,
      agentName: session.agentName,
      agentAvatarKey: session.agentAvatarKey,
      agentAvatarUrl: _agentAvatarUrl(
        url: session.agentAvatarUrl,
        key: session.agentAvatarKey,
      ),
      agentCity: session.agentCity,
      workspaceId: session.workspaceId,
      conversationId: session.conversationId,
    );
  }

  AgentProfile _normalizeAgentProfile(AgentProfile profile) {
    return AgentProfile(
      id: profile.id,
      name: profile.name,
      userId: profile.userId,
      workspaceId: profile.workspaceId,
      gender: profile.gender,
      city: profile.city,
      avatarKey: profile.avatarKey,
      avatarUrl: _agentAvatarUrl(
        url: profile.avatarUrl,
        key: profile.avatarKey,
      ),
    );
  }

  MusicTrack _normalizeMusicTrack(MusicTrack track) {
    return track.copyWith(url: _absoluteUrl(track.url));
  }

  MusicTracksResponse _normalizeMusicTracksResponse(MusicTracksResponse value) {
    return MusicTracksResponse(
      tracks: value.tracks.map(_normalizeMusicTrack).toList(),
      apiEnabled: value.apiEnabled,
      library: value.library,
    );
  }

  MusicPlayback _normalizeMusicPlayback(MusicPlayback value) {
    final track = value.track;
    return MusicPlayback(
      track: track == null ? null : _normalizeMusicTrack(track),
      positionSeconds: value.positionSeconds,
      isPlaying: value.isPlaying,
      updatedAt: value.updatedAt,
    );
  }

  ChatAttachment _normalizeChatAttachment(ChatAttachment value) {
    return value.copyWith(url: _absoluteUrl(value.url));
  }

  OfflineActivity _normalizeOfflineActivity(OfflineActivity value) {
    final feedback = value.completionFeedback;
    if (feedback == null) return value;
    return value.copyWith(
      completionFeedback: feedback.copyWith(
        photoAttachments: feedback.photoAttachments
            .map(_normalizeChatAttachment)
            .toList(),
      ),
    );
  }

  OfflineActivities _normalizeOfflineActivities(OfflineActivities value) {
    return OfflineActivities(
      latest: value.latest == null
          ? null
          : _normalizeOfflineActivity(value.latest!),
      pending: value.pending.map(_normalizeOfflineActivity).toList(),
      completed: value.completed.map(_normalizeOfflineActivity).toList(),
    );
  }

  OfflineHome _normalizeOfflineHome(OfflineHome value) {
    final latest = value.latestActivity;
    return OfflineHome(
      pendingActivityCount: value.pendingActivityCount,
      completedActivityCount: value.completedActivityCount,
      giftCount: value.giftCount,
      shippingGiftCount: value.shippingGiftCount,
      hasLocation: value.hasLocation,
      tags: value.tags,
      latestActivity: latest == null ? null : _normalizeOfflineActivity(latest),
      giftSummary: value.giftSummary,
    );
  }

  ChatMessage _normalizeChatMessage(ChatMessage value) {
    final metadata = value.metadata;
    if (metadata == null) return value;
    final rawAttachments = metadata['attachments'];
    if (rawAttachments is! List) return value;
    final attachments = [
      for (final item in rawAttachments)
        if (item is Map)
          _normalizeChatAttachment(
            ChatAttachment.fromJson(Map<String, dynamic>.from(item)),
          ).toJson(),
    ];
    return value.copyWith(metadata: {...metadata, 'attachments': attachments});
  }

  DailySharePhotosResponse _normalizeDailySharePhotos(
    DailySharePhotosResponse value,
  ) {
    return DailySharePhotosResponse(
      total: value.total,
      groups: [
        for (final group in value.groups)
          group.copyWith(
            photos: group.photos.map(_normalizeChatAttachment).toList(),
          ),
      ],
    );
  }

  ChatLinkCardResponse _normalizeChatLinkCard(ChatLinkCardResponse value) {
    return value;
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? debugLabel,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    final stopwatch = Stopwatch()..start();
    try {
      final request = await client.openUrl(method, _uri(path));
      request.headers.contentType = ContentType.json;
      if (authToken != null && authToken!.isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $authToken',
        );
      }
      if (body != null) {
        final payload = jsonEncode(body);
        if (debugLabel != null) {
          debugPrint(
            '[$debugLabel] request $method $path body=${utf8.encode(payload).length}B elapsed=${stopwatch.elapsedMilliseconds}ms',
          );
        }
        request.write(payload);
      } else if (debugLabel != null) {
        debugPrint(
          '[$debugLabel] request $method $path body=0B elapsed=${stopwatch.elapsedMilliseconds}ms',
        );
      }

      final response = await request.close();
      if (debugLabel != null) {
        debugPrint(
          '[$debugLabel] response headers status=${response.statusCode} elapsed=${stopwatch.elapsedMilliseconds}ms',
        );
      }
      final text = await response.transform(utf8.decoder).join();
      if (debugLabel != null) {
        debugPrint(
          '[$debugLabel] response body=${utf8.encode(text).length}B elapsed=${stopwatch.elapsedMilliseconds}ms',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(response.statusCode, _extractError(text));
      }
      if (response.statusCode == 204 || text.isEmpty) return null;
      return jsonDecode(text);
    } on SocketException catch (error) {
      throw ApiException(0, '无法连接到后端：${error.message}');
    } on HandshakeException catch (error) {
      throw ApiException(0, '后端连接失败：${error.message}');
    } finally {
      client.close(force: true);
    }
  }

  String _extractError(String text) {
    if (text.isEmpty) return '请求失败';
    try {
      final json = jsonDecode(text);
      final detail = json is Map ? json['detail'] : null;
      if (detail is String && detail.isNotEmpty) return detail;
      return text;
    } catch (_) {
      return text;
    }
  }

  Future<AuthSession> login(String username, String password) async {
    final json =
        await _request(
              'POST',
              '/auth/login',
              body: {'username': username, 'password': password},
            )
            as Map<String, dynamic>;
    final session = _normalizeAuthSession(AuthSession.fromJson(json));
    authToken = session.token;
    return session;
  }

  Future<AuthSession> register(String username, String password) async {
    final json =
        await _request(
              'POST',
              '/auth/register',
              body: {'username': username, 'password': password},
            )
            as Map<String, dynamic>;
    final session = _normalizeAuthSession(AuthSession.fromJson(json));
    authToken = session.token;
    return session;
  }

  Future<AuthSession> wechatMobileLogin(
    String code, {
    required String platform,
  }) async {
    final json =
        await _request(
              'POST',
              '/auth/wechat/mobile',
              body: {'code': code, 'platform': platform},
            )
            as Map<String, dynamic>;
    final session = _normalizeAuthSession(AuthSession.fromJson(json));
    authToken = session.token;
    return session;
  }

  Future<AuthSession> getMe(String token) async {
    authToken = token;
    final json = await _request('GET', '/auth/me') as Map<String, dynamic>;
    final session = _normalizeAuthSession(AuthSession.fromJson(json));
    authToken = session.token;
    return session;
  }

  Future<Conversation> getConversation(String conversationId) async {
    final json =
        await _request('GET', '/conversations/$conversationId')
            as Map<String, dynamic>;
    return Conversation.fromJson(json);
  }

  Future<AgentProfile> getAgent(String agentId) async {
    final json =
        await _request('GET', '/agents/$agentId') as Map<String, dynamic>;
    return _normalizeAgentProfile(AgentProfile.fromJson(json));
  }

  Future<ProfileStats> fetchProfileStats({String? workspaceId}) async {
    final params = <String, String>{};
    if (workspaceId != null && workspaceId.isNotEmpty) {
      params['workspace_id'] = workspaceId;
    }
    final query = Uri(queryParameters: params).query;
    final path = query.isEmpty
        ? '/users/me/profile-stats'
        : '/users/me/profile-stats?$query';
    final json = await _request('GET', path) as Map<String, dynamic>;
    return ProfileStats.fromJson(json);
  }

  Future<bool> saveUserLocation({
    double? latitude,
    double? longitude,
    String? city,
    String? region,
    String? country,
    String permissionStatus = 'unknown',
  }) async {
    final json =
        await _request(
              'PUT',
              '/users/me/location',
              body: {
                'latitude': latitude,
                'longitude': longitude,
                'city': city,
                'region': region,
                'country': country,
                'source': 'device',
                'permission_status': permissionStatus,
              },
            )
            as Map<String, dynamic>;
    return json['has_location'] == true;
  }

  Future<OfflineHome> fetchOfflineHome({String? workspaceId}) async {
    final path = _pathWithWorkspace('/offline/home', workspaceId);
    final json = await _request('GET', path) as Map<String, dynamic>;
    return _normalizeOfflineHome(OfflineHome.fromJson(json));
  }

  Future<OfflineActivities> fetchOfflineActivities({
    String? workspaceId,
  }) async {
    final path = _pathWithWorkspace('/offline/activities', workspaceId);
    final json = await _request('GET', path) as Map<String, dynamic>;
    return _normalizeOfflineActivities(OfflineActivities.fromJson(json));
  }

  Future<OfflineActivity?> createOfflineActivityRecommendation({
    String? workspaceId,
  }) async {
    final path = _pathWithWorkspace(
      '/offline/activities/recommend',
      workspaceId,
    );
    final json = await _request('POST', path);
    if (json is! Map) return null;
    return _normalizeOfflineActivity(
      OfflineActivity.fromJson(Map<String, dynamic>.from(json)),
    );
  }

  Future<AdminActivityClearResult>
  clearOfflineActivitiesForCurrentUser() async {
    final json =
        await _request('DELETE', '/offline/admin/activities')
            as Map<String, dynamic>;
    return AdminActivityClearResult.fromJson(json);
  }

  Future<OfflineActivity> fetchOfflineActivity(String activityId) async {
    final json =
        await _request('GET', '/offline/activities/$activityId')
            as Map<String, dynamic>;
    return _normalizeOfflineActivity(OfflineActivity.fromJson(json));
  }

  Future<OfflineActivity> acceptOfflineActivity(String activityId) async {
    final json =
        await _request('POST', '/offline/activities/$activityId/accept')
            as Map<String, dynamic>;
    return _normalizeOfflineActivity(OfflineActivity.fromJson(json));
  }

  Future<OfflineActivity> ignoreOfflineActivity(String activityId) async {
    final json =
        await _request('POST', '/offline/activities/$activityId/ignore')
            as Map<String, dynamic>;
    return _normalizeOfflineActivity(OfflineActivity.fromJson(json));
  }

  Future<OfflineActivity> completeOfflineActivity(
    String activityId, {
    required String text,
    List<String> photoAttachmentIds = const [],
  }) async {
    final json =
        await _request(
              'POST',
              '/offline/activities/$activityId/complete',
              body: {'text': text, 'photo_attachment_ids': photoAttachmentIds},
            )
            as Map<String, dynamic>;
    return _normalizeOfflineActivity(OfflineActivity.fromJson(json));
  }

  Future<ChatAttachment> uploadOfflineActivityImage({
    required String activityId,
    required String name,
    required String mime,
    required int size,
    required int width,
    required int height,
    required String base64Data,
  }) async {
    final json =
        await _request(
              'POST',
              '/offline/activities/$activityId/media',
              body: {
                'name': name,
                'mime': mime,
                'size': size,
                'width': width,
                'height': height,
                'base64': base64Data,
              },
              debugLabel: 'offline.activity.media',
            )
            as Map<String, dynamic>;
    return _normalizeChatAttachment(ChatAttachment.fromJson(json));
  }

  Future<GiftsHome> fetchOfflineGifts({String? workspaceId}) async {
    final path = _pathWithWorkspace('/offline/gifts', workspaceId);
    final json = await _request('GET', path) as Map<String, dynamic>;
    return GiftsHome.fromJson(json);
  }

  Future<GiftAddress> fetchGiftAddress() async {
    final json =
        await _request('GET', '/offline/gifts/address') as Map<String, dynamic>;
    return GiftAddress.fromJson(json);
  }

  Future<GiftAddress> saveGiftAddress({
    required String recipientName,
    required String phone,
    required String province,
    required String city,
    required String district,
    required String detail,
  }) async {
    final json =
        await _request(
              'PUT',
              '/offline/gifts/address',
              body: {
                'recipient_name': recipientName,
                'phone': phone,
                'province': province,
                'city': city,
                'district': district,
                'detail': detail,
              },
            )
            as Map<String, dynamic>;
    return GiftAddress.fromJson(json);
  }

  Future<RealWorldGift> fetchOfflineGift(String giftId) async {
    final json =
        await _request('GET', '/offline/gifts/$giftId') as Map<String, dynamic>;
    return RealWorldGift.fromJson(json);
  }

  Future<GiftTracking> fetchGiftTracking(String giftId) async {
    final json =
        await _request('GET', '/offline/gifts/$giftId/tracking')
            as Map<String, dynamic>;
    return GiftTracking.fromJson(json);
  }

  Future<RealWorldGift> sendGiftThanks(
    String giftId, {
    required String message,
  }) async {
    final json =
        await _request(
              'POST',
              '/offline/gifts/$giftId/thanks',
              body: {'message': message},
            )
            as Map<String, dynamic>;
    final gift = json['gift'];
    return RealWorldGift.fromJson(Map<String, dynamic>.from(gift as Map));
  }

  Future<List<Conversation>> listConversations({
    required String userId,
    String? workspaceId,
  }) async {
    final params = <String, String>{'user_id': userId};
    if (workspaceId != null && workspaceId.isNotEmpty) {
      params['workspace_id'] = workspaceId;
    }
    final query = Uri(queryParameters: params).query;
    final json = await _request('GET', '/conversations?$query') as List;
    return json
        .map((item) => Conversation.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Conversation> createConversation({
    required String userId,
    required String agentId,
    String? workspaceId,
  }) async {
    final json =
        await _request(
              'POST',
              '/conversations',
              body: {
                'user_id': userId,
                'agent_id': agentId,
                'workspace_id': workspaceId,
              },
            )
            as Map<String, dynamic>;
    return Conversation.fromJson(json);
  }

  Future<List<ChatMessage>> loadMessages(
    String conversationId, {
    int limit = 100,
    int offset = 0,
  }) async {
    final json =
        await _request(
              'GET',
              '/conversations/$conversationId/messages?limit=$limit&offset=$offset&include_metadata=true&include_achievements=true',
            )
            as List;
    return json
        .map(
          (item) => _normalizeChatMessage(
            ChatMessage.fromJson(item as Map<String, dynamic>),
          ),
        )
        .toList();
  }

  Future<ChatAttachment> uploadChatImage({
    required String conversationId,
    required String name,
    required String mime,
    required int size,
    required int width,
    required int height,
    required String base64Data,
  }) async {
    final json =
        await _request(
              'POST',
              '/chat/media',
              body: {
                'conversation_id': conversationId,
                'name': name,
                'mime': mime,
                'size': size,
                'width': width,
                'height': height,
                'base64': base64Data,
              },
              debugLabel: 'chat.media.image',
            )
            as Map<String, dynamic>;
    return _normalizeChatAttachment(ChatAttachment.fromJson(json));
  }

  Future<ChatLinkCardResponse> previewChatLink({
    required String conversationId,
    String? url,
    String? sharedText,
    String? sourceApp,
  }) async {
    final json =
        await _request(
              'POST',
              '/chat/links/preview',
              body: {
                'conversation_id': conversationId,
                if (url?.trim().isNotEmpty == true) 'url': url!.trim(),
                if (sharedText?.trim().isNotEmpty == true)
                  'shared_text': sharedText!.trim(),
                if (sourceApp?.trim().isNotEmpty == true)
                  'source_app': sourceApp!.trim(),
              },
              debugLabel: 'chat.links.preview',
            )
            as Map<String, dynamic>;
    return _normalizeChatLinkCard(ChatLinkCardResponse.fromJson(json));
  }

  Future<DailySharePhotosResponse> listDailySharePhotos({int? limit}) async {
    final suffix = limit == null ? '' : '?limit=$limit';
    final json =
        await _request('GET', '/daily-share/photos$suffix')
            as Map<String, dynamic>;
    return _normalizeDailySharePhotos(DailySharePhotosResponse.fromJson(json));
  }

  Future<DailyShareLinksResponse> listDailyShareLinks({int? limit}) async {
    final suffix = limit == null ? '' : '?limit=$limit';
    final json =
        await _request('GET', '/daily-share/links$suffix')
            as Map<String, dynamic>;
    return DailyShareLinksResponse.fromJson(json);
  }

  Future<SudConfigResponse> getSudConfig() async {
    final json =
        await _request('GET', '/games/sud/config') as Map<String, dynamic>;
    return SudConfigResponse.fromJson(json);
  }

  Future<List<SudSession>> listSudSessions() async {
    final json = await _request('GET', '/games/sud/sessions') as List;
    return json
        .map((item) => SudSession.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<SudSession> createSudSession({
    required String agentId,
    String? workspaceId,
    String? conversationId,
    String? mgId,
    String? roomId,
    required SudGamePlayMode playMode,
    required SudGameDifficulty difficulty,
  }) async {
    final json =
        await _request(
              'POST',
              '/games/sud/sessions',
              body: {
                'agent_id': agentId,
                'workspace_id': workspaceId,
                'conversation_id': conversationId,
                'mg_id': mgId,
                'room_id': roomId,
                'play_mode': playMode.name,
                'difficulty': difficulty.name,
              },
            )
            as Map<String, dynamic>;
    return SudSession.fromJson(json);
  }

  Future<SudSession> refreshSudSessionCode(String sessionId) async {
    final json =
        await _request('POST', '/games/sud/sessions/$sessionId/code')
            as Map<String, dynamic>;
    return SudSession.fromJson(json);
  }

  Future<SudGameEventResponse> sendSudGameEvent({
    required String sessionId,
    required String eventType,
    String? state,
    Map<String, dynamic> payload = const {},
    String source = 'client',
  }) async {
    final json =
        await _request(
              'POST',
              '/games/sud/sessions/$sessionId/events',
              body: {
                'event_type': eventType,
                'state': state,
                'payload': payload,
                'source': source,
              },
            )
            as Map<String, dynamic>;
    return SudGameEventResponse.fromJson(json);
  }

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

  Future<AchievementsResponse> listAchievements({
    required String agentId,
  }) async {
    final query = Uri(queryParameters: {'agent_id': agentId}).query;
    final json =
        await _request(
              'GET',
              '/achievements?$query',
              debugLabel: 'achievements',
            )
            as Map<String, dynamic>;
    return AchievementsResponse.fromJson(json);
  }

  Future<WalletBalance> getWallet({String? agentId}) async {
    final params = <String, String>{};
    if (agentId != null && agentId.isNotEmpty) {
      params['agent_id'] = agentId;
    }
    final query = params.isEmpty
        ? ''
        : '?${Uri(queryParameters: params).query}';
    final json =
        await _request('GET', '/wallet$query', debugLabel: 'wallet.balance')
            as Map<String, dynamic>;
    return WalletBalance.fromJson(json);
  }

  Future<WalletBalance> exchangeTicketsToPoints({
    required int ticketAmount,
  }) async {
    final json =
        await _request(
              'POST',
              '/wallet/exchange',
              body: {
                'from_currency': 'ticket',
                'to_currency': 'point',
                'ticket_amount': ticketAmount,
              },
              debugLabel: 'wallet.exchange',
            )
            as Map<String, dynamic>;
    return WalletBalance.fromJson(json);
  }

  Future<RemindersResponse> listReminders({
    required String userId,
    String? agentId,
    String status = 'active',
    int limit = 200,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'user_id': userId,
      'status': status,
      'limit': '$limit',
      'offset': '$offset',
    };
    if (agentId != null && agentId.isNotEmpty) {
      params['agent_id'] = agentId;
    }
    final query = Uri(queryParameters: params).query;
    final json =
        await _request('GET', '/reminders?$query', debugLabel: 'reminder.list')
            as Map<String, dynamic>;
    return RemindersResponse.fromJson(json);
  }

  Future<ReminderItem> createReminder({
    required String agentId,
    required String summary,
    required DateTime triggerTime,
    String recurrence = 'once',
    List<int>? habitWeekdays,
    bool sentToAi = false,
    String? workspaceId,
    String? conversationId,
  }) async {
    final json =
        await _request(
              'POST',
              '/reminders',
              body: {
                'agent_id': agentId,
                'workspace_id': workspaceId,
                'summary': summary,
                'trigger_time': triggerTime.toUtc().toIso8601String(),
                'recurrence': recurrence,
                if (habitWeekdays != null) 'habit_weekdays': habitWeekdays,
                'sent_to_ai': sentToAi,
                'conversation_id': conversationId,
              },
              debugLabel: 'reminder.create',
            )
            as Map<String, dynamic>;
    return ReminderItem.fromJson(json);
  }

  Future<ReminderItem> updateReminder(
    String triggerId, {
    String? summary,
    DateTime? triggerTime,
    String? recurrence,
    List<int>? habitWeekdays,
    bool? pinned,
    bool? sentToAi,
    String? conversationId,
  }) async {
    final json =
        await _request(
              'PATCH',
              '/reminders/$triggerId',
              body: {
                if (summary != null) 'summary': summary,
                if (triggerTime != null)
                  'trigger_time': triggerTime.toUtc().toIso8601String(),
                if (recurrence != null) 'recurrence': recurrence,
                if (habitWeekdays != null) 'habit_weekdays': habitWeekdays,
                if (pinned != null) 'pinned': pinned,
                if (sentToAi != null) 'sent_to_ai': sentToAi,
                'conversation_id': conversationId,
              },
              debugLabel: 'reminder.update',
            )
            as Map<String, dynamic>;
    return ReminderItem.fromJson(json);
  }

  Future<ReminderItem> completeReminder(
    String triggerId, {
    String? conversationId,
    DateTime? occurrenceDate,
  }) async {
    final params = <String, String>{
      if (conversationId != null && conversationId.isNotEmpty)
        'conversation_id': conversationId,
      if (occurrenceDate != null) 'occurrence_date': _dateOnly(occurrenceDate)!,
    };
    final query = params.isEmpty
        ? ''
        : '?${Uri(queryParameters: params).query}';
    final json =
        await _request(
              'POST',
              '/reminders/$triggerId/complete$query',
              debugLabel: 'reminder.complete',
            )
            as Map<String, dynamic>;
    return ReminderItem.fromJson(json);
  }

  Future<void> deleteReminder(
    String triggerId, {
    String? conversationId,
  }) async {
    final query = conversationId == null || conversationId.isEmpty
        ? ''
        : '?${Uri(queryParameters: {'conversation_id': conversationId}).query}';
    await _request('DELETE', '/reminders/$triggerId$query');
  }

  Future<void> registerPushDevice({
    required String token,
    required String environment,
    required String deviceId,
    String? bundleId,
    String? appVersion,
  }) async {
    final body = {
      'platform': 'ios',
      'token': token,
      'environment': environment,
      'device_id': deviceId,
    };
    if (bundleId != null && bundleId.isNotEmpty) {
      body['bundle_id'] = bundleId;
    }
    if (appVersion != null && appVersion.isNotEmpty) {
      body['app_version'] = appVersion;
    }
    await _request(
      'POST',
      '/notifications/devices',
      body: body,
      debugLabel: 'push.register',
    );
  }

  Future<void> disablePushDevice({required String token}) async {
    await _request(
      'DELETE',
      '/notifications/devices',
      body: {'token': token},
      debugLabel: 'push.disable',
    );
  }

  Future<void> updatePushPresence({
    required String deviceId,
    required bool foreground,
    String? workspaceId,
    String? conversationId,
  }) async {
    await _request(
      'POST',
      '/notifications/presence',
      body: {
        'device_id': deviceId,
        'foreground': foreground,
        'workspace_id': workspaceId,
        'conversation_id': conversationId,
      },
      debugLabel: 'push.presence',
    );
  }

  Future<List<TimeCapsule>> listTimeCapsules({
    String? agentId,
    String? workspaceId,
    String? state,
  }) async {
    final params = <String, String>{};
    if (agentId != null && agentId.isNotEmpty) {
      params['agent_id'] = agentId;
    }
    if (workspaceId != null && workspaceId.isNotEmpty) {
      params['workspace_id'] = workspaceId;
    }
    if (state != null && state.isNotEmpty) {
      params['state'] = state;
    }
    final query = Uri(queryParameters: params).query;
    final json =
        await _request('GET', '/capsules?$query', debugLabel: 'capsule.list')
            as List;
    return json
        .map((item) => TimeCapsule.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<TimeCapsule> getTimeCapsule(String capsuleId) async {
    final json =
        await _request(
              'GET',
              '/capsules/$capsuleId',
              debugLabel: 'capsule.detail',
            )
            as Map<String, dynamic>;
    return TimeCapsule.fromJson(json);
  }

  Future<TimeCapsule> openTimeCapsule(String capsuleId) async {
    final json =
        await _request(
              'POST',
              '/capsules/$capsuleId/open',
              debugLabel: 'capsule.open',
            )
            as Map<String, dynamic>;
    return TimeCapsule.fromJson(json);
  }

  Future<Map<String, dynamic>> uploadTimeCapsuleMedia({
    required String kind,
    required String name,
    required String mime,
    required int size,
    required String base64Data,
    int? durationSeconds,
  }) async {
    final json =
        await _request(
              'POST',
              '/capsules/media',
              body: {
                'kind': kind,
                'name': name,
                'mime': mime,
                'size': size,
                'duration_seconds': durationSeconds,
                'base64': base64Data,
              },
              debugLabel: 'capsule.media.$kind',
            )
            as Map<String, dynamic>;
    return Map<String, dynamic>.from(json);
  }

  Future<TimeCapsule> createTimeCapsule({
    String? agentId,
    required String content,
    required String status,
    String? workspaceId,
    DateTime? openDate,
    String? title,
    Map<String, dynamic>? media,
    String skin = 'paper',
  }) async {
    final json =
        await _request(
              'POST',
              '/capsules',
              body: {
                if (agentId != null && agentId.isNotEmpty) 'agent_id': agentId,
                'workspace_id': workspaceId,
                'title': title,
                'content': content,
                'media': media,
                'skin': skin,
                'status': status,
                'open_date': _dateOnly(openDate),
              },
              debugLabel: 'capsule.create',
            )
            as Map<String, dynamic>;
    return TimeCapsule.fromJson(json);
  }

  Future<TimeCapsule> updateTimeCapsule(
    String capsuleId, {
    String? content,
    String? status,
    DateTime? openDate,
    String? title,
    Map<String, dynamic>? media,
    String? skin,
    bool clearMedia = false,
  }) async {
    final body = <String, dynamic>{
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (skin != null) 'skin': skin,
      if (status != null) 'status': status,
      if (openDate != null) 'open_date': _dateOnly(openDate),
      if (media != null) 'media': media else if (clearMedia) 'media': null,
    };
    final json =
        await _request(
              'PATCH',
              '/capsules/$capsuleId',
              body: body,
              debugLabel: 'capsule.update',
            )
            as Map<String, dynamic>;
    return TimeCapsule.fromJson(json);
  }

  Future<void> deleteTimeCapsule(String capsuleId) async {
    await _request('DELETE', '/capsules/$capsuleId');
  }

  Future<List<LastWill>> listLastWills({
    String? agentId,
    String? workspaceId,
  }) async {
    final params = <String, String>{};
    if (agentId != null && agentId.isNotEmpty) {
      params['agent_id'] = agentId;
    }
    if (workspaceId != null && workspaceId.isNotEmpty) {
      params['workspace_id'] = workspaceId;
    }
    final query = Uri(queryParameters: params).query;
    final path = query.isEmpty ? '/last-wills' : '/last-wills?$query';
    final json =
        await _request('GET', path, debugLabel: 'last_will.list') as List;
    return json
        .map((item) => LastWill.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<LastWill> createLastWill({
    String? agentId,
    required String content,
    required int inactivityDays,
    required List<LastWillContact> contacts,
    required String status,
    String? workspaceId,
  }) async {
    final json =
        await _request(
              'POST',
              '/last-wills',
              body: {
                if (agentId != null && agentId.isNotEmpty) 'agent_id': agentId,
                if (workspaceId != null && workspaceId.isNotEmpty)
                  'workspace_id': workspaceId,
                'content': content,
                'inactivity_days': inactivityDays,
                'contacts': contacts.map((item) => item.toJson()).toList(),
                'status': status,
              },
              debugLabel: 'last_will.create',
            )
            as Map<String, dynamic>;
    return LastWill.fromJson(json);
  }

  Future<LastWill> updateLastWill(
    String willId, {
    String? content,
    int? inactivityDays,
    List<LastWillContact>? contacts,
    String? status,
  }) async {
    final json =
        await _request(
              'PATCH',
              '/last-wills/$willId',
              body: {
                if (content != null) 'content': content,
                if (inactivityDays != null) 'inactivity_days': inactivityDays,
                if (contacts != null)
                  'contacts': contacts.map((item) => item.toJson()).toList(),
                if (status != null) 'status': status,
              },
              debugLabel: 'last_will.update',
            )
            as Map<String, dynamic>;
    return LastWill.fromJson(json);
  }

  Future<LastWill> startLastWill(String willId) async {
    final json =
        await _request(
              'POST',
              '/last-wills/$willId/start',
              debugLabel: 'last_will.start',
            )
            as Map<String, dynamic>;
    return LastWill.fromJson(json);
  }

  Future<LastWill> pauseLastWill(String willId) async {
    final json =
        await _request(
              'POST',
              '/last-wills/$willId/pause',
              debugLabel: 'last_will.pause',
            )
            as Map<String, dynamic>;
    return LastWill.fromJson(json);
  }

  Future<void> clearLastWillContent(String willId) async {
    await _request('DELETE', '/last-wills/$willId');
  }

  Future<AgentProfile> createAgent({
    required String userId,
    required String name,
    required String gender,
    required Map<String, int> personality,
  }) async {
    final json =
        await _request(
              'POST',
              '/agents',
              body: {
                'user_id': userId,
                'name': name,
                'gender': gender,
                'personality': personality,
              },
            )
            as Map<String, dynamic>;
    return _normalizeAgentProfile(AgentProfile.fromJson(json));
  }

  Future<AgentProvisionStatus> getAgentProvisionStatus(String agentId) async {
    final json =
        await _request('GET', '/agents/$agentId/provision-status')
            as Map<String, dynamic>;
    return AgentProvisionStatus.fromJson(json);
  }

  Future<AgentDeleteResult> deleteAgent(String agentId) async {
    final json =
        await _request('DELETE', '/agents/$agentId') as Map<String, dynamic>;
    return AgentDeleteResult.fromJson(json);
  }

  Future<AuthSession> ensureConversation(AuthSession session) async {
    final agentId = session.agentId;
    if (!session.hasAgent || agentId == null || agentId.isEmpty) {
      return session;
    }
    final existingConversationId = session.conversationId;
    if (existingConversationId != null && existingConversationId.isNotEmpty) {
      try {
        final conversation = await getConversation(existingConversationId);
        return session.copyWith(
          workspaceId: conversation.workspaceId ?? session.workspaceId,
          conversationId: conversation.id,
        );
      } catch (_) {
        // Continue to list/create below.
      }
    }

    final conversations = await listConversations(
      userId: session.userId,
      workspaceId: session.workspaceId,
    );
    final matched = conversations.where((item) => item.agentId == agentId);
    if (matched.isNotEmpty) {
      final conversation = matched.first;
      return session.copyWith(
        workspaceId: conversation.workspaceId ?? session.workspaceId,
        conversationId: conversation.id,
      );
    }

    final created = await createConversation(
      userId: session.userId,
      agentId: agentId,
      workspaceId: session.workspaceId,
    );
    return session.copyWith(
      workspaceId: created.workspaceId ?? session.workspaceId,
      conversationId: created.id,
    );
  }

  String? _dateOnly(DateTime? value) {
    if (value == null) return null;
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _pathWithWorkspace(String path, String? workspaceId) {
    if (workspaceId == null || workspaceId.isEmpty) return path;
    final query = Uri(queryParameters: {'workspace_id': workspaceId}).query;
    return '$path?$query';
  }
}
