import 'package:flutter_test/flutter_test.dart';
import 'package:companion_flutter/offline_models.dart';

void main() {
  test(
    'event facts survive media normalization and copy without fake times',
    () {
      final event = OfflineActivity.fromJson({
        'id': 'event1',
        'title': '秋日市集',
        'kind': 'event',
        'time_precision': 'date',
        'event_status': 'scheduled',
        'schedule_label': '2026/10/24—10/25 每日10:00—18:00',
        'starts_at': '2026-10-24T00:00:00+08:00',
        'ends_at': '2026-10-25T23:59:59+08:00',
        'place_lat': 32.2,
        'place_lng': 119.4,
        'coordinate_system': 'wgs84',
      });
      final normalized = event.copyWith(imageUrls: ['/photo.jpg']);
      expect(normalized.kind, 'event');
      expect(normalized.timePrecision, 'date');
      expect(normalized.eventStatus, 'scheduled');
      expect(normalized.placeLat, 32.2);
      expect(normalized.placeLng, 119.4);
      expect(normalized.coordinateSystem, 'wgs84');
      expect(normalized.scheduleLabel, '2026/10/24—10/25 每日10:00—18:00');
      expect(normalized.scheduleLabel, isNot(contains('00:00')));
      expect(OfflineActivity.fromJson({'id': 'legacy'}).kind, 'place');
    },
  );

  test(
    'review keeps original images separate from user gallery through copying',
    () {
      final review = OfflineActivityReview.fromJson({
        'id': 'a1',
        'title': '公园',
        'cover_url': '/cover.jpg',
        'image_urls': ['/one.jpg', '/two.jpg', '/three.jpg'],
        'gallery': ['/user.jpg'],
      });
      expect(review.imageUrls, ['/one.jpg', '/two.jpg', '/three.jpg']);
      expect(
        review.copyWith(coverUrl: '/other.jpg').imageUrls,
        review.imageUrls,
      );
      final normalized = review.copyWith(
        imageUrls: ['https://example.com/one.jpg'],
      );
      expect(normalized.imageUrls, ['https://example.com/one.jpg']);
      expect(normalized.gallery, ['/user.jpg']);
      expect(
        OfflineActivityReview.fromJson({'cover_url': '/legacy.jpg'}).imageUrls,
        isEmpty,
      );
    },
  );

  test('offline activity response parses nested fields', () {
    final data = OfflineActivities.fromJson({
      'latest': {
        'id': 'a1',
        'status': 'accepted',
        'title': '春日音乐野餐会',
        'summary': '轻松户外音乐',
        'description': '在公园里听音乐',
        'image_urls': ['https://example.com/a.png'],
        'easter_egg_task': {'title': '拍一张照片'},
        'search_sources': [
          {'title': 'source', 'url': 'https://example.com'},
        ],
        'completion_feedback': {
          'text': '今天很放松',
          'photo_attachments': [
            {
              'id': 'p1',
              'kind': 'image',
              'mime': 'image/jpeg',
              'size': 12,
              'url': '/offline/media/p1.jpg',
            },
          ],
          'audio_attachment': {
            'id': 'v1',
            'kind': 'audio',
            'mime': 'audio/mp4',
            'size': 18,
            'duration_seconds': 9,
            'url': '/offline/media/v1.m4a',
          },
          'created_at': '2026-06-21T11:00:00Z',
        },
        'created_at': '2026-06-21T10:00:00Z',
        'updated_at': '2026-06-21T10:00:00Z',
      },
      'pending': [],
      'ignored': [
        {
          'id': 'a2',
          'status': 'ignored',
          'title': '暂不考虑的活动',
          'summary': '',
          'description': '之后再说',
          'image_urls': [],
          'search_sources': [],
          'created_at': '2026-06-21T10:00:00Z',
          'updated_at': '2026-06-21T10:00:00Z',
        },
      ],
      'completed': [],
    });

    expect(data.latest?.id, 'a1');
    expect(data.latest?.imageUrls, ['https://example.com/a.png']);
    expect(data.latest?.easterEggTask?['title'], '拍一张照片');
    expect(data.latest?.completionFeedback?.text, '今天很放松');
    expect(data.ignored.single.status, 'ignored');
    expect(
      data.latest?.completionFeedback?.photoAttachments.single.url,
      '/offline/media/p1.jpg',
    );
    expect(data.latest?.completionFeedback?.audioAttachment?.kind, 'audio');
    expect(
      data.latest?.completionFeedback?.audioAttachment?.durationSeconds,
      9,
    );
  });

  test('gift home response parses address, shipping gift and tracking', () {
    final gifts = GiftsHome.fromJson({
      'address': {'id': 'addr1', 'display': '上海市 浦东新区 张江路***'},
      'shipping_gift': {
        'id': 'g1',
        'status': 'shipping',
        'trigger_type': 'scheduled',
        'gift_name': '手冲咖啡壶套装',
        'paid_amount_cents': 3900,
        'created_at': '2026-06-21T10:00:00Z',
        'updated_at': '2026-06-21T10:00:00Z',
      },
      'groups': [
        {
          'year': 2026,
          'gifts': [
            {
              'id': 'g2',
              'status': 'delivered',
              'trigger_type': 'scheduled',
              'gift_name': '绘本',
              'paid_amount_cents': 2500,
              'created_at': '2026-02-18T10:00:00Z',
              'updated_at': '2026-02-18T10:00:00Z',
            },
          ],
        },
      ],
    });

    expect(gifts.address?.hasAddress, isTrue);
    expect(gifts.shippingGift?.giftName, '手冲咖啡壶套装');
    expect(gifts.groups.single.gifts.single.id, 'g2');

    final tracking = GiftTracking.fromJson({
      'gift_id': 'g1',
      'events': [
        {
          'id': 'e1',
          'status': 'shipping',
          'title': '包裹正在运输中',
          'occurred_at': '2026-06-21T18:00:00Z',
        },
      ],
    });
    expect(tracking.events.single.title, '包裹正在运输中');
  });
}
