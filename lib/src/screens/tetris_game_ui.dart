part of 'package:companion_flutter/main.dart';

const String _tetrisFigmaAsset = 'assets/prototype/games/tetris-figma/';

/// The round buttons are drawn as a 3D disc with a base beneath, so the lit
/// face sits 4.6% of the artwork's height above its geometric centre. Labels
/// are lifted by twice that as bottom padding to land on the face.
const double _tetrisButtonFaceLift = 0.092;

class _TetrisHome extends StatelessWidget {
  const _TetrisHome({
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
    final values = ['$total', '$wins', '$rate%', _mineFormatDuration(seconds)];
    return Scaffold(
      backgroundColor: const Color(0xFF1B0B33),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          return Stack(
            children: [
              Positioned.fill(
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 11000),
                  scaleAmount: 0.005,
                  child: Image.asset(
                    '${_tetrisFigmaAsset}home_bg.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                left: width * (26 / 393),
                top: height * (147 / 852),
                width: width * (340 / 393),
                height: height * (90 / 852),
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 5200),
                  scaleAmount: 0.011,
                  translateY: 1.6,
                  child: Image.asset(
                    '${_tetrisFigmaAsset}home_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                left: width * (68 / 393),
                top: height * (270 / 852),
                width: width * (257 / 393),
                height: height * (216 / 852),
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 6500),
                  scaleAmount: 0.007,
                  translateY: 1.8,
                  phase: 0.55,
                  child: Image.asset(
                    '${_tetrisFigmaAsset}home_board.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              if (error != null)
                Positioned(
                  left: width * 0.08,
                  right: width * 0.08,
                  top: height * 0.75,
                  child: _GomokuNotice(text: error!, isError: true),
                ),
              Positioned(
                left: width * (77 / 393),
                top: height * (519 / 852),
                width: width * (86 / 393),
                height: height * (98 / 852),
                child: _TetrisArtButton(
                  asset: '${_tetrisFigmaAsset}home_btn_exit.png',
                  label: '退出\n游戏',
                  enabled: !starting,
                  onTap: onExit,
                ),
              ),
              Positioned(
                left: width * (230 / 393),
                top: height * (519 / 852),
                width: width * (87 / 393),
                height: height * (98 / 852),
                child: _TetrisArtButton(
                  asset: '${_tetrisFigmaAsset}home_btn_start.png',
                  label: '开始\n游戏',
                  enabled: !starting,
                  loading: starting,
                  onTap: () => unawaited(onStart()),
                ),
              ),
              for (var index = 0; index < 4; index += 1)
                Positioned(
                  left: width * (const [15, 109, 203, 297][index] / 393),
                  top: height * (667 / 852),
                  width: width * (80 / 393),
                  height: height * (99 / 852),
                  child: _TetrisHomeStatCard(
                    label: const ['总对局', '胜利局', '胜率', '时长'][index],
                    value: values[index],
                    cyan: index < 2,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TetrisHomeStatCard extends StatelessWidget {
  const _TetrisHomeStatCard({
    required this.label,
    required this.value,
    required this.cyan,
  });

  final String label;
  final String value;
  final bool cyan;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                cyan
                    ? '${_tetrisFigmaAsset}home_stat_cyan.png'
                    : '${_tetrisFigmaAsset}home_stat_pink.png',
                fit: BoxFit.fill,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: height * (22 / 99),
              height: height * (26 / 99),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
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
              left: 0,
              right: 0,
              top: height * (55 / 99),
              height: height * (30 / 99),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: const Color(0xFFFEFEFD),
                      fontSize: 20,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      decoration: TextDecoration.none,
                      shadows: [
                        Shadow(
                          color: cyan
                              ? const Color(0xCC00FBFF)
                              : const Color(0xCCFF7FC5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TetrisGameScreen extends StatelessWidget {
  const _TetrisGameScreen({
    required this.engine,
    required this.agentName,
    required this.userName,
    required this.agentAvatarUrl,
    required this.userAvatarUrl,
    required this.canControl,
    required this.starting,
    required this.onMove,
    required this.onRotate,
    required this.onHold,
    required this.onHardDrop,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onRestart,
    required this.onExit,
    required this.onPauseChanged,
  });

  final TetrisDuelEngine engine;
  final String agentName;
  final String userName;
  final String? agentAvatarUrl;
  final String? userAvatarUrl;
  final bool canControl;
  final bool starting;
  final ValueChanged<int> onMove;
  final VoidCallback onRotate;
  final VoidCallback onHold;
  final VoidCallback onHardDrop;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final Future<void> Function() onRestart;
  final Future<void> Function() onExit;
  final ValueChanged<bool> onPauseChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B0B33),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          return Stack(
            children: [
              Positioned.fill(
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 11000),
                  scaleAmount: 0.005,
                  child: Image.asset(
                    '${_tetrisFigmaAsset}game_bg.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                left: width * (10 / 393),
                top: height * (122 / 852),
                width: width * (170 / 393),
                height: height * (62 / 852),
                child: _TetrisNamePlate(name: userName, avatarOnLeft: true),
              ),
              Positioned(
                left: width * (213 / 393),
                top: height * (122 / 852),
                width: width * (170 / 393),
                height: height * (62 / 852),
                child: _TetrisNamePlate(name: agentName, avatarOnLeft: false),
              ),
              Positioned(
                left: width * (16 / 393),
                top: height * (128 / 852),
                width: width * (50 / 393),
                child: _TetrisAvatar(
                  name: userName,
                  imageUrl: userAvatarUrl,
                  active: canControl,
                  accent: const Color(0xFF00FBFF),
                ),
              ),
              Positioned(
                left: width * (326 / 393),
                top: height * (128 / 852),
                width: width * (50 / 393),
                child: _TetrisAvatar(
                  name: agentName,
                  imageUrl: agentAvatarUrl,
                  active: !engine.isFinished,
                  accent: const Color(0xFFFF7FC5),
                ),
              ),
              Positioned(
                left: width * (44 / 393),
                top: height * (219 / 852),
                width: width * (113 / 393),
                height: height * (43 / 852),
                child: _TetrisScorePlate(
                  asset: '${_tetrisFigmaAsset}game_score_user.png',
                  score: engine.user.score,
                ),
              ),
              Positioned(
                left: width * (236 / 393),
                top: height * (219 / 852),
                width: width * (113 / 393),
                height: height * (43 / 852),
                child: _TetrisScorePlate(
                  asset: '${_tetrisFigmaAsset}game_score_agent.png',
                  score: engine.agent.score,
                ),
              ),
              Positioned(
                left: width * (157 / 393),
                top: height * (219 / 852),
                width: width * (79 / 393),
                height: height * (43 / 852),
                child: _TetrisClock(engine: engine),
              ),
              Positioned(
                left: width * (14 / 393),
                top: height * (273 / 852),
                width: width * (173 / 393),
                height: height * (333 / 852),
                child: _TetrisNeonPanel(
                  border: const Color(0xFFFDF0F0),
                  glow: const Color(0x9900FBFF),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: canControl ? onRotate : null,
                    onPanStart: canControl ? onPanStart : null,
                    onPanUpdate: canControl ? onPanUpdate : null,
                    onPanEnd: canControl ? onPanEnd : null,
                    child: CustomPaint(
                      painter: _TetrisBoardPainter(
                        board: engine.user,
                        accent: const Color(0xFF00FBFF),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: width * (206 / 393),
                top: height * (273 / 852),
                width: width * (173 / 393),
                height: height * (333 / 852),
                child: _TetrisNeonPanel(
                  border: const Color(0xFFFFF476),
                  glow: const Color(0x99FF3F0A),
                  child: CustomPaint(
                    painter: _TetrisBoardPainter(
                      board: engine.agent,
                      accent: const Color(0xFFFFB347),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: width * (33 / 393),
                top: height * (662 / 852),
                width: width * (50 / 393),
                height: width * (50 / 393),
                child: _TetrisIconButton(
                  asset: '${_tetrisFigmaAsset}btn_left.png',
                  enabled: canControl,
                  onTap: () => onMove(-1),
                ),
              ),
              Positioned(
                left: width * (116 / 393),
                top: height * (662 / 852),
                width: width * (50 / 393),
                height: width * (50 / 393),
                child: _TetrisIconButton(
                  asset: '${_tetrisFigmaAsset}btn_right.png',
                  enabled: canControl,
                  onTap: () => onMove(1),
                ),
              ),
              Positioned(
                left: width * (232 / 393),
                top: height * (658 / 852),
                width: width * (50 / 393),
                height: width * (57 / 393),
                child: _TetrisIconButton(
                  asset: '${_tetrisFigmaAsset}btn_rotate.png',
                  label: '旋转',
                  enabled: canControl,
                  onTap: onRotate,
                  // The 4-button layout has no dedicated hold slot.
                  onLongPress: onHold,
                ),
              ),
              Positioned(
                left: width * (303 / 393),
                top: height * (658 / 852),
                width: width * (50 / 393),
                height: width * (57 / 393),
                child: _TetrisIconButton(
                  asset: '${_tetrisFigmaAsset}btn_drop.png',
                  label: '速降',
                  enabled: canControl,
                  onTap: onHardDrop,
                ),
              ),
              Positioned(
                left: width * (105 / 393),
                top: height * (768 / 852),
                width: width * (86 / 393),
                height: height * (38 / 852),
                child: _TetrisPlateButton(
                  label: '退出',
                  onTap: () => unawaited(_confirmExit(context)),
                ),
              ),
              Positioned(
                left: width * (202 / 393),
                top: height * (768 / 852),
                width: width * (86 / 393),
                height: height * (38 / 852),
                child: _TetrisPlateButton(
                  label: '暂停',
                  onTap: () => unawaited(_showPause(context)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Both sheets freeze the duel clock for as long as they are on screen.
  Future<void> _confirmExit(BuildContext context) async {
    onPauseChanged(true);
    try {
      await _showTetrisModal(
        context,
        title: '退出对局',
        message: '这局还没跑完，退出后本局进度会清空。',
        actions: (dialogContext) => [
          _TetrisModalButton(
            label: '继续',
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
          const SizedBox(height: 9),
          _TetrisModalButton(
            label: '退出',
            onTap: () {
              Navigator.of(dialogContext).pop();
              unawaited(onExit());
            },
          ),
        ],
      );
    } finally {
      onPauseChanged(false);
    }
  }

  Future<void> _showPause(BuildContext context) async {
    onPauseChanged(true);
    try {
      await _showTetrisModal(
        context,
        title: '游戏暂停',
        message: '要继续当前这局，还是重新开一局？',
        actions: (dialogContext) => [
          _TetrisModalButton(
            label: '继续',
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
          const SizedBox(height: 9),
          _TetrisModalButton(
            label: starting ? '载入中' : '重新开局',
            enabled: !starting,
            onTap: () {
              Navigator.of(dialogContext).pop();
              unawaited(onRestart());
            },
          ),
        ],
      );
    } finally {
      onPauseChanged(false);
    }
  }
}

/// Duel countdown; turns warm once the last ten seconds start.
class _TetrisClock extends StatelessWidget {
  const _TetrisClock({required this.engine});

  final TetrisDuelEngine engine;

  @override
  Widget build(BuildContext context) {
    final remaining = engine.remainingSeconds;
    final urgent = remaining <= 10 && !engine.isFinished;
    final accent = urgent ? const Color(0xFFFF7FC5) : const Color(0xFF00FBFF);
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1020).withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: accent.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 12),
            ],
          ),
          child: Text(
            '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}',
            style: TextStyle(
              color: accent,
              fontSize: 18,
              height: 1,
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _TetrisNeonPanel extends StatelessWidget {
  const _TetrisNeonPanel({
    required this.border,
    required this.glow,
    required this.child,
  });

  final Color border;
  final Color glow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF232130),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: border, width: 3),
        boxShadow: [BoxShadow(color: glow, blurRadius: 14, spreadRadius: 1)],
      ),
      padding: const EdgeInsets.all(5),
      child: ClipRRect(borderRadius: BorderRadius.circular(16), child: child),
    );
  }
}

class _TetrisNamePlate extends StatelessWidget {
  const _TetrisNamePlate({required this.name, required this.avatarOnLeft});

  final String name;
  final bool avatarOnLeft;

  @override
  Widget build(BuildContext context) {
    final plate = Image.asset(
      '${_tetrisFigmaAsset}game_nameplate.png',
      fit: BoxFit.fill,
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: avatarOnLeft
              ? plate
              : Transform.flip(flipX: true, child: plate),
        ),
        Padding(
          padding: EdgeInsets.only(
            left: avatarOnLeft ? 58 : 12,
            right: avatarOnLeft ? 12 : 58,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
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

class _TetrisAvatar extends StatelessWidget {
  const _TetrisAvatar({
    required this.name,
    required this.imageUrl,
    required this.active,
    required this.accent,
  });

  final String name;
  final String? imageUrl;
  final bool active;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.maxWidth;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent, width: 2),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.75),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ]
                  : const [],
            ),
            child: ClipOval(
              child: _Avatar(
                size: size,
                label: name.trim().isEmpty ? '伴' : name.trim().characters.first,
                imageUrl: imageUrl,
                gradient: const [Color(0xFF8E7BFF), Color(0xFF3B2A73)],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TetrisScorePlate extends StatelessWidget {
  const _TetrisScorePlate({required this.asset, required this.score});

  final String asset;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: Image.asset(asset, fit: BoxFit.fill)),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(left: 42, right: 10, top: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$score',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TetrisIconButton extends StatefulWidget {
  const _TetrisIconButton({
    required this.asset,
    required this.enabled,
    required this.onTap,
    this.label,
    this.onLongPress,
  });

  final String asset;
  final bool enabled;
  final VoidCallback onTap;
  final String? label;
  final VoidCallback? onLongPress;

  @override
  State<_TetrisIconButton> createState() => _TetrisIconButtonState();
}

class _TetrisIconButtonState extends State<_TetrisIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: widget.enabled
          ? () => setState(() => _pressed = false)
          : null,
      onTapUp: widget.enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap();
            }
          : null,
      onLongPress: widget.enabled ? widget.onLongPress : null,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration: const Duration(milliseconds: 90),
        child: Opacity(
          opacity: widget.enabled ? 1 : 0.45,
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(widget.asset, fit: BoxFit.contain),
                ),
                if (widget.label != null)
                  Positioned.fill(
                    // The art has a 3D base under the face, so its lit top sits
                    // above the image centre; nudge the label onto it.
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: constraints.maxHeight * _tetrisButtonFaceLift,
                      ),
                      child: Center(
                        child: Text(
                          widget.label!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            decoration: TextDecoration.none,
                            shadows: [
                              Shadow(
                                color: Color(0xB3000000),
                                offset: Offset(0, 1),
                                blurRadius: 3,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TetrisArtButton extends StatefulWidget {
  const _TetrisArtButton({
    required this.asset,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.loading = false,
  });

  final String asset;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool loading;

  @override
  State<_TetrisArtButton> createState() => _TetrisArtButtonState();
}

class _TetrisArtButtonState extends State<_TetrisArtButton> {
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
        scale: _pressed ? 0.95 : 1,
        duration: const Duration(milliseconds: 90),
        child: Opacity(
          opacity: enabled ? 1 : 0.7,
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(widget.asset, fit: BoxFit.contain),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: constraints.maxHeight * _tetrisButtonFaceLift,
                    ),
                    child: Center(
                      child: widget.loading
                          ? const CupertinoActivityIndicator(
                              color: Colors.white,
                            )
                          : Text(
                              widget.label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                height: 1.15,
                                fontWeight: FontWeight.w900,
                                decoration: TextDecoration.none,
                                shadows: [
                                  Shadow(
                                    color: Color(0xB3000000),
                                    offset: Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TetrisPlateButton extends StatefulWidget {
  const _TetrisPlateButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  State<_TetrisPlateButton> createState() => _TetrisPlateButtonState();
}

class _TetrisPlateButtonState extends State<_TetrisPlateButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: widget.enabled
          ? () => setState(() => _pressed = false)
          : null,
      onTapUp: widget.enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1,
        duration: const Duration(milliseconds: 90),
        child: Opacity(
          opacity: widget.enabled ? 1 : 0.6,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Image.asset(
                  '${_tetrisFigmaAsset}game_btn_plate.png',
                  fit: BoxFit.fill,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
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

class _TetrisModalButton extends StatelessWidget {
  const _TetrisModalButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: _TetrisPlateButton(label: label, enabled: enabled, onTap: onTap),
    );
  }
}

Future<void> _showTetrisModal(
  BuildContext context, {
  required String title,
  required String message,
  required List<Widget> Function(BuildContext dialogContext) actions,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭',
    barrierColor: Colors.black.withValues(alpha: 0.58),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, _, __) => Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 50),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3A2364), Color(0xFF1D1033)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF7DE7FF), width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x8000FBFF),
                blurRadius: 26,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
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
                  color: Color(0xCCFFFFFF),
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
