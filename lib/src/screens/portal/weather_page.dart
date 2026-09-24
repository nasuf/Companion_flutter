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
    // 「今天」行高亮加深到商城深蓝：浅端 #4A9BFF → 深端 #0A84FF。
    todayA: Color(0xFF4A9BFF),
    todayB: Color(0xFF0A84FF),
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
      CompanionPageRoute<void>(
        builder: (context) =>
            _FutureWeatherPage(forecast: forecast, agentName: widget.agentName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = _W2b.resolve(context);
    return _WeatherScope(
      scheme: scheme,
      child: Scaffold(
        backgroundColor: scheme.base,
        body: Stack(
          children: [
            Positioned.fill(
              child: _WeatherBreathBackdrop(animation: _breathController),
            ),
            SafeArea(
              bottom: false,
              child: _WeatherHome(
                forecast: _forecast,
                agentName: widget.agentName,
                breath: _breathController,
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
    final scheme = _W2b.resolve(context);
    return _WeatherScope(
      scheme: scheme,
      child: Scaffold(
        backgroundColor: scheme.base,
        body: Stack(
          children: [
            Positioned.fill(
              child: _WeatherBreathBackdrop(
                animation: _breathController,
                forecast: true,
              ),
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
  }
}
