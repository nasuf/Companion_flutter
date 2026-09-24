part of 'package:companion_flutter/companion_api.dart';

mixin _CompanionApiCapsule on _CompanionApiCore {
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
    String? note,
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
                if (note != null) 'note': note,
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
    String? note,
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
                if (note != null) 'note': note,
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
}
