part of 'package:companion_flutter/main.dart';

/// Sub-label under a task title: the plan type, or the habit's weekdays.
String _taskPlanLabel(ReminderItem item) {
  if (!item.isHabit) return '单次计划';
  return _recurrenceDetailLabel(item.recurrence, item.habitWeekdays);
}

class _CheckinTaskList extends StatelessWidget {
  const _CheckinTaskList({
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

  static const double _rowExtent = _kCheckinTaskRowHeight + _kCheckinTaskRowGap;

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
        height: items.isEmpty
            ? 0
            : items.length * _rowExtent - _kCheckinTaskRowGap,
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
                height: _kCheckinTaskRowHeight,
                child: _SwipeTaskRow(
                  // Keyed by id, not row index: the row owns swipe state that
                  // has to follow its task when the list reorders.
                  key: Key('checkin-task-${items[index].id}'),
                  item: items[index],
                  index: index + 1,
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

/// A task row. The design only draws a tick circle; complete / pin / reschedule
/// / delete stay reachable by swiping the row sideways.
class _SwipeTaskRow extends StatefulWidget {
  const _SwipeTaskRow({
    super.key,
    required this.item,
    required this.index,
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
  final int index;
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

class _SwipeTaskRowState extends State<_SwipeTaskRow>
    with SingleTickerProviderStateMixin {
  static const double _reveal = 112;

  late final AnimationController _sweepController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  double _offset = 0;
  bool _flashFromRight = false;
  bool _collapsing = false;
  bool _sweeping = false;
  bool _optimisticCompleted = false;
  Color _flashColor = const Color(0xFF5DCFA8);

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
    _sweepController.dispose();
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
    final tokens = _CheckinTokens.of(context);
    final completed = widget.completed || _optimisticCompleted;
    final leadingLimit = completed ? _reveal / 2 : _reveal;
    final trailingLimit = completed ? _reveal / 2 : _reveal;
    final leadingWidth = _offset > 0 ? _offset : 0.0;
    final trailingWidth = _offset < 0 ? -_offset : 0.0;
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
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 140),
        opacity: _collapsing ? 0 : 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_kCheckinCardRadius),
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
                            color: tokens.accent,
                            icon: CupertinoIcons.calendar,
                            onTap: _handleReschedule,
                            reveal: trailingWidth / trailingLimit,
                          ),
                        ),
                      Expanded(
                        child: _TaskActionButton(
                          color: const Color(0xFFFF4C4C),
                          icon: CupertinoIcons.delete,
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
                    _card(tokens, completed),
                    Positioned.fill(
                      child: IgnorePointer(child: _sweepOverlay()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(_CheckinTokens tokens, bool completed) {
    final item = widget.item;
    return Container(
      height: _kCheckinTaskRowHeight,
      padding: const EdgeInsets.symmetric(horizontal: _kCheckinMargin),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(_kCheckinCardRadius),
        boxShadow: tokens.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tokens.accentSoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${widget.index}',
              style: TextStyle(
                color: tokens.accent,
                fontSize: 15,
                height: 1.2,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.title,
                    fontSize: 16,
                    height: 1.375,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _taskPlanLabel(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.subtitle,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          if (widget.pinned) ...[
            const Icon(
              CupertinoIcons.pin_fill,
              color: Color(0xFFFFB83F),
              size: 14,
            ),
            const SizedBox(width: 8),
          ],
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(24, 24),
            onPressed: completed ? null : _handleComplete,
            child: SizedBox(
              width: 24,
              height: 24,
              child: completed
                  ? Icon(Icons.check_rounded, size: 24, color: tokens.accent)
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: tokens.markIdle, width: 2),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sweepOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: _sweepController,
          builder: (context, _) {
            final progress = Curves.easeOutCubic.transform(
              _sweepController.value,
            );
            final opacity = (1 - _sweepController.value * 0.25).clamp(0.0, 1.0);
            return Stack(
              children: [
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: _flashFromRight ? null : 0,
                  right: _flashFromRight ? 0 : null,
                  width: constraints.maxWidth * progress,
                  child: Opacity(
                    opacity: opacity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          _kCheckinCardRadius,
                        ),
                        gradient: LinearGradient(
                          begin: _flashFromRight
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          end: _flashFromRight
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          colors: [
                            _flashColor.withValues(alpha: 0.42),
                            _flashColor.withValues(alpha: 0.24),
                            _flashColor.withValues(alpha: 0.06),
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
    );
  }
}

class _TaskActionButton extends StatelessWidget {
  const _TaskActionButton({
    required this.color,
    required this.icon,
    required this.onTap,
    required this.reveal,
  });

  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  final double reveal;

  @override
  Widget build(BuildContext context) {
    final progress = Curves.easeOutCubic.transform(reveal.clamp(0.0, 1.0));
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        height: double.infinity,
        color: color,
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
