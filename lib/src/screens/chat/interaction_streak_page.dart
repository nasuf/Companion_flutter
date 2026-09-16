part of 'package:companion_flutter/main.dart';

const Color _interactionAccent = Color(0xFF06C893);

/// Flame badge index for the current consecutive-day count.
int interactionFlameStage(int days) {
  if (days >= 100) return 5;
  if (days >= 61) return 4;
  if (days >= 32) return 3;
  if (days >= 16) return 2;
  if (days >= 8) return 1;
  return 0;
}

double interactionStageProgress(int days) {
  if (days >= 100) return 1;
  final stage = interactionFlameStage(days);
  final (start, end) = switch (stage) {
    0 => (0, 7),
    1 => (8, 15),
    2 => (16, 31),
    3 => (32, 60),
    4 => (61, 99),
    _ => (100, 100),
  };
  final span = end - start + 1;
  return ((days - start + 1) / span).clamp(0.08, 1).toDouble();
}

/// UTC+8 calendar day. Device TZ is ignored so a traveler's phone cannot
/// shift the interaction ledger relative to the server.
DateTime interactionUtc8Date([DateTime? now]) {
  final utc = (now ?? DateTime.now()).toUtc();
  final shanghai = utc.add(const Duration(hours: 8));
  return DateTime(shanghai.year, shanghai.month, shanghai.day);
}

DateTime? _parseIsoDate(String? raw) {
  final text = (raw ?? '').trim();
  if (text.length < 10) return null;
  return DateTime.tryParse(text.substring(0, 10));
}

class InteractionStreakPage extends StatefulWidget {
  const InteractionStreakPage({
    super.key,
    required this.api,
    required this.session,
    required this.workspaceId,
    required this.agentAvatarUrl,
    required this.userAvatarUrl,
  });

  final CompanionApi api;
  final AuthSession session;
  final String workspaceId;
  final String? agentAvatarUrl;
  final String? userAvatarUrl;

  @override
  State<InteractionStreakPage> createState() => _InteractionStreakPageState();
}

class _InteractionStreakPageState extends State<InteractionStreakPage> {
  late DateTime _selectedDate;
  late DateTime _visibleWeek;
  late DateTime _visibleMonth;
  late DateTime _today;
  bool _calendarExpanded = false;
  bool _applying = false;
  String? _error;
  int _streak = 0;
  int _makeupCards = 0;
  final Map<String, WorkspaceInteractionDay> _days = {};

  @override
  void initState() {
    super.initState();
    _today = interactionUtc8Date();
    _selectedDate = _today;
    _visibleWeek = _weekStart(_today);
    _visibleMonth = _monthOnly(_today);
    unawaited(_load(year: _today.year, month: _today.month, syncToday: true));
  }

