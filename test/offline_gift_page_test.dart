import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
// Test-only in-memory files for the cache manager's package:file contract.
// ignore: depend_on_referenced_packages
import 'package:file/memory.dart';
import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:companion_flutter/offline_models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ImageCache extends Fake implements BaseCacheManager {
  bool fails = true;
  int reads = 0;
  int downloads = 0;
  final keys = <String>{};
  final requests = <Map<String, String>?>[];
  final file = MemoryFileSystem().file('/gift.png')
    ..writeAsBytesSync(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD0In+KAAAADklEQVR4nGP4z8DwH4QBEfcD/ePF9e8AAAAASUVORK5CYII=',
      ),
    );

  @override
  Future<void> removeFile(String key) async {
    keys.remove(key);
  }

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) async* {
    reads++;
    requests.add(headers);
    if (fails) throw StateError('image unavailable');
    if (keys.add(key ?? url)) downloads++;
    yield FileInfo(
      file,
      FileSource.Cache,
      DateTime.now().add(const Duration(days: 1)),
      url,
    );
  }
}

const _session = AuthSession(
  token: 'test',
  userId: 'user',
  username: 'tester',
  role: UserRole.user,
  hasAgent: true,
);
RealWorldGift _gift({String? image, String? thanks}) => RealWorldGift.fromJson({
  'id': 'gift',
  'status': 'delivered',
  'gift_name': '暖手宝',
  'gift_note': '焐着手再敲键盘，别老把指尖冻得冰凉。',
  'product_image_url': image,
  'thanks_sent_at': thanks,
  'created_at': '2026-09-02T12:22:00+08:00',
});
GiftTrackingEvent _event(int i, {String title = '包裹正在运输中'}) =>
    GiftTrackingEvent(
      id: '$i',
      status: 'shipping',
      title: title,
      location: '转运中心',
      description: '下一站会继续更新。',
      occurredAt: '2026-09-${i.toString().padLeft(2, '0')}T12:22:00+08:00',
    );

class _Api extends CompanionApi {
  _Api({RealWorldGift? gift})
    : gift = gift ?? _gift(),
      super(baseUrl: 'https://example.test') {
    authToken = 'synthetic';
  }
  RealWorldGift gift;
  bool homeFails = false;
  bool trackingFails = false;
  bool thanksFails = false;
  bool empty = false;
  int homeCalls = 0;
  int trackingCalls = 0;
  List<String?> thanksIds = [];
  List<String> thanksMessages = [];
  Completer<GiftTracking>? trackingGate;
  List<GiftTrackingEvent> events = [for (var i = 1; i <= 12; i++) _event(i)];
  @override
  Future<GiftsHome> fetchOfflineGifts({String? workspaceId}) async {
    homeCalls++;
    if (homeFails) throw const ApiException(503, 'unavailable');
    return GiftsHome(
      groups: empty
          ? []
          : [
              GiftYearGroup(year: 2026, gifts: [gift]),
            ],
    );
  }

  @override
  Future<RealWorldGift> fetchOfflineGift(String id) async => gift;
  @override
  Future<GiftTracking> fetchGiftTracking(String id) async {
    trackingCalls++;
    if (trackingFails) throw const ApiException(503, 'unavailable');
    return trackingGate?.future ??
        Future.value(GiftTracking(giftId: id, events: events));
  }

  @override
  Future<RealWorldGift> sendGiftThanks(
    String id, {
    required String message,
    String? clientId,
  }) async {
    thanksIds.add(clientId);
    thanksMessages.add(message);
    if (thanksFails) throw const ApiException(503, 'unavailable');
    return gift;
  }
}

Future<void> _show(
  WidgetTester tester,
  _Api api, {
  bool detail = true,
  bool dark = false,
  double scale = 1,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: OfflineGiftPage(
        api: api,
        session: _session,
        initialGiftId: detail ? 'gift' : null,
      ),
    ),
  );
  // Pending loading spinners deliberately never settle.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder get _scroll => find.byKey(const ValueKey('offline-detail-scroll-礼物详情'));
