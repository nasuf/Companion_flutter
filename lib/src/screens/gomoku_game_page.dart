part of 'package:companion_flutter/main.dart';

class _NativeGomokuGamePage extends StatefulWidget {
  const _NativeGomokuGamePage({
    required this.api,
    required this.authSession,
    required this.game,
  });

  final CompanionApi api;
  final AuthSession authSession;
  final _GameTile game;

  @override
  State<_NativeGomokuGamePage> createState() => _NativeGomokuGamePageState();
}

class _NativeGomokuGamePageState extends State<_NativeGomokuGamePage> {
  GomokuEngine? _engine;
  GameSession? _session;
  List<GameSession> _rounds = const [];
  final List<_GameTimelineItem> _timeline = [];
  DateTime? _startedAt;
  bool _starting = false;
  bool _aiThinking = false;
  bool _roundsLoading = true;
  bool _recoveringTerminalEvents = true;
  bool _completedLocally = false;
  bool _isFullscreen = false;
  int _eventSequence = 0;
  String? _error;
  String? _syncNotice;
  late final NativeGameEventOutbox _eventOutbox;

  String get _agentName =>
      _session?.aiPlayer.nickName ?? widget.authSession.agentName ?? 'AI';

  @override
  void initState() {
    super.initState();
    _eventOutbox = NativeGameEventOutbox.forApi(
      api: widget.api,
      authSession: widget.authSession,
    );
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await _eventOutbox.replay();
    GomokuEngine? restoredEngine;
    GameSession? resumableSession;
    try {
      final sessions = await widget.api.listNativeGameSessions(
        gameKey: _nativeGomokuGameKey,
      );
      final agentId = widget.authSession.agentId;
      final active = sessions
          .where(
            (candidate) =>
                candidate.status == 'playing' &&
                (agentId == null || candidate.agentId == agentId),
          )
          .firstOrNull;
      resumableSession = active;
      if (active != null) {
        final process = _asNativeGameMap(
          _asNativeGameMap(active.result?['process'])['gomoku'],
        );
        final moves = _asNativeGameMapList(process['moves']);
        restoredEngine = GomokuEngine.restore(moves);
      }
      if (!mounted) return;
      setState(() {
        _rounds = sessions.where(_GameRoundSummary.canShow).toList();
        _roundsLoading = false;
        _recoveringTerminalEvents = false;
        if (active != null && restoredEngine != null) {
          _session = active;
          _engine = restoredEngine;
          _startedAt = DateTime.now();
          _completedLocally = false;
          _isFullscreen = true;
          _timeline
            ..clear()
            ..add(
              _GameTimelineItem.ai(_agentName, '这盘还在，我把棋谱接回来了。轮到谁、走到哪一步都没丢。'),
            );
        }
      });
      if (active != null && restoredEngine != null) {
        await _reportEvent(
          'game_state_snapshot',
          state: 'playing',
          payload: {
            'reason': 'resumed',
            'move_count': restoredEngine.moves.length,
            'analysis': restoredEngine.analyze().toJson(),
          },
          updateUi: false,
        );
      }
      if (restoredEngine?.isFinished == true) {
        unawaited(_finishGame(restoredEngine!.status));
      } else if (restoredEngine?.currentActor == GomokuActor.agent) {
        unawaited(_playAgentTurn());
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _session = resumableSession;
        _completedLocally = false;
        _roundsLoading = false;
        _recoveringTerminalEvents = false;
        _syncNotice = '上一局五子棋无法恢复，可以重新开一局：${_formatError(error)}';
      });
    }
  }

  Future<void> _loadRounds() async {
    try {
      final sessions = await widget.api.listNativeGameSessions(
        gameKey: _nativeGomokuGameKey,
      );
      if (!mounted) return;
      setState(() {
        _rounds = sessions.where(_GameRoundSummary.canShow).toList();
        _roundsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _roundsLoading = false;
        _syncNotice = _formatError(error);
      });
    }
  }

  Future<void> _resumeRound(GameSession candidate) async {
    if (_session?.id == candidate.id && _engine != null) {
      if (mounted) setState(() => _isFullscreen = true);
      return;
    }
    if (_starting || _recoveringTerminalEvents || _aiThinking) {
      if (mounted) {
        setState(() {
          _syncNotice = _aiThinking
              ? '$_agentName 还在走当前这一步，请稍等一下。'
              : '正在恢复棋局，请稍等一下。';
        });
      }
      return;
    }
    setState(() {
      _recoveringTerminalEvents = true;
      _syncNotice = null;
    });
    try {
      final sessions = await widget.api.listNativeGameSessions(
        gameKey: _nativeGomokuGameKey,
      );
      final session = sessions
          .where((item) => item.id == candidate.id)
          .firstOrNull;
      final agentId = widget.authSession.agentId;
      if (session == null ||
          session.status != 'playing' ||
          (agentId != null && session.agentId != agentId)) {
        if (!mounted) return;
        setState(() {
          _rounds = sessions.where(_GameRoundSummary.canShow).toList();
          _syncNotice = '这局的状态已经更新，请重新选择。';
        });
        return;
      }
      final process = _asNativeGameMap(
        _asNativeGameMap(session.result?['process'])[_nativeGomokuGameKey],
      );
      final engine = GomokuEngine.restore(
        _asNativeGameMapList(process['moves']),
      );
      if (!mounted) return;
      setState(() {
        _rounds = sessions.where(_GameRoundSummary.canShow).toList();
        _session = session;
        _engine = engine;
        _startedAt = DateTime.now();
        _completedLocally = false;
        _isFullscreen = true;
        _timeline
          ..clear()
          ..add(
            _GameTimelineItem.ai(_agentName, '这盘还在，我把棋谱接回来了。轮到谁、走到哪一步都没丢。'),
          );
      });
      await _reportEvent(
        'game_state_snapshot',
        state: 'playing',
        payload: {
          'reason': 'resumed_from_history',
          'move_count': engine.moves.length,
          'analysis': engine.analyze().toJson(),
        },
        updateUi: false,
      );
      if (engine.isFinished) {
        unawaited(_finishGame(engine.status));
      } else if (engine.currentActor == GomokuActor.agent) {
        unawaited(_playAgentTurn());
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _syncNotice = '这局五子棋暂时无法恢复：${_formatError(error)}';
        });
      }
    } finally {
      if (mounted) setState(() => _recoveringTerminalEvents = false);
    }
  }

  Future<void> _startGame() async {
    final agentId = widget.authSession.agentId;
    if (_recoveringTerminalEvents) {
      setState(() => _syncNotice = '正在补齐上一局的结算，请稍等一下。');
      return;
    }
    if (agentId == null || agentId.isEmpty || _starting) {
      if (agentId == null || agentId.isEmpty) {
        setState(() => _error = '还没有可用的 AI 伙伴，暂时不能开局。');
      }
      return;
    }
    if (_session != null && !_completedLocally) {
      await _reportAbort('restarted');
    }
    setState(() {
      _starting = true;
      _error = null;
      _syncNotice = null;
      _timeline.clear();
      _engine = null;
      _session = null;
      _completedLocally = false;
      _aiThinking = false;
      _eventSequence = 0;
    });
    try {
      final session = await widget.api.createNativeGameSession(
        agentId: agentId,
        workspaceId: widget.authSession.workspaceId,
        conversationId: widget.authSession.conversationId,
        gameKey: _nativeGomokuGameKey,
      );
      if (!mounted) return;
      setState(() {
        _session = session;
        _engine = GomokuEngine();
        _isFullscreen = true;
        _startedAt = DateTime.now();
        final intro = session.companionReply;
        if (intro != null && intro.isNotEmpty) {
          _timeline.add(_GameTimelineItem.ai(_agentName, intro));
        }
      });
      await _reportEvent(
        'game_started',
        state: 'playing',
        payload: {
          'board_size': GomokuEngine.boardSize,
          'play_style': 'natural_companion',
          'first_actor': 'user',
        },
      );
    } catch (error) {
      if (mounted) setState(() => _error = _formatError(error));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _handleBoardTap(GomokuPoint point) async {
    final engine = _engine;
    if (engine == null || engine.isFinished || _aiThinking || _starting) return;
    try {
      final result = engine.place(point, GomokuActor.user);
      unawaited(HapticFeedback.selectionClick());
      if (mounted) setState(() {});
      await _reportMove(result.move);
      if (result.status != GomokuGameStatus.playing) {
        await _finishGame(result.status);
        return;
      }
      await _playAgentTurn();
    } on StateError catch (error) {
      final code = error.message.toString();
      if (code == 'occupied_position') {
        if (mounted) setState(() => _syncNotice = '这里已经有棋子了，换一个交叉点。');
        unawaited(
          _reportEvent(
            'invalid_move',
            payload: {'reason': code, 'row': point.row, 'col': point.col},
          ),
        );
      }
    }
  }

  Future<void> _playAgentTurn() async {
    final engine = _engine;
    if (engine == null || engine.isFinished) return;
    setState(() => _aiThinking = true);
    await _reportEvent(
      'ai_thinking_started',
      payload: {
        'move_number': engine.moves.length + 1,
        'play_style': 'natural_companion',
        'analysis': engine.analyze().toJson(),
      },
    );
    await Future<void>.delayed(const Duration(milliseconds: 520));
    if (!mounted || engine.isFinished) return;
    final decision = engine.chooseAiMove();
    await _reportEvent(
      'ai_move_decided',
      payload: {...decision.toJson(), 'play_style': 'natural_companion'},
    );
    final result = engine.place(
      decision.point,
      GomokuActor.agent,
      decision: decision,
    );
    unawaited(HapticFeedback.lightImpact());
    if (mounted) setState(() => _aiThinking = false);
    await _reportMove(result.move);
    if (result.status != GomokuGameStatus.playing) {
      await _finishGame(result.status);
    }
  }

  Future<void> _reportMove(GomokuMove move) async {
    final response = await _reportEvent(
      'move_placed',
      state: 'playing',
      payload: move.toJson(),
    );
    if (move.moment != null) {
      await _reportEvent(
        'threat_detected',
        payload: {
          ...move.moment!,
          'move_number': move.number,
          'actor': move.actor.name,
          'row': move.point.row,
          'col': move.point.col,
          'analysis': move.analysis.toJson(),
        },
      );
    }
    if (response?.companionReply == null) {
      final local = _localCommentFor(move);
      if (local != null && mounted) {
        setState(() {
          _timeline.add(_GameTimelineItem.ai(_agentName, local));
          _trimTimeline();
        });
      }
    }
  }

  Future<void> _finishGame(GomokuGameStatus status) async {
    final engine = _engine;
    if (engine == null || _completedLocally) return;
    _completedLocally = true;
    if (mounted) setState(() => _aiThinking = false);
    final summary = engine.summaryJson();
    await _reportEvent(
      'game_finished',
      state: 'settled',
      payload: {
        ...summary,
        'user_outcome': switch (status) {
          GomokuGameStatus.userWon => 'win',
          GomokuGameStatus.agentWon => 'lose',
          GomokuGameStatus.draw => 'draw',
          GomokuGameStatus.playing => 'draw',
        },
        'duration_seconds': _elapsedSeconds,
        'analysis': engine.analyze().toJson(),
      },
    );
    unawaited(_loadRounds());
  }

  Future<void> _reportAbort(String reason, {bool updateUi = true}) async {
    final engine = _engine;
    final session = _session;
    if (session == null || _completedLocally) return;
    _completedLocally = true;
    await _reportEvent(
      'game_aborted',
      state: 'aborted',
      payload: {
        ...?engine?.summaryJson(),
        'reason': reason,
        'duration_seconds': _elapsedSeconds,
      },
      updateUi: updateUi,
    );
  }

  Future<GameEventResponse?> _reportEvent(
    String eventType, {
    String? state,
    Map<String, dynamic> payload = const {},
    bool updateUi = true,
  }) async {
    final session = _session;
    if (session == null) return null;
    _eventSequence += 1;
    final clientEventId =
        '${session.id}:$eventType:${DateTime.now().microsecondsSinceEpoch}:$_eventSequence';
    final critical = {
      'game_started',
      'move_placed',
      'game_finished',
      'game_aborted',
    }.contains(eventType);
    final eventPayload = {'schema_version': 1, ...payload};
    if (critical) {
      try {
        await _eventOutbox.enqueue(
          sessionId: session.id,
          eventType: eventType,
          state: state,
          payload: eventPayload,
          clientEventId: clientEventId,
        );
      } catch (error) {
        if (mounted && updateUi) {
          setState(() => _syncNotice = '本地过程日志暂时无法写入：${_formatError(error)}');
        }
      }
    }
    final attempts = critical ? 3 : 2;
    Object? lastError;
    for (var attempt = 0; attempt < attempts; attempt += 1) {
      try {
        final response = await widget.api.sendNativeGameEvent(
          sessionId: session.id,
          eventType: eventType,
          state: state,
          payload: eventPayload,
          clientEventId: clientEventId,
        );
        if (critical) await _eventOutbox.remove(clientEventId);
        if (mounted && updateUi) {
          setState(() {
            _session = response.session;
            _syncNotice = null;
            final reply = response.companionReply;
            if (reply != null && reply.isNotEmpty) {
              _timeline.add(_GameTimelineItem.ai(_agentName, reply));
              _trimTimeline();
            }
          });
        }
        return response;
      } catch (error) {
        lastError = error;
        if (attempt + 1 < attempts) {
          await Future<void>.delayed(
            Duration(milliseconds: 280 * (attempt + 1)),
          );
        }
      }
    }
    if (mounted && updateUi) {
      setState(
        () => _syncNotice = critical
            ? '这一步已保存在手机里，联网后会按顺序自动同步。'
            : '对局仍可继续，结算时会补齐棋谱：${_formatError(lastError!)}',
      );
    }
    return null;
  }

  int get _elapsedSeconds {
    final startedAt = _startedAt;
    if (startedAt == null) return 0;
    return math.max(0, DateTime.now().difference(startedAt).inSeconds);
  }

  void _trimTimeline() {
    if (_timeline.length > 6) {
      _timeline.removeRange(0, _timeline.length - 6);
    }
  }

  String? _localCommentFor(GomokuMove move) {
    if (move.actor == GomokuActor.user && move.number == 1) {
      return '从 ${move.point.coordinate} 开始啊。好，我跟着你的方向看。';
    }
    if (move.actor == GomokuActor.agent && move.number == 6) {
      return '棋盘开始热起来了。你不用急着追我，先把自己的线铺舒服。';
    }
    if (move.actor == GomokuActor.user && move.analysis.userLongestChain >= 3) {
      return '我看到你在连这边了。再不管你，我可能真要吃亏。';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final engine = _engine;
    if (_isFullscreen && engine != null) {
      return _NativeFullscreenGameSurface(
        title: '五子棋',
        subtitle: _statusText(engine),
        onExit: () => setState(() => _isFullscreen = false),
        onRestart: _startGame,
        restartLabel: engine.isFinished ? '再来一盘' : '重新开一盘',
        restartDisabled: _starting || _aiThinking,
        restartLoading: _starting,
        child: _activeGameContents(engine),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.page,
      body: Stack(
        children: [
          const _GameBackground(progress: 0.5),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header(context)),
              SliverToBoxAdapter(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 380),
                  reverseDuration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.985, end: 1).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(engine == null ? 'cover' : 'board'),
                    child: engine == null ? _gameCover() : _activeGame(engine),
                  ),
                ),
              ),
              if (_timeline.isNotEmpty)
                SliverToBoxAdapter(child: _companionPanel()),
              SliverToBoxAdapter(child: _roundHistory()),
              const SliverToBoxAdapter(child: SizedBox(height: 42)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        MediaQuery.paddingOf(context).top + 12,
        18,
        14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(38, 38),
            onPressed: () => Navigator.maybePop(context),
            child: _GlassButton(
              size: 38,
              child: const Icon(CupertinoIcons.chevron_left, size: 17),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '五子棋',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 36,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _session == null ? '和 $_agentName 安静下一盘' : _statusText(_engine),
            style: TextStyle(
              color: AppColors.text.withValues(alpha: 0.55),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _gameCover() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: _GlassPanel(
        radius: 24,
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _GamePlaceholderStage(game: widget.game),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              _GomokuNotice(text: _error!, isError: true),
            ],
            const SizedBox(height: 12),
            _PrimaryGameButton(
              label: '开始游戏',
              loading: _starting || _recoveringTerminalEvents,
              disabled: _starting || _recoveringTerminalEvents,
              onPressed: _startGame,
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeGame(GomokuEngine engine) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: _GlassPanel(
        radius: 24,
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: _NativeFullscreenToggleButton(
                expanded: false,
                onPressed: () => setState(() => _isFullscreen = true),
              ),
            ),
            const SizedBox(height: 6),
            _activeGameContents(engine),
            const SizedBox(height: 12),
            if (engine.isFinished)
              _PrimaryGameButton(
                label: '再来一盘',
                loading: _starting,
                disabled: _starting,
                onPressed: _startGame,
              )
            else
              _GomokuRestartButton(
                loading: _starting,
                disabled: _starting || _aiThinking,
                onPressed: _startGame,
              ),
          ],
        ),
      ),
    );
  }

  Widget _activeGameContents(GomokuEngine engine) => Column(
    children: [
      _GomokuPlayersBar(
        agentName: _agentName,
        agentAvatarUrl: widget.authSession.agentAvatarUrl,
        userAvatarUrl: widget.authSession.userAvatarUrl,
        status: engine.status,
        aiThinking: _aiThinking,
        moveCount: engine.moves.length,
      ),
      const SizedBox(height: 14),
      _GomokuBoardFrame(
        child: _GomokuBoard(
          engine: engine,
          enabled: !_aiThinking && !engine.isFinished,
          aiThinking: _aiThinking,
          onPointTap: _handleBoardTap,
        ),
      ),
      const SizedBox(height: 11),
      _GomokuAnalysisStrip(analysis: engine.analyze(), agentName: _agentName),
      if (_syncNotice != null) ...[
        const SizedBox(height: 10),
        _GomokuNotice(text: _syncNotice!, isError: false),
      ],
    ],
  );

  Widget _companionPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: _GlassPanel(
        radius: 22,
        padding: const EdgeInsets.fromLTRB(15, 14, 15, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF20AA72),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$_agentName 在棋盘边',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final item in _timeline.reversed.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TimelineRow(item: item),
              ),
          ],
        ),
      ),
    );
  }

  Widget _roundHistory() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '游戏回忆',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              if (_rounds.isNotEmpty)
                _SoftCountPill(text: '${_rounds.length} 局'),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '完整棋谱、关键手和当时的局面都会留在这里。',
            style: TextStyle(
              color: AppColors.text.withValues(alpha: 0.46),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 11),
          if (_roundsLoading)
            const Center(child: CupertinoActivityIndicator())
          else if (_rounds.isEmpty)
            const _GameRoundEmptyState(
              icon: CupertinoIcons.square_grid_3x2,
              title: '第一盘还在等你',
              subtitle: '下完以后，这里会出现你们共同的一局棋。',
            )
          else
            for (final round in _rounds.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _GameRoundCard(
                  summary: _GameRoundSummary.fromSession(round),
                  onTap: () {
                    if (round.status == 'playing') {
                      unawaited(_resumeRound(round));
                      return;
                    }
                    _showRound(round);
                  },
                ),
              ),
        ],
      ),
    );
  }

  void _showRound(GameSession session) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      builder: (_) => _GameRoundDetailSheet(
        summary: _GameRoundSummary.fromSession(session),
      ),
    );
  }

  String _statusText(GomokuEngine? engine) {
    if (engine == null) return '准备中';
    if (_aiThinking) return '$_agentName 正在想';
    return switch (engine.status) {
      GomokuGameStatus.playing => '轮到你落子',
      GomokuGameStatus.userWon => '你赢了',
      GomokuGameStatus.agentWon => '$_agentName 赢了',
      GomokuGameStatus.draw => '平局',
    };
  }

  String _formatError(Object error) {
    if (error is ApiException) return error.message;
    return error.toString();
  }
}

