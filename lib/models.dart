enum UserRole { user, admin }

UserRole parseUserRole(String value) {
  return value == 'admin' ? UserRole.admin : UserRole.user;
}

enum LoginMethod { wechat, phone, password }

/// 一种已绑定的登录方式。[label] 是直接可展示的文案（手机号已由服务端脱敏成
/// `138****5678`），[kind] 供 UI 选颜色 —— 视图层不应该去匹配文案字符串。
class LoginMethodInfo {
  const LoginMethodInfo(this.kind, this.label);

  final LoginMethod kind;
  final String label;
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
    this.phone,
    this.wechatBound = false,
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

  /// 已绑定的手机号，服务端已脱敏成 `138****5678`。未绑定为 null。
  final String? phone;
  final bool wechatBound;

  /// 账号已绑定的登录方式，用于个人资料页展示。可能同时有多个（微信 + 手机号）。
  ///
  /// [LoginMethod.password] 由**推断**得出而不是服务端字段：三种登录方式在数据
  /// 模型上互斥 —— 微信/手机号各对应一条 auth_identities 行，密码账号没有任何身份
  /// 行，所以两者都没有就只能是密码账号。密码登录目前只服务内部（登录页那个
  /// 「QQ登录」按钮打开的就是它），不值得为它单独加一个接口字段。
  List<LoginMethodInfo> get loginMethods {
    final methods = <LoginMethodInfo>[];
    if (wechatBound) {
      methods.add(const LoginMethodInfo(LoginMethod.wechat, '微信'));
    }
    final bound = phone?.trim();
    if (bound != null && bound.isNotEmpty) {
      methods.add(LoginMethodInfo(LoginMethod.phone, bound));
    }
    if (methods.isEmpty) {
      methods.add(const LoginMethodInfo(LoginMethod.password, '账号密码'));
    }
    return methods;
  }

  /// 展示用名字，为空时用 [fallback]。
  ///
  /// 优先级（自设昵称 → 微信昵称 → 用户+手机尾号）**整条都在服务端**
  /// (`services/user_profile.resolve_display_identity`)，客户端只需要挑一个场景
  /// 兜底词。这里刻意不再回落到 [username]：那对真实用户是 `wx_89b939bc004` 这类
  /// 内部 hash，历史上服务端把它塞进展示名字段，客户端不得不用正则再滤一遍——加一
  /// 种登录方式（苹果登录已经在登录页上了）正则就会漏。
  String displayNameOr(String fallback) {
    final name = userDisplayName?.trim();
    return name == null || name.isEmpty ? fallback : name;
  }

  /// 对局页/胶囊等第一人称场景的名字。
  String get userFacingName => displayNameOr('我');

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
      phone: json['phone'] as String?,
      wechatBound: json['wechat_bound'] as bool? ?? false,
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
      // 绑定状态只由服务端给出，没有参数可以本地改 —— 但必须在这里透传，否则每次
      // 改昵称/头像都会把它清掉。
      phone: phone,
      wechatBound: wechatBound,
    );
  }
}

/// 用户在圆形取景框里框定的正方形，坐标是**源图像素**（EXIF 校正后）。
///
/// 不在客户端出成品图: Flutter 只能编码 PNG，一张 512² 的照片 PNG 约 400KB，
/// 而服务端本来就要重新编码一遍。传原图 + 这个矩形，线上体积就是 picker 输出
/// 的那张 JPEG（约 150-250KB），裁剪由服务端的 Pillow 精确完成。
class AvatarCropRect {
  const AvatarCropRect({required this.x, required this.y, required this.size});

  final int x;
  final int y;
  final int size;
}

/// 昵称 / 头像修改的回执（`PATCH /users/me/profile`、`POST /users/me/avatar`）。
///
/// 服务端返回的是**解析后**的展示身份，不是刚提交的原值：只改了昵称时
/// [avatarUrl] 仍是当前生效的头像（可能来自微信回落），调用方直接
/// `session.copyWith` 就能让两个字段同时对齐。
class UserProfileUpdateResult {
  const UserProfileUpdateResult({this.displayName, this.avatarUrl});

  final String? displayName;
  final String? avatarUrl;

