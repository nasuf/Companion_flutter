import 'dart:convert';
import 'dart:io';
import 'package:companion_flutter/companion_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'address edit and delete use authenticated owner endpoint and accept 204',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final methods = <String>[];
      final subscription = server.listen((request) async {
        methods.add(request.method);
        expect(request.uri.path, '/offline/gifts/address');
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer synthetic',
        );
        await request.drain<void>();
        if (request.method == 'DELETE') {
          request.response.statusCode = 204;
        } else {
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({'id': 'address', 'phone': '13812345678'}),
          );
        }
        await request.response.close();
      });
      try {
        final api = CompanionApi(baseUrl: 'http://127.0.0.1:${server.port}')
          ..authToken = 'synthetic';
        expect((await api.fetchGiftAddress()).phone, '13812345678');
        await api.deleteGiftAddress();
        expect(methods, ['GET', 'DELETE']);
      } finally {
        await subscription.cancel();
        await server.close(force: true);
      }
    },
  );
  test(
    'normalizes relative gift images for home, deep link and thanks response',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final gift = {
        'id': 'gift',
        'product_image_url': '/offline/media/gift.jpg',
      };
      final subscription = server.listen((request) async {
        await request.drain<void>();
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(
            request.uri.path == '/offline/gifts'
                ? {
                    'shipping_gift': gift,
                    'groups': [
                      {
                        'year': 2026,
                        'gifts': [
                          gift,
                          {
                            'id': 'external',
                            'product_image_url': 'https://shop.test/p.jpg',
                          },
                          {'id': 'missing', 'product_image_url': '  '},
                        ],
                      },
                    ],
                  }
                : request.uri.path.endsWith('/thanks')
                ? {'gift': gift}
                : gift,
          ),
        );
        await request.response.close();
      });
      try {
        final base = 'http://127.0.0.1:${server.port}';
        final api = CompanionApi(baseUrl: base);
        final home = await api.fetchOfflineGifts();
        expect(
          home.shippingGift!.productImageUrl,
          '$base/offline/media/gift.jpg',
        );
        expect(
          home.groups.first.gifts.first.productImageUrl,
          '$base/offline/media/gift.jpg',
        );
        expect(
          home.groups.first.gifts[1].productImageUrl,
          'https://shop.test/p.jpg',
        );
        expect(home.groups.first.gifts[2].productImageUrl, isNull);
        expect(
          (await api.fetchOfflineGift('gift')).productImageUrl,
          '$base/offline/media/gift.jpg',
        );
        expect(
          (await api.sendGiftThanks('gift', message: '谢谢')).productImageUrl,
          '$base/offline/media/gift.jpg',
        );
      } finally {
        await subscription.cancel();
        await server.close(force: true);
      }
    },
  );
  test('confirm receipt posts to owner endpoint and parses reveal', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <String>[];
    final subscription = server.listen((request) async {
      requests.add('${request.method} ${request.uri.path}');
      expect(
        request.headers.value(HttpHeaders.authorizationHeader),
        'Bearer synthetic',
      );
      await request.drain<void>();
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'ok': true,
          'already_confirmed': false,
          'assistant_message': '是桂花乌龙茶！',
          'gift': {
            'id': 'gift',
            'status': 'delivered',
            'revealed': true,
            'gift_name': '桂花乌龙茶',
            'product_image_url': '/offline/media/user_image_a.jpg',
          },
        }),
      );
      await request.response.close();
    });
    try {
      final api = CompanionApi(baseUrl: 'http://127.0.0.1:${server.port}')
        ..authToken = 'synthetic';
      final result = await api.confirmGiftReceipt('gift');
      expect(requests, ['POST /offline/gifts/gift/confirm-receipt']);
      expect(result.gift.revealed, isTrue);
      expect(result.gift.giftName, '桂花乌龙茶');
      expect(
        result.gift.productImageUrl,
        'http://127.0.0.1:${server.port}/offline/media/user_image_a.jpg',
      );
      expect(result.assistantMessage, '是桂花乌龙茶！');
      expect(result.alreadyConfirmed, isFalse);
    } finally {
      await subscription.cancel();
      await server.close(force: true);
    }
  });
}
