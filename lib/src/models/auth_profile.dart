part of 'package:companion_flutter/models.dart';

enum UserRole { user, admin }

UserRole parseUserRole(String value) {
  return value == 'admin' ? UserRole.admin : UserRole.user;
}

enum LoginMethod { wechat, phone, password }

/// 一种已绑定的登录方式。[label] 是直接可展示的文案（手机号已由服务端脱敏成
/// `138****5678`），[kind] 供 UI 选颜色 —— 视图层不应该去匹配文案字符串。
class LoginMethodInfo {
  const LoginMethodInfo(this.kind, this.label);

  final LoginMethod kind;
  final String label;
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.userId,
    required this.username,
    required this.role,
    required this.hasAgent,
    this.userDisplayName,
    this.userAvatarUrl,
    this.agentId,
    this.agentName,
    this.agentAvatarKey,
    this.agentAvatarUrl,
    this.agentCity,
    this.workspaceId,
    this.conversationId,
    this.phone,
    this.wechatBound = false,
  });

  final String token;
  final String userId;
  final String username;
  final String? userDisplayName;
  final String? userAvatarUrl;
  final UserRole role;
  final bool hasAgent;
  final String? agentId;
  final String? agentName;
  final String? agentAvatarKey;
  final String? agentAvatarUrl;
  final String? agentCity;
  final String? workspaceId;
  final String? conversationId;

  /// 已绑定的手机号，服务端已脱敏成 `138****5678`。未绑定为 null。
  final String? phone;
  final bool wechatBound;

  /// 账号已绑定的登录方式，用于个人资料页展示。可能同时有多个（微信 + 手机号）。
  ///
  /// [LoginMethod.password] 由**推断**得出而不是服务端字段：三种登录方式在数据
  /// 模型上互斥 —— 微信/手机号各对应一条 auth_identities 行，密码账号没有任何身份
  /// 行，所以两者都没有就只能是密码账号。密码登录目前只服务内部（登录页那个
  /// 「QQ登录」按钮打开的就是它），不值得为它单独加一个接口字段。
  List<LoginMethodInfo> get loginMethods {
    final methods = <LoginMethodInfo>[];
    if (wechatBound) {
      methods.add(const LoginMethodInfo(LoginMethod.wechat, '微信'));
    }
    final bound = phone?.trim();
    if (bound != null && bound.isNotEmpty) {
      methods.add(LoginMethodInfo(LoginMethod.phone, bound));
    }
    if (methods.isEmpty) {
      methods.add(const LoginMethodInfo(LoginMethod.password, '账号密码'));
    }
    return methods;
  }

  /// 展示用名字，为空时用 [fallback]。
  ///
  /// 优先级（自设昵称 → 微信昵称 → 用户+手机尾号）**整条都在服务端**
  /// (`services/user_profile.resolve_display_identity`)，客户端只需要挑一个场景
  /// 兜底词。这里刻意不再回落到 [username]：那对真实用户是 `wx_89b939bc004` 这类
  /// 内部 hash，历史上服务端把它塞进展示名字段，客户端不得不用正则再滤一遍——加一
  /// 种登录方式（苹果登录已经在登录页上了）正则就会漏。
  String displayNameOr(String fallback) {
    final name = userDisplayName?.trim();
    return name == null || name.isEmpty ? fallback : name;
  }

  /// 对局页/胶囊等第一人称场景的名字。
  String get userFacingName => displayNameOr('我');

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: json['token'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      userDisplayName: json['user_display_name'] as String?,
      userAvatarUrl: json['user_avatar_url'] as String?,
      role: parseUserRole(json['role'] as String? ?? 'user'),
      hasAgent: json['has_agent'] as bool? ?? false,
      agentId: json['agent_id'] as String?,
      agentName: json['agent_name'] as String?,
      agentAvatarKey: json['agent_avatar_key'] as String?,
      agentAvatarUrl: json['agent_avatar_url'] as String?,
      agentCity: json['agent_city'] as String?,
      workspaceId: json['workspace_id'] as String?,
      conversationId: json['conversation_id'] as String?,
      phone: json['phone'] as String?,
      wechatBound: json['wechat_bound'] as bool? ?? false,
    );
  }

  AuthSession copyWith({
    String? userDisplayName,
    String? userAvatarUrl,
    String? agentName,
    String? agentAvatarKey,
    String? agentAvatarUrl,
    String? agentCity,
    String? workspaceId,
    String? conversationId,
  }) {
    return AuthSession(
      token: token,
      userId: userId,
      username: username,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      role: role,
      hasAgent: hasAgent,
      agentId: agentId,
      agentName: agentName ?? this.agentName,
      agentAvatarKey: agentAvatarKey ?? this.agentAvatarKey,
      agentAvatarUrl: agentAvatarUrl ?? this.agentAvatarUrl,
      agentCity: agentCity ?? this.agentCity,
      workspaceId: workspaceId ?? this.workspaceId,
      conversationId: conversationId ?? this.conversationId,
      // 绑定状态只由服务端给出，没有参数可以本地改 —— 但必须在这里透传，否则每次
      // 改昵称/头像都会把它清掉。
      phone: phone,
      wechatBound: wechatBound,
    );
  }
}

