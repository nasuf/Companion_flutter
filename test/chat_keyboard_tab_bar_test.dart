import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _ChatApi extends CompanionApi {
  _ChatApi() : super(baseUrl: 'http://127.0.0.1:1');

  @override
  Future<Conversation> getConversation(String id) async => Conversation(
    id: id,
    userId: 'user',
    agentId: 'agent',
    aiStatus: 'idle',
    aiStatusLabel: '空闲',
    interactionDays: 12,
  );

  @override
  Future<List<ChatMessage>> loadMessages(
    String id, {
    int limit = 100,
    int offset = 0,
  }) async => [];
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
      'com.llfbandit.record/messages',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => null,
      );
    }
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async {
        final id = (call.arguments as Map?)?['playerId'];
        if (id != null) {
          messenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/$id'),
            (_) async => null,
          );
        }
        return null;
      },
    );
  });
  tearDownAll(() => MusicPlaybackController.instance.dispose());
  for (final brightness in Brightness.values) {
    testWidgets('tab bar stays fixed through IME frames in $brightness', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
      tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
      addTearDown(tester.view.reset);
      AppColors.use(brightness);
      addTearDown(() => AppColors.use(Brightness.light));
      final api = _ChatApi();
      // The playback controller outlives individual chat pages. Its service
      // timer must run outside the widget test's fake animation clock.
      await tester.runAsync(() async {
        MusicPlaybackController.instance.configureQuota(api);
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.materialTheme(brightness),
          home: MainShell(
            api: api,
            session: const AuthSession(
              token: 'synthetic',
              userId: 'user',
              username: 'user',
              role: UserRole.user,
              hasAgent: true,
              agentId: 'agent',
              agentName: '小伴',
              conversationId: 'conversation',
            ),
            onSessionChanged: (_) {},
            onLogout: () {},
          ),
        ),
      );
      await _frames(tester);
      final bar = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_FloatingTabBar',
      );
      final originalRect = tester.getRect(bar);
      final opacity = find.ancestor(
        of: bar,
        matching: find.byType(FadeTransition),
      );
      void expectFixed() {
        expect(tester.getRect(bar), originalRect);
        expect(tester.widget<FadeTransition>(opacity.first).opacity.value, 1);
      }

      final field = find.byType(ExtendedTextField);
      final focus = tester.widget<ExtendedTextField>(field).focusNode!;
      Future<void> inset(double height) async {
        tester.view.viewInsets = FakeViewPadding(bottom: height);
        tester.view.padding = FakeViewPadding(
          top: 47,
          bottom: height > 0 ? 0 : 34,
        );
        await tester.pump(const Duration(milliseconds: 16));
        expectFixed();
      }

      // Cold keyboard: focus itself must not start hiding the bar.
      await tester.tap(field);
      await _frames(tester);
      expect(focus.hasFocus, isTrue);
      expectFixed();
      for (final height in [80.0, 180.0, 336.0, 220.0, 120.0]) {
        await inset(height);
      }
      // The keyboard's own dismiss action can leave the field focused.
      await inset(0);
      await _frames(tester);
      expectFixed();
      focus.unfocus();
      await _frames(tester);
      expectFixed();

      // A real custom panel still hides the bar. Switching from that panel
      // to the keyboard must not keep the bar hidden by held occupancy.
      for (final tooltip in ['表情', '更多']) {
        final panelButton = find.descendant(
          of: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_Composer',
          ),
          matching: find.byTooltip(tooltip),
        );
        await tester.tap(panelButton);
        await _frames(tester);
        expect(tester.getRect(bar).top, greaterThan(844));
        expect(tester.widget<FadeTransition>(opacity.first).opacity.value, 0);
        await tester.tap(field);
        tester.view.viewInsets = const FakeViewPadding(bottom: 336);
        tester.view.padding = const FakeViewPadding(top: 47);
        await _frames(tester);
        expectFixed();
        focus.unfocus();
        for (final height in [240.0, 100.0, 0.0]) {
          await inset(height);
        }
        await _frames(tester);
        expectFixed();
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
    });
  }
}
