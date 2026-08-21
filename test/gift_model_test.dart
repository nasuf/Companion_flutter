import 'package:companion_flutter/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gift send result parses offering, card, and remaining inventory', () {
    final result = GiftSendResult.fromJson({
      'offering': {
        'id': 'off-1',
        'kind': 'gift',
        'ticket_amount': 25,
        'agent_value_yuan': 25,
        'status': 'sent',
        'agent_id': 'agent-1',
        'created_at': '2026-08-21T08:00:00Z',
        'product_kind': 'gift_1',
        'product_title': '美式咖啡',
        'product_subcategory': '饮品',
        'product_asset_key': '1',
      },
      'component_card': {
        'type': 'gift',
        'title': '美式咖啡',
        'subtitle': '',
        'body': '饮品',
        'footer': '点击查看',
        'accent': '#FF8A3D',
        'payload': {
          'offering_id': 'off-1',
          'kind': 'gift',
          'product_kind': 'gift_1',
          'product_title': '美式咖啡',
          'status': 'sent',
          'status_label': '待接收',
        },
      },
      'wallet': {
        'ticket_balance': 10,
        'point_balance': 80,
        'achievement_points_synced': 0,
      },
      'inventory_item': {
        'product_kind': 'gift_1',
        'quantity': 1,
      },
    });

    expect(result.offering.id, 'off-1');
    expect(result.offering.kind, 'gift');
    expect(result.offering.productTitle, '美式咖啡');
    expect(result.offering.productAssetKey, '1');
    expect(result.offering.isReceived, isFalse);
    expect(result.componentCard.type, 'gift');
    expect(result.componentCard.payload['status_label'], '待接收');
    expect(result.wallet?.ticketBalance, 10);
    expect(result.inventoryItem?.quantity, 1);
  });

  test('offering received notice is recognized from metadata', () {
    final message = ChatMessage(
      id: 'n1',
      conversationId: 'c1',
      role: 'assistant',
      content: '小芜领取了你的红包',
      createdAt: DateTime.utc(2026, 8, 21),
      metadata: {
        'offering_received': true,
        'offering_kind': 'red_packet',
        'offering_id': 'off-1',
      },
    );

    expect(message.isOfferingReceived, isTrue);
    expect(message.isMusicStatus, isFalse);
  });

  test('gift get result allows a missing wallet and inventory', () {
    final result = GiftSendResult.fromJson({
      'offering': {
        'id': 'off-2',
        'kind': 'gift',
        'ticket_amount': 25,
        'agent_value_yuan': 25,
        'status': 'received',
        'agent_id': 'agent-1',
        'created_at': '2026-08-21T08:00:00Z',
        'received_at': '2026-08-21T08:01:00Z',
        'product_kind': 'gift_1',
        'product_title': '美式咖啡',
      },
      'component_card': {
        'type': 'gift',
        'title': '美式咖啡',
        'subtitle': '',
        'body': '饮品',
        'payload': {'offering_id': 'off-2', 'status': 'received'},
      },
    });

    expect(result.offering.isReceived, isTrue);
    expect(result.wallet, isNull);
    expect(result.inventoryItem, isNull);
  });
}
