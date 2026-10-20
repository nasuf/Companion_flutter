import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:companion_flutter/offline_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

const _name = '春树·花艺 (常发广场店) & 咖啡';
const _address = '黄山西路常发广场5号楼102';
const _display = '镇江市 $_address';
const _urlChannel = MethodChannel('plugins.flutter.io/url_launcher');

class _Api extends CompanionApi {
  _Api(this.activity) : super(baseUrl: 'https://example.test');
  final OfflineActivity activity;

  @override
  Future<OfflineActivity> fetchOfflineActivity(String id) async => activity;
}

class _Geocoder extends geocoding.GeocodingPlatform {
  final queries = <String>[];

  @override
  Future<List<geocoding.Location>> locationFromAddress(String address) async {
    queries.add(address);
    return [];
  }
}

Future<void> _openLocation(
  WidgetTester tester,
  TargetPlatform platform, {
  bool hasCoordinates = true,
  String coordinateSystem = 'gcj02',
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final activity = OfflineActivity.fromJson({
    'id': 'activity',
    'status': 'accepted',
    'title': _name,
    'location_name': _name,
    'address': _address,
    'city': '镇江市',
    'summary': '顺路看看花艺',
    if (hasCoordinates) 'place_lat': 32.203,
    if (hasCoordinates) 'place_lng': 119.451,
    'coordinate_system': coordinateSystem,
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      home: OfflineCheckinPage(
        api: _Api(activity),
        session: const AuthSession(
          token: 'test',
          userId: 'user',
          username: 'tester',
          role: UserRole.user,
          hasAgent: true,
        ),
        activityId: activity.id,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('查看位置'));
  await tester.pumpAndSettle();
  expect(find.text(_display), findsOneWidget);
}

void main() {
  final calls = <MethodCall>[];
  late _Geocoder geocoder;
  var installed = true;
  var launchResult = true;
  var throwNative = false;
  var systemResult = true;

  setUp(() {
    calls.clear();
    installed = true;
    launchResult = true;
    throwNative = false;
    systemResult = true;
    geocoder = _Geocoder();
    geocoding.GeocodingPlatform.instance = geocoder;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_urlChannel, (call) async {
          calls.add(call);
          if (call.method == 'canLaunch') return installed;
          final uri = Uri.parse((call.arguments as Map)['url'] as String);
          if (uri.scheme == 'iosamap' || uri.scheme == 'amapuri') {
            if (throwNative) throw PlatformException(code: 'unavailable');
            return launchResult;
          }
          return systemResult;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_urlChannel, null);
  });

  Future<void> navigate(WidgetTester tester) async {
    expect(calls, isEmpty);
    await tester.tap(find.text('导航前往'));
    await tester.pumpAndSettle();
    expect(find.text('位置'), findsNothing);
    for (final call in calls.where((call) => call.method == 'launch')) {
      final args = call.arguments as Map;
      expect(args['useSafariVC'], isFalse);
      expect(args['useWebView'], isFalse);
      final uri = Uri.parse(args['url'] as String);
      expect(uri.host, isNot('navi'));
      expect(uri.queryParameters, isNot(contains('style')));
    }
    expect(tester.takeException(), isNull);
  }

  List<Uri> launches() => [
    for (final call in calls.where((call) => call.method == 'launch'))
      Uri.parse((call.arguments as Map)['url'] as String),
  ];

  void expectSystem(TargetPlatform platform, Uri uri) {
    expect(uri.scheme, platform == TargetPlatform.iOS ? 'http' : 'geo');
    expect(uri.queryParameters['q'], _display);
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final coordinates in ['gcj02', 'wgs84']) {
      testWidgets('$platform $coordinates opens route planning from activity', (
        tester,
      ) async {
        await _openLocation(tester, platform, coordinateSystem: coordinates);
        await navigate(tester);
        final uri = launches().single;
        expect(
          uri.scheme,
          platform == TargetPlatform.iOS ? 'iosamap' : 'amapuri',
        );
        expect(uri.host, platform == TargetPlatform.iOS ? 'path' : 'route');
        expect(uri.path, platform == TargetPlatform.iOS ? '' : '/plan/');
        expect(uri.queryParameters, {
          'sourceApplication': '伴生',
          'dname': _name,
          'dlat': '32.203',
          'dlon': '119.451',
          'dev': coordinates == 'wgs84' ? '1' : '0',
          't': '0',
          'm': '0',
        });
        expect(geocoder.queries, isEmpty);
        expect(calls.map((call) => call.method), ['canLaunch', 'launch']);
      });
    }

    for (final failure in ['not installed', 'returns false', 'throws']) {
      testWidgets('$platform native $failure opens system map', (tester) async {
        installed = failure != 'not installed';
        launchResult = failure != 'returns false';
        throwNative = failure == 'throws';
        await _openLocation(tester, platform);
        await navigate(tester);
        expect(launches(), hasLength(installed ? 2 : 1));
        expectSystem(platform, launches().last);
      });
    }

    testWidgets('$platform unresolved old activity opens address search', (
      tester,
    ) async {
      await _openLocation(tester, platform, hasCoordinates: false);
      await navigate(tester);
      expect(geocoder.queries, [_display]);
      expectSystem(platform, launches().single);
      expect(calls.single.method, 'launch');
    });

    testWidgets('$platform failed system launch shows unavailable message', (
      tester,
    ) async {
      installed = false;
      systemResult = false;
      await _openLocation(tester, platform);
      await navigate(tester);
      expect(find.text('没有可用的地图应用'), findsOneWidget);
    });
  }
}
