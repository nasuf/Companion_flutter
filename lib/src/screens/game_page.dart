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
  String? _latestStatus;
  GameWallet? _gameWallet;
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
    // Start both requests together so the header cards load concurrently
    // instead of on two sequential round-trips. The latest-session lookup is a
    // lightweight status-only query (no full session payload).
    final latestFuture = widget.api.getLatestNativeGameSession(
      agentId: widget.session.agentId,
    );
    final walletFuture = widget.api.getGameWallet();
    try {
      final status = await latestFuture;
      if (mounted) setState(() => _latestStatus = status);
    } catch (error) {
      if (mounted) setState(() => _error = _formatError(error));
    }
    try {
      final wallet = await walletFuture;
      if (mounted) setState(() => _gameWallet = wallet);
    } catch (_) {
      // Points are non-fatal for the hub.
    }
  }

  Future<void> _openGame(_GameGroup group, _GameTile game) async {
    setState(() {
      _activeGroup = group;
      _activeGame = game;
    });
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
    final status = _latestStatus;
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
            status == null
                ? '不用多说，一起玩一会儿就好'
                : '最近一局 · ${_localizedGameStatus(status)}',
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
                  value: _localizedGameStatus(status),
                  label: '最近一局',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  value: status == null ? '--' : '自然对局',
                  label: '陪玩方式',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  value: _gameWallet == null ? '--' : '${_gameWallet!.balance}',
                  label: '积分',
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

  String _localizedGameStatus(String? status) {
    switch (status) {
      case 'playing':
        return '进行中';
      case 'settled':
        return '已结束';
      case 'aborted':
        return '已退出';
      case 'created':
        return '准备中';
      default:
        return '未开局';
    }
  }

  void _showNoPointsDialog() {
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
              Expanded(child: _breakdown('负场', losses, const Color(0xFFD84A4A))),
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
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: const [
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
