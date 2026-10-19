import 'dart:async';

import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const session = AuthSession(
  token: 'admin-token',
  userId: 'admin',
  username: 'admin',
  role: UserRole.admin,
  hasAgent: true,
);

class _Api extends CompanionApi {
  _Api() : super(baseUrl: 'https://synthetic.test');
  bool enabled = false, failRead = false, failWrite = false;
  int reads = 0;
  Completer<bool>? pendingRead, pendingWrite;
  final writes = <bool>[];

  @override
  Future<bool> fetchAdminRealMoneyPaymentsEnabled() async {
    expect(authToken, session.token);
    reads++;
    if (failRead) throw const ApiException(503, 'synthetic');
    return pendingRead?.future ?? enabled;
  }

  @override
  Future<bool> updateAdminRealMoneyPaymentsEnabled(bool next) async {
    expect(authToken, session.token);
    writes.add(next);
    if (failWrite) {
      enabled = next; // The backend may have committed before a lost response.
      throw const ApiException(503, 'synthetic');
    }
    enabled = await (pendingWrite?.future ?? Future.value(next));
    return enabled;
  }
}

Finder get card => find
    .ancestor(
      of: find.text('真实付费购买'),
      matching: find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_AdminFlagCard',
      ),
    )
    .first;
Finder get toggle =>
    find.descendant(of: card, matching: find.byType(CupertinoSwitch));
Finder label(String text) =>
    find.descendant(of: card, matching: find.text(text));

Future<void> _open(
  WidgetTester t,
  _Api api, {
  double width = 390,
  double scale = 1,
}) async {
  t.view.physicalSize = Size(width, 1000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: AdminToolsPage(api: api, session: session),
    ),
  );
  await t.pump(const Duration(milliseconds: 500));
  await t.scrollUntilVisible(find.text('全局模块开关'), 400, maxScrolls: 20);
  await t.tap(find.text('全局模块开关'));
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
  await t.ensureVisible(toggle);
  await t.pump();
}

void main() {
  testWidgets(
    'root opens shared payment switch; saves only acknowledged state and polls external changes',
    (t) async {
      final api = _Api();
      await _open(t, api);
      expect(label('已关闭'), findsOneWidget);
      api.pendingWrite = Completer<bool>();
      await t.tap(toggle);
      await t.pump();
      expect(api.writes, [true]);
      expect(t.widget<CupertinoSwitch>(toggle).value, false);
      expect(t.widget<CupertinoSwitch>(toggle).onChanged, isNull);
      expect(label('保存中…'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 9500));
      expect(api.reads, 1, reason: 'Polling must not race an in-flight save');
      api.pendingWrite!.complete(true);
      await t.pump();
      await t.pump();
      expect(label('已开启'), findsOneWidget);
      api.enabled = false;
      await t.pump(const Duration(seconds: 10));
      await t.pump();
      expect(label('已关闭'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'failed reads and unconfirmed writes stay unknown; manual refresh recovers actual backend state',
    (t) async {
      final api = _Api()..failRead = true;
      await _open(t, api);
      expect(label('读取失败'), findsOneWidget);
      expect(label('已关闭'), findsNothing);
      expect(t.widget<CupertinoSwitch>(toggle).onChanged, isNull);
      api.failRead = false;
      await t.ensureVisible(label('刷新支付开关'));
      await t.tap(label('刷新支付开关'));
      await t.pump();
      await t.pump();
      expect(label('已关闭'), findsOneWidget);
      api.failWrite = true;
      await t.ensureVisible(toggle);
      await t.pump();
      await t.tap(toggle);
      await t.pump();
      await t.pump();
      expect(label('保存结果未确认，请刷新查看'), findsOneWidget);
      expect(label('已关闭'), findsNothing);
      expect(t.widget<CupertinoSwitch>(toggle).onChanged, isNull);
      await t.ensureVisible(label('刷新支付开关'));
      await t.tap(label('刷新支付开关'));
      await t.pump();
      await t.pump();
      expect(label('已开启'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'background pauses polling, resume refreshes; late replies after leaving do not update disposed state',
    (t) async {
      final api = _Api();
      await _open(t, api);
      final reads = api.reads;
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump(const Duration(seconds: 20));
      expect(api.reads, reads);
      api.enabled = true;
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      await t.pump();
      expect(label('已开启'), findsOneWidget);
      api.pendingRead = Completer<bool>();
      await t.ensureVisible(label('刷新支付开关'));
      await t.tap(label('刷新支付开关'));
      await t.pump();
      await t.pumpWidget(const SizedBox());
      api.pendingRead!.complete(false);
      await t.pump();
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'compact layout remains usable and payment timeout does not block other module cards',
    (t) async {
      final api = _Api()..pendingRead = Completer<bool>();
      await _open(t, api, width: 320, scale: 1.5);
      expect(label('读取中…'), findsOneWidget);
      expect(t.widget<CupertinoSwitch>(toggle).onChanged, isNull);
      await t.pump(const Duration(seconds: 6));
      await t.pump();
      expect(label('读取失败'), findsOneWidget);
      expect(find.text('线下活动推荐'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      api.pendingRead!.complete(false);
      await t.pump();
    },
  );
}
