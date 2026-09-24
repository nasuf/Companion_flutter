part of 'package:companion_flutter/models.dart';

class Conversation {
  const Conversation({
    required this.id,
    required this.userId,
    required this.agentId,
    this.workspaceId,
    this.title,
    this.createdAt,
    this.updatedAt,
    this.interactionDays,
    this.aiStatus,
    this.aiStatusLabel,
    this.aiActivity,
    this.musicCoListening,
  });

  final String id;
  final String userId;
  final String agentId;
  final String? workspaceId;
  final String? title;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? interactionDays;
  final String? aiStatus;
  final String? aiStatusLabel;
  final String? aiActivity;
  final MusicCoListening? musicCoListening;

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      agentId: json['agent_id'] as String? ?? '',
      workspaceId: json['workspace_id'] as String?,
      title: json['title'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
      interactionDays: (json['interaction_days'] as num?)?.round(),
      aiStatus: json['ai_status'] as String?,
      aiStatusLabel: json['ai_status_label'] as String?,
      aiActivity: json['ai_activity'] as String?,
      musicCoListening: json['music_co_listening'] is Map
          ? MusicCoListening.fromJson(
              Map<String, dynamic>.from(json['music_co_listening'] as Map),
            )
          : null,
    );
  }
}

class WorkspaceInteractionDay {
  const WorkspaceInteractionDay({
    required this.date,
    this.source,
    required this.makeupEligible,
  });

  final String date;
  final String? source;
  final bool makeupEligible;

  factory WorkspaceInteractionDay.fromJson(Map<String, dynamic> json) {
    return WorkspaceInteractionDay(
      date: json['date'] as String? ?? '',
      source: json['source'] as String?,
      makeupEligible: json['makeup_eligible'] as bool? ?? false,
    );
  }
}

class WorkspaceInteractionOverview {
  const WorkspaceInteractionOverview({
    required this.currentStreak,
    required this.today,
    required this.todayMarked,
    required this.makeupCards,
    required this.lookbackDays,
    required this.workspaceCreatedOn,
    this.month,
    required this.days,
  });

  final int currentStreak;
  final String today;
  final bool todayMarked;
  final int makeupCards;
  final int lookbackDays;
  final String workspaceCreatedOn;
  final String? month;
  final List<WorkspaceInteractionDay> days;

