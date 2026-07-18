import 'package:companion_flutter/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthSession.userFacingName', () {
    test('prefers the WeChat display name', () {
      final session = _session(
        username: 'wx_ed8b9ba77f12f5c8',
        userDisplayName: '山木',
      );

      expect(session.userFacingName, '山木');
    });

    test('uses a regular username when no display name is available', () {
      final session = _session(username: 'songtao');

      expect(session.userFacingName, 'songtao');
    });

    test('does not expose generated WeChat or phone identifiers', () {
      expect(_session(username: 'wx_ed8b9ba77f12f5c8').userFacingName, '我');
      expect(_session(username: 'ph_a71f0950d87f').userFacingName, '我');
    });

    test('ignores a generated identifier returned as display name', () {
      final session = _session(
        username: 'wx_ed8b9ba77f12f5c8',
        userDisplayName: 'wx_ed8b9ba77f12f5c8',
      );

      expect(session.userFacingName, '我');
    });
  });
}

AuthSession _session({required String username, String? userDisplayName}) {
  return AuthSession(
    token: 'token',
    userId: 'user-id',
    username: username,
    userDisplayName: userDisplayName,
    role: UserRole.user,
    hasAgent: false,
  );
}
