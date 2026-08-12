part of 'package:companion_flutter/main.dart';

/// 取景框在源图上对应的正方形。
///
/// [scale] = 1 表示图片刚好盖满取景框（短边贴合），[offset] 是图片中心相对取景
/// 框中心的位移。抽成纯函数是因为这段坐标反推没法靠界面看出来对不对 —— 差一个
/// 系数只是头像偏了一点，没人会发现。
AvatarCropRect avatarCropRectFor({
  required Size source,
  required double viewport,
  required double scale,
  required Offset offset,
}) {
  final perPixel = avatarPixelsPerSourcePixel(source, viewport, scale);
  if (!perPixel.isFinite || perPixel <= 0) {
    // 取景框退化成 0（[_AvatarCropPageState._viewportSize] 的下界是 0，为的是在
    // 极矮的可用空间里不溢出）。此时 perPixel 为 0，下面的除法会出 NaN/Infinity，
    // 而 `.round()` 对非有限值直接抛 UnsupportedError —— 退回"居中最大正方形"，
    // 也正是服务端在完全不给裁剪框时的行为。
    final edge = math.min(source.width, source.height);
    return AvatarCropRect(
      x: ((source.width - edge) / 2).round(),
      y: ((source.height - edge) / 2).round(),
      size: edge.round(),
    );
  }
  // 取景框左上角落在图片显示坐标系里的哪个位置 → 除以缩放比就是源图像素。
  final left = (viewport - source.width * perPixel) / 2 + offset.dx;
  final top = (viewport - source.height * perPixel) / 2 + offset.dy;
  return AvatarCropRect(
    x: (-left / perPixel).round(),
    y: (-top / perPixel).round(),
    // round 之后可能比源图边长多 1 像素，服务端会 clamp，这里不重复兜底。
    size: (viewport / perPixel).round(),
  );
}

/// 源图 1 像素在屏幕上占多少逻辑像素（[scale] = 1 时短边恰好盖满取景框）。
double avatarPixelsPerSourcePixel(Size source, double viewport, double scale) {
  return viewport / math.min(source.width, source.height) * scale;
}

/// 把位移收进「图片始终盖满取景框」的范围内。
Offset clampAvatarOffset({
  required Size source,
  required double viewport,
  required double scale,
  required Offset offset,
}) {
  final perPixel = avatarPixelsPerSourcePixel(source, viewport, scale);
  // scale >= 1 保证两个方向的显示尺寸都 >= viewport，所以上限不会是负数。
  final maxDx = math.max(0.0, (source.width * perPixel - viewport) / 2);
  final maxDy = math.max(0.0, (source.height * perPixel - viewport) / 2);
  return Offset(offset.dx.clamp(-maxDx, maxDx), offset.dy.clamp(-maxDy, maxDy));
}

