part of 'package:companion_flutter/companion_api.dart';

mixin _CompanionApiOffline on _CompanionApiCore {
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

  /// 管理员测试：为当前用户注入一份走 mock 链路的礼物（含物流轨迹）。
  /// [delivered] 为 true 时直接注入「已送达」礼物并推送送达消息。
  /// Admin QA: manually fire one proactive chat message for the current user.
  Future<AdminProactiveTriggerResult> triggerAdminProactiveChat({
    String? workspaceId,
    String? agentId,
    String triggerType = 'silence_wakeup',
    bool skipLimits = true,
    bool useWebSearch = false,
    bool useLinkCard = false,
  }) async {
    final json =
        await _request(
              'POST',
              '/admin-api/proactive/trigger',
              body: {
                if (workspaceId != null && workspaceId.isNotEmpty)
                  'workspace_id': workspaceId,
                if (agentId != null && agentId.isNotEmpty) 'agent_id': agentId,
                'trigger_type': triggerType,
                'skip_limits': skipLimits,
                'use_web_search': useWebSearch,
                'use_link_card': useLinkCard,
              },
            )
            as Map<String, dynamic>;
    return AdminProactiveTriggerResult.fromJson(json);
  }

  Future<RealWorldGift> createMockGift({
    String? workspaceId,
    bool delivered = false,
  }) async {
    final params = <String, String>{'delivered': delivered.toString()};
    if (workspaceId != null && workspaceId.isNotEmpty) {
      params['workspace_id'] = workspaceId;
    }
    final query = Uri(queryParameters: params).query;
    final json =
        await _request('POST', '/offline/admin/gifts/mock?$query')
            as Map<String, dynamic>;
    return RealWorldGift.fromJson(json);
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

  /// 确认到达：上报当前 GPS，服务端做 ≤200m 直线校验。距离不够 / 无坐标（且强制）
  /// 时抛 [ApiException]，message 已是可直接展示的提示文案。
  Future<OfflineActivity> arriveOfflineActivity(
    String activityId, {
    double? lat,
    double? lng,
  }) async {
    // 坐标可选：拿到就带上（地点已地理编码时服务端做 ≤200m 校验），拿不到也放行。
    final body = <String, dynamic>{
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    };
    final json =
        await _request(
              'POST',
              '/offline/activities/$activityId/arrive',
              body: body,
            )
            as Map<String, dynamic>;
    return _normalizeOfflineActivity(OfflineActivity.fromJson(json));
  }

  /// 抽此行小预言（未到达前每活动一次）。返回带 prophecyText 的活动。
  Future<OfflineActivity> drawOfflineActivityProphecy(String activityId) async {
    final json =
        await _request('POST', '/offline/activities/$activityId/prophecy')
            as Map<String, dynamic>;
    return _normalizeOfflineActivity(OfflineActivity.fromJson(json));
  }

  /// 收好这次旅途回忆（手动归档）：accepted -> completed。
  Future<OfflineActivity> archiveOfflineActivity(String activityId) async {
    final json =
        await _request('POST', '/offline/activities/$activityId/archive')
            as Map<String, dynamic>;
    return _normalizeOfflineActivity(OfflineActivity.fromJson(json));
  }

  /// 管理员测试页：检视活动详情 + 拍摄物品(任务) + 已产出碎片。
  Future<OfflineActivityInspect> adminInspectOfflineActivity(
    String activityId,
  ) async {
    final json =
        await _request('GET', '/offline/admin/activities/$activityId/inspect')
            as Map<String, dynamic>;
    return OfflineActivityInspect.fromJson(json);
  }

  /// 管理员测试专用：绕过到达校验直接生成拍摄物品(任务)，返回检视结果。
  Future<OfflineActivityInspect> adminGenerateOfflineActivityItems(
    String activityId,
  ) async {
    final json = await _request(
      'POST',
      '/offline/admin/activities/$activityId/generate-items',
    ) as Map<String, dynamic>;
    return OfflineActivityInspect.fromJson(json);
  }

  /// 活动回顾聚合（英雄区/故事/画廊/碎片/事件）。图片 URL 已绝对化。
  Future<OfflineActivityReview> fetchOfflineActivityReview(
    String activityId,
  ) async {
    final json =
        await _request('GET', '/offline/activities/$activityId/review')
            as Map<String, dynamic>;
    final review = OfflineActivityReview.fromJson(json);
    return review.copyWith(
      coverUrl: review.coverUrl == null ? null : _absoluteUrl(review.coverUrl!),
      gallery: review.gallery.map(_absoluteUrl).toList(),
    );
  }

  /// 生成/获取记忆手札旅途小记（幂等，后端缓存 travel_note）。
  Future<OfflineMemoryNote> generateOfflineMemoryNote(String activityId) async {
    final json =
        await _request('POST', '/offline/activities/$activityId/memory-note')
            as Map<String, dynamic>;
    final note = OfflineMemoryNote.fromJson(json);
    return note.coverUrl == null
        ? note
        : note.copyWith(coverUrl: _absoluteUrl(note.coverUrl!));
  }

  Future<OfflineActivity> completeOfflineActivity(
    String activityId, {
    required String text,
    List<String> photoAttachmentIds = const [],
    String? audioAttachmentId,
  }) async {
    final body = <String, dynamic>{
      'text': text,
      'photo_attachment_ids': photoAttachmentIds,
      if (audioAttachmentId != null && audioAttachmentId.isNotEmpty)
        'audio_attachment_id': audioAttachmentId,
    };
    final json =
        await _request(
              'POST',
              '/offline/activities/$activityId/complete',
              body: body,
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
                'kind': 'image',
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

  Future<ChatAttachment> uploadOfflineActivityAudio({
    required String activityId,
    required String name,
    required String mime,
    required int size,
    required int durationSeconds,
    required String base64Data,
  }) async {
    final json =
        await _request(
              'POST',
              '/offline/activities/$activityId/media',
              body: {
                'kind': 'audio',
                'name': name,
                'mime': mime,
                'size': size,
                'duration_seconds': durationSeconds,
                'base64': base64Data,
              },
              debugLabel: 'offline.activity.media.audio',
            )
            as Map<String, dynamic>;
    return _normalizeChatAttachment(ChatAttachment.fromJson(json));
  }

  Future<Uint8List> fetchAuthorizedBytes(String url) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(Uri.parse(_absoluteUrl(url)));
      if (authToken != null && authToken!.isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $authToken',
        );
      }
      final response = await request.close();
      final bytes = await consolidateHttpClientResponseBytes(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(response.statusCode, '媒体加载失败');
      }
      return bytes;
    } finally {
      client.close(force: true);
    }
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
    String? clientId,
  }) async {
    final json =
        await _request(
              'POST',
              '/offline/gifts/$giftId/thanks',
              body: {
                'message': message,
                if (clientId != null && clientId.isNotEmpty)
                  'client_id': clientId,
              },
            )
            as Map<String, dynamic>;
    final gift = json['gift'];
    return RealWorldGift.fromJson(Map<String, dynamic>.from(gift as Map));
  }
}
