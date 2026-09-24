import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show BytesBuilder;

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'offline_models.dart';

part 'src/api/auth_api.dart';
part 'src/api/chat_api.dart';
part 'src/api/offline_api.dart';
part 'src/api/games_api.dart';
part 'src/api/music_api.dart';
part 'src/api/store_api.dart';
part 'src/api/capsule_api.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

class AdminProactiveTriggerResult {
  const AdminProactiveTriggerResult({
    required this.ok,
    required this.triggerType,
    this.message,
    this.reason,
    this.webSearchUsed = false,
    this.linkCardUsed = false,
    this.linkCardSkipReason,
  });

  final bool ok;
  final String triggerType;
  final String? message;
  final String? reason;
  final bool webSearchUsed;
  final bool linkCardUsed;
  // 2026-09-14 (server task#12): linkCardUsed=false 时说明具体原因,
  // 如 metadata_unusable_partial (微博/知乎需登录, 抓不到内容) /
  // preselected_no_url / gate_rejected / exception_XXX. linkCardUsed=true 时 null.
  final String? linkCardSkipReason;

  factory AdminProactiveTriggerResult.fromJson(Map<String, dynamic> json) {
    return AdminProactiveTriggerResult(
      ok: json['ok'] == true,
      triggerType: json['trigger_type']?.toString() ?? '',
      message: json['message']?.toString(),
      reason: json['reason']?.toString(),
      webSearchUsed: json['web_search_used'] == true,
      linkCardUsed: json['link_card_used'] == true,
      linkCardSkipReason: json['link_card_skip_reason']?.toString(),
    );
  }
}

abstract class _CompanionApiCore {
  _CompanionApiCore({required this.baseUrl});

