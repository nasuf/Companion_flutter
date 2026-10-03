import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:companion_flutter/chat_socket.dart';
import 'package:companion_flutter/companion_api.dart';
import 'package:flutter_test/flutter_test.dart';

class LocalChatServer {
  LocalChatServer(this.server);
  final HttpServer server;
  final peers = <WebSocket>[];
  final protocols = <String>[];
  final authorizations = <String?>[];
  final requestUris = <Uri>[];
  int ticketRequests = 0;
  int ticketStatus = 200;
  String detail = 'Not Found';
  late final StreamSubscription<HttpRequest> subscription;
  String get baseUrl => 'http://127.0.0.1:${server.port}';

  static Future<LocalChatServer> start() async {
    final result = LocalChatServer(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );
    result.subscription = result.server.listen((request) async {
      result.requestUris.add(request.uri);
      if (request.uri.path.endsWith('/ws-ticket')) {
        result.ticketRequests++;
        result.authorizations.add(request.headers.value('authorization'));
        request.response.statusCode = result.ticketStatus;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(
            result.ticketStatus == 200
                ? {
                    'ticket': (result.ticketRequests == 1 ? 'a' : 'b') * 43,
                    'protocol': 'companion.chat.v1',
                  }
                : {'detail': result.detail},
          ),
        );
        await request.response.close();
      } else {
        result.protocols.add(
          request.headers.value('sec-websocket-protocol') ?? '',
        );
        final peer = await WebSocketTransformer.upgrade(
          request,
          protocolSelector: (offered) => offered.contains('companion.chat.v1')
              ? 'companion.chat.v1'
              : null,
        );
        result.peers.add(peer);
        peer.listen((frame) {
          final value = jsonDecode(frame as String) as Map<String, dynamic>;
          if (value['type'] == 'ping') {
            peer.add(jsonEncode({'type': 'pong', 'data': {}}));
          }
          if (value['type'] == 'message') {
            peer.add(
              jsonEncode({
                'type': 'ack',
                'data': {'client_id': value['data']['client_id']},
              }),
            );
          }
        });
      }
    });
    return result;
  }

  Future<void> close() async {
    for (final peer in peers) {
      await peer.close();
    }
    await subscription.cancel();
    await server.close(force: true);
  }
}

void main() {
  late LocalChatServer server;
  ChatSocket? socket;
  setUp(() async {
    server = await LocalChatServer.start();
  });
  tearDown(() async {
    await socket?.close();
    socket = null;
    await server.close();
  });

  ChatSocket create({Future<String> Function()? provider}) {
    final api = CompanionApi(baseUrl: server.baseUrl)
      ..authToken = 'synthetic-jwt';
    return socket = ChatSocket(
      baseUrl: server.baseUrl,
      conversationId: 'conv',
      ticketProvider: provider ?? () => api.getWebSocketTicket('conv'),
    );
  }

  test(
    'real ticket HTTP and WebSocket keep token out of URL and preserve messages',
    () async {
      final chat = create();
      final opened = chat.states.firstWhere(
        (s) => s.status == ChatSocketStatus.open,
      );
      await chat.connect();
      await opened.timeout(const Duration(seconds: 5));
      expect(server.authorizations, ['Bearer synthetic-jwt']);
      expect(server.protocols.single, contains('companion.ticket.${'a' * 43}'));
      expect(
        server.requestUris.every(
          (uri) =>
              !uri.toString().contains('synthetic-jwt') &&
              !uri.toString().contains('a' * 43),
        ),
        true,
      );
      final ack = chat.events.firstWhere((event) => event.type == 'ack');
      expect(chat.sendMessage('hello', 'client-1'), true);
      expect(
        (await ack.timeout(const Duration(seconds: 5))).data['client_id'],
        'client-1',
      );
    },
  );

  test('concurrent connects request only one ticket', () async {
    final pending = Completer<String>();
    int count = 0;
    final chat = create(
      provider: () {
        count++;
        return pending.future;
      },
    );
    final connection = chat.connect();
    await chat.connect();
    expect(count, 1);
    pending.complete('a' * 43);
    await connection;
    expect(server.peers.length, 1);
  });

  test('disposed connection ignores late ticket', () async {
    final pending = Completer<String>();
    final chat = create(provider: () => pending.future);
    final connection = chat.connect();
    await chat.close();
    pending.complete('a' * 43);
    await connection;
    expect(server.peers, isEmpty);
    socket = null; // Already closed.
  });

  test('reconnect obtains a fresh ticket after server restart', () async {
    final chat = create();
    await chat.connect();
    final reopened = chat.states.firstWhere(
      (s) => s.status == ChatSocketStatus.open,
    );
    await server.peers.first.close(1001, 'restart');
    await reopened.timeout(const Duration(seconds: 5));
    expect(server.ticketRequests, 2);
    expect(server.protocols.last, contains('companion.ticket.${'b' * 43}'));
    expect(chat.isOpen, true);
  });

  for (final status in [401, 403, 410]) {
    test('$status cannot downgrade to legacy connection', () async {
      server.ticketStatus = status;
      final chat = create();
      final error = chat.states.firstWhere(
        (state) => state.status == ChatSocketStatus.error,
      );
      await chat.connect();
      expect(server.peers, isEmpty);
      expect((await error).code, status);
      expect(server.ticketRequests, 1);
    });
  }

  test('route-missing 404 cannot open an anonymous connection', () async {
    server.ticketStatus = 404;
    server.detail = 'Not Found';
    final chat = create();
    await chat.connect();
    expect(chat.isOpen, false);
    expect(server.peers, isEmpty);
  });

  test('resource 404 cannot enable anonymous connection', () async {
    server.ticketStatus = 404;
    server.detail = 'Conversation not found';
    final chat = create();
    await chat.connect();
    expect(server.peers, isEmpty);
  });

  test(
    'invalid ticket data and denied provider cannot open connection',
    () async {
      final chat = create(provider: () async => 'bad');
      await chat.connect();
      expect(server.peers, isEmpty);
    },
  );
}
