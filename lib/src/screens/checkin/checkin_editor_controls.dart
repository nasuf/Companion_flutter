part of 'package:companion_flutter/main.dart';

const _kCheckinWeekdayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

/// Pill-shaped plan name field.
class _CheckinNameField extends StatelessWidget {
  const _CheckinNameField({
    required this.controller,
    required this.enabled,
    required this.autofocus,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = _CheckinTokens.of(context);
    return Container(
      key: const Key('checkin-name'),
      height: _kCheckinFieldHeight,
      padding: const EdgeInsets.symmetric(horizontal: _kCheckinMargin),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.card,
        border: Border.all(color: tokens.accent),
        borderRadius: BorderRadius.circular(999),
        boxShadow: tokens.cardShadow,
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        autofocus: autofocus,
        maxLines: 1,
        textInputAction: TextInputAction.done,
        onChanged: onChanged,
        cursorColor: tokens.accent,
        style: TextStyle(
          color: tokens.title,
          fontSize: 14,
          height: 1.2,
          fontWeight: FontWeight.w400,
        ),
        decoration: _checkinBareInput(
          hint: '输入计划名称',
          hintStyle: TextStyle(
            color: tokens.placeholder,
            fontSize: 14,
            height: 1.2,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// Single plan / repeating habit switch. The blue thumb slides between halves.
class _CheckinModeSwitch extends StatelessWidget {
  const _CheckinModeSwitch({required this.value, required this.onChanged});

  final _CheckinEntryMode value;
  final ValueChanged<_CheckinEntryMode>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = _CheckinTokens.of(context);
    final habit = value == _CheckinEntryMode.habit;
    return LayoutBuilder(
      builder: (context, constraints) {
        final thumbWidth = constraints.maxWidth / 2;
        return SizedBox(
          key: const Key('checkin-mode'),
          height: _kCheckinFieldHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.accentSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: habit ? thumbWidth : 0,
                top: 0,
                bottom: 0,
                width: thumbWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              // Positioned.fill, not a bare child: a loose Stack child is laid
              // out at its own height and pinned to the top corner, which is
              // what left the labels riding above the pill's centre line.
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      child: _segment(
                        tokens,
                        asset: 'icon_clock.png',
                        iconWidth: 26,
                        label: '单次计划',
                        active: !habit,
                        onTap: onChanged == null
                            ? null
                            : () => onChanged!(_CheckinEntryMode.once),
                      ),
                    ),
                    Expanded(
                      child: _segment(
                        tokens,
                        asset: 'icon_repeat.png',
                        // The loop glyph is wider than tall and only fills part
                        // of its 26px frame in the design.
                        iconWidth: 22,
                        label: '周期习惯',
                        active: habit,
                        onTap: onChanged == null
                            ? null
                            : () => onChanged!(_CheckinEntryMode.habit),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _segment(
    _CheckinTokens tokens, {
    required String asset,
    required double iconWidth,
    required String label,
    required bool active,
    required VoidCallback? onTap,
  }) {
    // The design draws the inactive label heavier than the active one; the
    // blue thumb already carries the selection, so the weight only has to keep
    // the inactive side readable on the pale track.
    final color = active ? Colors.white : tokens.title;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      // Both halves start their icon 23px in rather than centring the pair,
      // which is how the design lines the two labels up with each other.
      child: Row(
        children: [
          const SizedBox(width: 23),
          SizedBox(
            width: 26,
            height: 26,
            child: Image.asset(
              '$_kCheckinAsset$asset',
              width: iconWidth,
              color: color,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 9),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 16,
              height: 1.2,
              fontWeight: active ? FontWeight.w500 : FontWeight.w700,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

/// White card holding the label / value pair for the reminder time.
class _CheckinReminderRow extends StatelessWidget {
  const _CheckinReminderRow({required this.value, required this.onPick});

  final String value;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final tokens = _CheckinTokens.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPick,
      child: Container(
        key: const Key('checkin-reminder'),
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: tokens.card,
          borderRadius: BorderRadius.circular(_kCheckinCardRadius),
          boxShadow: tokens.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: tokens.accent.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Image.asset(
                '${_kCheckinAsset}icon_alarm.png',
                width: 24,
                height: 24,
                color: Colors.white,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '提醒时间',
                    style: TextStyle(
                      color: tokens.sectionTitle,
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      color: tokens.title,
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            if (onPick != null)
              Icon(
                CupertinoIcons.chevron_forward,
                size: 16,
                color: tokens.title,
              ),
          ],
        ),
      ),
    );
  }
}

/// Weekday picker for a repeating habit.
class _CheckinWeekdayCard extends StatelessWidget {
  /// [onToggle] is null on the detail sheet, where the row is a readout.
  const _CheckinWeekdayCard({required this.selected, this.onToggle});

  final Set<int> selected;
  final ValueChanged<int>? onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = _CheckinTokens.of(context);
    return Container(
      key: const Key('checkin-weekdays'),
      height: 116,
      padding: const EdgeInsets.fromLTRB(17, 12, 17, 0),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(_kCheckinCardRadius),
        boxShadow: tokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '重复频率',
            style: TextStyle(
              color: tokens.sectionTitle,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var weekday = 1; weekday <= 7; weekday += 1)
                _weekdayPill(tokens, weekday),
            ],
          ),
        ],
      ),
    );
  }

  Widget _weekdayPill(_CheckinTokens tokens, int weekday) {
    final active = selected.contains(weekday);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle == null ? null : () => onToggle!(weekday),
      child: Container(
        width: _kCheckinDayWidth,
        height: _kCheckinDayHeight,
        padding: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: active ? tokens.accentSoft : tokens.dayPill,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Column(
          children: [
            Text(
              _kCheckinWeekdayLabels[weekday - 1],
              style: TextStyle(
                color: tokens.dayNumber,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w400,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 8),
            active
                ? _CheckinCheckBadge(size: 12, color: tokens.accent)
                : _CheckinRingMark(size: 12, color: tokens.markIdle),
          ],
        ),
      ),
    );
  }
}

/// Optional free-text note.
class _CheckinNoteCard extends StatelessWidget {
  const _CheckinNoteCard({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = _CheckinTokens.of(context);
    return Container(
      key: const Key('checkin-note'),
      height: 84,
      padding: const EdgeInsets.fromLTRB(
        _kCheckinMargin,
        12,
        _kCheckinMargin,
        0,
      ),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(_kCheckinCardRadius),
        boxShadow: tokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '备注（可选）',
            style: TextStyle(
              color: tokens.sectionTitle,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tokens.noteField,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: controller,
              maxLines: 1,
              maxLength: 500,
              textInputAction: TextInputAction.done,
              cursorColor: tokens.accent,
              style: TextStyle(
                color: tokens.title,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w400,
              ),
              decoration: _checkinBareInput(
                hint: '请填写备注内容',
                hintStyle: TextStyle(
                  color: tokens.placeholder,
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width pill button at the bottom of the editor sheet.
class _CheckinPrimaryButton extends StatelessWidget {
  const _CheckinPrimaryButton({
    required this.label,
    required this.onPressed,
    required this.busy,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final tokens = _CheckinTokens.of(context);
    final base = danger ? const Color(0xFFFF4C4C) : tokens.accent;
    final enabled = onPressed != null && !busy;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size.fromHeight(_kCheckinSaveHeight),
      borderRadius: BorderRadius.circular(999),
      onPressed: enabled ? onPressed : null,
      child: Container(
        key: const Key('checkin-save'),
        height: _kCheckinSaveHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? base : base.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: base.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(2, 8),
                  ),
                ]
              : null,
        ),
        child: busy
            ? const CupertinoActivityIndicator(color: Colors.white)
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
      ),
    );
  }
}

/// Outlined counterpart to the filled primary button.
class _CheckinSecondaryButton extends StatelessWidget {
  const _CheckinSecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = _CheckinTokens.of(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size.fromHeight(_kCheckinSaveHeight),
      borderRadius: BorderRadius.circular(999),
      onPressed: onPressed,
      child: Container(
        height: _kCheckinSaveHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tokens.card,
          border: Border.all(color: tokens.accent),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: tokens.accent,
            fontSize: 17,
            height: 1.4,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

/// Small round action in the editor's top row (only shown when editing).
class _CheckinSheetAction extends StatelessWidget {
  const _CheckinSheetAction({
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.busy,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(32, 32),
      borderRadius: BorderRadius.circular(16),
      onPressed: busy ? null : onPressed,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: busy
            ? CupertinoActivityIndicator(radius: 8, color: color)
            : Icon(icon, size: 17, color: color),
      ),
    );
  }
}