  factory UserProfileUpdateResult.fromJson(Map<String, dynamic> json) {
    return UserProfileUpdateResult(
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
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

int? parseRedPacketTicketAmount(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final value = int.tryParse(trimmed);
  if (value == null || value < 1 || value > 1000000) return null;
  return value;
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

class WalletBalance {
  const WalletBalance({
    required this.ticketBalance,
    required this.pointBalance,
    required this.achievementPointsSynced,
    this.giftTicketBalance = 0,
  });

  final int ticketBalance;
  final int pointBalance;
  final int achievementPointsSynced;

  /// VIP 每月赠送的限时钞票（随 VIP 存续结转，过期即清零）。花费时优先扣
  /// 这部分而非 [ticketBalance]，见 companion_api.dart:getVipStatus 附近说明。
  final int giftTicketBalance;

  /// 可花费的钞票总额 = 限时赠送 + 永久，跟商城/聊天/音乐超额提示保持一致。
  int get spendableTickets => ticketBalance + giftTicketBalance;

  factory WalletBalance.fromJson(Map<String, dynamic> json) {
    return WalletBalance(
      ticketBalance: (json['ticket_balance'] as num?)?.round() ?? 0,
      pointBalance: (json['point_balance'] as num?)?.round() ?? 0,
      achievementPointsSynced:
          (json['achievement_points_synced'] as num?)?.round() ?? 0,
      giftTicketBalance: (json['gift_ticket_balance'] as num?)?.round() ?? 0,
    );
  }
}

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
      'quit_below_threshold': {
        'threshold': 128,
        'below': -2,
        'at_or_above': 0,
      },
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

class StoreCatalogStatus {
  const StoreCatalogStatus({
    required this.isVip,
    required this.vipTrialAvailable,
  });

  final bool isVip;
  final bool vipTrialAvailable;

  factory StoreCatalogStatus.fromJson(Map<String, dynamic> json) {
    return StoreCatalogStatus(
      isVip: json['is_vip'] == true,
      vipTrialAvailable: json['vip_trial_available'] != false,
    );
  }
}

/// 统一 VIP 状态：`GET /me/vip`，供 Store/Profile/Chat/Music 共用一个来源，
/// 避免各屏各自查一遍 (见后端 CLAUDE.md 权益项总览)。
class VipStatus {
  const VipStatus({
    required this.isVip,
    required this.vipUntil,
    required this.vipTrialAvailable,
    required this.giftTicketBalance,
    required this.ticketBalance,
    required this.pointBalance,
    required this.spendableTickets,
  });

  final bool isVip;
  final DateTime? vipUntil;
  final bool vipTrialAvailable;
  final int giftTicketBalance;
  final int ticketBalance;
  final int pointBalance;
  final int spendableTickets;

  factory VipStatus.fromJson(Map<String, dynamic> json) {
    return VipStatus(
      isVip: json['is_vip'] == true,
      vipUntil: json['vip_until'] == null
          ? null
          : DateTime.tryParse(json['vip_until'].toString()),
      vipTrialAvailable: json['vip_trial_available'] == true,
      giftTicketBalance: (json['gift_ticket_balance'] as num?)?.round() ?? 0,
      ticketBalance: (json['ticket_balance'] as num?)?.round() ?? 0,
      pointBalance: (json['point_balance'] as num?)?.round() ?? 0,
      spendableTickets: (json['spendable_tickets'] as num?)?.round() ?? 0,
    );
  }
}

/// 对话额度预检：`GET /chat/quota`。发送前用它判断要不要弹确认框。
enum ChatQuotaMode { free, paid, blocked }

class ChatQuota {
  const ChatQuota({
    required this.mode,
    required this.freeRemaining,
    required this.perMsgCost,
    required this.spendableTickets,
  });

  final ChatQuotaMode mode;
  final int freeRemaining;
  final double perMsgCost;
  final int spendableTickets;

  factory ChatQuota.fromJson(Map<String, dynamic> json) {
    return ChatQuota(
      mode: _parseChatQuotaMode(json['mode']?.toString()),
      freeRemaining: (json['free_remaining'] as num?)?.round() ?? 0,
      perMsgCost: (json['per_msg_cost'] as num?)?.toDouble() ?? 0,
      spendableTickets: (json['spendable_tickets'] as num?)?.round() ?? 0,
    );
  }
}

ChatQuotaMode _parseChatQuotaMode(String? value) {
  switch (value) {
    case 'paid':
      return ChatQuotaMode.paid;
    case 'blocked':
      return ChatQuotaMode.blocked;
    default:
      return ChatQuotaMode.free;
  }
}

/// 服务端对一次 WS 发送的拒绝：额度耗尽后未确认付费，或余额不足。
enum ChatQuotaBlockReason { paidConfirm, noTicket }

class ChatQuotaBlocked {
  const ChatQuotaBlocked({
    required this.reason,
    required this.perMsgCost,
    required this.spendableTickets,
    this.clientId,
  });

  final ChatQuotaBlockReason reason;
  final double perMsgCost;
  final int spendableTickets;

  /// 被拒消息的 client_id，用于精确摘掉对应草稿（用户连发多条时，"摘最后
  /// 一条待发消息" 这个启发式可能摘错）。旧版服务端可能不带这个字段。
  final String? clientId;

  factory ChatQuotaBlocked.fromJson(Map<String, dynamic> json) {
    return ChatQuotaBlocked(
      reason: json['reason'] == 'no_ticket'
          ? ChatQuotaBlockReason.noTicket
          : ChatQuotaBlockReason.paidConfirm,
      perMsgCost: (json['per_msg_cost'] as num?)?.toDouble() ?? 0,
      spendableTickets: (json['spendable_tickets'] as num?)?.round() ?? 0,
      clientId: json['client_id']?.toString(),
    );
  }
}

/// 音乐时长上报结果：`POST /music/quota/report`。
enum MusicQuotaAction { none, confirmTicket, buyCoupon, buyVip }

class MusicQuotaReport {
  const MusicQuotaReport({
    required this.action,
    required this.acceptedSeconds,
    required this.pendingSeconds,
    required this.ticketCost,
  });

  final MusicQuotaAction action;
  final int acceptedSeconds;
  final int pendingSeconds;
  final int ticketCost;

  factory MusicQuotaReport.fromJson(Map<String, dynamic> json) {
    return MusicQuotaReport(
      action: _parseMusicQuotaAction(json['action']?.toString()),
      acceptedSeconds: (json['accepted_seconds'] as num?)?.round() ?? 0,
      pendingSeconds: (json['pending_seconds'] as num?)?.round() ?? 0,
      ticketCost: (json['ticket_cost'] as num?)?.round() ?? 0,
    );
  }
}

MusicQuotaAction _parseMusicQuotaAction(String? value) {
  switch (value) {
    case 'confirm_ticket':
      return MusicQuotaAction.confirmTicket;
    case 'buy_coupon':
      return MusicQuotaAction.buyCoupon;
    case 'buy_vip':
      return MusicQuotaAction.buyVip;
    default:
      return MusicQuotaAction.none;
  }
}

class StoreBundlePurchaseResponse {
  const StoreBundlePurchaseResponse({
    required this.wallet,
    this.inventoryItem,
    this.gameBalance,
  });

  final WalletBalance wallet;
  final StoreInventoryItem? inventoryItem;
  final int? gameBalance;

  factory StoreBundlePurchaseResponse.fromJson(Map<String, dynamic> json) {
    final inventory = json['inventory_item'];
    return StoreBundlePurchaseResponse(
      wallet: WalletBalance.fromJson(
        Map<String, dynamic>.from(json['wallet'] as Map? ?? const {}),
      ),
      inventoryItem: inventory is Map
          ? StoreInventoryItem.fromJson(Map<String, dynamic>.from(inventory))
          : null,
      gameBalance: (json['game_balance'] as num?)?.round(),
    );
  }
}

class StoreInventoryItem {
  const StoreInventoryItem({
    required this.productKind,
    required this.quantity,
    this.acquiredAt,
    this.updatedAt,
    this.expiresAt,
    this.isGift = false,
  });

  final String productKind;
  final int quantity;
  final DateTime? acquiredAt;
  final DateTime? updatedAt;

  /// 音乐畅听券/补签卡的最早到期时间；普通装扮/礼物永远为 null（无过期）。
  final DateTime? expiresAt;

  /// true 表示这份数量里含 VIP 每月赠送的部分（会随 VIP 过期失效，不结转）。
  final bool isGift;

  factory StoreInventoryItem.fromJson(Map<String, dynamic> json) {
    return StoreInventoryItem(
      productKind: json['product_kind']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.round() ?? 0,
      acquiredAt: DateTime.tryParse(json['acquired_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
      isGift: json['is_gift'] == true,
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
    this.note,
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
  final String? note;
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
      note: (json['note'] as String?)?.trim().isNotEmpty == true
          ? (json['note'] as String).trim()
          : null,
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
