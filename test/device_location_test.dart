import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:companion_flutter/companion_api.dart';
import 'package:flutter/foundation.dart';
import 'package:companion_flutter/src/services/device_location.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class _Gps extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  final requests = <LocationSettings?>[];
  int failures = 0;
  Position? cached;
  Completer<Position>? gate;
  int settingsOpened = 0;
  bool? nativeCache;
  @override
  Future<LocationPermission> requestPermission() async => permission;
  @override
  Future<bool> openAppSettings() async {
    settingsOpened++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    settingsOpened++;
    return true;
  }

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async {
    nativeCache = forceLocationManager;
    return cached;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    requests.add(locationSettings);
    if (failures-- > 0) throw TimeoutException("test position timeout");
    if (gate != null) return gate!.future;
    return Position(
      latitude: 32.2,
      longitude: 119.4,
      timestamp: DateTime(2026, 10, 6),
      accuracy: 10,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

class _Geocoder extends GeocodingPlatform {
  final calls = <String>[];
  bool localeUnsupported = false;
  bool lookupFails = false;
  bool lookupWaits = false;
  Duration lookupDelay = Duration.zero;
  bool localeWaits = false;
  String? district = '京口区';

  @override
  Future<void> setLocaleIdentifier(String localeIdentifier) async {
    calls.add(localeIdentifier);
    if (localeWaits) return Completer<void>().future;
    if (localeUnsupported) throw UnsupportedError('locale');
  }

  @override
  Future<List<Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    calls.add('lookup');
    if (lookupDelay > Duration.zero) await Future<void>.delayed(lookupDelay);
    if (lookupWaits) return Completer<List<Placemark>>().future;
    if (lookupFails) throw StateError('geocoder unavailable');
    return [
      Placemark(
        locality: '镇江市',
        subLocality: district,
        subAdministrativeArea: '句容市',
        administrativeArea: '江苏省',
        thoroughfare: '江滨路',
        subThoroughfare: '18号',
      ),
    ];
  }
}

class _Api extends CompanionApi {
  _Api() : super(baseUrl: 'https://example.test');
  bool fail = false;
  bool accepted = true;
  bool wait = false;
  int saves = 0;
  Duration delay = Duration.zero;
  double? latitude;
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
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    this.latitude = latitude;
    if (fail) throw const ApiException(503, 'unavailable');
    if (wait) return Completer<bool>().future;
    return accepted;
  }
}

