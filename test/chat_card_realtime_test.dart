import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:companion_flutter/src/widgets/chat/chat_timeline_timestamp.dart';
import 'package:flutter/material.dart';
import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'takeover_flow_test.dart' as flow;
import 'takeover_typing_flow_test.dart' as typing;

class _CardApi extends flow.FakeTakeoverApi {
  _CardApi({required super.baseUrl}) {
    scriptedHistory = [];
  }

  int historyLoads = 0;
  int replayRequests = 0;
  List<ChatMessage>? olderHistory;
  final historyOffsets = <int>[];

  @override
  Future<String> getWebSocketTicket(String id) async => 'a' * 43;

  @override
  Future<ReplyEventPage> loadReplyEvents(String id, int? afterSequence) async {
    replayRequests++;
    // Exercise the currently deployed legacy socket/history contract, without
    // assuming that the gated SQL reply-event API is enabled.
    throw const ApiException(404, 'reply events not enabled');
  }

  @override
  Future<List<ChatMessage>> loadMessages(
    String id, {
    int limit = 100,
    int offset = 0,
  }) async {
    historyLoads++;
    historyOffsets.add(offset);
    if (offset > 0 && olderHistory != null) return olderHistory!;
    return super.loadMessages(id, limit: limit, offset: offset);
  }
}

Map<String, dynamic> _card(String title, String snapshot) => {
  'type': 'external_link',
  'title': title,
  'body': title,
  'payload': {
    'link_id': 'shared-url-cache',
    'snapshot_id': snapshot,
    'platform': '链接',
    'page_title': title,
    'final_url': 'https://example.com/$snapshot',
    'source_url': 'https://example.com/shared',
  },
};

ChatMessage _history(String id, Map<String, dynamic> card, DateTime at) =>
    ChatMessage.fromJson({
      'id': id,
      'conversation_id': 'conv',
      'role': 'assistant',
      'content': '',
      'created_at': at.toIso8601String(),
      'metadata': {'component_card': card},
    });

Future<void> _withChat(
  WidgetTester tester,
  Future<void> Function(_CardApi api, List<WebSocket> peers) body, {
  List<ChatMessage> initialHistory = const [],
  Brightness? brightness,
  double textScale = 1,
}) async {
  await HttpOverrides.runZoned(() async {
    final server = await tester.runAsync(
      () => HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );
    final peers = <WebSocket>[];
    final requests = await tester.runAsync(
      () async => server!.listen((request) async {
        if (request.uri.path != '/ws/conv') {
          request.response.statusCode = 404;
          await request.response.close();
          return;
        }
        peers.add(
          await WebSocketTransformer.upgrade(
            request,
            protocolSelector: (protocols) =>
                protocols.contains('companion.chat.v1')
                ? 'companion.chat.v1'
                : null,
          ),
        );
      }),
    );
    final api = _CardApi(baseUrl: 'http://127.0.0.1:${server!.port}')
      ..scriptedHistory = initialHistory;
    // The app-wide player outlives ChatPage. Start its timer outside this test's
    // FakeAsync zone and dispose it once after all page fixtures are finished.
    await tester.runAsync(() async {
      MusicPlaybackController.instance.configureQuota(api);
    });
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.reset);
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: brightness == null ? null : AppTheme.materialTheme(brightness),
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
      for (var i = 0; peers.isEmpty && i < 100; i++) {
        await typing.network(tester, () async {});
      }
      expect(peers, hasLength(1));
      // Accepting the server socket precedes the client's on-open/replay
      // callback. Wait for that readiness signal, not only the socket accept,
      // so cold/parallel test runs cannot race the fixture's final assertion.
      for (var i = 0; api.replayRequests == 0 && i < 100; i++) {
        await typing.network(tester, () async {});
      }
      expect(api.replayRequests, 1);
      await flow.drain(tester);
      await body(api, peers);
      expect(api.replayRequests, 1);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        for (final peer in peers) {
          unawaited(peer.close());
        }
      });
      await typing.network(tester, () async {});
      await tester.runAsync(() async {
        await requests!.cancel();
        await server.close(force: true);
      });
    }
  }, createHttpClient: typing.RealHttp().createHttpClient);
}

