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

class _CheckersGameScreen extends StatelessWidget {
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
    required this.starting,
    required this.timerPaused,
    required this.enabled,
    required this.onTap,
    required this.onRestart,
    required this.onExit,
    required this.onTimerPauseChanged,
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
  final bool starting;
  final bool timerPaused;
  final bool enabled;
  final ValueChanged<int> onTap;
  final Future<void> Function() onRestart;
  final Future<void> Function() onExit;
  final ValueChanged<bool> onTimerPauseChanged;

  @override
  Widget build(BuildContext context) {
    final token = '${engine.moveCount}:${aiThinking ? 'agent' : 'user'}';
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
                    '${_checkersFigmaAsset}bg.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                left: width * (45 / 393),
                top: height * (88 / 852),
                width: width * (148 / 393),
                height: height * (57 / 852),
                child: _CheckersNamePlate(name: userName, avatarOnLeft: true),
              ),
              Positioned(
                left: width * (14 / 393),
                top: height * (71 / 852),
                width: width * (91 / 393),
                child: _CheckersAvatar(
                  name: userName,
                  imageUrl: userAvatarUrl,
                  active: enabled,
                ),
              ),
              Positioned(
                left: width * (200 / 393),
                top: height * (88 / 852),
                width: width * (148 / 393),
                height: height * (57 / 852),
                child: _CheckersNamePlate(name: agentName, avatarOnLeft: false),
              ),
              Positioned(
                left: width * (290 / 393),
                top: height * (68 / 852),
                width: width * (90 / 393),
                child: _CheckersAvatar(
                  name: agentName,
                  imageUrl: agentAvatarUrl,
                  active: aiThinking,
                ),
              ),
              Positioned(
                left: width * (132 / 393),
                top: height * (162 / 852),
                width: width * (117 / 393),
                height: height * (34 / 852),
                child: _CheckersClockPlate(
                  token: token,
                  paused: timerPaused || aiThinking,
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
                  lastMove: lastMove,
                  selected: selected,
                  targets: targets,
                  figmaStyle: true,
                  onTap: onTap,
                ),
              ),
              Positioned(
                left: width * (83 / 393),
                top: height * (690 / 852),
                width: width * (101 / 393),
                height: height * (50 / 852),
                child: _CheckersGameTextButton(
                  label: '退出',
                  onTap: () => unawaited(_confirmExit(context)),
                ),
              ),
              Positioned(
                left: width * (209 / 393),
                top: height * (690 / 852),
                width: width * (101 / 393),
                height: height * (50 / 852),
                child: _CheckersGameTextButton(
                  label: '暂停',
                  accent: true,
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
            unawaited(onExit());
          },
        ),
      ],
    );
    onTimerPauseChanged(false);
  }

  Future<void> _showPause(BuildContext context) async {
    onTimerPauseChanged(true);
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
          label: starting ? '载入中' : '重新开局',
          enabled: !starting,
          onTap: () {
            Navigator.of(dialogContext).pop();
            unawaited(onRestart());
          },
        ),
      ],
    );
    onTimerPauseChanged(false);
  }
}

class _CheckersNamePlate extends StatelessWidget {
  const _CheckersNamePlate({required this.name, required this.avatarOnLeft});

  final String name;
  final bool avatarOnLeft;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: Image.asset(
            '${_checkersFigmaAsset}game_nameplate.png',
            fit: BoxFit.fill,
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            left: avatarOnLeft ? 58 : 10,
            right: avatarOnLeft ? 10 : 58,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              name,
              style: const TextStyle(
                color: Color(0xFFFEE0B6),
                fontSize: 15,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CheckersAvatar extends StatelessWidget {
  const _CheckersAvatar({
    required this.name,
    required this.imageUrl,
    required this.active,
  });

  final String name;
  final String? imageUrl;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.maxWidth;
          return Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                width: size * 0.82,
                height: size * 0.82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: active
                      ? const [
                          BoxShadow(
                            color: Color(0xCCFFD064),
                            blurRadius: 18,
                            spreadRadius: 3,
                          ),
                        ]
                      : const [],
                ),
                child: ClipOval(
                  child: _Avatar(
                    size: size * 0.82,
                    label: name.trim().isEmpty
                        ? '伴'
                        : name.trim().characters.first,
                    imageUrl: imageUrl,
                    gradient: const [Color(0xFFFFE2B5), Color(0xFFE38B36)],
                  ),
                ),
              ),
              Positioned.fill(
                child: Image.asset(
                  '${_checkersFigmaAsset}game_avatar_frame.png',
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

class _CheckersClockPlate extends StatelessWidget {
  const _CheckersClockPlate({required this.token, required this.paused});

  final String token;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: const Alignment(0.28, 0),
      children: [
        Positioned.fill(
          child: Image.asset(
            '${_checkersFigmaAsset}game_timer.png',
            fit: BoxFit.fill,
          ),
        ),
        _CheckersTurnClock(token: token, paused: paused),
      ],
    );
  }
}

class _CheckersTurnClock extends StatefulWidget {
  const _CheckersTurnClock({required this.token, required this.paused});

  final String token;
  final bool paused;

  @override
  State<_CheckersTurnClock> createState() => _CheckersTurnClockState();
}

class _CheckersTurnClockState extends State<_CheckersTurnClock> {
  Timer? _timer;
  int _remaining = 90;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || widget.paused || _remaining <= 0) return;
      setState(() => _remaining -= 1);
    });
  }

  @override
  void didUpdateWidget(covariant _CheckersTurnClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) _remaining = 90;
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
    return Text(
      '$minutes:$seconds',
      style: const TextStyle(
        color: Color(0xFFFEE0B6),
        fontSize: 20,
        fontWeight: FontWeight.w900,
        decoration: TextDecoration.none,
      ),
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

class _CheckersGameTextButton extends StatefulWidget {
  const _CheckersGameTextButton({
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool accent;

  @override
  State<_CheckersGameTextButton> createState() =>
      _CheckersGameTextButtonState();
}

class _CheckersGameTextButtonState extends State<_CheckersGameTextButton> {
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
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 90),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: widget.accent
                  ? const [Color(0xFFFFB857), Color(0xFFD86625)]
                  : const [Color(0xFFC58A67), Color(0xFF86513C)],
            ),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFFFCB78), width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.label,
              style: const TextStyle(
                color: Color(0xFFFFF0D0),
                fontSize: 19,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.none,
                shadows: [
                  Shadow(
                    color: Color(0x77000000),
                    offset: Offset(1, 2),
                    blurRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
  const _CheckersModalButton({
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
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
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
