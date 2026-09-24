part of 'package:companion_flutter/main.dart';

// ===========================================================================
// Reusable admin UI primitives
// ===========================================================================

/// Full-screen scaffold shared by every admin dashboard sub-page: animated
/// backdrop + centered title + optional trailing action.
/// Drag-to-dismiss keyboard for all admin scroll views.
class _AdminScrollBehavior extends ScrollBehavior {
  const _AdminScrollBehavior();

  @override
  ScrollViewKeyboardDismissBehavior getKeyboardDismissBehavior(
    BuildContext context,
  ) {
    return ScrollViewKeyboardDismissBehavior.onDrag;
  }
}

/// Bottom color of [_ProfileBackgroundPainter] — fills IME corner gaps if any
/// pixel misses the custom paint layer.
Color _adminPageBaseColor(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? const Color(0xFF0D1211) : const Color(0xFFEEF9F8);
}

/// Cupertino admin pages must opt out of viewport shrink so the gradient
/// background paints through the iOS keyboard corner radii (not black gaps).
/// Both [CupertinoPageScaffold] and [Scaffold] need resizeToAvoidBottomInset:
/// false — the Cupertino wrapper defaults to true and would shrink the route
/// even when the inner Material scaffold opts out.
Widget _adminPageHost({required Widget body}) {
  return Builder(
    builder: (context) {
      final baseColor = _adminPageBaseColor(context);
      return CupertinoPageScaffold(
        backgroundColor: baseColor,
        resizeToAvoidBottomInset: false,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: baseColor,
          body: body,
        ),
      );
    },
  );
}

/// Animated admin background stays full-screen; foreground lifts above keyboard.
Widget _buildAdminKeyboardAwareStack({
  required BuildContext context,
  required double motionProgress,
  required Widget child,
}) {
  final keyboard = MediaQuery.viewInsetsOf(context).bottom;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Stack(
    fit: StackFit.expand,
    children: [
      Positioned.fill(
        child: CustomPaint(
          painter: _ProfileBackgroundPainter(
            progress: motionProgress,
            isDark: isDark,
          ),
        ),
      ),
      Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: ScrollConfiguration(
          behavior: const _AdminScrollBehavior(),
          child: child,
        ),
      ),
    ],
  );
}

/// Full-screen modal host for admin form dialogs (search / grant / VIP).
class _AdminDialogHost extends StatelessWidget {
  const _AdminDialogHost({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final fullHeight = media.size.height + keyboard;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      body: SizedBox(
        height: fullHeight,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.black.withValues(alpha: 0.42)),
            ),
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 36, 20, 36 + keyboard),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White dialog panel for admin forms with text fields.
class _AdminFormDialogFrame extends StatelessWidget {
  const _AdminFormDialogFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxWidth: 460,
        maxHeight: math.min(
          MediaQuery.sizeOf(context).height * 0.82,
          MediaQuery.sizeOf(context).height - 72,
        ),
      ),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2024) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ScrollConfiguration(
        behavior: const _AdminScrollBehavior(),
        child: child,
      ),
    );
  }
}

/// Transparent scaffold root for admin bottom sheets with text fields.
Widget _adminSheetHost({required Widget child}) {
  return Scaffold(
    resizeToAvoidBottomInset: false,
    backgroundColor: Colors.transparent,
    // Modal sheet children declare their own height; pin them to the bottom
    // edge — a bare Scaffold body top-aligns and pushes the panel upward.
    body: Align(
      alignment: Alignment.bottomCenter,
      child: child,
    ),
  );
}

/// Admin dialogs draw their own scrim via [_AdminDialogHost].
Future<T?> showAdminDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.transparent,
    builder: builder,
  );
}

