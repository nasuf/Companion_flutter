import 'dart:convert';
import 'dart:io';

import 'package:companion_flutter/companion_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'activity reads use scoped GET endpoints and normalize media URLs',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final paths = <String>[];
      final subscription = server.listen((request) async {
        expect(request.method, 'GET');
        expect(
          request.headers.value('authorization'),
          'Bearer synthetic-admin',
        );
        paths.add(request.uri.path);
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'id': 'activity',
            'status': 'completed',
            'title': '活动详情',
            'image_urls': ['/offline/media/cover.jpg'],
            'cover_url': '/offline/media/cover.jpg',
            'gallery': ['/offline/media/photo.jpg'],
            'recommendation_message': '已有寄语',
          }),
        );
        await request.response.close();
      });
      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
      });
      final base = 'http://127.0.0.1:${server.port}';
      final api = CompanionApi(baseUrl: base)..authToken = 'synthetic-admin';
      final activity = await api.fetchTakeoverActivity('case', 'activity');
      final review = await api.fetchTakeoverActivityReview('case', 'activity');
      expect(paths, [
        '/admin-api/takeovers/case/activities/activity',
        '/admin-api/takeovers/case/activities/activity/review',
      ]);
      expect(activity.imageUrls, ['$base/offline/media/cover.jpg']);
      expect(activity.recommendationMessage, '已有寄语');
      expect(review.coverUrl, '$base/offline/media/cover.jpg');
      expect(review.imageUrls, ['$base/offline/media/cover.jpg']);
      expect(review.gallery, ['$base/offline/media/photo.jpg']);
    },
  );

  test('human reply retries keep the message identity', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <Map<String, dynamic>>[];
    final subscription = server.listen((request) async {
      expect(request.headers.value('authorization'), 'Bearer synthetic-admin');
      expect(request.uri.path, '/admin-api/takeovers/case/messages');
      final body =
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
      requests.add(body);
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'message_id': 'saved-message'}));
      await request.response.close();
    });
    addTearDown(() async {
      await subscription.cancel();
      await server.close(force: true);
    });
    final api = CompanionApi(baseUrl: 'http://127.0.0.1:${server.port}')
      ..authToken = 'synthetic-admin';
    for (var attempt = 0; attempt < 2; attempt++) {
      final id = await api.sendTakeoverMessage(
        'case',
        text: 'hello',
        clientId: 'stable-retry-id',
      );
      expect(id, 'saved-message');
    }
    expect(requests, hasLength(2));
    expect(requests[0], requests[1]);
    expect(requests[0]['client_id'], 'stable-retry-id');
    expect(requests[0].containsKey('attachments'), isFalse);
  });

  test(
    'takeover list preserves state and awaiting-agent claim availability',
    () {
      final pending = TakeoverListItem.fromJson({
        'id': 'case',
        'user_id': 'owner',
        'status': 'pending',
        'unread_count': 0,
        'read_state': 'read',
        'can_claim': false,
      });
      expect(pending.canClaim, isFalse);
      expect(pending.readState, 'read');
      final detail = TakeoverReview.fromJson({
        'id': 'case',
        'status': 'active',
        'can_claim': false,
        'owner_admin_id': 'admin',
        'user': {'id': 'owner'},
        'agent': {'name': 'Synthetic', 'conversation_id': 'conv'},
      });
      expect(detail.conversationId, 'conv');
      expect(detail.ownerAdminId, 'admin');
    },
  );
}
