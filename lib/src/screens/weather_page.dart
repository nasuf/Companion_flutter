part of 'package:companion_flutter/main.dart';

/// 天气模块「2b 分层玻璃」设计令牌（对齐 design 稿 天气模块重构.dc.html）。
///
/// 2b 原稿有明确的浅色 / 深色两套，所有色值都从 design 内联样式读出。
/// 通过 [_WeatherScope] 注入，页面里的组件用 [_W2b.of] 取当前配色，
/// 跟随「我的」里的深色模式开关（`Theme.of(context).brightness`）切换。
@immutable
class _W2b {
  const _W2b({
    required this.isDark,
    required this.base,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.glass,
    required this.glassBorder,
    required this.heroChipBg,
    required this.heroChipBorder,
    required this.panelShadow,
    required this.pillShadow,
    required this.heroHalo,
    required this.hourPillTop,
    required this.hourPillBottom,
    required this.hourPillBorder,
    required this.hourHalo,
    required this.todayA,
    required this.todayB,
    required this.forecastMin,
    required this.forecastMax,
  });

  final bool isDark;

  /// 页面底色，柔光渐层铺在其上。
  final Color base;

  final Color ink; // 主文字
  final Color inkSoft; // 次级文字 rgba(.55)
  final Color inkFaint; // 更弱文字

  final Color glass; // 玻璃面板 / 药丸底
  final Color glassBorder;
  final Color heroChipBg; // 主视觉下方信息药丸
  final Color heroChipBorder;

  final List<BoxShadow> panelShadow; // 大面板 / 卡片
  final BoxShadow pillShadow; // 返回键 / 定位药丸

  /// 主视觉图标背后的柔光（浅色=白，深色=蓝），alpha 已烘进颜色。
  final Color heroHalo;

  // 小时药丸：浅色用「白→浅蓝」把图标边缘压出来；深色用半透明玻璃。
  final Color hourPillTop;
  final Color hourPillBottom;
  final Color hourPillBorder;
  final Color hourHalo;

  // 未来 7 天「今天」行的 1a 高亮渐变（浅/深各一套）。
  final Color todayA;
  final Color todayB;
  final Color forecastMin;
  final Color forecastMax;

  static const light = _W2b(
    isDark: false,
    base: Color(0xFFE9F0FB),
    ink: Color(0xFF12283F),
    inkSoft: Color(0x8C12283F), // rgba(18,40,63,.55)
    inkFaint: Color(0x8012283F), // rgba(18,40,63,.50)
    glass: Color(0x8CFFFFFF), // rgba(255,255,255,.55)
    glassBorder: Color(0xD9FFFFFF), // rgba(255,255,255,.85)
    heroChipBg: Color(0x80FFFFFF), // rgba(255,255,255,.50)
    heroChipBorder: Color(0xCCFFFFFF), // rgba(255,255,255,.80)
    panelShadow: [
      BoxShadow(
        color: Color(0x241E467C), // rgba(30,70,124,.14)
        blurRadius: 32,
        offset: Offset(0, 16),
      ),
    ],
    pillShadow: BoxShadow(
      color: Color(0x1A234878), // rgba(35,72,120,.10)
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
    heroHalo: Color(0xD9FFFFFF), // white .85
    hourPillTop: Color(0xC7FFFFFF), // white .78
    hourPillBottom: Color(0xF0D6E4F8), // #D6E4F8 @ .94
    hourPillBorder: Color(0xD9FFFFFF),
    hourHalo: Color(0x2E4B9AFF), // #4B9AFF @ .18
    todayA: Color(0xFFAACDFF),
    todayB: Color(0xFF4B9AFF),
    forecastMin: Color(0xFF4193FD),
    forecastMax: Color(0xFFFE9D0B),
  );

  static const dark = _W2b(
    isDark: true,
    base: Color(0xFF070C14),
    ink: Color(0xFFF2F7FB),
    inkSoft: Color(0x80F2F7FB), // rgba(242,247,251,.50)
    inkFaint: Color(0x66F2F7FB), // rgba(242,247,251,.40)
    glass: Color(0x14FFFFFF), // rgba(255,255,255,.08)
    glassBorder: Color(0x24FFFFFF), // rgba(255,255,255,.14)
    heroChipBg: Color(0x14FFFFFF), // rgba(255,255,255,.08)
    heroChipBorder: Color(0x24FFFFFF), // rgba(255,255,255,.14)
    panelShadow: [
      BoxShadow(
        color: Color(0x66000000), // rgba(0,0,0,.4)
        blurRadius: 32,
        offset: Offset(0, 16),
      ),
    ],
    pillShadow: BoxShadow(
      color: Color(0x50000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
    heroHalo: Color(0x4D78B4FF), // rgba(120,180,255,.30)
    hourPillTop: Color(0x1AFFFFFF), // white .10
    hourPillBottom: Color(0x0DFFFFFF), // white .05
    hourPillBorder: Color(0x24FFFFFF), // white .14
    hourHalo: Color(0x338CBEFF), // rgba(140,190,255,.20)
    todayA: Color(0xFF2B5FA8), // 1a 深色今日行
    todayB: Color(0xFF123A6B),
    forecastMin: Color(0xFF7FB0FF),
    forecastMax: Color(0xFFFFB93E),
  );

  static _W2b resolve(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  static _W2b of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_WeatherScope>()?.scheme ??
      resolve(context);
}

/// 把当前 [_W2b] 配色下发给天气页所有子组件。
class _WeatherScope extends InheritedWidget {
  const _WeatherScope({required this.scheme, required super.child});

  final _W2b scheme;

  @override
  bool updateShouldNotify(_WeatherScope oldWidget) =>
      oldWidget.scheme != scheme;
}

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
  late _WeatherForecast _forecast;
  bool _isRefreshing = true;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8600),
    )..repeat(reverse: true);
    // Reuse the last successfully fetched forecast (if still valid for today)
    // so re-entering the page shows real data instantly instead of resetting
    // to placeholder values; a background refresh still runs right away.
    final cached = _WeatherService.cachedForecast(_forecastCacheKey);
    _forecast =
        cached ?? _WeatherService.placeholderForCity(widget.initialCity);
    _refreshForecast(initial: true);
  }

