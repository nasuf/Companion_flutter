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

class _MinesweeperGameScreen extends StatefulWidget {
  const _MinesweeperGameScreen({
    required this.engine,
    required this.lastAction,
    required this.agentName,
    required this.userName,
    required this.agentAvatarUrl,
    required this.userAvatarUrl,
    required this.aiThinking,
    required this.enabled,
    required this.turnToken,
    required this.onReveal,
    required this.onFlag,
    required this.onShowLose,
    required this.onPauseChanged,
    required this.gamePoints,
  });

  final MinesweeperEngine engine;
  final MinesweeperAction? lastAction;
  final String agentName;
  final String userName;
  final String? agentAvatarUrl;
  final String? userAvatarUrl;
  final bool aiThinking;
  final bool enabled;
  final String turnToken;
  final ValueChanged<int> onReveal;
  final ValueChanged<int> onFlag;
  // Quitting or restarting mid-game → 失败.
  final Future<void> Function() onShowLose;
  // Holds/releases the page-level idle gate while a sheet / rules popup is up.
  final ValueChanged<bool> onPauseChanged;
  final int? gamePoints;

  @override
  State<_MinesweeperGameScreen> createState() => _MinesweeperGameScreenState();
}

class _MinesweeperGameScreenState extends State<_MinesweeperGameScreen> {
  @override
  Widget build(BuildContext context) {
    final userActive = widget.enabled;
    final agentActive = widget.aiThinking;
    // The points badge is pinned below the status bar (safe-area top), so the
    // nameplate header must drop by the same inset to keep the design's gap
    // between them — otherwise the badge slides down onto the avatars.
    final topInset = MediaQuery.paddingOf(context).top;
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
                    '${_mineFigmaAsset}game_bg2.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // Two nameplates (design 扫雷-游戏, frame 393x852). No countdown —
              // the active player just gets a soft glow behind card + avatar.
              ..._playerBlock(
                width,
                height,
                topInset: topInset,
                isUser: true,
                name: widget.userName,
                imageUrl: widget.userAvatarUrl,
                active: userActive,
              ),
              ..._playerBlock(
                width,
                height,
                topInset: topInset,
                isUser: false,
                name: widget.agentName,
                imageUrl: widget.agentAvatarUrl,
                active: agentActive,
              ),
              Positioned(
                left: width * (22 / 393),
                top: height * (246 / 852),
                width: width * (350 / 393),
                height: height * (418 / 852),
                child: _MineBoard(
                  engine: widget.engine,
                  lastAction: widget.lastAction,
                  enabled: widget.enabled,
                  flagMode: false,
                  onReveal: widget.onReveal,
                  onFlag: widget.onFlag,
                ),
              ),
              Positioned(
                left: width * (17 / 393),
                top: height * (735 / 852),
                width: width * (120 / 393),
                height: width * (120 / 393) * (42 / 120),
                child: _MineArtButton(
                  asset: '${_mineFigmaAsset}game_btn_exit2.png',
                  onTap: () => unawaited(_confirmExit(context)),
                ),
              ),
              Positioned(
                left: width * (141 / 393),
                top: height * (735 / 852),
                width: width * (120 / 393),
                height: width * (120 / 393) * (42 / 120),
                child: _MineArtButton(
                  asset: '${_mineFigmaAsset}game_btn_pause2.png',
                  onTap: () => unawaited(_showPause(context)),
                ),
              ),
              // Gear → rules popup (like 五子棋, blurred backdrop). Opening it
              // holds the idle nudge; closing resumes.
              Positioned(
                left: width * (331 / 393),
                top: height * (735 / 852),
                width: width * (40 / 393),
                height: width * (40 / 393) * (41 / 40),
                child: _MineArtButton(
                  asset: '${_mineFigmaAsset}game_gear.png',
                  onTap: () => unawaited(_showRules(context)),
                ),
              ),
              _NativeGamePointsBadge(points: widget.gamePoints),
              // Invisible 45s idle watcher — no countdown dial, but if the user
              // sits idle it auto-opens the pause menu. Positioned (zero-size)
              // so it never becomes the Stack's sizing child (a non-positioned
              // child would collapse the loosely-constrained Stack to 0x0).
              Positioned(
                left: 0,
                top: 0,
                width: 0,
                height: 0,
                child: _MineIdleWatcher(
                  active: userActive,
                  token: widget.turnToken,
                  onTimeout: () => _handleUserIdleTimeout(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Nameplate whose colour tracks whose turn it is — exactly like 五子棋:
  // the active player gets the WHITE plate + white avatar ring, the waiting
  // player gets the GOLD plate. The two exported plates are colour-per-state
  // (white = avatar-left, gold = avatar-right), so we pick the plate by state
  // and horizontally mirror it when the baked coin needs to sit on this
  // player's side (user = left, agent = right). The real avatar + name are
  // drawn upright on top, so the mirror never flips the portrait or the text.
  List<Widget> _playerBlock(
    double width,
    double height, {
    required double topInset,
    required bool isUser,
    required String name,
    required String? imageUrl,
    required bool active,
  }) {
    // active → white plate (native coin on the LEFT); inactive → gold plate
    // (native coin on the RIGHT).
    final bool white = active;
    final String plate = white ? 'game_plate_active' : 'game_plate_inactive';
    final bool nativeCoinLeft = white;
    // Flip the plate when its native coin side differs from this player's side.
    final bool flip = nativeCoinLeft != isUser;

    // Plate rect in design space (393x852 frame). Top corners, symmetric.
    final double pL = isUser ? 28 : 215;
    const double pT = 100;
    const double pW = 150;
    final double imgAspect = white ? 149 / 395 : 150 / 393;

    final double left = width * (pL / 393);
    final double top = topInset + height * (pT / 852);
    final double w = width * (pW / 393);
    final double h = w * imgAspect;

    // Coin centre as a fraction of the (pre-flip) art, then mirror if flipped.
    final double nativeCx = white ? 0.203 : 0.814;
    final double avCx = flip ? 1 - nativeCx : nativeCx;
    final double avCy = white ? 0.51 : 0.547;
    // Portrait must be large enough to fully cover the plate's baked coin
    // (~0.36w) so its cream frame never peeks around the real avatar.
    final double avD = w * 0.42;
    // Dedicated coin ring drawn over the portrait: white glow (Home-v2_8 1) on
    // this player's turn, gold (Home-v2_8 2) while waiting. It has the soft
    // halo the flat baked ring lacks; its opaque band frames the portrait and
    // hides the baked ring underneath.
    final double ringD = w * 0.52;
    // Name sits on the coin's opposite side — fixed per player, not per state.
    final double nmCx = isUser ? 0.66 : 0.34;
    const double nmCy = 0.50;
    final double nmW = w * 0.56;
    final double nmH = h * 0.55;

    final double avLeft = left + avCx * w - avD / 2;
    final double avTop = top + avCy * h - avD / 2;
    final double nmLeft = left + nmCx * w - nmW / 2;
    final double nmTop = top + nmCy * h - nmH / 2;

    return [
      Positioned(
        left: left,
        top: top,
        width: w,
        height: h,
        child: IgnorePointer(
          child: Transform.flip(
            flipX: flip,
            child: Image.asset('$_mineFigmaAsset$plate.png', fit: BoxFit.fill),
          ),
        ),
      ),
      Positioned(
        left: avLeft,
        top: avTop,
        width: avD,
        height: avD,
        // Raw portrait clipped to a circle — no hairline border, so it fills
        // the ring's opening edge-to-edge (the ring art supplies the frame).
        child: ClipOval(
          child: AgentAvatarImage(
            imageUrl: imageUrl,
            width: avD,
            height: avD,
            fit: BoxFit.cover,
            fallback: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFFE2B5), Color(0xFFE38B36)],
                ),
              ),
              child: Center(
                child: Text(
                  name.trim().isEmpty ? '伴' : name.trim().characters.first,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: avD * 0.42,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        left: left + avCx * w - ringD / 2,
        top: top + avCy * h - ringD / 2,
        width: ringD,
        height: ringD,
        child: IgnorePointer(
          child: Image.asset(
            '$_mineFigmaAsset${white ? 'game_ring_active' : 'game_ring_inactive'}.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
      Positioned(
        left: nmLeft,
        top: nmTop,
        width: nmW,
        height: nmH,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              name,
              maxLines: 1,
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
    ];
  }

  /// Both sheets hold the idle nudge while they are on screen.
  Future<void> _confirmExit(BuildContext context) async {
    widget.onPauseChanged(true);
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
          const SizedBox(width: 10),
          _MineModalButton(
            label: '退出',
            onTap: () {
              Navigator.of(dialogContext).pop();
              // Quitting mid-game → 失败; the 失败 screen's 退出 then leaves.
              unawaited(widget.onShowLose());
            },
          ),
        ],
      );
    } finally {
      widget.onPauseChanged(false);
    }
  }

  void _handleUserIdleTimeout(BuildContext context) {
    if (!mounted || widget.engine.isFinished) return;
    unawaited(_showPause(context));
  }

  Future<void> _showPause(BuildContext context) async {
    widget.onPauseChanged(true);
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
          const SizedBox(width: 10),
          _MineModalButton(
            label: '重新开局',
            onTap: () {
              Navigator.of(dialogContext).pop();
              // Restarting mid-game forfeits the round → 失败; the 失败 screen's
              // 重来一局 then starts the new game.
              unawaited(widget.onShowLose());
            },
          ),
        ],
      );
    } finally {
      widget.onPauseChanged(false);
    }
  }

  // Rules popup (shared card, like 五子棋). Holds the idle nudge while open (no
  // pause dialog) and resumes when it closes.
  Future<void> _showRules(BuildContext context) async {
    widget.onPauseChanged(true);
    try {
      await _showGameRulesDialog(
        context,
        gameName: '扫雷',
        rules: const [
          '1、点开数字提示周边地雷数量',
          '2、点开空白格自动连片展开',
          '3、长按格子插旗标记地雷',
          '4、误触地雷直接结束，插满所有雷即通关',
        ],
      );
    } finally {
      widget.onPauseChanged(false);
    }
  }
}

/// Invisible per-turn idle watcher: minesweeper has no countdown dial, but if
/// the user leaves it idle for 45s while it is their turn, [onTimeout] fires
/// (auto-opening the pause menu). Restarts each turn; stops when inactive.
class _MineIdleWatcher extends StatefulWidget {
  const _MineIdleWatcher({
    required this.active,
    required this.token,
    required this.onTimeout,
  });

  final bool active;
  final String token;
  final VoidCallback onTimeout;

  @override
  State<_MineIdleWatcher> createState() => _MineIdleWatcherState();
}

class _MineIdleWatcherState extends State<_MineIdleWatcher> {
  static const _timeout = Duration(seconds: 45);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _MineIdleWatcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active || widget.token != oldWidget.token) {
      _sync();
    }
  }

