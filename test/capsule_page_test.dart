import 'dart:io';

import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _session = AuthSession(
  token: 'test-token',
  userId: 'user-1',
  username: 'tester',
  // 服务端总会给出解析好的展示名 (密码账号建号时预写 = username, 微信用昵称,
  // 手机号用尾号), 客户端不再自己回落到 username —— fixture 跟着对齐, 否则这里
  // 测的就不是真实渲染。
  userDisplayName: 'tester',
  role: UserRole.user,
  hasAgent: true,
  agentId: 'agent-1',
  agentName: '小芜',
  workspaceId: 'ws-1',
  conversationId: 'conv-1',
);

TimeCapsule _capsule({
  required String id,
  required String state,
  String content = '亲爱的未来的我，希望你还记得今天的心情。',
  DateTime? openDate,
  DateTime? createdAt,
  DateTime? openedAt,
  String? title,
}) {
  final created = createdAt ?? DateTime(2025, 7, 12);
  return TimeCapsule(
    id: id,
    userId: 'user-1',
    title: title,
    content: content,
    status: state == 'draft' ? 'draft' : 'sealed',
    state: state,
    createdAt: created,
    updatedAt: created,
    sealedAt: state == 'draft' ? null : created,
    openDate: openDate ?? DateTime(2026, 7, 12),
    openedAt: openedAt,
  );
}

class _FakeCapsuleApi extends CompanionApi {
  _FakeCapsuleApi(this.items) : super(baseUrl: 'https://example.test') {
    authToken = 'test-token';
  }

  final List<TimeCapsule> items;
  final deleted = <String>[];

  @override
  Future<List<TimeCapsule>> listTimeCapsules({
    String? agentId,
    String? workspaceId,
    String? state,
  }) async => items;

  @override
  Future<void> deleteTimeCapsule(String capsuleId) async {
    deleted.add(capsuleId);
  }
}

/// Pins the harness to the 390x844 reference canvas the designs are drawn
/// against. `setSurfaceSize` alone resizes the render surface but leaves
/// MediaQuery reporting the default 800x600, so the view is configured instead.
void _useDesignCanvas(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
}

/// Widget tests render `Image.asset` as a blank box unless the bytes are
/// decoded on a real (async) frame, which would leave the goldens empty.
///
/// The home breathes on a perpetual `AnimationController`, so `pumpAndSettle`
/// would spin forever waiting for a frame that never stops coming. Pump a
/// bounded, fixed run of frames instead: 600ms clears any finite transition
/// (bottom sheet ~250ms, Cupertino route ~400ms) while tolerating the endless
/// background drift, and a fixed pumped duration keeps the captured frame — and
/// therefore the goldens — deterministic.
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _settleWithImages(WidgetTester tester) async {
  await _pumpFrames(tester);
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      await precacheImage(image.image, element);
    }
  });
  await _pumpFrames(tester);
}

