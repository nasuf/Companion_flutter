import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  for (var i = 0; i < 70; i += 1) {
    await tester.pump(const Duration(milliseconds: 50));
    if (find.text('微信登录').evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 700));
      return;
    }
  }
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('removes inherited text decorations from login copy', (
    tester,
  ) async {
    await pumpLoginPage(tester);

    final paragraph = tester.renderObject<RenderParagraph>(find.text('Hello'));
    expect(paragraph.text.style?.decoration, TextDecoration.none);
  });

  testWidgets('raster-filters the animated Hello bubble', (tester) async {
    await pumpLoginPage(tester);

    final transforms = tester.widgetList<Transform>(
      find.ancestor(of: find.text('Hello'), matching: find.byType(Transform)),
    );
    expect(
      transforms.any(
        (transform) => transform.filterQuality == FilterQuality.high,
      ),
      isTrue,
    );
  });

  testWidgets('holds the splash for two seconds and crossfades to login', (
    tester,
  ) async {
    await tester.pumpWidget(const CompanionApp());
    await tester.pump();

    expect(find.text('独处时刻，皆有伴生相守'), findsOneWidget);
    expect(find.text('微信登录'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1900));
    expect(find.text('独处时刻，皆有伴生相守'), findsOneWidget);
    expect(find.text('微信登录'), findsNothing);

    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('独处时刻，皆有伴生相守'), findsOneWidget);
    expect(find.text('微信登录'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    final transitionOpacities = tester
        .widgetList<FadeTransition>(find.byType(FadeTransition))
        .map((transition) => transition.opacity.value);
    expect(
      transitionOpacities.any((opacity) => opacity > 0 && opacity < 1),
      isTrue,
    );

    for (var i = 0; i < 15; i += 1) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('独处时刻，皆有伴生相守').evaluate().isEmpty) break;
    }
    expect(find.text('独处时刻，皆有伴生相守'), findsNothing);
    expect(find.text('微信登录'), findsOneWidget);
  });

  testWidgets('renders secondary login methods as unavailable', (tester) async {
    await pumpLoginPage(tester);

    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('微信登录'), findsOneWidget);
    expect(find.text('其他登录方式'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('同意用户协议和隐私协议'));
    await tester.pump();

    for (final method in ['苹果登录', '手机号登录']) {
      await tester.tap(find.bySemanticsLabel(method));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('暂未开放'), findsOneWidget);
      expect(find.text('$method功能正在准备中，敬请期待。'), findsOneWidget);

      await tester.tap(find.widgetWithText(CupertinoDialogAction, '知道了'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
  });

  for (final method in ['微信登录', '苹果登录', 'QQ登录', '手机号登录']) {
    testWidgets('requires consent before $method', (tester) async {
      await pumpLoginPage(tester);

      final entry = method == '微信登录'
          ? find.text(method)
          : find.bySemanticsLabel(method);
      await tester.tap(entry);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('同意用户协议与隐私政策'), findsOneWidget);
      expect(find.text('同意并继续'), findsOneWidget);

      await tester.tap(find.text('暂不同意'));
      await tester.pump();
    });
  }

  testWidgets('opens username and password login from QQ entry', (
    tester,
  ) async {
    await pumpLoginPage(tester);

    await tester.tap(find.bySemanticsLabel('QQ登录'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('同意用户协议与隐私政策'), findsOneWidget);
    expect(find.text('用户名密码登录'), findsNothing);

    await tester.tap(find.text('同意并继续'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('用户名密码登录'), findsOneWidget);
    expect(find.text('用户名'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
    expect(find.text('暂未开放'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pump();
    expect(find.text('请输入用户名和密码'), findsOneWidget);
  });

  testWidgets('renders wechat login button', (tester) async {
    await pumpLoginPage(tester);

    expect(find.text('微信登录'), findsOneWidget);
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
