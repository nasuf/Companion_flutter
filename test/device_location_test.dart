import 'package:companion_flutter/src/services/device_location.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class _Gps extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => Position(
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

class _Geocoder extends GeocodingPlatform {
  final calls = <String>[];
  bool localeUnsupported = false;
  bool lookupFails = false;
  String? district = '京口区';

  @override
  Future<void> setLocaleIdentifier(String localeIdentifier) async {
    calls.add(localeIdentifier);
    if (localeUnsupported) throw UnsupportedError('locale');
  }

  @override
  Future<List<Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    calls.add('lookup');
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Geocoder geocoder;
  late GeolocatorPlatform oldGps;
  GeocodingPlatform? oldGeocoder;

  setUp(() {
    oldGps = GeolocatorPlatform.instance;
    oldGeocoder = GeocodingPlatform.instance;
    GeolocatorPlatform.instance = _Gps();
    geocoder = _Geocoder();
    GeocodingPlatform.instance = geocoder;
  });

  tearDown(() {
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
}
