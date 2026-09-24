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
          // 参考商城主按钮(_storeAccentButtonDecoration)：亮薄荷 → 活动主青绿的
          // 渐变 + 同色系柔光投影，去掉糖果感的白描边 / 文字阴影 / 圆形 emoji 底，
          // 读成干净、有分量的高级 CTA。深端锚定活动模块主调 _kActivityAccent(青绿)。
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF63D2BC), _kActivityAccent],
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
    this.overlayGlass = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  /// 高斯模糊弹层上的次按钮：独立 frosted glass + 实线描边（如「保存图片」）。
  final bool overlayGlass;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    const radius = 20.0;
    final borderRadius = BorderRadius.circular(radius);
    final labelWidget = Text(
      label,
      style: TextStyle(
        color: w.ink,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        decoration: TextDecoration.none,
      ),
    );

    Widget surface;
    if (overlayGlass) {
      // 背景已由 _blurGlassBarrier 模糊；按钮只做局部 frosted tint + 清晰白边。
      // 不用 boxShadow（大 blur 会把描边晕开），描边用满不透明色。
      final decoration = BoxDecoration(
        color: w.isDark
            ? const Color(0xB3141A24)
            : const Color(0xD9FFFFFF),
        borderRadius: borderRadius,
        border: Border.all(
          color: w.isDark
              ? const Color(0x99FFFFFF)
              : Colors.white,
          width: 1,
        ),
      );
      final panel = Container(
        height: 58,
        decoration: decoration,
        child: Center(child: labelWidget),
      );
      surface = useLightweightGlassEffects
          ? panel
          : ClipRRect(
              borderRadius: borderRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: panel,
              ),
            );
    } else {
      surface = Container(
        height: 58,
        decoration: BoxDecoration(
          color: w.glass,
          borderRadius: borderRadius,
          border: Border.all(color: w.glassBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(child: labelWidget),
      );
    }

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      borderRadius: borderRadius,
      onPressed: enabled ? onPressed : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 140),
        opacity: enabled ? 1 : 0.56,
        child: surface,
      ),
    );
  }
}
