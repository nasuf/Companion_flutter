import 'dart:async';

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
  _Api(this.activity, {this.takeoverId})
    : super(baseUrl: 'https://example.test');
  final OfflineActivity activity;
  final String? takeoverId;
  final reads = <String>[];
  bool failLocation = false;
  Future<void>? locationGate;

  @override
  Future<OfflineActivity> fetchOfflineActivity(String id) async {
    expect(takeoverId, isNull, reason: 'takeover cannot read own activities');
    reads.add('own/$id');
    await locationGate;
    if (failLocation) throw const ApiException(404, '活动位置暂不可用');
    return activity;
  }

  @override
  Future<OfflineActivity> fetchTakeoverActivity(String scope, String id) async {
    expect(scope, takeoverId);
    reads.add('$scope/$id');
    await locationGate;
    if (failLocation) throw const ApiException(404, '活动位置暂不可用');
    return activity;
  }

  OfflineActivityReview review() => OfflineActivityReview.fromJson({
    'id': activity.id,
    'title': '一段旅途回忆，而不是场所名',
    'address': _address,
    'story': '这次留下了一段回忆',
  });

  @override
  Future<OfflineActivityReview> fetchOfflineActivityReview(String id) async {
    expect(takeoverId, isNull);
    return review();
  }

  @override
  Future<OfflineActivityReview> fetchTakeoverActivityReview(
    String scope,
    String id,
  ) async {
    expect(scope, takeoverId);
    return review();
  }
}

class _Geocoder extends geocoding.GeocodingPlatform {
  final queries = <String>[];

  @override
  Future<List<geocoding.Location>> locationFromAddress(String address) async {
    queries.add(address);
    return [];
  }
}

Future<_Api> _openLocation(
  WidgetTester tester,
  TargetPlatform platform, {
  bool hasCoordinates = true,
  String coordinateSystem = 'gcj02',
  String status = 'accepted',
  String description = '',
  bool reached = false,
  bool openLocation = true,
  String? takeoverId,
  Size viewport = const Size(390, 844),
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final activity = OfflineActivity.fromJson({
    'id': 'activity',
    'status': status,
    'reached': reached,
    'title': _name,
    'location_name': _name,
    'address': _address,
    'city': '镇江市',
    'summary': '顺路看看花艺',
    'description': description,
    if (hasCoordinates) 'place_lat': 32.203,
    if (hasCoordinates) 'place_lng': 119.451,
    'coordinate_system': coordinateSystem,
  });
  final api = _Api(activity, takeoverId: takeoverId);
  const session = AuthSession(
    token: 'test',
    userId: 'user',
    username: 'tester',
    role: UserRole.user,
    hasAgent: true,
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      home: status == 'accepted'
          ? OfflineCheckinPage(
              api: api,
              session: session,
              activityId: activity.id,
              takeoverId: takeoverId,
            )
          : status == 'completed'
          ? OfflineReviewPage(
              api: api,
              session: session,
              activityId: activity.id,
              takeoverId: takeoverId,
            )
          : Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => openOfflineActivityDetail(
                    context,
                    api: api,
                    session: session,
                    activity: activity,
                    takeoverId: takeoverId,
                  ),
                  child: const Text('打开活动'),
                ),
              ),
            ),
    ),
  );
  await tester.pumpAndSettle();
  if (status != 'accepted' && status != 'completed') {
    await tester.tap(find.text('打开活动'));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(find.text('查看位置'));
  await tester.pumpAndSettle();
  if (openLocation) {
    await tester.tap(find.text('查看位置'));
    await tester.pumpAndSettle();
    expect(find.text(_display), findsOneWidget);
  }
  return api;
}

