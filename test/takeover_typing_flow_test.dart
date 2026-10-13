import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:companion_flutter/takeover_inbox.dart';
import 'package:companion_flutter/takeover_unread.dart';
import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'takeover_flow_test.dart' as flow;

class TypingApi extends flow.FakeTakeoverApi {
  TypingApi({super.baseUrl});
  final adminPresence = <bool>[];
  final userPresence = <bool>[];
  int historyLoads = 0;
  int summaries = 0;
  bool connectInbox = false;
  bool connectChat = false;
  bool failPresence = false;
  @override
  Future<String> getTakeoverInboxTicket() async =>
      connectInbox ? 'a' * 43 : throw const ApiException(403, 'synthetic');
  @override
  Future<String> getWebSocketTicket(String id) async =>
      connectChat ? 'a' * 43 : throw const ApiException(403, 'synthetic');
  @override
  Future<void> setTakeoverTyping(
    String id, {
    required bool active,
    required int revision,
    String? sessionId,
  }) async {
    adminPresence.add(active);
    if (failPresence) throw const ApiException(503, 'typing unavailable');
  }

  @override
  Future<void> setUserTyping(
    String id, {
    required bool active,
    required int revision,
    required String sessionId,
  }) async {
    userPresence.add(active);
  }

  @override
  Future<List<ChatMessage>> loadMessages(
    String id, {
    int limit = 100,
    int offset = 0,
  }) {
    historyLoads++;
    return super.loadMessages(id, limit: limit, offset: offset);
  }

  @override
  Future<TakeoverUnreadSummary> getTakeoverUnreadSummary() {
    summaries++;
    return super.getTakeoverUnreadSummary();
  }
}

class RealHttp extends HttpOverrides {}

Future<void> network(
  WidgetTester tester,
  Future<void> Function() action,
) async {
  await tester.runAsync(() async {
    await action();
    await Future<void>.delayed(const Duration(milliseconds: 30));
  });
  await tester.pump(const Duration(milliseconds: 80));
}

