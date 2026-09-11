import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Live backdrop blur is disproportionately expensive on Android during scroll
/// and animation. iOS keeps the frosted-glass look unchanged.
bool get useLightweightGlassEffects => Platform.isAndroid;

/// Soft glow blob used on interaction tab backgrounds.
class PlatformSoftAura extends StatelessWidget {
  const PlatformSoftAura({
    super.key,
    required this.size,
    required this.color,
    required this.blur,
  });

  final Size size;
  final Color color;
  final double blur;

  @override
  Widget build(BuildContext context) {
    if (useLightweightGlassEffects) {
      final glowAlpha = (color.a * 1.55).clamp(0.0, 1.0);
      return Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: glowAlpha),
              color.withValues(alpha: glowAlpha * 0.35),
              color.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
      );
    }
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: color,
        ),
      ),
    );
  }
}

/// Frosted panel: BackdropFilter on iOS, static translucent fill on Android.
class PlatformBackdropGlass extends StatelessWidget {
  const PlatformBackdropGlass({
    super.key,
    required this.child,
    this.sigma = 18,
    this.tint,
  });

  final Widget child;
  final double sigma;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    if (useLightweightGlassEffects) {
      return child;
    }
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: tint == null
            ? child
            : ColoredBox(color: tint!, child: child),
      ),
    );
  }
}

/// Dims content when a drawer/sheet opens. iOS uses live blur; Android uses a
/// lightweight scrim so inactive tabs are not re-blurred every frame.
class PlatformSidebarDim extends StatelessWidget {
  const PlatformSidebarDim({
    super.key,
    required this.enabled,
    required this.child,
    this.blurSigma = 9,
    this.scale = 1,
  });

  final bool enabled;
  final Widget child;
  final double blurSigma;
  final double scale;

  @override
  Widget build(BuildContext context) {
    Widget content = child;
    if (enabled) {
      content = useLightweightGlassEffects
          ? ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.10),
                BlendMode.darken,
              ),
              child: child,
            )
          : ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: blurSigma,
                sigmaY: blurSigma,
              ),
              child: child,
            );
    }
    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      child: content,
    );
  }
}
