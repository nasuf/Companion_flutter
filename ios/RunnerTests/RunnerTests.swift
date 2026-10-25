import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {
  func testAdminForegroundPushCrossesNativeFlutterChannel() {
    for type in ["admin_redis_capacity", "admin_new_user", "admin_takeover_message"] {
      let messenger = RecordingMessenger()
      let channel = FlutterMethodChannel(
        name: "companion/push_notifications", binaryMessenger: messenger
      )
      let payload = [
        "type": type, "notification_id": "event-\(type)",
        "title": "管理员提醒", "body": "验收内容", "route": "system",
      ]
      XCTAssertTrue(AppDelegate.forwardForegroundNotification(payload, channel: channel))
      XCTAssertEqual(messenger.calls.count, 1)
      XCTAssertEqual(messenger.channels, ["companion/push_notifications"])
      XCTAssertEqual(messenger.calls.first?.method, "remoteNotificationForeground")
      XCTAssertEqual(messenger.calls.first?.arguments as? [String: String], payload)
    }
  }

  func testUnrelatedPushKeepsExistingHandling() {
    let messenger = RecordingMessenger()
    let channel = FlutterMethodChannel(
      name: "companion/push_notifications", binaryMessenger: messenger
    )
    for payload: [String: Any] in [
      ["type": "agent_message"], ["type": "system_custom"], ["type": "future_type"],
      ["type": 17], [:],
    ] {
      XCTAssertFalse(AppDelegate.forwardForegroundNotification(payload, channel: channel))
    }
    XCTAssertTrue(messenger.calls.isEmpty)
  }

  func testUnavailableChannelDoesNotConsumeAdminPush() {
    XCTAssertFalse(AppDelegate.forwardForegroundNotification(
      ["type": "admin_redis_capacity"], channel: nil
    ))
  }

  func testBackgroundCallbackDeliversOnPlatformMainThread() {
    let sent = expectation(description: "Foreground event reaches Flutter")
    let messenger = RecordingMessenger()
    messenger.onSend = {
      XCTAssertTrue(Thread.isMainThread)
      sent.fulfill()
    }
    let channel = FlutterMethodChannel(
      name: "companion/push_notifications", binaryMessenger: messenger
    )
    DispatchQueue.global().async {
      XCTAssertTrue(AppDelegate.forwardForegroundNotification(
        ["type": "admin_redis_capacity"], channel: channel
      ))
    }
    wait(for: [sent], timeout: 3)
    XCTAssertEqual(messenger.calls.count, 1)
  }
}

private final class RecordingMessenger: NSObject, FlutterBinaryMessenger {
  var calls: [FlutterMethodCall] = []
  var channels: [String] = []
  var onSend: (() -> Void)?

  func send(onChannel channel: String, message: Data?) {
    guard let message else { return }
    channels.append(channel)
    calls.append(FlutterStandardMethodCodec.sharedInstance().decodeMethodCall(message))
    onSend?()
  }

  func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply?) {
    send(onChannel: channel, message: message)
  }

  func setMessageHandlerOnChannel(
    _ channel: String, binaryMessageHandler handler: FlutterBinaryMessageHandler?
  ) -> FlutterBinaryMessengerConnection {
    return 0
  }

  func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}
}
