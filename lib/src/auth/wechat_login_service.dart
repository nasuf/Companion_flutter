part of 'package:companion_flutter/main.dart';

const _wechatUniversalLink = String.fromEnvironment(
  'WECHAT_UNIVERSAL_LINK',
  defaultValue: 'https://www.banshengcomp.com/wechat/',
);

const _wechatAppId = String.fromEnvironment(
  'WECHAT_APP_ID',
  defaultValue: 'wx1411402de055bd22',
);

class WeChatLoginException implements Exception {
  const WeChatLoginException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WeChatAuthResult {
  const WeChatAuthResult({
    required this.errCode,
    required this.code,
    required this.state,
    this.errStr,
  });

  final int? errCode;
  final String? code;
  final String? state;
  final String? errStr;

  bool get isSuccessful => errCode == 0;
}

abstract class WeChatGateway {
  Future<bool> registerApi({
    required String appId,
    required String universalLink,
  });

  Future<bool> get isWeChatInstalled;

  Future<bool> authBy({required String scope, required String state});

  void addAuthListener(ValueChanged<WeChatAuthResult> listener);

  void removeAuthListener(ValueChanged<WeChatAuthResult> listener);
}

class FluwxWeChatGateway implements WeChatGateway {
  FluwxWeChatGateway({Fluwx? fluwx}) : _fluwx = fluwx ?? Fluwx();

  final Fluwx _fluwx;
  final Map<ValueChanged<WeChatAuthResult>, WeChatResponseSubscriber>
  _listeners = {};

  @override
  Future<bool> registerApi({
    required String appId,
    required String universalLink,
  }) {
    return _fluwx.registerApi(appId: appId, universalLink: universalLink);
  }

  @override
  Future<bool> get isWeChatInstalled => _fluwx.isWeChatInstalled;

  @override
  Future<bool> authBy({required String scope, required String state}) {
    return _fluwx.authBy(
      which: NormalAuth(scope: scope, state: state),
    );
  }

  @override
  void addAuthListener(ValueChanged<WeChatAuthResult> listener) {
    void subscriber(WeChatResponse response) {
      if (response is WeChatAuthResponse) {
        listener(
          WeChatAuthResult(
            errCode: response.errCode,
            errStr: response.errStr,
            code: response.code,
            state: response.state,
          ),
        );
      }
    }

    _listeners[listener] = subscriber;
    _fluwx.addSubscriber(subscriber);
  }

  @override
  void removeAuthListener(ValueChanged<WeChatAuthResult> listener) {
    final subscriber = _listeners.remove(listener);
    if (subscriber != null) {
      _fluwx.removeSubscriber(subscriber);
    }
  }
}

class WeChatLoginService {
  WeChatLoginService({
    WeChatGateway? gateway,
    String appId = _wechatAppId,
    String universalLink = _wechatUniversalLink,
    Duration responseTimeout = const Duration(seconds: 90),
  }) : _gateway = gateway ?? FluwxWeChatGateway(),
       _appId = appId,
       _universalLink = universalLink,
       _responseTimeout = responseTimeout;

  final WeChatGateway _gateway;
  final String _appId;
  final String _universalLink;
  final Duration _responseTimeout;

  Future<AuthSession> login({
    required CompanionApi api,
    required String platform,
  }) async {
    final code = await requestAuthCode();
    return api.wechatMobileLogin(code, platform: platform);
  }

  Future<String> requestAuthCode() async {
    final appId = _appId.trim();
    if (appId.isEmpty) {
      throw const WeChatLoginException('微信登录暂未开放');
    }
    final registered = await _gateway.registerApi(
      appId: appId,
      universalLink: _universalLink,
    );
    if (!registered) {
      throw const WeChatLoginException('微信登录初始化失败');
    }
    final installed = await _gateway.isWeChatInstalled;
    if (!installed) {
      throw const WeChatLoginException('请先安装微信后再登录');
    }

    final state = _newState();
    final completer = Completer<String>();
    late final ValueChanged<WeChatAuthResult> listener;
    listener = (result) {
      if (result.state != state || completer.isCompleted) return;
      if (result.isSuccessful &&
          result.code != null &&
          result.code!.isNotEmpty) {
        completer.complete(result.code!);
        return;
      }
      if (result.errCode == -2) {
        completer.completeError(const WeChatLoginException('已取消微信登录'));
        return;
      }
      completer.completeError(const WeChatLoginException('微信授权失败，请重试'));
    };

    _gateway.addAuthListener(listener);
    try {
      final launched = await _gateway.authBy(
        scope: 'snsapi_userinfo',
        state: state,
      );
      if (!launched) {
        throw const WeChatLoginException('无法打开微信授权');
      }
      return await completer.future.timeout(
        _responseTimeout,
        onTimeout: () {
          throw const WeChatLoginException('微信授权超时，请重试');
        },
      );
    } finally {
      _gateway.removeAuthListener(listener);
    }
  }

  String _newState() {
    final random = math.Random.secure().nextInt(1 << 32);
    return 'bansheng_${DateTime.now().microsecondsSinceEpoch}_$random';
  }
}

String currentWechatPlatform() {
  if (Platform.isIOS) return 'ios';
  if (Platform.isAndroid) return 'android';
  return 'harmony';
}
