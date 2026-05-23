part of 'package:companion_flutter/main.dart';

enum _SidebarDestination {
  cloud('云端', CupertinoIcons.cloud_fill, Color(0xFF0A84FF)),
  link('连接', CupertinoIcons.link, Color(0xFF12C7C1)),
  mail('信箱', CupertinoIcons.envelope_fill, Color(0xFF7C3CFF)),
  task('任务', CupertinoIcons.checkmark_seal_fill, Color(0xFFFF6B34)),
  list('清单', CupertinoIcons.checkmark_rectangle_fill, Color(0xFF08C767)),
  note('记录', CupertinoIcons.doc_text_fill, Color(0xFFFF8B26));

  const _SidebarDestination(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

class _ChatSidebarOverlay extends StatelessWidget {
  const _ChatSidebarOverlay({
    required this.visible,
    required this.onDismiss,
    required this.onSelected,
  });

  final bool visible;
  final VoidCallback onDismiss;
  final ValueChanged<_SidebarDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final top = math.max(safeTop + 98, screenHeight * 0.16);

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDismiss,
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: visible ? 0.22 : 0),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              top: top,
              right: visible ? 28 : -92,
              child: _SidebarRail(onSelected: onSelected),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarRail extends StatelessWidget {
  const _SidebarRail({required this.onSelected});

  final ValueChanged<_SidebarDestination> onSelected;

  static const _grouped = [
    _SidebarDestination.cloud,
    _SidebarDestination.link,
    _SidebarDestination.mail,
    _SidebarDestination.task,
    _SidebarDestination.list,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LiquidRailContainer(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _grouped.length; i += 1) ...[
                _SidebarButton(
                  destination: _grouped[i],
                  onTap: () => onSelected(_grouped[i]),
                ),
                if (i != _grouped.length - 1) const SizedBox(height: 16),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        _LiquidRailContainer(
          padding: const EdgeInsets.all(12),
          child: _SidebarButton(
            destination: _SidebarDestination.note,
            onTap: () => onSelected(_SidebarDestination.note),
          ),
        ),
      ],
    );
  }
}

class _LiquidRailContainer extends StatelessWidget {
  const _LiquidRailContainer({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(38),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(38),
            border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF315B88).withValues(alpha: 0.15),
                blurRadius: 26,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.76),
                blurRadius: 1,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SidebarButton extends StatelessWidget {
  const _SidebarButton({required this.destination, required this.onTap});

  final _SidebarDestination destination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: destination.label,
      child: CupertinoButton(
        minimumSize: Size.zero,
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: SizedBox(
          width: 60,
          height: 60,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: destination.color,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: destination.color.withValues(alpha: 0.22),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(destination.icon, color: Colors.white, size: 30),
                ),
              ),
              Positioned(
                right: 5,
                top: 4,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _badgeColor(destination),
                    shape: BoxShape.circle,
                    border: Border.all(color: destination.color, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _badgeColor(_SidebarDestination destination) {
    return switch (destination) {
      _SidebarDestination.cloud => AppColors.accentCyan,
      _SidebarDestination.link => AppColors.accentCyan,
      _SidebarDestination.mail => AppColors.accent,
      _SidebarDestination.task => const Color(0xFFFFC23A),
      _SidebarDestination.list => const Color(0xFFFFC23A),
      _SidebarDestination.note => const Color(0xFFFFC23A),
    };
  }
}

class _SidebarDestinationPage extends StatelessWidget {
  const _SidebarDestinationPage({required this.destination});

  final _SidebarDestination destination;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.page,
        foregroundColor: AppColors.text,
        title: Text(destination.label),
      ),
      body: const SizedBox.expand(),
    );
  }
}
