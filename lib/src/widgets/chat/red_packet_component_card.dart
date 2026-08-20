part of 'package:companion_flutter/main.dart';

class _RedPacketComponentCard extends StatelessWidget {
  const _RedPacketComponentCard({
    required this.card,
    required this.isMine,
    required this.onTap,
  });

  final ChatComponentCard card;
  final bool isMine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFF4D5F);
    final colors = AppColors.of(context);
    final isDark = AppColors.isDark(context);
    final received = card.payload['status']?.toString() == 'received';
    final statusLabel = received
        ? '已领取'
        : (card.payload['status_label']?.toString().trim().isNotEmpty == true
              ? card.payload['status_label'].toString()
              : '待领取');
    final radius = BorderRadius.only(
      topLeft: Radius.circular(isMine ? 20 : 5),
      topRight: Radius.circular(isMine ? 5 : 20),
      bottomLeft: const Radius.circular(20),
      bottomRight: const Radius.circular(20),
    );
    final background = isDark
        ? const [Color(0xFF2A181C), Color(0xFF181214)]
        : const [Color(0xFFFFF1F2), Color(0xFFFFFFFF)];

    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 292),
        child: DecoratedBox(
          key: const Key('red-packet-card'),
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
                color: accent.withValues(alpha: isDark ? 0.22 : 0.14),
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
                      color: accent.withValues(alpha: isDark ? 0.18 : 0.10),
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
                                colors: [Color(0xFFFF7A88), accent],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.24),
                                  blurRadius: 13,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const _RedPacketIcon(size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  card.title.isEmpty ? '红包' : card.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  ),
                                ),
                                Text(
                                  card.body.isEmpty ? '给你的一点心意' : card.body,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFFC9A8AD)
                                        : const Color(0xFF9D6E74),
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
                              color: accent.withValues(
                                alpha: received ? 0.08 : 0.12,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                color: received
                                    ? (isDark
                                          ? const Color(0xFFD7B4B8)
                                          : const Color(0xFF9A6A70))
                                    : accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            card.footer.isEmpty ? '点击查看' : card.footer,
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

/// White hongbao silhouette for the red gradient badge — a vertical envelope
/// with a folded flap and gold seal, not the old 「封」 character.
class _RedPacketIcon extends StatelessWidget {
  const _RedPacketIcon({this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '红包',
      child: CustomPaint(
        key: const Key('red-packet-icon'),
        size: Size.square(size),
        painter: const _RedPacketIconPainter(),
      ),
    );
  }
}

class _RedPacketIconPainter extends CustomPainter {
  const _RedPacketIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final left = s * 0.18;
    final right = s * 0.82;
    final top = s * 0.08;
    final bottom = s * 0.92;
    final radius = Radius.circular(s * 0.12);
    final body = RRect.fromLTRBR(left, top, right, bottom, radius);

    final fill = Paint()..color = Colors.white;
    canvas.drawRRect(body, fill);

    canvas.save();
    canvas.clipRRect(body);
    final flap = Path()
      ..moveTo(left, top)
      ..lineTo(right, top)
      ..lineTo(s * 0.5, top + s * 0.38)
      ..close();
    canvas.drawPath(flap, Paint()..color = const Color(0xFFFFE08A));
    canvas.restore();

    canvas.drawCircle(
      Offset(s * 0.5, top + s * 0.38),
      s * 0.12,
      Paint()..color = const Color(0xFFE2B93A),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
