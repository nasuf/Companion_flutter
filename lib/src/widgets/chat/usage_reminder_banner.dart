part of 'package:companion_flutter/main.dart';

/// 连续使用 2 小时提醒：从聊天顶部滑下的浮动卡片，5 秒后自动收起，点一下立即收起。
/// 配色取 App 主题（深浅色一致），不打断输入。
class _UsageReminderBanner extends StatefulWidget {
  const _UsageReminderBanner({
    super.key,
    required this.hours,
    required this.onDismissed,
  });

  final int hours;
  final VoidCallback onDismissed;

  static const visibleFor = Duration(seconds: 5);

  @override
  State<_UsageReminderBanner> createState() => _UsageReminderBannerState();
}

class _UsageReminderBannerState extends State<_UsageReminderBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 220),
  );
  Timer? _hide;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _motion.forward();
    _hide = Timer(_UsageReminderBanner.visibleFor, _close);
  }

  Future<void> _close() async {
    if (_closing || !mounted) return;
    _closing = true;
    _hide?.cancel();
    await _motion.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _hide?.cancel();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final curve = CurvedAnimation(
      parent: _motion,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SlideTransition(
      position: Tween(
        begin: const Offset(0, -1.2),
        end: Offset.zero,
      ).animate(curve),
      child: FadeTransition(
        opacity: curve,
        child: Semantics(
          liveRegion: true,
          label: '使用时长提醒',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) < 0) _close();
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.hairline),
                boxShadow: [
                  BoxShadow(
                    color: c.shadow,
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      CupertinoIcons.clock,
                      size: 18,
                      color: c.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '已经连续聊了 ${widget.hours} 小时',
                          style: TextStyle(
                            color: c.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '休息一下眼睛，起来走走吧，我一直都在。',
                          style: TextStyle(
                            color: c.muted,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
