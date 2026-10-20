import 'package:flutter/widgets.dart';

/// Inserts space above the composer while painting the entire row unmodified.
/// Top alignment moves the full-size bubble with the message flow; its lower
/// part passes behind the composer instead of being wiped by a row-local clip.
/// Never clip here: bubble shadows extend beyond the row even at rest.
class MessageEntrance extends StatefulWidget {
  const MessageEntrance({
    super.key,
    required this.child,
    this.animate = false,
    this.settle,
  });

  static const duration = Duration(milliseconds: 240);
  final Widget child;
  final bool animate;
  final Listenable? settle;

  @override
  State<MessageEntrance> createState() => _MessageEntranceState();
}

class _MessageEntranceState extends State<MessageEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: MessageEntrance.duration,
    value: widget.animate ? 0 : 1,
  );
  bool _initialized = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    widget.settle?.addListener(_settle);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion || !TickerMode.valuesOf(context).enabled) {
      _settle();
    } else if (!_initialized && widget.animate) {
      _controller.animateTo(
        1,
        duration: MessageEntrance.duration,
        curve: Curves.easeOutCubic,
      );
    }
    _initialized = true;
  }

  @override
  void didUpdateWidget(covariant MessageEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settle != widget.settle) {
      oldWidget.settle?.removeListener(_settle);
      widget.settle?.addListener(_settle);
    }
    // Rebuilds/acks never restart an entrance. Reply replacement happens in
    // the same row; there is intentionally no exit/collapse animation here.
  }

  void _settle() => _controller.value = 1;

  @override
  void dispose() {
    widget.settle?.removeListener(_settle);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      return Align(
        heightFactor: _controller.value,
        alignment: Alignment.topCenter,
        child: widget.child,
      );
    },
  );
}
