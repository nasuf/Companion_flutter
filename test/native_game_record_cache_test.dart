import 'dart:io';

import 'package:companion_flutter/models.dart';
import 'package:companion_flutter/src/games/native_game_record_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;

  setUp(() async {
    NativeGameRecordCache.debugClear();
    directory = await Directory.systemTemp.createTemp('native-game-record-');
  });

  tearDown(() async {
    NativeGameRecordCache.debugClear();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  NativeGameRecordCache cache({String userId = 'user-1'}) {
    return NativeGameRecordCache(
      apiBaseUrl: 'https://example.test',
      userId: userId,
      supportDirectory: () async => directory,
    );
  }

  const gomoku = NativeGameRecordStats(
    totalRounds: 12,
    wins: 5,
    losses: 4,
    draws: 1,
    aborted: 2,
    totalSeconds: 900,
    winRate: 41.666,
  );

  test('memory hit is visible before disk is read again', () async {
    final store = cache();
    await store.write('gomoku', gomoku);
    expect(store.peek('gomoku')?.wins, 5);
    expect(store.peek('go'), isNull);
  });

  test('a new instance reads the same account from disk', () async {
    await cache().write('gomoku', gomoku);
    await cache().write(
      'go',
      const NativeGameRecordStats(
        totalRounds: 3,
        wins: 1,
        losses: 1,
        draws: 0,
        aborted: 1,
        totalSeconds: 120,
        winRate: 33.3,
      ),
    );
    NativeGameRecordCache.debugClear();
    final loaded = await cache().read('gomoku');
    expect(loaded?.totalRounds, 12);
    expect(loaded?.aborted, 2);
    expect(loaded?.totalSeconds, 900);
    expect((await cache().read('go'))?.totalRounds, 3);
    expect(await cache(userId: 'user-2').read('gomoku'), isNull);
  });
}