  Future<void> _load({int? year, int? month, bool syncToday = false}) async {
    if (widget.workspaceId.isEmpty) {
      setState(() {
        _error = null;
        _streak = 0;
        _makeupCards = 0;
      });
      return;
    }
    setState(() {
      _error = null;
    });
    try {
      final overview = await widget.api.getWorkspaceInteraction(
        widget.workspaceId,
        year: year,
        month: month,
      );
      if (!mounted) return;
      final today = _parseIsoDate(overview.today) ?? _today;
      setState(() {
        _today = today;
        _streak = overview.currentStreak;
        _makeupCards = overview.makeupCards;
        if (syncToday) {
          _selectedDate = today;
          _visibleWeek = _weekStart(today);
          _visibleMonth = _monthOnly(today);
        }
        for (final day in overview.days) {
          _days[day.date] = day;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    }
  }

  _CheckinTokens _tokens(BuildContext context) {
    final dark = AppColors.isDark(context);
    if (dark) {
      return const _CheckinTokens(
        page: Color(0xFF071410),
        card: Color(0xB3172231),
        cardSolid: Color(0xFF141E2B),
        glassBorder: Color(0x33FFFFFF),
        accent: _interactionAccent,
        accentSoft: Color(0x3806C893),
        accentInk: Color(0xFF7DFFD6),
        dayPill: Color(0xFF1B2432),
        noteField: Color(0xFF1B2432),
        markIdle: Color(0xFF3A4658),
        title: Color(0xFFF2F7FB),
        sectionTitle: Color(0xFFE4EBF3),
        subtitle: Color(0xFF9AA8B8),
        placeholder: Color(0xFF7F8B9A),
        dayNumber: Color(0xFFE4EBF3),
        scrim: Color(0xC7000000),
        cardShadowColor: Color(0x99000000),
        navShadowColor: Color(0x99000000),
      );
    }
    return const _CheckinTokens(
      page: Color(0xFFE3FBF4),
      card: Color(0x8CFFFFFF),
      cardSolid: Color(0xFFFCFDFF),
      glassBorder: Color(0xD9FFFFFF),
      accent: _interactionAccent,
      accentSoft: Color(0x3306C893),
      accentInk: Color(0xFF047A5A),
      dayPill: Color(0xFFEEFBF7),
      noteField: Color(0xFFEEFBF7),
      markIdle: Color(0xFFDFDFDF),
      title: Color(0xFF000000),
      sectionTitle: Color(0xFF333333),
      subtitle: Color(0xFF414443),
      placeholder: Color(0xFF888888),
      dayNumber: Color(0xFF000000),
      scrim: Color(0xB3000000),
      cardShadowColor: Color(0x1A06C893),
      navShadowColor: Color(0x4006C893),
    );
  }

  _CheckinDayMark _markFor(DateTime date) {
    final row = _days[_dateKey(date)];
    if (row == null) return _CheckinDayMark.none;
    if (row.source == 'makeup') return _CheckinDayMark.makeup;
    if (row.source != null && row.source!.isNotEmpty) {
      return _CheckinDayMark.done;
    }
    if (row.makeupEligible) return _CheckinDayMark.missable;
    return _CheckinDayMark.none;
  }

  Future<void> _onDaySelected(DateTime date) async {
    if (_applying) return;
    setState(() {
      _selectedDate = date;
      _visibleWeek = _weekStart(date);
      _visibleMonth = _monthOnly(date);
    });
    final row = _days[_dateKey(date)];
    if (row?.makeupEligible == true) {
      await _confirmMakeup(date);
    }
  }

  Future<void> _confirmMakeup(DateTime date) async {
    if (_applying) return;
    if (_makeupCards <= 0) {
      await _promptBuyCards();
      return;
    }
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('补签'),
          content: Text('使用 1 张补签卡补签 ${date.month}月${date.day}日？'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('补签'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await _applyMakeup(date);
  }

  Future<void> _applyMakeup(DateTime date) async {
    setState(() => _applying = true);
    try {
      await widget.api.applyWorkspaceInteractionMakeup(
        widget.workspaceId,
        date: _dateKey(date),
      );
      if (!mounted) return;
      await _load(year: date.year, month: date.month);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 400 && error.message.contains('补签卡不足')) {
        await _promptBuyCards();
      } else {
        _showToast(error.message);
      }
    } catch (error) {
      if (!mounted) return;
      _showToast(error.toString());
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _promptBuyCards() async {
    final goStore = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('补签卡不足'),
          content: const Text('去商店看看补签卡礼包？'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('去商店'),
            ),
          ],
        );
      },
    );
    if (goStore == true && mounted) {
      await _openStore();
    }
  }

  Future<void> _openStore() async {
    await Navigator.of(context).push<void>(
      CompanionPageRoute<void>(
        builder: (_) => StorePage(
          api: widget.api,
          session: widget.session,
          openBundle: true,
        ),
      ),
    );
    if (mounted) {
      await _load(year: _visibleMonth.year, month: _visibleMonth.month);
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  Future<void> _onVisibleMonthChanged(DateTime month) async {
    setState(() => _visibleMonth = month);
    await _load(year: month.year, month: month.month);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = _tokens(context);
    final w = _W2b.resolve(context);
    final stage = interactionFlameStage(_streak);
    return Scaffold(
      backgroundColor: tokens.page,
      body: Stack(
        children: [
          const Positioned.fill(child: _InteractionBackground()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    height: 36,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: KeyedSubtree(
                            key: const Key('interaction-back'),
                            child: _WeatherBackButton(
                              onTap: () => Navigator.of(context).pop(),
                              iconColor: _interactionAccent,
                            ),
                          ),
                        ),
                        Text(
                          '连续互动',
                          style: TextStyle(
                            color: tokens.title,
                            fontSize: 20,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    key: const Key('interaction-scroll'),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _InteractionSummaryCard(
                        agentAvatarUrl: widget.agentAvatarUrl,
                        userAvatarUrl: widget.userAvatarUrl,
                        days: _streak,
                        progress: interactionStageProgress(_streak),
                        stage: stage,
                        glass: w,
                      ),
                      const SizedBox(height: 16),
                      _CheckinCalendarCard(
                        selectedDate: _selectedDate,
                        visibleWeek: _visibleWeek,
                        visibleMonth: _visibleMonth,
                        expanded: _calendarExpanded,
                        markFor: _markFor,
                        onSelected: _onDaySelected,
                        onVisibleWeekChanged: (week) =>
                            setState(() => _visibleWeek = week),
                        onVisibleMonthChanged: _onVisibleMonthChanged,
                        onExpandedChanged: (expanded) =>
                            setState(() => _calendarExpanded = expanded),
                        tokens: tokens,
                        calendarKey: 'interaction-calendar',
                        dayKeyPrefix: 'interaction',
                        today: _today,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: tokens.subtitle,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _InteractionMarksCard(currentStage: stage, glass: w),
                      const SizedBox(height: 20),
                      GestureDetector(
                        key: const Key('interaction-makeup-count'),
                        behavior: HitTestBehavior.opaque,
                        onTap: _makeupCards <= 0 ? _openStore : null,
                        child: Text(
                          '补签卡 x$_makeupCards',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: _makeupCards <= 0
                                ? _interactionAccent
                                : tokens.subtitle,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractionBackground extends StatelessWidget {
  const _InteractionBackground();

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF071410) : const Color(0xFFE3FBF4),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -90,
            top: -72,
            child: _WeatherGlowBlob(
              width: 262,
              height: 232,
              color: dark ? const Color(0xFF1A5C4A) : const Color(0xFFB8F4E4),
              opacity: dark ? 0.5 : 0.9,
            ),
          ),
          Positioned(
            right: -96,
            top: 70,
            child: _WeatherGlowBlob(
              width: 232,
              height: 208,
              color: dark ? const Color(0xFF164A5C) : const Color(0xFFCFF8EA),
              opacity: dark ? 0.42 : 0.82,
            ),
          ),
          Positioned(
            left: -74,
            bottom: -84,
            child: _WeatherGlowBlob(
              width: 252,
              height: 220,
              color: dark ? const Color(0xFF2A4A3F) : const Color(0xFFD4F5E8),
              opacity: dark ? 0.36 : 0.64,
            ),
          ),
          Positioned.fill(
            child: _WeatherGrain(
              dotColor: dark
                  ? const Color(0x24FFFFFF)
                  : const Color(0x59FFFFFF),
              opacity: dark ? 0.6 : 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractionSummaryCard extends StatelessWidget {
  const _InteractionSummaryCard({
    required this.agentAvatarUrl,
    required this.userAvatarUrl,
    required this.days,
    required this.progress,
    required this.stage,
    required this.glass,
  });

  final String? agentAvatarUrl;
  final String? userAvatarUrl;
  final int days;
  final double progress;
  final int stage;
  final _W2b glass;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 183,
      decoration: BoxDecoration(
        color: glass.glass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: glass.glassBorder),
        boxShadow: glass.panelShadow,
      ),
      child: Stack(
        children: [
          Positioned(
            left: 24,
            top: 24,
            child: Column(
              children: [
                SizedBox(
                  width: 120,
                  height: 64,
                  child: Stack(
                    children: [
                      _Avatar(
                        size: 64,
                        label: '我',
                        imageUrl: userAvatarUrl,
                        gradient: const [Color(0xFFE8F3FF), Color(0xFFF8FBFF)],
                      ),
                      Positioned(
                        left: 56,
                        child: _Avatar(
                          size: 64,
                          label: '伴',
                          imageUrl: agentAvatarUrl,
                          gradient: const [
                            Color(0xFFE8F3FF),
                            Color(0xFFDDEBFF),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      '连续互动',
                      style: TextStyle(fontSize: 14, color: Colors.black),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$days',
                      style: const TextStyle(
                        fontSize: 24,
                        height: 1,
                        color: _interactionAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      '天',
                      style: TextStyle(fontSize: 14, color: Colors.black),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            right: 11,
            top: 16,
            child: _CurrentInteractionMark(stage: stage),
          ),
          Positioned(
            left: 24,
            right: 26,
            bottom: 24,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFF51FFD0)),
                    boxShadow: [
                      BoxShadow(
                        color: _interactionAccent.withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
                Positioned.fill(
                  left: 3,
                  right: 3,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: _interactionAccent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  right: -18,
                  top: -16,
                  child: _InteractionMarkIcon(size: 40, stage: 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractionMarksCard extends StatelessWidget {
  const _InteractionMarksCard({
    required this.currentStage,
    required this.glass,
  });

  final int currentStage;
  final _W2b glass;

  static const _ranges = [
    '0-7天',
    '8-15天',
    '16-31天',
    '32-60天',
    '61-99天',
    '100天以上',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 340,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      decoration: BoxDecoration(
        color: glass.glass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: glass.glassBorder),
        boxShadow: glass.panelShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _SectionSparkleIcon(size: 16),
              SizedBox(width: 4),
              Text(
                '连续互动标识',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _ranges.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 24,
                crossAxisSpacing: 24,
                childAspectRatio: 0.82,
              ),
              itemBuilder: (context, index) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _InteractionMarkIcon(size: 84, stage: index),
                    const SizedBox(height: 4),
                    Text(
                      _ranges[index],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: index <= currentStage
                            ? Colors.black
                            : const Color(0xFF5E5E5E),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionSparkleIcon extends StatelessWidget {
  const _SectionSparkleIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SectionSparklePainter()),
    );
  }
}

class _SectionSparklePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.5, 0)
      ..lineTo(size.width * 0.635, size.height * 0.365)
      ..lineTo(size.width, size.height * 0.5)
      ..lineTo(size.width * 0.635, size.height * 0.635)
      ..lineTo(size.width * 0.5, size.height)
      ..lineTo(size.width * 0.365, size.height * 0.635)
      ..lineTo(0, size.height * 0.5)
      ..lineTo(size.width * 0.365, size.height * 0.365)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = _interactionAccent
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _SectionSparklePainter oldDelegate) => false;
}
