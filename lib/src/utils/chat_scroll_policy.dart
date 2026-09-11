import 'package:flutter/widgets.dart';

/// Reversed chronological chat list: offset 0 is the newest message (composer
/// edge). Keyboard motion is a compositor slide, not a spacer/jumpTo, so IME
/// frames never relayout bubbles.
class ChatScrollPolicy {
  static const String headerKey = 'chat-list-header';
  static const String messageKeyPrefix = 'chat-message-';

  static const double newestEdgeThreshold = 120;
  static const double oldestEdgeThreshold = 80;
  static const double composerListGap = 18;

  static ScrollPhysics get listPhysics =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  static String messageKey(String id) => '$messageKeyPrefix$id';

  static bool hasLaidOut(ScrollPosition position) =>
      position.hasContentDimensions && position.hasPixels;

  /// Occupancy of the docked chrome (emoji/more panel, or the floating tab
  /// bar). Keyboard height is not included — that is compositor-only.
  static double restLift({
    required double tabBarLift,
    required double panelLift,
  }) => panelLift > 0 ? panelLift : tabBarLift;

  /// Hide the floating tab bar while a composer panel is docked or the IME
  /// is covering the same bottom strip. Cold-keyboard and panel-keyboard
  /// then share one motion source instead of the tab bar fighting the IME.
  static bool hideFloatingTabBar({
    required bool panelDocked,
    required bool imeDocked,
  }) => panelDocked || imeDocked;

  /// Extra translation so the transcript tracks the IME. Rest padding stays
  /// on the composer/tab-bar occupancy; the keyboard delta is composited.
  static double imeSlide({
    required double composerBottom,
    required double restLift,
  }) {
    final slide = composerBottom - restLift;
    return slide > 0.5 ? slide : 0;
  }

  /// Spacer below the newest message while the keyboard is closed (or only
  /// the emoji/more panel is open). Does not include IME height.
  static double restComposerGap({
    required double composerHeight,
    required double restLift,
  }) => composerHeight + restLift + composerListGap;

  /// True when the viewport is glued to the composer / newest messages.
  ///
  /// A [ScrollPosition] can be attached (`hasClients`) before the first
  /// layout fills in extents. Reading `minScrollExtent` then throws.
  static bool isNearNewest(
    ScrollMetrics metrics, {
    double threshold = newestEdgeThreshold,
  }) {
    if (metrics is ScrollPosition && !hasLaidOut(metrics)) return true;
    return metrics.pixels - metrics.minScrollExtent < threshold;
  }

  /// True when the viewport is at the oldest end (load-older trigger).
  static bool isNearOldest(
    ScrollMetrics metrics, {
    double threshold = oldestEdgeThreshold,
  }) {
    if (metrics is ScrollPosition && !hasLaidOut(metrics)) return false;
    return metrics.maxScrollExtent - metrics.pixels < threshold;
  }

  /// Builder order in a reversed sliver: newest is index 0.
  static int? childIndexForKey(Key key, List<String> chronologicalIds) {
    if (key is! ValueKey<String>) return null;
    final value = key.value;
    if (!value.startsWith(messageKeyPrefix)) return null;
    final id = value.substring(messageKeyPrefix.length);
    final chronologicalIndex = chronologicalIds.indexOf(id);
    if (chronologicalIndex < 0) return null;
    return chronologicalIds.length - 1 - chronologicalIndex;
  }

  static double estimatedOffsetForChronologicalIndex({
    required int chronologicalIndex,
    required int messageCount,
    required double maxScrollExtent,
    double estimatedItemExtent = 90,
  }) {
    final fromNewest = messageCount - 1 - chronologicalIndex;
    return (fromNewest * estimatedItemExtent).clamp(0.0, maxScrollExtent);
  }
}
