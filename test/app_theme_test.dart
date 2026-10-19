import 'package:companion_flutter/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('all three choices survive controller restoration', () async {
    final controller = AppThemeController();
    addTearDown(controller.dispose);
    for (final mode in [ThemeMode.dark, ThemeMode.light, ThemeMode.system]) {
      await controller.setMode(mode);
      final restored = AppThemeController();
      await restored.restore();
      expect(restored.mode, mode);
      restored.dispose();
    }
  });

  test(
    'first launch defaults to automatic, existing explicit choices are retained',
    () async {
      for (final entry in <String?, ThemeMode>{
        null: ThemeMode.system,
        'system': ThemeMode.system,
        'light': ThemeMode.light,
        'dark': ThemeMode.dark,
      }.entries) {
        FlutterSecureStorage.setMockInitialValues({
          if (entry.key != null) 'app_theme_mode': entry.key!,
        });
        final controller = AppThemeController();
        await controller.restore();
        expect(controller.mode, entry.value);
        controller.dispose();
      }
    },
  );

  testWidgets(
    'real app follows system events in automatic mode and preserves manual overrides',
    (tester) async {
      final dispatcher = tester.binding.platformDispatcher;
      addTearDown(dispatcher.clearPlatformBrightnessTestValue);
      addTearDown(() async {
        await appThemeController.setMode(ThemeMode.system);
        AppColors.use(Brightness.light);
      });
      await appThemeController.setMode(ThemeMode.system);
      dispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpWidget(const CompanionApp());
      await tester.pump();

      void expectAppearance(Brightness brightness) {
        final context = tester.element(find.byType(Navigator).first);
        expect(Theme.of(context).brightness, brightness);
        expect(CupertinoTheme.of(context).brightness, brightness);
        expect(
          AppColors.current.page,
          brightness == Brightness.dark
              ? AppColors.dark.page
              : AppColors.light.page,
        );
      }

      Future<void> system(Brightness brightness) async {
        dispatcher.platformBrightnessTestValue = brightness;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      expectAppearance(Brightness.light);
      await system(Brightness.dark);
      expectAppearance(Brightness.dark);
      await appThemeController.setMode(ThemeMode.light);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expectAppearance(Brightness.light);
      await system(Brightness.light);
      await system(Brightness.dark);
      expectAppearance(Brightness.light);
      await appThemeController.setMode(ThemeMode.dark);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await system(Brightness.light);
      expectAppearance(Brightness.dark);
      await appThemeController.setMode(ThemeMode.system);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expectAppearance(Brightness.light);
      await system(Brightness.dark);
      expectAppearance(Brightness.dark);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
