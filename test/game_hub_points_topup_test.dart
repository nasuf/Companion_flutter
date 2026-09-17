import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

const _session = AuthSession(
  token: 't',
  userId: 'u1',
  username: 'tester',
  role: UserRole.user,
  hasAgent: true,
  agentId: 'a1',
);

/// The hub breathes its card art forever, so pumpAndSettle never returns here.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

int _initialPageOf(WidgetTester tester) {
  final pageView = tester.widget<PageView>(find.byType(PageView));
  return pageView.controller!.initialPage;
}

Finder _coinPlus() => find.byWidgetPredicate(
  (w) =>
      w is Image &&
      w.image is AssetImage &&
      (w.image as AssetImage).assetName.endsWith('coin_plus.png'),
);

Future<void> _pumpHub(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    CupertinoApp(
      home: GamePage(
        api: CompanionApi(baseUrl: 'http://localhost'),
        session: _session,
      ),
    ),
  );
  // The hub fires wallet / catalog / stats on mount; they fail against this
  // host, which is fine — the top bar renders either way.
  await _settle(tester);
}

/// The hub's ＋ is the only way in to buying game points, and they are sold in
/// the store's 礼包 tab — landing anywhere else leaves the player to find it.
void main() {
  testWidgets('积分 ＋ 确认后进入商城「礼包」tab', (tester) async {
    await _pumpHub(tester);

    await tester.tap(_coinPlus());
    await _settle(tester);
    expect(find.text('游戏积分'), findsOneWidget);

    await tester.tap(find.text('去商城'));
    await _settle(tester);

    expect(find.byType(StorePage), findsOneWidget);
    expect(_initialPageOf(tester), 1, reason: '礼包是第 2 个 tab');
  });

  testWidgets('取消则留在游戏主页', (tester) async {
    await _pumpHub(tester);

    await tester.tap(_coinPlus());
    await _settle(tester);
    await tester.tap(find.text('取消'));
    await _settle(tester);

    expect(find.byType(StorePage), findsNothing);
    expect(find.byType(GamePage), findsOneWidget);
  });
}