void main() {
  final calls = <MethodCall>[];
  late _Geocoder geocoder;
  var installed = true;
  var launchResult = true;
  var throwNative = false;
  var systemResult = true;
  String? clipboard;

  setUp(() {
    calls.clear();
    installed = true;
    launchResult = true;
    throwNative = false;
    systemResult = true;
    clipboard = null;
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_urlChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> navigate(WidgetTester tester, {String label = '导航前往'}) async {
    expect(calls, isEmpty);
    await tester.tap(find.text(label));
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
    for (final (status, reached) in [
      ('pending', false),
      ('ignored', false),
      ('accepted', false),
      ('accepted', true),
      ('completed', true),
    ]) {
      testWidgets('$platform $status reached=$reached location actions', (
        tester,
      ) async {
        await _openLocation(tester, platform, status: status, reached: reached);
        final planned = status == 'accepted' && !reached;
        expect(find.text('复制地址'), findsOneWidget);
        expect(find.text(planned ? '查看距离' : '导航前往'), findsNothing);
        await navigate(tester, label: planned ? '导航前往' : '查看距离');
        final uri = launches().single;
        expect(
          uri.scheme,
          platform == TargetPlatform.iOS ? 'iosamap' : 'amapuri',
        );
        expect(uri.host, platform == TargetPlatform.iOS ? 'path' : 'route');
        expect(uri.queryParameters['dname'], _name);
        expect(uri.queryParameters['dlat'], '32.203');
        expect(uri.queryParameters['dlon'], '119.451');
        expect(geocoder.queries, isEmpty);
      });
    }

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

  testWidgets('pending location copies the complete address without maps', (
    tester,
  ) async {
    await _openLocation(tester, TargetPlatform.iOS, status: 'pending');
    await tester.tap(find.text('复制地址'));
    await tester.pumpAndSettle();
    expect(clipboard, _display);
    expect(calls, isEmpty);
    expect(find.text('地址已复制'), findsOneWidget);
  });

  for (final status in ['pending', 'ignored', 'completed']) {
    testWidgets('narrow $status address keeps location button clickable', (
      tester,
    ) async {
      await _openLocation(
        tester,
        TargetPlatform.iOS,
        status: status,
        viewport: const Size(320, 740),
      );
      await navigate(tester, label: '查看距离');
    });
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      '$platform ignored long detail keeps address actions at bottom',
      (tester) async {
        await _openLocation(
          tester,
          platform,
          status: 'ignored',
          description: List.filled(
            12,
            '可以按自己的节奏看看展览，出发前确认当天的开放安排。',
          ).join('\n\n'),
          openLocation: false,
          viewport: const Size(320, 740),
        );
        final address = tester.getRect(find.text('📍 $_address'));
        final button = tester.getRect(find.text('查看位置'));
        expect(button.left, greaterThan(address.right));
        expect(button.right, lessThanOrEqualTo(320));
        expect(button.center.dy, closeTo(address.center.dy, 1));
        expect(find.text('重新接受邀请'), findsOneWidget);
        await tester.tap(find.text('查看位置'));
        await tester.pumpAndSettle();
        expect(find.text('查看距离'), findsOneWidget);
        expect(find.text('导航前往'), findsNothing);
        await tester.tap(find.text('复制地址'));
        await tester.pumpAndSettle();
        expect(clipboard, _display);
        expect(calls, isEmpty);
        await tester.tap(find.text('知道了'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('查看位置'));
        await tester.pumpAndSettle();
        await navigate(tester, label: '查看距离');
        final uri = launches().single;
        expect(uri.host, platform == TargetPlatform.iOS ? 'path' : 'route');
        expect(uri.queryParameters['dname'], _name);
        expect(uri.queryParameters['dlat'], '32.203');
        expect(uri.queryParameters['dlon'], '119.451');
        expect(find.text('重新接受邀请'), findsOneWidget);
      },
    );
  }

  testWidgets('takeover review reads the original owner location', (
    tester,
  ) async {
    final api = await _openLocation(
      tester,
      TargetPlatform.android,
      status: 'completed',
      takeoverId: 'case',
    );
    expect(api.reads, ['case/activity']);
    await navigate(tester, label: '查看距离');
    expect(launches().single.queryParameters['dname'], _name);
  });

  testWidgets('review location failure stays on review and can retry', (
    tester,
  ) async {
    final api = await _openLocation(
      tester,
      TargetPlatform.iOS,
      status: 'completed',
      openLocation: false,
    );
    api.failLocation = true;
    await tester.tap(find.text('查看位置'));
    await tester.pumpAndSettle();
    expect(find.text('活动位置暂不可用'), findsOneWidget);
    expect(find.text('这次留下了一段回忆'), findsOneWidget);
    expect(calls, isEmpty);
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    api.failLocation = false;
    await tester.tap(find.text('查看位置'));
    await tester.pumpAndSettle();
    await navigate(tester, label: '查看距离');
  });

  testWidgets('review repeated location taps create one lookup and sheet', (
    tester,
  ) async {
    final api = await _openLocation(
      tester,
      TargetPlatform.iOS,
      status: 'completed',
      openLocation: false,
    );
    final gate = Completer<void>();
    api.locationGate = gate.future;
    await tester.tap(find.text('查看位置'));
    await tester.pump();
    await tester.tap(find.text('查看位置'));
    await tester.pump();
    expect(api.reads, ['own/activity']);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('位置'), findsOneWidget);
    await navigate(tester, label: '查看距离');
  });

  testWidgets('leaving review during lookup does not open a location sheet', (
    tester,
  ) async {
    final api = await _openLocation(
      tester,
      TargetPlatform.iOS,
      status: 'completed',
      openLocation: false,
    );
    final gate = Completer<void>();
    api.locationGate = gate.future;
    await tester.tap(find.text('查看位置'));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: Text('已离开活动')));
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('位置'), findsNothing);
    expect(find.text('已离开活动'), findsOneWidget);
    expect(calls, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
