part of 'package:companion_flutter/main.dart';

class _CalendarExpansionPanel extends StatefulWidget {
  const _CalendarExpansionPanel({
    required this.progress,
    required this.dragging,
    required this.week,
    required this.month,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  static const double collapsedHeight = 84;
  static const double expandedHeight = 398;

  final double progress;
  final bool dragging;
  final Widget week;
  final Widget month;
  final VoidCallback onDragStart;
  final ValueChanged<double> onDragUpdate;
  final ValueChanged<double> onDragEnd;

  @override
  State<_CalendarExpansionPanel> createState() =>
      _CalendarExpansionPanelState();
}

class _CalendarExpansionPanelState extends State<_CalendarExpansionPanel> {
  double _dragDy = 0;
  double _dragDx = 0;
  int? _dragPointer;
  bool _verticalDragActive = false;
  bool _horizontalDragIgnored = false;
  VelocityTracker? _velocityTracker;

  double get _height {
    final eased = Curves.easeOutCubic.transform(widget.progress);
    return _CalendarExpansionPanel.collapsedHeight +
        (_CalendarExpansionPanel.expandedHeight -
                _CalendarExpansionPanel.collapsedHeight) *
            eased;
  }

  @override
  Widget build(BuildContext context) {
    final weekOpacity = (1 - widget.progress * 1.35).clamp(0.0, 1.0);
    final monthOpacity = ((widget.progress - 0.10) / 0.90).clamp(0.0, 1.0);
    final duration = widget.dragging
        ? Duration.zero
        : const Duration(milliseconds: 240);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutCubic,
        height: _height,
        child: ClipRect(
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: _CalendarExpansionPanel.collapsedHeight,
                child: IgnorePointer(
                  ignoring: widget.progress > 0.35,
                  child: AnimatedOpacity(
                    duration: duration,
                    opacity: weekOpacity.toDouble(),
                    child: widget.week,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: _CalendarExpansionPanel.expandedHeight,
                child: IgnorePointer(
                  ignoring: widget.progress < 0.45,
                  child: AnimatedOpacity(
                    duration: duration,
                    opacity: monthOpacity.toDouble(),
                    child: widget.month,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_dragPointer != null) return;
    _dragPointer = event.pointer;
    _dragDx = 0;
    _dragDy = 0;
    _verticalDragActive = false;
    _horizontalDragIgnored = false;
    _velocityTracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_dragPointer != event.pointer || _horizontalDragIgnored) return;
    _velocityTracker?.addPosition(event.timeStamp, event.position);
    _dragDx += event.delta.dx;
    _dragDy += event.delta.dy;
    final absDx = _dragDx.abs();
    final absDy = _dragDy.abs();

    if (!_verticalDragActive) {
      if (absDx < 7 && absDy < 7) return;
      if (absDx > absDy * 1.12) {
        _horizontalDragIgnored = true;
        return;
      }
      if (absDy > absDx * 1.24) {
        _verticalDragActive = true;
        widget.onDragStart();
      } else {
        return;
      }
    }

    widget.onDragUpdate(_dragDy);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_dragPointer != event.pointer) return;
    if (_verticalDragActive) {
      final velocity =
          _velocityTracker?.getVelocity().pixelsPerSecond.dy ?? 0.0;
      widget.onDragEnd(velocity);
    }
    _resetPointerDrag();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_dragPointer != event.pointer) return;
    if (_verticalDragActive) {
      widget.onDragEnd(0);
    }
    _resetPointerDrag();
  }

  void _resetPointerDrag() {
    _dragPointer = null;
    _dragDx = 0;
    _dragDy = 0;
    _verticalDragActive = false;
    _horizontalDragIgnored = false;
    _velocityTracker = null;
  }
}

class _DateRail extends StatefulWidget {
  const _DateRail({
    required this.active,
    required this.selectedDate,
    required this.visibleMonth,
    required this.datesWithTasks,
    required this.onSelected,
    required this.onVisibleMonthChanged,
    required this.onExpand,
  });

  final bool active;
  final DateTime selectedDate;
  final DateTime visibleMonth;
  final Set<String> datesWithTasks;
  final ValueChanged<DateTime> onSelected;
  final ValueChanged<DateTime> onVisibleMonthChanged;
  final VoidCallback onExpand;

  @override
  State<_DateRail> createState() => _DateRailState();
}

class _DateRailState extends State<_DateRail> {
  static const int _initialPage = 520;

  late final PageController _pageController;
  late DateTime _baseWeek;
  late DateTime _visibleWeek;

  @override
  void initState() {
    super.initState();
    _baseWeek = _weekForMonth(widget.visibleMonth, widget.selectedDate);
    _visibleWeek = _baseWeek;
    _pageController = PageController(initialPage: _initialPage);
  }

  @override
  void didUpdateWidget(covariant _DateRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active) return;
    final targetWeek = _weekForMonth(widget.visibleMonth, widget.selectedDate);
    final becameActive = !oldWidget.active && widget.active;
    final monthChanged = !_isSameMonth(
      oldWidget.visibleMonth,
      widget.visibleMonth,
    );
    final selectedWeekChanged = !_isSameDate(
      _weekStart(oldWidget.selectedDate),
      _weekStart(widget.selectedDate),
    );
    if (!_isSameDate(targetWeek, _visibleWeek) &&
        (becameActive || monthChanged || selectedWeekChanged)) {
      final weekDelta = targetWeek.difference(_baseWeek).inDays ~/ 7;
      _visibleWeek = targetWeek;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        _pageController.animateToPage(
          _initialPage + weekDelta,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: _weekdayShortLabels
              .map(
                (label) => Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 11,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 55,
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (page) {
              final week = _baseWeek.add(
                Duration(days: (page - _initialPage) * 7),
              );
              setState(() => _visibleWeek = week);
              if (widget.active) {
                widget.onVisibleMonthChanged(_monthForWeek(week));
              }
            },
            itemBuilder: (context, page) {
              final week = _baseWeek.add(
                Duration(days: (page - _initialPage) * 7),
              );
              return Row(
                children: List.generate(7, (index) {
                  final date = week.add(Duration(days: index));
                  return Expanded(
                    child: _WeekDayCell(
                      date: date,
                      selected: _isSameDate(date, widget.selectedDate),
                      today: _isSameDate(date, DateTime.now()),
                      hasTask: widget.datesWithTasks.contains(_dateKey(date)),
                      onTap: () => widget.onSelected(date),
                    ),
                  );
                }),
              );
            },
          ),
        ),
        const SizedBox(height: 2),
        _WeekDragHandle(onExpand: widget.onExpand),
      ],
    );
  }
}

class _WeekDayCell extends StatelessWidget {
  const _WeekDayCell({
    required this.date,
    required this.selected,
    required this.today,
    required this.hasTask,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool today;
  final bool hasTask;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lunar = _SolarLunar.label(date);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: SizedBox(
        height: 55,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 31,
                  height: 31,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: today ? const Color(0xFFFFC23A) : Colors.transparent,
                    border: Border.all(
                      color: selected && !today
                          ? const Color(0xFFFFC23A).withValues(alpha: 0.60)
                          : Colors.transparent,
                      width: selected && !today ? 1.2 : 0,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: today || selected ? 18 : 17,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                if (hasTask)
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF6D45D9),
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  Text(
                    lunar,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: today || selected
                          ? AppColors.text
                          : AppColors.muted,
                      fontSize: 8,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekDragHandle extends StatelessWidget {
  const _WeekDragHandle({required this.onExpand});

  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onExpand,
      child: SizedBox(
        height: 8,
        width: double.infinity,
        child: Center(
          child: Container(
            width: 30,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFFFFC8BE),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}

const _weekdayShortLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

class _MonthCalendar extends StatefulWidget {
  const _MonthCalendar({
    required this.allowExternalSync,
    required this.selectedDate,
    required this.visibleMonth,
    required this.datesWithTasks,
    required this.onSelected,
    required this.onVisibleMonthChanged,
    required this.onCollapse,
  });

  final bool allowExternalSync;
  final DateTime selectedDate;
  final DateTime visibleMonth;
  final Set<String> datesWithTasks;
  final ValueChanged<DateTime> onSelected;
  final ValueChanged<DateTime> onVisibleMonthChanged;
  final VoidCallback onCollapse;

  @override
  State<_MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<_MonthCalendar> {
  static const int _initialPage = 1200;

  late final PageController _pageController;
  late DateTime _baseMonth;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _baseMonth = _monthOnly(widget.visibleMonth);
    _visibleMonth = _baseMonth;
    _pageController = PageController(initialPage: _initialPage);
  }

  @override
  void didUpdateWidget(covariant _MonthCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.allowExternalSync) return;
    final nextMonth = _monthOnly(widget.visibleMonth);
    if (!_isSameMonth(nextMonth, _visibleMonth) &&
        !_isSameMonth(oldWidget.visibleMonth, widget.visibleMonth)) {
      final monthDelta = _monthDifference(_baseMonth, nextMonth);
      final targetPage = _initialPage + monthDelta;
      _visibleMonth = nextMonth;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        _pageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.10),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Text(
                '${_visibleMonth.year}年${_visibleMonth.month}月',
                key: ValueKey(_dateKey(_visibleMonth)),
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Spacer(),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: widget.onCollapse,
              child: Icon(
                CupertinoIcons.chevron_up,
                size: 18,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: ['一', '二', '三', '四', '五', '六', '日']
              .map(
                (day) => Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 318,
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (page) {
              setState(() {
                _visibleMonth = DateTime(
                  _baseMonth.year,
                  _baseMonth.month + (page - _initialPage),
                );
              });
              widget.onVisibleMonthChanged(_visibleMonth);
            },
            itemBuilder: (context, page) {
              final month = DateTime(
                _baseMonth.year,
                _baseMonth.month + (page - _initialPage),
              );
              return _MonthGrid(
                month: month,
                selectedDate: widget.selectedDate,
                datesWithTasks: widget.datesWithTasks,
                onSelected: widget.onSelected,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selectedDate,
    required this.datesWithTasks,
    required this.onSelected,
  });

  final DateTime month;
  final DateTime selectedDate;
  final Set<String> datesWithTasks;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final start = first.subtract(Duration(days: first.weekday - 1));
    final days = List.generate(42, (index) => start.add(Duration(days: index)));
    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: days.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisExtent: 52,
      ),
      itemBuilder: (context, index) {
        final date = days[index];
        final selected = _isSameDate(date, selectedDate);
        final today = _isSameDate(date, DateTime.now());
        final muted = date.month != month.month;
        final hasTask = datesWithTasks.contains(_dateKey(date));
        final label = _SolarLunar.label(date);
        return _MonthDayCell(
          date: date,
          label: label,
          selected: selected,
          today: today,
          muted: muted,
          hasTask: hasTask,
          onTap: () => onSelected(date),
        );
      },
    );
  }
}

class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({
    required this.date,
    required this.label,
    required this.selected,
    required this.today,
    required this.muted,
    required this.hasTask,
    required this.onTap,
  });

  final DateTime date;
  final String label;
  final bool selected;
  final bool today;
  final bool muted;
  final bool hasTask;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
        padding: const EdgeInsets.symmetric(vertical: 3),
        decoration: const BoxDecoration(color: Colors.transparent),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: 2,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: today ? const Color(0xFFFFC23A) : Colors.transparent,
                  border: Border.all(
                    color: selected && !today
                        ? const Color(0xFFFFC23A).withValues(alpha: 0.76)
                        : Colors.transparent,
                    width: selected && !today ? 1.4 : 0,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    color: muted && !today && !selected
                        ? AppColors.muted.withValues(alpha: 0.54)
                        : AppColors.text,
                    fontSize: 15,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            if (hasTask)
              Positioned(
                top: 35,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: today
                        ? const Color(0xFF6D45D9)
                        : const Color(0xFF6374F6),
                    shape: BoxShape.circle,
                  ),
                ),
              )
            else
              Positioned(
                top: 33,
                left: 2,
                right: 2,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: muted && !selected
                        ? const Color(0xFF4FBF9F).withValues(alpha: 0.58)
                        : const Color(0xFF4FBF9F),
                    fontSize: 8,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
