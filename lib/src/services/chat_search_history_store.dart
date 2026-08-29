part of 'package:companion_flutter/main.dart';

/// Recent chat-search terms, scoped per conversation (different agent chats
/// keep separate history). No `shared_preferences` dependency exists in this
/// app — follows the same small-wrapper-over-[FlutterSecureStorage] pattern
/// as [AuthSessionStore]/[AppThemeController].
class ChatSearchHistoryStore {
  ChatSearchHistoryStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _maxEntries = 12;

  final FlutterSecureStorage _storage;

  String _keyFor(String conversationId) => 'chat_search_history_$conversationId';

  Future<List<String>> load(String conversationId) async {
    final raw = await _storage.read(key: _keyFor(conversationId));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is String && item.trim().isNotEmpty) item,
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<List<String>> add(String conversationId, String term) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return load(conversationId);
    final current = await load(conversationId);
    final updated = [
      trimmed,
      ...current.where((item) => item != trimmed),
    ].take(_maxEntries).toList();
    await _storage.write(
      key: _keyFor(conversationId),
      value: jsonEncode(updated),
    );
    return updated;
  }

  Future<List<String>> remove(String conversationId, String term) async {
    final current = await load(conversationId);
    final updated = current.where((item) => item != term).toList();
    await _storage.write(
      key: _keyFor(conversationId),
      value: jsonEncode(updated),
    );
    return updated;
  }

  Future<void> clear(String conversationId) async {
    await _storage.delete(key: _keyFor(conversationId));
  }
}
