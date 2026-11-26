import 'dart:async';
import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api extends CompanionApi {
  _Api() : super(baseUrl: 'https://synthetic.test');
  bool enabled = false, fails = false, autoRenew = false;
  bool trialAvailable = true;
  Completer<bool>? gate;
  int reads = 0;
  AndroidStoreSettings android = AndroidStoreSettings.closed;
  int androidReads = 0;
  int meReads = 0;
  @override
  Future<AuthSession> getMe(String token) async {
    // /auth/me 会撤销冷静期内的注销申请，商城不能调用它。
    meReads++;
    throw StateError('store must not call /auth/me');
  }

  @override
  Future<AndroidStoreSettings> getAndroidStoreSettings() async {
    androidReads++;
    return android;
  }

  @override
  Future<bool> getRealMoneyPaymentsEnabled() async {
    reads++;
    if (fails) throw const ApiException(503, 'unavailable');
    return gate?.future ?? enabled;
  }

  @override
  Future<WalletBalance> getWallet({String? agentId}) async =>
      const WalletBalance(
        ticketBalance: 1000,
        pointBalance: 1000,
        achievementPointsSynced: 0,
      );
  @override
  Future<IapMembership> getIapMembership({int historyLimit = 50}) async =>
      IapMembership(
        vip: VipStatus(
          isVip: autoRenew,
          vipUntil: null,
          vipTrialAvailable: trialAvailable,
          giftTicketBalance: 0,
          ticketBalance: 1000,
          pointBalance: 1000,
          spendableTickets: 1000,
        ),
        autoRenewActive: autoRenew,
        history: [],
      );
}

/// 绑定微信：不拉起真微信，直接返回服务端绑定后的会话。
class _Bind extends WeChatLoginService {
  int calls = 0;
  bool succeed = true;
  @override
  Future<AuthSession> bind({required CompanionApi api}) async {
    calls++;
    if (!succeed) throw const WeChatLoginException('已取消微信登录');
    return boundSession;
  }
}

const boundSession = AuthSession(
  token: 'synthetic',
  userId: 'test',
  username: 'test',
  role: UserRole.user,
  hasAgent: true,
  agentId: 'a',
  wechatBound: true,
);

const session = AuthSession(
  token: 'synthetic',
  userId: 'test',
  username: 'test',
  role: UserRole.user,
  hasAgent: true,
  agentId: 'a',
);
Future<void> _show(
  WidgetTester t,
  _Api api, {
  bool recharge = false,
  bool bundle = false,
  AuthSession user = session,
  WeChatLoginService? wechatLogin,
}) async {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      home: StorePage(
        api: api,
        session: user,
        wechatLogin: wechatLogin,
        openTicketRecharge: recharge,
        openBundle: bundle,
      ),
    ),
  );
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
}

Finder _subscriptionScroll() => find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .first;

/// 档位卡的描边宽度：选中 2.4，未选中 1（见 store_subscription_plan.dart）。
double _planBorderWidth(WidgetTester t, String title) {
  final box = t.widget<AnimatedContainer>(
    find
        .ancestor(of: find.text(title), matching: find.byType(AnimatedContainer))
        .first,
  );
  return ((box.decoration as BoxDecoration).border as Border).top.width;
}

CupertinoButton _button(WidgetTester t, String label) =>
    t.widget<CupertinoButton>(
      find
          .ancestor(
            of: find.text(label),
            matching: find.byType(CupertinoButton),
          )
          .first,
    );
