part of 'package:companion_flutter/main.dart';

const _hubArt = 'assets/prototype/games/hub-figma';

const _hubCream = Color(0xFFFFF0DB);
const _hubSlab = Color(0xFFEFC299);
const _hubInk = Color(0xFF4B1D08);
const _hubInkSoft = Color(0xFF9D6646);
const _hubBadgeFace = Color(0xFFE9C7A9);
const _hubBadgeSlab = Color(0xFFD4B08B);

/// Every measurement below is taken from the 393pt-wide design frame and
/// multiplied by `s = width / 393` so the page keeps its proportions.
const double _hubRefWidth = 393;

/// Board games swap in the illustrated thumbnails from the design; every other
/// group keeps the photography it already shipped with.
const _hubBoardThumbs = <String, String>{
  _nativeGomokuGameKey: '$_hubArt/thumb_gomoku.png',
  _nativeGoGameKey: '$_hubArt/thumb_go.png',
  _nativeReversiGameKey: '$_hubArt/thumb_reversi.png',
  _nativeXiangqiGameKey: '$_hubArt/thumb_xiangqi.png',
  _nativeChessGameKey: '$_hubArt/thumb_chess.png',
  _nativeChineseCheckersGameKey:
      'assets/prototype/games/checkers-figma/home_board.png',
};

String _hubTileArt(_GameTile game) =>
    _hubBoardThumbs[game.nativeGameKey] ?? game.image;

/// The badge's two lines: `皮革手套-白` over `初学起步`. The ladder stores the
/// glove, its colour and the caption separately, so this only joins them.
({String title, String subtitle}) _hubLevelLabels(GameLevel? level) {
  if (level == null) return (title: '皮革手套-白', subtitle: '初学起步');
  final glove = level.stageName.trim();
  final colour = level.tierName.trim();
  final title = [glove, colour].where((part) => part.isNotEmpty).join('-');
  return (
    title: title.isEmpty ? '皮革手套-白' : title,
    subtitle: level.stageCaption.trim(),
  );
}

/// Press feedback without clipping — the cards rely on drop shadows that a
/// ClipRRect would cut off.
class _HubPress extends StatefulWidget {
  const _HubPress({
    required this.onTap,
    required this.pressedScale,
    required this.child,
  });

  final VoidCallback onTap;
  final double pressedScale;
  final Widget child;

  @override
  State<_HubPress> createState() => _HubPressState();
}

class _HubPressState extends State<_HubPress> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// The design's two-tone card: a darker slab peeking out beneath a cream face.
List<Widget> _hubCardLayers({
  required double s,
  required double faceTop,
  required double faceHeight,
  required double slabTop,
  required double slabHeight,
}) => [
  Positioned(
    left: 0,
    right: 0,
    top: slabTop * s,
    height: slabHeight * s,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: _hubSlab,
        borderRadius: BorderRadius.circular(8 * s),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 3,
            offset: Offset(0, 4 * s),
          ),
        ],
      ),
    ),
  ),
  Positioned(
    left: 0,
    right: 0,
    top: faceTop * s,
    height: faceHeight * s,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: _hubCream,
        borderRadius: BorderRadius.circular(13 * s),
      ),
    ),
  ),
];