Position _cached({
  Duration age = const Duration(seconds: 30),
  double accuracy = 20,
  double latitude = 32.2,
}) => Position(
  latitude: latitude,
  longitude: 119.4,
  timestamp: DateTime.now().subtract(age),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class _RealHttp extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Geocoder geocoder;
  late _Gps gps;
  late GeolocatorPlatform oldGps;
  GeocodingPlatform? oldGeocoder;

  setUp(() {
    oldGps = GeolocatorPlatform.instance;
    oldGeocoder = GeocodingPlatform.instance;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    gps = _Gps();
    GeolocatorPlatform.instance = gps;
    geocoder = _Geocoder();
    GeocodingPlatform.instance = geocoder;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    GeolocatorPlatform.instance = oldGps;
    if (oldGeocoder != null) GeocodingPlatform.instance = oldGeocoder;
  });

  test(
    'localized city and district become the regional search anchor',
    () async {
      final location = await requestCurrentDeviceLocation();
      expect(geocoder.calls, ['zh_CN', 'lookup']);
      expect(location!.city, '镇江市');
      expect(location.region, '京口区');
      expect(location.toComponentCard().payload['region'], '京口区');
      expect(location.accuracyMeters, 10);
      expect(location.observedAt, DateTime(2026, 10, 6));
    },
  );

  test('county remains available when the district is missing', () async {
    geocoder.district = null;
    expect((await requestCurrentDeviceLocation())!.region, '句容市');
  });

  test('unsupported locale override still resolves the location', () async {
    geocoder.localeUnsupported = true;
    final location = await requestCurrentDeviceLocation();
    expect(location!.city, '镇江市');
    expect(location.region, '京口区');
  });

  test('geocoder outage preserves device coordinates and accuracy', () async {
    geocoder.lookupFails = true;
    final location = await requestCurrentDeviceLocation();
    expect(location!.latitude, 32.2);
    expect(location.longitude, 119.4);
    expect(location.accuracyMeters, 10);
    expect(location.city, isNull);
  });

  test('Android uses native location manager after primary timeout', () async {
    gps.failures = 1;
    final result = await requestDeviceLocationResult();
    expect(result.snapshot, isNotNull);
    expect(gps.requests, hasLength(2));
    final fallback = gps.requests.last as AndroidSettings;
    expect(fallback.forceLocationManager, isTrue);
    expect(fallback.accuracy, LocationAccuracy.medium);
  });

  test(
    'recent accurate cache can support profile location after both providers fail',
    () async {
      gps
        ..failures = 2
        ..cached = _cached();
      final result = await requestDeviceLocationResult(allowRecentCache: true);
      expect(result.snapshot!.observedAt, gps.cached!.timestamp);
      expect(gps.nativeCache, isTrue);
    },
  );

  test(
    'stale, imprecise, future and invalid cached positions are rejected',
    () async {
      for (final cached in [
        _cached(age: const Duration(minutes: 3)),
        _cached(accuracy: 101),
        _cached(age: const Duration(seconds: -30)),
        _cached(latitude: double.nan),
        _cached(accuracy: 0),
      ]) {
        gps
          ..failures = 2
          ..cached = cached;
        final result = await requestDeviceLocationResult(
          allowRecentCache: true,
        );
        expect(result.snapshot, isNull);
        expect(result.failure, DeviceLocationFailure.timeout);
      }
    },
  );

  test(
    'arrival-compatible API never falls back to cached coordinates',
    () async {
      gps
        ..failures = 2
        ..cached = _cached();
      expect(await requestCurrentDeviceLocation(), isNull);
    },
  );

  test(
    'profile synchronization failure preserves coordinates and supports retry',
    () async {
      final api = _Api()..fail = true;
      final failed = await requestDeviceLocationResult(
        api: api,
        syncUserProfile: true,
      );
      expect(failed.snapshot!.latitude, 32.2);
      expect(failed.profileSaved, isFalse);
      expect(failed.failure, DeviceLocationFailure.profileSyncFailed);
      api.fail = false;
      final retried = await requestDeviceLocationResult(
        api: api,
        syncUserProfile: true,
      );
      expect(retried.profileSaved, isTrue);
      expect(api.saves, 2);
    },
  );

  test(
    'legacy snapshot API preserves local position when upload fails',
    () async {
      expect(
        await requestCurrentDeviceLocation(
          api: _Api()..fail = true,
          syncUserProfile: true,
        ),
        isNotNull,
      );
    },
  );

  test('server has_location false must not be reported as saved', () async {
    final result = await requestDeviceLocationResult(
      api: _Api()..accepted = false,
      syncUserProfile: true,
    );
    expect(result.profileSaved, isFalse);
    expect(result.failure, DeviceLocationFailure.profileRejected);
    expect(result.message, contains("服务器未确认保存"));
    expect(result.message, isNot(contains("网络")));
  });

  for (final stage in ['locale', 'lookup']) {
    test('stalled $stage does not block saving acquired coordinates', () async {
      geocoder.localeWaits = stage == 'locale';
      geocoder.lookupWaits = stage == 'lookup';
      final api = _Api();
      final result = await requestDeviceLocationResult(
        api: api,
        syncUserProfile: true,
      );
      expect(result.profileSaved, isTrue);
      expect(api.latitude, 32.2);
      expect(result.snapshot!.city, isNull);
    });
  }

  test('stalled upload times out with coordinates still available', () async {
    final result = await requestDeviceLocationResult(
      api: _Api()..wait = true,
      syncUserProfile: true,
    );
    expect(result.snapshot, isNotNull);
    expect(result.failure, DeviceLocationFailure.profileSyncFailed);
  });

  test(
    'blocked permission opens settings even when status upload fails',
    () async {
      gps.permission = LocationPermission.deniedForever;
      final result = await requestDeviceLocationResult(
        api: _Api()..fail = true,
        openSettingsWhenBlocked: true,
      );
      expect(result.failure, DeviceLocationFailure.permissionDeniedForever);
      expect(gps.settingsOpened, 1);
      expect(gps.requests, isEmpty);
    },
  );

  test('disabled location service returns a distinct failure', () async {
    gps.enabled = false;
    final result = await requestDeviceLocationResult(
      openSettingsWhenBlocked: true,
    );
    expect(result.failure, DeviceLocationFailure.serviceDisabled);
    expect(gps.settingsOpened, 1);
  });

  test(
    'overlapping activity requests share one GPS and upload operation',
    () async {
      gps.gate = Completer<Position>();
      final api = _Api();
      final first = requestDeviceLocationResult(
        api: api,
        syncUserProfile: true,
        allowRecentCache: true,
      );
      final second = requestDeviceLocationResult(
        api: api,
        syncUserProfile: true,
        allowRecentCache: true,
      );
      expect(identical(first, second), isTrue);
      await Future<void>.delayed(Duration.zero);
      gps.gate!.complete(_cached(age: Duration.zero));
      expect((await first).profileSaved, isTrue);
      expect(gps.requests, hasLength(1));
      expect(api.saves, 1);
    },
  );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    test(
      '$platform saves through real HTTP and decodes a confirmed location',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        await HttpOverrides.runZoned(() async {
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          final requests = <Map<String, dynamic>>[];
          final listener = server.listen((request) async {
            expect(request.method, 'PUT');
            expect(request.uri.path, '/users/me/location');
            final body =
                jsonDecode(await utf8.decoder.bind(request).join())
                    as Map<String, dynamic>;
            requests.add(body);
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode({
                'has_location': true,
                'latitude': body['latitude'],
                'longitude': body['longitude'],
                'permission_status': body['permission_status'],
                'updated_at': '2026-10-21T06:31:00+00:00',
              }),
            );
            await request.response.close();
          });
          try {
            final api = CompanionApi(
              baseUrl: 'http://127.0.0.1:${server.port}',
            );
            final result = await requestDeviceLocationResult(
              api: api,
              syncUserProfile: true,
            );
            expect(result.profileSaved, isTrue);
            expect(result.failure, isNull);
            expect(requests.single['permission_status'], 'whileInUse');
            expect(requests.single['latitude'], 32.2);
            expect(gps.requests, hasLength(1));
            expect(
              gps.requests.single!.accuracy,
              platform == TargetPlatform.iOS
                  ? LocationAccuracy.best
                  : LocationAccuracy.high,
            );
          } finally {
            await listener.cancel();
            await server.close(force: true);
          }
        }, createHttpClient: _RealHttp().createHttpClient);
      },
    );
  }

  testWidgets(
    'iOS preserves successful synchronization beyond the Android timeout',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final api = _Api()..delay = const Duration(seconds: 10);
        DeviceLocationResult? result;
        final pending = requestDeviceLocationResult(
          api: api,
          syncUserProfile: true,
        ).then((value) => result = value);
        await tester.pump();
        expect(api.saves, 1);
        await tester.pump(const Duration(seconds: 9));
        expect(result, isNull);
        await tester.pump(const Duration(seconds: 2));
        await pending;
        expect(result!.profileSaved, isTrue);
        expect(result!.failure, isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
  testWidgets(
    'iOS retains city when address lookup takes longer than the Android budget',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        geocoder.lookupDelay = const Duration(seconds: 5);
        DeviceLocationResult? result;
        final pending = requestDeviceLocationResult(
          api: _Api(),
          syncUserProfile: true,
        ).then((value) => result = value);
        await tester.pump();
        await tester.pump(const Duration(seconds: 4));
        expect(result, isNull);
        await tester.pump(const Duration(seconds: 2));
        await pending;
        expect(result!.profileSaved, isTrue);
        expect(result!.snapshot!.city, '镇江市');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
