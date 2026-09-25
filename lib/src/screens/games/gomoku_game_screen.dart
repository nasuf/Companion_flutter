part of 'package:companion_flutter/main.dart';

// ===========================================================================
// 五子棋游戏界面 (illustrated game-art board screen, 1:1 with Figma). Canyon
// background, two framed avatars (user left + medal, agent right) whose frame
// glows on that player's turn, a warm wooden 15×15 board, and 退出/暂停.
// Positions are fractions measured from the 393×852 design frame.
// ===========================================================================

const String _gomokuGameBg = '${_gomokuHomeAsset}game_bg.png';
const String _gomokuNamePlate = '${_gomokuHomeAsset}game_name_plate.png';

class _GomokuGameScreen extends StatefulWidget {
  const _GomokuGameScreen({
    required this.engine,
    required this.agentName,
    required this.userName,
    required this.agentAvatarUrl,
    required this.userAvatarUrl,
    required this.aiThinking,
    required this.starting,
    required this.syncNotice,
    required this.onPointTap,
    required this.onShowLose,
    required this.bannerInMs,
    required this.bannerHoldMs,
    required this.bannerOutMs,
    required this.gamePoints,
  });

  final GomokuEngine engine;
  final String agentName;
  final String userName;
  final String? agentAvatarUrl;
  final String? userAvatarUrl;
  final bool aiThinking;
  final bool starting;
  final String? syncNotice;
  final ValueChanged<GomokuPoint> onPointTap;
  // Quitting / restarting mid-game → settle as a loss and show the 失败 screen.
  final Future<void> Function() onShowLose;
  // "你的回合" banner timing (ms), from the per-game admin config.
  final int bannerInMs;
  final int bannerHoldMs;
  final int bannerOutMs;
  // Current game points, shown in the top-right coin badge.
  final int? gamePoints;

  @override
  State<_GomokuGameScreen> createState() => _GomokuGameScreenState();
}

class _GomokuGameScreenState extends State<_GomokuGameScreen> {
  // True while a modal (pause / exit confirm) is open, so the turn countdown
  // freezes instead of ticking behind the dialog.
  bool _paused = false;

  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    final agentName = widget.agentName;
    final userName = widget.userName;
    final agentAvatarUrl = widget.agentAvatarUrl;
    final userAvatarUrl = widget.userAvatarUrl;
    final aiThinking = widget.aiThinking;
    final starting = widget.starting;
    final syncNotice = widget.syncNotice;
    final onPointTap = widget.onPointTap;
    final finished = engine.isFinished;
    final userTurn =
        !finished &&
        !aiThinking &&
        !starting &&
        engine.status == GomokuGameStatus.playing;
    final boardEnabled = userTurn;
    final clockPaused = gameClockPaused(context, manualPaused: _paused);