  void _sync() {
    _timer?.cancel();
    if (widget.active) {
      _timer = Timer(_timeout, () {
        if (mounted && widget.active) widget.onTimeout();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Coin avatar: peach ring frame over the portrait (no countdown dial).
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
  const _MineTextButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_MineTextButton> createState() => _MineTextButtonState();
}

class _MineTextButtonState extends State<_MineTextButton> {
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
        child: Opacity(
          opacity: 1,
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
                      colorFilter: const ColorFilter.mode(
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
  const _MineModalButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Two buttons share a row (like 五子棋) — each takes half the width and its
    // height follows the pill art's aspect, so the pair stays compact.
    return Expanded(
      child: AspectRatio(
        aspectRatio: _mineButtonAspect,
        child: _MineTextButton(label: label, onTap: onTap),
      ),
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
              Row(children: actions(dialogContext)),
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

enum _MinesweeperResultKind { win, lose }

/// Full-screen 扫雷 win / lose result scene, composed from the exported art with
/// a staggered pop-in, shown at the page level in place of the game. Positions
/// letterboxed onto the 393x852 design canvas so overlaps hold on any aspect.
class _MinesweeperResultScreen extends StatefulWidget {
  const _MinesweeperResultScreen({
    super.key,
    required this.kind,
    required this.onRestart,
    required this.onExit,
  });

  final _MinesweeperResultKind kind;
  final Future<void> Function() onRestart;
  final Future<void> Function() onExit;

  @override
  State<_MinesweeperResultScreen> createState() =>
      _MinesweeperResultScreenState();
}

class _MinesweeperResultScreenState extends State<_MinesweeperResultScreen>
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
      Image.asset('$_mineFigmaAsset$name', fit: BoxFit.fill);

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

  // 积分 plate (积分 label + number over it): 胜利 gains +3, 失败 loses -3.
  Widget _scorePlate() {
    final win = widget.kind == _MinesweeperResultKind.win;
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(child: _img('result_score_plate.png')),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    '${_mineFigmaAsset}result_score_label.png',
                    height: 24,
                  ),
                  const SizedBox(width: 5),
                  Image.asset(
                    '$_mineFigmaAsset${win ? 'result_num' : 'result_lose_num'}.png',
                    height: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _exitButton() => _MinesweeperResultButton(
    text: 'result_txt_exit.png',
    onTap: () => unawaited(widget.onExit()),
  );

  Widget _againButton() => _MinesweeperResultButton(
    text: 'result_txt_again.png',
    onTap: () => unawaited(widget.onRestart()),
  );

  @override
  Widget build(BuildContext context) {
    final win = widget.kind == _MinesweeperResultKind.win;
    return Scaffold(
      backgroundColor: const Color(0xFF9CC7E8),
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
                  Positioned.fill(
                    child: Image.asset(
                      '${_mineFigmaAsset}game_bg2.png',
                      fit: BoxFit.cover,
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

  // 扫雷-胜利 layout (frame 393x852).
  List<Widget> _winPieces() => [
    // Light burst behind the banner/title.
    _piece(
      cx: 0.501, cy: 0.467, wFrac: 0.448,
      aspect: 276 / 528, begin: 0.04, end: 0.4,
      child: _img('result_win_glow.png'),
    ),
    // Sun / shield medallion (272x244 @ 61,129), drops in.
    _piece(
      cx: 0.501, cy: 0.295, wFrac: 0.692,
      aspect: 732 / 816, begin: 0.12, end: 0.46, drop: true,
      child: _img('result_win_emblem.png'),
    ),
    // Red banner (358x120 @ 18,306).
    _piece(
      cx: 0.501, cy: 0.430, wFrac: 0.911,
      aspect: 360 / 1074, begin: 0.32, end: 0.58,
      child: _img('result_win_banner.png'),
    ),
    // 胜利 title on the banner.
    _piece(
      cx: 0.5, cy: 0.415, wFrac: 0.26,
      aspect: 234 / 408, begin: 0.44, end: 0.68,
      child: _img('result_win_title.png'),
    ),
    // 积分 plate (131x41 @ 131,548).
    _piece(
      cx: 0.501, cy: 0.667, wFrac: 0.333,
      aspect: 123 / 393, begin: 0.56, end: 0.76,
      child: _scorePlate(),
    ),
    _piece(
      cx: 0.278, cy: 0.782, wFrac: 0.364,
      aspect: 174 / 429, begin: 0.66, end: 0.88,
      child: _exitButton(),
    ),
    _piece(
      cx: 0.724, cy: 0.782, wFrac: 0.364,
      aspect: 174 / 429, begin: 0.72, end: 0.94,
      child: _againButton(),
    ),
  ];

  // 扫雷-失败 layout.
  List<Widget> _losePieces() => [
    // Tall light beam behind the emblem.
    _piece(
      cx: 0.501, cy: 0.341, wFrac: 0.448,
      aspect: 927 / 528, begin: 0.04, end: 0.4,
      child: _img('result_lose_glow.png'),
    ),
    // Sun medallion (160x158 @ 117,184), drops in.
    _piece(
      cx: 0.501, cy: 0.309, wFrac: 0.407,
      aspect: 474 / 480, begin: 0.12, end: 0.46, drop: true,
      child: _img('result_lose_emblem.png'),
    ),
    // Red banner (369x118 @ centre, top 342).
    _piece(
      cx: 0.5, cy: 0.471, wFrac: 0.939,
      aspect: 354 / 1107, begin: 0.32, end: 0.58,
      child: _img('result_lose_banner.png'),
    ),
    // 失败 title on the banner.
    _piece(
      cx: 0.5, cy: 0.455, wFrac: 0.26,
      aspect: 233 / 418, begin: 0.44, end: 0.68,
      child: _img('result_lose_title.png'),
    ),
    // 积分 plate (131x41 @ 131,544).
    _piece(
      cx: 0.501, cy: 0.662, wFrac: 0.333,
      aspect: 123 / 393, begin: 0.56, end: 0.76,
      child: _scorePlate(),
    ),
    _piece(
      cx: 0.278, cy: 0.777, wFrac: 0.364,
      aspect: 174 / 429, begin: 0.66, end: 0.88,
      child: _exitButton(),
    ),
    _piece(
      cx: 0.724, cy: 0.777, wFrac: 0.364,
      aspect: 174 / 429, begin: 0.72, end: 0.94,
      child: _againButton(),
    ),
  ];
}

/// Result-screen button (退出 / 重来一局): textless base art + text overlay.
class _MinesweeperResultButton extends StatefulWidget {
  const _MinesweeperResultButton({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  State<_MinesweeperResultButton> createState() =>
      _MinesweeperResultButtonState();
}

class _MinesweeperResultButtonState extends State<_MinesweeperResultButton> {
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
                '${_mineFigmaAsset}result_btn_exit.png',
                fit: BoxFit.fill,
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment: const Alignment(0, -0.04),
                child: FractionallySizedBox(
                  heightFactor: 0.4,
                  child: Image.asset(
                    '$_mineFigmaAsset${widget.text}',
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