void main() {
  tearDown(() async {
    TakeoverUnreadController.instance.clear();
    await TakeoverInbox.instance.stop();
  });

  testWidgets(
    'admin composer reports edits, idle, pause and route departure accurately',
    (tester) async {
      final api = TypingApi();
      await flow.chat(tester, api);
      final input = tester
          .widget<ExtendedTextField>(find.byType(ExtendedTextField))
          .controller!;
      input.text = 'a';
      await flow.drain(tester);
      expect(api.adminPresence.first, true);
      await tester.pump(const Duration(seconds: 5));
      expect(api.adminPresence.last, false);
      final before = api.adminPresence.length;
      input.selection = const TextSelection.collapsed(offset: 0);
      await flow.drain(tester);
      expect(api.adminPresence.length, before);
      input.text = 'ab';
      await flow.drain(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(api.adminPresence.last, false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await flow.drain(tester);
      expect(api.adminPresence.last, false);
      input.text = 'abc';
      await flow.drain(tester);
      final context = tester.element(find.byType(ChatPage));
      unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('详情')),
          ),
        ),
      );
      await flow.drain(tester);
      expect(api.adminPresence.last, false);
      await tester.pumpWidget(const SizedBox());
      await flow.drain(tester);
    },
  );

  testWidgets('typing transport failure does not block sending a message', (
    tester,
  ) async {
    final api = TypingApi()..failPresence = true;
    await flow.chat(tester, api);
    tester
            .widget<ExtendedTextField>(find.byType(ExtendedTextField))
            .controller!
            .text =
        '正常发送';
    await flow.drain(tester);
    expect(api.adminPresence.first, true);
    await tester.tap(find.text('发送'));
    await flow.drain(tester);
    expect(api.sends, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await flow.drain(tester);
  });

  for (final admin in [true, false]) {
    testWidgets(
      '${admin ? 'admin inbox' : 'user chat'} displays and expires peer typing from its real WebSocket',
      (tester) async {
        await HttpOverrides.runZoned(() async {
          final server = await tester.runAsync(
            () => HttpServer.bind(InternetAddress.loopbackIPv4, 0),
          );
          final peers = <WebSocket>[];
          final requests = await tester.runAsync(
            () async => server!.listen((request) async {
              if (!request.uri.path.startsWith('/ws/')) {
                request.response.statusCode = 404;
                await request.response.close();
                return;
              }
              peers.add(
                await WebSocketTransformer.upgrade(
                  request,
                  protocolSelector: (_) => 'companion.chat.v1',
                ),
              );
            }),
          );
          final api = TypingApi(baseUrl: 'http://127.0.0.1:${server!.port}')
            ..connectInbox = admin
            ..connectChat = !admin;
          try {
            if (admin) {
              TakeoverUnreadController.instance.configure(api, 'admin');
              await flow.chat(tester, api);
            } else {
              tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
                const MethodChannel('com.llfbandit.record/messages'),
                (_) async => null,
              );
              addTearDown(() {
                tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
                  const MethodChannel('com.llfbandit.record/messages'),
                  null,
                );
              });
              tester.view.physicalSize = const Size(390, 844);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.reset);
              await tester.pumpWidget(
                MaterialApp(
                  navigatorObservers: [appRouteObserver],
                  home: Scaffold(
                    body: ChatPage(
                      api: api,
                      session: const AuthSession(
                        token: 'synthetic',
                        userId: 'subject',
                        username: 'user',
                        role: UserRole.user,
                        hasAgent: true,
                        conversationId: 'conv',
                      ),
                      isActive: true,
                      onOpenSidebar: () {},
                    ),
                  ),
                ),
              );
              await flow.drain(tester);
            }
            for (var i = 0; peers.isEmpty && i < 100; i++) {
              await network(tester, () async {});
            }
            expect(peers, hasLength(1));
            await flow.drain(tester);
            final historyBefore = api.historyLoads;
            final summaryBefore = api.summaries;
            void emit(bool active, int revision, {String claim = 'case'}) =>
                peers.single.add(
                  jsonEncode({
                    'type': admin ? 'takeover_user_typing' : 'takeover_typing',
                    'data': {
                      'takeover_id': claim,
                      'conversation_id': 'conv',
                      'active': active,
                      'revision': revision,
                    },
                  }),
                );
            final indicator = find.byKey(const ValueKey('chat-peer-typing'));
            await network(tester, () async => emit(true, 1));
            expect(indicator, findsOneWidget);
            if (admin) {
              await network(
                tester,
                () async => emit(false, 50, claim: 'other'),
              );
              expect(indicator, findsOneWidget);
              expect(api.historyLoads, historyBefore);
              expect(api.summaries, summaryBefore);
            }
            await network(tester, () async => emit(false, 3));
            expect(indicator, findsNothing);
            await network(tester, () async => emit(true, 2));
            expect(indicator, findsNothing);
            await network(tester, () async => emit(true, 4));
            expect(indicator, findsOneWidget);
            await tester.pump(const Duration(seconds: 8));
            expect(indicator, findsNothing);
            if (!admin) {
              final input = tester
                  .widget<ExtendedTextField>(find.byType(ExtendedTextField))
                  .controller!;
              input.text = '用户正在编辑';
              await tester.pump();
              expect(api.userPresence.last, true);
              input.clear();
              await tester.pump();
              expect(api.userPresence.last, false);
            }
            await network(tester, () async => emit(true, 5));
            expect(indicator, findsOneWidget);
            await network(
              tester,
              () async => peers.single.add(
                jsonEncode({
                  'type': admin ? 'takeover_user_message' : 'reply',
                  'data': {
                    'takeover_id': 'case',
                    'conversation_id': 'conv',
                    'text': '已发送的消息',
                    'message_id': 'peer-message',
                    'assistant_message_id': 'peer-message',
                    'reply_index': 0,
                  },
                }),
              ),
            );
            await flow.drain(tester);
            expect(indicator, findsNothing);
            await network(tester, () async => emit(true, 6));
            expect(indicator, findsOneWidget);
            if (!admin) {
              // Ending human presence must not cancel ordinary agent feedback.
              await network(
                tester,
                () async => peers.single.add(
                  jsonEncode({
                    'type': 'processing',
                    'data': {'message_id': 'incoming', 'ui_delay_seconds': 0},
                  }),
                ),
              );
              await network(tester, () async => emit(false, 7));
              await tester.pump(const Duration(seconds: 8));
              expect(indicator, findsOneWidget);
              await network(
                tester,
                () async => peers.single.add(
                  jsonEncode({'type': 'done', 'data': <String, dynamic>{}}),
                ),
              );
              expect(indicator, findsNothing);
              await network(tester, () async => emit(true, 8));
              expect(indicator, findsOneWidget);
            }
            await network(tester, () async {
              await peers.single.close(1001, 'synthetic disconnect');
            });
            expect(indicator, findsNothing);
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox());
            if (!admin) MusicPlaybackController.instance.dispose();
            TakeoverUnreadController.instance.clear();
            await network(tester, TakeoverInbox.instance.stop);
            await tester.runAsync(() async {
              for (final peer in peers) {
                unawaited(peer.close());
              }
              await requests!.cancel();
              await server.close(force: true);
            });
          }
        }, createHttpClient: RealHttp().createHttpClient);
      },
    );
  }
}
