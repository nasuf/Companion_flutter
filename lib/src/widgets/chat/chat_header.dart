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
    required this.onInteractionTap,
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
  final VoidCallback onInteractionTap;
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
      height: 76,
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF06C893).withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
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
                  size: 40,
                  label: '伴',
                  imageUrl: avatarUrl,
                  gradient: const [Color(0xFFE8F3FF), Color(0xFFDDEBFF)],
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
                Text(
                  agentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                if (statusLabel != null) ...[
                  const SizedBox(height: 3),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 156),
                    child: _HeaderPill(
                      foreground: statusColor.foreground,
                      background: statusColor.background,
                      label: statusLabel,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onInteractionTap,
            child: Tooltip(
              message: interactionDays == null
                  ? '互动标识'
                  : '已互动 $interactionDays 天',
              child: const _InteractionMarkIcon(size: 40, stage: 0),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: '更多',
            onPressed: onOpenSidebar,
            icon: const Icon(CupertinoIcons.ellipsis, size: 24),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 40),
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

class _InteractionMarkIcon extends StatelessWidget {
  const _InteractionMarkIcon({required this.size, required this.stage});

  final double size;
  final int stage;

  static const _gradients = [
    [Color(0xFF51FFD0), Color(0xFF06C893)],
    [Color(0xFF84F7FF), Color(0xFF00D6DF)],
    [Color(0xFF8CEBFF), Color(0xFF01A0FD)],
    [Color(0xFFAED7FF), Color(0xFF915FFB)],
    [Color(0xFFFFA8F8), Color(0xFFFF58D8)],
    [Color(0xFFFFD2FB), Color(0xFF8A5CFF)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _gradients[stage.clamp(0, _gradients.length - 1)];
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.86,
            height: size * 0.86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.last.withValues(alpha: 0.28),
                  blurRadius: size * 0.34,
                  offset: Offset(0, size * 0.12),
                ),
              ],
            ),
          ),
          Icon(
            CupertinoIcons.flame_fill,
            size: size * 0.92,
            color: Colors.white.withValues(alpha: 0.92),
          ),
          Icon(CupertinoIcons.star_fill, size: size * 0.40, color: colors.last),
          Positioned(
            right: size * 0.02,
            top: size * 0.14,
            child: Icon(
              CupertinoIcons.sparkles,
              size: size * 0.24,
              color: const Color(0xFFFFF2A8),
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractionStreakPage extends StatelessWidget {
  const _InteractionStreakPage({
    required this.agentAvatarUrl,
    required this.userAvatarUrl,
    required this.interactionDays,
  });

  final String? agentAvatarUrl;
  final String? userAvatarUrl;
  final int interactionDays;

  int get _stage {
    if (interactionDays >= 100) return 5;
    if (interactionDays >= 61) return 4;
    if (interactionDays >= 32) return 3;
    if (interactionDays >= 16) return 2;
    if (interactionDays >= 8) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final days = interactionDays <= 0 ? 1 : interactionDays;
    final progress = (days / 8).clamp(0.08, 1.0).toDouble();
    return Scaffold(
      backgroundColor: const Color(0xFFE3FBF4),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFFD0FEF3), Color(0xFFE8FAF9)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                left: 16,
                top: 8,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB8F4E4),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF06C893,
                          ).withValues(alpha: 0.14),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      CupertinoIcons.chevron_left,
                      color: Color(0xFF06C893),
                      size: 22,
                    ),
                  ),
                ),
              ),
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 68, 16, 40),
                physics: const BouncingScrollPhysics(),
                children: [
                  _InteractionSummaryCard(
                    agentAvatarUrl: agentAvatarUrl,
                    userAvatarUrl: userAvatarUrl,
                    days: days,
                    progress: progress,
                    stage: _stage,
                  ),
                  const SizedBox(height: 24),
                  _InteractionMarksCard(currentStage: _stage),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InteractionSummaryCard extends StatelessWidget {
  const _InteractionSummaryCard({
    required this.agentAvatarUrl,
    required this.userAvatarUrl,
    required this.days,
    required this.progress,
    required this.stage,
  });

  final String? agentAvatarUrl;
  final String? userAvatarUrl;
  final int days;
  final double progress;
  final int stage;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 183,
      decoration: BoxDecoration(
        color: const Color(0xFFF2FBFB),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF03A276).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 24,
            top: 24,
            child: Column(
              children: [
                SizedBox(
                  width: 120,
                  height: 64,
                  child: Stack(
                    children: [
                      _Avatar(
                        size: 64,
                        label: '我',
                        imageUrl: userAvatarUrl,
                        gradient: const [Color(0xFFE8F3FF), Color(0xFFF8FBFF)],
                      ),
                      Positioned(
                        left: 56,
                        child: _Avatar(
                          size: 64,
                          label: '伴',
                          imageUrl: agentAvatarUrl,
                          gradient: const [
                            Color(0xFFE8F3FF),
                            Color(0xFFDDEBFF),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      '已互动',
                      style: TextStyle(fontSize: 14, color: Colors.black),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$days',
                      style: const TextStyle(
                        fontSize: 24,
                        height: 1,
                        color: Color(0xFF06C893),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      '天',
                      style: TextStyle(fontSize: 14, color: Colors.black),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            right: 18,
            top: 10,
            child: _InteractionMarkIcon(size: 124, stage: stage),
          ),
          Positioned(
            left: 24,
            right: 26,
            bottom: 24,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFF51FFD0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF06C893).withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
                Positioned.fill(
                  left: 3,
                  right: 3,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF06C893),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -18,
                  top: -16,
                  child: _InteractionMarkIcon(size: 40, stage: 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractionMarksCard extends StatelessWidget {
  const _InteractionMarksCard({required this.currentStage});

  final int currentStage;

  static const _ranges = [
    '0-7天',
    '8-15天',
    '16-31天',
    '31-60天',
    '61-99天',
    '100天以上',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 340,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF2FBFB),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF03A276).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(CupertinoIcons.sparkles, size: 16, color: Color(0xFF06C893)),
              SizedBox(width: 4),
              Text(
                '互动标识',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _ranges.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 24,
                crossAxisSpacing: 24,
                childAspectRatio: 0.82,
              ),
              itemBuilder: (context, index) {
                final active = index <= currentStage;
                return Opacity(
                  opacity: active ? 1 : 0.55,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _InteractionMarkIcon(size: 84, stage: index),
                      const SizedBox(height: 4),
                      Text(
                        _ranges[index],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
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
  });

  final String label;
  final Color foreground;
  final Color background;

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
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: foreground,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
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
