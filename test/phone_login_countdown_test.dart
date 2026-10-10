import 'package:companion_flutter/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'SMS attempt disables resend for 30 seconds despite HTTP failure',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(home: LoginPage(onAuthenticated: (_, _) {})),
      );
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == '手机号登录',
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('同意并继续'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      TextButton button(String label) =>
          tester.widget<TextButton>(find.widgetWithText(TextButton, label));
      expect(button('获取验证码').onPressed, isNull);
      await tester.enterText(find.byType(TextField).first, '15601905361');
      await tester.pump();
      expect(button('获取验证码').onPressed, isNotNull);
      await tester.tap(find.text('获取验证码'));
      await tester.pump();
      // Test HTTP requests fail; the cooldown must survive that failure.
      await tester.pump();
      expect(button('30s').onPressed, isNull);
      await tester.pump(const Duration(seconds: 1));
      expect(button('29s').onPressed, isNull);
      await tester.tap(find.text('29s'));
      await tester.pump(const Duration(seconds: 28));
      expect(button('1s').onPressed, isNull);
      await tester.pump(const Duration(seconds: 1));
      expect(button('获取验证码').onPressed, isNotNull);
      await tester.tap(find.text('获取验证码'));
      await tester.pump();
      expect(button('30s').onPressed, isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 31));
      expect(tester.takeException(), isNull);
    },
  );
}
