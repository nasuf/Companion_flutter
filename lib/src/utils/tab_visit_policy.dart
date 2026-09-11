import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

/// Chat tab is always mounted. Other tabs are GPU-heavy on Android after a
/// visit because IndexedStack keeps Offstage subtrees (decoded images, shadow
/// layers) alive. iOS is not stuttering, so it keeps the historical keep-alive.
bool get unmountInactiveNonChatTabs => Platform.isAndroid;

const int chatTabIndex = 0;

/// Portal JPEGs on the 互动 tab. Evict only these — never [ImageCache.clear].
const List<String> onlinePortalAssetPaths = [
  'assets/prototype/daily-journal.jpg',
  'assets/prototype/movie-bouquet.jpg',
  'assets/prototype/game-pieces.jpg',
  'assets/prototype/vinyl-record.jpg',
];

Set<int> nextVisitedTabs({
  required Set<int> current,
  required int selectedIndex,
  bool? unmountInactiveNonChat,
}) {
  final unmount = unmountInactiveNonChat ?? unmountInactiveNonChatTabs;
  if (!unmount) {
    return {...current, selectedIndex};
  }
  return {chatTabIndex, selectedIndex};
}

void evictOnlinePortalImages() {
  for (final path in onlinePortalAssetPaths) {
    unawaited(AssetImage(path).evict());
  }
}
