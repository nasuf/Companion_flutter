part of 'package:companion_flutter/main.dart';

// ===========================================================================
// 资源监控 (Server resource monitoring — host + Postgres + Redis)
// ===========================================================================

String _fmtResBytes(num? n) {
  if (n == null) return '—';
  const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  var v = n.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i += 1;
  }
  final digits = (i == 0 || v >= 100) ? 0 : 1;
  return '${v.toStringAsFixed(digits)} ${units[i]}';
}

String _fmtResRate(num? n) => n == null ? '—' : '${_fmtResBytes(n)}/s';

String _fmtResUptime(num? seconds) {
  if (seconds == null) return '—';
  final s = seconds.toInt();
  final d = s ~/ 86400;
  final h = (s % 86400) ~/ 3600;
  final m = (s % 3600) ~/ 60;
  if (d > 0) return '$d 天 $h 小时';
  if (h > 0) return '$h 小时 $m 分';
  return '$m 分';
}

class _ResSystem {
  const _ResSystem({
    this.cpuCount,
    this.cpuPercent,
    this.loadAvg,
    this.loadPercent,
    this.uptimeSeconds,
  });

  final int? cpuCount;
  final double? cpuPercent;
  final List<double>? loadAvg;
  final double? loadPercent;
  final double? uptimeSeconds;

  factory _ResSystem.fromJson(Map<String, dynamic> json) {
    final la = json['load_avg'];
    return _ResSystem(
      cpuCount: (json['cpu_count'] as num?)?.toInt(),
      cpuPercent: (json['cpu_percent'] as num?)?.toDouble(),
      loadAvg: la is List
          ? la.map((e) => (e as num?)?.toDouble() ?? 0).toList()
          : null,
      loadPercent: (json['load_percent'] as num?)?.toDouble(),
      uptimeSeconds: (json['uptime_seconds'] as num?)?.toDouble(),
    );
  }
}

class _ResMemory {
  const _ResMemory({
    required this.total,
    required this.used,
    required this.available,
    required this.percent,
    required this.swapTotal,
    required this.swapUsed,
    required this.swapPercent,
  });

  final int total;
  final int used;
  final int available;
  final double percent;
  final int swapTotal;
  final int swapUsed;
  final double swapPercent;

  factory _ResMemory.fromJson(Map<String, dynamic> json) {
    return _ResMemory(
      total: (json['total'] as num?)?.toInt() ?? 0,
      used: (json['used'] as num?)?.toInt() ?? 0,
      available: (json['available'] as num?)?.toInt() ?? 0,
      percent: (json['percent'] as num?)?.toDouble() ?? 0,
      swapTotal: (json['swap_total'] as num?)?.toInt() ?? 0,
      swapUsed: (json['swap_used'] as num?)?.toInt() ?? 0,
      swapPercent: (json['swap_percent'] as num?)?.toDouble() ?? 0,
    );
  }
}

class _ResDisk {
  const _ResDisk({
    required this.mount,
    required this.label,
    required this.total,
    required this.used,
    required this.free,
    required this.percent,
  });

  final String mount;
  final String label;
  final int total;
  final int used;
  final int free;
  final double percent;

  factory _ResDisk.fromJson(Map<String, dynamic> json) {
    return _ResDisk(
      mount: _jsonString(json['mount']),
      label: _jsonString(json['label']),
      total: (json['total'] as num?)?.toInt() ?? 0,
      used: (json['used'] as num?)?.toInt() ?? 0,
      free: (json['free'] as num?)?.toInt() ?? 0,
      percent: (json['percent'] as num?)?.toDouble() ?? 0,
    );
  }
}

class _ResConnections {
  const _ResConnections({this.active, this.max, this.percent});

  final int? active;
  final int? max;
  final double? percent;

  factory _ResConnections.fromJson(Map<String, dynamic> json) {
    return _ResConnections(
      active: (json['active'] as num?)?.toInt(),
      max: (json['max'] as num?)?.toInt(),
      percent: (json['percent'] as num?)?.toDouble(),
    );
  }
}

