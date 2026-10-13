part of 'package:companion_flutter/companion_api.dart';

class TakeoverListItem {
  const TakeoverListItem({
    required this.id,
    required this.userId,
    required this.status,
    required this.unreadCount,
    required this.readState,
    this.conversationId,
    this.agentId,
    this.agentName,
    this.username,
    this.displayName,
    this.lastMessagePreview,
    this.canClaim = false,
    this.userAvatarUrl,
    this.agentAvatarUrl,
  });

  final String id;
  final String userId;
  final String? conversationId;
  final String? agentId;
  final String? agentName;
  final String? username;
  final String? displayName;
  final String status;
  final int unreadCount;
  final String readState;
  final String? lastMessagePreview;
  final bool canClaim;
  final String? userAvatarUrl;
  final String? agentAvatarUrl;

  String get title {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final user = username?.trim();
    if (user != null && user.isNotEmpty) return user;
    return '新用户';
  }

  factory TakeoverListItem.fromJson(Map<String, dynamic> json) {
    return TakeoverListItem(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      conversationId: json['conversation_id']?.toString(),
      agentId: json['agent_id']?.toString(),
      agentName: json['agent_name']?.toString(),
      username: json['username']?.toString(),
      displayName: json['display_name']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      unreadCount: (json['unread_count'] as num?)?.round() ?? 0,
      readState: json['read_state']?.toString() ?? 'read',
      lastMessagePreview: json['last_message_preview']?.toString(),
      canClaim: json['can_claim'] == true,
      userAvatarUrl: json['user_avatar_url']?.toString(),
      agentAvatarUrl: json['agent_avatar_url']?.toString(),
    );
  }
}

class TakeoverReview {
  const TakeoverReview({
    required this.id,
    required this.status,
    required this.canClaim,
    required this.user,
    this.agent,
    this.ownerName,
    this.ownerAdminId,
  });

  final String id;
  final String status;
  final bool canClaim;
  final String? ownerName;
  final String? ownerAdminId;
  final Map<String, dynamic> user;
  final Map<String, dynamic>? agent;

  String? get conversationId => agent?['conversation_id']?.toString();

  String get userName {
    final display = user['display_name']?.toString().trim();
    if (display != null && display.isNotEmpty) return display;
    final username = user['username']?.toString().trim();
    if (username != null && username.isNotEmpty) return username;
    return '用户';
  }

  String get agentName => agent?['name']?.toString().trim().isNotEmpty == true
      ? agent!['name'].toString()
      : 'Companion';

  String? get userAvatarUrl => _portraitUrl(user['avatar_url']);

  String? get agentAvatarUrl => _portraitUrl(agent?['avatar_url']);

  static String? _portraitUrl(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  factory TakeoverReview.fromJson(Map<String, dynamic> json) {
    final agent = json['agent'];
    return TakeoverReview(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      canClaim: json['can_claim'] == true,
      ownerName: json['owner_name']?.toString(),
      ownerAdminId: json['owner_admin_id']?.toString(),
      user: json['user'] is Map
          ? Map<String, dynamic>.from(json['user'] as Map)
          : const {},
      agent: agent is Map ? Map<String, dynamic>.from(agent) : null,
    );
  }
}

class TakeoverUnreadSummary {
  const TakeoverUnreadSummary(this.count, this.sampledAt);
  final int count;
  final DateTime sampledAt;
}

mixin _CompanionApiTakeover on _CompanionApiCore {
  Future<TakeoverUnreadSummary> getTakeoverUnreadSummary() async {
    final json =
        await _request('GET', '/admin-api/takeovers/unread-summary')
            as Map<String, dynamic>;
    final count = json['unread_count'];
    final sampled = DateTime.tryParse(json['sampled_at']?.toString() ?? '');
    if (count is! int || count < 0 || sampled == null) {
      throw const ApiException(502, '未读信息暂时不可用');
    }
    return TakeoverUnreadSummary(count, sampled);
  }

  Future<List<TakeoverListItem>> listTakeovers(String scope) async {
    final json =
        await _request('GET', '/admin-api/takeovers?scope=$scope')
            as Map<String, dynamic>;
    final items = json['items'];
    if (items is! List) return const [];
    return [
      for (final item in items)
        if (item is Map)
          TakeoverListItem.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<TakeoverReview> getTakeover(String takeoverId) async {
    final json =
        await _request(
              'GET',
              '/admin-api/takeovers/${Uri.encodeComponent(takeoverId)}',
            )
            as Map<String, dynamic>;
    return TakeoverReview.fromJson(json);
  }

  Future<void> dismissTakeover(String takeoverId) async {
    await _request(
      'POST',
      '/admin-api/takeovers/${Uri.encodeComponent(takeoverId)}/dismiss',
    );
  }

  Future<TakeoverReview> claimTakeover(String takeoverId) async {
    final json =
        await _request(
              'POST',
              '/admin-api/takeovers/${Uri.encodeComponent(takeoverId)}/claim',
            )
            as Map<String, dynamic>;
    return TakeoverReview.fromJson(json);
  }

  Future<void> markTakeoverRead(String takeoverId, String messageId) async {
    await _request(
      'POST',
      '/admin-api/takeovers/${Uri.encodeComponent(takeoverId)}/read',
      body: {'message_id': messageId},
    );
  }

  Future<String> getTakeoverInboxTicket() async {
    final json =
        await _request('POST', '/admin-api/takeovers/inbox-ticket')
            as Map<String, dynamic>;
    final ticket = json['ticket'];
    if (ticket is! String || ticket.isEmpty) {
      throw const ApiException(502, '接管通道暂时不可用');
    }
    return ticket;
  }

  Future<String> sendTakeoverMessage(
    String takeoverId, {
    required String text,
    String? clientId,
  }) async {
    final json =
        await _request(
              'POST',
              '/admin-api/takeovers/${Uri.encodeComponent(takeoverId)}/messages',
              body: {
                'text': text,
                if (clientId != null) 'client_id': clientId,
              },
            )
            as Map<String, dynamic>;
    return json['message_id']?.toString() ?? '';
  }

  Future<void> setTakeoverStatus(String takeoverId, String status) async {
    await _request(
      'PATCH',
      '/admin-api/takeovers/${Uri.encodeComponent(takeoverId)}/status',
      body: {'status': status},
    );
  }
}
