import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:companion_flutter/chat_socket.dart';
import 'package:companion_flutter/models.dart';

void main() {
  test(
    'truncated active waits trigger a bounded event drain from zero',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final connections = <WebSocket>[];
      final subscription = server.listen((request) async {
        connections.add(
          await WebSocketTransformer.upgrade(
            request,
            protocolSelector: (offered) => offered.contains('companion.chat.v1')
                ? 'companion.chat.v1'
                : null,
          ),
        );
      });
      final cursors = <int?>[];
      final drained = Completer<void>();
      final socket = ChatSocket(
        baseUrl: 'http://127.0.0.1:${server.port}',
        conversationId: 'conv',
        ticketProvider: () async => 'a' * 43,
        replyEventProvider: (cursor) async {
          cursors.add(cursor);
          if (cursors.length == 2) drained.complete();
          return ReplyEventPage(
            events: [],
            nextSequence: 900,
            hasMore: false,
            activeWaitsTruncated: cursors.length == 1,
          );
        },
      );
      try {
        await socket.connect();
        await drained.future.timeout(const Duration(seconds: 5));
        expect(cursors, [null, 0]);
      } finally {
        await socket.close();
        for (final connection in connections) {
          await connection.close();
        }
        await subscription.cancel();
        await server.close(force: true);
      }
    },
  );
  test(
    'a lost replay page is retried at the same cursor after reconnect and all missing pages are drained',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final connections = <WebSocket>[];
      final serverSubscription = server.listen((request) async {
        connections.add(
          await WebSocketTransformer.upgrade(
            request,
            protocolSelector: (offered) => offered.contains('companion.chat.v1')
                ? 'companion.chat.v1'
                : null,
          ),
        );
      });
      final cursors = <int?>[];
      final fault = Completer<void>();
      final receivedFirst = Completer<void>();
      final receivedAll = Completer<void>();
      final ids = <String>[];
      WsEnvelope reply(int id) => WsEnvelope(
        type: 'reply',
        data: {
          'message_id': 'm$id',
          'event_id': 'e$id',
          'text': 'same',
          'replayed': true,
        },
      );
      final socket = ChatSocket(
        baseUrl: 'http://127.0.0.1:${server.port}',
        conversationId: 'conv',
        ticketProvider: () async => 'a' * 43,
        replyEventProvider: (cursor) async {
          cursors.add(cursor);
          if (cursors.length == 1) {
            return ReplyEventPage(
              events: [reply(10)],
              nextSequence: 10,
              hasMore: false,
            );
          }
          if (cursors.length == 2) {
            fault.complete();
            throw TimeoutException('synthetic lost response');
          }
          if (cursor == 10) {
            return ReplyEventPage(
              events: [reply(11), reply(12)],
              nextSequence: 12,
              hasMore: true,
            );
          }
          return ReplyEventPage(
            events: [reply(13)],
            nextSequence: 13,
            hasMore: false,
          );
        },
      );
      final events = socket.events.listen((envelope) {
        ids.add(envelope.data['message_id'] as String);
        if (ids.length == 1) receivedFirst.complete();
        if (ids.length == 4) receivedAll.complete();
      });
      try {
        await socket.connect();
        await receivedFirst.future.timeout(const Duration(seconds: 5));
        connections.first.add(
          jsonEncode({'type': 'reply', 'data': reply(12).data}),
        );
        await fault.future.timeout(const Duration(seconds: 5));
        final reopened = socket.states.firstWhere(
          (s) => s.status == ChatSocketStatus.open,
        );
        await connections.first.close(1001, 'restart');
        await reopened.timeout(const Duration(seconds: 5));
        await receivedAll.future.timeout(const Duration(seconds: 5));
        expect(cursors, [null, 10, 10, 12]);
        expect(ids, ['m10', 'm12', 'm11', 'm13']);
      } finally {
        await events.cancel();
        await socket.close();
        for (final connection in connections) {
          await connection.close();
        }
        await serverSubscription.cancel();
        await server.close(force: true);
      }
    },
  );
  test(
    'replayed event ids are suppressed across reconnect while equal text in distinct events is retained',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final connections = <WebSocket>[];
      final serverSubscription = server.listen((request) async {
        connections.add(
          await WebSocketTransformer.upgrade(
            request,
            protocolSelector: (offered) => offered.contains('companion.chat.v1')
                ? 'companion.chat.v1'
                : null,
          ),
        );
      });
      final socket = ChatSocket(
        baseUrl: 'http://127.0.0.1:${server.port}',
        conversationId: 'conv',
        ticketProvider: () async => 'a' * 43,
      );
      final ids = <String?>[];
      final received = Completer<void>();
      final events = socket.events.listen((envelope) {
        ids.add(envelope.data['event_id'] as String?);
        if (ids.length == 4) received.complete();
      });
      void send(WebSocket connection, String? id) => connection.add(
        jsonEncode({
          'type': 'reply',
          'data': {'text': '同一句', if (id != null) 'event_id': id},
        }),
      );
      try {
        await socket.connect();
        send(connections.first, 'e1');
        final reopened = socket.states.firstWhere(
          (s) => s.status == ChatSocketStatus.open,
        );
        await connections.first.close(1001, 'restart');
        await reopened.timeout(const Duration(seconds: 5));
        send(connections.last, 'e1');
        send(connections.last, 'e2');
        send(connections.last, null);
        send(connections.last, null);
        await received.future.timeout(const Duration(seconds: 5));
        expect(ids, ['e1', 'e2', null, null]);
      } finally {
        await events.cancel();
        await socket.close();
        for (final connection in connections) {
          await connection.close();
        }
        await serverSubscription.cancel();
        await server.close(force: true);
      }
    },
  );
  test(
    'duplicate connect shares ticket and reconnect obtains a new one',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final tickets = <String?>[];
      final connections = <WebSocket>[];
      final subscription = server.listen((request) async {
        expect(request.uri.queryParameters.containsKey('ticket'), isFalse);
        final offered = request.headers
            .value('sec-websocket-protocol')!
            .split(',')
            .map((v) => v.trim());
        tickets.add(
          offered
              .firstWhere((v) => v.startsWith('companion.ticket.'))
              .substring('companion.ticket.'.length),
        );
        connections.add(
          await WebSocketTransformer.upgrade(
            request,
            protocolSelector: (offered) => offered.contains('companion.chat.v1')
                ? 'companion.chat.v1'
                : null,
          ),
        );
      });
      var requested = 0;
      final gate = Completer<String>();
      final socket = ChatSocket(
        baseUrl: 'http://127.0.0.1:${server.port}',
        conversationId: 'conv',
        ticketProvider: () {
          requested += 1;
          return requested == 1 ? gate.future : Future.value('b' * 43);
        },
      );
      final first = socket.connect();
      await socket.connect();
      expect(requested, 1);
      gate.complete('a' * 43);
      await first;
      expect(tickets, ['a' * 43]);
      final reopened = socket.states.firstWhere(
        (s) => s.status == ChatSocketStatus.open,
      );
      await connections.first.close(1001, 'restart');
      await reopened.timeout(const Duration(seconds: 5));
      expect(requested, 2);
      expect(tickets, ['a' * 43, 'b' * 43]);
      await socket.close();
      for (final connection in connections) {
        await connection.close();
      }
      await subscription.cancel();
      await server.close(force: true);
    },
  );

  test(
    'dispose during ticket request does not open a connection or emit after close',
    () async {
      final gate = Completer<String>();
      final socket = ChatSocket(
        baseUrl: 'http://127.0.0.1:59999',
        conversationId: 'conv',
        ticketProvider: () => gate.future,
      );
      final connecting = socket.connect();
      await socket.close();
      gate.complete('late');
      await connecting;
      expect(socket.isOpen, isFalse);
    },
  );
  test(
    'a nonadvancing replay cursor stops instead of draining forever',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final peers = <WebSocket>[];
      final subscription = server.listen((request) async {
        peers.add(
          await WebSocketTransformer.upgrade(
            request,
            protocolSelector: (_) => 'companion.chat.v1',
          ),
        );
      });
      var calls = 0;
      final visited = Completer<void>();
      final socket = ChatSocket(
        baseUrl: 'http://127.0.0.1:${server.port}',
        conversationId: 'conv',
        ticketProvider: () async => 'a' * 43,
        replyEventProvider: (cursor) async {
          calls++;
          visited.complete();
          return const ReplyEventPage(
            events: [
              WsEnvelope(type: 'reply', data: {'event_id': 'bad-page'}),
            ],
            nextSequence: 0,
            hasMore: true,
          );
        },
      );
      try {
        await socket.connect();
        await visited.future.timeout(const Duration(seconds: 5));
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(calls, 1);
        expect(socket.isOpen, isTrue);
      } finally {
        await socket.close();
        for (final peer in peers) {
          await peer.close();
        }
        await subscription.cancel();
        await server.close(force: true);
      }
    },
  );
}
