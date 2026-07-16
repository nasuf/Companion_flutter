part of 'package:companion_flutter/main.dart';

/// Keeps native games on one restrained, predictable haptic vocabulary.
class _NativeGameHaptics {
  const _NativeGameHaptics._();

  static void selection() => unawaited(HapticFeedback.selectionClick());

  static void rejected() => unawaited(HapticFeedback.mediumImpact());

  static void placement({bool keyMoment = false}) => unawaited(
    keyMoment ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact(),
  );

  static void pass() => unawaited(HapticFeedback.selectionClick());

  static void capture(int count, {bool keyMoment = false}) => unawaited(
    count >= 3 || keyMoment
        ? HapticFeedback.heavyImpact()
        : HapticFeedback.mediumImpact(),
  );

  static void flip(int count, {bool corner = false}) => unawaited(
    corner || count >= 8
        ? HapticFeedback.heavyImpact()
        : count >= 4
        ? HapticFeedback.mediumImpact()
        : HapticFeedback.lightImpact(),
  );

  static void jump({required int hops, bool keyMoment = false}) => unawaited(
    keyMoment || hops >= 3
        ? HapticFeedback.heavyImpact()
        : hops >= 2
        ? HapticFeedback.mediumImpact()
        : HapticFeedback.lightImpact(),
  );

  static void match3Turn(int cascadeCount) => unawaited(
    cascadeCount >= 3
        ? HapticFeedback.heavyImpact()
        : HapticFeedback.mediumImpact(),
  );

  static void merge(Iterable<int> mergedValues) {
    final values = mergedValues.toList(growable: false);
    unawaited(
      values.any((value) => value >= 128)
          ? HapticFeedback.heavyImpact()
          : values.isNotEmpty
          ? HapticFeedback.mediumImpact()
          : HapticFeedback.selectionClick(),
    );
  }

  static void mineAction({
    required bool hitMine,
    required int revealedCount,
    required bool flagAction,
  }) {
    unawaited(
      hitMine
          ? HapticFeedback.heavyImpact()
          : revealedCount >= 8
          ? HapticFeedback.mediumImpact()
          : flagAction
          ? HapticFeedback.lightImpact()
          : HapticFeedback.selectionClick(),
    );
  }

  static void outcome(String? outcome) {
    if (outcome != null) unawaited(_playOutcome(outcome));
  }

  static Future<void> _playOutcome(String outcome) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));
    switch (outcome) {
      case 'win':
      case 'completed':
        await HapticFeedback.mediumImpact();
        await Future<void>.delayed(const Duration(milliseconds: 90));
        await HapticFeedback.lightImpact();
      case 'lose':
      case 'failed':
        await HapticFeedback.heavyImpact();
      case 'draw':
        await HapticFeedback.mediumImpact();
    }
  }
}
