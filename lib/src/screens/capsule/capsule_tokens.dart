part of 'package:companion_flutter/main.dart';

// 胶囊「暖玻璃」设计令牌。玻璃结构（半透明面 + 描边）沿用天气页的 _W2b
// （glass / glassBorder），叠一层暖色光斑呼吸背景 + 橙色 accent + 暖投影，
// 保持胶囊一贯的橙暖调，同时与天气 / 商城的分层玻璃扁平风统一。
const _capsuleWarmBase = Color(0xFFF6EDE0); // 暖砂底（浅色）
const _capsuleWarmBaseDark = Color(0xFF15120E); // 暖夜底（深色）
const _capsuleBlobApricot = Color(0xFFFFC69B);
const _capsuleBlobHoney = Color(0xFFFFE0B0);
const _capsuleBlobTerra = Color(0xFFE6BFA8);

/// 暖光呼吸背景：暖砂底 + 2~3 团暖色柔光 + 细噪点，随内置呼吸动画轻微漂移。
/// 直接复用天气页的 _WeatherGlowBlob / _WeatherGrain（同库私有，可见）。
///
/// 自带 8600ms 呼吸 controller，任何胶囊页面直接 `_CapsuleBackground()` 铺底即可，
/// 无需各自持有 ticker——首页 / 已解封 / 仪式页共用同一套漂移节奏。
class _CapsuleBackground extends StatefulWidget {
  const _CapsuleBackground();

  @override
  State<_CapsuleBackground> createState() => _CapsuleBackgroundState();
}

class _CapsuleBackgroundState extends State<_CapsuleBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => _CapsuleBackgroundPaint(
        progress: Curves.easeInOut.transform(_controller.value),
      ),
    );
  }
}

class _CapsuleBackgroundPaint extends StatelessWidget {
  const _CapsuleBackgroundPaint({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final dark = _W2b.resolve(context).isDark;
    final drift = progress * 8;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? _capsuleWarmBaseDark : _capsuleWarmBase,
      ),
      child: Stack(
        children: [
          Positioned(
            left: -86,
            top: -64 + drift,
            child: _WeatherGlowBlob(
              width: 250,
              height: 220,
              color: _capsuleBlobApricot,
              opacity: dark ? 0.5 : 0.92,
            ),
          ),
          Positioned(
            right: -88,
            top: 96 + drift,
            child: _WeatherGlowBlob(
              width: 220,
              height: 196,
              color: _capsuleBlobHoney,
              opacity: dark ? 0.42 : 0.85,
            ),
          ),
          Positioned(
            left: -70,
            bottom: -72 - drift,
            child: _WeatherGlowBlob(
              width: 240,
              height: 206,
              color: _capsuleBlobTerra,
              opacity: dark ? 0.4 : 0.7,
            ),
          ),
          Positioned.fill(
            child: _WeatherGrain(
              dotColor: dark
                  ? const Color(0x24FFFFFF)
                  : const Color(0x66FFFFFF),
              opacity: dark ? 0.6 : 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// 橙色圆底 + 白色线性图标的徽章，承载草稿 / 待解封 / 已解封 / 写信等功能图标。
/// 仿天气页指标图标 _WeatherMetricIcon：实心圆底（径向高光）+ 白字形 +
/// 浅色下柔和橙投影、深色下无（避免暗底发脏）。
class _CapsuleMedallion extends StatelessWidget {
  const _CapsuleMedallion({required this.icon, this.size = 48});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = _W2b.resolve(context).isDark;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFB971), _capsuleOrange],
        ),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: _capsuleOrange.withValues(alpha: 0.32),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }
}

/// 胶囊玻璃卡通用装饰：中性玻璃面（复用 _W2b）+ 暖橙投影。
BoxDecoration _capsuleGlassCard(BuildContext context, {double radius = 24}) {
  final w = _W2b.resolve(context);
  return BoxDecoration(
    color: w.glass,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: w.glassBorder),
    boxShadow: const [_capsuleGlassShadow],
  );
}
