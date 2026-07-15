part of 'package:companion_flutter/main.dart';

class _NativeGameRuntime {
  _NativeGameRuntime({
    required this.api,
    required this.authSession,
    required this.gameKey,
    required this.gameTitle,
    required this.onChanged,
  });

  final CompanionApi api;
  final AuthSession authSession;
  final String gameKey;
  final String gameTitle;
  final VoidCallback onChanged;

  GameSession? session;
  List<GameSession> rounds = const [];
  final List<_GameTimelineItem> timeline = [];
  DateTime? startedAt;
  bool starting = false;
  bool aiThinking = false;
  bool roundsLoading = true;
  bool recovering = true;
  bool completed = false;
  bool resumed = false;
  String? error;
  String? syncNotice;
  int _eventSequence = 0;
  late final NativeGameEventOutbox _eventOutbox = NativeGameEventOutbox.forApi(
    api: api,
    authSession: authSession,
  );

  String get agentName =>
      session?.aiPlayer.nickName ?? authSession.agentName ?? 'AI';

  int get elapsedSeconds {
    final value = startedAt;
    if (value == null) return 0;
    return math.max(0, DateTime.now().difference(value).inSeconds);
  }

  Future<_NativeGameResume?> initialize() async {
    await _eventOutbox.replay();
    try {
      final sessions = await api.listNativeGameSessions(gameKey: gameKey);
      rounds = sessions.where(_GameRoundSummary.canShow).toList();
      final agentId = authSession.agentId;
      final active = sessions.where(
        (candidate) =>
            candidate.status == 'playing' &&
            (agentId == null || candidate.agentId == agentId),
      );
      final candidate = active.firstOrNull;
      if (candidate != null) {
        return _activateResume(candidate);
      }
      return null;
    } catch (caught) {
      syncNotice = _formatError(caught);
      return null;
    } finally {
      recovering = false;
      roundsLoading = false;
      _notify();
    }
  }

  Future<_NativeGameResume?> resumeRound(GameSession candidate) async {
    if (starting || recovering || aiThinking) {
      syncNotice = aiThinking ? '$agentName 还在走当前这一步，请稍等一下。' : '正在恢复棋局，请稍等一下。';
      _notify();
      return null;
    }
    if (!_isResumable(candidate)) {
      syncNotice = '这局已经结束，可以在回忆里查看完整数据。';
      _notify();
      return null;
    }
    recovering = true;
    syncNotice = null;
    _notify();
    try {
      final sessions = await api.listNativeGameSessions(gameKey: gameKey);
      rounds = sessions.where(_GameRoundSummary.canShow).toList();
      final latest = sessions
          .where((item) => item.id == candidate.id)
          .firstOrNull;
      if (latest == null || !_isResumable(latest)) {
        syncNotice = '这局的状态已经更新，请重新选择。';
        return null;
      }
      return await _activateResume(latest);
    } catch (caught) {
      syncNotice = '这局暂时无法恢复：${_formatError(caught)}';
      return null;
    } finally {
      recovering = false;
      roundsLoading = false;
      _notify();
    }
  }

  bool _isResumable(GameSession candidate) {
    final agentId = authSession.agentId;
    return candidate.status == 'playing' &&
        (candidate.gameKey == null || candidate.gameKey == gameKey) &&
        (agentId == null || candidate.agentId == agentId);
  }

  Future<_NativeGameResume> _activateResume(GameSession candidate) async {
    final resume = _NativeGameResume.fromSession(candidate, gameKey);
    if (resume.actionCount > 0 && resume.state.isEmpty) {
      throw const FormatException('saved_game_state_missing');
    }
    session = candidate;
    // A resumed page starts a new active segment. Time spent away from the
    // game must not be reported as play time for this visit.
    startedAt = DateTime.now();
    completed = false;
    resumed = true;
    aiThinking = false;
    timeline
      ..clear()
      ..add(_GameTimelineItem.ai(agentName, '这局还在。棋盘和走过的每一步我都替你留着，我们接着来。'));
    await reportEvent(
      'game_state_snapshot',
      state: 'playing',
      payload: {
        'reason': 'resumed',
        'action_count': resume.actionCount,
        'state_after': resume.state,
      },
      updateUi: false,
    );
    return resume;
  }

  Future<void> loadRounds() async {
    try {
      final sessions = await api.listNativeGameSessions(gameKey: gameKey);
      rounds = sessions.where(_GameRoundSummary.canShow).toList();
      roundsLoading = false;
      _notify();
    } catch (caught) {
      roundsLoading = false;
      syncNotice = _formatError(caught);
      _notify();
    }
  }