class _AdminScaffold extends StatefulWidget {
  const _AdminScaffold({
    required this.title,
    required this.child,
    this.trailing,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  State<_AdminScaffold> createState() => _AdminScaffoldState();
}

class _AdminScaffoldState extends State<_AdminScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motionController;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _adminPageHost(
      body: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: _motionController,
          builder: (context, _) {
            return _buildAdminKeyboardAwareStack(
              context: context,
              motionProgress: _motionController.value,
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      18,
                      media.padding.top + 12,
                      18,
                      4,
                    ),
                    child: SizedBox(
                      height: 48,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _AppNavCircleButton(
                              icon: CupertinoIcons.chevron_left,
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.text
                                      : const Color(0xFF12171B),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              if (widget.subtitle != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    widget.subtitle!,
                                    style: TextStyle(
                                      color: isDark
                                          ? const Color(0x9EEBF2EE)
                                          : AppColors.muted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (widget.trailing != null)
                            Align(
                              alignment: Alignment.centerRight,
                              child: widget.trailing,
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                      child: widget.child,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Glass card container used to group dashboard content.
class _AdminCard extends StatelessWidget {
  const _AdminCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.64),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.of(
              context,
            ).shadow.withValues(alpha: isDark ? 0.4 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Admin form bottom sheet shell — background extends behind the keyboard
/// (RedPacketSendSheet geometry). [child] is padded above the IME.
class _AdminSheetLayout extends StatelessWidget {
  const _AdminSheetLayout({
    required this.backgroundColor,
    required this.child,
    this.heightFraction = 0.58,
    this.borderRadius = 22,
    this.horizontalPadding = 18,
  });

  final Color backgroundColor;
  final Widget child;
  final double heightFraction;
  final double borderRadius;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final baseHeight = media.size.height * heightFraction;
    // Grow through the IME slot so iOS keyboard corner radii show sheet color
    // (same geometry as RedPacketSendSheet).
    final sheetHeight = math.min(baseHeight + keyboard, media.size.height);
    final contentBottom =
        keyboard > 0 ? keyboard + 12 : 12 + media.padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: sheetHeight,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(borderRadius),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(borderRadius),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              contentBottom,
            ),
            child: ScrollConfiguration(
              behavior: const _AdminScrollBehavior(),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminSheetGrabber extends StatelessWidget {
  const _AdminSheetGrabber();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.22)
                : Colors.black.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }
}

class _AdminSectionTitle extends StatelessWidget {
  const _AdminSectionTitle({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: isDark ? AppColors.text : const Color(0xFF12171B),
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// KPI stat tile.
class _AdminStatTile extends StatelessWidget {
  const _AdminStatTile({
    required this.label,
    required this.value,
    this.sub,
    this.accent = false,
    this.warn = false,
    this.onTap,
    this.badge,
  });

  final String label;
  final String value;
  final String? sub;
  final bool accent;
  final bool warn;
  final VoidCallback? onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppColors.of(context);
    final valueColor = warn
        ? colors.danger
        : accent
        ? colors.accent
        : (isDark ? AppColors.text : const Color(0xFF12171B));
    final content = Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: warn
            ? colors.danger.withValues(alpha: 0.10)
            : isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: warn
              ? colors.danger.withValues(alpha: 0.28)
              : isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0x14181F2A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              if (badge != null) badge!,
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(
              sub!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.42)
                    : const Color(0x8012171B),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: content,
    );
  }
}

/// Responsive KPI grid (2 columns on phones).
/// Responsive KPI grid (2 columns on phones). Each row uses IntrinsicHeight +
/// stretched Expanded so both tiles in a row share the tallest tile's height —
/// tiles with and without a subtitle stay perfectly aligned.
class _AdminStatGrid extends StatelessWidget {
  const _AdminStatGrid({required this.tiles});

  static const int _columns = 2;
  static const double _spacing = 10;

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += _columns) {
      final rowChildren = <Widget>[];
      for (var c = 0; c < _columns; c++) {
        if (c > 0) rowChildren.add(const SizedBox(width: _spacing));
        final index = i + c;
        rowChildren.add(
          Expanded(
            child: index < tiles.length
                ? tiles[index]
                : const SizedBox.shrink(),
          ),
        );
      }
      if (rows.isNotEmpty) rows.add(const SizedBox(height: _spacing));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rowChildren,
          ),
        ),
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

/// Segmented control for window selection.
class _AdminSegment<T> extends StatelessWidget {
  const _AdminSegment({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<MapEntry<T, String>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0x14181F2A),
        ),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(option.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: option.key == value
                        ? colors.accent
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    option.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: option.key == value
                          ? Colors.white
                          : (isDark
                                ? const Color(0xB0EBF2EE)
                                : AppColors.muted),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AdminInlineHint extends StatelessWidget {
  const _AdminInlineHint({required this.text, this.height = 180});

  final String text;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: height,
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
