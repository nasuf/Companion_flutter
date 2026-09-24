part of 'package:companion_flutter/main.dart';

class _WeatherMetricGrid extends StatelessWidget {
  const _WeatherMetricGrid({required this.day, required this.current});

  final _WeatherDay day;
  final _WeatherSnapshot? current;

  @override
  Widget build(BuildContext context) {
    final snapshot = day.displaySnapshot(current);
    final items = [
      _WeatherMetricData(
        title: '体感',
        value: '${snapshot.apparentTemperature.round()}℃',
        glyph: _WeatherGlyph.feelsLike,
      ),
      _WeatherMetricData(
        title: '降雨概率',
        value: '${day.maxRainProbability.round()}%',
        glyph: _WeatherGlyph.rain,
      ),
      _WeatherMetricData(
        title: '湿度',
        value: '${snapshot.humidity.round()}%',
        glyph: _WeatherGlyph.humidity,
      ),
      _WeatherMetricData(
        title: '风速',
        value: '${snapshot.windSpeed.round()}km/h',
        glyph: _WeatherGlyph.wind,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 16,
        childAspectRatio: 168 / 88,
      ),
      itemBuilder: (context, index) => _WeatherMetricCard(data: items[index]),
    );
  }
}

class _WeatherMetricData {
  const _WeatherMetricData({
    required this.title,
    required this.value,
    required this.glyph,
  });

  final String title;
  final String value;
  final _WeatherGlyph glyph;
}

/// 指标卡字形，直接用 design 稿导出的白色 PNG（72px = 24pt @3x）。
enum _WeatherGlyph {
  feelsLike('assets/weather/metric_feels.png'),
  rain('assets/weather/metric_rain.png'),
  humidity('assets/weather/metric_humidity.png'),
  wind('assets/weather/metric_wind.png');

  const _WeatherGlyph(this.asset);

  final String asset;
}

/// design 稿的指标图标：48pt 纯蓝圆底 + 24pt 白色字形（四个指标同色）。
///
/// 圆底在代码里画而不是用稿子里的 `Ellipse` 位图——四张导出图逐字节相同，
/// 都是 #4C9BFF 实心圆加一层烘死的投影，画出来既省包体也能随尺寸保持锐利。
class _WeatherMetricIcon extends StatelessWidget {
  const _WeatherMetricIcon({required this.glyph});

  static const _diameter = 48.0;
  static const _glyphSize = 24.0;
  // 与商城/订阅页加深后的主蓝统一（#0A84FF）。
  static const _fill = Color(0xFF0A84FF);

  final _WeatherGlyph glyph;

  @override
  Widget build(BuildContext context) {
    final dark = _W2b.of(context).isDark;
    return Container(
      width: _diameter,
      height: _diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _fill,
        // 深色模式下蓝色辉光糊在暗背景上会脏，只在浅色保留稿子里的投影。
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: _fill.withValues(alpha: 0.30),
                  blurRadius: 9,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Image.asset(glyph.asset, width: _glyphSize, height: _glyphSize),
    );
  }
}

class _WeatherMetricCard extends StatelessWidget {
  const _WeatherMetricCard({required this.data});

  final _WeatherMetricData data;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.of(context);
    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: w.glass,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: w.glassBorder),
        boxShadow: w.panelShadow,
      ),
      child: Row(
        children: [
          _WeatherMetricIcon(glyph: data.glyph),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: w.inkSoft,
                    fontSize: 13,
                    height: 1,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    data.value,
                    style: TextStyle(
                      color: w.ink,
                      fontSize: 20,
                      height: 1,
                      fontWeight: FontWeight.w700,
                    ),
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

class _TodayHourlyHeader extends StatelessWidget {
  const _TodayHourlyHeader({required this.onShowFuture});

  final VoidCallback onShowFuture;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.of(context);
    return Row(
      children: [
        Text(
          '今天',
          style: TextStyle(
            color: w.ink,
            fontSize: 18,
            height: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        CupertinoButton(
          minimumSize: Size.zero,
          padding: EdgeInsets.zero,
          onPressed: onShowFuture,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '未来7天',
                style: TextStyle(
                  color: w.inkSoft,
                  fontSize: 13,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Icon(CupertinoIcons.chevron_right, color: w.inkSoft, size: 13),
            ],
          ),
        ),
      ],
    );
  }
}

class _HourlyWeatherStrip extends StatefulWidget {
  const _HourlyWeatherStrip({required this.day});

  final _WeatherDay day;

  @override
  State<_HourlyWeatherStrip> createState() => _HourlyWeatherStripState();
}

class _HourlyWeatherStripState extends State<_HourlyWeatherStrip> {
  static const double _pillWidth = 68;
  static const double _pillSpacing = 16;

  ScrollController? _scrollController;

  @override
  void dispose() {
    _scrollController?.dispose();
    super.dispose();
  }

  // Start the strip with the current-hour pill in the second visible slot,
  // keeping one pill of past context on the left (clamped at both ends).
  double _initialOffsetFor({
    required int selectedIndex,
    required int itemCount,
    required double viewportWidth,
  }) {
    final contentWidth =
        itemCount * _pillWidth + (itemCount - 1) * _pillSpacing;
    final maxOffset = math.max(0.0, contentWidth - viewportWidth);
    final target = (selectedIndex - 1) * (_pillWidth + _pillSpacing);
    return math.min(math.max(target, 0.0), maxOffset);
  }

  @override
  Widget build(BuildContext context) {
    final hours = widget.day.stripHours;
    if (hours.isEmpty) return const SizedBox.shrink();
    final selectedIndex = _selectedHourIndex(hours);
    return SizedBox(
      height: 136,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _scrollController ??= ScrollController(
            initialScrollOffset: _initialOffsetFor(
              selectedIndex: selectedIndex,
              itemCount: hours.length,
              viewportWidth: constraints.maxWidth,
            ),
          );
          return ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            padding: EdgeInsets.zero,
            itemCount: hours.length,
            separatorBuilder: (_, _) => const SizedBox(width: _pillSpacing),
            itemBuilder: (context, index) {
              return _HourlyWeatherPill(
                hour: hours[index],
                selected: index == selectedIndex,
              );
            },
          );
        },
      ),
    );
  }

  int _selectedHourIndex(List<_WeatherHour> hours) {
    final nowHour = DateTime.now().hour;
    var best = 0;
    var bestDistance = 100;
    for (var i = 0; i < hours.length; i += 1) {
      final distance = (hours[i].time.hour - nowHour).abs();
      if (distance < bestDistance) {
        best = i;
        bestDistance = distance;
      }
    }
    return best;
  }
}

