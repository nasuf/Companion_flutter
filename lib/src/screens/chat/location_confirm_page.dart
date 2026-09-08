part of 'package:companion_flutter/main.dart';

const _locationConfirmAccent = Color(0xFF22C66B);
const _locationConfirmAccentDeep = Color(0xFF18A957);

/// Half-screen glass bottom sheet to preview a location share before sending.
class LocationConfirmPage extends StatelessWidget {
  const LocationConfirmPage({
    super.key,
    required this.snapshot,
  });

  final DeviceLocationSnapshot snapshot;

  static Future<ChatComponentCard?> push(
    BuildContext context, {
    required DeviceLocationSnapshot snapshot,
  }) {
    return showModalBottomSheet<ChatComponentCard>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.46),
      builder: (_) => LocationConfirmPage(snapshot: snapshot),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    final card = snapshot.toComponentCard();
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: w.isDark
                ? const [Color(0xFF0C1511), Color(0xFF070C14)]
                : const [Color(0xFFE6F6EC), Color(0xFFE9F0FB)],
          ),
          boxShadow: w.panelShadow,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: Stack(
            children: [
              Positioned(
                top: -40,
                right: -20,
                child: IgnorePointer(
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _locationConfirmAccent.withValues(
                        alpha: w.isDark ? 0.14 : 0.18,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 72,
                left: -36,
                child: IgnorePointer(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF4B9AFF).withValues(
                        alpha: w.isDark ? 0.10 : 0.12,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottomInset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SheetGrabber(
                      color: Color(0x9922C66B),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '确认要发送这个位置吗？',
                      style: TextStyle(
                        color: w.ink,
                        fontSize: 20,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _LocationConfirmPreviewCard(card: card),
                    if (snapshot.accuracyMeters != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _LocationConfirmMetaChip(
                          label:
                              '定位精度约 ${snapshot.accuracyMeters!.round()} 米',
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _LocationConfirmActionButton(
                            label: '取消',
                            filled: false,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _LocationConfirmActionButton(
                            label: '发送位置',
                            filled: true,
                            onTap: () => Navigator.of(context).pop(card),
                          ),
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
    );
  }
}

class _LocationConfirmPreviewCard extends StatelessWidget {
  const _LocationConfirmPreviewCard({required this.card});

  final ChatComponentCard card;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    final title = card.title.isEmpty ? '我的位置' : card.title;
    final subtitle = card.subtitle.isEmpty ? '当前位置' : card.subtitle;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: w.glass,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: w.glassBorder),
            boxShadow: w.panelShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 140,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: w.isDark
                              ? const [
                                  Color(0xFF173A28),
                                  Color(0xFF0E1713),
                                ]
                              : const [
                                  Color(0xFFDDF5E7),
                                  Color(0xFFF2FFF7),
                                ],
                        ),
                      ),
                      child: CustomPaint(
                        painter: _LocationGridPainter(
                          color: _locationConfirmAccent.withValues(
                            alpha: w.isDark ? 0.12 : 0.14,
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _locationConfirmAccent.withValues(
                            alpha: w.isDark ? 0.16 : 0.14,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _locationConfirmAccent.withValues(
                                alpha: 0.28,
                              ),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          CupertinoIcons.location_solid,
                          color: _locationConfirmAccent,
                          size: 34,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _locationConfirmAccent.withValues(
                              alpha: w.isDark ? 0.16 : 0.12,
                            ),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: _locationConfirmAccent.withValues(
                                alpha: 0.28,
                              ),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.location,
                                size: 13,
                                color: _locationConfirmAccent,
                              ),
                              SizedBox(width: 5),
                              Text(
                                '当前位置',
                                style: TextStyle(
                                  color: _locationConfirmAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: w.ink,
                        fontSize: 20,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: w.inkSoft,
                        fontSize: 14,
                        height: 1.45,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationConfirmMetaChip extends StatelessWidget {
  const _LocationConfirmMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: w.glass,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: w.glassBorder),
            boxShadow: [w.pillShadow],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: w.inkSoft,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationConfirmActionButton extends StatelessWidget {
  const _LocationConfirmActionButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: filled ? 0 : 14, sigmaY: filled ? 0 : 14),
          child: Container(
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled ? _locationConfirmAccent : w.glass,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: filled ? _locationConfirmAccentDeep : w.glassBorder,
              ),
              boxShadow: filled
                  ? [
                      BoxShadow(
                        color: _locationConfirmAccent.withValues(alpha: 0.32),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [w.pillShadow],
            ),
            child: Text(
              label,
              style: TextStyle(
                color: filled ? Colors.white : w.ink,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
