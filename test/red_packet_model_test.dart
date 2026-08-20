import 'package:companion_flutter/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseRedPacketTicketAmount accepts integers in range', () {
    expect(parseRedPacketTicketAmount('1'), 1);
    expect(parseRedPacketTicketAmount(' 18 '), 18);
    expect(parseRedPacketTicketAmount('1000000'), 1000000);
  });

  test('parseRedPacketTicketAmount rejects empty and out of range', () {
    expect(parseRedPacketTicketAmount(''), isNull);
    expect(parseRedPacketTicketAmount('0'), isNull);
    expect(parseRedPacketTicketAmount('-3'), isNull);
    expect(parseRedPacketTicketAmount('1.5'), isNull);
    expect(parseRedPacketTicketAmount('1000001'), isNull);
    expect(parseRedPacketTicketAmount('abc'), isNull);
  });

  test('red packet send result parses offering and card', () {
    final result = RedPacketSendResult.fromJson({
      'offering': {
        'id': 'off-1',
        'kind': 'red_packet',
        'ticket_amount': 18,
        'agent_value_yuan': 18,
        'status': 'sent',
        'agent_id': 'agent-1',
        'created_at': '2026-08-20T08:00:00Z',
      },
      'component_card': {
        'type': 'red_packet',
        'title': '红包',
        'subtitle': '待领取',
        'body': '给你的一点心意',
        'footer': '点击查看',
        'accent': '#FF4D5F',
        'payload': {
          'offering_id': 'off-1',
          'ticket_amount': 18,
          'status': 'sent',
        },
      },
      'wallet': {
        'ticket_balance': 82,
        'point_balance': 0,
        'achievement_points_synced': 0,
      },
    });

    expect(result.offering.id, 'off-1');
    expect(result.offering.ticketAmount, 18);
    expect(result.offering.isReceived, isFalse);
    expect(result.componentCard.type, 'red_packet');
    expect(result.componentCard.payload['offering_id'], 'off-1');
    expect(result.wallet?.ticketBalance, 82);
  });

  test('red packet get result allows a missing wallet', () {
    final result = RedPacketSendResult.fromJson({
      'offering': {
        'id': 'off-2',
        'kind': 'red_packet',
        'ticket_amount': 6,
        'agent_value_yuan': 6,
        'status': 'received',
        'agent_id': 'agent-1',
        'created_at': '2026-08-20T08:00:00Z',
        'received_at': '2026-08-20T08:01:00Z',
      },
      'component_card': {
        'type': 'red_packet',
        'title': '红包',
        'subtitle': '已领取',
        'body': '给你的一点心意',
        'footer': '点击查看',
        'payload': {'offering_id': 'off-2', 'status': 'received'},
      },
    });

    expect(result.offering.isReceived, isTrue);
    expect(result.wallet, isNull);
  });
}
