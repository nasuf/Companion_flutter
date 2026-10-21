import 'dart:async';

import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:companion_flutter/offline_models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class _Gps extends GeolocatorPlatform {
  bool unavailable = false;
  Completer<Position>? gate;
  int requests = 0;
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => null;
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    requests++;
    if (unavailable) throw TimeoutException('test timeout');
    if (gate != null) return gate!.future;
    return _position();
  }
}

Position _position() => Position(
  latitude: 32.2,
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

class _Geocoder extends GeocodingPlatform {
  @override
  Future<void> setLocaleIdentifier(String localeIdentifier) async {}
  @override
  Future<List<Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude,
  ) async => [];
}

class _Api extends CompanionApi {
  _Api() : super(baseUrl: 'https://example.test');
  bool fail = true;
  int saves = 0;
  @override
  Future<OfflineHome> fetchOfflineHome({String? workspaceId}) async =>
      OfflineHome.fromJson({});
  @override
  Future<OfflineActivities> fetchOfflineActivities({
    String? workspaceId,
  }) async => const OfflineActivities(pending: [], ignored: [], completed: []);
  @override
  Future<bool> saveUserLocation({
    double? latitude,
    double? longitude,
    String? city,
    String? region,
    String? country,
    String permissionStatus = 'unknown',
  }) async {
    saves++;
    if (fail) throw const ApiException(503, 'test save failed');
    return true;
  }
}

const _session = AuthSession(
  token: 'test',
  userId: 'user',
  username: 'tester',
  role: UserRole.user,
  hasAgent: true,
);
Future<void> _show(WidgetTester tester, _Api api) async {
  tester.view.physicalSize = const Size(430, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    CupertinoApp(
      home: OfflineActivityPage(
        api: api,
        session: _session,
        hasLocation: false,
      ),
    ),
  );
  await tester.pump();
}

Future<void> _advance(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late GeolocatorPlatform oldGps;
  GeocodingPlatform? oldGeocoder;
  late _Gps gps;
  setUp(() {
    oldGps = GeolocatorPlatform.instance;
    oldGeocoder = GeocodingPlatform.instance;
    gps = _Gps();
    GeolocatorPlatform.instance = gps;
    GeocodingPlatform.instance = _Geocoder();
  });
  tearDown(() {
    GeolocatorPlatform.instance = oldGps;
    if (oldGeocoder != null) GeocodingPlatform.instance = oldGeocoder;
  });

  testWidgets(
    'activity shows upload failure and succeeds after a retry',
    (tester) async {
      final api = _Api();
      await _show(tester, api);
      await tester.ensureVisible(find.text('让我知道你在哪'));
      await tester.tap(find.text('让我知道你在哪'));
      await _advance(tester);
      expect(find.textContaining('已获取手机位置，但同步暂未完成'), findsOneWidget);
      expect(find.text('让我知道你在哪'), findsOneWidget);
      api.fail = false;
      await tester.ensureVisible(find.text('让我知道你在哪'));
      await tester.tap(find.text('让我知道你在哪'));
      await _advance(tester);
      expect(find.textContaining('已获取手机位置，但同步暂未完成'), findsNothing);
      expect(find.text('让我知道你在哪'), findsNothing);
      expect(find.text('小惊喜一会儿不定时有'), findsOneWidget);
      expect(api.saves, 2);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  testWidgets('position timeout displays an actionable error', (tester) async {
    gps.unavailable = true;
    await _show(tester, _Api());
    await tester.ensureVisible(find.text('让我知道你在哪'));
    await tester.tap(find.text('让我知道你在哪'));
    await _advance(tester);
    expect(find.textContaining('暂时未能获取位置'), findsOneWidget);
    expect(find.text('让我知道你在哪'), findsOneWidget);
  });

  testWidgets(
    'pending location is visible and repeated taps do not start another request',
    (tester) async {
      final api = _Api()..fail = false;
      gps.gate = Completer<Position>();
      await _show(tester, api);
      await tester.ensureVisible(find.text('让我知道你在哪'));
      await tester.tap(find.text('让我知道你在哪'));
      await _advance(tester);
      expect(find.text('正在获取位置…'), findsOneWidget);
      await tester.tap(find.text('正在获取位置…'));
      expect(gps.requests, 1);
      gps.gate!.complete(_position());
      await _advance(tester);
      expect(find.text('正在获取位置…'), findsNothing);
      expect(api.saves, 1);
    },
  );
  testWidgets(
    'automatic location retries transient failures on the next visit',
    (tester) async {
      final api = _Api()..fail = false;
      gps.unavailable = true;
      Widget home(bool active) => CupertinoApp(
        home: OfflineInteractionPage(
          api: api,
          session: _session,
          agentName: '伙伴',
          active: active,
        ),
      );
      tester.view.physicalSize = const Size(430, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(home(true));
      await _advance(tester);
      expect(gps.requests, 2);
      await tester.pumpWidget(home(false));
      gps.unavailable = false;
      await tester.pumpWidget(home(true));
      await _advance(tester);
      expect(gps.requests, 3);
      expect(api.saves, 1);
      await tester.pumpWidget(home(false));
      await tester.pumpWidget(home(true));
      await _advance(tester);
      expect(gps.requests, 3);
    },
  );
}
