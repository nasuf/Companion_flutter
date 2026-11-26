import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api extends CompanionApi {
  _Api() : super(baseUrl: 'https://synthetic.test');
  @override
  Future<bool> getRealMoneyPaymentsEnabled() async => false;
  @override
  Future<WalletBalance> getWallet({String? agentId}) async =>
      const WalletBalance(
        ticketBalance: 1000,
        pointBalance: 1000,
        achievementPointsSynced: 0,
      );
  @override
  Future<IapMembership> getIapMembership({int historyLimit = 50}) async =>
      IapMembership(
        vip: VipStatus(
          isVip: false,
          vipUntil: null,
          vipTrialAvailable: true,
          giftTicketBalance: 0,
          ticketBalance: 1000,
          pointBalance: 1000,
          spendableTickets: 1000,
        ),
        autoRenewActive: false,
        history: [],
      );
}

const _session = AuthSession(
  token: 'synthetic',
  userId: 'test',
  username: 'test',
  role: UserRole.user,
  hasAgent: true,
  agentId: 'a',
);

const _labels = ['饮品', '鲜花', '生活', '饰品', '配饰', '数码', '美食', '奢享'];

Finder _tab(String label) => find.descendant(
  of: find.byKey(const ValueKey('exchange-gift-tabs')),
  matching: find.text(label),
);

void main() {
  testWidgets(
    'exchange shows gift subcategories as scrollable top tabs that reveal neighbours',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          home: StorePage(api: _Api(), session: _session, openExchange: true),
        ),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));

      expect(find.text('盲盒'), findsNothing);
      expect(find.text('装扮'), findsNothing);
      expect(find.text('礼物'), findsNothing);
      for (final label in _labels) {
        expect(_tab(label), findsOneWidget);
      }

      bool fullyVisible(String label) {
        final rect = t.getRect(_tab(label));
        return rect.left >= 0 && rect.right <= 390;
      }

      // 8 个分类在 390 宽的屏上放不下，最右侧至少一个被截断。
      expect(fullyVisible('奢享'), isFalse);
      final lastVisible = _labels.lastWhere(fullyVisible);
      final next = _labels[_labels.indexOf(lastVisible) + 1];
      expect(fullyVisible(next), isFalse);

      // 点最右边露全的 tab：它右边的邻居被滚进来。
      await t.tap(_tab(lastVisible));
      await t.pumpAndSettle();
      expect(fullyVisible(lastVisible), isTrue);
      expect(fullyVisible(next), isTrue);

      // 一路点到最后一个，左侧被滚出去。
      await t.tap(_tab(next));
      await t.pumpAndSettle();
      await t.ensureVisible(_tab('奢享'));
      await t.pumpAndSettle();
      await t.tap(_tab('奢享'));
      await t.pumpAndSettle();
      expect(fullyVisible('奢享'), isTrue);
      expect(fullyVisible('饮品'), isFalse);

      // 回头点左边贴边的 tab：它左边的邻居也露出来。
      final firstVisible = _labels.firstWhere(fullyVisible);
      final previous = _labels[_labels.indexOf(firstVisible) - 1];
      expect(fullyVisible(previous), isFalse);
      await t.tap(_tab(firstVisible));
      await t.pumpAndSettle();
      expect(fullyVisible(firstVisible), isTrue);
      expect(fullyVisible(previous), isTrue);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('large system font keeps the tab bar from overflowing', (
    t,
  ) async {
    t.view.physicalSize = const Size(360, 720);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(
      MaterialApp(
        home: StorePage(api: _Api(), session: _session, openExchange: true),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    await t.tap(_tab('鲜花'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
