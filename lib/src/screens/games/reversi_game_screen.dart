part of 'package:companion_flutter/main.dart';

class _ReversiGameScreen extends StatefulWidget {
  const _ReversiGameScreen({
    required this.engine,
    required this.lastMove,
    required this.agentName,
    required this.userName,
    required this.agentAvatarUrl,
    required this.userAvatarUrl,
    required this.startedAt,
    required this.aiThinking,
    required this.resolving,
    required this.starting,
    required this.timerPaused,
    required this.enabled,
    required this.onTap,
    required this.onRestart,
    required this.onExit,
    required this.onTimerPauseChanged,
    required this.onShowLose,
    required this.bannerInMs,
    required this.bannerHoldMs,
    required this.bannerOutMs,
    required this.gamePoints,
  });

  final ReversiEngine engine;
  final ReversiMove? lastMove;
  final String agentName;
  final String userName;
  final String? agentAvatarUrl;
  final String? userAvatarUrl;
  final DateTime? startedAt;
  final bool aiThinking;
  final bool resolving;
  final bool starting;
  final bool timerPaused;
  final bool enabled;
  final ValueChanged<int> onTap;
  final Future<void> Function() onRestart;
  final VoidCallback onExit;
  final ValueChanged<bool> onTimerPauseChanged;
  // Quit / restart mid-game → show the loss result instead of exiting directly.
  final VoidCallback onShowLose;
  // "你的回合" banner timing (ms), from the per-game admin config.
  final int bannerInMs;
  final int bannerHoldMs;
  final int bannerOutMs;
  // Current game points, shown in the top-right coin badge.
  final int? gamePoints;

  @override
  State<_ReversiGameScreen> createState() => _ReversiGameScreenState();
}

