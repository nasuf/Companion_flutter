import 'dart:io';

import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/models.dart';
import 'package:companion_flutter/src/games/native_game_event_outbox.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _SettlementApi extends CompanionApi {
  _SettlementApi() : super(baseUrl: 'https://settlement.test');
  bool offline = true;

  @override
  Future<GameEventResponse> sendNativeGameEvent({
    required String sessionId,
    required String eventType,
    String? state,
    Map<String, dynamic> payload = const {},
    String source = 'client',
    String? clientEventId,
  }) async {
    if (offline) throw const ApiException(503, 'offline');
    return GameEventResponse.fromJson({
      'session': {
        'id': sessionId,
        'status': 'settled',
        'result': {
          'point_settlement': {'delta': 38, 'base_delta': 25},
        },
      },
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'durable terminal replay publishes actual VIP receipt after recovery',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'settlement-replay-',
      );
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => directory.path);
      addTearDown(() async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        await directory.delete(recursive: true);
      });

      final api = _SettlementApi();
      final receipts = <GameEventResponse>[];
      final outbox = NativeGameEventOutbox.forApi(
        api: api,
        authSession: const AuthSession(
          token: 'test',
          userId: 'u1',
          username: 'tester',
          role: UserRole.user,
          hasAgent: true,
        ),
        onResponse: receipts.add,
      );
      await outbox.enqueue(
        sessionId: 'round-1',
        eventType: 'game_finished',
        state: 'settled',
        payload: {'max_tile': 2048},
        clientEventId: 'finish-1',
      );
      await outbox.replay();
      expect(receipts, isEmpty);
      expect(await outbox.read(), hasLength(1));

      api.offline = false;
      await outbox.replay();
      expect(receipts.single.session.id, 'round-1');
      expect(receipts.single.session.settledPointsDelta, 38);
      expect(await outbox.read(), isEmpty);
      await outbox.replay();
      expect(receipts, hasLength(1));
    },
  );
}