class _GomokuPlayersBar extends StatelessWidget {
  const _GomokuPlayersBar({
    required this.agentName,
    required this.agentAvatarUrl,
    required this.userAvatarUrl,
    required this.status,
    required this.aiThinking,
    required this.moveCount,
  });

  final String agentName;
  final String? agentAvatarUrl;
  final String? userAvatarUrl;
  final GomokuGameStatus status;
  final bool aiThinking;
  final int moveCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 310;
        return Row(
          children: [
            _GomokuPlayerToken(
              name: '你',
              imageUrl: userAvatarUrl,
              isBlack: true,
              isActive: status == GomokuGameStatus.playing && !aiThinking,
              compact: compact,
            ),
            Expanded(
              child: _GomokuTurnIndicator(
                agentName: agentName,
                status: status,
                aiThinking: aiThinking,
                moveCount: moveCount,
                compact: compact,
              ),
            ),
            _GomokuPlayerToken(
              name: agentName,
              imageUrl: agentAvatarUrl,
              isBlack: false,
              isActive: status == GomokuGameStatus.playing && aiThinking,
              compact: compact,
              alignEnd: true,
            ),
          ],
        );
      },
    );
  }
}

class _GomokuPlayerToken extends StatelessWidget {
  const _GomokuPlayerToken({
    required this.name,
    required this.imageUrl,
    required this.isBlack,
    required this.isActive,
    required this.compact,
    this.alignEnd = false,
  });

