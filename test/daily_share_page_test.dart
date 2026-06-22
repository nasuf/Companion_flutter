import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDailyShareApi extends CompanionApi {
  _FakeDailyShareApi() : super(baseUrl: 'https://example.test') {
    authToken = 'test-token';
  }

  @override
  Future<DailySharePhotosResponse> listDailySharePhotos({int? limit}) async {
    return DailySharePhotosResponse(
      total: 4,
      groups: [
        DailySharePhotoGroup(
          id: 'evening-light',
          title: '傍晚光线',
          subtitle: '适合一句很短的晚安。',
          count: 4,
          photos: [
            ChatAttachment(
              id: 'att-1',
              kind: 'image',
              mime: 'image/jpeg',
              size: 100,
              width: 800,
              height: 600,
              url: 'https://example.test/chat/media/user_sunset.jpg',
            ),
            ChatAttachment(
              id: 'att-2',
              kind: 'image',
              mime: 'image/jpeg',
              size: 100,
              width: 800,
              height: 600,
              url: 'https://example.test/chat/media/user_lake.jpg',
            ),
            ChatAttachment(
              id: 'att-3',
              kind: 'image',
              mime: 'image/jpeg',
              size: 100,
              width: 800,
              height: 600,
              url: 'https://example.test/chat/media/user_road.jpg',
            ),
            ChatAttachment(
              id: 'att-4',
              kind: 'image',
              mime: 'image/jpeg',
              size: 100,
              width: 800,
              height: 600,
              url: 'https://example.test/chat/media/user_mountain.jpg',
            ),
          ],
        ),
      ],
    );
  }

  @override
  Future<DailyShareLinksResponse> listDailyShareLinks({int? limit}) async {
    return const DailyShareLinksResponse(
      total: 1,
      groups: [
        DailyShareLinkGroup(
          id: 'links-2026-06-19',
          title: '06月19日',
          subtitle: '小红书',
          count: 1,
          links: [
            DailyShareLink(
              id: 'link-1',
              conversationId: 'conv-1',
              role: 'user',
              sourceUrl: 'https://xhslink.com/a1',
              finalUrl: 'https://www.xiaohongshu.com/explore/1',
              platform: '小红书',
              title: '周末咖啡馆',
              summary: '阳光很好，适合坐在窗边。',
              componentCard: ChatComponentCard(
                type: 'external_link',
                title: '小红书',
                subtitle: '',
                body: '复制来的小红书原文 阳光很好，适合坐在窗边。',
                footer: '点击打开小红书app/网页',
                accent: '#F43F5E',
                payload: {
                  'link_id': 'link-1',
                  'final_url': 'https://www.xiaohongshu.com/explore/1',
                  'platform': '小红书',
                  'original_text': '复制来的小红书原文 阳光很好，适合坐在窗边。',
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

Future<void> _pumpDailySharePage(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(home: DailySharePage(api: _FakeDailyShareApi())),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _scrollToPhotoGroup(WidgetTester tester) async {
  await tester.drag(find.byType(CustomScrollView), const Offset(0, -420));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

void main() {
  testWidgets('daily share photo tab renders grouped photos and preview', (
    tester,
  ) async {
    await _pumpDailySharePage(tester);

    expect(find.text('DAILY BOARD'), findsOneWidget);
    expect(find.text('照片'), findsOneWidget);
    expect(find.text('链接'), findsOneWidget);

    await _scrollToPhotoGroup(tester);

    expect(find.text('傍晚光线'), findsOneWidget);
    expect(find.text('4 张'), findsOneWidget);

    final secondPhoto = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is NetworkImage &&
          (widget.image as NetworkImage).url.contains('user_lake'),
    );
    expect(secondPhoto, findsWidgets);

    await tester.tap(secondPhoto.last);
    await tester.pump(const Duration(milliseconds: 260));

    expect(find.text('适合一句很短的晚安。 · 第 2 张'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('daily-photo-preview-thumbs')),
      findsOneWidget,
    );
    final zoomablePreview = tester.widget<InteractiveViewer>(
      find.byKey(const ValueKey('daily-photo-preview-zoom-1')),
    );
    expect(zoomablePreview.minScale, 1);
    expect(zoomablePreview.maxScale, 4);
    expect(
      find.byKey(const ValueKey('daily-photo-preview-thumb-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('daily-photo-preview-thumb-1')),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const ValueKey('daily-photo-preview-page-view')),
      const Offset(-260, 0),
    );
    await tester.pump(const Duration(milliseconds: 360));

    expect(find.text('适合一句很短的晚安。 · 第 3 张'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('daily-photo-preview-thumb-0')));
    await tester.pump(const Duration(milliseconds: 320));

    expect(find.text('适合一句很短的晚安。 · 第 1 张'), findsOneWidget);
  });

  testWidgets('daily share photo rail hides arrows at scroll boundaries', (
    tester,
  ) async {
    await _pumpDailySharePage(tester);
    await _scrollToPhotoGroup(tester);

    expect(
      find.byKey(const ValueKey('daily-photo-rail-previous')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('daily-photo-rail-next')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('daily-photo-rail-next')));
    await tester.pump(const Duration(milliseconds: 360));

    expect(
      find.byKey(const ValueKey('daily-photo-rail-previous')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('daily-photo-rail-next')), findsNothing);
  });

  testWidgets('daily share link tab does not render photo hero card', (
    tester,
  ) async {
    await _pumpDailySharePage(tester);

    await tester.tap(find.text('链接'));
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('06月19日'), findsOneWidget);
    expect(find.text('1 条 · 小红书'), findsOneWidget);
    expect(find.text('周末咖啡馆'), findsNothing);
    expect(find.text('复制来的小红书原文 阳光很好，适合坐在窗边。'), findsOneWidget);
    expect(find.text('点击打开小红书app/网页'), findsOneWidget);
    expect(find.text('PHOTO DIARY'), findsNothing);
    expect(find.text('把照片整理成一句自然分享'), findsNothing);
  });
}
