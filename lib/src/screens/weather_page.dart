part of 'package:companion_flutter/main.dart';

class WeatherPage extends StatefulWidget {
  const WeatherPage({
    super.key,
    required this.api,
    required this.agentName,
    this.agentId,
    this.initialCity,
  });

  final CompanionApi api;
  final String? agentId;
  final String agentName;
  final String? initialCity;

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathController;
  late Future<_WeatherForecast> _forecast;
  int _selectedDay = 0;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8200),
    )..repeat(reverse: true);
    _forecast = _loadForecast();
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _forecast = _loadForecast();
    });
  }

  Future<_WeatherForecast> _loadForecast() async {
    var city = widget.initialCity;
    final agentId = widget.agentId;
    if (agentId != null && agentId.isNotEmpty) {
      try {
        final agent = await widget.api.getAgent(agentId);
        city = agent.city ?? city;
      } catch (_) {
        // 登录态里的城市足够作为天气兜底；失败时不阻塞天气页呈现。
      }
    }
    return _WeatherService.fetchForCity(city);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breathController,
      builder: (context, _) {
        final progress = Curves.easeInOut.transform(_breathController.value);
        return Scaffold(
          backgroundColor: const Color(0xFFF8FBFA),
          body: Stack(
            children: [
              Positioned.fill(child: _WeatherBackground(progress: progress)),
              SafeArea(
                bottom: false,
                child: FutureBuilder<_WeatherForecast>(
                  future: _forecast,
                  builder: (context, snapshot) {
                    final bottom = MediaQuery.paddingOf(context).bottom;
                    if (snapshot.connectionState != ConnectionState.done) {
                      return _WeatherLoading(bottomPadding: bottom);
                    }
                    if (snapshot.hasError || !snapshot.hasData) {
                      return _WeatherError(
                        onRetry: _reload,
                        bottomPadding: bottom,
                      );
                    }
                    final forecast = snapshot.data!;
                    final day = forecast
                        .days[_selectedDay.clamp(0, forecast.days.length - 1)];
                    return ListView(
                      padding: EdgeInsets.fromLTRB(28, 18, 28, bottom + 32),
                      children: [
                        _WeatherTopBar(
                          onBack: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(height: 32),
                        _WeatherHeroCard(
                          day: day,
                          current: forecast.current,
                          location: forecast.location,
                          agentName: widget.agentName,
                          progress: progress,
                        ),
                        const SizedBox(height: 18),
                        _WeatherDayTabs(
                          selectedIndex: _selectedDay,
                          days: forecast.days,
                          onSelected: (value) =>
                              setState(() => _selectedDay = value),
                        ),
                        const SizedBox(height: 18),
                        _WeatherChartCard(day: day),
                        const SizedBox(height: 16),
                        _WeatherInsightGrid(day: day),
                        const SizedBox(height: 16),
                        _WeatherSuggestionRow(day: day),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WeatherTopBar extends StatelessWidget {
  const _WeatherTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _WeatherCircleButton(icon: CupertinoIcons.chevron_left, onTap: onBack),
        const Spacer(),
      ],
    );
  }
}

class _WeatherCircleButton extends StatelessWidget {
  const _WeatherCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF315B88).withValues(alpha: 0.13),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Icon(icon, color: const Color(0xFF111922), size: 27),
      ),
    );
  }
}

class _WeatherBackground extends StatelessWidget {
  const _WeatherBackground({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            const Color(0xFFEFFBFA).withValues(alpha: 0.96),
            const Color(0xFFF8FAFF),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -64 + 10 * progress,
            top: 110 + 8 * progress,
            child: _WeatherBlurBlob(
              size: 248 + 12 * progress,
              color: const Color(
                0xFF1F8FFF,
              ).withValues(alpha: 0.12 + 0.05 * progress),
              radius: 86,
            ),
          ),
          Positioned(
            left: -78 - 7 * progress,
            bottom: 140 - 8 * progress,
            child: _WeatherBlurBlob(
              size: 204 + 10 * progress,
              color: const Color(
                0xFFFFC63D,
              ).withValues(alpha: 0.08 + 0.04 * progress),
              radius: 76,
            ),
          ),
          Positioned(
            right: 34 + 8 * progress,
            bottom: 70 + 7 * progress,
            child: _WeatherBlurBlob(
              size: 156 + 8 * progress,
              color: const Color(
                0xFF18C6C0,
              ).withValues(alpha: 0.08 + 0.04 * progress),
              radius: 60,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherBlurBlob extends StatelessWidget {
  const _WeatherBlurBlob({
    required this.size,
    required this.color,
    required this.radius,
  });

  final double size;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: Container(
        width: size,
        height: size * 0.78,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class _WeatherHeroCard extends StatelessWidget {
  const _WeatherHeroCard({
    required this.day,
    required this.current,
    required this.location,
    required this.agentName,
    required this.progress,
  });

  final _WeatherDay day;
  final _WeatherSnapshot? current;
  final _WeatherLocation location;
  final String agentName;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final snapshot = day.displaySnapshot(current);
    final temp = snapshot.temperature.round();
    final min = day.minTemperature.round();
    final max = day.maxTemperature.round();
    final windLevel = _windLevel(snapshot.windSpeed);
    final advice = _weatherAdvice(day);

    return Container(
      height: 306,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.92),
            const Color(0xFFEAF3FF).withValues(alpha: 0.72),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.80)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF315B88).withValues(alpha: 0.13),
            blurRadius: 34,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.82),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -34,
            bottom: -2,
            child: _WeatherOrb(code: day.weatherCode, progress: progress),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'WEATHER CARD',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 13,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 72,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$temp° ${day.weatherText}，$advice',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 30,
                      height: 1.12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.only(right: 108),
                child: Text(
                  '$agentName所在地 · ${location.displayName}。全天 $min° - $max°，风力 $windLevel 级。',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.muted.withValues(alpha: 0.82),
                    fontSize: 15,
                    height: 1.42,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.only(right: 104),
                child: Row(
                  children: [
                    Expanded(
                      child: _WeatherMetric(
                        value: day.aqiText,
                        label: day.aqi == null ? '降雨' : 'AQI',
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _WeatherMetric(
                        value: '${snapshot.humidity.round()}%',
                        label: '湿度',
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _WeatherMetric(
                        value: '$windLevel级',
                        label: snapshot.windDirection,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeatherMetric extends StatelessWidget {
  const _WeatherMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.57),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
          ),
          child: FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 23,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.muted.withValues(alpha: 0.72),
                    fontSize: 12,
                    height: 1,
                    fontWeight: FontWeight.w700,
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

class _WeatherOrb extends StatelessWidget {
  const _WeatherOrb({required this.code, required this.progress});

  final int code;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final wave = (math.sin(progress * math.pi * 2) + 1) / 2;
    final scale = lerpDouble(0.96, 1.045, wave)!;
    final opacity = lerpDouble(0.78, 0.98, wave)!;
    return SizedBox(
      width: 150,
      height: 132,
      child: Transform.translate(
        offset: Offset(4 * wave, -5 * wave),
        child: Transform.rotate(
          angle: (7 + 2.4 * wave) * math.pi / 180,
          child: Transform.scale(
            scale: scale,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(48),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(
                              0xFF20D2C8,
                            ).withValues(alpha: 0.34 * opacity),
                            AppColors.accent.withValues(alpha: 0.46 * opacity),
                            const Color(
                              0xFF4B7EFF,
                            ).withValues(alpha: 0.38 * opacity),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 100,
                    height: 92,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(34),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(
                            0xFF18C6C0,
                          ).withValues(alpha: 0.74 * opacity),
                          AppColors.accent.withValues(alpha: 0.88 * opacity),
                          const Color(
                            0xFF4B7EFF,
                          ).withValues(alpha: 0.84 * opacity),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(
                            alpha: 0.18 * opacity,
                          ),
                          blurRadius: 30,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 20,
                          top: 16,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.86),
                                  Colors.white.withValues(alpha: 0.13),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 19,
                          bottom: 18,
                          child: Icon(
                            _weatherIcon(code),
                            color: Colors.white.withValues(alpha: 0.90),
                            size: 29,
                          ),
                        ),
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(17),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.32),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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

class _WeatherDayTabs extends StatefulWidget {
  const _WeatherDayTabs({
    required this.selectedIndex,
    required this.days,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<_WeatherDay> days;
  final ValueChanged<int> onSelected;

  @override
  State<_WeatherDayTabs> createState() => _WeatherDayTabsState();
}

class _WeatherDayTabsState extends State<_WeatherDayTabs> {
  static const _gap = 4.0;
  static const _itemWidth = 72.0;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void didUpdateWidget(covariant _WeatherDayTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.days.length != widget.days.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;
    final selected = widget.selectedIndex.clamp(0, widget.days.length - 1);
    final max = _scrollController.position.maxScrollExtent;
    final target = math.max(0.0, (selected - 3) * (_itemWidth + _gap));
    _scrollController.animateTo(
      target.clamp(0.0, max),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 120) return;
        final next = velocity < 0
            ? widget.selectedIndex + 1
            : widget.selectedIndex - 1;
        widget.onSelected(next.clamp(0, widget.days.length - 1).toInt());
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 58,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: Colors.white.withValues(alpha: 0.58),
              border: Border.all(color: Colors.white.withValues(alpha: 0.76)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF315B88).withValues(alpha: 0.07),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.70),
                  blurRadius: 1,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final count = math.max(1, widget.days.length);
                final contentWidth = math.max(
                  constraints.maxWidth,
                  count * _itemWidth + (count - 1) * _gap,
                );
                final selected = widget.selectedIndex.clamp(0, count - 1);
                final left = selected * (_itemWidth + _gap);
                return SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: SizedBox(
                    width: contentWidth,
                    height: 48,
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          left: left,
                          top: 0,
                          bottom: 0,
                          width: _itemWidth,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(23),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF1F6FFF), Color(0xFF18C6C0)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accent.withValues(
                                    alpha: 0.14,
                                  ),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            for (
                              var index = 0;
                              index < widget.days.length;
                              index += 1
                            ) ...[
                              SizedBox(
                                width: _itemWidth,
                                child: _WeatherDateTab(
                                  day: widget.days[index],
                                  selected: widget.selectedIndex == index,
                                  onTap: () => widget.onSelected(index),
                                ),
                              ),
                              if (index != widget.days.length - 1)
                                const SizedBox(width: _gap),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _WeatherDateTab extends StatelessWidget {
  const _WeatherDateTab({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final _WeatherDay day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: SizedBox(
        height: 48,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.text,
            fontSize: 14,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(day.dateLabel, maxLines: 1),
              const SizedBox(height: 5),
              Text(
                day.weekdayLabel,
                maxLines: 1,
                style: TextStyle(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.76)
                      : AppColors.muted.withValues(alpha: 0.66),
                  fontSize: 10,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on DateTime {
  String get _weatherDateLabel => '$month/${day.toString().padLeft(2, '0')}';

  String get _weatherWeekdayLabel {
    const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return labels[weekday - 1];
  }
}

class _WeatherChartCard extends StatelessWidget {
  const _WeatherChartCard({required this.day});

  final _WeatherDay day;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 156,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.73),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF315B88).withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                '温度曲线',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              _LegendDot(color: AppColors.accent, label: '气温'),
              const SizedBox(width: 10),
              const _LegendDot(color: Color(0xFF22C66B), label: '降雨'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: CustomPaint(
              painter: _WeatherCurvePainter(hours: day.chartHours),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: AppColors.muted.withValues(alpha: 0.72),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _WeatherInsightGrid extends StatelessWidget {
  const _WeatherInsightGrid({required this.day});

  final _WeatherDay day;

  @override
  Widget build(BuildContext context) {
    final snapshot = day.displaySnapshot(null);
    final items = [
      (
        '体感',
        '${snapshot.apparentTemperature.round()}°',
        CupertinoIcons.thermometer,
      ),
      (
        '降雨概率',
        '${day.maxRainProbability.round()}%',
        CupertinoIcons.cloud_rain_fill,
      ),
      ('湿度', '${snapshot.humidity.round()}%', CupertinoIcons.drop_fill),
      ('风速', '${snapshot.windSpeed.round()} km/h', CupertinoIcons.wind),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.78,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.80)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF315B88).withValues(alpha: 0.07),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(item.$3, color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.$1,
                      style: TextStyle(
                        color: AppColors.muted.withValues(alpha: 0.78),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: Text(
                        item.$2,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
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
}

class _WeatherSuggestionRow extends StatelessWidget {
  const _WeatherSuggestionRow({required this.day});

  final _WeatherDay day;

  @override
  Widget build(BuildContext context) {
    final event = day.suggestionEvent;
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.80)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF315B88).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFDCEBFF),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              event.hour,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  event.subtitle,
                  style: TextStyle(
                    color: AppColors.muted.withValues(alpha: 0.82),
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${event.temperature.round()}°',
            style: TextStyle(
              color: AppColors.muted.withValues(alpha: 0.82),
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherLoading extends StatelessWidget {
  const _WeatherLoading({required this.bottomPadding});

  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(28, 18, 28, bottomPadding + 32),
      children: [
        _WeatherTopBar(onBack: () => Navigator.of(context).maybePop()),
        const SizedBox(height: 72),
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.78),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
            ),
            child: const CupertinoActivityIndicator(radius: 16),
          ),
        ),
      ],
    );
  }
}

class _WeatherError extends StatelessWidget {
  const _WeatherError({required this.onRetry, required this.bottomPadding});

  final VoidCallback onRetry;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(28, 18, 28, bottomPadding + 32),
      children: [
        _WeatherTopBar(onBack: () => Navigator.of(context).maybePop()),
        const SizedBox(height: 42),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '天气暂时没有回来',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '网络或天气服务短暂波动，稍后再试就好。',
                style: TextStyle(
                  color: AppColors.muted.withValues(alpha: 0.82),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onRetry,
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text(
                    '重新加载',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeatherCurvePainter extends CustomPainter {
  const _WeatherCurvePainter({required this.hours});

  final List<_WeatherHour> hours;

  @override
  void paint(Canvas canvas, Size size) {
    if (hours.length < 2) return;

    final chartRect = Rect.fromLTWH(8, 8, size.width - 16, size.height - 24);
    final gridPaint = Paint()
      ..color = const Color(0xFFDCE7F1).withValues(alpha: 0.46)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i += 1) {
      final y = chartRect.top + chartRect.height * i / 3;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    final temps = hours.map((h) => h.temperature).toList();
    final minTemp = temps.reduce(math.min);
    final maxTemp = temps.reduce(math.max);
    final span = math.max(1, maxTemp - minTemp);

    Offset tempPoint(int index) {
      final hour = hours[index];
      final x = chartRect.left + chartRect.width * index / (hours.length - 1);
      final normalized = (hour.temperature - minTemp) / span;
      final y = chartRect.bottom - normalized * chartRect.height;
      return Offset(x, y);
    }

    Offset rainPoint(int index) {
      final hour = hours[index];
      final x = chartRect.left + chartRect.width * index / (hours.length - 1);
      final y =
          chartRect.bottom -
          (hour.rainProbability.clamp(0, 100) / 100) * chartRect.height;
      return Offset(x, y);
    }

    final tempPath = _smoothPath(List.generate(hours.length, tempPoint));
    final rainPath = _smoothPath(List.generate(hours.length, rainPoint));

    final tempShadow = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(tempPath, tempShadow);

    final tempPaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(tempPath, tempPaint);

    final rainPaint = Paint()
      ..color = const Color(0xFF22C66B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    _drawDashedPath(canvas, rainPath, rainPaint);

    final labelPaint = TextPainter(textDirection: TextDirection.ltr);
    final labelStyle = TextStyle(
      color: AppColors.muted.withValues(alpha: 0.58),
      fontSize: 10,
      fontWeight: FontWeight.w700,
    );
    for (final index in [0, hours.length ~/ 2, hours.length - 1]) {
      final point = tempPoint(index);
      labelPaint.text = TextSpan(
        text: '${hours[index].time.hour}:00',
        style: labelStyle,
      );
      labelPaint.layout();
      labelPaint.paint(
        canvas,
        Offset(point.dx - labelPaint.width / 2, size.height - 12),
      );
    }
  }

  Path _smoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i += 1) {
      final current = points[i];
      final next = points[i + 1];
      final control = Offset((current.dx + next.dx) / 2, current.dy);
      final control2 = Offset((current.dx + next.dx) / 2, next.dy);
      path.cubicTo(
        control.dx,
        control.dy,
        control2.dx,
        control2.dy,
        next.dx,
        next.dy,
      );
    }
    return path;
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + 8, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += 14;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherCurvePainter oldDelegate) {
    return oldDelegate.hours != hours;
  }
}

class _WeatherService {
  const _WeatherService._();

  static const _fallbackCity = '杭州';
  static const _fallbackTimezone = 'Asia/Shanghai';
  static const _forecastDays = 10;

  static Future<_WeatherForecast> fetchForCity(String? city) async {
    final location = await _resolveLocation(city);
    final forecastUri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': location.latitude.toString(),
      'longitude': location.longitude.toString(),
      'timezone': location.timezone,
      'forecast_days': _forecastDays.toString(),
      'current':
          'temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,wind_direction_10m,apparent_temperature,precipitation',
      'hourly':
          'temperature_2m,relative_humidity_2m,precipitation_probability,weather_code,wind_speed_10m,wind_direction_10m,apparent_temperature',
      'daily':
          'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,wind_speed_10m_max,wind_direction_10m_dominant',
    });

    final weather = await _getJson(forecastUri);
    final aqi = await _fetchAqiByHour(location);
    return _parseForecast(weather, aqi, location);
  }

  static Future<_WeatherLocation> _resolveLocation(String? city) async {
    final candidates = <String>[
      _normalizeCityName(city),
      _fallbackCity,
    ].where((value) => value.isNotEmpty).toSet();

    for (final candidate in candidates) {
      try {
        final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
          'name': candidate,
          'count': '5',
          'language': 'zh',
          'format': 'json',
          'countryCode': 'CN',
        });
        final json = await _getJson(uri);
        final results = json['results'];
        if (results is! List || results.isEmpty) continue;
        final selected = results.whereType<Map<String, dynamic>>().firstWhere(
          (item) => item['country_code'] == 'CN',
          orElse: () => results.whereType<Map<String, dynamic>>().first,
        );
        final latitude = _asDouble(selected['latitude']);
        final longitude = _asDouble(selected['longitude']);
        if (latitude == 0 && longitude == 0) continue;
        final name = (selected['name'] as String?)?.trim();
        final timezone = (selected['timezone'] as String?)?.trim();
        return _WeatherLocation(
          displayName: name == null || name.isEmpty ? candidate : name,
          latitude: latitude,
          longitude: longitude,
          timezone: timezone == null || timezone.isEmpty
              ? _fallbackTimezone
              : timezone,
        );
      } catch (_) {
        continue;
      }
    }

    return const _WeatherLocation(
      displayName: _fallbackCity,
      latitude: 30.29365,
      longitude: 120.16142,
      timezone: _fallbackTimezone,
    );
  }

  static String _normalizeCityName(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return '';
    final parts = raw
        .split(RegExp(r'[\s,，、/]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      final second = _stripAdministrativeTail(parts[1]);
      if (second.isNotEmpty) return second;
    }

    final compact = raw.replaceAll(RegExp(r'[\s,，、/]+'), '');
    final cityIndex = compact.indexOf('市');
    if (cityIndex > 0) {
      final beforeCity = compact.substring(0, cityIndex);
      final boundaryEnd = _lastProvinceBoundaryEnd(beforeCity);
      final city = beforeCity.substring(boundaryEnd + 1);
      final normalized = _stripAdministrativeTail(city);
      if (normalized.isNotEmpty) return normalized;
    }

    for (final suffix in const ['自治州', '地区', '盟']) {
      final index = compact.indexOf(suffix);
      if (index > 0) {
        final before = compact.substring(0, index);
        final boundaryEnd = _lastProvinceBoundaryEnd(before);
        final city = before.substring(boundaryEnd + 1);
        if (city.isNotEmpty) return city;
      }
    }

    final boundaryEnd = _lastProvinceBoundaryEnd(compact);
    if (boundaryEnd >= 0 && boundaryEnd < compact.length - 1) {
      final city = _stripAdministrativeTail(compact.substring(boundaryEnd + 1));
      if (city.isNotEmpty) return city;
    }

    return _stripAdministrativeTail(compact);
  }

  static int _lastProvinceBoundaryEnd(String value) {
    var result = -1;
    for (final marker in const ['特别行政区', '自治区', '省']) {
      final index = value.lastIndexOf(marker);
      if (index >= 0) result = math.max(result, index + marker.length - 1);
    }
    return result;
  }

  static String _stripAdministrativeTail(String value) {
    var result = value.trim();
    for (final suffix in const ['市', '地区', '盟', '自治州']) {
      if (result.endsWith(suffix) && result.length > suffix.length) {
        result = result.substring(0, result.length - suffix.length);
      }
    }
    for (final marker in const ['区', '县', '街道', '镇', '乡']) {
      final index = result.indexOf(marker);
      if (index > 1) return result.substring(0, index);
    }
    return result;
  }

  static Future<Map<String, double>> _fetchAqiByHour(
    _WeatherLocation location,
  ) async {
    final uri = Uri.https('air-quality-api.open-meteo.com', '/v1/air-quality', {
      'latitude': location.latitude.toString(),
      'longitude': location.longitude.toString(),
      'timezone': location.timezone,
      'forecast_days': _forecastDays.toString(),
      'hourly': 'us_aqi',
    });

    try {
      final json = await _getJson(uri);
      final hourly = json['hourly'] as Map<String, dynamic>?;
      final times = _stringList(hourly?['time']);
      final values = _numList(hourly?['us_aqi']);
      final result = <String, double>{};
      for (var i = 0; i < math.min(times.length, values.length); i += 1) {
        final value = values[i];
        if (value != null) result[times[i]] = value;
      }
      return result;
    } catch (_) {
      return const {};
    }
  }

  static Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      final body = await utf8.decodeStream(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Weather API ${response.statusCode}: $body',
          uri: uri,
        );
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Unexpected weather response');
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  static _WeatherForecast _parseForecast(
    Map<String, dynamic> json,
    Map<String, double> aqiByHour,
    _WeatherLocation location,
  ) {
    final currentJson = json['current'] as Map<String, dynamic>?;
    final current = currentJson == null
        ? null
        : _WeatherSnapshot(
            temperature: _asDouble(currentJson['temperature_2m']),
            apparentTemperature: _asDouble(currentJson['apparent_temperature']),
            humidity: _asDouble(currentJson['relative_humidity_2m']),
            weatherCode: _asInt(currentJson['weather_code']),
            windSpeed: _asDouble(currentJson['wind_speed_10m']),
            windDirection: _windDirection(
              _asDouble(currentJson['wind_direction_10m']),
            ),
          );

    final hourly = json['hourly'] as Map<String, dynamic>?;
    final hourlyTimes = _stringList(hourly?['time']);
    final hourlyTemps = _numList(hourly?['temperature_2m']);
    final hourlyFeels = _numList(hourly?['apparent_temperature']);
    final hourlyHumidity = _numList(hourly?['relative_humidity_2m']);
    final hourlyRain = _numList(hourly?['precipitation_probability']);
    final hourlyCodes = _numList(hourly?['weather_code']);
    final hourlyWind = _numList(hourly?['wind_speed_10m']);
    final hourlyDirection = _numList(hourly?['wind_direction_10m']);

    final hoursByDay = <String, List<_WeatherHour>>{};
    for (var i = 0; i < hourlyTimes.length; i += 1) {
      final time = DateTime.parse(hourlyTimes[i]);
      final key = _dateKey(time);
      final hour = _WeatherHour(
        time: time,
        temperature: hourlyTemps.elementAtOrNull(i) ?? 0,
        apparentTemperature:
            hourlyFeels.elementAtOrNull(i) ??
            hourlyTemps.elementAtOrNull(i) ??
            0,
        humidity: hourlyHumidity.elementAtOrNull(i) ?? 0,
        rainProbability: hourlyRain.elementAtOrNull(i) ?? 0,
        weatherCode: (hourlyCodes.elementAtOrNull(i) ?? 0).round(),
        windSpeed: hourlyWind.elementAtOrNull(i) ?? 0,
        windDirection: _windDirection(hourlyDirection.elementAtOrNull(i) ?? 0),
        aqi: aqiByHour[hourlyTimes[i]],
      );
      hoursByDay.putIfAbsent(key, () => []).add(hour);
    }

    final daily = json['daily'] as Map<String, dynamic>?;
    final dates = _stringList(daily?['time']);
    final maxTemps = _numList(daily?['temperature_2m_max']);
    final minTemps = _numList(daily?['temperature_2m_min']);
    final rain = _numList(daily?['precipitation_probability_max']);
    final codes = _numList(daily?['weather_code']);
    final wind = _numList(daily?['wind_speed_10m_max']);
    final windDirection = _numList(daily?['wind_direction_10m_dominant']);

    final days = <_WeatherDay>[];
    for (var i = 0; i < math.min(_forecastDays, dates.length); i += 1) {
      final date = DateTime.parse(dates[i]);
      final hours = hoursByDay[_dateKey(date)] ?? const <_WeatherHour>[];
      final code =
          (codes.elementAtOrNull(i) ??
                  (hours.isEmpty ? 0 : hours.first.weatherCode))
              .round();
      days.add(
        _WeatherDay(
          index: i,
          date: date,
          weatherCode: code,
          minTemperature: minTemps.elementAtOrNull(i) ?? _minHour(hours),
          maxTemperature: maxTemps.elementAtOrNull(i) ?? _maxHour(hours),
          maxRainProbability: rain.elementAtOrNull(i) ?? _maxRain(hours),
          maxWindSpeed: wind.elementAtOrNull(i) ?? _maxWind(hours),
          dominantWindDirection: _windDirection(
            windDirection.elementAtOrNull(i) ?? 0,
          ),
          hours: hours,
        ),
      );
    }

    if (days.isEmpty) throw const FormatException('Weather forecast is empty');
    return _WeatherForecast(days: days, current: current, location: location);
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList();
  }

  static List<double?> _numList(Object? value) {
    if (value is! List) return const [];
    return value.map((item) => item is num ? item.toDouble() : null).toList();
  }

  static double _asDouble(Object? value) => value is num ? value.toDouble() : 0;

  static int _asInt(Object? value) => value is num ? value.round() : 0;

  static String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static double _minHour(List<_WeatherHour> hours) {
    if (hours.isEmpty) return 0;
    return hours.map((h) => h.temperature).reduce(math.min);
  }

  static double _maxHour(List<_WeatherHour> hours) {
    if (hours.isEmpty) return 0;
    return hours.map((h) => h.temperature).reduce(math.max);
  }

  static double _maxRain(List<_WeatherHour> hours) {
    if (hours.isEmpty) return 0;
    return hours.map((h) => h.rainProbability).reduce(math.max);
  }

  static double _maxWind(List<_WeatherHour> hours) {
    if (hours.isEmpty) return 0;
    return hours.map((h) => h.windSpeed).reduce(math.max);
  }
}

class _WeatherLocation {
  const _WeatherLocation({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    required this.timezone,
  });

  final String displayName;
  final double latitude;
  final double longitude;
  final String timezone;
}

class _WeatherForecast {
  const _WeatherForecast({
    required this.days,
    required this.current,
    required this.location,
  });

  final List<_WeatherDay> days;
  final _WeatherSnapshot? current;
  final _WeatherLocation location;
}

class _WeatherDay {
  const _WeatherDay({
    required this.index,
    required this.date,
    required this.weatherCode,
    required this.minTemperature,
    required this.maxTemperature,
    required this.maxRainProbability,
    required this.maxWindSpeed,
    required this.dominantWindDirection,
    required this.hours,
  });

  final int index;
  final DateTime date;
  final int weatherCode;
  final double minTemperature;
  final double maxTemperature;
  final double maxRainProbability;
  final double maxWindSpeed;
  final String dominantWindDirection;
  final List<_WeatherHour> hours;

  String get weatherText => _weatherText(weatherCode);

  String get dateLabel => date._weatherDateLabel;

  String get weekdayLabel => index == 0 ? '今天' : date._weatherWeekdayLabel;

  List<_WeatherHour> get chartHours {
    if (hours.length <= 12) return hours;
    final preferred = hours
        .where((h) => h.time.hour >= 6 && h.time.hour <= 23)
        .toList();
    if (preferred.length <= 12) return preferred;
    return [for (var i = 0; i < preferred.length; i += 2) preferred[i]];
  }

  double? get aqi {
    final valid = hours.map((h) => h.aqi).whereType<double>().toList();
    if (valid.isEmpty) return null;
    return valid.reduce((a, b) => a + b) / valid.length;
  }

  String get aqiText {
    final value = aqi;
    if (value == null) return '${maxRainProbability.round()}%';
    return value.round().toString();
  }

  _WeatherSnapshot displaySnapshot(_WeatherSnapshot? current) {
    if (index == 0 && current != null) return current;
    final targetHour = index == 0 ? DateTime.now().hour : 14;
    final hour = hours.isEmpty
        ? null
        : hours.reduce((a, b) {
            final aDistance = (a.time.hour - targetHour).abs();
            final bDistance = (b.time.hour - targetHour).abs();
            return aDistance <= bDistance ? a : b;
          });
    if (hour == null) {
      return _WeatherSnapshot(
        temperature: (minTemperature + maxTemperature) / 2,
        apparentTemperature: (minTemperature + maxTemperature) / 2,
        humidity: 0,
        weatherCode: weatherCode,
        windSpeed: maxWindSpeed,
        windDirection: dominantWindDirection,
      );
    }
    return _WeatherSnapshot(
      temperature: hour.temperature,
      apparentTemperature: hour.apparentTemperature,
      humidity: hour.humidity,
      weatherCode: hour.weatherCode,
      windSpeed: hour.windSpeed,
      windDirection: hour.windDirection,
    );
  }

  _WeatherSuggestion get suggestionEvent {
    if (hours.isEmpty) {
      return _WeatherSuggestion(
        hour: '14',
        title: '天气稳定',
        subtitle: '适合把当天安排轻轻排开，小芜会继续看着天气。',
        temperature: (minTemperature + maxTemperature) / 2,
      );
    }

    final evening = hours
        .where((h) => h.time.hour >= 17 && h.time.hour <= 20)
        .toList();
    if (evening.isNotEmpty) {
      final first = evening.first;
      final last = evening.last;
      if (first.temperature - last.temperature >= 2) {
        return _WeatherSuggestion(
          hour: first.time.hour.toString(),
          title: '${first.time.hour}:00 降温',
          subtitle: '出门建议薄外套，小芜会在傍晚前提醒。',
          temperature: last.temperature,
        );
      }
    }

    final rainHour = hours
        .where((h) => h.rainProbability >= 45)
        .fold<_WeatherHour?>(null, (prev, h) => prev ?? h);
    if (rainHour != null) {
      return _WeatherSuggestion(
        hour: rainHour.time.hour.toString(),
        title: '${rainHour.time.hour}:00 可能有雨',
        subtitle: '记得带伞，行程可以稍微留一点缓冲。',
        temperature: rainHour.temperature,
      );
    }

    final midday = displaySnapshot(null);
    return _WeatherSuggestion(
      hour: '14',
      title: '14:00 适合出门',
      subtitle: '天气节奏比较平稳，短途散步或采购都可以。',
      temperature: midday.temperature,
    );
  }
}

class _WeatherHour {
  const _WeatherHour({
    required this.time,
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.rainProbability,
    required this.weatherCode,
    required this.windSpeed,
    required this.windDirection,
    required this.aqi,
  });

  final DateTime time;
  final double temperature;
  final double apparentTemperature;
  final double humidity;
  final double rainProbability;
  final int weatherCode;
  final double windSpeed;
  final String windDirection;
  final double? aqi;
}

class _WeatherSnapshot {
  const _WeatherSnapshot({
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.weatherCode,
    required this.windSpeed,
    required this.windDirection,
  });

  final double temperature;
  final double apparentTemperature;
  final double humidity;
  final int weatherCode;
  final double windSpeed;
  final String windDirection;
}

class _WeatherSuggestion {
  const _WeatherSuggestion({
    required this.hour,
    required this.title,
    required this.subtitle,
    required this.temperature,
  });

  final String hour;
  final String title;
  final String subtitle;
  final double temperature;
}

String _weatherText(int code) {
  if (code == 0) return '晴';
  if (code == 1 || code == 2) return '多云';
  if (code == 3) return '阴';
  if (code == 45 || code == 48) return '有雾';
  if (code >= 51 && code <= 67) return '小雨';
  if (code >= 71 && code <= 77) return '有雪';
  if (code >= 80 && code <= 82) return '阵雨';
  if (code >= 95) return '雷雨';
  return '多云';
}

IconData _weatherIcon(int code) {
  if (code == 0) return CupertinoIcons.sun_max_fill;
  if (code == 1 || code == 2) return CupertinoIcons.cloud_sun_fill;
  if (code == 3) return CupertinoIcons.cloud_fill;
  if (code >= 71 && code <= 77) return CupertinoIcons.snow;
  if (code >= 51 && code <= 82) return CupertinoIcons.cloud_rain_fill;
  if (code >= 95) return CupertinoIcons.cloud_bolt_rain_fill;
  return CupertinoIcons.cloud_fill;
}

String _weatherAdvice(_WeatherDay day) {
  if (day.maxRainProbability >= 55) return '记得带伞';
  if (day.maxTemperature >= 30) return '注意防晒';
  if (day.minTemperature <= 10) return '加件外套';
  if (day.weatherCode == 0 || day.weatherCode == 1 || day.weatherCode == 2) {
    return '适合短途散步';
  }
  return '傍晚适合短途散步';
}

int _windLevel(double speedKmH) {
  final speedMs = speedKmH / 3.6;
  if (speedMs < 0.3) return 0;
  if (speedMs < 1.6) return 1;
  if (speedMs < 3.4) return 2;
  if (speedMs < 5.5) return 3;
  if (speedMs < 8.0) return 4;
  if (speedMs < 10.8) return 5;
  return 6;
}

String _windDirection(double degrees) {
  final normalized = degrees % 360;
  const labels = ['北风', '东北风', '东风', '东南风', '南风', '西南风', '西风', '西北风'];
  final index = ((normalized + 22.5) ~/ 45) % labels.length;
  return labels[index];
}
