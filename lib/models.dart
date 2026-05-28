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

  AuthSession copyWith({String? workspaceId, String? conversationId}) {
    return AuthSession(
      token: token,
      userId: userId,
      username: username,
      role: role,
      hasAgent: hasAgent,
      agentId: agentId,
      agentName: agentName,
      agentAvatarKey: agentAvatarKey,
      agentAvatarUrl: agentAvatarUrl,
      agentCity: agentCity,
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

class Conversation {
  const Conversation({
    required this.id,
    required this.userId,
    required this.agentId,
    this.workspaceId,
    this.title,
  });

  final String id;
  final String userId;
  final String agentId;
  final String? workspaceId;
  final String? title;

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      agentId: json['agent_id'] as String? ?? '',
      workspaceId: json['workspace_id'] as String?,
      title: json['title'] as String?,
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
  bool get isDraft => id.startsWith('draft-');
  String? get clientId => metadata?['client_id'] as String?;
  ChatComponentCard? get componentCard {
    final raw = metadata?['component_card'] ?? metadata?['componentCard'];
    return raw is Map ? ChatComponentCard.fromJson(raw) : null;
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

class TimeCapsule {
  const TimeCapsule({
    required this.id,
    required this.userId,
    required this.agentId,
    required this.content,
    required this.status,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
    this.media,
    this.skin = 'paper',
    this.workspaceId,
    this.title,
    this.openDate,
    this.sealedAt,
    this.openedAt,
  });

  final String id;
  final String userId;
  final String agentId;
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
      agentId: json['agent_id'] as String? ?? '',
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
