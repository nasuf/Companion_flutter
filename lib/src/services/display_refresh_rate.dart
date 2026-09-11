import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:refresh_rate/refresh_rate.dart';

/// ColorOS LTPO hops 120→30→120 when we call setFrameRate(ALWAYS) while
/// already at peak. Native code mirrors these rules.
@visibleForTesting
class DisplayRefreshPolicy {
  /// [RefreshRate.boost] on Android ends with `resetToDefault()`. Never use it.
  static bool usesTemporaryBoost({required bool isAndroid}) => !isAndroid;

  /// Plugin preferMax/matchContent rewrite WindowManager.LayoutParams and
  /// ColorOS treats that as "leave launch boost → 60 Hz".
  static bool usesPluginWindowHints({required bool isAndroid}) => !isAndroid;

  static const peakSlackHz = 8.0;
  static const ltpoHopMinHz = 20.0;
  static const ltpoHopMaxHz = 40.0;
  static const stuckBelowPeak = Duration(milliseconds: 400);

  /// Tab-switch lockPeak spam retriggers ALWAYS and flashes 30 Hz.
  static const androidTabReassertDelays = <Duration>[];

  static const pointerThrottle = Duration(milliseconds: 400);

  static bool isLtpoHopHz(double hz) =>
      hz >= ltpoHopMinHz && hz <= ltpoHopMaxHz;

  /// Vote only after a real drop (typically 60 Hz) has lasted long enough.
  /// Ignore already-at-peak and the 30 Hz LTPO hop.
  static bool shouldRecoverVote({
    required double currentHz,
    required double peakHz,
    required Duration belowPeakFor,
  }) {
    if (currentHz >= peakHz - peakSlackHz) return false;
    if (belowPeakFor < stuckBelowPeak) return false;
    return true;
  }
}

/// Opts the app into the device peak refresh rate.
///
/// iOS: [RefreshRate.enable] / [RefreshRate.preferMax] (CADisplayLink).
/// Android: native SurfaceControl vote. Do not re-vote during tab switches
/// while already at 120 Hz — that forces a 120→30→120 LTPO hop.
class DisplayRefreshRate {
  static const _nativeChannel = MethodChannel('companion/display_refresh');

  static bool _enabled = false;
  static DateTime? _lastPointerPersist;

  static Future<void> initialize() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      if (Platform.isIOS) {
        RefreshRate.enable();
        RefreshRate.preferMax();
      }
      _enabled = true;
    } catch (error, stackTrace) {
      debugPrint('[display] refresh rate enable failed: $error\n$stackTrace');
    }
  }

  static void handleAppLifecycleState(AppLifecycleState state) {
    if (!_enabled) return;
    if (state == AppLifecycleState.resumed) {
      _persistPeakRate();
    }
  }

  static void onUserInteraction() {
    if (!_enabled) return;
    if (Platform.isIOS) _persistPeakRate();
  }

  /// Android must not re-vote here. Tab taps already hit [onPointerActivity],
  /// and a peak-rate ALWAYS vote is what flashes 30 Hz on ColorOS.
  static void onTabBecameVisible() {
    if (!_enabled) return;
    if (Platform.isIOS) _persistPeakRate();
  }

  static void onPointerActivity() {
    if (!_enabled || !Platform.isAndroid) return;
    final now = DateTime.now();
    final last = _lastPointerPersist;
    if (last != null &&
        now.difference(last) < DisplayRefreshPolicy.pointerThrottle) {
      return;
    }
    _lastPointerPersist = now;
    _lockNativePeak();
  }

  static void _persistPeakRate() {
    try {
      if (Platform.isIOS) {
        RefreshRate.preferMax();
        return;
      }
      if (Platform.isAndroid) {
        _lockNativePeak();
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[display] persist peak rate failed: $error');
      }
    }
  }

  static void _lockNativePeak() {
    if (!Platform.isAndroid) return;
    unawaited(_invokeNativeLock());
  }

  static Future<void> _invokeNativeLock() async {
    try {
      await _nativeChannel.invokeMethod<void>('lockPeak');
    } catch (_) {}
  }
}

/// Forwards pointer events so Android can recover a real 60 Hz drop.
/// Native no-ops when already at peak, so this does not flash 30 Hz.
class DisplayRefreshGate extends StatelessWidget {
  const DisplayRefreshGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !Platform.isAndroid) return child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => DisplayRefreshRate.onPointerActivity(),
      onPointerMove: (_) => DisplayRefreshRate.onPointerActivity(),
      child: child,
    );
  }
}
