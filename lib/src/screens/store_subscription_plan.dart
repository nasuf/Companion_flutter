part of 'package:companion_flutter/main.dart';

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.selected,
    required this.title,
    required this.price,
    required this.origin,
    required this.onTap,
    this.badge,
  });

  final bool selected;
  final String title;
  final String price;
  final String origin;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 132,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.elevatedSurface(context, light: 0.98)
              : AppColors.subtleFill(context, light: 0.72),
          borderRadius: BorderRadius.circular(27),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.glassBorder(context),
            width: selected ? 2.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(
                alpha: selected ? (isDark ? 0.30 : 0.20) : 0.08,
              ),
              blurRadius: selected ? 26 : 14,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (badge != null)
              Positioned(
                left: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            Center(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  badge == null ? 10 : 24,
                  12,
                  10,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      price,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.text
                            : const Color(0xFF243040),
                        fontSize: 31,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      origin,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.muted
                            : const Color(0xFF9AA5B2),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
