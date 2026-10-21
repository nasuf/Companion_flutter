import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';

/// Requests foreground location in the same launch flow as notifications.
/// Only permission is requested here; GPS and profile sync remain on demand.
class StartupLocationPermission {
  StartupLocationPermission({
    Future<Directory> Function()? applicationSupportDirectory,
  }) : _applicationSupportDirectory =
           applicationSupportDirectory ?? getApplicationSupportDirectory;

  static final instance = StartupLocationPermission();
  final Future<Directory> Function() _applicationSupportDirectory;
  Future<void>? _request;

  Future<void> requestOnce() => _request ??= _requestOnce();

  Future<void> _requestOnce() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }

    File? marker;
    try {
      final directory = await _applicationSupportDirectory().timeout(
        const Duration(seconds: 3),
      );
      // App-local storage is removed on uninstall, unlike the iOS Keychain.
      marker = File('${directory.path}/startup_location_permission_v1');
      if (await marker.exists()) return;
    } catch (error) {
      debugPrint(
        'startup_location stage=read_marker error=${error.runtimeType}',
      );
    }

    try {
      final permission = await Geolocator.checkPermission().timeout(
        const Duration(seconds: 3),
      );
      if (permission == LocationPermission.denied) {
        // Await the user's choice, without starting a GPS request or settings.
        await Geolocator.requestPermission();
      }
    } catch (error) {
      debugPrint(
        'startup_location stage=permission error=${error.runtimeType}',
      );
      return;
    }

    if (marker == null) return;
    try {
      await marker.parent.create(recursive: true);
      await marker.writeAsString('requested', flush: true);
    } catch (error) {
      debugPrint(
        'startup_location stage=write_marker error=${error.runtimeType}',
      );
    }
  }
}
