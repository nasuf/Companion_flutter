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
