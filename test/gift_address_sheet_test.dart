import 'dart:async';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/models.dart';
import 'package:companion_flutter/offline_models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _full = GiftAddress(
  id: 'address',
  recipientName: '测试收件人',
  phone: '13812345678',
  province: '上海市',
  city: '上海市',
  district: '黄浦区',
  detail: '测试街道123号',
  display: '上海市 黄浦区 测试街道***',
);
const _masked = GiftAddress(
  id: 'address',
  recipientName: '测试收件人',
  phone: '138****5678',
  province: '上海市',
  city: '上海市',
  district: '黄浦区',
  detail: '测试街道***',
  display: '上海市 黄浦区 测试街道***',
);
const _session = AuthSession(
  token: 'test',
  userId: 'user',
  username: 'test',
  role: UserRole.user,
  hasAgent: true,
);

class _Api extends CompanionApi {
  _Api() : super(baseUrl: 'https://example.test');
  bool exists = true;
  bool readFails = false;
  bool deleteFails = false;
  bool saveFails = false;
  int homeCalls = 0;
  int deletes = 0;
  String? savedPhone;
  Completer<void>? deleteGate;
  Completer<void>? readGate;
  @override
  Future<GiftsHome> fetchOfflineGifts({String? workspaceId}) async {
    homeCalls++;
    return GiftsHome(address: exists ? _masked : null, groups: const []);
  }

  @override
  Future<GiftAddress> fetchGiftAddress() async {
    await readGate?.future;
    if (readFails) throw const ApiException(503, 'unavailable');
    return exists ? _full : const GiftAddress();
  }

  @override
  Future<void> deleteGiftAddress() async {
    deletes++;
    if (deleteFails) throw const ApiException(503, 'unavailable');
    await deleteGate?.future;
    exists = false;
  }

  @override
  Future<GiftAddress> saveGiftAddress({
    required String recipientName,
    required String phone,
    required String province,
    required String city,
    required String district,
    required String detail,
  }) async {
    if (saveFails) throw const ApiException(503, 'unavailable');
    savedPhone = phone;
    return _full;
  }
}

Future<void> _open(
  WidgetTester tester,
  _Api api, {
  Size size = const Size(390, 844),
  double scale = 1,
  bool waitForAddress = true,
  Duration openingDuration = const Duration(milliseconds: 400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: OfflineGiftPage(api: api, session: _session),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('gift-address-entry')));
  if (waitForAddress) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(openingDuration);
  }
}