/// Full-bleed illustrated backdrop, slightly blurred and slowly breathing.
class _HubBackground extends StatelessWidget {
  const _HubBackground({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRect(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: Transform.scale(
            scale: 1.04 + progress * 0.03,
            child: Image.asset(
              '$_hubArt/bg.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }
}

/// Slow zoom plus a drifting highlight, the same idle motion the previous hub
/// used on its artwork. `seed` staggers cards so they never pulse in unison.
class _HubBreathingArt extends StatefulWidget {
  const _HubBreathingArt({
    required this.asset,
    required this.seed,
    this.desaturate = false,
  });

  final String asset;
  final int seed;
  final bool desaturate;

  // Kept identical to the hub's previous idle motion.
  static const double _scaleAmount = 0.09;
  static const double _glowAmount = 0.16;

  @override
  State<_HubBreathingArt> createState() => _HubBreathingArtState();
}

class _HubBreathingArtState extends State<_HubBreathingArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _breath;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    final offset = widget.seed.abs();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 4300 + offset % 900),
      value: (offset % 1000) / 1000,
    )..repeat(reverse: true);
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    );
    _breath = Tween<double>(
      begin: 1.0,
      end: 1.0 + _HubBreathingArt._scaleAmount,
    ).animate(curve);
    _glow = Tween<double>(
      begin: 0.0,
      end: _HubBreathingArt._glowAmount,
    ).animate(curve);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(
      widget.asset,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
    );
    if (widget.desaturate) {
      image = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.34, 0.46, 0.14, 0, 12, //
          0.32, 0.44, 0.14, 0, 12, //
          0.29, 0.40, 0.13, 0, 12, //
          0, 0, 0, 1, 0,
        ]),
        child: image,
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(scale: _breath.value, child: child),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.35, -0.45),
                  radius: 0.9,
                  colors: [
                    Colors.white.withValues(alpha: _glow.value),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.74],
                ),
              ),
            ),
          ),
        ],
      ),
      child: image,
    );
  }
}

class _HubRoundButton extends StatelessWidget {
  const _HubRoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _HubPress(
      onTap: onTap,
      pressedScale: 0.9,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF63B9EA), Color(0xFF2E86C8)],
          ),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, size: 17, color: Colors.white),
      ),
    );
  }
}

class _HubCoinBar extends StatelessWidget {
  const _HubCoinBar({
    required this.scale,
    required this.balance,
    required this.onPlus,
  });

  final double scale;
  final int? balance;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return SizedBox(
      width: 124 * s,
      height: 31 * s,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('$_hubArt/coin_pill.png', fit: BoxFit.fill),
          ),
          Positioned(
            left: 27 * s,
            right: 30 * s,
            top: 0,
            bottom: 0,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  balance == null ? '--' : '$balance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15 * s,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                    shadows: const [
                      Shadow(
                        color: Color(0x88001428),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 3 * s,
            top: 2 * s,
            width: 24 * s,
            height: 25 * s,
            child: Image.asset('$_hubArt/coin_icon.png', fit: BoxFit.contain),
          ),
          Positioned(
            left: 97 * s,
            top: 3 * s,
            width: 24 * s,
            height: 23 * s,
            child: _HubPress(
              onTap: onPlus,
              pressedScale: 0.88,
              child: Image.asset('$_hubArt/coin_plus.png', fit: BoxFit.contain),
            ),
          ),
        ],
      ),
    );
  }
}

/// Level medallion: glove badge, tier name and the stage underneath it.
class _HubLevelCard extends StatelessWidget {
  const _HubLevelCard({
    required this.scale,
    required this.tierName,
    required this.stageName,
    required this.glove,
    required this.onTap,
  });

  final double scale;
  final String tierName;
  final String stageName;

