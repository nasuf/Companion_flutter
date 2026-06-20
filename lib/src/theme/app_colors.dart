part of 'package:companion_flutter/main.dart';

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.page,
    required this.surface,
    required this.surfaceMuted,
    required this.glass,
    required this.input,
    required this.hairline,
    required this.text,
    required this.muted,
    required this.accent,
    required this.accentDeep,
    required this.accentSoft,
    required this.accentCyan,
    required this.danger,
    required this.shadow,
  });

  final Color page;
  final Color surface;
  final Color surfaceMuted;
  final Color glass;
  final Color input;
  final Color hairline;
  final Color text;
  final Color muted;
  final Color accent;
  final Color accentDeep;
  final Color accentSoft;
  final Color accentCyan;
  final Color danger;
  final Color shadow;

  @override
  AppPalette copyWith({
    Color? page,
    Color? surface,
    Color? surfaceMuted,
    Color? glass,
    Color? input,
    Color? hairline,
    Color? text,
    Color? muted,
    Color? accent,
    Color? accentDeep,
    Color? accentSoft,
    Color? accentCyan,
    Color? danger,
    Color? shadow,
  }) {
    return AppPalette(
      page: page ?? this.page,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      glass: glass ?? this.glass,
      input: input ?? this.input,
      hairline: hairline ?? this.hairline,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      accent: accent ?? this.accent,
      accentDeep: accentDeep ?? this.accentDeep,
      accentSoft: accentSoft ?? this.accentSoft,
      accentCyan: accentCyan ?? this.accentCyan,
      danger: danger ?? this.danger,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      page: Color.lerp(page, other.page, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      input: Color.lerp(input, other.input, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentDeep: Color.lerp(accentDeep, other.accentDeep, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentCyan: Color.lerp(accentCyan, other.accentCyan, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

class AppColors {
  static const light = AppPalette(
    page: Color(0xFFF7FAFF),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEFF5FF),
    glass: Color(0xA8FFFFFF),
    input: Color(0xFFFFFFFF),
    hairline: Color(0xFFE1E9F6),
    text: Color(0xFF101418),
    muted: Color(0xFF7D8790),
    accent: Color(0xFF0A84FF),
    accentDeep: Color(0xFF1F6FFF),
    accentSoft: Color(0xFFE8F3FF),
    accentCyan: Color(0xFF18C6C0),
    danger: Color(0xFFD95B5B),
    shadow: Color(0x1F315B88),
  );

  static const dark = AppPalette(
    page: Color(0xFF080D14),
    surface: Color(0xFF101820),
    surfaceMuted: Color(0xFF182331),
    glass: Color(0xCC121A24),
    input: Color(0xFF121B25),
    hairline: Color(0xFF263445),
    text: Color(0xFFF2F7FB),
    muted: Color(0xFF9AA8B8),
    accent: Color(0xFF4BA3FF),
    accentDeep: Color(0xFF5C93FF),
    accentSoft: Color(0xFF17324C),
    accentCyan: Color(0xFF2DD8D2),
    danger: Color(0xFFFF7777),
    shadow: Color(0x99000000),
  );

  static AppPalette _current = light;

  static AppPalette get current => _current;

  static AppPalette of(BuildContext context) {
    return Theme.of(context).extension<AppPalette>() ?? _current;
  }

  static AppPalette paletteFor(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }

  static void use(Brightness brightness) {
    _current = paletteFor(brightness);
  }

  static Color get page => _current.page;
  static Color get surface => _current.surface;
  static Color get surfaceMuted => _current.surfaceMuted;
  static Color get glass => _current.glass;
  static Color get input => _current.input;
  static Color get hairline => _current.hairline;
  static Color get text => _current.text;
  static Color get muted => _current.muted;
  static Color get accent => _current.accent;
  static Color get accentDeep => _current.accentDeep;
  static Color get accentSoft => _current.accentSoft;
  static Color get accentCyan => _current.accentCyan;
  static Color get danger => _current.danger;
  static Color get shadow => _current.shadow;
  static Color get wechatGreen => accent;

  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Color elevatedSurface(BuildContext context, {double light = 0.82}) {
    final colors = of(context);
    return isDark(context)
        ? colors.surface.withValues(alpha: 0.86)
        : colors.surface.withValues(alpha: light);
  }

  static Color glassBorder(BuildContext context, {double light = 0.78}) {
    final colors = of(context);
    return isDark(context)
        ? Colors.white.withValues(alpha: 0.12)
        : colors.hairline.withValues(alpha: light);
  }

  static Color subtleFill(BuildContext context, {double light = 0.66}) {
    final colors = of(context);
    return isDark(context)
        ? colors.surfaceMuted.withValues(alpha: 0.72)
        : colors.surface.withValues(alpha: light);
  }
}
