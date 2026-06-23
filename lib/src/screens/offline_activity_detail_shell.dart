part of 'package:companion_flutter/main.dart';

class _CollapsedSheetGrabber extends StatelessWidget {
  const _CollapsedSheetGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Center(
        child: Container(
          width: 48,
          height: 5,
          decoration: BoxDecoration(
            color: AppColors.of(context).hairline,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _ExpandedSheetTopBar extends StatelessWidget {
  const _ExpandedSheetTopBar({
    super.key,
    required this.title,
    required this.onClose,
  });

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final view = View.of(context);
    final topInset = view.padding.top / view.devicePixelRatio;
    return SizedBox(
      height: topInset + 74,
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 18),
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size.square(46),
                  borderRadius: BorderRadius.circular(23),
                  onPressed: onClose,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: colors.surfaceMuted.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.xmark,
                      size: 24,
                      color: colors.accent,
                    ),
                  ),
                ),
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: colors.text,
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