class _ResTable {
  const _ResTable({
    required this.name,
    required this.totalBytes,
    required this.totalPretty,
    required this.rows,
  });

  final String name;
  final int totalBytes;
  final String totalPretty;
  final int rows;

  factory _ResTable.fromJson(Map<String, dynamic> json) {
    return _ResTable(
      name: _jsonString(json['name']),
      totalBytes: (json['total_bytes'] as num?)?.toInt() ?? 0,
      totalPretty: _jsonString(json['total_pretty']),
      rows: (json['rows'] as num?)?.toInt() ?? 0,
    );
  }
}

class _ResDatabase {
  const _ResDatabase({
    required this.available,
    this.sizeBytes,
    this.sizePretty,
    this.largestTables = const [],
    this.connections,
  });

  final bool available;
  final int? sizeBytes;
  final String? sizePretty;
  final List<_ResTable> largestTables;
  final _ResConnections? connections;

  factory _ResDatabase.fromJson(Map<String, dynamic> json) {
    return _ResDatabase(
      available: json['available'] == true,
      sizeBytes: (json['size_bytes'] as num?)?.toInt(),
      sizePretty: _jsonNullableString(json['size_pretty']),
      largestTables: _jsonList(
        json['largest_tables'],
      ).map(_ResTable.fromJson).toList(),
      connections: json['connections'] == null
          ? null
          : _ResConnections.fromJson(_jsonMap(json['connections'])),
    );
  }
}

class _ResRedis {
  const _ResRedis({
    required this.available,
    this.usedMemory,
    this.maxmemory,
    this.memPercent,
    this.keys,
    this.connectedClients,
    this.hits,
    this.misses,
    this.hitRate,
    this.evictedKeys,
  });

  final bool available;
  final int? usedMemory;
  final int? maxmemory;
  final double? memPercent;
  final int? keys;
  final int? connectedClients;
  final int? hits;
  final int? misses;
  final double? hitRate;
  final int? evictedKeys;

  factory _ResRedis.fromJson(Map<String, dynamic> json) {
    return _ResRedis(
      available: json['available'] == true,
      usedMemory: (json['used_memory'] as num?)?.toInt(),
      maxmemory: (json['maxmemory'] as num?)?.toInt(),
      memPercent: (json['mem_percent'] as num?)?.toDouble(),
      keys: (json['keys'] as num?)?.toInt(),
      connectedClients: (json['connected_clients'] as num?)?.toInt(),
      hits: (json['hits'] as num?)?.toInt(),
      misses: (json['misses'] as num?)?.toInt(),
      hitRate: (json['hit_rate'] as num?)?.toDouble(),
      evictedKeys: (json['evicted_keys'] as num?)?.toInt(),
    );
  }
}

class _ResourceStats {
  const _ResourceStats({
    required this.system,
    required this.memory,
    required this.disks,
    required this.network,
    required this.database,
    required this.redis,
  });

  final _ResSystem system;
  final _ResMemory? memory;
  final List<_ResDisk> disks;
  final Map<String, dynamic>? network;
  final _ResDatabase database;
  final _ResRedis redis;

  factory _ResourceStats.fromJson(Map<String, dynamic> json) {
    return _ResourceStats(
      system: _ResSystem.fromJson(_jsonMap(json['system'])),
      memory: json['memory'] == null
          ? null
          : _ResMemory.fromJson(_jsonMap(json['memory'])),
      disks: _jsonList(json['disks']).map(_ResDisk.fromJson).toList(),
      network: json['network'] == null ? null : _jsonMap(json['network']),
      database: _ResDatabase.fromJson(_jsonMap(json['database'])),
      redis: _ResRedis.fromJson(_jsonMap(json['redis'])),
    );
  }
}

/// Thin usage bar for disk / memory / connection saturation.
class _ResUsageBar extends StatelessWidget {
  const _ResUsageBar({required this.percent, this.color});

  final double percent;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = percent.clamp(0, 100).toDouble();
    final fill =
        color ??
        (p >= 90
            ? const Color(0xFFE06B6B)
            : p >= 75
            ? const Color(0xFFF5C26B)
            : const Color(0xFF4FB0C4));
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: p / 100,
        minHeight: 8,
        backgroundColor: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0x14181F2A),
        valueColor: AlwaysStoppedAnimation<Color>(fill),
      ),
    );
  }
}