Future<void> _bottom(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    if (find.text('向 TA 说声谢谢').hitTestable().evaluate().isNotEmpty) return;
    await tester.drag(_scroll, const Offset(0, -400));
    await tester.pumpAndSettle();
  }
}

Future<void> _thank(WidgetTester tester, String words) async {
  await tester.tap(find.text('向 TA 说声谢谢'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('gift-thanks-input')),
    words,
  );
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('gift-thanks-send')));
  await tester.pumpAndSettle();
}

void main() {
  late _ImageCache cache;
  setUp(() {
    cache = _ImageCache();
    CachedNetworkImageProvider.defaultCacheManager = cache;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  testWidgets(
    'list and detail share decoded image and disk bytes without a second download',
    (tester) async {
      cache.fails = false;
      final api = _Api(gift: _gift(image: 'https://images.test/gift.png'));
      await _show(tester, api, detail: false);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pumpAndSettle();
      final listImage = tester.widget<Image>(find.byType(Image).first);
      final listKey = await listImage.image.obtainKey(ImageConfiguration.empty);
      expect(cache.downloads, 1);
      await tester.tap(find.text('暖手宝'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pumpAndSettle();
      final detailImage = tester.widget<Image>(
        find.descendant(of: _scroll, matching: find.byType(Image)).first,
      );
      expect(
        await detailImage.image.obtainKey(ImageConfiguration.empty),
        listKey,
      );
      expect(detailImage.fit, BoxFit.cover);
      expect(cache.reads, 1);
      expect(find.text('正在加载图片…'), findsNothing);
      expect(
        find.byKey(const ValueKey('offline-detail-glass')),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pumpAndSettle();
      // Simulate decoded-memory eviction: reopen still reads the cached file.
      await listImage.image.evict();
      await tester.tap(find.text('暖手宝'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pumpAndSettle();
      expect(cache.downloads, 1);
      expect(cache.reads, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'protected image keys isolate sessions without leaking credentials',
    (tester) async {
      cache.fails = false;
      const url = 'https://example.test/offline/media/gift.jpg';
      final api = _Api(gift: _gift(image: url));
      await _show(tester, api, detail: false);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pumpAndSettle();
      final firstKey = cache.keys.single;
      expect(firstKey, isNot(contains('synthetic')));
      api.authToken = 'second-session';
      await tester.tap(find.text('暖手宝'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pumpAndSettle();
      expect(cache.downloads, 2);
      expect(cache.keys.length, 2);
      expect(cache.requests.last, {'Authorization': 'Bearer second-session'});
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'raw catalogue CDN images are bounded while attribution parameters survive',
    (tester) async {
      const raw = 'https://images.unsplash.com/photo-gift?ixid=attribution';
      await _show(tester, _Api(gift: _gift(image: raw)));
      await tester.pumpAndSettle();
      final image = tester.widget<Image>(
        find.descendant(of: _scroll, matching: find.byType(Image)).first,
      );
      final provider =
          (image.image as ResizeImage).imageProvider
              as CachedNetworkImageProvider;
      final uri = Uri.parse(provider.url);
      expect(uri.queryParameters, {
        'ixid': 'attribution',
        'w': '960',
        'auto': 'format',
        'q': '80',
      });
      expect(provider.headers, isNull);
    },
  );

  testWidgets(
    'image retry clears failed cache and recovers when bytes become available',
    (tester) async {
      await _show(
        tester,
        _Api(gift: _gift(image: 'https://images.test/retry.png')),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: _scroll, matching: find.text('图片暂时加载失败')),
        findsOneWidget,
      );
      cache.fails = false;
      await tester.tap(
        find.descendant(of: _scroll, matching: find.text('重新加载')),
      );
      await tester.pump();
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: _scroll, matching: find.text('图片暂时加载失败')),
        findsNothing,
      );
      expect(find.text('正在加载图片…'), findsNothing);
      expect(cache.downloads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'gift home has a quiet utility row and one collection hierarchy',
    (tester) async {
      await _show(tester, _Api(), detail: false);
      expect(find.text('每一份心意，都好好收藏'), findsNothing);
      expect(find.text('每一份礼物，都是被惦记的证明'), findsNothing);
      expect(find.text('新的惊喜正在悄悄酝酿中'), findsNothing);
      expect(find.text('我的礼物'), findsOneWidget);
      expect(find.text('收到的礼物'), findsOneWidget);
      expect(find.text('1 份'), findsOneWidget);
      expect(find.text('暂无在途礼物'), findsNothing);
      expect(find.text('最近收到 · 9月2日'), findsOneWidget);
      expect(find.text('暖手宝').hitTestable(), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('gift-address-entry'))).height,
        lessThan(90),
      );
      await tester.tap(find.text('暖手宝'));
      await tester.pumpAndSettle();
      expect(find.byIcon(CupertinoIcons.xmark), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('礼物详情'), findsNothing);
    },
  );

  testWidgets(
    'detail keeps its header fixed and supports swipe dismissal without an X',
    (tester) async {
      await _show(tester, _Api());
      final handle = find.byKey(const ValueKey('offline-detail-grabber'));
      final before = tester.getTopLeft(handle);
      await _bottom(tester);
      // First scroll expands the draggable sheet; subsequent content scrolling must not move its header.
      final expanded = tester.getTopLeft(handle);
      expect(expanded.dy, lessThanOrEqualTo(before.dy));
      await tester.drag(_scroll, const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(handle), expanded);
      expect(find.text('礼物详情').hitTestable(), findsOneWidget);
      expect(find.text('向 TA 说声谢谢').hitTestable(), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.xmark), findsNothing);
      await tester.drag(handle, const Offset(0, 700));
      await tester.pumpAndSettle();
      expect(find.text('礼物详情'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'tracking failure is caught and retry distinguishes empty results',
    (tester) async {
      final api = _Api()..trackingFails = true;
      await _show(tester, api);
      await _bottom(tester);
      expect(find.text('物流同步失败'), findsOneWidget);
      expect(tester.takeException(), isNull);
      api.trackingFails = false;
      api.events = [];
      await tester.tap(find.text('重试').hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('暂时还没有物流更新'), findsOneWidget);
      expect(find.text('物流同步失败'), findsNothing);
      expect(api.trackingCalls, 2);
    },
  );
  testWidgets('tracking loading is explicit until request completes', (
    tester,
  ) async {
    final api = _Api()..trackingGate = Completer<GiftTracking>();
    await _show(tester, api);
    expect(find.text('正在同步物流...'), findsOneWidget);
    api.trackingGate!.complete(const GiftTracking(giftId: 'gift', events: []));
    await tester.pumpAndSettle();
    expect(find.text('暂时还没有物流更新'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'sorts logistics by time and preserves repeated statuses at different times',
    (tester) async {
      final api = _Api()
        ..events = [_event(3, title: '最新记录'), _event(1), _event(2), _event(2)];
      await _show(tester, api);
      expect(find.text('包裹正在运输中'), findsNWidgets(2));
      expect(
        tester.getTopLeft(find.text('最新记录')).dy,
        lessThan(tester.getTopLeft(find.text('包裹正在运输中').first).dy),
      );
    },
  );
  testWidgets('thanks failures retain sheet and reuse client id on retry', (
    tester,
  ) async {
    final api = _Api()
      ..thanksFails = true
      ..events = [];
    await _show(tester, api);
    await _bottom(tester);
    await _thank(tester, '好暖和，谢谢你');
    expect(find.text('感谢暂时没有传达成功，请重试'), findsOneWidget);
    expect(find.text('礼物详情'), findsOneWidget);
    api.thanksFails = false;
    await tester.ensureVisible(find.text('向 TA 说声谢谢'));
    await _thank(tester, '好暖和，谢谢你');
    expect(api.thanksIds.length, 2);
    expect(api.thanksIds.toSet().length, 1);
    expect(api.thanksMessages, ['好暖和，谢谢你', '好暖和，谢谢你']);
    expect(find.text('礼物详情'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('thanks asks for words first and can be cancelled', (
    tester,
  ) async {
    final api = _Api()..events = [];
    await _show(tester, api);
    await _bottom(tester);
    await tester.tap(find.text('向 TA 说声谢谢'));
    await tester.pumpAndSettle();
    expect(find.text('想对 TA 说点什么？'), findsOneWidget);
    // 没写内容时不能发送。
    final send = tester.widget<CupertinoDialogAction>(
      find.byKey(const ValueKey('gift-thanks-send')),
    );
    expect(send.onPressed, isNull);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(api.thanksIds, isEmpty);
    expect(find.text('礼物详情'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'failed home load never displays false empty or delivered states',
    (tester) async {
      final api = _Api()..homeFails = true;
      await _show(tester, api, detail: false);
      expect(find.text('礼物暂时加载失败，请重试'), findsOneWidget);
      expect(find.text('还没有收到礼物'), findsNothing);
      expect(find.text('所有心意都已抵达'), findsNothing);
      expect(find.text('收货地址'), findsNothing);
      api.homeFails = false;
      api.empty = true;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('还没有收到礼物'), findsOneWidget);
      expect(find.text('0 份'), findsNothing);
      expect(find.text('收到的礼物'), findsNothing);
      expect(
        find.byKey(const ValueKey('gift-empty-collection')),
        findsOneWidget,
      );
      expect(find.text('期待下一份小惊喜'), findsNothing);
      expect(find.text('去聊聊'), findsNothing);
    },
  );
  testWidgets('refresh failure keeps previously loaded gifts visible', (
    tester,
  ) async {
    final api = _Api();
    await _show(tester, api, detail: false);
    api.homeFails = true;
    await tester
        .widget<CupertinoSliverRefreshControl>(
          find.byType(CupertinoSliverRefreshControl, skipOffstage: false),
        )
        .onRefresh!();
    await tester.pumpAndSettle();
    expect(find.text('暖手宝'), findsOneWidget);
    expect(find.text('礼物暂时加载失败，请重试'), findsOneWidget);
    expect(find.text('还没有收到礼物'), findsNothing);
  });
  testWidgets('already thanked gifts keep their success state', (tester) async {
    await _show(tester, _Api(gift: _gift(thanks: '2026-09-06T12:00:00Z')));
    await tester.ensureVisible(find.text('✓ 感谢已传达'));
    expect(find.text('✓ 感谢已传达').hitTestable(), findsOneWidget);
    expect(find.text('向 TA 说声谢谢'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('empty home adapts to small screens and large text', (
    tester,
  ) async {
    await _show(
      tester,
      _Api()..empty = true,
      detail: false,
      dark: true,
      scale: 1.6,
      size: const Size(320, 640),
    );
    await tester.ensureVisible(find.text('还没有收到礼物'));
    expect(tester.takeException(), isNull);
  });
  testWidgets('missing picture has a dedicated placeholder', (tester) async {
    await _show(tester, _Api());
    expect(
      find.descendant(of: _scroll, matching: find.text('暂无礼物图片')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  for (final url in [
    'https://example.test/offline/media/gift.jpg',
    'https://external.test/offline/media/gift.jpg',
  ]) {
    testWidgets('image failure is retryable with scoped headers: $url', (
      tester,
    ) async {
      await _show(tester, _Api(gift: _gift(image: url)));
      await tester.pumpAndSettle();
      final images = tester
          .widgetList<Image>(find.byType(Image))
          .where((image) => image.image is ResizeImage)
          .toList();
      final providers = images
          .map((image) => (image.image as ResizeImage).imageProvider)
          .whereType<CachedNetworkImageProvider>()
          .where((image) => image.url == url)
          .toList();
      expect(providers, isNotEmpty);
      expect(
        providers.first.headers,
        url.startsWith('https://example.test/')
            ? {'Authorization': 'Bearer synthetic'}
            : isNull,
      );
      expect(
        find.descendant(of: _scroll, matching: find.text('图片暂时加载失败')),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(of: _scroll, matching: find.text('重新加载')),
      );
      await tester.pumpAndSettle();
      expect(find.text('礼物详情'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('dark small screen and large text keep all content reachable', (
    tester,
  ) async {
    await _show(
      tester,
      _Api(),
      dark: true,
      scale: 1.6,
      size: const Size(320, 640),
    );
    await _bottom(tester);
    expect(find.text('向 TA 说声谢谢').hitTestable(), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.xmark), findsNothing);
    expect(find.text('礼物详情').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
