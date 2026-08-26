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

int _initialPageOf(WidgetTester tester) {
  final pageView = tester.widget<PageView>(find.byType(PageView));
  return pageView.controller!.initialPage;
}

/// Store content overflows the default (much smaller) test window; use a
/// real-phone-ish size so the assertions below aren't drowned out by
/// unrelated RenderFlex overflow warnings.
void _usePhoneSizedWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('openTicketRecharge lands on section index 3 (充值)', (
    tester,
  ) async {
    _usePhoneSizedWindow(tester);
    await tester.pumpWidget(
      CupertinoApp(
        home: StorePage(
          api: CompanionApi(baseUrl: 'http://localhost'),
          session: _session,
          openTicketRecharge: true,
        ),
      ),
    );
    await tester.pump();

    expect(_initialPageOf(tester), 3);
  });

  testWidgets('no open flag defaults to section index 0 (订阅)', (
    tester,
  ) async {
    _usePhoneSizedWindow(tester);
    await tester.pumpWidget(
      CupertinoApp(
        home: StorePage(
          api: CompanionApi(baseUrl: 'http://localhost'),
          session: _session,
        ),
      ),
    );
    await tester.pump();

    expect(_initialPageOf(tester), 0);
  });

  testWidgets(
    'showVipUpsellDialog: 点击「去充值」进入充值 tab, 不是订阅 tab '
    '(2026-08-26 用户反馈: 这个弹框此前只能导向订阅页)',
    (tester) async {
      _usePhoneSizedWindow(tester);
      final api = CompanionApi(baseUrl: 'http://localhost');
      await tester.pumpWidget(
        CupertinoApp(
          home: Builder(
            builder: (context) => CupertinoButton(
              onPressed: () =>
                  showVipUpsellDialog(context, api: api, session: _session),
              child: const Text('trigger'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();

      expect(find.text('钞票不足'), findsOneWidget);
      await tester.tap(find.text('去充值'));
      await tester.pumpAndSettle();

      expect(_initialPageOf(tester), 3);
    },
  );

  testWidgets('showVipUpsellDialog: 点击「去订阅」进入订阅 tab', (tester) async {
    _usePhoneSizedWindow(tester);
    final api = CompanionApi(baseUrl: 'http://localhost');
    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () =>
                showVipUpsellDialog(context, api: api, session: _session),
            child: const Text('trigger'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('去订阅'));
    await tester.pumpAndSettle();

    expect(_initialPageOf(tester), 0);
  });
}
