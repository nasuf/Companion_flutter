import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var pushChannel: FlutterMethodChannel?
  private var apnsToken: String?
  private var pendingNotificationPayload: [String: Any]?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    configurePushChannel()
    UNUserNotificationCenter.current().delegate = self
    if let remote = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
      pendingNotificationPayload = normalizeNotificationPayload(remote)
    }
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    configurePushChannel(registry: engineBridge.pluginRegistry)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    configurePushChannel()
  }

  private func configurePushChannel(registry: FlutterPluginRegistry? = nil) {
    guard pushChannel == nil else {
      return
    }
    guard let registrar = (registry ?? self).registrar(forPlugin: "CompanionPushNotifications") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "companion/push_notifications",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self else {
        result(FlutterError(code: "unavailable", message: "AppDelegate unavailable", details: nil))
        return
      }
      switch call.method {
      case "requestAuthorizationAndRegister":
        self.requestAuthorizationAndRegister(result: result)
      case "refreshRegistration":
        self.refreshRemoteNotificationRegistration(result: result)
      case "getToken":
        result(self.apnsToken)
      case "apnsEnvironment":
        result(self.currentApnsEnvironment())
      case "appMetadata":
        result(self.currentAppMetadata())
      case "takeInitialNotification":
        let payload = self.pendingNotificationPayload
        self.pendingNotificationPayload = nil
        result(payload)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    pushChannel = channel
  }

  private func currentAppMetadata() -> [String: String] {
    let bundleId = Bundle.main.bundleIdentifier ?? ""
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    let appVersion = build.isEmpty ? version : "\(version) (\(build))"
    return [
      "bundle_id": bundleId,
      "app_version": appVersion,
    ]
  }

  private func currentApnsEnvironment() -> String? {
    if let profileEnvironment = apnsEnvironmentFromProvisioningProfile() {
      return profileEnvironment
    }
    if let plistEnvironment = Bundle.main.object(forInfoDictionaryKey: "APS_ENVIRONMENT") as? String {
      return normalizeApnsEnvironment(plistEnvironment)
    }
    return nil
  }

  private func apnsEnvironmentFromProvisioningProfile() -> String? {
    guard
      let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
      let data = try? Data(contentsOf: url),
      let text = String(data: data, encoding: .isoLatin1),
      let start = text.range(of: "<?xml"),
      let end = text.range(of: "</plist>")
    else {
      return nil
    }
    let plistText = String(text[start.lowerBound..<end.upperBound])
    guard
      let plistData = plistText.data(using: .utf8),
      let plist = try? PropertyListSerialization.propertyList(
        from: plistData,
        options: [],
        format: nil
      ) as? [String: Any],
      let entitlements = plist["Entitlements"] as? [String: Any],
      let environment = entitlements["aps-environment"] as? String
    else {
      return nil
    }
    return normalizeApnsEnvironment(environment)
  }

  private func normalizeApnsEnvironment(_ value: String) -> String? {
    switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "development", "sandbox":
      return "development"
    case "production":
      return "production"
    default:
      return nil
    }
  }

  private func refreshRemoteNotificationRegistration(result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      var canRegister = settings.authorizationStatus == .authorized ||
        settings.authorizationStatus == .provisional
      if #available(iOS 14.0, *) {
        canRegister = canRegister || settings.authorizationStatus == .ephemeral
      }
      DispatchQueue.main.async {
        if canRegister {
          UIApplication.shared.registerForRemoteNotifications()
        }
        result(self.apnsToken)
      }
    }
  }

  private func requestAuthorizationAndRegister(result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
      if let error {
        DispatchQueue.main.async {
          result(FlutterError(code: "permission_error", message: error.localizedDescription, details: nil))
        }
        return
      }
      if granted {
        DispatchQueue.main.async {
          UIApplication.shared.registerForRemoteNotifications()
          result(true)
        }
      } else {
        DispatchQueue.main.async {
          result(false)
        }
      }
    }
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    apnsToken = token
    pushChannel?.invokeMethod("apnsToken", arguments: token)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("APNs registration failed: \(error.localizedDescription)")
    pushChannel?.invokeMethod("apnsRegistrationFailed", arguments: error.localizedDescription)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let payload = normalizeNotificationPayload(response.notification.request.content.userInfo)
    if pushChannel == nil {
      pendingNotificationPayload = payload
    } else {
      pushChannel?.invokeMethod("remoteNotificationTapped", arguments: payload)
    }
    super.userNotificationCenter(
      center,
      didReceive: response,
      withCompletionHandler: completionHandler
    )
  }

  private func normalizeNotificationPayload(_ userInfo: [AnyHashable: Any]) -> [String: Any] {
    var payload: [String: Any] = [:]
    for (key, value) in userInfo {
      guard let key = key as? String, key != "aps" else { continue }
      payload[key] = value
    }
    return payload
  }
}