  final String name;
  final String? imageUrl;
  final bool isBlack;
  final bool isActive;
  final bool compact;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final avatar = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive
              ? AppColors.accent.withValues(alpha: 0.78)
              : Colors.transparent,
          width: 2,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.18),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : const [],
      ),
      child: _Avatar(
        size: compact ? 28 : 34,
        label: isBlack
            ? '你'
            : name.trim().isEmpty
            ? '伴'
            : name.trim().characters.first,
        imageUrl: imageUrl,
        gradient: isBlack
            ? const [Color(0xFFE8F3FF), Color(0xFFD7E9FF)]
            : const [Color(0xFFE2F6EC), Color(0xFFD4EDE5)],
      ),
    );
    final label = Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: compact ? 46 : 62),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.text,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isBlack
                    ? const Color(0xFF111923)
                    : const Color(0xFFF6F1E6),
                border: Border.all(
                  color: isBlack
                      ? Colors.white.withValues(alpha: 0.24)
                      : const Color(0xFFC7BFAF),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              isBlack ? '黑子' : '白子',
              style: TextStyle(
                color: AppColors.text.withValues(alpha: 0.44),
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: alignEnd
          ? [label, SizedBox(width: compact ? 5 : 7), avatar]
          : [avatar, SizedBox(width: compact ? 5 : 7), label],
    );
  }
}

