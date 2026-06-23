import 'package:flutter_test/flutter_test.dart';
import 'package:companion_flutter/offline_models.dart';

void main() {
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
          'created_at': '2026-06-21T11:00:00Z',
        },
        'created_at': '2026-06-21T10:00:00Z',
        'updated_at': '2026-06-21T10:00:00Z',
      },
      'pending': [],
      'completed': [],
    });

    expect(data.latest?.id, 'a1');
    expect(data.latest?.imageUrls, ['https://example.com/a.png']);
    expect(data.latest?.easterEggTask?['title'], '拍一张照片');
    expect(data.latest?.completionFeedback?.text, '今天很放松');
    expect(
      data.latest?.completionFeedback?.photoAttachments.single.url,
      '/offline/media/p1.jpg',
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
