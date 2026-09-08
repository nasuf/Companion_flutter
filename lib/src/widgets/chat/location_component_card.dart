part of 'package:companion_flutter/main.dart';

const _locationAccent = Color(0xFF22C66B);

class _LocationComponentCard extends StatelessWidget {
  const _LocationComponentCard({
    required this.card,
    required this.isMine,
    required this.onTap,
  });

  final ChatComponentCard card;
  final bool isMine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = AppColors.isDark(context);
    final title = card.title.isEmpty ? '我的位置' : card.title;
    final subtitle = card.subtitle.isEmpty ? '当前位置' : card.subtitle;
    final radius = BorderRadius.only(
      topLeft: Radius.circular(isMine ? 20 : 5),
      topRight: Radius.circular(isMine ? 5 : 20),
      bottomLeft: const Radius.circular(20),
      bottomRight: const Radius.circular(20),
    );

    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 292),
        child: DecoratedBox(
          key: const Key('location-card'),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF121916) : Colors.white,
            borderRadius: radius,
            border: Border.all(
              color: _locationAccent.withValues(alpha: isDark ? 0.34 : 0.26),
            ),
            boxShadow: [
              BoxShadow(
                color: _locationAccent.withValues(alpha: isDark ? 0.18 : 0.12),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 118,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? const [
                                    Color(0xFF1A2A22),
                                    Color(0xFF101714),
                                  ]
                                : const [
                                    Color(0xFFEAF9F0),
                                    Color(0xFFF6FFFA),
                                  ],
                          ),
                        ),
                        child: CustomPaint(
                          painter: _LocationGridPainter(
                            color: _locationAccent.withValues(
                              alpha: isDark ? 0.10 : 0.12,
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: _locationAccent.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.location_solid,
                            color: _locationAccent,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            CupertinoIcons.location,
                            size: 14,
                            color: _locationAccent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '位置',
                            style: TextStyle(
                              color: _locationAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.muted,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationGridPainter extends CustomPainter {
  const _LocationGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const spacing = 22.0;
    for (var x = 0.0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LocationGridPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
