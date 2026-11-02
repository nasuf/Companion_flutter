import 'dart:io';

import 'package:companion_flutter/companion_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'connection dropped mid-body surfaces a friendly network error',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = server.listen((request) async {
        await request.drain<void>();
        // 声明的长度大于实际写出的字节后直接断开 socket, 复现弱网下
        // "Connection closed while receiving data"。
        final socket = await request.response.detachSocket(
          writeHeaders: false,
        );
        socket.write(
          'HTTP/1.1 200 OK\r\n'
          'Content-Type: application/json\r\n'
          'Content-Length: 1000\r\n\r\n'
          '[{"id":',
        );
        await socket.flush();
        socket.destroy();
      });
      try {
        final api = CompanionApi(baseUrl: 'http://127.0.0.1:${server.port}')
          ..authToken = 'token';
        await expectLater(
          api.loadMessages('conv-1', limit: 100),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', 0)
                .having((e) => e.message, 'message', '网络连接中断，请稍后重试'),
          ),
        );
      } finally {
        await subscription.cancel();
        await server.close(force: true);
      }
    },
  );
}