  /// Artwork for the player's current step, so the badge matches their colour.
  final String glove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return _HubPress(onTap: onTap, pressedScale: 0.97, child: _card(s));
  }

  Widget _card(double s) {
    return SizedBox(
      width: 121 * s,
      height: 154 * s,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ..._hubCardLayers(
            s: s,
            faceTop: 0,
            faceHeight: 152,
            slabTop: 7,
            slabHeight: 147,
          ),
          Positioned(
            left: 18 * s,
            top: 16 * s,
            width: 84 * s,
            height: 84 * s,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _hubBadgeSlab,
                borderRadius: BorderRadius.circular(13 * s),
              ),
            ),
          ),
          Positioned(
            left: 18 * s,
            top: 18 * s,
            width: 84 * s,
            height: 84 * s,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _hubBadgeFace,
                borderRadius: BorderRadius.circular(13 * s),
              ),
            ),
          ),
          Positioned(
            left: 32 * s,
            top: 26 * s,
            width: 57 * s,
            height: 68 * s,
            child: Image.asset(glove, fit: BoxFit.contain),
          ),
          _spark(s, 51, 52, 7, 0.25),
          _spark(s, 56.5, 53.5, 9, 0.31),
          _spark(s, 63, 58, 9, 0.31),
          // Both lines keep a margin off the card edge; the ladder's names run
          // up to six characters, which used to fill the card edge to edge.
          Positioned(
            left: 9 * s,
            right: 9 * s,
            top: 103 * s,
            height: 28 * s,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  tierName,
                  maxLines: 1,
                  style: TextStyle(
                    color: _hubInk,
                    fontSize: 20 * s,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 9 * s,
            right: 9 * s,
            top: 131 * s,
            height: 18 * s,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  stageName,
                  maxLines: 1,
                  style: TextStyle(
                    color: _hubInkSoft,
                    fontSize: 11.5 * s,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _spark(double s, double x, double y, double size, double turns) =>
      Positioned(
        left: x * s,
        top: y * s,
        width: size * s,
        height: size * s,
        child: Transform.rotate(
          angle: turns * 2 * math.pi,
          child: Image.asset('$_hubArt/level_spark.png', fit: BoxFit.contain),
        ),
      );
}

/// Cartoon lettering from the design: white glyphs with a dark brown rim.
class _HubOutlinedText extends StatelessWidget {
  const _HubOutlinedText({
    required this.text,
    required this.fontSize,
    required this.strokeWidth,
  });

  final String text;
  final double fontSize;
  final double strokeWidth;

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
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = _hubInk,
          ),
        ),
        Text(text, maxLines: 1, style: base.copyWith(color: Colors.white)),
      ],
    );
  }
}

class _HubStatPill extends StatelessWidget {
  const _HubStatPill({
    required this.scale,
    required this.icon,
    required this.label,
    required this.value,
    this.loading = false,
  });

  final double scale;
  final String icon;
  final String label;
  final String value;

