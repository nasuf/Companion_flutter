import 'package:companion_flutter/src/services/display_refresh_rate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android must not use RefreshRate.boost (it resets the window to 60 Hz)',
    () {
      expect(DisplayRefreshPolicy.usesTemporaryBoost(isAndroid: true), isFalse);
    },
  );

  test('iOS may still use a temporary boost; it does not reset to 60 Hz', () {
    expect(DisplayRefreshPolicy.usesTemporaryBoost(isAndroid: false), isTrue);
  });

  test('Android must not rewrite WindowManager.LayoutParams after launch', () {
    expect(
      DisplayRefreshPolicy.usesPluginWindowHints(isAndroid: true),
      isFalse,
    );
    expect(
      DisplayRefreshPolicy.usesPluginWindowHints(isAndroid: false),
      isTrue,
    );
  });

  test('Android does not re-vote during tab switch', () {
    expect(DisplayRefreshPolicy.androidTabReassertDelays, isEmpty);
  });

  test(
    'already at peak must not recover-vote (ALWAYS would hop 120→30→120)',
    () {
      expect(
        DisplayRefreshPolicy.shouldRecoverVote(
          currentHz: 120,
          peakHz: 120,
          belowPeakFor: Duration.zero,
        ),
        isFalse,
      );
    },
  );

  test('30 Hz LTPO hop must not recover-vote immediately', () {
    expect(DisplayRefreshPolicy.isLtpoHopHz(30), isTrue);
    expect(
      DisplayRefreshPolicy.shouldRecoverVote(
        currentHz: 30,
        peakHz: 120,
        belowPeakFor: const Duration(milliseconds: 80),
      ),
      isFalse,
    );
  });

  test('30 Hz LTPO hop must not recover-vote even after stuckBelowPeak', () {
    expect(
      DisplayRefreshPolicy.shouldRecoverVote(
        currentHz: 30,
        peakHz: 120,
        belowPeakFor: DisplayRefreshPolicy.stuckBelowPeak,
      ),
      isFalse,
    );
  });

  test('sustained 60 Hz drop does recover-vote', () {
    expect(
      DisplayRefreshPolicy.shouldRecoverVote(
        currentHz: 60,
        peakHz: 120,
        belowPeakFor: const Duration(milliseconds: 400),
      ),
      isTrue,
    );
  });
}
