part of 'package:companion_flutter/main.dart';

const _redPacketSendAccent = Color(0xFFFF4D5F);
const _redPacketSendAccentDeep = Color(0xFFE03A4C);

/// Half-screen glass sheet to pick a ticket amount and optional blessing.
class RedPacketSendSheet extends StatefulWidget {
  const RedPacketSendSheet({
    super.key,
    required this.ticketBalance,
  });

  final num ticketBalance;

  static Future<RedPacketSendDraft?> push(
    BuildContext context, {
    required num ticketBalance,
  }) {
    return showModalBottomSheet<RedPacketSendDraft>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.46),
      builder: (_) => RedPacketSendSheet(ticketBalance: ticketBalance),
    );
  }

  @override
  State<RedPacketSendSheet> createState() => _RedPacketSendSheetState();
}

class _RedPacketSendSheetState extends State<RedPacketSendSheet> {
  final _amountController = TextEditingController();
  final _blessingController = TextEditingController();
  String _errorText = '';

  @override
  void dispose() {
    _amountController.dispose();
    _blessingController.dispose();
    super.dispose();
  }

  void _submit() {
    final value = parseRedPacketTicketAmount(_amountController.text);
    if (value == null) {
      setState(() => _errorText = '请输入 1 到 1000000 的整数');
      return;
    }
    if (value > widget.ticketBalance) {
      setState(() => _errorText = '余额不足，当前 ${formatTicketAmount(widget.ticketBalance)} 钞票');
      return;
    }
    Navigator.of(context).pop(
      RedPacketSendDraft(
        ticketAmount: value,
        blessing: normalizeRedPacketBlessing(_blessingController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final half = media.size.height * 0.5;
    // Paint the sheet through the IME slot so iOS keyboard corner radii do
    // not punch holes in a transparent pad. Only the form is inset.
    final sheetHeight = math.min(half + keyboard, media.size.height);
    final bottomInset = media.padding.bottom;
    final contentBottom = keyboard > 0 ? keyboard + 12 : 16 + bottomInset;

    return SizedBox(
      key: const Key('red-packet-send-sheet'),
      height: sheetHeight,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(30),
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: w.isDark
                ? const [Color(0xFF1A1013), Color(0xFF0C0709)]
                : const [Color(0xFFFFF1F2), Color(0xFFE9F0FB)],
          ),
          boxShadow: w.panelShadow,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(30),
          ),
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
                      color: _redPacketSendAccent.withValues(
                        alpha: w.isDark ? 0.16 : 0.14,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, contentBottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SheetGrabber(
                      color: Color(0x99FF4D5F),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '发红包',
                      style: TextStyle(
                        color: w.ink,
                        fontSize: 20,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '当前余额 ${formatTicketAmount(widget.ticketBalance)} 钞票',
                      style: TextStyle(
                        color: w.inkSoft,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _RedPacketSendField(
                              controller: _amountController,
                              fieldKey: const Key('red-packet-send-amount'),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              placeholder: '输入钞票数量',
                              autofocus: true,
                              onChanged: (_) {
                                if (_errorText.isNotEmpty) {
                                  setState(() => _errorText = '');
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            _RedPacketSendField(
                              controller: _blessingController,
                              fieldKey: const Key(
                                'red-packet-send-blessing',
                              ),
                              placeholder: '写一句话给对方（选填）',
                              maxLines: 3,
                              maxLength: kRedPacketBlessingMaxChars,
                              onChanged: (_) => setState(() {}),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${_blessingController.text.length}/$kRedPacketBlessingMaxChars',
                                style: TextStyle(
                                  color: w.inkFaint,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                            if (_errorText.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                _errorText,
                                style: const TextStyle(
                                  color: _redPacketSendAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _RedPacketSendActionButton(
                      key: const Key('red-packet-send-submit'),
                      label: '发送',
                      onTap: _submit,
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

class _RedPacketSendField extends StatelessWidget {
  const _RedPacketSendField({
    required this.controller,
    required this.placeholder,
    required this.fieldKey,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.maxLength,
    this.autofocus = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String placeholder;
  final Key fieldKey;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final int? maxLength;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return CupertinoTextField(
      key: fieldKey,
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: [
        ...?inputFormatters,
        if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
      ],
      placeholder: placeholder,
      autofocus: autofocus,
      maxLines: maxLines,
      minLines: maxLines > 1 ? 2 : 1,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      placeholderStyle: TextStyle(
        color: w.inkFaint,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      style: TextStyle(
        color: w.ink,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: w.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: w.glassBorder),
      ),
      onChanged: onChanged,
    );
  }
}

class _RedPacketSendActionButton extends StatelessWidget {
  const _RedPacketSendActionButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _redPacketSendAccent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _redPacketSendAccentDeep),
          boxShadow: [
            BoxShadow(
              color: _redPacketSendAccent.withValues(alpha: 0.32),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
