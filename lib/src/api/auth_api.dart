part of 'package:companion_flutter/companion_api.dart';

mixin _CompanionApiAuth on _CompanionApiCore {
  Future<AuthSession> login(String username, String password) async {
    final json =
        await _request(
              'POST',
              '/auth/login',
              body: {'username': username, 'password': password},
            )
            as Map<String, dynamic>;
    final session = _normalizeAuthSession(AuthSession.fromJson(json));
    authToken = session.token;
    return session;
  }

  Future<AuthSession> register(
    String username,
    String password, {
    String? platform,
    String? osVersion,
    String? appVersion,
  }) async {
    // channel marks the signup origin (users.signup_source = "password_app");
    // device fields are optional analytics extras collected best-effort.
    final body = <String, dynamic>{
      'username': username,
      'password': password,
      'channel': 'app',
    };
    if (platform != null) body['platform'] = platform;
    if (osVersion != null) body['os_version'] = osVersion;
    if (appVersion != null) body['app_version'] = appVersion;
    final json =
        await _request('POST', '/auth/register', body: body)
            as Map<String, dynamic>;
    final session = _normalizeAuthSession(AuthSession.fromJson(json));
    authToken = session.token;
    return session;
  }

  /// Request an SMS verification code for [phone] (mainland-CN 11-digit).
  /// Backend enforces cooldown/quota; errors surface as ApiException with a
  /// user-facing Chinese message.
  Future<void> smsSend(String phone) async {
    await _request('POST', '/auth/sms/send', body: {'phone': phone});
  }

  /// Phone + SMS code login; auto-registers on first login. Device metadata
  /// tags the signup source (users.signup_* columns, source "sms_app") like
  /// the WeChat path.
  Future<AuthSession> smsLogin(
    String phone,
    String code, {
    String? platform,
    String? osVersion,
    String? appVersion,
  }) async {
    final body = <String, dynamic>{
      'phone': phone,
      'code': code,
      'channel': 'app',
    };
    if (platform != null) body['platform'] = platform;
    if (osVersion != null) body['os_version'] = osVersion;
    if (appVersion != null) body['app_version'] = appVersion;
    final json =
        await _request('POST', '/auth/sms/login', body: body)
            as Map<String, dynamic>;
    final session = _normalizeAuthSession(AuthSession.fromJson(json));
    authToken = session.token;
    return session;
  }

  Future<AuthSession> wechatMobileLogin(
    String code, {
    required String platform,
    String? osVersion,
    String? appVersion,
  }) async {
    final body = <String, dynamic>{'code': code, 'platform': platform};
    if (osVersion != null) body['os_version'] = osVersion;
    if (appVersion != null) body['app_version'] = appVersion;
    final json =
        await _request('POST', '/auth/wechat/mobile', body: body)
            as Map<String, dynamic>;
    final session = _normalizeAuthSession(AuthSession.fromJson(json));
    authToken = session.token;
    return session;
  }

  Future<AuthSession> getMe(String token) async {
    authToken = token;
    final json = await _request('GET', '/auth/me') as Map<String, dynamic>;
    final session = _normalizeAuthSession(AuthSession.fromJson(json));
    authToken = session.token;
    return session;
  }

  Future<AgentProfile> getAgent(String agentId) async {
    final json =
        await _request('GET', '/agents/$agentId') as Map<String, dynamic>;
    return _normalizeAgentProfile(AgentProfile.fromJson(json));
  }

  Future<ProfileStats> fetchProfileStats({String? workspaceId}) async {
    final params = <String, String>{};
    if (workspaceId != null && workspaceId.isNotEmpty) {
      params['workspace_id'] = workspaceId;
    }
    final query = Uri(queryParameters: params).query;
    final path = query.isEmpty
        ? '/users/me/profile-stats'
        : '/users/me/profile-stats?$query';
    final json = await _request('GET', path) as Map<String, dynamic>;
    return ProfileStats.fromJson(json);
  }

  Future<UserFeedbackSubmission> submitUserFeedback({
    required String content,
    required String contact,
    String? occurredAt,
    String? appVersion,
    String? platform,
    List<Uint8List> imageBytes = const [],
    List<String> imageNames = const [],
    List<String> imageMimes = const [],
  }) async {
    final json =
        await _requestFeedbackMultipart(
              content: content,
              contact: contact,
              occurredAt: occurredAt,
              appVersion: appVersion,
              platform: platform,
              imageBytes: imageBytes,
              imageNames: imageNames,
              imageMimes: imageMimes,
            )
            as Map<String, dynamic>;
    return UserFeedbackSubmission.fromJson(json);
  }

  Future<AdminUserFeedbackList> listAdminUserFeedback({
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, String>{'limit': '$limit', 'offset': '$offset'};
    if (status != null && status.isNotEmpty) {
      params['status'] = status;
    }
    final query = Uri(queryParameters: params).query;
    final json =
        await _request('GET', '/admin-api/user-feedback?$query')
            as Map<String, dynamic>;
    return AdminUserFeedbackList.fromJson(json);
  }

  Future<AdminUserFeedbackItem> updateAdminUserFeedbackStatus({
    required String feedbackId,
    required String status,
  }) async {
    final json =
        await _request(
              'PATCH',
              '/admin-api/user-feedback/$feedbackId',
              body: {'status': status},
            )
            as Map<String, dynamic>;
    return AdminUserFeedbackItem.fromJson(json);
  }

  /// 改昵称。返回服务端解析后的展示身份，调用方 `session.copyWith` 即可。
  Future<UserProfileUpdateResult> updateUserDisplayName(String name) async {
    final json =
        await _request(
              'PATCH',
              '/users/me/profile',
              body: {'display_name': name},
              debugLabel: 'user.profile.name',
            )
            as Map<String, dynamic>;
    return _normalizeUserProfile(UserProfileUpdateResult.fromJson(json));
  }

  /// 上传头像。传的是 picker 输出的原图 + 裁剪框（源图像素坐标），实际裁剪与
  /// 压到 512×512 由服务端完成 —— Flutter 只能编码 PNG，在客户端出成品图反而
  /// 让线上体积翻几倍。
  Future<UserProfileUpdateResult> uploadUserAvatar({
    required Uint8List bytes,
    required String mime,
    AvatarCropRect? crop,
  }) async {
    final json =
        await _requestMultipart(
              'POST',
              '/users/me/avatar',
              fields: crop == null
                  ? const {}
                  : {
                      'crop_x': '${crop.x}',
                      'crop_y': '${crop.y}',
                      'crop_size': '${crop.size}',
                    },
              fileField: 'file',
              fileName: 'avatar${_extensionForImageMime(mime)}',
              fileMime: mime,
              fileBytes: bytes,
              debugLabel: 'user.profile.avatar',
            )
            as Map<String, dynamic>;
    return _normalizeUserProfile(UserProfileUpdateResult.fromJson(json));
  }

  Future<ChatRecordsClearResult> clearChatRecords({String? workspaceId}) async {
    final params = <String, String>{};
    if (workspaceId != null && workspaceId.isNotEmpty) {
      params['workspace_id'] = workspaceId;
    }
    final query = Uri(queryParameters: params).query;
    final path = query.isEmpty
        ? '/users/me/chat-records'
        : '/users/me/chat-records?$query';
    final json =
        await _request('DELETE', path, debugLabel: 'users.chatRecords.clear')
            as Map<String, dynamic>;
    return ChatRecordsClearResult.fromJson(json);
  }

  Future<bool> saveUserLocation({
    double? latitude,
    double? longitude,
    String? city,
    String? region,
    String? country,
    String permissionStatus = 'unknown',
  }) async {
    final json =
        await _request(
              'PUT',
              '/users/me/location',
              body: {
                'latitude': latitude,
                'longitude': longitude,
                'city': city,
                'region': region,
                'country': country,
                'source': 'device',
                'permission_status': permissionStatus,
              },
            )
            as Map<String, dynamic>;
    return json['has_location'] == true;
  }

  Future<void> registerPushDevice({
    required String token,
    required String environment,
    required String deviceId,
    String? bundleId,
    String? appVersion,
  }) async {
    final body = {
      'platform': 'ios',
      'token': token,
      'environment': environment,
      'device_id': deviceId,
    };
    if (bundleId != null && bundleId.isNotEmpty) {
      body['bundle_id'] = bundleId;
    }
    if (appVersion != null && appVersion.isNotEmpty) {
      body['app_version'] = appVersion;
    }
    await _request(
      'POST',
      '/notifications/devices',
      body: body,
      debugLabel: 'push.register',
    );
  }

  Future<void> disablePushDevice({required String token}) async {
    await _request(
      'DELETE',
      '/notifications/devices',
      body: {'token': token},
      debugLabel: 'push.disable',
    );
  }

  Future<void> updatePushPresence({
    required String deviceId,
    required bool foreground,
    String? workspaceId,
    String? conversationId,
  }) async {
    await _request(
      'POST',
      '/notifications/presence',
      body: {
        'device_id': deviceId,
        'foreground': foreground,
        'workspace_id': workspaceId,
        'conversation_id': conversationId,
      },
      debugLabel: 'push.presence',
    );
  }

  Future<AgentProfile> createAgent({
    required String userId,
    String? name,
    required String gender,
    required Map<String, int> personality,
  }) async {
    final body = <String, dynamic>{
      'user_id': userId,
      'gender': gender,
      'personality': personality,
    };
    // Blank means the server samples a gender-matched name from the library
    // and injects it into persona generation. Do not send a placeholder.
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      body['name'] = trimmed;
    }
    final json =
        await _request(
              'POST',
              '/agents',
              body: body,
            )
            as Map<String, dynamic>;
    return _normalizeAgentProfile(AgentProfile.fromJson(json));
  }

  Future<AgentProvisionStatus> getAgentProvisionStatus(String agentId) async {
    final json =
        await _request('GET', '/agents/$agentId/provision-status')
            as Map<String, dynamic>;
    return AgentProvisionStatus.fromJson(json);
  }

  Future<AgentDeleteResult> deleteAgent(String agentId) async {
    final json =
        await _request('DELETE', '/agents/$agentId') as Map<String, dynamic>;
    return AgentDeleteResult.fromJson(json);
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
