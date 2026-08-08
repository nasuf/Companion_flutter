part of 'package:companion_flutter/main.dart';

const String _mergeFigmaAsset = 'assets/prototype/games/merge-figma/';

/// Playfield bounds inside `game_board_frame2.png`, as fractions of the frame
/// — matches the design's 350x350 well at (19,265) on the 393x852 canvas.
const double _mergeFrameAspect = 382 / 367;
const double _mergeFieldLeft = 18.5 / 382;
const double _mergeFieldTop = 9 / 367;
const double _mergeFieldWidth = 350 / 382;

class _MergeHome extends StatelessWidget {
  const _MergeHome({
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
      backgroundColor: const Color(0xFF050912),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          return Stack(
            children: [
              Positioned.fill(
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 13000),
                  scaleAmount: 0.005,
                  child: Image.asset(
                    '${_mergeFigmaAsset}home_bg.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                left: width * (31 / 393),
                top: height * (325 / 852),
                width: width * (331 / 393),
                height: height * (201 / 852),
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 6500),
                  scaleAmount: 0.007,
                  translateY: 1.6,
                  phase: 0.55,
                  child: Image.asset(
                    '${_mergeFigmaAsset}home_board.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              if (error != null)
                Positioned(
                  left: width * 0.08,
                  right: width * 0.08,
                  top: height * 0.77,
                  child: _GomokuNotice(text: error!, isError: true),
                ),
              Positioned(
                left: width * (44 / 393),
                top: height * (563 / 852),
                width: width * (155 / 393),
                height: height * (68 / 852),
                child: _MergeArtButton(
                  asset: '${_mergeFigmaAsset}home_btn_exit.png',
                  enabled: !starting,
                  onTap: onExit,
                ),
              ),
              Positioned(
                left: width * (199 / 393),
                top: height * (560 / 852),
                width: width * (150 / 393),
                height: height * (71 / 852),
                child: _MergeArtButton(
                  asset: '${_mergeFigmaAsset}home_btn_start.png',
                  enabled: !starting,
                  loading: starting,
                  onTap: () => unawaited(onStart()),
                ),
              ),
              for (var index = 0; index < 4; index += 1)
                Positioned(
                  left: width * (const [8, 103, 198, 293][index] / 393),
                  top: height * (699 / 852),
                  width: width * (90 / 393),
                  height: height * (103 / 852),
                  child: _MergeHomeStatCard(
                    label: const ['总对局', '胜利局', '胜率', '时长'][index],
                    value: values[index],
                    icon: const [
                      '${_mergeFigmaAsset}icon_total.png',
                      '${_mergeFigmaAsset}icon_wins.png',
                      '${_mergeFigmaAsset}icon_rate.png',
                      // Merge's kit has no clock art; borrow minesweeper's.
                      '${_mineFigmaAsset}icon_time.png',
                    ][index],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MergeHomeStatCard extends StatelessWidget {
  const _MergeHomeStatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final String icon;

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
                '${_mergeFigmaAsset}home_stat_card.png',
                fit: BoxFit.fill,
              ),
            ),
            Positioned(
              left: width * (10 / 90),
              top: height * (6 / 103),
              width: width * (70 / 90),
              height: height * (8 / 103),
              child: Image.asset(
                '${_mergeFigmaAsset}home_stat_bar.png',
                fit: BoxFit.fill,
              ),
            ),
            // Icon and label travel together and stay centred, so two- and
            // three-character labels both sit in the middle of the card.
            Positioned(
              left: width * (8 / 90),
              right: width * (8 / 90),
              top: height * (20 / 103),
              height: height * (21 / 103),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(icon, width: 14, height: 14),
                    const SizedBox(width: 3),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFFA4A8B8),
                        fontSize: 15,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: height * (49 / 103),
              height: height * (32 / 103),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFFFEFEFD),
                      fontSize: 20,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      decoration: TextDecoration.none,
                      shadows: [
                        Shadow(color: Color(0x80FFBB00), blurRadius: 8),
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

class _MergeGameScreen extends StatelessWidget {
  const _MergeGameScreen({
    required this.engine,
    required this.lastMove,
    required this.agentName,
    required this.userName,
    required this.agentAvatarUrl,
    required this.userAvatarUrl,
    required this.aiThinking,
    required this.starting,
    required this.enabled,
    required this.gamePoints,
    required this.onMove,
    required this.onExit,
    required this.onPauseChanged,
    required this.onAbandon,
    required this.onPreviewWin,
  });

  final NumberMergeEngine engine;
  final NumberMergeMove? lastMove;
  final String agentName;
  final String userName;
  final String? agentAvatarUrl;
  final String? userAvatarUrl;
  final bool aiThinking;
  final bool starting;
  final bool enabled;

  /// Global coin balance for the top-right badge, same as the other games.
  final int? gamePoints;
  final ValueChanged<NumberMergeDirection> onMove;
  final Future<void> Function() onExit;
  final ValueChanged<bool> onPauseChanged;

  /// Giving up mid-board — from 退出 — counts as a loss and shows the lose
  /// screen, which is where the player then picks between leaving and starting
  /// over.
  final VoidCallback onAbandon;

  // TODO(games): temporary test hook — 重新开局 shows the 胜利 screen so its
  // layout can be checked without actually reaching 2048. Restore the
  // onAbandon call below once the result screens are signed off.
  final VoidCallback onPreviewWin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050912),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          // Whose turn it is drives the plate/ring artwork on each side. This
          // reads the engine rather than `enabled` so pausing or resolving a
          // move doesn't hand the highlight to the other player.
          final userTurn =
              !engine.isFinished && engine.turn == NumberMergeActor.user;
          final agentTurn =
              !engine.isFinished && engine.turn == NumberMergeActor.agent;
          return Stack(
            children: [
              Positioned.fill(
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 13000),
                  scaleAmount: 0.005,
                  child: Image.asset(
                    '${_mergeFigmaAsset}game_bg2.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // Nameplates sit under the portraits, which overhang them on the
              // outer edge — 118x46 at (63,133) and (213,133) in the design.
              Positioned(
                left: width * (63 / 393),
                top: height * (133 / 852),
                width: width * (118 / 393),
                height: height * (46 / 852),
                child: _MergeNamePlate(
                  name: userName,
                  avatarOnLeft: true,
                  active: userTurn,
                ),
              ),
              Positioned(
                left: width * (213 / 393),
                top: height * (133 / 852),
                width: width * (118 / 393),
                height: height * (46 / 852),
                child: _MergeNamePlate(
                  name: agentName,
                  avatarOnLeft: false,
                  active: agentTurn,
                ),
              ),
              Positioned(
                left: width * (35 / 393),
                top: height * (127 / 852),
                width: width * (57 / 393),
                height: height * (56 / 852),
                child: _MergeAvatar(
                  name: userName,
                  imageUrl: userAvatarUrl,
                  active: userTurn,
                ),
              ),
              Positioned(
                left: width * (302 / 393),
                top: height * (128 / 852),
                width: width * (57 / 393),
                height: height * (56 / 852),
                child: _MergeAvatar(
                  name: agentName,
                  imageUrl: agentAvatarUrl,
                  active: agentTurn,
                ),
              ),
              Positioned(
                left: width * (0.5 / 393),
                top: height * (256 / 852),
                width: width * (382 / 393),
                height: height * (367 / 852),
                // Frame and grid scale together so the tiles stay inside the
                // artwork on shorter screens.
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _mergeFrameAspect,
                    child: LayoutBuilder(
                      builder: (context, frame) {
                        final frameWidth = frame.maxWidth;
                        final frameHeight = frame.maxHeight;
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Image.asset(
                                  '${_mergeFigmaAsset}game_board_frame2.png',
                                  fit: BoxFit.fill,
                                ),
                              ),
                            ),
                            // The frosted well is drawn by the board painter
                            // itself — see _NumberMergeBoardPainter.paint.
                            Positioned(
                              left: frameWidth * _mergeFieldLeft,
                              top: frameHeight * _mergeFieldTop,
                              width: frameWidth * _mergeFieldWidth,
                              height: frameWidth * _mergeFieldWidth,
                              child: _NumberMergeBoard(
                                engine: engine,
                                lastMove: lastMove,
                                thinking: aiThinking,
                                enabled: enabled,
                                figmaStyle: true,
                                onMove: onMove,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                left: width * (14 / 393),
                top: height * (696 / 852),
                width: width * (101 / 393),
                height: height * (53 / 852),
                child: _MergePlateButton(
                  label: '退出',
                  onTap: () => unawaited(_confirmExit(context)),
                ),
              ),
              Positioned(
                left: width * (135 / 393),
                top: height * (696 / 852),
                width: width * (101 / 393),
                height: height * (53 / 852),
                child: _MergePlateButton(
                  label: '暂停',
                  onTap: () => unawaited(_showPause(context)),
                ),
              ),
              Positioned(
                left: width * (329 / 393),
                top: height * (702 / 852),
                width: width * (40 / 393),
                height: height * (41 / 852),
                child: _MergeGearButton(
                  onTap: () => unawaited(_showRules(context)),
                ),
              ),
              _NativeGamePointsBadge(points: gamePoints),
            ],
          );
        },
      ),
    );
  }

  /// Both sheets hold the idle nudge while they are on screen.
  Future<void> _confirmExit(BuildContext context) async {
    onPauseChanged(true);
    try {
      await _showMergeModal(
        context,
        title: '退出对局',
        message: '这盘数字还没结束，退出后本局进度会清空。',
        actions: (dialogContext) => [
          _MergeModalButton(
            label: '继续',
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
          const SizedBox(height: 9),
          _MergeModalButton(
            label: '退出',
            onTap: () {
              Navigator.of(dialogContext).pop();
              onAbandon();
            },
          ),
        ],
      );
    } finally {
      onPauseChanged(false);
    }
  }

  Future<void> _showRules(BuildContext context) async {
    onPauseChanged(true);
    try {
      await _showGameRulesDialog(
        context,
        gameName: '数字合并',
        rules: const [
          '1、上下左右滑动移动全部数字方块',
          '2、相同数字相撞合并，数值相加',
          '3、合成 2048 即可通关，格子填满无法移动则失败',
        ],
      );
    } finally {
      onPauseChanged(false);
    }
  }

  Future<void> _showPause(BuildContext context) async {
    onPauseChanged(true);
    try {
      await _showMergeModal(
        context,
        title: '游戏暂停',
        message: '要继续当前这盘，还是重新开一局？',
        actions: (dialogContext) => [
          _MergeModalButton(
            label: '继续',
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
          const SizedBox(height: 9),
          _MergeModalButton(
            label: starting ? '载入中' : '重新开局',
            enabled: !starting,
            onTap: () {
              Navigator.of(dialogContext).pop();
              onPreviewWin();
            },
          ),
        ],
      );
    } finally {
      onPauseChanged(false);
    }
  }
}

/// Nameplate. The design ships a lit and an unlit plate; whoever is to move
/// gets the lit one, which is how the board shows whose turn it is.
class _MergeNamePlate extends StatelessWidget {
  const _MergeNamePlate({
    required this.name,
    required this.avatarOnLeft,
    required this.active,
  });

  final String name;
  final bool avatarOnLeft;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final plate = Image.asset(
      '$_mergeFigmaAsset${active ? 'nameplate_active' : 'nameplate_idle'}.png',
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
        // The portrait overhangs the outer edge, so the name is nudged away
        // from that side.
        Padding(
          padding: EdgeInsets.only(
            left: avatarOnLeft ? 26 : 10,
            right: avatarOnLeft ? 10 : 26,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              name,
              maxLines: 1,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.none,
                // The name stays white on both plates. The lit plate is pale,
                // so it gets a shadow to keep the text readable there.
                shadows: active
                    ? const [
                        Shadow(
                          color: Color(0x99000000),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MergeAvatar extends StatelessWidget {
  const _MergeAvatar({
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
          // The exported frame is a solid metal plate, so the portrait sits on
          // top of it rather than behind a cut-out ring.
          final portrait = size * 0.84;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Portrait first, ring on top: the ring art is a hollow bezel.
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                width: portrait,
                height: portrait,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: active
                      ? const [
                          BoxShadow(
                            color: Color(0xCCFF9B3D),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                        ]
                      : const [],
                ),
                child: ClipOval(
                  child: _Avatar(
                    size: portrait,
                    label: name.trim().isEmpty
                        ? '伴'
                        : name.trim().characters.first,
                    imageUrl: imageUrl,
                    gradient: const [Color(0xFF7C8698), Color(0xFF2A3140)],
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Image.asset(
                    '$_mergeFigmaAsset'
                    '${active ? 'avatar_ring_active' : 'avatar_ring_idle'}.png',
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

/// Gear in the bottom-right corner; opens the shared rules sheet.
class _MergeGearButton extends StatelessWidget {
  const _MergeGearButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Image.asset('${_mergeFigmaAsset}btn_gear.png', fit: BoxFit.contain),
  );
}

class _MergeArtButton extends StatefulWidget {
  const _MergeArtButton({
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
  State<_MergeArtButton> createState() => _MergeArtButtonState();
}

class _MergeArtButtonState extends State<_MergeArtButton> {
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
                const CupertinoActivityIndicator(color: Color(0xFFFFD9A0)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MergePlateButton extends StatefulWidget {
  const _MergePlateButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  State<_MergePlateButton> createState() => _MergePlateButtonState();
}

class _MergePlateButtonState extends State<_MergePlateButton> {
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
                  '${_mergeFigmaAsset}game_btn_plate.png',
                  fit: BoxFit.fill,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    color: Color(0xFFE5E5E7),
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

class _MergeModalButton extends StatelessWidget {
  const _MergeModalButton({
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
      height: 46,
      child: _MergePlateButton(label: label, enabled: enabled, onTap: onTap),
    );
  }
}

Future<void> _showMergeModal(
  BuildContext context, {
  required String title,
  required String message,
  required List<Widget> Function(BuildContext dialogContext) actions,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭',
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, _, __) => Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 50),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2A3040), Color(0xFF13171F)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE8892F), width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66FF9B3D),
                blurRadius: 26,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFFFD9A0),
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
                  color: Color(0xCCE5E5E7),
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

enum _MergeResultKind { win, lose }

/// Full-screen 数字合并 win / lose scene, laid out on the 393x852 design canvas
/// and letterboxed so the overlaps hold on any aspect ratio. Pieces stagger in
/// the way the other native games' result screens do.
class _MergeResultScreen extends StatefulWidget {
  const _MergeResultScreen({
    required this.kind,
    required this.pointsDelta,
    required this.onRestart,
    required this.onExit,
  });

  final _MergeResultKind kind;

  /// What this round settled for; null while the wallet hasn't loaded, in which
  /// case the number is simply left off rather than shown wrong.
  final int? pointsDelta;
  final Future<void> Function() onRestart;
  final Future<void> Function() onExit;

  @override
  State<_MergeResultScreen> createState() => _MergeResultScreenState();
}

class _MergeResultScreenState extends State<_MergeResultScreen>
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
      Image.asset('$_mergeFigmaAsset$name', fit: BoxFit.fill);

  /// Places a piece by its design-canvas centre, with the artwork's own aspect
  /// so nothing stretches.
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

  /// The design's Group 66/67: a 176.91x40 band holding the 积分 plate with a
  /// short gradient tail bleeding out of each side.
  Widget _scoreGroup() {
    // Fractions of the 176.91 wide group, taken straight from the CSS boxes
    // (tails at x 0 and x 150, plate at x 25.83; tails sit at y 19 of 40).
    const groupW = 176.91;
    const tailW = 26.91 / groupW;
    const plateL = 25.83 / groupW;
    const plateW = 125.35 / groupW;
    const tailR = 150.0 / groupW;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        final tailH = math.max(1.0, w * tailW * (3 / 84));
        return Stack(
          children: [
            Positioned(
              left: 0,
              top: h * (19 / 40) - tailH / 2,
              width: w * tailW,
              height: tailH,
              child: Image.asset(
                '${_mergeFigmaAsset}result_score_line_l.png',
                fit: BoxFit.fill,
              ),
            ),
            Positioned(
              left: w * tailR,
              top: h * (19 / 40) - tailH / 2,
              width: w * tailW,
              height: tailH,
              child: Image.asset(
                '${_mergeFigmaAsset}result_score_line_r.png',
                fit: BoxFit.fill,
              ),
            ),
            Positioned(
              left: w * plateL,
              top: 0,
              width: w * plateW,
              height: h * (37.29 / 40),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(child: _img('result_score_plate.png')),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              '${_mergeFigmaAsset}result_score_label.png',
                              height: 22,
                            ),
                            const SizedBox(width: 6),
                            if (widget.pointsDelta != null)
                              _NativeGameScoreDelta(
                                delta: widget.pointsDelta!,
                                fill: const Color(0xFFFFFFFF),
                                stroke: const Color(0xFF000000),
                                height: 22,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final win = widget.kind == _MergeResultKind.win;
    return Scaffold(
      backgroundColor: const Color(0xFF050912),
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
                  // The design softens the backdrop so the emblem reads.
                  Positioned.fill(
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Image.asset(
                        '${_mergeFigmaAsset}game_bg2.jpg',
                        fit: BoxFit.cover,
                      ),
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

  // 2048-胜利 (canvas 393x852).
  List<Widget> _winPieces() => [
    // Bloom behind the medallion (the design blurs a copy of the same art).
    _piece(
      cx: 0.5318,
      cy: 0.2732,
      wFrac: 0.630,
      aspect: 1,
      begin: 0.04,
      end: 0.40,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: _img('result_win_emblem.png'),
      ),
    ),
    // Sun medallion (234x234 @ centre, top 118), drops in.
    _piece(
      cx: 0.5013,
      cy: 0.2732,
      wFrac: 0.625,
      aspect: 1,
      begin: 0.12,
      end: 0.46,
      drop: true,
      child: _img('result_win_emblem.png'),
    ),
    // Red ribbon (632x135 @ centre+12.5, top 208).
    _piece(
      cx: 0.4989,
      cy: 0.3234,
      wFrac: 0.952,
      aspect: 405 / 1179,
      begin: 0.32,
      end: 0.58,
      child: _img('result_win_banner.png'),
    ),
    // 胜利 wordmark on the ribbon, centred 9.5px below the ribbon per the CSS
    // (ribbon 275.5, title 285). Only the width is taken from the design
    // screenshot instead of the CSS box, which renders the glyphs ~27% large.
    _piece(
      cx: 0.5,
      cy: 285 / 852,
      wFrac: 0.312,
      aspect: 221 / 391,
      begin: 0.44,
      end: 0.68,
      child: _img('result_win_title.png'),
    ),
    // 积分 group (176.91x40 @ centre, top 512).
    _piece(
      cx: 0.4999,
      cy: 0.6244,
      wFrac: 176.91 / 393,
      aspect: 40 / 176.91,
      begin: 0.56,
      end: 0.76,
      child: _scoreGroup(),
    ),
    _piece(
      cx: 0.2672,
      cy: 0.7758,
      wFrac: 0.3562,
      aspect: 150 / 420,
      begin: 0.66,
      end: 0.88,
      child: _MergeResultButton(
        plate: 'result_btn_exit.png',
        text: 'result_txt_exit.png',
        textWidthFrac: 0.30,
        onTap: () => unawaited(widget.onExit()),
      ),
    ),
    _piece(
      cx: 0.7328,
      cy: 0.7752,
      wFrac: 0.3562,
      aspect: 147 / 420,
      begin: 0.72,
      end: 0.94,
      child: _MergeResultButton(
        plate: 'result_btn_again.png',
        text: 'result_txt_again.png',
        textWidthFrac: 0.56,
        onTap: () => unawaited(widget.onRestart()),
      ),
    ),
  ];

  // 2048-失败 (canvas 393x852).
  List<Widget> _losePieces() => [
    _piece(
      cx: 0.4946,
      cy: 0.2659,
      wFrac: 0.972,
      aspect: 633 / 1179,
      begin: 0.04,
      end: 0.40,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: _img('result_lose_banner.png'),
      ),
    ),
    // Sun + trailing ribbon (449x211 @ -11, 121), drops in.
    _piece(
      cx: 0.4946,
      cy: 0.2659,
      wFrac: 0.972,
      aspect: 633 / 1179,
      begin: 0.12,
      end: 0.46,
      drop: true,
      child: _img('result_lose_banner.png'),
    ),
    // 失败 wordmark (164x99 @ centre, top 337).
    _piece(
      cx: 0.4987,
      cy: 0.4536,
      wFrac: 0.4173,
      aspect: 186 / 376,
      begin: 0.40,
      end: 0.66,
      child: _img('result_lose_title.png'),
    ),
    // 积分 group (176.91x40 @ centre, top 511).
    _piece(
      cx: 0.4999,
      cy: 0.6232,
      wFrac: 176.91 / 393,
      aspect: 40 / 176.91,
      begin: 0.56,
      end: 0.76,
      child: _scoreGroup(),
    ),
    _piece(
      cx: 0.2672,
      cy: 0.7758,
      wFrac: 0.3562,
      aspect: 150 / 420,
      begin: 0.66,
      end: 0.88,
      child: _MergeResultButton(
        plate: 'result_btn_exit.png',
        text: 'result_txt_exit.png',
        textWidthFrac: 0.30,
        onTap: () => unawaited(widget.onExit()),
      ),
    ),
    _piece(
      cx: 0.7328,
      cy: 0.7752,
      wFrac: 0.3562,
      aspect: 147 / 420,
      begin: 0.72,
      end: 0.94,
      child: _MergeResultButton(
        plate: 'result_btn_again.png',
        text: 'result_txt_again.png',
        textWidthFrac: 0.56,
        onTap: () => unawaited(widget.onRestart()),
      ),
    ),
  ];
}

/// Result-screen button: art plate with its baked wordmark laid over it.
class _MergeResultButton extends StatefulWidget {
  const _MergeResultButton({
    required this.plate,
    required this.text,
    required this.textWidthFrac,
    required this.onTap,
  });

  final String plate;
  final String text;
  final double textWidthFrac;
  final VoidCallback onTap;

  @override
  State<_MergeResultButton> createState() => _MergeResultButtonState();
}

class _MergeResultButtonState extends State<_MergeResultButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 90),
        child: LayoutBuilder(
          builder: (context, box) => Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Image.asset(
                  '$_mergeFigmaAsset${widget.plate}',
                  fit: BoxFit.fill,
                ),
              ),
              Image.asset(
                '$_mergeFigmaAsset${widget.text}',
                width: box.maxWidth * widget.textWidthFrac,
                fit: BoxFit.contain,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
