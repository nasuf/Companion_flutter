part of 'package:companion_flutter/main.dart';

Future<void> _showRedPacketSheet({
  required BuildContext context,
  required CompanionApi api,
  required ChatComponentCard card,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.46),
    builder: (_) => _RedPacketSheet(
      api: api,
      initialCard: card,
      topInset: MediaQuery.paddingOf(context).top,
    ),
  );
}

class _RedPacketSheet extends StatefulWidget {
  const _RedPacketSheet({
    required this.api,
    required this.initialCard,
    required this.topInset,
  });

  final CompanionApi api;
  final ChatComponentCard initialCard;
  final double topInset;

  @override
  State<_RedPacketSheet> createState() => _RedPacketSheetState();
}

class _RedPacketSheetState extends State<_RedPacketSheet> {
  late ChatComponentCard _card;
  bool _loading = true;

  String get _offeringId =>
      _card.payload['offering_id']?.toString().trim() ?? '';

  bool get _received => _card.payload['status']?.toString() == 'received';

  int get _amount =>
      int.tryParse(_card.payload['ticket_amount']?.toString() ?? '') ?? 0;

  @override
  void initState() {
    super.initState();
    _card = widget.initialCard;
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final offeringId = _offeringId;
    if (offeringId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final result = await widget.api.getRedPacket(offeringId);
      if (!mounted) return;
      setState(() {
        _card = result.componentCard;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    final isDark = w.isDark;
    final glass = isDark
        ? const Color(0x33FFFFFF)
        : const Color(0xB3FFFFFF);
    final glassBorder = isDark
        ? const Color(0x3DFFFFFF)
        : const Color(0x66FFFFFF);
    final ink = isDark ? const Color(0xFFFFF2F3) : const Color(0xFF4A1F27);
    final inkSoft = isDark
        ? const Color(0xB3FFD6DB)
        : const Color(0xFF8A5960);
    final maxHeight = MediaQuery.sizeOf(context).height - widget.topInset - 18;
    const accent = Color(0xFFFF4D5F);
    final sheetHeight = math.max(maxHeight, 0).toDouble();

    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: sheetHeight,
        child: DecoratedBox(
          key: const Key('red-packet-sheet'),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xE61A1013) : const Color(0xF2FFF7F8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: glassBorder),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: isDark ? 0.22 : 0.16),
                blurRadius: 32,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -48,
                top: -36,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: isDark ? 0.18 : 0.10),
                  ),
                ),
              ),
              Positioned(
                left: -60,
                bottom: 80,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF8A3D).withValues(
                      alpha: isDark ? 0.12 : 0.08,
                    ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    children: [
                      Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: ink.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        width: 72,
                        height: 72,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFF7A88), accent],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.28),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Text(
                          '封',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _received ? '已经收下了' : '还没拆开',
                        style: TextStyle(
                          color: ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _received ? '这份心意已经到账' : '发出去了，等对方拆开',
                        style: TextStyle(
                          color: inkSoft,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                        decoration: BoxDecoration(
                          color: glass,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: glassBorder),
                        ),
                        child: _loading
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 18),
                                child: Center(
                                  child: CupertinoActivityIndicator(),
                                ),
                              )
                            : Column(
                                children: [
                                  Text(
                                    '$_amount',
                                    style: TextStyle(
                                      color: ink,
                                      fontSize: 48,
                                      fontWeight: FontWeight.w800,
                                      height: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '钞票',
                                    style: TextStyle(
                                      color: inkSoft,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: accent.withValues(
                                        alpha: _received ? 0.10 : 0.14,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      _received ? '已领取' : '待领取',
                                      style: TextStyle(
                                        color: _received ? inkSoft : accent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const Spacer(),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).pop(),
                        child: Container(
                          width: double.infinity,
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            '好的',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
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
