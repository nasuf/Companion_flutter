import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// 后台「语音通话」全局开关：服务端返回什么，加号面板就显示什么。
class _ChatApi extends CompanionApi {
  _ChatApi() : super(baseUrl: 'http://127.0.0.1:1');
  bool voiceCallEnabled = false;
  int flagReads = 0;

  @override
  Future<bool> getVoiceCallEnabled() async {
    flagReads++;
    return voiceCallEnabled;
  }

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

const _session = AuthSession(
  token: 'synthetic',
  userId: 'user',
  username: 'user',
  role: UserRole.user,
  hasAgent: true,
  agentId: 'agent',
  agentName: '小伴',
  conversationId: 'conversation',
);

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Finder _composerButton(String tooltip) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == '_Composer',
  ),
  matching: find.byTooltip(tooltip),
);

Future<void> _open(WidgetTester tester, _ChatApi api) async {
  FlutterSecureStorage.setMockInitialValues({});
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.runAsync(() async {
    MusicPlaybackController.instance.configureQuota(api);
  });
  await tester.pumpWidget(
    MaterialApp(
      navigatorObservers: [appRouteObserver],
      theme: AppTheme.materialTheme(Brightness.light),
      home: Scaffold(
        body: ChatPage(
          api: api,
          session: _session,
          isActive: true,
          onOpenSidebar: () {},
        ),
      ),
    ),
  );
  await _frames(tester);
}

Future<void> _toggleMore(WidgetTester tester) async {
  await tester.tap(_composerButton('更多'));
  await _frames(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
      'com.llfbandit.record/messages',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => null,
      );
    }
  });
  tearDownAll(() => MusicPlaybackController.instance.dispose());

  test('an unreachable server reads the voice switch as off', () async {
    final api = CompanionApi(baseUrl: 'http://127.0.0.1:1');
    expect(await api.getVoiceCallEnabled(), isFalse);
  });

  testWidgets('switch off hides the icon and the rest reflow to 4 + 2', (
    tester,
  ) async {
    final api = _ChatApi();
    await _open(tester, api);
    await _toggleMore(tester);
    expect(find.text('语音通话'), findsNothing);
    for (final label in ['图片', '拍摄', '红包', '位置', '查找', '礼物']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    // 第一行 4 个（同一高度），位置顺延到第一行末尾，查找和礼物落到第二行最左。
    final rowOne = tester.getCenter(find.text('图片')).dy;
    expect(tester.getCenter(find.text('位置')).dy, rowOne);
    expect(tester.getCenter(find.text('查找')).dy, greaterThan(rowOne));
    expect(
      tester.getCenter(find.text('查找')).dx,
      moreOrLessEquals(tester.getCenter(find.text('图片')).dx),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester);
  });

  testWidgets('admin toggles take effect the next time the panel opens', (
    tester,
  ) async {
    final api = _ChatApi();
    await _open(tester, api);
    await _toggleMore(tester);
    expect(find.text('语音通话'), findsNothing);
    await _toggleMore(tester);

    api.voiceCallEnabled = true;
    await _toggleMore(tester);
    expect(find.text('语音通话'), findsOneWidget);
    await _toggleMore(tester);

    api.voiceCallEnabled = false;
    await _toggleMore(tester);
    expect(find.text('语音通话'), findsNothing);
    expect(api.flagReads, greaterThanOrEqualTo(4));
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester);
  });
}
