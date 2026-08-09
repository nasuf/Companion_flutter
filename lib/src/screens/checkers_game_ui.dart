part of 'package:companion_flutter/main.dart';

const String _checkersFigmaAsset = 'assets/prototype/games/checkers-figma/';

class _CheckersHome extends StatelessWidget {
  const _CheckersHome({
    required this.rounds,
    required this.starting,
    required this.error,
    required this.onStart,
    required this.onExit,
  });

  final List<GameSession> rounds;
  final bool starting;
  final String? error;
  final Future<void> Function() onStart;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final summaries = rounds.map(_GameRoundSummary.fromSession).toList();
    final total = summaries.length;
    final wins = summaries.where((round) => round.isWin).length;
    final rate = total == 0 ? 0 : (wins / total * 100).round();
    final seconds = summaries.fold<int>(
      0,
      (sum, round) => sum + (round.durationSeconds ?? 0),
    );
    final labels = ['总对局', '胜利局', '胜率', '时长'];
    final values = ['$total', '$wins', '$rate%', _formatDuration(seconds)];
    return Scaffold(
      backgroundColor: const Color(0xFF6D2F20),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          return Stack(
            children: [
              Positioned(
                left: -width * (70 / 393),
                top: -height * (25 / 852),
                width: width * (489 / 393),
                height: height * (877 / 852),
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 11000),
                  scaleAmount: 0.004,
                  child: Image.asset(
                    '${_checkersFigmaAsset}bg.png',
                    fit: BoxFit.fill,
                  ),
                ),
              ),
              Positioned(
                left: width * (50 / 393),
                top: height * (86 / 852),
                width: width * (293 / 393),
                height: height * (139 / 852),
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 5200),
                  scaleAmount: 0.009,
                  translateY: 1.4,
                  child: Image.asset(
                    '${_checkersFigmaAsset}home_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                left: width * (36 / 393),
                top: height * (256 / 852),
                width: width * (323 / 393),
                height: height * (282 / 852),
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 6500),
                  scaleAmount: 0.006,
                  translateY: 1.5,
                  phase: 0.55,
                  child: Image.asset(
                    '${_checkersFigmaAsset}home_board.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              if (error != null)
                Positioned(
                  left: width * 0.08,
                  right: width * 0.08,
                  top: height * 0.64,
                  child: _GomokuNotice(text: error!, isError: true),
                ),
              Positioned(
                left: width * (28 / 393),
                top: height * (597 / 852),
                width: width * (165 / 393),
                height: height * (69 / 852),
                child: _CheckersArtButton(
                  asset: '${_checkersFigmaAsset}home_btn_exit.png',
                  enabled: !starting,
                  onTap: onExit,
                ),
              ),
              Positioned(
                left: width * (200 / 393),
                top: height * (597 / 852),
                width: width * (165 / 393),
                height: height * (69 / 852),
                child: _CheckersArtButton(
                  asset: '${_checkersFigmaAsset}home_btn_start.png',
                  enabled: !starting,
                  loading: starting,
                  onTap: () => unawaited(onStart()),
                ),
              ),
              Positioned(
                left: width * (20 / 393),
                top: height * (703 / 852),
                width: width * (352 / 393),
                height: height * (115 / 852),
                child: _CheckersHomeStats(labels: labels, values: values),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0m';
    if (seconds >= 3600) {
      final hours = seconds / 3600;
      final value = hours == hours.truncateToDouble()
          ? hours.round().toString()
          : hours.toStringAsFixed(1);
      return '${value}H';
    }
    return '${(seconds / 60).ceil()}m';
  }
}

class _CheckersHomeStats extends StatelessWidget {
  const _CheckersHomeStats({required this.labels, required this.values});

  final List<String> labels;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                '${_checkersFigmaAsset}home_stats.png',
                fit: BoxFit.fill,
              ),
            ),
            for (var index = 0; index < 4; index += 1) ...[
              Positioned(
                left:
                    width * (const [0.138, 0.376, 0.621, 0.860][index] - 0.125),
                top: 0,
                width: width * 0.25,
                height: height * (97 / 401),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      labels[index],
                      style: const TextStyle(
                        color: Color(0xFFFFE39B),
                        fontSize: 15,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left:
                    width * (const [0.138, 0.376, 0.621, 0.860][index] - 0.125),
                top: height * (102 / 401),
                width: width * 0.25,
                height: height * (235 / 401),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      values[index],
                      style: const TextStyle(
                        color: Color(0xFFFFF6E2),
                        fontSize: 20,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.none,
                        shadows: [
                          Shadow(
                            color: Color(0x66000000),
                            offset: Offset(0, 3),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _CheckersGameScreen extends StatefulWidget {
  const _CheckersGameScreen({
    required this.engine,
    required this.lastMove,
    required this.selected,
    required this.targets,
    required this.agentName,
    required this.userName,
    required this.agentAvatarUrl,
    required this.userAvatarUrl,
    required this.aiThinking,
    required this.enabled,
    required this.onTap,
    required this.onShowLose,
    required this.bannerInMs,
    required this.bannerHoldMs,
    required this.bannerOutMs,
    required this.gamePoints,
  });

  final ChineseCheckersEngine engine;
  final ChineseCheckersMove? lastMove;
  final int? selected;
  final Map<int, List<int>> targets;
  final String agentName;
  final String userName;
  final String? agentAvatarUrl;
  final String? userAvatarUrl;
  final bool aiThinking;
  final bool enabled;
  final ValueChanged<int> onTap;
  // Quitting or restarting mid-game → 失败 + 扣分.
  final Future<void> Function() onShowLose;
  // "你的回合" banner timing (ms), from the per-game admin config.
  final int bannerInMs;
  final int bannerHoldMs;
  final int bannerOutMs;
  // Current game points, shown in the top-right coin badge.
  final int? gamePoints;

  @override
  State<_CheckersGameScreen> createState() => _CheckersGameScreenState();
}

class _CheckersGameScreenState extends State<_CheckersGameScreen> {
  // Freezes the per-turn dial while a modal (pause / exit) or the rules popup
  // is open — the rules popup pauses the countdown without a pause dialog.
  bool _paused = false;

  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    final userTurn = widget.enabled && !engine.isFinished;
    final agentTurn = !engine.isFinished && widget.aiThinking;
    final token = '${engine.moveCount}:${widget.aiThinking ? 'agent' : 'user'}';
    return Scaffold(
      backgroundColor: const Color(0xFF6F321F),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          return Stack(
            children: [
              Positioned.fill(
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 11000),
                  scaleAmount: 0.004,
                  child: Image.asset(
                    '${_checkersFigmaAsset}game_bg2.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // Two nameplates (design 跳棋-游戏, frame 393x852). The coin avatar
              // carries a per-turn 30s dial (like 五子棋). User top-left, agent
              // top-right.
              // User card: pill dims when it is not the user's turn; the name
              // is centred on the full pill (the coin overlaps its outer edge).
              Positioned(
                left: width * (62 / 393),
                top: height * (134 / 852),
                width: width * (122 / 393),
                height: height * (47 / 852),
                child: _CheckersCard(active: userTurn),
              ),
              Positioned(
                left: width * (95 / 393),
                top: height * (134 / 852),
                width: width * (89 / 393),
                height: height * (47 / 852),
                child: _CheckersName(name: widget.userName, active: userTurn),
              ),
              Positioned(
                left: width * (29 / 393),
                top: height * (125 / 852),
                width: width * (66 / 393),
                height: width * (66 / 393),
                child: _CheckersTurnAvatar(
                  token: token,
                  imageUrl: widget.userAvatarUrl,
                  fallback: widget.userName,
                  active: userTurn,
                  paused: _paused,
                  onTimeout: _handleUserIdleTimeout,
                ),
              ),
              Positioned(
                left: width * (208 / 393),
                top: height * (134 / 852),
                width: width * (122 / 393),
                height: height * (47 / 852),
                child: _CheckersCard(active: agentTurn),
              ),
              Positioned(
                left: width * (208 / 393),
                top: height * (134 / 852),
                width: width * (89 / 393),
                height: height * (47 / 852),
                child: _CheckersName(name: widget.agentName, active: agentTurn),
              ),
              Positioned(
                left: width * (297 / 393),
                top: height * (122 / 852),
                width: width * (66 / 393),
                height: width * (66 / 393),
                child: _CheckersTurnAvatar(
                  token: token,
                  imageUrl: widget.agentAvatarUrl,
                  fallback: widget.agentName,
                  active: agentTurn,
                  paused: _paused || widget.aiThinking,
                ),
              ),
              Positioned(
                left: width * (5 / 393),
                top: height * (265 / 852),
                width: width * (384 / 393),
                height: height * (388 / 852),
                child: IgnorePointer(
                  child: Image.asset(
                    '${_checkersFigmaAsset}game_board_back.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                left: width * (6 / 393),
                top: height * (257 / 852),
                width: width * (380 / 393),
                height: height * (404 / 852),
                child: _ChineseCheckersBoard(
                  engine: engine,
                  lastMove: widget.lastMove,
                  selected: widget.selected,
                  targets: widget.targets,
                  figmaStyle: true,
                  onTap: widget.onTap,
                ),
              ),
              // "你的回合" ribbon at the board's lower-middle, flashing in when
              // the user's turn begins (timing from the per-game admin config).
              Positioned(
                left: 0,
                right: 0,
                top: height * 0.60 - (width * 0.13) / 2,
                height: width * 0.13,
                child: _TurnBanner(
                  userTurn: userTurn,
                  inMs: widget.bannerInMs,
                  holdMs: widget.bannerHoldMs,
                  outMs: widget.bannerOutMs,
                ),
              ),
              Positioned(
                left: width * (12 / 393),
                top: height * (716 / 852),
                width: width * (101 / 393),
                height: height * (50 / 852),
                child: _CheckersArtButton(
                  asset: '${_checkersFigmaAsset}game_btn_exit2.png',
                  onTap: () => unawaited(_confirmExit(context)),
                ),
              ),
              Positioned(
                left: width * (150 / 393),
                top: height * (716 / 852),
                width: width * (101 / 393),
                height: height * (50 / 852),
                child: _CheckersArtButton(
                  asset: '${_checkersFigmaAsset}game_btn_pause2.png',
                  onTap: () => unawaited(_showPause(context)),
                ),
              ),
              // Gear → rules popup (like 黑白棋). Opening it pauses the dial
              // without a pause dialog; closing it resumes.
              Positioned(
                left: width * (333 / 393),
                top: height * (716 / 852),
                width: width * (44 / 393),
                height: width * (44 / 393),
                child: _CheckersArtButton(
                  asset: '${_checkersFigmaAsset}game_gear.png',
                  onTap: () => unawaited(_showRules(context)),
                ),
              ),
              _NativeGamePointsBadge(points: widget.gamePoints),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    setState(() => _paused = true);
    await _showCheckersModal(
      context,
      title: '退出对局',
      message: '当前棋局还没有结束，退出后本局进度会清空。',
      actions: (dialogContext) => [
        _CheckersModalButton(
          label: '继续',
          onTap: () => Navigator.of(dialogContext).pop(),
        ),
        const SizedBox(height: 9),
        _CheckersModalButton(
          label: '退出',
          onTap: () {
            Navigator.of(dialogContext).pop();
            // Quitting mid-game → 失败 + 扣分; the 失败 screen's 退出 then leaves.
            unawaited(widget.onShowLose());
          },
        ),
      ],
    );
    if (mounted) setState(() => _paused = false);
  }

  // The per-turn dial ran out while the user hadn't moved → auto-open the pause
  // menu (tapping 继续 resumes with a fresh dial).
  void _handleUserIdleTimeout() {
    if (!mounted || _paused || widget.engine.isFinished) return;
    unawaited(_showPause(context));
  }

  Future<void> _showPause(BuildContext context) async {
    setState(() => _paused = true);
    await _showCheckersModal(
      context,
      title: '游戏暂停',
      message: '要继续当前棋局，还是重新开一盘？',
      actions: (dialogContext) => [
        _CheckersModalButton(
          label: '继续',
          onTap: () => Navigator.of(dialogContext).pop(),
        ),
        const SizedBox(height: 9),
        _CheckersModalButton(
          label: '重新开局',
          onTap: () {
            Navigator.of(dialogContext).pop();
            // Restarting mid-game → 失败 + 扣分; the 失败 screen's 重来一局 restarts.
            unawaited(widget.onShowLose());
          },
        ),
      ],
    );
    if (mounted) setState(() => _paused = false);
  }

  // Rules popup (shared card, like 黑白棋). The countdown pauses while it is
  // open — but no pause dialog is shown — and resumes when it closes.
  Future<void> _showRules(BuildContext context) async {
    setState(() => _paused = true);
    await _showGameRulesDialog(
      context,
      gameName: '跳棋',
      rules: const [
        '1、可直行移动一格，或隔着一颗棋子跳跃前进',
        '2、率先将全部棋子移入对面大本营获胜',
      ],
    );
    if (mounted) setState(() => _paused = false);
  }
}

/// Pill card art — the orange plate on this player's turn, the brown plate
/// while waiting (separate design assets, not a dimmed copy).
class _CheckersCard extends StatelessWidget {
  const _CheckersCard({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) => Image.asset(
    active
        ? '${_checkersFigmaAsset}game_card.png'
        : '${_checkersFigmaAsset}game_card_inactive.png',
    fit: BoxFit.fill,
  );
}

/// Nameplate text, centred in the pill's exposed area (the part not covered by
/// the avatar coin). Bright gold on the active player's turn; muted brown while
/// waiting.
class _CheckersName extends StatelessWidget {
  const _CheckersName({required this.name, required this.active});

  final String name;
  final bool active;

  @override
  Widget build(BuildContext context) => Center(
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        name,
        style: TextStyle(
          color: active ? const Color(0xFFFEE0B6) : const Color(0xFFC9A876),
          fontSize: 15,
          height: 1,
          fontWeight: FontWeight.w900,
          decoration: TextDecoration.none,
        ),
      ),
    ),
  );
}

/// Coin avatar with a per-turn countdown dial (reuses the 五子棋 painter): a
/// translucent pie mask + sweeping red hand + cyan seconds, shown while it is
/// this player's turn. The peach ring frame overlays the portrait.
class _CheckersTurnAvatar extends StatefulWidget {
  const _CheckersTurnAvatar({
    required this.token,
    required this.imageUrl,
    required this.fallback,
    required this.active,
    required this.paused,
    this.onTimeout,
  });

  final String token;
  final String? imageUrl;
  final String fallback;
  final bool active;
  final bool paused;
  final VoidCallback? onTimeout;

  @override
  State<_CheckersTurnAvatar> createState() => _CheckersTurnAvatarState();
}

class _CheckersTurnAvatarState extends State<_CheckersTurnAvatar>
    with SingleTickerProviderStateMixin {
  static const int _turnSeconds = 30;
  static const Color _cyan = Color(0xFF01FFFF);

  late final AnimationController _countdown;

  @override
  void initState() {
    super.initState();
    _countdown = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _turnSeconds),
    )..addStatusListener(_onCountdownStatus);
    _sync();
  }

  void _onCountdownStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        widget.active &&
        !widget.paused) {
      widget.onTimeout?.call();
    }
  }

  @override
  void didUpdateWidget(covariant _CheckersTurnAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active || widget.token != oldWidget.token) {
      _sync();
    } else if (widget.paused != oldWidget.paused && widget.active) {
      if (widget.paused) {
        _countdown.stop();
      } else if (_countdown.value >= 1.0) {
        _countdown.forward(from: 0);
      } else {
        _countdown.forward();
      }
    }
  }

  void _sync() {
    if (widget.active && !widget.paused) {
      _countdown.forward(from: 0);
    } else if (!widget.active) {
      _countdown.stop();
      _countdown.value = 0;
    }
  }

  @override
  void dispose() {
    _countdown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final d = constraints.maxWidth;
        final inner = d * 0.79;
        return AnimatedBuilder(
          animation: _countdown,
          builder: (context, _) {
            final remainingFraction = (1 - _countdown.value).clamp(0.0, 1.0);
            final remainingSeconds = (remainingFraction * _turnSeconds)
                .ceil()
                .clamp(0, _turnSeconds);
            return SizedBox(
              width: d,
              height: d,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: inner,
                      height: inner,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _Avatar(
                            size: inner,
                            label: widget.fallback.trim().isEmpty
                                ? '伴'
                                : widget.fallback.trim().characters.first,
                            imageUrl: widget.imageUrl,
                            gradient: const [
                              Color(0xFFFFE2B5),
                              Color(0xFFE38B36),
                            ],
                          ),
                          if (widget.active) ...[
                            CustomPaint(
                              painter: _GomokuTurnTimerPainter(
                                remainingFraction: remainingFraction,
                              ),
                            ),
                            Center(
                              child: Text(
                                '$remainingSeconds',
                                style: TextStyle(
                                  color: _cyan,
                                  fontSize: inner * 0.4,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                  decoration: TextDecoration.none,
                                  shadows: const [
                                    Shadow(
                                      color: Color(0x99000000),
                                      offset: Offset(0, 1),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Ring frame on top (transparent centre): peach on this
                  // player's turn, gold while waiting (separate design assets).
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Image.asset(
                        widget.active
                            ? '${_checkersFigmaAsset}game_avatar_ring.png'
                            : '${_checkersFigmaAsset}game_avatar_ring_inactive.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CheckersArtButton extends StatefulWidget {
  const _CheckersArtButton({
    required this.asset,
    required this.onTap,
    this.enabled = true,
    this.loading = false,
  });

  final String asset;
  final VoidCallback onTap;
  final bool enabled;
  final bool loading;

  @override
  State<_CheckersArtButton> createState() => _CheckersArtButtonState();
}

class _CheckersArtButtonState extends State<_CheckersArtButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !widget.loading;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 90),
        child: Opacity(
          opacity: enabled ? 1 : 0.7,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Image.asset(widget.asset, fit: BoxFit.fill),
              ),
              if (widget.loading)
                const CupertinoActivityIndicator(color: Color(0xFFFFE4B5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckersModalButton extends StatelessWidget {
  const _CheckersModalButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: 1,
        child: Container(
          height: 42,
          alignment: const Alignment(0, 0.12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFB65A), Color(0xFFD86625)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF7A321C), width: 2),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFFF0D0),
              fontSize: 16,
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showCheckersModal(
  BuildContext context, {
  required String title,
  required String message,
  required List<Widget> Function(BuildContext dialogContext) actions,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭',
    barrierColor: Colors.black.withValues(alpha: 0.52),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, _, __) => Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 50),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD79A), Color(0xFFE98B3A)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF8B3E20), width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF6C2F1B),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xCC6C2F1B),
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 17),
              ...actions(dialogContext),
            ],
          ),
        ),
      ),
    ),
    transitionBuilder: (_, animation, __, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: child,
      ),
    ),
  );
}

enum _CheckersResultKind { win, lose }

/// Full-screen 跳棋 win / lose result scene, composed from the exported art
/// (glow → sun/medal emblem → banner → title → 积分 → buttons) with a staggered
/// pop-in. Shown at the page level in place of the game so the board / avatars
/// / dial are torn down. Positions letterboxed onto the 393x852 design canvas
/// so overlaps hold on any aspect ratio.
class _CheckersResultScreen extends StatefulWidget {
  const _CheckersResultScreen({
    super.key,
    required this.kind,
    required this.pointsDelta,
    required this.onRestart,
    required this.onExit,
  });

  final _CheckersResultKind kind;

  /// What this round settled for; null while the wallet hasn't loaded, in
  /// which case the number is left off rather than shown wrong.
  final int? pointsDelta;
  final Future<void> Function() onRestart;
  final Future<void> Function() onExit;

  @override
  State<_CheckersResultScreen> createState() => _CheckersResultScreenState();
}

class _CheckersResultScreenState extends State<_CheckersResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  static const double _designW = 393;
  static const double _designH = 852;
  double _canvasW = _designW;
  double _canvasH = _designH;
  double _originX = 0;
  double _originY = 0;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
        _c.value = 1;
      } else {
        _c.forward();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _img(String name) =>
      Image.asset('$_checkersFigmaAsset$name', fit: BoxFit.fill);

  Widget _piece({
    required double cx,
    required double cy,
    required double wFrac,
    required double aspect,
    required double begin,
    required double end,
    bool drop = false,
    required Widget child,
  }) {
    final p = ((_c.value - begin) / (end - begin)).clamp(0.0, 1.0);
    final eased = Curves.easeOutBack.transform(p);
    final opacity = (p * 2.4).clamp(0.0, 1.0);
    final width = _canvasW * wFrac;
    final height = width * aspect;
    final dy = drop
        ? -_canvasH * 0.10 * (1 - Curves.easeOutCubic.transform(p))
        : 0.0;
    final scale = drop ? 1.0 : (0.7 + 0.3 * eased);
    return Positioned(
      left: _originX + _canvasW * cx - width / 2,
      top: _originY + _canvasH * cy - height / 2 + dy,
      width: width,
      height: height,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(scale: scale, child: child),
      ),
    );
  }

  Widget _scoreRow() => Center(
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('${_checkersFigmaAsset}result_score_label.png', height: 30),
          const SizedBox(width: 6),
          if (widget.pointsDelta != null)
            _NativeGameScoreDelta(
              delta: widget.pointsDelta!,
              assetPrefix: _checkersFigmaAsset,
              winValue: 5,
              loseValue: -4,
              fill: const Color(0xFFFDEBC0),
              stroke: const Color(0xFF77240A),
              height: 30,
            ),
        ],
      ),
    ),
  );

  Widget _exitButton() => _CheckersResultButton(
    base: 'result_btn_exit.png',
    text: 'result_txt_exit.png',
    onTap: () => unawaited(widget.onExit()),
  );

  Widget _againButton() => _CheckersResultButton(
    base: 'result_btn_again.png',
    text: 'result_txt_again.png',
    onTap: () => unawaited(widget.onRestart()),
  );

  @override
  Widget build(BuildContext context) {
    final win = widget.kind == _CheckersResultKind.win;
    return Scaffold(
      backgroundColor: const Color(0xFF6F321F),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final s = math.min(w / _designW, h / _designH);
          _canvasW = _designW * s;
          _canvasH = _designH * s;
          _originX = (w - _canvasW) / 2;
          _originY = (h - _canvasH) / 2;
          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      '${_checkersFigmaAsset}game_bg2.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  ...(win ? _winPieces() : _losePieces()),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // 跳棋-胜利 layout (frame 393x852). z-order: emblem glow → sun emblem →
  // banner glow → banner → 胜利 title → 积分 → buttons.
  List<Widget> _winPieces() => [
    _piece(
      cx: 0.5, cy: 0.35, wFrac: 0.63,
      aspect: 1068 / 924, begin: 0.04, end: 0.4,
      child: _img('result_win_emblem_glow.png'),
    ),
    _piece(
      cx: 0.501, cy: 0.350, wFrac: 0.529,
      aspect: 768 / 624, begin: 0.12, end: 0.46, drop: true,
      child: _img('result_win_emblem.png'),
    ),
    _piece(
      cx: 0.5, cy: 0.372, wFrac: 0.96,
      aspect: 666 / 1179, begin: 0.28, end: 0.56,
      child: _img('result_win_banner_glow.png'),
    ),
    _piece(
      cx: 0.5, cy: 0.372, wFrac: 0.878,
      aspect: 366 / 1035, begin: 0.32, end: 0.58,
      child: _img('result_win_banner.png'),
    ),
    _piece(
      cx: 0.5, cy: 0.350, wFrac: 0.26,
      aspect: 234 / 408, begin: 0.44, end: 0.68,
      child: _img('result_win_title.png'),
    ),
    _piece(
      cx: 0.5, cy: 0.634, wFrac: 0.42,
      aspect: 0.14, begin: 0.56, end: 0.76,
      child: _scoreRow(),
    ),
    _piece(
      cx: 0.313, cy: 0.772, wFrac: 0.346,
      aspect: 180 / 408, begin: 0.66, end: 0.88,
      child: _exitButton(),
    ),
    _piece(
      cx: 0.690, cy: 0.772, wFrac: 0.346,
      aspect: 180 / 408, begin: 0.72, end: 0.94,
      child: _againButton(),
    ),
  ];

  // 跳棋-失败 layout.
  List<Widget> _losePieces() => [
    _piece(
      cx: 0.5, cy: 0.355, wFrac: 0.66,
      aspect: 1257 / 1179, begin: 0.04, end: 0.4,
      child: _img('result_lose_emblem_glow.png'),
    ),
    _piece(
      cx: 0.5, cy: 0.359, wFrac: 0.598,
      aspect: 717 / 705, begin: 0.12, end: 0.46, drop: true,
      child: _img('result_lose_emblem.png'),
    ),
    _piece(
      cx: 0.5, cy: 0.383, wFrac: 0.96,
      aspect: 942 / 1179, begin: 0.28, end: 0.56,
      child: _img('result_lose_banner_glow.png'),
    ),
    _piece(
      cx: 0.5, cy: 0.383, wFrac: 0.875,
      aspect: 402 / 1032, begin: 0.32, end: 0.58,
      child: _img('result_lose_banner.png'),
    ),
    _piece(
      cx: 0.5, cy: 0.360, wFrac: 0.26,
      aspect: 233 / 418, begin: 0.44, end: 0.68,
      child: _img('result_lose_title.png'),
    ),
    _piece(
      cx: 0.5, cy: 0.634, wFrac: 0.42,
      aspect: 0.14, begin: 0.56, end: 0.76,
      child: _scoreRow(),
    ),
    _piece(
      cx: 0.313, cy: 0.772, wFrac: 0.346,
      aspect: 180 / 408, begin: 0.66, end: 0.88,
      child: _exitButton(),
    ),
    _piece(
      cx: 0.690, cy: 0.772, wFrac: 0.346,
      aspect: 180 / 408, begin: 0.72, end: 0.94,
      child: _againButton(),
    ),
  ];
}

/// Result-screen button (退出 / 重来一局): textless base art + text overlay,
/// sized by height so both share the same glyph size, with a press-in scale.
class _CheckersResultButton extends StatefulWidget {
  const _CheckersResultButton({
    required this.base,
    required this.text,
    required this.onTap,
  });

  final String base;
  final String text;
  final VoidCallback onTap;

  @override
  State<_CheckersResultButton> createState() => _CheckersResultButtonState();
}

class _CheckersResultButtonState extends State<_CheckersResultButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                '$_checkersFigmaAsset${widget.base}',
                fit: BoxFit.fill,
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment: const Alignment(0, -0.04),
                child: FractionallySizedBox(
                  heightFactor: 0.42,
                  child: Image.asset(
                    '$_checkersFigmaAsset${widget.text}',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