Finder get _sheet => find.byKey(const ValueKey('gift-address-sheet'));
Finder get _scroll => find.byKey(const ValueKey('gift-address-scroll'));
Finder get _delete => find.byKey(const ValueKey('gift-address-delete'));
Future<void> _confirmDelete(WidgetTester tester) async {
  await tester.tap(_delete);
  await tester.pumpAndSettle();
  await tester.tap(find.text('删除'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('keyboard closing keeps sheet movement in one direction', (
    tester,
  ) async {
    await _open(tester, _Api());
    await tester.tap(find.byType(CupertinoTextField).at(1));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    await tester.drag(_scroll, const Offset(0, -450));
    await tester.pumpAndSettle();
    await tester.tap(find.text('收货地址').last);
    await tester.pumpAndSettle();
    var previousTop = tester.getTopLeft(_sheet).dy;
    var previousFieldTop = tester
        .getTopLeft(find.byType(CupertinoTextField).last)
        .dy;
    for (final inset in [220.0, 140.0, 80.0, 40.0, 20.0, 1.0, 0.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
      await tester.pump(const Duration(milliseconds: 16));
      final top = tester.getTopLeft(_sheet).dy;
      expect(top, greaterThanOrEqualTo(previousTop), reason: 'inset=$inset');
      final fieldTop = tester
          .getTopLeft(find.byType(CupertinoTextField).last)
          .dy;
      expect(
        fieldTop,
        greaterThanOrEqualTo(previousFieldTop),
        reason: 'field inset=$inset',
      );
      previousTop = top;
      previousFieldTop = fieldTop;
    }
    await tester.pumpAndSettle();
    expect(find.text('保存地址').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('address completing during entrance keeps sheet height stable', (
    tester,
  ) async {
    final gate = Completer<void>();
    await _open(
      tester,
      _Api()..readGate = gate,
      waitForAddress: false,
      openingDuration: const Duration(milliseconds: 100),
    );
    final loadingHeight = tester.getSize(_sheet).height;
    gate.complete();
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getSize(_sheet).height, loadingHeight);
    await tester.pumpAndSettle();
    expect(tester.getSize(_sheet).height, loadingHeight);
    expect(find.text('保存地址').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(390, 844), const Size(430, 932)]) {
    testWidgets('address loading preserves sheet bounds on $size', (
      tester,
    ) async {
      final gate = Completer<void>();
      final api = _Api()..readGate = gate;
      await _open(tester, api, size: size, waitForAddress: false);
      final loadingBounds = tester.getRect(_sheet);
      final detailBounds = tester.getRect(find.byType(CupertinoTextField).last);
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(tester.getRect(_sheet), loadingBounds);
      expect(
        tester.getRect(find.byType(CupertinoTextField).last),
        detailBounds,
      );
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  for (final exists in [true, false]) {
    testWidgets('default form fits without scrolling (saved: $exists)', (
      tester,
    ) async {
      await _open(tester, _Api()..exists = exists);
      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: _scroll, matching: find.byType(Scrollable)).first,
      );
      expect(scrollable.position.maxScrollExtent, 0);
      final save = find.ancestor(
        of: find.text('保存地址'),
        matching: find.byType(CupertinoButton),
      );
      expect(save.hitTestable(), findsOneWidget);
      expect(
        tester.getRect(_scroll).contains(tester.getBottomRight(save)),
        isTrue,
      );
      expect(tester.getTopLeft(_sheet).dy, greaterThanOrEqualTo(59));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'keyboard keeps sheet below safe top, form scrolls and header swipes closed',
    (tester) async {
      await _open(tester, _Api());
      expect(
        tester
            .widgetList<CupertinoTextField>(find.byType(CupertinoTextField))
            .elementAt(1)
            .controller!
            .text,
        '13812345678',
      );
      await tester.tap(find.byType(CupertinoTextField).at(1));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(_sheet).dy, greaterThanOrEqualTo(59));
      expect(tester.getBottomRight(_sheet).dy, closeTo(844, 1));
      final header = tester.getTopLeft(
        find.byKey(const ValueKey('gift-address-grabber')),
      );
      await tester.drag(_scroll, const Offset(0, -450));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
      expect(
        tester
            .widget<CupertinoTextField>(find.byType(CupertinoTextField).at(1))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      expect(find.text('保存地址').hitTestable(), findsOneWidget);
      expect(tester.getBottomRight(find.text('保存地址')).dy, lessThan(544));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('gift-address-grabber'))),
        header,
      );
      await tester.drag(
        find.byKey(const ValueKey('gift-address-grabber')),
        const Offset(0, 700),
      );
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'barrier first hides keyboard, next tap dismisses address sheet',
    (tester) async {
      await _open(tester, _Api());
      await tester.tap(find.byType(CupertinoTextField).at(1));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.tapAt(const Offset(10, 50));
      await tester.pumpAndSettle();
      expect(_sheet, findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse);
      // The OS reports the closing keyboard's new inset separately.
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      expect(find.text('保存地址').hitTestable(), findsOneWidget);
      await tester.tapAt(const Offset(10, 50));
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('blank sheet area hides keyboard without dismissing the sheet', (
    tester,
  ) async {
    await _open(tester, _Api());
    await tester.tap(find.byType(CupertinoTextField).last);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    await tester.tap(find.text('收货地址').last);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(_sheet, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'delete can be cancelled, confirmed and refreshes saved address',
    (tester) async {
      final api = _Api();
      await _open(tester, api);
      await tester.tap(_delete);
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(api.deletes, 0);
      expect(_sheet, findsOneWidget);
      await _confirmDelete(tester);
      expect(api.deletes, 1);
      expect(_sheet, findsNothing);
      expect(find.text('添加地址，方便接收礼物'), findsOneWidget);
      expect(api.homeCalls, 2);
    },
  );

  testWidgets('failed delete retains address and offers retry', (tester) async {
    final api = _Api()..deleteFails = true;
    await _open(tester, api);
    await _confirmDelete(tester);
    expect(find.text('地址删除失败，请重试'), findsOneWidget);
    expect(_sheet, findsOneWidget);
    expect(api.homeCalls, 1);
    api.deleteFails = false;
    await _confirmDelete(tester);
    expect(_sheet, findsNothing);
    expect(api.deletes, 2);
  });

  testWidgets('address read failure blocks masked overwrite and can retry', (
    tester,
  ) async {
    final api = _Api()..readFails = true;
    await _open(tester, api);
    expect(find.text('地址加载失败，请重试'), findsOneWidget);
    expect(
      tester
          .widgetList<CupertinoTextField>(find.byType(CupertinoTextField))
          .elementAt(1)
          .controller!
          .text,
      isEmpty,
    );
    expect(tester.widget<CupertinoButton>(_delete).onPressed, isNull);
    api.readFails = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<CupertinoTextField>(find.byType(CupertinoTextField))
          .elementAt(1)
          .controller!
          .text,
      '13812345678',
    );
    await tester.ensureVisible(find.text('保存地址'));
    await tester.tap(find.text('保存地址'));
    await tester.pumpAndSettle();
    expect(api.savedPhone, '13812345678');
    expect(_sheet, findsNothing);
  });

  testWidgets('save failure is visible and retains edited values', (
    tester,
  ) async {
    final api = _Api()..saveFails = true;
    await _open(tester, api);
    await tester.ensureVisible(find.text('保存地址'));
    await tester.tap(find.text('保存地址'));
    await tester.pumpAndSettle();
    expect(find.text('地址保存失败，请重试'), findsOneWidget);
    expect(_sheet, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'new address has no delete button and fits large text with keyboard',
    (tester) async {
      await _open(
        tester,
        _Api()..exists = false,
        size: const Size(320, 640),
        scale: 1.6,
      );
      expect(_delete, findsNothing);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      await tester.drag(_scroll, const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(find.text('保存地址').hitTestable(), findsOneWidget);
      expect(tester.getTopLeft(_sheet).dy, greaterThanOrEqualTo(59));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'deletion completing after sheet dismissal still refreshes home',
    (tester) async {
      final api = _Api()..deleteGate = Completer<void>();
      await _open(tester, api);
      await _confirmDelete(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);
      api.deleteGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('添加地址，方便接收礼物'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
