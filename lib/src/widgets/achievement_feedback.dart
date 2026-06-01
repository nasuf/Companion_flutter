part of 'package:companion_flutter/main.dart';

class _AchievementError extends StatelessWidget {
  const _AchievementError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_circle,
              color: AppColors.muted,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 14),
            ),
            const SizedBox(height: 14),
            CupertinoButton.filled(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

class _AchievementBackdrop extends StatelessWidget {
  const _AchievementBackdrop({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AchievementToastStack extends StatelessWidget {
  const _AchievementToastStack({
    required this.entries,
    required this.onDismiss,
  });

  static const _itemHeight = 82.0;
  static const _gap = 10.0;

  final List<_AchievementToastEntry> entries;
  final ValueChanged<String> onDismiss;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final height = entries.length * _itemHeight + (entries.length - 1) * _gap;
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < entries.length; index++)
            AnimatedPositioned(
              key: ValueKey(entries[index].id),
              top: index * (_itemHeight + _gap),
              left: 0,
              right: 0,
              height: _itemHeight,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: _AchievementUnlockToast(
                entry: entries[index],
                onDismiss: onDismiss,
              ),
            ),
        ],
      ),
    );
  }
}

class _AchievementUnlockToast extends StatefulWidget {
  const _AchievementUnlockToast({required this.entry, required this.onDismiss});

  final _AchievementToastEntry entry;
  final ValueChanged<String> onDismiss;

  @override
  State<_AchievementUnlockToast> createState() =>
      _AchievementUnlockToastState();
}

class _AchievementUnlockToastState extends State<_AchievementUnlockToast> {
  double _dragOffset = 0;
  bool _dragging = false;

  void _handleDragUpdate(DragUpdateDetails details) {
    final next = math.max(0.0, _dragOffset + details.delta.dx);
    if (next == _dragOffset) return;
    setState(() {
      _dragging = true;
      _dragOffset = next;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_dragOffset > 86 || velocity > 360) {
      widget.onDismiss(widget.entry.id);
      return;
    }
    setState(() {
      _dragging = false;
      _dragOffset = 0;
    });
  }

  void _handleDragCancel() {
    setState(() {
      _dragging = false;
      _dragOffset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.entry.entered && !widget.entry.closing;
    final item = widget.entry.item;
    final color = _achievementColor(item.id);
    const radius = BorderRadius.only(
      topLeft: Radius.circular(22),
      bottomLeft: Radius.circular(22),
    );
    return IgnorePointer(
      ignoring: !visible,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: _handleDragUpdate,
        onHorizontalDragEnd: _handleDragEnd,
        onHorizontalDragCancel: _handleDragCancel,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = math.max(1.0, constraints.maxWidth);
            return AnimatedSlide(
              offset: visible ? Offset.zero : const Offset(1.12, 0),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              child: AnimatedSlide(
                offset: Offset(_dragOffset / width, 0),
                duration: _dragging
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: visible ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: RepaintBoundary(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: radius,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.13),
                                  blurRadius: 18,
                                  offset: const Offset(-1, 8),
                                ),
                                BoxShadow(
                                  color: color.withValues(alpha: 0.18),
                                  blurRadius: 28,
                                  offset: const Offset(-10, 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: radius,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: radius,
                                color: Colors.white.withValues(alpha: 0.74),
                                border: Border.all(
                                  color: Colors.black.withValues(alpha: 0.11),
                                  width: 1,
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.90),
                                    color.withValues(alpha: 0.12),
                                    Colors.white.withValues(alpha: 0.72),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: radius,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0.42),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          left: 18,
                          right: 0,
                          child: Container(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.76),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 11, 18, 11),
                          child: Row(
                            children: [
                              _AchievementIcon(
                                color: color,
                                label: item.name.isNotEmpty
                                    ? item.name.substring(0, 1)
                                    : '?',
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      item.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.text,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.popupText,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppColors.text.withValues(
                                          alpha: 0.56,
                                        ),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        height: 1.18,
                                        letterSpacing: 0,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 0,
                          bottom: 10,
                          child: Container(
                            width: 1,
                            color: Colors.white.withValues(alpha: 0.58),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
