import 'dart:async';

import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class _ChatApi extends CompanionApi {
  _ChatApi() : super(baseUrl: 'http://127.0.0.1:1');
  int locationSaves = 0;

  @override
  Future<Conversation> getConversation(String id) async => Conversation(
    id: id,
    userId: 'user',
    agentId: 'agent',
    aiStatus: 'idle',
    aiStatusLabel: '空闲',
    interactionDays: 12,
  );

  @override
  Future<List<ChatMessage>> loadMessages(
    String id, {
    int limit = 100,
    int offset = 0,
  }) async => [];

  @override
  Future<bool> saveUserLocation({
    double? latitude,
    double? longitude,
    String? city,
    String? region,
    String? country,
    String permissionStatus = 'unknown',
  }) async {
    locationSaves++;
    return true;
  }
}

Position _position([double latitude = 32.2]) => Position(
  latitude: latitude,
  longitude: 119.4,
  timestamp: DateTime.now(),
  accuracy: 10,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class _Gps extends GeolocatorPlatform {
  final reads = <Completer<Position>>[];
  bool enabled = true;
  int settingsOpened = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    final read = Completer<Position>();
    reads.add(read);
    return read.future;
  }

  @override
  Future<bool> openLocationSettings() async {
    settingsOpened++;
    return true;
  }
}

class _Geocoder extends GeocodingPlatform {
  final reads = <Completer<List<Placemark>>>[];
  @override
  Future<void> setLocaleIdentifier(String localeIdentifier) async {}
  @override
  Future<List<Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude,
  ) {
    final read = Completer<List<Placemark>>();
    reads.add(read);
    return read.future;
  }
}

const _session = AuthSession(
  token: 'synthetic',
  userId: 'user',
  username: 'user',
  role: UserRole.user,
  hasAgent: true,
  agentId: 'agent',
  agentName: '小伴',
  conversationId: 'conversation',
);

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Finder _composerButton(String tooltip) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == '_Composer',
  ),
  matching: find.byTooltip(tooltip),
);

final _spinner = find.byKey(const ValueKey('chat-location-loading'));

class _Fixture {
  final api = _ChatApi();
  final gps = _Gps();
  final geocoder = _Geocoder();
  final active = ValueNotifier(true);
  final session = ValueNotifier(_session);
  final navigator = GlobalKey<NavigatorState>();

