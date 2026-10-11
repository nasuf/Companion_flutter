part of 'package:companion_flutter/main.dart';

class _ExpandedSheetTopBar extends StatelessWidget {
  const _ExpandedSheetTopBar({
    required this.title,
    required this.onClose,
    this.includeTopInset = true,
    this.contentHeight = 74,
    this.showCloseButton = true,
  });

  final String title;
  final VoidCallback onClose;
  final bool includeTopInset;
  final double contentHeight;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    final view = View.of(context);
    final topInset = includeTopInset
        ? view.padding.top / view.devicePixelRatio
        : 0.0;
    return SizedBox(
      height: topInset + contentHeight,
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (showCloseButton)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 18),
                  // 关闭键跟活动主页左上角返回键同款同大小(36pt 玻璃圆)，只是图标
                  // 换成 X。
                  child: _WeatherBackButton(
                    onTap: onClose,
                    icon: CupertinoIcons.xmark,
                    iconColor: w.ink,
                  ),
                ),
              ),
            Text(
              title,
              style: TextStyle(
                color: w.ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared fixed header and clipped scroll body for activity and gift details.
class _OfflineDetailSheetFrame extends StatelessWidget {
  const _OfflineDetailSheetFrame({
    required this.title,
    required this.scrollController,
    required this.children,
    this.compact = false,
    this.showCloseButton = true,
  });

  final String title;
  final ScrollController scrollController;
  final List<Widget> children;
  final bool compact;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(compact ? 28 : 0),
      ),
      child: _OfflineDetailSurface(
        glass: compact,
        child: DefaultTextStyle(
          style: _mutedStyle(context, 15),
          child: Column(
            children: [
              if (compact)
                Padding(
                  key: const ValueKey('offline-detail-grabber'),
                  padding: const EdgeInsets.only(top: 10),
                  child: _sheetGrabber(context, bottomSpacing: 6),
                ),
              _ExpandedSheetTopBar(
                title: title,
                showCloseButton: showCloseButton,
                includeTopInset: !compact,
                contentHeight: compact ? 50 : 74,
                onClose: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  key: ValueKey('offline-detail-scroll-$title'),
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    22,
                    4,
                    22,
                    MediaQuery.paddingOf(context).bottom + 22,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One clipped blur behind the sheet, rather than a blur per scrolling row.
class _OfflineDetailSurface extends StatelessWidget {
  const _OfflineDetailSurface({required this.glass, required this.child});
  final bool glass;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    if (!glass) return ColoredBox(color: w.base, child: child);
    return PlatformBackdropGlass(
      sigma: 24,
      child: DecoratedBox(
        key: const ValueKey('offline-detail-glass'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: w.isDark
                ? [const Color(0xE0242D3A), const Color(0xEC121B28)]
                : [const Color(0xDCFFFFFF), const Color(0xCCEAF0F6)],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: w.glassBorder, width: 0.8),
        ),
        child: child,
      ),
    );
  }
}
