import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProfileApi extends CompanionApi {
  _FakeProfileApi() : super(baseUrl: 'http://localhost:8000');

  @override
  Future<ProfileStats> fetchProfileStats({String? workspaceId}) async {
    return const ProfileStats(
      workspaceId: 'workspace',
      intimacyStage: 'P4',
      intimacyStageLabel: '稳定陪伴',
      topicIntimacy: 72,
      companionDays: 126,
      chatHours: 48,
      messageCount: 3284,
      companionSummary: '唯一伴生对象 · 女 · ENFP',
    );
  }
}

Future<void> pumpLoginPage(WidgetTester tester) async {
  await tester.pumpWidget(const CompanionApp());
  for (var i = 0; i < 10; i += 1) {
    await tester.pump(const Duration(milliseconds: 50));
    if (find.text('从一句话开始').evaluate().isNotEmpty) return;
  }
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('renders prototype login entry and opens backend form', (
    tester,
  ) async {
    await pumpLoginPage(tester);

    expect(find.text('从一句话开始'), findsOneWidget);
    expect(find.text('Ban Sheng'), findsOneWidget);
    expect(find.text('手机号登录'), findsOneWidget);
    expect(find.text('or'), findsOneWidget);
    expect(find.text('后端地址'), findsNothing);

    await tester.tap(find.text('手机号登录'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('后端地址'), findsOneWidget);
    expect(find.text('登录'), findsWidgets);
    expect(find.text('注册'), findsOneWidget);
    expect(find.text('账号'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
  });

  testWidgets('renders wechat login button', (tester) async {
    await pumpLoginPage(tester);

    expect(find.bySemanticsLabel('微信'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.chat_bubble_2_fill), findsNothing);
  });

  testWidgets('profile logout asks for confirmation before logging out', (
    tester,
  ) async {
    var logoutCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.materialTheme(Brightness.light),
        home: Scaffold(
          body: ProfilePage(
            api: _FakeProfileApi(),
            session: const AuthSession(
              token: 'token',
              userId: 'user',
              username: 'shanmu',
              userDisplayName: '山木',
              role: UserRole.user,
              hasAgent: true,
              agentId: 'agent',
              agentName: '小芜',
              workspaceId: 'workspace',
              conversationId: 'conversation',
            ),
            onAgentDeleted: (_) {},
            onLogout: () => logoutCount += 1,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('3,284'), findsOneWidget);

    Finder logoutEntry() => find.byIcon(CupertinoIcons.square_arrow_right).last;

    await tester.ensureVisible(logoutEntry());
    await tester.tap(logoutEntry());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('确定要退出当前账号吗？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(logoutCount, 0);

    await tester.ensureVisible(logoutEntry());
    await tester.tap(logoutEntry());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('退出'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(logoutCount, 1);
  });
}
