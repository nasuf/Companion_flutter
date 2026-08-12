import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 「我的」页顶部关系头图 + 个人资料卡。
///
/// 头图是**固定高度** Container 里放 Column + Spacer：内容一旦超过可用高度，Spacer
/// 归零然后溢出。放大头像时那点高度算术只能靠真机尺寸验，肉眼在一种屏上看不出别的
/// 屏会不会挤爆 —— widget test 里溢出会直接变成失败。
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

Future<void> _pumpProfile(WidgetTester tester, {AuthSession? session}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.materialTheme(Brightness.light),
      home: Scaffold(
        body: ProfilePage(
          api: _FakeProfileApi(),
          session: session ?? _session(wechatBound: true),
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
  // 常见在售宽度 + 一个刻意偏矮的用来逼出纵向溢出。
  //
  // 刻意**不含** 320x568（iPhone SE 一代）：那个尺寸上数据卡片有一处**预存的**
  // 纵向溢出（卡片高度按 childAspectRatio 随宽度缩放，卡内文字却是固定字号），
  // 跟本次头像放大无关 —— 我把头像改回 64 那处依然溢出。修它要在「固定卡片高度」
  // 和「字号自适应」之间做设计取舍，已单独立项；修完把 320 加回这里即可拿到回归覆盖。
  const sizes = <String, Size>{
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
      tester.view.physicalSize = const Size(320, 568) * tester.view.devicePixelRatio;
      addTearDown(tester.view.resetPhysicalSize);

      await _pumpProfile(
        tester,
        session: _session(wechatBound: true, phone: '138****5678'),
      );
      // 头图那处 320 上有预存的卡片溢出（见上面的说明），先清掉再看资料页自己的。
      tester.takeException();
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