  Future<void> open(WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      MusicPlaybackController.instance.configureQuota(api);
    });
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [appRouteObserver],
        theme: AppTheme.materialTheme(Brightness.light),
        home: ValueListenableBuilder(
          valueListenable: active,
          builder: (_, isActive, _) => ValueListenableBuilder(
            valueListenable: session,
            builder: (_, session, _) => Scaffold(
              body: ChatPage(
                api: api,
                session: session,
                isActive: isActive,
                onOpenSidebar: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await _frames(tester);
    await tester.tap(_composerButton('更多'));
    await _frames(tester);
    expect(find.text('位置'), findsOneWidget);
  }

  Future<void> start(WidgetTester tester) async {
    await tester.tap(find.text('位置'));
    await tester.pump();
    expect(_spinner, findsOneWidget);
    expect(gps.reads, hasLength(1));
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    for (final read in gps.reads) {
      if (!read.isCompleted) read.complete(_position());
    }
    for (final read in geocoder.reads) {
      if (!read.isCompleted) read.complete([]);
    }
    await _frames(tester);
    active.dispose();
    session.dispose();
    expect(tester.takeException(), isNull);
  }
}

void _scenario(
  String name,
  Future<void> Function(WidgetTester, _Fixture) body, {
  TargetPlatform platform = TargetPlatform.android,
}) {
  testWidgets(name, (tester) async {
    final oldGps = GeolocatorPlatform.instance;
    final oldGeocoder = GeocodingPlatform.instance;
    final fixture = _Fixture();
    debugDefaultTargetPlatformOverride = platform;
    GeolocatorPlatform.instance = fixture.gps;
    GeocodingPlatform.instance = fixture.geocoder;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    try {
      await fixture.open(tester);
      await body(tester, fixture);
    } finally {
      await fixture.close(tester);
      debugDefaultTargetPlatformOverride = null;
      GeolocatorPlatform.instance = oldGps;
      if (oldGeocoder != null) GeocodingPlatform.instance = oldGeocoder;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
      'com.llfbandit.record/messages',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => null,
      );
    }
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async {
        final id = (call.arguments as Map?)?['playerId'];
        if (id != null) {
          messenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/$id'),
            (_) async => null,
          );
        }
        return null;
      },
    );
  });
  tearDownAll(() => MusicPlaybackController.instance.dispose());

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    _scenario(
      '$platform shows busy immediately and previews before geocoding finishes',
      (tester, f) async {
        await f.start(tester);
        await tester.tap(find.text('位置'));
        await tester.pump();
        expect(f.gps.reads, hasLength(1));
        expect(find.byType(LocationConfirmPage), findsNothing);
        f.gps.reads.single.complete(_position());
        await _frames(tester);
        expect(find.byType(LocationConfirmPage), findsOneWidget);
        expect(find.text('正在获取地址…'), findsOneWidget);
        expect(find.text('发送位置'), findsOneWidget);
        expect(f.geocoder.reads, hasLength(1));
        f.geocoder.reads.single.complete([Placemark(locality: '镇江市')]);
        await _frames(tester);
        expect(find.text('正在获取地址…'), findsNothing);
        expect(find.text('镇江市'), findsWidgets);
        expect(f.gps.reads, hasLength(1));
        // Previewing or cancelling must not sync the profile or send a message.
        await tester.tap(find.text('取消'));
        await _frames(tester);
        expect(f.api.locationSaves, 0);
      },
      platform: platform,
    );
  }

  for (final exit in [
    'close',
    'close-reopen',
    'emoji',
    'keyboard',
    'tab',
    'route',
    'popup',
    'background',
    'session',
  ]) {
    _scenario('ignores a late location after $exit', (tester, f) async {
      await f.start(tester);
      switch (exit) {
        case 'close':
        case 'close-reopen':
          await tester.tap(_composerButton('更多'));
          await _frames(tester);
          if (exit == 'close-reopen') {
            await tester.tap(_composerButton('更多'));
            await _frames(tester);
          }
        case 'emoji':
          await tester.tap(_composerButton('表情'));
          await _frames(tester);
        case 'keyboard':
          await tester.tap(find.byType(ExtendedTextField));
          await _frames(tester);
        case 'tab':
          f.active.value = false;
          await _frames(tester);
          f.active.value = true;
          await _frames(tester);
        case 'route':
          unawaited(
            f.navigator.currentState!.push<void>(
              MaterialPageRoute(
                builder: (_) => const Scaffold(body: Text('其他页面')),
              ),
            ),
          );
          await _frames(tester);
          f.navigator.currentState!.pop();
          await _frames(tester);
        case 'popup':
          unawaited(
            showDialog<void>(
              context: tester.element(find.byType(ChatPage)),
              builder: (_) => const AlertDialog(content: Text('其他弹窗')),
            ),
          );
          await _frames(tester);
          f.navigator.currentState!.pop();
          await _frames(tester);
        case 'background':
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await tester.pump();
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await _frames(tester);
        case 'session':
          f.session.value = _session.copyWith(
            conversationId: 'other-conversation',
          );
          await _frames(tester);
      }
      f.gps.reads.single.complete(_position());
      await _frames(tester);
      expect(find.byType(LocationConfirmPage), findsNothing);
      expect(_spinner, findsNothing);
      expect(f.geocoder.reads, isEmpty);
      expect(f.api.locationSaves, 0);
    });
  }

  _scenario('new tap after reopening owns the pending result', (
    tester,
    f,
  ) async {
    await f.start(tester);
    await tester.tap(_composerButton('更多'));
    await _frames(tester);
    await tester.tap(_composerButton('更多'));
    await _frames(tester);
    await f.start(tester);
    f.gps.reads.single.complete(_position());
    await _frames(tester);
    expect(find.byType(LocationConfirmPage), findsOneWidget);
  });

  _scenario('location failure restores the button and allows retry', (
    tester,
    f,
  ) async {
    f.gps.enabled = false;
    await tester.tap(find.text('位置'));
    await _frames(tester);
    expect(_spinner, findsNothing);
    expect(find.text('手机定位服务未开启，请在系统设置中开启后重试。'), findsOneWidget);
    expect(f.gps.settingsOpened, 0);
    ScaffoldMessenger.of(
      tester.element(find.byType(ChatPage)),
    ).hideCurrentSnackBar();
    await _frames(tester);
    f.gps.enabled = true;
    await f.start(tester);
    f.gps.reads.single.complete(_position());
    await _frames(tester);
    expect(find.byType(LocationConfirmPage), findsOneWidget);
  });

  _scenario('permission dialog inactivity does not cancel the tap', (
    tester,
    f,
  ) async {
    await f.start(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    f.gps.reads.single.complete(_position());
    await _frames(tester);
    expect(find.byType(LocationConfirmPage), findsOneWidget);
  });

  _scenario('late GPS failure after closing is silent', (tester, f) async {
    await f.start(tester);
    await tester.tap(_composerButton('更多'));
    await _frames(tester);
    f.gps.reads.single.completeError(PermissionDeniedException('test denied'));
    await _frames(tester);
    expect(find.byType(LocationConfirmPage), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(_spinner, findsNothing);
  });

  _scenario('confirming a location still syncs the selected coordinates', (
    tester,
    f,
  ) async {
    await f.start(tester);
    f.gps.reads.single.complete(_position());
    await _frames(tester);
    f.geocoder.reads.single.complete([Placemark(locality: '镇江市')]);
    await _frames(tester);
    await tester.tap(find.text('发送位置'));
    await _frames(tester);
    expect(find.byType(LocationConfirmPage), findsNothing);
    expect(f.api.locationSaves, 1);
  });

  _scenario(
    'late address cannot overwrite a refreshed position or reopen a sheet',
    (tester, f) async {
      await f.start(tester);
      f.gps.reads.single.complete(_position());
      await _frames(tester);
      await tester.tap(find.text('重新定位'));
      await tester.pump();
      expect(f.gps.reads, hasLength(2));
      f.gps.reads.last.complete(_position(31.1));
      await _frames(tester);
      f.geocoder.reads.last.complete([Placemark(locality: '新位置')]);
      await _frames(tester);
      f.geocoder.reads.first.complete([Placemark(locality: '旧位置')]);
      await _frames(tester);
      expect(find.text('新位置'), findsWidgets);
      expect(find.text('旧位置'), findsNothing);
      expect(find.textContaining('31.100000'), findsWidgets);
      await tester.tap(find.text('取消'));
      await _frames(tester);
      expect(find.byType(LocationConfirmPage), findsNothing);
    },
  );

  _scenario('small screen can scroll the preview without overflow', (
    tester,
    f,
  ) async {
    await f.start(tester);
    tester.view.physicalSize = const Size(390, 500);
    f.gps.reads.single.complete(_position());
    await _frames(tester);
    expect(find.byType(LocationConfirmPage), findsOneWidget);
    await tester.ensureVisible(find.text('取消'));
    await _frames(tester);
    await tester.tap(find.text('取消'));
    await _frames(tester);
    expect(find.byType(LocationConfirmPage), findsNothing);
  });

  _scenario('cancelling a refresh ignores its late GPS result', (
    tester,
    f,
  ) async {
    await f.start(tester);
    f.gps.reads.single.complete(_position());
    await _frames(tester);
    await tester.tap(find.text('重新定位'));
    await tester.pump();
    expect(f.gps.reads, hasLength(2));
    await tester.tap(find.text('取消'));
    await _frames(tester);
    f.gps.reads.last.complete(_position(31.1));
    await _frames(tester);
    expect(find.byType(LocationConfirmPage), findsNothing);
    expect(f.api.locationSaves, 0);
  });

  _scenario('dismissing the sheet during address lookup never reopens it', (
    tester,
    f,
  ) async {
    await f.start(tester);
    f.gps.reads.single.complete(_position());
    await _frames(tester);
    await tester.tap(find.text('取消'));
    await _frames(tester);
    f.geocoder.reads.single.complete([Placemark(locality: '镇江市')]);
    await _frames(tester);
    expect(find.byType(LocationConfirmPage), findsNothing);
    expect(f.api.locationSaves, 0);
  });
}
