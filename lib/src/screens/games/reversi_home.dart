part of 'package:companion_flutter/main.dart';

class _ReversiHome extends StatelessWidget {
  const _ReversiHome({
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
    final labels = [
      '${_reversiAsset}stat_label_total.png',
      '${_reversiAsset}stat_label_wins.png',
      '${_reversiAsset}stat_label_rate.png',
      '${_reversiAsset}stat_label_time.png',
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF69B9EE),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          return Stack(
            children: [
              Positioned.fill(
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 10000),
                  scaleAmount: 0.004,
                  child: Image.asset(
                    '${_reversiAsset}home_bg.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                left: width * (46 / 393),
                top: height * (129 / 852),
                width: width * (300 / 393),
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 5000),
                  scaleAmount: 0.008,
                  translateY: 2,
                  phase: 0.3,
                  child: Image.asset(
                    '${_reversiAsset}home_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                left: width * (36 / 393),
                top: height * (313 / 852),
                width: width * (321 / 393),
                child: _GomokuBreathingMotion(
                  duration: const Duration(milliseconds: 6200),
                  scaleAmount: 0.005,
                  translateY: 1.5,
                  phase: 0.65,
                  child: Image.asset(
                    '${_reversiAsset}home_board.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              if (error != null)
                Positioned(
                  left: width * 0.08,
                  right: width * 0.08,
                  top: height * 0.60,
                  child: _GomokuNotice(text: error!, isError: true),
                ),
              Positioned(
                left: width * (30 / 393),
                top: height * (526 / 852),
                width: width * (150 / 393),
                child: _ReversiImageButton(
                  base: '${_reversiAsset}home_btn_exit.png',
                  textAsset: '${_reversiAsset}home_btn_exit_text.png',
                  aspectRatio: 450 / 186,
                  enabled: !starting,
                  onTap: onExit,
                ),
              ),
              Positioned(
                left: width * (203 / 393),
                top: height * (526 / 852),
                width: width * (150 / 393),
                child: _ReversiImageButton(
                  base: '${_reversiAsset}home_btn_start.png',
                  textAsset: '${_reversiAsset}home_btn_start_text.png',
                  aspectRatio: 450 / 186,
                  loading: starting,
                  enabled: !starting,
                  onTap: () => unawaited(onStart()),
                ),
              ),
              for (var index = 0; index < 4; index += 1)
                Positioned(
                  left: width * ((5 + index * 98) / 393),
                  top: height * (673 / 852),
                  width: width * (90 / 393),
                  child: _ReversiHomeStatCard(
                    labelAsset: labels[index],
                    value: values[index],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ReversiHomeStatCard extends StatelessWidget {
  const _ReversiHomeStatCard({required this.labelAsset, required this.value});

  final String labelAsset;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 270 / 342,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  '${_reversiAsset}home_stat_card.png',
                  fit: BoxFit.fill,
                ),
              ),
              Positioned(
                left: width * 0.13,
                right: width * 0.13,
                top: height * (41 / 114),
                height: height * (19 / 114),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Image.asset(labelAsset),
                ),
              ),
              Positioned(
                left: width * 0.12,
                right: width * 0.12,
                top: height * (67 / 114),
                height: height * (26 / 114),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF502A2A),
                      fontSize: 20,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      decoration: TextDecoration.none,
                      shadows: [
                        Shadow(
                          color: Color(0x40000000),
                          offset: Offset(1, 1),
                          blurRadius: 1,
                        ),
                      ],
                    ),
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

class _ReversiImageButton extends StatefulWidget {
  const _ReversiImageButton({
    required this.base,
    required this.textAsset,
    required this.aspectRatio,
    required this.onTap,
    this.textWidthFactor = 0.74,
    this.textAlignment = Alignment.center,
    this.enabled = true,
    this.loading = false,
  });

  final String base;
  final String textAsset;
  final double aspectRatio;
  final VoidCallback onTap;
  final double textWidthFactor;
  final Alignment textAlignment;
  final bool enabled;
  final bool loading;

  @override
  State<_ReversiImageButton> createState() => _ReversiImageButtonState();
}

class _ReversiImageButtonState extends State<_ReversiImageButton> {
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
        duration: const Duration(milliseconds: 100),
        child: Opacity(
          opacity: enabled ? 1 : 0.72,
          child: AspectRatio(
            aspectRatio: widget.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Image.asset(widget.base, fit: BoxFit.fill),
                ),
                if (widget.loading)
                  const CupertinoActivityIndicator(color: Colors.white)
                else
                  Align(
                    alignment: widget.textAlignment,
                    child: FractionallySizedBox(
                      widthFactor: widget.textWidthFactor,
                      heightFactor: 0.62,
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
