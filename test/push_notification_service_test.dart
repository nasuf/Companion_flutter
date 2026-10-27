import 'dart:async';
import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api extends CompanionApi {
  _Api(this.name) : super(baseUrl: 'https://example.invalid');
  final String name;
  final events = <String>[];
  final entered = Completer<void>();
  Completer<void>? release;
  @override
  Future<void> registerPushDevice({
    String platform = 'ios',
    required String token,
    required String environment,
    required String deviceId,
    String? bundleId,
    String? appVersion,
  }) async {
    expect(platform, 'android');
    expect(token, 'registration_XYZ123');
    expect(bundleId, 'com.bansheng.prod');
    events.add('register-start');
    if (!entered.isCompleted) entered.complete();
    await release?.future;
    events.add('register-end');
  }

  @override
  Future<void> disablePushDevice({required String token}) async {
    events.add('disable');
  }

  @override
  Future<void> updatePushPresence({
    required String deviceId,
    required bool foreground,
    String? workspaceId,
    String? conversationId,
  }) async {}
}

AuthSession _session(String user) => AuthSession(
  token: user,
  userId: user,
  username: user,
  role: UserRole.user,
  hasAgent: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('companion/push_notifications');
  late PushNotificationService service;
  late List<String> native;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    service = PushNotificationService.forTesting();
    native = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          native.add(call.method);
          return switch (call.method) {
            'getToken' || 'refreshRegistration' => 'registration_XYZ123',
            'requestAuthorizationAndRegister' => true,
            'appMetadata' => {
              'bundle_id': 'com.bansheng.prod',
              'app_version': '0.6.1',
            },
            _ => null,
          };
        });
  });
  tearDown(() async {
    await service.clear();
    WidgetsBinding.instance.removeObserver(service);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('logout waits for registration before disabling the device', () async {
    final api = _Api('old')..release = Completer<void>();
    final configured = service.configure(api, _session('old'));
    await api.entered.future;
    final cleared = service.clear();
    api.release!.complete();
    await Future.wait([configured, cleared]);
    expect(api.events, ['register-start', 'register-end', 'disable']);
    expect(native.last, 'stopPush');
  });

  test('queued account switch remains enabled after previous logout', () async {
    final old = _Api('old');
    final next = _Api('next');
    await service.configure(old, _session('old'));
    final cleared = service.clear();
    final configured = service.configure(next, _session('next'));
    await Future.wait([cleared, configured]);
    expect(old.events.last, 'disable');
    expect(next.events, ['register-start', 'register-end']);
    expect(
      native.lastIndexOf('requestAuthorizationAndRegister'),
      greaterThan(native.lastIndexOf('stopPush')),
    );
  });

  test('notification click payload preserves the destination', () async {
    await service.configure(_Api('user'), _session('user'));
    final payload = service.payloads.first;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('remoteNotificationTapped', {
          'type': 'agent_message',
          'route': 'chat',
          'conversation_id': 'conversation',
        }),
      ),
      (_) {},
    );
    expect((await payload).data['conversation_id'], 'conversation');
    expect(service.takePendingPayload()!.route, 'chat');
  });

  test('service health push is an operations alert too', () {
    final event = AppNotificationEvent.fromPushPayload(
      const PushNotificationPayload({
        'type': 'admin_service_health',
        'route': 'system',
        'notification_id': 'service-health-1',
        'title': '服务告警',
        'body': '30分钟内3条用户消息超过3分钟未回复。',
      }),
    );
    expect(event.isOperationsAlert, isTrue);
    expect(event.title, '服务告警');
  });

  test('native Redis foreground push becomes an in-app alert', () async {
    await service.configure(_Api('admin'), _session('admin'));
    final payload = service.payloads.first;
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('remoteNotificationForeground', {
              'type': 'admin_redis_capacity',
              'route': 'system',
              'notification_id': 'redis-capacity-1',
              'title': 'Redis 内存预警',
              'body': '内存使用76%',
            }),
          ),
          (_) {},
        );
    final event = AppNotificationEvent.fromPushPayload(await payload);
    expect(event.isOperationsAlert, isTrue);
    expect(event.source, AppNotificationSource.inApp);
    expect(event.id, 'redis-capacity-1');
    expect(event.title, 'Redis 内存预警');
    expect(event.body, '内存使用76%');
  });
}
