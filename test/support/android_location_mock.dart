import 'package:companion_flutter/src/services/android_location_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

/// Adapt existing UI GPS fixtures to the Android platform-channel boundary.
/// Late callbacks intentionally remain possible, to test the Dart exit guards.
void mockAndroidLocation(
  Future<Position> Function() read, {
  List<int>? cancelled,
}) {
  AndroidLocationSession.resetForTesting();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(AndroidLocationSession.channel, (call) async {
        if (call.method == 'cancel') {
          cancelled?.add((call.arguments as Map)['id'] as int);
          return null;
        }
        final position = await read();
        return position.toJson();
      });
}
