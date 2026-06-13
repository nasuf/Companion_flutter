part of 'package:companion_flutter/main.dart';

class StoredAuthSession {
  const StoredAuthSession({required this.baseUrl, required this.token});

  final String baseUrl;
  final String token;
}

class AuthSessionStore {
  AuthSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _baseUrlKey = 'auth.base_url';
  static const _tokenKey = 'auth.token';

  final FlutterSecureStorage _storage;

  Future<StoredAuthSession?> read() async {
    final baseUrl = (await _storage.read(key: _baseUrlKey))?.trim();
    final token = (await _storage.read(key: _tokenKey))?.trim();
    if (baseUrl == null || baseUrl.isEmpty || token == null || token.isEmpty) {
      return null;
    }
    return StoredAuthSession(baseUrl: baseUrl, token: token);
  }

  Future<void> save({required String baseUrl, required String token}) async {
    final normalizedBaseUrl = baseUrl.trim().replaceAll(RegExp(r'/$'), '');
    final normalizedToken = token.trim();
    if (normalizedBaseUrl.isEmpty || normalizedToken.isEmpty) {
      await clear();
      return;
    }
    await Future.wait([
      _storage.write(key: _baseUrlKey, value: normalizedBaseUrl),
      _storage.write(key: _tokenKey, value: normalizedToken),
    ]);
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _baseUrlKey),
      _storage.delete(key: _tokenKey),
    ]);
  }
}