Future<void> _emit(
  WidgetTester tester,
  WebSocket peer,
  String type,
  Map<String, dynamic> payload,
) async {
  await typing.network(
    tester,
    () async => peer.add(jsonEncode({'type': type, 'data': payload})),
  );
  await flow.drain(tester);
}

Future<void> _reconnect(
  WidgetTester tester,
  _CardApi api,
  List<WebSocket> peers,
) async {
  final count = peers.length;
  final loads = api.historyLoads;
  await typing.network(
    tester,
    () async => peers.last.close(1001, 'local reconnect fixture'),
  );
  await tester.pump(const Duration(seconds: 2));
  for (var i = 0; peers.length == count && i < 100; i++) {
    await typing.network(tester, () async {});
  }
  expect(peers.length, count + 1);
  await flow.drain(tester);
  expect(api.historyLoads, greaterThan(loads));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDownAll(() => MusicPlaybackController.instance.dispose());
  final launched = <String>[];
  setUp(() {
    launched.clear();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
      'com.llfbandit.record/messages',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (_) async => null,
      );
    }
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async {
        final id = (call.arguments as Map?)?['playerId'];
        if (id != null) {
          messenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/$id'),
            (_) async => null,
          );
        }
        return null;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async {
        if (call.method == 'launch') {
          launched.add((call.arguments as Map)['url'] as String);
        }
        return true;
      },
    );
  });

  ChatMessage plain(String id, int minute) => ChatMessage(
    id: id,
    conversationId: 'conv',
    role: 'assistant',
    content: id,
    createdAt: DateTime.utc(2026, 10, 19, 12, minute),
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'timestamps group adjacent messages and stay centered: $brightness',
      (tester) async {
        final base = DateTime(2026, 10, 19, 10, 25);
        ChatMessage message(String id, int seconds, String role) => ChatMessage(
          id: id,
          conversationId: 'conv',
          role: role,
          content: id,
          createdAt: base.add(Duration(seconds: seconds)),
        );
        final history = [
          message('time-a', 0, 'user'),
          message('time-b', 60, 'assistant'),
          message('time-c', 120, 'user'),
        ];
        await _withChat(
          tester,
          (api, peers) async {
            expect(find.byType(ChatTimelineTimestamp), findsOneWidget);
            final label = find.byKey(const ValueKey('chat-time-time-a'));
            final text = find.descendant(
              of: label,
              matching: find.byType(Text),
            );
            expect(tester.getCenter(text).dx, closeTo(195, 0.1));
            final body = find.text('time-a');
            expect(
              tester.getBottomLeft(text).dy,
              lessThan(tester.getTopLeft(body).dy),
            );
            for (final (id, seconds) in [('time-d', 419), ('time-e', 719)]) {
              await _emit(tester, peers.last, 'reply', {
                'message_id': id,
                'text': id,
                'created_at': base
                    .add(Duration(seconds: seconds))
                    .toUtc()
                    .toIso8601String(),
              });
            }
            // Four messages over almost seven minutes remain one continuous group;
            // exactly five minutes of silence introduces the second centered label.
            expect(find.byType(ChatTimelineTimestamp), findsNWidgets(2));
            expect(
              find.byKey(const ValueKey('chat-time-time-d')),
              findsNothing,
            );
            expect(
              find.byKey(const ValueKey('chat-time-time-e')),
              findsOneWidget,
            );
            for (final id in ['time-b', 'time-c', 'time-d']) {
              final row = find.byKey(ValueKey('chat-message-$id'));
              expect(
                find.descendant(
                  of: row,
                  matching: find.byWidgetPredicate(
                    (w) =>
                        w is Text &&
                        RegExp(r'\d{2}:\d{2}').hasMatch(w.data ?? ''),
                  ),
                ),
                findsNothing,
              );
            }
          },
          initialHistory: history.reversed.toList(),
          brightness: brightness,
        );
      },
    );
  }

  testWidgets('older pagination removes the artificial page-edge timestamp', (
    tester,
  ) async {
    final base = DateTime(2026, 10, 19, 10);
    ChatMessage message(int index) => ChatMessage(
      id: 'paged-$index',
      conversationId: 'conv',
      role: 'assistant',
      content: 'paged-$index',
      createdAt: base.add(Duration(seconds: index * 20)),
    );
    await _withChat(tester, (api, peers) async {
      api.olderHistory = [message(-1)];
      final scrollable = find
          .descendant(
            of: find.byType(ChatPage),
            matching: find.byType(Scrollable),
          )
          .first;
      final position = tester.state<ScrollableState>(scrollable).position;
      position.jumpTo(position.maxScrollExtent);
      await flow.drain(tester);
      expect(api.historyOffsets, contains(100));
      expect(find.byKey(const ValueKey('chat-time-paged-0')), findsNothing);
      expect(find.byKey(const ValueKey('chat-time-paged--1')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('chat-message-paged-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('chat-message-paged--1')),
        findsOneWidget,
      );
    }, initialHistory: [for (var i = 99; i >= 0; i--) message(i)]);
  });

  testWidgets(
    'live reply and local send push existing rows over multiple frames',
    (tester) async {
      await _withChat(tester, (api, peers) async {
        final old = find.byKey(const ValueKey('chat-message-motion-history'));
        final before = tester.getTopLeft(old).dy;
        await typing.network(
          tester,
          () async => peers.last.add(
            jsonEncode({
              'type': 'reply',
              'data': {
                'text': '平滑的新回复',
                'message_id': 'motion-reply',
                'reply_index': 0,
              },
            }),
          ),
        );
        final initial = tester.getTopLeft(old).dy;
        expect(initial, closeTo(before, 0.1));
        await tester.pump(const Duration(milliseconds: 64));
        final midway = tester.getTopLeft(old).dy;
        expect(midway, lessThan(initial));
        await flow.drain(tester);
        final after = tester.getTopLeft(old).dy;
        expect(after, lessThan(midway));
        // Replaying the same reply must not replay its animation.
        await _emit(tester, peers.last, 'reply', {
          'text': '平滑的新回复',
          'message_id': 'motion-reply',
          'reply_index': 0,
        });
        expect(tester.getTopLeft(old).dy, closeTo(after, 0.1));

        final sentFrames = <Map<String, dynamic>>[];
        final sentSub = peers.last.listen((raw) {
          final frame = jsonDecode(raw as String) as Map<String, dynamic>;
          if (frame['type'] == 'message') sentFrames.add(frame);
        });
        final input = tester.widget<ExtendedTextField>(
          find.byType(ExtendedTextField),
        );
        input.controller!.text = '用户发送也平滑';
        await flow.drain(tester);
        final beforeSend = tester.getTopLeft(old).dy;
        await tester.tap(find.text('发送'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 64));
        final duringSend = tester.getTopLeft(old).dy;
        expect(duringSend, lessThan(beforeSend));
        await typing.network(tester, () async {});
        expect(sentFrames, hasLength(1));
        final clientId =
            (sentFrames.single['data'] as Map)['client_id'] as String;
        final localRow = find.byKey(ValueKey('chat-message-$clientId'));
        final element = tester.element(localRow);
        await _emit(tester, peers.last, 'ack', {
          'client_id': clientId,
          'message_id': 'server-ack',
          'defer_ui': true,
        });
        expect(identical(tester.element(localRow), element), isTrue);
        expect(find.text('用户发送也平滑'), findsOneWidget);
        expect(tester.getTopLeft(old).dy, lessThan(duringSend));
        await tester.runAsync(sentSub.cancel);
      }, initialHistory: [plain('motion-history', 0)]);
    },
  );

  testWidgets(
    'rapid live replies stay continuous and replay batches do not animate',
    (tester) async {
      await _withChat(tester, (api, peers) async {
        final old = find.byKey(const ValueKey('chat-message-burst-history'));
        final before = tester.getTopLeft(old).dy;
        for (var index = 0; index < 3; index++) {
          await typing.network(
            tester,
            () async => peers.last.add(
              jsonEncode({
                'type': 'reply',
                'data': {
                  'text': '连续回复$index',
                  'message_id': 'burst-$index',
                  'reply_index': index,
                },
              }),
            ),
          );
          final atInsert = tester.getTopLeft(old).dy;
          await tester.pump(const Duration(milliseconds: 48));
          expect(tester.getTopLeft(old).dy, lessThan(atInsert));
        }
        await flow.drain(tester);
        final settled = tester.getTopLeft(old).dy;
        expect(settled, lessThan(before));
        await typing.network(
          tester,
          () async => peers.last.add(
            jsonEncode({
              'type': 'reply',
              'data': {
                'text': '断线补发',
                'message_id': 'replayed-batch',
                'replayed': true,
              },
            }),
          ),
        );
        final replayed = tester.getTopLeft(old).dy;
        expect(replayed, lessThan(settled));
        await tester.pump(const Duration(milliseconds: 64));
        expect(tester.getTopLeft(old).dy, closeTo(replayed, 0.1));
      }, initialHistory: [plain('burst-history', 0)]);
    },
  );

  testWidgets(
    'new remote messages preserve a stationary history reading anchor',
    (tester) async {
      await _withChat(tester, (api, peers) async {
        final scrollable = find
            .descendant(
              of: find.byType(ChatPage),
              matching: find.byType(Scrollable),
            )
            .first;
        final position = tester.state<ScrollableState>(scrollable).position;
        position.jumpTo(600);
        await flow.drain(tester);
        final visible = <Finder>[];
        for (var i = 0; i < 60; i++) {
          final row = find.byKey(ValueKey('chat-message-history-$i'));
          if (row.evaluate().isNotEmpty) {
            final y = tester.getTopLeft(row).dy;
            if (y > 150 && y < 900) visible.add(row);
          }
        }
        expect(visible, isNotEmpty);
        final anchor = visible.first;
        final before = tester.getTopLeft(anchor).dy;
        await _emit(tester, peers.last, 'reply', {
          'text': '阅读旧记录时收到的一条新消息',
          'message_id': 'while-reading',
          'reply_index': 0,
        });
        expect(position.pixels, closeTo(600, 0.1));
        expect(tester.getTopLeft(anchor).dy, closeTo(before, 0.5));
        await _emit(tester, peers.last, 'reply', {
          'text': List.filled(150, '一条很长的新回复，查看历史时应保持阅读位置。').join('\n'),
          'message_id': 'long-while-reading',
          'reply_index': 1,
        });
        expect(tester.getTopLeft(anchor).dy, closeTo(before, 0.5));
        final drag = await tester.startGesture(const Offset(220, 400));
        await drag.moveBy(const Offset(0, 40));
        await tester.pump();
        final duringDrag = tester.getTopLeft(anchor).dy;
        await _emit(tester, peers.last, 'reply', {
          'text': '手指滑动时也不能抢走位置',
          'message_id': 'during-drag',
          'reply_index': 2,
        });
        expect(tester.getTopLeft(anchor).dy, closeTo(duringDrag, 0.5));
        await drag.up();
        await flow.drain(tester);
        // Returning to the min edge reveals buffered messages without a
        // delayed entrance; the actual transcript has contained them all along.
        position.jumpTo(0);
        await flow.drain(tester);
        expect(
          find.byKey(const ValueKey('chat-message-during-drag')),
          findsOneWidget,
        );
        expect(position.pixels, closeTo(position.minScrollExtent, 0.1));
      }, initialHistory: [for (var i = 59; i >= 0; i--) plain('history-$i', i)]);
    },
  );

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.8]) {
      testWidgets(
        'typing becomes the reply in the same row: $brightness / $scale',
        (tester) async {
          AppColors.use(brightness);
          addTearDown(() => AppColors.use(Brightness.light));
          await _withChat(
            tester,
            (api, peers) async {
              await _emit(tester, peers.last, 'takeover_typing', {
                'takeover_id': 'case',
                'conversation_id': 'conv',
                'active': true,
                'revision': 1,
              });
              final typingIndicator = find.byKey(
                const ValueKey('chat-peer-typing'),
              );
              expect(typingIndicator, findsOneWidget);
              final slot = find.byWidgetPredicate(
                (widget) =>
                    widget is RepaintBoundary &&
                    widget.key is ValueKey<String> &&
                    (widget.key as ValueKey<String>).value.startsWith(
                      'chat-message-peer-typing-slot-',
                    ),
              );
              final element = tester.element(slot);
              final avatar = find.descendant(
                of: slot,
                matching: find.byWidgetPredicate(
                  (w) => w.runtimeType.toString() == '_Avatar',
                ),
              );
              final avatarElement = tester.element(avatar);
              final before = tester.getTopLeft(avatar);
              Finder surface() => find.descendant(
                of: slot,
                matching: find.byWidgetPredicate(
                  (w) => w.runtimeType.toString() == '_MessageBubbleSurface',
                ),
              );
              BoxDecoration decoration() =>
                  tester
                          .widget<DecoratedBox>(
                            find
                                .descendant(
                                  of: surface(),
                                  matching: find.byType(DecoratedBox),
                                )
                                .first,
                          )
                          .decoration
                      as BoxDecoration;
              final style = decoration();
              final bubbleBefore = tester.getRect(surface());
              await typing.network(
                tester,
                () async => peers.last.add(
                  jsonEncode({
                    'type': 'reply',
                    'data': {
                      'text': '你好',
                      'message_id': 'replaces-typing',
                      'reply_index': 0,
                    },
                  }),
                ),
              );
              expect(
                find.byKey(const ValueKey('chat-peer-typing')),
                findsNothing,
              );
              expect(find.text('你好'), findsOneWidget);
              expect(identical(tester.element(slot), element), isTrue);
              expect(identical(tester.element(avatar), avatarElement), isTrue);
              expect(decoration(), style);
              expect(tester.getTopLeft(avatar), before);
              expect(tester.getRect(surface()).topLeft, bubbleBefore.topLeft);
              expect(
                tester.getRect(surface()).height,
                closeTo(bubbleBefore.height, 0.1),
              );
              for (var frame = 0; frame < 16; frame++) {
                await tester.pump(const Duration(milliseconds: 16));
                expect(tester.getTopLeft(avatar), before);
                expect(tester.getRect(surface()).topLeft, bubbleBefore.topLeft);
              }
              // A new typing cycle that ends without a reply removes its slot
              // immediately, with no collapsing bubble or stale dots left behind.
              await _emit(tester, peers.last, 'takeover_typing', {
                'takeover_id': 'case',
                'conversation_id': 'conv',
                'active': true,
                'revision': 2,
              });
              expect(
                find.byKey(const ValueKey('chat-peer-typing')),
                findsOneWidget,
              );
              await typing.network(
                tester,
                () async => peers.last.add(
                  jsonEncode({
                    'type': 'takeover_typing',
                    'data': {
                      'takeover_id': 'case',
                      'conversation_id': 'conv',
                      'active': false,
                      'revision': 3,
                    },
                  }),
                ),
              );
              expect(
                find.byKey(const ValueKey('chat-peer-typing')),
                findsNothing,
              );
            },
            brightness: brightness,
            textScale: scale,
          );
        },
      );
    }
  }

  testWidgets('typing is replaced once by the first of several long replies', (
    tester,
  ) async {
    await _withChat(tester, (api, peers) async {
      await _emit(tester, peers.last, 'takeover_typing', {
        'takeover_id': 'case',
        'conversation_id': 'conv',
        'active': true,
        'revision': 1,
      });
      final slot = find.byWidgetPredicate(
        (w) =>
            w is RepaintBoundary &&
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith(
              'chat-message-peer-typing-slot-',
            ),
      );
      final slotElement = tester.element(slot);
      final avatar = find.descendant(
        of: slot,
        matching: find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_Avatar',
        ),
      );
      final before = tester.getTopLeft(avatar).dy;
      final first = List.filled(5, '长回复也应该直接替换输入内容').join('，');
      await typing.network(tester, () async {
        for (var i = 0; i < 2; i++) {
          peers.last.add(
            jsonEncode({
              'type': 'reply',
              'data': {
                'text': i == 0 ? first : '紧接着的第二条',
                'message_id': 'replace-batch-$i',
                'reply_index': i,
              },
            }),
          );
        }
      });
      expect(find.byKey(const ValueKey('chat-peer-typing')), findsNothing);
      expect(identical(tester.element(slot), slotElement), isTrue);
      // A timestamp may be inserted above the slot after a long silence. The
      // bubble/avatar itself must still replace the typing row in place.
      expect(tester.getTopLeft(avatar).dy, closeTo(before, 0.1));
      expect(find.text(first), findsOneWidget);
      final firstFrame = tester.getTopLeft(avatar).dy;
      await tester.pump(const Duration(milliseconds: 64));
      expect(tester.getTopLeft(avatar).dy, lessThan(firstFrame));
      await flow.drain(tester);
      expect(find.text('紧接着的第二条'), findsOneWidget);
      final settled = tester.getRect(slot);
      // The id alias stays on the same slot across a later duplicate/replay.
      await _emit(tester, peers.last, 'reply', {
        'text': first,
        'message_id': 'replace-batch-0',
        'reply_index': 0,
        'replayed': true,
      });
      expect(identical(tester.element(slot), slotElement), isTrue);
      expect(tester.getRect(slot), settled);
    }, initialHistory: [plain('before-typing', 0)]);
  });

  for (final summary in ['爱探店的话，可以了解这家常发广场里的花艺小店。', '']) {
    testWidgets(
      'activity chat card renders its verified summary: ${summary.isEmpty ? "legacy empty" : "present"}',
      (tester) async {
        final component = <String, dynamic>{
          'type': 'offline_activity',
          'title': '春树·花艺(常发广场店)',
          'subtitle': '待确定 · 春树·花艺(常发广场店)',
          'body': summary,
          'footer': '点击查看活动详情',
          'payload': {
            'activity_id': 'spring',
            'status': 'pending',
            'status_label': '待确定',
          },
        };
        await _withChat(
          tester,
          (api, peers) async {
            if (summary.isEmpty) {
              expect(
                find.byKey(const ValueKey('offline-activity-card-summary')),
                findsNothing,
              );
            } else {
              expect(find.text(summary), findsOneWidget);
              final text = tester.widget<Text>(
                find.byKey(const ValueKey('offline-activity-card-summary')),
              );
              expect(text.data, summary);
              expect(text.maxLines, 3);
              tester.view.physicalSize = const Size(320, 844);
              tester.platformDispatcher.textScaleFactorTestValue = 1.6;
              addTearDown(
                tester.platformDispatcher.clearTextScaleFactorTestValue,
              );
              await tester.pump();
              expect(tester.takeException(), isNull);
            }
          },
          initialHistory: [
            _history('activity', component, DateTime.utc(2026, 10, 19)),
          ],
        );
      },
    );
  }

  testWidgets('failed location retry preserves full card and client identity', (
    tester,
  ) async {
    await _withChat(tester, (api, peers) async {
      final frames = <Map<String, dynamic>>[];
      final subscription = peers.last.listen((raw) {
        final frame = jsonDecode(raw as String) as Map<String, dynamic>;
        if (frame['type'] == 'message') frames.add(frame);
      });
      final card = ChatComponentCard.fromJson({
        'type': 'location',
        'title': '重试位置',
        'subtitle': '合成街道',
        'payload': {'latitude': 32.2, 'longitude': 119.4, 'address': '合成街道'},
      });
      final dynamic state = tester.state(find.byType(ChatPage));
      state.sendComponentMessage('', card);
      await typing.network(tester, () async {});
      await flow.drain(tester);
      expect(frames, hasLength(1));
      final original = frames.single['data'] as Map<String, dynamic>;
      await _emit(tester, peers.last, 'error', {
        'client_id': original['client_id'],
        'message': '合成发送失败',
      });
      await flow.drain(tester);
      final retry = find.bySemanticsLabel('发送失败，点击重试');
      expect(retry, findsOneWidget);
      await tester.tap(retry);
      await typing.network(tester, () async {});
      await flow.drain(tester);
      expect(frames, hasLength(2));
      final retried = frames.last['data'] as Map<String, dynamic>;
      expect(retried['client_id'], original['client_id']);
      expect(retried['component_card'], original['component_card']);
      expect(retried['message'], '');
      expect(find.byKey(const Key('location-card')), findsOneWidget);
      await _emit(tester, peers.last, 'ack', {
        'client_id': original['client_id'],
        'message_id': 'location-accepted',
      });
      expect(find.bySemanticsLabel('发送失败，点击重试'), findsNothing);
      await tester.runAsync(subscription.cancel);
    });
  });

  for (final type in ['reply', 'proactive']) {
    testWidgets('$type card-only reply survives dedup and history reconnect', (
      tester,
    ) async {
      await _withChat(tester, (api, peers) async {
        final card = _card('推荐的原始链接标题', 'snapshot-one');
        final at = DateTime.now().toUtc();
        final payload = {
          'message_id': 'card-one',
          'created_at': at.toIso8601String(),
          // Both established spellings are accepted by ChatComponentCard.
          type == 'reply' ? 'component_card' : 'componentCard': card,
        };
        await _emit(tester, peers.last, type, payload);
        expect(find.text('推荐的原始链接标题'), findsOneWidget);
        await _emit(tester, peers.last, type, payload);
        expect(find.text('推荐的原始链接标题'), findsOneWidget);
        await tester.tap(find.text('推荐的原始链接标题'), warnIfMissed: false);
        await flow.drain(tester);
        expect(launched, ['https://example.com/snapshot-one']);

        api.scriptedHistory = [_history('card-one', card, at)];
        await _reconnect(tester, api, peers);
        expect(find.text('推荐的原始链接标题'), findsOneWidget);
        // A separate message sharing the same resource is still a new event.
        await _emit(tester, peers.last, type, {
          ...payload,
          'message_id': 'card-two',
        });
        expect(find.text('推荐的原始链接标题'), findsNWidgets(2));
        await _emit(tester, peers.last, 'reply', {
          'message_id': 'ordinary-text',
          'text': '原有文字回复继续显示',
        });
        expect(find.text('原有文字回复继续显示'), findsOneWidget);
      });
    });
  }

  testWidgets('card-only history renders on the initial page load', (
    tester,
  ) async {
    final card = _card('历史里的链接卡片', 'history-snapshot');
    await _withChat(
      tester,
      (api, peers) async {
        expect(find.text('历史里的链接卡片'), findsOneWidget);
        await _emit(tester, peers.last, 'reply', {
          'message_id': 'history-card',
          'component_card': card,
        });
        expect(find.text('历史里的链接卡片'), findsOneWidget);
      },
      initialHistory: [_history('history-card', card, DateTime.now().toUtc())],
    );
  });

  testWidgets('legacy ID-less cards reconcile by full body, not empty text', (
    tester,
  ) async {
    await _withChat(tester, (api, peers) async {
      final first = _card('同一标题的不同快照', 'snapshot-a');
      final second = _card('同一标题的不同快照', 'snapshot-b');
      final at = DateTime.now().toUtc();
      await _emit(tester, peers.last, 'proactive', {'component_card': first});
      await _emit(tester, peers.last, 'proactive', {'component_card': second});
      expect(find.text('同一标题的不同快照'), findsNWidgets(2));
      api.scriptedHistory = [_history('stored-a', first, at)];
      await _reconnect(tester, api, peers);
      expect(find.text('同一标题的不同快照'), findsNWidgets(2));

      final payload = second['payload'] as Map<String, dynamic>;
      final reordered = {
        ...second,
        'payload': Map<String, dynamic>.fromEntries(
          payload.entries.toList().reversed,
        ),
      };
      api.scriptedHistory = [
        _history('stored-b', reordered, at.add(const Duration(seconds: 1))),
        _history('stored-a', first, at),
      ];
      await _reconnect(tester, api, peers);
      expect(find.text('同一标题的不同快照'), findsNWidgets(2));
    });
  });

  testWidgets('attachment-only replies keep distinct media on history merge', (
    tester,
  ) async {
    await _withChat(tester, (api, peers) async {
      final at = DateTime.now().toUtc();
      final first = {
        'id': 'audio-one',
        'kind': 'audio',
        'mime': 'audio/mp4',
        'duration_seconds': 3,
        'url': '/chat/media/audio-one.m4a',
      };
      final second = {
        ...first,
        'id': 'audio-two',
        'duration_seconds': 4,
        'url': '/chat/media/audio-two.m4a',
      };
      for (final attachment in [first, second]) {
        await _emit(tester, peers.last, 'reply', {
          'attachments': [attachment],
        });
      }
      expect(find.text('3″'), findsOneWidget);
      expect(find.text('4″'), findsOneWidget);
      api.scriptedHistory = [
        ChatMessage.fromJson({
          'id': 'stored-audio-one',
          'conversation_id': 'conv',
          'role': 'assistant',
          'content': '',
          'created_at': at.toIso8601String(),
          'metadata': {
            'attachments': [
              {
                ...first,
                'url': '${api.baseUrl}/chat/media/audio-one.m4a',
                'transcription_status': 'ready',
              },
            ],
          },
        }),
      ];
      await _reconnect(tester, api, peers);
      expect(find.text('3″'), findsOneWidget);
      expect(find.text('4″'), findsOneWidget);
    });
  });
}
