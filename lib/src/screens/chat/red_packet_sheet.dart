part of 'package:companion_flutter/main.dart';

Future<void> _showRedPacketSheet({
  required BuildContext context,
  required CompanionApi api,
  required ChatComponentCard card,
}) {
  return RedPacketSheetPage.push(context, api: api, card: card);
}

/// Full-screen status page for a sent / received red packet.
///
/// Same chrome as [CapsuleEditorPage]: a `fullscreenDialog` that covers the
/// chat, title in the middle, 36pt glass X at the top-left.
class RedPacketSheetPage extends StatefulWidget {
  const RedPacketSheetPage({
    super.key,
    required this.api,
    required this.card,
  });

  final CompanionApi api;
  final ChatComponentCard card;

  static Future<void> push(
    BuildContext context, {
    required CompanionApi api,
    required ChatComponentCard card,
  }) {
    return Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => RedPacketSheetPage(api: api, card: card),
      ),
    );
  }

  @override
  State<RedPacketSheetPage> createState() => _RedPacketSheetPageState();
}

class _RedPacketSheetPageState extends State<RedPacketSheetPage> {
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
    _card = widget.card;
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
    const accent = Color(0xFFFF4D5F);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF1A1013)
          : const Color(0xFFFFF7F8),
      body: Stack(
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
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                  child: SizedBox(
                    height: 44,
                    child: Stack(
                      children: [
                        const Positioned.fill(
                          child: Center(
                            child: Text(
                              '红包',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: _RedPacketCloseButton(
                              onTap: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      24 + MediaQuery.paddingOf(context).bottom,
                    ),
                    child: Column(
                      children: [
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
                          child: const _RedPacketIcon(size: 34),
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
                          _received ? '这份心意已被接收' : '发出去了，等对方拆开',
                          style: TextStyle(
                            color: inkSoft,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          key: const Key('red-packet-sheet'),
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
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
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
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RedPacketCloseButton extends StatelessWidget {
  const _RedPacketCloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: w.glass,
          shape: BoxShape.circle,
          border: Border.all(color: w.glassBorder),
          boxShadow: [w.pillShadow],
        ),
        alignment: Alignment.center,
        child: Icon(CupertinoIcons.xmark, color: _capsuleOrange, size: 20),
      ),
    );
  }
}
