part of 'package:companion_flutter/main.dart';

class _ActivityResponseButtons extends StatelessWidget {
  const _ActivityResponseButtons({
    required this.working,
    required this.onAccept,
    required this.onIgnore,
  });

  final bool working;
  final VoidCallback onAccept;
  final VoidCallback onIgnore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SecondaryActivityPillButton(
            label: '先放一放',
            enabled: !working,
            onPressed: onIgnore,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PrimaryActivityPillButton(
            label: working ? '处理中...' : '想去看看',
            icon: '✨',
            enabled: !working,
            onPressed: onAccept,
          ),
        ),
      ],
    );
  }
}

class _PrimaryActivityPillButton extends StatelessWidget {
  const _PrimaryActivityPillButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.enabled = true,
  });

  final String label;
  final String? icon;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      borderRadius: BorderRadius.circular(22),
      onPressed: enabled ? onPressed : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 140),
        opacity: enabled ? 1 : 0.56,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF78D7EA), Color(0xFF54C2DE)],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.48)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF48BFD9).withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.24),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(icon!, style: const TextStyle(fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                  shadows: [
                    Shadow(
                      color: Color(0x22000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
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

class _SecondaryActivityPillButton extends StatelessWidget {
  const _SecondaryActivityPillButton({
    required this.label,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      borderRadius: BorderRadius.circular(22),
      onPressed: enabled ? onPressed : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 140),
        opacity: enabled ? 1 : 0.56,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: colors.surfaceMuted.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.hairline.withValues(alpha: 0.70)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: colors.text,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
