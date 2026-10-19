import 'dart:convert';
import 'dart:io';
import 'package:companion_flutter/companion_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'availability and preflight use authenticated endpoints; malformed replies fail closed',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      String mode = 'closed';
      final sub = server.listen((request) async {
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer synthetic',
        );
        await request.drain<void>();
        request.response.headers.contentType = ContentType.json;
        expect(
          request.uri.path,
          request.method == 'GET'
              ? '/iap/apple/availability'
              : '/iap/apple/purchase-permission',
        );
        if (mode == 'unavailable') {
          request.response.statusCode = 503;
          request.response.write('{"detail":"unavailable"}');
        } else if (request.method == 'POST' && mode == 'closed') {
          request.response.statusCode = 403;
          request.response.write('{"detail":"real_money_payments_disabled"}');
        } else {
          request.response.write(
            jsonEncode(
              mode == 'missing'
                  ? {}
                  : {
                      'real_money_payments_enabled': mode == 'malformed'
                          ? 'true'
                          : mode == 'open',
                    },
            ),
          );
        }
        await request.response.close();
      });
      try {
        final api = CompanionApi(baseUrl: 'http://127.0.0.1:${server.port}')
          ..authToken = 'synthetic';
        expect(await api.getRealMoneyPaymentsEnabled(), false);
        await expectLater(
          api.authorizeRealMoneyPurchase(),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 403),
          ),
        );
        mode = 'open';
        expect(await api.getRealMoneyPaymentsEnabled(), true);
        await api.authorizeRealMoneyPurchase();
        for (final bad in ['missing', 'malformed']) {
          mode = bad;
          expect(await api.getRealMoneyPaymentsEnabled(), false);
          await expectLater(
            api.authorizeRealMoneyPurchase(),
            throwsA(isA<ApiException>()),
          );
        }
        mode = 'unavailable';
        await expectLater(
          api.getRealMoneyPaymentsEnabled(),
          throwsA(isA<ApiException>()),
        );
        await expectLater(
          api.authorizeRealMoneyPurchase(),
          throwsA(isA<ApiException>()),
        );
      } finally {
        await sub.cancel();
        await server.close(force: true);
      }
    },
  );
}
