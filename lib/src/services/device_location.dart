import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';

import '../../companion_api.dart';
import '../../models.dart';

/// Result of a one-shot device location read (system GPS + reverse geocoding).
class DeviceLocationSnapshot {
  const DeviceLocationSnapshot({
    required this.latitude,
    required this.longitude,
    required this.permissionStatus,
    this.city,
    this.region,
    this.country,
    this.address,
    this.accuracyMeters,
    this.observedAt,
  });

  final double latitude;
  final double longitude;
  final String permissionStatus;
  final String? city;
  final String? region;
  final String? country;
  final String? address;
  final double? accuracyMeters;
  final DateTime? observedAt;

  String get displayTitle {
    final cityLabel = _firstNonEmpty([city, region]);
    if (cityLabel != null && cityLabel.isNotEmpty) {
      return cityLabel;
    }
    return '我的位置';
  }

  String get displaySubtitle {
    return _firstNonEmpty([address, region, city, country]) ?? '当前位置';
  }

  ChatComponentCard toComponentCard() {
    return ChatComponentCard(
      type: 'location',
      title: displayTitle,
      subtitle: displaySubtitle,
      body: _firstNonEmpty([region, city]) ?? '',
      footer: '刚刚',
      accent: '#22C66B',
      payload: {
        'latitude': latitude,
        'longitude': longitude,
        if (address != null && address!.isNotEmpty) 'address': address,
        if (city != null && city!.isNotEmpty) 'city': city,
        if (region != null && region!.isNotEmpty) 'region': region,
        if (country != null && country!.isNotEmpty) 'country': country,
        if (accuracyMeters != null) 'accuracy_meters': accuracyMeters,
        'source': 'device',
      },
    );
  }
}

String? _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

String _composeAddress(geocoding.Placemark place) {
  final parts = <String>[
    if ((place.subThoroughfare ?? '').trim().isNotEmpty)
      place.subThoroughfare!.trim(),
    if ((place.thoroughfare ?? '').trim().isNotEmpty)
      place.thoroughfare!.trim(),
    if ((place.subLocality ?? '').trim().isNotEmpty) place.subLocality!.trim(),
    if ((place.locality ?? '').trim().isNotEmpty) place.locality!.trim(),
    if ((place.subAdministrativeArea ?? '').trim().isNotEmpty)
      place.subAdministrativeArea!.trim(),
    if ((place.administrativeArea ?? '').trim().isNotEmpty)
      place.administrativeArea!.trim(),
  ];
  return parts.join('');
}

enum DeviceLocationFailure {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unavailable,
  profileSyncFailed,
  profileRejected,
}

class DeviceLocationResult {
  const DeviceLocationResult({
    this.snapshot,
    this.failure,
    this.profileSaved = false,
  });

  final DeviceLocationSnapshot? snapshot;
  final DeviceLocationFailure? failure;
  final bool profileSaved;

  String? get message => switch (failure) {
    DeviceLocationFailure.serviceDisabled => '手机定位服务未开启，请在系统设置中开启后重试。',
    DeviceLocationFailure.permissionDenied => '尚未获得位置权限，请允许使用位置后重试。',
    DeviceLocationFailure.permissionDeniedForever =>
      '位置权限已被关闭，请在应用设置中允许使用位置后重试。',
    DeviceLocationFailure.timeout => '暂时未能获取位置，请确认系统定位已开启，移到窗边或室外后重试。',
    DeviceLocationFailure.unavailable => '暂时无法获取位置，请检查系统定位服务后重试。',
    DeviceLocationFailure.profileSyncFailed => '已获取手机位置，但同步暂未完成，请稍后重试。',
    DeviceLocationFailure.profileRejected => '已获取手机位置，但服务器未确认保存，请稍后重试。',
    null => null,
  };
}

// Join an automatic request when the user taps the activity card mid-flight.
final _pendingLocationRequests =
    <(CompanionApi?, bool, bool), Future<DeviceLocationResult>>{};

Future<DeviceLocationResult> requestDeviceLocationResult({
  CompanionApi? api,
  bool openSettingsWhenBlocked = false,
  bool syncUserProfile = false,
  bool allowRecentCache = false,
}) {
  final key = (api, syncUserProfile, allowRecentCache);
  final pending = _pendingLocationRequests[key];
  if (pending != null) return pending;
  final future =
      _requestDeviceLocation(
        api: api,
        openSettingsWhenBlocked: openSettingsWhenBlocked,
        syncUserProfile: syncUserProfile,
        allowRecentCache: allowRecentCache,
      ).whenComplete(() {
        _pendingLocationRequests.remove(key);
      });
  _pendingLocationRequests[key] = future;
  return future;
}

/// Compatibility API for chat and arrival verification. Profile sync failure
/// must not discard an already acquired device position.
Future<DeviceLocationSnapshot?> requestCurrentDeviceLocation({
  CompanionApi? api,
  bool openSettingsWhenBlocked = false,
  bool syncUserProfile = false,
}) async => (await requestDeviceLocationResult(
  api: api,
  openSettingsWhenBlocked: openSettingsWhenBlocked,
  syncUserProfile: syncUserProfile,
  allowRecentCache: syncUserProfile,
)).snapshot;

void _logLocationFailure(String stage, Object error) {
  // No coordinates, user identifiers, API payloads or tokens in device logs.
  debugPrint('device_location stage=$stage error=${error.runtimeType}');
}

Future<void> _recordBlockedLocation(CompanionApi? api, String status) async {
  if (api == null) return;
  try {
    await api
        .saveUserLocation(permissionStatus: status)
        .timeout(const Duration(seconds: 3));
  } catch (error) {
    _logLocationFailure('permission_sync', error);
  }
}

