import 'dart:ui' as ui;

import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Header geometry, scroll reversibility and profile actions use the real page.
class _FakeProfileApi extends CompanionApi {
  _FakeProfileApi({this.vip = false}) : super(baseUrl: 'http://localhost:8000');
  final bool vip;

  @override
  Future<StoreInventoryResponse> listStoreInventory() async {
    return const StoreInventoryResponse(items: []);
  }

  @override
  Future<IapMembership> getIapMembership({int historyLimit = 50}) async {
    return IapMembership(
      vip: VipStatus(
        isVip: vip,
        vipUntil: null,
        vipTrialAvailable: false,
        giftTicketBalance: 0,
        ticketBalance: 0,
        pointBalance: 0,
        spendableTickets: 0,
      ),
      autoRenewActive: false,
      history: [],
    );
  }

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

AuthSession _session({String? phone, bool wechatBound = false}) {
  return AuthSession(
    token: 'token',
    userId: 'e7a1c3d4-1111-2222-3333-444455556666',
    username: 'wx_ed8b9ba77f12f5c8',
    userDisplayName: '山木',
    role: UserRole.user,
    hasAgent: true,
    agentId: 'agent',
    agentName: '小芜',
    workspaceId: 'workspace',
    conversationId: 'conversation',
    phone: phone,
    wechatBound: wechatBound,
  );
}

Future<void> _pumpProfile(
  WidgetTester tester, {
  AuthSession? session,
  double scale = 1,
  Brightness brightness = Brightness.light,
  bool active = false,
  bool reduceMotion = false,
  bool vip = false,
}) async {
  AppColors.use(brightness);
  addTearDown(() => AppColors.use(Brightness.light));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.materialTheme(brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduceMotion,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: ProfilePage(
          api: _FakeProfileApi(vip: vip),
          session: session ?? _session(wechatBound: true),
          active: active,
          onAgentDeleted: (_) {},
          onSessionChanged: (_) {},
          onLogout: () {},
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  for (final width in [390.0, 320.0]) {
    testWidgets(
      'appearance subpage preserves system and manual choices at width $width',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({});
        final systemBrightness = width == 320
            ? Brightness.dark
            : Brightness.light;
        tester.binding.platformDispatcher.platformBrightnessTestValue =
            systemBrightness;
        addTearDown(
          tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
        );
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await _pumpProfile(tester);
        final page = tester.widget<ProfilePage>(find.byType(ProfilePage));
        final controller = AppThemeController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              AppColors.use(controller.resolveBrightness(systemBrightness));
              return AppThemeScope(
                controller: controller,
                child: MaterialApp(
                  theme: AppTheme.materialTheme(Brightness.light),
                  darkTheme: AppTheme.materialTheme(Brightness.dark),
                  themeMode: controller.mode,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(width == 320 ? 1.8 : 1),
                    ),
                    child: child!,
                  ),
                  home: Scaffold(body: page),
                ),
              );
            },
          ),
        );
        await tester.pump();
        expect(find.byKey(const ValueKey('profile-theme-mode')), findsNothing);
        await tester.ensureVisible(find.text('显示模式'));
        await tester.pump();
        await tester.tap(find.text('显示模式'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final follow = find.byKey(
          const ValueKey('profile-theme-follow-system'),
        );
        expect(tester.widget<CupertinoSwitch>(follow).value, isTrue);
        expect(find.text('手动选择'), findsNothing);
        expect(find.text('普通模式'), findsNothing);
        expect(find.text('深色模式'), findsNothing);
        await tester.tap(follow);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          controller.mode,
          systemBrightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
        );
        for (final entry in {
          '深色模式': ThemeMode.dark,
          '普通模式': ThemeMode.light,
        }.entries) {
          await tester.ensureVisible(find.text(entry.key));
          await tester.pump();
          await tester.tap(find.text(entry.key));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(controller.mode, entry.value);
          final restored = AppThemeController();
          await restored.restore();
          expect(restored.mode, entry.value);
          restored.dispose();
          expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        Navigator.of(tester.element(follow)).pop();
        await tester.pumpAndSettle();
        expect(find.text('浅色'), findsOneWidget);
        await tester.tap(find.text('显示模式'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.widget<CupertinoSwitch>(follow).value, isFalse);
        await tester.ensureVisible(follow);
        await tester.pump();
        await tester.tap(follow);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(controller.mode, ThemeMode.system);
        expect(find.text('手动选择'), findsNothing);
        expect(find.text('普通模式'), findsNothing);
        expect(find.text('深色模式'), findsNothing);
        final restored = AppThemeController();
        await restored.restore();
        expect(restored.mode, ThemeMode.system);
        restored.dispose();
        Navigator.of(tester.element(follow)).pop();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('profile-theme-follow-system')),
          findsNothing,
        );
        expect(find.text('跟随系统'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets('tile edge narrows geometrically to both tips ($brightness)', (
      tester,
    ) async {
      await _pumpProfile(tester, brightness: brightness);
      final tile = tester.widget<CustomPaint>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('profile-stat-亲密度')),
              matching: find.byType(CustomPaint),
            )
            .first,
      );
      const size = Size(172, 118);
      const scale = 8;
      final pixelWidth = (size.width * scale).round();
      final pixelHeight = (size.height * scale).round();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..scale(scale.toDouble());
      tile.foregroundPainter!.paint(canvas, size);
      final picture = recorder.endRecording();
      final bytes = await tester.runAsync(() async {
        final image = await picture.toImage(pixelWidth, pixelHeight);
        final result = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        image.dispose();
        picture.dispose();
        return result;
      });
      int alpha(double x, double y) => bytes!.getUint8(
        ((y * scale).floor() * pixelWidth + (x * scale).floor()) * 4 + 3,
      );

      // The middle remains 3px, while the corner's inner portion is transparent.
      // A constant-width stroke with faded opacity still paints these pixels.
      expect(alpha(1.5, 59), greaterThan(180));
      expect(alpha(3.6, 59), 0);
      for (final bottom in [false, true]) {
        double y(double top) => bottom ? size.height - top : top;
        expect(alpha(15.665, y(2.503)), 0); // Near the tip: less than 1.5px.
        expect(alpha(8.211, y(8.211)), 0); // Mid-corner: less than 2.5px.
        expect(alpha(6.974, y(6.974)), greaterThan(20));
        expect(alpha(3.17, y(15.88)), greaterThan(20));
      }
    });
  }

  const sizes = <String, Size>{
    'iPhone SE (320x568)': Size(320, 568),
    'iPhone 8 (375x667)': Size(375, 667),
    'iPhone 15 Pro Max (430x932)': Size(430, 932),
    '偏矮 (360x480)': Size(360, 480),
  };

  group('关系头图', () {
    for (final entry in sizes.entries) {
      testWidgets('${entry.key} 不溢出', (tester) async {
        tester.view.physicalSize = entry.value * tester.view.devicePixelRatio;
        addTearDown(tester.view.resetPhysicalSize);

        await _pumpProfile(tester);

        // 溢出会以 FlutterError 形式被测试框架捕获，这里显式再确认一次。
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('头像放大到 88，两侧一致', (tester) async {
      await _pumpProfile(tester);

      // 两个头像（agent + 用户）都应该是 88；二级页的行内小头像仍是 64，不在本页。
      final circles = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.constraints?.maxWidth == 88)
          .length;
      expect(circles, greaterThanOrEqualTo(2));
    });
  });

  group('滚动收拢', () {
    for (final brightness in Brightness.values) {
      testWidgets(
        'avatars converge continuously, pin and restore ($brightness)',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
          addTearDown(tester.view.reset);
          await _pumpProfile(tester, brightness: brightness);
          final agent = find.byKey(const ValueKey('profile-agent-avatar'));
          final user = find.byKey(const ValueKey('profile-user-avatar'));
          final scrollable = tester.state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(const PageStorageKey('profile-scroll')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          final expandedAgent = tester.getRect(agent);
          final expandedUser = tester.getRect(user);
          expect(expandedAgent.width, 88);
          scrollable.position.jumpTo(95);
          await tester.pump();
          final middle = tester.getRect(agent);
          expect(middle.width, inExclusiveRange(36, 88));
          expect(middle.left, lessThan(expandedAgent.left));
          scrollable.position.jumpTo(220);
          await tester.pump();
          final compactAgent = tester.getRect(agent);
          final compactUser = tester.getRect(user);
          expect(compactAgent.width, 36);
          expect(compactAgent.top, greaterThanOrEqualTo(47));
          expect(compactUser.left, lessThan(compactAgent.right));
          expect(find.text('故事从这里开始').hitTestable(), findsNothing);
          scrollable.position.jumpTo(400);
          await tester.pump();
          expect(tester.getRect(agent), compactAgent);
          expect(tester.getRect(user), compactUser);
          scrollable.position.jumpTo(0);
          await tester.pump();
          expect(tester.getRect(agent), expandedAgent);
          expect(tester.getRect(user), expandedUser);
          expect(find.text('故事从这里开始').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets('compact avatars still open their own pages', (tester) async {
      await _pumpProfile(tester);
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      position.jumpTo(300);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('profile-user-avatar')));
      await tester.pumpAndSettle();
      expect(find.text('个人资料'), findsOneWidget);
      final context = tester.element(find.text('个人资料'));
      Navigator.of(context).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-agent-avatar')));
      await tester.pumpAndSettle();
      expect(find.text('小芜形象'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('large text on narrow display keeps stat text readable', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pumpProfile(tester, scale: 1.8, reduceMotion: true, active: true);
      for (final label in ['亲密度', '相识时间', '相处时光', '讯息总数']) {
        await tester.ensureVisible(find.byKey(ValueKey('profile-stat-$label')));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });
  });

  testWidgets('VIP crown remains visible and attached throughout collapse', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(top: 47);
    addTearDown(tester.view.reset);
    await _pumpProfile(tester, vip: true);
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    final badge = find.byKey(const ValueKey('profile-vip-badge'));
    for (final offset in [0.0, 95.0, 220.0, 400.0, 0.0]) {
      position.jumpTo(offset);
      await tester.pump();
      expect(badge, findsOneWidget);
      expect(tester.widget<Text>(badge).data, '👑');
      final opacity = tester.widgetList<Opacity>(
        find.ancestor(of: badge, matching: find.byType(Opacity)),
      );
      expect(opacity.every((widget) => widget.opacity > 0), isTrue);
      final crown = tester.getRect(badge);
      final avatar = tester.getRect(
        find.byKey(const ValueKey('profile-user-avatar')),
      );
      expect(crown.top, greaterThanOrEqualTo(47));
      expect(crown.center.dx, greaterThan(avatar.center.dx));
      expect(crown.top, lessThan(avatar.center.dy));
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('non-members have no VIP crown', (tester) async {
    await _pumpProfile(tester);
    expect(find.byKey(const ValueKey('profile-vip-badge')), findsNothing);
  });

  group('个人资料卡', () {
    testWidgets('不再显示登录账号那串内部 hash', (tester) async {
      await _pumpProfile(tester);
      await tester.tap(find.text('山木').first);
      await tester.pumpAndSettle();

      expect(find.text('个人资料'), findsOneWidget);
      expect(find.text('登录账号'), findsNothing);
      expect(find.text('wx_ed8b9ba77f12f5c8'), findsNothing);
    });

    testWidgets('微信账号显示「微信」徽标', (tester) async {
      await _pumpProfile(tester, session: _session(wechatBound: true));
      await tester.tap(find.text('山木').first);
      await tester.pumpAndSettle();

      expect(find.text('账号类型'), findsOneWidget);
      expect(find.text('微信'), findsOneWidget);
    });

    testWidgets('微信+手机号双绑时两个徽标都在', (tester) async {
      await _pumpProfile(
        tester,
        session: _session(wechatBound: true, phone: '138****5678'),
      );
      await tester.tap(find.text('山木').first);
      await tester.pumpAndSettle();

      expect(find.text('微信'), findsOneWidget);
      expect(find.text('138****5678'), findsOneWidget);
    });

    testWidgets('双绑徽标在最窄机型上不挤爆行', (tester) async {
      // 徽标是这一行里最宽的可能内容: 标签在 Expanded 里能被压到 0, 徽标却按自然
      // 宽度铺开。320pt 是 iOS 15 还支持的最窄宽度 (iPhone SE 一代)。
      tester.view.physicalSize =
          const Size(320, 568) * tester.view.devicePixelRatio;
      addTearDown(tester.view.resetPhysicalSize);

      await _pumpProfile(
        tester,
        session: _session(wechatBound: true, phone: '138****5678'),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('山木').first);
      await tester.pumpAndSettle();

      expect(find.text('账号类型'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('两者都没有则推断为账号密码', (tester) async {
      await _pumpProfile(tester, session: _session());
      await tester.tap(find.text('山木').first);
      await tester.pumpAndSettle();

      expect(find.text('账号密码'), findsOneWidget);
    });

    testWidgets('用户ID 只显示前 8 位', (tester) async {
      await _pumpProfile(tester);
      await tester.tap(find.text('山木').first);
      await tester.pumpAndSettle();

      expect(find.text('e7a1c3d4… 复制'), findsOneWidget);
      // 完整 uuid 36 字符会把标签挤掉，不该整串铺在行里。
      expect(find.text('e7a1c3d4-1111-2222-3333-444455556666'), findsNothing);
    });
  });
}
