import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The contact sheet is the one place in 遗言 that puts a keyboard over a form,
/// so what is pinned here is how the panel and the keyboard move together —
/// the same contract the check-in editor holds.
const _session = AuthSession(
  token: 'test-token',
  userId: 'user-1',
  username: 'tester',
  role: UserRole.user,
  hasAgent: true,
  agentId: 'agent-1',
  agentName: '小芜',
  workspaceId: 'ws-1',
  conversationId: 'conv-1',
);

const double _safeBottom = 34;
const double _canvasWidth = 390;
const double _canvasHeight = 844;

/// No will yet, which is the state the contact card is reachable from.
class _FakeWillApi extends CompanionApi {
  _FakeWillApi() : super(baseUrl: 'https://example.test') {
    authToken = 'test-token';
  }

  @override
  Future<List<LastWill>> listLastWills({
    String? agentId,
    String? workspaceId,
  }) async => const [];
}

void _useDesignCanvas(WidgetTester tester, {double keyboard = 0}) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(_canvasWidth, _canvasHeight);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  // The platform folds the keyboard into the bottom padding as it rises, so
  // the home indicator inset is only reported while it is actually visible.
  tester.view.padding = FakeViewPadding(
    top: 47,
    bottom: keyboard > 0 ? 0 : _safeBottom,
  );
  addTearDown(tester.view.reset);
}

/// The page runs a 12s glow loop, so nothing here ever settles — advance a
/// fixed span instead, long enough for the route and sheet transitions.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// Home card → 管理联系人 → first empty slot → the add sheet.
Future<void> _openContactSheet(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LastWillPage(api: _FakeWillApi(), session: _session),
    ),
  );
  await _settle(tester);

  await tester.tap(find.text('管理'));
  await _settle(tester);
  await tester.tap(find.byKey(const Key('legacy-contact-slot-0')));
  await _settle(tester);
  expect(find.byKey(const Key('legacy-contact-sheet')), findsOneWidget);
}

void main() {
  group('emergency contact sheet', () {
    testWidgets('sits on the screen edge with the keyboard down', (
      tester,
    ) async {
      _useDesignCanvas(tester);
      await _openContactSheet(tester);

      final sheet = tester.getRect(
        find.byKey(const Key('legacy-contact-sheet')),
      );
      final save = tester.getRect(find.byKey(const Key('legacy-contact-save')));
      expect(sheet.bottom, _canvasHeight);
      // 34 design gap, widened to clear the home indicator when there is one.
      expect(sheet.bottom - save.bottom, _safeBottom + 20);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the panel tracks the keyboard frame by frame', (tester) async {
      _useDesignCanvas(tester);
      await _openContactSheet(tester);
      await tester.tap(find.text('名字'));
      await _settle(tester);

      // Walk the inset the way the platform reports it mid-animation. The
      // panel has to be a continuous function of it: the AnimatedPadding this
      // replaced ran a second 200ms curve on top of the system one, which is
      // what made the sheet trail the keyboard on the way down.
      double? gap;
      var previousTop = double.infinity;
      for (final inset in [80.0, 160.0, 240.0, 336.0]) {
        _useDesignCanvas(tester, keyboard: inset);
        await tester.pump();

        final sheet = tester.getRect(
          find.byKey(const Key('legacy-contact-sheet')),
        );
        final save = tester.getRect(
          find.byKey(const Key('legacy-contact-save')),
        );

        // Reaching the screen edge is the point: the gradient carries on
        // behind the keyboard instead of leaving a dark band between them.
        expect(sheet.bottom, _canvasHeight);
        expect(sheet.top, lessThan(previousTop));
        previousTop = sheet.top;

        final toKeyboard = (_canvasHeight - inset) - save.bottom;
        gap ??= toKeyboard;
        expect(toKeyboard, closeTo(gap, 0.5));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('the form scrolls under a tall keyboard', (tester) async {
      _useDesignCanvas(tester, keyboard: 336);
      await _openContactSheet(tester);

      // The fields have to stay reachable once the keyboard has taken half the
      // screen, and the button must not be the thing that gets pushed off.
      final save = tester.getRect(find.byKey(const Key('legacy-contact-save')));
      expect(save.bottom, lessThanOrEqualTo(_canvasHeight - 336));

      await tester.drag(find.text('紧急联系人'), const Offset(0, -120));
      await tester.pump();
      expect(find.text('电话'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
