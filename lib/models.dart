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
    this.avatarKey,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String userId;
  final String? workspaceId;
  final String? gender;
  final String? avatarKey;
  final String? avatarUrl;

  factory AgentProfile.fromJson(Map<String, dynamic> json) {
    return AgentProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      workspaceId: json['workspace_id'] as String?,
      gender: json['gender'] as String?,
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
      metadata: clientId != null ? {'client_id': clientId} : null,
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
