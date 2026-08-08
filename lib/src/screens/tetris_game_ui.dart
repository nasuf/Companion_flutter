part of 'package:companion_flutter/main.dart';

const String _tetrisFigmaAsset = 'assets/prototype/games/tetris-figma/';

/// The buttons are drawn as a 3D disc/pill with a base beneath, so the lit
/// face centre sits ~3.3% of the artwork's height above its geometric centre
/// (measured off the art). Content is lifted by twice that as bottom padding
/// to land centred on the face.
const double _tetrisButtonFaceLift = 0.066;

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
    required this.gamePoints,
    required this.onMove,
    required this.onRotate,
    required this.onHold,
    required this.onSoftDropStart,
    required this.onSoftDropEnd,
    required this.onHardDrop,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onShowLose,
    required this.onShowWin,
    required this.onPauseChanged,
  });

  final TetrisDuelEngine engine;
  final String agentName;
  final String userName;
  final String? agentAvatarUrl;
  final String? userAvatarUrl;
  final bool canControl;
  final int? gamePoints;
  final ValueChanged<int> onMove;
  final VoidCallback onRotate;
  final VoidCallback onHold;
  final VoidCallback onSoftDropStart;
  final VoidCallback onSoftDropEnd;
  final VoidCallback onHardDrop;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final Future<void> Function() onShowLose;
  final Future<void> Function() onShowWin;
  final ValueChanged<bool> onPauseChanged;

  static const _userCyan = Color(0xFF28FDFE);
  static const _agentPink = Color(0xFFFD9BED);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF120726),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          double x(double v) => width * (v / 393);
          double y(double v) => height * (v / 852);
          return Stack(
            children: [
              Positioned.fill(
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 11000),
                  scaleAmount: 0.005,
                  child: Image.asset(
                    '${_tetrisFigmaAsset}game_bg2.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // Nameplates (avatar socket baked into the plate art).
              Positioned(
                left: x(10),
                top: y(122),
                width: x(170),
                height: y(62),
                child: _TetrisNamePlate(
                  name: userName,
                  imageUrl: userAvatarUrl,
                  avatarOnLeft: true,
                ),
              ),
              Positioned(
                left: x(213),
                top: y(122),
                width: x(170),
                height: y(62),
                child: _TetrisNamePlate(
                  name: agentName,
                  imageUrl: agentAvatarUrl,
                  avatarOnLeft: false,
                ),
              ),
              // Score badges + centre clock ring.
              Positioned(
                left: x(41),
                top: y(206),
                width: x(120),
                height: y(44),
                child: _TetrisScoreBadge(
                  labelAsset: '${_tetrisFigmaAsset}score_label_user.png',
                  score: engine.user.score,
                  frameColor: const Color(0xFF25A8EE),
                  borderColor: const Color(0xFF8BEBFF),
                  innerColor: const Color(0xFF1F3767),
                  numberColor: _userCyan,
                ),
              ),
              Positioned(
                left: x(233),
                top: y(206),
                width: x(120),
                height: y(44),
                child: _TetrisScoreBadge(
                  labelAsset: '${_tetrisFigmaAsset}score_label_agent.png',
                  score: engine.agent.score,
                  frameColor: const Color(0xFFC84CF2),
                  borderColor: const Color(0xFFDC95FD),
                  innerColor: const Color(0xFF2C145B),
                  numberColor: _agentPink,
                ),
              ),
              Positioned(
                left: x(167),
                top: y(200),
                width: x(60),
                height: x(60),
                child: _TetrisClockRing(engine: engine),
              ),
              // NEXT previews above each board.
              Positioned(
                left: x(69),
                top: y(266),
                width: x(56),
                height: x(52),
                child: _TetrisNextPreview(
                  type: engine.user.next.isEmpty
                      ? null
                      : engine.user.next.first,
                  accent: _userCyan,
                ),
              ),
              Positioned(
                left: x(268),
                top: y(266),
                width: x(56),
                height: x(52),
                child: _TetrisNextPreview(
                  type: engine.agent.next.isEmpty
                      ? null
                      : engine.agent.next.first,
                  accent: _agentPink,
                ),
              ),
              // Play fields.
              Positioned(
                left: x(14),
                top: y(323),
                width: x(170),
                height: y(322),
                child: _TetrisNeonPanel(
                  border: const Color(0xFF8BEBFF),
                  glow: const Color(0x99FF7A2A),
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
                left: x(210),
                top: y(323),
                width: x(170),
                height: y(322),
                child: _TetrisNeonPanel(
                  border: const Color(0xFFDC95FD),
                  glow: const Color(0x9900FBFF),
                  child: CustomPaint(
                    painter: _TetrisBoardPainter(
                      board: engine.agent,
                      accent: const Color(0xFFDC95FD),
                    ),
                  ),
                ),
              ),
              // Controls: ← → rotate 速降.
              Positioned(
                left: x(33),
                top: y(692),
                width: x(59),
                height: x(60),
                child: _TetrisIconButton(
                  asset: '${_tetrisFigmaAsset}btn_left.png',
                  enabled: canControl,
                  onTap: () => onMove(-1),
                ),
              ),
              Positioned(
                left: x(119),
                top: y(692),
                width: x(59),
                height: x(60),
                child: _TetrisIconButton(
                  asset: '${_tetrisFigmaAsset}btn_right.png',
                  enabled: canControl,
                  onTap: () => onMove(1),
                ),
              ),
              Positioned(
                left: x(244),
                top: y(688),
                width: x(60),
                height: x(68),
                child: _TetrisIconButton(
                  asset: '${_tetrisFigmaAsset}btn_rotate_base.png',
                  iconAsset: '${_tetrisFigmaAsset}icon_rotate.png',
                  enabled: canControl,
                  onTap: onRotate,
                  // No dedicated hold slot in the 4-button layout.
                  onLongPress: onHold,
                ),
              ),
              Positioned(
                left: x(318),
                top: y(688),
                width: x(60),
                height: x(68),
                child: _TetrisIconButton(
                  asset: '${_tetrisFigmaAsset}btn_drop_base.png',
                  iconAsset: '${_tetrisFigmaAsset}icon_drop.png',
                  enabled: canControl,
                  // 速降 accelerates the fall while held (spec 4).
                  onPressStart: onSoftDropStart,
                  onPressEnd: onSoftDropEnd,
                ),
              ),
              // Bottom bar: 退出 / 暂停 pills + gear (rules).
              Positioned(
                left: x(123),
                top: y(803),
                width: x(74),
                height: y(34),
                child: _TetrisPillButton(
                  label: '退出',
                  onTap: () => unawaited(_confirmExit(context)),
                ),
              ),
              Positioned(
                left: x(202),
                top: y(803),
                width: x(74),
                height: y(34),
                child: _TetrisPillButton(
                  label: '暂停',
                  onTap: () => unawaited(_showPause(context)),
                ),
              ),
              Positioned(
                left: x(328),
                top: y(799),
                width: x(40),
                height: x(41),
                child: _TetrisIconButton(
                  asset: '${_tetrisFigmaAsset}btn_gear.png',
                  enabled: true,
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

  /// The dialogs / rules sheet freeze the duel clock while they are up.
  Future<void> _confirmExit(BuildContext context) async {
    onPauseChanged(true);
    try {
      await _showTetrisModal(
        context,
        title: '退出对局',
        message: '这局还没跑完，中途退出会判负。',
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
              // Quitting mid-duel → 失败; the 失败 page's 退出 then leaves.
              unawaited(onShowLose());
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
            label: '重新开局',
            onTap: () {
              Navigator.of(dialogContext).pop();
              // TEMP (spec 3): preview the 胜利 page. Restarting mid-duel would
              // normally forfeit (onShowLose); swap back when done.
              unawaited(onShowWin());
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
      // Shared 五子棋-style rules card (blurred backdrop), consistent with the
      // other games.
      await _showGameRulesDialog(
        context,
        gameName: '方块竞速',
        rules: const ['1、左右移动、下移、旋转方块', '2、横向填满整行直接消除得分', '3、方块堆叠触顶游戏结束'],
      );
    } finally {
      onPauseChanged(false);
    }
  }
}

/// Duel countdown inside the neon ring; turns warm in the last ten seconds.
class _TetrisClockRing extends StatelessWidget {
  const _TetrisClockRing({required this.engine});

  final TetrisDuelEngine engine;

  @override
  Widget build(BuildContext context) {
    final remaining = engine.remainingSeconds;
    final urgent = remaining <= 10 && !engine.isFinished;
    final accent = urgent ? const Color(0xFFFF7FC5) : const Color(0xFF28FDFE);
    final text =
        '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}';
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Image.asset(
                '${_tetrisFigmaAsset}clock_ring.png',
                fit: BoxFit.contain,
              ),
            ),
            // Digits sit in a 27x12 box at (17,22) of the 60x60 ring, i.e.
            // just above the ring's centre rather than on it.
            Positioned(
              left: w * (17 / 60),
              top: w * (22 / 60),
              width: w * (27 / 60),
              height: w * (12 / 60),
              child: CustomPaint(
                painter: _SevenSegClockPainter(text: text, color: accent),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Seven-segment ("electronic number") renderer for the duel clock.
class _SevenSegClockPainter extends CustomPainter {
  _SevenSegClockPainter({required this.text, required this.color});

  final String text;
  final Color color;

  // Segments per digit, order [a, b, c, d, e, f, g].
  static const Map<String, List<int>> _segs = {
    '0': [1, 1, 1, 1, 1, 1, 0],
    '1': [0, 1, 1, 0, 0, 0, 0],
    '2': [1, 1, 0, 1, 1, 0, 1],
    '3': [1, 1, 1, 1, 0, 0, 1],
    '4': [0, 1, 1, 0, 0, 1, 1],
    '5': [1, 0, 1, 1, 0, 1, 1],
    '6': [1, 0, 1, 1, 1, 1, 1],
    '7': [1, 1, 1, 0, 0, 0, 0],
    '8': [1, 1, 1, 1, 1, 1, 1],
    '9': [1, 1, 1, 1, 0, 1, 1],
  };

  double _charWidth(String c, double dh) => c == ':' ? dh * 0.30 : dh * 0.56;

  @override
  void paint(Canvas canvas, Size size) {
    var dh = size.height;
    const gapFactor = 0.16;
    double total(double h) {
      var w = 0.0;
      for (var i = 0; i < text.length; i++) {
        if (i > 0) w += h * gapFactor;
        w += _charWidth(text[i], h);
      }
      return w;
    }

    if (total(dh) > size.width) dh = dh * size.width / total(dh);
    var x = (size.width - total(dh)) / 2;
    final y = (size.height - dh) / 2;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final glow = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, dh * 0.05);

    for (final ch in text.split('')) {
      final w = _charWidth(ch, dh);
      if (ch == ':') {
        final r = dh * 0.06;
        for (final cy in [y + dh * 0.34, y + dh * 0.66]) {
          final c = Offset(x + w / 2, cy);
          canvas.drawCircle(c, r, glow);
          canvas.drawCircle(c, r, fill);
        }
      } else {
        final segs = _segs[ch];
        if (segs != null) _drawDigit(canvas, x, y, w, dh, segs, fill, glow);
      }
      x += w + dh * gapFactor;
    }
  }

  void _drawDigit(
    Canvas canvas,
    double x,
    double y,
    double w,
    double h,
    List<int> segs,
    Paint fill,
    Paint glow,
  ) {
    final t = h * 0.13;
    final pad = t * 0.7;
    final left = x + pad;
    final right = x + w - pad;
    final top = y + pad;
    final midY = y + h / 2;
    final bot = y + h - pad;

    void hseg(double cy) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left + t * 0.4, cy - t / 2, (right - left) - t * 0.8, t),
        Radius.circular(t / 2),
      );
      canvas.drawRRect(rect, glow);
      canvas.drawRRect(rect, fill);
    }

    void vseg(double cx, double yTop, double yBot) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - t / 2, yTop + t * 0.4, t, (yBot - yTop) - t * 0.8),
        Radius.circular(t / 2),
      );
      canvas.drawRRect(rect, glow);
      canvas.drawRRect(rect, fill);
    }

    if (segs[0] == 1) hseg(top);
    if (segs[1] == 1) vseg(right, top, midY);
    if (segs[2] == 1) vseg(right, midY, bot);
    if (segs[3] == 1) hseg(bot);
    if (segs[4] == 1) vseg(left, midY, bot);
    if (segs[5] == 1) vseg(left, top, midY);
    if (segs[6] == 1) hseg(midY);
  }

  @override
  bool shouldRepaint(covariant _SevenSegClockPainter oldDelegate) =>
      oldDelegate.text != text || oldDelegate.color != color;
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

/// Neon nameplate: the avatar ring is baked into the plate art, so the real
/// portrait is dropped into the socket and the name fills the pill. No turn
/// countdown — the duel is real-time, both sides always active (spec 5).
class _TetrisNamePlate extends StatelessWidget {
  const _TetrisNamePlate({
    required this.name,
    required this.imageUrl,
    required this.avatarOnLeft,
  });

  final String name;
  final String? imageUrl;
  final bool avatarOnLeft;

  @override
  Widget build(BuildContext context) {
    final plate = Image.asset(
      '${_tetrisFigmaAsset}game_plate.png',
      fit: BoxFit.fill,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final avD = h * 0.74;
        final avCx = avatarOnLeft ? w * 0.182 : w * 0.818;
        final nameCx = avatarOnLeft ? w * 0.62 : w * 0.38;
        final nameW = w * 0.56;
        return Stack(
          children: [
            Positioned.fill(
              child: avatarOnLeft
                  ? plate
                  : Transform.flip(flipX: true, child: plate),
            ),
            Positioned(
              left: avCx - avD / 2,
              top: (h - avD) / 2,
              width: avD,
              height: avD,
              child: ClipOval(
                child: AgentAvatarImage(
                  imageUrl: imageUrl,
                  width: avD,
                  height: avD,
                  fit: BoxFit.cover,
                  fallback: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF8E7BFF), Color(0xFF3B2A73)],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        name.trim().isEmpty
                            ? '伴'
                            : name.trim().characters.first,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: avD * 0.4,
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
              left: nameCx - nameW / 2,
              top: 0,
              bottom: 0,
              width: nameW,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    name,
                    maxLines: 1,
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
          ],
        );
      },
    );
  }
}

/// Neon score plate drawn per the design: a coloured frame around a dark inner
/// panel, "SCORE" label image top-left, and a bold score number bottom-right.
class _TetrisScoreBadge extends StatelessWidget {
  const _TetrisScoreBadge({
    required this.labelAsset,
    required this.score,
    required this.frameColor,
    required this.borderColor,
    required this.innerColor,
    required this.numberColor,
  });

  final String labelAsset;
  final int score;
  final Color frameColor;
  final Color borderColor;
  final Color innerColor;
  final Color numberColor;

  /// The label is stretched to the design's text box rather than scaled by the
  /// art's own 122x34 ratio — the design sets the lettering wider and flatter
  /// than the exported bitmap. Keeping the art's ratio made it a third taller,
  /// which is what pushed it up against the frame.
  static const _labelWidth = 44.0;
  static const _labelHeight = 9.2;

  /// Inset from the plate's corner. The design puts the box at (6,6), which
  /// leaves only 4pt to the inner panel and reads as touching the frame.
  static const _labelLeft = 8.0;
  static const _labelTop = 7.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Everything below is the design's 120x44 plate expressed as fractions.
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        double fx(double v) => w * (v / 120);
        double fy(double v) => h * (v / 44);

        return Stack(
          children: [
            // Frame 120x44 over an inner panel 116x38 at (2,3): a 2px rim down
            // the sides and 3px top and bottom.
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: frameColor,
                  borderRadius: BorderRadius.circular(fy(8)),
                  border: Border.all(color: borderColor, width: fy(1)),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(fx(1), fy(2), fx(1), fy(2)),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: innerColor,
                      borderRadius: BorderRadius.circular(fy(8)),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: fx(_labelLeft),
              top: fy(_labelTop),
              width: fx(_labelWidth),
              height: fy(_labelHeight),
              child: Image.asset(labelAsset, fit: BoxFit.fill),
            ),
            // Score number: 70x29 at (49,13), centred in its box. Nudged down
            // to sit on the same baseline as the design's own artwork.
            Positioned(
              left: fx(49),
              top: fy(14.2),
              width: fx(70),
              height: fy(29),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$score',
                  style: TextStyle(
                    color: numberColor,
                    // Anton, as the design specifies — a narrow heavy face the
                    // system fonts cannot approximate.
                    fontFamily: 'Anton',
                    // The design's stated 20px does not match its own artwork;
                    // measured against the exported 90000 it renders 11% large.
                    fontSize: fy(18),
                    height: 1.2,
                    decoration: TextDecoration.none,
                    shadows: [
                      Shadow(
                        color: numberColor.withValues(alpha: 0.7),
                        blurRadius: fy(4),
                      ),
                    ],
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

class _TetrisIconButton extends StatefulWidget {
  const _TetrisIconButton({
    required this.asset,
    required this.enabled,
    this.onTap,
    this.iconAsset,
    this.onLongPress,
    this.onPressStart,
    this.onPressEnd,
  });

  final String asset;
  final bool enabled;
  final VoidCallback? onTap;

  /// Optional glyph drawn on the button face (rotate / 速降 icons).
  final String? iconAsset;
  final VoidCallback? onLongPress;

  /// Press-and-hold hooks — used by 速降 to accelerate gravity while held.
  final VoidCallback? onPressStart;
  final VoidCallback? onPressEnd;

  @override
  State<_TetrisIconButton> createState() => _TetrisIconButtonState();
}

class _TetrisIconButtonState extends State<_TetrisIconButton> {
  bool _pressed = false;

  void _release() {
    if (!_pressed) return;
    setState(() => _pressed = false);
    widget.onPressEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled
          ? (_) {
              setState(() => _pressed = true);
              widget.onPressStart?.call();
            }
          : null,
      onTapCancel: widget.enabled ? _release : null,
      onTapUp: widget.enabled
          ? (_) {
              _release();
              widget.onTap?.call();
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
                if (widget.iconAsset != null)
                  Positioned.fill(
                    // The 3D base lifts the lit face above the image centre.
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: constraints.maxHeight * _tetrisButtonFaceLift,
                      ),
                      child: Center(
                        child: FractionallySizedBox(
                          widthFactor: 0.46,
                          heightFactor: 0.46,
                          child: Image.asset(
                            widget.iconAsset!,
                            fit: BoxFit.contain,
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
  const _TetrisPlateButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_TetrisPlateButton> createState() => _TetrisPlateButtonState();
}

class _TetrisPlateButtonState extends State<_TetrisPlateButton> {
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
        duration: const Duration(milliseconds: 90),
        child: Opacity(
          opacity: 1,
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
  const _TetrisModalButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: _TetrisPlateButton(label: label, onTap: onTap),
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

/// Small neon NEXT box that renders the live next tetromino.
class _TetrisNextPreview extends StatelessWidget {
  const _TetrisNextPreview({required this.type, required this.accent});

  final TetrisTetromino? type;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF191233),
            borderRadius: BorderRadius.circular(h * 0.2),
            border: Border.all(color: accent.withValues(alpha: 0.9), width: 2),
            boxShadow: [
              BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 8),
            ],
          ),
          padding: EdgeInsets.all(h * 0.08),
          child: Column(
            children: [
              SizedBox(
                height: h * 0.26,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'NEXT',
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        height: 1,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: type == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: EdgeInsets.only(top: h * 0.04),
                        child: CustomPaint(
                          painter: _TetrisNextPainter(type: type!),
                          size: Size.infinite,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TetrisNextPainter extends CustomPainter {
  _TetrisNextPainter({required this.type});

  final TetrisTetromino type;

  @override
  void paint(Canvas canvas, Size size) {
    // Spawn-orientation cells via the public piece API (the engine's private
    // shape table lives in a separate library).
    final cells = TetrisActivePiece(type: type, rotation: 0, x: 0, y: 0).cells;
    var minX = 99, maxX = -99, minY = 99, maxY = -99;
    for (final c in cells) {
      minX = math.min(minX, c.x);
      maxX = math.max(maxX, c.x);
      minY = math.min(minY, c.y);
      maxY = math.max(maxY, c.y);
    }
    final cols = maxX - minX + 1;
    final rows = maxY - minY + 1;
    final cs = math.min(size.width / cols, size.height / rows);
    final ox = (size.width - cs * cols) / 2;
    final oy = (size.height - cs * rows) / 2;
    final palette = _tetrisPalette[type.index % _tetrisPalette.length];
    for (final c in cells) {
      final rect = Rect.fromLTWH(
        ox + (c.x - minX) * cs + cs * 0.06,
        oy + (c.y - minY) * cs + cs * 0.06,
        cs * 0.88,
        cs * 0.88,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(cs * 0.18)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [palette.first, palette.last],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TetrisNextPainter oldDelegate) =>
      oldDelegate.type != type;
}

/// Small neon pill (退出 / 暂停) at the bottom bar.
class _TetrisPillButton extends StatefulWidget {
  const _TetrisPillButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_TetrisPillButton> createState() => _TetrisPillButtonState();
}

class _TetrisPillButtonState extends State<_TetrisPillButton> {
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
        scale: _pressed ? 0.94 : 1,
        duration: const Duration(milliseconds: 90),
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  '${_tetrisFigmaAsset}btn_pill.png',
                  fit: BoxFit.fill,
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: constraints.maxHeight * _tetrisButtonFaceLift,
                  ),
                  child: Center(
                    child: FittedBox(
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

enum _TetrisResultKind { win, lose }

/// Full-screen 方块竞速 win / lose page, shown in place of the board.
class _TetrisResultScreen extends StatefulWidget {
  const _TetrisResultScreen({
    super.key,
    required this.kind,
    required this.onRestart,
    required this.onExit,
  });

  final _TetrisResultKind kind;
  final Future<void> Function() onRestart;
  final Future<void> Function() onExit;

  @override
  State<_TetrisResultScreen> createState() => _TetrisResultScreenState();
}

class _TetrisResultScreenState extends State<_TetrisResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _pop(Widget child) {
    return FadeTransition(
      opacity: _controller,
      child: ScaleTransition(
        scale: Tween(begin: 0.7, end: 1.0).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final win = widget.kind == _TetrisResultKind.win;
    return Scaffold(
      backgroundColor: const Color(0xFF120726),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          double x(double v) => width * (v / 393);
          double y(double v) => height * (v / 852);
          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  '${_tetrisFigmaAsset}game_bg2.jpg',
                  fit: BoxFit.cover,
                ),
              ),
              Positioned.fill(
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.28)),
              ),
              if (win)
                Positioned(
                  left: x(28),
                  top: y(110),
                  width: x(338),
                  height: y(250),
                  child: _pop(
                    Stack(
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            '${_tetrisFigmaAsset}result_win_emblem.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        // Title sits within the ribbon band (measured red band
                        // centre ≈ 0.638 of the emblem).
                        Positioned(
                          left: x(338) * 0.30,
                          top: y(250) * 0.518,
                          width: x(338) * 0.40,
                          height: y(250) * 0.24,
                          child: Image.asset(
                            '${_tetrisFigmaAsset}result_win_title.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Positioned(
                  left: x(79),
                  top: y(117),
                  width: x(235),
                  height: y(235),
                  child: _pop(
                    Image.asset(
                      '${_tetrisFigmaAsset}result_lose_sun.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  left: x(14),
                  top: y(197),
                  width: x(365),
                  height: y(126),
                  child: _pop(
                    Stack(
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            '${_tetrisFigmaAsset}result_lose_banner.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        // Title within the ribbon band (measured centre ≈
                        // 0.406 of the banner).
                        Positioned(
                          left: x(365) * 0.30,
                          top: y(126) * 0.196,
                          width: x(365) * 0.40,
                          height: y(126) * 0.42,
                          child: Image.asset(
                            '${_tetrisFigmaAsset}result_lose_title.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              Positioned(
                left: 0,
                right: 0,
                top: y(486),
                height: y(40),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        '${_tetrisFigmaAsset}result_score_label.png',
                        height: y(27),
                        fit: BoxFit.contain,
                      ),
                      SizedBox(width: x(8)),
                      Image.asset(
                        win
                            ? '${_tetrisFigmaAsset}result_win_num.png'
                            : '${_tetrisFigmaAsset}result_lose_num.png',
                        height: y(34),
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: x(49),
                top: y(602),
                width: x(127),
                height: y(58),
                child: _TetrisResultButton(
                  base: '${_tetrisFigmaAsset}result_btn_exit.png',
                  label: '退出',
                  onTap: () => unawaited(widget.onExit()),
                ),
              ),
              Positioned(
                left: x(216),
                top: y(602),
                width: x(130),
                height: y(58),
                child: _TetrisResultButton(
                  base: '${_tetrisFigmaAsset}result_btn_again.png',
                  label: '重来一局',
                  onTap: () => unawaited(widget.onRestart()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TetrisResultButton extends StatefulWidget {
  const _TetrisResultButton({
    required this.base,
    required this.label,
    required this.onTap,
  });

  final String base;
  final String label;
  final VoidCallback onTap;

  @override
  State<_TetrisResultButton> createState() => _TetrisResultButtonState();
}

class _TetrisResultButtonState extends State<_TetrisResultButton> {
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
        duration: const Duration(milliseconds: 90),
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              Positioned.fill(
                child: Image.asset(widget.base, fit: BoxFit.fill),
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: constraints.maxHeight * 0.072,
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          height: 1,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
