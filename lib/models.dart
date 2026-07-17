enum UserRole { user, admin }

UserRole parseUserRole(String value) {
  return value == 'admin' ? UserRole.admin : UserRole.user;
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.userId,
    required this.username,
    required this.role,
    required this.hasAgent,
    this.userDisplayName,
    this.userAvatarUrl,
    this.agentId,
    this.agentName,
    this.agentAvatarKey,
    this.agentAvatarUrl,
    this.agentCity,
    this.workspaceId,
    this.conversationId,
  });

  final String token;
  final String userId;
  final String username;
  final String? userDisplayName;
  final String? userAvatarUrl;
  final UserRole role;
  final bool hasAgent;
  final String? agentId;
  final String? agentName;
  final String? agentAvatarKey;
  final String? agentAvatarUrl;
  final String? agentCity;
  final String? workspaceId;
  final String? conversationId;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: json['token'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      userDisplayName: json['user_display_name'] as String?,
      userAvatarUrl: json['user_avatar_url'] as String?,
      role: parseUserRole(json['role'] as String? ?? 'user'),
      hasAgent: json['has_agent'] as bool? ?? false,
      agentId: json['agent_id'] as String?,
      agentName: json['agent_name'] as String?,
      agentAvatarKey: json['agent_avatar_key'] as String?,
      agentAvatarUrl: json['agent_avatar_url'] as String?,
      agentCity: json['agent_city'] as String?,
      workspaceId: json['workspace_id'] as String?,
      conversationId: json['conversation_id'] as String?,
    );
  }

  AuthSession copyWith({
    String? userDisplayName,
    String? userAvatarUrl,
    String? agentName,
    String? agentAvatarKey,
    String? agentAvatarUrl,
    String? agentCity,
    String? workspaceId,
    String? conversationId,
  }) {
    return AuthSession(
      token: token,
      userId: userId,
      username: username,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      role: role,
      hasAgent: hasAgent,
      agentId: agentId,
      agentName: agentName ?? this.agentName,
      agentAvatarKey: agentAvatarKey ?? this.agentAvatarKey,
      agentAvatarUrl: agentAvatarUrl ?? this.agentAvatarUrl,
      agentCity: agentCity ?? this.agentCity,
      workspaceId: workspaceId ?? this.workspaceId,
      conversationId: conversationId ?? this.conversationId,
    );
  }
}