  Future<GameSession?> start(Map<String, dynamic> payload) async {
    final agentId = authSession.agentId;
    if (recovering) {
      syncNotice = '正在补齐上一局的结算，请稍等一下。';
      _notify();
      return null;
    }
    if (agentId == null || agentId.isEmpty || starting) {
      if (agentId == null || agentId.isEmpty) {
        error = '还没有可用的 AI 伙伴，暂时不能开局。';
        _notify();
      }
      return null;
    }
    starting = true;
    error = null;
    syncNotice = null;
    session = null;
    timeline.clear();
    completed = false;
    resumed = false;
    aiThinking = false;
    _eventSequence = 0;
    _notify();
    try {
      session = await api.createNativeGameSession(
        agentId: agentId,
        workspaceId: authSession.workspaceId,
        conversationId: authSession.conversationId,
        gameKey: gameKey,
      );
      startedAt = DateTime.now();
      final intro = session?.companionReply;
      if (intro != null && intro.isNotEmpty) {
        timeline.add(_GameTimelineItem.ai(agentName, intro));
      }
      _notify();
      await reportEvent(
        'game_started',
        state: 'playing',
        payload: {
          'schema_version': 1,
          'play_style': 'natural_companion',
          ...payload,
        },
      );
      return session;
    } catch (caught) {
      error = _formatError(caught);
      _notify();
      return null;
    } finally {
      starting = false;
      _notify();
    }
  }

  Future<GameEventResponse?> finish(Map<String, dynamic> payload) async {
    if (completed || session == null) return null;
    completed = true;
    aiThinking = false;
    _notify();
    final terminalPayload = Map<String, dynamic>.from(payload);
    if (resumed) {
      // The server already owns the canonical pre-resume action stream. New
      // actions have also been appended one-by-one, so a partial local history
      // must not replace or fail validation against that stream at settlement.
      terminalPayload.remove('actions');
      terminalPayload.remove('moves');
    }
    final response = await reportEvent(
      'game_finished',
      state: 'settled',
      payload: {
        'schema_version': 1,
        'duration_seconds': elapsedSeconds,
        ...terminalPayload,
      },
    );
    unawaited(loadRounds());
    return response;
  }

  Future<GameEventResponse?> abort(
    String reason,
    Map<String, dynamic> payload, {
    bool updateUi = true,
  }) async {
    if (completed || session == null) return null;
    completed = true;
    return reportEvent(
      'game_aborted',
      state: 'aborted',
      payload: {
        'schema_version': 1,
        'reason': reason,
        'duration_seconds': elapsedSeconds,
        ...payload,
      },
      updateUi: updateUi,
    );
  }

  Future<GameEventResponse?> reportEvent(
    String eventType, {
    String? state,
    Map<String, dynamic> payload = const {},
    bool updateUi = true,
  }) async {
    final active = session;
    if (active == null) return null;
    _eventSequence += 1;
    final clientEventId =
        '${active.id}:$eventType:'
        '${DateTime.now().microsecondsSinceEpoch}:$_eventSequence';
    final terminal = {'game_finished', 'game_aborted'}.contains(eventType);
    final critical =
        terminal ||
        {
          'game_started',
          'move_placed',
          'stone_placed',
          'disc_placed',
          'piece_moved',
          'tiles_swapped',
          'cell_action',
          'board_slid',
        }.contains(eventType);
    final eventPayload = {'schema_version': 1, ...payload};
    if (critical) {
      try {
        await _eventOutbox.enqueue(
          sessionId: active.id,
          eventType: eventType,
          state: state,
          payload: eventPayload,
          clientEventId: clientEventId,
        );
      } catch (caught) {
        if (updateUi) {
          syncNotice = '本地过程日志暂时无法写入：${_formatError(caught)}';
          _notify();
        }
      }
    }
    final attempts = critical ? 3 : 2;
    Object? lastError;
    for (var attempt = 0; attempt < attempts; attempt += 1) {
      try {
        final response = await api.sendNativeGameEvent(
          sessionId: active.id,
          eventType: eventType,
          state: state,
          payload: eventPayload,
          clientEventId: clientEventId,
        );
        if (critical) await _eventOutbox.remove(clientEventId);
        session = response.session;
        syncNotice = null;
        final reply = response.companionReply;
        if (updateUi && reply != null && reply.isNotEmpty) {
          timeline.add(_GameTimelineItem.ai(agentName, reply));
          _trimTimeline();
        }
        _notify(updateUi);
        return response;
      } catch (caught) {
        lastError = caught;
        if (attempt + 1 < attempts) {
          await Future<void>.delayed(
            Duration(milliseconds: 280 * (attempt + 1)),
          );
        }
      }
    }
    if (updateUi) {
      syncNotice = critical
          ? '这一步已保存在手机里，联网后会按顺序自动同步。'
          : '对局仍可继续，结算时会补齐过程：${_formatError(lastError!)}';
      _notify();
    }
    return null;
  }