class _AdminResourcePage extends StatefulWidget {
  const _AdminResourcePage({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_AdminResourcePage> createState() => _AdminResourcePageState();
}

class _AdminResourcePageState extends State<_AdminResourcePage>
    with WidgetsBindingObserver {
  // Resource metrics are live (server does not cache), so poll a touch faster.
  static const _interval = Duration(seconds: 10);

  bool _loading = false;
  String? _error;
  _ResourceStats? _data;
  // 巡检数据独立于资源指标: 它取不到时资源页仍应正常显示, 反之亦然。
  _CronHealthSummary? _cronHealth;
  DateTime? _lastRefreshed;
  Timer? _timer;
  int _loadSeq = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.api.authToken = widget.session.token;
    _load();
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimer();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      _load(silent: true);
    } else {
      _stopTimer();
    }
  }

  void _startTimer() {
    _timer ??= Timer.periodic(_interval, (_) => _load(silent: true));
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _load({bool silent = false}) async {
    final seq = ++_loadSeq;
    if (!silent) setState(() => _loading = true);
    try {
      widget.api.authToken = widget.session.token;
      final data = await widget.api.fetchResourceStats();
      // 巡检失败不该让整页报错 —— 资源指标本身还是有用的。
      _CronHealthSummary? health;
      try {
        health = await widget.api.fetchCronHealth();
      } catch (_) {
        health = null;
      }
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _data = data;
        _cronHealth = health;
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

  @override
  Widget build(BuildContext context) {
    final refreshedLabel = _lastRefreshed == null
        ? '实时监控 · 每 10 秒刷新'
        : '自动刷新 · ${_adminClockLabel(_lastRefreshed!)}';
    return _AdminScaffold(
      title: '资源监控',
      subtitle: refreshedLabel,
      trailing: _loading
          ? const Padding(
              padding: EdgeInsets.only(right: 4),
              child: CupertinoActivityIndicator(radius: 10),
            )
          : _AppNavCircleButton(
              icon: CupertinoIcons.refresh,
              onPressed: () => _load(),
            ),
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    final data = _data;
    if (_error != null && data == null) {
      return ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        children: [
          _AdminStatePanel(
            title: '加载失败',
            message: _error!,
            actionText: '重试',
            onTap: () => _load(),
          ),
        ],
      );
    }
    if (data == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CupertinoActivityIndicator(radius: 14)),
      );
    }
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
      children: [
        _buildHost(data),
        const SizedBox(height: 12),
        _buildDisks(data),
        const SizedBox(height: 12),
        _buildNetwork(data),
        const SizedBox(height: 12),
        _buildDatabase(data),
        const SizedBox(height: 12),
        _buildRedis(data),
        if (_cronHealth != null) ...[
          const SizedBox(height: 12),
          _buildCronHealth(_cronHealth!),
        ],
      ],
    );
  }