class _ReversiGameScreenState extends State<_ReversiGameScreen> {
  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    final lastMove = widget.lastMove;
    final agentName = widget.agentName;
    final userName = widget.userName;
    final agentAvatarUrl = widget.agentAvatarUrl;
    final userAvatarUrl = widget.userAvatarUrl;
    final aiThinking = widget.aiThinking;
    final resolving = widget.resolving;
    final enabled = widget.enabled;
    final onTap = widget.onTap;
    final userTurn =
        !engine.isFinished &&
        engine.turn == ReversiActor.user &&
        !aiThinking &&
        !resolving;
    final agentTurn =
        !engine.isFinished && (engine.turn == ReversiActor.agent || aiThinking);
    final clockPaused = gameClockPaused(
      context,
      manualPaused: widget.timerPaused,
    );
    return Scaffold(
      backgroundColor: const Color(0xFF85D3EB),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          return Stack(
            children: [
              Positioned.fill(
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 10000),
                  scaleAmount: 0.005,
                  phase: 0.4,
                  child: Image.asset(
                    '${_reversiAsset}game_bg.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // Avatars sit on the outer edges with their name plates tucked
              // inside, all in one row (design 37:200). Positions are measured
              // from the design proportions — nudge if slightly off.
              Positioned(
                left: width * (31 / 393),
                top: height * (146 / 852),
                width: width * (50 / 393),
                child: _ReversiAvatar(
                  frameAsset: '${_reversiAsset}game_avatar_frame_user.png',
                  imageUrl: userAvatarUrl,
                  fallback: userName,
                  active: userTurn,
                  glowColor: const Color(0xFF49DFFF),
                  paused: clockPaused,
                  onTimeout: _handleUserIdleTimeout,
                ),
              ),
              Positioned(
                left: width * (312 / 393),
                top: height * (146 / 852),
                width: width * (50 / 393),
                child: _ReversiAvatar(
                  frameAsset: '${_reversiAsset}game_avatar_frame_agent.png',
                  imageUrl: agentAvatarUrl,
                  fallback: agentName,
                  active: agentTurn,
                  glowColor: const Color(0xFFFFC94D),
                  paused: clockPaused,
                ),
              ),
              // Name plates sit right beside the avatars with a small gap
              // (design 37:200, measured).
              Positioned(
                left: width * (93 / 393),
                top: height * (152 / 852),
                width: width * (97 / 393),
                child: _ReversiNamePlate(
                  asset: '${_reversiAsset}game_name_user.png',
                  name: userName,
                  active: userTurn,
                ),
              ),
              Positioned(
                left: width * (203 / 393),
                top: height * (152 / 852),
                width: width * (97 / 393),
                child: _ReversiNamePlate(
                  asset: '${_reversiAsset}game_name_agent.png',
                  name: agentName,
                  active: agentTurn,
                ),
              ),
              // Live disc score "user VS agent" — replaces the old standalone
              // countdown + hourglass.
              Positioned(
                left: width * (138 / 393),
                top: height * (214 / 852),
                width: width * (116 / 393),
                child: _ReversiScorePlate(
                  userCount: engine.userCount,
                  agentCount: engine.agentCount,
                ),
              ),
              Positioned(
                left: width * (17 / 393),
                top: height * (274 / 852),
                width: width * (368 / 393),
                child: AspectRatio(
                  aspectRatio: 368 / 374,
                  child: _ReversiBoard(
                    engine: engine,
                    lastMove: lastMove,
                    thinking: aiThinking,
                    enabled: enabled,
                    onTap: onTap,
                  ),
                ),
              ),
              Positioned(
                left: width * (27 / 393),
                top: height * (666 / 852),
                width: width * (100 / 393),
                child: _ReversiImageButton(
                  base: '${_reversiAsset}game_btn_exit.png',
                  textAsset: '${_reversiAsset}game_btn_exit_text.png',
                  aspectRatio: 300 / 165,
                  textWidthFactor: 0.46,
                  textAlignment: const Alignment(0, 0.10),
                  onTap: () => unawaited(_confirmExit(context)),
                ),
              ),
              Positioned(
                left: width * (144 / 393),
                top: height * (666 / 852),
                width: width * (100 / 393),
                child: _ReversiImageButton(
                  base: '${_reversiAsset}game_btn_pause.png',
                  textAsset: '${_reversiAsset}game_btn_pause_text.png',
                  aspectRatio: 300 / 165,
                  textWidthFactor: 0.46,
                  textAlignment: const Alignment(0, 0.10),
                  onTap: () => unawaited(_showPause(context)),
                ),
              ),
              // Gear (bottom-right) opens the reversi rules popup (design 198:1273).
              // 40x41 in Figma; vertical centre aligned with the exit/pause
              // buttons (their centre sits at 666 + 55/2 = 693.5).
              Positioned(
                left: width * (330 / 393),
                top: height * (673 / 852),
                width: width * (40 / 393),
                child: _ReversiGearButton(
                  onTap: () => unawaited(_showRules(context)),
                ),
              ),
              // "你的回合" ribbon flashes in at the board's lower-middle on the
              // user's turn (shared with gomoku).
              Positioned(
                left: 0,
                right: 0,
                top: height * 0.63 - (width * 0.13) / 2,
                height: width * 0.13,
                child: _TurnBanner(
                  userTurn: userTurn,
                  inMs: widget.bannerInMs,
                  holdMs: widget.bannerHoldMs,
                  outMs: widget.bannerOutMs,
                ),
              ),
              _NativeGamePointsBadge(points: widget.gamePoints),
            ],
          );
        },
      ),
    );
  }

  // The 30s turn countdown ran out while the user hadn't moved — auto-open the
  // pause menu (mirrors gomoku; replaces the old idle-timeout prompt).
  void _handleUserIdleTimeout() {
    if (!mounted || widget.timerPaused || widget.engine.isFinished) return;
    unawaited(_showPause(context));
  }

  Future<void> _confirmExit(BuildContext context) async {
    widget.onTimerPauseChanged(true);
    await _showReversiModal(
      context,
      title: '退出对局',
      message: '当前棋局还没结束，退出后本局进度会清空。',
      actions: (dialogContext) => [
        Expanded(
          child: _ReversiModalButton(
            asset: '${_reversiAsset}game_btn_pause.png',
            label: '继续',
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ReversiModalButton(
            asset: '${_reversiAsset}game_btn_exit.png',
            label: '退出',
            onTap: () {
              Navigator.of(dialogContext).pop();
              widget.onShowLose();
            },
          ),
        ),
      ],
    );
    widget.onTimerPauseChanged(false);
  }

  Future<void> _showPause(BuildContext context) async {
    widget.onTimerPauseChanged(true);
    await _showReversiModal(
      context,
      title: '游戏暂停',
      message: '要继续当前棋局，还是重新开一盘？',
      actions: (dialogContext) => [
        Expanded(
          child: _ReversiModalButton(
            asset: '${_reversiAsset}game_btn_pause.png',
            label: '继续',
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ReversiModalButton(
            asset: '${_reversiAsset}game_btn_exit.png',
            label: '重新开局',
            onTap: () {
              Navigator.of(dialogContext).pop();
              widget.onShowLose();
            },
          ),
        ),
      ],
    );
    widget.onTimerPauseChanged(false);
  }

  // Rules popup — pauses the turn countdown while open (no pause dialog),
  // resumes on close.
  Future<void> _showRules(BuildContext context) async {
    widget.onTimerPauseChanged(true);
    await _showGameRulesDialog(
      context,
      gameName: '黑白棋',
      rules: const ['1、落子需夹住对方棋子，将其翻转为己方颜色', '2、棋盘无子可落则跳过回合', '3、对局结束棋子数量多者获胜'],
    );
    widget.onTimerPauseChanged(false);
  }
}

class _ReversiAvatar extends StatefulWidget {
  const _ReversiAvatar({
    required this.frameAsset,
    required this.imageUrl,
    required this.fallback,
    required this.active,
    required this.glowColor,
    required this.paused,
    this.onTimeout,
  });

  final String frameAsset;
  final String? imageUrl;
  final String fallback;
  final bool active;
  final Color glowColor;
  final bool paused;
  // Fired when the 30s turn countdown runs out while still this player's turn.
  final VoidCallback? onTimeout;

  @override
  State<_ReversiAvatar> createState() => _ReversiAvatarState();
}

class _ReversiAvatarState extends State<_ReversiAvatar>
    with SingleTickerProviderStateMixin {
  static const int _turnSeconds = 30;
  late final AnimationController _countdown;

  @override
  void initState() {
    super.initState();
    _countdown = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _turnSeconds),
    )..addStatusListener(_onStatus);
    _sync();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        widget.active &&
        !widget.paused) {
      widget.onTimeout?.call();
    }
  }

  @override
  void didUpdateWidget(covariant _ReversiAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
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
    return AspectRatio(
      aspectRatio: 88 / 90,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final inner = width * (80 / 88);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: width * (4 / 88),
                top: height * (8 / 90),
                width: inner,
                height: inner,
                child: DecoratedBox(
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: ClipOval(
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
                            Color(0xFFE8F3FF),
                            Color(0xFFD7E9FF),
                          ],
                        ),
                        if (widget.active)
                          AnimatedBuilder(
                            animation: _countdown,
                            builder: (context, _) {
                              final remaining = (1 - _countdown.value).clamp(
                                0.0,
                                1.0,
                              );
                              final secs = (remaining * _turnSeconds)
                                  .ceil()
                                  .clamp(0, _turnSeconds);
                              return Stack(
                                fit: StackFit.expand,
                                children: [
                                  CustomPaint(
                                    painter: _GomokuTurnTimerPainter(
                                      remainingFraction: remaining,
                                    ),
                                  ),
                                  Center(
                                    child: Text(
                                      '$secs',
                                      style: TextStyle(
                                        color: widget.glowColor,
                                        fontSize: inner * 0.32,
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
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Image.asset(widget.frameAsset, fit: BoxFit.fill),
              ),
              // Glowing ring swapped in while it is this player's turn.
              if (widget.active)
                Positioned.fill(
                  child: Transform.scale(
                    scale: 1.12,
                    child: Image.asset(
                      '${_reversiAsset}game_avatar_frame_active.png',
                      fit: BoxFit.contain,
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

class _ReversiNamePlate extends StatelessWidget {
  const _ReversiNamePlate({
    required this.asset,
    required this.name,
    this.active = false,
  });

  final String asset;
  final String name;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 300 / 120,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // The plate swaps to the glowing active art while it is this
              // player's turn (design "头像/名字方框变色").
              Positioned.fill(
                child: Image.asset(
                  active ? '${_reversiAsset}game_name_active.png' : asset,
                  fit: BoxFit.fill,
                ),
              ),
              // Name centered in the plate.
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: width * 0.14,
                    vertical: height * 0.2,
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _ReversiOutlinedText(text: name, fontSize: 15),
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

/// Live disc score "user VS agent" on the wooden plate (design 37:200),
/// replacing the old elapsed-time timer + hourglass.
class _ReversiScorePlate extends StatelessWidget {
  const _ReversiScorePlate({required this.userCount, required this.agentCount});

  final int userCount;
  final int agentCount;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 210 / 75,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Image.asset(
              '${_reversiAsset}game_timer_plate.png',
              fit: BoxFit.fill,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _ReversiOutlinedText(
                text: '$userCount  VS  $agentCount',
                fontSize: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom-right gear that opens the rules popup (design 198:1273).
class _ReversiGearButton extends StatefulWidget {
  const _ReversiGearButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ReversiGearButton> createState() => _ReversiGearButtonState();
}

class _ReversiGearButtonState extends State<_ReversiGearButton> {
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
        scale: _pressed ? 0.9 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Image.asset(
          '${_reversiAsset}game_gear.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _ReversiOutlinedText extends StatelessWidget {
  const _ReversiOutlinedText({required this.text, required this.fontSize});

  final String text;
  final double fontSize;

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
              ..strokeWidth = 2.2
              ..strokeJoin = StrokeJoin.round
              ..color = Colors.black,
          ),
        ),
        Text(
          text,
          style: TextStyle(
            color: Colors.white,
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

class _ReversiModalButton extends StatelessWidget {
  const _ReversiModalButton({
    required this.asset,
    required this.label,
    required this.onTap,
  });

  final String asset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 300 / 165,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(child: Image.asset(asset, fit: BoxFit.fill)),
            _ReversiOutlinedText(text: label, fontSize: 17),
          ],
        ),
      ),
    );
  }
}

Future<void> _showReversiModal(
  BuildContext context, {
  required String title,
  required String message,
  required List<Widget> Function(BuildContext dialogContext) actions,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, _, __) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 46),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF5D8), Color(0xFFE9C695)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF8A4B27), width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
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
                    color: Color(0xFF502A2A),
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
                    color: Color(0xFF75513B),
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 18),
                Row(children: actions(dialogContext)),
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}