void main() {
  testWidgets(
    'subscription stays fixed when it fits while payment availability changes silently',
    (t) async {
      final api = _Api()..gate = Completer<bool>();
      await _show(t, api);
      final vertical = _subscriptionScroll();
      final scroll = t.state<ScrollableState>(vertical);
      expect(scroll.position.maxScrollExtent, 0);
      expect(find.text('正在确认购买服务…'), findsNothing);
      final initialButton = t.getRect(find.text('立即开通'));
      expect(initialButton.top, greaterThan(0));
      expect(t.getRect(find.text('兑换激活码')).bottom, lessThan(844));
      await t.drag(vertical, const Offset(0, -220));
      await t.pump(const Duration(milliseconds: 300));
      expect(scroll.position.pixels, 0);
      expect(t.getRect(find.text('立即开通')), initialButton);
      api.gate!.complete(false);
      await t.pump();
      await t.pump();
      expect(find.text('付费购买暂未开放，激活码兑换仍可使用'), findsNothing);
      expect(t.getRect(find.text('立即开通')), initialButton);
      api.gate = null;
      api.enabled = true;
      await t.pump(const Duration(seconds: 10));
      await t.pump();
      expect(t.getRect(find.text('立即开通')), initialButton);
      await t.drag(vertical, const Offset(0, 220));
      await t.pump(const Duration(milliseconds: 300));
      expect(scroll.position.pixels, 0);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'short screens and large system fonts can scroll to the bottom links',
    (t) async {
      t.view.physicalSize = const Size(360, 720);
      t.view.devicePixelRatio = 1;
      t.view.padding = const FakeViewPadding(top: 32, bottom: 48);
      t.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(t.view.reset);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await t.pumpWidget(
        MaterialApp(
          home: StorePage(api: _Api(), session: session),
        ),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      final scroll = t.state<ScrollableState>(_subscriptionScroll());
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      await t.drag(_subscriptionScroll(), const Offset(0, -1000));
      await t.pumpAndSettle();
      expect(scroll.position.pixels, scroll.position.maxScrollExtent);
      final barTop = t.getRect(find.text('充值').last).top;
      expect(t.getRect(find.text('兑换激活码')).bottom, lessThan(barTop));
      await t.tap(find.text('兑换激活码'));
      await t.pumpAndSettle();
      expect(find.text('兑换 VIP 激活码'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'iOS hides activation code redemption but keeps restore purchases',
    (t) async {
      await _show(t, _Api());
      expect(find.text('恢复购买'), findsOneWidget);
      expect(find.text('兑换激活码'), findsNothing);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'iOS subscription stays disabled after consent; remote toggle updates live',
    (t) async {
      final api = _Api();
      await _show(t, api);
      await t.ensureVisible(find.text('已阅读同意'));
      await t.pump();
      await t.tap(find.text('已阅读同意'));
      await t.pump();
      expect(_button(t, '立即开通').onPressed, isNull);
      expect(find.text('付费购买暂未开放，激活码兑换仍可使用'), findsNothing);
      api.enabled = true;
      await t.pump(const Duration(seconds: 10));
      await t.pump();
      expect(_button(t, '立即开通').onPressed, isNotNull);
      api.enabled = false;
      await t.pump(const Duration(seconds: 10));
      await t.pump();
      expect(_button(t, '立即开通').onPressed, isNull);
      expect(api.reads, 3);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'Android ignores the Apple flag: purchases follow only WeChat Pay',
    (t) async {
      // Apple 内购开、微信支付关：安卓三个入口都不可点，文案保持原样；
      // 激活码兑换不受影响。
      final api = _Api()..enabled = true;
      await _show(t, api);
      await t.ensureVisible(find.text('已阅读同意'));
      await t.pump();
      await t.tap(find.text('已阅读同意'));
      await t.pump();
      expect(_button(t, '立即开通').onPressed, isNull);
      expect(_button(t, '兑换激活码').onPressed, isNotNull);

      await t.tap(find.text('充值'));
      await t.pumpAndSettle();
      expect(_button(t, '立即充值').onPressed, isNull);

      await t.tap(find.text('礼包'));
      await t.pumpAndSettle();
      final trial = find.text('¥1 立即体验');
      await t.scrollUntilVisible(
        trial,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(_button(t, '¥1 立即体验').onPressed, isNull);

      // 微信支付打开后，安卓三个入口都可点（走服务号引导）。
      api.android = const AndroidStoreSettings(
        wechatPayEnabled: true,
        autoRenewPlanEnabled: false,
      );
      await t.pump(const Duration(seconds: 10));
      await t.pumpAndSettle();
      expect(_button(t, '¥1 立即体验').onPressed, isNotNull);
      await t.tap(find.text('充值'));
      await t.pumpAndSettle();
      expect(_button(t, '立即充值').onPressed, isNotNull);
      await t.tap(find.text('订阅'));
      await t.pumpAndSettle();
      // 切换 tab 后订阅页重建，协议需要重新勾选。
      expect(_button(t, '立即开通').onPressed, isNull);
      await t.ensureVisible(find.text('已阅读同意'));
      await t.pump();
      await t.tap(find.text('已阅读同意'));
      await t.pump();
      expect(_button(t, '立即开通').onPressed, isNotNull);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('agreement links open legal documents without toggling consent', (
    t,
  ) async {
    final api = _Api()..enabled = true;
    await _show(t, api);
    await t.ensureVisible(find.text('《隐私政策》'));
    await t.pump();
    await t.tap(find.text('《隐私政策》'));
    await t.pumpAndSettle();
    expect(find.text('隐私政策'), findsWidgets);
    t.state<NavigatorState>(find.byType(Navigator).last).pop();
    await t.pumpAndSettle();
    // 点链接不应顺带勾选同意。
    expect(_button(t, '立即开通').onPressed, isNull);
    await t.tap(find.text('《会员协议与续费条款》'));
    await t.pumpAndSettle();
    expect(find.text('用户协议'), findsWidgets);
    expect(t.takeException(), isNull);
  });
  testWidgets('loading and network errors never enable cash recharge', (
    t,
  ) async {
    final api = _Api()..gate = Completer<bool>();
    await _show(t, api, recharge: true);
    expect(_button(t, '立即充值').onPressed, isNull);
    final rechargeButton = t.getRect(find.text('立即充值'));
    await t.dragFrom(const Offset(195, 320), const Offset(0, -180));
    await t.pump(const Duration(milliseconds: 300));
    expect(t.getRect(find.text('立即充值')), rechargeButton);
    api.gate!.completeError(const ApiException(503, 'unavailable'));
    await t.pump();
    await t.pump();
    expect(_button(t, '立即充值').onPressed, isNull);
    expect(find.text('购买服务暂不可用，请稍后重试'), findsNothing);
    expect(t.getRect(find.text('立即充值')), rechargeButton);
    api.gate = null;
    api.enabled = true;
    await t.pump(const Duration(seconds: 10));
    await t.pump();
    expect(_button(t, '立即充值').onPressed, isNotNull);
    expect(t.getRect(find.text('立即充值')), rechargeButton);
    api.fails = true;
    await t.pump(const Duration(seconds: 10));
    await t.pump();
    expect(_button(t, '立即充值').onPressed, isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  testWidgets(
    'internal point conversion remains enabled with real-money switch off',
    (t) async {
      final api = _Api();
      await _show(t, api, recharge: true);
      await t.tap(find.text('我的积分'));
      await t.pump();
      expect(_button(t, '立即兑换').onPressed, isNotNull);
      expect(find.text('付费购买暂未开放，激活码兑换仍可使用'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'managing an existing subscription does not require the payment flag or a new agreement',
    (t) async {
      final api = _Api()..autoRenew = true;
      await _show(t, api);
      expect(_button(t, '管理订阅').onPressed, isNotNull);
    },
  );
  testWidgets(
    'cash VIP trial is disabled while internal bundle purchases stay clickable',
    (t) async {
      await _show(t, _Api(), bundle: true);
      await t.scrollUntilVisible(
        find.text('购买').first,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(_button(t, '购买').onPressed, isNotNull);
      final trial = find.textContaining('立即体验');
      await t.scrollUntilVisible(
        trial,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        t
            .widget<CupertinoButton>(
              find
                  .ancestor(of: trial, matching: find.byType(CupertinoButton))
                  .first,
            )
            .onPressed,
        isNull,
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('Android routes both purchases to WeChat and hides auto-renew', (
    t,
  ) async {
    final api = _Api()..android = const AndroidStoreSettings(
      wechatPayEnabled: true,
      autoRenewPlanEnabled: false,
    );
    await _show(t, api, recharge: true, user: boundSession);
    await t.pump();
    // 充值页：按钮文案保持原样（应用市场审核），不额外加入口行。
    expect(find.text('立即充值'), findsOneWidget);
    expect(find.textContaining('去微信'), findsNothing);
    // Apple 内购关着也能点，因为它走的是微信而不是 StoreKit。
    expect(_button(t, '立即充值').onPressed, isNotNull);

    // 订阅页：按钮文案不变，连续包月档位按开关隐藏。
    await t.tap(find.text('订阅'));
    await t.pumpAndSettle();
    expect(find.text('连续包月'), findsNothing);
    expect(find.text('月卡'), findsOneWidget);
    // 默认选中的是被隐藏的连续包月，必须回退到第一个可见档位（月卡），
    // 否则没有任何卡片是选中态，按钮打的也是看不见的档位。
    expect(_planBorderWidth(t, '月卡'), 2.4);
    expect(find.text('立即开通'), findsOneWidget);
    expect(find.textContaining('去微信'), findsNothing);
    await t.ensureVisible(find.text('已阅读同意'));
    await t.pump();
    await t.tap(find.text('已阅读同意'));
    await t.pump();
    expect(_button(t, '立即开通').onPressed, isNotNull);
    await t.tap(find.text('立即开通'));
    await t.pumpAndSettle();
    expect(find.text('前往微信服务号支付'), findsOneWidget);
    expect(find.textContaining('会员需要在微信服务号'), findsOneWidget);
    await t.tap(find.text('取消'));
    await t.pumpAndSettle();

    // 开关打开后连续包月回来。
    api.android = const AndroidStoreSettings(
      wechatPayEnabled: true,
      autoRenewPlanEnabled: true,
    );
    await t.pump(const Duration(seconds: 10));
    await t.pumpAndSettle();
    expect(find.text('连续包月'), findsOneWidget);

    // 微信支付关掉后回到 Apple 内购的置灰逻辑。
    api.android = AndroidStoreSettings.closed;
    await t.pump(const Duration(seconds: 10));
    await t.pumpAndSettle();
    expect(_button(t, '立即开通').onPressed, isNull);
  });

  testWidgets('a phone-only account binds WeChat before the payment guide', (
    t,
  ) async {
    final api = _Api()..android = const AndroidStoreSettings(
      wechatPayEnabled: true,
      autoRenewPlanEnabled: false,
    );
    final bind = _Bind()..succeed = false;
    await _show(t, api, recharge: true, wechatLogin: bind);
    await t.pump();
    await t.tap(find.text('立即充值'));
    await t.pumpAndSettle();
    // 先弹绑定框，不直接出支付引导。
    expect(find.text('请先绑定微信'), findsOneWidget);
    expect(find.text('前往微信服务号支付'), findsNothing);
    // 取消绑定：不进入支付引导。
    await t.tap(find.text('取消'));
    await t.pumpAndSettle();
    expect(bind.calls, 0);
    expect(find.text('前往微信服务号支付'), findsNothing);
    // 绑定失败：提示原因，仍不进入支付引导。
    await t.tap(find.text('立即充值'));
    await t.pumpAndSettle();
    await t.tap(find.text('绑定微信'));
    await t.pumpAndSettle();
    expect(bind.calls, 1);
    expect(find.text('已取消微信登录'), findsOneWidget);
    expect(find.text('前往微信服务号支付'), findsNothing);
    await t.pump(const Duration(seconds: 2));
    // 绑定成功：紧接着弹出正常的支付引导，引导框里写明已绑定成功（底部提示
    // 会被弹框盖住），新会话交给 AuthGate，之后不再要求绑定。
    bind.succeed = true;
    final published = <AuthSession>[];
    final sub = authSessionUpdatesForTesting.listen(published.add);
    addTearDown(sub.cancel);
    await t.tap(find.text('立即充值'));
    await t.pumpAndSettle();
    await t.tap(find.text('绑定微信'));
    await t.pumpAndSettle();
    expect(bind.calls, 2);
    expect(find.text('前往微信服务号支付'), findsOneWidget);
    expect(find.textContaining('微信已绑定成功'), findsOneWidget);
    expect(published.map((s) => s.wechatBound), [true]);
    await t.tap(find.text('取消'));
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 2));
    await t.tap(find.text('立即充值'));
    await t.pumpAndSettle();
    expect(find.text('请先绑定微信'), findsNothing);
    expect(find.text('前往微信服务号支付'), findsOneWidget);
    // 已绑定账号的引导框不重复说「绑定成功」。
    expect(find.textContaining('微信已绑定成功'), findsNothing);
    expect(api.meReads, 0);
  });

  testWidgets('VIP trial button follows only the payment flag, like plans', (
    t,
  ) async {
    // 已体验过：开关打开时按钮照常可点、文案不变，点击后才说明限购，
    // 不拉起 Apple 支付。
    final api = _Api()
      ..enabled = true
      ..trialAvailable = false;
    await _show(t, api, bundle: true);
    await t.pump();
    final trial = find.textContaining('立即体验');
    await t.scrollUntilVisible(
      trial,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('¥1 立即体验'), findsOneWidget);
    expect(find.textContaining('暂不可购买'), findsNothing);
    final button = find
        .ancestor(of: trial, matching: find.byType(CupertinoButton))
        .first;
    expect(t.widget<CupertinoButton>(button).onPressed, isNotNull);
    await t.tap(trial);
    await t.pumpAndSettle();
    expect(find.text('每个账号只能体验一次，你已经体验过了。'), findsOneWidget);
    expect(find.textContaining('将支付'), findsNothing);
    await t.tap(find.text('知道了'));
    await t.pumpAndSettle();

    // 开关关闭：与订阅 tab 一样只是不可点，文案保持不变。
    api.enabled = false;
    await t.pump(const Duration(seconds: 10));
    await t.pumpAndSettle();
    expect(find.text('¥1 立即体验'), findsOneWidget);
    expect(t.widget<CupertinoButton>(button).onPressed, isNull);
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Android VIP trial opens the WeChat guide instead of IAP', (
    t,
  ) async {
    final api = _Api()..android = const AndroidStoreSettings(
      wechatPayEnabled: true,
      autoRenewPlanEnabled: false,
    );
    await _show(t, api, bundle: true, user: boundSession);
    await t.pump();
    final trial = find.textContaining('立即体验');
    await t.scrollUntilVisible(
      trial,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    // Apple 内购关着，但安卓走服务号，体验按钮可以点。
    final button = find
        .ancestor(of: trial, matching: find.byType(CupertinoButton))
        .first;
    expect(t.widget<CupertinoButton>(button).onPressed, isNotNull);
    await t.tap(trial);
    await t.pumpAndSettle();
    expect(find.text('前往微信服务号支付'), findsOneWidget);
    expect(find.textContaining('月度 VIP 体验需要在微信服务号'), findsOneWidget);
    expect(find.textContaining('内购暂不可用'), findsNothing);
    await t.tap(find.text('取消'));
    await t.pumpAndSettle();
  });

  testWidgets('iOS keeps Apple IAP and never reads the Android flags', (
    t,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final api = _Api()
        ..enabled = true
        ..android = const AndroidStoreSettings(
          wechatPayEnabled: true,
          autoRenewPlanEnabled: false,
        );
      await _show(t, api, recharge: true);
      await t.pump(const Duration(seconds: 10));
      await t.pump();
      // 安卓开关在 iOS 上既不请求，也不影响任何文案或档位。
      expect(api.androidReads, 0);
      expect(find.text('立即充值'), findsOneWidget);
      await t.tap(find.text('订阅'));
      await t.pumpAndSettle();
      expect(find.text('连续包月'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('an active auto-renew keeps its plan visible on Android', (
    t,
  ) async {
    // 在 iOS 订阅、换到安卓登录同一账号：连续包月开关是关的，但档位必须还在，
    // 否则用户看不到「管理订阅」，没有任何地方能停掉扣款。
    final api = _Api()
      ..autoRenew = true
      ..android = const AndroidStoreSettings(
        wechatPayEnabled: true,
        autoRenewPlanEnabled: false,
      );
    await _show(t, api);
    await t.pumpAndSettle();
    expect(find.text('连续包月'), findsOneWidget);
    expect(_planBorderWidth(t, '连续包月'), 2.4);
    // 管理订阅走 Apple，点了不能弹出去微信的引导。
    expect(_button(t, '管理订阅').onPressed, isNotNull);
  });

  testWidgets('the WeChat guidance dialog renders real text, not mojibake', (
    t,
  ) async {
    final api = _Api()..android = const AndroidStoreSettings(
      wechatPayEnabled: true,
      autoRenewPlanEnabled: false,
    );
    await _show(t, api, recharge: true, user: boundSession);
    await t.pump();
    await t.tap(find.text('立即充值'));
    await t.pumpAndSettle();
    // 弹窗正文是用户走这条路看到的第一屏，必须可读：不能有替换字符。
    final body = t
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .join('\n');
    expect(body.contains('\uFFFD'), isFalse, reason: body);
    expect(find.textContaining('伴生小助手'), findsOneWidget);
    expect(find.textContaining('服务号名称已复制'), findsOneWidget);
    expect(find.text('打开微信'), findsOneWidget);
    // 取消后不写剪贴板、不拉起微信。
    await t.tap(find.text('取消'));
    await t.pumpAndSettle();
    expect(find.text('打开微信'), findsNothing);
  });
}
