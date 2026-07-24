part of 'package:companion_flutter/main.dart';

// ---------------------------------------------------------------------------
// Admin dashboard (数据监控 / 运营管理 / 系统设置)
//
// These screens mirror the web 后台管理 statistics + system-settings surfaces,
// re-shaped for mobile. All network + polling work lives behind the admin-only
// entry, and every polling timer is torn down on dispose / app-background so it
// never touches the battery or bandwidth of a normal (non-admin) user.
// ---------------------------------------------------------------------------

// ===========================================================================
// Shared HTTP helper (single source of truth for /admin-api/* requests).
// `_AdminUserApi._adminRequest` (admin_tools_page.dart) delegates here too.
// ===========================================================================

Future<dynamic> _adminHttpRequest(
  CompanionApi api,
  String method,
  String path, {
  Map<String, dynamic>? body,
}) async {
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.openUrl(
      method,
      Uri.parse('${api.baseUrl}$path'),
    );
    request.headers.contentType = ContentType.json;
    final token = api.authToken;
    if (token != null && token.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    if (body != null) request.write(jsonEncode(body));

    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, _adminErrorText(text));
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

String _adminErrorText(String text) {
  if (text.isEmpty) return '请求失败';
  try {
    final json = jsonDecode(text);
    final detail = json is Map ? json['detail'] : null;
    if (detail is String && detail.isNotEmpty) return detail;
    if (detail != null) return jsonEncode(detail);
    return text;
  } catch (_) {
    return text;
  }
}

extension _AdminStatsApi on CompanionApi {
  Future<_MonitoringStats> fetchMonitoringStats({
    int days = 7,
    bool refresh = false,
  }) async {
    final query = <String, String>{
      'days': days.toString(),
      if (refresh) 'refresh': 'true',
    };
    final path = Uri(
      path: '/admin-api/stats/monitoring',
      queryParameters: query,
    ).toString();
    final json =
        await _adminHttpRequest(this, 'GET', path) as Map<String, dynamic>;
    return _MonitoringStats.fromJson(json);
  }

  Future<_OnlineStats> fetchOnlineStats() async {
    final json =
        await _adminHttpRequest(this, 'GET', '/admin-api/stats/online')
            as Map<String, dynamic>;
    return _OnlineStats.fromJson(json);
  }

  Future<_OnlineUsersPage> fetchOnlineUsers({
    int page = 1,
    int pageSize = 30,
  }) async {
    final path = Uri(
      path: '/admin-api/stats/online/users',
      queryParameters: {
        'page': page.toString(),
        'page_size': pageSize.toString(),
      },
    ).toString();
    final json =
        await _adminHttpRequest(this, 'GET', path) as Map<String, dynamic>;
    return _OnlineUsersPage.fromJson(json);
  }

  Future<_TokenUsageStats> fetchTokenUsage({int days = 30}) async {
    final path = Uri(
      path: '/admin-api/stats/token-usage',
      queryParameters: {'days': days.toString()},
    ).toString();
    final json =
        await _adminHttpRequest(this, 'GET', path) as Map<String, dynamic>;
    return _TokenUsageStats.fromJson(json);
  }

  Future<_OperationsStats> fetchOperationsStats({int days = 7}) async {
    final path = Uri(
      path: '/admin-api/stats/operations',
      queryParameters: {'days': days.toString()},
    ).toString();
    final json =
        await _adminHttpRequest(this, 'GET', path) as Map<String, dynamic>;
    return _OperationsStats.fromJson(json);
  }

  Future<_MediaUsageStats> fetchMediaUsage({int days = 7}) async {
    // Flutter only renders the aggregate tiles, so request the smallest
    // allowed per-user page (limit=1) to keep the payload minimal.
    final path = Uri(
      path: '/admin-api/stats/media-usage',
      queryParameters: {'days': days.toString(), 'limit': '1'},
    ).toString();
    final json =
        await _adminHttpRequest(this, 'GET', path) as Map<String, dynamic>;
    return _MediaUsageStats.fromJson(json);
  }

  Future<_OfflineSettings> fetchOfflineSettings() async {
    final json =
        await _adminHttpRequest(this, 'GET', '/admin-api/offline-settings')
            as Map<String, dynamic>;
    return _OfflineSettings.fromJson(json);
  }

  Future<_OfflineSettings> updateOfflineSettings({
    bool? activityEnabled,
    bool? giftEnabled,
  }) async {
    final body = <String, dynamic>{
      if (activityEnabled != null) 'activity_enabled': activityEnabled,
      if (giftEnabled != null) 'gift_enabled': giftEnabled,
    };
    final json =
        await _adminHttpRequest(
              this,
              'PUT',
              '/admin-api/offline-settings',
              body: body,
            )
            as Map<String, dynamic>;
    return _OfflineSettings.fromJson(json);
  }

  Future<_AchievementSettings> fetchAchievementSettings() async {
    final json =
        await _adminHttpRequest(this, 'GET', '/admin-api/achievement-settings')
            as Map<String, dynamic>;
    return _AchievementSettings.fromJson(json);
  }

  Future<_AchievementSettings> updateAchievementSettings(String mode) async {
    final json =
        await _adminHttpRequest(
              this,
              'PUT',
              '/admin-api/achievement-settings',
              body: {'mode': mode},
            )
            as Map<String, dynamic>;
    return _AchievementSettings.fromJson(json);
  }
}

// ===========================================================================
// Models
// ===========================================================================

double _jsonDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

bool _jsonBool(Object? value) {
  if (value is bool) return value;
  final text = value?.toString().toLowerCase();
  return text == 'true' || text == '1';
}

class _StatWindow {
  const _StatWindow({this.start, this.end, this.days});

  final String? start;
  final String? end;
  final int? days;

  factory _StatWindow.fromJson(Map<String, dynamic> json) {
    return _StatWindow(
      start: _jsonNullableString(json['start']),
      end: _jsonNullableString(json['end']),
      days: json['days'] == null ? null : _jsonInt(json['days']),
    );
  }
}

class _OnlineStats {
  const _OnlineStats({
    required this.count,
    required this.active5min,
    required this.redisAvailable,
    required this.asOf,
  });

  final int count;
  final int active5min;
  final bool redisAvailable;
  final String? asOf;

  factory _OnlineStats.fromJson(Map<String, dynamic> json) {
    return _OnlineStats(
      count: _jsonInt(json['count']),
      active5min: _jsonInt(json['active_5min']),
      redisAvailable: _jsonBool(json['redis_available']),
      asOf: _jsonNullableString(json['as_of']),
    );
  }
}

class _MonitoringOverview {
  const _MonitoringOverview({
    required this.totalUsers,
    required this.totalConversations,
    required this.totalAgents,
    required this.newUsersWindow,
    required this.activeUsersWindow,
    required this.userMessagesWindow,
    required this.dau,
    required this.wau,
    required this.mau,
  });

  final int totalUsers;
  final int totalConversations;
  final int totalAgents;
  final int newUsersWindow;
  final int activeUsersWindow;
  final int userMessagesWindow;
  final int dau;
  final int wau;
  final int mau;

  factory _MonitoringOverview.fromJson(Map<String, dynamic> json) {
    return _MonitoringOverview(
      totalUsers: _jsonInt(json['total_users']),
      totalConversations: _jsonInt(json['total_conversations']),
      totalAgents: _jsonInt(json['total_agents']),
      newUsersWindow: _jsonInt(json['new_users_window']),
      activeUsersWindow: _jsonInt(json['active_users_window']),
      userMessagesWindow: _jsonInt(json['user_messages_window']),
      dau: _jsonInt(json['dau']),
      wau: _jsonInt(json['wau']),
      mau: _jsonInt(json['mau']),
    );
  }
}

class _DailyPoint {
  const _DailyPoint({required this.date, required this.value});

  final String date;
  final double value;
}

class _HourlyPoint {
  const _HourlyPoint({
    required this.hour,
    required this.users,
    required this.userMessages,
  });

  final int hour;
  final int users;
  final int userMessages;
}

class _DailyActivePoint {
  const _DailyActivePoint({
    required this.date,
    required this.activeUsers,
    required this.userMessages,
  });

  final String date;
  final int activeUsers;
  final int userMessages;
}

class _MessageBucket {
  const _MessageBucket({required this.label, required this.users});

  final String label;
  final int users;
}

class _CostTopUser {
  const _CostTopUser({
    required this.userId,
    required this.username,
    required this.costCny,
    required this.requestCount,
    required this.totalTokens,
  });

  final String userId;
  final String username;
  final double costCny;
  final int requestCount;
  final int totalTokens;

  factory _CostTopUser.fromJson(Map<String, dynamic> json) {
    return _CostTopUser(
      userId: _jsonString(json['user_id']),
      username: _jsonString(json['username'], fallback: '未知用户'),
      costCny: _jsonDouble(json['cost_cny']),
      requestCount: _jsonInt(json['request_count']),
      totalTokens: _jsonInt(json['total_tokens']),
    );
  }
}

class _MonitoringStats {
  const _MonitoringStats({
    required this.window,
    required this.onlineNow,
    required this.overview,
    required this.registrationsDaily,
    required this.hourlyActive,
    required this.dailyActive,
    required this.messageBuckets,
    required this.costTopUsers,
  });

  final _StatWindow window;
  final _OnlineStats onlineNow;
  final _MonitoringOverview overview;
  final List<_DailyPoint> registrationsDaily;
  final List<_HourlyPoint> hourlyActive;
  final List<_DailyActivePoint> dailyActive;
  final List<_MessageBucket> messageBuckets;
  final List<_CostTopUser> costTopUsers;

  factory _MonitoringStats.fromJson(Map<String, dynamic> json) {
    final registrations = _jsonMap(json['registrations']);
    final buckets = _jsonMap(json['message_buckets']);
    return _MonitoringStats(
      window: _StatWindow.fromJson(_jsonMap(json['window'])),
      onlineNow: _OnlineStats.fromJson(_jsonMap(json['online_now'])),
      overview: _MonitoringOverview.fromJson(_jsonMap(json['overview'])),
      registrationsDaily: _jsonList(registrations['daily'])
          .map(
            (item) => _DailyPoint(
              date: _jsonString(item['date']),
              value: _jsonDouble(item['count']),
            ),
          )
          .toList(growable: false),
      hourlyActive: _jsonList(json['hourly_active'])
          .map(
            (item) => _HourlyPoint(
              hour: _jsonInt(item['hour']),
              users: _jsonInt(item['users']),
              userMessages: _jsonInt(item['user_messages']),
            ),
          )
          .toList(growable: false),
      dailyActive: _jsonList(json['daily_active'])
          .map(
            (item) => _DailyActivePoint(
              date: _jsonString(item['date']),
              activeUsers: _jsonInt(item['active_users']),
              userMessages: _jsonInt(item['user_messages']),
            ),
          )
          .toList(growable: false),
      messageBuckets: _jsonList(buckets['buckets'])
          .map(
            (item) => _MessageBucket(
              label: _jsonString(item['label']),
              users: _jsonInt(item['users']),
            ),
          )
          .toList(growable: false),
      costTopUsers: _jsonList(
        json['cost_top_users'],
      ).map(_CostTopUser.fromJson).toList(growable: false),
    );
  }
}

class _OnlineUser {
  const _OnlineUser({
    required this.userId,
    required this.username,
    required this.email,
    required this.methods,
  });

  final String userId;
  final String username;
  final String? email;
  final List<_AdminAuthMethod> methods;

  factory _OnlineUser.fromJson(Map<String, dynamic> json) {
    return _OnlineUser(
      userId: _jsonString(json['user_id']),
      username: _jsonString(json['username'], fallback: '未知用户'),
      email: _jsonNullableString(json['email']),
      methods: _jsonList(
        json['methods'],
      ).map(_AdminAuthMethod.fromJson).toList(growable: false),
    );
  }
}

class _OnlineUsersPage {
  const _OnlineUsersPage({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.redisAvailable,
    required this.items,
  });

  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
  final bool redisAvailable;
  final List<_OnlineUser> items;

  factory _OnlineUsersPage.fromJson(Map<String, dynamic> json) {
    return _OnlineUsersPage(
      total: _jsonInt(json['total']),
      page: _jsonInt(json['page']),
      pageSize: _jsonInt(json['page_size']),
      totalPages: _jsonInt(json['total_pages']),
      redisAvailable: _jsonBool(json['redis_available']),
      items: _jsonList(
        json['items'],
      ).map(_OnlineUser.fromJson).toList(growable: false),
    );
  }
}

class _TokenTotals {
  const _TokenTotals({
    required this.requestCount,
    required this.callCount,
    required this.inputTokens,
    required this.outputTokens,
    required this.cachedInputTokens,
    required this.cacheHitRate,
    required this.costCny,
  });

  final int requestCount;
  final int callCount;
  final int inputTokens;
  final int outputTokens;
  final int cachedInputTokens;
  final double? cacheHitRate;
  final double costCny;

  factory _TokenTotals.fromJson(Map<String, dynamic> json) {
    return _TokenTotals(
      requestCount: _jsonInt(json['request_count']),
      callCount: _jsonInt(json['call_count']),
      inputTokens: _jsonInt(json['input_tokens']),
      outputTokens: _jsonInt(json['output_tokens']),
      cachedInputTokens: _jsonInt(json['cached_input_tokens']),
      cacheHitRate: json['cache_hit_rate'] == null
          ? null
          : _jsonDouble(json['cache_hit_rate']),
      costCny: _jsonDouble(json['cost_cny']),
    );
  }
}

class _ModelCost {
  const _ModelCost({required this.model, required this.costCny});

  final String model;
  final double costCny;
}

class _TokenUsageStats {
  const _TokenUsageStats({
    required this.window,
    required this.totals,
    required this.byModel,
    required this.daily,
  });

  final _StatWindow window;
  final _TokenTotals totals;
  final List<_ModelCost> byModel;
  final List<_DailyPoint> daily;

  factory _TokenUsageStats.fromJson(Map<String, dynamic> json) {
    return _TokenUsageStats(
      window: _StatWindow.fromJson(_jsonMap(json['window'])),
      totals: _TokenTotals.fromJson(_jsonMap(json['totals'])),
      byModel: _jsonList(json['by_model'])
          .map(
            (item) => _ModelCost(
              model: _jsonString(item['model'], fallback: '未知模型'),
              costCny: _jsonDouble(item['cost_cny']),
            ),
          )
          .toList(growable: false),
      daily: _jsonList(json['daily'])
          .map(
            (item) => _DailyPoint(
              date: _jsonString(item['date']),
              value: _jsonDouble(item['cost_cny']),
            ),
          )
          .toList(growable: false),
    );
  }
}

/// Voice/image usage rollup (运营管理 → 媒体用量).
/// Flutter renders aggregate tiles only; the per-user breakdown lives in the
/// web admin console as a paginated table.
class _MediaUsageStats {
  const _MediaUsageStats({
    required this.voiceCount,
    required this.voiceSeconds,
    required this.voiceBytes,
    required this.voiceTextCount,
    required this.voiceTextSeconds,
    required this.imageCount,
    required this.imageBytes,
  });

  final int voiceCount;
  final int voiceSeconds;
  final int voiceBytes;
  // Voice-to-text (语音转文字): transcribed then sent as text, no attachment.
  final int voiceTextCount;
  final int voiceTextSeconds;
  final int imageCount;
  final int imageBytes;

  factory _MediaUsageStats.fromJson(Map<String, dynamic> json) {
    final voice = _jsonMap(json['voice']);
    final voiceText = _jsonMap(json['voice_text']);
    final image = _jsonMap(json['image']);
    return _MediaUsageStats(
      voiceCount: _jsonInt(voice['count']),
      voiceSeconds: _jsonInt(voice['total_seconds']),
      voiceBytes: _jsonInt(voice['total_bytes']),
      voiceTextCount: _jsonInt(voiceText['count']),
      voiceTextSeconds: _jsonInt(voiceText['total_seconds']),
      imageCount: _jsonInt(image['count']),
      imageBytes: _jsonInt(image['total_bytes']),
    );
  }
}

/// 145408 → "142.0 KB" — auto KB/MB/GB bucket for media sizes.
String _fmtMediaBytes(int bytes) {
  if (bytes <= 0) return '0 KB';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  return '${(mb / 1024).toStringAsFixed(2)} GB';
}

/// 62 → "1分2秒"; 3700 → "1小时1分40秒".
String _fmtMediaDuration(int totalSeconds) {
  final seconds = totalSeconds < 0 ? 0 : totalSeconds;
  if (seconds < 60) return '$seconds秒';
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final rest = seconds % 60;
  final head = hours > 0 ? '$hours小时' : '';
  return '$head$minutes分$rest秒';
}

class _OperationsStats {
  const _OperationsStats({
    required this.avgLatencyMs,
    required this.failureCount,
    required this.fallbackCount,
    required this.circuitOpenCount,
    required this.memoryStored,
    required this.memoryRetrieval,
    required this.visibleInjected,
    required this.visiblyUsed,
    required this.unsupportedReference,
    required this.avgVisibleUseRate,
    required this.proactiveSent,
    required this.proactiveSkipped,
    required this.proactiveWaiting,
    required this.jobsReady,
    required this.jobsDelayed,
    required this.jobsRunning,
    required this.crisisCreated,
    required this.crisisHigh,
    required this.redisAvailable,
  });

  final double avgLatencyMs;
  final int failureCount;
  final int fallbackCount;
  final int circuitOpenCount;
  final int memoryStored;
  final int memoryRetrieval;
  final int visibleInjected;
  final int visiblyUsed;
  final int unsupportedReference;
  final double avgVisibleUseRate;
  final int proactiveSent;
  final int proactiveSkipped;
  final int proactiveWaiting;
  final int jobsReady;
  final int jobsDelayed;
  final int jobsRunning;
  final int crisisCreated;
  final int crisisHigh;
  final bool redisAvailable;

  bool get hasLlmRisk =>
      failureCount > 0 || fallbackCount > 0 || circuitOpenCount > 0;

  factory _OperationsStats.fromJson(Map<String, dynamic> json) {
    final llm = _jsonMap(json['llm']);
    final memory = _jsonMap(json['memory']);
    final visibleUse = _jsonMapOrNull(memory['visible_use']);
    final proactive = _jsonMap(json['proactive']);
    final jobs = _jsonMap(json['runtime_jobs']);
    final crisis = _jsonMapOrNull(json['crisis_events']);
    final severity = crisis == null
        ? null
        : _jsonMapOrNull(crisis['by_severity']);
    final dataQuality = _jsonMap(json['data_quality']);
    return _OperationsStats(
      avgLatencyMs: _jsonDouble(llm['avg_latency_ms']),
      failureCount: _jsonInt(llm['failure_count']),
      fallbackCount: _jsonInt(llm['fallback_count']),
      circuitOpenCount: _jsonInt(llm['circuit_open_count']),
      memoryStored: _jsonInt(memory['stored_count']),
      memoryRetrieval: _jsonInt(memory['retrieval_access_count']),
      visibleInjected: visibleUse == null
          ? 0
          : _jsonInt(visibleUse['injected_count']),
      visiblyUsed: visibleUse == null
          ? 0
          : _jsonInt(visibleUse['visibly_used_count']),
      unsupportedReference: visibleUse == null
          ? 0
          : _jsonInt(visibleUse['unsupported_reference_count']),
      avgVisibleUseRate: visibleUse == null
          ? 0
          : _jsonDouble(visibleUse['avg_visible_use_rate']),
      proactiveSent: _jsonInt(proactive['sent_count']),
      proactiveSkipped: _jsonInt(proactive['skipped_count']),
      proactiveWaiting: _jsonInt(proactive['waiting_user_count']),
      jobsReady: _jsonInt(jobs['ready_count']),
      jobsDelayed: _jsonInt(jobs['delayed_count']),
      jobsRunning: _jsonInt(jobs['running_count']),
      crisisCreated: crisis == null ? 0 : _jsonInt(crisis['created_count']),
      crisisHigh: severity == null ? 0 : _jsonInt(severity['high']),
      redisAvailable: _jsonBool(dataQuality['redis_available']),
    );
  }
}

class _OfflineSettings {
  const _OfflineSettings({
    required this.activityEnabled,
    required this.giftEnabled,
  });

  final bool activityEnabled;
  final bool giftEnabled;

  _OfflineSettings copyWith({bool? activityEnabled, bool? giftEnabled}) {
    return _OfflineSettings(
      activityEnabled: activityEnabled ?? this.activityEnabled,
      giftEnabled: giftEnabled ?? this.giftEnabled,
    );
  }

  factory _OfflineSettings.fromJson(Map<String, dynamic> json) {
    return _OfflineSettings(
      activityEnabled: _jsonBool(json['activity_enabled']),
      giftEnabled: _jsonBool(json['gift_enabled']),
    );
  }
}

class _AchievementSettings {
  const _AchievementSettings({
    required this.mode,
    required this.envMode,
    required this.effectiveMode,
  });

  final String? mode;
  final String envMode;
  final String effectiveMode;

  factory _AchievementSettings.fromJson(Map<String, dynamic> json) {
    return _AchievementSettings(
      mode: _jsonNullableString(json['mode']),
      envMode: _jsonString(json['env_mode'], fallback: 'on'),
      effectiveMode: _jsonString(json['effective_mode'], fallback: 'on'),
    );
  }
}

// ===========================================================================
// Formatting helpers
// ===========================================================================

String _fmtFull(num value) {
  final rounded = value.round();
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${rounded < 0 ? '-' : ''}$buffer';
}

String _fmtCompact(num value) {
  final abs = value.abs();
  String unit(double scaled, String suffix) {
    var text = scaled.toStringAsFixed(1);
    if (text.endsWith('.0')) text = text.substring(0, text.length - 2);
    return '$text$suffix';
  }

  if (abs >= 1e9) return unit(value / 1e9, 'B');
  if (abs >= 1e6) return unit(value / 1e6, 'M');
  if (abs >= 1e3) return unit(value / 1e3, 'K');
  return _fmtFull(value);
}

String _fmtCny(num value) => '¥${value.toStringAsFixed(4)}';

String _fmtMmDd(String value) {
  if (value.length >= 10) return value.substring(5, 10);
  if (value.length > 5) return value.substring(5);
  return value;
}

String _fmtMs(double value) {
  if (!value.isFinite || value <= 0) return '0 ms';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)} s';
  return '${_fmtFull(value.round())} ms';
}

