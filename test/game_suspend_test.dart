import 'package:companion_flutter/src/games/game_suspend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bar pull progress grows with horizontal drag away from edge', () {
    const screen = Size(400, 844);
    expect(
      barPullProgressFromDrag(
        pullPx: 0,
        screen: screen,
        edge: GameFloatEdge.right,
      ),
      0,
    );
    final thumbWidth = gameFloatThumbSize(screen).width;
    final maxPull = maxBarPullDistance(
      screen: screen,
      edge: GameFloatEdge.right,
      thumbWidth: thumbWidth,
    );
    expect(maxPull, greaterThan(0));
    expect(
      barPullProgressFromDrag(
        pullPx: maxPull,
        screen: screen,
        edge: GameFloatEdge.right,
      ),
      closeTo(1, 0.001),
    );
  });

  test('docked bar pull visual stays flush with the screen edge while growing', () {
    const screen = Size(400, 844);
    const padding = EdgeInsets.zero;
    const centerY = 200.0;
    final docked = computeBarPullVisual(
      edge: GameFloatEdge.right,
      centerY: centerY,
      progress: 0,
      screen: screen,
      padding: padding,
    );
    expect(docked.rect.right, closeTo(400, 0.001));
    expect(docked.rect.width, gameFloatBarWidth);
    expect(docked.flushOuterEdge, isFalse);

    final growing = computeBarPullVisual(
      edge: GameFloatEdge.right,
      centerY: centerY,
      progress: 0.35,
      screen: screen,
      padding: padding,
    );
    expect(growing.rect.right, closeTo(400, 0.001));
    expect(growing.rect.width, greaterThan(gameFloatBarWidth));

    final thumbWidth = gameFloatThumbSize(screen).width;
    final resting = computeBarPullVisual(
      edge: GameFloatEdge.right,
      centerY: centerY,
      progress: 1,
      screen: screen,
      padding: padding,
    );
    expect(
      resting.rect.left,
      thumbLeftForEdge(
        edge: GameFloatEdge.right,
        screenWidth: screen.width,
        thumbWidth: thumbWidth,
      ),
    );
    expect(resting.flushOuterEdge, isFalse);
  });

  test('dock cluster keeps cards flush with the screen edge while pulling', () {
    const screen = Size(400, 844);
    final rightMidShrink =
        multiCardStackProgressThreshold(
          screen: screen,
          edge: GameFloatEdge.right,
          count: 2,
        ) *
        0.35;
    final visual = computeDockClusterVisual(
      entryIds: ['a', 'b'],
      edge: GameFloatEdge.right,
      centerY: 200,
      progress: rightMidShrink,
      screen: screen,
      padding: EdgeInsets.zero,
    );
    expect(visual.cards, isNotEmpty);
    expect(visual.cards.last.rect.right, closeTo(400, 1));

    final leftMidShrink =
        multiCardStackProgressThreshold(
          screen: screen,
          edge: GameFloatEdge.left,
          count: 2,
        ) *
        0.35;
    final leftVisual = computeDockClusterVisual(
      entryIds: ['a', 'b'],
      edge: GameFloatEdge.left,
      centerY: 200,
      progress: leftMidShrink,
      screen: screen,
      padding: EdgeInsets.zero,
    );
    expect(leftVisual.cards, isNotEmpty);
    expect(leftVisual.cards.first.rect.left, closeTo(0, 1));
  });

  test('multi-card collapse keeps rounded corners on the edge card', () {
    const screen = Size(400, 844);
    final stackThreshold = multiCardStackProgressThreshold(
      screen: screen,
      edge: GameFloatEdge.right,
      count: 2,
    );
    final midStack =
        stackThreshold + (1 - stackThreshold) * 0.5;
    final overlap = computeDockClusterVisual(
      entryIds: ['a', 'b'],
      edge: GameFloatEdge.right,
      centerY: 200,
      progress: midStack,
      screen: screen,
      padding: EdgeInsets.zero,
    );
    final edgeCard = overlap.cards.firstWhere((card) => card.entryId == 'b');
    expect(edgeCard.flushOuterEdge, isFalse);
    expect(edgeCard.radius, greaterThan(0));

    final shrinking = computeDockClusterVisual(
      entryIds: ['a', 'b'],
      edge: GameFloatEdge.right,
      centerY: 200,
      progress: stackThreshold * 0.5,
      screen: screen,
      padding: EdgeInsets.zero,
    );
    expect(
      shrinking.cards.every((card) => !card.flushOuterEdge),
      isTrue,
    );
  });

  test('multi-card collapse stacks the inner card onto the edge card', () {
    const screen = Size(400, 844);
    final spread = computeDockClusterVisual(
      entryIds: ['a', 'b'],
      edge: GameFloatEdge.right,
      centerY: 200,
      progress: 1,
      screen: screen,
      padding: EdgeInsets.zero,
    );
    final cardA = spread.cards.firstWhere((card) => card.entryId == 'a');
    final cardB = spread.cards.firstWhere((card) => card.entryId == 'b');
    expect(cardA.rect.left, lessThan(cardB.rect.left));

    final stackThreshold = multiCardStackProgressThreshold(
      screen: screen,
      edge: GameFloatEdge.right,
      count: 2,
    );
    final stacked = computeDockClusterVisual(
      entryIds: ['a', 'b'],
      edge: GameFloatEdge.right,
      centerY: 200,
      progress: stackThreshold,
      screen: screen,
      padding: EdgeInsets.zero,
    );
    expect(stacked.cards.first.rect.left, closeTo(cardB.rect.left, 1));
    expect(stacked.cards.last.rect.left, closeTo(cardB.rect.left, 1));

    final mid = computeDockClusterVisual(
      entryIds: ['a', 'b'],
      edge: GameFloatEdge.right,
      centerY: 200,
      progress: 0.81,
      screen: screen,
      padding: EdgeInsets.zero,
    );
    final midA = mid.cards.firstWhere((card) => card.entryId == 'a');
    final midB = mid.cards.firstWhere((card) => card.entryId == 'b');
    expect(midA.rect.left, greaterThan(cardA.rect.left));
    expect(midA.rect.right, greaterThan(midB.rect.left));
  });

  test('multi-game dock cluster respects left edge at full reveal', () {
    const screen = Size(400, 844);
    final visual = computeDockClusterVisual(
      entryIds: ['a', 'b'],
      edge: GameFloatEdge.left,
      centerY: 200,
      progress: 1,
      screen: screen,
      padding: EdgeInsets.zero,
    );
    expect(visual.cards, hasLength(2));
    expect(visual.cards.first.rect.left, closeTo(gameFloatThumbGap, 2));
  });

  test('dock preview scrim fades in with peel progress', () {
    expect(scrimOpacityFromDockPullProgress(0), 0);
    expect(scrimOpacityFromDockPullProgress(0.04), 0);
    expect(
      scrimOpacityFromDockPullProgress(1),
      closeTo(gameFloatDockScrimMaxOpacity, 0.01),
    );
  });

  test('multi-card collapse pull distance fits stack plus shrink travel', () {
    const screen = Size(400, 844);
    for (final count in [2, 3]) {
      final collapseMax = maxDockPullDistance(
        screen: screen,
        edge: GameFloatEdge.right,
        count: count,
        collapsing: true,
      );
      final expandMax = maxDockPullDistance(
        screen: screen,
        edge: GameFloatEdge.right,
        count: count,
        collapsing: false,
      );
      final expected =
          multiCardStackTravel(screen: screen, count: count) +
          multiCardShrinkTravel(screen: screen, edge: GameFloatEdge.right);
      expect(collapseMax, closeTo(expected, 0.01));
      expect(collapseMax, lessThan(expandMax));

      final progressAtFullCollapse = dockPullProgressFromDragDelta(
        dragDelta: Offset(collapseMax, 0),
        startProgress: 1,
        screen: screen,
        edge: GameFloatEdge.right,
        count: count,
      );
      expect(progressAtFullCollapse, closeTo(0, 0.01));
    }
  });

  test('multi-card stack threshold scales with card count', () {
    const screen = Size(400, 844);
    final twoCard = multiCardStackProgressThreshold(
      screen: screen,
      edge: GameFloatEdge.right,
      count: 2,
    );
    final threeCard = multiCardStackProgressThreshold(
      screen: screen,
      edge: GameFloatEdge.right,
      count: 3,
    );
    expect(twoCard, greaterThan(0));
    expect(twoCard, lessThan(1));
    expect(threeCard, lessThan(twoCard));
  });

  test('outward drag from a resting preview reduces pull progress', () {
    const screen = Size(400, 844);
    final maxPull = maxDockPullDistance(
      screen: screen,
      edge: GameFloatEdge.right,
      count: 1,
    );
    expect(
      dockPullProgressFromDragDelta(
        dragDelta: Offset(maxPull * 0.5, 0),
        startProgress: 1,
        screen: screen,
        edge: GameFloatEdge.right,
        count: 1,
      ),
      closeTo(0.5, 0.01),
    );
    final leftPeel = dockPullProgressFromDragDelta(
      dragDelta: const Offset(-40, 0),
      startProgress: 1,
      screen: screen,
      edge: GameFloatEdge.left,
      count: 2,
    );
    expect(leftPeel, lessThan(1.0));
    expect(leftPeel, greaterThan(0.0));
  });

  test('cluster snap prefers the closer screen edge by bounds', () {
    const screenWidth = 400.0;
    expect(
      nearestHorizontalEdgeForBounds(
        bounds: const Rect.fromLTWH(8, 0, 220, 100),
        screenWidth: screenWidth,
      ),
      GameFloatEdge.left,
    );
    expect(
      nearestHorizontalEdgeForBounds(
        bounds: const Rect.fromLTWH(172, 0, 220, 100),
        screenWidth: screenWidth,
      ),
      GameFloatEdge.right,
    );
  });

  test('docked multi-game cluster shows only the thin bar at progress zero', () {
    const screen = Size(400, 844);
    final visual = computeDockClusterVisual(
      entryIds: ['a', 'b'],
      edge: GameFloatEdge.right,
      centerY: 200,
      progress: 0,
      screen: screen,
      padding: EdgeInsets.zero,
    );
    expect(visual.showBar, isTrue);
    expect(visual.cards, isEmpty);
    expect(visual.barRect.width, gameFloatBarWidth);
  });

  test('free preview layout centers cards on the given point', () {
    const screen = Size(400, 844);
    const center = Offset(180, 220);
    final visual = computeDockClusterVisualFree(
      entryIds: ['a'],
      center: center,
      screen: screen,
      padding: EdgeInsets.zero,
    );
    expect(visual.cards, hasLength(1));
    expect(
      clusterBoundsFromVisual(visual).center.dx,
      closeTo(center.dx, 1),
    );
    expect(visual.showBar, isFalse);
  });

  test('early dock pull clips cards to the visible strip width', () {
    const screen = Size(400, 844);
    final visual = computeDockClusterVisual(
      entryIds: ['a', 'b'],
      edge: GameFloatEdge.right,
      centerY: 200,
      progress: 0.08,
      screen: screen,
      padding: EdgeInsets.zero,
    );
    expect(visual.cards, isNotEmpty);
    for (final card in visual.cards) {
      expect(card.rect.width, lessThan(gameFloatThumbWidth));
    }
  });

  test('canMinimize stops after three games are already suspended', () {
    final controller = GameSuspendController();
    for (final id in ['a', 'b', 'c', 'd']) {
      controller.open(
        id: id,
        title: id,
        previewAsset: '',
        pageBuilder: (_) => const SizedBox.shrink(),
      );
      controller.setPhase(id, GameFloatPhase.bar);
    }
    controller.setPhase('d', GameFloatPhase.expanded);
    expect(controller.suspendedCount, gameFloatMaxSuspended);
    expect(controller.canMinimize('d'), isFalse);
    controller.closeAll();
  });

  test('thumbnail snaps to the nearer horizontal edge', () {
    expect(nearestHorizontalEdge(centerX: 120, width: 400), GameFloatEdge.left);
    expect(
      nearestHorizontalEdge(centerX: 200, width: 400),
      GameFloatEdge.right,
    );
    expect(thumbLeftForEdge(edge: GameFloatEdge.left, screenWidth: 400), 8);
    expect(
      thumbLeftForEdge(edge: GameFloatEdge.right, screenWidth: 400),
      400 - gameFloatThumbWidth - gameFloatThumbGap,
    );
    expect(barLeftForEdge(edge: GameFloatEdge.left, screenWidth: 400), 0);
    expect(
      barLeftForEdge(edge: GameFloatEdge.right, screenWidth: 400),
      400 - gameFloatBarWidth,
    );
  });

  test(
    'thumbnail keeps the screen aspect so it can grow back without cropping',
    () {
      const screen = Size(390, 844);
      final thumb = gameFloatThumbSize(screen);
      expect(
        thumb.width / thumb.height,
        closeTo(screen.width / screen.height, 0.001),
      );
      expect(thumb.width, lessThanOrEqualTo(gameFloatThumbWidth));
    },
  );

  test('requestMinimize freezes the round before capture starts', () {
    final controller = GameSuspendController();
    controller.open(
      id: 'gomoku',
      title: '五子棋',
      previewAsset: 'assets/poster.png',
      pageBuilder: (_) => const SizedBox.shrink(),
    );
    expect(controller.isPresented('gomoku'), isTrue);
    controller.requestMinimize('gomoku');
    expect(controller.isPresented('gomoku'), isFalse);
    expect(controller.find('gomoku')!.phase, GameFloatPhase.expanded);
    controller.closeAll();
  });

  test('a minimized round stays frozen until the zoom-in has settled', () {
    final controller = GameSuspendController();
    final done = controller.open(
      id: 'gomoku',
      title: '五子棋',
      previewAsset: 'assets/poster.png',
      pageBuilder: (_) => const SizedBox.shrink(),
    );
    expect(controller.isPresented('gomoku'), isTrue);
    controller.setPhase('gomoku', GameFloatPhase.minimizing);
    expect(controller.isPresented('gomoku'), isFalse);
    controller.setPhase('gomoku', GameFloatPhase.bar);
    controller.markPresented('gomoku');
    expect(controller.isPresented('gomoku'), isFalse);
    controller.setPhase('gomoku', GameFloatPhase.expanded);
    expect(controller.isPresented('gomoku'), isFalse);
    controller.markPresented('gomoku');
    expect(controller.isPresented('gomoku'), isTrue);
    controller.closeAll();
    done.ignore();
  });

  test('five seconds without a touch is long enough to fold the thumbnail', () {
    final touched = DateTime(2026, 9, 25, 15);
    expect(
      gameFloatIdleElapsed(
        now: touched.add(const Duration(seconds: 5)),
        lastTouch: touched,
      ),
      isTrue,
    );
    expect(
      gameFloatIdleElapsed(
        now: touched.add(const Duration(seconds: 4)),
        lastTouch: touched,
      ),
      isFalse,
    );
  });

  testWidgets(
    'suspending keeps the same round and the bar starts on the right',
    (tester) async {
      final controller = GameSuspendController();
      await _pumpHost(tester, controller);

      await tester.tap(find.text('open-gomoku'));
      await tester.pump();
      expect(find.text('round-1-gomoku'), findsOneWidget);

      await tester.tap(find.text('score'));
      await tester.pump();
      expect(find.text('round-2-gomoku'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('game-suspend-button-gomoku')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      expect(find.text('round-2-gomoku'), findsNothing);
      final preview = controller.find('gomoku')?.preview;
      expect(preview, isNotNull);
      final shot = preview!;
      final pixels = await tester.runAsync(() => shot.toByteData());
      expect(pixels, isNotNull);
      final bytes = pixels!.buffer.asUint8List();
      var foundMarker = false;
      for (var i = 0; i + 3 < bytes.length; i += 64) {
        final red = bytes[i];
        final green = bytes[i + 1];
        final blue = bytes[i + 2];
        if (red > 30 &&
            red < 80 &&
            green > 70 &&
            green < 130 &&
            blue > 120 &&
            blue < 190) {
          foundMarker = true;
          break;
        }
      }
      expect(foundMarker, isTrue);
      final bar = find.byKey(const ValueKey('game-float-dock-bar'));
      expect(bar, findsOneWidget);
      final width = tester.getSize(find.byType(GameSuspendHost)).width;
      expect(tester.getTopLeft(bar).dx, width - gameFloatBarWidth);

      await tester.tap(bar);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('game-float-dock-card-gomoku')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('game-float-dock-card-gomoku')),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('round-2-gomoku'), findsOneWidget);
      controller.closeAll();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('the first bar drag expands immediately without a widget swap', (
    tester,
  ) async {
    final controller = GameSuspendController();
    await _pumpHost(tester, controller);

    await tester.tap(find.text('open-gomoku'));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('game-suspend-button-gomoku')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    final bar = find.byKey(const ValueKey('game-float-dock-bar'));
    expect(bar, findsOneWidget);

    final topLeft = tester.getTopLeft(bar);
    final gesture = await tester.startGesture(
      topLeft + const Offset(10, gameFloatBarHeight / 2),
    );
    await tester.pump();
    await gesture.moveBy(const Offset(-56, 0));
    await tester.pump();

    final card = find.byKey(const ValueKey('game-float-dock-card-gomoku'));
    expect(card, findsOneWidget);
    expect(tester.getSize(card).width, greaterThan(gameFloatBarWidth));

    await gesture.up();
    await tester.pumpAndSettle();
    controller.closeAll();
    await tester.pumpAndSettle();
  });

  testWidgets('pulling the bar far enough commits to a thumbnail', (
    tester,
  ) async {
    final controller = GameSuspendController();
    await _pumpHost(tester, controller);

    await tester.tap(find.text('open-gomoku'));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('game-suspend-button-gomoku')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    final bar = find.byKey(const ValueKey('game-float-dock-bar'));
    expect(bar, findsOneWidget);
    await tester.drag(bar, const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('game-float-dock-card-gomoku')),
      findsOneWidget,
    );
    expect(controller.find('gomoku')!.phase, GameFloatPhase.thumbnail);

    controller.closeAll();
    await tester.pumpAndSettle();
  });

  testWidgets('float close button dismisses the suspended game', (
    tester,
  ) async {
    _MarkerState.forfeited = false;
    final controller = GameSuspendController();
    await _pumpHost(tester, controller);

    await tester.tap(find.text('open-gomoku'));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('game-suspend-button-gomoku')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('game-float-dock-bar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game-float-close')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('game-float-close')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('game-float-dock-card-gomoku')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('game-float-dock-bar')), findsNothing);
    expect(_MarkerState.forfeited, isTrue);
    expect(controller.entries, isEmpty);
  });

  testWidgets('restoring one game collapses other revealed previews', (
    tester,
  ) async {
    final controller = GameSuspendController();
    await _pumpHost(tester, controller, entryIds: ['gomoku', 'chess']);

    for (final id in ['gomoku', 'chess']) {
      await tester.tap(find.text('open-$id'));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('game-suspend-button-$id')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byKey(const ValueKey('game-float-dock-bar')));
    await tester.pumpAndSettle();
    expect(controller.find('gomoku')!.phase, GameFloatPhase.thumbnail);
    expect(controller.find('chess')!.phase, GameFloatPhase.thumbnail);

    await tester.tap(find.byKey(const ValueKey('game-float-dock-card-gomoku')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(controller.find('chess')!.phase, isNot(GameFloatPhase.expanded));
    expect(
      controller.find('chess')!.phase == GameFloatPhase.bar ||
          controller.find('chess')!.phase == GameFloatPhase.thumbnail,
      isTrue,
    );

    await tester.pumpAndSettle();
    expect(find.text('round-1-gomoku'), findsOneWidget);
    expect(controller.find('chess')!.phase, GameFloatPhase.bar);

    controller.closeAll();
    await tester.pumpAndSettle();
  });

  testWidgets('only one dock bar is shown for multiple suspended games', (
    tester,
  ) async {
    final controller = GameSuspendController();
    await _pumpHost(tester, controller, entryIds: ['gomoku', 'chess']);

    for (final id in ['gomoku', 'chess']) {
      await tester.tap(find.text('open-$id'));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('game-suspend-button-$id')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
    }

    expect(find.byKey(const ValueKey('game-float-dock-bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('game-float-dock-bar-gomoku')), findsNothing);
    expect(find.byKey(const ValueKey('game-float-dock-bar-chess')), findsNothing);
    expect(controller.suspendedCount, 2);

    final cluster = computeDockClusterVisual(
      entryIds: ['gomoku', 'chess'],
      edge: GameFloatEdge.right,
      centerY: 200,
      progress: 1,
      screen: const Size(800, 600),
      padding: EdgeInsets.zero,
    );
    expect(cluster.cards.length, 2);

    controller.closeAll();
    await tester.pumpAndSettle();
  });

  testWidgets('the suspend button disables when three games are suspended', (
    tester,
  ) async {
    final controller = GameSuspendController();
    await _pumpHost(
      tester,
      controller,
      entryIds: ['a', 'b', 'c', 'd'],
    );

    for (final id in ['a', 'b', 'c']) {
      await tester.tap(find.text('open-$id'));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('game-suspend-button-$id')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('open-d'));
    await tester.pump();
    final button = find.byKey(const ValueKey('game-suspend-button-d'));
    expect(button, findsOneWidget);
    expect(controller.canMinimize('d'), isFalse);
    await tester.tap(button);
    await tester.pump();
    expect(controller.find('d')!.phase, GameFloatPhase.expanded);

    controller.closeAll();
    await tester.pumpAndSettle();
  });

  testWidgets('dock preview scrim is hidden while only the bar is shown', (
    tester,
  ) async {
    final controller = GameSuspendController();
    await _pumpHost(tester, controller);

    await tester.tap(find.text('open-gomoku'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('game-suspend-button-gomoku')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('game-float-dock-bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('game-float-dock-scrim')), findsNothing);

    controller.closeAll();
    await tester.pumpAndSettle();
  });

  testWidgets('tapping outside a revealed preview collapses back to the bar', (
    tester,
  ) async {
    final controller = GameSuspendController();
    await _pumpHost(tester, controller);

    await tester.tap(find.text('open-gomoku'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('game-suspend-button-gomoku')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('game-float-dock-bar')));
    await tester.pumpAndSettle();
    expect(controller.find('gomoku')!.phase, GameFloatPhase.thumbnail);
    expect(find.byKey(const ValueKey('game-float-dock-scrim')), findsOneWidget);

    await tester.tapAt(const Offset(200, 300));
    await tester.pumpAndSettle();
    expect(controller.find('gomoku')!.phase, GameFloatPhase.bar);
    expect(find.byKey(const ValueKey('game-float-dock-scrim')), findsNothing);

    controller.closeAll();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'dragging a snapped preview toward the edge collapses into the bar',
    (tester) async {
      final controller = GameSuspendController();
      await _pumpHost(tester, controller);

      await tester.tap(find.text('open-gomoku'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('game-suspend-button-gomoku')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('game-float-dock-bar')));
      await tester.pumpAndSettle();
      expect(controller.find('gomoku')!.phase, GameFloatPhase.thumbnail);

      final card = find.byKey(const ValueKey('game-float-dock-card-gomoku'));
      await tester.drag(card, const Offset(120, 0), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(controller.find('gomoku')!.phase, GameFloatPhase.bar);

      controller.closeAll();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'multiple revealed previews snap to the left when dragged there',
    (tester) async {
      final controller = GameSuspendController();
      await _pumpHost(tester, controller, entryIds: ['gomoku', 'chess']);

      for (final id in ['gomoku', 'chess']) {
        await tester.tap(find.text('open-$id'));
        await tester.pump();
        await tester.tap(find.byKey(ValueKey('game-suspend-button-$id')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 900));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byKey(const ValueKey('game-float-dock-bar')));
      await tester.pumpAndSettle();
      expect(controller.find('gomoku')!.phase, GameFloatPhase.thumbnail);
      expect(controller.find('chess')!.phase, GameFloatPhase.thumbnail);

      final card = find.byKey(const ValueKey('game-float-dock-card-gomoku'));
      await tester.drag(card, const Offset(-600, 20), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(controller.find('gomoku')!.edge, GameFloatEdge.left);
      expect(controller.find('chess')!.edge, GameFloatEdge.left);
      final leftCard = tester.getTopLeft(
        find.byKey(const ValueKey('game-float-dock-card-gomoku')),
      );
      expect(leftCard.dx, closeTo(gameFloatThumbGap, 4));

      controller.closeAll();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('a revealed preview can move freely and snap to the nearest edge', (
    tester,
  ) async {
    final controller = GameSuspendController();
    await _pumpHost(tester, controller);

    await tester.tap(find.text('open-gomoku'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('game-suspend-button-gomoku')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('game-float-dock-bar')));
    await tester.pumpAndSettle();
    expect(controller.find('gomoku')!.phase, GameFloatPhase.thumbnail);

    final card = find.byKey(const ValueKey('game-float-dock-card-gomoku'));
    final before = tester.getTopLeft(card);
    await tester.drag(card, const Offset(-400, 40), warnIfMissed: false);
    await tester.pump();
    final during = tester.getTopLeft(card);
    expect(during.dx, lessThan(before.dx - 80));
    expect(during.dy, greaterThan(before.dy + 10));

    await tester.pumpAndSettle();
    expect(controller.find('gomoku')!.phase, GameFloatPhase.thumbnail);
    expect(controller.find('gomoku')!.edge, GameFloatEdge.left);
    final after = tester.getTopLeft(card);
    expect(after.dx, lessThan(40));

    controller.closeAll();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'a revealed dock folds back into a bar after 5s without touch',
    (tester) async {
      final controller = GameSuspendController();
      await _pumpHost(tester, controller);

      await tester.tap(find.text('open-gomoku'));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('game-suspend-button-gomoku')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('game-float-dock-bar')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('game-float-dock-card-gomoku')),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 4));
      expect(
        find.byKey(const ValueKey('game-float-dock-card-gomoku')),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('game-float-dock-bar')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('game-float-dock-card-gomoku')),
        findsNothing,
      );
      controller.closeAll();
      await tester.pumpAndSettle();
    },
  );
}

Future<void> _pumpHost(
  WidgetTester tester,
  GameSuspendController controller, {
  List<String> entryIds = const ['gomoku'],
}) {
  return tester.pumpWidget(
    MaterialApp(
      builder: (context, child) {
        return GameSuspendHost(
          controller: controller,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: Scaffold(
        body: Column(
          children: [
            for (final id in entryIds)
              TextButton(
                onPressed: () {
                  controller.open(
                    id: id,
                    title: id,
                    previewAsset: '',
                    pageBuilder: (_) => _Marker(entryId: id),
                  );
                },
                child: Text('open-$id'),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Marker extends StatefulWidget {
  const _Marker({required this.entryId});

  final String entryId;

  @override
  State<_Marker> createState() => _MarkerState();
}

class _MarkerState extends State<_Marker> {
  static bool forfeited = false;

  int value = 1;

  @override
  Widget build(BuildContext context) {
    return GameSuspendForfeitBinding(
      onForfeit: () async {
        forfeited = true;
      },
      child: ColoredBox(
        color: const Color(0xFF336699),
        child: Column(
          children: [
            const GameSuspendButton(),
            Text('round-$value-${widget.entryId}'),
            TextButton(
              onPressed: () => setState(() => value += 1),
              child: const Text('score'),
            ),
          ],
        ),
      ),
    );
  }
}
