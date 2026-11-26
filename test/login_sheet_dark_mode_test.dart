import 'package:companion_flutter/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 登录 bottom sheet 固定是浅色底（白色输入框）。深色模式下输入的文字必须仍是
/// 深色，否则是浅色字落在白底上，用户看不清自己输入的手机号和验证码。
Future<void> _openPhoneSheet(WidgetTester tester, Brightness brightness) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.materialTheme(brightness),
      home: LoginPage(onAuthenticated: (_, _) {}),
    ),
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
}

void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('$brightness phone login keeps the typed digits readable', (
      tester,
    ) async {
      await _openPhoneSheet(tester, brightness);
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2));
      await tester.enterText(fields.first, '15601905361');
      await tester.enterText(fields.last, '123456');
      await tester.pump();
      for (var i = 0; i < 2; i++) {
        final field = tester.widget<TextField>(fields.at(i));
        // 白色输入框上的深色字，不跟随主题。
        expect(field.style?.color, const Color(0xFF111111), reason: 'field $i');
        final decoration = field.decoration!;
        expect(decoration.fillColor, Colors.white);
        expect(
          (decoration.labelStyle as TextStyle).color,
          const Color(0xFF7B8582),
        );
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  }
}
