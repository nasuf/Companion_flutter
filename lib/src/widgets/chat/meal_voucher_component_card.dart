part of 'package:companion_flutter/main.dart';

class _MealVoucherComponentCard extends StatelessWidget {
  const _MealVoucherComponentCard({
    required this.card,
    required this.isMine,
    required this.onTap,
  });

  final ChatComponentCard card;
  final bool isMine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFF7A1A);
    final colors = AppColors.of(context);
    final isDark = AppColors.isDark(context);
    final isEnded = card.payload['native_status']?.toString() == 'ended';
    final displaySubtitle = isEnded ? '佛山“西甲”霸王餐活动' : card.subtitle;
    final nativeMessage = card.payload['native_message']?.toString().trim();
    final displayBody = isEnded && nativeMessage?.isNotEmpty == true
        ? nativeMessage!
        : card.body;
    final displayFooter = isEnded ? '查看活动说明' : card.footer;
    final radius = BorderRadius.only(
      topLeft: Radius.circular(isMine ? 20 : 5),
      topRight: Radius.circular(isMine ? 5 : 20),
      bottomLeft: const Radius.circular(20),
      bottomRight: const Radius.circular(20),
    );
    final background = isDark
        ? const [Color(0xFF2A2119), Color(0xFF181512)]
        : const [Color(0xFFFFF5E8), Color(0xFFFFFFFF)];

    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 292),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: background,
            ),
            borderRadius: radius,
            border: Border.all(
              color: accent.withValues(alpha: isDark ? 0.36 : 0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: isDark ? 0.20 : 0.13),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              children: [
                Positioned(
                  right: -30,
                  top: -38,
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: isDark ? 0.16 : 0.10),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 14, 15, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFFF9A3C), accent],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.24),
                                  blurRadius: 13,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Text(
                              '券',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  card.title.isEmpty ? '霸王餐券' : card.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  ),
                                ),
                                if (displaySubtitle.isNotEmpty)
                                  Text(
                                    displaySubtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF9D846C),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              '已结束',
                              style: TextStyle(
                                color: Color(0xFFE36812),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      SizedBox(
                        height: 18,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _MealVoucherPerforationPainter(
                            lineColor: accent.withValues(alpha: 0.27),
                            notchColor: colors.page,
                          ),
                        ),
                      ),
                      if (displayBody.isNotEmpty)
                        Text(
                          displayBody,
                          style: TextStyle(
                            color: isDark
                                ? colors.text.withValues(alpha: 0.82)
                                : const Color(0xFF5E5144),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            displayFooter.isEmpty ? '查看活动记录' : displayFooter,
                            style: const TextStyle(
                              color: accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Icon(
                            CupertinoIcons.chevron_forward,
                            color: accent,
                            size: 15,
                          ),
                        ],
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

class _MealVoucherPerforationPainter extends CustomPainter {
  const _MealVoucherPerforationPainter({
    required this.lineColor,
    required this.notchColor,
  });

  final Color lineColor;
  final Color notchColor;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    const dash = 5.0;
    const gap = 4.0;
    final y = size.height / 2;
    for (double x = 0; x < size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + dash, size.width), y),
        line,
      );
    }

    final notch = Paint()..color = notchColor;
    canvas.drawCircle(Offset.zero.translate(0, y), 7.5, notch);
    canvas.drawCircle(Offset(size.width, y), 7.5, notch);
  }

  @override
  bool shouldRepaint(_MealVoucherPerforationPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.notchColor != notchColor;
  }
}
