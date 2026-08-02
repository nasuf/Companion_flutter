part of 'package:companion_flutter/main.dart';

const String _mergeFigmaAsset = 'assets/prototype/games/merge-figma/';

/// Playfield bounds inside `game_board_frame.png`, as fractions of the frame.
const double _mergeFrameAspect = 382 / 367;
const double _mergeFieldLeft = 19 / 382;
const double _mergeFieldTop = 12 / 367;
const double _mergeFieldWidth = 344 / 382;

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
    required this.onMove,
    required this.onRestart,
    required this.onExit,
    required this.onPauseChanged,
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
  final ValueChanged<NumberMergeDirection> onMove;
  final Future<void> Function() onRestart;
  final Future<void> Function() onExit;
  final ValueChanged<bool> onPauseChanged;

  @override
  Widget build(BuildContext context) {
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
                    '${_mergeFigmaAsset}game_bg.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                left: width * (47 / 393),
                top: height * (153 / 852),
                width: width * (148 / 393),
                height: height * (58 / 852),
                child: _MergeNamePlate(name: userName, avatarOnLeft: true),
              ),
              Positioned(
                left: width * (194 / 393),
                top: height * (153 / 852),
                width: width * (149 / 393),
                height: height * (58 / 852),
                child: _MergeNamePlate(name: agentName, avatarOnLeft: false),
              ),
              Positioned(
                left: width * (3 / 393),
                top: height * (135 / 852),
                width: width * (93 / 393),
                child: _MergeAvatar(
                  name: userName,
                  imageUrl: userAvatarUrl,
                  active: enabled,
                ),
              ),
              Positioned(
                left: width * (297 / 393),
                top: height * (135 / 852),
                width: width * (93 / 393),
                child: _MergeAvatar(
                  name: agentName,
                  imageUrl: agentAvatarUrl,
                  active: aiThinking,
                ),
              ),
              Positioned(
                left: width * (4 / 393),
                top: height * (284 / 852),
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
                                  '${_mergeFigmaAsset}game_board_frame.png',
                                  fit: BoxFit.fill,
                                ),
                              ),
                            ),
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
                left: width * (75 / 393),
                top: height * (696 / 852),
                width: width * (101 / 393),
                height: height * (53 / 852),
                child: _MergePlateButton(
                  label: '退出',
                  onTap: () => unawaited(_confirmExit(context)),
                ),
              ),
              Positioned(
                left: width * (217 / 393),
                top: height * (696 / 852),
                width: width * (101 / 393),
                height: height * (53 / 852),
                child: _MergePlateButton(
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

class _MergeNamePlate extends StatelessWidget {
  const _MergeNamePlate({required this.name, required this.avatarOnLeft});

  final String name;
  final bool avatarOnLeft;

  @override
  Widget build(BuildContext context) {
    final plate = Image.asset(
      '${_mergeFigmaAsset}game_nameplate.png',
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
            left: avatarOnLeft ? 44 : 12,
            right: avatarOnLeft ? 12 : 44,
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
          final portrait = size * 0.78;
          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Image.asset(
                  '${_mergeFigmaAsset}game_avatar_frame.png',
                  fit: BoxFit.contain,
                ),
              ),
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
                            blurRadius: 18,
                            spreadRadius: 2,
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
            ],
          );
        },
      ),
    );
  }
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
