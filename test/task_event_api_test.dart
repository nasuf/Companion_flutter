import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:companion_flutter/companion_api.dart';

void main() {
  test(
    'all-event recovery has a reply-only rolling fallback; controls keep scope and exact revision',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final paths = <String>[];
      final bodies = <Map<String, dynamic>>[];
      final subscription = server.listen((request) async {
        paths.add(request.uri.toString());
        expect(request.headers.value('authorization'), 'Bearer synthetic');
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path.endsWith('/events')) {
          request.response.statusCode = 404;
          request.response.write(jsonEncode({'detail': 'missing'}));
        } else if (request.uri.path.endsWith('/reply-events')) {
          request.response.write(
            jsonEncode({'events': [], 'next_sequence': 12, 'has_more': false}),
          );
        } else {
          if (request.uri.path.endsWith('/resume')) {
            bodies.add(
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>,
            );
          }
          request.response.write(jsonEncode({'status': 'queued'}));
        }
        await request.response.close();
      });
      final api = CompanionApi(baseUrl: 'http://127.0.0.1:${server.port}')
        ..authToken = 'synthetic';
      try {
        expect((await api.loadReplyEvents('conv', 10)).nextSequence, 12);
        await api.resumeTask('run', 'pending', 2, {'approved': true});
        await api.cancelTask('run');
        expect(paths, [
          '/conversations/conv/events?after_sequence=10',
          '/conversations/conv/reply-events?after_sequence=10',
          '/agent-runs/run/resume',
          '/agent-runs/run/cancel',
        ]);
        expect(bodies, [
          {
            'pending_action_id': 'pending',
            'revision': 2,
            'response': {'approved': true},
          },
        ]);
      } finally {
        await subscription.cancel();
        await server.close(force: true);
      }
    },
  );

  test('forbidden event recovery never tries the legacy endpoint', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var calls = 0;
    final subscription = server.listen((request) async {
      calls++;
      request.response.statusCode = 403;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'detail': 'forbidden'}));
      await request.response.close();
    });
    try {
      final api = CompanionApi(baseUrl: 'http://127.0.0.1:${server.port}');
      await expectLater(
        api.loadReplyEvents('conv', null),
        throwsA(isA<ApiException>()),
      );
      expect(calls, 1);
    } finally {
      await subscription.cancel();
      await server.close(force: true);
    }
  });
}
