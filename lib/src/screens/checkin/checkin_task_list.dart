part of 'package:companion_flutter/main.dart';

class _SwipeTaskRow extends StatefulWidget {
  const _SwipeTaskRow({
    required this.item,
    required this.completed,
    required this.pinned,
    required this.openItemId,
    required this.onSwipeOpen,
    required this.onTap,
    required this.onComplete,
    required this.onPin,
    required this.onReschedule,
    required this.onDelete,
  });

  final ReminderItem item;
  final bool completed;
  final bool pinned;
  final String? openItemId;
  final ValueChanged<String> onSwipeOpen;
  final VoidCallback onTap;
  final Future<void> Function() onComplete;
  final Future<void> Function() onPin;
  final Future<void> Function() onReschedule;
  final Future<void> Function() onDelete;

  @override
  State<_SwipeTaskRow> createState() => _SwipeTaskRowState();
}

class _AnimatedTaskList extends StatelessWidget {
  const _AnimatedTaskList({
    required this.items,
    required this.isCompleted,
    required this.isPinned,
    required this.openItemId,
    required this.onSwipeOpen,
    required this.onItemTap,
    required this.onComplete,
    required this.onPin,
    required this.onReschedule,
    required this.onDelete,
  });

  static const double _rowExtent = 84;
  static const double _rowGap = 10;