/// 用户在圆形取景框里框定的正方形，坐标是**源图像素**（EXIF 校正后）。
///
/// 不在客户端出成品图: Flutter 只能编码 PNG，一张 512² 的照片 PNG 约 400KB，
/// 而服务端本来就要重新编码一遍。传原图 + 这个矩形，线上体积就是 picker 输出
/// 的那张 JPEG（约 150-250KB），裁剪由服务端的 Pillow 精确完成。
class AvatarCropRect {
  const AvatarCropRect({required this.x, required this.y, required this.size});

  final int x;
  final int y;
  final int size;
}

/// 昵称 / 头像修改的回执（`PATCH /users/me/profile`、`POST /users/me/avatar`）。
///
/// 服务端返回的是**解析后**的展示身份，不是刚提交的原值：只改了昵称时
/// [avatarUrl] 仍是当前生效的头像（可能来自微信回落），调用方直接
/// `session.copyWith` 就能让两个字段同时对齐。
class UserProfileUpdateResult {
  const UserProfileUpdateResult({this.displayName, this.avatarUrl});

  final String? displayName;
  final String? avatarUrl;

  factory UserProfileUpdateResult.fromJson(Map<String, dynamic> json) {
    return UserProfileUpdateResult(
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
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

class ProfileStats {
  const ProfileStats({
    required this.workspaceId,
    required this.intimacyStage,
    required this.intimacyStageLabel,
    required this.topicIntimacy,
    required this.intimacySubtitle,
    required this.companionDays,
    required this.companionStartedOn,
    required this.chatHours,
    required this.chatMinutes,
    required this.chatDurationLabel,
    required this.chatDurationSubtitle,
    required this.messageCount,
    required this.recent7dMessageCount,
    required this.recent7dMessageLabel,
    required this.companionSummary,
    required this.backpackCount,
    required this.memberIsActive,
    required this.memberExpiresOn,
  });

  final String workspaceId;
  final String intimacyStage;
  final String intimacyStageLabel;
  final double topicIntimacy;
  final String intimacySubtitle;
  final int companionDays;
  final String? companionStartedOn;
  final int chatHours;
  final int chatMinutes;
  final String chatDurationLabel;
  final String chatDurationSubtitle;
  final int messageCount;
  final int recent7dMessageCount;
  final String recent7dMessageLabel;
  final String companionSummary;
  final int backpackCount;
  final bool memberIsActive;
  final String? memberExpiresOn;

  factory ProfileStats.fromJson(Map<String, dynamic> json) {
    final companionDays = (json['companion_days'] as num?)?.round() ?? 0;
    final chatHours = (json['chat_hours'] as num?)?.round() ?? 0;
    final chatMinutes =
        (json['chat_minutes'] as num?)?.round() ?? chatHours * 60;
    final recent7d = (json['recent_7d_message_count'] as num?)?.round() ?? 0;
    return ProfileStats(
      workspaceId: json['workspace_id'] as String? ?? '',
      intimacyStage: json['intimacy_stage'] as String? ?? 'P1',
      intimacyStageLabel: json['intimacy_stage_label'] as String? ?? '初见陪伴',
      topicIntimacy: (json['topic_intimacy'] as num?)?.toDouble() ?? 0,
      intimacySubtitle: json['intimacy_subtitle'] as String? ?? '故事刚刚开始',
      companionDays: companionDays,
      companionStartedOn: json['companion_started_on'] as String?,
      chatHours: chatHours,
      chatMinutes: chatMinutes,
      chatDurationLabel:
          json['chat_duration_label'] as String? ??
          _formatDuration(chatMinutes),
      chatDurationSubtitle:
          json['chat_duration_subtitle'] as String? ?? '累计聊天时长',
      messageCount: (json['message_count'] as num?)?.round() ?? 0,
      recent7dMessageCount: recent7d,
      recent7dMessageLabel:
          json['recent_7d_message_label'] as String? ?? '近7天 +$recent7d条',
      companionSummary: json['companion_summary'] as String? ?? '唯一伴生对象',
      backpackCount: (json['backpack_count'] as num?)?.round() ?? 0,
      memberIsActive: json['member_is_active'] as bool? ?? false,
      memberExpiresOn: json['member_expires_on'] as String?,
    );
  }

  static String _formatDuration(int minutes) {
    if (minutes <= 0) return '0m';
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    if (hours > 0 && remainder > 0) return '${hours}h${remainder}m';
    if (hours > 0) return '${hours}h';
    return '${remainder}m';
  }
}

class ChatRecordsClearResult {
  const ChatRecordsClearResult({
    required this.workspaceId,
    required this.clearedConversations,
  });

  final String workspaceId;
  final int clearedConversations;

  factory ChatRecordsClearResult.fromJson(Map<String, dynamic> json) {
    return ChatRecordsClearResult(
      workspaceId: json['workspace_id'] as String? ?? '',
      clearedConversations:
          (json['cleared_conversations'] as num?)?.round() ?? 0,
    );
  }
}

class UserFeedbackSubmission {
  const UserFeedbackSubmission({required this.id, required this.createdAt});

  final String id;
  final DateTime createdAt;

  factory UserFeedbackSubmission.fromJson(Map<String, dynamic> json) {
    return UserFeedbackSubmission(
      id: json['id'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class AdminUserFeedbackItem {
  const AdminUserFeedbackItem({
    required this.id,
    required this.userId,
    required this.content,
    required this.contact,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.username,
    this.displayName,
    this.occurredAt,
    this.imageUrls = const [],
    this.appVersion,
    this.platform,
  });

  final String id;
  final String userId;
  final String? username;
  final String? displayName;
  final String content;
  final String contact;
  final String? occurredAt;
  final List<String> imageUrls;
  final String status;
  final String? appVersion;
  final String? platform;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AdminUserFeedbackItem.fromJson(Map<String, dynamic> json) {
    return AdminUserFeedbackItem(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String?,
      displayName: json['display_name'] as String?,
      content: json['content'] as String? ?? '',
      contact: json['contact'] as String? ?? '',
      occurredAt: json['occurred_at'] as String?,
      imageUrls:
          (json['image_urls'] as List?)
              ?.map((item) => item.toString())
              .toList(growable: false) ??
          const [],
      status: json['status'] as String? ?? 'open',
      appVersion: json['app_version'] as String?,
      platform: json['platform'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class AdminUserFeedbackList {
  const AdminUserFeedbackList({required this.items, required this.total});

  final List<AdminUserFeedbackItem> items;
  final int total;

  factory AdminUserFeedbackList.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return AdminUserFeedbackList(
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) => AdminUserFeedbackItem.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const [],
      total: (json['total'] as num?)?.round() ?? 0,
    );
  }
}

class AgentProvisionStatus {
  const AgentProvisionStatus({
    required this.agentId,
    required this.status,
    required this.stage,
    required this.percent,
    required this.message,
    this.current,
    this.total,
  });

  final String agentId;
  final String status;
  final String stage;
  final int percent;
  final String message;
  final int? current;
  final int? total;

  bool get isComplete => stage == 'complete' || percent >= 100;
  bool get isFailed => stage == 'failed';

  factory AgentProvisionStatus.fromJson(Map<String, dynamic> json) {
    return AgentProvisionStatus(
      agentId: json['agent_id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      stage: json['stage'] as String? ?? 'initializing',
      percent: (json['percent'] as num?)?.round() ?? 0,
      message: json['message'] as String? ?? '正在初始化...',
      current: (json['current'] as num?)?.round(),
      total: (json['total'] as num?)?.round(),
    );
  }

  AgentProvisionStatus copyWith({
    String? status,
    String? stage,
    int? percent,
    String? message,
    int? current,
    int? total,
  }) {
    return AgentProvisionStatus(
      agentId: agentId,
      status: status ?? this.status,
      stage: stage ?? this.stage,
      percent: percent ?? this.percent,
      message: message ?? this.message,
      current: current ?? this.current,
      total: total ?? this.total,
    );
  }
}

class AgentDeleteResult {
  const AgentDeleteResult({required this.ok, required this.stats});

  final bool ok;
  final Map<String, int> stats;

  factory AgentDeleteResult.fromJson(Map<String, dynamic> json) {
    final rawStats = json['stats'];
    return AgentDeleteResult(
      ok: json['ok'] as bool? ?? false,
      stats: rawStats is Map
          ? rawStats.map(
              (key, value) =>
                  MapEntry(key.toString(), (value as num?)?.round() ?? 0),
            )
          : const {},
    );
  }
}