class _GomokuTurnIndicator extends StatefulWidget {
  const _GomokuTurnIndicator({
    required this.agentName,
    required this.status,
    required this.aiThinking,
    required this.moveCount,
    required this.compact,
  });

  final String agentName;
  final GomokuGameStatus status;
  final bool aiThinking;
  final int moveCount;
  final bool compact;

  @override
  State<_GomokuTurnIndicator> createState() => _GomokuTurnIndicatorState();
}

class _GomokuTurnIndicatorState extends State<_GomokuTurnIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 920),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _GomokuTurnIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.aiThinking) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.status == GomokuGameStatus.playing
        ? widget.aiThinking
              ? '${widget.agentName} 在想'
              : '轮到你'
        : '本局结束';
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final pulse = Curves.easeInOut.transform(_pulse.value);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: BoxConstraints(minWidth: widget.compact ? 58 : 74),
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 7 : 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(
                  alpha: widget.status == GomokuGameStatus.playing
                      ? 0.08 + pulse * 0.05
                      : 0.05,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.accent.withValues(
                    alpha: 0.14 + pulse * 0.14,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.aiThinking) ...[
                    _ThinkingDots(progress: _pulse.value),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: widget.compact ? 9.5 : 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.moveCount} 手',
              style: TextStyle(
                color: AppColors.text.withValues(alpha: 0.38),
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ThinkingDots extends StatelessWidget {
  const _ThinkingDots({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final phase = (progress + index * 0.23) % 1;
        final scale = 0.64 + math.sin(phase * math.pi) * 0.36;
        return Padding(
          padding: EdgeInsets.only(right: index == 2 ? 0 : 2.5),
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 3.5,
              height: 3.5,
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _GomokuBoardFrame extends StatelessWidget {
  const _GomokuBoardFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark(context);
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF243B3B), Color(0xFF101A22)]
              : const [Color(0xFF264F4B), Color(0xFF163330)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF173E3A).withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: dark ? 0.03 : 0.42),
            blurRadius: 1,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(18), child: child),
    );
  }
}