void main() {
  group('capsule home', () {
    testWidgets('empty state keeps every shortcut at zero', (tester) async {
      _useDesignCanvas(tester);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: CapsulePage(api: _FakeCapsuleApi(const []), session: _session),
        ),
      );
      await _settleWithImages(tester);

      expect(find.text('Hi，未来的自己'), findsOneWidget);
      expect(find.text('写新胶囊'), findsOneWidget);
      expect(find.text('草稿'), findsOneWidget);
      expect(find.text('待解封'), findsOneWidget);
      expect(find.text('已解封'), findsOneWidget);
      expect(find.text('距上一个胶囊开启过去'), findsOneWidget);
      // Every shortcut now shows its count as a value (like the weather metric
      // cards), so an empty vault reads "0" on all three shortcuts plus the
      // zeroed "days since" counter — four zeros, and never a stray 1.
      expect(find.text('1'), findsNothing);
      expect(find.text('0'), findsNWidgets(4));
      expect(tester.takeException(), isNull);

      await expectLater(
        find.byType(CapsulePage),
        matchesGoldenFile('goldens/capsule_home_empty.png'),
      );
    });

    testWidgets('content state badges each shortcut bucket', (tester) async {
      _useDesignCanvas(tester);

      final api = _FakeCapsuleApi([
        _capsule(id: 'd1', state: 'draft'),
        _capsule(id: 'd2', state: 'draft'),
        _capsule(id: 'p1', state: 'pending'),
        _capsule(id: 'r1', state: 'ready'),
        _capsule(
          id: 'o1',
          state: 'opened',
          openDate: DateTime(2025, 8, 1),
          openedAt: DateTime(2025, 8, 1),
        ),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: CapsulePage(api: api, session: _session),
        ),
      );
      await _settleWithImages(tester);

      // Drafts 2 / pending 1 / arrived (opened+ready) 2.
      expect(find.text('2'), findsNWidgets(2));
      expect(find.text('1'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await expectLater(
        find.byType(CapsulePage),
        matchesGoldenFile('goldens/capsule_home_content.png'),
      );
    });
  });

  group('capsule drafts', () {
    testWidgets('the sheet reads as the warm capsule list, not purple chips', (
      tester,
    ) async {
      _useDesignCanvas(tester);

      final api = _FakeCapsuleApi([
        _capsule(
          id: 'd1',
          state: 'draft',
          content: '今天想跟一年后的你说点什么',
          openDate: DateTime(2026, 8, 20),
        ),
        _capsule(id: 'd2', state: 'draft', content: '第二封还没写完'),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: CapsulePage(api: api, session: _session),
        ),
      );
      await _settleWithImages(tester);

      await tester.tap(find.text('草稿'));
      await _settleWithImages(tester);

      expect(find.text('还没封存，随时可以接着写'), findsOneWidget);
      expect(find.text('今天想跟一年后的你说点什么'), findsOneWidget);
      // Seeded 2025-07-12, so the edit date is the same on both rows and only
      // the open date differs.
      expect(find.text('7月12日 编辑 · 8月20日 开启'), findsOneWidget);
      expect(find.text('7月12日 编辑 · 7月12日 开启'), findsOneWidget);

      // Drafts moved to line-glyph medallions to match the 草稿 shortcut the
      // sheet grows from, so the old draft-icon PNG is gone everywhere. Each
      // row now carries a doc-glyph medallion instead.
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/capsule/draft-icon.png',
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Icon && widget.icon == CupertinoIcons.doc_text_fill,
          ),
        ),
        findsNWidgets(2),
      );

      // The rows used to lead with a lavender square holding 1/2/3. Nothing in
      // the capsule palette is purple, and the sequence number carried no
      // meaning once the rows show their own dates.
      expect(find.text('1'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text && widget.style?.color == const Color(0xFF7C3CFF),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);

      // Framed on the sheet alone rather than the whole app: the home behind
      // it already has its own goldens, and capturing it here would make this
      // one fail for changes it does not speak to.
      await expectLater(
        find.byType(BottomSheet),
        matchesGoldenFile('goldens/capsule_drafts_sheet.png'),
      );
    });

    testWidgets('tapping a row opens that draft in the editor', (tester) async {
      _useDesignCanvas(tester);

      final api = _FakeCapsuleApi([
        _capsule(id: 'd1', state: 'draft', content: '今天想跟一年后的你说点什么'),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: CapsulePage(api: api, session: _session),
        ),
      );
      await _settleWithImages(tester);

      await tester.tap(find.text('草稿'));
      await _settleWithImages(tester);
      await tester.tap(find.text('今天想跟一年后的你说点什么'));
      await _settleWithImages(tester);

      // The row is the only way into an unsealed draft, so a swallowed pop
      // value would strand the drafts with no entry point at all.
      expect(find.byType(CapsuleEditorPage), findsOneWidget);
      expect(find.text('草稿'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('opened capsules', () {
    testWidgets('summary card counts the list and rows use dotted dates', (
      tester,
    ) async {
      _useDesignCanvas(tester);

      final api = _FakeCapsuleApi([
        _capsule(
          id: 'o1',
          state: 'opened',
          content: '记得那年夏天的风。',
          openDate: DateTime(2026, 7, 12),
          openedAt: DateTime(2026, 7, 12),
        ),
        _capsule(id: 'r1', state: 'ready', openDate: DateTime(2026, 7, 12)),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: CapsulePage(api: api, session: _session),
        ),
      );
      await _settleWithImages(tester);

      await tester.tap(find.text('已解封'));
      await _settleWithImages(tester);

      // The count is its own span (bigger, orange), so the headline only
      // exists as rich text.
      expect(find.text('共有 2 枚胶囊', findRichText: true), findsOneWidget);
      expect(find.text('已经解封'), findsOneWidget);
      expect(find.text('我的胶囊'), findsOneWidget);
      expect(find.text('2025.07.12 创建'), findsNWidgets(2));
      expect(find.text('2026.07.12 开启'), findsNWidgets(2));
      // Ready rows invite the unseal flow; opened rows only show details.
      expect(find.text('开启'), findsOneWidget);
      expect(find.text('查看详情'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // The opened page is a private route widget, so the whole app is the
      // narrowest finder available here.
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/capsule_opened_list.png'),
      );
    });
  });

  group('compose', () {
    testWidgets('the editor is warm capsule orange, not the app purple', (
      tester,
    ) async {
      _useDesignCanvas(tester);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: CapsulePage(api: _FakeCapsuleApi(const []), session: _session),
        ),
      );
      await _settleWithImages(tester);

      await tester.tap(find.text('写新胶囊'));
      await _settleWithImages(tester);
      expect(find.byType(CapsuleEditorPage), findsOneWidget);

      // The 封存 button, the date pill's calendar and the default letter
      // paper's accent all used to be the app-wide purple, which reads as a
      // different product from the orange screen the editor opens out of.
      final painted = _paintedColors(tester);
      expect(painted, isNot(contains(const Color(0xFF7C3CFF))));
      expect(painted, contains(const Color(0xFFFE9631)));
      expect(tester.takeException(), isNull);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/capsule_composer.png'),
      );
    });

    testWidgets('open-date wheels never list a day already gone', (
      tester,
    ) async {
      _useDesignCanvas(tester);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: CapsulePage(api: _FakeCapsuleApi(const []), session: _session),
        ),
      );
      await _settleWithImages(tester);

      await tester.tap(find.text('写新胶囊'));
      await _settleWithImages(tester);
      await tester.tap(find.text('开启日期'));
      await _settleWithImages(tester);

      final now = DateTime.now();
      // Every rendered row has to be reachable: the wheels are built from
      // clipped lists rather than a full calendar that bounces back.
      expect(
        _wheelValues(tester, '年'),
        everyElement(greaterThanOrEqualTo(now.year)),
      );
      expect(
        _wheelValues(tester, '月'),
        everyElement(greaterThanOrEqualTo(now.month)),
      );
      expect(
        _wheelValues(tester, '日'),
        everyElement(greaterThanOrEqualTo(now.day)),
      );
      // The wheels open on today rather than on some future day.
      expect(_wheelValues(tester, '日').first, now.day);
      expect(tester.takeException(), isNull);
    });
  });

  group('capsule detail', () {
    testWidgets('deleting closes the page and leaves the navigator usable', (
      tester,
    ) async {
      _useDesignCanvas(tester);

      final api = _FakeCapsuleApi(const []);
      Object? popped;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Builder(
            builder: (context) => Center(
              child: CupertinoButton(
                onPressed: () async {
                  popped = await CapsuleEditorPage.push(
                    context,
                    api: api,
                    session: _session,
                    draft: _capsule(
                      id: 'c1',
                      state: 'opened',
                      openedAt: DateTime(2026, 7, 12),
                    ),
                    readOnly: true,
                  );
                },
                child: const Text('详情'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('详情'));
      await tester.pumpAndSettle();
      expect(find.text('胶囊详情'), findsOneWidget);

      // Close on the left and delete on the right are separate widgets, so
      // nothing but this keeps them the same circle: the header reads as
      // lopsided the moment one of them is resized on its own.
      expect(
        _circleSize(tester, CupertinoIcons.xmark),
        _circleSize(tester, CupertinoIcons.delete),
      );

      await tester.tap(find.byIcon(CupertinoIcons.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CupertinoDialogAction, '删除'));
      await tester.pumpAndSettle();

      expect(api.deleted, ['c1']);
      // The delete result is not a chat draft, so a route typed for one used to
      // throw while popping: the page stayed put, the error read 操作失败, and a
      // second attempt hit "Capsule not found" while the navigator stayed
      // locked against every later push and pop.
      expect(find.text('胶囊详情'), findsNothing);
      expect(popped, isNotNull);
      expect(popped, isNot(isA<CapsuleChatDraft>()));
      expect(tester.takeException(), isNull);

      // Proves the navigator is not wedged after the pop.
      await tester.tap(find.text('详情'));
      await tester.pumpAndSettle();
      expect(find.text('胶囊详情'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  test('the capsule editor is only opened through its own route helper', () {
    final builders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where(
          (file) => file.readAsStringSync().contains('=> CapsuleEditorPage('),
        )
        .map((file) => file.path)
        .toList();
    // The editor pops three different result types, so its route has to be
    // Route<Object?>. Hand-rolling the push somewhere else is how a narrower
    // route type slips back in, and that failure mode is a locked navigator
    // rather than a compile error.
    expect(builders, ['lib/src/screens/capsule/capsule_editor.dart']);
  });

  test('no capsule screen reaches for the app-wide purple', () {
    final source = _capsuleSource();
    // Covers the states a widget test never renders — the button's loading
    // spinner, the disabled pill — where the purple used to hide. The
    // 薰衣草信笺 skin keeps its own violet palette on purpose: that one is a
    // letter paper the user picks, not chrome the module imposes.
    expect(source.contains('0xFF7C3CFF'), isFalse);
    // Same purple, string-hex form — this is how ChatComponentCard.accent
    // (a JSON-serializable field, e.g. the "发聊天" share draft) carries a
    // color, and it slipped past the Color(0xFF...) check above once
    // already: the shared time-capsule card's icon rendered purple while
    // every other part of the card (via capsuleSkin) was already orange.
    expect(source.toLowerCase().contains("'#7c3cff'"), isFalse);
  });

  test('every capsule artwork the page names is actually shipped', () {
    final source = _capsuleSource();
    final referenced = RegExp(
      r"'(assets/[^']+)'",
    ).allMatches(source).map((match) => match.group(1)!).toSet();
    expect(referenced, contains('assets/capsule/sealed-card.png'));
    // A renamed or dropped asset only shows up as an empty box at runtime,
    // and the sealed card is now one cut of the design rather than paint
    // calls, so losing it would leave the dialog blank.
    for (final path in referenced) {
      expect(File(path).existsSync(), isTrue, reason: 'missing $path');
    }
  });
}

/// All capsule source: the home entry plus every split file under capsule/.
/// The purple/asset guards must cover the whole feature, not just the slimmed
/// entry file, after the module was split by component/page.
String _capsuleSource() {
  final buffer = StringBuffer(
    File('lib/src/screens/capsule_page.dart').readAsStringSync(),
  );
  final dir = Directory('lib/src/screens/capsule');
  if (dir.existsSync()) {
    for (final file in dir.listSync().whereType<File>()) {
      if (file.path.endsWith('.dart')) {
        buffer.writeln(file.readAsStringSync());
      }
    }
  }
  return buffer.toString();
}

/// Size of the round button drawn behind a header icon.
Size _circleSize(WidgetTester tester, IconData icon) {
  return tester.getSize(
    find
        .ancestor(of: find.byIcon(icon), matching: find.byType(Container))
        .first,
  );
}

/// Every colour the current tree actually paints through an icon, a text style
/// or a box decoration. Cheaper and far more legible than a golden diff when
/// the question is only "is this hue still on screen".
Set<Color> _paintedColors(WidgetTester tester) {
  final colors = <Color>{};
  for (final widget in tester.allWidgets) {
    if (widget is Icon && widget.color != null) colors.add(widget.color!);
    if (widget is Text && widget.style?.color != null) {
      colors.add(widget.style!.color!);
    }
    final decoration = switch (widget) {
      Container(:final decoration) => decoration,
      DecoratedBox(:final decoration) => decoration,
      _ => null,
    };
    if (decoration is BoxDecoration) {
      if (decoration.color != null) colors.add(decoration.color!);
      final border = decoration.border;
      if (border is Border) colors.add(border.top.color);
    }
  }
  return colors;
}

/// Reads the numbers currently laid out in one date wheel column.
List<int> _wheelValues(WidgetTester tester, String suffix) {
  final values = <int>[];
  for (final element in find.byType(Text).evaluate()) {
    final data = (element.widget as Text).data;
    if (data == null || !data.endsWith(suffix)) continue;
    final parsed = int.tryParse(data.substring(0, data.length - 1));
    if (parsed != null) values.add(parsed);
  }
  return values;
}
