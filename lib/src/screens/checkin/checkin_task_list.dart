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
                  onDelete: () => onDelete(items[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A task row. The design only draws a tick circle; pin and delete live behind
/// a sideways swipe.
///
/// The revealed action is part of the row rather than a button parked next to
/// it: the colour fills the whole rounded rectangle, the card slides over it,
/// and the card's leading (or trailing) corners go square while it is open so
/// the two halves meet flush instead of showing a crescent of colour.
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
  final Future<void> Function() onDelete;

  @override
  State<_SwipeTaskRow> createState() => _SwipeTaskRowState();
}

class _SwipeTaskRowState extends State<_SwipeTaskRow>
    with SingleTickerProviderStateMixin {
  static const double _reveal = 88;
  static const Color _pinColor = Color(0xFFFFB83F);
  static const Color _deleteColor = Color(0xFFFF4C4C);

  late final AnimationController _sweepController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  double _offset = 0;
  bool _dragging = false;

  /// Which end the last swipe opened. Kept past the release so the colour and
  /// the action stay put while the card eases back over them.
  bool _openLeading = true;
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

  Future<void> _handleDelete() async {
    await _flash(_deleteColor, fromRight: true);
    if (mounted) setState(() => _collapsing = true);
    await Future<void>.delayed(const Duration(milliseconds: 170));
    await widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = _CheckinTokens.of(context);
    final completed = widget.completed || _optimisticCompleted;
    final revealed = _offset.abs();
    return GestureDetector(
      onHorizontalDragStart: (_) {
        if (_sweeping || _collapsing) return;
        setState(() => _dragging = true);
      },
      onHorizontalDragUpdate: (details) {
        if (_sweeping || _collapsing) return;
        final next = (_offset + details.delta.dx).clamp(-_reveal, _reveal);
        if (next.abs() > 2) widget.onSwipeOpen(widget.item.id);
        setState(() {
          _offset = next;
          if (next != 0) _openLeading = next > 0;
        });
      },
      onHorizontalDragEnd: (_) {
        if (_sweeping || _collapsing) return;
        setState(() {
          // Leaving _dragging false hands the settle to the implicit
          // animation below; during the drag it has to track the finger.
          _dragging = false;
          if (_offset > 36) {
            _offset = _reveal;
          } else if (_offset < -36) {
            _offset = -_reveal;
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
        child: DecoratedBox(
          // The shadow belongs to the row, not to the sliding card — leaving it
          // on the card would darken the action colour it slides over.
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_kCheckinCardRadius),
            boxShadow: tokens.cardShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_kCheckinCardRadius),
            child: Stack(
              children: [
                // The colour and the action sit under the card at full width
                // and never move; the card slides off them. Animating one
                // thing keeps the two halves locked together.
                Positioned.fill(
                  // Rounded like the row rather than a plain fill: at rest the
                  // card's own corner arcs sit exactly on top, and a square
                  // base would fringe through them.
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _openLeading ? _pinColor : _deleteColor,
                      borderRadius: BorderRadius.circular(_kCheckinCardRadius),
                    ),
                  ),
                ),
                Positioned(
                  left: _openLeading ? 0 : null,
                  right: _openLeading ? null : 0,
                  top: 0,
                  bottom: 0,
                  width: _reveal,
                  child: _TaskSwipeAction(
                    icon: _openLeading
                        ? (widget.pinned
                              ? CupertinoIcons.pin_slash_fill
                              : CupertinoIcons.pin_fill)
                        : CupertinoIcons.delete,
                    label: _openLeading
                        ? (widget.pinned ? '取消置顶' : '置顶')
                        : '删除',
                    reveal: revealed / _reveal,
                    dragging: _dragging,
                    onTap: _openLeading ? _handlePin : _handleDelete,
                  ),
                ),
                _card(tokens, completed),
                Positioned.fill(child: IgnorePointer(child: _sweepOverlay())),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Square off whichever end is butted against the revealed action.
  BorderRadius get _cardRadius => BorderRadius.horizontal(
    left: Radius.circular(_offset > 0 ? 0 : _kCheckinCardRadius),
    right: Radius.circular(_offset < 0 ? 0 : _kCheckinCardRadius),
  );

  Widget _card(_CheckinTokens tokens, bool completed) {
    final item = widget.item;
    // Position and corner rounding animate together on release, so the card
    // eases back over the colour instead of snapping and popping its corner.
    return AnimatedContainer(
      duration: _dragging ? Duration.zero : const Duration(milliseconds: 190),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(_offset, 0, 0),
      height: _kCheckinTaskRowHeight,
      padding: const EdgeInsets.symmetric(horizontal: _kCheckinMargin),
      decoration: BoxDecoration(color: tokens.card, borderRadius: _cardRadius),
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
            const Icon(CupertinoIcons.pin_fill, color: _pinColor, size: 14),
            const SizedBox(width: 8),
          ],
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(24, 24),
            onPressed: completed ? null : _handleComplete,
            child: completed
                ? _CheckinCheckBadge(size: 24, color: tokens.accent)
                : _CheckinRingMark(size: 24, color: tokens.markIdle),
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

/// Icon + label filling the revealed end of a row.
class _TaskSwipeAction extends StatelessWidget {
  const _TaskSwipeAction({
    required this.icon,
    required this.label,
    required this.reveal,
    required this.dragging,
    required this.onTap,
  });

  static const Duration _settle = Duration(milliseconds: 190);

  final IconData icon;
  final String label;
  final double reveal;

  /// While the finger is down the fade tracks it; on release it eases out in
  /// step with the card sliding back, instead of blinking off.
  final bool dragging;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = Curves.easeOutCubic.transform(reveal.clamp(0.0, 1.0));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedOpacity(
        duration: dragging ? Duration.zero : _settle,
        curve: Curves.easeOutCubic,
        opacity: progress,
        child: AnimatedScale(
          duration: dragging ? Duration.zero : _settle,
          curve: Curves.easeOutCubic,
          scale: 0.82 + progress * 0.18,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
