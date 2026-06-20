part of 'package:companion_flutter/main.dart';

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.agentName,
    this.interactionDays,
    this.aiStatus,
    this.aiStatusLabel,
    this.aiActivity,
    this.avatarUrl,
    this.isMusicListening = false,
    this.isMusicPlaying = false,
    this.onMusicTap,
    required this.onAvatarDoubleTap,
    required this.onOpenSidebar,
  });

  final String agentName;
  final int? interactionDays;
  final String? aiStatus;
  final String? aiStatusLabel;
  final String? aiActivity;
  final String? avatarUrl;
  final bool isMusicListening;
  final bool isMusicPlaying;
  final VoidCallback? onMusicTap;
  final VoidCallback onAvatarDoubleTap;
  final VoidCallback onOpenSidebar;

  @override
  Widget build(BuildContext context) {
    final statusLabel = _formatAgentStatusLabel(
      status: aiStatus,
      label: aiStatusLabel,
      activity: aiActivity,
    );
    final statusColor = _agentStatusColor(aiStatus);
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.page,
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: onAvatarDoubleTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _Avatar(
                  size: 44,
                  label: '伴',
                  imageUrl: avatarUrl,
                  gradient: [Color(0xFFE8F3FF), Color(0xFFDDEBFF)],
                ),
                if (isMusicListening)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onMusicTap,
                      child: _ListeningBadge(isPlaying: isMusicPlaying),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        agentName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (statusLabel != null) ...[
                      const SizedBox(width: 7),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 126),
                        child: _HeaderPill(
                          foreground: statusColor.foreground,
                          background: statusColor.background,
                          label: statusLabel,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _HeaderPill(
                      foreground: const Color(0xFFFF8A22),
                      background: const Color(0xFFFFF1E4),
                      icon: CupertinoIcons.flame_fill,
                      label: interactionDays == null
                          ? '互动中'
                          : '互动第$interactionDays天',
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '更多',
            onPressed: onOpenSidebar,
            icon: const Icon(CupertinoIcons.ellipsis, size: 24),
          ),
        ],
      ),
    );
  }
}

({Color foreground, Color background}) _agentStatusColor(String? status) {
  return switch (status) {
    'idle' => (
      foreground: const Color(0xFF15A66A),
      background: const Color(0xFFE9FAF2),
    ),
    'busy' || 'very_busy' => (
      foreground: const Color(0xFFE88424),
      background: const Color(0xFFFFF4E8),
    ),
    'sleep' => (
      foreground: const Color(0xFF6470D8),
      background: const Color(0xFFEFF1FF),
    ),
    _ => (
      foreground: const Color(0xFF7B8794),
      background: const Color(0xFFF2F5F8),
    ),
  };
}

String? _formatAgentStatusLabel({
  required String? status,
  required String? label,
  required String? activity,
}) {
  final cleanStatus = status?.trim();
  final statusText = _firstNonEmpty(label, switch (cleanStatus) {
    'idle' => '空闲',
    'busy' => '忙碌',
    'very_busy' => '很忙',
    'sleep' => '睡眠',
    _ => cleanStatus,
  });
  if (statusText == null) return null;

  final cleanActivity = activity?.trim();
  if (cleanActivity == null ||
      cleanActivity.isEmpty ||
      cleanActivity == statusText) {
    return statusText;
  }
  return '$statusText · $cleanActivity';
}

String? _firstNonEmpty(String? primary, String? fallback) {
  final cleanPrimary = primary?.trim();
  if (cleanPrimary != null && cleanPrimary.isNotEmpty) return cleanPrimary;
  final cleanFallback = fallback?.trim();
  if (cleanFallback != null && cleanFallback.isNotEmpty) return cleanFallback;
  return null;
}

class _ListeningBadge extends StatefulWidget {
  const _ListeningBadge({required this.isPlaying});

  final bool isPlaying;

  @override
  State<_ListeningBadge> createState() => _ListeningBadgeState();
}

class _ListeningBadgeState extends State<_ListeningBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _sync();
  }

  @override
  void didUpdateWidget(covariant _ListeningBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      _sync();
    }
  }

  void _sync() {
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final glow = widget.isPlaying ? 0.14 + _controller.value * 0.14 : 0.10;
        final spread = widget.isPlaying ? 1.0 + _controller.value * 2.0 : 0.4;
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF24D7D3).withValues(alpha: glow),
                blurRadius: 12,
                spreadRadius: spread,
              ),
            ],
          ),
          child: child,
        );
      },
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF82F5FF), Color(0xFF1F9CFF)],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.86),
                width: 1.4,
              ),
            ),
            child: const Icon(
              CupertinoIcons.headphones,
              size: 10,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({
    required this.label,
    required this.foreground,
    required this.background,
    this.icon,
  });

  final String label;
  final Color foreground;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      constraints: const BoxConstraints(minHeight: 21),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
          ] else ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                height: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
