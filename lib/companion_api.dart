import 'dart:convert';
import 'dart:io';

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
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
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
        request.write(jsonEncode(body));
      }

      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
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
              '/conversations/$conversationId/messages?limit=$limit&offset=$offset',
            )
            as List;
    return json
        .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
        .toList();
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
}