class _GomokuBoard extends StatefulWidget {
  const _GomokuBoard({
    required this.engine,
    required this.enabled,
    required this.aiThinking,
    required this.onPointTap,
  });

  final GomokuEngine engine;
  final bool enabled;
  final bool aiThinking;
  final ValueChanged<GomokuPoint> onPointTap;

  @override
  State<_GomokuBoard> createState() => _GomokuBoardState();
}

class _GomokuBoardState extends State<_GomokuBoard>
    with TickerProviderStateMixin {
  late final AnimationController _placement;
  late final AnimationController _thinking;
  late final Listenable _boardAnimation;
  late int _lastMoveCount;
  GomokuPoint? _previewPoint;

  @override
  void initState() {
    super.initState();
    _placement = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: 1,
    );
    _thinking = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _boardAnimation = Listenable.merge([_placement, _thinking]);
    _lastMoveCount = widget.engine.moves.length;
    _syncThinking();
  }

  @override
  void didUpdateWidget(covariant _GomokuBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_lastMoveCount != widget.engine.moves.length) {
      _lastMoveCount = widget.engine.moves.length;
      _placement.forward(from: 0);
    }
    if (oldWidget.aiThinking != widget.aiThinking) _syncThinking();
  }

  void _syncThinking() {
    if (widget.aiThinking) {
      if (!_thinking.isAnimating) _thinking.repeat();
    } else {
      _thinking.stop();
      _thinking.value = 0;
    }
  }

  @override
  void dispose() {
    _placement.dispose();
    _thinking.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedBuilder(
            animation: _boardAnimation,
            builder: (context, _) => Semantics(
              label: '十五乘十五五子棋棋盘',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: widget.enabled
                    ? (details) => setState(() {
                        _previewPoint = _pointForOffset(
                          details.localPosition,
                          constraints.biggest,
                        );
                      })
                    : null,
                onTapCancel: widget.enabled
                    ? () => setState(() => _previewPoint = null)
                    : null,
                onTapUp: widget.enabled
                    ? (details) {
                        final point = _pointForOffset(
                          details.localPosition,
                          constraints.biggest,
                        );
                        setState(() => _previewPoint = null);
                        if (point != null) widget.onPointTap(point);
                      }
                    : null,
                child: CustomPaint(
                  painter: _GomokuBoardPainter(
                    board: widget.engine.board,
                    lastMove: widget.engine.moves.isEmpty
                        ? null
                        : widget.engine.moves.last.point,
                    previewPoint: _previewPoint,
                    winningLine: widget.engine.winningLine,
                    placementProgress: Curves.easeOutBack.transform(
                      _placement.value,
                    ),
                    thinkingProgress: _thinking.value,
                    aiThinking: widget.aiThinking,
                    darkMode: AppColors.isDark(context),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  GomokuPoint? _pointForOffset(Offset offset, Size size) {
    final padding = size.width * 0.064;
    final cell = (size.width - padding * 2) / (GomokuEngine.boardSize - 1);
    final col = ((offset.dx - padding) / cell).round();
    final row = ((offset.dy - padding) / cell).round();
    if (row < 0 ||
        row >= GomokuEngine.boardSize ||
        col < 0 ||
        col >= GomokuEngine.boardSize) {
      return null;
    }
    final center = Offset(padding + col * cell, padding + row * cell);
    if ((center - offset).distance > cell * 0.56) return null;
    return GomokuPoint(row, col);
  }
}

class _GomokuBoardPainter extends CustomPainter {
  const _GomokuBoardPainter({
    required this.board,
    required this.lastMove,
    required this.previewPoint,
    required this.winningLine,
    required this.placementProgress,
    required this.thinkingProgress,
    required this.aiThinking,
    required this.darkMode,
  });

  final List<List<GomokuStone>> board;
  final GomokuPoint? lastMove;
  final GomokuPoint? previewPoint;
  final List<GomokuPoint> winningLine;
  final double placementProgress;
  final double thinkingProgress;
  final bool aiThinking;
  final bool darkMode;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.width * 0.055);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, radius));
    final background = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: darkMode
            ? const [Color(0xFF9A7247), Color(0xFF6A482F)]
            : const [Color(0xFFD5A566), Color(0xFFA96E42)],
      ).createShader(rect);
    canvas.drawRect(rect, background);

    final grain = Paint()
      ..color = (darkMode ? Colors.black : const Color(0xFF7B412B)).withValues(
        alpha: darkMode ? 0.12 : 0.08,
      )
      ..strokeWidth = math.max(0.5, size.width / 760);
    for (var i = 0; i < 18; i += 1) {
      final y = size.height * (i + 0.6) / 18;
      final bend = math.sin(i * 1.7) * size.width * 0.018;
      final path = Path()
        ..moveTo(-size.width * 0.04, y)
        ..cubicTo(
          size.width * 0.28,
          y + bend,
          size.width * 0.68,
          y - bend,
          size.width * 1.04,
          y + bend * 0.35,
        );
      canvas.drawPath(path, grain);
    }

    final edgeShade = Paint()
      ..shader = RadialGradient(
        radius: 0.82,
        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.16)],
        stops: const [0.62, 1],
      ).createShader(rect);
    canvas.drawRect(rect, edgeShade);

    final padding = size.width * 0.064;
    final cell = (size.width - padding * 2) / (GomokuEngine.boardSize - 1);
    final grid = Paint()
      ..color = (darkMode ? Colors.white : const Color(0xFF34261F)).withValues(
        alpha: darkMode ? 0.38 : 0.58,
      )
      ..strokeWidth = math.max(0.75, size.width / 520);
    for (var i = 0; i < GomokuEngine.boardSize; i += 1) {
      final axis = padding + i * cell;
      canvas.drawLine(
        Offset(padding, axis),
        Offset(size.width - padding, axis),
        grid,
      );
      canvas.drawLine(
        Offset(axis, padding),
        Offset(axis, size.height - padding),
        grid,
      );
    }
    final star = Paint()
      ..color = grid.color.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    for (final point in const [
      GomokuPoint(3, 3),
      GomokuPoint(3, 11),
      GomokuPoint(7, 7),
      GomokuPoint(11, 3),
      GomokuPoint(11, 11),
    ]) {
      canvas.drawCircle(_offset(point, padding, cell), cell * 0.09, star);
    }

    if (aiThinking) {
      final scanX = size.width * (-0.12 + thinkingProgress * 1.24);
      final scanRect = Rect.fromCenter(
        center: Offset(scanX, size.height / 2),
        width: size.width * 0.24,
        height: size.height * 1.4,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              const Color(0xFFB6F4E2).withValues(alpha: 0.055),
              Colors.transparent,
            ],
          ).createShader(scanRect),
      );
    }

    if (previewPoint != null &&
        board[previewPoint!.row][previewPoint!.col] == GomokuStone.empty) {
      final center = _offset(previewPoint!, padding, cell);
      canvas.drawCircle(
        center,
        cell * 0.38,
        Paint()..color = const Color(0xFF111923).withValues(alpha: 0.22),
      );
      canvas.drawCircle(
        center,
        cell * 0.45,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    if (winningLine.length >= 2) {
      final winPaint = Paint()
        ..color = const Color(0xFFFFD56A).withValues(alpha: 0.74)
        ..strokeWidth = cell * 0.28
        ..strokeCap = StrokeCap.round;
      final start = _offset(winningLine.first, padding, cell);
      final end = _offset(winningLine.last, padding, cell);
      canvas.drawLine(
        start,
        Offset.lerp(start, end, placementProgress.clamp(0, 1))!,
        winPaint,
      );
    }

    for (var row = 0; row < GomokuEngine.boardSize; row += 1) {
      for (var col = 0; col < GomokuEngine.boardSize; col += 1) {
        final stone = board[row][col];
        if (stone == GomokuStone.empty) continue;
        final point = GomokuPoint(row, col);
        final center = _offset(point, padding, cell);
        final isLatest = lastMove == point;
        final scale = isLatest ? placementProgress.clamp(0.05, 1.08) : 1.0;
        final shadowProgress = isLatest ? placementProgress.clamp(0, 1) : 1.0;
        final radiusStone = cell * 0.43 * scale;
        canvas.drawCircle(
          center + Offset(0, cell * 0.08),
          radiusStone,
          Paint()
            ..color = Colors.black.withValues(
              alpha: 0.10 + 0.12 * shadowProgress,
            ),
        );
        final stoneRect = Rect.fromCircle(center: center, radius: radiusStone);
        final paint = Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.34, -0.38),
            radius: 0.92,
            colors: stone == GomokuStone.black
                ? const [
                    Color(0xFF596474),
                    Color(0xFF111722),
                    Color(0xFF05070B),
                  ]
                : const [
                    Color(0xFFFFFFFF),
                    Color(0xFFF0E9DA),
                    Color(0xFFC9C0AD),
                  ],
          ).createShader(stoneRect);
        canvas.drawCircle(center, radiusStone, paint);
        if (isLatest) {
          canvas.drawCircle(
            center,
            cell * 0.115 * scale,
            Paint()
              ..color = stone == GomokuStone.black
                  ? const Color(0xFFFFC857)
                  : const Color(0xFF178BFF),
          );
        }
      }
    }
    canvas.restore();
  }

  Offset _offset(GomokuPoint point, double padding, double cell) =>
      Offset(padding + point.col * cell, padding + point.row * cell);

  @override
  bool shouldRepaint(covariant _GomokuBoardPainter oldDelegate) =>
      oldDelegate.lastMove != lastMove ||
      oldDelegate.previewPoint != previewPoint ||
      oldDelegate.winningLine != winningLine ||
      oldDelegate.board != board ||
      oldDelegate.placementProgress != placementProgress ||
      oldDelegate.thinkingProgress != thinkingProgress ||
      oldDelegate.aiThinking != aiThinking ||
      oldDelegate.darkMode != darkMode;
}

