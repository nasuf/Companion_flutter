import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'models.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

class CompanionApi {
  CompanionApi({required this.baseUrl});

  final String baseUrl;
  String? authToken;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? debugLabel,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    final stopwatch = Stopwatch()..start();
    try {
      final request = await client.openUrl(method, _uri(path));
      request.headers.contentType = ContentType.json;
      if (authToken != null && authToken!.isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $authToken',
        );
      }
      if (body != null) {
        final payload = jsonEncode(body);
        if (debugLabel != null) {
          debugPrint(
            '[$debugLabel] request $method $path body=${utf8.encode(payload).length}B elapsed=${stopwatch.elapsedMilliseconds}ms',
          );
        }
        request.write(payload);
      } else if (debugLabel != null) {
        debugPrint(
          '[$debugLabel] request $method $path body=0B elapsed=${stopwatch.elapsedMilliseconds}ms',
        );
      }

      final response = await request.close();
      if (debugLabel != null) {
        debugPrint(
          '[$debugLabel] response headers status=${response.statusCode} elapsed=${stopwatch.elapsedMilliseconds}ms',
        );
      }
      final text = await response.transform(utf8.decoder).join();
      if (debugLabel != null) {
        debugPrint(
          '[$debugLabel] response body=${utf8.encode(text).length}B elapsed=${stopwatch.elapsedMilliseconds}ms',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(response.statusCode, _extractError(text));
      }
      if (response.statusCode == 204 || text.isEmpty) return null;
      return jsonDecode(text);
    } on SocketException catch (error) {
      throw ApiException(0, '无法连接到后端：${error.message}');
    } on HandshakeException catch (error) {
      throw ApiException(0, '后端连接失败：${error.message}');
    } finally {
      client.close(force: true);
    }
  }

  String _extractError(String text) {
    if (text.isEmpty) return '请求失败';
    try {
      final json = jsonDecode(text);
      final detail = json is Map ? json['detail'] : null;
      if (detail is String && detail.isNotEmpty) return detail;
      return text;
    } catch (_) {
      return text;
    }
  }

  Future<AuthSession> login(String username, String password) async {
    final json =
        await _request(
              'POST',
              '/auth/login',
              body: {'username': username, 'password': password},
            )
            as Map<String, dynamic>;
    final session = AuthSession.fromJson(json);
    authToken = session.token;
    return session;
  }

  Future<AuthSession> wechatMobileLogin(
    String code, {
    required String platform,
  }) async {
    final json =
        await _request(
              'POST',
              '/auth/wechat/mobile',
              body: {'code': code, 'platform': platform},
            )
            as Map<String, dynamic>;
    final session = AuthSession.fromJson(json);
    authToken = session.token;
    return session;
  }

  Future<AuthSession> getMe(String token) async {
    authToken = token;
    final json = await _request('GET', '/auth/me') as Map<String, dynamic>;
    final session = AuthSession.fromJson(json);
    authToken = session.token;
    return session;
  }

  Future<Conversation> getConversation(String conversationId) async {
    final json =
        await _request('GET', '/conversations/$conversationId')
            as Map<String, dynamic>;
    return Conversation.fromJson(json);
  }

  Future<AgentProfile> getAgent(String agentId) async {
    final json =
        await _request('GET', '/agents/$agentId') as Map<String, dynamic>;
    return AgentProfile.fromJson(json);
  }

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
              '/conversations/$conversationId/messages?limit=$limit&offset=$offset&include_metadata=true',
            )
            as List;
    return json
        .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
        .toList();
  }

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
    required String agentId,
    String? workspaceId,
    String? state,
  }) async {
    final params = <String, String>{'agent_id': agentId};
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
    required String agentId,
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
                'agent_id': agentId,
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
    required String agentId,
    String? workspaceId,
  }) async {
    final params = <String, String>{'agent_id': agentId};
    if (workspaceId != null && workspaceId.isNotEmpty) {
      params['workspace_id'] = workspaceId;
    }
    final query = Uri(queryParameters: params).query;
    final json =
        await _request(
              'GET',
              '/last-wills?$query',
              debugLabel: 'last_will.list',
            )
            as List;
    return json
        .map((item) => LastWill.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<LastWill> createLastWill({
    required String agentId,
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
                'agent_id': agentId,
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

  Future<AgentProfile> createAgent({
    required String userId,
    required String name,
    required String gender,
    required Map<String, int> personality,
  }) async {
    final json =
        await _request(
              'POST',
              '/agents',
              body: {
                'user_id': userId,
                'name': name,
                'gender': gender,
                'personality': personality,
              },
            )
            as Map<String, dynamic>;
    return AgentProfile.fromJson(json);
  }

  Future<AuthSession> ensureConversation(AuthSession session) async {
    final agentId = session.agentId;
    if (!session.hasAgent || agentId == null || agentId.isEmpty) {
      return session;
    }
    final existingConversationId = session.conversationId;
    if (existingConversationId != null && existingConversationId.isNotEmpty) {
      try {
        final conversation = await getConversation(existingConversationId);
        return session.copyWith(
          workspaceId: conversation.workspaceId ?? session.workspaceId,
          conversationId: conversation.id,
        );
      } catch (_) {
        // Continue to list/create below.
      }
    }

    final conversations = await listConversations(
      userId: session.userId,
      workspaceId: session.workspaceId,
    );
    final matched = conversations.where((item) => item.agentId == agentId);
    if (matched.isNotEmpty) {
      final conversation = matched.first;
      return session.copyWith(
        workspaceId: conversation.workspaceId ?? session.workspaceId,
        conversationId: conversation.id,
      );
    }

    final created = await createConversation(
      userId: session.userId,
      agentId: agentId,
      workspaceId: session.workspaceId,
    );
    return session.copyWith(
      workspaceId: created.workspaceId ?? session.workspaceId,
      conversationId: created.id,
    );
  }

  String? _dateOnly(DateTime? value) {
    if (value == null) return null;
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
