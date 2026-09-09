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
  });

  final double latitude;
  final double longitude;
  final String permissionStatus;
  final String? city;
  final String? region;
  final String? country;
  final String? address;
  final double? accuracyMeters;

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

/// Reads the current device location and optionally syncs coarse profile location.
Future<DeviceLocationSnapshot?> requestCurrentDeviceLocation({
  CompanionApi? api,
  bool openSettingsWhenBlocked = false,
  bool syncUserProfile = false,
}) async {
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (api != null) {
        await api.saveUserLocation(permissionStatus: 'service_disabled');
      }
      if (openSettingsWhenBlocked) {
        await Geolocator.openLocationSettings();
      }
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (api != null) {
        await api.saveUserLocation(permissionStatus: permission.name);
      }
      if (openSettingsWhenBlocked) {
        await Geolocator.openAppSettings();
      }
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        timeLimit: Duration(seconds: 15),
      ),
    );

    String? city;
    String? region;
    String? country;
    String? address;
    try {
      final places = await geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (places.isNotEmpty) {
        final place = places.first;
        city = _firstNonEmpty([
          place.locality,
          place.subAdministrativeArea,
          place.administrativeArea,
        ]);
        region = _firstNonEmpty([
          place.administrativeArea,
          place.subAdministrativeArea,
        ]);
        country = _firstNonEmpty([
          place.country,
          place.isoCountryCode,
        ]);
        final composed = _composeAddress(place).trim();
        if (composed.isNotEmpty) {
          address = composed;
        }
      }
    } catch (_) {
      // Coordinates are still useful even when reverse geocoding fails.
    }

    if (syncUserProfile && api != null) {
      await api.saveUserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        city: city,
        region: region,
        country: country,
        permissionStatus: permission.name,
      );
    }

    return DeviceLocationSnapshot(
      latitude: position.latitude,
      longitude: position.longitude,
      permissionStatus: permission.name,
      city: city,
      region: region,
      country: country,
      address: address,
      accuracyMeters: position.accuracy,
    );
  } catch (_) {
    return null;
  }
}
