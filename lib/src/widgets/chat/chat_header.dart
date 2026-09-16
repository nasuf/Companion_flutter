part of 'package:companion_flutter/main.dart';

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.agentName,
    required this.topInset,
    this.interactionDays,
    this.aiStatus,
    this.aiStatusLabel,
    this.avatarUrl,
    this.isMusicListening = false,
    this.isMusicPlaying = false,
    this.onMusicTap,
    required this.onAvatarDoubleTap,
    required this.onInteractionTap,
    required this.onOpenSidebar,
  });

  final String agentName;
  final double topInset;
  final int? interactionDays;
  final String? aiStatus;
  final String? aiStatusLabel;
  final String? avatarUrl;
  final bool isMusicListening;
  final bool isMusicPlaying;
  final VoidCallback? onMusicTap;
  final VoidCallback onAvatarDoubleTap;
  final VoidCallback onInteractionTap;
  final VoidCallback onOpenSidebar;

  @override
  Widget build(BuildContext context) {
    final statusLabel = formatAgentStatusLabel(
      status: aiStatus,
      label: aiStatusLabel,
    );
    final statusColor = _agentStatusColor(aiStatus);
    return Container(
      height: topInset + 76,
      padding: EdgeInsets.fromLTRB(16, topInset + 10, 12, 10),
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
            child: Row(
              children: [
                Flexible(
                  fit: FlexFit.loose,
                  child: Text(
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
                ),
                if (statusLabel != null) ...[
                  const SizedBox(width: 6),
                  _HeaderPill(
                    foreground: statusColor.foreground,
                    background: statusColor.background,
                    label: statusLabel,
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
                  ? '连续互动天数'
                  : '连续互动 $interactionDays 天',
              child: _InteractionMarkIcon(
                size: 40,
                stage: interactionFlameStage(interactionDays ?? 0),
              ),
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

class _InteractionMarkIcon extends StatelessWidget {
  const _InteractionMarkIcon({required this.size, required this.stage});

  final double size;
  final int stage;

  static const _assets = [
    'assets/interaction/streak-stage-0.png',
    'assets/interaction/streak-stage-1.png',
    'assets/interaction/streak-stage-2.png',
    'assets/interaction/streak-stage-3.png',
    'assets/interaction/streak-stage-4.png',
    'assets/interaction/streak-stage-5.png',
  ];

  static const _shadowColors = [
    Color(0xFF00D7CD),
    Color(0xFF00D6DF),
    Color(0xFF01A0FD),
    Color(0xFF8F6BFF),
    Color(0xFFFF58D8),
    Color(0xFF8A5CFF),
  ];

  static String assetForStage(int stage) {
    final index = stage.clamp(0, _assets.length - 1);
    return _assets[index];
  }

  static Color shadowColorForStage(int stage) {
    final index = stage.clamp(0, _shadowColors.length - 1);
    return _shadowColors[index];
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        assetForStage(stage),
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class _CurrentInteractionMark extends StatelessWidget {
  const _CurrentInteractionMark({required this.stage});

  final int stage;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 124,
      height: 124,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 8,
            top: 74,
            child: SvgPicture.asset(
              'assets/interaction/current-mark-shadow.svg',
              width: 112,
              height: 49,
              fit: BoxFit.fill,
              colorFilter: ColorFilter.mode(
                _InteractionMarkIcon.shadowColorForStage(stage),
                BlendMode.srcIn,
              ),
            ),
          ),
          Positioned(
            left: 20,
            top: 0,
            child: Transform.rotate(
              angle: math.pi / 12,
              child: SizedBox(
                width: 84,
                height: 100,
                child: Image.asset(
                  _InteractionMarkIcon.assetForStage(stage),
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
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
        child: PlatformBackdropGlass(
          sigma: 8,
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
