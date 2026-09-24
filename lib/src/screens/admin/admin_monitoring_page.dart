part of 'package:companion_flutter/main.dart';

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
      CompanionPageRoute<void>(
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
