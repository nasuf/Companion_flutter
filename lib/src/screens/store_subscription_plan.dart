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
    final w = _W2b.resolve(context);
    final titleColor = selected ? Colors.white : w.ink;
    final originColor = selected
        ? Colors.white.withValues(alpha: 0.75)
        : w.inkSoft;
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 124,
        height: 136,
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF4B9AFF), Color(0xFF8ABAFF)],
                )
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [w.hourPillTop, w.hourPillBottom],
                ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? Colors.transparent : w.hourPillBorder,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x474E9BFF),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ]
              : w.panelShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
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
                      color: selected
                          ? Colors.white.withValues(alpha: 0.22)
                          : const Color(0xFF4B9AFF),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(22),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
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
                    badge == null ? 16 : 26,
                    12,
                    16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        price,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 26,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        origin,
                        style: TextStyle(
                          color: originColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: originColor,
                        ),
                      ),
                    ],
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