  final String baseUrl;
  String? authToken;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  String _absoluteUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty ||
        trimmed.startsWith('http://') ||
        trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (!trimmed.startsWith('/')) return trimmed;
    return '$baseUrl$trimmed';
  }

  String? _absoluteOptionalUrl(String? url) {
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) return trimmed;
    return _absoluteUrl(trimmed);
  }

  String? _agentAvatarUrl({String? url, String? key}) {
    final explicit = _absoluteOptionalUrl(url);
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final trimmedKey = key?.trim();
    if (trimmedKey == null || trimmedKey.isEmpty) return null;
    return _absoluteUrl(
      '/agents/avatar/${Uri.encodeComponent(trimmedKey)}.png',
    );
  }

  AuthSession _normalizeAuthSession(AuthSession session) {
    return AuthSession(
      token: session.token,
      userId: session.userId,
      username: session.username,
      userDisplayName: session.userDisplayName,
      userAvatarUrl: _absoluteOptionalUrl(session.userAvatarUrl),
      role: session.role,
      hasAgent: session.hasAgent,
      agentId: session.agentId,
      agentName: session.agentName,
      agentAvatarKey: session.agentAvatarKey,
      agentAvatarUrl: _agentAvatarUrl(
        url: session.agentAvatarUrl,
        key: session.agentAvatarKey,
      ),
      agentCity: session.agentCity,
      workspaceId: session.workspaceId,
      conversationId: session.conversationId,
      phone: session.phone,
      wechatBound: session.wechatBound,
    );
  }

  UserProfileUpdateResult _normalizeUserProfile(UserProfileUpdateResult value) {
    return UserProfileUpdateResult(
      displayName: value.displayName,
      avatarUrl: _absoluteOptionalUrl(value.avatarUrl),
    );
  }

  AgentProfile _normalizeAgentProfile(AgentProfile profile) {
    return AgentProfile(
      id: profile.id,
      name: profile.name,
      userId: profile.userId,
      workspaceId: profile.workspaceId,
      gender: profile.gender,
      city: profile.city,
      avatarKey: profile.avatarKey,
      avatarUrl: _agentAvatarUrl(
        url: profile.avatarUrl,
        key: profile.avatarKey,
      ),
    );
  }

  MusicTrack _normalizeMusicTrack(MusicTrack track) {
    return track.copyWith(url: _absoluteUrl(track.url));
  }

  MusicTracksResponse _normalizeMusicTracksResponse(MusicTracksResponse value) {
    return MusicTracksResponse(
      tracks: value.tracks.map(_normalizeMusicTrack).toList(),
      apiEnabled: value.apiEnabled,
      library: value.library,
    );
  }

  MusicPlayback _normalizeMusicPlayback(MusicPlayback value) {
    final track = value.track;
    return MusicPlayback(
      track: track == null ? null : _normalizeMusicTrack(track),
      positionSeconds: value.positionSeconds,
      isPlaying: value.isPlaying,
      updatedAt: value.updatedAt,
    );
  }

  ChatAttachment _normalizeChatAttachment(ChatAttachment value) {
    return value.copyWith(url: _absoluteUrl(value.url));
  }

  OfflineActivity _normalizeOfflineActivity(OfflineActivity value) {
    final feedback = value.completionFeedback;
    final imageUrls = value.imageUrls.map(_absoluteUrl).toList();
    if (feedback == null) {
      return value.copyWith(imageUrls: imageUrls);
    }
    return value.copyWith(
      imageUrls: imageUrls,
      completionFeedback: feedback.copyWith(
        photoAttachments: feedback.photoAttachments
            .map(_normalizeChatAttachment)
            .toList(),
      ),
    );
  }

  OfflineActivities _normalizeOfflineActivities(OfflineActivities value) {
    return OfflineActivities(
      latest: value.latest == null
          ? null
          : _normalizeOfflineActivity(value.latest!),
      pending: value.pending.map(_normalizeOfflineActivity).toList(),
      ignored: value.ignored.map(_normalizeOfflineActivity).toList(),
      completed: value.completed.map(_normalizeOfflineActivity).toList(),
    );
  }

  OfflineHome _normalizeOfflineHome(OfflineHome value) {
    final latest = value.latestActivity;
    return OfflineHome(
      pendingActivityCount: value.pendingActivityCount,
      acceptedActivityCount: value.acceptedActivityCount,
      completedActivityCount: value.completedActivityCount,
      giftCount: value.giftCount,
      shippingGiftCount: value.shippingGiftCount,
      hasLocation: value.hasLocation,
      tags: value.tags,
      latestActivity: latest == null ? null : _normalizeOfflineActivity(latest),
      giftSummary: value.giftSummary,
    );
  }

  ChatMessage _normalizeChatMessage(ChatMessage value) {
    final metadata = value.metadata;
    if (metadata == null) return value;
    final rawAttachments = metadata['attachments'];
    if (rawAttachments is! List) return value;
    final attachments = [
      for (final item in rawAttachments)
        if (item is Map)
          _normalizeChatAttachment(
            ChatAttachment.fromJson(Map<String, dynamic>.from(item)),
          ).toJson(),
    ];
    return value.copyWith(metadata: {...metadata, 'attachments': attachments});
  }

  DailySharePhotosResponse _normalizeDailySharePhotos(
    DailySharePhotosResponse value,
  ) {
    return DailySharePhotosResponse(
      total: value.total,
      groups: [
        for (final group in value.groups)
          group.copyWith(
            photos: group.photos.map(_normalizeChatAttachment).toList(),
          ),
      ],
    );
  }

  ChatLinkCardResponse _normalizeChatLinkCard(ChatLinkCardResponse value) {
    return value;
  }

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
      // 结构化 detail（如到达校验的 {reason, distance_m, message}）取其 message 展示。
      if (detail is Map &&
          detail['message'] is String &&
          (detail['message'] as String).isNotEmpty) {
        return detail['message'] as String;
      }
      return text;
    } catch (_) {
      return text;
    }
  }

  String _extensionForImageMime(String mime) {
    switch (mime) {
      case 'image/png':
        return '.png';
      case 'image/webp':
        return '.webp';
      default:
        return '.jpg';
    }
  }

  /// Multipart/form-data request over the same authenticated HttpClient the
  /// JSON `_request` uses. Avoids the +33% base64 inflation on media uploads.
  Future<dynamic> _requestMultipart(
    String method,
    String path, {
    required Map<String, String> fields,
    required String fileField,
    required String fileName,
    required String fileMime,
    required Uint8List fileBytes,
    String? debugLabel,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    final stopwatch = Stopwatch()..start();
    try {
      final boundary =
          'companion-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
      final request = await client.openUrl(method, _uri(path));
      request.headers.contentType = ContentType(
        'multipart',
        'form-data',
        parameters: {'boundary': boundary},
      );
      if (authToken != null && authToken!.isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $authToken',
        );
      }
      final body = BytesBuilder();
      for (final entry in fields.entries) {
        body.add(
          utf8.encode(
            '--$boundary\r\n'
            'Content-Disposition: form-data; name="${entry.key}"\r\n\r\n'
            '${entry.value}\r\n',
          ),
        );
      }
      body.add(
        utf8.encode(
          '--$boundary\r\n'
          'Content-Disposition: form-data; name="$fileField"; '
          'filename="${fileName.replaceAll('"', '_')}"\r\n'
          'Content-Type: $fileMime\r\n\r\n',
        ),
      );
      body.add(fileBytes);
      body.add(utf8.encode('\r\n--$boundary--\r\n'));
      final payload = body.takeBytes();
      request.headers.contentLength = payload.length;
      if (debugLabel != null) {
        debugPrint(
          '[$debugLabel] request $method $path body=${payload.length}B elapsed=${stopwatch.elapsedMilliseconds}ms',
        );
      }
      request.add(payload);
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      if (debugLabel != null) {
        debugPrint(
          '[$debugLabel] response status=${response.statusCode} body=${utf8.encode(text).length}B elapsed=${stopwatch.elapsedMilliseconds}ms',
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

  Future<dynamic> _requestFeedbackMultipart({
    required String content,
    required String contact,
    String? occurredAt,
    String? appVersion,
    String? platform,
    required List<Uint8List> imageBytes,
    required List<String> imageNames,
    required List<String> imageMimes,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 20);
    final stopwatch = Stopwatch()..start();
    try {
      final boundary =
          'companion-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
      final request = await client.openUrl('POST', _uri('/users/me/feedback'));
      request.headers.contentType = ContentType(
        'multipart',
        'form-data',
        parameters: {'boundary': boundary},
      );
      if (authToken != null && authToken!.isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $authToken',
        );
      }
      final body = BytesBuilder();
      void writeField(String name, String value) {
        body.add(
          utf8.encode(
            '--$boundary\r\n'
            'Content-Disposition: form-data; name="$name"\r\n\r\n'
            '$value\r\n',
          ),
        );
      }

      writeField('content', content);
      writeField('contact', contact);
      if (occurredAt != null && occurredAt.isNotEmpty) {
        writeField('occurred_at', occurredAt);
      }
      if (appVersion != null && appVersion.isNotEmpty) {
        writeField('app_version', appVersion);
      }
      if (platform != null && platform.isNotEmpty) {
        writeField('platform', platform);
      }
      for (var i = 0; i < imageBytes.length; i += 1) {
        final bytes = imageBytes[i];
        final name = i < imageNames.length ? imageNames[i] : 'image_$i.jpg';
        final mime = i < imageMimes.length ? imageMimes[i] : 'image/jpeg';
        body.add(
          utf8.encode(
            '--$boundary\r\n'
            'Content-Disposition: form-data; name="images"; '
            'filename="${name.replaceAll('"', '_')}"\r\n'
            'Content-Type: $mime\r\n\r\n',
          ),
        );
        body.add(bytes);
        body.add(utf8.encode('\r\n'));
      }
      body.add(utf8.encode('--$boundary--\r\n'));
      final payload = body.takeBytes();
      request.headers.contentLength = payload.length;
      debugPrint(
        '[feedback.submit] request POST /users/me/feedback body=${payload.length}B elapsed=${stopwatch.elapsedMilliseconds}ms',
      );
      request.add(payload);
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(response.statusCode, _extractError(text));
      }
      if (text.isEmpty) return null;
      return jsonDecode(text);
    } on SocketException catch (error) {
      throw ApiException(0, '无法连接到后端：${error.message}');
    } on HandshakeException catch (error) {
      throw ApiException(0, '后端连接失败：${error.message}');
    } finally {
      client.close(force: true);
    }
  }

  String? _dateOnly(DateTime? value) {
    if (value == null) return null;
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _pathWithWorkspace(String path, String? workspaceId) {
    if (workspaceId == null || workspaceId.isEmpty) return path;
    final query = Uri(queryParameters: {'workspace_id': workspaceId}).query;
    return '$path?$query';
  }

  Future<Conversation> getConversation(String conversationId);

  Future<List<Conversation>> listConversations({
    required String userId,
    String? workspaceId,
  });

  Future<Conversation> createConversation({
    required String userId,
    required String agentId,
    String? workspaceId,
  });
}

class CompanionApi extends _CompanionApiCore
    with
        _CompanionApiAuth,
        _CompanionApiChat,
        _CompanionApiOffline,
        _CompanionApiGames,
        _CompanionApiMusic,
        _CompanionApiStore,
        _CompanionApiCapsule {
  CompanionApi({required super.baseUrl});
}
