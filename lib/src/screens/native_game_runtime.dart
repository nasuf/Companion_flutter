part of 'package:companion_flutter/main.dart';

class _NativeGameRuntime {
  _NativeGameRuntime({
    required this.api,
    required this.authSession,
    required this.gameKey,
    required this.onChanged,
  });

  final CompanionApi api;
  final AuthSession authSession;
  final String gameKey;
  final VoidCallback onChanged;

  GameSession? session;
  List<GameSession> rounds = const [];
  DateTime? startedAt;
  bool starting = false;
  bool aiThinking = false;
  bool roundsLoading = true;
  bool initializing = true;
  bool completed = false;
  bool deleting = false;
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
    try {
      final sessions = await api.listNativeGameSessions(gameKey: gameKey);
      final closed = <GameSession>[];
      final activeAgentId = authSession.agentId;
      for (final candidate in sessions.where(
        (item) =>
            activeAgentId != null &&
            item.agentId == activeAgentId &&
            {'created', 'playing'}.contains(item.status),
      )) {
        final terminated = await _terminateLegacySession(candidate);
        if (terminated != null) closed.add(terminated);
      }
      rounds = [
        ...closed,
        ...sessions,
      ].where(_GameRoundSummary.canShow).toList();
    } catch (caught) {
      syncNotice = _formatError(caught);
    } finally {
      initializing = false;
      roundsLoading = false;
      _notify();
    }
  }

  Future<GameSession?> _terminateLegacySession(GameSession candidate) async {
    final clientEventId = '${candidate.id}:game_aborted:resume-disabled';
    const payload = {
      'schema_version': 1,
      'reason': 'progress_resume_disabled',
      'duration_seconds': 0,
    };
    try {
      await _eventOutbox.enqueue(
        sessionId: candidate.id,
        eventType: 'game_aborted',
        state: 'aborted',
        payload: payload,
        clientEventId: clientEventId,
      );
      final response = await api.sendNativeGameEvent(
        sessionId: candidate.id,
        eventType: 'game_aborted',
        state: 'aborted',
        payload: payload,
        clientEventId: clientEventId,
      );
      await _eventOutbox.remove(clientEventId);
      return response.session;
    } catch (caught) {
      debugPrint(
        'Failed to terminate obsolete native game ${candidate.id}: $caught',
      );
      return null;
    }
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

  Future<bool> deleteRound(GameSession candidate) async {
    final isActive = session?.id == candidate.id;
    if (deleting || starting || initializing || (isActive && aiThinking)) {
      showNotice(
        isActive && aiThinking
            ? '$agentName 还在完成当前这一步，请稍等一下。'
            : '正在处理游戏记录，请稍等一下。',
      );
      return false;
    }
    deleting = true;
    syncNotice = null;
    _notify();
    try {
      try {
        await api.deleteNativeGameSession(candidate.id);
      } on ApiException catch (caught) {
        if (!_isMissingNativeGameSession(caught)) rethrow;
      }
      try {
        await _eventOutbox.removeSession(candidate.id);
      } catch (caught) {
        debugPrint(
          'Failed to clear native game outbox for ${candidate.id}: $caught',
        );
      }
      rounds = rounds.where((round) => round.id != candidate.id).toList();
      if (isActive) {
        session = null;
        startedAt = null;
        completed = false;
        aiThinking = false;
      }
      syncNotice = '游戏记录已删除。';
      return true;
    } catch (caught) {
      syncNotice = '暂时无法删除这局：${_formatError(caught)}';
      return false;
    } finally {
      deleting = false;
      _notify();
    }
  }

  Future<GameSession?> start(Map<String, dynamic> payload) async {
    final agentId = authSession.agentId;
    if (initializing) {
      syncNotice = '正在清理上一局，请稍等一下。';
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
    _NativeGameHaptics.outcome(payload['user_outcome'] as String?);
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

  void showNotice(String message) {
    syncNotice = message;
    _notify();
  }

  String _formatError(Object caught) {
    if (caught is ApiException) return caught.message;
    return caught.toString();
  }

  void _notify([bool enabled = true]) {
    if (enabled) onChanged();
  }
}