  String get _forecastCacheKey {
    final agentId = widget.agentId;
    if (agentId != null && agentId.isNotEmpty) return 'agent:$agentId';
    final city = _WeatherService._normalizeCityName(widget.initialCity);
    return city.isEmpty
        ? 'city:${_WeatherService._fallbackCity}'
        : 'city:$city';
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
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

  Future<void> _refreshForecast({bool initial = false}) async {
    if (!initial && mounted) {
      setState(() => _isRefreshing = true);
    }
    try {
      final forecast = await _loadForecast();
      // Store into the session cache even if the page was already disposed,
      // so the next visit can start from this data.
      _WeatherService.storeForecast(_forecastCacheKey, forecast);
      if (!mounted) return;
      setState(() {
        _forecast = forecast;
      });
    } catch (_) {
      // 保留首屏占位或上一份天气数据；天气页不因刷新失败切到空态。
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _handleBack() {
    Navigator.of(context).maybePop();
  }

  void _openFutureForecast(_WeatherForecast forecast) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) =>
            _FutureWeatherPage(forecast: forecast, agentName: widget.agentName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breathController,
      builder: (context, _) {
        final progress = Curves.easeInOut.transform(_breathController.value);
        final scheme = _W2b.resolve(context);
        return _WeatherScope(
          scheme: scheme,
          child: Scaffold(
            backgroundColor: scheme.base,
            body: Stack(
              children: [
                Positioned.fill(child: _WeatherBackground(progress: progress)),
                SafeArea(
                  bottom: false,
                  child: _WeatherHome(
                    forecast: _forecast,
                    agentName: widget.agentName,
                    progress: progress,
                    isRefreshing: _isRefreshing,
                    onBack: _handleBack,
                    onShowFuture: () => _openFutureForecast(_forecast),
                    bottomPadding: MediaQuery.paddingOf(context).bottom,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FutureWeatherPage extends StatefulWidget {
  const _FutureWeatherPage({required this.forecast, required this.agentName});

  final _WeatherForecast forecast;
  final String agentName;

  @override
  State<_FutureWeatherPage> createState() => _FutureWeatherPageState();
}

class _FutureWeatherPageState extends State<_FutureWeatherPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathController;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breathController,
      builder: (context, _) {
        final progress = Curves.easeInOut.transform(_breathController.value);
        final scheme = _W2b.resolve(context);
        return _WeatherScope(
          scheme: scheme,
          child: Scaffold(
            backgroundColor: scheme.base,
            body: Stack(
              children: [
                Positioned.fill(
                  child: _WeatherBackground(progress: progress, forecast: true),
                ),
                SafeArea(
                  bottom: false,
                  child: _FutureWeatherList(
                    forecast: widget.forecast,
                    agentName: widget.agentName,
                    onBack: () => Navigator.of(context).maybePop(),
                    bottomPadding: MediaQuery.paddingOf(context).bottom,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WeatherHome extends StatelessWidget {
  const _WeatherHome({
    required this.forecast,
    required this.agentName,
    required this.progress,
    required this.isRefreshing,
    required this.onBack,
    required this.onShowFuture,
    required this.bottomPadding,
  });

  final _WeatherForecast forecast;
  final String agentName;
  final double progress;
  final bool isRefreshing;
  final VoidCallback onBack;
  final VoidCallback onShowFuture;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final today = forecast.days.first;
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 18, 20, bottomPadding + 34),
      physics: const BouncingScrollPhysics(),
      children: [
        _WeatherTopBar(
          location: forecast.location,
          agentName: agentName,
          isRefreshing: isRefreshing,
          onBack: onBack,
        ),
        const SizedBox(height: 28),
        _WeatherHeroCard(
          day: today,
          current: forecast.current,
          progress: progress,
        ),
        const SizedBox(height: 36),
        _WeatherMetricGrid(day: today, current: forecast.current),
        const SizedBox(height: 36),
        _TodayHourlyHeader(onShowFuture: onShowFuture),
        const SizedBox(height: 16),
        _HourlyWeatherStrip(day: today),
      ],
    );
  }
}

class _FutureWeatherList extends StatelessWidget {
  const _FutureWeatherList({
    required this.forecast,
    required this.agentName,
    required this.onBack,
    required this.bottomPadding,
  });

  final _WeatherForecast forecast;
  final String agentName;
  final VoidCallback onBack;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final days = forecast.days.take(7).toList();
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 18, 20, bottomPadding + 34),
      physics: const BouncingScrollPhysics(),
      children: [
        _WeatherTopBar(
          location: forecast.location,
          agentName: agentName,
          isRefreshing: false,
          onBack: onBack,
          title: '未来 7 天',
        ),
        const SizedBox(height: 24),
        for (var index = 0; index < days.length; index += 1) ...[
          _FutureWeatherRow(
            day: days[index],
            highlight: days[index].index == 0,
          ),
          if (index != days.length - 1) const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _WeatherTopBar extends StatelessWidget {
  const _WeatherTopBar({
    required this.location,
    required this.agentName,
    required this.isRefreshing,
    required this.onBack,
    this.title,
  });

  final _WeatherLocation location;
  final String agentName;
  final bool isRefreshing;
  final VoidCallback onBack;

  /// 非空时走 design 2b 的未来 7 天头部：左标题 + 右侧纯文字地点。
  final String? title;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.of(context);
    final title = this.title;
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          _WeatherBackButton(onTap: onBack),
          if (title != null) ...[
            const SizedBox(width: 14),
            Text(
              title,
              style: TextStyle(
                color: w.ink,
                fontSize: 18,
                height: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: isRefreshing
                ? const SizedBox(
                    key: ValueKey('weather-refreshing'),
                    width: 16,
                    height: 16,
                    child: CupertinoActivityIndicator(radius: 7),
                  )
                : const SizedBox(
                    key: ValueKey('weather-idle'),
                    width: 0,
                    height: 16,
                  ),
          ),
          if (isRefreshing) const SizedBox(width: 8),
          // Expanded + 右对齐：右侧内容自然收缩，不会被 Spacer 均分掉一半宽度。
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: title != null
                  ? Text(
                      location.displayName,
                      style: TextStyle(
                        color: w.inkSoft,
                        fontSize: 12,
                        height: 1,
                        fontWeight: FontWeight.w400,
                      ),
                    )
                  : _WeatherLocationPill(
                      location: location.displayName,
                      agentName: agentName,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Spec 2b：右上角地点做成毛玻璃圆角药丸。
class _WeatherLocationPill extends StatelessWidget {
  const _WeatherLocationPill({required this.location, required this.agentName});

  final String location;
  final String agentName;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: w.glass,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: w.glassBorder),
            boxShadow: [w.pillShadow],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.location_solid, color: w.ink, size: 13),
              const SizedBox(width: 6),
              // 用 ConstrainedBox 而非 Flexible：Flexible 会在 min-size Row 里
              // 吃掉全部可用宽度，把药丸撑满整行。
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: w.ink,
                    fontSize: 13,
                    height: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Text(
                  '$agentName所在地',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: w.inkFaint,
                    fontSize: 11,
                    height: 1,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeatherBackButton extends StatelessWidget {
  const _WeatherBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.of(context);
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: w.glass,
              shape: BoxShape.circle,
              border: Border.all(color: w.glassBorder),
              boxShadow: [w.pillShadow],
            ),
            child: Icon(CupertinoIcons.chevron_left, color: w.ink, size: 20),
          ),
        ),
      ),
    );
  }
}

/// Spec 2b：`#E9F0FB` 底色 + 三团柔光渐层（会随呼吸动效轻微游移）。
class _WeatherBackground extends StatelessWidget {
  const _WeatherBackground({required this.progress, this.forecast = false});

  final double progress;

  /// 未来 7 天页用另一套光斑落位（design 稿里两页光斑不同）。
  final bool forecast;

  @override
  Widget build(BuildContext context) {
    final scheme = _W2b.of(context);
    final drift = progress * 8;
    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.base),
      child: Stack(
        children: [
          if (scheme.isDark) ...[
            // Spec 2b 深色：饱和蓝/青/紫光斑 + 一层极细白点噪点（材质感）。
            Positioned(
              left: -120,
              top: (forecast ? -120 : -80) + drift,
              child: const _WeatherGlowBlob(
                width: 420,
                height: 380,
                color: Color(0x8C2E77E0), // rgba(46,119,224,.55)
              ),
            ),
            Positioned(
              right: forecast ? -150 : -140,
              top: forecast ? null : 80 + drift,
              bottom: forecast ? -60 - drift : null,
              child: const _WeatherGlowBlob(
                width: 400,
                height: 360,
                color: Color(0x4D18C6C0), // rgba(24,198,192,.30)
              ),
            ),
            if (!forecast)
              Positioned(
                left: -60,
                bottom: -140 - drift,
                child: const _WeatherGlowBlob(
                  width: 420,
                  height: 360,
                  color: Color(0x4D785ADC), // rgba(120,90,220,.30)
                ),
              ),
            const Positioned.fill(
              child: _WeatherGrain(dotColor: Color(0x29FFFFFF), opacity: 0.6),
            ),
          ] else if (forecast) ...[
            Positioned(
              left: -120,
              top: -120 + drift,
              child: const _WeatherGlowBlob(
                width: 420,
                height: 380,
                color: Color(0xFF7FB6FF),
              ),
            ),
            Positioned(
              right: -150,
              bottom: -60 - drift,
              child: const _WeatherGlowBlob(
                width: 400,
                height: 360,
                color: Color(0xFF9FE8E4),
                opacity: 0.7,
              ),
            ),
            const Positioned.fill(
              child: _WeatherGrain(dotColor: Color(0x80FFFFFF), opacity: 0.5),
            ),
          ] else ...[
            Positioned(
              left: -120,
              top: -80 + drift,
              child: const _WeatherGlowBlob(
                width: 420,
                height: 380,
                color: Color(0xFF7FB6FF),
              ),
            ),
            Positioned(
              right: -140,
              top: 60 + drift,
              child: const _WeatherGlowBlob(
                width: 400,
                height: 360,
                color: Color(0xFFFFD9A0),
                opacity: 0.75,
              ),
            ),
            Positioned(
              left: -60,
              bottom: -120 - drift,
              child: const _WeatherGlowBlob(
                width: 420,
                height: 360,
                color: Color(0xFF9FE8E4),
                opacity: 0.7,
              ),
            ),
            const Positioned.fill(
              child: _WeatherGrain(dotColor: Color(0x80FFFFFF), opacity: 0.5),
            ),
          ],
        ],
      ),
    );
  }
}

/// `radial-gradient(circle, color, transparent)` 的 Flutter 等价实现。
class _WeatherGlowBlob extends StatelessWidget {
  const _WeatherGlowBlob({
    required this.width,
    required this.height,
    required this.color,
    this.opacity = 1,
  });

  final double width;
  final double height;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    // design 稿 1:1：`width×height` 的椭圆（border-radius:50%）里填一个
    // `radial-gradient(circle, color, transparent)`（默认 farthest-corner）。
    // 渐变圆半径 = 到最远角的距离 ≈ 0.75×最短边，实色在中心、到椭圆边约剩
    // 1/4 浓度，再被椭圆裁成圆边 —— 所以是「大而饱和、柔圆边」的色块，
    // 不是中心一点的虚光，也不会有矩形硬接缝（椭圆裁剪代替矩形裁剪）。
    return Opacity(
      opacity: opacity,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(
            Radius.elliptical(width / 2, height / 2),
          ),
          gradient: RadialGradient(
            radius: 0.75,
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

/// Spec 2b 的白点噪点层（`radial-gradient(white α .6px) / 3px`）。
/// 浅色：white .5 @ opacity .5；深色：white .16 @ opacity .6。
/// 用 RepaintBoundary + shouldRepaint=false 让 Flutter 把它栅格缓存，
/// 呼吸动效重建时不会逐帧重画这几万个点。
class _WeatherGrain extends StatelessWidget {
  const _WeatherGrain({required this.dotColor, required this.opacity});

  final Color dotColor;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Opacity(
        opacity: opacity,
        child: CustomPaint(
          painter: _WeatherGrainPainter(dotColor),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _WeatherGrainPainter extends CustomPainter {
  const _WeatherGrainPainter(this.dotColor);

  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = dotColor;
    const step = 3.0;
    const r = 0.3;
    for (var y = 0.0; y < size.height; y += step) {
      for (var x = 0.0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_WeatherGrainPainter oldDelegate) =>
      oldDelegate.dotColor != dotColor;
}

class _WeatherHeroCard extends StatelessWidget {
  const _WeatherHeroCard({
    required this.day,
    required this.current,
    required this.progress,
  });

  final _WeatherDay day;
  final _WeatherSnapshot? current;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.of(context);
    final snapshot = day.displaySnapshot(current);
    final temp = snapshot.temperature.round();
    final text = _weatherText(snapshot.weatherCode);
    final mood = _weatherMoodLine(day);
    final wave = (math.sin(progress * math.pi * 2) + 1) / 2;
    final feels = snapshot.apparentTemperature.round();
    final range =
        '${day.minTemperature.round()}–${day.maxTemperature.round()}°';

    // Spec 2b「大背景模式」：不再包蓝色卡片，内容直接落在柔光渐层上。
    return Column(
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // design 稿里图标背后的 150px 柔光（浅色=白，深色=蓝）。
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [w.heroHalo, w.heroHalo.withValues(alpha: 0)],
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(2 * wave, -4 * wave),
                child: _AnimatedWeatherIcon(
                  weatherCode: snapshot.weatherCode,
                  hour: DateTime.now().hour,
                  size: 124,
                  progress: progress,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$temp',
              style: TextStyle(
                color: w.ink,
                fontSize: 96,
                height: 0.8,
                fontWeight: FontWeight.w200,
                letterSpacing: -5,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10, left: 4),
              child: Text(
                '°',
                style: TextStyle(
                  color: w.ink,
                  fontSize: 30,
                  height: 1,
                  fontWeight: FontWeight.w200,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _WeatherHeroChip(label: text),
            _WeatherHeroChip(label: '体感 $feels°'),
            _WeatherHeroChip(label: range),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          mood.replaceAll('\n', ''),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: w.inkSoft,
            fontSize: 13,
            height: 1.5,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

/// Spec 2b：主视觉下方的半透明信息药丸（天气 / 体感 / 温区）。
class _WeatherHeroChip extends StatelessWidget {
  const _WeatherHeroChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.of(context);
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: w.heroChipBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: w.heroChipBorder),
      ),
      // Row(min) 才会收缩包裹；Container.alignment 会把药丸撑满整行。
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: w.ink,
              fontSize: 12,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedWeatherIcon extends StatelessWidget {
  const _AnimatedWeatherIcon({
    required this.weatherCode,
    required this.hour,
    required this.size,
    required this.progress,
  });

  final int weatherCode;
  final int hour;
  final double size;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final phase = progress % 1;
    final pulse = math.sin(phase * math.pi * 2);
    final scale = 0.985 + 0.025 * (pulse + 1) / 2;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _WeatherIconAuraPainter(
                weatherCode: weatherCode,
                progress: phase,
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(1.8 * pulse, -2.2 * pulse),
            child: Transform.scale(
              scale: scale,
              child: Image.asset(
                _weatherAsset(weatherCode, hour: hour),
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _WeatherIconParticlePainter(
                weatherCode: weatherCode,
                progress: phase,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherIconAuraPainter extends CustomPainter {
  const _WeatherIconAuraPainter({
    required this.weatherCode,
    required this.progress,
  });

  final int weatherCode;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.54, size.height * 0.54);
    final pulse = (math.sin(progress * math.pi * 2) + 1) / 2;
    final auraPaint = Paint()
      ..color = const Color(0xFF4B9AFF).withValues(alpha: 0.16 + 0.10 * pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: size.width * (0.86 + 0.08 * pulse),
        height: size.height * (0.70 + 0.08 * pulse),
      ),
      auraPaint,
    );

    if (_isSunnyWeather(weatherCode) || _isPartlyCloudyWeather(weatherCode)) {
      final sunPaint = Paint()
        ..color = const Color(0xFFFFD86F).withValues(alpha: 0.18 + 0.14 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      canvas.drawCircle(
        Offset(size.width * 0.68, size.height * 0.30),
        size.width * (0.20 + 0.03 * pulse),
        sunPaint,
      );
    }

    if (_isThunderWeather(weatherCode)) {
      final flash = math
          .pow((math.sin(progress * math.pi * 6) + 1) / 2, 5)
          .toDouble();
      if (flash > 0.32) {
        final flashPaint = Paint()
          ..color = const Color(0xFFFFF2A6).withValues(alpha: 0.28 * flash)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
        canvas.drawCircle(
          Offset(size.width * 0.48, size.height * 0.58),
          size.width * 0.34,
          flashPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherIconAuraPainter oldDelegate) {
    return oldDelegate.weatherCode != weatherCode ||
        oldDelegate.progress != progress;
  }
}

class _WeatherIconParticlePainter extends CustomPainter {
  const _WeatherIconParticlePainter({
    required this.weatherCode,
    required this.progress,
  });

  final int weatherCode;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (_isRainWeather(weatherCode)) {
      _paintRain(canvas, size);
    }
    if (_isSnowWeather(weatherCode)) {
      _paintSnow(canvas, size);
    }
    if (_isThunderWeather(weatherCode)) {
      _paintLightning(canvas, size);
    }
  }

  void _paintRain(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3CE7D6).withValues(alpha: 0.72)
      ..strokeWidth = size.width * 0.035
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i += 1) {
      final t = (progress + i * 0.17) % 1;
      final x = size.width * (0.32 + i * 0.09);
      final y = size.height * (0.58 + 0.28 * t);
      final opacity = math.sin(t * math.pi).clamp(0.0, 1.0);
      paint.color = const Color(
        0xFF3CE7D6,
      ).withValues(alpha: 0.22 + 0.50 * opacity);
      canvas.drawLine(Offset(x, y), Offset(x - 4, y + 12), paint);
    }
  }

  void _paintSnow(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.78)
      ..strokeWidth = size.width * 0.020
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i += 1) {
      final t = (progress + i * 0.23) % 1;
      final center = Offset(
        size.width * (0.36 + i * 0.10 + 0.02 * math.sin(t * math.pi * 2)),
        size.height * (0.58 + 0.26 * t),
      );
      final arm = size.width * 0.035;
      final opacity = math.sin(t * math.pi).clamp(0.0, 1.0);
      paint.color = Colors.white.withValues(alpha: 0.24 + 0.54 * opacity);
      canvas.drawLine(
        center.translate(-arm, 0),
        center.translate(arm, 0),
        paint,
      );
      canvas.drawLine(
        center.translate(0, -arm),
        center.translate(0, arm),
        paint,
      );
    }
  }

  void _paintLightning(Canvas canvas, Size size) {
    final flash = math
        .pow((math.sin(progress * math.pi * 6) + 1) / 2, 4)
        .toDouble();
    if (flash < 0.42) return;
    final paint = Paint()
      ..color = const Color(0xFFFFE15B).withValues(alpha: 0.42 * flash)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.025
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.45, size.height * 0.48)
      ..lineTo(size.width * 0.38, size.height * 0.62)
      ..lineTo(size.width * 0.48, size.height * 0.62)
      ..lineTo(size.width * 0.40, size.height * 0.78);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WeatherIconParticlePainter oldDelegate) {
    return oldDelegate.weatherCode != weatherCode ||
        oldDelegate.progress != progress;
  }
}

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
        tone: _WeatherMetricTone.amber,
      ),
      _WeatherMetricData(
        title: '降雨概率',
        value: '${day.maxRainProbability.round()}%',
        glyph: _WeatherGlyph.rain,
        tone: _WeatherMetricTone.blue,
      ),
      _WeatherMetricData(
        title: '湿度',
        value: '${snapshot.humidity.round()}%',
        glyph: _WeatherGlyph.humidity,
        tone: _WeatherMetricTone.teal,
      ),
      _WeatherMetricData(
        title: '风速',
        value: '${snapshot.windSpeed.round()}km/h',
        glyph: _WeatherGlyph.wind,
        tone: _WeatherMetricTone.indigo,
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
    required this.tone,
  });

  final String title;
  final String value;
  final _WeatherGlyph glyph;
  final _WeatherMetricTone tone;
}

/// Spec 2b 的图标是「纯色实心字形」，Cupertino 的线性图标混在一起会不齐整，
/// 所以四个字形都用矢量实心图形画。
///
/// [humidity] / [wind] 直接取自 design 稿（hum2b / win2b 的 path 原值）；
/// design 稿本身只有 湿度/风速/空气/日照 四个字形，没有体感和降雨，
/// 因此 [feelsLike] / [rain] 按同一套几何语言（圆角实心块 + .55 次级透明度
/// + 白色高光）补齐。
enum _WeatherGlyph { feelsLike, rain, humidity, wind }

String _weatherGlyphSvg(_WeatherGlyph glyph, Color glyphStart, Color glyphEnd) {
  final start = _svgHex(glyphStart);
  final end = _svgHex(glyphEnd);
  String wrap(String coords, String body) =>
      '<svg width="19" height="19" viewBox="0 0 24 24" fill="none">'
      '<defs><linearGradient id="g" $coords gradientUnits="userSpaceOnUse">'
      '<stop stop-color="$start"/><stop offset="1" stop-color="$end"/>'
      '</linearGradient></defs>$body</svg>';

  switch (glyph) {
    case _WeatherGlyph.humidity:
      return wrap(
        'x1="6" y1="3" x2="18" y2="21"',
        '<path d="M12 2.2 6.4 8.1a7.8 7.8 0 1 0 11.2 0Z" fill="url(#g)"/>'
            '<path d="M9.1 12.6c-.5 1.7 0 3.3 1.4 4.3-2.3-.3-3.6-2.2-3.1-4.3.3-1.2 1-2.2 1.9-3-.3.9-.4 2-.2 3Z" fill="#fff" opacity=".62"/>',
      );
    case _WeatherGlyph.wind:
      return wrap(
        'x1="3" y1="4" x2="20" y2="20"',
        '<g fill="url(#g)">'
            '<rect x="2.4" y="5" width="10.6" height="2.5" rx="1.25"/>'
            '<path fill-rule="evenodd" d="M16.1 3.35a2.9 2.9 0 1 1 0 5.8 2.9 2.9 0 0 1 0-5.8Zm0 1.9a1 1 0 1 0 0 2 1 1 0 0 0 0-2Z"/>'
            '<rect x="2.4" y="10.75" width="14" height="2.5" rx="1.25"/>'
            '<path fill-rule="evenodd" d="M19.3 9.1a2.9 2.9 0 1 1 0 5.8 2.9 2.9 0 0 1 0-5.8Zm0 1.9a1 1 0 1 0 0 2 1 1 0 0 0 0-2Z"/>'
            '<rect x="2.4" y="16.5" width="8" height="2.5" rx="1.25" opacity=".55"/>'
            '<path fill-rule="evenodd" opacity=".55" d="M13.4 14.85a2.9 2.9 0 1 1 0 5.8 2.9 2.9 0 0 1 0-5.8Zm0 1.9a1 1 0 1 0 0 2 1 1 0 0 0 0-2Z"/>'
            '</g>',
      );
    case _WeatherGlyph.feelsLike:
      // 实心温度计：柱体 + 球泡，右侧热浪沿用 design 的 .55 次级透明度。
      return wrap(
        'x1="5" y1="3" x2="19" y2="21"',
        '<g fill="url(#g)">'
            '<rect x="7.9" y="2.8" width="3.4" height="13.4" rx="1.7"/>'
            '<circle cx="9.6" cy="17.9" r="4"/>'
            '<rect x="15" y="6.1" width="6.2" height="2.3" rx="1.15" opacity=".55"/>'
            '<rect x="15" y="10.5" width="4.3" height="2.3" rx="1.15" opacity=".55"/>'
            '</g>'
            '<rect x="9.05" y="5.1" width="1.1" height="5.4" rx=".55" fill="#fff" opacity=".55"/>',
      );
    case _WeatherGlyph.rain:
      // 实心伞面沿用 design 半圆穹顶的画法（见 sun2b），加伞柄与白色高光。
      return wrap(
        'x1="4" y1="4" x2="20" y2="20"',
        '<g fill="url(#g)">'
            '<path d="M12 3.2a8.4 8.4 0 0 1 8.4 8.4H3.6A8.4 8.4 0 0 1 12 3.2Z"/>'
            '<rect x="10.9" y="11.6" width="2.2" height="7.6" rx="1.1"/>'
            '<rect x="6.6" y="17.9" width="6.5" height="2.2" rx="1.1" opacity=".55"/>'
            '</g>'
            '<path d="M9.5 5.3a8.4 8.4 0 0 0-4.2 6.3h2.2c0-2.5.7-4.7 2-6.3Z" fill="#fff" opacity=".5"/>',
      );
  }
}

String _svgHex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Spec 2b 图标语义色板：体感橙 / 降雨蓝 / 湿度青 / 风速靛。
///
/// 浅色：`linear-gradient(150deg,#FFFFFF,tintLight)` 圆底 + 彩色投影，
///       字形走浅色双色实心渐变。
/// 深色：`linear-gradient(150deg, tintDark@.30, tintDark@.08)` 半透明圆底 +
///       内高光，字形走 design 稿的深色双色渐变（hum2bd/win2bd/…）。
enum _WeatherMetricTone {
  amber(
    Color(0xFFFCEBCC),
    Color(0xFFFFD97A),
    Color(0xFFF59A15),
    0.22,
    Color(0xFFFFC766),
    Color(0xFFFFE7A8),
    Color(0xFFFBA92B),
  ),
  blue(
    Color(0xFFE1EBFF),
    Color(0xFF8FB6FF),
    Color(0xFF2E6BE6),
    0.20,
    Color(0xFF7FA8FF),
    Color(0xFFC3D8FF),
    Color(0xFF4A83F0),
  ),
  teal(
    Color(0xFFDFF5F4),
    Color(0xFF4FE3DD),
    Color(0xFF0FA49F),
    0.22,
    Color(0xFF2DD8D2),
    Color(0xFF7DF2ED),
    Color(0xFF17B8B2),
  ),
  indigo(
    Color(0xFFE4E9FF),
    Color(0xFF93B4FF),
    Color(0xFF5C93FF),
    0.20,
    Color(0xFF93B4FF),
    Color(0xFFBFD0FF),
    Color(0xFF6E9BFF),
  );

  const _WeatherMetricTone(
    this.tintLight,
    this.glyphLightStart,
    this.glyphLightEnd,
    this.shadowOpacity,
    this.tintDark,
    this.glyphDarkStart,
    this.glyphDarkEnd,
  );

  final Color tintLight;
  final Color glyphLightStart;
  final Color glyphLightEnd;
  final double shadowOpacity;
  final Color tintDark;
  final Color glyphDarkStart;
  final Color glyphDarkEnd;
}

/// Spec 2b：38px 渐变圆底 + 双色实心字形（浅/深两套）。
class _WeatherMetricIcon extends StatelessWidget {
  const _WeatherMetricIcon({required this.glyph, required this.tone});

  final _WeatherGlyph glyph;
  final _WeatherMetricTone tone;

  @override
  Widget build(BuildContext context) {
    final dark = _W2b.of(context).isDark;
    final glyphStart = dark ? tone.glyphDarkStart : tone.glyphLightStart;
    final glyphEnd = dark ? tone.glyphDarkEnd : tone.glyphLightEnd;
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // CSS 150deg ≈ 从左上偏上流向右下偏下。
        gradient: LinearGradient(
          begin: const Alignment(-0.5, -1),
          end: const Alignment(0.5, 1),
          colors: dark
              ? [
                  tone.tintDark.withValues(alpha: 0.30),
                  tone.tintDark.withValues(alpha: 0.08),
                ]
              : [Colors.white, tone.tintLight],
        ),
        border: dark
            ? Border.all(color: Colors.white.withValues(alpha: 0.18))
            : null,
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: tone.glyphLightEnd.withValues(
                    alpha: tone.shadowOpacity,
                  ),
                  blurRadius: 9,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      // 渐变写在 SVG 内部而不是用 ShaderMask：字形里的白色高光要保持白色。
      child: SvgPicture.string(
        _weatherGlyphSvg(glyph, glyphStart, glyphEnd),
        width: 19,
        height: 19,
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: w.glass,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: w.glassBorder),
        boxShadow: w.panelShadow,
      ),
      child: Row(
        children: [
          _WeatherMetricIcon(glyph: data.glyph, tone: data.tone),
          const SizedBox(width: 18),
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
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF4B9AFF), Color(0xFF8ABAFF)],
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
                  color: Color(0x474E9BFF), // #4E9BFF @ .28
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
                  color: const Color(0xFF509AFD).withValues(alpha: 0.28),
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
                          : const Color(0xFF4B9AFF).withValues(alpha: 0.70),
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
                          : const Color(0xFF4B9AFF).withValues(alpha: 0.70),
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

class _WeatherService {
  const _WeatherService._();

  static const _fallbackCity = '杭州';
  static const _fallbackTimezone = 'Asia/Shanghai';
  static const _forecastDays = 10;

  // Session-level cache of the last successfully fetched forecast, keyed by
  // agent (or city as fallback). Keeps the page from resetting to placeholder
  // data every time it is re-entered within the same app session.
  static final Map<String, _WeatherForecast> _forecastCache = {};

  static _WeatherForecast? cachedForecast(String key) {
    final cached = _forecastCache[key];
    if (cached == null) return null;
    // Drop cache that no longer starts at today (e.g. fetched before
    // midnight); otherwise the "today" sections would show yesterday.
    final now = DateTime.now();
    final firstDay = cached.days.first.date;
    final coversToday =
        firstDay.year == now.year &&
        firstDay.month == now.month &&
        firstDay.day == now.day;
    if (!coversToday) {
      _forecastCache.remove(key);
      return null;
    }
    return cached;
  }

  static void storeForecast(String key, _WeatherForecast forecast) {
    _forecastCache[key] = forecast;
  }

  static _WeatherForecast placeholderForCity(String? city) {
    final displayName = _normalizeCityName(city);
    final location = _WeatherLocation(
      displayName: displayName.isEmpty ? _fallbackCity : displayName,
      latitude: 30.29365,
      longitude: 120.16142,
      timezone: _fallbackTimezone,
    );
    final now = DateTime.now();
    final baseDate = DateTime(now.year, now.month, now.day);
    final days = List.generate(_forecastDays, (dayIndex) {
      final date = baseDate.add(Duration(days: dayIndex));
      final minTemp = 19.0 + (dayIndex % 3);
      final maxTemp = 27.0 + (dayIndex % 4);
      final code = dayIndex % 5 == 3 ? 61 : 2;
      final hours = List.generate(24, (hour) {
        final temperature =
            minTemp +
            (maxTemp - minTemp) *
                (0.5 + 0.5 * math.sin((hour - 7) / 24 * math.pi * 2));
        return _WeatherHour(
          time: DateTime(date.year, date.month, date.day, hour),
          temperature: temperature,
          apparentTemperature: temperature + 1,
          humidity: 58 + (hour % 6) * 2,
          rainProbability: code == 61 ? 42 : 8,
          weatherCode: code,
          windSpeed: 8 + (hour % 4),
          windDirection: '东南风',
          aqi: 42 + dayIndex.toDouble(),
        );
      });
      return _WeatherDay(
        index: dayIndex,
        date: date,
        weatherCode: code,
        minTemperature: minTemp,
        maxTemperature: maxTemp,
        maxRainProbability: code == 61 ? 42 : 8,
        maxWindSpeed: 12,
        dominantWindDirection: '东南风',
        hours: hours,
      );
    });
    return _WeatherForecast(
      days: days,
      current: days.first.displaySnapshot(null),
      location: location,
    );
  }

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

  String get dateLabel =>
      '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

  String get futureTitle {
    if (index == 0) return '今天';
    if (index == 1) return '明天';
    return date._weatherWeekdayLabel;
  }

  List<_WeatherHour> get stripHours {
    if (hours.isEmpty) return const [];
    final selected = <_WeatherHour>[];
    for (final target in const [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22]) {
      selected.add(_nearestHour(target));
    }
    return selected;
  }

  _WeatherHour _nearestHour(int targetHour) {
    return hours.reduce((a, b) {
      final aDistance = (a.time.hour - targetHour).abs();
      final bDistance = (b.time.hour - targetHour).abs();
      return aDistance <= bDistance ? a : b;
    });
  }

  _WeatherSnapshot displaySnapshot(_WeatherSnapshot? current) {
    if (index == 0 && current != null) return current;
    final hour = hours.isEmpty
        ? null
        : _nearestHour(index == 0 ? DateTime.now().hour : 14);
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

extension on DateTime {
  String get _weatherWeekdayLabel {
    const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return labels[weekday - 1];
  }
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

String _weatherAsset(int code, {required int hour}) {
  final isNight = hour < 6 || hour >= 20;
  if (code == 0) return 'assets/weather/sunny.png';
  if (code == 1 || code == 2) {
    return isNight
        ? 'assets/weather/cloudy.png'
        : 'assets/weather/partly_cloudy.png';
  }
  if (code == 3 || code == 45 || code == 48) {
    return 'assets/weather/cloudy.png';
  }
  if (code >= 71 && code <= 77) return 'assets/weather/snow.png';
  if (code >= 95) return 'assets/weather/storm_rain.png';
  if (code >= 51 && code <= 67) return 'assets/weather/rain.png';
  if (code >= 80 && code <= 82) return 'assets/weather/storm_rain.png';
  return isNight
      ? 'assets/weather/cloudy.png'
      : 'assets/weather/partly_cloudy.png';
}

bool _isSunnyWeather(int code) => code == 0;

bool _isPartlyCloudyWeather(int code) => code == 1 || code == 2;

bool _isRainWeather(int code) => (code >= 51 && code <= 67) || code >= 80;

bool _isSnowWeather(int code) => code >= 71 && code <= 77;

bool _isThunderWeather(int code) => code >= 95;

String _weatherMoodLine(_WeatherDay day) {
  if (day.maxRainProbability >= 55) return '今天是小雨天，\n我的心情也变得安静了一点';
  if (day.maxTemperature >= 30) return '阳光有点认真，\n记得把防晒也放进行程里';
  if (day.minTemperature <= 10) return '天气有点凉，\n适合把外套和温柔都带上';
  if (day.weatherCode == 0 || day.weatherCode == 1 || day.weatherCode == 2) {
    return '天气很轻快，\n适合出去走走也适合慢慢聊';
  }
  return '云层慢慢铺开，\n今天可以把节奏放柔一点';
}

String _windDirection(double degrees) {
  final normalized = degrees % 360;
  const labels = ['北风', '东北风', '东风', '东南风', '南风', '西南风', '西风', '西北风'];
  final index = ((normalized + 22.5) ~/ 45) % labels.length;
  return labels[index];
}