class AgentProfile {
  const AgentProfile({
    required this.id,
    required this.name,
    required this.userId,
    this.workspaceId,
    this.gender,
    this.city,
    this.avatarKey,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String userId;
  final String? workspaceId;
  final String? gender;
  final String? city;
  final String? avatarKey;
  final String? avatarUrl;

  factory AgentProfile.fromJson(Map<String, dynamic> json) {
    return AgentProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      workspaceId: json['workspace_id'] as String?,
      gender: json['gender'] as String?,
      city: json['city'] as String?,
      avatarKey: json['avatar_key'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}

class ProfileStats {
  const ProfileStats({
    required this.workspaceId,
    required this.intimacyStage,
    required this.intimacyStageLabel,
    required this.topicIntimacy,
    required this.intimacySubtitle,
    required this.companionDays,
    required this.companionStartedOn,
    required this.chatHours,
    required this.chatMinutes,
    required this.chatDurationLabel,
    required this.chatDurationSubtitle,
    required this.messageCount,
    required this.recent7dMessageCount,
    required this.recent7dMessageLabel,
    required this.companionSummary,
    required this.backpackCount,
    required this.memberIsActive,
    required this.memberExpiresOn,
  });

  final String workspaceId;
  final String intimacyStage;
  final String intimacyStageLabel;
  final double topicIntimacy;
  final String intimacySubtitle;
  final int companionDays;
  final String? companionStartedOn;
  final int chatHours;
  final int chatMinutes;
  final String chatDurationLabel;
  final String chatDurationSubtitle;
  final int messageCount;
  final int recent7dMessageCount;
  final String recent7dMessageLabel;
  final String companionSummary;
  final int backpackCount;
  final bool memberIsActive;
  final String? memberExpiresOn;

  factory ProfileStats.fromJson(Map<String, dynamic> json) {
    final companionDays = (json['companion_days'] as num?)?.round() ?? 0;
    final chatHours = (json['chat_hours'] as num?)?.round() ?? 0;
    final chatMinutes =
        (json['chat_minutes'] as num?)?.round() ?? chatHours * 60;
    final recent7d = (json['recent_7d_message_count'] as num?)?.round() ?? 0;
    return ProfileStats(
      workspaceId: json['workspace_id'] as String? ?? '',
      intimacyStage: json['intimacy_stage'] as String? ?? 'P1',
      intimacyStageLabel: json['intimacy_stage_label'] as String? ?? '初见陪伴',
      topicIntimacy: (json['topic_intimacy'] as num?)?.toDouble() ?? 0,
      intimacySubtitle: json['intimacy_subtitle'] as String? ?? '故事刚刚开始',
      companionDays: companionDays,
      companionStartedOn: json['companion_started_on'] as String?,
      chatHours: chatHours,
      chatMinutes: chatMinutes,
      chatDurationLabel:
          json['chat_duration_label'] as String? ??
          _formatDuration(chatMinutes),
      chatDurationSubtitle:
          json['chat_duration_subtitle'] as String? ?? '累计聊天时长',
      messageCount: (json['message_count'] as num?)?.round() ?? 0,
      recent7dMessageCount: recent7d,
      recent7dMessageLabel:
          json['recent_7d_message_label'] as String? ?? '近7天 +$recent7d条',
      companionSummary: json['companion_summary'] as String? ?? '唯一伴生对象',
      backpackCount: (json['backpack_count'] as num?)?.round() ?? 0,
      memberIsActive: json['member_is_active'] as bool? ?? false,
      memberExpiresOn: json['member_expires_on'] as String?,
    );
  }

  static String _formatDuration(int minutes) {
    if (minutes <= 0) return '0m';
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    if (hours > 0 && remainder > 0) return '${hours}h${remainder}m';
    if (hours > 0) return '${hours}h';
    return '${remainder}m';
  }
}

class ChatRecordsClearResult {
  const ChatRecordsClearResult({
    required this.workspaceId,
    required this.clearedConversations,
  });

  final String workspaceId;
  final int clearedConversations;

  factory ChatRecordsClearResult.fromJson(Map<String, dynamic> json) {
    return ChatRecordsClearResult(
      workspaceId: json['workspace_id'] as String? ?? '',
      clearedConversations:
          (json['cleared_conversations'] as num?)?.round() ?? 0,
    );
  }
}

class AgentProvisionStatus {
  const AgentProvisionStatus({
    required this.agentId,
    required this.status,
    required this.stage,
    required this.percent,
    required this.message,
    this.current,
    this.total,
  });

  final String agentId;
  final String status;
  final String stage;
  final int percent;
  final String message;
  final int? current;
  final int? total;

  bool get isComplete => stage == 'complete' || percent >= 100;
  bool get isFailed => stage == 'failed';

  factory AgentProvisionStatus.fromJson(Map<String, dynamic> json) {
    return AgentProvisionStatus(
      agentId: json['agent_id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      stage: json['stage'] as String? ?? 'initializing',
      percent: (json['percent'] as num?)?.round() ?? 0,
      message: json['message'] as String? ?? '正在初始化...',
      current: (json['current'] as num?)?.round(),
      total: (json['total'] as num?)?.round(),
    );
  }

  AgentProvisionStatus copyWith({
    String? status,
    String? stage,
    int? percent,
    String? message,
    int? current,
    int? total,
  }) {
    return AgentProvisionStatus(
      agentId: agentId,
      status: status ?? this.status,
      stage: stage ?? this.stage,
      percent: percent ?? this.percent,
      message: message ?? this.message,
      current: current ?? this.current,
      total: total ?? this.total,
    );
  }
}

class AgentDeleteResult {
  const AgentDeleteResult({required this.ok, required this.stats});

  final bool ok;
  final Map<String, int> stats;

  factory AgentDeleteResult.fromJson(Map<String, dynamic> json) {
    final rawStats = json['stats'];
    return AgentDeleteResult(
      ok: json['ok'] as bool? ?? false,
      stats: rawStats is Map
          ? rawStats.map(
              (key, value) =>
                  MapEntry(key.toString(), (value as num?)?.round() ?? 0),
            )
          : const {},
    );
  }
}

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
  });

  final String id;
  final String conversationId;
  final String role;
  final String content;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;
  final bool pending;
  final bool read;

  bool get isMine => role == 'user';
  bool get isAchievement => role == 'achievement';
  bool get isMusicStatus => metadata?['music_status'] != null;
  bool get isGameStatus => metadata?['game_status'] != null;
  bool get isChatMessage => role == 'user' || role == 'assistant';
  bool get isDraft => id.startsWith('draft-');
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

class WalletBalance {
  const WalletBalance({
    required this.ticketBalance,
    required this.pointBalance,
    required this.achievementPointsSynced,
  });

  final int ticketBalance;
  final int pointBalance;
  final int achievementPointsSynced;

  factory WalletBalance.fromJson(Map<String, dynamic> json) {
    return WalletBalance(
      ticketBalance: (json['ticket_balance'] as num?)?.round() ?? 0,
      pointBalance: (json['point_balance'] as num?)?.round() ?? 0,
      achievementPointsSynced:
          (json['achievement_points_synced'] as num?)?.round() ?? 0,
    );
  }
}

class StoreInventoryItem {
  const StoreInventoryItem({
    required this.productKind,
    required this.quantity,
    this.acquiredAt,
    this.updatedAt,
  });

  final String productKind;
  final int quantity;
  final DateTime? acquiredAt;
  final DateTime? updatedAt;

  factory StoreInventoryItem.fromJson(Map<String, dynamic> json) {
    return StoreInventoryItem(
      productKind: json['product_kind']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.round() ?? 0,
      acquiredAt: DateTime.tryParse(json['acquired_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }
}

class StoreInventoryResponse {
  const StoreInventoryResponse({required this.items});

  final List<StoreInventoryItem> items;

  factory StoreInventoryResponse.fromJson(Map<String, dynamic> json) {
    return StoreInventoryResponse(
      items: (json['items'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                StoreInventoryItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }
}

class StoreExchangeResponse {
  const StoreExchangeResponse({
    required this.wallet,
    required this.inventoryItem,
  });

  final WalletBalance wallet;
  final StoreInventoryItem inventoryItem;

  factory StoreExchangeResponse.fromJson(Map<String, dynamic> json) {
    return StoreExchangeResponse(
      wallet: WalletBalance.fromJson(
        Map<String, dynamic>.from(json['wallet'] as Map? ?? const {}),
      ),
      inventoryItem: StoreInventoryItem.fromJson(
        Map<String, dynamic>.from(json['inventory_item'] as Map? ?? const {}),
      ),
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

class ReminderItem {
  const ReminderItem({
    required this.id,
    required this.summary,
    required this.triggerTime,
    required this.recurrence,
    required this.status,
    required this.agentId,
    required this.createdAt,
    this.memoryId,
    this.lastFired,
    this.completedAt,
    this.retryCount = 0,
    this.pinned = false,
    this.habitWeekdays = const <int>[],
    this.completedDates = const <String>[],
    this.sentToAi = false,
  });

  final String id;
  final String? memoryId;
  final String summary;
  final DateTime triggerTime;
  final DateTime? lastFired;
  final DateTime? completedAt;
  final String recurrence;
  final String status;
  final int retryCount;
  final bool pinned;
  final List<int> habitWeekdays;
  final List<String> completedDates;
  final bool sentToAi;
  final String agentId;
  final DateTime createdAt;

  bool get isHabit => recurrence != 'once';

  factory ReminderItem.fromJson(Map<String, dynamic> json) {
    return ReminderItem(
      id: json['id'] as String? ?? '',
      memoryId: json['memory_id'] as String?,
      summary: json['summary'] as String? ?? '',
      triggerTime:
          DateTime.tryParse(json['trigger_time'] as String? ?? '') ??
          DateTime.now(),
      lastFired: DateTime.tryParse(json['last_fired'] as String? ?? ''),
      completedAt: DateTime.tryParse(json['completed_at'] as String? ?? ''),
      recurrence: json['recurrence'] as String? ?? 'once',
      status: json['status'] as String? ?? 'active',
      retryCount: (json['retry_count'] as num?)?.round() ?? 0,
      pinned: json['pinned'] as bool? ?? false,
      habitWeekdays: (json['habit_weekdays'] as List? ?? const [])
          .whereType<num>()
          .map((value) => value.round())
          .where((value) => value >= 1 && value <= 7)
          .toList(),
      completedDates: (json['completed_dates'] as List? ?? const [])
          .whereType<String>()
          .toList(),
      sentToAi: json['sent_to_ai'] as bool? ?? false,
      agentId: json['agent_id'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class RemindersResponse {
  const RemindersResponse({
    required this.items,
    required this.total,
    required this.dlqCount,
  });

  final List<ReminderItem> items;
  final int total;
  final int dlqCount;

  factory RemindersResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return RemindersResponse(
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) =>
                      ReminderItem.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
      total: (json['total'] as num?)?.round() ?? 0,
      dlqCount: (json['dlq_count'] as num?)?.round() ?? 0,
    );
  }
}

class TimeCapsule {
  const TimeCapsule({
    required this.id,
    required this.userId,
    required this.content,
    required this.status,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
    this.media,
    this.skin = 'paper',
    this.agentId,
    this.workspaceId,
    this.title,
    this.openDate,
    this.sealedAt,
    this.openedAt,
  });

  final String id;
  final String userId;
  final String? agentId;
  final String? workspaceId;
  final String? title;
  final String content;
  final Map<String, dynamic>? media;
  final String skin;
  final DateTime? openDate;
  final String status;
  final String state;
  final DateTime? sealedAt;
  final DateTime? openedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isDraft => state == 'draft';
  bool get isPending => state == 'pending';
  bool get isReady => state == 'ready';
  bool get isOpened => state == 'opened';

  String get displayTitle {
    final trimmed = title?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    final line = content
        .split('\n')
        .map((item) => item.trim())
        .firstWhere((item) => item.isNotEmpty, orElse: () => '未命名胶囊');
    return line.length > 18 ? '${line.substring(0, 18)}...' : line;
  }

  String get preview {
    final compact = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.isEmpty) return '还没有写下内容。';
    return compact;
  }

  factory TimeCapsule.fromJson(Map<String, dynamic> json) {
    return TimeCapsule(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      agentId: json['agent_id'] as String?,
      workspaceId: json['workspace_id'] as String?,
      title: json['title'] as String?,
      content: json['content'] as String? ?? '',
      media: json['media'] is Map
          ? Map<String, dynamic>.from(json['media'] as Map)
          : null,
      skin: json['skin'] as String? ?? 'paper',
      openDate: _parseDateOnly(json['open_date'] as String?),
      status: json['status'] as String? ?? 'draft',
      state: json['state'] as String? ?? 'draft',
      sealedAt: DateTime.tryParse(json['sealed_at'] as String? ?? ''),
      openedAt: DateTime.tryParse(json['opened_at'] as String? ?? ''),
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class LastWillContact {
  const LastWillContact({required this.name, this.email, this.phone});

  final String name;
  final String? email;
  final String? phone;

  bool get hasChannel =>
      (email != null && email!.trim().isNotEmpty) ||
      (phone != null && phone!.trim().isNotEmpty);

  factory LastWillContact.fromJson(Map<String, dynamic> json) {
    return LastWillContact(
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name.trim(),
      if (email != null && email!.trim().isNotEmpty) 'email': email!.trim(),
      if (phone != null && phone!.trim().isNotEmpty) 'phone': phone!.trim(),
    };
  }
}

class LastWill {
  const LastWill({
    required this.id,
    required this.userId,
    required this.content,
    required this.inactivityDays,
    required this.contacts,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.agentId,
    this.workspaceId,
    this.lastSeenAt,
    this.startedAt,
    this.triggeredAt,
    this.deliveredAt,
  });

  final String id;
  final String userId;
  final String? agentId;
  final String? workspaceId;
  final String content;
  final int inactivityDays;
  final List<LastWillContact> contacts;
  final String status;
  final DateTime? lastSeenAt;
  final DateTime? startedAt;
  final DateTime? triggeredAt;
  final DateTime? deliveredAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive => status == 'active';
  bool get isTriggered => status == 'triggered';
  bool get hasContent => content.trim().isNotEmpty;

  String get preview {
    final compact = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.isEmpty) return '还没有写下内容。';
    return compact.length > 42 ? '${compact.substring(0, 42)}...' : compact;
  }

  factory LastWill.fromJson(Map<String, dynamic> json) {
    final rawContacts = json['contacts'];
    final contacts = rawContacts is List
        ? rawContacts
              .whereType<Map>()
              .map(
                (item) =>
                    LastWillContact.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <LastWillContact>[];
    return LastWill(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      agentId: json['agent_id'] as String?,
      workspaceId: json['workspace_id'] as String?,
      content: json['content'] as String? ?? '',
      inactivityDays: (json['inactivity_days'] as num?)?.round() ?? 30,
      contacts: contacts,
      status: json['status'] as String? ?? 'draft',
      lastSeenAt: DateTime.tryParse(json['last_seen_at'] as String? ?? ''),
      startedAt: DateTime.tryParse(json['started_at'] as String? ?? ''),
      triggeredAt: DateTime.tryParse(json['triggered_at'] as String? ?? ''),
      deliveredAt: DateTime.tryParse(json['delivered_at'] as String? ?? ''),
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

DateTime? _parseDateOnly(String? value) {
  if (value == null || value.isEmpty) return null;
  final parts = value.split('-');
  if (parts.length < 3) return DateTime.tryParse(value);
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
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

class MusicTrack {
  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.library,
    required this.url,
    required this.durationSec,
    required this.coverKey,
    required this.accentA,
    required this.accentB,
    required this.source,
    required this.isFavorite,
    required this.playedByAgent,
    this.metadata = const {},
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final String library;
  final String url;
  final int durationSec;
  final String coverKey;
  final String accentA;
  final String accentB;
  final String source;
  final bool isFavorite;
  final bool playedByAgent;
  final Map<String, dynamic> metadata;

  String? get coverImageUrl {
    final direct =
        _metadataString(metadata['image']) ??
        _metadataString(metadata['album_image']) ??
        _metadataString(metadata['cover_image']) ??
        _metadataString(metadata['cover_url']);
    if (direct != null) return direct;
    final raw = metadata['raw'];
    if (raw is Map) {
      return _metadataString(raw['image']) ??
          _metadataString(raw['album_image']) ??
          _metadataString(raw['cover_image']) ??
          _metadataString(raw['cover_url']);
    }
    return null;
  }

  String get coverAsset => 'assets/prototype/music/$visualCoverKey';
  String get visualCoverKey {
    final cleanCover = coverKey.trim();
    final generatedSource = source == 'jamendo' || source == 'mock';
    if (!generatedSource &&
        cleanCover.isNotEmpty &&
        cleanCover != 'music-cover-01.jpg') {
      return cleanCover;
    }
    final seed = '$id|$title|$url|$library';
    var hash = 17;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    final index = (hash % 11) + 1;
    return 'music-cover-${index.toString().padLeft(2, '0')}.jpg';
  }

  static String? _metadataString(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text == 'null') return null;
    if (!text.startsWith('http://') && !text.startsWith('https://')) {
      return null;
    }
    return text;
  }

  String get durationLabel {
    if (durationSec <= 0) return '--:--';
    final minutes = durationSec ~/ 60;
    final seconds = durationSec % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  factory MusicTrack.fromJson(Map<String, dynamic> json) {
    return MusicTrack(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Audio',
      artist: json['artist'] as String? ?? 'Jamendo',
      album: json['album'] as String? ?? 'Jamendo Library',
      library: json['library'] as String? ?? 'focus',
      url: json['url'] as String? ?? '',
      durationSec: (json['duration_sec'] as num?)?.round() ?? 0,
      coverKey: json['cover_key'] as String? ?? 'music-cover-01.jpg',
      accentA: json['accent_a'] as String? ?? '#1f6fff',
      accentB: json['accent_b'] as String? ?? '#18c6c0',
      source: json['source'] as String? ?? 'jamendo',
      isFavorite: json['is_favorite'] as bool? ?? false,
      playedByAgent: json['played_by_agent'] as bool? ?? false,
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'library': library,
      'url': url,
      'duration_sec': durationSec,
      'cover_key': visualCoverKey,
      'accent_a': accentA,
      'accent_b': accentB,
      'source': source,
      'metadata': metadata,
    };
  }

  MusicTrack copyWith({
    String? url,
    bool? isFavorite,
    bool? playedByAgent,
    Map<String, dynamic>? metadata,
  }) {
    return MusicTrack(
      id: id,
      title: title,
      artist: artist,
      album: album,
      library: library,
      url: url ?? this.url,
      durationSec: durationSec,
      coverKey: coverKey,
      accentA: accentA,
      accentB: accentB,
      source: source,
      isFavorite: isFavorite ?? this.isFavorite,
      playedByAgent: playedByAgent ?? this.playedByAgent,
      metadata: metadata ?? this.metadata,
    );
  }
}

class MusicTrackPlayUrl {
  const MusicTrackPlayUrl({
    required this.trackId,
    required this.url,
    this.expiresAt,
  });

  final String trackId;
  final String url;
  final DateTime? expiresAt;

  factory MusicTrackPlayUrl.fromJson(Map<String, dynamic> json) {
    final expiresRaw = json['expires_at'] as String?;
    return MusicTrackPlayUrl(
      trackId: json['track_id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      expiresAt: expiresRaw == null || expiresRaw.isEmpty
          ? null
          : DateTime.tryParse(expiresRaw),
    );
  }
}

class MusicTracksResponse {
  const MusicTracksResponse({
    required this.tracks,
    required this.apiEnabled,
    this.library,
  });

  final List<MusicTrack> tracks;
  final bool apiEnabled;
  final String? library;

  factory MusicTracksResponse.fromJson(Map<String, dynamic> json) {
    final rawTracks = json['tracks'];
    return MusicTracksResponse(
      tracks: rawTracks is List
          ? rawTracks
                .whereType<Map>()
                .map(
                  (item) =>
                      MusicTrack.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
      apiEnabled: json['api_enabled'] as bool? ?? false,
      library: json['library'] as String?,
    );
  }
}

class MusicLibrary {
  const MusicLibrary({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String title;
  final String subtitle;

  factory MusicLibrary.fromJson(Map<String, dynamic> json) {
    return MusicLibrary(
      id: json['id'] as String? ?? 'focus',
      title: json['title'] as String? ?? '专注',
      subtitle: json['subtitle'] as String? ?? '',
    );
  }
}

class MusicLibrariesResponse {
  const MusicLibrariesResponse({
    required this.libraries,
    required this.defaultLibrary,
  });

  final List<MusicLibrary> libraries;
  final String defaultLibrary;

  factory MusicLibrariesResponse.fromJson(Map<String, dynamic> json) {
    final rawLibraries = json['libraries'];
    return MusicLibrariesResponse(
      libraries: rawLibraries is List
          ? rawLibraries
                .whereType<Map>()
                .map(
                  (item) =>
                      MusicLibrary.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
      defaultLibrary: json['default_library'] as String? ?? 'focus',
    );
  }
}

class MusicPlayback {
  const MusicPlayback({
    required this.track,
    required this.positionSeconds,
    required this.isPlaying,
    this.updatedAt,
  });

  final MusicTrack? track;
  final int positionSeconds;
  final bool isPlaying;
  final DateTime? updatedAt;

  factory MusicPlayback.fromJson(Map<String, dynamic> json) {
    final rawTrack = json['track'];
    return MusicPlayback(
      track: rawTrack is Map
          ? MusicTrack.fromJson(Map<String, dynamic>.from(rawTrack))
          : null,
      positionSeconds: (json['position_seconds'] as num?)?.round() ?? 0,
      isPlaying: json['is_playing'] as bool? ?? false,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }
}

class MusicCoListening {
  const MusicCoListening({
    required this.status,
    required this.track,
    required this.positionSeconds,
    required this.isPlaying,
    this.initiatedBy,
    this.endedReason,
    this.updatedAt,
  });

  final String status;
  final MusicTrack? track;
  final int positionSeconds;
  final bool isPlaying;
  final String? initiatedBy;
  final String? endedReason;
  final DateTime? updatedAt;

  bool get isActive => status == 'active' && track != null;

  factory MusicCoListening.fromJson(Map<String, dynamic> json) {
    final rawTrack = json['track'];
    return MusicCoListening(
      status: json['status'] as String? ?? 'ended',
      track: rawTrack is Map
          ? MusicTrack.fromJson(Map<String, dynamic>.from(rawTrack))
          : null,
      positionSeconds: (json['position_seconds'] as num?)?.round() ?? 0,
      isPlaying: json['is_playing'] as bool? ?? false,
      initiatedBy: json['initiated_by'] as String?,
      endedReason: json['ended_reason'] as String?,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }
}
