part of 'package:companion_flutter/main.dart';

class _PlanModeSwitch extends StatelessWidget {
  const _PlanModeSwitch({required this.value, required this.onChanged});

  final _CheckinEntryMode value;
  final ValueChanged<_CheckinEntryMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final onceSelected = value == _CheckinEntryMode.once;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F8),
        borderRadius: BorderRadius.circular(22),
      ),
      child: SizedBox(
        height: 48,
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: onceSelected
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F5EA8).withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                _PlanModeButton(
                  selected: onceSelected,
                  label: '单次计划',
                  icon: CupertinoIcons.clock,
                  onTap: () => onChanged(_CheckinEntryMode.once),
                ),
                _PlanModeButton(
                  selected: !onceSelected,
                  label: '周期习惯',
                  icon: CupertinoIcons.repeat,
                  onTap: () => onChanged(_CheckinEntryMode.habit),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanModeButton extends StatelessWidget {
  const _PlanModeButton({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF4F5EA8) : AppColors.muted;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.expand(
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 7),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyModePill extends StatelessWidget {
  const _ReadOnlyModePill({required this.mode});

  final _CheckinEntryMode mode;

  @override
  Widget build(BuildContext context) {
    final isHabit = mode == _CheckinEntryMode.habit;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F8),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isHabit ? CupertinoIcons.repeat : CupertinoIcons.clock,
            color: const Color(0xFF4F5EA8),
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            isHabit ? '周期习惯' : '单次计划',
            style: const TextStyle(
              color: Color(0xFF4F5EA8),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFECEFF3)),
      ),
      child: child,
    );
  }
}

class _SettingIconBox extends StatelessWidget {
  const _SettingIconBox({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: AppColors.text, size: 23),
    );
  }
}

class _SettingLabel extends StatelessWidget {
  const _SettingLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 15,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _SettingTitle extends StatelessWidget {
  const _SettingTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AppColors.text,
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _IconPillButton extends StatelessWidget {
  const _IconPillButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(42, 42),
      onPressed: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, color: const Color(0xFF4F5EA8), size: 21),
      ),
    );
  }
}

class _SingleReminderTimeRow extends StatelessWidget {
  const _SingleReminderTimeRow({required this.dateTime, required this.onPick});

  final DateTime dateTime;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    return _SettingCard(
      child: Row(
        children: [
          const _SettingIconBox(icon: CupertinoIcons.alarm),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SettingLabel('提醒时间'),
                const SizedBox(height: 3),
                _SettingTitle(_fullDateTimeLabel(dateTime)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (onPick != null)
            _IconPillButton(icon: CupertinoIcons.pencil, onTap: onPick!),
        ],
      ),
    );
  }
}

class _HabitWeekdaySection extends StatelessWidget {
  const _HabitWeekdaySection({
    required this.selected,
    required this.dateTime,
    required this.onPickTime,
    required this.onToggle,
  });

  final Set<int> selected;
  final DateTime dateTime;
  final VoidCallback? onPickTime;
  final ValueChanged<int>? onToggle;

  @override
  Widget build(BuildContext context) {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return _SettingCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SettingLabel('习惯周期'),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: onPickTime,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE7EAF0)),
                  ),
                  child: Text(
                    _timeLabel(dateTime),
                    style: const TextStyle(
                      color: Color(0xFF4F5EA8),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: List.generate(7, (index) {
              final weekday = index + 1;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: index == 0 ? 0 : 6),
                  child: _WeekdayDotButton(
                    selected: selected.contains(weekday),
                    label: labels[index],
                    onTap: onToggle == null ? null : () => onToggle!(weekday),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _WeekdayDotButton extends StatelessWidget {
  const _WeekdayDotButton({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(38.0, constraints.maxWidth);
        return Center(
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              curve: Curves.easeOutCubic,
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFFFC338) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? const Color(0xFFFFC338)
                      : const Color(0xFFE4E8EE),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.text : AppColors.muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
