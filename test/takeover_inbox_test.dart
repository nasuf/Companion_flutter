import 'dart:convert';
import 'dart:io';

import 'package:companion_flutter/takeover_inbox.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'inbox reconnect announces reconciliation and ignores malformed frames',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final peers = <WebSocket>[];
      final inbox = TakeoverInbox.instance;
      final events = <String>[];
      final subscription = inbox.events.listen(
        (event) => events.add(event.type),
      );
      var tickets = 0;
      final requests = server.listen((request) async {
        expect(request.uri.path, '/ws/admin-inbox/admin');
        final socket = await WebSocketTransformer.upgrade(
          request,
          protocolSelector: (_) => 'companion.chat.v1',
        );
        peers.add(socket);
        socket.add('malformed frame');
        socket.add(
          jsonEncode({
            'type': 'takeover_user_message',
            'data': {'text': 'complete message'},
          }),
        );
      });
      addTearDown(() async {
        await inbox.stop();
        await subscription.cancel();
        for (final peer in peers) {
          await peer.close();
        }
        await requests.cancel();
        await server.close(force: true);
      });
      Future<void> until(bool Function() condition) async {
        final end = DateTime.now().add(const Duration(seconds: 8));
        while (!condition() && DateTime.now().isBefore(end)) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(condition(), isTrue);
      }

      inbox.start(
        baseUrl: 'http://127.0.0.1:${server.port}',
        adminId: 'admin',
        ticketProvider: () async => 'synthetic-${++tickets}',
      );
      await until(() => events.contains('takeover_user_message'));
      await peers.first.close(1001, 'synthetic disconnect');
      await until(
        () => events.where((event) => event == 'inbox_connected').length == 2,
      );
      expect(tickets, 2);
      expect(
        events.where((event) => event == 'takeover_user_message'),
        hasLength(2),
      );
    },
  );
}
