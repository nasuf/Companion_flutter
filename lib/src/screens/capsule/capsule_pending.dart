part of 'package:companion_flutter/main.dart';

class _PendingCapsuleScene extends StatefulWidget {
  const _PendingCapsuleScene({required this.capsules});

  final List<TimeCapsule> capsules;

  @override
  State<_PendingCapsuleScene> createState() => _PendingCapsuleSceneState();
}

class _PendingCapsuleSceneState extends State<_PendingCapsuleScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final safeTop = MediaQuery.paddingOf(context).top;
    final sx = size.width / 390;
    final sy = size.height / 844;
    double x(double value) => value * sx;
    double y(double value) => value * sy;
    final first = widget.capsules.first;
    final dateText = first.openDate == null
        ? '未知'
        : _formatCapsuleShortDate(first.openDate!);
    return Material(
      color: const Color(0xFFEB772A),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final breath = Curves.easeInOut.transform(_controller.value);
          Widget sticker(
            String asset, {
            required double left,
            required double top,
            required double width,
            required double height,
            double rotate = 0,
            double dx = 0,
            double dy = 0,
          }) {
            return Positioned(
              left: x(left),
              top: y(top),
              width: x(width),
              height: y(height),
              child: Transform.translate(
                offset: Offset(dx * breath, dy * breath),
                child: Transform.rotate(
                  angle: rotate,
                  child: Image.asset(asset, fit: BoxFit.contain),
                ),
              ),
            );
          }

          return Stack(
            children: [
              Positioned(
                left: x(-284.31),
                top: y(331),
                width: x(881.32),
                height: y(746.82),
                child: Transform.rotate(
                  angle: 0.351,
                  child: _WarmBlurSpot(
                    color: const Color(0xFFFFF2C5).withValues(alpha: 0.56),
                    size: x(720),
                  ),
                ),
              ),
              Positioned(
                left: x(243),
                top: y(-99),
                width: x(300),
                height: y(313),
                child: _WarmBlurSpot(
                  color: Colors.white.withValues(alpha: 0.34),
                  size: x(313),
                ),
              ),
              Positioned(
                left: x(20),
                top: safeTop + 8,
                child: _CapsuleWarmBackButton(
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
              Positioned(
                left: x(-82),
                top: y(639),
                width: x(503),
                height: y(379),
                child: Transform.rotate(
                  angle: 0.349,
                  child: Container(color: const Color(0xFFFFC271)),
                ),
              ),
              Positioned(
                left: x(10),
                top: y(650),
                width: x(181.4574),
                height: y(95.3926),
                child: SvgPicture.asset(
                  _capsuleAssetPendingShadowRing,
                  fit: BoxFit.fill,
                ),
              ),
              Positioned(
                left: x(44),
                top: y(281) + breath * y(8),
                width: x(294),
                height: y(409),
                child: Image.asset(
                  _capsuleAssetPendingBig,
                  fit: BoxFit.contain,
                  opacity: const AlwaysStoppedAnimation<double>(0.80),
                ),
              ),
              Positioned(
                left: x(0),
                right: 0,
                top: y(99),
                child: Column(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white, Color(0xFFFFD697)],
                      ).createShader(bounds),
                      child: const Text(
                        '时间胶囊',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    SizedBox(height: y(16)),
                    Container(
                      width: x(160),
                      height: y(38),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9215),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFFFFC9F)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '开启时间：$dateText',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              sticker(
                _capsuleAssetPendingSticker58,
                left: 16,
                top: 267,
                width: 92,
                height: 42,
                dx: -3,
                dy: 5,
              ),
              sticker(
                _capsuleAssetPendingSticker65,
                left: 16,
                top: 367,
                width: 74,
                height: 64,
                dx: 4,
                dy: -5,
              ),
              sticker(
                _capsuleAssetPendingSticker54,
                left: 133,
                top: 422,
                width: 53,
                height: 44,
                dx: -2,
                dy: -4,
              ),
              sticker(
                _capsuleAssetPendingSticker55,
                left: 96,
                top: 488,
                width: 64,
                height: 61,
                rotate: 0.551,
                dx: 3,
                dy: 4,
              ),
              sticker(
                _capsuleAssetPendingSticker56,
                left: 180,
                top: 494,
                width: 67,
                height: 76,
                dx: -3,
                dy: 4,
              ),
              sticker(
                _capsuleAssetPendingSticker64,
                left: 299,
                top: 521,
                width: 64,
                height: 65,
                dx: 2,
                dy: -4,
              ),
              sticker(
                _capsuleAssetPendingSticker59,
                left: 247,
                top: 610,
                width: 112,
                height: 94,
                rotate: 0.524,
                dx: -4,
                dy: -5,
              ),
            ],
          );
        },
      ),
    );
  }
}
