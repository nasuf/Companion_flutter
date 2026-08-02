part of 'package:companion_flutter/main.dart';

const String _mineFigmaAsset = 'assets/prototype/games/minesweeper-figma/';

/// Shared pill proportions (`game_btn_blank.png` is 472×179 including its glow)
/// so in-game and dialog buttons never stretch differently.
const double _mineButtonAspect = 472 / 179;

/// Playfield bounds inside `game_board_frame.png`, as fractions of the frame.
const double _mineFieldLeft = 49 / 900;
const double _mineFieldTop = 50 / 1059;
const double _mineFieldWidth = 802 / 900;
const double _mineFieldHeight = 962 / 1059;

class _MinesweeperHome extends StatelessWidget {
  const _MinesweeperHome({
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
      backgroundColor: const Color(0xFF9CC7E8),
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
                    '${_mineFigmaAsset}home_bg.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                left: width * (61 / 393),
                top: height * (92 / 852),
                width: width * (273 / 393),
                height: height * (138 / 852),
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 5200),
                  scaleAmount: 0.009,
                  translateY: 1.4,
                  child: Image.asset(
                    '${_mineFigmaAsset}home_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                left: width * (62 / 393),
                top: height * (285 / 852),
                width: width * (271 / 393),
                height: height * (282 / 852),
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 6500),
                  scaleAmount: 0.006,
                  translateY: 1.5,
                  phase: 0.55,
                  child: Image.asset(
                    '${_mineFigmaAsset}home_board.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              if (error != null)
                Positioned(
                  left: width * 0.08,
                  right: width * 0.08,
                  top: height * 0.68,
                  child: _GomokuNotice(text: error!, isError: true),
                ),
              // Height follows the 450×156 artwork so the pills aren't stretched.
              Positioned(
                left: width * (28 / 393),
                top: height * (603 / 852),
                width: width * (150 / 393),
                height: width * (52 / 393),
                child: _MineArtButton(
                  asset: '${_mineFigmaAsset}home_btn_exit.png',
                  enabled: !starting,
                  onTap: onExit,
                ),
              ),
              Positioned(
                left: width * (215 / 393),
                top: height * (603 / 852),
                width: width * (150 / 393),
                height: width * (52 / 393),
                child: _MineArtButton(
                  asset: '${_mineFigmaAsset}home_btn_start.png',
                  enabled: !starting,
                  loading: starting,
                  onTap: () => unawaited(onStart()),
                ),
              ),
              for (var index = 0; index < 4; index += 1)
                Positioned(
                  left: width * (const [9, 103, 201, 299][index] / 393),
                  top: height * (713 / 852),
                  width: width * (85 / 393),
                  height: height * (91 / 852),
                  child: _MineHomeStatCard(
                    label: const ['总对局', '胜利局', '胜率', '时长'][index],
                    value: values[index],
                    icon: const [
                      'icon_total.png',
                      'icon_wins.png',
                      'icon_rate.png',
                      'icon_time.png',
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

String _mineFormatDuration(int seconds) {
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

class _MineHomeStatCard extends StatelessWidget {
  const _MineHomeStatCard({
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
        final height = constraints.maxHeight;
        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                '${_mineFigmaAsset}home_stat_card.png',
                fit: BoxFit.fill,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: height * (13 / 91),
              height: height * (22 / 91),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF603719),
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
              top: height * (36 / 91),
              height: height * (17 / 91),
              child: Center(
                child: Image.asset(
                  '$_mineFigmaAsset$icon',
                  height: height * (17 / 91),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: height * (55 / 91),
              height: height * (28 / 91),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF5D2E0D),
                      fontSize: 20,
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
    );
  }
}

class _MinesweeperGameScreen extends StatelessWidget {
  const _MinesweeperGameScreen({
    required this.engine,
    required this.lastAction,
    required this.agentName,
    required this.userName,
    required this.agentAvatarUrl,
    required this.userAvatarUrl,
    required this.aiThinking,
    required this.starting,
    required this.flagMode,
    required this.enabled,
    required this.onReveal,
    required this.onFlag,
    required this.onFlagModeChanged,
    required this.onRestart,
    required this.onExit,
    required this.onPauseChanged,
  });

  final MinesweeperEngine engine;
  final MinesweeperAction? lastAction;
  final String agentName;
  final String userName;
  final String? agentAvatarUrl;
  final String? userAvatarUrl;
  final bool aiThinking;
  final bool starting;
  final bool flagMode;
  final bool enabled;
  final ValueChanged<int> onReveal;
  final ValueChanged<int> onFlag;
  final ValueChanged<bool> onFlagModeChanged;
  final Future<void> Function() onRestart;
  final Future<void> Function() onExit;
  final ValueChanged<bool> onPauseChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF9CC7E8),
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
                    '${_mineFigmaAsset}game_bg.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                left: width * (17 / 393),
                top: height * (136 / 852),
                width: width * (171 / 393),
                height: height * (65 / 852),
                child: _MineNamePlate(name: userName, avatarOnLeft: true),
              ),
              Positioned(
                left: width * (209 / 393),
                top: height * (136 / 852),
                width: width * (171 / 393),
                height: height * (65 / 852),
                child: _MineNamePlate(name: agentName, avatarOnLeft: false),
              ),
              Positioned(
                left: width * (4 / 393),
                top: height * (120 / 852),
                width: width * (91 / 393),
                child: _MineAvatar(
                  name: userName,
                  imageUrl: userAvatarUrl,
                  active: enabled,
                ),
              ),
              Positioned(
                left: width * (298 / 393),
                top: height * (120 / 852),
                width: width * (91 / 393),
                child: _MineAvatar(
                  name: agentName,
                  imageUrl: agentAvatarUrl,
                  active: aiThinking,
                ),
              ),
              Positioned(
                left: width * (22 / 393),
                top: height * (246 / 852),
                width: width * (350 / 393),
                height: height * (418 / 852),
                child: _MineBoard(
                  engine: engine,
                  lastAction: lastAction,
                  enabled: enabled,
                  flagMode: flagMode,
                  onReveal: onReveal,
                  onFlag: onFlag,
                ),
              ),
              Positioned(
                left: width * (12 / 393),
                top: height * (700 / 852),
                width: width * (120 / 393),
                // Height follows the pill's own aspect so it never stretches.
                height: width * (120 / 393) / _mineButtonAspect,
                child: _MineTextButton(
                  label: '退出',
                  onTap: () => unawaited(_confirmExit(context)),
                ),
              ),
              Positioned(
                left: width * (136.5 / 393),
                top: height * (700 / 852),
                width: width * (120 / 393),
                // Height follows the pill's own aspect so it never stretches.
                height: width * (120 / 393) / _mineButtonAspect,
                child: _MineTextButton(
                  label: '暂停',
                  onTap: () => unawaited(_showPause(context)),
                ),
              ),
              Positioned(
                left: width * (261 / 393),
                top: height * (700 / 852),
                width: width * (120 / 393),
                // Height follows the pill's own aspect so it never stretches.
                height: width * (120 / 393) / _mineButtonAspect,
                child: _MineTextButton(
                  label: flagMode ? '插旗中' : '插旗',
                  active: flagMode,
                  enabled: !engine.isFinished,
                  onTap: () => onFlagModeChanged(!flagMode),
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
      await _showMineModal(
        context,
        title: '退出对局',
        message: '这局雷区还没清完，退出后本局进度会清空。',
        actions: (dialogContext) => [
          _MineModalButton(
            label: '继续',
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
          const SizedBox(height: 6),
          _MineModalButton(
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
      await _showMineModal(
        context,
        title: '游戏暂停',
        message: '要继续当前雷区，还是重新开一局？',
        actions: (dialogContext) => [
          _MineModalButton(
            label: '继续',
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
          const SizedBox(height: 6),
          _MineModalButton(
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

class _MineNamePlate extends StatelessWidget {
  const _MineNamePlate({required this.name, required this.avatarOnLeft});

  final String name;
  final bool avatarOnLeft;

  @override
  Widget build(BuildContext context) {
    final plate = Image.asset(
      '${_mineFigmaAsset}game_nameplate.png',
      fit: BoxFit.fill,
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: avatarOnLeft
              ? Transform.flip(flipX: true, child: plate)
              : plate,
        ),
        // The portrait overlaps roughly half the plate, so the name is inset
        // past it as a fraction of the plate rather than a fixed gap.
        LayoutBuilder(
          builder: (context, constraints) {
            final plateWidth = constraints.maxWidth;
            return Padding(
              padding: EdgeInsets.only(
                left: plateWidth * (avatarOnLeft ? 0.48 : 0.08),
                right: plateWidth * (avatarOnLeft ? 0.08 : 0.48),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  name,
                  maxLines: 1,
                  style: TextStyle(
                    color: const Color(0xFF603719),
                    fontSize: plateWidth * 0.088,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _MineAvatar extends StatelessWidget {
  const _MineAvatar({
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
                width: size * 0.84,
                height: size * 0.84,
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
                    size: size * 0.84,
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
                  '${_mineFigmaAsset}game_avatar_frame.png',
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

/// Board frame plus the live cell grid.
///
/// The frame is drawn at whatever aspect ratio keeps its printed playfield
/// square-celled for the engine's current row/column count, so an admin
/// changing the board size can never leave the grid misaligned in the wood.
class _MineBoard extends StatelessWidget {
  const _MineBoard({
    required this.engine,
    required this.lastAction,
    required this.enabled,
    required this.flagMode,
    required this.onReveal,
    required this.onFlag,
  });

  final MinesweeperEngine engine;
  final MinesweeperAction? lastAction;
  final bool enabled;
  final bool flagMode;
  final ValueChanged<int> onReveal;
  final ValueChanged<int> onFlag;

  @override
  Widget build(BuildContext context) {
    final frameAspect =
        (_mineFieldHeight / _mineFieldWidth) * (engine.columns / engine.rows);
    return Center(
      child: AspectRatio(
        aspectRatio: frameAspect,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final frameWidth = constraints.maxWidth;
            final frameHeight = constraints.maxHeight;
            final cell = frameWidth * _mineFieldWidth / engine.columns;
            return Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    '${_mineFigmaAsset}game_board_frame.png',
                    fit: BoxFit.fill,
                  ),
                ),
                Positioned(
                  left: frameWidth * _mineFieldLeft,
                  top: frameHeight * _mineFieldTop,
                  width: frameWidth * _mineFieldWidth,
                  height: frameHeight * _mineFieldHeight,
                  child: Stack(
                    children: [
                      for (var index = 0; index < engine.cellCount; index += 1)
                        Positioned(
                          left: (index % engine.columns) * cell,
                          top: (index ~/ engine.columns) * cell,
                          width: cell,
                          height: cell,
                          child: _MineCell(
                            engine: engine,
                            index: index,
                            size: cell,
                            highlighted:
                                lastAction?.point.index(engine.columns) ==
                                index,
                            onTap: enabled
                                ? () =>
                                      flagMode ? onFlag(index) : onReveal(index)
                                : null,
                            onLongPress: enabled ? () => onFlag(index) : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MineCell extends StatelessWidget {
  const _MineCell({
    required this.engine,
    required this.index,
    required this.size,
    required this.highlighted,
    required this.onTap,
    required this.onLongPress,
  });

  final MinesweeperEngine engine;
  final int index;
  final double size;
  final bool highlighted;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Digits 1-3 ship as painted tiles; 4-8 reuse the blank tile plus text in
  /// the same palette, since the design set only covers the common cases.
  static const _digitColors = <int, Color>{
    4: Color(0xFF7B5BC4),
    5: Color(0xFFB86A2E),
    6: Color(0xFF1E8E8E),
    7: Color(0xFF4A4A55),
    8: Color(0xFF8A8F9B),
  };

  @override
  Widget build(BuildContext context) {
    final revealed = engine.isRevealed(index);
    final flagged = engine.isFlagged(index);
    final mine = engine.isMine(index);
    String asset;
    int? digit;
    if (!revealed) {
      if (flagged) {
        asset = engine.isFinished && mine
            ? '${_mineFigmaAsset}cell_safe.png'
            : '${_mineFigmaAsset}cell_flag.png';
      } else if (engine.isFinished && mine) {
        asset = '${_mineFigmaAsset}cell_mine.png';
      } else {
        asset = '${_mineFigmaAsset}cell_covered.png';
      }
    } else if (mine) {
      asset = '${_mineFigmaAsset}cell_mine.png';
    } else {
      final adjacent = engine.adjacentMineCount(index);
      if (adjacent >= 1 && adjacent <= 3) {
        asset = '${_mineFigmaAsset}cell_$adjacent.png';
      } else {
        asset = '${_mineFigmaAsset}cell_empty.png';
        if (adjacent >= 4) digit = adjacent;
      }
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedScale(
        scale: highlighted ? 1.06 : 1,
        duration: const Duration(milliseconds: 180),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(child: Image.asset(asset, fit: BoxFit.fill)),
            if (digit != null)
              Text(
                '$digit',
                style: TextStyle(
                  color: _digitColors[digit] ?? const Color(0xFF4A4A55),
                  fontSize: size * 0.52,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                  shadows: const [
                    Shadow(
                      color: Color(0x59FFFFFF),
                      offset: Offset(0, 1),
                      blurRadius: 1,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MineArtButton extends StatefulWidget {
  const _MineArtButton({
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
  State<_MineArtButton> createState() => _MineArtButtonState();
}

class _MineArtButtonState extends State<_MineArtButton> {
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
                const CupertinoActivityIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

/// Green pill in the same style as the exported buttons, but with free text —
/// the exported art has its label baked in.
class _MineTextButton extends StatefulWidget {
  const _MineTextButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.active = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool active;

  @override
  State<_MineTextButton> createState() => _MineTextButtonState();
}

class _MineTextButtonState extends State<_MineTextButton> {
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
          opacity: enabled ? 1 : 0.65,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Same pill artwork as 退出 / 暂停 with the baked label painted
              // out, so all three buttons read as one set.
              final height = constraints.maxHeight;
              return Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: ColorFiltered(
                      colorFilter: widget.active
                          ? const ColorFilter.mode(
                              Color(0x66FFC24D),
                              BlendMode.srcATop,
                            )
                          : const ColorFilter.mode(
                              Colors.transparent,
                              BlendMode.dst,
                            ),
                      child: Image.asset(
                        '${_mineFigmaAsset}game_btn_blank.png',
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: height * 0.30),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _MineButtonLabel(
                        text: widget.label,
                        fontSize: height * 0.44,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// White glyphs with the dark rim the exported button labels use.
class _MineButtonLabel extends StatelessWidget {
  const _MineButtonLabel({required this.text, required this.fontSize});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: fontSize,
      height: 1,
      fontWeight: FontWeight.w900,
      decoration: TextDecoration.none,
    );
    return Stack(
      children: [
        Text(
          text,
          maxLines: 1,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = fontSize * 0.24
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0xFF2E1606),
          ),
        ),
        Text(text, maxLines: 1, style: base.copyWith(color: Colors.white)),
      ],
    );
  }
}

class _MineModalButton extends StatelessWidget {
  const _MineModalButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(148.0, constraints.maxWidth);
        return Center(
          child: SizedBox(
            width: width,
            height: width / _mineButtonAspect,
            child: _MineTextButton(
              label: label,
              enabled: enabled,
              onTap: onTap,
            ),
          ),
        );
      },
    );
  }
}

Future<void> _showMineModal(
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
        padding: const EdgeInsets.symmetric(horizontal: 62),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF3DC), Color(0xFFF0CBA0)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF8B5A2B), width: 3),
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
                  color: Color(0xFF5D2E0D),
                  fontSize: 19,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xCC5D2E0D),
                  fontSize: 12.5,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 14),
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
