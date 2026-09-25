import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../models.dart';

/// Last home-screen record for each native game, kept on device so opening a
/// game can paint 总对局 / 胜利局 / 胜率 / 时长 before the network returns.
///
/// Memory is checked first (same process). Disk is the cold-start copy, one
/// file per account. A later server response overwrites both.
class NativeGameRecordCache {
  NativeGameRecordCache({
    required this.apiBaseUrl,
    required this.userId,
    Future<Directory> Function()? supportDirectory,
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  final String apiBaseUrl;
  final String userId;
  final Future<Directory> Function() _supportDirectory;

  static const _version = 1;
  static final Map<String, NativeGameRecordStats> _memory = {};
  static final Map<String, Future<void>> _writeTails = {};

  String get _scope => '$apiBaseUrl:$userId';

  String _memoryKey(String gameKey) => '$_scope\n$gameKey';

  String get _fileName =>
      'native_game_record_cache_'
      '${base64Url.encode(utf8.encode(_scope))}.json';

  /// Same-process hit. Does not touch disk.
  NativeGameRecordStats? peek(String gameKey) => _memory[_memoryKey(gameKey)];

  Future<NativeGameRecordStats?> read(String gameKey) async {
    final cached = peek(gameKey);
    if (cached != null) return cached;
    final games = await _readGames();
    final raw = games[gameKey];
    if (raw is! Map) return null;
    try {
      final stats = NativeGameRecordStats.fromJson(
        Map<String, dynamic>.from(raw),
      );
      _memory[_memoryKey(gameKey)] = stats;
      return stats;
    } catch (caught) {
      debugPrint('Ignoring unreadable native game record cache: $caught');
      return null;
    }
  }

  Future<void> write(String gameKey, NativeGameRecordStats stats) {
    _memory[_memoryKey(gameKey)] = stats;
    final previous = _writeTails[_scope] ?? Future<void>.value();
    final next = previous
        .catchError((_) {})
        .then((_) => _writeGames(gameKey, stats));
    _writeTails[_scope] = next;
    return next;
  }

  @visibleForTesting
  static void debugClear() {
    _memory.clear();
    _writeTails.clear();
  }

  Future<File> _file() async {
    final directory = await _supportDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<Map<String, dynamic>> _readGames() async {
    try {
      final file = await _file();
      if (!await file.exists()) return {};
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return {};
      if (decoded['v'] != _version) return {};
      final games = decoded['games'];
      if (games is! Map) return {};
      return Map<String, dynamic>.from(games);
    } catch (caught) {
      debugPrint('Failed to read native game record cache: $caught');
      return {};
    }
  }

  Future<void> _writeGames(String gameKey, NativeGameRecordStats stats) async {
    final games = await _readGames();
    games[gameKey] = stats.toJson();
    final file = await _file();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(
      jsonEncode({'v': _version, 'games': games}),
      flush: true,
    );
    await tmp.rename(file.path);
  }
}
