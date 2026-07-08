import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Device + build metadata attached to auth requests so the backend can
/// record where an account was created (users.signup_* columns).
///
/// Collection is best-effort: any plugin failure degrades to platform-only
/// info and must never block the login flow.
class ClientInfo {
  const ClientInfo({required this.platform, this.osVersion, this.appVersion});

  /// ios / android / harmony — same values the WeChat login already reports.
  final String platform;

  /// e.g. "iOS 17.5.1" / "Android 14 (SDK 34)".
  final String? osVersion;

  /// e.g. "0.1.10+1" (version + build number from the app bundle).
  final String? appVersion;

  static ClientInfo? _cached;

  static Future<ClientInfo> load() async {
    final cached = _cached;
    if (cached != null) return cached;

    String? osVersion;
    String? appVersion;
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        osVersion = 'iOS ${ios.systemVersion}';
      } else if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        osVersion =
            'Android ${android.version.release} (SDK ${android.version.sdkInt})';
      } else {
        osVersion = Platform.operatingSystemVersion;
      }
    } catch (error) {
      debugPrint('[client-info] os version unavailable: $error');
    }
    try {
      final package = await PackageInfo.fromPlatform();
      appVersion = package.buildNumber.isEmpty
          ? package.version
          : '${package.version}+${package.buildNumber}';
    } catch (error) {
      debugPrint('[client-info] app version unavailable: $error');
    }

    final info = ClientInfo(
      platform: _currentPlatform(),
      osVersion: osVersion,
      appVersion: appVersion,
    );
    _cached = info;
    return info;
  }

  // Kept in sync with currentWechatPlatform() in wechat_login_service.dart.
  static String _currentPlatform() {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'harmony';
  }
}