  factory WorkspaceInteractionOverview.fromJson(Map<String, dynamic> json) {
    return WorkspaceInteractionOverview(
      currentStreak: (json['current_streak'] as num?)?.round() ?? 0,
      today: json['today'] as String? ?? '',
      todayMarked: json['today_marked'] as bool? ?? false,
      makeupCards: (json['makeup_cards'] as num?)?.round() ?? 0,
      lookbackDays: (json['lookback_days'] as num?)?.round() ?? 30,
      workspaceCreatedOn: json['workspace_created_on'] as String? ?? '',
      month: json['month'] as String?,
      days: (json['days'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (row) => WorkspaceInteractionDay.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList(),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.metadata,
    this.pending = false,
    this.read = false,
    this.failed = false,
  });

  final String id;
  final String conversationId;
  final String role;
  final String content;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;
  final bool pending;
  final bool read;

  /// 发出去之后既没等到 ack/回复，也没被服务端拒绝 (quota_blocked)，而是
  /// 客户端自己判定"等不到响应了" (发送超时 / socket 未连接 / error 事件) ——
  /// 跟 [pending] 互斥: 一条消息不会同时"还在发送中"又"已确认失败"。
  final bool failed;

  bool get isMine => role == 'user';
  bool get isAchievement => role == 'achievement';
  bool get isMusicStatus => metadata?['music_status'] != null;
  bool get isMusicActivityBurst =>
      metadata?['kind']?.toString() == 'music_activity_burst';
  bool get isMusicActivityTimeline =>
      isMusicActivityBurst || isMusicStatus;
  bool get isGameStatus => metadata?['game_status'] != null;
  bool get isGameActivityBurst =>
      metadata?['kind']?.toString() == 'game_activity_burst';
  bool get isGameActivityTimeline =>
      isGameActivityBurst || isGameStatus;
  bool get isOfferingReceived =>
      metadata?['offering_received'] == true ||
      metadata?['offering_received']?.toString() == 'true';
  bool get isChatMessage => role == 'user' || role == 'assistant';
  bool get isDraft => id.startsWith('draft-');
  bool get isVoiceTranscriptionPending =>
      metadata?['voice_transcription_pending'] == true;
  bool get isVoiceUploadPending => metadata?['voice_upload_pending'] == true;
  int? get voicePendingDurationSeconds {
    final raw = metadata?['voice_duration_seconds'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  String? get clientId => metadata?['client_id'] as String?;
  AchievementItem? get achievementItem {
    final raw = metadata?['achievement'];
    if (raw is Map) return AchievementItem.fromJson(raw);
    return null;
  }

  ChatComponentCard? get componentCard {
    final raw = metadata?['component_card'] ?? metadata?['componentCard'];
    return raw is Map ? ChatComponentCard.fromJson(raw) : null;
  }

  List<ChatAttachment> get attachments {
    final raw = metadata?['attachments'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map)
          ChatAttachment.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  /// 思绪碎片气泡（识图命中后后端推送）：
  /// metadata.offline_fragment = {fragment_id, tier, lead_in, source_message_id}
  Map<String, dynamic>? get offlineThoughtFragment {
    final raw = metadata?['offline_fragment'];
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  /// 该用户图片消息是否已被识图命中（用于在图片气泡上叠「偶遇一缕思绪」提示）。
  bool get offlineRecognized => metadata?['offline_recognized'] == true;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String? ?? '',
      conversationId: json['conversation_id'] as String? ?? '',
      role: json['role'] as String? ?? 'assistant',
      content: json['content'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
      // The backend has no read receipt field: a message returned by the
      // server is by definition persisted and delivered to the agent, which
      // is exactly what the read indicator means (same semantics as web,
      // where DB-loaded history is always treated as read). Without this,
      // history rendered as unread and the post-reply history reconcile
      // flipped freshly acked messages back to unread.
      read: true,
    );
  }

  factory ChatMessage.draft({
    required String conversationId,
    required String role,
    required String content,
    String? clientId,
    Map<String, dynamic>? metadata,
  }) {
    final id =
        clientId ??
        'draft-${DateTime.now().microsecondsSinceEpoch}-${content.hashCode}';
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      role: role,
      content: content,
      createdAt: DateTime.now(),
      metadata: {...?metadata, if (clientId != null) 'client_id': clientId},
      pending: true,
      read: false,
    );
  }

  factory ChatMessage.achievement({
    required String conversationId,
    required AchievementItem item,
    String? id,
    DateTime? createdAt,
  }) {
    final unlockedAt = createdAt ?? item.unlockedAt ?? DateTime.now();
    return ChatMessage(
      id: id ?? 'achievement-${item.id}-${unlockedAt.microsecondsSinceEpoch}',
      conversationId: conversationId,
      role: 'achievement',
      content: item.name,
      createdAt: unlockedAt,
      metadata: {'achievement': item.toJson()},
      pending: false,
      read: true,
    );
  }

  ChatMessage copyWith({
    String? id,
    Map<String, dynamic>? metadata,
    bool? pending,
    bool? read,
    bool? failed,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId,
      role: role,
      content: content,
      createdAt: createdAt,
      metadata: metadata ?? this.metadata,
      pending: pending ?? this.pending,
      read: read ?? this.read,
      failed: failed ?? this.failed,
    );
  }
}

/// One hit from `GET /conversations/{id}/messages/search`. Wraps a real
/// [ChatMessage] (the search response's per-item fields are a superset of
/// [MessageResponse]) instead of duplicating message parsing, so search
/// results render through the exact same bubble/card widgets as live chat.
class MessageSearchHit {
  const MessageSearchHit({
    required this.message,
    required this.matchType,
    required this.rank,
    this.matchedAttachmentId,
  });

  final ChatMessage message;
  final String matchType; // 'text' | 'card' | 'image'
  final int rank;
  final String? matchedAttachmentId;

  factory MessageSearchHit.fromJson(Map<String, dynamic> json) {
    return MessageSearchHit(
      message: ChatMessage.fromJson(json),
      matchType: json['match_type'] as String? ?? 'text',
      rank: (json['rank'] as num?)?.round() ?? 0,
      matchedAttachmentId: json['matched_attachment_id'] as String?,
    );
  }

  MessageSearchHit copyWith({ChatMessage? message}) {
    return MessageSearchHit(
      message: message ?? this.message,
      matchType: matchType,
      rank: rank,
      matchedAttachmentId: matchedAttachmentId,
    );
  }
}

class MessageSearchResult {
  const MessageSearchResult({
    required this.text,
    required this.cards,
    required this.images,
    required this.hasMoreText,
    required this.hasMoreCards,
    required this.hasMoreImages,
  });

  final List<MessageSearchHit> text;
  final List<MessageSearchHit> cards;
  final List<MessageSearchHit> images;
  final bool hasMoreText;
  final bool hasMoreCards;
  final bool hasMoreImages;

  static List<MessageSearchHit> _hits(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map)
          MessageSearchHit.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  factory MessageSearchResult.fromJson(Map<String, dynamic> json) {
    return MessageSearchResult(
      text: _hits(json['text']),
      cards: _hits(json['cards']),
      images: _hits(json['images']),
      hasMoreText: json['has_more_text'] == true,
      hasMoreCards: json['has_more_cards'] == true,
      hasMoreImages: json['has_more_images'] == true,
    );
  }
}

class ChatAttachment {
  const ChatAttachment({
    required this.id,
    required this.kind,
    required this.mime,
    required this.size,
    required this.url,
    this.name,
    this.width,
    this.height,
    this.durationSeconds,
    this.visionStatus = 'pending',
    this.visionSummary,
    this.transcriptionStatus,
    this.transcriptionText,
    this.transcriptionModel,
    this.transcriptionRequestId,
    this.createdAt,
  });

  final String id;
  final String kind;
  final String? name;
  final String mime;
  final int size;
  final int? width;
  final int? height;
  final int? durationSeconds;
  final String url;
  final String visionStatus;
  final String? visionSummary;
  final String? transcriptionStatus;
  final String? transcriptionText;
  final String? transcriptionModel;
  final String? transcriptionRequestId;
  final DateTime? createdAt;

  bool get isImage => kind == 'image' && url.trim().isNotEmpty;
  bool get isAudio => kind == 'audio' && url.trim().isNotEmpty;
  bool get showsAsVoice => isAudio;

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      id: json['id'] as String? ?? '',
      kind: json['kind'] as String? ?? 'image',
      name: json['name'] as String?,
      mime: json['mime'] as String? ?? 'image/jpeg',
      size: (json['size'] as num?)?.round() ?? 0,
      width: (json['width'] as num?)?.round(),
      height: (json['height'] as num?)?.round(),
      durationSeconds: (json['duration_seconds'] as num?)?.round(),
      url: json['url'] as String? ?? '',
      visionStatus: json['vision_status'] as String? ?? 'pending',
      visionSummary: json['vision_summary'] as String?,
      transcriptionStatus: json['transcription_status'] as String?,
      transcriptionText: json['transcription_text'] as String?,
      transcriptionModel: json['transcription_model'] as String?,
      transcriptionRequestId: json['transcription_request_id'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kind': kind,
      'name': name,
      'mime': mime,
      'size': size,
      'width': width,
      'height': height,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      'url': url,
      'vision_status': visionStatus,
      if (visionSummary != null && visionSummary!.isNotEmpty)
        'vision_summary': visionSummary,
      if (transcriptionStatus != null)
        'transcription_status': transcriptionStatus,
      if (transcriptionText != null && transcriptionText!.isNotEmpty)
        'transcription_text': transcriptionText,
      if (transcriptionModel != null) 'transcription_model': transcriptionModel,
      if (transcriptionRequestId != null)
        'transcription_request_id': transcriptionRequestId,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  ChatAttachment copyWith({String? url}) {
    return ChatAttachment(
      id: id,
      kind: kind,
      name: name,
      mime: mime,
      size: size,
      width: width,
      height: height,
      durationSeconds: durationSeconds,
      url: url ?? this.url,
      visionStatus: visionStatus,
      visionSummary: visionSummary,
      transcriptionStatus: transcriptionStatus,
      transcriptionText: transcriptionText,
      transcriptionModel: transcriptionModel,
      transcriptionRequestId: transcriptionRequestId,
      createdAt: createdAt,
    );
  }
}

class ChatAudioTranscription {
  const ChatAudioTranscription({
    required this.text,
    required this.durationSeconds,
    required this.model,
    this.attachment,
    this.requestId,
  });

  final String text;
  final ChatAttachment? attachment;
  final int durationSeconds;
  final String model;
  final String? requestId;
}

class DailySharePhotoGroup {
  const DailySharePhotoGroup({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.photos,
  });

  final String id;
  final String title;
  final String subtitle;
  final int count;
  final List<ChatAttachment> photos;

  factory DailySharePhotoGroup.fromJson(Map<String, dynamic> json) {
    final rawPhotos = json['photos'];
    return DailySharePhotoGroup(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      count: (json['count'] as num?)?.round() ?? 0,
      photos: [
        if (rawPhotos is List)
          for (final item in rawPhotos)
            if (item is Map)
              ChatAttachment.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }

  DailySharePhotoGroup copyWith({List<ChatAttachment>? photos}) {
    return DailySharePhotoGroup(
      id: id,
      title: title,
      subtitle: subtitle,
      count: count,
      photos: photos ?? this.photos,
    );
  }
}

class DailySharePhotosResponse {
  const DailySharePhotosResponse({required this.total, required this.groups});

  final int total;
  final List<DailySharePhotoGroup> groups;

  factory DailySharePhotosResponse.fromJson(Map<String, dynamic> json) {
    final rawGroups = json['groups'];
    return DailySharePhotosResponse(
      total: (json['total'] as num?)?.round() ?? 0,
      groups: [
        if (rawGroups is List)
          for (final item in rawGroups)
            if (item is Map)
              DailySharePhotoGroup.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }
}

class ChatComponentCard {
  const ChatComponentCard({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.footer,
    this.accent = '#7C3CFF',
    this.payload = const {},
    this.version = 1,
  });

  final int version;
  final String type;
  final String title;
  final String subtitle;
  final String body;
  final String footer;
  final String accent;
  final Map<String, dynamic> payload;

  factory ChatComponentCard.fromJson(Map<dynamic, dynamic> json) {
    return ChatComponentCard(
      version: (json['version'] as num?)?.round() ?? 1,
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      footer: json['footer']?.toString() ?? '',
      accent: json['accent']?.toString() ?? '#7C3CFF',
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'body': body,
      'footer': footer,
      'accent': accent,
      'payload': payload,
    };
  }
}

class ChatLinkCardResponse {
  const ChatLinkCardResponse({
    required this.id,
    required this.conversationId,
    required this.sourceUrl,
    required this.finalUrl,
    required this.platform,
    required this.title,
    required this.componentCard,
    this.messageId,
    this.role = 'user',
    this.sourceApp,
    this.description = '',
    this.author,
    this.imageUrl,
    this.summary = '',
    this.status = 'ready',
    this.error,
    this.createdAt,
  });

  final String id;
  final String conversationId;
  final String? messageId;
  final String role;
  final String? sourceApp;
  final String sourceUrl;
  final String finalUrl;
  final String platform;
  final String title;
  final String description;
  final String? author;
  final String? imageUrl;
  final String summary;
  final String status;
  final String? error;
  final DateTime? createdAt;
  final ChatComponentCard componentCard;

  factory ChatLinkCardResponse.fromJson(Map<String, dynamic> json) {
    return ChatLinkCardResponse(
      id: json['id'] as String? ?? '',
      conversationId: json['conversation_id'] as String? ?? '',
      messageId: json['message_id'] as String?,
      role: json['role'] as String? ?? 'user',
      sourceApp: json['source_app'] as String?,
      sourceUrl: json['source_url'] as String? ?? '',
      finalUrl: json['final_url'] as String? ?? '',
      platform: json['platform'] as String? ?? '链接',
      title: json['title'] as String? ?? '未命名链接',
      description: json['description'] as String? ?? '',
      author: json['author'] as String?,
      imageUrl: json['image_url'] as String?,
      summary: json['summary'] as String? ?? '',
      status: json['status'] as String? ?? 'ready',
      error: json['error'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      componentCard: ChatComponentCard.fromJson(
        json['component_card'] is Map
            ? json['component_card'] as Map
            : const <String, dynamic>{},
      ),
    );
  }
}

class DailyShareLink {
  const DailyShareLink({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.sourceUrl,
    required this.finalUrl,
    required this.platform,
    required this.title,
    required this.componentCard,
    this.messageId,
    this.sourceApp,
    this.description = '',
    this.author,
    this.imageUrl,
    this.summary = '',
    this.createdAt,
  });

  final String id;
  final String? messageId;
  final String conversationId;
  final String role;
  final String? sourceApp;
  final String sourceUrl;
  final String finalUrl;
  final String platform;
  final String title;
  final String description;
  final String? author;
  final String? imageUrl;
  final String summary;
  final DateTime? createdAt;
  final ChatComponentCard componentCard;

  factory DailyShareLink.fromJson(Map<String, dynamic> json) {
    return DailyShareLink(
      id: json['id'] as String? ?? '',
      messageId: json['message_id'] as String?,
      conversationId: json['conversation_id'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      sourceApp: json['source_app'] as String?,
      sourceUrl: json['source_url'] as String? ?? '',
      finalUrl: json['final_url'] as String? ?? '',
      platform: json['platform'] as String? ?? '链接',
      title: json['title'] as String? ?? '未命名链接',
      description: json['description'] as String? ?? '',
      author: json['author'] as String?,
      imageUrl: json['image_url'] as String?,
      summary: json['summary'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      componentCard: ChatComponentCard.fromJson(
        json['component_card'] is Map
            ? json['component_card'] as Map
            : const <String, dynamic>{},
      ),
    );
  }
}

class DailyShareLinkGroup {
  const DailyShareLinkGroup({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.links,
  });

  final String id;
  final String title;
  final String subtitle;
  final int count;
  final List<DailyShareLink> links;

  factory DailyShareLinkGroup.fromJson(Map<String, dynamic> json) {
    final rawLinks = json['links'];
    return DailyShareLinkGroup(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      count: (json['count'] as num?)?.round() ?? 0,
      links: [
        if (rawLinks is List)
          for (final item in rawLinks)
            if (item is Map)
              DailyShareLink.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }
}

class DailyShareLinksResponse {
  const DailyShareLinksResponse({required this.total, required this.groups});

  final int total;
  final List<DailyShareLinkGroup> groups;

  factory DailyShareLinksResponse.fromJson(Map<String, dynamic> json) {
    final rawGroups = json['groups'];
    return DailyShareLinksResponse(
      total: (json['total'] as num?)?.round() ?? 0,
      groups: [
        if (rawGroups is List)
          for (final item in rawGroups)
            if (item is Map)
              DailyShareLinkGroup.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }
}

class AchievementItem {
  const AchievementItem({
    required this.id,
    required this.category,
    required this.name,
    required this.popupText,
    required this.conditionText,
    required this.ruleText,
    required this.levelName,
    required this.score,
    required this.unlocked,
    this.unlockedAt,
  });

  final int id;
  final String category;
  final String name;
  final String popupText;
  final String conditionText;
  final String ruleText;
  final String levelName;
  final int score;
  final bool unlocked;
  final DateTime? unlockedAt;

  factory AchievementItem.fromJson(Map<dynamic, dynamic> json) {
    final rawId = json['achievement_id'] ?? json['id'];
    return AchievementItem(
      id: (rawId as num?)?.round() ?? 0,
      category: json['category']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      popupText: json['popup_text']?.toString() ?? '',
      conditionText: json['condition_text']?.toString() ?? '',
      ruleText: json['rule_text']?.toString() ?? '',
      levelName: json['level_name']?.toString() ?? '',
      score: (json['score'] as num?)?.round() ?? 0,
      unlocked: json['unlocked'] as bool? ?? false,
      unlockedAt: DateTime.tryParse(json['unlocked_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'achievement_id': id,
      'category': category,
      'name': name,
      'popup_text': popupText,
      'condition_text': conditionText,
      'rule_text': ruleText,
      'level_name': levelName,
      'score': score,
      'unlocked': unlocked,
      'unlocked_at': unlockedAt?.toIso8601String(),
    };
  }
}

class AchievementsResponse {
  const AchievementsResponse({
    required this.total,
    required this.unlocked,
    required this.score,
    required this.items,
  });

  final int total;
  final int unlocked;
  final int score;
  final List<AchievementItem> items;

  factory AchievementsResponse.fromJson(Map<String, dynamic> json) {
    return AchievementsResponse(
      total: (json['total'] as num?)?.round() ?? 0,
      unlocked: (json['unlocked'] as num?)?.round() ?? 0,
      score: (json['score'] as num?)?.round() ?? 0,
      items: (json['items'] as List? ?? const [])
          .map((item) => AchievementItem.fromJson(item as Map))
          .toList(),
    );
  }
}

int? parseRedPacketTicketAmount(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final value = int.tryParse(trimmed);
  if (value == null || value < 1 || value > 1000000) return null;
  return value;
}

const kRedPacketBlessingMaxChars = 40;
const kRedPacketDefaultBody = '给你的一点心意';

class RedPacketSendDraft {
  const RedPacketSendDraft({required this.ticketAmount, this.blessing});

  final int ticketAmount;
  final String? blessing;
}

String? normalizeRedPacketBlessing(String? raw) {
  final trimmed = (raw ?? '').trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.length <= kRedPacketBlessingMaxChars) return trimmed;
  return trimmed.substring(0, kRedPacketBlessingMaxChars);
}

int redPacketTicketAmountFromCard(ChatComponentCard card) {
  final raw = card.payload['ticket_amount'];
  if (raw is num) return raw.round();
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}

String redPacketBlessingFromCard(ChatComponentCard card) {
  final fromPayload = card.payload['blessing']?.toString().trim() ?? '';
  if (fromPayload.isNotEmpty) return fromPayload;
  final body = card.body.trim();
  return body.isEmpty ? kRedPacketDefaultBody : body;
}

class RedPacketOffering {
  const RedPacketOffering({
    required this.id,
    required this.kind,
    required this.ticketAmount,
    required this.agentValueYuan,
    required this.status,
    this.blessing,
    this.conversationId,
    this.messageId,
    required this.agentId,
    required this.createdAt,
    this.receivedAt,
    this.productKind,
    this.productTitle,
    this.productSubcategory,
    this.productAssetKey,
  });

  final String id;
  final String kind;
  final int ticketAmount;
  final int agentValueYuan;
  final String status;
  final String? blessing;
  final String? conversationId;
  final String? messageId;
  final String agentId;
  final String createdAt;
  final String? receivedAt;
  final String? productKind;
  final String? productTitle;
  final String? productSubcategory;
  final String? productAssetKey;

  bool get isReceived => status == 'received';

  factory RedPacketOffering.fromJson(Map<String, dynamic> json) {
    return RedPacketOffering(
      id: json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'red_packet',
      ticketAmount: (json['ticket_amount'] as num?)?.round() ?? 0,
      agentValueYuan: (json['agent_value_yuan'] as num?)?.round() ?? 0,
      status: json['status']?.toString() ?? 'sent',
      blessing: json['blessing']?.toString(),
      conversationId: json['conversation_id']?.toString(),
      messageId: json['message_id']?.toString(),
      agentId: json['agent_id']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      receivedAt: json['received_at']?.toString(),
      productKind: json['product_kind']?.toString(),
      productTitle: json['product_title']?.toString(),
      productSubcategory: json['product_subcategory']?.toString(),
      productAssetKey: json['product_asset_key']?.toString(),
    );
  }
}

class RedPacketSendResult {
  const RedPacketSendResult({
    required this.offering,
    required this.componentCard,
    this.wallet,
  });

  final RedPacketOffering offering;
  final ChatComponentCard componentCard;
  final WalletBalance? wallet;

  factory RedPacketSendResult.fromJson(Map<String, dynamic> json) {
    final rawCard = json['component_card'];
    final rawWallet = json['wallet'];
    return RedPacketSendResult(
      offering: RedPacketOffering.fromJson(
        Map<String, dynamic>.from(json['offering'] as Map? ?? const {}),
      ),
      componentCard: ChatComponentCard.fromJson(
        rawCard is Map ? rawCard : const {},
      ),
      wallet: rawWallet is Map
          ? WalletBalance.fromJson(Map<String, dynamic>.from(rawWallet))
          : null,
    );
  }
}

class GiftSendResult {
  const GiftSendResult({
    required this.offering,
    required this.componentCard,
    this.wallet,
    this.inventoryItem,
  });

  final RedPacketOffering offering;
  final ChatComponentCard componentCard;
  final WalletBalance? wallet;
  final StoreInventoryItem? inventoryItem;

  factory GiftSendResult.fromJson(Map<String, dynamic> json) {
    final rawCard = json['component_card'];
    final rawWallet = json['wallet'];
    final inventory = json['inventory_item'];
    return GiftSendResult(
      offering: RedPacketOffering.fromJson(
        Map<String, dynamic>.from(json['offering'] as Map? ?? const {}),
      ),
      componentCard: ChatComponentCard.fromJson(
        rawCard is Map ? rawCard : const {},
      ),
      wallet: rawWallet is Map
          ? WalletBalance.fromJson(Map<String, dynamic>.from(rawWallet))
          : null,
      inventoryItem: inventory is Map
          ? StoreInventoryItem.fromJson(Map<String, dynamic>.from(inventory))
          : null,
    );
  }
}


class WsEnvelope {
  const WsEnvelope({required this.type, required this.data});

  final String type;
  final Map<String, dynamic> data;

  factory WsEnvelope.fromJson(Map<String, dynamic> json) {
    return WsEnvelope(
      type: json['type'] as String? ?? '',
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : const {},
    );
  }
}
