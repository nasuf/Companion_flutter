part of 'package:companion_flutter/main.dart';

class _NativeGameRuntime {
  static const int _roundHistoryLimit = 16;

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
  final DateTime _openedAt = DateTime.now().toUtc();

  GameSession? session;
  List<GameSession> rounds = const [];
  DateTime? startedAt;
  bool starting = false;
  bool aiThinking = false;
  bool roundsLoading = true;
  bool completed = false;
  // Current game-point balance shown at the bottom of every game screen.
  int? gamePoints;
  Map<String, dynamic>? terminalPayload;
  DateTime? terminalPresentedAt;
  bool turnTimeoutVisible = false;
  bool deleting = false;
  String? error;
  String? syncNotice;
  int _eventSequence = 0;
  Timer? _turnTimer;
  String? _turnToken;
  Duration? _turnDuration;
  Future<void> _networkTail = Future<void>.value();
  bool _disposed = false;
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
    // History repair is useful, but it must not keep the local game board
    // behind a network loading state. Start replaying before the history
    // request and keep every later event on the same ordered network tail.
    _queueNetworkTask(_replayPendingEventsAtLaunch);
    _queueNetworkTask(loadGamePoints);
    try {
      final sessions = await api.listNativeGameSessions(
        gameKey: gameKey,
        limit: _roundHistoryLimit,
      );
      rounds = sessions.where(_GameRoundSummary.canShow).toList();
      roundsLoading = false;
      _notify();

      final activeAgentId = authSession.agentId;
      final obsolete = sessions.where(
        (item) =>
            activeAgentId != null &&
            item.agentId == activeAgentId &&
            {'created', 'playing'}.contains(item.status) &&
            (item.createdAt?.toUtc().isBefore(_openedAt) ?? true),
      );
      if (obsolete.isNotEmpty) {
        _queueNetworkTask(() => _terminateLegacySessions(obsolete.toList()));
      }
    } catch (caught) {
      syncNotice = _formatError(caught);
    } finally {
      roundsLoading = false;
      _notify();
    }
  }

  Future<void> _replayPendingEventsAtLaunch() async {
    final pending = await _eventOutbox.read();
    if (pending.isEmpty) return;
    await _eventOutbox.replay();
    await loadRounds();
  }

  /// Load this game's own points for the bottom-of-screen display (the global
  /// total already lives on the game hub). Non-fatal: a failure must not disrupt
  /// gameplay or the round history.
  Future<void> loadGamePoints() async {
    try {
      final wallet = await api.getGameWallet(gameKey: gameKey);
      gamePoints = wallet.gamePointsForGame ?? wallet.balance;
      _notify();
    } catch (_) {
      // Keep whatever value we last had; never block the game screen.
    }
  }

  Future<void> _terminateLegacySessions(List<GameSession> sessions) async {
    var changed = false;
    for (final candidate in sessions) {
      if (candidate.id == session?.id) continue;
      changed = await _terminateLegacySession(candidate) != null || changed;
    }
    if (changed) await loadRounds();
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
      final sessions = await api.listNativeGameSessions(
        gameKey: gameKey,
        limit: _roundHistoryLimit,
      );
      rounds = sessions.where(_GameRoundSummary.canShow).toList();
      roundsLoading = false;
      _notify();
      // A round list reload follows game start / settle, so refresh the
      // points balance too (a finished/aborted game just changed it).
      await loadGamePoints();
    } catch (caught) {
      roundsLoading = false;
      syncNotice = _formatError(caught);
      _notify();
    }
  }

  Future<bool> deleteRound(GameSession candidate) async {
    final isActive = session?.id == candidate.id;
    if (deleting || starting || (isActive && aiThinking)) {
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
        clearTurnTimeout();
        session = null;
        startedAt = null;
        completed = false;
        terminalPayload = null;
        terminalPresentedAt = null;
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

  Future<GameSession?> start(
    Map<String, dynamic> payload, {
    Map<String, dynamic> Function(GameSession session)? payloadBuilder,
  }) async {
    final agentId = authSession.agentId;
    if (agentId == null || agentId.isEmpty || starting) {
      if (agentId == null || agentId.isEmpty) {
        error = '还没有可用的 AI 伙伴，暂时不能开局。';
        _notify();
      }
      return null;
    }
    final previousSession = session;
    final previousStartedAt = startedAt;
    final previousCompleted = completed;
    final previousTerminalPayload = terminalPayload;
    final previousTerminalPresentedAt = terminalPresentedAt;
    final previousEventSequence = _eventSequence;
    starting = true;
    error = null;
    syncNotice = null;
    session = null;
    completed = false;
    terminalPayload = null;
    terminalPresentedAt = null;
    clearTurnTimeout();
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
      final gamePayload = payloadBuilder?.call(session!) ?? payload;
      await reportEvent(
        'game_started',
        state: 'playing',
        payload: {
          'schema_version': 1,
          'play_style': 'natural_companion',
          'config_version': session!.configVersion,
          'effective_strength': session!.effectiveStrength,
          'engine_config': session!.engineConfig,
          ...gamePayload,
        },
      );
      return session;
    } catch (caught) {
      if (previousTerminalPayload != null) {
        session = previousSession;
        startedAt = previousStartedAt;
        completed = previousCompleted;
        terminalPayload = previousTerminalPayload;
        terminalPresentedAt = previousTerminalPresentedAt;
        _eventSequence = previousEventSequence;
      }
      error = _formatError(caught);
      _notify();
      return null;
    } finally {
      starting = false;
      _notify();
    }
  }

  Future<void> finish(Map<String, dynamic> payload) async {
    if (completed || session == null) return;
    completed = true;
    aiThinking = false;
    clearTurnTimeout();
    terminalPayload = Map<String, dynamic>.unmodifiable(payload);
    terminalPresentedAt = DateTime.now();
    _notify();
    _NativeGameHaptics.outcome(payload['user_outcome'] as String?);
    await reportEvent(
      'game_finished',
      state: 'settled',
      payload: {
        'schema_version': 1,
        'duration_seconds': elapsedSeconds,
        ...payload,
      },
    );
  }

  Future<void> abort(
    String reason,
    Map<String, dynamic> payload, {
    bool updateUi = true,
  }) async {
    if (completed || session == null) return;
    completed = true;
    clearTurnTimeout();
    await reportEvent(
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

  Future<void> reportEvent(
    String eventType, {
    String? state,
    Map<String, dynamic> payload = const {},
    bool updateUi = true,
  }) async {
    final active = session;
    if (active == null) return;
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
          'tetromino_locked',
          'garbage_sent',
          'turn_timed_out',
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
        _queueNetworkTask(
          () => _flushEventOutbox(
            sessionId: active.id,
            refreshRounds: terminal,
          ),
        );
        return;
      } catch (caught) {
        if (updateUi) {
          syncNotice = '本地过程日志暂时无法写入：${_formatError(caught)}';
          _notify();
        }
      }
    }

    _queueNetworkTask(
      () => _sendBestEffortEvent(
        sessionId: active.id,
        eventType: eventType,
        state: state,
        payload: eventPayload,
        clientEventId: clientEventId,
        attempts: critical ? 3 : 2,
        critical: critical,
        updateUi: updateUi,
      ),
    );
  }

  Future<void> _flushEventOutbox({
    required String sessionId,
    required bool refreshRounds,
  }) async {
    for (var attempt = 0; attempt < 3; attempt += 1) {
      await _eventOutbox.replay();
      final remaining = await _eventOutbox.read();
      final pending = remaining.any(
        (event) => event['session_id'] == sessionId,
      );
      if (!pending) {
        if (refreshRounds) await loadRounds();
        return;
      }
      if (attempt < 2) {
        await Future<void>.delayed(Duration(milliseconds: 280 * (attempt + 1)));
      }
    }
  }

  Future<void> _sendBestEffortEvent({
    required String sessionId,
    required String eventType,
    required String? state,
    required Map<String, dynamic> payload,
    required String clientEventId,
    required int attempts,
    required bool critical,
    required bool updateUi,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < attempts; attempt += 1) {
      try {
        await api.sendNativeGameEvent(
          sessionId: sessionId,
          eventType: eventType,
          state: state,
          payload: payload,
          clientEventId: clientEventId,
        );
        if (session?.id == sessionId &&
            critical &&
            syncNotice?.startsWith('本地过程日志暂时无法写入') == true) {
          syncNotice = null;
          _notify(updateUi);
        }
        return;
      } catch (caught) {
        lastError = caught;
        if (attempt + 1 < attempts) {
          await Future<void>.delayed(
            Duration(milliseconds: 280 * (attempt + 1)),
          );
        }
      }
    }
    if (updateUi && session?.id == sessionId) {
      syncNotice = critical
          ? '这一步暂时无法写入本地或同步：${_formatError(lastError!)}'
          : '对局仍可继续，结算时会补齐过程：${_formatError(lastError!)}';
      _notify();
    }
  }

  void _queueNetworkTask(Future<void> Function() task) {
    _networkTail = _networkTail
        .catchError((_) {})
        .then((_) => task())
        .catchError((Object caught, StackTrace stackTrace) {
          debugPrint('Native game background sync failed: $caught');
        });
  }

  void showNotice(String message) {
    syncNotice = message;
    _notify();
  }

  void syncUserTurnTimeout({
    required bool active,
    required String token,
    required Duration duration,
  }) {
    if (!active || completed || session == null) {
      clearTurnTimeout();
      return;
    }
    if (_turnToken == token &&
        _turnDuration == duration &&
        (_turnTimer?.isActive == true || turnTimeoutVisible)) {
      return;
    }
    _turnTimer?.cancel();
    _turnToken = token;
    _turnDuration = duration;
    turnTimeoutVisible = false;
    _turnTimer = Timer(duration, () => _handleTurnTimeout(token, duration));
  }

  void continueAfterTurnTimeout() {
    final token = _turnToken;
    final duration = _turnDuration;
    if (token == null || duration == null) return;
    turnTimeoutVisible = false;
    _turnTimer?.cancel();
    _turnTimer = Timer(duration, () => _handleTurnTimeout(token, duration));
    unawaited(
      reportEvent(
        'turn_timeout_continued',
        payload: {
          'actor': 'user',
          'turn_token': token,
          'timeout_seconds': duration.inSeconds,
        },
        updateUi: false,
      ),
    );
    _notify();
  }

  void _handleTurnTimeout(String token, Duration duration) {
    if (completed || session == null || _turnToken != token) return;
    turnTimeoutVisible = true;
    _turnTimer = null;
    _NativeGameHaptics.rejected();
    unawaited(
      reportEvent(
        'turn_timed_out',
        payload: {
          'actor': 'user',
          'turn_token': token,
          'timeout_seconds': duration.inSeconds,
        },
        updateUi: false,
      ),
    );
    _notify();
  }

  void clearTurnTimeout() {
    _turnTimer?.cancel();
    _turnTimer = null;
    _turnToken = null;
    _turnDuration = null;
    turnTimeoutVisible = false;
  }

  void clearPresentation() {
    clearTurnTimeout();
    terminalPayload = null;
    terminalPresentedAt = null;
    _notify();
  }

  void dispose() {
    _disposed = true;
    _turnTimer?.cancel();
    _turnTimer = null;
  }

  String _formatError(Object caught) {
    if (caught is ApiException) return caught.message;
    return caught.toString();
  }

  void _notify([bool enabled = true]) {
    if (enabled && !_disposed) onChanged();
  }
}
