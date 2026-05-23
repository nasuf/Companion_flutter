import 'package:companion_flutter/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders backend login form', (tester) async {
    await tester.pumpWidget(const CompanionApp());

    expect(find.text('从一句话开始'), findsOneWidget);
    expect(find.text('后端地址'), findsOneWidget);
    expect(find.text('账号'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
  });
}