// Warm accent palette matching the web charts.
const List<Color> _chartColors = [
  Color(0xFFFF8C6B),
  Color(0xFFA8C4F5),
  Color(0xFFA8E0C4),
  Color(0xFFF5C26B),
  Color(0xFFC9A8F5),
  Color(0xFFF59EC4),
  Color(0xFF7FD1DE),
  Color(0xFFE0B0A0),
];

// ===========================================================================
// Reusable admin UI primitives
// ===========================================================================

/// Full-screen scaffold shared by every admin dashboard sub-page: animated
/// backdrop + centered title + optional trailing action.
class _AdminScaffold extends StatefulWidget {
  const _AdminScaffold({
    required this.title,
    required this.child,
    this.trailing,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  State<_AdminScaffold> createState() => _AdminScaffoldState();
}

class _AdminScaffoldState extends State<_AdminScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motionController;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CupertinoPageScaffold(
      backgroundColor: Colors.transparent,
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: _motionController,
          builder: (context, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _ProfileBackgroundPainter(
                    progress: _motionController.value,
                    isDark: isDark,
                  ),
                ),
                Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        18,
                        media.padding.top + 12,
                        18,
                        4,
                      ),
                      child: SizedBox(
                        height: 48,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _AppNavCircleButton(
                                icon: CupertinoIcons.chevron_left,
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.title,
                                  style: TextStyle(
                                    color: isDark
                                        ? AppColors.text
                                        : const Color(0xFF12171B),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                if (widget.subtitle != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      widget.subtitle!,
                                      style: TextStyle(
                                        color: isDark
                                            ? const Color(0x9EEBF2EE)
                                            : AppColors.muted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (widget.trailing != null)
                              Align(
                                alignment: Alignment.centerRight,
                                child: widget.trailing,
                              ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(child: widget.child),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Glass card container used to group dashboard content.
class _AdminCard extends StatelessWidget {
  const _AdminCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.64),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.of(
              context,
            ).shadow.withValues(alpha: isDark ? 0.4 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _AdminSectionTitle extends StatelessWidget {
  const _AdminSectionTitle({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: isDark ? AppColors.text : const Color(0xFF12171B),
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// KPI stat tile.
class _AdminStatTile extends StatelessWidget {
  const _AdminStatTile({
    required this.label,
    required this.value,
    this.sub,
    this.accent = false,
    this.warn = false,
    this.onTap,
    this.badge,
  });

  final String label;
  final String value;
  final String? sub;
  final bool accent;
  final bool warn;
  final VoidCallback? onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppColors.of(context);
    final valueColor = warn
        ? colors.danger
        : accent
        ? colors.accent
        : (isDark ? AppColors.text : const Color(0xFF12171B));
    final content = Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: warn
            ? colors.danger.withValues(alpha: 0.10)
            : isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: warn
              ? colors.danger.withValues(alpha: 0.28)
              : isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0x14181F2A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              if (badge != null) badge!,
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(
              sub!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.42)
                    : const Color(0x8012171B),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: content,
    );
  }
}

/// Responsive KPI grid (2 columns on phones).
/// Responsive KPI grid (2 columns on phones). Each row uses IntrinsicHeight +
/// stretched Expanded so both tiles in a row share the tallest tile's height —
/// tiles with and without a subtitle stay perfectly aligned.
class _AdminStatGrid extends StatelessWidget {
  const _AdminStatGrid({required this.tiles});

  static const int _columns = 2;
  static const double _spacing = 10;

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += _columns) {
      final rowChildren = <Widget>[];
      for (var c = 0; c < _columns; c++) {
        if (c > 0) rowChildren.add(const SizedBox(width: _spacing));
        final index = i + c;
        rowChildren.add(
          Expanded(
            child: index < tiles.length
                ? tiles[index]
                : const SizedBox.shrink(),
          ),
        );
      }
      if (rows.isNotEmpty) rows.add(const SizedBox(height: _spacing));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rowChildren,
          ),
        ),
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

/// Segmented control for window selection.
class _AdminSegment<T> extends StatelessWidget {
  const _AdminSegment({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<MapEntry<T, String>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0x14181F2A),
        ),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(option.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: option.key == value
                        ? colors.accent
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    option.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: option.key == value
                          ? Colors.white
                          : (isDark
                                ? const Color(0xB0EBF2EE)
                                : AppColors.muted),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AdminInlineHint extends StatelessWidget {
  const _AdminInlineHint({required this.text, this.height = 180});

  final String text;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: height,
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Charts (CustomPainter based, zero dependency)
// ===========================================================================

class _AdminAreaChart extends StatelessWidget {
  const _AdminAreaChart({required this.points, required this.color});

  static const double _height = 180;

  final List<_DailyPoint> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const _AdminInlineHint(text: '暂无数据', height: _height);
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: _height,
      child: Column(
        children: [
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _AreaLinePainter(
                values: points.map((p) => p.value).toList(),
                color: color,
                gridColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0x14181F2A),
              ),
            ),
          ),
          const SizedBox(height: 6),
          _ChartXLabels(
            labels: points.map((p) => _fmtMmDd(p.date)).toList(),
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _AreaLinePainter extends CustomPainter {
  _AreaLinePainter({
    required this.values,
    required this.color,
    required this.gridColor,
  });

  final List<double> values;
  final Color color;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxValue = values.reduce(math.max);
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final dx = values.length == 1 ? 0.0 : size.width / (values.length - 1);
    Offset pointAt(int i) {
      final x = values.length == 1 ? size.width / 2 : dx * i;
      final y = size.height - (values[i] / safeMax) * size.height * 0.92 - 2;
      return Offset(x, y);
    }

    final linePath = Path();
    for (var i = 0; i < values.length; i++) {
      final p = pointAt(i);
      if (i == 0) {
        linePath.moveTo(p.dx, p.dy);
      } else {
        linePath.lineTo(p.dx, p.dy);
      }
    }

    final fillPath = Path.from(linePath)
      ..lineTo(pointAt(values.length - 1).dx, size.height)
      ..lineTo(pointAt(0).dx, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.42),
            color.withValues(alpha: 0.04),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _AreaLinePainter old) =>
      old.values != values || old.color != color;
}

class _AdminBarChart extends StatelessWidget {
  const _AdminBarChart({
    required this.values,
    required this.labels,
    required this.color,
  });

  static const double _height = 180;

  final List<double> values;
  final List<String> labels;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const _AdminInlineHint(text: '暂无数据', height: _height);
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: _height,
      child: Column(
        children: [
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _BarsPainter(
                values: values,
                color: color,
                gridColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0x14181F2A),
              ),
            ),
          ),
          const SizedBox(height: 6),
          _ChartXLabels(labels: labels, isDark: isDark),
        ],
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.values,
    required this.color,
    required this.gridColor,
  });

  final List<double> values;
  final Color color;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxValue = values.reduce(math.max);
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final slot = size.width / values.length;
    final barWidth = math.min(slot * 0.62, 18.0);
    final paint = Paint()..color = color;
    for (var i = 0; i < values.length; i++) {
      final barHeight = (values[i] / safeMax) * size.height * 0.92;
      final left = slot * i + (slot - barWidth) / 2;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(left, size.height - barHeight, barWidth, barHeight),
        topLeft: const Radius.circular(3),
        topRight: const Radius.circular(3),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) =>
      old.values != values || old.color != color;
}

/// Bars (messages) + line overlay (active users), independent normalization.
class _AdminDualChart extends StatelessWidget {
  const _AdminDualChart({required this.points});

  static const double _height = 200;

  final List<_DailyActivePoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const _AdminInlineHint(text: '暂无数据', height: _height);
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: _height,
      child: Column(
        children: [
          _ChartLegend(
            items: [
              _ChartLegendItem(color: _chartColors[2], label: '聊天句子'),
              _ChartLegendItem(color: _chartColors[0], label: '活跃用户'),
            ],
            isDark: isDark,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _DualPainter(
                bars: points.map((p) => p.userMessages.toDouble()).toList(),
                line: points.map((p) => p.activeUsers.toDouble()).toList(),
                barColor: _chartColors[2],
                lineColor: _chartColors[0],
                gridColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0x14181F2A),
              ),
            ),
          ),
          const SizedBox(height: 6),
          _ChartXLabels(
            labels: points.map((p) => _fmtMmDd(p.date)).toList(),
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _DualPainter extends CustomPainter {
  _DualPainter({
    required this.bars,
    required this.line,
    required this.barColor,
    required this.lineColor,
    required this.gridColor,
  });

  final List<double> bars;
  final List<double> line;
  final Color barColor;
  final Color lineColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final barMax = bars.reduce(math.max);
    final lineMax = line.isEmpty ? 1.0 : line.reduce(math.max);
    final safeBarMax = barMax <= 0 ? 1.0 : barMax;
    final safeLineMax = lineMax <= 0 ? 1.0 : lineMax;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final slot = size.width / bars.length;
    final barWidth = math.min(slot * 0.5, 16.0);
    final barPaint = Paint()..color = barColor.withValues(alpha: 0.55);
    for (var i = 0; i < bars.length; i++) {
      final barHeight = (bars[i] / safeBarMax) * size.height * 0.9;
      final left = slot * i + (slot - barWidth) / 2;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(left, size.height - barHeight, barWidth, barHeight),
        topLeft: const Radius.circular(3),
        topRight: const Radius.circular(3),
      );
      canvas.drawRRect(rect, barPaint);
    }

    final linePath = Path();
    for (var i = 0; i < line.length; i++) {
      final x = slot * i + slot / 2;
      final y = size.height - (line[i] / safeLineMax) * size.height * 0.9;
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _DualPainter old) =>
      old.bars != bars || old.line != line;
}

class _ChartXLabels extends StatelessWidget {
  const _ChartXLabels({required this.labels, required this.isDark});

  final List<String> labels;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    // Show at most first / middle / last to avoid clutter on mobile.
    final indices = <int>{0, labels.length ~/ 2, labels.length - 1}.toList()
      ..sort();
    final style = TextStyle(
      color: isDark
          ? Colors.white.withValues(alpha: 0.4)
          : const Color(0x8012171B),
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      decoration: TextDecoration.none,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final index in indices) Text(labels[index], style: style),
      ],
    );
  }
}

class _ChartLegendItem {
  const _ChartLegendItem({required this.color, required this.label});

  final Color color;
  final String label;
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.items, required this.isDark});

  final List<_ChartLegendItem> items;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: item.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  item.label,
                  style: TextStyle(
                    color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Horizontal progress-bar list (buckets / cost / model share) — mobile friendly.
class _AdminHBarRow extends StatelessWidget {
  const _AdminHBarRow({
    required this.label,
    required this.fraction,
    required this.color,
    required this.trailing,
    this.leadingRank,
    this.subtitle,
  });

  final String label;
  final double fraction;
  final Color color;
  final String trailing;
  final int? leadingRank;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final clamped = fraction.isFinite ? fraction.clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leadingRank != null) ...[
            SizedBox(
              width: 18,
              child: Text(
                '$leadingRank',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.42)
                      : const Color(0x8012171B),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? AppColors.text : const Color(0xFF12171B),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 5,
                    child: Stack(
                      children: [
                        Container(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0x14181F2A),
                        ),
                        FractionallySizedBox(
                          widthFactor: clamped == 0 ? 0.02 : clamped,
                          child: Container(color: color),
                        ),
                      ],
                    ),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.4)
                          : const Color(0x8012171B),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            trailing,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminDonut extends StatelessWidget {
  const _AdminDonut({required this.byModel});

  final List<_ModelCost> byModel;

  static const Map<String, Color> _modelColors = {
    'qwen3.5-flash': Color(0xFFFF8C6B),
    'qwen3.5-plus': Color(0xFFA8C4F5),
  };

  Color _colorFor(String model, int index) {
    return _modelColors[model] ?? _chartColors[index % _chartColors.length];
  }

  @override
  Widget build(BuildContext context) {
    if (byModel.isEmpty) {
      return const _AdminInlineHint(text: '暂无数据', height: 150);
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = byModel.fold<double>(0, (sum, m) => sum + m.costCny);
    final segments = <_DonutSegment>[
      for (var i = 0; i < byModel.length; i++)
        _DonutSegment(
          value: byModel[i].costCny,
          color: _colorFor(byModel[i].model, i),
        ),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 110,
          height: 110,
          child: CustomPaint(
            painter: _DonutPainter(
              segments: segments,
              trackColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0x14181F2A),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < byModel.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: _colorFor(byModel[i].model, i),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          byModel[i].model,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark
                                ? AppColors.text
                                : const Color(0xFF12171B),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        total > 0
                            ? '${(byModel[i].costCny / total * 100).toStringAsFixed(1)}%'
                            : '0%',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.42)
                              : const Color(0x8012171B),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutSegment {
  const _DonutSegment({required this.value, required this.color});

  final double value;
  final Color color;
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.segments, required this.trackColor});

  final List<_DonutSegment> segments;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = math.min(size.width, size.height) / 2;
    const stroke = 20.0;
    final arcRect = Rect.fromCircle(
      center: center,
      radius: radius - stroke / 2,
    );

    canvas.drawArc(
      arcRect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = trackColor
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke,
    );

    final total = segments.fold<double>(0, (sum, s) => sum + s.value);
    if (total <= 0) return;
    var start = -math.pi / 2;
    for (final segment in segments) {
      final sweep = segment.value / total * 2 * math.pi;
      canvas.drawArc(
        arcRect,
        start,
        sweep - 0.02,
        false,
        Paint()
          ..color = segment.color
          ..strokeWidth = stroke
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.segments != segments;
}

// ===========================================================================
// 数据监控 (Data Monitoring)
// ===========================================================================

class _AdminMonitoringPage extends StatefulWidget {
  const _AdminMonitoringPage({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_AdminMonitoringPage> createState() => _AdminMonitoringPageState();
}

class _AdminMonitoringPageState extends State<_AdminMonitoringPage>
    with WidgetsBindingObserver {
  static const _statsInterval = Duration(seconds: 30);
  static const _onlineInterval = Duration(seconds: 5);

  int _days = 7;
  bool _loading = false;
  String? _error;
  _MonitoringStats? _data;
  _OnlineStats? _online;
  DateTime? _lastRefreshed;
  Timer? _statsTimer;
  Timer? _onlineTimer;
  int _loadSeq = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.api.authToken = widget.session.token;
    _load(force: true);
    _loadOnline();
    _startTimers();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimers();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause polling whenever the app is not in the foreground so an admin
    // leaving the app open never burns bandwidth in the background.
    if (state == AppLifecycleState.resumed) {
      _startTimers();
      _load(silent: true);
      _loadOnline();
    } else {
      _stopTimers();
    }
  }

  void _startTimers() {
    _statsTimer ??= Timer.periodic(_statsInterval, (_) => _load(silent: true));
    _onlineTimer ??= Timer.periodic(_onlineInterval, (_) => _loadOnline());
  }

  void _stopTimers() {
    _statsTimer?.cancel();
    _statsTimer = null;
    _onlineTimer?.cancel();
    _onlineTimer = null;
  }

  Future<void> _load({bool force = false, bool silent = false}) async {
    // Monotonic sequence so the latest request always wins even when a slow
    // background poll overlaps a window switch (no stale-window flicker).
    final seq = ++_loadSeq;
    if (!silent) setState(() => _loading = true);
    try {
      widget.api.authToken = widget.session.token;
      final data = await widget.api.fetchMonitoringStats(
        days: _days,
        refresh: force,
      );
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _data = data;
        _online ??= data.onlineNow;
        _lastRefreshed = DateTime.now();
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _error = _asMessage(error);
        _loading = false;
      });
    }
  }

  Future<void> _loadOnline() async {
    try {
      widget.api.authToken = widget.session.token;
      final online = await widget.api.fetchOnlineStats();
      if (!mounted) return;
      setState(() => _online = online);
    } catch (_) {
      // Keep the last known online count; a single failure is non-fatal.
    }
  }

  void _changeWindow(int days) {
    if (days == _days) return;
    setState(() => _days = days);
    _load(force: true);
  }

  void _openOnlineUsers() {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) =>
            _AdminOnlineUsersPage(api: widget.api, session: widget.session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final refreshedLabel = _lastRefreshed == null
        ? null
        : '自动刷新 · ${_adminClockLabel(_lastRefreshed!)}';
    return _AdminScaffold(
      title: '数据监控',
      subtitle: refreshedLabel,
      trailing: _loading
          ? const Padding(
              padding: EdgeInsets.only(right: 4),
              child: CupertinoActivityIndicator(radius: 10),
            )
          : _AppNavCircleButton(
              icon: CupertinoIcons.refresh,
              onPressed: () {
                _load(force: true);
                _loadOnline();
              },
            ),
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    final data = _data;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
      children: [
        _AdminSegment<int>(
          value: _days,
          options: const [
            MapEntry(1, '今日'),
            MapEntry(3, '近3天'),
            MapEntry(7, '近7天'),
            MapEntry(30, '近30天'),
            MapEntry(0, '全部'),
          ],
          onChanged: _changeWindow,
        ),
        const SizedBox(height: 16),
        if (_error != null && data == null)
          _AdminStatePanel(
            title: '加载失败',
            message: _error!,
            actionText: '重试',
            onTap: () => _load(force: true),
          )
        else if (data == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CupertinoActivityIndicator(radius: 14)),
          )
        else ...[
          _buildOverview(data),
          const SizedBox(height: 16),
          _AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _AdminSectionTitle(title: '新增注册走势'),
                _AdminAreaChart(
                  points: data.registrationsDaily,
                  color: _chartColors[0],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _AdminSectionTitle(title: '分时段活跃人数 (按小时)'),
                _AdminBarChart(
                  values: data.hourlyActive
                      .map((h) => h.users.toDouble())
                      .toList(),
                  labels: data.hourlyActive.map((h) => '${h.hour}:00').toList(),
                  color: _chartColors[1],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _AdminSectionTitle(title: '每日活跃用户与聊天量'),
                _AdminDualChart(points: data.dailyActive),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _AdminSectionTitle(title: '聊天句子数量区间分布'),
                _buildBuckets(data),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _AdminSectionTitle(title: '聊天费用 Top 10'),
                _buildCostTop(data),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOverview(_MonitoringStats data) {
    final ov = data.overview;
    final online = _online ?? data.onlineNow;
    final degraded = !online.redisAvailable;
    final activePct = ov.totalUsers > 0
        ? '占比 ${(ov.activeUsersWindow / ov.totalUsers * 100).toStringAsFixed(1)}%'
        : null;
    final perActive = ov.activeUsersWindow > 0
        ? '人均 ${(ov.userMessagesWindow / ov.activeUsersWindow).toStringAsFixed(1)} 句'
        : null;
    return _AdminStatGrid(
      tiles: [
        _AdminStatTile(
          label: '实时在线',
          value: degraded ? '—' : _fmtFull(online.count),
          sub: degraded
              ? 'Redis 不可用'
              : '近5分钟 ${_fmtFull(online.active5min)} · 点击查看',
          accent: true,
          onTap: _openOnlineUsers,
          badge: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: degraded ? AppColors.muted : const Color(0xFF1FA97A),
              shape: BoxShape.circle,
            ),
          ),
        ),
        _AdminStatTile(
          label: '今日活跃 (DAU)',
          value: _fmtFull(ov.dau),
          accent: true,
        ),
        _AdminStatTile(label: '本周活跃 (WAU)', value: _fmtFull(ov.wau)),
        _AdminStatTile(label: '本月活跃 (MAU)', value: _fmtFull(ov.mau)),
        _AdminStatTile(
          label: '累计用户',
          value: _fmtFull(ov.totalUsers),
          sub: '累计 ${_fmtFull(ov.totalConversations)} 会话',
        ),
        _AdminStatTile(
          label: '本区间新增注册',
          value: _fmtFull(ov.newUsersWindow),
          accent: true,
        ),
        _AdminStatTile(
          label: '本区间活跃用户',
          value: _fmtFull(ov.activeUsersWindow),
          sub: activePct,
        ),
        _AdminStatTile(
          label: '本区间聊天句子',
          value: _fmtFull(ov.userMessagesWindow),
          sub: perActive,
        ),
      ],
    );
  }

  Widget _buildBuckets(_MonitoringStats data) {
    if (data.messageBuckets.isEmpty) {
      return const _AdminInlineHint(text: '暂无数据', height: 80);
    }
    final maxUsers = data.messageBuckets.fold<int>(
      0,
      (m, b) => math.max(m, b.users),
    );
    return Column(
      children: [
        for (var i = 0; i < data.messageBuckets.length; i++)
          _AdminHBarRow(
            label: data.messageBuckets[i].label,
            fraction: maxUsers > 0
                ? data.messageBuckets[i].users / maxUsers
                : 0,
            color: _chartColors[i % _chartColors.length],
            trailing: '${_fmtFull(data.messageBuckets[i].users)} 人',
          ),
      ],
    );
  }

  Widget _buildCostTop(_MonitoringStats data) {
    if (data.costTopUsers.isEmpty) {
      return const _AdminInlineHint(text: '暂无数据', height: 80);
    }
    final maxCost = data.costTopUsers.first.costCny;
    return Column(
      children: [
        for (var i = 0; i < data.costTopUsers.length; i++)
          _AdminHBarRow(
            leadingRank: i + 1,
            label: data.costTopUsers[i].username,
            fraction: maxCost > 0 ? data.costTopUsers[i].costCny / maxCost : 0,
            color: _chartColors[0],
            trailing: _fmtCny(data.costTopUsers[i].costCny),
            subtitle:
                '${data.costTopUsers[i].requestCount} 次 · ${_fmtCompact(data.costTopUsers[i].totalTokens)} tok',
          ),
      ],
    );
  }
}

String _adminClockLabel(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  final second = local.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}

// ===========================================================================
// 在线用户明细 (Online users)
// ===========================================================================

class _AdminOnlineUsersPage extends StatefulWidget {
  const _AdminOnlineUsersPage({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_AdminOnlineUsersPage> createState() => _AdminOnlineUsersPageState();
}

class _AdminOnlineUsersPageState extends State<_AdminOnlineUsersPage> {
  bool _loading = true;
  String? _error;
  _OnlineUsersPage? _page;
  int _pageIndex = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      widget.api.authToken = widget.session.token;
      final page = await widget.api.fetchOnlineUsers(
        page: _pageIndex,
        pageSize: 30,
      );
      if (!mounted) return;
      setState(() {
        _page = page;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _asMessage(error);
        _loading = false;
      });
    }
  }

  void _goToPage(int index) {
    setState(() => _pageIndex = index);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    return _AdminScaffold(
      title: '在线用户',
      subtitle: page == null ? null : '共 ${_fmtFull(page.total)} 人在线',
      trailing: _loading
          ? const Padding(
              padding: EdgeInsets.only(right: 4),
              child: CupertinoActivityIndicator(radius: 10),
            )
          : _AppNavCircleButton(icon: CupertinoIcons.refresh, onPressed: _load),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        children: [
          if (_error != null && page == null)
            _AdminStatePanel(
              title: '加载失败',
              message: _error!,
              actionText: '重试',
              onTap: _load,
            )
          else if (page == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CupertinoActivityIndicator(radius: 14)),
            )
          else if (page.items.isEmpty)
            const _AdminStatePanel(title: '暂无在线用户', message: '当前没有活跃的在线用户。')
          else
            _AdminCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  for (var i = 0; i < page.items.length; i++)
                    _buildRow(
                      page.items[i],
                      (page.page - 1) * page.pageSize + i + 1,
                    ),
                ],
              ),
            ),
          if (page != null && page.totalPages > 1) ...[
            const SizedBox(height: 16),
            _buildPager(page),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(_OnlineUser user, int rank) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '$rank',
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.42)
                    : const Color(0x8012171B),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? AppColors.text : const Color(0xFF12171B),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
                if (user.methods.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      for (final method in user.methods)
                        _AdminAuthMethodChip(method: method, compact: true),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPager(_OnlineUsersPage page) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _AppNavCircleButton(
          icon: CupertinoIcons.chevron_left,
          onPressed: page.page > 1 ? () => _goToPage(page.page - 1) : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            '${page.page} / ${page.totalPages}',
            style: TextStyle(
              color: isDark ? AppColors.text : const Color(0xFF12171B),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        _AppNavCircleButton(
          icon: CupertinoIcons.chevron_right,
          onPressed: page.page < page.totalPages
              ? () => _goToPage(page.page + 1)
              : null,
        ),
      ],
    );
  }
}

// ===========================================================================
// 运营管理 (Operations)
// ===========================================================================

class _AdminOperationsPage extends StatefulWidget {
  const _AdminOperationsPage({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_AdminOperationsPage> createState() => _AdminOperationsPageState();
}

class _AdminOperationsPageState extends State<_AdminOperationsPage> {
  int _days = 7;
  bool _loading = false;
  String? _error;
  _TokenUsageStats? _token;
  _OperationsStats? _ops;
  _MediaUsageStats? _media;
  int _loadSeq = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final seq = ++_loadSeq;
    setState(() => _loading = true);
    try {
      widget.api.authToken = widget.session.token;
      final results = await Future.wait([
        widget.api.fetchTokenUsage(days: _days),
        widget.api.fetchOperationsStats(days: _days),
        widget.api.fetchMediaUsage(days: _days),
      ]);
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _token = results[0] as _TokenUsageStats;
        _ops = results[1] as _OperationsStats;
        _media = results[2] as _MediaUsageStats;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _error = _asMessage(error);
        _loading = false;
      });
    }
  }

  void _changeWindow(int days) {
    if (days == _days) return;
    setState(() => _days = days);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return _AdminScaffold(
      title: '运营管理',
      subtitle: 'LLM 成本与系统健康',
      trailing: _loading
          ? const Padding(
              padding: EdgeInsets.only(right: 4),
              child: CupertinoActivityIndicator(radius: 10),
            )
          : _AppNavCircleButton(icon: CupertinoIcons.refresh, onPressed: _load),
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    final token = _token;
    final ops = _ops;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
      children: [
        _AdminSegment<int>(
          value: _days,
          options: const [
            MapEntry(3, '近3天'),
            MapEntry(7, '近7天'),
            MapEntry(30, '近30天'),
            MapEntry(0, '全部'),
          ],
          onChanged: _changeWindow,
        ),
        const SizedBox(height: 16),
        if (_error != null && token == null)
          _AdminStatePanel(
            title: '加载失败',
            message: _error!,
            actionText: '重试',
            onTap: _load,
          )
        else if (token == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CupertinoActivityIndicator(radius: 14)),
          )
        else ...[
          _buildCostKpis(token),
          const SizedBox(height: 16),
          _AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AdminSectionTitle(
                  title: '每日费用走势',
                  trailing:
                      token.window.start != null && token.window.end != null
                      ? Text(
                          '${_fmtMmDd(token.window.start!)} → ${_fmtMmDd(token.window.end!)}',
                          style: TextStyle(
                            color: AppColors.of(context).muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        )
                      : null,
                ),
                _AdminAreaChart(points: token.daily, color: _chartColors[3]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _AdminSectionTitle(title: '模型分布 (按实际计费)'),
                _AdminDonut(byModel: token.byModel),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _AdminSectionTitle(title: '媒体用量 (语音 / 图片)'),
                if (_media == null)
                  const _AdminInlineHint(text: '暂无媒体用量数据', height: 80)
                else
                  _buildMediaUsage(_media!),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _AdminSectionTitle(title: '系统健康'),
                if (ops == null)
                  const _AdminInlineHint(text: '暂无运营指标', height: 80)
                else
                  _buildSystemHealth(ops),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Aggregate tiles only — per-user breakdown lives in the web admin
  // console (paginated table), per product decision 2026-07-23.
  Widget _buildMediaUsage(_MediaUsageStats media) {
    return _AdminStatGrid(
      tiles: [
        _AdminStatTile(
          label: '语音消息',
          value: _fmtFull(media.voiceCount),
          sub: '条',
        ),
        _AdminStatTile(
          label: '纯语音时长',
          value: _fmtMediaDuration(media.voiceSeconds),
          sub: '发出语音 · 共 ${_fmtFull(media.voiceSeconds)} 秒',
        ),
        _AdminStatTile(
          label: '语音转文字时长',
          value: _fmtMediaDuration(media.voiceTextSeconds),
          sub: '${_fmtFull(media.voiceTextCount)} 次 · 共 ${_fmtFull(media.voiceTextSeconds)} 秒',
        ),
        _AdminStatTile(
          label: '语音总大小',
          value: _fmtMediaBytes(media.voiceBytes),
        ),
        _AdminStatTile(
          label: '图片消息',
          value: _fmtFull(media.imageCount),
          sub: '张',
        ),
        _AdminStatTile(
          label: '图片总大小',
          value: _fmtMediaBytes(media.imageBytes),
        ),
      ],
    );
  }

  Widget _buildCostKpis(_TokenUsageStats token) {
    final totals = token.totals;
    final avgPerRequest = totals.requestCount > 0
        ? totals.costCny / totals.requestCount
        : 0.0;
    return _AdminStatGrid(
      tiles: [
        _AdminStatTile(label: '请求次数', value: _fmtFull(totals.requestCount)),
        _AdminStatTile(label: 'LLM 调用次数', value: _fmtFull(totals.callCount)),
        _AdminStatTile(
          label: '输入 token',
          value: _fmtCompact(totals.inputTokens),
        ),
        _AdminStatTile(
          label: '输出 token',
          value: _fmtCompact(totals.outputTokens),
        ),
        _AdminStatTile(
          label: '缓存命中率',
          value: totals.cacheHitRate != null
              ? '${(totals.cacheHitRate! * 100).toStringAsFixed(1)}%'
              : '—',
          sub: totals.cachedInputTokens > 0
              ? '命中 ${_fmtCompact(totals.cachedInputTokens)} tok'
              : 'provider prefix cache',
        ),
        _AdminStatTile(
          label: '总费用 (元)',
          value: '¥${totals.costCny.toStringAsFixed(4)}',
          sub: totals.requestCount > 0
              ? '均 ¥${avgPerRequest.toStringAsFixed(6)}/请求'
              : null,
          accent: true,
        ),
      ],
    );
  }

  Widget _buildSystemHealth(_OperationsStats ops) {
    final visibleRate = (ops.avgVisibleUseRate * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AdminStatGrid(
          tiles: [
            _AdminStatTile(
              label: '记忆写入',
              value: _fmtFull(ops.memoryStored),
              sub: '召回 ${_fmtFull(ops.memoryRetrieval)}',
            ),
            _AdminStatTile(
              label: 'LLM fallback',
              value: _fmtFull(ops.fallbackCount),
              sub: '均延迟 ${_fmtMs(ops.avgLatencyMs)}',
              warn: ops.hasLlmRisk,
            ),
            _AdminStatTile(
              label: '主动消息',
              value: _fmtFull(ops.proactiveSent),
              sub: '跳过 ${_fmtFull(ops.proactiveSkipped)}',
            ),
            _AdminStatTile(
              label: '可见使用率',
              value: '$visibleRate%',
              sub:
                  '${_fmtFull(ops.visiblyUsed)} / ${_fmtFull(ops.visibleInjected)} 条',
              warn: ops.unsupportedReference > 0,
            ),
            _AdminStatTile(
              label: '危机事件',
              value: _fmtFull(ops.crisisCreated),
              sub: '高危 ${_fmtFull(ops.crisisHigh)}',
              warn: ops.crisisHigh > 0,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _AdminHealthBlock(
          title: 'LLM 运行',
          warn: ops.hasLlmRisk,
          rows: [
            MapEntry('平均延迟', _fmtMs(ops.avgLatencyMs)),
            MapEntry('失败次数', _fmtFull(ops.failureCount)),
            MapEntry('熔断次数', _fmtFull(ops.circuitOpenCount)),
          ],
        ),
        const SizedBox(height: 10),
        _AdminHealthBlock(
          title: '主动交流',
          rows: [
            MapEntry('等待用户', _fmtFull(ops.proactiveWaiting)),
            MapEntry('已发送', _fmtFull(ops.proactiveSent)),
            MapEntry('已跳过', _fmtFull(ops.proactiveSkipped)),
          ],
        ),
        const SizedBox(height: 10),
        _AdminHealthBlock(
          title: '运行队列',
          warn: !ops.redisAvailable,
          rows: [
            MapEntry('Redis', ops.redisAvailable ? '正常' : '不可用'),
            MapEntry('待执行', _fmtFull(ops.jobsReady)),
            MapEntry('延迟中', _fmtFull(ops.jobsDelayed)),
            MapEntry('执行中', _fmtFull(ops.jobsRunning)),
          ],
        ),
      ],
    );
  }
}

class _AdminHealthBlock extends StatelessWidget {
  const _AdminHealthBlock({
    required this.title,
    required this.rows,
    this.warn = false,
  });

  final String title;
  final List<MapEntry<String, String>> rows;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: warn
              ? colors.danger.withValues(alpha: 0.28)
              : isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0x14181F2A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isDark ? AppColors.text : const Color(0xFF12171B),
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 8),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3.5),
              child: Row(
                children: [
                  Text(
                    row.key,
                    style: TextStyle(
                      color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    row.value,
                    style: TextStyle(
                      color: isDark ? AppColors.text : const Color(0xFF12171B),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ===========================================================================
// 系统设置 (System settings — global module switches)
// ===========================================================================

class _AdminSystemSettingsPage extends StatefulWidget {
  const _AdminSystemSettingsPage({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_AdminSystemSettingsPage> createState() =>
      _AdminSystemSettingsPageState();
}

class _AdminSystemSettingsPageState extends State<_AdminSystemSettingsPage> {
  bool _loading = true;
  String? _error;
  _OfflineSettings? _offline;
  _AchievementSettings? _achievement;
  String? _savingKey; // 'activity' | 'gift' | 'achievement'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    widget.api.authToken = widget.session.token;
    // Two independent groups: one failing must not blank the other.
    final results = await Future.wait([
      widget.api
          .fetchOfflineSettings()
          .then<Object?>((v) => v)
          .catchError((e) => e),
      widget.api
          .fetchAchievementSettings()
          .then<Object?>((v) => v)
          .catchError((e) => e),
    ]);
    if (!mounted) return;
    final offlineResult = results[0];
    final achievementResult = results[1];
    String? error;
    setState(() {
      if (offlineResult is _OfflineSettings) {
        _offline = offlineResult;
      } else {
        error = _asMessage(offlineResult as Object);
      }
      if (achievementResult is _AchievementSettings) {
        _achievement = achievementResult;
      } else {
        error ??= _asMessage(achievementResult as Object);
      }
      _error = error;
      _loading = false;
    });
  }

  Future<void> _toggleOffline({
    required bool isActivity,
    required bool next,
  }) async {
    final current = _offline;
    if (current == null || _savingKey != null) return;
    final key = isActivity ? 'activity' : 'gift';
    final previous = current;
    setState(() {
      _savingKey = key;
      _error = null;
      _offline = isActivity
          ? current.copyWith(activityEnabled: next)
          : current.copyWith(giftEnabled: next);
    });
    try {
      widget.api.authToken = widget.session.token;
      final updated = await widget.api.updateOfflineSettings(
        activityEnabled: isActivity ? next : null,
        giftEnabled: isActivity ? null : next,
      );
      if (!mounted) return;
      setState(() {
        _offline = updated;
        _savingKey = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _offline = previous; // revert on failure
        _error = _asMessage(error);
        _savingKey = null;
      });
    }
  }

  Future<void> _changeAchievement(String next) async {
    final current = _achievement;
    if (current == null ||
        _savingKey != null ||
        current.effectiveMode == next) {
      return;
    }
    final previous = current;
    setState(() {
      _savingKey = 'achievement';
      _error = null;
      _achievement = _AchievementSettings(
        mode: next,
        envMode: current.envMode,
        effectiveMode: next,
      );
    });
    try {
      widget.api.authToken = widget.session.token;
      final updated = await widget.api.updateAchievementSettings(next);
      if (!mounted) return;
      setState(() {
        _achievement = updated;
        _savingKey = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _achievement = previous; // revert on failure
        _error = _asMessage(error);
        _savingKey = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AdminScaffold(
      title: '系统设置',
      subtitle: '全局模块开关 · 切换即保存',
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _offline == null && _achievement == null) {
      return const Center(child: CupertinoActivityIndicator(radius: 14));
    }
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
      children: [
        _AdminCard(
          child: Text(
            '控制线下模块主动推送与成就系统运行模式，切换后即时保存。已产生的条目及其查看 / 操作不受影响。',
            style: TextStyle(
              color: AppColors.isDark(context)
                  ? const Color(0x9EEBF2EE)
                  : AppColors.muted,
              fontSize: 12.5,
              height: 1.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _AdminFlagCard(
          marker: '活',
          title: '线下活动推荐',
          badge: '主动推送',
          description: '定时向用户推送线下活动邀约与活动卡片。关闭后不再主动生成推荐，手动触发接口也会拒绝创建。',
          scope: '定时任务 · 邀约消息 · 活动卡片',
          enabled: _offline?.activityEnabled ?? false,
          saving: _savingKey == 'activity',
          disabled:
              _offline == null ||
              (_savingKey != null && _savingKey != 'activity'),
          onChanged: (next) => _toggleOffline(isActivity: true, next: next),
        ),
        const SizedBox(height: 12),
        _AdminFlagCard(
          marker: '礼',
          title: '礼物推荐',
          badge: '主动推送',
          description: '定时触发礼物赠送并推进物流卡片。关闭后不再生成新礼物、暂停到货刷新，管理端 mock 接口也会被拒绝。',
          scope: '定时任务 · 礼物生成 · 物流卡片',
          enabled: _offline?.giftEnabled ?? false,
          saving: _savingKey == 'gift',
          disabled:
              _offline == null || (_savingKey != null && _savingKey != 'gift'),
          onChanged: (next) => _toggleOffline(isActivity: false, next: next),
        ),
        const SizedBox(height: 12),
        _AdminAchievementCard(
          settings: _achievement,
          saving: _savingKey == 'achievement',
          disabled:
              _achievement == null ||
              (_savingKey != null && _savingKey != 'achievement'),
          onChanged: _changeAchievement,
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(
            _error!,
            style: TextStyle(
              color: AppColors.of(context).danger,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ],
    );
  }
}

class _AdminFlagCard extends StatelessWidget {
  const _AdminFlagCard({
    required this.marker,
    required this.title,
    required this.badge,
    required this.description,
    required this.scope,
    required this.enabled,
    required this.saving,
    required this.disabled,
    required this.onChanged,
  });

  final String marker;
  final String title;
  final String badge;
  final String description;
  final String scope;
  final bool enabled;
  final bool saving;
  final bool disabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppColors.of(context);
    return _AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  marker,
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.text
                                  : const Color(0xFF12171B),
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _AdminMiniBadge(text: badge),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      saving ? '保存中…' : (enabled ? '已开启' : '已关闭'),
                      style: TextStyle(
                        color: saving
                            ? colors.accent
                            : enabled
                            ? const Color(0xFF1FA97A)
                            : AppColors.muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              CupertinoSwitch(
                value: enabled,
                onChanged: disabled || saving ? null : onChanged,
                activeTrackColor: const Color(0xFF1FA97A),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            scope,
            style: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.36)
                  : const Color(0x6612171B),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminAchievementCard extends StatelessWidget {
  const _AdminAchievementCard({
    required this.settings,
    required this.saving,
    required this.disabled,
    required this.onChanged,
  });

  final _AchievementSettings? settings;
  final bool saving;
  final bool disabled;
  final ValueChanged<String> onChanged;

  static const _options = [
    _AchievementOption(
      value: 'on',
      label: '全量开启',
      hint: '实时解锁并提示：聊天弹窗 / 时间线 / 系统推送 / 成就页 / 积分全部开启。',
    ),
    _AchievementOption(
      value: 'silent',
      label: '静默计算',
      hint: 'H5 期间推荐：照常计算并落库，成就页与积分正常可见；仅关闭聊天内成就达成提示与系统推送。',
    ),
    _AchievementOption(
      value: 'off',
      label: '完全停算',
      hint: '应急开关：停止评估与日终任务（checkpoint 冻结），成就页隐藏。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppColors.of(context);
    final effective = settings?.effectiveMode ?? 'on';
    final hint = settings == null
        ? '加载失败，无法读取当前模式。'
        : _options
              .firstWhere(
                (o) => o.value == effective,
                orElse: () => _options.first,
              )
              .hint;
    return _AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '成',
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '成就系统',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.text
                                : const Color(0xFF12171B),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const _AdminMiniBadge(text: '全局模式'),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      saving ? '保存中…' : _achievementBadge(effective),
                      style: TextStyle(
                        color: saving
                            ? colors.accent
                            : _achievementColor(effective, colors),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AdminSegment<String>(
            value: effective,
            options: [for (final o in _options) MapEntry(o.value, o.label)],
            onChanged: disabled || saving ? (_) {} : onChanged,
          ),
          const SizedBox(height: 12),
          Text(
            hint,
            style: TextStyle(
              color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
          if (settings != null && settings!.mode == null) ...[
            const SizedBox(height: 8),
            Text(
              '当前跟随 .env (${settings!.envMode})',
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.36)
                    : const Color(0x6612171B),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _achievementBadge(String mode) {
    return switch (mode) {
      'on' => '全量运行中',
      'silent' => '静默计算中',
      'off' => '已停算',
      _ => mode,
    };
  }

  Color _achievementColor(String mode, AppPalette colors) {
    return switch (mode) {
      'on' => const Color(0xFF1FA97A),
      'silent' => const Color(0xFFD4A843),
      'off' => colors.danger,
      _ => colors.muted,
    };
  }
}

class _AchievementOption {
  const _AchievementOption({
    required this.value,
    required this.label,
    required this.hint,
  });

  final String value;
  final String label;
  final String hint;
}

class _AdminMiniBadge extends StatelessWidget {
  const _AdminMiniBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0x0F181F2A),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