/// 圆形头像裁剪页：拖动 / 双指缩放大图，把要保留的部分对进圆框。
///
/// 手势与取景框自绘而没有用 InteractiveViewer：这里需要从变换反推源图坐标，
/// 自己持有 scale/offset 比读 InteractiveViewer 的矩阵再反推更直接，也更容易
/// 保证「图片始终盖满取景框」这条约束（InteractiveViewer 的 boundaryMargin
/// 表达不了随缩放变化的边界）。
class AvatarCropPage extends StatefulWidget {
  const AvatarCropPage({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<AvatarCropPage> createState() => _AvatarCropPageState();
}

class _AvatarCropPageState extends State<AvatarCropPage> {
  static const _maxScale = 6.0;

  Size? _sourceSize;
  String? _error;

  double _scale = 1;
  Offset _offset = Offset.zero;

  double _gestureStartScale = 1;
  Offset _gestureStartOffset = Offset.zero;
  Offset _gestureStartFocal = Offset.zero;

  @override
  void initState() {
    super.initState();
    unawaited(_decodeSource());
  }

  Future<void> _decodeSource() async {
    try {
      final codec = await instantiateImageCodec(widget.imageBytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() {
        _sourceSize = Size(
          frame.image.width.toDouble(),
          frame.image.height.toDouble(),
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '这张图片无法读取，换一张试试。');
    }
  }

  /// 底部提示文案 + 按钮预留的高度，从可用空间里先扣掉再算取景框。实测约 126，
  /// 取 150 留出字号/安全区的余量 —— 这里**必须**是高估：低估会让取景框比
  /// Expanded 实际拿到的空间还大，直接溢出。
  static const _footerHeight = 150.0;

  /// 取景框边长（正方形）。圆是它的内切圆 —— 头像最终由 ClipOval 渲染，
  /// 真正要裁的是这个外接正方形。
  ///
  /// 下界是 0 而不是某个"最小可用尺寸"：横屏小屏上硬撑一个下界只会换来溢出，
  /// 而裁剪结果由 scale/offset 决定、与取景框大小无关（见 [avatarCropRectFor]），
  /// 框小一点只是难瞄准，不会裁错。
  static double _viewportSize(BoxConstraints constraints) {
    return math
        .min(constraints.maxWidth - 40, constraints.maxHeight - _footerHeight - 40)
        .clamp(0.0, 420.0);
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gestureStartScale = _scale;
    _gestureStartOffset = _offset;
    _gestureStartFocal = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, double viewport) {
    if (_sourceSize == null) return;
    final newScale = (_gestureStartScale * details.scale).clamp(1.0, _maxScale);
    final ratio = newScale / _gestureStartScale;
    // 以手指落点为锚点缩放：先把锚点在内容坐标里的位置按比例放大，再补上这一帧
    // 的平移量。ratio == 1 时退化为纯拖动。
    final center = Offset(viewport / 2, viewport / 2);
    final startFocal = _gestureStartFocal - center;
    final anchor = startFocal - _gestureStartOffset;
    final panned = details.localFocalPoint - _gestureStartFocal;
    final next = startFocal - anchor * ratio + panned;
    setState(() {
      _scale = newScale;
      _offset = clampAvatarOffset(
        source: _sourceSize!,
        viewport: viewport,
        scale: newScale,
        offset: next,
      );
    });
  }

  void _confirm(double viewport) {
    final source = _sourceSize;
    if (source == null) return;
    Navigator.of(context).pop(
      avatarCropRectFor(
        source: source,
        viewport: viewport,
        scale: _scale,
        offset: _offset,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF101014),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: const Color(0xFF101014),
        border: null,
        middle: const Text(
          '调整头像',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消', style: TextStyle(color: Colors.white)),
        ),
      ),
      child: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ),
      );
    }
    if (_sourceSize == null) {
      return const Center(child: CupertinoActivityIndicator(color: Colors.white));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // 取景框边长在这里算一次，取景框和确认按钮共用 —— 两处各算一次迟早会
        // 因为可用空间的算法微调而对不上，裁出来就偏了。
        final viewport = _viewportSize(constraints);
        return Column(
          children: [
            Expanded(child: Center(child: _buildViewport(viewport))),
            const Text(
              '拖动、双指缩放，把想要的部分放进圆圈里',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  // 取景框退化时按钮置灰而不是静默无效：用户看得出这里没法操作。
                  onPressed: viewport <= 0 ? null : () => _confirm(viewport),
                  child: const Text('使用这张'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildViewport(double viewport) {
    final source = _sourceSize!;
    final perPixel = avatarPixelsPerSourcePixel(source, viewport, _scale);
    final displayWidth = source.width * perPixel;
    final displayHeight = source.height * perPixel;
    return GestureDetector(
      onScaleStart: _onScaleStart,
      onScaleUpdate: (details) => _onScaleUpdate(details, viewport),
      child: SizedBox(
        width: viewport,
        height: viewport,
        child: ClipRect(
          child: Stack(
            children: [
              Positioned(
                left: (viewport - displayWidth) / 2 + _offset.dx,
                top: (viewport - displayHeight) / 2 + _offset.dy,
                width: displayWidth,
                height: displayHeight,
                child: Image.memory(
                  widget.imageBytes,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _CircleMaskPainter()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 圆外压暗 + 一圈描边。用 evenOdd 挖洞，比叠四块矩形遮罩少一次布局。
class _CircleMaskPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final circle = Path()
      ..addOval(Rect.fromCircle(
        center: bounds.center,
        radius: size.shortestSide / 2,
      ));
    final mask = Path.combine(
      PathOperation.difference,
      Path()..addRect(bounds),
      circle,
    );
    canvas.drawPath(mask, Paint()..color = const Color(0xB3000000));
    canvas.drawPath(
      circle,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _CircleMaskPainter oldDelegate) => false;
}
