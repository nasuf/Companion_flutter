part of 'package:companion_flutter/models.dart';

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
