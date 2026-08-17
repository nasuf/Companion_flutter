part of 'package:companion_flutter/main.dart';

/// Monday of the ISO week that page 0 of the week strip shows.
final DateTime _kCheckinEpochMonday = DateTime.utc(2000, 1, 3);

int _checkinWeekIndex(DateTime date) {
  final monday = _weekStart(date);
  return DateTime.utc(
        monday.year,
        monday.month,
        monday.day,
      ).difference(_kCheckinEpochMonday).inDays ~/
      7;
}

DateTime _checkinWeekFromIndex(int index) {
  final utc = _kCheckinEpochMonday.add(Duration(days: index * 7));
  return DateTime(utc.year, utc.month, utc.day);
}

int _checkinMonthIndex(DateTime month) =>
    (month.year - 2000) * 12 + month.month - 1;

DateTime _checkinMonthFromIndex(int index) =>
    DateTime(2000 + index ~/ 12, index % 12 + 1);

/// Week rows a month needs. The design frame happens to be a 5-row month, but
/// a 31-day month starting on a weekend spills into a sixth row.
int _checkinMonthRows(DateTime month) {
  final first = _monthOnly(month);
  final leading = first.weekday - DateTime.monday;
  final days = DateTime(first.year, first.month + 1, 0).day;
  return ((leading + days) / 7).ceil();
}

double _checkinExpandedHeight(DateTime month) {
  final rows = _checkinMonthRows(month);
  // 50 header block + 20 weekday row + 16 gap + rows + 24 bottom padding.
  return 50 + 20 + 16 + rows * _kCheckinDayHeight + (rows - 1) * 12 + 24;
}

/// The calendar card at the top of the check-in page.
///
/// Collapsed it is a one-week strip; expanded it is the whole month. Both
/// states are the same card, so the height animates rather than swapping
/// widgets, and the paging index is derived from the parent's state instead of
/// being mirrored here — mirroring is what made the two views drift apart.
class _CheckinCalendarCard extends StatefulWidget {
  const _CheckinCalendarCard({
    required this.selectedDate,
    required this.visibleWeek,
    required this.visibleMonth,
    required this.expanded,
    required this.markFor,
    required this.onSelected,
    required this.onVisibleWeekChanged,
    required this.onVisibleMonthChanged,
    required this.onExpandedChanged,
  });

  final DateTime selectedDate;
  final DateTime visibleWeek;
  final DateTime visibleMonth;
  final bool expanded;
  final _CheckinDayMark Function(DateTime date) markFor;
  final ValueChanged<DateTime> onSelected;
  final ValueChanged<DateTime> onVisibleWeekChanged;
  final ValueChanged<DateTime> onVisibleMonthChanged;
  final ValueChanged<bool> onExpandedChanged;

  @override
  State<_CheckinCalendarCard> createState() => _CheckinCalendarCardState();
}

