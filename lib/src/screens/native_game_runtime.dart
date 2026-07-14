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

  Future<void> initialize() async {
    await _eventOutbox.replay();
    recovering = false;
    _notify();
    await loadRounds();
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
    final response = await reportEvent(
      'game_finished',
      state: 'settled',
      payload: {
        'schema_version': 1,
        'duration_seconds': elapsedSeconds,
        ...payload,
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
          'dice_rolled',
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

class _NativeFullscreenGameSurface extends StatelessWidget {
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
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) onExit();
    },
    child: Scaffold(
      backgroundColor: AppColors.page,
      body: Stack(
        children: [
          const _GameBackground(progress: 0.5),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.text,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.text.withValues(alpha: 0.5),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _NativeFullscreenToggleButton(
                        expanded: true,
                        onPressed: onExit,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: math.max(0.0, constraints.maxHeight - 12),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: math.min(700, constraints.maxWidth),
                            ),
                            child: _GlassPanel(
                              radius: 24,
                              padding: const EdgeInsets.all(12),
                              child: child,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: _PrimaryGameButton(
                      label: restartLabel,
                      loading: restartLoading,
                      disabled: restartDisabled,
                      onPressed: onRestart,
                    ),
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
