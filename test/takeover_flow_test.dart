import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:companion_flutter/takeover_inbox.dart';
import 'package:companion_flutter/takeover_unread.dart';
import 'package:flutter/cupertino.dart';
import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTakeoverApi extends CompanionApi {
  FakeTakeoverApi() : super(baseUrl: 'http://127.0.0.1:1');
  final scopes = <String>[];
  final reads = <String>[];
  final sends = <String>[];
  int unread = 3;
  bool failSummary = false;
  bool failHistory = false;
  bool failFirstSend = false;
  Completer<TakeoverUnreadSummary>? pendingSummary;
  Completer<List<TakeoverListItem>>? pendingList;
  List<ChatMessage>? scriptedHistory;

  @override
  Future<String> getTakeoverInboxTicket() async =>
      throw const ApiException(403, 'synthetic');
  @override
  Future<TakeoverUnreadSummary> getTakeoverUnreadSummary() async {
    if (pendingSummary != null) return pendingSummary!.future;
    if (failSummary) throw const ApiException(503, 'synthetic');
    return TakeoverUnreadSummary(unread, DateTime.utc(2026, 10, 12));
  }

  @override
  Future<List<TakeoverListItem>> listTakeovers(String scope) async {
    scopes.add(scope);
    if (scope == 'pending' && pendingList != null) return pendingList!.future;
    return [
      TakeoverListItem.fromJson({
        'id': 'case',
        'user_id': 'subject',
        'conversation_id': 'conv',
        'display_name': scope == 'mine' ? '我的用户' : '待处理用户',
        'status': scope == 'mine' ? 'active' : 'pending',
        'unread_count': unread,
      }),
    ];
  }

  @override
  Future<Conversation> getConversation(String id) async => Conversation(
    id: id,
    userId: 'subject',
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
  }) async {
    if (failHistory) throw const ApiException(503, 'history unavailable');
    if (scriptedHistory != null) return scriptedHistory!;
    return [
      ChatMessage(
        id: 'incoming',
        conversationId: id,
        role: 'user',
        content: '用户完整消息',
        createdAt: DateTime.utc(2026, 10, 12),
        metadata: const {'human_takeover': true, 'takeover_sequence': 1},
      ),
    ];
  }

  @override
  Future<void> markTakeoverRead(String takeoverId, String messageId) async {
    reads.add(messageId);
  }

  @override
  Future<String> sendTakeoverMessage(
    String takeoverId, {
    required String text,
    String? clientId,
  }) async {
    sends.add(clientId!);
    if (failFirstSend && sends.length == 1) {
      throw const ApiException(503, 'synthetic lost ack');
    }
    return 'saved-admin-message';
  }
}

AuthSession adminSession() => const AuthSession(
  token: 'synthetic',
  userId: 'admin',
  username: 'admin',
  role: UserRole.admin,
  hasAgent: false,
);

Future<void> drain(WidgetTester tester) async {
  for (var n = 0; n < 8; n++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

Future<void> chat(WidgetTester tester, FakeTakeoverApi api) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      navigatorObservers: [appRouteObserver],
      home: ChatPage(
        api: api,
        session: adminSession(),
        isActive: true,
        onOpenSidebar: () {},
        takeover: const TakeoverChatTarget(
          takeoverId: 'case',
          conversationId: 'conv',
          userName: '我的用户',
          agentName: '目标角色',
        ),
      ),
    ),
  );
  await drain(tester);
}