  void addLocalComment(String message) {
    timeline.add(_GameTimelineItem.ai(agentName, message));
    _trimTimeline();
    _notify();
  }

  void _trimTimeline() {
    if (timeline.length > 6) {
      timeline.removeRange(0, timeline.length - 6);
    }
  }

  String _formatError(Object caught) {
    if (caught is ApiException) return caught.message;
    return caught.toString();
  }

  void _notify([bool enabled = true]) {
    if (enabled) onChanged();
  }
}

class _NativeGameResume {
  const _NativeGameResume({
    required this.session,
    required this.process,
    required this.state,
    required this.actions,
    required this.actionCount,
  });

  final GameSession session;
  final Map<String, dynamic> process;
  final Map<String, dynamic> state;
  final List<Map<String, dynamic>> actions;
  final int actionCount;

  factory _NativeGameResume.fromSession(GameSession session, String gameKey) {
    final result = session.result ?? const <String, dynamic>{};
    final processRoot = _asNativeGameMap(result['process']);
    final process = _asNativeGameMap(processRoot[gameKey]);
    final actions = _asNativeGameMapList(
      process['actions'] ?? process['moves'],
    );
    return _NativeGameResume(
      session: session,
      process: process,
      state: _asNativeGameMap(process['final_state']),
      actions: actions,
      actionCount: _asNativeGameInt(
        process['action_count'] ?? process['move_count'],
        fallback: actions.length,
      ),
    );
  }
}

Map<String, dynamic> _asNativeGameMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _asNativeGameMapList(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false)
    : const <Map<String, dynamic>>[];

int _asNativeGameInt(Object? value, {required int fallback}) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

class _NativeFullscreenGameSurface extends StatefulWidget {
  const _NativeFullscreenGameSurface({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onExit,
    required this.onRestart,
    required this.restartLabel,
    required this.restartDisabled,
    required this.restartLoading,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback onExit;
  final Future<void> Function() onRestart;
  final String restartLabel;
  final bool restartDisabled;
  final bool restartLoading;

  @override
  State<_NativeFullscreenGameSurface> createState() =>
      _NativeFullscreenGameSurfaceState();
}

class _NativeFullscreenGameSurfaceState
    extends State<_NativeFullscreenGameSurface> {
  @override
  void initState() {
    super.initState();
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
  }

  @override
  void dispose() {
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]),
    );
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) widget.onExit();
    },
    child: Scaffold(
      backgroundColor: AppColors.page,
      body: Stack(
        children: [
          const _GameBackground(progress: 0.5),
          SafeArea(
            minimum: const EdgeInsets.all(8),
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  Positioned.fill(
                    child: Center(
                      child: _GlassPanel(
                        radius: 20,
                        padding: const EdgeInsets.all(10),
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(width: 620, child: widget.child),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: IgnorePointer(
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth * .45,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: .9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.text.withValues(alpha: .08),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              widget.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.text.withValues(alpha: .5),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Row(
                      children: [
                        _NativeFullscreenActionButton(
                          tooltip: widget.restartLabel,
                          icon: Icons.refresh_rounded,
                          loading: widget.restartLoading,
                          onPressed: widget.restartDisabled
                              ? null
                              : widget.onRestart,
                        ),
                        const SizedBox(width: 8),
                        _NativeFullscreenToggleButton(
                          expanded: true,
                          onPressed: widget.onExit,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _NativeFullscreenActionButton extends StatelessWidget {
  const _NativeFullscreenActionButton({
    required this.tooltip,
    required this.icon,
    required this.loading,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool loading;
  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(38, 38),
      onPressed: onPressed == null ? null : () => unawaited(onPressed!()),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: .88),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.text.withValues(alpha: .09)),
        ),
        alignment: Alignment.center,
        child: loading
            ? const CupertinoActivityIndicator(radius: 8)
            : Icon(
                icon,
                color: AppColors.text.withValues(alpha: .78),
                size: 21,
              ),
      ),
    ),
  );
}

class _NativeFullscreenToggleButton extends StatelessWidget {
  const _NativeFullscreenToggleButton({
    required this.expanded,
    required this.onPressed,
  });

  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    label: expanded ? '退出全屏' : '进入全屏',
    button: true,
    child: ExcludeSemantics(
      child: Tooltip(
        message: expanded ? '退出全屏' : '全屏',
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(38, 38),
          onPressed: onPressed,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.text.withValues(alpha: 0.09)),
            ),
            alignment: Alignment.center,
            child: Icon(
              expanded
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
              color: AppColors.text.withValues(alpha: 0.78),
              size: 22,
            ),
          ),
        ),
      ),
    ),
  );
}
