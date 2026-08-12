import 'package:companion_flutter/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 取景框 → 源图像素的坐标反推。
///
/// 这段没法靠肉眼验收：差一个系数只是头像偏了一点，用户不会报，我们也看不出。
void main() {
  const viewport = 300.0;

  group('avatarCropRectFor', () {
    test('untouched landscape framing is a centered square crop', () {
      final rect = avatarCropRectFor(
        source: const Size(1024, 600),
        viewport: viewport,
        scale: 1,
        offset: Offset.zero,
      );

      // 短边 600 决定裁剪边长，长边两侧各留 (1024-600)/2 = 212。
      expect(rect.size, 600);
      expect(rect.x, 212);
      expect(rect.y, 0);
    });

    test('untouched portrait framing crops the vertical middle', () {
      final rect = avatarCropRectFor(
        source: const Size(600, 1024),
        viewport: viewport,
        scale: 1,
        offset: Offset.zero,
      );

      expect(rect.size, 600);
      expect(rect.x, 0);
      expect(rect.y, 212);
    });

    test('a square source at rest crops the whole image', () {
      final rect = avatarCropRectFor(
        source: const Size(800, 800),
        viewport: viewport,
        scale: 1,
        offset: Offset.zero,
      );

      expect(rect.x, 0);
      expect(rect.y, 0);
      expect(rect.size, 800);
    });

    test('zooming in halves the crop edge at 2x', () {
      final rect = avatarCropRectFor(
        source: const Size(800, 800),
        viewport: viewport,
        scale: 2,
        offset: Offset.zero,
      );

      expect(rect.size, 400);
      expect(rect.x, 200);
      expect(rect.y, 200);
    });

    test('panning right moves the crop window left in source pixels', () {
      const source = Size(1024, 600);
      final centered = avatarCropRectFor(
        source: source,
        viewport: viewport,
        scale: 1,
        offset: Offset.zero,
      );
      // 把图往右拖 = 取景框相对图片往左移。
      final panned = avatarCropRectFor(
        source: source,
        viewport: viewport,
        scale: 1,
        offset: const Offset(50, 0),
      );

      expect(panned.x, lessThan(centered.x));
      // 50 逻辑像素 ÷ (300/600 每源像素) = 100 源像素。
      expect(centered.x - panned.x, 100);
      expect(panned.size, centered.size);
    });

    test('panning to the clamp limit lands exactly on the image edge', () {
      const source = Size(1024, 600);
      final limit = clampAvatarOffset(
        source: source,
        viewport: viewport,
        scale: 1,
        offset: const Offset(9999, 0),
      );

      final rect = avatarCropRectFor(
        source: source,
        viewport: viewport,
        scale: 1,
        offset: limit,
      );

      // 顶到边界时裁剪窗口正好贴住图片左沿，不会滑出去露出空白。
      expect(rect.x, 0);
      expect(rect.size, 600);
    });

    test('a degenerate viewport yields the centered max square, not a crash', () {
      // 取景框边长的下界是 0（极矮可用空间下不溢出），此时 perPixel 为 0，
      // 直接做除法会得到 NaN/Infinity，而 `.round()` 对非有限值抛 UnsupportedError。
      for (final degenerate in [0.0, -1.0, double.nan]) {
        final rect = avatarCropRectFor(
          source: const Size(1024, 600),
          viewport: degenerate,
          scale: 1,
          offset: Offset.zero,
        );

        expect(rect.size, 600, reason: 'viewport=$degenerate');
        expect(rect.x, 212, reason: 'viewport=$degenerate');
        expect(rect.y, 0, reason: 'viewport=$degenerate');
      }
    });

    test('the crop window never escapes the source at any clamped offset', () {
      const source = Size(1024, 600);
      for (final scale in [1.0, 1.5, 3.0, 6.0]) {
        for (final raw in [
          const Offset(-9999, -9999),
          const Offset(9999, 9999),
          const Offset(-40, 120),
        ]) {
          final rect = avatarCropRectFor(
            source: source,
            viewport: viewport,
            scale: scale,
            offset: clampAvatarOffset(
              source: source,
              viewport: viewport,
              scale: scale,
              offset: raw,
            ),
          );

          final reason = 'scale=$scale offset=$raw';
          expect(rect.x, greaterThanOrEqualTo(0), reason: reason);
          expect(rect.y, greaterThanOrEqualTo(0), reason: reason);
          expect(rect.x + rect.size, lessThanOrEqualTo(1024), reason: reason);
          expect(rect.y + rect.size, lessThanOrEqualTo(600), reason: reason);
        }
      }
    });
  });

  group('clampAvatarOffset', () {
    test('the short axis cannot move at rest', () {
      // 1024x600 在 scale=1 时高度恰好等于取景框：纵向没有余量可拖。
      final clamped = clampAvatarOffset(
        source: const Size(1024, 600),
        viewport: viewport,
        scale: 1,
        offset: const Offset(0, 80),
      );

      expect(clamped.dy, 0);
    });

    test('zooming opens up travel on both axes', () {
      final clamped = clampAvatarOffset(
        source: const Size(1024, 600),
        viewport: viewport,
        scale: 2,
        offset: const Offset(0, 9999),
      );

      // 600 * (300/600 * 2) = 600 显示高，余量 (600-300)/2 = 150。
      expect(clamped.dy, 150);
    });
  });
}
