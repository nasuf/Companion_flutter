part of 'package:companion_flutter/main.dart';

const String _xiangqiAsset = 'assets/prototype/games/xiangqi/';

class _XiangqiHome extends StatelessWidget {
  const _XiangqiHome({
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
      backgroundColor: const Color(0xFFD8E2F3),
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
                  phase: 0.35,
                  child: Image.asset(
                    '${_xiangqiAsset}home_bg.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                left: width * (14 / 393),
                top: height * (80 / 852),
                width: width * (365 / 393),
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 5600),
                  scaleAmount: 0.008,
                  translateY: 1.7,
                  phase: 0.18,
                  child: Image.asset(
                    '${_xiangqiAsset}home_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                left: width * (14 / 393),
                top: height * (226 / 852),
                width: width * (365 / 393),
                height: height * (251 / 852),
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 6500),
                  scaleAmount: 0.006,
                  translateY: 1.5,
                  phase: 0.62,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(width * 0.025),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF36566B).withValues(alpha: 0.2),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(width * 0.025),
                      child: Image.asset(
                        '${_xiangqiAsset}home_board.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              if (error != null)
                Positioned(
                  left: width * 0.08,
                  right: width * 0.08,
                  top: height * 0.535,
                  child: _GomokuNotice(text: error!, isError: true),
                ),
              Positioned(
                left: width * (18 / 393),
                top: height * (525 / 852),
                width: width * (166 / 393),
                child: _XiangqiArtButton(
                  asset: '${_xiangqiAsset}home_btn_exit.png',
                  aspectRatio: 507 / 150,
                  enabled: !starting,
                  onTap: onExit,
                ),
              ),
              Positioned(
                left: width * (209 / 393),
                top: height * (525 / 852),
                width: width * (166 / 393),
                child: _XiangqiArtButton(
                  asset: '${_xiangqiAsset}home_btn_start.png',
                  aspectRatio: 507 / 150,
                  loading: starting,
                  enabled: !starting,
                  onTap: () => unawaited(onStart()),
                ),
              ),
              for (var index = 0; index < 4; index += 1)
                Positioned(
                  left: width * ([9, 106, 201, 300][index] / 393),
                  top: height * (704 / 852),
                  width: width * (83 / 393),
                  child: _XiangqiHomeStatCard(
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

class _XiangqiHomeStatCard extends StatelessWidget {
  const _XiangqiHomeStatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 83 / 89,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  '${_xiangqiAsset}home_stat_card.png',
                  fit: BoxFit.fill,
                ),
              ),
              Positioned(
                left: 5,
                right: 5,
                top: height * (17 / 89),
                height: height * (20 / 89),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF502A2A),
                      fontSize: 15,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      decoration: TextDecoration.none,
                      shadows: [
                        Shadow(
                          color: Color(0x40000000),
                          offset: Offset(1, 1),
                          blurRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 5,
                right: 5,
                top: height * (41 / 89),
                height: height * (27 / 89),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF502A2A),
                      fontSize: 20,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      decoration: TextDecoration.none,
                      shadows: [
                        Shadow(
                          color: Color(0x40000000),
                          offset: Offset(1, 1),
                          blurRadius: 1,
                        ),
                      ],
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

class _XiangqiTextButton extends StatefulWidget {
  const _XiangqiTextButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  State<_XiangqiTextButton> createState() => _XiangqiTextButtonState();
}

class _XiangqiTextButtonState extends State<_XiangqiTextButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
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
          child: AspectRatio(
            aspectRatio: 390 / 138,
            child: Stack(
              alignment: const Alignment(0, 0.25),
              children: [
                Positioned.fill(
                  child: Image.asset(
                    '${_xiangqiAsset}home_button.png',
                    fit: BoxFit.fill,
                  ),
                ),
                _XiangqiOutlinedText(
                  text: widget.label,
                  fontSize: 24,
                  fillColor: const Color(0xFFFFE49B),
                  strokeColor: const Color(0xFF5C211B),
                  strokeWidth: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _XiangqiGameScreen extends StatelessWidget {
  const _XiangqiGameScreen({
    required this.engine,
    required this.selectedSquare,
    required this.legalTargets,
    required this.agentName,
    required this.userName,
    required this.agentAvatarUrl,
    required this.userAvatarUrl,
    required this.aiThinking,
    required this.starting,
    required this.timerPaused,
    required this.enabled,
    required this.notice,
    required this.onSquareTap,
    required this.onShowLose,
    required this.onPreviewWin,
    required this.onTimerPauseChanged,
    required this.bannerInMs,
    required this.bannerHoldMs,
    required this.bannerOutMs,
    required this.gamePoints,
  });

  final ChessFamilyEngine engine;
  final int? selectedSquare;
  final Set<int> legalTargets;
  final String agentName;
  final String userName;
  final String? agentAvatarUrl;
  final String? userAvatarUrl;
  final bool aiThinking;
  final bool starting;
  final bool timerPaused;
  final bool enabled;

  /// Something went wrong out of the player's sight — a failed sync or a move
  /// the agent could not complete. Left invisible it just looks like the board
  /// stopped responding.
  final String? notice;
  final ValueChanged<int> onSquareTap;
  // Quitting / restarting mid-game → settle as a loss and show the 失败 screen.
  final Future<void> Function() onShowLose;

  // TODO(games): temporary test hook — 重新开局 jumps straight to the 胜利
  // screen so its layout can be checked without actually winning a round.
  // Restore the onShowLose call below once the result screens are signed off.
  final VoidCallback onPreviewWin;
  final ValueChanged<bool> onTimerPauseChanged;
  // "你的回合" banner timing (ms), from the per-game admin config (read fresh
  // each round from engine_config).
  final int bannerInMs;
  final int bannerHoldMs;
  final int bannerOutMs;
  // Current game points, shown in the top-right coin badge.
  final int? gamePoints;

  @override
  Widget build(BuildContext context) {
    final userTurn = enabled && !engine.isFinished;
    final agentTurn = !engine.isFinished && (engine.isAgentTurn || aiThinking);
    final turnToken =
        '${engine.moveCount}:${engine.isAgentTurn ? 'agent' : 'user'}';
    return Scaffold(
      backgroundColor: const Color(0xFFDCE7F5),
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
                  phase: 0.45,
                  child: Image.asset(
                    '${_xiangqiAsset}game_bg.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // Symmetric avatars / name plates at the same height, with the
              // countdown holder centred between them (design 象棋-游戏,
              // frame 393x852).
              Positioned(
                left: width * (46 / 393),
                top: height * (124 / 852),
                width: width * (66 / 393),
                child: _XiangqiAvatar(
                  frameAsset: '${_xiangqiAsset}game_avatar_frame_user.png',
                  imageUrl: userAvatarUrl,
                  fallback: userName,
                  active: userTurn,
                  glowColor: const Color(0xFF4CE0C1),
                ),
              ),
              Positioned(
                left: width * (281 / 393),
                top: height * (123 / 852),
                width: width * (65 / 393),
                child: _XiangqiAvatar(
                  frameAsset: '${_xiangqiAsset}game_avatar_frame_agent.png',
                  imageUrl: agentAvatarUrl,
                  fallback: agentName,
                  active: agentTurn,
                  glowColor: const Color(0xFFFFD870),
                ),
              ),
              Positioned(
                left: width * (144 / 393),
                top: height * (132 / 852),
                width: width * (105 / 393),
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 4200),
                  scaleAmount: 0.012,
                  translateY: 1.2,
                  phase: 0.22,
                  child: Image.asset(
                    '${_xiangqiAsset}game_timer.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                left: width * (132 / 393),
                top: height * (158 / 852),
                width: width * (130 / 393),
                height: height * (33 / 852),
                child: _XiangqiTurnTimer(
                  token: turnToken,
                  paused:
                      timerPaused ||
                      aiThinking ||
                      engine.isAgentTurn ||
                      engine.isFinished,
                  timeout: _nativeGameTurnTimeout(_nativeXiangqiGameKey),
                  // Ran out of time on the user's turn → auto-open the pause
                  // menu; tapping 继续 resumes with a fresh dial.
                  onTimeout: () => unawaited(_showPause(context)),
                ),
              ),
              Positioned(
                left: width * (8 / 393),
                top: height * (199 / 852),
                width: width * (141 / 393),
                child: _XiangqiNamePlate(
                  asset: '${_xiangqiAsset}game_name_user.png',
                  name: userName,
                  active: userTurn,
                ),
              ),
              Positioned(
                left: width * (243 / 393),
                top: height * (199 / 852),
                width: width * (141 / 393),
                child: _XiangqiNamePlate(
                  asset: '${_xiangqiAsset}game_name_agent.png',
                  name: agentName,
                  active: agentTurn,
                ),
              ),
              Positioned(
                left: width * (14 / 393),
                top: height * (289 / 852),
                width: width * (365 / 393),
                height: height * (381 / 852),
                child: _ChessFamilyBoard(
                  engine: engine,
                  selectedSquare: selectedSquare,
                  legalTargets: legalTargets,
                  onSquareTap: onSquareTap,
                  xiangqiArtworkAsset: '${_xiangqiAsset}game_board.png',
                ),
              ),
              // "你的回合" ribbon at the board's lower-middle, flashing in when
              // the user's turn begins (timing from the per-game admin config).
              Positioned(
                left: 0,
                right: 0,
                top: height * 0.62 - (width * 0.13) / 2,
                height: width * 0.13,
                child: _TurnBanner(
                  userTurn: userTurn,
                  inMs: bannerInMs,
                  holdMs: bannerHoldMs,
                  outMs: bannerOutMs,
                ),
              ),
              if (notice case final text?)
                Positioned(
                  left: width * (26 / 393),
                  right: width * (26 / 393),
                  top: height * (640 / 852),
                  child: _XiangqiNotice(text: text),
                ),
              Positioned(
                left: width * (26 / 393),
                top: height * (684 / 852),
                width: width * (130 / 393),
                child: _XiangqiArtButton(
                  asset: '${_xiangqiAsset}game_btn_exit.png',
                  onTap: () => unawaited(_confirmExit(context)),
                ),
              ),
              Positioned(
                left: width * (168 / 393),
                top: height * (684 / 852),
                width: width * (130 / 393),
                child: _XiangqiArtButton(
                  asset: '${_xiangqiAsset}game_btn_pause.png',
                  onTap: () => unawaited(_showPause(context)),
                ),
              ),
              _NativeGamePointsBadge(points: gamePoints),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    onTimerPauseChanged(true);
    await _showXiangqiModal(
      context,
      title: '退出对局',
      message: '当前棋局还没有结束，退出后本局进度会清空。',
      actions: (dialogContext) => [
        Expanded(
          child: _XiangqiTextButton(
            label: '继续',
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _XiangqiTextButton(
            label: '退出',
            onTap: () {
              Navigator.of(dialogContext).pop();
              unawaited(onShowLose());
            },
          ),
        ),
      ],
    );
    onTimerPauseChanged(false);
  }

  Future<void> _showPause(BuildContext context) async {
    onTimerPauseChanged(true);
    await _showXiangqiModal(
      context,
      title: '游戏暂停',
      message: '要继续当前棋局，还是重新开一盘？',
      actions: (dialogContext) => [
        Expanded(
          child: _XiangqiTextButton(
            label: '继续',
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _XiangqiTextButton(
            label: starting ? '载入中' : '重开',
            enabled: !starting,
            onTap: () {
              Navigator.of(dialogContext).pop();
              onPreviewWin();
            },
          ),
        ),
      ],
    );
    onTimerPauseChanged(false);
  }
}

class _XiangqiNotice extends StatelessWidget {
  const _XiangqiNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFF7A2418).withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFFFFE7C9),
          fontSize: 12,
          height: 1.3,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.none,
        ),
      ),
    ),
  );
}

class _XiangqiAvatar extends StatelessWidget {
  const _XiangqiAvatar({
    required this.frameAsset,
    required this.imageUrl,
    required this.fallback,
    required this.active,
    required this.glowColor,
  });

  final String frameAsset;
  final String? imageUrl;
  final String fallback;
  final bool active;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 100 / 99,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final inner = width * 0.79;
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                width: inner,
                height: inner,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: glowColor.withValues(alpha: 0.32),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ]
                      : const [],
                ),
                child: ClipOval(
                  child: _Avatar(
                    size: inner,
                    label: fallback.trim().isEmpty
                        ? '伴'
                        : fallback.trim().characters.first,
                    imageUrl: imageUrl,
                    gradient: const [Color(0xFFEAF6FF), Color(0xFFD9EDFF)],
                  ),
                ),
              ),
              Positioned.fill(
                child: Image.asset(frameAsset, fit: BoxFit.contain),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: active ? 1 : 0,
                    duration: const Duration(milliseconds: 260),
                    child: _GomokuBreathingMotion(
                      duration: const Duration(milliseconds: 1800),
                      scaleAmount: 0.035,
                      child: Image.asset(
                        '${_xiangqiAsset}game_avatar_glow.png',
                        fit: BoxFit.contain,
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

class _XiangqiNamePlate extends StatelessWidget {
  const _XiangqiNamePlate({
    required this.asset,
    required this.name,
    this.active = false,
  });

  final String asset;
  final String name;
  // True while it is this player's turn — swaps to the lit plate and shows a
  // soft glow halo behind it.
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 141 / 40,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (active)
            Positioned.fill(
              child: IgnorePointer(
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 1800),
                  scaleAmount: 0.04,
                  child: Transform.scale(
                    scale: 1.28,
                    child: Image.asset(
                      '${_xiangqiAsset}game_glow_halo.png',
                      fit: BoxFit.fill,
                    ),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: Image.asset(
              active ? '${_xiangqiAsset}game_name_glow.png' : asset,
              fit: BoxFit.fill,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _XiangqiOutlinedText(
                text: name,
                fontSize: 15,
                fillColor: Colors.white,
                strokeColor: Colors.black,
                strokeWidth: 2.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _XiangqiTurnTimer extends StatefulWidget {
  const _XiangqiTurnTimer({
    required this.token,
    required this.paused,
    required this.timeout,
    this.onTimeout,
  });

  final String token;
  final bool paused;
  final Duration timeout;
  // Fired once when the dial hits 0 while it is the user's turn.
  final VoidCallback? onTimeout;

  @override
  State<_XiangqiTurnTimer> createState() => _XiangqiTurnTimerState();
}

class _XiangqiTurnTimerState extends State<_XiangqiTurnTimer> {
  Timer? _timer;
  late int _remaining;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.timeout.inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || widget.paused || _remaining <= 0) return;
      setState(() => _remaining -= 1);
      if (_remaining == 0 && !_timedOut) {
        _timedOut = true;
        widget.onTimeout?.call();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _XiangqiTurnTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token ||
        oldWidget.timeout != widget.timeout) {
      // New turn → fresh dial.
      _remaining = widget.timeout.inSeconds;
      _timedOut = false;
    } else if (oldWidget.paused && !widget.paused && _timedOut) {
      // Resumed after a timeout (user tapped 继续 on the auto pause menu) →
      // give a fresh turn instead of staying stuck at 0.
      _remaining = widget.timeout.inSeconds;
      _timedOut = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: _XiangqiOutlinedText(
        text: '$_remaining',
        fontSize: 25,
        fillColor: const Color(0xFFFFCE0B),
        strokeColor: const Color(0xFF121212),
        strokeWidth: 2.8,
      ),
    );
  }
}

class _XiangqiArtButton extends StatefulWidget {
  const _XiangqiArtButton({
    required this.asset,
    required this.onTap,
    this.enabled = true,
    this.loading = false,
    this.aspectRatio = 390 / 138,
  });

  final String asset;
  final VoidCallback onTap;
  final bool enabled;
  final bool loading;
  final double aspectRatio;

  @override
  State<_XiangqiArtButton> createState() => _XiangqiArtButtonState();
}

class _XiangqiArtButtonState extends State<_XiangqiArtButton> {
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
                  const CupertinoActivityIndicator(color: Color(0xFFFFF0C5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _XiangqiOutlinedText extends StatelessWidget {
  const _XiangqiOutlinedText({
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

Future<void> _showXiangqiModal(
  BuildContext context, {
  required String title,
  required String message,
  required List<Widget> Function(BuildContext dialogContext) actions,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭',
    barrierColor: Colors.black.withValues(alpha: 0.48),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, _, __) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 44),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 17),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF8E2), Color(0xFFE8D3A9)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF7B4A31), width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.32),
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
                    color: Color(0xCC502A2A),
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

enum _XiangqiResultKind { win, lose }

/// Full-screen xiangqi win / lose result scene (mountain theme), composed from
/// the exported art with a staggered pop-in. Shown at the page level in place
/// of the game so the board / avatars / countdown are torn down (no timer left
/// running behind it). Positions are estimated from the design and easy to
/// nudge — one (cx,cy,wFrac) per piece.
class _XiangqiResultScreen extends StatefulWidget {
  const _XiangqiResultScreen({
    super.key,
    required this.kind,
    required this.pointsDelta,
    required this.onRestart,
    required this.onExit,
  });

  final _XiangqiResultKind kind;

  /// What this round settled for; null while the wallet hasn't loaded, in
  /// which case the number is left off rather than shown wrong.
  final int? pointsDelta;
  final Future<void> Function() onRestart;
  final Future<void> Function() onExit;

  @override
  State<_XiangqiResultScreen> createState() => _XiangqiResultScreenState();
}

class _XiangqiResultScreenState extends State<_XiangqiResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

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
      Image.asset('$_xiangqiAsset$name', fit: BoxFit.fill);

  Widget _piece({
    required double screenW,
    required double screenH,
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
    final width = screenW * wFrac;
    final height = width * aspect;
    final dy = drop
        ? -screenH * 0.10 * (1 - Curves.easeOutCubic.transform(p))
        : 0.0;
    final scale = drop ? 1.0 : (0.7 + 0.3 * eased);
    return Positioned(
      left: screenW * cx - width / 2,
      top: screenH * cy - height / 2 + dy,
      width: width,
      height: height,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(scale: scale, child: child),
      ),
    );
  }

  Widget _scorePlate(String plateAsset) => Stack(
    alignment: Alignment.center,
    children: [
      Positioned.fill(child: _img(plateAsset)),
      Positioned.fill(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  '${_xiangqiAsset}result_score_label.png',
                  height: 28,
                ),
                const SizedBox(width: 2),
                if (widget.pointsDelta != null)
                  _NativeGameScoreDelta(
                    delta: widget.pointsDelta!,
                    fill: const Color(0xFFFDEBC0),
                    stroke: const Color(0xFF77240A),
                    height: 28,
                  ),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  Widget _button({
    required String base,
    required String text,
    required VoidCallback onTap,
  }) => _XiangqiResultButton(base: base, text: text, onTap: onTap);

  @override
  Widget build(BuildContext context) {
    final win = widget.kind == _XiangqiResultKind.win;
    return Scaffold(
      backgroundColor: const Color(0xFFCADCEB),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      '${_xiangqiAsset}game_bg.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  ...win ? _winPieces(w, h) : _losePieces(w, h),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // Positions from the 胜利弹窗 CSS export (frame 393x852).
  List<Widget> _winPieces(double w, double h) => [
    // Blurred confetti/light burst behind the sun.
    _piece(
      screenW: w, screenH: h, cx: 0.5, cy: 0.30, wFrac: 0.9,
      aspect: 1590 / 1179, begin: 0.06, end: 0.42,
      child: _img('result_win_glow.png'),
    ),
    // Sun + red ribbon emblem, at (near) its CSS size, centred (the +15px
    // right offset was what clipped the right tassel; size was fine).
    _piece(
      screenW: w, screenH: h, cx: 0.5, cy: 0.333, wFrac: 1.0,
      aspect: 930 / 1179, begin: 0.12, end: 0.46, drop: true,
      child: _img('result_win_emblem.png'),
    ),
    // "胜利" centred on the ribbon.
    _piece(
      screenW: w, screenH: h, cx: 0.5, cy: 0.365, wFrac: 0.34,
      aspect: 234 / 408, begin: 0.34, end: 0.6,
      child: _img('result_win_title.png'),
    ),
    // 积分 plate (155x51 @ 119,523).
    _piece(
      screenW: w, screenH: h, cx: 0.5, cy: 0.644, wFrac: 0.394,
      aspect: 153 / 465, begin: 0.5, end: 0.72,
      child: _scorePlate('result_score_plate_win.png'),
    ),
    // 退出 (151x49 @ 28,659) / 重开一局 (153x49 @ 212,658).
    _piece(
      screenW: w, screenH: h, cx: 0.263, cy: 0.803, wFrac: 0.384,
      aspect: 147 / 453, begin: 0.62, end: 0.86,
      child: _button(
        base: 'result_btn_exit_win.png',
        text: 'result_txt_exit.png',
        onTap: () => unawaited(widget.onExit()),
      ),
    ),
    _piece(
      screenW: w, screenH: h, cx: 0.734, cy: 0.801, wFrac: 0.389,
      aspect: 147 / 459, begin: 0.68, end: 0.92,
      child: _button(
        base: 'result_btn_again_win.png',
        text: 'result_txt_again.png',
        onTap: () => unawaited(widget.onRestart()),
      ),
    ),
  ];

  // Positions from the 失败弹窗 CSS export (frame 393x852).
  List<Widget> _losePieces(double w, double h) => [
    // Lotus mandala emblem (213x181 @ 100,155).
    _piece(
      screenW: w, screenH: h, cx: 0.525, cy: 0.288, wFrac: 0.542,
      aspect: 543 / 639, begin: 0.12, end: 0.46, drop: true,
      child: _img('result_lose_emblem.png'),
    ),
    // Red ribbon (382x122 @ 6,265), over the emblem's lower half.
    _piece(
      screenW: w, screenH: h, cx: 0.501, cy: 0.383, wFrac: 0.972,
      aspect: 366 / 1146, begin: 0.3, end: 0.56,
      child: _img('result_lose_ribbon.png'),
    ),
    // "失败" centred on the red band. The glyph fill sits at 0.433 of the PNG
    // (shadow pads the bottom), so cy 0.363 lands it on the band centre (~0.357).
    _piece(
      screenW: w, screenH: h, cx: 0.5, cy: 0.363, wFrac: 0.34,
      aspect: 233 / 418, begin: 0.44, end: 0.66,
      child: _img('result_lose_title.png'),
    ),
    // 积分 plate (155x51 @ 119,516).
    _piece(
      screenW: w, screenH: h, cx: 0.5, cy: 0.636, wFrac: 0.394,
      aspect: 153 / 465, begin: 0.56, end: 0.76,
      child: _scorePlate('result_score_plate_lose.png'),
    ),
    // 退出 (151x49 @ 28,652) / 重开一局 (153x49 @ 212,651).
    _piece(
      screenW: w, screenH: h, cx: 0.263, cy: 0.794, wFrac: 0.384,
      aspect: 147 / 453, begin: 0.66, end: 0.88,
      child: _button(
        base: 'result_btn_exit_lose.png',
        text: 'result_txt_exit.png',
        onTap: () => unawaited(widget.onExit()),
      ),
    ),
    _piece(
      screenW: w, screenH: h, cx: 0.734, cy: 0.793, wFrac: 0.389,
      aspect: 147 / 459, begin: 0.72, end: 0.94,
      child: _button(
        base: 'result_btn_again_lose.png',
        text: 'result_txt_again.png',
        onTap: () => unawaited(widget.onRestart()),
      ),
    ),
  ];
}

/// Result-screen button (退出 / 重开一局): textless base art + text overlay,
/// sized by height so both share the same glyph size, with a press-in scale.
class _XiangqiResultButton extends StatefulWidget {
  const _XiangqiResultButton({
    required this.base,
    required this.text,
    required this.onTap,
  });

  final String base;
  final String text;
  final VoidCallback onTap;

  @override
  State<_XiangqiResultButton> createState() => _XiangqiResultButtonState();
}

class _XiangqiResultButtonState extends State<_XiangqiResultButton> {
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
                '$_xiangqiAsset${widget.base}',
                fit: BoxFit.fill,
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment: const Alignment(0, 0.06),
                child: FractionallySizedBox(
                  heightFactor: 0.56,
                  child: Image.asset(
                    '$_xiangqiAsset${widget.text}',
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
