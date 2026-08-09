part of 'package:companion_flutter/main.dart';

/// What the 12px mark under a day number says about that day.
enum _CheckinDayMark {
  /// Nothing scheduled — a flat grey dot.
  none,

  /// Scheduled, nothing ticked yet — a solid accent dot.
  pending,

  /// Some of the day's tasks are ticked — an accent ring.
  partial,

  /// Everything on that day is ticked — an accent disc with a check.
  done,
}

const String _kCheckinAsset = 'assets/checkin/';

// Geometry lifted from the Figma frames (390x844). Horizontal values stay put
// on wider screens; only the day columns and cards stretch.
const double _kCheckinMargin = 16;
const double _kCheckinCardRadius = 20;
const double _kCheckinCardPadX = 18;
const double _kCheckinDayWidth = 36;
const double _kCheckinDayHeight = 54;
const double _kCheckinCalendarCollapsed = 164;
const double _kCheckinCalendarExpanded = 428;
const double _kCheckinTaskRowHeight = 75;
const double _kCheckinTaskRowGap = 12;
const double _kCheckinSectionGap = 36;
const double _kCheckinSectionTitleGap = 16;
const double _kCheckinFabSize = 56;

// Editor sheet, measured from the sheet's own top edge (design y=164).
const double _kCheckinSheetRatio = 680 / 844;
const double _kCheckinSheetPadTop = 36;
const double _kCheckinSheetFieldGap = 24;
const double _kCheckinSheetSaveGap = 36;
const double _kCheckinFieldHeight = 44;
const double _kCheckinSaveHeight = 52;

/// Colours for the check-in surface.
///
/// The Figma file only ships a light theme. The dark values are a mapping that
/// keeps the same contrast steps rather than a second design.
@immutable
class _CheckinTokens {
  const _CheckinTokens({
    required this.page,
    required this.card,
    required this.accent,
    required this.accentSoft,
    required this.accentInk,
    required this.dayPill,
    required this.noteField,
    required this.markIdle,
    required this.title,
    required this.sectionTitle,
    required this.subtitle,
    required this.placeholder,
    required this.dayNumber,
    required this.scrim,
    required this.cardShadowColor,
    required this.navShadowColor,
  });

  final Color page;
  final Color card;
  final Color accent;
  final Color accentSoft;
  final Color accentInk;
  final Color dayPill;
  final Color noteField;
  final Color markIdle;
  final Color title;
  final Color sectionTitle;
  final Color subtitle;
  final Color placeholder;
  final Color dayNumber;
  final Color scrim;
  final Color cardShadowColor;
  final Color navShadowColor;

  static const light = _CheckinTokens(
    page: Color(0xFFF0F3FF),
    card: Color(0xFFFFFFFF),
    accent: Color(0xFF496CFC),
    accentSoft: Color(0x33496CFC),
    accentInk: Color(0xFF434399),
    dayPill: Color(0xFFF2F0F9),
    noteField: Color(0xFFF1F0F9),
    markIdle: Color(0xFFDFDFDF),
    title: Color(0xFF000000),
    sectionTitle: Color(0xFF333333),
    subtitle: Color(0xFF414443),
    placeholder: Color(0xFF888888),
    dayNumber: Color(0xFF000000),
    scrim: Color(0xB3000000),
    cardShadowColor: Color(0x1A496CFC),
    navShadowColor: Color(0x40B0A2F7),
  );

  static const dark = _CheckinTokens(
    page: Color(0xFF080D14),
    card: Color(0xFF131C27),
    accent: Color(0xFF6C8BFF),
    accentSoft: Color(0x386C8BFF),
    accentInk: Color(0xFFAEBBFF),
    dayPill: Color(0xFF1B2432),
    noteField: Color(0xFF1B2432),
    markIdle: Color(0xFF3A4658),
    title: Color(0xFFF2F7FB),
    sectionTitle: Color(0xFFE4EBF3),
    subtitle: Color(0xFF9AA8B8),
    placeholder: Color(0xFF7F8B9A),
    dayNumber: Color(0xFFE4EBF3),
    scrim: Color(0xC7000000),
    cardShadowColor: Color(0x99000000),
    navShadowColor: Color(0x99000000),
  );

  static _CheckinTokens of(BuildContext context) =>
      AppColors.isDark(context) ? dark : light;

  /// `box-shadow: 0px 8px 16px` on every card in the design.
  List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: cardShadowColor,
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  /// The shallower `0px 4px 4px` used by the round nav button and the FAB.
  List<BoxShadow> get navShadow => [
    BoxShadow(color: navShadowColor, blurRadius: 4, offset: const Offset(0, 4)),
  ];

  List<BoxShadow> get fabShadow => [
    BoxShadow(
      color: accent.withValues(alpha: 0.25),
      blurRadius: 16,
      offset: const Offset(2, 8),
    ),
  ];
}

/// A text field with no chrome of its own.
///
/// The app theme fills and outlines every `TextField`, and its `enabledBorder`
/// outranks a plain `border: none`, so each slot has to be cleared by hand —
/// otherwise a second rounded outline shows up inside the card that already
/// draws the field.
InputDecoration _checkinBareInput({
  required String hint,
  required TextStyle hintStyle,
}) {
  return InputDecoration(
    isDense: true,
    filled: false,
    counterText: '',
    contentPadding: EdgeInsets.zero,
    hintText: hint,
    hintStyle: hintStyle,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
  );
}

/// The design's "done" mark: a filled accent disc with the check knocked out.
///
/// It shows up at three sizes — 12px under a calendar day, 12px on a weekday
/// pill, 24px on a task row — and all three are the same glyph.
class _CheckinCheckBadge extends StatelessWidget {
  const _CheckinCheckBadge({
    required this.size,
    required this.color,
    this.checkColor = Colors.white,
  });

  final double size;
  final Color color;

  /// Inverted on today's filled pill, where the disc itself has to be white.
  final Color checkColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(
        Icons.check_rounded,
        size: size * 0.78,
        color: checkColor,
        weight: 700,
      ),
    );
  }
}

/// The unchecked counterpart: a hairline ring.
class _CheckinRingMark extends StatelessWidget {
  const _CheckinRingMark({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
    );
  }
}
