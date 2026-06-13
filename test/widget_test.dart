import 'package:companion_flutter/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpLoginPage(WidgetTester tester) async {
  await tester.pumpWidget(const CompanionApp());
  for (var i = 0; i < 10; i += 1) {
    await tester.pump(const Duration(milliseconds: 50));
    if (find.text('从一句话开始').evaluate().isNotEmpty) return;
  }
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('renders prototype login entry and opens backend form', (
    tester,
  ) async {
    await pumpLoginPage(tester);

    expect(find.text('从一句话开始'), findsOneWidget);
    expect(find.text('Ban Sheng'), findsOneWidget);
    expect(find.text('手机号登录'), findsOneWidget);
    expect(find.text('or'), findsOneWidget);
    expect(find.text('后端地址'), findsNothing);

    await tester.tap(find.text('手机号登录'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('后端地址'), findsOneWidget);
    expect(find.text('登录'), findsWidgets);
    expect(find.text('注册'), findsOneWidget);
    expect(find.text('账号'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
  });

  testWidgets('renders wechat login button', (tester) async {
    await pumpLoginPage(tester);

    expect(find.bySemanticsLabel('微信'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.chat_bubble_2_fill), findsNothing);
  });
}