bool _validCoordinates(Position position) =>
    position.latitude.isFinite &&
    position.latitude.abs() <= 90 &&
    position.longitude.isFinite &&
    position.longitude.abs() <= 180 &&
    position.accuracy.isFinite &&
    position.accuracy >= 0;

Future<Position> _readDevicePosition({required bool allowRecentCache}) async {
  Object? failure;
  final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final settings = <LocationSettings>[
    LocationSettings(
      accuracy: android ? LocationAccuracy.high : LocationAccuracy.best,
      timeLimit: Duration(seconds: 15),
    ),
    if (android)
      AndroidSettings(
        forceLocationManager: true,
        accuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
        intervalDuration: const Duration(seconds: 1),
      ),
  ];
  for (final setting in settings) {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: setting,
      ).timeout(setting.timeLimit!);
      if (!_validCoordinates(position)) throw StateError('Invalid position');
      return position;
    } on PermissionDeniedException {
      rethrow;
    } on LocationServiceDisabledException {
      rethrow;
    } catch (error) {
      failure = error;
      _logLocationFailure(
        setting is AndroidSettings ? 'system_position' : 'position',
        error,
      );
    }
  }
  if (allowRecentCache) {
    try {
      final cached = await Geolocator.getLastKnownPosition(
        forceAndroidLocationManager: android,
      ).timeout(const Duration(seconds: 2));
      if (cached != null &&
          _validCoordinates(cached) &&
          cached.accuracy > 0 &&
          cached.accuracy <= 100) {
        final age = DateTime.now().difference(cached.timestamp);
        if (!age.isNegative && age <= const Duration(minutes: 2)) return cached;
      }
    } on PermissionDeniedException {
      rethrow;
    } on LocationServiceDisabledException {
      rethrow;
    } catch (error) {
      _logLocationFailure('cached_position', error);
    }
  }
  throw failure ?? StateError('Position unavailable');
}

Future<List<geocoding.Placemark>> _readAddress(Position position) async {
  try {
    await geocoding.setLocaleIdentifier('zh_CN');
  } catch (_) {
    // Locale override is optional; the lookup still runs when unsupported.
  }
  return geocoding.placemarkFromCoordinates(
    position.latitude,
    position.longitude,
  );
}

Future<DeviceLocationResult> _requestDeviceLocation({
  required CompanionApi? api,
  required bool openSettingsWhenBlocked,
  required bool syncUserProfile,
  required bool allowRecentCache,
}) async {
  final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
      const Duration(seconds: 3),
    );
    if (!serviceEnabled) {
      await _recordBlockedLocation(api, 'service_disabled');
      if (openSettingsWhenBlocked) {
        await Geolocator.openLocationSettings().timeout(
          const Duration(seconds: 3),
        );
      }
      return const DeviceLocationResult(
        failure: DeviceLocationFailure.serviceDisabled,
      );
    }
    var permission = await Geolocator.checkPermission().timeout(
      const Duration(seconds: 3),
    );
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      await _recordBlockedLocation(api, permission.name);
      if (openSettingsWhenBlocked &&
          permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings().timeout(const Duration(seconds: 3));
      }
      return DeviceLocationResult(
        failure: permission == LocationPermission.deniedForever
            ? DeviceLocationFailure.permissionDeniedForever
            : DeviceLocationFailure.permissionDenied,
      );
    }

    final position = await _readDevicePosition(
      allowRecentCache: allowRecentCache,
    );
    String? city;
    String? region;
    String? country;
    String? address;
    try {
      final places = await _readAddress(
        position,
      ).timeout(Duration(seconds: android ? 3 : 10));
      if (places.isNotEmpty) {
        final place = places.first;
        city = _firstNonEmpty([
          place.locality,
          place.subAdministrativeArea,
          place.administrativeArea,
        ]);
        region = _firstNonEmpty([
          place.subLocality,
          place.subAdministrativeArea,
          place.administrativeArea,
        ]);
        country = _firstNonEmpty([place.country, place.isoCountryCode]);
        final composed = _composeAddress(place).trim();
        if (composed.isNotEmpty) address = composed;
      }
    } catch (error) {
      _logLocationFailure('reverse_geocoding', error);
    }
    final snapshot = DeviceLocationSnapshot(
      latitude: position.latitude,
      longitude: position.longitude,
      permissionStatus: permission.name,
      city: city,
      region: region,
      country: country,
      address: address,
      accuracyMeters: position.accuracy,
      observedAt: position.timestamp,
    );
    if (syncUserProfile && api != null) {
      try {
        final saved = await api
            .saveUserLocation(
              latitude: position.latitude,
              longitude: position.longitude,
              city: city,
              region: region,
              country: country,
              permissionStatus: permission.name,
            )
            .timeout(Duration(seconds: android ? 8 : 30));
        return DeviceLocationResult(
          snapshot: snapshot,
          profileSaved: saved,
          failure: saved ? null : DeviceLocationFailure.profileRejected,
        );
      } catch (error) {
        _logLocationFailure('profile_sync', error);
        return DeviceLocationResult(
          snapshot: snapshot,
          failure: DeviceLocationFailure.profileSyncFailed,
        );
      }
    }
    return DeviceLocationResult(snapshot: snapshot);
  } on PermissionDeniedException {
    return const DeviceLocationResult(
      failure: DeviceLocationFailure.permissionDenied,
    );
  } on LocationServiceDisabledException {
    return const DeviceLocationResult(
      failure: DeviceLocationFailure.serviceDisabled,
    );
  } on TimeoutException {
    return const DeviceLocationResult(failure: DeviceLocationFailure.timeout);
  } catch (error) {
    _logLocationFailure('request', error);
    return const DeviceLocationResult(
      failure: DeviceLocationFailure.unavailable,
    );
  }
}
