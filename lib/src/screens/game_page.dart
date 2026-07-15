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
  GameSession? _activeSession;
  Set<String> _resumableGameKeys = const {};
  _GameGroup? _activeGroup = _gameGroupCatalog.first;
  _GameTile _activeGame = _gameGroupCatalog.first.games[1];
  String? _error;

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
    setState(() => _error = null);
    try {
      final sessions = await widget.api.listNativeGameSessions(limit: 20);
      if (!mounted) return;
      final agentId = widget.session.agentId;
      final relevantSessions = sessions
          .where((session) => agentId == null || session.agentId == agentId)
          .toList(growable: false);
      setState(() {
        _activeSession = relevantSessions
            .where((session) => session.status == 'playing')
            .firstOrNull;
        _activeSession ??= relevantSessions.firstOrNull;
        _resumableGameKeys = relevantSessions
            .where((session) => session.status == 'playing')
            .map((session) => session.gameKey)
            .whereType<String>()
            .toSet();
      });
    } catch (error) {
      if (mounted) setState(() => _error = _formatError(error));
    }
  }

  Future<void> _openGame(_GameGroup group, _GameTile game) async {
    setState(() {
      _activeGroup = group;
      _activeGame = game;
    });
    if (!game.isOnline) return;
    final page = switch (game.nativeGameKey) {
      _nativeReversiGameKey => _ReversiGamePage(
        api: widget.api,
        authSession: widget.session,
        game: game,
      ),
      _nativeGoGameKey => _GoGamePage(
        api: widget.api,
        authSession: widget.session,
        game: game,
      ),
      _nativeGomokuGameKey => _NativeGomokuGamePage(
        api: widget.api,
        authSession: widget.session,
        game: game,
      ),
      _nativeXiangqiGameKey => _ChessFamilyGamePage(
        api: widget.api,
        authSession: widget.session,
        game: game,
        kind: ChessFamilyKind.xiangqi,
      ),
      _nativeChessGameKey => _ChessFamilyGamePage(
        api: widget.api,
        authSession: widget.session,
        game: game,
        kind: ChessFamilyKind.chess,
      ),
      _nativeChineseCheckersGameKey => _ChineseCheckersGamePage(
        api: widget.api,
        authSession: widget.session,
        game: game,
      ),
      _nativeMatch3GameKey => _Match3GamePage(
        api: widget.api,
        authSession: widget.session,
        game: game,
      ),
      _nativeMinesweeperGameKey => _MinesweeperGamePage(
        api: widget.api,
        authSession: widget.session,
        game: game,
      ),
      _nativeNumberMergeGameKey => _NumberMergeGamePage(
        api: widget.api,
        authSession: widget.session,
        game: game,
      ),
      _ => null,
    };
    if (page == null) return;
    await Navigator.of(
      context,
    ).push(CupertinoPageRoute<void>(builder: (_) => page));
    if (mounted) unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = Curves.easeInOut.transform(_controller.value);
        return Scaffold(
          backgroundColor: AppColors.page,
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
              child: Center(
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
          Text(
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
            style: TextStyle(
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
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFCC3D3D),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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
                  value: session == null ? '--' : '自然对局',
                  label: '陪玩方式',
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: _MetricCard(value: '自研', label: '游戏源'),
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
                resumableGameKeys: _resumableGameKeys,
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

  String _formatError(Object error) {
    if (error is ApiException) return error.message;
    return error.toString();
  }
}

class _PrimaryGameButton extends StatelessWidget {
  const _PrimaryGameButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.disabled = false,
  });

  final String label;
  final bool loading;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final active = !disabled && !loading;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(16),
      onPressed: active ? onPressed : null,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent
              : AppColors.accent.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: loading
              ? const CupertinoActivityIndicator(color: Colors.white)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
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
    required this.gomoku,
    required this.gameKey,
    required this.gameData,
    required this.aiName,
    required this.roomId,
  });

  final GameSession session;
  final String outcome;
  final int? userScore;
  final int? aiScore;
  final int? durationSeconds;
  final DateTime? playedAt;
  final Map<String, dynamic> userExtras;
  final Map<String, dynamic> gomoku;
  final String gameKey;
  final Map<String, dynamic> gameData;
  final String aiName;
  final String roomId;

  static bool canShow(GameSession session) {
    if (session.status == 'playing') return true;
    return session.result != null &&
        {'settled', 'aborted'}.contains(session.status);
  }

  factory _GameRoundSummary.fromSession(GameSession session) {
    final result = session.result ?? const <String, dynamic>{};
    final user = _asMap(result['user']);
    final ai = _asMap(result['ai']);
    final process = _asMap(result['process']);
    final gomoku = {..._asMap(process['gomoku']), ..._asMap(result['gomoku'])};
    final gameKey =
        session.gameKey ?? result['game_key']?.toString() ?? 'gomoku';
    final storedGame = _asMap(process[gameKey]);
    final resultGame = _asMap(result[gameKey]);
    final finalPayload = _asMap(result['final_payload']);
    final gameSummary = {
      ...storedGame,
      ...resultGame,
      ..._asMap(storedGame['summary']),
      ..._asMap(resultGame['summary']),
      ...finalPayload,
    };
    final outcome = (result['user_outcome'] ?? session.status).toString();
    return _GameRoundSummary(
      session: session,
      outcome: outcome,
      userScore:
          _intValue(user['score']) ?? _intValue(gameSummary['user_score']),
      aiScore: _intValue(ai['score']) ?? _intValue(gameSummary['agent_score']),
      durationSeconds:
          session.durationSeconds ?? _intValue(result['duration_seconds']),
      playedAt: session.endedAt ?? session.startedAt ?? session.createdAt,
      userExtras: _asMap(result['user_extras']),
      gomoku: gomoku,
      gameKey: gameKey,
      gameData: gameSummary,
      aiName: session.aiPlayer.nickName.isEmpty
          ? 'AI'
          : session.aiPlayer.nickName,
      roomId: session.roomId,
    );
  }

  bool get isWin => outcome == 'win';
  bool get isLose => outcome == 'lose';
  bool get isPlaying => session.status == 'playing';
  bool get isAborted => outcome == 'aborted' || session.status == 'aborted';
  bool get isGomoku => gomoku.isNotEmpty;
  bool get isCooperative => {
    _nativeMatch3GameKey,
    _nativeMinesweeperGameKey,
    _nativeNumberMergeGameKey,
  }.contains(gameKey);

  int? get actionCount =>
      _intValue(gameData['move_count']) ??
      _intValue(gameData['turn_count']) ??
      _intValue(gameData['action_count']);

  String get resultLabel {
    if (isPlaying) return '继续游戏';
    if (isAborted) return '未完成';
    if (isCooperative && isWin) return '共同过关';
    if (isCooperative && isLose) return '这次没过';
    if (isWin) return '你赢了';
    if (isLose) return '$aiName 小赢';
    if (outcome == 'draw') return '平局';
    return '已结束';
  }

  String get title {
    if (isPlaying) return '这局还在进行';
    if (isAborted) return '这局先停在半路';
    if (isCooperative && isWin) return '这一关你们一起拿下了';
    if (isCooperative && isLose) return '差一点就一起解开了';
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
    final gomokuText = gomokuLine;
    if (gomokuText != null) fragments.add(gomokuText);
    final genericText = genericLine;
    if (genericText != null) fragments.add(genericText);
    if (fragments.isEmpty && durationText != null) fragments.add(durationText!);
    if (isPlaying) {
      final progress = fragments.isEmpty ? '进度已经保存' : fragments.join(' · ');
      return '$progress，点开继续。';
    }
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

  String? get gomokuLine {
    final moveCount = _intValue(gomoku['move_count']);
    final direction = _gomokuDirectionLabel(
      gomoku['win_direction']?.toString(),
    );
    final fragments = <String>[];
    if (moveCount != null && moveCount > 0) fragments.add('$moveCount 手');
    if (direction != null) fragments.add(direction);
    return fragments.isEmpty ? null : fragments.join(' · ');
  }

  String? get genericLine {
    if (isGomoku) return null;
    if (gameKey == _nativeGoGameKey) {
      final score = _asMap(gameData['score']);
      final user = score['user_total'];
      final agent = score['agent_total'];
      if (user != null && agent != null) return '数目 $user : $agent';
    }
    if (gameKey == _nativeReversiGameKey) {
      final user = _intValue(gameData['user_count']);
      final agent = _intValue(gameData['agent_count']);
      if (user != null && agent != null) return '棋子 $user : $agent';
    }
    if (gameKey == _nativeMatch3GameKey) {
      final total = _intValue(gameData['total_score']);
      final target = _intValue(gameData['target_score']);
      if (total != null && target != null) return '$total / $target 分';
    }
    if (gameKey == _nativeMinesweeperGameKey) {
      final revealed = _intValue(gameData['revealed_count']);
      final safeCells = _intValue(gameData['safe_cell_count']);
      if (revealed != null && safeCells != null) {
        return '共同清理 $revealed / $safeCells 格';
      }
    }
    if (gameKey == _nativeNumberMergeGameKey) {
      final score = _intValue(gameData['score']);
      final maxTile = _intValue(gameData['max_tile']);
      if (score != null && maxTile != null) return '$score 分 · 最大 $maxTile';
    }
    final count = actionCount;
    if (count == null || count <= 0) return null;
    return '$count 步';
  }

  List<_RoundDetailMetric> get metrics {
    final items = <_RoundDetailMetric>[];
    if (scoreLine != null) {
      items.add(_RoundDetailMetric(isCooperative ? '贡献' : '比分', scoreLine!));
    }
    if (durationText != null) {
      items.add(_RoundDetailMetric('时长', durationText!));
    }
    if (isGomoku) {
      final moveCount = _intValue(gomoku['move_count']);
      final direction = _gomokuDirectionLabel(
        gomoku['win_direction']?.toString(),
      );
      final lastMove = _asMap(gomoku['last_move']);
      if (moveCount != null && moveCount > 0) {
        items.add(_RoundDetailMetric('手数', '$moveCount 手'));
      }
      if (direction != null) {
        items.add(_RoundDetailMetric('收官', direction));
      }
      if (lastMove.isNotEmpty) {
        final x = _intValue(lastMove['x']);
        final y = _intValue(lastMove['y']);
        if (x != null && y != null) {
          items.add(_RoundDetailMetric('最后一手', '(${x + 1}, ${y + 1})'));
        }
      }
      items.add(_RoundDetailMetric('房间', roomId));
      return items;
    }
    _appendNativeGameMetrics(items);
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

  void _appendNativeGameMetrics(List<_RoundDetailMetric> items) {
    final analysis = _asMap(gameData['analysis']);
    switch (gameKey) {
      case _nativeReversiGameKey:
        final count = actionCount;
        if (count != null) items.add(_RoundDetailMetric('手数', '$count 手'));
        final user = _intValue(gameData['user_count']);
        final agent = _intValue(gameData['agent_count']);
        if (user != null && agent != null) {
          items.add(_RoundDetailMetric('最终棋子', '你 $user : $agent $aiName'));
        }
        final userCorners = _intValue(analysis['user_corner_count']);
        final agentCorners = _intValue(analysis['agent_corner_count']);
        if (userCorners != null && agentCorners != null) {
          items.add(
            _RoundDetailMetric('角点', '你 $userCorners : $agentCorners $aiName'),
          );
        }
      case _nativeGoGameKey:
        final count = actionCount;
        if (count != null) items.add(_RoundDetailMetric('手数', '$count 手'));
        final score = _asMap(gameData['score']);
        final user = score['user_total'];
        final agent = score['agent_total'];
        if (user != null && agent != null) {
          items.add(_RoundDetailMetric('最终数目', '你 $user : $agent $aiName'));
        }
        final userCaptures = _intValue(gameData['user_captures']);
        final agentCaptures = _intValue(gameData['agent_captures']);
        if (userCaptures != null && agentCaptures != null) {
          items.add(
            _RoundDetailMetric(
              '提子',
              '你 $userCaptures : $agentCaptures $aiName',
            ),
          );
        }
      case _nativeXiangqiGameKey:
      case _nativeChessGameKey:
        final count = actionCount;
        if (count != null) items.add(_RoundDetailMetric('手数', '$count 手'));
        final result = gameData['result']?.toString();
        if (result != null && result.isNotEmpty) {
          items.add(_RoundDetailMetric('棋局结果', result));
        }
        if (analysis['in_check'] == true) {
          items.add(const _RoundDetailMetric('终局', '将军局面'));
        }
      case _nativeChineseCheckersGameKey:
        final count = actionCount;
        if (count != null) items.add(_RoundDetailMetric('步数', '$count 步'));
        final userTarget = _intValue(analysis['user_target_pieces']);
        final agentTarget = _intValue(analysis['agent_target_pieces']);
        if (userTarget != null && agentTarget != null) {
          items.add(
            _RoundDetailMetric('进营', '你 $userTarget : $agentTarget $aiName'),
          );
        }
      case _nativeMatch3GameKey:
        final total = _intValue(gameData['total_score']);
        final target = _intValue(gameData['target_score']);
        final turns = actionCount;
        if (total != null && target != null) {
          items.add(_RoundDetailMetric('合作进度', '$total / $target'));
        }
        if (turns != null) items.add(_RoundDetailMetric('交换', '$turns 次'));
        final specialCount = _intValue(analysis['special_count']);
        if (specialCount != null) {
          items.add(_RoundDetailMetric('终局特殊块', '$specialCount 个'));
        }
      case _nativeMinesweeperGameKey:
        final actions = actionCount;
        if (actions != null) {
          items.add(_RoundDetailMetric('共同操作', '$actions 步'));
        }
        final revealed = _intValue(gameData['revealed_count']);
        final safeCells = _intValue(gameData['safe_cell_count']);
        if (revealed != null && safeCells != null) {
          items.add(_RoundDetailMetric('清理进度', '$revealed / $safeCells'));
        }
        final deductions = _intValue(gameData['deductions']);
        final guesses = _intValue(gameData['guesses']);
        if (deductions != null || guesses != null) {
          items.add(
            _RoundDetailMetric(
              '推理方式',
              '${deductions ?? 0} 次确定 · ${guesses ?? 0} 次试探',
            ),
          );
        }
        final largestReveal = _intValue(gameData['largest_reveal']);
        if (largestReveal != null && largestReveal > 0) {
          items.add(_RoundDetailMetric('最大连开', '$largestReveal 格'));
        }
      case _nativeNumberMergeGameKey:
        final moves = actionCount;
        if (moves != null) {
          items.add(_RoundDetailMetric('共同滑动', '$moves 次'));
        }
        final score = _intValue(gameData['score']);
        final maxTile = _intValue(gameData['max_tile']);
        if (score != null) items.add(_RoundDetailMetric('共同得分', '$score'));
        if (maxTile != null) items.add(_RoundDetailMetric('最大数字', '$maxTile'));
        final userScore = _intValue(gameData['user_score']);
        final agentScore = _intValue(gameData['agent_score']);
        if (userScore != null && agentScore != null) {
          items.add(
            _RoundDetailMetric('合并贡献', '你 $userScore : $agentScore $aiName'),
          );
        }
        final totalMerges = _intValue(gameData['total_merges']);
        final bestCombo = _intValue(gameData['best_combo']);
        if (totalMerges != null) {
          items.add(
            _RoundDetailMetric(
              '合并表现',
              '$totalMerges 次合并 · 单步最多 ${bestCombo ?? 0} 次',
            ),
          );
        }
    }
    final moments = gameData['key_moments'];
    if (moments is List && moments.isNotEmpty) {
      items.add(_RoundDetailMetric('关键节点', '${moments.length} 个'));
    }
  }

  Color get accent {
    if (isPlaying) return const Color(0xFF16A56F);
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
    final isDark = AppColors.isDark(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(18),
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.subtleFill(context, light: 0.54),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.glassBorder(context)),
          boxShadow: [
            if (isDark)
              BoxShadow(
                color: AppColors.shadow.withValues(alpha: 0.46),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
          ],
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
                summary.isPlaying
                    ? CupertinoIcons.play_fill
                    : summary.isAborted
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
                          style: TextStyle(
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
    final isDark = AppColors.isDark(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.subtleFill(context, light: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder(context)),
        boxShadow: [
          if (isDark)
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.40),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
        ],
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
                  style: TextStyle(
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
  const _SoftCountPill({required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? AppColors.accent;
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
    final isDark = AppColors.isDark(context);
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
                color: AppColors.elevatedSurface(context, light: 0.94),
                border: Border.all(color: AppColors.glassBorder(context)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow.withValues(
                      alpha: isDark ? 0.78 : 0.10,
                    ),
                    blurRadius: 30,
                    offset: const Offset(0, -8),
                  ),
                ],
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
                                style: TextStyle(
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
                    const SizedBox(height: 18),
                    _RoundDebugInfo(summary: summary),
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

class _RoundDebugInfo extends StatelessWidget {
  const _RoundDebugInfo({required this.summary});

  final _GameRoundSummary summary;

  @override
  Widget build(BuildContext context) {
    final debugData = _roundDebugData(summary);
    final isDark = AppColors.isDark(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceMuted.withValues(alpha: 0.62)
            : const Color(0xFF101827).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.data_object_rounded,
                size: 15,
                color: AppColors.text.withValues(alpha: 0.46),
              ),
              const SizedBox(width: 7),
              Text(
                'Debug Info',
                style: TextStyle(
                  color: AppColors.text.withValues(alpha: 0.62),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: SingleChildScrollView(
              child: SelectableText(
                const JsonEncoder.withIndent('  ').convert(debugData),
                style: TextStyle(
                  color: AppColors.text.withValues(alpha: 0.70),
                  fontSize: 10.5,
                  height: 1.35,
                  fontFamily: 'Menlo',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
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
        color: AppColors.subtleFill(context, light: 0.68),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.glassBorder(context)),
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
            style: TextStyle(
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
  if (summary.isGomoku) {
    if (summary.isWin) {
      return '这盘你最后收得很干净，不是突然赢的，是前面几手慢慢铺出来的。';
    }
    return '这盘有几手其实已经卡到关键点了，下次我可以陪你提前一手把那条线堵住。';
  }
  if (summary.isWin) {
    return '这局更像是你把手感慢慢攒起来的一局。不是冷冰冰的胜负，它会留在你们的游戏记忆里。';
  }
  if (summary.isLose) {
    return '这局虽然输了，但里面有几段节奏值得留下。下次再玩，AI 可以接着这个手感陪你调整。';
  }
  return '这局没有明显输赢，倒像是两个人一起试了一次节奏。';
}

Map<String, dynamic> _roundDebugData(_GameRoundSummary summary) {
  final session = summary.session;
  final result = session.result ?? const <String, dynamic>{};
  final process = _asMap(result['process']);
  return {
    'session': {
      'id': session.id,
      'room_id': session.roomId,
      'status': session.status,
      'difficulty': session.difficulty,
      'ai_level': session.aiLevel,
      'duration_seconds': summary.durationSeconds,
      'started_at': session.startedAt?.toIso8601String(),
      'ended_at': session.endedAt?.toIso8601String(),
      'created_at': session.createdAt?.toIso8601String(),
    },
    'players': {
      'user': {
        'uid': session.userPlayer.uid,
        'nick_name': session.userPlayer.nickName,
      },
      'ai': {
        'uid': session.aiPlayer.uid,
        'nick_name': session.aiPlayer.nickName,
        'is_ai': session.aiPlayer.isAi,
      },
    },
    'summary': {
      'outcome': summary.outcome,
      'result_label': summary.resultLabel,
      'user_score': summary.userScore,
      'ai_score': summary.aiScore,
      'score_line': summary.scoreLine,
      'duration_text': summary.durationText,
    },
    'parsed': {
      'user': _asMap(result['user']),
      'ai': _asMap(result['ai']),
      'user_extras': _asMap(result['user_extras']),
      'ai_extras': _asMap(result['ai_extras']),
      'gomoku': summary.gomoku,
      'process': process,
    },
    'raw_result': result,
  };
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

String? _gomokuDirectionLabel(String? direction) {
  switch (direction) {
    case 'horizontal':
      return '横线收官';
    case 'vertical':
      return '竖线收官';
    case 'diagonal':
      return '斜线收官';
    default:
      return null;
  }
}

class _GameBackground extends StatelessWidget {
  const _GameBackground({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.page,
            Color.lerp(colors.page, colors.surfaceMuted, 0.40)!,
            Color.lerp(colors.page, colors.accentSoft, 0.18)!,
          ],
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
            style: TextStyle(
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
    required this.resumableGameKeys,
    required this.onTap,
    required this.onGameSelected,
  });

  final _GameGroup group;
  final bool isOpen;
  final _GameTile activeGame;
  final Set<String> resumableGameKeys;
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
                                resumable: resumableGameKeys.contains(
                                  game.nativeGameKey,
                                ),
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
    required this.resumable,
    required this.onTap,
  });

  final _GameTile game;
  final bool selected;
  final bool resumable;
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
              child: _GameStatusTag(
                isOnline: widget.game.isOnline,
                resumable: widget.resumable,
              ),
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
  const _GameStatusTag({required this.isOnline, required this.resumable});

  final bool isOnline;
  final bool resumable;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isOnline ? null : Colors.white.withValues(alpha: 0.20),
        gradient: isOnline
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: resumable
                    ? const [
                        Color(0xFF74C8FF),
                        Color(0xFF2987F5),
                        Color(0xFF1556C6),
                      ]
                    : const [
                        Color(0xFF64EAA2),
                        Color(0xFF19C778),
                        Color(0xFF078E55),
                      ],
                stops: const [0.0, 0.52, 1.0],
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
                  color:
                      (resumable
                              ? const Color(0xFF287FF0)
                              : const Color(0xFF03A85E))
                          .withValues(alpha: 0.28),
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
                resumable
                    ? '继续上局'
                    : isOnline
                    ? '已上线'
                    : '待上线',
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 5),
            decoration: const BoxDecoration(
              color: Color(0xFF22A06B),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
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
  final colors = AppColors.current;
  final isDark = colors == AppColors.dark;
  return BoxDecoration(
    color: isDark
        ? colors.surfaceMuted.withValues(alpha: 0.74)
        : Colors.white.withValues(alpha: 0.60),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: isDark
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.white.withValues(alpha: 0.72),
    ),
    boxShadow: [
      BoxShadow(
        color: colors.shadow.withValues(alpha: isDark ? 0.70 : 0.10),
        blurRadius: 24,
        offset: const Offset(0, 12),
      ),
    ],
  );
}

class _GameTimelineItem {
  const _GameTimelineItem(this.title, this.detail);

  factory _GameTimelineItem.ai(String title, String detail) =>
      _GameTimelineItem(title, detail);

  final String title;
  final String detail;
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
    this.nativeGameKey = '',
  });

  final String title;
  final String note;
  final String image;
  final String nativeGameKey;

  bool get isOnline => nativeGameKey.isNotEmpty;
}

const _nativeGoGameKey = 'go';
const _nativeReversiGameKey = 'reversi';
const _nativeGomokuGameKey = 'gomoku';
const _nativeXiangqiGameKey = 'xiangqi';
const _nativeChessGameKey = 'chess';
const _nativeChineseCheckersGameKey = 'chinese_checkers';
const _nativeMatch3GameKey = 'match3';
const _nativeMinesweeperGameKey = 'minesweeper';
const _nativeNumberMergeGameKey = 'number_merge';

const _gameGroupCatalog = [
  _GameGroup(
    id: 'board',
    kicker: 'slow strategy',
    title: '棋牌游戏',
    badge: '静心对弈',
    metric: '6 款棋类',
    hero: 'assets/prototype/games/category-board-hero.jpg',
    accent: Color(0xFF1F6FFF),
    description: '从安静落子开始，不急着赢，只把这一局慢慢下完。',
    games: [
      _GameTile(
        title: '黑白棋',
        note: '抢角、迫停，翻一盘短局。',
        image: 'assets/prototype/games/reversi-native.jpg',
        nativeGameKey: _nativeReversiGameKey,
      ),
      _GameTile(
        title: '围棋',
        note: '九路快棋，提子数目都算清。',
        image: 'assets/prototype/games/go-conquest.jpg',
        nativeGameKey: _nativeGoGameKey,
      ),
      _GameTile(
        title: '五子棋',
        note: '五子连线，几分钟开局。',
        image: 'assets/prototype/games/gomoku-lets-go.jpg',
        nativeGameKey: _nativeGomokuGameKey,
      ),
      _GameTile(
        title: '象棋',
        note: '攻守推进，一边聊一边下。',
        image: 'assets/prototype/games/chinese-chess.jpg',
        nativeGameKey: _nativeXiangqiGameKey,
      ),
      _GameTile(
        title: '国际象棋',
        note: '节奏更锋利的策略局。',
        image: 'assets/prototype/games/chess-ultra.jpg',
        nativeGameKey: _nativeChessGameKey,
      ),
      _GameTile(
        title: '跳棋',
        note: '连续跳跃，把棋子送进对面的星角。',
        image: 'assets/prototype/games/chinese-checkers-native.jpg',
        nativeGameKey: _nativeChineseCheckersGameKey,
      ),
    ],
  ),
  _GameGroup(
    id: 'together',
    kicker: 'co-op room',
    title: '双人同行',
    badge: '一起过关',
    metric: '6 个搭档局',
    hero: 'assets/prototype/games/category-coop-hero.jpg',
    accent: Color(0xFFFF7A3D),
    description: '需要一点配合，也允许一点手忙脚乱，笑出来就算赢。',
    games: [
      _GameTile(
        title: '协作扫雷',
        note: '一起推理，别踩到那颗雷。',
        image: 'assets/prototype/games/minesweeper-native.jpg',
        nativeGameKey: _nativeMinesweeperGameKey,
      ),
      _GameTile(
        title: '数字合并',
        note: '轮流滑动，把小数字慢慢养大。',
        image: 'assets/prototype/games/number-merge-native.jpg',
        nativeGameKey: _nativeNumberMergeGameKey,
      ),
      _GameTile(
        title: '双人厨房',
        note: '分工备餐，别把锅烧糊。',
        image: 'assets/prototype/games/overcooked-2.jpg',
      ),
      _GameTile(
        title: '乒乓大战',
        note: '短回合接球，节奏很轻。',
        image: 'assets/prototype/games/eleven-table-tennis.jpg',
      ),
      _GameTile(
        title: '经典台球',
        note: '瞄准、撞球、慢慢收杆。',
        image: 'assets/prototype/games/pure-pool.jpg',
      ),
      _GameTile(
        title: '异界冒险',
        note: '两个人一起探索下一格。',
        image: 'assets/prototype/games/it-takes-two.jpg',
      ),
    ],
  ),
  _GameGroup(
    id: 'versus',
    kicker: 'quick match',
    title: '联机对战',
    badge: '热血一局',
    metric: '4 个竞技场',
    hero: 'assets/prototype/games/category-versus-hero.jpg',
    accent: Color(0xFF7C3CFF),
    description: '想把注意力切走的时候，打一局刚刚好，不把输赢看太重。',
    games: [
      _GameTile(
        title: '怪物消消乐',
        note: '连消攒分，过程数据更适合伴聊。',
        image: 'assets/prototype/games/monster-crush.png',
        nativeGameKey: _nativeMatch3GameKey,
      ),
      _GameTile(
        title: '拳皇',
        note: '街机感对战，出招要快。',
        image: 'assets/prototype/games/kof-xv.jpg',
      ),
      _GameTile(
        title: '合金弹头',
        note: '横版闯关，火力一起开。',
        image: 'assets/prototype/games/metal-slug-tactics.jpg',
      ),
      _GameTile(
        title: '赛车竞速',
        note: '弯道超车，追一点风。',
        image: 'assets/prototype/games/forza-horizon-5.jpg',
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
      ),
      _GameTile(
        title: '冒险王',
        note: '向前一格，就有新发现。',
        image: 'assets/prototype/games/adventurequest-3d.jpg',
      ),
      _GameTile(
        title: '解忧时光',
        note: '收集温柔物件，整理心情。',
        image: 'assets/prototype/games/cozy-grove.jpg',
      ),
      _GameTile(
        title: '密室寻宝',
        note: '找线索，开最后一扇门。',
        image: 'assets/prototype/games/escape-simulator.jpg',
      ),
    ],
  ),
];
