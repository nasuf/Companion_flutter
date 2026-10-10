import 'dart:async';
import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:companion_flutter/offline_models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const session = AuthSession(
  token: 'admin-token',
  userId: 'owner',
  username: 'admin',
  role: UserRole.admin,
  hasAgent: true,
  workspaceId: 'space',
);

class Api extends CompanionApi {
  Api() : super(baseUrl: 'https://example.test');
  int clears = 0;
  bool fail = false;
  Completer<AdminGiftClearResult>? pending;
  final injections = <bool>[];
  @override
  Future<RealWorldGift> createMockGift({
    String? workspaceId,
    bool delivered = false,
  }) async {
    expect(authToken, 'admin-token');
    expect(workspaceId, 'space');
    injections.add(delivered);
    return RealWorldGift.fromJson({'id': 'gift', 'gift_name': '测试礼物'});
  }

  @override
  Future<AdminGiftClearResult> clearOfflineGiftsForCurrentUser() async {
    expect(authToken, 'admin-token');
    clears++;
    if (fail) throw StateError('unavailable');
    return pending?.future ??
        Future.value(
          const AdminGiftClearResult(
            deletedGifts: 7,
            deletedTrackingEvents: 12,
            deletedMessages: 9,
            resetTriggerStates: 2,
          ),
        );
  }
}

Future<void> open(WidgetTester t, Api api, {AuthSession auth = session}) async {
  t.view.physicalSize = const Size(430, 1100);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      home: AdminGiftTestPage(api: api, session: auth),
    ),
  );
  await t.pump();
  await t.pump(const Duration(seconds: 1));
}

Finder button(String text) => find.widgetWithText(CupertinoButton, text);
Future<void> clear(WidgetTester t) async {
  await t.ensureVisible(button('清空所有礼物信息'));
  await t.tap(button('清空所有礼物信息'));
  await t.pump();
  await t.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('injection options retain owner, workspace and delivery mode', (
    t,
  ) async {
    final api = Api();
    await open(t, api);
    for (final name in ['注入运输中礼物', '注入已送达礼物']) {
      await t.tap(button(name));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.text('测试礼物已注入'), findsOneWidget);
      await t.tap(find.text('知道了'));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
    }
    expect(api.injections, [false, true]);
    expect(api.clears, 0);
  });
  testWidgets('cancel never deletes; confirmed reset displays actual counts', (
    t,
  ) async {
    final api = Api();
    await open(t, api);
    await clear(t);
    expect(find.textContaining('所有工作区、所有状态'), findsOneWidget);
    await t.tap(find.text('取消'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(api.clears, 0);
    await clear(t);
    await t.tap(find.text('确认清空'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(api.clears, 1);
    expect(find.textContaining('7 份礼物、12 条物流轨迹、9 条关联消息'), findsOneWidget);
    await t.tap(find.text('好'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
  });
  testWidgets('failure permits retry and busy reset disables all operations', (
    t,
  ) async {
    final api = Api()..fail = true;
    await open(t, api);
    await clear(t);
    await t.tap(find.text('确认清空'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.textContaining('清空失败'), findsOneWidget);
    api.fail = false;
    api.pending = Completer();
    await clear(t);
    await t.tap(find.text('确认清空'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    for (final b in t.widgetList<CupertinoButton>(
      find.byType(CupertinoButton),
    )) {
      if (b.child is Text &&
          ['注入运输中礼物', '注入已送达礼物'].contains((b.child as Text).data)) {
        expect(b.onPressed, isNull);
      }
    }
    expect(api.clears, 2);
    expect(api.injections, isEmpty);
    api.pending!.complete(
      const AdminGiftClearResult(
        deletedGifts: 0,
        deletedTrackingEvents: 0,
        deletedMessages: 0,
        resetTriggerStates: 0,
      ),
    );
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.text('好'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
  });
  testWidgets('non-admin has no destructive actions', (t) async {
    final api = Api();
    await open(
      t,
      api,
      auth: const AuthSession(
        token: 'user',
        userId: 'owner',
        username: 'user',
        role: UserRole.user,
        hasAgent: true,
      ),
    );
    expect(find.text('仅管理员可用'), findsOneWidget);
    expect(button('清空所有礼物信息'), findsNothing);
    expect(api.clears, 0);
  });
  testWidgets('admin root contains one gift entry and navigates to options', (
    t,
  ) async {
    final api = Api();
    await t.pumpWidget(
      MaterialApp(
        home: AdminToolsPage(api: api, session: session),
      ),
    );
    await t.pump(const Duration(milliseconds: 500));
    await t.scrollUntilVisible(find.text('测试礼物赠送'), 400, maxScrolls: 20);
    expect(find.text('注入运输中礼物'), findsNothing);
    expect(find.text('注入已送达礼物'), findsNothing);
    await t.tap(find.text('测试礼物赠送'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.byType(AdminGiftTestPage), findsOneWidget);
    expect(button('清空所有礼物信息'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