class _CheckinCalendarCardState extends State<_CheckinCalendarCard>
    with SingleTickerProviderStateMixin {
  static const _weekdayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  static const double _dragTravel =
      _kCheckinCalendarExpanded - _kCheckinCalendarCollapsed;
  static const Duration _heightSettle = Duration(milliseconds: 220);

  late final AnimationController _expansion;
  late final PageController _weekPages;
  late final PageController _monthPages;

  @override
  void initState() {
    super.initState();
    _expansion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: widget.expanded ? 1 : 0,
    );
    _weekPages = PageController(
      initialPage: _checkinWeekIndex(widget.visibleWeek),
    );
    _monthPages = PageController(
      initialPage: _checkinMonthIndex(widget.visibleMonth),
    );
  }

  @override
  void didUpdateWidget(covariant _CheckinCalendarCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != oldWidget.expanded) {
      if (widget.expanded) {
        _expansion.animateTo(1, curve: Curves.easeOutCubic);
      } else {
        _expansion.animateBack(0, curve: Curves.easeOutCubic);
      }
    }
    _syncPage(_weekPages, () => _checkinWeekIndex(widget.visibleWeek));
    _syncPage(_monthPages, () => _checkinMonthIndex(widget.visibleMonth));
  }

  /// Pull a page controller onto the parent's page when it moved without us.
  ///
  /// [resolve] is re-read inside the callback so a second change landing in the
  /// same frame does not get overwritten by the first one's stale target.
  void _syncPage(PageController controller, int Function() resolve) {
    if (!controller.hasClients) return;
    if ((controller.page?.round() ?? controller.initialPage) == resolve()) {
      return;
    }
    // Jump rather than animate: the controller may still be settling from a
    // swipe, and stacking animations lands on a fractional page.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.hasClients) return;
      final target = resolve();
      if (controller.page?.round() == target) return;
      controller.jumpToPage(target);
    });
  }

  @override
  void dispose() {
    _expansion.dispose();
    _weekPages.dispose();
    _monthPages.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _expansion.value = (_expansion.value + details.delta.dy / _dragTravel)
        .clamp(0.0, 1.0);
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dy;
    final expand = velocity > 320
        ? true
        : velocity < -320
        ? false
        : _expansion.value >= 0.45;
    if (expand == widget.expanded) {
      // The parent will not rebuild us, so settle the controller here.
      if (expand) {
        _expansion.animateTo(1, curve: Curves.easeOutCubic);
      } else {
        _expansion.animateBack(0, curve: Curves.easeOutCubic);
      }
      return;
    }
    widget.onExpandedChanged(expand);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = _CheckinTokens.of(context);
    // A six-row month makes the open card taller; ease that change so paging
    // into one does not snap the task list down the screen.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: _checkinExpandedHeight(widget.visibleMonth)),
      duration: _heightSettle,
      curve: Curves.easeOutCubic,
      builder: (context, expandedHeight, _) =>
          _buildCard(tokens, expandedHeight),
    );
  }

  Widget _buildCard(_CheckinTokens tokens, double expandedHeight) {
    // Built once per parent rebuild, not once per animation frame: passing the
    // same widget instances back lets the two PageViews and their ~49 day
    // pills sit out the expand animation instead of rebuilding at 60fps.
    final week = _weekStrip(tokens);
    final month = _monthGrid(tokens);
    return AnimatedBuilder(
      animation: _expansion,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_expansion.value);
        final height = lerpDouble(
          _kCheckinCalendarCollapsed,
          expandedHeight,
          t,
        )!;
        final weekOpacity = (1 - t * 2.2).clamp(0.0, 1.0);
        final monthOpacity = ((t - 0.45) / 0.55).clamp(0.0, 1.0);
        // The whole card takes the vertical drag, not just the handle bar:
        // "pull the calendar down" is the gesture people reach for, and a
        // 4px bar is not a target. The cost is that a vertical drag started on
        // the card does not scroll the page — the task list below still does.
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: _handleDragUpdate,
          onVerticalDragEnd: _handleDragEnd,
          child: Container(
            key: const Key('checkin-calendar'),
            height: height,
            decoration: BoxDecoration(
              color: tokens.card,
              borderRadius: BorderRadius.circular(_kCheckinCardRadius),
              border: Border.all(color: tokens.glassBorder),
              boxShadow: tokens.cardShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_kCheckinCardRadius),
              child: Stack(
                children: [
                  Positioned(
                    left: _kCheckinMargin,
                    right: _kCheckinMargin,
                    top: 12,
                    height: 22,
                    child: _monthHeader(tokens, t),
                  ),
                  // Both views stay mounted even at zero opacity: a detached
                  // PageController forgets the page it was on, so collapsing
                  // after swiping would drop the calendar back to its start.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 50,
                    height: 79,
                    child: IgnorePointer(
                      ignoring: weekOpacity < 0.5,
                      child: Opacity(opacity: weekOpacity, child: week),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 50,
                    bottom: 24,
                    child: IgnorePointer(
                      ignoring: monthOpacity < 0.5,
                      child: Opacity(opacity: monthOpacity, child: month),
                    ),
                  ),
                  // Sized to the open card's bottom padding so it never covers
                  // the last row of dates.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 24,
                    child: _dragHandle(tokens, t),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _monthHeader(_CheckinTokens tokens, double t) {
    final label = '${widget.visibleMonth.year}年${widget.visibleMonth.month}月';
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: tokens.title,
            fontSize: 14,
            height: 1.2,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.none,
          ),
        ),
        const Spacer(),
        // The chip and the collapse chevron occupy the same slot, so they
        // cross-fade with the card instead of jumping between two rows.
        Stack(
          alignment: Alignment.centerRight,
          children: [
            if (t < 1)
              Opacity(
                opacity: (1 - t * 2.2).clamp(0.0, 1.0),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: t < 0.5 ? () => widget.onExpandedChanged(true) : null,
                  child: _weekRangeChip(tokens),
                ),
              ),
            if (t > 0)
              Opacity(
                opacity: ((t - 0.45) / 0.55).clamp(0.0, 1.0),
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(32, 22),
                  onPressed: t > 0.5
                      ? () => widget.onExpandedChanged(false)
                      : null,
                  child: Icon(
                    CupertinoIcons.chevron_up,
                    size: 16,
                    color: tokens.sectionTitle,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _weekRangeChip(_CheckinTokens tokens) {
    final start = widget.visibleWeek;
    final end = start.add(const Duration(days: 6));
    String pad(int value) => value.toString().padLeft(2, '0');
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${pad(start.month)}.${pad(start.day)} - ${pad(end.month)}.${pad(end.day)}',
        style: TextStyle(
          color: tokens.accentInk,
          fontSize: 10,
          height: 1.2,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  Widget _weekStrip(_CheckinTokens tokens) {
    return PageView.builder(
      controller: _weekPages,
      onPageChanged: (index) {
        final week = _checkinWeekFromIndex(index);
        widget.onVisibleWeekChanged(week);
        widget.onVisibleMonthChanged(_monthForWeek(week));
      },
      itemBuilder: (context, index) {
        final weekStart = _checkinWeekFromIndex(index);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kCheckinCardPadX),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var offset = 0; offset < 7; offset += 1)
                SizedBox(
                  width: _kCheckinDayWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _weekdayLabels[offset],
                        style: TextStyle(
                          color: tokens.sectionTitle,
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _dayPill(
                        tokens,
                        weekStart.add(Duration(days: offset)),
                        keyPrefix: 'week',
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _monthGrid(_CheckinTokens tokens) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kCheckinCardPadX),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final label in _weekdayLabels)
                SizedBox(
                  width: _kCheckinDayWidth,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: tokens.sectionTitle,
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: PageView.builder(
            controller: _monthPages,
            onPageChanged: (index) =>
                widget.onVisibleMonthChanged(_checkinMonthFromIndex(index)),
            itemBuilder: (context, index) =>
                _monthPage(tokens, _checkinMonthFromIndex(index)),
          ),
        ),
      ],
    );
  }

  Widget _monthPage(_CheckinTokens tokens, DateTime month) {
    final gridStart = _weekStart(month);
    final rowCount = _checkinMonthRows(month);
    final rows = <Widget>[];
    for (var row = 0; row < rowCount; row += 1) {
      rows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final date in [
              for (var column = 0; column < 7; column += 1)
                gridStart.add(Duration(days: row * 7 + column)),
            ])
              _dayPill(
                tokens,
                date,
                dimmed: !_isSameMonth(date, month),
                keyPrefix: 'month',
              ),
          ],
        ),
      );
    }
    // The card height catches up to a six-row month one animation behind the
    // page, so the grid has to tolerate being taller than its viewport.
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: _kCheckinCardPadX),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index += 1) ...[
            if (index > 0) const SizedBox(height: 12),
            rows[index],
          ],
        ],
      ),
    );
  }

  Widget _dayPill(
    _CheckinTokens tokens,
    DateTime date, {
    required String keyPrefix,
    bool dimmed = false,
  }) {
    final selected = _isSameDate(date, widget.selectedDate);
    final isToday = _isSameDate(date, DateTime.now());
    final mark = widget.markFor(date);
    return GestureDetector(
      key: Key('checkin-$keyPrefix-day-${_dateKey(date)}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onSelected(_dateOnlyTime(date)),
      child: Container(
        width: _kCheckinDayWidth,
        height: _kCheckinDayHeight,
        decoration: BoxDecoration(
          // Today owns the solid pill and keeps it whether or not it is the
          // selected day; selection is the outline. The plan mark stays on in
          // both cases — it is the only thing telling the two states apart.
          color: isToday ? tokens.accent : tokens.dayPill,
          borderRadius: BorderRadius.circular(999),
          border: selected && !isToday
              ? Border.all(color: tokens.accent)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                color: isToday
                    ? Colors.white
                    : dimmed
                    ? tokens.dayNumber.withValues(alpha: 0.35)
                    : tokens.dayNumber,
                fontSize: 12,
                height: 1.16,
                fontWeight: FontWeight.w400,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 8),
            Opacity(
              opacity: dimmed ? 0.4 : 1,
              child: _CheckinDayMarker(
                mark: mark,
                tokens: tokens,
                onAccent: isToday,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dragHandle(_CheckinTokens tokens, double t) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onExpandedChanged(!widget.expanded),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Opacity(
          opacity: (1 - t * 2.2).clamp(0.0, 1.0),
          child: Container(
            width: 64,
            height: 4,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: tokens.accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}

/// The 12x12 mark under a day number.
///
/// Every state occupies the same 12x12 box so the day number does not shift
/// by a couple of pixels as a day goes from empty to done.
class _CheckinDayMarker extends StatelessWidget {
  const _CheckinDayMarker({
    required this.mark,
    required this.tokens,
    this.onAccent = false,
  });

  static const double _size = 12;

  final _CheckinDayMark mark;
  final _CheckinTokens tokens;

  /// Today's pill is solid accent, so the mark inverts to white on it.
  final bool onAccent;

  @override
  Widget build(BuildContext context) {
    final marked = onAccent ? Colors.white : tokens.accent;
    final idle = onAccent
        ? Colors.white.withValues(alpha: 0.45)
        : tokens.markIdle;
    return SizedBox(
      width: _size,
      height: _size,
      child: switch (mark) {
        _CheckinDayMark.done => _CheckinCheckBadge(
          size: _size,
          color: marked,
          checkColor: onAccent ? tokens.accent : Colors.white,
        ),
        _CheckinDayMark.partial => _CheckinRingMark(size: _size, color: marked),
        _CheckinDayMark.pending => _dot(marked),
        _CheckinDayMark.none => _dot(idle),
      },
    );
  }

  Widget _dot(Color color) {
    return Center(
      child: Container(
        width: _size * 2 / 3,
        height: _size * 2 / 3,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
