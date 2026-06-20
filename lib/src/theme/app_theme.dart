part of 'package:companion_flutter/main.dart';

class AppThemeController extends ChangeNotifier {
  static const _storageKey = 'app_theme_mode';
  static const _storage = FlutterSecureStorage();

  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  Future<void> restore() async {
    final raw = await _storage.read(key: _storageKey);
    _mode = _decode(raw);
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    await _storage.write(key: _storageKey, value: _encode(mode));
  }

  Brightness resolveBrightness(Brightness platformBrightness) {
    return switch (_mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => platformBrightness,
    };
  }

  String labelFor(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => '跟随系统',
      ThemeMode.light => '浅色',
      ThemeMode.dark => '深色',
    };
  }

  String get currentLabel => labelFor(_mode);

  static ThemeMode _decode(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static String _encode(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }
}
