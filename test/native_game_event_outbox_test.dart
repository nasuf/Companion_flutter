import 'dart:io';

import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/src/games/native_game_event_outbox.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _event(String sessionId, String clientEventId) => {
  'session_id': sessionId,
  'event_type': 'piece_moved',
  'state': 'playing',
  'payload': {'state_after_hash': clientEventId},
  'client_event_id': clientEventId,
};

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('native-game-outbox-');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test(
    'write-ahead events replay oldest first and clear after success',
    () async {
      final sent = <String>[];
      final outbox = NativeGameEventOutbox(
        apiBaseUrl: 'https://example.test',
        userId: 'user-1',
        supportDirectory: () async => directory,
        sendEvent: (event) async {
          sent.add(event['client_event_id']! as String);
        },
      );

      for (final id in ['event-1', 'event-2', 'event-3']) {
        final event = _event('session-1', id);
        await outbox.enqueue(
          sessionId: event['session_id']! as String,
          eventType: event['event_type']! as String,
          state: event['state'] as String?,
          payload: event['payload']! as Map<String, dynamic>,
          clientEventId: id,
        );
      }

      expect((await outbox.read()).map((event) => event['client_event_id']), [
        'event-3',
        'event-2',
        'event-1',
      ]);

      await outbox.replay();

      expect(sent, ['event-1', 'event-2', 'event-3']);
      expect(await outbox.read(), isEmpty);
    },
  );

  test('a failed event blocks newer events from the same session', () async {
    final sent = <String>[];
    final outbox = NativeGameEventOutbox(
      apiBaseUrl: 'https://example.test',
      userId: 'user-1',
      supportDirectory: () async => directory,
      sendEvent: (event) async {
        final id = event['client_event_id']! as String;
        sent.add(id);
        if (id == 'event-1') throw const ApiException(503, 'offline');
      },
    );
    await outbox.write([
      _event('session-2', 'other-1'),
      _event('session-1', 'event-2'),
      _event('session-1', 'event-1'),
    ]);

    await outbox.replay();

    expect(sent, ['event-1', 'other-1']);
    expect((await outbox.read()).map((event) => event['client_event_id']), [
      'event-2',
      'event-1',
    ]);
  });

  test('a terminal server session discards all stale queued events', () async {
    final outbox = NativeGameEventOutbox(
      apiBaseUrl: 'https://example.test',
      userId: 'user-1',
      supportDirectory: () async => directory,
      sendEvent: (event) async {
        throw const ApiException(400, 'session_finished');
      },
    );
    await outbox.write([
      _event('session-1', 'event-2'),
      _event('session-1', 'event-1'),
    ]);

    await outbox.replay();

    expect(await outbox.read(), isEmpty);
  });

  test('removing a session keeps other sessions queued', () async {
    final outbox = NativeGameEventOutbox(
      apiBaseUrl: 'https://example.test',
      userId: 'user-1',
      supportDirectory: () async => directory,
      sendEvent: (event) async {},
    );
    await outbox.write([
      _event('session-2', 'other-1'),
      _event('session-1', 'event-2'),
      _event('session-1', 'event-1'),
    ]);

    await outbox.removeSession('session-1');

    expect((await outbox.read()).map((event) => event['client_event_id']), [
      'other-1',
    ]);
  });

  test('concurrent writes are serialized without losing an action', () async {
    final outbox = NativeGameEventOutbox(
      apiBaseUrl: 'https://example.test',
      userId: 'user-1',
      supportDirectory: () async => directory,
      sendEvent: (event) async {},
    );

    await Future.wait([
      for (var index = 0; index < 20; index += 1)
        outbox.enqueue(
          sessionId: 'session-1',
          eventType: 'piece_moved',
          state: 'playing',
          payload: {'action_number': index + 1},
          clientEventId: 'event-$index',
        ),
    ]);

    final ids = (await outbox.read())
        .map((event) => event['client_event_id'])
        .toSet();
    expect(ids, hasLength(20));
    expect(
      ids,
      containsAll([for (var index = 0; index < 20; index++) 'event-$index']),
    );
  });

  test('separate page instances share one serialized queue', () async {
    NativeGameEventOutbox build() => NativeGameEventOutbox(
      apiBaseUrl: 'https://example.test',
      userId: 'user-1',
      supportDirectory: () async => directory,
      sendEvent: (event) async {},
    );
    final first = build();
    final second = build();

    await Future.wait([
      for (var index = 0; index < 20; index += 1)
        (index.isEven ? first : second).enqueue(
          sessionId: 'session-${index % 2}',
          eventType: 'piece_moved',
          state: 'playing',
          payload: {'action_number': index + 1},
          clientEventId: 'cross-instance-$index',
        ),
    ]);

    final events = await first.read();
    expect(events, hasLength(20));
    expect(
      events.map((event) => event['client_event_id']).toSet(),
      hasLength(20),
    );
    expect(
      directory.listSync().where((entry) => entry.path.endsWith('.tmp')),
      isEmpty,
    );
  });
}