  final List<ReminderItem> items;
  final bool Function(ReminderItem item) isCompleted;
  final bool Function(ReminderItem item) isPinned;
  final String? openItemId;
  final ValueChanged<String> onSwipeOpen;
  final ValueChanged<ReminderItem> onItemTap;
  final Future<void> Function(ReminderItem item) onComplete;
  final Future<void> Function(ReminderItem item) onPin;
  final Future<void> Function(ReminderItem item) onReschedule;
  final Future<void> Function(ReminderItem item) onDelete;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: SizedBox(
        height: items.length * _rowExtent,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var index = 0; index < items.length; index += 1)
              AnimatedPositioned(
                key: ValueKey(items[index].id),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                left: 0,
                right: 0,
                top: index * _rowExtent,
                height: _rowExtent - _rowGap,
                child: _SwipeTaskRow(
                  item: items[index],
                  completed: isCompleted(items[index]),
                  pinned: isPinned(items[index]),
                  openItemId: openItemId,
                  onSwipeOpen: onSwipeOpen,
                  onTap: () => onItemTap(items[index]),
                  onComplete: () => onComplete(items[index]),
                  onPin: () => onPin(items[index]),
                  onReschedule: () => onReschedule(items[index]),
                  onDelete: () => onDelete(items[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SwipeTaskRowState extends State<_SwipeTaskRow>
    with SingleTickerProviderStateMixin {
  static const double _leadingReveal = 112;
  static const double _trailingReveal = 112;

  double _offset = 0;
  bool _flashFromRight = false;
  bool _collapsing = false;
  bool _sweeping = false;
  bool _optimisticCompleted = false;
  Color _flashColor = const Color(0xFF5DCFA8);
  AnimationController? _sweepControllerInstance;

  AnimationController get _sweepController {
    return _sweepControllerInstance ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void initState() {
    super.initState();
    _sweepController;
  }

  @override
  void didUpdateWidget(covariant _SwipeTaskRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id || widget.completed) {
      _optimisticCompleted = false;
    }
    if (widget.openItemId != widget.item.id &&
        _offset != 0 &&
        !_sweeping &&
        !_collapsing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.openItemId != widget.item.id && _offset != 0) {
          setState(() => _offset = 0);
        }
      });
    }
  }

  @override
  void dispose() {
    _sweepControllerInstance?.dispose();
    super.dispose();
  }

  Future<void> _closeActions() async {
    if (_offset == 0) return;
    setState(() => _offset = 0);
    await Future<void>.delayed(const Duration(milliseconds: 130));
  }

  Future<void> _flash(Color color, {bool fromRight = false}) async {
    setState(() {
      _flashColor = color;
      _flashFromRight = fromRight;
      _offset = 0;
      _sweeping = true;
    });
    await _sweepController.forward(from: 0);
    if (!mounted) return;
    _sweepController.value = 0;
    setState(() => _sweeping = false);
  }

  Future<void> _handleComplete() async {
    if (widget.completed || _optimisticCompleted) return;
    setState(() => _optimisticCompleted = true);
    try {
      await _flash(const Color(0xFF5DCFA8));
      await widget.onComplete();
      if (mounted) setState(() => _offset = 0);
    } catch (_) {
      if (mounted) {
        setState(() {
          _optimisticCompleted = false;
          _offset = 0;
        });
      }
      rethrow;
    }
  }

  Future<void> _handlePin() async {
    await _closeActions();
    await widget.onPin();
  }

  Future<void> _handleReschedule() async {
    if (widget.completed || _optimisticCompleted) return;
    await _closeActions();
    await widget.onReschedule();
  }

  Future<void> _handleDelete() async {
    await _flash(const Color(0xFFFF4C4C), fromRight: true);
    if (mounted) setState(() => _collapsing = true);
    await Future<void>.delayed(const Duration(milliseconds: 170));
    await widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final completed = widget.completed || _optimisticCompleted;
    final leadingLimit = completed ? _leadingReveal / 2 : _leadingReveal;
    final trailingLimit = completed ? _trailingReveal / 2 : _trailingReveal;
    final leadingWidth = _offset > 0 ? _offset : 0.0;
    final trailingWidth = _offset < 0 ? -_offset : 0.0;
    final leadingProgress = (leadingWidth / _leadingReveal).clamp(0.0, 1.0);
    final foregroundRadius = BorderRadius.horizontal(
      left: Radius.circular(_offset > 0 ? 0 : 22),
      right: Radius.circular(_offset < 0 ? 0 : 22),
    );
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (_sweeping || _collapsing) return;
        final next = (_offset + details.delta.dx).clamp(
          -trailingLimit,
          leadingLimit,
        );
        if (next.abs() > 2) widget.onSwipeOpen(widget.item.id);
        setState(() => _offset = next);
      },
      onHorizontalDragEnd: (_) {
        if (_sweeping || _collapsing) return;
        setState(() {
          if (_offset > 44) {
            _offset = leadingLimit;
          } else if (_offset < -44) {
            _offset = -trailingLimit;
          } else {
            _offset = 0;
          }
        });
      },
      onTap: () {
        if (_sweeping || _collapsing) return;
        if (_offset != 0) {
          unawaited(_closeActions());
          return;
        }
        widget.onTap();
      },
      child: AnimatedSize(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 140),
          opacity: _collapsing ? 0 : 1,
          child: _collapsing
              ? const SizedBox(width: double.infinity)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    children: [
                      if (!_sweeping) ...[
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: leadingWidth,
                          child: Row(
                            children: [
                              if (!completed)
                                Expanded(
                                  child: _TaskActionButton(
                                    color: const Color(0xFF5DCFA8),
                                    icon: CupertinoIcons.check_mark,
                                    borderRadius: const BorderRadius.horizontal(
                                      left: Radius.circular(22),
                                    ),
                                    onTap: _handleComplete,
                                    reveal: leadingWidth / leadingLimit,
                                  ),
                                ),
                              Expanded(
                                child: _TaskActionButton(
                                  color: const Color(0xFFFFB83F),
                                  icon: widget.pinned
                                      ? CupertinoIcons.pin_slash
                                      : CupertinoIcons.pin,
                                  borderRadius: completed
                                      ? const BorderRadius.horizontal(
                                          left: Radius.circular(22),
                                        )
                                      : BorderRadius.zero,
                                  onTap: _handlePin,
                                  reveal: leadingWidth / leadingLimit,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          width: trailingWidth,
                          child: Row(
                            children: [
                              if (!completed)
                                Expanded(
                                  child: _TaskActionButton(
                                    color: const Color(0xFF4F6DF5),
                                    icon: CupertinoIcons.calendar,
                                    borderRadius: BorderRadius.zero,
                                    onTap: _handleReschedule,
                                    reveal: trailingWidth / trailingLimit,
                                  ),
                                ),
                              Expanded(
                                child: _TaskActionButton(
                                  color: const Color(0xFFFF4C4C),
                                  icon: CupertinoIcons.delete,
                                  borderRadius: const BorderRadius.horizontal(
                                    right: Radius.circular(22),
                                  ),
                                  onTap: _handleDelete,
                                  reveal: trailingWidth / trailingLimit,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Transform.translate(
                        offset: Offset(_offset, 0),
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.fromLTRB(
                                13,
                                11,
                                14,
                                11,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: foregroundRadius,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF24344A,
                                    ).withValues(alpha: 0.06),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  if (completed)
                                    Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF5DCFA8),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.check_mark,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    )
                                  else
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 120,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      width: 26 * (1 - leadingProgress),
                                      child: IgnorePointer(
                                        ignoring: leadingProgress > 0.12,
                                        child: AnimatedOpacity(
                                          duration: const Duration(
                                            milliseconds: 100,
                                          ),
                                          opacity: 1 - leadingProgress,
                                          child: CupertinoButton(
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size.zero,
                                            onPressed: _handleComplete,
                                            child: Container(
                                              width: 26,
                                              height: 26,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFF9EA4AA,
                                                  ),
                                                  width: 2,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  SizedBox(
                                    width: completed
                                        ? 11
                                        : 11 * (1 - leadingProgress),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.summary,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: completed
                                                ? AppColors.text.withValues(
                                                    alpha: 0.55,
                                                  )
                                                : AppColors.text,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            decoration: completed
                                                ? TextDecoration.lineThrough
                                                : TextDecoration.none,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          completed
                                              ? '已完成'
                                              : item.isHabit
                                              ? '${_chatCardRecurrenceLabel(item.recurrence, item.habitWeekdays)} · ${_timeLabel(item.triggerTime)}'
                                              : '${_timeLabel(item.triggerTime)} · ${_recurrenceLabel(item.recurrence)}',
                                          style: const TextStyle(
                                            color: AppColors.muted,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (widget.pinned)
                                    const Icon(
                                      CupertinoIcons.pin_fill,
                                      color: Color(0xFFFFB83F),
                                      size: 16,
                                    ),
                                ],
                              ),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    return AnimatedBuilder(
                                      animation: _sweepController,
                                      builder: (context, _) {
                                        final progress = Curves.easeOutCubic
                                            .transform(_sweepController.value);
                                        final width =
                                            constraints.maxWidth * progress;
                                        final opacity =
                                            (1 - _sweepController.value * 0.25)
                                                .clamp(0.0, 1.0);
                                        return Stack(
                                          children: [
                                            Positioned(
                                              top: 0,
                                              bottom: 0,
                                              left: _flashFromRight ? null : 0,
                                              right: _flashFromRight ? 0 : null,
                                              width: width,
                                              child: Opacity(
                                                opacity: opacity,
                                                child: DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        foregroundRadius,
                                                    gradient: LinearGradient(
                                                      begin: _flashFromRight
                                                          ? Alignment
                                                                .centerRight
                                                          : Alignment
                                                                .centerLeft,
                                                      end: _flashFromRight
                                                          ? Alignment.centerLeft
                                                          : Alignment
                                                                .centerRight,
                                                      colors: [
                                                        _flashColor.withValues(
                                                          alpha: 0.42,
                                                        ),
                                                        _flashColor.withValues(
                                                          alpha: 0.24,
                                                        ),
                                                        _flashColor.withValues(
                                                          alpha: 0.06,
                                                        ),
                                                      ],
                                                      stops: const [0, 0.72, 1],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
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

class _TaskActionButton extends StatelessWidget {
  const _TaskActionButton({
    required this.color,
    required this.icon,
    required this.borderRadius,
    required this.onTap,
    required this.reveal,
  });

  final Color color;
  final IconData icon;
  final BorderRadius borderRadius;
  final VoidCallback onTap;
  final double reveal;

  @override
  Widget build(BuildContext context) {
    final progress = Curves.easeOutCubic.transform(reveal.clamp(0.0, 1.0));
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: AnimatedContainer(
        duration: Duration.zero,
        height: double.infinity,
        decoration: BoxDecoration(color: color, borderRadius: borderRadius),
        alignment: Alignment.center,
        child: Transform.scale(
          scale: 0.76 + progress * 0.24,
          child: Opacity(
            opacity: progress,
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}
