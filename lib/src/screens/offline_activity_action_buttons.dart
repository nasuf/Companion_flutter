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
          // 参考商城主按钮(_storeAccentButtonDecoration)：亮青 → 活动主蓝的渐变 +
          // 同色系柔光投影，去掉糖果感的白描边 / 文字阴影 / 圆形 emoji 底，读成
          // 干净、有分量的高级 CTA。深端锚定活动模块主调 _kActivityAccent。
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF5AC8FA), _kActivityAccent],
            ),
            boxShadow: [
              BoxShadow(
                color: _kActivityAccent.withValues(alpha: 0.32),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Text(icon!, style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 7),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  decoration: TextDecoration.none,
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
    final w = _W2b.resolve(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      borderRadius: BorderRadius.circular(20),
      onPressed: enabled ? onPressed : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 140),
        opacity: enabled ? 1 : 0.56,
        child: Container(
          height: 58,
          // 次按钮走「白玻璃描边」：跟卡片同一套玻璃令牌，和深色主按钮拉开主/次
          // 层级，比原来的灰底更干净通透。
          decoration: BoxDecoration(
            color: w.glass,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: w.glassBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: w.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