  /// Counters come from a separate history request; spin until it lands rather
  /// than flashing a placeholder zero.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return SizedBox(
      width: 163 * s,
      height: 44 * s,
      // The round icon is taller than the pill and the slab casts a shadow past
      // the bottom edge, so this stack must not clip.
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 21 * s,
            top: 4 * s,
            width: 142 * s,
            height: 40 * s,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _hubSlab,
                borderRadius: BorderRadius.circular(13 * s),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 3,
                    offset: Offset(0, 4 * s),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 21 * s,
            top: 2 * s,
            width: 142 * s,
            height: 40 * s,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _hubCream,
                borderRadius: BorderRadius.circular(13 * s),
              ),
            ),
          ),
          Positioned(
            left: 36 * s,
            right: 11 * s,
            top: 6 * s,
            height: 17 * s,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                // The design sets the caption in solid ink and reserves the
                // outlined white lettering for the number below it.
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: _hubInk,
                    fontSize: 15 * s,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 36 * s,
            right: 11 * s,
            top: 23 * s,
            height: 17 * s,
            child: Center(
              child: loading
                  ? CupertinoActivityIndicator(radius: 6.5 * s, color: _hubInk)
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _HubOutlinedText(
                        text: value,
                        fontSize: 13 * s,
                        strokeWidth: 2.6 * s,
                      ),
                    ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            width: 47 * s,
            height: 48 * s,
            child: Image.asset(icon, fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }
}

class _HubProgressBar extends StatelessWidget {
  const _HubProgressBar({required this.value, required this.label});

  final double value;
  final String label;

  // Fractions of the track artwork that make up the recessed groove.
  static const double _left = 0.049;
  static const double _right = 0.951;
  static const double _top = 0.285;
  static const double _bottom = 0.672;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => _build(constraints.maxWidth),
    );
  }

  Widget _build(double width) {
    final height = width * 52 / 304;
    final grooveWidth = width * (_right - _left);
    final grooveTop = height * _top;
    final grooveHeight = height * (_bottom - _top);
    final fillWidth = grooveWidth * value.clamp(0.0, 1.0);
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('$_hubArt/progress_track.png', fit: BoxFit.fill),
          ),
          if (fillWidth > 2)
            Positioned(
              left: width * _left,
              top: grooveTop,
              width: fillWidth,
              height: grooveHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(grooveHeight / 2),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFE066), Color(0xFFF9A81B)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFC947).withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            top: grooveTop,
            height: grooveHeight,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: height * 0.42,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                    shadows: const [
                      Shadow(
                        color: Color(0xAA3A1A05),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Category banner. Tapping it folds the group's tiles open or closed; the
/// artwork grows on open with the same 128→184 ratio, duration and curve the
/// previous hub used.
class _HubGroupBanner extends StatelessWidget {
  const _HubGroupBanner({
    required this.scale,
    required this.group,
    required this.isOpen,
    required this.onTap,
  });

  final double scale;
  final _GameGroup group;
  final bool isOpen;
  final VoidCallback onTap;

  /// Open matches the design's window; closed keeps the original 128/184 ratio.
  static const double openArtHeight = 92;
  static const double closedArtHeight = openArtHeight * 128 / 184;

  /// Top lip above the artwork plus the title band below it.
  static const double _chrome = 8 + 44;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final art = group.id == 'board'
        ? '$_hubArt/banner_board_art.png'
        : group.hero;
    return _HubPress(
      onTap: onTap,
      pressedScale: 0.985,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: isOpen ? openArtHeight : closedArtHeight),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        builder: (context, artHeight, _) {
          final faceHeight = artHeight + _chrome;
          return SizedBox(
            width: 351 * s,
            height: (faceHeight + 2) * s,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // The slab only peeks 2pt past the face, same as every other
                // card in the design — it reads as an edge, not a band.
                ..._hubCardLayers(
                  s: s,
                  faceTop: 0,
                  faceHeight: faceHeight,
                  slabTop: 6,
                  slabHeight: faceHeight - 4,
                ),
                Positioned(
                  left: 8 * s,
                  top: 8 * s,
                  width: 336 * s,
                  height: artHeight * s,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11 * s),
                    child: _HubBreathingArt(
                      asset: art,
                      seed: group.id.hashCode,
                    ),
                  ),
                ),
                Positioned(
                  left: 34 * s,
                  right: 34 * s,
                  top: (artHeight + 10) * s,
                  height: 34 * s,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        group.title,
                        maxLines: 1,
                        style: TextStyle(
                          color: _hubInk,
                          fontSize: 24 * s,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 14 * s,
                  top: (artHeight + 10) * s,
                  height: 34 * s,
                  child: Center(
                    child: AnimatedRotation(
                      duration: const Duration(milliseconds: 280),
                      turns: isOpen ? 0.5 : 0,
                      child: Icon(
                        CupertinoIcons.chevron_down,
                        size: 16 * s,
                        color: _hubInkSoft,
                      ),
                    ),
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

class _HubGameTile extends StatelessWidget {
  const _HubGameTile({
    required this.scale,
    required this.game,
    required this.onTap,
  });

  final double scale;
  final _GameTile game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return _HubPress(
      onTap: onTap,
      pressedScale: 0.965,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ..._hubCardLayers(
            s: s,
            faceTop: 6,
            faceHeight: 130,
            slabTop: 12,
            slabHeight: 126,
          ),
          Positioned(
            left: 15 * s,
            top: 24 * s,
            width: 140 * s,
            height: 80 * s,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11 * s),
              child: _HubBreathingArt(
                asset: _hubTileArt(game),
                seed: game.title.hashCode,
                desaturate: !game.isOnline,
              ),
            ),
          ),
          Positioned(
            left: 10 * s,
            right: 10 * s,
            top: 104 * s,
            height: 32 * s,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  game.title,
                  maxLines: 1,
                  style: TextStyle(
                    color: _hubInk,
                    fontSize: 24 * s,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 55 * s,
            top: 0,
            width: 60 * s,
            height: 23 * s,
            child: game.isOnline
                ? Image.asset('$_hubArt/badge_online.png', fit: BoxFit.contain)
                : DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF9A8A74),
                      borderRadius: BorderRadius.circular(8 * s),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.6),
                        width: 1.4,
                      ),
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '待上线',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12 * s,
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
    );
  }
}
