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
  GameWallet? _gameWallet;
  // Header counters: total rounds, lifetime play time, and time played today.
  Future<List<GameLevelTier>>? _levelTiers;
  // The history request that feeds the three header counters is still in
  // flight; the pills spin instead of showing a placeholder zero.
  bool _statsLoading = true;
  bool _levelSheetOpen = false;
  int? _totalRounds;
  int _totalSeconds = 0;
  int _todaySeconds = 0;
  // Native game keys an admin has taken offline; hidden from the hub. Empty by
  // default so every game shows until the catalog says otherwise.
  Set<String> _disabledGameKeys = const {};
  late List<_GameGroup> _visibleGroups;
  _GameGroup? _activeGroup;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 18000),
      value: 0.5,
    );
    _applyVisibleGroups();
    _load();
  }

  /// Rebuild the filtered catalog and re-anchor the active group/game to objects
  /// that live inside it (the filtered groups are fresh instances, so identity
  /// comparisons in the cards must use these, not the const catalog).
  void _applyVisibleGroups() {
    _visibleGroups = _computeVisibleGroups(_disabledGameKeys);
    final activeGroupId = _activeGroup?.id;
    _activeGroup = _visibleGroups.isEmpty
        ? null
        : _visibleGroups.firstWhere(
            (group) => group.id == activeGroupId,
            orElse: () => _visibleGroups.first,
          );
  }

  static List<_GameGroup> _computeVisibleGroups(Set<String> disabled) {
    final groups = <_GameGroup>[];
    for (final group in _gameGroupCatalog) {
      // Placeholder tiles (no native key) are "coming soon" art and stay; only
      // real native games can be toggled off by the admin.
      final games = group.games
          .where(
            (game) =>
                game.nativeGameKey.isEmpty ||
                !disabled.contains(game.nativeGameKey),
          )
          .toList();
      if (games.isEmpty) continue;
      groups.add(
        _GameGroup(
          id: group.id,
          kicker: group.kicker,
          title: group.title,
          badge: group.badge,
          metric: group.metric,
          hero: group.hero,
          accent: group.accent,
          description: group.description,
          games: games,
        ),
      );
    }
    return groups;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _error = null;
      _statsLoading = true;
    });
    // Start every request together so the header loads on one round-trip
    // instead of three sequential ones.
    final walletFuture = widget.api.getGameWallet();
    final catalogFuture = widget.api.getNativeGameCatalog();
    final statsFuture = widget.api.getNativePlayStats();
    try {
      final wallet = await walletFuture;
      if (mounted) setState(() => _gameWallet = wallet);
    } catch (error) {
      // The wallet gates whether a game can start at all, so this one is worth
      // surfacing — unlike the catalog and the counters below.
      if (mounted) setState(() => _error = _formatError(error));
    }
    try {
      final catalog = await catalogFuture;
      final disabled = catalog
          .where((entry) => !entry.enabled && entry.gameKey.isNotEmpty)
          .map((entry) => entry.gameKey)
          .toSet();
      if (mounted) {
        setState(() {
          _disabledGameKeys = disabled;
          _applyVisibleGroups();
        });
      }
    } catch (_) {
      // Visibility is non-fatal: on failure keep showing the full catalog.
    }
    try {
      final stats = await statsFuture;
      if (mounted) {
        setState(() {
          _totalRounds = stats.totalRounds;
          _totalSeconds = stats.totalSeconds;
          _todaySeconds = stats.todaySeconds;
        });
      }
    } catch (_) {
      // Counters are decorative, and this endpoint is newer than the rest of
      // the hub — a server that predates it must not turn the whole page into
      // an error. Leave the numbers at zero and carry on.
    } finally {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  /// Fetch the ladder lazily and keep it for the rest of the session — the
  /// sheet is opened repeatedly and the table almost never changes.
  Future<void> _openLevelSheet() async {
    _levelTiers ??= widget.api.listGameLevelTiers();
    setState(() => _levelSheetOpen = true);
    try {
      await showHubLevelSheet(context, tiers: _levelTiers!);
    } finally {
      if (mounted) setState(() => _levelSheetOpen = false);
    }
  }

  void _showPointsInfoDialog() {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('游戏积分'),
        content: const Text('每天会自动赠送一份游戏积分，玩过的对局也会累计成陪玩等级。'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  /// Compact durations for the header pills: `142H` / `35m` / `48s`.
  static String _hubDuration(int seconds) {
    if (seconds >= 3600) return '${seconds ~/ 3600}H';
    if (seconds >= 60) return '${seconds ~/ 60}m';
    return '${seconds}s';
  }

  Future<void> _openGame(_GameGroup group, _GameTile game) async {
    setState(() => _activeGroup = group);
    if (!game.isOnline) return;
    // Play gate: a user with 0 game points cannot start a new game until the
    // next day's grant. The server enforces this too (403), this is the UX hint.
    final wallet = _gameWallet;
    if (wallet != null && !wallet.canPlay) {
      _showNoPointsDialog();
      return;
    }
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
      _nativeTetrisDuelGameKey => _TetrisDuelGamePage(
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
    if (!mounted) return;
    // Refresh immediately, then once more shortly after: a mid-game quit settles
    // the point deduction via an async abort event, which can land a moment after
    // we return, so the second refresh reflects it without a manual reload.
    unawaited(_load());
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) unawaited(_load());
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = Curves.easeInOut.transform(_controller.value);
        return Scaffold(
          backgroundColor: const Color(0xFF9FD0E6),
          // Every card here breathes on a repeating ticker. Behind the level
          // sheet's frosted backdrop that motion is invisible but would force a
          // full-screen blur pass every frame, so the hub holds still instead.
          body: TickerMode(
            enabled: !_levelSheetOpen,
            child: Stack(
              children: [
                _HubBackground(progress: progress),
                LayoutBuilder(
                  builder: (context, constraints) {
                    // The design is a 393pt frame; everything scales from there.
                    final s = constraints.maxWidth / _hubRefWidth;
                    return CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(child: _topBar(context, s)),
                        SliverToBoxAdapter(child: _statsHeader(s)),
                        SliverToBoxAdapter(child: _gameGroupsSection(s)),
                        SliverToBoxAdapter(child: SizedBox(height: 120 * s)),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _topBar(BuildContext context, double s) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16 * s,
        MediaQuery.paddingOf(context).top + 10 * s,
        8 * s,
        0,
      ),
      child: Row(
        children: [
          _HubRoundButton(
            icon: CupertinoIcons.chevron_left,
            onTap: () => Navigator.maybePop(context),
          ),
          const Spacer(),
          _HubCoinBar(
            scale: s,
            balance: _gameWallet?.balance,
            onPlus: _showPointsInfoDialog,
          ),
        ],
      ),
    );
  }

  Widget _statsHeader(double s) {
    final wallet = _gameWallet;
    final level = wallet?.level;
    final next = wallet?.nextTier;
    final earned = wallet?.lifetimeEarned ?? 0;
    final floor = level?.cumulativePoints ?? 0;
    final ceiling = next?.cumulativePoints;
    final span = ceiling == null ? 0 : ceiling - floor;
    final done = (earned - floor).clamp(0, span == 0 ? 1 : span);
    final labels = _hubLevelLabels(level);
    return Padding(
      padding: EdgeInsets.fromLTRB(45 * s, 31 * s, 45 * s, 0),
      child: Column(
        children: [
          SizedBox(
            height: 156 * s,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 2 * s),
                  child: _HubLevelCard(
                    scale: s,
                    tierName: labels.title,
                    stageName: labels.subtitle,
                    glove: hubLevelGlove(level),
                    onTap: () => unawaited(_openLevelSheet()),
                  ),
                ),
                const Spacer(),
                Column(
                  children: [
                    _HubStatPill(
                      scale: s,
                      icon: '$_hubArt/icon_rounds.png',
                      label: '累计相伴',
                      value: '${_totalRounds ?? 0} 局',
                      loading: _statsLoading,
                    ),
                    SizedBox(height: 11 * s),
                    _HubStatPill(
                      scale: s,
                      icon: '$_hubArt/icon_hours.png',
                      label: '游戏时长',
                      value: _hubDuration(_totalSeconds),
                      loading: _statsLoading,
                    ),
                    SizedBox(height: 11 * s),
                    _HubStatPill(
                      scale: s,
                      icon: '$_hubArt/icon_today.png',
                      label: '今日活跃',
                      value: _hubDuration(_todaySeconds),
                      loading: _statsLoading,
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 26 * s),
          _HubProgressBar(
            value: span <= 0 ? 1 : done / span,
            label: ceiling == null ? '$earned' : '$done/$span',
          ),
          if (_error != null) ...[
            SizedBox(height: 10 * s),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFFFD5D5),
                fontSize: 12 * s,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _gameGroupsSection(double s) {
    return Padding(
      padding: EdgeInsets.fromLTRB(21 * s, 31 * s, 21 * s, 0),
      child: Column(
        children: [
          for (final group in _visibleGroups)
            Padding(
              padding: EdgeInsets.only(bottom: 20 * s),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Column(
                  children: [
                    _HubGroupBanner(
                      scale: s,
                      group: group,
                      isOpen: group == _activeGroup,
                      onTap: () => setState(() {
                        _activeGroup = group == _activeGroup ? null : group;
                      }),
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
                      child: group == _activeGroup
                          ? Padding(
                              key: ValueKey(group.id),
                              padding: EdgeInsets.only(top: 4 * s),
                              child: GridView.count(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 2,
                                mainAxisSpacing: 16 * s,
                                crossAxisSpacing: 10 * s,
                                childAspectRatio: 170 / 138,
                                children: [
                                  for (final game in group.games)
                                    _HubGameTile(
                                      scale: s,
                                      game: game,
                                      onTap: () => _openGame(group, game),
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
        ],
      ),
    );
  }

  void _showNoPointsDialog() => _showGameNoPointsDialog(context);

  String _formatError(Object error) {
    if (error is ApiException) return error.message;
    return error.toString();
  }
}

/// Shared "today's game points are used up" dialog — shown both when opening a
/// game from the hub and when starting from inside an individual game.
void _showGameNoPointsDialog(BuildContext context) {
  showCupertinoDialog<void>(
    context: context,
    builder: (context) {
      return CupertinoAlertDialog(
        title: const Text('今日游戏积分已用完'),
        content: const Text('明天会重新赠送游戏积分，到时候再来一起玩吧。'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      );
    },
  );
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
    final score = _asMap(finalPayload['score']);
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
          _intValue(user['score']) ??
          _intValue(gameSummary['user_score']) ??
          _intValue(score['user']),
      aiScore:
          _intValue(ai['score']) ??
          _intValue(gameSummary['agent_score']) ??
          _intValue(score['agent']),
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
  bool get isAborted => outcome == 'aborted' || session.status == 'aborted';
}

bool _isMissingNativeGameSession(ApiException error) =>
    error.statusCode == 404 && error.message.contains('session_not_found');

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
  const _SoftCountPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.accent;
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

/// Aggregate win/loss statistics for a game, replacing the per-round history
/// list. 逃跑局（中途退出）不计入胜率分母：胜率 = 胜 ÷ (总对局 - 逃跑局) × 100%。
class _GameRoundStats extends StatelessWidget {
  const _GameRoundStats({
    required this.rounds,
    required this.roundsLoading,
    this.emptyState,
    this.gamePoints,
  });

  final List<GameSession> rounds;
  final bool roundsLoading;
  final Widget? emptyState;
  final int? gamePoints;

  @override
  Widget build(BuildContext context) {
    final total = rounds.length;
    var wins = 0;
    var losses = 0;
    var draws = 0;
    var escapes = 0;
    for (final round in rounds) {
      final summary = _GameRoundSummary.fromSession(round);
      if (summary.isAborted) {
        escapes += 1;
      } else if (summary.isWin) {
        wins += 1;
      } else if (summary.isLose) {
        losses += 1;
      } else if (summary.outcome == 'draw') {
        draws += 1;
      }
    }
    final decided = total - escapes;
    final winRate = decided > 0 ? wins / decided * 100 : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '游戏统计',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              if (gamePoints != null) ...[
                _SoftCountPill(text: '积分 $gamePoints'),
                const SizedBox(width: 8),
              ],
              if (total > 0) _SoftCountPill(text: '$total 局'),
            ],
          ),
          const SizedBox(height: 11),
          if (roundsLoading)
            const Center(child: CupertinoActivityIndicator())
          else if (total == 0)
            emptyState ??
                const _GameRoundEmptyState(
                  icon: CupertinoIcons.chart_bar_alt_fill,
                  title: '还没有对局记录',
                  subtitle: '玩完一局以后，这里会统计你们的战绩。',
                )
          else
            _GameRoundStatsPanel(
              total: total,
              wins: wins,
              losses: losses,
              draws: draws,
              escapes: escapes,
              winRate: winRate,
            ),
        ],
      ),
    );
  }
}

class _GameRoundStatsPanel extends StatelessWidget {
  const _GameRoundStatsPanel({
    required this.total,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.escapes,
    required this.winRate,
  });

  final int total;
  final int wins;
  final int losses;
  final int draws;
  final int escapes;
  final double winRate;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final rateText = winRate == winRate.roundToDouble()
        ? '${winRate.toInt()}%'
        : '${winRate.toStringAsFixed(1)}%';
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
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _hero('总对局', '$total')),
              Container(
                width: 1,
                height: 34,
                color: AppColors.text.withValues(alpha: 0.08),
              ),
              Expanded(child: _hero('胜率', rateText)),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: _breakdown('胜场', wins, const Color(0xFF18A66F))),
              Expanded(
                child: _breakdown('负场', losses, const Color(0xFFD84A4A)),
              ),
              Expanded(child: _breakdown('平局', draws, AppColors.accent)),
              Expanded(
                child: _breakdown(
                  '逃跑局',
                  escapes,
                  AppColors.text.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hero(String label, String value) => Column(
    children: [
      Text(
        value,
        style: TextStyle(
          color: AppColors.text,
          fontSize: 24,
          height: 1,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        label,
        style: TextStyle(
          color: AppColors.text.withValues(alpha: 0.5),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  Widget _breakdown(String label, int value, Color color) => Column(
    children: [
      Text(
        '$value',
        style: TextStyle(
          color: color,
          fontSize: 18,
          height: 1,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: TextStyle(
          color: AppColors.text.withValues(alpha: 0.5),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
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
const _nativeTetrisDuelGameKey = 'tetris_duel';

/// 合作过关类游戏：胜负看共同目标是否达成，双方分数只是贡献值，
/// 所有面向用户的文案必须用「你们一起」的合作措辞，避免对抗式误读。
const _nativeCooperativeGameKeys = {
  _nativeMatch3GameKey,
  _nativeMinesweeperGameKey,
  _nativeNumberMergeGameKey,
};

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
    metric: '5 个竞技场',
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
        title: '双人方块竞速',
        note: '90 秒同步落块，消行和进攻都算进比分。',
        image: 'assets/prototype/games/tetris-duel.jpg',
        nativeGameKey: _nativeTetrisDuelGameKey,
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
