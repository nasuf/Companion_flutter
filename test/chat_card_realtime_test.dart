import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:flutter/material.dart';
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
    addTearDown(tester.view.reset);
    try {
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
      for (var i = 0; peers.isEmpty && i < 100; i++) {
        await typing.network(tester, () async {});
      }
      expect(peers, hasLength(1));
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
