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
  late _WeatherForecast _forecast;
  bool _isRefreshing = true;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8600),
    )..repeat(reverse: true);
    _forecast = _WeatherService.placeholderForCity(widget.initialCity);
    _refreshForecast(initial: true);
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
        return Scaffold(
          backgroundColor: const Color(0xFFEFF3FC),
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
        return Scaffold(
          backgroundColor: const Color(0xFFEFF3FC),
          body: Stack(
            children: [
              Positioned.fill(child: _WeatherBackground(progress: progress)),
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
        ),
        const SizedBox(height: 24),
        for (var index = 0; index < days.length; index += 1) ...[
          _FutureWeatherRow(day: days[index]),
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
  });

  final _WeatherLocation location;
  final String agentName;
  final bool isRefreshing;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          _WeatherBackButton(onTap: onBack),
          const Spacer(),
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
          Icon(
            CupertinoIcons.location_solid,
            color: const Color(0xFF333333).withValues(alpha: 0.92),
            size: 21,
          ),
          const SizedBox(width: 8),
          Text(
            location.displayName,
            style: const TextStyle(
              color: Color(0xFF333333),
              fontSize: 20,
              height: 1,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          Text(
            ' · $agentName所在地',
            style: const TextStyle(
              color: Color(0xFF333333),
              fontSize: 12,
              height: 1,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherBackButton extends StatelessWidget {
  const _WeatherBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4B9AFF).withValues(alpha: 0.24),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(
          CupertinoIcons.chevron_left,
          color: Color(0xFF4B9AFF),
          size: 24,
        ),
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
      decoration: const BoxDecoration(color: Color(0xFFEFF3FC)),
      child: Stack(
        children: [
          Positioned(
            right: -96 + 10 * progress,
            top: 104 + 8 * progress,
            child: _WeatherBlurBlob(
              width: 220 + 18 * progress,
              height: 170 + 12 * progress,
              color: const Color(0xFF4B9AFF).withValues(alpha: 0.13),
              radius: 62,
            ),
          ),
          Positioned(
            left: -82 - 5 * progress,
            bottom: 132 - 8 * progress,
            child: _WeatherBlurBlob(
              width: 210,
              height: 162,
              color: const Color(0xFFFFD86F).withValues(alpha: 0.11),
              radius: 64,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherBlurBlob extends StatelessWidget {
  const _WeatherBlurBlob({
    required this.width,
    required this.height,
    required this.color,
    required this.radius,
  });

  final double width;
  final double height;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
      child: Container(
        width: width,
        height: height,
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
    required this.progress,
  });

  final _WeatherDay day;
  final _WeatherSnapshot? current;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final snapshot = day.displaySnapshot(current);
    final temp = snapshot.temperature.round();
    final text = _weatherText(snapshot.weatherCode);
    final mood = _weatherMoodLine(day);
    final wave = (math.sin(progress * math.pi * 2) + 1) / 2;

    return Container(
      height: 196,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(21, 24, 18, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFAACDFF), Color(0xFF4B9AFF)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3892F9).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                ShaderMask(
                  shaderCallback: (rect) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, Color(0x33FFFFFF)],
                      stops: [0.40, 1],
                    ).createShader(rect);
                  },
                  child: Text(
                    '$temp℃',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 64,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  mood,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.42,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 124,
            height: 124,
            child: Transform.translate(
              offset: Offset(2 * wave, -4 * wave),
              child: _AnimatedWeatherIcon(
                weatherCode: snapshot.weatherCode,
                hour: DateTime.now().hour,
                size: 124,
                progress: progress,
              ),
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
        icon: CupertinoIcons.thermometer_sun,
      ),
      _WeatherMetricData(
        title: '降雨概率',
        value: '${day.maxRainProbability.round()}%',
        icon: CupertinoIcons.umbrella,
      ),
      _WeatherMetricData(
        title: '湿度',
        value: '${snapshot.humidity.round()}%',
        icon: CupertinoIcons.drop,
      ),
      _WeatherMetricData(
        title: '风速',
        value: '${snapshot.windSpeed.round()}km/h',
        icon: CupertinoIcons.wind,
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
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;
}

class _WeatherMetricCard extends StatelessWidget {
  const _WeatherMetricCard({required this.data});

  final _WeatherMetricData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4D9BFF).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: Icon(data.icon, color: const Color(0xFF4B9AFF), size: 31),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFBFBFBF),
                    fontSize: 14,
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
                    style: const TextStyle(
                      color: Colors.black,
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
    return Row(
      children: [
        const Text(
          '今天',
          style: TextStyle(
            color: Color(0xFF333333),
            fontSize: 20,
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
            children: const [
              Text(
                '未来7天',
                style: TextStyle(
                  color: Color(0x99333333),
                  fontSize: 14,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 4),
              Icon(
                CupertinoIcons.chevron_right,
                color: Color(0x99333333),
                size: 13,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HourlyWeatherStrip extends StatelessWidget {
  const _HourlyWeatherStrip({required this.day});

  final _WeatherDay day;

  @override
  Widget build(BuildContext context) {
    final hours = day.stripHours;
    if (hours.isEmpty) return const SizedBox.shrink();
    final selectedIndex = _selectedHourIndex(hours);
    return SizedBox(
      height: 136,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        padding: EdgeInsets.zero,
        itemCount: hours.length,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          return _HourlyWeatherPill(
            hour: hours[index],
            selected: index == selectedIndex,
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
    final foreground = selected ? Colors.white : const Color(0xFFBFBFBF);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: 68,
      height: 120,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: selected ? null : Colors.white,
        gradient: selected
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF4B9AFF), Color(0xFF8ABAFF)],
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: selected
                ? const Color(0xFF4E9BFF).withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
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
          const SizedBox(height: 8),
          SizedBox(
            width: 32,
            height: 32,
            child: Image.asset(
              _weatherAsset(hour.weatherCode, hour: hour.time.hour),
              fit: BoxFit.contain,
            ),
          ),
          const Spacer(),
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
  const _FutureWeatherRow({required this.day});

  final _WeatherDay day;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF509AFD).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
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
                  style: const TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 16,
                    height: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  day.dateLabel,
                  style: const TextStyle(
                    color: Color(0xFFAAAAAA),
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
                  style: const TextStyle(
                    color: Color(0xFF333333),
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
                      color: const Color(0xFF4B9AFF).withValues(alpha: 0.70),
                      size: 10,
                    ),
                    Text(
                      '${day.maxRainProbability.round()}%',
                      style: const TextStyle(
                        color: Color(0xFFA5A5A5),
                        fontSize: 10,
                        height: 1,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      CupertinoIcons.wind,
                      color: const Color(0xFF4B9AFF).withValues(alpha: 0.70),
                      size: 10,
                    ),
                    Flexible(
                      child: Text(
                        '${day.maxWindSpeed.round()}km/h',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFA5A5A5),
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
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [
                Text(
                  '${day.minTemperature.round()}℃',
                  style: const TextStyle(
                    color: Color(0xFF4193FD),
                    fontSize: 20,
                    height: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  '~',
                  style: TextStyle(
                    color: Color(0xFFA5A5A5),
                    fontSize: 20,
                    height: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${day.maxTemperature.round()}℃',
                  style: const TextStyle(
                    color: Color(0xFFFE9D0B),
                    fontSize: 20,
                    height: 1,
                    fontWeight: FontWeight.w600,
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

class _WeatherService {
  const _WeatherService._();

  static const _fallbackCity = '杭州';
  static const _fallbackTimezone = 'Asia/Shanghai';
  static const _forecastDays = 10;

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
