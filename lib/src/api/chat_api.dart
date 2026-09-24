part of 'package:companion_flutter/companion_api.dart';

mixin _CompanionApiChat on _CompanionApiCore {
  @override
  Future<Conversation> getConversation(String conversationId) async {
    final json =
        await _request('GET', '/conversations/$conversationId')
            as Map<String, dynamic>;
    return Conversation.fromJson(json);
  }

  Future<WorkspaceInteractionOverview> getWorkspaceInteraction(
    String workspaceId, {
    int? year,
    int? month,
  }) async {
    final params = <String, String>{};
    if (year != null) params['year'] = '$year';
    if (month != null) params['month'] = '$month';
    final query = Uri(queryParameters: params).query;
    final path = query.isEmpty
        ? '/workspaces/$workspaceId/interaction'
        : '/workspaces/$workspaceId/interaction?$query';
    final json = await _request('GET', path) as Map<String, dynamic>;
    return WorkspaceInteractionOverview.fromJson(json);
  }

  Future<void> applyWorkspaceInteractionMakeup(
    String workspaceId, {
    required String date,
  }) async {
    await _request(
      'POST',
      '/workspaces/$workspaceId/interaction/makeup',
      body: {'date': date},
    );
  }

  /// 某条消息在会话中的实时 rank（= loadMessages 的 offset），用于跳转定位。
  /// 找不到返回 null。
  Future<int?> fetchMessageRank(String conversationId, String messageId) async {
    final json = await _request(
      'GET',
      '/conversations/$conversationId/messages/$messageId/rank',
    ) as Map<String, dynamic>;
    final rank = json['rank'];
    return rank is int ? rank : (rank is num ? rank.toInt() : null);
  }

  @override
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

  @override
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

  Future<MessageSearchResult> searchMessages(
    String conversationId, {
    String? query,
    String scope = 'all',
    String? cardCategory,
    int limit = 30,
    int offset = 0,
  }) async {
    final params = <String, String>{
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      'scope': scope,
      if (cardCategory != null && cardCategory.isNotEmpty)
        'card_category': cardCategory,
      'limit': '$limit',
      'offset': '$offset',
    };
    final queryString = Uri(queryParameters: params).query;
    final json =
        await _request(
              'GET',
              '/conversations/$conversationId/messages/search?$queryString',
            )
            as Map<String, dynamic>;
    final result = MessageSearchResult.fromJson(json);
    List<MessageSearchHit> normalize(List<MessageSearchHit> hits) => hits
        .map((hit) => hit.copyWith(message: _normalizeChatMessage(hit.message)))
        .toList();
    return MessageSearchResult(
      text: normalize(result.text),
      cards: normalize(result.cards),
      images: normalize(result.images),
      hasMoreText: result.hasMoreText,
      hasMoreCards: result.hasMoreCards,
      hasMoreImages: result.hasMoreImages,
    );
  }

  Future<ChatAttachment> uploadChatImage({
    required String conversationId,
    required String name,
    required String mime,
    required Uint8List bytes,
  }) async {
    try {
      final json =
          await _requestMultipart(
                'POST',
                '/chat/media/upload',
                fields: {'conversation_id': conversationId, 'name': name},
                fileField: 'file',
                fileName: name,
                fileMime: mime,
                fileBytes: bytes,
                debugLabel: 'chat.media.image',
              )
              as Map<String, dynamic>;
      return _normalizeChatAttachment(ChatAttachment.fromJson(json));
    } on ApiException catch (error) {
      // Older servers only expose the base64 JSON route; fall back once.
      if (error.statusCode != 404 && error.statusCode != 405) rethrow;
      final json =
          await _request(
                'POST',
                '/chat/media',
                body: {
                  'conversation_id': conversationId,
                  'name': name,
                  'mime': mime,
                  'size': bytes.length,
                  'width': 0,
                  'height': 0,
                  'base64': base64Encode(bytes),
                },
                debugLabel: 'chat.media.image.base64',
              )
              as Map<String, dynamic>;
      return _normalizeChatAttachment(ChatAttachment.fromJson(json));
    }
  }

  Future<ChatAudioTranscription> transcribeChatAudio({
    required String conversationId,
    required String name,
    required String mime,
    required int size,
    required int durationSeconds,
    required String displayMode,
    required String base64Data,
  }) async {
    final json =
        await _request(
              'POST',
              '/chat/transcribe',
              body: {
                'conversation_id': conversationId,
                'name': name,
                'mime': mime,
                'size': size,
                'duration_seconds': durationSeconds,
                'display_mode': displayMode,
                'base64': base64Data,
              },
              debugLabel: 'chat.audio.transcribe',
            )
            as Map<String, dynamic>;
    final text = json['text']?.toString().trim() ?? '';
    if (text.isEmpty) {
      throw const ApiException(502, '没有识别到清晰的语音');
    }
    final rawAttachment = json['attachment'];
    if (displayMode == 'voice' && rawAttachment is! Map) {
      throw const ApiException(502, '语音文件保存失败');
    }
    final attachment = rawAttachment is Map
        ? _normalizeChatAttachment(
            ChatAttachment.fromJson(Map<String, dynamic>.from(rawAttachment)),
          )
        : null;
    return ChatAudioTranscription(
      text: text,
      attachment: attachment,
      durationSeconds:
          (json['duration_seconds'] as num?)?.round() ?? durationSeconds,
      model: json['model']?.toString() ?? '',
      requestId: json['request_id']?.toString(),
    );
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

  Future<RedPacketSendResult> sendRedPacket({
    required String conversationId,
    required int ticketAmount,
    String? blessing,
  }) async {
    final json =
        await _request(
              'POST',
              '/red-packets',
              body: {
                'conversation_id': conversationId,
                'ticket_amount': ticketAmount,
                if (blessing != null && blessing.trim().isNotEmpty)
                  'blessing': blessing.trim(),
              },
              debugLabel: 'redPacket.send',
            )
            as Map<String, dynamic>;
    return RedPacketSendResult.fromJson(json);
  }

  Future<GiftSendResult> sendGift({
    required String conversationId,
    required String productKind,
  }) async {
    final json =
        await _request(
              'POST',
              '/gifts',
              body: {
                'conversation_id': conversationId,
                'product_kind': productKind,
              },
              debugLabel: 'gift.send',
            )
            as Map<String, dynamic>;
    return GiftSendResult.fromJson(json);
  }

  Future<GiftSendResult> getGift(String offeringId) async {
    final json =
        await _request(
              'GET',
              '/gifts/${Uri.encodeComponent(offeringId)}',
              debugLabel: 'gift.get',
            )
            as Map<String, dynamic>;
    return GiftSendResult.fromJson(json);
  }

  Future<RedPacketSendResult> getRedPacket(String offeringId) async {
    final json =
        await _request(
              'GET',
              '/red-packets/${Uri.encodeComponent(offeringId)}',
              debugLabel: 'redPacket.get',
            )
            as Map<String, dynamic>;
    return RedPacketSendResult.fromJson(json);
  }
}
