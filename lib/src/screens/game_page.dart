part of 'package:companion_flutter/main.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key, required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  SudConfigResponse? _config;
  List<SudSession> _sessions = const [];
  SudSession? _activeSession;
  SudGamePlayMode _mode = SudGamePlayMode.versus;
  SudGameDifficulty _difficulty = SudGameDifficulty.newbie;
  _GameGroup? _activeGroup = _gameGroupCatalog.first;
  _GameTile _activeGame = _gameGroupCatalog.first.games[1];
  final List<String> _boardMarks = List.filled(9, '');
  final List<_GameTimelineItem> _timeline = [];
  bool _loading = true;
  bool _starting = false;
  bool _sendingEvent = false;
  String? _error;
  int _moveCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 18000),
      value: 0.5,
    );
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.api.getSudConfig(),
        widget.api.listSudSessions(),
      ]);
      if (!mounted) return;
      final sessions = results[1] as List<SudSession>;
      setState(() {
        _config = results[0] as SudConfigResponse;
        _sessions = sessions;
        _activeSession ??= sessions.isEmpty ? null : sessions.first;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _formatError(error);
        _loading = false;
      });
    }
  }

  Future<void> _startSession() async {
    final agentId = widget.session.agentId;
    if (agentId == null || agentId.isEmpty) {
      setState(() => _error = '还没有可用的 AI 伙伴，无法创建游戏房间。');
      return;
    }
    if (_starting) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final session = await widget.api.createSudSession(
        agentId: agentId,
        workspaceId: widget.session.workspaceId,
        conversationId: widget.session.conversationId,
        mgId: _resolvedMgId(),
        playMode: _mode,
        difficulty: _difficulty,
      );
      if (!mounted) return;
      setState(() {
        _activeSession = session;
        _sessions = [
          session,
          ..._sessions.where((item) => item.id != session.id),
        ];
        _resetBoard();
        _timeline.insert(
          0,
          _GameTimelineItem.system(
            '房间创建成功',
            '${session.roomId} · AI Lv.${session.aiLevel}',
          ),
        );
        if (session.companionReply != null &&
            session.companionReply!.isNotEmpty) {
          _timeline.insert(
            0,
            _GameTimelineItem.ai(
              session.aiPlayer.nickName,
              session.companionReply!,
            ),
          );
        }
        _trimTimeline();
      });
    } catch (error) {
      if (mounted) setState(() => _error = _formatError(error));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<SudSession?> _refreshCodeForNativeGame() async {
    final session = _activeSession;
    if (session == null) return null;
    try {
      final refreshed = await widget.api.refreshSudSessionCode(session.id);
      if (!mounted) return refreshed;
      setState(() {
        _activeSession = refreshed;
        _sessions = [
          refreshed,
          ..._sessions.where((item) => item.id != refreshed.id),
        ];
      });
      return refreshed;
    } catch (error) {
      if (mounted) setState(() => _error = _formatError(error));
      return null;
    }
  }

  Future<void> _ensureSessionAndSend(_GameDemoEvent event) async {
    if (_activeSession == null) {
      await _startSession();
    }
    await _sendEvent(event);
  }

  Future<void> _sendEvent(_GameDemoEvent event) async {
    final session = _activeSession;
    if (session == null || _sendingEvent) return;
    final payload = _payloadFor(event, session);
    setState(() {
      _sendingEvent = true;
      _error = null;
      _timeline.insert(0, _GameTimelineItem.user(event.label, event.detail));
      _trimTimeline();
    });
    await _sendRawEvent(
      sessionId: session.id,
      eventType: event.eventType,
      state: event.state,
      payload: payload,
    );
    if (mounted) setState(() => _sendingEvent = false);
  }

  Future<void> _openGame(_GameGroup group, _GameTile game) async {
    setState(() {
      _activeGroup = group;
      _activeGame = game;
    });
    if (!game.isOnline) return;
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => _SudGamePlayPage(
          api: widget.api,
          authSession: widget.session,
          initialConfig: _config,
          game: game,
        ),
      ),
    );
    if (mounted) unawaited(_load());
  }

  Future<void> _handleNativeEvent({
    required String eventType,
    String? state,
    Map<String, dynamic> payload = const {},
  }) async {
    final session = _activeSession;
    if (session == null) return;
    await _sendRawEvent(
      sessionId: session.id,
      eventType: eventType,
      state: state,
      payload: {
        ...payload,
        'source': 'sud_flutter_callback',
        'mg_id': session.mgId,
        'game_title': _activeGame.title,
        'play_mode': _mode.name,
        'difficulty': _difficulty.name,
      },
    );
  }

  Future<void> _sendRawEvent({
    required String sessionId,
    required String eventType,
    String? state,
    Map<String, dynamic> payload = const {},
  }) async {
    try {
      final response = await widget.api.sendSudGameEvent(
        sessionId: sessionId,
        eventType: eventType,
        state: state,
        payload: payload,
      );
      if (!mounted) return;
      setState(() {
        _activeSession = response.session;
        _error = null;
        _sessions = [
          response.session,
          ..._sessions.where((item) => item.id != response.session.id),
        ];
        final reply = response.companionReply;
        if (reply != null && reply.isNotEmpty) {
          _timeline.insert(
            0,
            _GameTimelineItem.ai(response.session.aiPlayer.nickName, reply),
          );
          _trimTimeline();
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = _formatError(error));
    }
  }

  String? _resolvedMgId() {
    if (_activeGame.mgId.isNotEmpty) return _activeGame.mgId;
    final configMgId = _config?.defaultMgId ?? '';
    if (configMgId.isNotEmpty) return configMgId;
    return _demoSudMgId;
  }

  void _resetBoard() {
    _moveCount = 0;
    for (var i = 0; i < _boardMarks.length; i += 1) {
      _boardMarks[i] = '';
    }
  }

  void _trimTimeline() {
    if (_timeline.length > 20) {
      _timeline.removeRange(20, _timeline.length);
    }
  }

  Map<String, dynamic> _payloadFor(_GameDemoEvent event, SudSession session) {
    final payload = <String, dynamic>{
      'mg_id': session.mgId,
      'game_title': _activeGame.title,
      'play_mode': _mode.name,
      'difficulty': _difficulty.name,
    };
    switch (event) {
      case _GameDemoEvent.gameStarted:
        payload['gameState'] = 'playing';
      case _GameDemoEvent.move:
        final slot = _nextBoardSlot();
        _boardMarks[slot] = _moveCount.isEven ? 'X' : 'O';
        _moveCount += 1;
        payload['move_index'] = slot;
        payload['piece'] = _boardMarks[slot];
      case _GameDemoEvent.levelSuccess:
        payload['checkpoint'] = 'demo-clear';
      case _GameDemoEvent.levelFailed:
        payload['checkpoint'] = 'demo-stuck';
      case _GameDemoEvent.gameSettleWin:
      case _GameDemoEvent.gameSettleLose:
      case _GameDemoEvent.gameSettleDraw:
        payload['gameRoundId'] = DateTime.now().microsecondsSinceEpoch
            .toString();
        payload['battle_duration'] = math.max(45, _moveCount * 18);
        payload['results'] = [
          {'uid': session.userPlayer.uid, 'isWin': event.userOutcomeValue},
          {'uid': session.aiPlayer.uid, 'isWin': event.aiOutcomeValue},
        ];
    }
    return payload;
  }

  int _nextBoardSlot() {
    final empty = _boardMarks.indexWhere((mark) => mark.isEmpty);
    if (empty >= 0) return empty;
    _resetBoard();
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = Curves.easeInOut.transform(_controller.value);
        return Scaffold(
          backgroundColor: const Color(0xFFF5F8FB),
          body: Stack(
            children: [
              _GameBackground(progress: progress),
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _topActions(context)),
                  SliverToBoxAdapter(child: _intro()),
                  SliverToBoxAdapter(child: _gameGroupsSection()),
                  const SliverToBoxAdapter(child: SizedBox(height: 126)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _topActions(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        MediaQuery.paddingOf(context).top + 12,
        18,
        10,
      ),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(38, 38),
            borderRadius: BorderRadius.circular(19),
            onPressed: () => Navigator.maybePop(context),
            child: _GlassButton(
              size: 38,
              child: const Icon(CupertinoIcons.chevron_left, size: 17),
            ),
          ),
          const Spacer(),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(36, 36),
            borderRadius: BorderRadius.circular(18),
            onPressed: _load,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: _glassDecoration(18),
              child: const Center(
                child: Text(
                  '刷新',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _intro() {
    final session = _activeSession;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LIVE MINI GAME',
            style: TextStyle(
              color: AppColors.accent,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '和 ${widget.session.agentName ?? 'AI'} 一起玩',
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 34,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            session == null
                ? '不用多说，一起玩一会儿就好'
                : '${session.roomId} · ${session.status}',
            style: TextStyle(
              color: AppColors.text.withValues(alpha: 0.56),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  value: session?.status ?? '未开局',
                  label: '状态',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  value: session == null ? '16' : 'Lv.${session.aiLevel}',
                  label: 'AI 强度',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  value: _config?.sdkEnabled == true ? 'SUD' : 'Demo',
                  label: '游戏源',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _readinessCard() {
    final config = _config;
    final message = _loading
        ? '正在读取 SUD 配置'
        : config?.sdkEnabled == true
        ? 'SUD 配置已就绪，可加载原生 Flutter PlatformView'
        : '后端游戏链路已接通，等待 SUD AppId/AppKey/AppSecret';
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: _GlassPanel(
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  config?.sdkEnabled == true
                      ? CupertinoIcons.checkmark_seal_fill
                      : CupertinoIcons.exclamationmark_triangle_fill,
                  color: config?.sdkEnabled == true
                      ? const Color(0xFF22A06B)
                      : const Color(0xFFFF8B2D),
                  size: 18,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 9),
              Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFCC3D3D),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (config != null && config.missingConfig.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '缺少配置：${config.missingConfig.join(', ')}',
                style: TextStyle(
                  color: AppColors.text.withValues(alpha: 0.56),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _modeControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: Column(
        children: [
          Row(
            children: [
              for (final mode in SudGamePlayMode.values) ...[
                Expanded(
                  child: _SegmentButton(
                    selected: _mode == mode,
                    icon: mode == SudGamePlayMode.versus
                        ? CupertinoIcons.scope
                        : CupertinoIcons.circle_grid_hex,
                    label: mode.title,
                    onTap: () => setState(() => _mode = mode),
                  ),
                ),
                if (mode != SudGamePlayMode.values.last)
                  const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 10),
          for (final difficulty in SudGameDifficulty.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DifficultyRow(
                difficulty: difficulty,
                selected: _difficulty == difficulty,
                onTap: () => setState(() => _difficulty = difficulty),
              ),
            ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _gameStage() {
    final session = _activeSession;
    final useNative = session?.canLoadNativeGame == true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: _GlassPanel(
        radius: 24,
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            SizedBox(
              height: 330,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: useNative
                    ? _SudNativeGameStage(
                        key: ValueKey('${session!.id}:${session.code}'),
                        session: session,
                        api: widget.api,
                        onRefreshCode: _refreshCodeForNativeGame,
                        onEvent: _handleNativeEvent,
                      )
                    : _LocalGameStage(
                        group: _activeGroup ?? _gameGroupCatalog.first,
                        tile: _activeGame,
                        marks: _boardMarks,
                        session: session,
                      ),
              ),
            ),
            const SizedBox(height: 12),
            CupertinoButton(
              padding: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(16),
              onPressed: _starting ? null : _startSession,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: _starting
                      ? AppColors.accent.withValues(alpha: 0.58)
                      : AppColors.accent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: _starting
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : Text(
                          session == null ? '创建游戏房间' : '重新开一局',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _eventControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '测试事件',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          GridView.count(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 3.25,
            children: [
              for (final event in _GameDemoEvent.values)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  borderRadius: BorderRadius.circular(14),
                  onPressed: _sendingEvent
                      ? null
                      : () => _ensureSessionAndSend(event),
                  child: Container(
                    decoration: _glassDecoration(14),
                    child: Center(
                      child: Text(
                        event.label,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _gameGroupsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: Column(
        children: [
          for (final group in _gameGroupCatalog)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GameGroupCard(
                group: group,
                isOpen: group == _activeGroup,
                activeGame: _activeGame,
                onTap: () => setState(() {
                  _activeGroup = group == _activeGroup ? null : group;
                }),
                onGameSelected: (game) => _openGame(group, game),
              ),
            ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _timelinePanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: _GlassPanel(
        radius: 22,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI 伴聊与事件流水',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            if (_timeline.isEmpty)
              Text(
                '创建房间后，这里会显示开局、落子、闯关和结算对应的话术。',
                style: TextStyle(
                  color: AppColors.text.withValues(alpha: 0.56),
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              for (final item in _timeline.take(8))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _TimelineRow(item: item),
                ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _recentSessions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '最近房间',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          if (_sessions.isEmpty)
            Text(
              '暂无历史房间。',
              style: TextStyle(
                color: AppColors.text.withValues(alpha: 0.52),
                fontSize: 12,
              ),
            )
          else
            for (final session in _sessions.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  borderRadius: BorderRadius.circular(14),
                  onPressed: () => setState(() {
                    _activeSession = session;
                    _mode = session.playMode;
                    _difficulty = session.difficulty;
                    _resetBoard();
                    _timeline.insert(
                      0,
                      _GameTimelineItem.system(
                        '切换到历史房间',
                        '${session.roomId} · ${session.status}',
                      ),
                    );
                    _trimTimeline();
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: _glassDecoration(14),
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.rectangle_stack_fill,
                          color: AppColors.accent,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.roomId,
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${session.playMode.title} · ${session.difficulty.title} · ${session.status}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.text.withValues(alpha: 0.54),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          _activeSession?.id == session.id
                              ? CupertinoIcons.checkmark_circle_fill
                              : CupertinoIcons.chevron_right,
                          color: AppColors.text.withValues(alpha: 0.42),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  String _formatError(Object error) {
    if (error is ApiException) return error.message;
    return error.toString();
  }
}

class _SudGamePlayPage extends StatefulWidget {
  const _SudGamePlayPage({
    required this.api,
    required this.authSession,
    required this.initialConfig,
    required this.game,
  });

  final CompanionApi api;
  final AuthSession authSession;
  final SudConfigResponse? initialConfig;
  final _GameTile game;

  @override
  State<_SudGamePlayPage> createState() => _SudGamePlayPageState();
}

class _SudGamePlayPageState extends State<_SudGamePlayPage> {
  SudConfigResponse? _config;
  SudSession? _session;
  List<SudSession> _rounds = const [];
  final List<_GameTimelineItem> _timeline = [];
  bool _roundsLoading = true;
  bool _starting = false;
  String? _error;
  String? _roundsError;

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
    if (_config == null) unawaited(_loadConfig());
    unawaited(_loadRounds());
  }

  Future<void> _loadConfig() async {
    try {
      final config = await widget.api.getSudConfig();
      if (mounted) setState(() => _config = config);
    } catch (error) {
      if (mounted) setState(() => _error = _formatError(error));
    }
  }

  Future<void> _loadRounds() async {
    if (!mounted) return;
    setState(() {
      _roundsLoading = true;
      _roundsError = null;
    });
    try {
      final sessions = await widget.api.listSudSessions();
      final mgId = _resolvedMgId();
      if (!mounted) return;
      setState(() {
        _rounds = sessions
            .where(
              (item) => item.mgId == mgId && _GameRoundSummary.canShow(item),
            )
            .toList();
        _roundsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _roundsLoading = false;
        _roundsError = _formatError(error);
      });
    }
  }

  Future<void> _startSession() async {
    final agentId = widget.authSession.agentId;
    if (agentId == null || agentId.isEmpty) {
      setState(() => _error = '还没有可用的 AI 伙伴，无法创建游戏房间。');
      return;
    }
    if (_starting) return;
    setState(() {
      _starting = true;
      _error = null;
      _timeline.clear();
    });
    try {
      final session = await widget.api.createSudSession(
        agentId: agentId,
        workspaceId: widget.authSession.workspaceId,
        conversationId: widget.authSession.conversationId,
        mgId: _resolvedMgId(),
        playMode: SudGamePlayMode.versus,
        difficulty: SudGameDifficulty.newbie,
      );
      if (!mounted) return;
      setState(() {
        _session = session;
        _timeline.insert(
          0,
          _GameTimelineItem.system(
            '房间创建成功',
            '${session.roomId} · AI Lv.${session.aiLevel}',
          ),
        );
        final reply = session.companionReply;
        if (reply != null && reply.isNotEmpty) {
          _timeline.insert(
            0,
            _GameTimelineItem.ai(session.aiPlayer.nickName, reply),
          );
        }
        _trimTimeline();
      });
      unawaited(_loadRounds());
    } catch (error) {
      if (mounted) setState(() => _error = _formatError(error));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<SudSession?> _refreshCode() async {
    final session = _session;
    if (session == null) return null;
    try {
      final refreshed = await widget.api.refreshSudSessionCode(session.id);
      if (mounted) setState(() => _session = refreshed);
      return refreshed;
    } catch (error) {
      if (mounted) setState(() => _error = _formatError(error));
      return null;
    }
  }

  Future<void> _handleNativeEvent({
    required String eventType,
    String? state,
    Map<String, dynamic> payload = const {},
  }) async {
    final session = _session;
    if (session == null) return;
    try {
      final response = await widget.api.sendSudGameEvent(
        sessionId: session.id,
        eventType: eventType,
        state: state,
        payload: {
          ...payload,
          'source': 'sud_flutter_callback',
          'mg_id': session.mgId,
          'game_title': widget.game.title,
          'play_mode': session.playMode.name,
          'difficulty': session.difficulty.name,
        },
      );
      if (!mounted) return;
      setState(() {
        _session = response.session;
        _error = null;
        final reply = response.companionReply;
        if (reply != null && reply.isNotEmpty) {
          _timeline.insert(
            0,
            _GameTimelineItem.ai(response.session.aiPlayer.nickName, reply),
          );
          _trimTimeline();
        }
      });
      if (_GameRoundSummary.canShow(response.session)) {
        unawaited(_loadRounds());
      }
    } catch (error) {
      if (mounted) setState(() => _error = _formatError(error));
    }
  }

  String? _resolvedMgId() {
    if (widget.game.mgId.isNotEmpty) return widget.game.mgId;
    final configMgId = _config?.defaultMgId ?? '';
    if (configMgId.isNotEmpty) return configMgId;
    return _demoSudMgId;
  }

  void _trimTimeline() {
    if (_timeline.length > 10) {
      _timeline.removeRange(10, _timeline.length);
    }
  }

  String _formatError(Object error) {
    if (error is ApiException) return error.message;
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final canLoadGame = session?.canLoadNativeGame == true;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FB),
      body: Stack(
        children: [
          const _GameBackground(progress: 0.5),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _playHeader(context)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                  child: _GlassPanel(
                    radius: 24,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 420,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: canLoadGame
                                ? _SudNativeGameStage(
                                    key: ValueKey(
                                      '${session!.id}:${session.code}',
                                    ),
                                    session: session,
                                    api: widget.api,
                                    onRefreshCode: _refreshCode,
                                    onEvent: _handleNativeEvent,
                                  )
                                : _GamePlaceholderStage(game: widget.game),
                          ),
                        ),
                        const SizedBox(height: 12),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          borderRadius: BorderRadius.circular(16),
                          onPressed: _starting ? null : _startSession,
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: _starting
                                  ? AppColors.accent.withValues(alpha: 0.58)
                                  : AppColors.accent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: _starting
                                  ? const CupertinoActivityIndicator(
                                      color: Colors.white,
                                    )
                                  : Text(
                                      session == null ? '开始游戏' : '重新开一局',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _playTimeline()),
              SliverToBoxAdapter(child: _roundHistorySection()),
              const SliverToBoxAdapter(child: SizedBox(height: 42)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _playHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        MediaQuery.paddingOf(context).top + 12,
        18,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(38, 38),
            borderRadius: BorderRadius.circular(19),
            onPressed: () => Navigator.maybePop(context),
            child: _GlassButton(
              size: 38,
              child: const Icon(CupertinoIcons.chevron_left, size: 17),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.game.title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 34,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _session == null
                ? '和 ${widget.authSession.agentName ?? 'AI'} 开一局'
                : '${_session!.roomId} · ${_session!.status}',
            style: TextStyle(
              color: AppColors.text.withValues(alpha: 0.56),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFCC3D3D),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _playTimeline() {
    if (_timeline.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: _GlassPanel(
        radius: 22,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI 伴聊',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            for (final item in _timeline.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TimelineRow(item: item),
              ),
          ],
        ),
      ),
    );
  }

  Widget _roundHistorySection() {
    final summaries = _rounds.map(_GameRoundSummary.fromSession).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      child: _GlassPanel(
        radius: 24,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '游戏回顾',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                if (summaries.isNotEmpty)
                  _SoftCountPill(text: '${summaries.length} 局'),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '每一局都先收起来，等你想回味的时候再打开。',
              style: TextStyle(
                color: AppColors.text.withValues(alpha: 0.50),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            if (_roundsLoading)
              const SizedBox(
                height: 72,
                child: Center(child: CupertinoActivityIndicator()),
              )
            else if (_roundsError != null)
              _GameRoundEmptyState(
                icon: CupertinoIcons.exclamationmark_triangle,
                title: '回顾暂时没拉到',
                subtitle: _roundsError!,
              )
            else if (summaries.isEmpty)
              const _GameRoundEmptyState(
                icon: CupertinoIcons.sparkles,
                title: '还没有完成的对局',
                subtitle: '玩完一局后，这里会留下你和 AI 的小小战绩。',
              )
            else
              Column(
                children: [
                  for (final summary in summaries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _GameRoundCard(
                        summary: summary,
                        onTap: () => _showRoundDetail(summary),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showRoundDetail(_GameRoundSummary summary) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: false,
      builder: (context) => _GameRoundDetailSheet(summary: summary),
    );
  }
}

class _GameRoundSummary {
  const _GameRoundSummary({
    required this.session,
    required this.outcome,
    required this.userScore,
    required this.aiScore,
    required this.durationSeconds,
    required this.playedAt,
    required this.userExtras,
    required this.aiName,
    required this.roomId,
  });

  final SudSession session;
  final String outcome;
  final int? userScore;
  final int? aiScore;
  final int? durationSeconds;
  final DateTime? playedAt;
  final Map<String, dynamic> userExtras;
  final String aiName;
  final String roomId;

  static bool canShow(SudSession session) {
    return session.result != null &&
        {'settled', 'aborted'}.contains(session.status);
  }

  factory _GameRoundSummary.fromSession(SudSession session) {
    final result = session.result ?? const <String, dynamic>{};
    final user = _asMap(result['user']);
    final ai = _asMap(result['ai']);
    final outcome = (result['user_outcome'] ?? session.status).toString();
    return _GameRoundSummary(
      session: session,
      outcome: outcome,
      userScore: _intValue(user['score']),
      aiScore: _intValue(ai['score']),
      durationSeconds:
          session.durationSeconds ?? _intValue(result['duration_seconds']),
      playedAt: session.endedAt ?? session.startedAt ?? session.createdAt,
      userExtras: _asMap(result['user_extras']),
      aiName: session.aiPlayer.nickName.isEmpty
          ? 'AI'
          : session.aiPlayer.nickName,
      roomId: session.roomId,
    );
  }

  bool get isWin => outcome == 'win';
  bool get isLose => outcome == 'lose';
  bool get isAborted => outcome == 'aborted' || session.status == 'aborted';

  String get resultLabel {
    if (isAborted) return '未完成';
    if (isWin) return '你赢了';
    if (isLose) return '$aiName 小赢';
    if (outcome == 'draw') return '平局';
    return '已结束';
  }

  String get title {
    if (isAborted) return '这局先停在半路';
    if (isWin) return '这一局你拿下了';
    if (isLose) return '差一点，节奏已经起来了';
    if (outcome == 'draw') return '谁也没让谁舒服';
    return '留下了一局记录';
  }

  String get subtitle {
    final fragments = <String>[];
    final scoreText = scoreLine;
    if (scoreText != null) fragments.add(scoreText);
    final combo = comboLine;
    if (combo != null) fragments.add(combo);
    if (fragments.isEmpty && durationText != null) fragments.add(durationText!);
    return fragments.isEmpty ? '点开看看这一局发生了什么。' : fragments.join(' · ');
  }

  String? get scoreLine {
    if (userScore == null || aiScore == null) return null;
    return '你 $userScore : $aiScore $aiName';
  }

  String? get durationText {
    final seconds = durationSeconds;
    if (seconds == null || seconds <= 0) return null;
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    if (minutes <= 0) return '$rest 秒';
    if (rest == 0) return '$minutes 分钟';
    return '$minutes 分 $rest 秒';
  }

  String? get comboLine {
    final perfect = _intValue(userExtras['numPerfect']) ?? 0;
    final excellent = _intValue(userExtras['numExcellent']) ?? 0;
    final crazy = _intValue(userExtras['numCrazy']) ?? 0;
    final good = _intValue(userExtras['numGood']) ?? 0;
    if (crazy > 0) return '$crazy 次 Crazy';
    if (excellent > 0) return '$excellent 次 Excellent';
    if (perfect > 0) return '$perfect 次 Perfect';
    if (good > 0) return '$good 次 Good';
    return null;
  }

  List<_RoundDetailMetric> get metrics {
    final items = <_RoundDetailMetric>[];
    if (scoreLine != null) {
      items.add(_RoundDetailMetric('比分', scoreLine!));
    }
    if (durationText != null) {
      items.add(_RoundDetailMetric('时长', durationText!));
    }
    final perfect = _intValue(userExtras['numPerfect']) ?? 0;
    final good = _intValue(userExtras['numGood']) ?? 0;
    final excellent = _intValue(userExtras['numExcellent']) ?? 0;
    final crazy = _intValue(userExtras['numCrazy']) ?? 0;
    if (perfect + good + excellent + crazy > 0) {
      items.add(
        _RoundDetailMetric(
          '手感',
          [
            if (perfect > 0) '$perfect Perfect',
            if (excellent > 0) '$excellent Excellent',
            if (crazy > 0) '$crazy Crazy',
            if (good > 0) '$good Good',
          ].join(' · '),
        ),
      );
    }
    items.add(_RoundDetailMetric('房间', roomId));
    return items;
  }

  Color get accent {
    if (isWin) return const Color(0xFF19A56F);
    if (isLose) return const Color(0xFF178BFF);
    if (isAborted) return const Color(0xFF8996A6);
    return const Color(0xFF8B5CF6);
  }
}

class _RoundDetailMetric {
  const _RoundDetailMetric(this.label, this.value);

  final String label;
  final String value;
}

class _GameRoundCard extends StatelessWidget {
  const _GameRoundCard({required this.summary, required this.onTap});

  final _GameRoundSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = summary.accent;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(18),
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.54),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                summary.isAborted
                    ? CupertinoIcons.pause_fill
                    : summary.isWin
                    ? CupertinoIcons.sparkles
                    : CupertinoIcons.game_controller_solid,
                color: accent,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          summary.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _SoftCountPill(text: summary.resultLabel, color: accent),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    summary.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.text.withValues(alpha: 0.56),
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              CupertinoIcons.chevron_forward,
              color: AppColors.text.withValues(alpha: 0.30),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _GameRoundEmptyState extends StatelessWidget {
  const _GameRoundEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.70)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.text.withValues(alpha: 0.50),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

class _SoftCountPill extends StatelessWidget {
  const _SoftCountPill({required this.text, this.color = AppColors.accent});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _GameRoundDetailSheet extends StatelessWidget {
  const _GameRoundDetailSheet({required this.summary});

  final _GameRoundSummary summary;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 14, 20, bottom + 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FBFF).withValues(alpha: 0.94),
                border: Border.all(color: Colors.white.withValues(alpha: 0.80)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.text.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: summary.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            CupertinoIcons.game_controller_solid,
                            color: summary.accent,
                            size: 25,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                summary.resultLabel,
                                style: TextStyle(
                                  color: summary.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                summary.title,
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 21,
                                  height: 1.08,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _roundMemorySentence(summary),
                      style: TextStyle(
                        color: AppColors.text.withValues(alpha: 0.66),
                        fontSize: 13,
                        height: 1.38,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final metric in summary.metrics)
                          _RoundMetricChip(metric: metric),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundMetricChip extends StatelessWidget {
  const _RoundMetricChip({required this.metric});

  final _RoundDetailMetric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            metric.label,
            style: TextStyle(
              color: AppColors.text.withValues(alpha: 0.44),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            metric.value,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 13,
              height: 1.18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

String _roundMemorySentence(_GameRoundSummary summary) {
  if (summary.isAborted) {
    return '这局没有完整打完，但它也算一次共同经历。下次回来，可以从同样的节奏重新开。';
  }
  if (summary.isWin) {
    return '这局更像是你把手感慢慢攒起来的一局。不是冷冰冰的胜负，它会留在你们的游戏记忆里。';
  }
  if (summary.isLose) {
    return '这局虽然输了，但里面有几段节奏值得留下。下次再玩，AI 可以接着这个手感陪你调整。';
  }
  return '这局没有明显输赢，倒像是两个人一起试了一次节奏。';
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

int? _intValue(Object? value) {
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}

class _SudNativeGameStage extends StatefulWidget {
  const _SudNativeGameStage({
    super.key,
    required this.session,
    required this.api,
    required this.onRefreshCode,
    required this.onEvent,
  });

  final SudSession session;
  final CompanionApi api;
  final Future<SudSession?> Function() onRefreshCode;
  final Future<void> Function({
    required String eventType,
    String? state,
    Map<String, dynamic> payload,
  })
  onEvent;

  @override
  State<_SudNativeGameStage> createState() => _SudNativeGameStageState();
}

class _SudNativeGameStageState extends State<_SudNativeGameStage>
    with WidgetsBindingObserver {
  final GlobalKey _viewKey = GlobalKey();
  late final SudGIPFSMGameDelegate _fsmGame;
  Widget? _platformView;
  int? _platformViewId;
  String? _loadedSessionKey;
  String? _status;
  bool _entryStateSynced = false;
  bool _exitReported = false;
  bool _nativeGameStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fsmGame = SudGIPFSMGameDelegate(
      onGameLoadingProgress: (stage, retCode, progress) {
        final code = (retCode as num?)?.round() ?? 0;
        if (code != 0) {
          final message = '加载失败 $code · $stage';
          if (mounted) setState(() => _status = message);
          widget.onEvent(
            eventType: 'game_load_failed',
            payload: {'stage': stage, 'ret_code': code, 'progress': progress},
          );
          return;
        }
        if (mounted) setState(() => _status = '加载中 $progress%');
      },
      onGameStarted: () {
        _nativeGameStarted = true;
        if (mounted) setState(() => _status = '游戏已启动');
        unawaited(_syncEntryStateToGame());
        widget.onEvent(
          eventType: 'game_started',
          payload: {'gameState': 'playing'},
        );
      },
      onGameDestroyed: () {
        if (mounted) setState(() => _status = '游戏已销毁');
        unawaited(_reportGameExit('destroyed', eventType: 'game_destroyed'));
      },
      onExpireCode: (_) async {
        final refreshed = await widget.onRefreshCode();
        final viewId = _platformViewId;
        if (refreshed != null && viewId != null) {
          await SudGipPlugin.updateCode(viewId, refreshed.code);
        }
      },
      onGameStateChange: (state, dataJson) {
        final payload = _decodeJson(dataJson);
        widget.onEvent(
          eventType: _eventTypeForSudState(state),
          state: state,
          payload: payload,
        );
      },
      onPlayerStateChange: (userId, state, dataJson) {
        widget.onEvent(
          eventType: 'sud_player_state',
          state: state,
          payload: {'uid': userId, ..._decodeJson(dataJson)},
        );
      },
    );
    _platformView = getSudGIPPlatformView((viewId) {
      _platformViewId = viewId;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadGame());
    });
  }

  @override
  void didUpdateWidget(covariant _SudNativeGameStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.id != widget.session.id ||
        oldWidget.session.code != widget.session.code) {
      _entryStateSynced = false;
      _nativeGameStarted = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadGame());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_reportGameExit('page_disposed'));
    final viewId = _platformViewId;
    if (viewId != null) {
      SudGipPlugin.removeFSMGame(viewId);
      SudGipPlugin.destroyGame(viewId);
      SudGipPlugin.dispose(viewId);
    }
    super.dispose();
  }

  Future<void> _reportGameExit(
    String reason, {
    String eventType = 'game_exited',
  }) async {
    if (_exitReported) return;
    if (!_nativeGameStarted && eventType != 'game_destroyed') return;
    _exitReported = true;
    await widget.onEvent(
      eventType: eventType,
      payload: {'reason': reason, 'gameState': 'aborted'},
    );
  }

  Future<void> _loadGame() async {
    final viewId = _platformViewId;
    if (viewId == null || !mounted) return;
    final session = widget.session;
    final sessionKey = '${session.id}:${session.code}';
    if (_loadedSessionKey == sessionKey) return;
    _loadedSessionKey = sessionKey;
    setState(() => _status = '初始化 SudGIP');
    try {
      final initResult = await SudGipPlugin.initSDKWithEnv(
        session.appId,
        session.appKey,
        session.userId,
        session.isTestEnv,
      );
      if ((initResult['retCode'] as num?)?.round() != 0) {
        setState(() => _status = 'SDK 初始化失败 ${initResult['retMsg'] ?? ''}');
        return;
      }
      await SudGipCfgPlugin.setShowCustomLoading(true);
      SudGipPlugin.setFSMGame(viewId, _fsmGame);
      final loadResult = await SudGipPlugin.loadGame(
        viewId,
        session.userId,
        session.roomId,
        session.code,
        session.mgId,
        'zh-CN',
        _gameViewInfoJson(),
        _gameConfigJson(),
      );
      if (!mounted) return;
      final retCode = (loadResult['retCode'] as num?)?.round() ?? -1;
      setState(() {
        _status = retCode == 0
            ? '正在进入游戏'
            : '加载失败 ${loadResult['retMsg'] ?? retCode}';
      });
      if (retCode == 0) {
        widget.onEvent(eventType: 'sdk_ready', payload: {'view_id': viewId});
      }
    } catch (error) {
      if (mounted) setState(() => _status = '原生游戏加载异常：$error');
    }
  }

  Future<void> _syncEntryStateToGame() async {
    final viewId = _platformViewId;
    if (viewId == null || _entryStateSynced) return;
    _entryStateSynced = true;
    final session = widget.session;
    try {
      await _notifyGameState('app_common_self_in', {
        'isIn': true,
        'seatIndex': 0,
        'isSeatRandom': false,
        'isRandom': false,
        'teamId': 1,
      });
      final gameSetting = _gameSettingSelectInfo(session);
      if (gameSetting != null) {
        await _notifyGameState(
          'app_common_game_setting_select_info',
          gameSetting,
        );
      }
      await _notifyGameState('app_common_self_ready', {'isReady': true});
      await _notifyGameState('app_common_self_captain', {
        'curCaptainUID': session.userId,
      });
      await _notifyGameState('app_common_game_add_ai_players', {
        'aiPlayers': [
          {
            'userId': session.aiPlayer.uid,
            'avatar': session.aiPlayer.avatarUrl,
            'name': session.aiPlayer.nickName,
            'gender': session.aiPlayer.gender.isEmpty
                ? 'male'
                : session.aiPlayer.gender,
            'level': session.aiPlayer.aiLevel,
          },
        ],
        'isReady': 1,
      });
      if (!mounted) return;
      setState(() => _status = '真人和 AI 已准备');
      widget.onEvent(
        eventType: 'sud_entry_synced',
        payload: {
          'view_id': viewId,
          'user_id': session.userId,
          'ai_user_id': session.aiPlayer.uid,
        },
      );
    } catch (error) {
      _entryStateSynced = false;
      if (mounted) setState(() => _status = '入座/准备同步失败：$error');
    }
  }

  Map<String, dynamic>? _gameSettingSelectInfo(SudSession session) {
    if (session.mgId == _monsterCrushSudMgId) {
      return {
        'MonsterCrush': {
          'mode_ex': session.playMode == SudGamePlayMode.cooperate ? 2 : 1,
        },
      };
    }
    return null;
  }

  Future<void> _notifyGameState(
    String state,
    Map<String, dynamic> payload,
  ) async {
    final viewId = _platformViewId;
    if (viewId == null) return;
    final result = await SudGipPlugin.notifyStateChange(
      viewId,
      state,
      jsonEncode(payload),
    );
    final retCode = (result['retCode'] as num?)?.round() ?? -1;
    if (retCode != 0) {
      throw StateError('$state ${result['retMsg'] ?? retCode}');
    }
  }

  String _gameViewInfoJson() {
    final box = _viewKey.currentContext?.findRenderObject() as RenderBox?;
    final size = box?.size ?? const Size(1, 1);
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return jsonEncode({
      'ret_code': 0,
      'ret_msg': 'success',
      'view_size': {
        'width': (size.width * ratio).ceil(),
        'height': (size.height * ratio).ceil(),
      },
      'view_game_rect': {
        'left': 0,
        'top': (72 * ratio).ceil(),
        'right': 0,
        'bottom': (116 * ratio).ceil(),
      },
    });
  }

  String _gameConfigJson() {
    return jsonEncode({
      'gameMode': 1,
      'gameCPU': 0,
      'gameSoundControl': 0,
      'gameSoundVolume': 100,
      'viewScale': 1.0,
      'autoScale': 0,
      'ui': {
        'ping': {'hide': false},
        'share_btn': {'hide': true},
        'game_bg': {'hide': false},
      },
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final viewId = _platformViewId;
    if (viewId == null) return;
    if (state == AppLifecycleState.paused) {
      SudGipPlugin.pauseGame(viewId);
    } else if (state == AppLifecycleState.resumed) {
      SudGipPlugin.playGame(viewId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: _viewKey,
      fit: StackFit.expand,
      children: [
        ColoredBox(color: const Color(0xFF111827), child: _platformView),
        Positioned(
          left: 14,
          top: 14,
          child: _NativeBadge(text: _status ?? 'SudGIP PlatformView'),
        ),
      ],
    );
  }

  Map<String, dynamic> _decodeJson(String value) {
    if (value.isEmpty) return const {};
    try {
      final decoded = jsonDecode(value);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : const {};
    } catch (_) {
      return {'raw': value};
    }
  }

  String _eventTypeForSudState(String state) {
    final lower = state.toLowerCase();
    if (lower.contains('settle')) return 'game_settle';
    if (lower.contains('player_scores')) return 'game_player_scores';
    if (lower.contains('ranking')) return 'game_ranking';
    if (lower.contains('game_info')) return 'game_process_info';
    if (lower.contains('ai_message')) return 'sud_ai_message';
    if (lower.contains('start')) return 'game_started';
    if (lower.contains('game_state')) return 'sud_game_state';
    return 'sud_$state';
  }
}

class _GameBackground extends StatelessWidget {
  const _GameBackground({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8FBFF), Color(0xFFFFFBF5), Color(0xFFEFF8F6)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _BoardBackgroundPainter()),
          ),
          Positioned(
            right: -86 + progress * 18,
            top: 88,
            child: _SoftField(
              size: const Size(260, 230),
              color: const Color(0x353D9EFF),
            ),
          ),
          Positioned(
            left: -120,
            top: 318 + progress * 16,
            child: _SoftField(
              size: const Size(270, 230),
              color: const Color(0x30FF7A3D),
            ),
          ),
          Positioned(
            right: -92,
            bottom: 180,
            child: _SoftField(
              size: const Size(300, 240),
              color: const Color(0x2D18C6C0),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftField extends StatelessWidget {
  const _SoftField({required this.size, required this.color});

  final Size size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 44, sigmaY: 44),
      child: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _BoardBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0A142235)
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += 38) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += 38) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: _glassDecoration(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: AppColors.text.withValues(alpha: 0.48),
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(14),
      onPressed: onTap,
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent
              : Colors.white.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.70)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? Colors.white : AppColors.text,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyRow extends StatelessWidget {
  const _DifficultyRow({
    required this.difficulty,
    required this.selected,
    required this.onTap,
  });

  final SudGameDifficulty difficulty;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(14),
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: selected ? 0.76 : 0.46),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.68)),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? CupertinoIcons.largecircle_fill_circle
                  : CupertinoIcons.circle,
              color: selected
                  ? AppColors.accent
                  : AppColors.text.withValues(alpha: 0.32),
              size: 16,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    difficulty.title,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    difficulty.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.text.withValues(alpha: 0.54),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalGameStage extends StatelessWidget {
  const _LocalGameStage({
    required this.group,
    required this.tile,
    required this.marks,
    required this.session,
  });

  final _GameGroup group;
  final _GameTile tile;
  final List<String> marks;
  final SudSession? session;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: group.accent,
        image: DecorationImage(
          image: AssetImage(group.hero),
          fit: BoxFit.cover,
          opacity: 0.30,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.08),
              Colors.black.withValues(alpha: 0.52),
            ],
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tile.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session?.status ?? '本地游戏壳',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                _NativeBadge(
                  text: session?.code.isNotEmpty == true
                      ? 'code ready'
                      : 'waiting',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: [
                  for (var i = 0; i < 9; i += 1)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.20),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          i < marks.length ? marks[i] : '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  session?.roomId ?? 'no room',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.76),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  session?.mgId ??
                      (tile.mgId.isEmpty ? _demoSudMgId : tile.mgId),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.76),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GamePlaceholderStage extends StatelessWidget {
  const _GamePlaceholderStage({required this.game});

  final _GameTile game;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(game.image),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.08),
              Colors.black.withValues(alpha: 0.70),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NativeBadge(text: game.isOnline ? '已上线' : '待上线'),
            const Spacer(),
            Text(
              game.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              game.note,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.76),
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NativeBadge extends StatelessWidget {
  const _NativeBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _PressScale extends StatefulWidget {
  const _PressScale({
    required this.child,
    required this.onTap,
    this.pressedScale = 0.975,
    this.borderRadius = 18,
  });

  final Widget child;
  final VoidCallback onTap;
  final double pressedScale;
  final double borderRadius;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: widget.child,
        ),
      ),
    );
  }
}

class _GameGroupCard extends StatelessWidget {
  const _GameGroupCard({
    required this.group,
    required this.isOpen,
    required this.activeGame,
    required this.onTap,
    required this.onGameSelected,
  });

  final _GameGroup group;
  final bool isOpen;
  final _GameTile activeGame;
  final VoidCallback onTap;
  final ValueChanged<_GameTile> onGameSelected;

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      onTap: onTap,
      pressedScale: 0.985,
      borderRadius: 26,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: group.accent.withValues(alpha: isOpen ? 0.13 : 0.08),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
          boxShadow: [
            BoxShadow(
              color: group.accent.withValues(alpha: isOpen ? 0.15 : 0.07),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                height: isOpen ? 184 : 128,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(group.hero, fit: BoxFit.cover),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.72),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.kicker,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              group.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              group.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: 12,
                                height: 1.28,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _WhiteChip(text: group.badge),
                                const SizedBox(width: 7),
                                _WhiteChip(text: group.metric),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 360),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final curved = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  );
                  return FadeTransition(
                    opacity: curved,
                    child: SizeTransition(
                      sizeFactor: curved,
                      alignment: const AlignmentDirectional(-1.0, -1.0),
                      child: child,
                    ),
                  );
                },
                child: isOpen
                    ? Padding(
                        key: ValueKey(group.id),
                        padding: const EdgeInsets.only(top: 10),
                        child: GridView.count(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.18,
                          children: [
                            for (final game in group.games)
                              _SmallGameTile(
                                game: game,
                                selected: game == activeGame,
                                onTap: () => onGameSelected(game),
                              ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallGameTile extends StatefulWidget {
  const _SmallGameTile({
    required this.game,
    required this.selected,
    required this.onTap,
  });

  final _GameTile game;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SmallGameTile> createState() => _SmallGameTileState();
}

class _SmallGameTileState extends State<_SmallGameTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathController;
  late final Animation<double> _breath;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    final staggerMs = widget.game.title.hashCode.abs() % 900;
    _breathController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 4300 + staggerMs),
      value: (widget.game.title.hashCode.abs() % 1000) / 1000,
    )..repeat(reverse: true);
    _breath = Tween<double>(begin: 1.0, end: 1.09).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOutSine),
    );
    _glow = Tween<double>(begin: 0.0, end: 0.16).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      onTap: widget.onTap,
      pressedScale: 0.965,
      borderRadius: 18,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _breathController,
              builder: (context, child) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Transform.scale(scale: _breath.value, child: child),
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(-0.35, -0.45),
                            radius: 0.9,
                            colors: [
                              Colors.white.withValues(alpha: _glow.value),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.74],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
              child: Image.asset(
                widget.game.image,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.76),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 8,
              top: 8,
              child: _GameStatusTag(isOnline: widget.game.isOnline),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.game.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.game.note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 10,
                      height: 1.24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameStatusTag extends StatelessWidget {
  const _GameStatusTag({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isOnline ? null : Colors.white.withValues(alpha: 0.20),
        gradient: isOnline
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF64EAA2),
                  Color(0xFF19C778),
                  Color(0xFF078E55),
                ],
                stops: [0.0, 0.52, 1.0],
              )
            : null,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isOnline
              ? Colors.white.withValues(alpha: 0.58)
              : Colors.white.withValues(alpha: 0.18),
        ),
        boxShadow: isOnline
            ? [
                BoxShadow(
                  color: const Color(0xFF03A85E).withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.20),
                  blurRadius: 5,
                  offset: const Offset(0, -1),
                ),
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isOnline)
            Positioned.fill(
              top: 1,
              bottom: 13,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  color: Colors.white.withValues(alpha: 0.20),
                ),
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isOnline) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.70),
                        blurRadius: 7,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                isOnline ? '已上线' : '待上线',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: isOnline ? 1 : 0.86),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WhiteChip extends StatelessWidget {
  const _WhiteChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.item});

  final _GameTimelineItem item;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.role) {
      _TimelineRole.system => AppColors.accent,
      _TimelineRole.user => const Color(0xFFFF7A3D),
      _TimelineRole.ai => const Color(0xFF22A06B),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: item.role == _TimelineRole.ai ? 0.70 : 0.48,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.detail,
                  style: TextStyle(
                    color: AppColors.text.withValues(alpha: 0.58),
                    fontSize: 12,
                    height: 1.36,
                    fontWeight: FontWeight.w600,
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

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    required this.radius,
    required this.padding,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: _glassDecoration(radius),
          child: child,
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: _glassDecoration(size / 2),
      child: Center(child: child),
    );
  }
}

BoxDecoration _glassDecoration(double radius) {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: 0.60),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF40546A).withValues(alpha: 0.10),
        blurRadius: 24,
        offset: const Offset(0, 12),
      ),
    ],
  );
}

enum _TimelineRole { system, user, ai }

class _GameTimelineItem {
  const _GameTimelineItem(this.role, this.title, this.detail);

  factory _GameTimelineItem.system(String title, String detail) =>
      _GameTimelineItem(_TimelineRole.system, title, detail);

  factory _GameTimelineItem.user(String title, String detail) =>
      _GameTimelineItem(_TimelineRole.user, title, detail);

  factory _GameTimelineItem.ai(String title, String detail) =>
      _GameTimelineItem(_TimelineRole.ai, title, detail);

  final _TimelineRole role;
  final String title;
  final String detail;
}

enum _GameDemoEvent {
  gameStarted('开局', '向后端发送 game_started', 'game_started', null, 0, 0),
  move('落子', '向后端发送 move，并更新本地棋盘', 'move', null, 0, 0),
  levelSuccess('闯关成功', '向后端发送 level_success', 'level_success', null, 0, 0),
  levelFailed('闯关失败', '向后端发送 level_failed', 'level_failed', null, 0, 0),
  gameSettleWin(
    '结算·用户胜',
    '向后端发送 game_settle，用户结果为胜',
    'game_settle',
    'mg_common_game_settle',
    2,
    1,
  ),
  gameSettleLose(
    '结算·AI 胜',
    '向后端发送 game_settle，用户结果为负',
    'game_settle',
    'mg_common_game_settle',
    1,
    2,
  ),
  gameSettleDraw(
    '结算·平局',
    '向后端发送 game_settle，用户结果为平',
    'game_settle',
    'mg_common_game_settle',
    3,
    3,
  );

  const _GameDemoEvent(
    this.label,
    this.detail,
    this.eventType,
    this.state,
    this.userOutcomeValue,
    this.aiOutcomeValue,
  );

  final String label;
  final String detail;
  final String eventType;
  final String? state;
  final int userOutcomeValue;
  final int aiOutcomeValue;
}

class _GameGroup {
  const _GameGroup({
    required this.id,
    required this.kicker,
    required this.title,
    required this.badge,
    required this.metric,
    required this.hero,
    required this.accent,
    required this.description,
    required this.games,
  });

  final String id;
  final String kicker;
  final String title;
  final String badge;
  final String metric;
  final String hero;
  final Color accent;
  final String description;
  final List<_GameTile> games;
}

class _GameTile {
  const _GameTile({
    required this.title,
    required this.note,
    required this.image,
    required this.mgId,
  });

  final String title;
  final String note;
  final String image;
  final String mgId;

  bool get isOnline => mgId.isNotEmpty;
}

const _gomokuSudMgId = '1676069429630722049';
const _monsterCrushSudMgId = '1664525565526667266';
const _demoSudMgId = _gomokuSudMgId;

const _gameGroupCatalog = [
  _GameGroup(
    id: 'board',
    kicker: 'slow strategy',
    title: '棋牌游戏',
    badge: '静心对弈',
    metric: '4 款棋类',
    hero: 'assets/prototype/games/category-board-hero.jpg',
    accent: Color(0xFF1F6FFF),
    description: '从安静落子开始，不急着赢，只把这一局慢慢下完。',
    games: [
      _GameTile(
        title: '围棋',
        note: '黑白落子，适合慢慢想。',
        image: 'assets/prototype/games/go-conquest.jpg',
        mgId: '',
      ),
      _GameTile(
        title: '五子棋',
        note: '五子连线，几分钟开局。',
        image: 'assets/prototype/games/gomoku-lets-go.jpg',
        mgId: _gomokuSudMgId,
      ),
      _GameTile(
        title: '象棋',
        note: '攻守推进，一边聊一边下。',
        image: 'assets/prototype/games/chinese-chess.jpg',
        mgId: '',
      ),
      _GameTile(
        title: '国际象棋',
        note: '节奏更锋利的策略局。',
        image: 'assets/prototype/games/chess-ultra.jpg',
        mgId: '',
      ),
    ],
  ),
  _GameGroup(
    id: 'together',
    kicker: 'co-op room',
    title: '双人同行',
    badge: '一起过关',
    metric: '4 个搭档局',
    hero: 'assets/prototype/games/category-coop-hero.jpg',
    accent: Color(0xFFFF7A3D),
    description: '需要一点配合，也允许一点手忙脚乱，笑出来就算赢。',
    games: [
      _GameTile(
        title: '双人厨房',
        note: '分工备餐，别把锅烧糊。',
        image: 'assets/prototype/games/overcooked-2.jpg',
        mgId: '',
      ),
      _GameTile(
        title: '乒乓大战',
        note: '短回合接球，节奏很轻。',
        image: 'assets/prototype/games/eleven-table-tennis.jpg',
        mgId: '',
      ),
      _GameTile(
        title: '经典台球',
        note: '瞄准、撞球、慢慢收杆。',
        image: 'assets/prototype/games/pure-pool.jpg',
        mgId: '',
      ),
      _GameTile(
        title: '异界冒险',
        note: '两个人一起探索下一格。',
        image: 'assets/prototype/games/it-takes-two.jpg',
        mgId: '',
      ),
    ],
  ),
  _GameGroup(
    id: 'versus',
    kicker: 'quick match',
    title: '联机对战',
    badge: '热血一局',
    metric: '5 个竞技场',
    hero: 'assets/prototype/games/category-versus-hero.jpg',
    accent: Color(0xFF7C3CFF),
    description: '想把注意力切走的时候，打一局刚刚好，不把输赢看太重。',
    games: [
      _GameTile(
        title: '怪物消消乐',
        note: '连消攒分，过程数据更适合伴聊。',
        image: 'assets/prototype/games/monster-crush.png',
        mgId: _monsterCrushSudMgId,
      ),
      _GameTile(
        title: '拳皇',
        note: '街机感对战，出招要快。',
        image: 'assets/prototype/games/kof-xv.jpg',
        mgId: '',
      ),
      _GameTile(
        title: '合金弹头',
        note: '横版闯关，火力一起开。',
        image: 'assets/prototype/games/metal-slug-tactics.jpg',
        mgId: '',
      ),
      _GameTile(
        title: '赛车竞速',
        note: '弯道超车，追一点风。',
        image: 'assets/prototype/games/forza-horizon-5.jpg',
        mgId: '',
      ),
      _GameTile(
        title: '球球大作战',
        note: '轻量吞噬，随时开局。',
        image: 'assets/prototype/games/ball-battle.jpg',
        mgId: '',
      ),
    ],
  ),
  _GameGroup(
    id: 'treasure',
    kicker: 'tiny quest',
    title: '宝藏收集',
    badge: '慢慢探索',
    metric: '4 个小世界',
    hero: 'assets/prototype/games/category-treasure-hero.jpg',
    accent: Color(0xFF22C66B),
    description: '捡起一点碎片，收集一点好运，也把今天放松一点。',
    games: [
      _GameTile(
        title: '像素世界',
        note: '小地图里搭一个角落。',
        image: 'assets/prototype/games/terraria.jpg',
        mgId: '',
      ),
      _GameTile(
        title: '冒险王',
        note: '向前一格，就有新发现。',
        image: 'assets/prototype/games/adventurequest-3d.jpg',
        mgId: '',
      ),
      _GameTile(
        title: '解忧时光',
        note: '收集温柔物件，整理心情。',
        image: 'assets/prototype/games/cozy-grove.jpg',
        mgId: '',
      ),
      _GameTile(
        title: '密室寻宝',
        note: '找线索，开最后一扇门。',
        image: 'assets/prototype/games/escape-simulator.jpg',
        mgId: '',
      ),
    ],
  ),
];