    return Scaffold(
      backgroundColor: const Color(0xFFE7C9A6),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          // Figma outer avatar ring is 86px on a 393px frame; the inner image
          // is 80px, leaving a 3px ring on each side.
          final avatarD = w * (66 / 393);
          final plateW = w * (121 / 393);
          return Stack(
            children: [
              Positioned.fill(
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 10000),
                  scaleAmount: 0.006,
                  phase: 0.45,
                  child: Image.asset(_gomokuGameBg, fit: BoxFit.cover),
                ),
              ),

              // Both avatars sit at the same height (design 2:3). Each glows
              // and shows a 30s turn countdown while it is that player's turn.
              _centered(
                w,
                h,
                cx: 0.763,
                cy: 0.18,
                width: avatarD,
                child: _GomokuAvatar(
                  imageUrl: agentAvatarUrl,
                  fallback: agentName,
                  diameter: avatarD,
                  active: aiThinking,
                  paused: clockPaused,
                ),
              ),
              _centered(
                w,
                h,
                cx: 0.237,
                cy: 0.18,
                width: avatarD,
                child: _GomokuAvatar(
                  imageUrl: userAvatarUrl,
                  fallback: '你',
                  diameter: avatarD,
                  active: userTurn,
                  paused: clockPaused,
                  onTimeout: _handleUserIdleTimeout,
                ),
              ),
              // Name plates sit directly under each avatar, overlapping its
              // lower edge, with the player's stone colour shown as a chip.
              _centered(
                w,
                h,
                cx: 0.763,
                cy: 0.252,
                width: plateW,
                child: _GomokuNamePlate(
                  name: agentName,
                  stone: GomokuStone.white,
                  stoneOnRight: false,
                ),
              ),
              _centered(
                w,
                h,
                cx: 0.237,
                cy: 0.252,
                width: plateW,
                child: _GomokuNamePlate(
                  name: userName,
                  stone: GomokuStone.black,
                  stoneOnRight: true,
                ),
              ),

              // Board.
              _centered(
                w,
                h,
                cx: 0.501,
                cy: 0.539,
                width: w * 0.891,
                child: _GomokuDesignBoard(
                  engine: engine,
                  enabled: boardEnabled,
                  onPointTap: onPointTap,
                ),
              ),

              // "你的回合" ribbon — flashes in from the right, holds ~2s, then
              // slides out to the left whenever the user's turn begins.
              Positioned(
                left: 0,
                right: 0,
                top: h * 0.64 - (w * 0.13) / 2,
                height: w * 0.13,
                child: _TurnBanner(
                  userTurn: userTurn,
                  inMs: widget.bannerInMs,
                  holdMs: widget.bannerHoldMs,
                  outMs: widget.bannerOutMs,
                ),
              ),

              if (syncNotice != null)
                Positioned(
                  left: w * 0.08,
                  right: w * 0.08,
                  top: h * 0.70,
                  child: _GomokuNotice(text: syncNotice, isError: false),
                ),

              // Bottom buttons — nudged down from the board per the design.
              Positioned(
                left: w * 0.074,
                top: h * 0.804,
                width: w * 0.254,
                child: _GomokuGameButton(
                  base: '${_gomokuHomeAsset}home_btn_exit.png',
                  label: '退出',
                  onTap: () => _confirmExit(context),
                ),
              ),
              Positioned(
                left: w * 0.374,
                top: h * 0.804,
                width: w * 0.254,
                child: _GomokuGameButton(
                  base: '${_gomokuHomeAsset}home_btn_start.png',
                  label: '暂停',
                  onTap: () => _showPauseMenu(context),
                ),
              ),
              // Help (?) button on the right — opens the rules popup.
              _centered(
                w,
                h,
                cx: 0.910,
                cy: 0.829,
                width: w * 0.064,
                child: _GomokuHelpButton(onTap: () => _showRules(context)),
              ),
              _NativeGamePointsBadge(points: widget.gamePoints),
            ],
          );
        },
      ),
    );
  }

  // Places a fixed-aspect child so its center lands on (cx,cy) as a fraction of
  // the screen; height follows the child's own aspect via the width.
  Widget _centered(
    double w,
    double h, {
    required double cx,
    required double cy,
    required double width,
    required Widget child,
  }) {
    return Positioned(
      left: w * cx - width / 2,
      top: h * cy,
      width: width,
      child: FractionalTranslation(
        translation: const Offset(0, -0.5),
        child: child,
      ),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    setState(() => _paused = true);
    await _showGomokuModal(
      context,
      title: '退出对局',
      message: '当前这盘还没下完，退出后进度会清空。确定要退出吗？',
      actions: (dialogContext) => [
        Expanded(
          child: _GomokuGameButton(
            base: '${_gomokuHomeAsset}home_btn_start.png',
            label: '再想想',
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GomokuGameButton(
            base: '${_gomokuHomeAsset}home_btn_exit.png',
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

  // The turn countdown ran out while the user hadn't moved — surface the pause
  // menu automatically (replaces the old idle-timeout prompt).
  void _handleUserIdleTimeout() {
    if (!mounted || _paused || widget.engine.isFinished) return;
    unawaited(_showPauseMenu(context));
  }

  Future<void> _showPauseMenu(BuildContext context) async {
    setState(() => _paused = true);
    await _showGomokuModal(
      context,
      title: '游戏暂停',
      message: '要继续当前对局，还是重新开一盘？',
      actions: (dialogContext) => [
        Expanded(
          child: _GomokuGameButton(
            base: '${_gomokuHomeAsset}home_btn_start.png',
            label: '继续',
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GomokuGameButton(
            base: '${_gomokuHomeAsset}home_btn_exit.png',
            label: '重新开局',
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

  // Rules popup — pauses the turn dial while open (no pause dialog), resumes on
  // close.
  Future<void> _showRules(BuildContext context) async {
    setState(() => _paused = true);
    await _showGameRulesDialog(
      context,
      gameName: '五子棋',
      rules: const ['1、黑白双方交替落子', '2、率先横向 / 竖向 / 斜向连成五子直接获胜', '3、棋盘布满无五子则平局'],
    );
    if (mounted) setState(() => _paused = false);
  }
}

/// Custom game-art modal (cream wood card + gold border) shown centered, used
/// for the exit confirm and pause menu so we never fall back to a system sheet.
Future<void> _showGomokuModal(
  BuildContext context, {
  required String title,
  String? message,
  required List<Widget> Function(BuildContext dialogContext) actions,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, _, __) {
      final rowActions = actions(dialogContext);
      return Center(
        child: _GomokuModalCard(
          title: title,
          message: message,
          child: Row(children: rowActions),
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
          scale: Tween<double>(begin: 0.86, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _GomokuModalCard extends StatelessWidget {
  const _GomokuModalCard({
    required this.title,
    required this.message,
    required this.child,
  });

  final String title;
  final String? message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: w * 0.13),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFDF6E9), Color(0xFFF3E4C9)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE0B072), width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7A4A22).withValues(alpha: 0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF5C3E22),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    height: 1.1,
                    decoration: TextDecoration.none,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF8A6A45),
                      fontSize: 13.5,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                child,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Circular avatar framed by a coin-ring asset — golden normally, swapped to
/// the silver-white ring while it is this player's turn. Shows a 30s countdown
/// dial over the portrait during that turn.
class _GomokuAvatar extends StatefulWidget {
  const _GomokuAvatar({
    required this.imageUrl,
    required this.fallback,
    required this.diameter,
    required this.active,
    required this.paused,
    this.onTimeout,
  });

  final String? imageUrl;
  final String fallback;
  final double diameter;
  final bool active;
  final bool paused;
  // Fired when the turn countdown runs out while still this player's turn.
  final VoidCallback? onTimeout;

  @override
  State<_GomokuAvatar> createState() => _GomokuAvatarState();
}

class _GomokuAvatarState extends State<_GomokuAvatar>
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
    // Turn ran out while it is still this player's turn (and no modal open).
    if (status == AnimationStatus.completed &&
        widget.active &&
        !widget.paused) {
      widget.onTimeout?.call();
    }
  }

  @override
  void didUpdateWidget(covariant _GomokuAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      _sync();
    } else if (widget.paused != oldWidget.paused && widget.active) {
      // Freeze/resume the turn dial when a modal (pause / exit) opens & closes,
      // keeping the current remaining time instead of restarting or ticking.
      if (widget.paused) {
        _countdown.stop();
      } else if (_countdown.value >= 1.0) {
        // The dial had already run out (e.g. the modal was the auto-timeout
        // pause) — give a fresh turn on resume rather than staying at 0.
        _countdown.forward(from: 0);
      } else {
        _countdown.forward();
      }
    }
  }

  void _sync() {
    if (widget.active && !widget.paused) {
      // Restart the dial from full at the start of every turn.
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
    // The portrait fills the ring asset's transparent hole; the ring PNG
    // (game_avatar_frame.png) overlays it as the golden coin frame.
    final inner = d * 0.74;
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
              // Portrait clipped to the ring's inner hole.
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
                        gradient: const [Color(0xFFE8F3FF), Color(0xFFD7E9FF)],
                      ),
                      if (widget.active) ...[
                        // Countdown mask + sweeping red hand + seconds.
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
                    ],
                  ),
                ),
              ),
              // Coin frame on top: golden by default, silver-white while it is
              // this player's turn (design 2:3 / 125:1028) — the frame itself
              // is the turn highlight, no extra glow.
              Image.asset(
                widget.active
                    ? '${_gomokuHomeAsset}game_avatar_frame_active.png'
                    : '${_gomokuHomeAsset}game_avatar_frame.png',
                width: d,
                height: d,
                fit: BoxFit.contain,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Draws the per-turn stopwatch: a translucent white disc over the portrait
/// and a red ring that drains clockwise from the top as time runs out.
class _GomokuTurnTimerPainter extends CustomPainter {
  const _GomokuTurnTimerPainter({required this.remainingFraction});

  final double remainingFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final elapsed = (1 - remainingFraction).clamp(0.0, 1.0);
    final handAngle = -math.pi / 2 + elapsed * 2 * math.pi;

    // Gray pie mask over the sector not yet swept. It starts covering the whole
    // portrait and shrinks clockwise as the red hand sweeps, revealing the
    // portrait — the mask is "eaten away" over the turn.
    final remainingSweep = (1 - elapsed) * 2 * math.pi;
    if (remainingSweep > 0.0001) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        handAngle,
        remainingSweep,
        true,
        Paint()..color = const Color(0xFF8E8E8E).withValues(alpha: 0.82),
      );
    }

    // Red sweeping hand at the leading edge of the mask.
    final dir = Offset(math.cos(handAngle), math.sin(handAngle));
    const red = Color(0xFFC81E1E);
    canvas.drawLine(
      center,
      center + dir * (radius * 0.94),
      Paint()
        ..color = red
        ..strokeWidth = radius * 0.08
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, radius * 0.08, Paint()..color = red);
  }

  @override
  bool shouldRepaint(covariant _GomokuTurnTimerPainter oldDelegate) =>
      oldDelegate.remainingFraction != remainingFraction;
}

/// Cream name pill (art) with the player's name and their stone colour shown
/// as a chip on the side facing the board centre.
class _GomokuNamePlate extends StatelessWidget {
  const _GomokuNamePlate({
    required this.name,
    required this.stone,
    required this.stoneOnRight,
  });

  final String name;
  final GomokuStone stone;
  final bool stoneOnRight;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 450 / 138,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final stoneWidget = SvgPicture.asset(
            stone == GomokuStone.black
                ? '${_gomokuHomeAsset}game_stone_black.svg'
                : '${_gomokuHomeAsset}game_stone_white.svg',
            width: h * 0.5,
            height: h * 0.5,
            fit: BoxFit.contain,
          );
          final nameWidget = Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                // Design 2:3: the name glyph is ~0.37x the plate height, so the
                // font size is ~0.42x height (was a fixed 22 → too large).
                child: Text(
                  name,
                  maxLines: 1,
                  style: _kNamePlateStyle.copyWith(fontSize: h * 0.42),
                ),
              ),
            ),
          );
          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Image.asset(_gomokuNamePlate, fit: BoxFit.fill),
              ),
              // The stone sits hard against the outer end of the pill; the name
              // centres in the remaining space (matches Figma 2:3).
              Padding(
                padding: EdgeInsets.symmetric(horizontal: h * 0.3),
                child: Row(
                  children: stoneOnRight
                      ? [nameWidget, SizedBox(width: h * 0.12), stoneWidget]
                      : [stoneWidget, SizedBox(width: h * 0.12), nameWidget],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

const TextStyle _kNamePlateStyle = TextStyle(
  color: Color(0xFF6B4A2E),
  fontSize: 22,
  fontWeight: FontWeight.w900,
  letterSpacing: 0,
  height: 1,
  decoration: TextDecoration.none,
);

/// Wooden framed 15×15 board that reuses the interactive board painter.
class _GomokuDesignBoard extends StatelessWidget {
  const _GomokuDesignBoard({
    required this.engine,
    required this.enabled,
    required this.onPointTap,
  });

  final GomokuEngine engine;
  final bool enabled;
  final ValueChanged<GomokuPoint> onPointTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1050 / 1113,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              '${_gomokuHomeAsset}game_board_base.png',
              fit: BoxFit.fill,
            ),
          ),
          Positioned.fill(
            child: _GomokuBoard(
              engine: engine,
              enabled: enabled,
              onPointTap: onPointTap,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom action button (art base + rendered label), matching 退出/暂停.
class _GomokuGameButton extends StatefulWidget {
  const _GomokuGameButton({
    required this.base,
    required this.label,
    required this.onTap,
  });

  final String base;
  final String label;
  final VoidCallback onTap;

  @override
  State<_GomokuGameButton> createState() => _GomokuGameButtonState();
}

class _GomokuGameButtonState extends State<_GomokuGameButton> {
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
        scale: _pressed ? 0.95 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AspectRatio(
          aspectRatio: 450 / 207,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Image.asset(widget.base, fit: BoxFit.fill),
              ),
              Align(
                alignment: const Alignment(0, -0.14),
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    height: 1,
                    decoration: TextDecoration.none,
                    shadows: [
                      Shadow(
                        color: Color(0x66000000),
                        offset: Offset(1.5, 1.5),
                        blurRadius: 2,
                      ),
                    ],
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
