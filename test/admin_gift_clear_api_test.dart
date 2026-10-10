import 'dart:convert';
import 'dart:io';
import 'package:companion_flutter/companion_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'gift reset uses owner endpoint and requires valid actual counts',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var mode = 'success';
      final subscription = server.listen((request) async {
        expect(request.method, 'DELETE');
        expect(request.uri.toString(), '/offline/admin/gifts');
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer admin-token',
        );
        await request.drain<void>();
        request.response.headers.contentType = ContentType.json;
        if (mode == 'failure') {
          request.response.statusCode = 503;
          request.response.write(jsonEncode({'detail': 'unavailable'}));
        } else {
          request.response.write(
            jsonEncode(
              mode == 'malformed'
                  ? {}
                  : {
                      'deleted_gifts': 3,
                      'deleted_tracking_events': 8,
                      'deleted_messages': 5,
                      'reset_trigger_states': 2,
                    },
            ),
          );
        }
        await request.response.close();
      });
      try {
        final api = CompanionApi(baseUrl: 'http://127.0.0.1:${server.port}')
          ..authToken = 'admin-token';
        final result = await api.clearOfflineGiftsForCurrentUser();
        expect(result.deletedGifts, 3);
        expect(result.deletedTrackingEvents, 8);
        expect(result.deletedMessages, 5);
        expect(result.resetTriggerStates, 2);
        mode = 'malformed';
        await expectLater(
          api.clearOfflineGiftsForCurrentUser(),
          throwsA(isA<TypeError>()),
        );
        mode = 'failure';
        await expectLater(
          api.clearOfflineGiftsForCurrentUser(),
          throwsA(anything),
        );
      } finally {
        await subscription.cancel();
        await server.close(force: true);
      }
    },
  );
}
