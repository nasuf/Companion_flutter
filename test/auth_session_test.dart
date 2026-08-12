import 'package:companion_flutter/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// 展示名的**优先级链整条在服务端**
/// (`services/user_profile.resolve_display_identity`: 自设昵称 → 微信昵称 →
/// 用户+手机尾号)，客户端只负责在它为空时挑一个场景兜底词。
///
/// 这里的测试就是在钉住"客户端不再自己拼来源"这件事：以前客户端会回落到
/// [AuthSession.username]，而那对真实用户是 `wx_89b939bc004` 这类内部 hash，于是
/// 又得写正则把它滤掉——加一种登录方式（苹果登录已经在登录页上）正则就会漏。
void main() {
  group('AuthSession.displayNameOr', () {
    test('uses the server-resolved display name', () {
      expect(
        _session(username: 'wx_ed8b9ba77f12f5c8', userDisplayName: '山木')
            .displayNameOr('小星辰'),
        '山木',
      );
    });

    test('falls back to the caller-supplied word when unset', () {
      expect(_session(username: 'songtao').displayNameOr('小星辰'), '小星辰');
    });

    test('treats a whitespace-only name as unset', () {
      expect(
        _session(username: 'songtao', userDisplayName: '   ').displayNameOr('小星辰'),
        '小星辰',
      );
    });

    test('trims the resolved name', () {
      expect(
        _session(username: 'songtao', userDisplayName: '  山木  ')
            .displayNameOr('小星辰'),
        '山木',
      );
    });

    test('never falls back to the login identifier', () {
      // 服务端为空就是为空。密码账号建号时会预写 display_name（见
      // auth.register），所以真实用户不会走到兜底词——但客户端绝不能自己去拿
      // username 顶上。
      final session = _session(username: 'songtao');

      expect(session.displayNameOr('小星辰'), isNot('songtao'));
      expect(session.userFacingName, isNot('songtao'));
    });

    test('each scene picks its own fallback word', () {
      final session = _session(username: 'ph_a71f0950d87f');

      expect(session.displayNameOr('小星辰'), '小星辰');
      expect(session.userFacingName, '我');
      expect(session.displayNameOr(''), '');
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
