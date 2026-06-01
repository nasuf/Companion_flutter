part of 'package:companion_flutter/main.dart';

class _AchievementHeader extends StatelessWidget {
  const _AchievementHeader({required this.data});

  final AchievementsResponse data;

  @override
  Widget build(BuildContext context) {
    final progress = data.total == 0 ? 0.0 : data.unlocked / data.total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CupertinoButton(
                minimumSize: Size.zero,
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Icon(
                  CupertinoIcons.chevron_left,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '成就',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF96556A).withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Row(
              children: [
                _AchievementMetric(value: '${data.unlocked}', label: '已解锁'),
                _AchievementMetric(value: '${data.total}', label: '全部'),
                _AchievementMetric(value: '${data.score}', label: '分值'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1).toDouble(),
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.72),
              color: const Color(0xFF96556A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(progress * 100).round()}% 完成',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementFilterBar extends StatelessWidget {
  const _AchievementFilterBar({
    required this.value,
    required this.data,
    required this.onChanged,
  });

  final _AchievementFilter value;
  final AchievementsResponse data;
  final ValueChanged<_AchievementFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
      child: Row(
        children: [
          _AchievementFilterChip(
            label: '全部 ${data.total}',
            selected: value == _AchievementFilter.all,
            onTap: () => onChanged(_AchievementFilter.all),
          ),
          const SizedBox(width: 8),
          _AchievementFilterChip(
            label: '已解锁 ${data.unlocked}',
            selected: value == _AchievementFilter.unlocked,
            onTap: () => onChanged(_AchievementFilter.unlocked),
          ),
          const SizedBox(width: 8),
          _AchievementFilterChip(
            label: '未解锁 ${data.total - data.unlocked}',
            selected: value == _AchievementFilter.locked,
            onTap: () => onChanged(_AchievementFilter.locked),
          ),
        ],
      ),
    );
  }
}

class _AchievementFilterChip extends StatelessWidget {
  const _AchievementFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.text
                : Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.text : AppColors.hairline,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _AchievementMetric extends StatelessWidget {
  const _AchievementMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
