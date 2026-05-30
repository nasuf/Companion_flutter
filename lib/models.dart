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
    required this.agentId,
    required this.content,
    required this.inactivityDays,
    required this.contacts,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.workspaceId,
    this.lastSeenAt,
    this.startedAt,
    this.triggeredAt,
    this.deliveredAt,
  });

  final String id;
  final String userId;
  final String agentId;
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
      agentId: json['agent_id'] as String? ?? '',
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
