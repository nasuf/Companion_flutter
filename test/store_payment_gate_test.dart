import 'dart:async';
import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api extends CompanionApi {
  _Api() : super(baseUrl: 'https://synthetic.test');
  bool enabled = false, fails = false, autoRenew = false;
  Completer<bool>? gate;
  int reads = 0;
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
          vipTrialAvailable: true,
          giftTicketBalance: 0,
          ticketBalance: 1000,
          pointBalance: 1000,
          spendableTickets: 1000,
        ),
        autoRenewActive: autoRenew,
        history: [],
      );
}

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
}) async {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      home: StorePage(
        api: api,
        session: session,
        openTicketRecharge: recharge,
        openBundle: bundle,
      ),
    ),
  );
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
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
    'subscription disabled after consent while redemption stays available; remote toggle updates live',
    (t) async {
      final api = _Api();
      await _show(t, api);
      await t.ensureVisible(find.text('已阅读同意《会员协议与续费条款》'));
      await t.pump();
      await t.tap(find.text('已阅读同意《会员协议与续费条款》'));
      await t.pump();
      expect(_button(t, '立即开通').onPressed, isNull);
      expect(_button(t, '兑换激活码').onPressed, isNotNull);
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
  );
  testWidgets('loading and network errors never enable cash recharge', (
    t,
  ) async {
    final api = _Api()..gate = Completer<bool>();
    await _show(t, api, recharge: true);
    expect(_button(t, '立即充值').onPressed, isNull);
    api.gate!.completeError(const ApiException(503, 'unavailable'));
    await t.pump();
    await t.pump();
    expect(_button(t, '立即充值').onPressed, isNull);
    expect(find.text('购买服务暂不可用，请稍后重试'), findsOneWidget);
    api.gate = null;
    api.enabled = true;
    await t.pump(const Duration(seconds: 10));
    await t.pump();
    expect(_button(t, '立即充值').onPressed, isNotNull);
    api.fails = true;
    await t.pump(const Duration(seconds: 10));
    await t.pump();
    expect(_button(t, '立即充值').onPressed, isNull);
  });
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
}
