import 'package:companion_flutter/src/utils/chat_scroll_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('newest message is builder index 0 in a reversed list', () {
    expect(
      ChatScrollPolicy.childIndexForKey(
        const ValueKey('${ChatScrollPolicy.messageKeyPrefix}b'),
        ['a', 'b'],
      ),
      0,
    );
    expect(
      ChatScrollPolicy.childIndexForKey(
        const ValueKey('${ChatScrollPolicy.messageKeyPrefix}a'),
        ['a', 'b'],
      ),
      1,
    );
  });

  test(
    'appending a newest message keeps older builder indices shifted by one',
    () {
      const older = ValueKey('${ChatScrollPolicy.messageKeyPrefix}a');
      expect(ChatScrollPolicy.childIndexForKey(older, ['a']), 0);
      expect(ChatScrollPolicy.childIndexForKey(older, ['a', 'b']), 1);
    },
  );

  test(
    'ime slide is only the extra lift above the rest composer occupancy',
    () {
      expect(ChatScrollPolicy.imeSlide(composerBottom: 80, restLift: 80), 0);
      expect(ChatScrollPolicy.imeSlide(composerBottom: 380, restLift: 80), 300);
    },
  );

  test('rest lift stays on the panel while a panel is docked', () {
    expect(ChatScrollPolicy.restLift(tabBarLift: 98, panelLift: 270), 270);
    expect(ChatScrollPolicy.restLift(tabBarLift: 98, panelLift: 0), 98);
  });

  test('floating tab bar hides for both panel and cold keyboard', () {
    expect(
      ChatScrollPolicy.hideFloatingTabBar(panelDocked: true, imeDocked: false),
      isTrue,
    );
    expect(
      ChatScrollPolicy.hideFloatingTabBar(panelDocked: false, imeDocked: true),
      isTrue,
    );
    expect(
      ChatScrollPolicy.hideFloatingTabBar(panelDocked: false, imeDocked: false),
      isFalse,
    );
  });

  test(
    'dropping restLift under a covering IME would jump transcript slide',
    () {
      const inset = 336.0;
      const panelLift = 270.0;
      const tabBarLift = 98.0;
      final heldSlide = ChatScrollPolicy.imeSlide(
        composerBottom: inset,
        restLift: panelLift,
      );
      final droppedSlide = ChatScrollPolicy.imeSlide(
        composerBottom: inset,
        restLift: tabBarLift,
      );
      expect(droppedSlide - heldSlide, closeTo(panelLift - tabBarLift, 0.001));
    },
  );

  test('rest composer gap does not include keyboard height', () {
    expect(
      ChatScrollPolicy.restComposerGap(composerHeight: 56, restLift: 80),
      56 + 80 + ChatScrollPolicy.composerListGap,
    );
  });

  test('near newest is the min edge (composer) on a reversed list', () {
    final metrics = FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: 2000,
      pixels: 10,
      viewportDimension: 700,
      axisDirection: AxisDirection.up,
      devicePixelRatio: 3,
    );
    expect(ChatScrollPolicy.isNearNewest(metrics), isTrue);
    expect(ChatScrollPolicy.isNearOldest(metrics), isFalse);
  });

  test('near oldest is the max edge (load older) on a reversed list', () {
    final metrics = FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: 2000,
      pixels: 1990,
      viewportDimension: 700,
      axisDirection: AxisDirection.up,
      devicePixelRatio: 3,
    );
    expect(ChatScrollPolicy.isNearNewest(metrics), isFalse);
    expect(ChatScrollPolicy.isNearOldest(metrics), isTrue);
  });

  testWidgets('reading newest-edge during the first build does not throw', (
    tester,
  ) async {
    final controller = ScrollController();
    Object? error;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            CustomScrollView(
              reverse: true,
              controller: controller,
              slivers: const [
                SliverToBoxAdapter(child: SizedBox(height: 2400)),
              ],
            ),
            Builder(
              builder: (context) {
                try {
                  if (controller.hasClients) {
                    final position = controller.position;
                    if (ChatScrollPolicy.hasLaidOut(position)) {
                      ChatScrollPolicy.isNearNewest(position);
                    } else {
                      expect(ChatScrollPolicy.isNearNewest(position), isTrue);
                    }
                  }
                } catch (e) {
                  error = e;
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
    expect(error, isNull);
    expect(ChatScrollPolicy.hasLaidOut(controller.position), isTrue);
  });

  testWidgets('reversed leading spacer sits below the newest row', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          height: 600,
          child: CustomScrollView(
            reverse: true,
            slivers: [
              SliverToBoxAdapter(child: SizedBox(key: Key('gap'), height: 200)),
              SliverToBoxAdapter(child: SizedBox(key: Key('msg'), height: 80)),
            ],
          ),
        ),
      ),
    );
    final gap = tester.getRect(find.byKey(const Key('gap')));
    final msg = tester.getRect(find.byKey(const Key('msg')));
    expect(gap.bottom, greaterThan(msg.bottom));
    expect(msg.bottom, closeTo(gap.top, 1));
  });

  testWidgets('prepending older rows preserves a reversed-list anchor', (
    tester,
  ) async {
    final controller = ScrollController();
    final messages = ValueNotifier<List<String>>(
      List.generate(40, (index) => 'm$index'),
    );
    addTearDown(controller.dispose);
    addTearDown(messages.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 320,
          child: ValueListenableBuilder<List<String>>(
            valueListenable: messages,
            builder: (context, chronologicalIds, _) {
              return CustomScrollView(
                reverse: true,
                controller: controller,
                slivers: [
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final id =
                            chronologicalIds[chronologicalIds.length -
                                1 -
                                index];
                        return SizedBox(
                          key: ValueKey(ChatScrollPolicy.messageKey(id)),
                          height: 48,
                          child: Text(id),
                        );
                      },
                      childCount: chronologicalIds.length,
                      findChildIndexCallback: (key) =>
                          ChatScrollPolicy.childIndexForKey(
                            key,
                            chronologicalIds,
                          ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    controller.jumpTo(384);
    await tester.pump();
    final anchor = find.byKey(ValueKey(ChatScrollPolicy.messageKey('m31')));
    final before = tester.getTopLeft(anchor).dy;

    messages.value = [
      for (var index = 0; index < 8; index += 1) 'older-$index',
      ...messages.value,
    ];
    await tester.pump();

    expect(controller.offset, closeTo(384, 0.001));
    expect(tester.getTopLeft(anchor).dy, closeTo(before, 0.001));
  });

  testWidgets('MediaQuery IME ticks only rebuild the transform follower', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var shellBuilds = 0;
    var followerBuilds = 0;
    var rowBuilds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: _StableMediaShell(
          onBuild: () => shellBuilds += 1,
          child: _DirectImeSlideHarness(
            onBuild: () => followerBuilds += 1,
            child: CustomScrollView(
              reverse: true,
              slivers: [
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    rowBuilds += 1;
                    return const SizedBox(height: 48, child: Text('row'));
                  }, childCount: 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(shellBuilds, 1);
    expect(followerBuilds, 1);
    expect(rowBuilds, 1);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pump();
    expect(shellBuilds, 1);
    expect(followerBuilds, 2);
    expect(rowBuilds, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('IME follower retains the composer child across inset ticks', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var shellBuilds = 0;
    var followerBuilds = 0;
    var composerBuilds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: _StableMediaShell(
          onBuild: () => shellBuilds += 1,
          child: _RetainedImeFollowerHarness(
            onBuild: () => followerBuilds += 1,
            child: _BuildCounter(onBuild: () => composerBuilds += 1),
          ),
        ),
      ),
    );
    expect(shellBuilds, 1);
    expect(followerBuilds, 1);
    expect(composerBuilds, 1);

    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pump();
    expect(shellBuilds, 1);
    expect(followerBuilds, 2);
    expect(composerBuilds, 1);
    expect(tester.takeException(), isNull);
  });
}

class _StableMediaShell extends StatelessWidget {
  const _StableMediaShell({required this.onBuild, required this.child});

  final VoidCallback onBuild;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    onBuild();
    MediaQuery.sizeOf(context);
    MediaQuery.viewPaddingOf(context);
    return child;
  }
}

class _DirectImeSlideHarness extends StatelessWidget {
  const _DirectImeSlideHarness({required this.onBuild, required this.child});

  final VoidCallback onBuild;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    onBuild();
    final slide = MediaQuery.viewInsetsOf(context).bottom;
    return ClipRect(
      child: Transform.translate(offset: Offset(0, -slide), child: child),
    );
  }
}

class _RetainedImeFollowerHarness extends StatelessWidget {
  const _RetainedImeFollowerHarness({
    required this.onBuild,
    required this.child,
  });

  final VoidCallback onBuild;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: const AlwaysStoppedAnimation<double>(1),
      child: RepaintBoundary(child: child),
      builder: (context, child) {
        onBuild();
        final slide = MediaQuery.viewInsetsOf(context).bottom;
        return Transform.translate(offset: Offset(0, -slide), child: child);
      },
    );
  }
}

class _BuildCounter extends StatelessWidget {
  const _BuildCounter({required this.onBuild});

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return const SizedBox(width: 40, height: 40);
  }
}