  /// 定时任务与数据巡检 — 只给汇总与出问题的项。
  ///
  /// 移动端不铺 27 行任务表 (web 端有), 但只给一个"2 项异常"的数字同样没用 ——
  /// 管理员在手机上看到告警, 下一个问题一定是"哪个坏了"。所以列出问题项名称,
  /// 正常的一概不列。
  Widget _buildCronHealth(_CronHealthSummary health) {
    return _AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _AdminSectionTitle(title: '定时任务与数据巡检'),
          _AdminStatGrid(
            tiles: [
              _AdminStatTile(
                label: '定时任务',
                value:
                    '${health.jobTotal - health.jobUnhealthy}/${health.jobTotal}',
                sub: health.jobUnhealthy > 0
                    ? '${health.jobUnhealthy} 项异常'
                    : '全部正常',
                warn: health.jobUnhealthy > 0,
              ),
              _AdminStatTile(
                label: '数据不变量',
                value: health.invariantChecked == null
                    ? '—'
                    : '${health.invariantTotal - health.invariantViolated}/${health.invariantTotal}',
                sub: health.invariantChecked == null
                    ? '尚未巡检'
                    : (health.invariantViolated > 0
                          ? '${health.invariantViolated} 项违反'
                          : '全部通过'),
                warn: health.invariantViolated > 0,
              ),
            ],
          ),
          if (health.problems.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final p in health.problems)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 5, right: 8),
                      child: Icon(
                        CupertinoIcons.exclamationmark_circle_fill,
                        size: 12,
                        color: CupertinoColors.systemOrange,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (p.detail.isNotEmpty)
                            Text(
                              p.detail,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: CupertinoColors.systemGrey,
                                height: 1.35,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildHost(_ResourceStats data) {
    final sys = data.system;
    final mem = data.memory;
    return _AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _AdminSectionTitle(title: '主机概览'),
          _AdminStatGrid(
            tiles: [
              _AdminStatTile(
                label: 'CPU 使用率',
                value: sys.cpuPercent != null
                    ? '${sys.cpuPercent!.toStringAsFixed(1)}%'
                    : '—',
                sub: sys.cpuCount != null ? '${sys.cpuCount} 核' : null,
                warn: (sys.cpuPercent ?? 0) >= 85,
              ),
              _AdminStatTile(
                label: '负载 (1m)',
                value: (sys.loadAvg != null && sys.loadAvg!.isNotEmpty)
                    ? sys.loadAvg![0].toStringAsFixed(2)
                    : '—',
                sub: (sys.loadAvg != null && sys.loadAvg!.length >= 3)
                    ? '5m ${sys.loadAvg![1].toStringAsFixed(2)} · 15m ${sys.loadAvg![2].toStringAsFixed(2)}'
                    : null,
                warn: (sys.loadPercent ?? 0) >= 100,
              ),
              _AdminStatTile(
                label: '内存使用率',
                value: mem != null ? '${mem.percent.toStringAsFixed(1)}%' : '—',
                sub: mem != null
                    ? '${_fmtResBytes(mem.used)} / ${_fmtResBytes(mem.total)}'
                    : null,
                warn: (mem?.percent ?? 0) >= 85,
              ),
              _AdminStatTile(
                label: '运行时长',
                value: _fmtResUptime(sys.uptimeSeconds),
                sub: (mem != null && mem.swapTotal > 0)
                    ? 'Swap ${mem.swapPercent.toStringAsFixed(0)}%'
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDisks(_ResourceStats data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? const Color(0x9EEBF2EE) : AppColors.muted;
    final strongColor = isDark ? AppColors.text : const Color(0xFF12171B);
    return _AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _AdminSectionTitle(title: '磁盘空间'),
          if (data.disks.isEmpty)
            Text(
              '无法读取磁盘信息',
              style: TextStyle(
                color: labelColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            )
          else
            for (var i = 0; i < data.disks.length; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              _diskRow(data.disks[i], labelColor, strongColor),
            ],
        ],
      ),
    );
  }

  Widget _diskRow(_ResDisk d, Color labelColor, Color strongColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                d.label,
                style: TextStyle(
                  color: strongColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            Text(
              '${d.percent.toStringAsFixed(1)}%',
              style: TextStyle(
                color: strongColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        _ResUsageBar(percent: d.percent),
        const SizedBox(height: 5),
        Text(
          '${_fmtResBytes(d.used)} / ${_fmtResBytes(d.total)} · 剩余 ${_fmtResBytes(d.free)}',
          style: TextStyle(
            color: labelColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }

  Widget _buildNetwork(_ResourceStats data) {
    final net = data.network;
    return _AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _AdminSectionTitle(title: '网络吞吐'),
          if (net == null)
            _unavailable('无法读取网络信息')
          else
            _AdminStatGrid(
              tiles: [
                _AdminStatTile(
                  label: '下行速率',
                  value: _fmtResRate(net['recv_rate_bps'] as num?),
                ),
                _AdminStatTile(
                  label: '上行速率',
                  value: _fmtResRate(net['sent_rate_bps'] as num?),
                ),
                _AdminStatTile(
                  label: '累计接收',
                  value: _fmtResBytes(net['bytes_recv'] as num?),
                ),
                _AdminStatTile(
                  label: '累计发送',
                  value: _fmtResBytes(net['bytes_sent'] as num?),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDatabase(_ResourceStats data) {
    final db = data.database;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? const Color(0x9EEBF2EE) : AppColors.muted;
    final strongColor = isDark ? AppColors.text : const Color(0xFF12171B);
    final conn = db.connections;
    final tables = db.largestTables;
    final topBytes = tables.isNotEmpty ? tables.first.totalBytes : 0;
    return _AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _AdminSectionTitle(title: '数据库 (Postgres)'),
          if (!db.available)
            _unavailable('数据库指标不可用')
          else ...[
            _AdminStatGrid(
              tiles: [
                _AdminStatTile(
                  label: '数据库大小',
                  value: db.sizePretty ?? '—',
                  accent: true,
                ),
                _AdminStatTile(
                  label: '活跃连接',
                  value:
                      '${conn?.active?.toString() ?? '—'} / ${conn?.max?.toString() ?? '—'}',
                  sub: conn?.percent != null
                      ? '占用 ${conn!.percent!.toStringAsFixed(1)}%'
                      : null,
                  warn: (conn?.percent ?? 0) >= 80,
                ),
              ],
            ),
            if (conn?.percent != null) ...[
              const SizedBox(height: 10),
              _ResUsageBar(percent: conn!.percent!),
            ],
            if (tables.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                '占用最大的表',
                style: TextStyle(
                  color: labelColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < tables.length; i++) ...[
                if (i > 0) const SizedBox(height: 9),
                _tableRow(tables[i], topBytes, labelColor, strongColor),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Widget _tableRow(
    _ResTable t,
    int topBytes,
    Color labelColor,
    Color strongColor,
  ) {
    final rel = topBytes > 0 ? (t.totalBytes / topBytes) * 100 : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                t.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: strongColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            Text(
              '${t.totalPretty} · ${t.rows} 行',
              style: TextStyle(
                color: labelColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        _ResUsageBar(percent: rel, color: const Color(0xFFA8C4F5)),
      ],
    );
  }

  Widget _buildRedis(_ResourceStats data) {
    final redis = data.redis;
    return _AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _AdminSectionTitle(title: '缓存 (Redis)'),
          if (!redis.available)
            _unavailable('Redis 指标不可用')
          else ...[
            _AdminStatGrid(
              tiles: [
                _AdminStatTile(
                  label: '内存占用',
                  value: redis.memPercent != null
                      ? '${redis.memPercent!.toStringAsFixed(1)}%'
                      : '—',
                  sub: redis.usedMemory != null
                      ? '${_fmtResBytes(redis.usedMemory)} / ${_fmtResBytes(redis.maxmemory)}'
                      : null,
                  warn: (redis.memPercent ?? 0) >= 85,
                ),
                _AdminStatTile(
                  label: '键数量',
                  value: redis.keys != null ? redis.keys.toString() : '—',
                ),
                _AdminStatTile(
                  label: '命中率',
                  value: redis.hitRate != null
                      ? '${redis.hitRate!.toStringAsFixed(1)}%'
                      : '—',
                  sub: (redis.hits != null && redis.misses != null)
                      ? '命中 ${redis.hits} · 未命中 ${redis.misses}'
                      : null,
                ),
                _AdminStatTile(
                  label: '客户端连接',
                  value: redis.connectedClients != null
                      ? redis.connectedClients.toString()
                      : '—',
                  sub: redis.evictedKeys != null
                      ? '逐出 ${redis.evictedKeys}'
                      : null,
                  warn: (redis.evictedKeys ?? 0) > 0,
                ),
              ],
            ),
            if (redis.memPercent != null) ...[
              const SizedBox(height: 10),
              _ResUsageBar(percent: redis.memPercent!),
            ],
          ],
        ],
      ),
    );
  }

  Widget _unavailable(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        message,
        style: TextStyle(
          color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
