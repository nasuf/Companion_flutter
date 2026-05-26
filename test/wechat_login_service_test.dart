import 'package:companion_flutter/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeWeChatGateway implements WeChatGateway {
  bool registerResult = true;
  bool installed = true;
  bool authLaunchResult = true;
  String? lastState;
  ValueChanged<WeChatAuthResult>? listener;

  @override
  Future<bool> authBy({required String scope, required String state}) async {
    lastState = state;
    return authLaunchResult;
  }

  @override
  Future<bool> get isWeChatInstalled async => installed;

  @override
  Future<bool> registerApi({
    required String appId,
    required String universalLink,
  }) async {
    return registerResult;
  }

  @override
  void addAuthListener(ValueChanged<WeChatAuthResult> listener) {
    this.listener = listener;
  }

  @override
  void removeAuthListener(ValueChanged<WeChatAuthResult> listener) {
    if (this.listener == listener) {
      this.listener = null;
    }
  }
}

void main() {
  test('requestAuthCode returns code from matching WeChat response', () async {
    final gateway = FakeWeChatGateway();
    final service = WeChatLoginService(
      gateway: gateway,
      appId: 'wx-test',
      responseTimeout: const Duration(seconds: 1),
    );

    final future = service.requestAuthCode();
    await Future<void>.delayed(Duration.zero);
    gateway.listener!(
      WeChatAuthResult(errCode: 0, code: 'code-1', state: gateway.lastState),
    );

    expect(await future, 'code-1');
    expect(gateway.listener, isNull);
  });

  test('requestAuthCode ignores stale state responses', () async {
    final gateway = FakeWeChatGateway();
    final service = WeChatLoginService(
      gateway: gateway,
      appId: 'wx-test',
      responseTimeout: const Duration(milliseconds: 20),
    );

    final future = service.requestAuthCode();
    await Future<void>.delayed(Duration.zero);
    gateway.listener!(
      const WeChatAuthResult(errCode: 0, code: 'stale', state: 'old-state'),
    );

    await expectLater(future, throwsA(isA<WeChatLoginException>()));
  });

  test(
    'requestAuthCode fails before SDK call when app id is missing',
    () async {
      final gateway = FakeWeChatGateway();
      final service = WeChatLoginService(gateway: gateway, appId: '');

      await expectLater(
        service.requestAuthCode(),
        throwsA(isA<WeChatLoginException>()),
      );
      expect(gateway.listener, isNull);
    },
  );

  test('requestAuthCode reports user cancellation', () async {
    final gateway = FakeWeChatGateway();
    final service = WeChatLoginService(
      gateway: gateway,
      appId: 'wx-test',
      responseTimeout: const Duration(seconds: 1),
    );

    final future = service.requestAuthCode();
    await Future<void>.delayed(Duration.zero);
    gateway.listener!(
      WeChatAuthResult(errCode: -2, code: null, state: gateway.lastState),
    );

    await expectLater(
      future,
      throwsA(
        isA<WeChatLoginException>().having(
          (error) => error.message,
          'message',
          '已取消微信登录',
        ),
      ),
    );
  });
}