class _HourlyWeatherPill extends StatelessWidget {
  const _HourlyWeatherPill({required this.hour, required this.selected});

  final _WeatherHour hour;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.of(context);
    final foreground = selected ? Colors.white : w.inkSoft;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: 68,
      height: 120,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: selected
            // 选中的天气圆柱：商城同款深蓝渐变（#0A84FF→#1F6FFF）。
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0A84FF), Color(0xFF1F6FFF)],
              )
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [w.hourPillTop, w.hourPillBottom],
              ),
        border: Border.all(
          color: selected ? Colors.transparent : w.hourPillBorder,
        ),
        boxShadow: selected
            ? [
                const BoxShadow(
                  color: Color(0x520A84FF), // #0A84FF @ .32
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ]
            : w.panelShadow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${hour.time.hour.toString().padLeft(2, '0')}:00',
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: foreground,
                  fontSize: 14,
                  height: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 选中态药丸本身是蓝底，图标已有对比，不再叠柔光。
                if (!selected)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [w.hourHalo, w.hourHalo.withValues(alpha: 0)],
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Image.asset(
                    _weatherAsset(hour.weatherCode, hour: hour.time.hour),
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${hour.temperature.round()}℃',
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: foreground,
                  fontSize: 20,
                  height: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FutureWeatherRow extends StatelessWidget {
  const _FutureWeatherRow({required this.day, this.highlight = false});

  final _WeatherDay day;

  /// 「今天」这行走 1a 的蓝色渐变高亮。
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.of(context);
    final title = highlight ? Colors.white : w.ink;
    final subtle = highlight ? Colors.white.withValues(alpha: 0.75) : w.inkSoft;

    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: highlight ? null : w.glass,
        gradient: highlight
            ? LinearGradient(
                // 1a 今日高亮：浅色 #AACDFF→#4B9AFF，深色 #2B5FA8→#123A6B。
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [w.todayA, w.todayB],
              )
            : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight ? Colors.transparent : w.glassBorder,
        ),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: const Color(0xFF0A84FF).withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ]
            : w.panelShadow,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 43,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day.futureTitle,
                  maxLines: 1,
                  style: TextStyle(
                    color: title,
                    fontSize: 16,
                    height: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  day.dateLabel,
                  style: TextStyle(
                    color: subtle,
                    fontSize: 12,
                    height: 1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 32,
            height: 32,
            child: Image.asset(
              _weatherAsset(day.weatherCode, hour: 12),
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 86,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day.weatherText,
                  style: TextStyle(
                    color: title,
                    fontSize: 14,
                    height: 1,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.drop,
                      color: highlight
                          ? Colors.white.withValues(alpha: 0.85)
                          : const Color(0xFF0A84FF).withValues(alpha: 0.70),
                      size: 10,
                    ),
                    Text(
                      '${day.maxRainProbability.round()}%',
                      style: TextStyle(
                        color: subtle,
                        fontSize: 10,
                        height: 1,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      CupertinoIcons.wind,
                      color: highlight
                          ? Colors.white.withValues(alpha: 0.85)
                          : const Color(0xFF0A84FF).withValues(alpha: 0.70),
                      size: 10,
                    ),
                    Flexible(
                      child: Text(
                        '${day.maxWindSpeed.round()}km/h',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: subtle,
                          fontSize: 10,
                          height: 1,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Expanded 给温区一个上界，FittedBox 才能真正 scaleDown；
          // 否则宽温区（如 "24℃ ~ 32℃"）会把这一行撑溢出。
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  children: [
                    Text(
                      '${day.minTemperature.round()}℃',
                      style: TextStyle(
                        color: highlight ? Colors.white : w.forecastMin,
                        fontSize: 20,
                        height: 1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '~',
                      style: TextStyle(
                        color: subtle,
                        fontSize: 20,
                        height: 1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${day.maxTemperature.round()}℃',
                      style: TextStyle(
                        color: highlight ? Colors.white : w.forecastMax,
                        fontSize: 20,
                        height: 1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
