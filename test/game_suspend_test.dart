import 'package:companion_flutter/src/games/game_suspend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bar pull progress grows as the float moves away from its edge', () {
    const width = 400.0;
    expect(
      barPullProgress(
        centerX: width - gameFloatBarWidth / 2,
        edge: GameFloatEdge.right,
        screenWidth: width,
      ),
      0,
    );
    expect(
      barPullProgress(
        centerX: width - 62,
        edge: GameFloatEdge.right,
        screenWidth: width,
      ),
      closeTo(1, 0.05),
    );
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

      await tester.tap(find.text('open'));
      await tester.pump();
      expect(find.text('round-1'), findsOneWidget);

      await tester.tap(find.text('score'));
      await tester.pump();
      expect(find.text('round-2'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('game-suspend-button-gomoku')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      expect(find.text('round-2'), findsNothing);
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
      final bar = find.byKey(const ValueKey('game-float-bar-gomoku'));
      expect(bar, findsOneWidget);
      final width = tester.getSize(find.byType(GameSuspendHost)).width;
      expect(tester.getTopLeft(bar).dx, width - gameFloatBarWidth);

      await tester.tap(bar);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('game-float-thumb-gomoku')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('game-float-thumb-gomoku')));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('round-2'), findsOneWidget);
      controller.closeAll();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('the first bar drag expands immediately without a widget swap', (
    tester,
  ) async {
    final controller = GameSuspendController();
    await _pumpHost(tester, controller);

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('game-suspend-button-gomoku')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    final bar = find.byKey(const ValueKey('game-float-bar-gomoku'));
    expect(bar, findsOneWidget);
    expect(
      find.byKey(const ValueKey('game-float-bar-pull-gomoku')),
      findsNothing,
    );
    final widthBefore = tester.getSize(bar).width;

    final topLeft = tester.getTopLeft(bar);
    final gesture = await tester.startGesture(
      topLeft + const Offset(10, gameFloatBarHeight / 2),
    );
    await tester.pump();
    await gesture.moveBy(const Offset(-56, 0));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('game-float-bar-pull-gomoku')),
      findsNothing,
    );
    expect(tester.getSize(bar).width, greaterThan(widthBefore));

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

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('game-suspend-button-gomoku')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    final bar = find.byKey(const ValueKey('game-float-bar-gomoku'));
    expect(bar, findsOneWidget);
    await tester.drag(bar, const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('game-float-thumb-gomoku')),
      findsOneWidget,
    );

    controller.closeAll();
    await tester.pumpAndSettle();
  });

  testWidgets('float close button dismisses the suspended game', (
    tester,
  ) async {
    _MarkerState.forfeited = false;
    final controller = GameSuspendController();
    await _pumpHost(tester, controller);

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('game-suspend-button-gomoku')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('game-float-bar-gomoku')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game-float-close')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('game-float-close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('game-float-thumb-gomoku')), findsNothing);
    expect(find.byKey(const ValueKey('game-float-bar-gomoku')), findsNothing);
    expect(_MarkerState.forfeited, isTrue);
    expect(controller.entries, isEmpty);
  });

  testWidgets(
    'a dragged thumbnail snaps, then folds back into a bar after 5s',
    (tester) async {
      final controller = GameSuspendController();
      await _pumpHost(tester, controller);

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('game-suspend-button-gomoku')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('game-float-bar-gomoku')));
      await tester.pumpAndSettle();
      final thumb = find.byKey(const ValueKey('game-float-thumb-gomoku'));
      expect(thumb, findsOneWidget);

      await tester.drag(thumb, const Offset(-500, 20));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(thumb).dx, gameFloatThumbGap);

      await tester.pump(const Duration(seconds: 4));
      expect(
        find.byKey(const ValueKey('game-float-thumb-gomoku')),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final bar = find.byKey(const ValueKey('game-float-bar-gomoku'));
      expect(bar, findsOneWidget);
      expect(
        find.byKey(const ValueKey('game-float-thumb-gomoku')),
        findsNothing,
      );
      expect(tester.getTopLeft(bar).dx, 0);
      controller.closeAll();
      await tester.pumpAndSettle();
    },
  );
}

Future<void> _pumpHost(WidgetTester tester, GameSuspendController controller) {
  return tester.pumpWidget(
    MaterialApp(
      builder: (context, child) {
        return GameSuspendHost(
          controller: controller,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: Scaffold(
        body: TextButton(
          onPressed: () {
            controller.open(
              id: 'gomoku',
              title: '五子棋',
              previewAsset: '',
              pageBuilder: (_) => const _Marker(),
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
}

class _Marker extends StatefulWidget {
  const _Marker();

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
            Text('round-$value'),
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
