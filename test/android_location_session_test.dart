import 'dart:async';
import 'package:companion_flutter/src/services/device_location.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

class _Gps extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.whileInUse;
  bool enabled = true;
  int prompts = 0;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> requestPermission() async {
    prompts++;
    return permission;
  }
}

Map<String, dynamic> position({
  int age = 0,
  double accuracy = 10,
  double latitude = 31.2,
}) => {
  'latitude': latitude,
  'longitude': 121.4,
  'accuracy': accuracy,
  'timestamp': DateTime.now()
      .subtract(Duration(seconds: age))
      .millisecondsSinceEpoch,
  'altitude': 0.0,
  'heading': 0.0,
  'speed': 0.0,
};

void locationTest(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    try {
      await body(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GeolocatorPlatform oldGps;
  late _Gps gps;
  final reads = <(int, bool, Completer<Map<String, dynamic>>)>[];
  final cancelled = <int>[];
  setUp(() {
    oldGps = GeolocatorPlatform.instance;
    gps = _Gps();
    GeolocatorPlatform.instance = gps;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidLocationSession.resetForTesting();
    reads.clear();
    cancelled.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidLocationSession.channel, (call) async {
          final args = call.arguments as Map;
          if (call.method == 'cancel') {
            cancelled.add(args['id'] as int);
            return null;
          }
          final result = Completer<Map<String, dynamic>>();
          reads.add((args['id'] as int, args['fresh'] as bool, result));
          return result.future;
        });
  });
  tearDown(() {
    GeolocatorPlatform.instance = oldGps;
    debugDefaultTargetPlatformOverride = null;
    AndroidLocationSession.resetForTesting();
  });

  locationTest('prewarm never prompts and iOS never opens the channel', (
    tester,
  ) async {
    final session = AndroidLocationSession();
    for (final permission in [
      LocationPermission.denied,
      LocationPermission.deniedForever,
    ]) {
      gps.permission = permission;
      await session.prewarm();
    }
    gps.permission = LocationPermission.whileInUse;
    gps.enabled = false;
    await session.prewarm();
    gps.enabled = true;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await session.prewarm();
    expect(reads, isEmpty);
    expect(gps.prompts, 0);
    session.close();
  });

  locationTest(
    'prewarm is shared by chat and arrival; observation time is preserved',
    (tester) async {
      final panel = AndroidLocationSession();
      final arrival = AndroidLocationSession();
      final warming = panel.prewarm();
      await tester.pump();
      final preview = requestDeviceLocationResult(
        purpose: DeviceLocationPurpose.chatPreview,
        androidSession: panel,
      );
      final checkin = requestDeviceLocationResult(
        purpose: DeviceLocationPurpose.arrival,
        androidSession: arrival,
      );
      await tester.pump();
      expect(reads, hasLength(1));
      final raw = position(age: 2);
      reads.single.$3.complete(raw);
      await tester.pump();
      await warming;
      final first = (await preview).snapshot!;
      final second = (await checkin).snapshot!;
      expect(second.observedAt, first.observedAt);
      expect(second.address, isNull);
      expect(first.observedAt!.millisecondsSinceEpoch, raw['timestamp']);
      await panel.read();
      expect(reads, hasLength(1));
      panel.close();
      arrival.close();
      await tester.pump();
      expect(cancelled, contains(reads.single.$1));
    },
  );

  locationTest(
    'last owner cancels immediately; a late result cannot seed reuse',
    (tester) async {
      final first = AndroidLocationSession();
      final second = AndroidLocationSession();
      final a = first.read();
      final b = second.read();
      final aError = expectLater(a, throwsStateError);
      final bError = expectLater(b, throwsStateError);
      await tester.pump();
      first.close();
      await tester.pump();
      expect(cancelled, isEmpty);
      second.close();
      await tester.pump();
      await aError;
      await bError;
      expect(cancelled, contains(reads.single.$1));
      reads.single.$3.complete(position());
      await tester.pump();
      final next = AndroidLocationSession();
      final c = next.read();
      await tester.pump();
      expect(reads, hasLength(2));
      reads.last.$3.complete(position());
      await c;
      next.close();
      await tester.pump();
    },
  );

  locationTest('coarse chat positions are never reused as verified arrival', (
    tester,
  ) async {
    final chat = AndroidLocationSession.chat();
    final preview = chat.read();
    await tester.pump();
    reads.single.$3.complete(position(accuracy: 500));
    expect((await preview).accuracy, 500);
    final arrival = AndroidLocationSession();
    final checkin = arrival.read();
    await tester.pump();
    expect(reads, hasLength(2));
    reads.last.$3.complete(position(accuracy: 20));
    expect((await checkin).accuracy, 20);
    chat.close();
    arrival.close();
    await tester.pump();
  });

  locationTest(
    'explicit refresh bypasses recent position and requests fresh native data',
    (tester) async {
      final session = AndroidLocationSession();
      final first = session.read();
      await tester.pump();
      reads.single.$3.complete(position());
      await first;
      final refresh = session.read(fresh: true);
      await tester.pump();
      expect(reads, hasLength(2));
      expect(reads.last.$2, isTrue);
      reads.last.$3.complete(position(latitude: 32.1));
      expect((await refresh).latitude, 32.1);
      session.close();
      await tester.pump();
    },
  );

  for (final (name, raw) in [
    ('stale', () => position(age: 16)),
    ('future', () => position(age: -1)),
    ('inaccurate', () => position(accuracy: 101)),
    ('zero accuracy', () => position(accuracy: 0)),
    ('invalid coordinate', () => position(latitude: double.nan)),
  ]) {
    locationTest('rejects $name native fixes', (tester) async {
      final session = AndroidLocationSession();
      final result = requestDeviceLocationResult(
        purpose: DeviceLocationPurpose.arrival,
        androidSession: session,
      );
      await tester.pump();
      reads.single.$3.complete(raw());
      await tester.pump();
      expect((await result).snapshot, isNull);
      session.close();
    });
  }

  locationTest(
    'hung channel has one deadline and cancels without serial retries',
    (tester) async {
      final session = AndroidLocationSession();
      final result = requestDeviceLocationResult(
        purpose: DeviceLocationPurpose.chatPreview,
        androidSession: session,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 9));
      expect((await result).failure, DeviceLocationFailure.timeout);
      expect(reads, hasLength(1));
      expect(cancelled, contains(reads.single.$1));
      session.close();
    },
  );

  locationTest(
    'closing while permission check is pending leaves no timers or native read',
    (tester) async {
      final session = AndroidLocationSession();
      final warming = session.prewarm();
      session.close();
      await tester.pump();
      await warming;
      expect(reads, isEmpty);
    },
  );
}
