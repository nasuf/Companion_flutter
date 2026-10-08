import 'dart:convert';
import 'dart:io';

import 'package:companion_flutter/companion_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'arrival sends the device fix time in UTC and preserves event fields',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      Map<String, dynamic>? body;
      final subscription = server.listen((request) async {
        expect(request.uri.path, '/offline/activities/event1/arrive');
        expect(request.headers.value('authorization'), 'Bearer synthetic');
        body =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'id': 'event1',
            'kind': 'event',
            'time_precision': 'date',
            'event_status': 'scheduled',
            'schedule_label': '2026/10/24—10/25',
            'image_urls': ['/offline/media/venue.jpg'],
            'reached': true,
          }),
        );
        await request.response.close();
      });
      try {
        final api = CompanionApi(baseUrl: 'http://127.0.0.1:${server.port}')
          ..authToken = 'synthetic';
        final fixTime = DateTime.parse('2026-10-24T10:30:00+08:00');
        final result = await api.arriveOfflineActivity(
          'event1',
          lat: 32.2,
          lng: 119.4,
          accuracyMeters: 12,
          observedAt: fixTime,
        );
        expect(body, {
          'lat': 32.2,
          'lng': 119.4,
          'accuracy_m': 12,
          'observed_at': '2026-10-24T02:30:00.000Z',
          'manual_confirmation': false,
        });
        expect(result.kind, 'event');
        expect(result.scheduleLabel, '2026/10/24—10/25');
        expect(
          result.imageUrls.single,
          'http://127.0.0.1:${server.port}/offline/media/venue.jpg',
        );
      } finally {
        await subscription.cancel();
        await server.close(force: true);
      }
    },
  );
}
