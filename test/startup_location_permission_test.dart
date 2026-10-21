import 'dart:async';
import 'dart:io';

import 'package:companion_flutter/src/services/startup_location_permission.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

class _Gps extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.denied;
  LocationPermission answer = LocationPermission.whileInUse;
  Completer<LocationPermission>? response;
  Object? failure;
  int checks = 0;
  int prompts = 0;
  int positions = 0;
  int settings = 0;

  @override
  Future<LocationPermission> checkPermission() async {
    checks++;
    if (failure != null) throw failure!;
    return permission;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    prompts++;
    return response?.future ?? Future.value(answer);
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    positions++;
    throw StateError('startup must not request GPS');
  }

  @override
  Future<bool> openAppSettings() async {
    settings++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    settings++;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GeolocatorPlatform previous;
  late _Gps gps;
  late Directory directory;

  setUp(() async {
    previous = GeolocatorPlatform.instance;
    gps = _Gps();
    GeolocatorPlatform.instance = gps;
    directory = await Directory.systemTemp.createTemp('startup-location-test-');
  });
  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    GeolocatorPlatform.instance = previous;
    await directory.delete(recursive: true);
  });

  StartupLocationPermission service() => StartupLocationPermission(
    applicationSupportDirectory: () async => directory,
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final answer in [
      LocationPermission.whileInUse,
      LocationPermission.denied,
    ]) {
      test('$platform first launch asks once and remembers $answer', () async {
        debugDefaultTargetPlatformOverride = platform;
        gps.answer = answer;
        await service().requestOnce();
        // A new service instance represents another app process/launch.
        await service().requestOnce();
        expect(gps.prompts, 1);
        expect(gps.positions, 0);
        expect(gps.settings, 0);
      });
    }
    for (final permission in [
      LocationPermission.whileInUse,
      LocationPermission.always,
      LocationPermission.deniedForever,
    ]) {
      test('$platform skips native prompting for $permission', () async {
        debugDefaultTargetPlatformOverride = platform;
        gps.permission = permission;
        await service().requestOnce();
        expect(gps.checks, 1);
        expect(gps.prompts, 0);
        expect(gps.positions, 0);
        expect(gps.settings, 0);
      });
    }
  }

  test(
    'overlapping startup calls share one pending permission dialog',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      gps.response = Completer<LocationPermission>();
      final coordinator = service();
      final first = coordinator.requestOnce();
      final second = coordinator.requestOnce();
      expect(identical(first, second), isTrue);
      while (gps.prompts == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      gps.response!.complete(LocationPermission.denied);
      await Future.wait([first, second]);
      expect(gps.prompts, 1);
    },
  );

  test(
    'permission errors allow launch and a later startup can retry',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      gps.failure = StateError('temporary plugin failure');
      await service().requestOnce();
      gps.failure = null;
      await service().requestOnce();
      expect(gps.prompts, 1);
    },
  );

  test(
    'marker storage failure does not prevent the permission request',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await StartupLocationPermission(
        applicationSupportDirectory: () async => throw StateError('storage'),
      ).requestOnce();
      expect(gps.prompts, 1);
    },
  );

  test('desktop startup skips location prompting', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await service().requestOnce();
    expect(gps.checks, 0);
    expect(gps.prompts, 0);
  });

  test('a new installation can request permission again', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    gps.answer = LocationPermission.denied;
    await service().requestOnce();
    await directory.delete(recursive: true);
    await directory.create();
    await service().requestOnce();
    expect(gps.prompts, 2);
  });
}
