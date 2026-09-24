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

  Future<_ResourceStats> fetchResourceStats() async {
    final json =
        await _adminHttpRequest(this, 'GET', '/admin-api/stats/resources')
            as Map<String, dynamic>;
    return _ResourceStats.fromJson(json);
  }

  Future<_CronHealthSummary> fetchCronHealth() async {
    final json =
        await _adminHttpRequest(this, 'GET', '/admin-api/stats/cron-health')
            as Map<String, dynamic>;
    return _CronHealthSummary.fromJson(json);
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

double _jsonDouble(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
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

/// Ark 联网内容插件按次计费, 走不了 token 价目表.
///
/// 免费额度按自然月重置, 所以「花了多少」只能按本月累计算 — 同一次搜索在额度
/// 内是 0 元, 用完之后才计价. [windowCalls] 才是所选时间窗内的次数.
class _WebSearchBilling {
  const _WebSearchBilling({
    required this.windowCalls,
    required this.monthCalls,
    required this.freeRemaining,
    required this.billableCalls,
    required this.costCny,
    required this.pricePerK,
  });

  final int windowCalls;
  final int monthCalls;
  final int freeRemaining;
  final int billableCalls;
  final double costCny;
  final double pricePerK;

  factory _WebSearchBilling.fromJson(Map<String, dynamic> json) {
    return _WebSearchBilling(
      windowCalls: _jsonInt(json['window_calls']),
      monthCalls: _jsonInt(json['month_calls']),
      freeRemaining: _jsonInt(json['free_remaining']),
      billableCalls: _jsonInt(json['billable_calls']),
      costCny: _jsonDouble(json['cost_cny']),
      pricePerK: _jsonDouble(json['price_cny_per_k']),
    );
  }
}

class _TokenUsageStats {
  const _TokenUsageStats({
    required this.window,
    required this.totals,
    required this.byModel,
    required this.daily,
    required this.webSearch,
  });

  final _StatWindow window;
  final _TokenTotals totals;
  final List<_ModelCost> byModel;
  final List<_DailyPoint> daily;

  /// null when the backend omitted it (older server, or the billing rollup
  /// query failed — it degrades rather than failing the whole dashboard).
  final _WebSearchBilling? webSearch;

  factory _TokenUsageStats.fromJson(Map<String, dynamic> json) {
    final webSearch = json['web_search'];
    return _TokenUsageStats(
      window: _StatWindow.fromJson(_jsonMap(json['window'])),
      totals: _TokenTotals.fromJson(_jsonMap(json['totals'])),
      webSearch: webSearch is Map && webSearch.isNotEmpty
          ? _WebSearchBilling.fromJson(_jsonMap(webSearch))
          : null,
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
/// 一条需要排查的项 (可能来自定时任务, 也可能来自数据不变量)。
class _CronProblem {
  const _CronProblem({required this.name, required this.detail});

  final String name;
  final String detail;
}

/// 定时任务健康 + 数据不变量的移动端汇总。
///
/// 服务端返回完整的任务表 (web 端要铺), 这里只留计数和问题项 —— 手机上滚 27 行
/// 正常任务没有意义, 但"哪个坏了"必须看得到。
class _CronHealthSummary {
  const _CronHealthSummary({
    required this.jobTotal,
    required this.jobUnhealthy,
    required this.invariantTotal,
    required this.invariantViolated,
    required this.invariantChecked,
    required this.problems,
  });

  final int jobTotal;
  final int jobUnhealthy;
  final int invariantTotal;
  final int invariantViolated;
  final DateTime? invariantChecked;
  final List<_CronProblem> problems;

  static int _asInt(dynamic v) => v is num ? v.toInt() : 0;

  static String _asText(dynamic v) => v is String ? v : '';

  factory _CronHealthSummary.fromJson(Map<String, dynamic> json) {
    final cron = (json['cron'] as Map?)?.cast<String, dynamic>() ?? {};
    final inv = (json['invariants'] as Map?)?.cast<String, dynamic>() ?? {};

    final problems = <_CronProblem>[];
    for (final raw in (cron['jobs'] as List? ?? const [])) {
      final job = (raw as Map?)?.cast<String, dynamic>() ?? {};
      final verdict = _asText(job['verdict']);
      if (verdict == 'healthy' || verdict == 'unknown') continue;
      // 只读 detail: 服务端已把失败原因并进去。再退回 fail_reason 的话, 健康任务
      // 会把几十天前那条陈旧错误显示出来。
      problems.add(
        _CronProblem(
          name: _asText(job['job_id']),
          detail: _asText(job['detail']),
        ),
      );
    }

    final results = (inv['results'] as List? ?? const []);
    for (final raw in results) {
      final item = (raw as Map?)?.cast<String, dynamic>() ?? {};
      final status = _asText(item['status']);
      if (status != 'violated' && status != 'error') continue;
      problems.add(
        _CronProblem(
          name: _asText(item['title']),
          detail: _asText(item['detail']),
        ),
      );
    }

    final checkedRaw = _asText(inv['checked_at']);
    return _CronHealthSummary(
      jobTotal: _asInt(cron['total']),
      jobUnhealthy: _asInt(cron['unhealthy_count']),
      invariantTotal: results.length,
      invariantViolated: _asInt(inv['violated_count']),
      invariantChecked: checkedRaw.isEmpty
          ? null
          : DateTime.tryParse(checkedRaw),
      problems: problems,
    );
  }
}

class _MediaUsageStats {
  const _MediaUsageStats({
    required this.voiceCount,
    required this.voiceSeconds,
    required this.voiceBytes,
    required this.voiceTextCount,
    required this.voiceTextSeconds,
    required this.imageCount,
    required this.imageBytes,
    required this.asrSeconds,
    required this.asrCount,
    required this.asrCostCny,
    required this.asrPricePerSecond,
    required this.ttsCount,
    required this.ttsMilliseconds,
    required this.ttsBytes,
    required this.ttsBillableCharacters,
    required this.ttsCostCny,
  });

  final int voiceCount;
  final int voiceSeconds;
  final int voiceBytes;
  // Voice-to-text (语音转文字): transcribed then sent as text, no attachment.
  final int voiceTextCount;
  final int voiceTextSeconds;
  final int imageCount;
  final int imageBytes;

  // 语音识别计费口径: 所有转写 (不分最终发语音还是发文字), 按秒计价.
  final int asrSeconds;
  final int asrCount;

  /// null = 未配置单价. Rendering ¥0.00 instead would read as "语音是免费的".
  final double? asrCostCny;
  final double asrPricePerSecond;
  final int ttsCount;
  final int ttsMilliseconds;
  final int ttsBytes;
  final int ttsBillableCharacters;
  final double ttsCostCny;

  factory _MediaUsageStats.fromJson(Map<String, dynamic> json) {
    final voice = _jsonMap(json['voice']);
    final voiceText = _jsonMap(json['voice_text']);
    final image = _jsonMap(json['image']);
    final asr = _jsonMap(json['asr']);
    final tts = _jsonMap(json['tts_output']);
    return _MediaUsageStats(
      voiceCount: _jsonInt(voice['count']),
      voiceSeconds: _jsonInt(voice['total_seconds']),
      voiceBytes: _jsonInt(voice['total_bytes']),
      voiceTextCount: _jsonInt(voiceText['count']),
      voiceTextSeconds: _jsonInt(voiceText['total_seconds']),
      imageCount: _jsonInt(image['count']),
      imageBytes: _jsonInt(image['total_bytes']),
      asrSeconds: _jsonInt(asr['total_seconds']),
      asrCount: _jsonInt(asr['count']),
      asrCostCny: asr['cost_cny'] == null ? null : _jsonDouble(asr['cost_cny']),
      asrPricePerSecond: _jsonDouble(asr['price_cny_per_second']),
      ttsCount: _jsonInt(tts['count']),
      ttsMilliseconds: _jsonInt(tts['total_milliseconds']),
      ttsBytes: _jsonInt(tts['total_bytes']),
      ttsBillableCharacters: _jsonInt(tts['billable_characters']),
      ttsCostCny: _jsonDouble(tts['cost_cny']),
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
