part of 'package:companion_flutter/main.dart';

class _WeatherHome extends StatelessWidget {
  const _WeatherHome({
    required this.forecast,
    required this.agentName,
    required this.breath,
    required this.isRefreshing,
    required this.onBack,
    required this.onShowFuture,
    required this.bottomPadding,
  });

  final _WeatherForecast forecast;
  final String agentName;
  final Animation<double> breath;
  final bool isRefreshing;
  final VoidCallback onBack;
  final VoidCallback onShowFuture;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final today = forecast.days.first;
    // 整屏不滚动：Column 填满可视区，各区块之间用弹性 Spacer 分配剩余空间，
    // 屏幕越高越透气、越矮越紧凑，保证所有元素同屏、互不重叠。
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPadding + 20),
      child: Column(
        children: [
          _WeatherTopBar(
            location: forecast.location,
            agentName: agentName,
            isRefreshing: isRefreshing,
            onBack: onBack,
          ),
          const Spacer(flex: 3),
          _WeatherHeroCard(
            day: today,
            current: forecast.current,
            breath: breath,
          ),
          const Spacer(flex: 3),
          _WeatherMetricGrid(day: today, current: forecast.current),
          const Spacer(flex: 2),
          _TodayHourlyHeader(onShowFuture: onShowFuture),
          const SizedBox(height: 14),
          _HourlyWeatherStrip(day: today),
        ],
      ),
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
    // 不用 BackdropFilter：整页在呼吸动效下每帧重合成，实时背景模糊会逐帧跑一
    // 次全屏 GPU blur → 卡顿。药丸很小、其后的渐层近乎匀色，半透明白底本身就有
    // 磨砂观感，省掉 blur 视觉几乎无差别。
    return Container(
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
    );
  }
}

class _WeatherBackButton extends StatelessWidget {
  const _WeatherBackButton({required this.onTap, this.iconColor, this.icon});

  final VoidCallback onTap;

  /// Chevron tint. Defaults to the weather accent blue; other pages reusing
  /// this glass button pass their own theme colour (capsule → orange).
  final Color? iconColor;

  /// Glyph override. Defaults to the back chevron; a page can reuse this exact
  /// 36pt glass circle for a same-size close (X) control (e.g. an editor).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.of(context);
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      // 同上：去掉 BackdropFilter，改半透明白底，避免每帧全屏模糊。
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
        child: Icon(
          icon ?? CupertinoIcons.chevron_left,
          color: iconColor ?? const Color(0xFF0A84FF),
          size: 20,
        ),
      ),
    );
  }
}

/// Isolates the 8600ms glow drift so the weather chrome (top bar, metrics,
/// hourly strip) is not rebuilt on every breath tick — those rebuilds used
/// to run through the whole Cupertino pop back to chat.
class _WeatherBreathBackdrop extends StatelessWidget {
  const _WeatherBreathBackdrop({
    required this.animation,
    this.forecast = false,
  });

  final Animation<double> animation;
  final bool forecast;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) => _WeatherBackground(
          progress: Curves.easeInOut.transform(animation.value),
          forecast: forecast,
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
    //
    // opacity 直接烘进渐变颜色，而不是用 Opacity 组件：背景每帧随呼吸动效重建，
    // Opacity 会每帧 saveLayer（离屏合成）→ 卡顿；乘进 alpha 后零额外开销。
    final tint = opacity >= 1
        ? color
        : color.withValues(alpha: color.a * opacity);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(
          Radius.elliptical(width / 2, height / 2),
        ),
        gradient: RadialGradient(
          radius: 0.75,
          colors: [tint, tint.withValues(alpha: 0)],
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
    // opacity 烘进颜色（去掉 Opacity 离屏层）；整层再包 RepaintBoundary，
    // 呼吸动效每帧重建时直接复用已栅格化的图层，不重画。
    final baked = dotColor.withValues(alpha: dotColor.a * opacity);
    return RepaintBoundary(
      child: CustomPaint(
        painter: _WeatherGrainPainter(baked),
        size: Size.infinite,
      ),
    );
  }
}

class _WeatherGrainPainter extends CustomPainter {
  const _WeatherGrainPainter(this.dotColor);

  final Color dotColor;

  // 同一尺寸的点阵只算一次，缓存复用（避免每次栅格化都重建 3 万+ 个 Offset）。
  static Size? _cachedSize;
  static List<Offset>? _cachedPoints;

  static List<Offset> _points(Size size) {
    if (_cachedSize == size && _cachedPoints != null) return _cachedPoints!;
    const step = 3.0;
    final pts = <Offset>[];
    for (var y = 0.0; y < size.height; y += step) {
      for (var x = 0.0; x < size.width; x += step) {
        pts.add(Offset(x, y));
      }
    }
    _cachedSize = size;
    _cachedPoints = pts;
    return pts;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // drawPoints 一次性批量画完所有点，比 3 万+ 次 drawCircle 快得多。
    final paint = Paint()
      ..color = dotColor
      ..strokeWidth = 0.6
      ..strokeCap = StrokeCap.round;
    canvas.drawPoints(PointMode.points, _points(size), paint);
  }

  @override
  bool shouldRepaint(_WeatherGrainPainter oldDelegate) =>
      oldDelegate.dotColor != dotColor;
}

class _WeatherHeroCard extends StatelessWidget {
  const _WeatherHeroCard({
    required this.day,
    required this.current,
    required this.breath,
  });

  final _WeatherDay day;
  final _WeatherSnapshot? current;
  final Animation<double> breath;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.of(context);
    final snapshot = day.displaySnapshot(current);
    final temp = snapshot.temperature.round();
    final text = _weatherText(snapshot.weatherCode);
    final mood = _weatherMoodLine(day);
    final feels = snapshot.apparentTemperature.round();
    final range =
        '${day.minTemperature.round()}–${day.maxTemperature.round()}°';

    // Spec 2b「大背景模式」：不再包蓝色卡片，内容直接落在柔光渐层上。
    // mainAxisSize.min：作为外层 Column 的非弹性子项，只占内容高度。
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 124,
          height: 124,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 图标背后的柔光（浅色=白，深色=蓝）。
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [w.heroHalo, w.heroHalo.withValues(alpha: 0)],
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: breath,
                builder: (context, _) {
                  final progress = Curves.easeInOut.transform(breath.value);
                  final wave = (math.sin(progress * math.pi * 2) + 1) / 2;
                  return Transform.translate(
                    offset: Offset(2 * wave, -4 * wave),
                    child: _AnimatedWeatherIcon(
                      weatherCode: snapshot.weatherCode,
                      hour: DateTime.now().hour,
                      size: 102,
                      progress: progress,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$temp',
              style: TextStyle(
                color: w.ink,
                fontSize: 80,
                height: 0.8,
                fontWeight: FontWeight.w200,
                letterSpacing: -4,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(
                '°',
                style: TextStyle(
                  color: w.ink,
                  fontSize: 26,
                  height: 1,
                  fontWeight: FontWeight.w200,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
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
        const SizedBox(height: 14),
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
      ..color = const Color(0xFF0A84FF).withValues(alpha: 0.16 + 0.10 * pulse)
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
