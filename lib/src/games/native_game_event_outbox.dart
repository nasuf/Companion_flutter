import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../../companion_api.dart';
import '../../models.dart';

typedef NativeGameEventSender =
    Future<void> Function(Map<String, dynamic> event);

class NativeGameEventOutbox {
  NativeGameEventOutbox({
    required this.apiBaseUrl,
    required this.userId,
    required NativeGameEventSender sendEvent,
    Future<Directory> Function()? supportDirectory,
    FlutterSecureStorage? legacyStorage,
  }) : _sendEvent = sendEvent,
       _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _legacyStorage = legacyStorage ?? const FlutterSecureStorage();

  factory NativeGameEventOutbox.forApi({
    required CompanionApi api,
    required AuthSession authSession,
  }) => NativeGameEventOutbox(
    apiBaseUrl: api.baseUrl,
    userId: authSession.userId,
    sendEvent: (event) async {
      await api.sendNativeGameEvent(
        sessionId: event['session_id']! as String,
        eventType: event['event_type']! as String,
        state: event['state'] as String?,
        payload: Map<String, dynamic>.from(event['payload']! as Map),
        source: 'replay',
        clientEventId: event['client_event_id']! as String,
      );
    },
  );

  final String apiBaseUrl;
  final String userId;
  final NativeGameEventSender _sendEvent;
  final Future<Directory> Function() _supportDirectory;
  final FlutterSecureStorage _legacyStorage;
  static final Map<String, Future<void>> _tails = {};

  String get _lockKey => '$apiBaseUrl:$userId';

  String get _legacyKey =>
      'native_game_terminal_outbox:'
      '${base64Url.encode(utf8.encode(apiBaseUrl))}:$userId';

  String get _fileName =>
      'native_game_event_outbox_'
      '${base64Url.encode(utf8.encode('$apiBaseUrl:$userId'))}.json';

  Future<File> _file() async {
    final directory = await _supportDirectory();
    return File('${directory.path}/$_fileName');
  }

  List<Map<String, dynamic>> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where(
            (item) =>
                item['session_id'] is String &&
                item['event_type'] is String &&
                item['client_event_id'] is String &&
                item['payload'] is Map,
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<T> _locked<T>(Future<T> Function() action) {
    final result = Completer<T>();
    final previous = _tails[_lockKey] ?? Future<void>.value();
    late final Future<void> next;
    next = previous
        .catchError((_) {})
        .then((_) async {
          try {
            result.complete(await action());
          } catch (error, stackTrace) {
            result.completeError(error, stackTrace);
          }
        })
        .whenComplete(() {
          if (identical(_tails[_lockKey], next)) _tails.remove(_lockKey);
        });
    _tails[_lockKey] = next;
    return result.future;
  }

  Future<List<Map<String, dynamic>>> _readUnlocked() async {
    try {
      final file = await _file();
      if (await file.exists()) return _decode(await file.readAsString());
    } catch (_) {
      // Fall through to the legacy Keychain-backed terminal queue.
    }
    try {
      final legacy = _decode(await _legacyStorage.read(key: _legacyKey));
      if (legacy.isNotEmpty) {
        await _writeUnlocked(legacy);
        await _legacyStorage.delete(key: _legacyKey);
      }
      return legacy;
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeUnlocked(List<Map<String, dynamic>> events) async {
    final file = await _file();
    if (events.isEmpty) {
      if (await file.exists()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(events), flush: true);
    await temporary.rename(file.path);
  }

  Future<List<Map<String, dynamic>>> read() => _locked(_readUnlocked);

  Future<void> write(List<Map<String, dynamic>> events) =>
      _locked(() => _writeUnlocked(events));

  Future<void> enqueue({
    required String sessionId,
    required String eventType,
    required String? state,
    required Map<String, dynamic> payload,
    required String clientEventId,
  }) => _locked(() async {
    final events = await _readUnlocked();
    events.removeWhere((item) => item['client_event_id'] == clientEventId);
    events.insert(0, {
      'session_id': sessionId,
      'event_type': eventType,
      'state': state,
      'payload': payload,
      'client_event_id': clientEventId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    await _writeUnlocked(events);
  });

  Future<void> remove(String clientEventId) => _locked(() async {
    final events = await _readUnlocked();
    events.removeWhere((item) => item['client_event_id'] == clientEventId);
    await _writeUnlocked(events);
  });

  Future<void> replay() => _locked(() async {
    final events = await _readUnlocked();
    if (events.isEmpty) return;
    final remaining = <Map<String, dynamic>>[];
    final blockedSessions = <String>{};
    final endedSessions = <String>{};
    for (final event in events.reversed) {
      final sessionId = event['session_id']! as String;
      if (endedSessions.contains(sessionId)) continue;
      if (blockedSessions.contains(sessionId)) {
        remaining.insert(0, event);
        continue;
      }
      try {
        await _sendEvent(event);
      } on ApiException catch (error) {
        if (error.message.contains('session_finished') ||
            error.message.contains('session_not_found')) {
          endedSessions.add(sessionId);
        } else {
          blockedSessions.add(sessionId);
          remaining.insert(0, event);
        }
      } catch (_) {
        blockedSessions.add(sessionId);
        remaining.insert(0, event);
      }
    }
    await _writeUnlocked(remaining);
  });
}
