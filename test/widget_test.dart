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
      intimacySubtitle: '稳定陪伴，越来越熟悉',
      companionDays: 126,
      companionStartedOn: '2026.02.11',
      chatHours: 48,
      chatMinutes: 2912,
      chatDurationLabel: '48h32m',
      chatDurationSubtitle: '≈ 一起看了26场电影',
      messageCount: 3284,
      recent7dMessageCount: 213,
      recent7dMessageLabel: '近7天 +213条',
      companionSummary: '唯一伴生对象 · 女 · ENFP',
      backpackCount: 5,
      memberIsActive: false,
      memberExpiresOn: null,
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
    expect(find.text('讯息总数'), findsOneWidget);
    expect(find.text('3284'), findsOneWidget);

    Finder logoutEntry() => find
        .ancestor(of: find.text('退出登录'), matching: find.byType(CupertinoButton))
        .last;

    await tester.ensureVisible(logoutEntry());
    await tester.tap(logoutEntry());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('退出后不会删除您的数据和AI伙伴，但需要重新登录。'), findsOneWidget);
    await tester.tap(find.text('再想想'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(logoutCount, 0);

    await tester.ensureVisible(logoutEntry());
    await tester.tap(logoutEntry());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '退出登录'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(logoutCount, 1);
  });

  testWidgets('profile settings surfaces follow dark palette', (tester) async {
    AppColors.use(Brightness.dark);
    addTearDown(() => AppColors.use(Brightness.light));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.materialTheme(Brightness.dark),
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
            onLogout: () {},
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox && widget.color == const Color(0xFF080D14),
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        return decoration is BoxDecoration &&
            decoration.color == const Color(0xFF101820);
      }),
      findsWidgets,
    );
  });
}
