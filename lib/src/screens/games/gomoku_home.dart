part of 'package:companion_flutter/main.dart';

// ===========================================================================
// 五子棋首页 (illustrated game-art home, 1:1 with Figma). Positions are
// fractions measured from the design composite so overlays land exactly where
// the artwork expects them. Replace any PNG in
// assets/prototype/games/gomoku/ with a higher-res version (same name) and the
// layout stays identical.
// ===========================================================================

const String _gomokuHomeAsset = 'assets/prototype/games/gomoku/';

/// Subtle idle motion for decorative artwork only. Interactive controls and
/// gameplay geometry deliberately never use this wrapper.
class _GomokuBreathingMotion extends StatefulWidget {
  const _GomokuBreathingMotion({
    required this.child,
    this.duration = const Duration(milliseconds: 6000),
    this.scaleAmount = 0.008,
    this.translateY = 0,
    this.phase = 0,
  });

  final Widget child;
  final Duration duration;
  final double scaleAmount;
  final double translateY;
  final double phase;

  @override
  State<_GomokuBreathingMotion> createState() => _GomokuBreathingMotionState();
}

class _GomokuBreathingMotionState extends State<_GomokuBreathingMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool? _animationsDisabled;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: widget.phase.clamp(0, 1),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_animationsDisabled == disabled) return;
    _animationsDisabled = disabled;
    if (disabled) {
      _controller
        ..stop()
        ..value = 0;
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final progress = Curves.easeInOut.transform(_controller.value);
          return Transform.translate(
            offset: Offset(0, -widget.translateY * progress),
            child: Transform.scale(
              scale: 1 + widget.scaleAmount * progress,
              child: child,
            ),
          );
        },
      ),
    );
  }
}

class _GomokuHome extends StatelessWidget {
  const _GomokuHome({
    super.key,
    required this.stats,
    required this.starting,
    required this.error,
    required this.onStart,
    required this.onExit,
  });

  final NativeGameRecordStats stats;
  final bool starting;
  final String? error;
  final Future<void> Function() onStart;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final values = _nativeHomeStatValues(stats);

    return Scaffold(
      // Sky-toned fallback so the frame never flashes black before the bg
      // texture decodes.
      backgroundColor: const Color(0xFF9AD0EE),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return Stack(
            children: [
              Positioned.fill(
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 9500),
                  scaleAmount: 0.004,
                  child: Image.asset(
                    '${_gomokuHomeAsset}home_bg.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
              Positioned(
                left: w * 0.117,
                top: h * 0.103,
                width: w * 0.761,
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 4800),
                  scaleAmount: 0.009,
                  translateY: 2.2,
                  phase: 0.35,
                  child: Image.asset(
                    '${_gomokuHomeAsset}home_logo.png',
                    fit: BoxFit.fitWidth,
                  ),
                ),
              ),
              if (error != null)
                Positioned(
                  left: w * 0.08,
                  right: w * 0.08,
                  top: h * 0.64,
                  child: _GomokuNotice(text: error!, isError: true),
                ),
              Positioned(
                left: w * 0.072,
                top: h * 0.714,
                width: w * 0.379,
                child: _GomokuHomeButton(
                  base: '${_gomokuHomeAsset}home_btn_exit.png',
                  textAsset: '${_gomokuHomeAsset}home_btn_exit_text.png',
                  aspectRatio: 450 / 207,
                  onTap: starting ? null : onExit,
                ),
              ),
              Positioned(
                left: w * 0.548,
                top: h * 0.714,
                width: w * 0.381,
                child: _GomokuHomeButton(
                  base: '${_gomokuHomeAsset}home_btn_start.png',
                  textAsset: '${_gomokuHomeAsset}home_btn_start_text.png',
                  aspectRatio: 450 / 210,
                  loading: starting,
                  onTap: starting ? null : () => onStart(),
                ),
              ),
              Positioned(
                left: w * 0.030,
                top: h * 0.831,
                width: w * 0.938,
                child: _GomokuHomeStats(
                  total: values[0],
                  wins: values[1],
                  rate: values[2],
                  duration: values[3],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GomokuHomeButton extends StatefulWidget {
  const _GomokuHomeButton({
    required this.base,
    required this.textAsset,
    required this.aspectRatio,
    required this.onTap,
    this.loading = false,
  });

  final String base;
  final String textAsset;
  final double aspectRatio;
  final VoidCallback? onTap;
  final bool loading;

  @override
  State<_GomokuHomeButton> createState() => _GomokuHomeButtonState();
}

class _GomokuHomeButtonState extends State<_GomokuHomeButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null && !widget.loading;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.955 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Opacity(
          opacity: enabled ? 1 : 0.75,
          child: AspectRatio(
            aspectRatio: widget.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Image.asset(widget.base, fit: BoxFit.fill),
                ),
                // The text rides the raised button face, a hair above the
                // geometric center to clear the 3D bottom lip.
                if (widget.loading)
                  const Align(
                    alignment: Alignment(0, -0.14),
                    child: CupertinoActivityIndicator(color: Colors.white),
                  )
                else
                  Align(
                    alignment: const Alignment(0, -0.14),
                    child: FractionallySizedBox(
                      widthFactor: 0.62,
                      child: Image.asset(widget.textAsset, fit: BoxFit.contain),
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

class _GomokuHomeStats extends StatelessWidget {
  const _GomokuHomeStats({
    required this.total,
    required this.wins,
    required this.rate,
    required this.duration,
  });

  final String total;
  final String wins;
  final String rate;
  final String duration;

  // Exact horizontal bounds of the four inset squares in the 1110px-wide
  // frame. Explicit bounds + clipping prevent painted text strokes from ever
  // bleeding into a neighbouring statistic.
  static const List<(double, double)> _slots = [
    (46 / 1110, 280 / 1110),
    (305 / 1110, 542 / 1110),
    (567 / 1110, 803 / 1110),
    (828 / 1110, 1065 / 1110),
  ];

  @override
  Widget build(BuildContext context) {
    final labels = [
      '${_gomokuHomeAsset}stat_label_total.png',
      '${_gomokuHomeAsset}stat_label_wins.png',
      '${_gomokuHomeAsset}stat_label_rate.png',
      '${_gomokuHomeAsset}stat_label_time.png',
    ];
    final values = [total, wins, rate, duration];
    return AspectRatio(
      aspectRatio: 1110 / 336,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fw = constraints.maxWidth;
          final fh = constraints.maxHeight;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: Image.asset(
                  '${_gomokuHomeAsset}home_stats_frame.png',
                  fit: BoxFit.fill,
                ),
              ),
              for (var i = 0; i < 4; i += 1) ...[
                Positioned(
                  left: fw * _slots[i].$1,
                  top: fh * 0.20,
                  width: fw * (_slots[i].$2 - _slots[i].$1),
                  height: fh * 0.24,
                  child: ClipRect(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: fw * 0.008),
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Image.asset(labels[i]),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: fw * _slots[i].$1,
                  top: fh * 0.49,
                  width: fw * (_slots[i].$2 - _slots[i].$1),
                  height: fh * 0.30,
                  child: ClipRect(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: fw * 0.012),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _StrokeText(
                          text: values[i],
                          fontSize: fh * 0.225,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