class _GomokuRestartButton extends StatelessWidget {
  const _GomokuRestartButton({
    required this.loading,
    required this.disabled,
    required this.onPressed,
  });

  final bool loading;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, 44),
      borderRadius: BorderRadius.circular(15),
      onPressed: disabled || loading ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 44,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.subtleFill(context, light: 0.48),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.glassBorder(context)),
        ),
        child: Center(
          child: loading
              ? const CupertinoActivityIndicator()
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.arrow_counterclockwise,
                      size: 15,
                      color: AppColors.text.withValues(
                        alpha: disabled ? 0.32 : 0.62,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '重新开一局',
                      style: TextStyle(
                        color: AppColors.text.withValues(
                          alpha: disabled ? 0.32 : 0.66,
                        ),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _GomokuAnalysisStrip extends StatelessWidget {
  const _GomokuAnalysisStrip({required this.analysis, required this.agentName});

  final GomokuBoardAnalysis analysis;
  final String agentName;

  @override
  Widget build(BuildContext context) {
    final userThreats = analysis.userWinningMoves.length;
    final agentThreats = analysis.agentWinningMoves.length;
    final text = userThreats > 0
        ? '你有 $userThreats 个直接胜点'
        : agentThreats > 0
        ? '小心，$agentName 有 $agentThreats 个胜点'
        : '你最长 ${analysis.userLongestChain} 连 · $agentName 最长 ${analysis.agentLongestChain} 连';
    return Container(
      width: double.infinity,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.subtleFill(context, light: 0.54),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.glassBorder(context)),
      ),
      child: Row(
        children: [
          Icon(
            userThreats + agentThreats > 0
                ? CupertinoIcons.bolt_fill
                : CupertinoIcons.scope,
            size: 14,
            color: userThreats > 0 ? const Color(0xFF18A66F) : AppColors.accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.text.withValues(alpha: 0.68),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GomokuNotice extends StatelessWidget {
  const _GomokuNotice({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFD84A4A) : const Color(0xFFB8791D);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          height: 1.3,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
