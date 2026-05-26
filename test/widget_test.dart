import 'package:companion_flutter/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders prototype login entry and opens backend form', (
    tester,
  ) async {
    await tester.pumpWidget(const CompanionApp());

    expect(find.text('从一句话开始'), findsOneWidget);
    expect(find.text('Ban Sheng'), findsOneWidget);
    expect(find.text('手机号登录'), findsOneWidget);
    expect(find.text('or'), findsOneWidget);
    expect(find.text('后端地址'), findsNothing);

    await tester.tap(find.text('手机号登录'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('后端地址'), findsOneWidget);
    expect(find.text('账号'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
  });

  testWidgets('renders wechat login button', (tester) async {
    await tester.pumpWidget(const CompanionApp());

    expect(find.byIcon(CupertinoIcons.chat_bubble_2_fill), findsOneWidget);
  });
}
