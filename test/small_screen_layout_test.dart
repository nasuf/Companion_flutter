import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _session = AuthSession(
  token: 't',
  userId: 'u',
  username: 'tester',
  role: UserRole.user,
  hasAgent: true,
  agentId: 'a',
  agentName: '小伴',
);

class _Api extends CompanionApi {
  _Api() : super(baseUrl: 'https://synthetic.test');

  @override
  Future<DailySharePhotosResponse> listDailySharePhotos({int? limit}) async =>
      const DailySharePhotosResponse(total: 0, groups: []);

  @override
  Future<DailyShareLinksResponse> listDailyShareLinks({int? limit}) async =>
      const DailyShareLinksResponse(total: 0, groups: []);
}

CompanionApi _api() => _Api();

/// 整屏不滚动的页面：矮屏、三键导航栏、系统字体调大时都不能溢出。
final _pages = <String, Widget Function()>{
  'store subscription': () => StorePage(api: _api(), session: _session),
  'store recharge': () =>
      StorePage(api: _api(), session: _session, openTicketRecharge: true),
  'weather': () => WeatherPage(api: _api(), agentName: '小伴'),
  'music': () => MusicPage(api: _api(), session: _session),
  'daily share': () => DailySharePage(api: _api()),
  'check-in': () => CheckinPage(api: _api(), session: _session),
};

const _screens = [
  (Size(360, 640), 1.0, '360x640'),
  (Size(360, 720), 1.3, '360x720 font 1.3'),
  (Size(393, 780), 1.5, '393x780 font 1.5'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // 与聊天页测试相同：音频插件通道给空实现，播放控制器单例最后统一释放。
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => null,
      );
    }
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async {
        final id = (call.arguments as Map?)?['playerId'];
        if (id != null) {
          messenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/$id'),
            (_) async => null,
          );
        }
        return null;
      },
    );
  });
  tearDownAll(() => MusicPlaybackController.instance.dispose());

  // 放得下的机型上不能出现几像素的可拖动空间（iPhone 15 Pro 曾回归过）。
  const phones = [
    (Size(393, 852), 59.0, 34.0, 'iPhone 15 Pro'),
    (Size(390, 844), 47.0, 34.0, 'iPhone 14'),
    (Size(430, 932), 59.0, 34.0, 'iPhone 15 Pro Max'),
  ];
  for (final name in [
    'store subscription',
    'store recharge',
    'weather',
    'music',
  ]) {
    for (final phone in phones) {
      testWidgets('$name does not scroll on ${phone.$4}', (t) async {
        t.view.physicalSize = phone.$1;
        t.view.devicePixelRatio = 1;
        t.view.padding = FakeViewPadding(top: phone.$2, bottom: phone.$3);
        t.view.viewPadding = FakeViewPadding(top: phone.$2, bottom: phone.$3);
        addTearDown(t.view.reset);
        await t.runAsync(() async {
          MusicPlaybackController.instance.configureQuota(_api());
        });
        final original = FlutterError.onError;
        FlutterError.onError = (_) {};
        final extents = <double>[];
        try {
          await t.pumpWidget(MaterialApp(home: _pages[name]!()));
          for (var i = 0; i < 6; i += 1) {
            await t.pump(const Duration(milliseconds: 100));
          }
          for (final element in find.byType(Scrollable).evaluate()) {
            final state = (element as StatefulElement).state as ScrollableState;
            if (state.axisDirection == AxisDirection.down) {
              extents.add(state.position.maxScrollExtent);
            }
          }
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(seconds: 30));
        } finally {
          FlutterError.onError = original;
        }
        expect(extents, isNotEmpty);
        expect(extents.first, 0);
      });
    }
  }

  for (final page in _pages.entries) {
    for (final screen in _screens) {
      testWidgets('${page.key} does not overflow at ${screen.$3}', (t) async {
        t.view.physicalSize = screen.$1;
        t.view.devicePixelRatio = 1;
        t.view.padding = const FakeViewPadding(top: 24, bottom: 48);
        t.platformDispatcher.textScaleFactorTestValue = screen.$2;
        addTearDown(t.view.reset);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);

        // 页面会请求假地址并报网络错误，这里只关心布局溢出。
        final overflows = <String>[];
        final original = FlutterError.onError;
        FlutterError.onError = (details) {
          final message = details.exceptionAsString();
          if (message.contains('overflowed')) {
            overflows.add(message.split('\n').first);
          }
        };
        // 播放控制器的周期计时器要建在假时钟之外，否则测试结束时报计时器未清理。
        await t.runAsync(() async {
          MusicPlaybackController.instance.configureQuota(_api());
        });
        try {
          await t.pumpWidget(MaterialApp(home: page.value()));
          for (var i = 0; i < 6; i += 1) {
            await t.pump(const Duration(milliseconds: 100));
          }
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(seconds: 30));
        } finally {
          FlutterError.onError = original;
        }
        expect(overflows, isEmpty);
      });
    }
  }
}
