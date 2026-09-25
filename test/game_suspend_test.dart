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
    expect(docked.flushOuterEdge, isTrue);

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
    final visual = computeDockClusterVisual(
      entryIds: ['a', 'b'],
      edge: GameFloatEdge.right,
      centerY: 200,
      progress: 0.45,
      screen: screen,
      padding: EdgeInsets.zero,
    );
    expect(visual.cards, isNotEmpty);
    expect(visual.cards.last.rect.right, closeTo(400, 1));
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

  testWidgets('swiping a revealed preview collapses back toward the bar', (
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

    final card = find.byKey(const ValueKey('game-float-dock-card-gomoku'));
    await tester.drag(card, const Offset(280, 0));
    await tester.pumpAndSettle();
    expect(controller.find('gomoku')!.phase, GameFloatPhase.bar);
    expect(controller.find('chess')!.phase, GameFloatPhase.bar);

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
