import 'package:companion_flutter/src/utils/tab_visit_policy.dart';
import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS keep-alive still accumulates visited tabs', () {
    var visited = {chatTabIndex};
    visited = nextVisitedTabs(
      current: visited,
      selectedIndex: 1,
      unmountInactiveNonChat: false,
    );
    visited = nextVisitedTabs(
      current: visited,
      selectedIndex: 2,
      unmountInactiveNonChat: false,
    );
    visited = nextVisitedTabs(
      current: visited,
      selectedIndex: chatTabIndex,
      unmountInactiveNonChat: false,
    );
    expect(visited, {0, 1, 2});
  });

  test('Android unmounts non-chat tabs when leaving them', () {
    var visited = {chatTabIndex};
    visited = nextVisitedTabs(
      current: visited,
      selectedIndex: 1,
      unmountInactiveNonChat: true,
    );
    expect(visited, {0, 1});
    visited = nextVisitedTabs(
      current: visited,
      selectedIndex: 2,
      unmountInactiveNonChat: true,
    );
    expect(visited, {0, 2});
    visited = nextVisitedTabs(
      current: visited,
      selectedIndex: 3,
      unmountInactiveNonChat: true,
    );
    expect(visited, {0, 3});
    visited = nextVisitedTabs(
      current: visited,
      selectedIndex: chatTabIndex,
      unmountInactiveNonChat: true,
    );
    expect(visited, {0});
  });

  test('chat tab is never dropped from the visited set', () {
    final visited = nextVisitedTabs(
      current: {0, 1, 2, 3},
      selectedIndex: 1,
      unmountInactiveNonChat: true,
    );
    expect(visited.contains(chatTabIndex), isTrue);
    expect(visited, {0, 1});
  });

  test('covered routes pause every tab, not only chat', () {
    expect(tabTickersEnabled(selected: true, routeCovered: false), isTrue);
    expect(tabTickersEnabled(selected: true, routeCovered: true), isFalse);
    expect(tabTickersEnabled(selected: false, routeCovered: false), isFalse);
    expect(tabTickersEnabled(selected: false, routeCovered: true), isFalse);
  });

  test('incoming routes freeze tickers until the push animation completes', () {
    expect(
      incomingRouteTickersEnabled(
        coveredOrPopping: false,
        animationStatus: AnimationStatus.forward,
      ),
      isFalse,
    );
    expect(
      incomingRouteTickersEnabled(
        coveredOrPopping: false,
        animationStatus: AnimationStatus.dismissed,
      ),
      isFalse,
    );
    expect(
      incomingRouteTickersEnabled(
        coveredOrPopping: false,
        animationStatus: AnimationStatus.completed,
      ),
      isTrue,
    );
    expect(
      incomingRouteTickersEnabled(
        coveredOrPopping: false,
        animationStatus: null,
      ),
      isTrue,
    );
    expect(
      incomingRouteTickersEnabled(
        coveredOrPopping: true,
        animationStatus: AnimationStatus.completed,
      ),
      isFalse,
    );
  });
}
