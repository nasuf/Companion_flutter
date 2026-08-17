part of 'package:companion_flutter/main.dart';

class _CapsuleSealedOverlay extends StatefulWidget {
  const _CapsuleSealedOverlay({required this.capsule});

  final TimeCapsule capsule;

  @override
  State<_CapsuleSealedOverlay> createState() => _CapsuleSealedOverlayState();
}

class _CapsuleSealedOverlayState extends State<_CapsuleSealedOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _drop;
  late final Animation<double> _fade;
  late final Animation<double> _sway;
  late final Animation<double> _button;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 980),
    )..forward();
    _drop = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.72, curve: Curves.elasticOut),
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.34, curve: Curves.easeOut),
    );
    _sway = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.28, 1, curve: Curves.easeInOutCubic),
    );
    _button = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 1, curve: Curves.easeOutBack),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The card drops in on the very first frame; without this it spends a
    // frame or two as a bare shadow while the artwork decodes.
    unawaited(
      precacheImage(
        const AssetImage('assets/capsule/sealed-card.png'),
        context,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final sx = size.width / 390;
    final sy = size.height / 844;
    double x(double value) => value * sx;
    double y(double value) => value * sy;
    final date = widget.capsule.openDate;
    return Material(
      color: Colors.black.withValues(alpha: 0.76),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final cardTop = lerpDouble(y(-360), y(143), _drop.value)!;
          final rotation = math.sin(_sway.value * math.pi * 2) * 0.012;
          return Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: _fade.value,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.16),
                        radius: 0.86,
                        colors: [
                          const Color(0xFFFFDA66).withValues(alpha: 0.22),
                          const Color(0xFFFFB52A).withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: y(50),
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: math.max(1.2, x(1.5)),
                    height: math.max(0, cardTop - y(50)),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.70),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFFFFD767,
                          ).withValues(alpha: 0.36),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: cardTop - y(3),
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: x(7),
                    height: x(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC34A),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFFFFD767,
                          ).withValues(alpha: 0.64),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: cardTop,
                left: 0,
                right: 0,
                child: Transform.rotate(
                  angle: rotation,
                  child: Center(
                    child: _SealedTicket(
                      date: date,
                      // The card keeps the design's proportions, so on screens
                      // that are wide for their height the width has to give
                      // way rather than let the card grow into the button.
                      width: math.min(
                        x(282),
                        y(565 - 143 - 24) / _SealedTicket.aspectRatio,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: x(42),
                right: x(42),
                top: y(565),
                child: Transform.scale(
                  scale: _button.value.clamp(0.0, 1.0),
                  child: Opacity(
                    opacity: _button.value.clamp(0.0, 1.0),
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                      child: Container(
                        height: y(56),
                        constraints: const BoxConstraints(minHeight: 52),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.84),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.28),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.42),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '完成',
                          style: TextStyle(
                            color: const Color(0xFF151719),
                            fontSize: math.max(20, x(22)),
                            fontWeight: FontWeight.w900,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
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

/// Year/month/day wheels that only ever list selectable values.
///
/// [CupertinoDatePicker] renders every month and day of the year regardless of
/// `minimumDate` and merely bounces back off the invalid ones, which reads as
/// "the past is offered but refused". Here the lists themselves are clipped to
/// [first]..[last], so today is simply the first row on the wheel.
class _CapsuleDateWheels extends StatefulWidget {
  const _CapsuleDateWheels({
    required this.initial,
    required this.first,
    required this.last,
    required this.textStyle,
    required this.overlayColor,
    required this.onChanged,
  });

  final DateTime initial;
  final DateTime first;
  final DateTime last;
  final TextStyle textStyle;
  final Color overlayColor;
  final ValueChanged<DateTime> onChanged;

  @override
  State<_CapsuleDateWheels> createState() => _CapsuleDateWheelsState();
}

class _CapsuleDateWheelsState extends State<_CapsuleDateWheels> {
  late int _year;
  late int _month;
  late int _day;
  late final FixedExtentScrollController _yearCtrl;
  late final FixedExtentScrollController _monthCtrl;
  late final FixedExtentScrollController _dayCtrl;

  @override
  void initState() {
    super.initState();
    // A caller that seeds a stale draft date must not produce a negative row
    // index, which would take the wheel down with an assertion.
    final seed = widget.initial.isBefore(widget.first)
        ? widget.first
        : (widget.initial.isAfter(widget.last) ? widget.last : widget.initial);
    _year = seed.year;
    _month = seed.month;
    _day = seed.day;
    _yearCtrl = FixedExtentScrollController(
      initialItem: _year - widget.first.year,
    );
    _monthCtrl = FixedExtentScrollController(initialItem: _month - _minMonth);
    _dayCtrl = FixedExtentScrollController(initialItem: _day - _minDay);
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    super.dispose();
  }

  int get _minMonth => _year == widget.first.year ? widget.first.month : 1;
  int get _maxMonth => _year == widget.last.year ? widget.last.month : 12;

  int get _minDay => _year == widget.first.year && _month == widget.first.month
      ? widget.first.day
      : 1;

  int get _maxDay {
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    return _year == widget.last.year && _month == widget.last.month
        ? math.min(widget.last.day, daysInMonth)
        : daysInMonth;
  }

  /// Picking a boundary year or month resizes the wheels to its right, so both
  /// the value and the row index below the change have to be pulled back into
  /// the new range once the shorter list has been laid out.
  void _reclamp() {
    setState(() {
      _month = _month.clamp(_minMonth, _maxMonth);
      _day = _day.clamp(_minDay, _maxDay);
    });
    widget.onChanged(DateTime(_year, _month, _day));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final monthIndex = _month - _minMonth;
      if (_monthCtrl.hasClients && _monthCtrl.selectedItem != monthIndex) {
        _monthCtrl.jumpToItem(monthIndex);
      }
      final dayIndex = _day - _minDay;
      if (_dayCtrl.hasClients && _dayCtrl.selectedItem != dayIndex) {
        _dayCtrl.jumpToItem(dayIndex);
      }
    });
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required List<int> values,
    required String suffix,
    required int column,
    required ValueChanged<int> onChanged,
  }) {
    return Expanded(
      child: CupertinoPicker(
        scrollController: controller,
        itemExtent: 38,
        squeeze: 1.1,
        magnification: 1.06,
        useMagnifier: true,
        backgroundColor: Colors.transparent,
        selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
          background: widget.overlayColor,
          capStartEdge: column == 0,
          capEndEdge: column == 2,
        ),
        onSelectedItemChanged: onChanged,
        children: [
          for (final value in values)
            Center(child: Text('$value$suffix', style: widget.textStyle)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final years = [
      for (var y = widget.first.year; y <= widget.last.year; y++) y,
    ];
    final months = [for (var m = _minMonth; m <= _maxMonth; m++) m];
    final days = [for (var d = _minDay; d <= _maxDay; d++) d];
    return Row(
      children: [
        _wheel(
          controller: _yearCtrl,
          values: years,
          suffix: '年',
          column: 0,
          onChanged: (index) {
            _year = years[index];
            _reclamp();
          },
        ),
        _wheel(
          controller: _monthCtrl,
          values: months,
          suffix: '月',
          column: 1,
          // The wheel can report a stale index for one frame after the list
          // shrinks; the post-frame jump in _reclamp settles it.
          onChanged: (index) {
            if (index < months.length) _month = months[index];
            _reclamp();
          },
        ),
        _wheel(
          controller: _dayCtrl,
          values: days,
          suffix: '日',
          column: 2,
          onChanged: (index) {
            if (index < days.length) _day = days[index];
            _reclamp();
          },
        ),
      ],
    );
  }
}

class _SealedTicket extends StatelessWidget {
  const _SealedTicket({required this.date, required this.width});

  /// The frame the artwork was cut from, in its own pixels. Anything the live
  /// sentence has to line up with — the divider above it, the jar it tucks
  /// into — is baked into the asset, so the placement below is written as
  /// fractions of this frame instead of round numbers.
  static const double _artWidth = 840;
  static const double _artHeight = 1004;
  static const double aspectRatio = _artHeight / _artWidth;

  /// Design-space geometry of the two body lines the asset had painted out.
  static const double _bodyBlockTop = 615;
  static const double _bodyLinePitch = 74;
  static const double _bodyFontSize = 49;

  final DateTime? date;
  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width * aspectRatio;
    final dateLabel = date == null ? '未来某天' : _formatCapsuleDate(date!);
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(width * 100 / _artWidth),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFC94E).withValues(alpha: 0.30),
                    blurRadius: 44,
                  ),
                  BoxShadow(
                    color: const Color(0xFF6B4600).withValues(alpha: 0.22),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
            ),
          ),
          // Everything static — gradient, inset groove, clouds, jar, sparkles,
          // lock badge, title, divider — is one cut of the design so the card
          // matches it exactly instead of approximating it in paint calls.
          Positioned.fill(
            child: Image.asset(
              'assets/capsule/sealed-card.png',
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
            ),
          ),
          Positioned(
            top: height * (_bodyBlockTop / _artHeight),
            left: width * 0.08,
            right: width * 0.08,
            child: Text.rich(
              textAlign: TextAlign.center,
              // The title above and the scenery below are pixels, so growing
              // this one sentence with the system text size would push it into
              // the clouds instead of making the card readable.
              textScaler: TextScaler.noScaling,
              TextSpan(
                style: TextStyle(
                  color: const Color(0xFF3D2607),
                  fontSize: width * (_bodyFontSize / _artWidth),
                  height: _bodyLinePitch / _bodyFontSize,
                  // Even leading keeps the glyphs centred in the line box, so
                  // the block lands where the painted-out one used to sit.
                  leadingDistribution: TextLeadingDistribution.even,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
                children: [
                  const TextSpan(text: '时间胶囊已经封存，\n期待'),
                  TextSpan(
                    text: dateLabel,
                    style: const TextStyle(color: Color(0xFFB56E00)),
                  ),
                  const TextSpan(text: '开启。'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CapsuleReadyOverlay extends StatefulWidget {
  const _CapsuleReadyOverlay({required this.capsule});

  final TimeCapsule capsule;

  @override
  State<_CapsuleReadyOverlay> createState() => _CapsuleReadyOverlayState();
}

class _CapsuleReadyOverlayState extends State<_CapsuleReadyOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _entrance;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    )..forward();
    _entrance = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // The route owns the fade in/out (see chat_page's showGeneralDialog), so
  // dismissing only has to pop; there is no exit animation to await here.
  void _dismiss({required bool open}) {
    if (_dismissed) return;
    _dismissed = true;
    Navigator.of(context).pop(open);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = constraints.maxWidth / _capsuleDesignWidth;
          double x(double value) => value * scale;
          return Stack(
            children: [
              // Design "Rectangle 245" — a flat 70% black scrim. Tapping it is the
              // same "look later" exit as the close button.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _dismiss(open: false),
                  child: const ColoredBox(color: Color(0xB3000000)),
                ),
              ),
              Center(
                // Design puts the postcard + buttons group at y=238..571 of the
                // 844 canvas, which is 17.5 above the vertical centre.
                child: Transform.translate(
                  offset: Offset(0, -x(17.5)),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) => Transform.scale(
                      scale: 0.92 + 0.08 * _entrance.value,
                      child: child,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ReadyPostcard(
                          capsule: widget.capsule,
                          scale: scale,
                          onClose: () => _dismiss(open: false),
                        ),
                        SizedBox(height: x(36)),
                        // Design y=541: two 124x30 pills with a 24 gutter, which
                        // centres the pair on the canvas.
                        SizedBox(
                          width: x(272),
                          child: Row(
                            children: [
                              Expanded(
                                child: _ReadyActionPill(
                                  label: '稍后再看',
                                  scale: scale,
                                  filled: false,
                                  onTap: () => _dismiss(open: false),
                                ),
                              ),
                              SizedBox(width: x(24)),
                              Expanded(
                                child: _ReadyActionPill(
                                  label: '立即查看',
                                  scale: scale,
                                  filled: true,
                                  onTap: () => _dismiss(open: true),
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
            ],
          );
        },
      ),
    );
  }
}

class _ReadyPostcard extends StatelessWidget {
  const _ReadyPostcard({
    required this.capsule,
    required this.scale,
    required this.onClose,
  });

  final TimeCapsule capsule;
  final double scale;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    double x(double value) => value * scale;
    final sealedAt = capsule.sealedAt ?? capsule.createdAt;
    // The 20pt gutter on both sides makes the 324-wide card land on the
    // design's x=33 while leaving room for the close button's overhang.
    return SizedBox(
      width: x(364),
      height: x(267),
      child: Stack(
        children: [
          Positioned(
            left: x(20),
            top: x(20),
            width: x(324),
            height: x(247),
            // Swallow taps: the scrim behind treats a tap as "look later",
            // and hitting the artwork itself should not close the card.
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: Image.asset(
                _capsuleAssetArrivedPostcard,
                fit: BoxFit.contain,
              ),
            ),
          ),
          // Design "Frame 363" at (72, 427) — the only dynamic copy; the
          // heading and illustration are baked into the postcard artwork.
          Positioned(
            left: x(59),
            top: x(189),
            width: x(150),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '《${capsule.displayTitle}》',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _capsuleInk,
                    fontSize: x(14),
                    height: 17 / 14,
                    fontWeight: FontWeight.w400,
                    decoration: TextDecoration.none,
                  ),
                ),
                SizedBox(height: x(4)),
                Text(
                  '封存于${_formatCapsuleDate(sealedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF999999),
                    fontSize: x(10),
                    height: 12 / 10,
                    fontWeight: FontWeight.w400,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          // Design "close" sits detached off the card's top-right corner
          // (x=353/y=238 against a card at 33..357/258..505). The 44pt tap
          // target grows inwards so the glyph keeps that exact slot.
          Positioned(
            right: 0,
            top: 0,
            child: CupertinoButton(
              minimumSize: Size.zero,
              padding: EdgeInsets.zero,
              onPressed: onClose,
              child: SizedBox(
                width: x(44),
                height: x(44),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Image.asset(
                    _capsuleAssetDialogClose,
                    width: x(24),
                    height: x(24),
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

class _ReadyActionPill extends StatelessWidget {
  const _ReadyActionPill({
    required this.label,
    required this.scale,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final double scale;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    double x(double value) => value * scale;
    // Design "Rectangle 243/244": #F29048 fill vs 1px #F29048 outline.
    const accent = Color(0xFFF29048);
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        height: x(30),
        decoration: BoxDecoration(
          color: filled ? accent : Colors.transparent,
          border: filled ? null : Border.all(color: accent),
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: filled ? Colors.white.withValues(alpha: 0.9) : accent,
            fontSize: x(14),
            height: 17 / 14,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