void main() {
  tearDown(() async {
    TakeoverUnreadController.instance.clear();
    await TakeoverInbox.instance.stop();
  });

  testWidgets('mine tab is first/default and header matches admin navigation', (
    tester,
  ) async {
    final api = FakeTakeoverApi();
    await tester.pumpWidget(
      MaterialApp(
        home: AdminTakeoverListPage(api: api, session: adminSession()),
      ),
    );
    await drain(tester);
    expect(api.scopes, ['mine']);
    expect(
      tester.getCenter(find.text('我接管的')).dx,
      lessThan(tester.getCenter(find.text('待处理')).dx),
    );
    expect(tester.widget<Text>(find.text('用户聊天接管')).style?.fontSize, 18);
    expect(find.byIcon(CupertinoIcons.chevron_left), findsOneWidget);
    expect(find.text('未读 3'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('late pending response cannot replace the mine tab', (
    tester,
  ) async {
    final api = FakeTakeoverApi()
      ..pendingList = Completer<List<TakeoverListItem>>();
    await tester.pumpWidget(
      MaterialApp(
        home: AdminTakeoverListPage(api: api, session: adminSession()),
      ),
    );
    await drain(tester);
    await tester.tap(find.text('待处理'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('我接管的'));
    await drain(tester);
    api.pendingList!.complete([
      TakeoverListItem.fromJson({'id': 'wrong', 'display_name': '错误响应'}),
    ]);
    await drain(tester);
    expect(find.text('我的用户'), findsOneWidget);
    expect(find.text('错误响应'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'takeover chat shows the user name, trailing status, and composer icons',
    (tester) async {
      final api = FakeTakeoverApi();
      await chat(tester, api);
      expect(find.text('我的用户'), findsOneWidget);
      expect(find.text('目标角色'), findsNothing);
      expect(find.text('空闲'), findsOneWidget);
      expect(find.text('退出'), findsOneWidget);
      expect(find.byTooltip('连续互动 12 天'), findsNothing);
      expect(find.byTooltip('表情'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.mic), findsOneWidget);
      expect(find.byTooltip('更多'), findsNothing);
      expect(find.text('回复由AI生成'), findsNothing);
      tester
              .widget<ExtendedTextField>(find.byType(ExtendedTextField))
              .controller!
              .text =
          '纯文字回复';
      await drain(tester);
      final sendBottom = tester.getBottomLeft(find.text('发送')).dy;
      expect(sendBottom, greaterThan(844 - 34 - 45));
      expect(api.reads, contains('incoming'));
      await tester.pumpWidget(const SizedBox());
      await drain(tester);
    },
  );

  testWidgets(
    'takeover chat puts the user portrait on the left and the agent on the right',
    (tester) async {
      const userPath = '/users/avatar/subject.jpg';
      const agentPath = '/agents/avatar/companion-female-01.png';
      final api = FakeTakeoverApi()
        ..scriptedHistory = [
          ChatMessage(
            id: 'incoming',
            conversationId: 'conv',
            role: 'user',
            content: '用户完整消息',
            createdAt: DateTime.utc(2026, 10, 12, 13),
            metadata: const {'human_takeover': true, 'takeover_sequence': 1},
          ),
          ChatMessage(
            id: 'reply',
            conversationId: 'conv',
            role: 'assistant',
            content: '在呢',
            createdAt: DateTime.utc(2026, 10, 12, 13, 1),
          ),
        ];
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [appRouteObserver],
          home: ChatPage(
            api: api,
            session: adminSession(),
            isActive: true,
            onOpenSidebar: () {},
            takeover: const TakeoverChatTarget(
              takeoverId: 'case',
              conversationId: 'conv',
              userName: '我的用户',
              agentName: '目标角色',
              userAvatarUrl: userPath,
              agentAvatarUrl: agentPath,
            ),
          ),
        ),
      );
      await drain(tester);

      List<double> centers(String url) {
        final finder = find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is CachedNetworkImageProvider &&
              (widget.image as CachedNetworkImageProvider).url == url,
        );
        return [
          for (final element in finder.evaluate())
            tester.getCenter(find.byWidget(element.widget)).dx,
        ];
      }

      final userXs = centers('http://127.0.0.1:1$userPath');
      final agentXs = centers('http://127.0.0.1:1$agentPath');
      expect(userXs.length, greaterThanOrEqualTo(2));
      expect(userXs.every((dx) => dx < 160), isTrue);
      expect(agentXs, [greaterThan(240)]);
      await tester.pumpWidget(const SizedBox());
      await drain(tester);
    },
  );

  testWidgets(
    'failed human reply retries the same client ID without duplicate bubbles',
    (tester) async {
      final api = FakeTakeoverApi()..failFirstSend = true;
      await chat(tester, api);
      tester
              .widget<ExtendedTextField>(find.byType(ExtendedTextField))
              .controller!
              .text =
          '重试文字';
      await drain(tester);
      await tester.tap(find.text('发送'));
      await drain(tester);
      expect(api.sends, hasLength(1));
      expect(find.text('重试文字'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == '发送失败，点击重试',
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == '发送失败，点击重试',
        ),
      );
      await drain(tester);
      expect(api.sends, hasLength(2));
      expect(api.sends.toSet(), hasLength(1));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == '发送失败，点击重试',
        ),
        findsNothing,
      );
      expect(find.text('重试文字'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await drain(tester);
    },
  );

  testWidgets('failed history never clears unread', (tester) async {
    final api = FakeTakeoverApi()..failHistory = true;
    await chat(tester, api);
    expect(api.reads, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await drain(tester);
  });

  testWidgets(
    'foreground takeover events display a banner even on the own-chat tab',
    (tester) async {
      final api = FakeTakeoverApi();
      await tester.pumpWidget(
        MaterialApp(
          home: MainShell(
            api: api,
            session: adminSession(),
            onSessionChanged: (_) {},
            onLogout: () {},
          ),
        ),
      );
      await drain(tester);
      AppNotificationService.instance.emit(
        const AppNotificationEvent(
          id: 'm1',
          type: 'admin_takeover_message',
          title: '用户昵称',
          body: '新的用户消息',
          route: 'admin_takeover_chat',
          source: AppNotificationSource.inApp,
          payload: {'takeover_id': 'case'},
        ),
      );
      await drain(tester);
      expect(find.text('用户昵称'), findsOneWidget);
      expect(find.text('新的用户消息'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await drain(tester);
    },
  );

  testWidgets('takeover menu entry uses the same numeric unread snapshot', (
    tester,
  ) async {
    final api = FakeTakeoverApi();
    TakeoverUnreadController.instance.configure(api, 'admin');
    await tester.pumpWidget(
      MaterialApp(
        home: AdminToolsPage(api: api, session: adminSession()),
      ),
    );
    await drain(tester);
    final row = find.text('用户聊天接管');
    await tester.scrollUntilVisible(
      row,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await drain(tester);
    expect(row, findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    TakeoverUnreadController.instance.clear();
    await tester.pumpWidget(const SizedBox());
    await drain(tester);
  });

  testWidgets('administrator profile entry displays the shared unread badge', (
    tester,
  ) async {
    final api = FakeTakeoverApi();
    TakeoverUnreadController.instance.configure(api, 'admin');
    await tester.pumpWidget(
      MaterialApp(
        home: ProfilePage(
          api: api,
          session: adminSession(),
          active: true,
          onAgentDeleted: (_) {},
          onSessionChanged: (_) {},
          onLogout: () {},
        ),
      ),
    );
    await drain(tester);
    expect(find.text('管理员入口'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    TakeoverUnreadController.instance.clear();
    await tester.pumpWidget(const SizedBox());
    await drain(tester);
  });

  testWidgets('unread badges update and retain stale counts on failure', (
    tester,
  ) async {
    final api = FakeTakeoverApi();
    final state = TakeoverUnreadController();
    state.configure(api, 'admin');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TakeoverUnreadBadge(controller: state)),
      ),
    );
    await drain(tester);
    expect(find.text('3'), findsOneWidget);
    api.failSummary = true;
    await state.refresh();
    await tester.pump();
    expect(find.text('3!'), findsOneWidget);
    api.failSummary = false;
    api.unread = 0;
    await state.refresh();
    await tester.pump();
    expect(find.byKey(const ValueKey('takeover-unread-badge')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });

  testWidgets(
    'unread loading and late logout response are not a zero snapshot',
    (tester) async {
      final api = FakeTakeoverApi()
        ..pendingSummary = Completer<TakeoverUnreadSummary>();
      final state = TakeoverUnreadController()..configure(api, 'admin');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TakeoverUnreadBadge(controller: state)),
        ),
      );
      await tester.pump();
      expect(find.text('…'), findsOneWidget);
      state.clear();
      api.pendingSummary!.complete(
        TakeoverUnreadSummary(9, DateTime.utc(2026, 10, 12)),
      );
      await tester.pump();
      expect(state.count, isNull);
      expect(find.byKey(const ValueKey('takeover-unread-badge')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );

  test(
    'foreground native push remains an in-app event with a stable registration ID',
    () {
      final event = AppNotificationEvent.fromPushPayload(
        const PushNotificationPayload({
          'type': 'admin_new_user',
          'route': 'admin_takeover_review',
          'takeover_id': 'case',
          '_foreground_delivery': true,
          'title': '新用户注册',
        }),
      );
      expect(event.isRemotePush, isFalse);
      expect(event.id, 'case');
      expect(event.isTakeoverReview, isTrue);
    },
  );
}
