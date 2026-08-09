part of 'package:companion_flutter/main.dart';

const String _goAsset = 'assets/prototype/games/go/';

class _GoHome extends StatelessWidget {
  const _GoHome({
    super.key,
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
      backgroundColor: const Color(0xFF191717),
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
                  phase: 0.42,
                  child: Image.asset(
                    '${_goAsset}home_bg.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                left: width * (24 / 393),
                top: height * (3 / 852),
                width: width * (344 / 393),
                height: height * (40 / 852),
                child: Image.asset(
                  '${_goAsset}home_logo_rope.png',
                  fit: BoxFit.fill,
                ),
              ),
              Positioned(
                left: width * (24 / 393),
                top: height * (37 / 852),
                width: width * (344 / 393),
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 5600),
                  scaleAmount: 0.007,
                  translateY: 1.4,
                  phase: 0.25,
                  child: Image.asset(
                    '${_goAsset}home_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                left: width * (23 / 393),
                top: height * (221 / 852),
                width: width * (346 / 393),
                height: height * (310 / 852),
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 6800),
                  scaleAmount: 0.005,
                  translateY: 1.6,
                  phase: 0.6,
                  child: Image.asset(
                    '${_goAsset}home_board.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              if (error != null)
                Positioned(
                  left: width * 0.08,
                  right: width * 0.08,
                  top: height * 0.61,
                  child: _GomokuNotice(text: error!, isError: true),
                ),
              Positioned(
                left: width * (12 / 393),
                top: height * (554 / 852),
                width: width * (175 / 393),
                child: _GoArtButton(
                  asset: '${_goAsset}home_btn_exit.png',
                  aspectRatio: 175 / 63,
                  enabled: !starting,
                  onTap: onExit,
                ),
              ),
              Positioned(
                left: width * (206 / 393),
                top: height * (554 / 852),
                width: width * (175 / 393),
                child: _GoArtButton(
                  asset: '${_goAsset}home_btn_start.png',
                  aspectRatio: 175 / 63,
                  loading: starting,
                  enabled: !starting,
                  onTap: () => unawaited(onStart()),
                ),
              ),
              for (var index = 0; index < 4; index += 1)
                Positioned(
                  left: width * ((10 + index * 97) / 393),
                  top: height * (652 / 852),
                  width: width * (87 / 393),
                  child: _GoHomeStatCard(
                    label: labels[index],
                    value: values[index],
                  ),
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

class _GoHomeStatCard extends StatelessWidget {
  const _GoHomeStatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 87 / 137,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: 0,
                width: width,
                height: height * (88 / 137),
                child: Image.asset(
                  '${_goAsset}home_stat_card.png',
                  fit: BoxFit.fill,
                ),
              ),
              Positioned(
                left: 4,
                right: 4,
                top: height * (18 / 137),
                height: height * (19 / 137),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _GoOutlinedText(
                    text: label,
                    fontSize: 15,
                    fillColor: Colors.white,
                    strokeColor: const Color(0xFF17120E),
                    strokeWidth: 2,
                  ),
                ),
              ),
              Positioned(
                left: 4,
                right: 4,
                top: height * (42 / 137),
                height: height * (25 / 137),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _GoOutlinedText(
                    text: value,
                    fontSize: 20,
                    fillColor: Colors.white,
                    strokeColor: const Color(0xFF17120E),
                    strokeWidth: 2.3,
                  ),
                ),
              ),
              Positioned(
                left: width * (25 / 87),
                top: height * (85 / 137),
                width: width * (37 / 87),
                height: height * (49 / 137),
                child: Image.asset(
                  '${_goAsset}home_stat_medal.png',
                  fit: BoxFit.contain,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GoGameScreen extends StatefulWidget {
  const _GoGameScreen({
    required this.engine,
    required this.lastMove,
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

  final GoEngine engine;
  final GoMove? lastMove;
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
  State<_GoGameScreen> createState() => _GoGameScreenState();
}

class _GoGameScreenState extends State<_GoGameScreen> {
  // True while a modal (pause / exit) is open, so the per-turn dial freezes
  // instead of ticking behind the dialog.
  bool _paused = false;

  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    final userTurn = widget.enabled && !engine.isFinished;
    final agentTurn = !engine.isFinished && (engine.turn == GoActor.agent);
    final token = '${engine.moveCount}:${engine.turn.name}';
    return Scaffold(
      backgroundColor: const Color(0xFF28150E),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // Game content is inset below the top safe area (notch / island) so
          // the coin badge sits above the name cards (matching 围棋-游戏), while
          // the background still fills the whole screen behind the notch.
          final safeTop = MediaQuery.paddingOf(context).top;
          final height = constraints.maxHeight - safeTop;
          return Stack(
            children: [
              Positioned.fill(
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 11000),
                  scaleAmount: 0.004,
                  phase: 0.35,
                  child: Image.asset(
                    '${_goAsset}game_bg.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: safeTop,
                height: height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Two name cards (design 围棋-游戏, frame 393x852). Each shows
                    // the player's portrait with a per-turn countdown dial over
                    // it, name, and stone-colour label. User top-left, agent
                    // lower-right.
                    Positioned(
                      left: width * (17 / 393),
                      top: height * (62 / 852),
                      width: width * (194 / 393),
                      child: _GoPlayerCard(
                        asset: '${_goAsset}game_card_user.png',
                        name: widget.userName,
                        colorLabel: '黑棋',
                        imageUrl: widget.userAvatarUrl,
                        active: userTurn,
                        paused: _paused,
                        clockToken: token,
                        onTimeout: _handleUserIdleTimeout,
                      ),
                    ),
                    Positioned(
                      left: width * (181 / 393),
                      top: height * (160 / 852),
                      width: width * (194 / 393),
                      child: _GoPlayerCard(
                        asset: '${_goAsset}game_card_agent.png',
                        name: widget.agentName,
                        colorLabel: '白棋',
                        imageUrl: widget.agentAvatarUrl,
                        active: agentTurn,
                        paused: _paused || widget.aiThinking,
                        clockToken: token,
                      ),
                    ),
                    Positioned(
                      left: width * (5 / 393),
                      top: height * (269 / 852),
                      width: width * (384 / 393),
                      height: height * (416 / 852),
                      child: IgnorePointer(
                        child: Image.asset(
                          '${_goAsset}game_board_frame.png',
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                    Positioned(
                      left: width * (32 / 393),
                      top: height * (296 / 852),
                      width: width * (330 / 393),
                      height: height * (362 / 852),
                      child: _GoBoard(
                        engine: engine,
                        lastMove: widget.lastMove,
                        thinking: widget.aiThinking,
                        enabled: widget.enabled,
                        artwork: true,
                        onTap: widget.onTap,
                      ),
                    ),
                    // "你的回合" ribbon at the board's lower-middle, flashing in
                    // when the user's turn begins (timing from admin config).
                    Positioned(
                      left: 0,
                      right: 0,
                      top: height * 0.6936 - (width * 0.13) / 2,
                      height: width * 0.13,
                      child: _TurnBanner(
                        userTurn: userTurn,
                        inMs: widget.bannerInMs,
                        holdMs: widget.bannerHoldMs,
                        outMs: widget.bannerOutMs,
                      ),
                    ),
                    Positioned(
                      left: width * (16 / 393),
                      top: height * (701 / 852),
                      width: width * (130 / 393),
                      child: _GoArtButton(
                        asset: '${_goAsset}game_btn_exit.png',
                        onTap: () => unawaited(_confirmExit(context)),
                      ),
                    ),
                    Positioned(
                      left: width * (146 / 393),
                      top: height * (701 / 852),
                      width: width * (139 / 393),
                      child: _GoArtButton(
                        asset: '${_goAsset}game_btn_pause.png',
                        aspectRatio: 139 / 50,
                        onTap: () => unawaited(_showPause(context)),
                      ),
                    ),
                  ],
                ),
              ),
              // Coin badge in the outer (full-screen) layer so it pins just
              // below the notch, above the inset cards.
              _NativeGamePointsBadge(points: widget.gamePoints),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    setState(() => _paused = true);
    await _showGoModal(
      context,
      title: '退出对局',
      message: '当前棋局还没有结束，退出后本局进度会清空。',
      actions: (dialogContext) => [
        Expanded(
          child: _GoModalButton(
            label: '继续',
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _GoModalButton(
            label: '退出',
            onTap: () {
              Navigator.of(dialogContext).pop();
              // Quitting mid-game → 失败 + 扣分; the 失败 screen's 退出 then leaves.
              unawaited(widget.onShowLose());
            },
          ),
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
    await _showGoModal(
      context,
      title: '游戏暂停',
      message: '要继续当前棋局，还是重新开一盘？',
      actions: (dialogContext) => [
        Expanded(
          child: _GoModalButton(
            label: '继续',
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _GoModalButton(
            label: '重开',
            onTap: () {
              Navigator.of(dialogContext).pop();
              // Restarting mid-game → 失败 + 扣分; the 失败 screen's 重来一局 then
              // starts the new round.
              unawaited(widget.onShowLose());
            },
          ),
        ),
      ],
    );
    if (mounted) setState(() => _paused = false);
  }
}

/// Name card: portrait (with a per-turn countdown dial like 五子棋), the
/// player's name, and their stone-colour label. Positions are card-relative
/// fractions from the 围棋-游戏 design (card 194x84).
class _GoPlayerCard extends StatelessWidget {
  const _GoPlayerCard({
    required this.asset,
    required this.name,
    required this.colorLabel,
    required this.imageUrl,
    required this.active,
    required this.paused,
    required this.clockToken,
    this.onTimeout,
  });

  final String asset;
  final String name;
  final String colorLabel;
  final String? imageUrl;
  final bool active;
  final bool paused;
  final String clockToken;
  final VoidCallback? onTimeout;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 194 / 84,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          // The card art has a gold-ring avatar hole (left), a dark leather
          // name bar (top-right), an art-drawn stone chip, and an empty inset.
          // The portrait fills the ring hole; the name is centred on the dark
          // bar; the colour label sits just right of the stone chip.
          // Flood-fill measured: ring hole centre (42.5, 41.2) d~51; dark name
          // bar x68..175 y15..43; framed inset box centred (156, 58).
          final avatarD = width * (51 / 194);
          return Stack(
            children: [
              Positioned.fill(child: Image.asset(asset, fit: BoxFit.fill)),
              Positioned(
                left: width * (17 / 194),
                top: height * (16 / 84),
                width: avatarD,
                height: avatarD,
                child: _GoTurnAvatar(
                  token: clockToken,
                  imageUrl: imageUrl,
                  fallback: name,
                  diameter: avatarD,
                  active: active,
                  paused: paused,
                  onTimeout: onTimeout,
                ),
              ),
              Positioned(
                left: width * (68 / 194),
                top: height * (15 / 84),
                width: width * (107 / 194),
                height: height * (28 / 84),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: Color(0xFFE1C292),
                        fontSize: 15,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.none,
                        shadows: [
                          Shadow(
                            color: Color(0x66000000),
                            offset: Offset(1, 1),
                            blurRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Colour label centred inside the small framed inset box on the
              // right. Scanline-measured box span x135..177 → centre 156 (a
              // prior eyeball read the right edge short, landing it left).
              Positioned(
                left: width * (140 / 194),
                top: height * (50 / 84),
                width: width * (32 / 194),
                height: height * (16 / 84),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      colorLabel,
                      style: const TextStyle(
                        color: Color(0xFF593016),
                        fontSize: 10,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Circular portrait with a per-turn countdown dial (reuses the 五子棋 painter):
/// a translucent pie mask + sweeping red hand + cyan seconds, shown only while
/// it is this player's turn. Restarts each turn; freezes while [paused].
class _GoTurnAvatar extends StatefulWidget {
  const _GoTurnAvatar({
    required this.token,
    required this.imageUrl,
    required this.fallback,
    required this.diameter,
    required this.active,
    required this.paused,
    this.onTimeout,
  });

  final String token;
  final String? imageUrl;
  final String fallback;
  final double diameter;
  final bool active;
  final bool paused;
  final VoidCallback? onTimeout;

  @override
  State<_GoTurnAvatar> createState() => _GoTurnAvatarState();
}

class _GoTurnAvatarState extends State<_GoTurnAvatar>
    with SingleTickerProviderStateMixin {
  // Seconds a player has to move; the design shows a 30s dial per turn.
  static const int _turnSeconds = 30;
  static const Color _cyan = Color(0xFF44E0FF);

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
  void didUpdateWidget(covariant _GoTurnAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active || widget.token != oldWidget.token) {
      _sync();
    } else if (widget.paused != oldWidget.paused && widget.active) {
      // Freeze/resume the dial when a modal (pause / exit) opens & closes.
      if (widget.paused) {
        _countdown.stop();
      } else if (_countdown.value >= 1.0) {
        // Ran out while the auto-timeout pause was open → fresh turn on resume.
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
    final d = widget.diameter;
    return AnimatedBuilder(
      animation: _countdown,
      builder: (context, _) {
        final remainingFraction = (1 - _countdown.value).clamp(0.0, 1.0);
        final remainingSeconds = (remainingFraction * _turnSeconds)
            .ceil()
            .clamp(0, _turnSeconds);
        return ClipOval(
          child: SizedBox(
            width: d,
            height: d,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _Avatar(
                  size: d,
                  label: widget.fallback.trim().isEmpty
                      ? '伴'
                      : widget.fallback.trim().characters.first,
                  imageUrl: widget.imageUrl,
                  gradient: const [Color(0xFFE8D4B7), Color(0xFFB99671)],
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
                        fontSize: d * 0.4,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        letterSpacing: 0,
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
        );
      },
    );
  }
}

class _GoArtButton extends StatefulWidget {
  const _GoArtButton({
    required this.asset,
    required this.onTap,
    this.aspectRatio = 130 / 46,
    this.enabled = true,
    this.loading = false,
  });

  final String asset;
  final VoidCallback onTap;
  final double aspectRatio;
  final bool enabled;
  final bool loading;

  @override
  State<_GoArtButton> createState() => _GoArtButtonState();
}

class _GoArtButtonState extends State<_GoArtButton> {
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
          opacity: enabled ? 1 : 0.72,
          child: AspectRatio(
            aspectRatio: widget.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Image.asset(widget.asset, fit: BoxFit.fill),
                ),
                if (widget.loading)
                  const CupertinoActivityIndicator(color: Color(0xFFF1D7A5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoOutlinedText extends StatelessWidget {
  const _GoOutlinedText({
    required this.text,
    required this.fontSize,
    required this.fillColor,
    required this.strokeColor,
    required this.strokeWidth,
  });

  final String text;
  final double fontSize;
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            height: 1,
            fontWeight: FontWeight.w900,
            decoration: TextDecoration.none,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = strokeColor,
          ),
        ),
        Text(
          text,
          style: TextStyle(
            color: fillColor,
            fontSize: fontSize,
            height: 1,
            fontWeight: FontWeight.w900,
            decoration: TextDecoration.none,
            shadows: const [
              Shadow(
                color: Color(0x55000000),
                offset: Offset(1, 1),
                blurRadius: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GoModalButton extends StatelessWidget {
  const _GoModalButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: 1,
        child: Container(
          height: 42,
          alignment: const Alignment(0, 0.12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFC79A63), Color(0xFF795137)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF4A2B20), width: 2),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFFE5B8),
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

Future<void> _showGoModal(
  BuildContext context, {
  required String title,
  required String message,
  required List<Widget> Function(BuildContext dialogContext) actions,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭',
    barrierColor: Colors.black.withValues(alpha: 0.56),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, _, __) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 44),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF1DFC2), Color(0xFFC09A70)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF4D3024), width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.42),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF3F281E),
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xCC3F281E),
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 17),
                Row(children: actions(dialogContext)),
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (_, animation, __, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: curve, child: child),
      );
    },
  );
}

enum _GoResultKind { win, lose }

/// Full-screen 围棋 win / lose result scene, composed from the exported art
/// pieces (bg → emblem → banner/title → 积分 → buttons) with a staggered pop-in.
/// Shown at the page level in place of the game so the board / avatars / dial
/// are torn down (no timer left running behind it). Positions measured from the
/// 围棋-胜利 / 围棋-失败 CSS export (frame 393x852).
class _GoResultScreen extends StatefulWidget {
  const _GoResultScreen({
    super.key,
    required this.kind,
    required this.pointsDelta,
    required this.onRestart,
    required this.onExit,
  });

  final _GoResultKind kind;

  /// What this round settled for; null while the wallet hasn't loaded, in
  /// which case the number is left off rather than shown wrong.
  final int? pointsDelta;
  final Future<void> Function() onRestart;
  final Future<void> Function() onExit;

  @override
  State<_GoResultScreen> createState() => _GoResultScreenState();
}

class _GoResultScreenState extends State<_GoResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  // The design is a 393x852 frame. Pieces are both sized and positioned within
  // a letterboxed copy of that frame (centered in the screen) so element
  // overlaps — e.g. the banner crossing the emblem — hold on any aspect ratio.
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

  Widget _img(String name) => Image.asset('$_goAsset$name', fit: BoxFit.fill);

  // Soft light halo behind the win scroll (design "Rectangle 45", a blurred
  // #D9D9D9 backdrop). A transparent rounded box whose big soft shadows radiate
  // out around the scroll's edges.
  Widget _glow() => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(30),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFFFF3D8).withValues(alpha: 0.8),
          blurRadius: 42,
          spreadRadius: 4,
        ),
        BoxShadow(
          color: const Color(0xFFF2E1BC).withValues(alpha: 0.55),
          blurRadius: 90,
          spreadRadius: 18,
        ),
      ],
    ),
  );

  // Positions a piece centered at (cx,cy) fractions of the design canvas with
  // width [wFrac] of the canvas; height follows the art's [aspect] (h/w). Both
  // size and position use the same letterboxed canvas so overlaps are stable.
  // Pops (scale) or drops in from above.
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

  Widget _scorePlate() => Stack(
    alignment: Alignment.center,
    children: [
      Positioned.fill(child: _img('result_score_plate.png')),
      Positioned.fill(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('${_goAsset}result_score_label.png', height: 26),
                const SizedBox(width: 6),
                if (widget.pointsDelta != null)
                  _NativeGameScoreDelta(
                    delta: widget.pointsDelta!,
                    assetPrefix: _goAsset,
                    winValue: 5,
                    loseValue: -4,
                    fill: const Color(0xFFE8C79B),
                    stroke: const Color(0xFFAC9473),
                    height: 26,
                  ),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  Widget _button({
    required String text,
    required VoidCallback onTap,
  }) => _GoResultButton(
    base: 'result_btn_exit.png',
    text: text,
    onTap: onTap,
  );

  @override
  Widget build(BuildContext context) {
    final win = widget.kind == _GoResultKind.win;
    return Scaffold(
      backgroundColor: const Color(0xFF191717),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          // Letterbox the 393x852 design canvas into the screen (centered).
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
                      '${_goAsset}game_bg.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  ...win ? _winPieces() : _losePieces(),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // Positions from the 围棋-胜利 CSS export (frame 393x852).
  List<Widget> _winPieces() => [
    // Soft light halo behind the scroll (Rectangle 45, 232x334 @ 81,122).
    _piece(
      cx: 0.501, cy: 0.339, wFrac: 0.52,
      aspect: 318 / 200, begin: 0.02, end: 0.36,
      child: _glow(),
    ),
    // Blank parchment scroll (200x318 @ 97,130), drops in — drawn first so the
    // sun emblem sits ON it (the scroll is opaque).
    _piece(
      cx: 0.501, cy: 0.339, wFrac: 0.509,
      aspect: 954 / 600, begin: 0.12, end: 0.46, drop: true,
      child: _img('result_win_scroll.png'),
    ),
    // Sun / compass emblem (158x160 @ 118,174), centred in the scroll's upper
    // half.
    _piece(
      cx: 0.501, cy: 0.298, wFrac: 0.402,
      aspect: 480 / 474, begin: 0.18, end: 0.5,
      child: _img('result_win_burst.png'),
    ),
    // Red banner (346x76 @ 24,334), over the scroll's lower half.
    _piece(
      cx: 0.501, cy: 0.437, wFrac: 0.880,
      aspect: 228 / 1038, begin: 0.32, end: 0.56,
      child: _img('result_win_banner.png'),
    ),
    // "胜利" centred on the banner band.
    _piece(
      cx: 0.5, cy: 0.434, wFrac: 0.30,
      aspect: 204 / 378, begin: 0.44, end: 0.66,
      child: _img('result_win_title.png'),
    ),
    // 积分 plate (144x50 @ 125,560).
    _piece(
      cx: 0.501, cy: 0.687, wFrac: 0.366,
      aspect: 150 / 432, begin: 0.56, end: 0.76,
      child: _scorePlate(),
    ),
    // 退出 (170x51 @ 23,664) / 重来一局 (172x50 @ 198,665).
    _piece(
      cx: 0.275, cy: 0.809, wFrac: 0.4326,
      aspect: 153 / 510, begin: 0.66, end: 0.88,
      child: _button(text: 'result_txt_exit.png', onTap: () => unawaited(widget.onExit())),
    ),
    _piece(
      cx: 0.7226, cy: 0.810, wFrac: 0.4377,
      aspect: 150 / 516, begin: 0.72, end: 0.94,
      child: _GoResultButton(
        base: 'result_btn_again.png',
        text: 'result_txt_again.png',
        onTap: () => unawaited(widget.onRestart()),
      ),
    ),
  ];

  // Positions from the 围棋-失败 CSS export (frame 393x852). Order = z-order
  // (design 截图5): dark plate at the BACK, the sun ring covers the plate's
  // top, then the red ribbon + 失败 title cross over the sun's lower third.
  List<Widget> _losePieces() => [
    // Dark plate (354x109 @ 20,257) — BACK layer.
    _piece(
      cx: 0.501, cy: 0.3656, wFrac: 0.9008,
      aspect: 327 / 1062, begin: 0.24, end: 0.5,
      child: _img('result_lose_banner_back.png'),
    ),
    // Sun ring emblem (213x213 @ 90,130), drops in, covering the plate's top.
    _piece(
      cx: 0.5, cy: 0.2776, wFrac: 0.542,
      aspect: 639 / 639, begin: 0.12, end: 0.46, drop: true,
      child: _img('result_lose_emblem.png'),
    ),
    // Front red ribbon (358x91 @ 18,291), crossing over the sun's lower third.
    _piece(
      cx: 0.501, cy: 0.395, wFrac: 0.911,
      aspect: 273 / 1074, begin: 0.34, end: 0.58,
      child: _img('result_lose_banner.png'),
    ),
    // "失败" centred on the ribbon band.
    _piece(
      cx: 0.5, cy: 0.398, wFrac: 0.30,
      aspect: 203 / 388, begin: 0.46, end: 0.68,
      child: _img('result_lose_title.png'),
    ),
    // 积分 plate (144x50 @ 125,562).
    _piece(
      cx: 0.501, cy: 0.689, wFrac: 0.366,
      aspect: 150 / 432, begin: 0.56, end: 0.76,
      child: _scorePlate(),
    ),
    // 退出 (170x51 @ 23,666) / 重来一局 (172x50 @ 198,667).
    _piece(
      cx: 0.275, cy: 0.8117, wFrac: 0.4326,
      aspect: 153 / 510, begin: 0.66, end: 0.88,
      child: _button(text: 'result_txt_exit.png', onTap: () => unawaited(widget.onExit())),
    ),
    _piece(
      cx: 0.7226, cy: 0.8122, wFrac: 0.4377,
      aspect: 150 / 516, begin: 0.72, end: 0.94,
      child: _GoResultButton(
        base: 'result_btn_again.png',
        text: 'result_txt_again.png',
        onTap: () => unawaited(widget.onRestart()),
      ),
    ),
  ];
}

/// Result-screen button (退出 / 重来一局): textless base art + text overlay,
/// sized by height so both share the same glyph size, with a press-in scale.
class _GoResultButton extends StatefulWidget {
  const _GoResultButton({
    required this.base,
    required this.text,
    required this.onTap,
  });

  final String base;
  final String text;
  final VoidCallback onTap;

  @override
  State<_GoResultButton> createState() => _GoResultButtonState();
}

class _GoResultButtonState extends State<_GoResultButton> {
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
              child: Image.asset('$_goAsset${widget.base}', fit: BoxFit.fill),
            ),
            Positioned.fill(
              child: Align(
                alignment: const Alignment(0, -0.04),
                child: FractionallySizedBox(
                  heightFactor: 0.42,
                  child: Image.asset(
                    '$_goAsset${widget.text}',
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
