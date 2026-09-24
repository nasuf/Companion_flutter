part of 'package:companion_flutter/main.dart';

// ===========================================================================
// Shared small widgets
// ===========================================================================

String _formatRate(double? rate) {
  if (rate == null) return '--';
  return '${(rate * 100).toStringAsFixed(1)}%';
}

class _AdminGamesFieldLabel extends StatelessWidget {
  const _AdminGamesFieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        decoration: TextDecoration.none,
      ),
    );
  }
}

class _AdminGamesSectionHeader extends StatelessWidget {
  const _AdminGamesSectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        color: isDark ? AppColors.text : const Color(0xFF12171B),
        fontSize: 14,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
        decoration: TextDecoration.none,
      ),
    );
  }
}

class _AdminGamesTextField extends StatelessWidget {
  const _AdminGamesTextField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AdminGamesFieldLabel(label),
        const SizedBox(height: 6),
        _AdminGamesInputBox(
          child: CupertinoTextField(
            controller: controller,
            decoration: const BoxDecoration(),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            style: _adminInputStyle(context),
          ),
        ),
      ],
    );
  }
}

class _AdminGamesNumberField extends StatelessWidget {
  const _AdminGamesNumberField({
    required this.label,
    required this.controller,
    this.signed = false,
    this.decimal = false,
  });

  final String label;
  final TextEditingController controller;
  final bool signed;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    final field = CupertinoTextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(
        signed: signed,
        decimal: decimal,
      ),
      decoration: const BoxDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      style: _adminInputStyle(context),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AdminGamesFieldLabel(label),
        const SizedBox(height: 6),
        _AdminGamesInputBox(
          // iOS's numeric keypad has no minus key, so signed fields (输/中途退出/
          // 里程碑积分 等可为负) get a ± toggle that flips the leading sign.
          child: signed
              ? Row(
                  children: [
                    _SignToggleButton(controller: controller),
                    Expanded(child: field),
                  ],
                )
              : field,
        ),
      ],
    );
  }
}

class _SignToggleButton extends StatelessWidget {
  const _SignToggleButton({required this.controller});

  final TextEditingController controller;

  void _toggle() {
    final text = controller.text;
    final next = text.startsWith('-') ? text.substring(1) : '-$text';
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _toggle,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.10),
            ),
          ),
        ),
        child: Text(
          '±',
          style: TextStyle(
            color: AppColors.of(context).accent,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

class _AdminGamesMultilineField extends StatelessWidget {
  const _AdminGamesMultilineField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _AdminGamesInputBox(
      child: CupertinoTextField(
        controller: controller,
        maxLines: 8,
        minLines: 4,
        decoration: const BoxDecoration(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        style: _adminInputStyle(
          context,
        ).copyWith(fontFamily: 'monospace', fontSize: 12.5),
      ),
    );
  }
}

class _AdminGamesReadonlyJson extends StatelessWidget {
  const _AdminGamesReadonlyJson({required this.label, required this.value});

  final String label;
  final Map<String, dynamic> value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AdminGamesFieldLabel(label),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.24)
                : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            const JsonEncoder.withIndent('  ').convert(value),
            style: TextStyle(
              color: isDark ? const Color(0xC8EBF2EE) : const Color(0xFF3A4350),
              fontSize: 12,
              fontFamily: 'monospace',
              height: 1.4,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }
}

TextStyle _adminInputStyle(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return TextStyle(
    color: isDark ? AppColors.text : const Color(0xFF12171B),
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    decoration: TextDecoration.none,
  );
}

class _AdminGamesInputBox extends StatelessWidget {
  const _AdminGamesInputBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.10),
        ),
      ),
      child: child,
    );
  }
}

class _AdminGamesPrimaryButton extends StatelessWidget {
  const _AdminGamesPrimaryButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.of(context).accent;
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 14),
        color: accent,
        borderRadius: BorderRadius.circular(16),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

class _AdminGamesSecondaryButton extends StatelessWidget {
  const _AdminGamesSecondaryButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.of(context).accent;
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 12),
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        onPressed: onPressed,
        child: Text(
          label,
          style: TextStyle(
            color: accent,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

class _AdminGamesErrorText extends StatelessWidget {
  const _AdminGamesErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.of(context).danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.of(context).danger.withValues(alpha: 0.24),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.of(context).danger,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _AdminGamesNoticeText extends StatelessWidget {
  const _AdminGamesNoticeText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF1FA97A);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: green.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: green.withValues(alpha: 0.24)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: green,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
