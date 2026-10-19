import 'dart:convert';
import 'dart:io';

import 'package:companion_flutter/companion_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'admin reads and writes the Web singleton with explicit bool acknowledgements',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var enabled = false;
      var mode = 'ok';
      final writes = <Map<String, dynamic>>[];
      final sub = server.listen((request) async {
        expect(request.uri.toString(), '/admin-api/payment-settings');
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer admin-token',
        );
        final body = await utf8.decoder.bind(request).join();
        if (request.method == 'PUT') {
          final payload = jsonDecode(body) as Map<String, dynamic>;
          expect(payload.keys, ['real_money_payments_enabled']);
          expect(payload['real_money_payments_enabled'], isA<bool>());
          writes.add(payload);
          enabled = payload['real_money_payments_enabled'] as bool;
        } else {
          expect(request.method, 'GET');
        }
        request.response.headers.contentType = ContentType.json;
        if (mode == 'forbidden') {
          request.response.statusCode = 403;
          request.response.write('{"detail":"admin_required"}');
        } else {
          request.response.write(
            jsonEncode(switch (mode) {
              'missing' => {},
              'invalid' => {'real_money_payments_enabled': 'false'},
              'mismatch' => {'real_money_payments_enabled': !enabled},
              _ => {'real_money_payments_enabled': enabled},
            }),
          );
        }
        await request.response.close();
      });
      try {
        final api = CompanionApi(baseUrl: 'http://127.0.0.1:${server.port}')
          ..authToken = 'admin-token';
        expect(await api.fetchAdminRealMoneyPaymentsEnabled(), false);
        expect(await api.updateAdminRealMoneyPaymentsEnabled(true), true);
        expect(await api.fetchAdminRealMoneyPaymentsEnabled(), true);
        expect(await api.updateAdminRealMoneyPaymentsEnabled(false), false);
        mode = 'mismatch';
        expect(
          await api.updateAdminRealMoneyPaymentsEnabled(true),
          false,
          reason:
              'Use server acknowledgement, never the requested optimistic state',
        );
        for (final bad in ['missing', 'invalid']) {
          mode = bad;
          await expectLater(
            api.fetchAdminRealMoneyPaymentsEnabled(),
            throwsFormatException,
          );
          await expectLater(
            api.updateAdminRealMoneyPaymentsEnabled(false),
            throwsFormatException,
          );
        }
        mode = 'forbidden';
        for (final action in [
          api.fetchAdminRealMoneyPaymentsEnabled,
          () => api.updateAdminRealMoneyPaymentsEnabled(false),
        ]) {
          await expectLater(
            action(),
            throwsA(
              isA<ApiException>().having((e) => e.statusCode, 'status', 403),
            ),
          );
        }
        expect(writes.first, {'real_money_payments_enabled': true});
      } finally {
        await sub.cancel();
        await server.close(force: true);
      }
    },
  );
}
