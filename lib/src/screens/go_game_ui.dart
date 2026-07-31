part of 'package:companion_flutter/main.dart';

const String _goAsset = 'assets/prototype/games/go/';

class _GoHome extends StatelessWidget {
  const _GoHome({
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

class _GoGameScreen extends StatelessWidget {
  const _GoGameScreen({
    required this.engine,
    required this.lastMove,
    required this.agentName,
    required this.userName,
    required this.agentAvatarUrl,
    required this.userAvatarUrl,
    required this.aiThinking,
    required this.resolving,
    required this.starting,
    required this.timerPaused,
    required this.enabled,
    required this.onTap,
    required this.onRestart,
    required this.onExit,
    required this.onTimerPauseChanged,
  });

  final GoEngine engine;
  final GoMove? lastMove;
  final String agentName;
  final String userName;
  final String? agentAvatarUrl;
  final String? userAvatarUrl;
  final bool aiThinking;
  final bool resolving;
  final bool starting;
  final bool timerPaused;
  final bool enabled;
  final ValueChanged<int> onTap;
  final Future<void> Function() onRestart;
  final Future<void> Function() onExit;
  final ValueChanged<bool> onTimerPauseChanged;

  @override
  Widget build(BuildContext context) {
    final userTurn = enabled && !engine.isFinished;
    final agentTurn = !engine.isFinished && (engine.turn == GoActor.agent);
    final token = '${engine.moveCount}:${engine.turn.name}';
    return Scaffold(
      backgroundColor: const Color(0xFF28150E),
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
                    '${_goAsset}game_bg.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                left: width * (17 / 393),
                top: height * (62 / 852),
                width: width * (194 / 393),
                child: _GoPlayerCard(
                  asset: '${_goAsset}game_player_user.png',
                  name: userName,
                  imageUrl: userAvatarUrl,
                  active: userTurn,
                  clockToken: token,
                  paused: timerPaused || !userTurn,
                  glowColor: const Color(0xFFCF6D52),
                ),
              ),
              Positioned(
                left: width * (181 / 393),
                top: height * (160 / 852),
                width: width * (194 / 393),
                child: _GoPlayerCard(
                  asset: '${_goAsset}game_player_agent.png',
                  name: agentName,
                  imageUrl: agentAvatarUrl,
                  active: agentTurn,
                  clockToken: token,
                  paused: timerPaused || !agentTurn || aiThinking,
                  glowColor: const Color(0xFF5B91C6),
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
                  lastMove: lastMove,
                  thinking: aiThinking,
                  enabled: enabled,
                  artwork: true,
                  onTap: onTap,
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
          );
        },
      ),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    onTimerPauseChanged(true);
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
              unawaited(onExit());
            },
          ),
        ),
      ],
    );
    onTimerPauseChanged(false);
  }

  Future<void> _showPause(BuildContext context) async {
    onTimerPauseChanged(true);
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
            label: starting ? '载入中' : '重开',
            enabled: !starting,
            onTap: () {
              Navigator.of(dialogContext).pop();
              unawaited(onRestart());
            },
          ),
        ),
      ],
    );
    onTimerPauseChanged(false);
  }
}

class _GoPlayerCard extends StatelessWidget {
  const _GoPlayerCard({
    required this.asset,
    required this.name,
    required this.imageUrl,
    required this.active,
    required this.clockToken,
    required this.paused,
    required this.glowColor,
  });

  final String asset;
  final String name;
  final String? imageUrl;
  final bool active;
  final String clockToken;
  final bool paused;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 194 / 85,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(width * 0.05),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: glowColor.withValues(alpha: 0.72),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ]
                  : const [],
            ),
            child: Stack(
              children: [
                Positioned.fill(child: Image.asset(asset, fit: BoxFit.fill)),
                Positioned(
                  left: width * (17 / 194),
                  top: height * (16 / 85),
                  width: width * (51 / 194),
                  height: width * (51 / 194),
                  child: ClipOval(
                    child: _Avatar(
                      size: width * (51 / 194),
                      label: name.trim().isEmpty
                          ? '伴'
                          : name.trim().characters.first,
                      imageUrl: imageUrl,
                      gradient: const [Color(0xFFE8D4B7), Color(0xFFB99671)],
                    ),
                  ),
                ),
                Positioned(
                  left: width * (54 / 194),
                  top: height * (20 / 85),
                  width: width * (130 / 194),
                  height: height * (23 / 85),
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
                Positioned(
                  left: width * (120 / 194),
                  top: height * (48 / 85),
                  width: width * (74 / 194),
                  height: height * (24 / 85),
                  child: _GoTurnClock(
                    token: clockToken,
                    active: active,
                    paused: paused,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GoTurnClock extends StatefulWidget {
  const _GoTurnClock({
    required this.token,
    required this.active,
    required this.paused,
  });

  final String token;
  final bool active;
  final bool paused;

  @override
  State<_GoTurnClock> createState() => _GoTurnClockState();
}

class _GoTurnClockState extends State<_GoTurnClock> {
  Timer? _timer;
  int _remaining = 90;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !widget.active || widget.paused || _remaining <= 0) {
        return;
      }
      setState(() => _remaining -= 1);
    });
  }

  @override
  void didUpdateWidget(covariant _GoTurnClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token && widget.active) {
      _remaining = 90;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _remaining ~/ 60;
    final seconds = (_remaining % 60).toString().padLeft(2, '0');
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        '$minutes:$seconds',
        style: const TextStyle(
          color: Color(0xFF593016),
          fontSize: 15,
          height: 1,
          fontWeight: FontWeight.w900,
          decoration: TextDecoration.none,
        ),
      ),
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
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
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
