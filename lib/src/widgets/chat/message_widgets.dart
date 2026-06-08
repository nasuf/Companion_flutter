part of 'package:companion_flutter/main.dart';

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.controller,
    required this.messages,
    required this.isLoadingOlder,
    required this.bottomPadding,
    required this.onComponentCardTap,
    required this.onAchievementTap,
    required this.onResolveMusicTrack,
    this.agentAvatarUrl,
  });

  final ScrollController controller;
  final List<ChatMessage> messages;
  final bool isLoadingOlder;
  final double bottomPadding;
  final ValueChanged<ChatComponentCard> onComponentCardTap;
  final ValueChanged<AchievementItem> onAchievementTap;
  final Future<MusicTrack?> Function(MusicTrack track) onResolveMusicTrack;
  final String? agentAvatarUrl;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(
        child: Text(
          '还没有聊天记录，发一句话开始吧。',
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }
    return ListView.builder(
      controller: controller,
      padding: EdgeInsets.fromLTRB(12, 10, 12, bottomPadding),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: messages.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: isLoadingOlder
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : const SizedBox(height: 4),
          );
        }
        final message = messages[index - 1];
        return _MessageRow(
          message: message,
          agentAvatarUrl: agentAvatarUrl,
          onComponentCardTap: onComponentCardTap,
          onAchievementTap: onAchievementTap,
          onResolveMusicTrack: onResolveMusicTrack,
        );
      },
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.message,
    required this.onComponentCardTap,
    required this.onAchievementTap,
    required this.onResolveMusicTrack,
    this.agentAvatarUrl,
  });

  final ChatMessage message;
  final ValueChanged<ChatComponentCard> onComponentCardTap;
  final ValueChanged<AchievementItem> onAchievementTap;
  final Future<MusicTrack?> Function(MusicTrack track) onResolveMusicTrack;
  final String? agentAvatarUrl;
  static const _avatarSize = 40.0;
  static const _avatarGap = 10.0;

  @override
  Widget build(BuildContext context) {
    if (message.isAchievement) {
      final item = message.achievementItem;
      if (item == null) return const SizedBox.shrink();
      return _AchievementTimelineRow(
        item: item,
        onTap: () => onAchievementTap(item),
      );
    }
    if (message.isMusicStatus) {
      return _MusicStatusTimelineRow(message: message);
    }

    final avatar = _Avatar(
      size: _avatarSize,
      label: message.isMine ? '我' : '伴',
      imageUrl: message.isMine ? null : agentAvatarUrl,
      gradient: message.isMine
          ? const [Color(0xFFE8F3FF), Color(0xFFF8FBFF)]
          : const [Color(0xFFE8F3FF), Color(0xFFDDEBFF)],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: message.isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!message.isMine) ...[avatar, const SizedBox(width: _avatarGap)],
          _Bubble(
            message: message,
            onComponentCardTap: onComponentCardTap,
            onResolveMusicTrack: onResolveMusicTrack,
          ),
          if (message.isMine) ...[const SizedBox(width: _avatarGap), avatar],
        ],
      ),
    );
  }
}

class _MusicStatusTimelineRow extends StatelessWidget {
  const _MusicStatusTimelineRow({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final title = message.metadata?['music_track_title']?.toString().trim();
    final hasTitle = title != null && title.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 318),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFEAF8EF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFBDEBCB)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF28C36A).withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD9F5E4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.music_note_2,
                      size: 16,
                      color: Color(0xFF159A4D),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '你们开始一起听',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Color(0xFF149249),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.62),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(
                                    0xFFBDEBCB,
                                  ).withValues(alpha: 0.72),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                child: Text(
                                  _formatTime(message.createdAt),
                                  style: TextStyle(
                                    color: const Color(
                                      0xFF149249,
                                    ).withValues(alpha: 0.62),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          hasTitle ? '《$title》' : message.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(
                              0xFF149249,
                            ).withValues(alpha: 0.82),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
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

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.onComponentCardTap,
    required this.onResolveMusicTrack,
  });

  final ChatMessage message;
  final ValueChanged<ChatComponentCard> onComponentCardTap;
  final Future<MusicTrack?> Function(MusicTrack track) onResolveMusicTrack;

  @override
  Widget build(BuildContext context) {
    final componentCard = message.componentCard;
    final showTextWithCard =
        componentCard?.type == 'music_track' &&
        message.content.trim().isNotEmpty;
    return Flexible(
      child: Column(
        crossAxisAlignment: message.isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (showTextWithCard) ...[
            _MessageTextBubble(message: message),
            const SizedBox(height: 8),
          ],
          if (componentCard != null)
            _ComponentCardBubble(
              card: componentCard,
              isMine: message.isMine,
              onTap: () => onComponentCardTap(componentCard),
              onResolveMusicTrack: onResolveMusicTrack,
            )
          else
            _MessageTextBubble(message: message),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTime(message.createdAt),
                style: const TextStyle(color: AppColors.muted, fontSize: 10),
              ),
              if (message.isMine && message.read) ...[
                const SizedBox(width: 5),
                const Text(
                  '✓✓',
                  style: TextStyle(color: Color(0xFFFFA726), fontSize: 10),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageTextBubble extends StatelessWidget {
  const _MessageTextBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 270),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: message.isMine ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(message.isMine ? 17 : 3),
            topRight: Radius.circular(message.isMine ? 3 : 17),
            bottomLeft: const Radius.circular(17),
            bottomRight: const Radius.circular(17),
          ),
          border: Border.all(
            color: message.isMine ? AppColors.accent : AppColors.hairline,
          ),
          boxShadow: [
            BoxShadow(
              color: message.isMine
                  ? AppColors.accent.withValues(alpha: 0.18)
                  : const Color(0xFF24344A).withValues(alpha: 0.08),
              blurRadius: message.isMine ? 18 : 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Text(
            message.content,
            style: TextStyle(
              color: message.isMine ? Colors.white : AppColors.text,
              fontSize: 15,
              height: 1.42,
            ),
          ),
        ),
      ),
    );
  }
}

class _ComponentCardBubble extends StatelessWidget {
  const _ComponentCardBubble({
    required this.card,
    required this.isMine,
    required this.onTap,
    required this.onResolveMusicTrack,
  });

  final ChatComponentCard card;
  final bool isMine;
  final VoidCallback onTap;
  final Future<MusicTrack?> Function(MusicTrack track) onResolveMusicTrack;

  @override
  Widget build(BuildContext context) {
    final accent = _parseColor(card.accent);
    if (card.type == 'music_track') {
      return _MusicComponentCard(
        card: card,
        isMine: isMine,
        accent: accent,
        onTap: onTap,
        onResolveTrack: onResolveMusicTrack,
      );
    }
    final isTimeCapsule = card.type == 'time_capsule';
    final timeCapsuleContent = _timeCapsuleContent(card);
    final icon = switch (card.type) {
      'weather' => CupertinoIcons.cloud_sun_fill,
      'checkin_reminder' ||
      'checkin_habit' => CupertinoIcons.check_mark_circled_solid,
      _ => CupertinoIcons.square_grid_2x2_fill,
    };

    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 292),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(isMine ? 20 : 5),
              topRight: Radius.circular(isMine ? 5 : 20),
              bottomLeft: const Radius.circular(20),
              bottomRight: const Radius.circular(20),
            ),
            border: Border.all(color: accent.withValues(alpha: 0.24)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.14),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(isMine ? 20 : 5),
              topRight: Radius.circular(isMine ? 5 : 20),
              bottomLeft: const Radius.circular(20),
              bottomRight: const Radius.circular(20),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -26,
                  top: -26,
                  child: Container(
                    width: 102,
                    height: 102,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 14, 15, 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _ComponentCardIcon(
                            type: card.type,
                            accent: accent,
                            fallbackIcon: icon,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: isTimeCapsule
                                ? Text(
                                    card.subtitle.isEmpty
                                        ? '时间胶囊'
                                        : card.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      height: 1.25,
                                    ),
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        card.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.text,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          height: 1.15,
                                        ),
                                      ),
                                      if (card.subtitle.isNotEmpty)
                                        Text(
                                          card.subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.muted,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 11,
                                            height: 1.35,
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                      if ((isTimeCapsule ? timeCapsuleContent : card.body)
                          .isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          isTimeCapsule ? timeCapsuleContent : card.body,
                          maxLines: isTimeCapsule ? 2 : 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 14,
                            height: 1.42,
                          ),
                        ),
                      ],
                      if (card.footer.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          card.footer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _parseColor(String value) {
    final hex = value.replaceFirst('#', '').trim();
    if (hex.length != 6) return const Color(0xFF7C3CFF);
    final intValue = int.tryParse(hex, radix: 16);
    if (intValue == null) return const Color(0xFF7C3CFF);
    return Color(0xFF000000 | intValue);
  }

  String _timeCapsuleContent(ChatComponentCard card) {
    final body = card.body.trim();
    if (body.isNotEmpty) return body;
    final payloadContent = card.payload['content']?.toString().trim();
    if (payloadContent != null && payloadContent.isNotEmpty) {
      return payloadContent;
    }
    return card.title.trim();
  }
}

class _MusicComponentCard extends StatefulWidget {
  const _MusicComponentCard({
    required this.card,
    required this.isMine,
    required this.accent,
    required this.onTap,
    required this.onResolveTrack,
  });

  final ChatComponentCard card;
  final bool isMine;
  final Color accent;
  final VoidCallback onTap;
  final Future<MusicTrack?> Function(MusicTrack track) onResolveTrack;

  @override
  State<_MusicComponentCard> createState() => _MusicComponentCardState();
}

class _MusicComponentCardState extends State<_MusicComponentCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _discController;
  final _playback = MusicPlaybackController.instance;
  MusicTrack? _resolvedTrack;

  @override
  void initState() {
    super.initState();
    _discController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 18000),
    );
    _playback.addListener(_handlePlaybackChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncDiscAnimation());
  }

  @override
  void didUpdateWidget(covariant _MusicComponentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncDiscAnimation();
  }

  @override
  void dispose() {
    _playback.removeListener(_handlePlaybackChanged);
    _discController.dispose();
    super.dispose();
  }

  void _handlePlaybackChanged() {
    _syncDiscAnimation();
    if (mounted) setState(() {});
  }

  void _syncDiscAnimation() {
    if (!mounted) return;
    if (!_playback.isCurrentTrack(_currentCardTrack) || !_playback.isPlaying) {
      if (_discController.isAnimating) {
        _discController.stop(canceled: false);
      }
      return;
    }
    if (!_discController.isAnimating) _discController.repeat();
  }

  Future<void> _toggleCardPlayback(MusicTrack? track) async {
    if (track == null) return;
    try {
      if (_playback.isCurrentTrack(track)) {
        if (_playback.isPlaying) {
          await _playback.toggle(track);
          return;
        }
        final resumed = await _playback.toggle(track);
        if (resumed) return;
        final resolved = await widget.onResolveTrack(track);
        if (!mounted) return;
        final playable = resolved ?? track;
        setState(() => _resolvedTrack = playable);
        await _playback.playTrack(playable, position: _playback.position);
        return;
      }
      final resolved = await widget.onResolveTrack(track);
      if (!mounted) return;
      final playable = resolved ?? track;
      setState(() => _resolvedTrack = playable);
      await _playback.toggle(playable);
    } catch (_) {
      // Chat card controls should stay silent; the player page can show errors.
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardTrack = _currentCardTrack;
    final track = _resolvedTrack?.id == cardTrack?.id
        ? _resolvedTrack
        : cardTrack;
    final title = track?.title ?? widget.card.title;
    final artist = track?.artist ?? widget.card.subtitle;
    final duration = track?.durationLabel ?? '';
    final library = widget.card.body.isNotEmpty ? widget.card.body : '音乐频道';
    final isCurrent = _playback.isCurrentTrack(track);
    final isPlaying = isCurrent && _playback.isPlaying;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 292),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF101A27),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(widget.isMine ? 22 : 6),
              topRight: Radius.circular(widget.isMine ? 6 : 22),
              bottomLeft: const Radius.circular(22),
              bottomRight: const Radius.circular(22),
            ),
            border: Border.all(color: widget.accent.withValues(alpha: 0.32)),
            boxShadow: [
              BoxShadow(
                color: widget.accent.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                _MusicCardDisc(
                  track: track,
                  animation: _discController,
                  isPlaying: isPlaying,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LoopingMarqueeText(
                        text: title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          artist,
                          duration,
                        ].where((item) => item.isNotEmpty).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.68),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.music_note_2,
                            color: widget.accent,
                            size: 15,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              library,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                CupertinoButton(
                  minimumSize: Size.zero,
                  padding: EdgeInsets.zero,
                  onPressed: track == null
                      ? null
                      : () => unawaited(_toggleCardPlayback(track)),
                  child: Icon(
                    isPlaying
                        ? CupertinoIcons.pause_circle_fill
                        : CupertinoIcons.play_circle_fill,
                    color: widget.accent,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  MusicTrack? get _currentCardTrack {
    final rawTrack = widget.card.payload['track'];
    return rawTrack is Map
        ? MusicTrack.fromJson(Map<String, dynamic>.from(rawTrack))
        : null;
  }
}

class _MusicCardDisc extends StatelessWidget {
  const _MusicCardDisc({
    required this.track,
    required this.animation,
    required this.isPlaying,
  });

  final MusicTrack? track;
  final Animation<double> animation;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final angle = animation.value * math.pi * 2;
          return Transform.rotate(angle: angle, child: child);
        },
        child: _MusicDisc(track: track, size: 58),
      ),
    );
  }
}

class _LoopingMarqueeText extends StatefulWidget {
  const _LoopingMarqueeText({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<_LoopingMarqueeText> createState() => _LoopingMarqueeTextState();
}

class _LoopingMarqueeTextState extends State<_LoopingMarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _overflow = 0;
  bool _shouldScroll = false;
  bool _scrolling = false;
  bool _looping = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(covariant _LoopingMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text == widget.text && oldWidget.style == widget.style) {
      return;
    }
    _controller.stop();
    _controller.reset();
    _overflow = 0;
    _shouldScroll = false;
    _scrolling = false;
    _looping = false;
  }

  @override
  void dispose() {
    _looping = false;
    _controller.dispose();
    super.dispose();
  }

  void _measureAndStart(double maxWidth) {
    if (!mounted || !maxWidth.isFinite || maxWidth <= 0) return;
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    final overflow = painter.width - maxWidth;
    final shouldScroll = overflow > 6;
    if (_shouldScroll != shouldScroll ||
        (shouldScroll && (_overflow - overflow).abs() > 1)) {
      setState(() {
        _shouldScroll = shouldScroll;
        _overflow = math.max(0, overflow);
      });
    }
    if (shouldScroll && !_looping) {
      _looping = true;
      unawaited(_runLoop());
    }
  }

  Future<void> _runLoop() async {
    while (mounted && _looping && _shouldScroll) {
      await Future<void>.delayed(const Duration(seconds: 5));
      if (!mounted || !_looping || !_shouldScroll) break;
      final durationMs = ((_overflow + 36) * 18).clamp(2200, 5200).round();
      _controller.duration = Duration(milliseconds: durationMs);
      setState(() => _scrolling = true);
      await _controller.forward(from: 0);
      if (!mounted) break;
      _controller.reset();
      setState(() => _scrolling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lineHeight =
        (widget.style.fontSize ?? 15) * (widget.style.height ?? 1.2);
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _measureAndStart(constraints.maxWidth),
        );
        if (!_shouldScroll || !_scrolling) {
          return Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: widget.style,
          );
        }
        return SizedBox(
          height: lineHeight,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final offset =
                    -(_overflow + 20) *
                    Curves.easeInOutCubic.transform(_controller.value);
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: child,
                );
              },
              child: OverflowBox(
                maxWidth: double.infinity,
                minHeight: lineHeight,
                maxHeight: lineHeight,
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.text,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                  style: widget.style,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ComponentCardIcon extends StatelessWidget {
  const _ComponentCardIcon({
    required this.type,
    required this.accent,
    required this.fallbackIcon,
  });

  final String type;
  final Color accent;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    if (type == 'time_capsule') {
      return SizedBox(
        width: 34,
        height: 34,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.22),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: CustomPaint(
              size: const Size(23, 23),
              painter: _CapsuleSidebarIconPainter(accent: accent),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(fallbackIcon, color: accent, size: 19),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.size,
    required this.label,
    required this.gradient,
    this.imageUrl,
  });

  final double size;
  final String label;
  final List<Color> gradient;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: gradient),
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.10),
            blurRadius: size * 0.42,
            offset: Offset(0, size * 0.14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _hasImage
          ? Image.network(
              imageUrl!,
              key: ValueKey(imageUrl),
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => _fallback,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return _fallback;
              },
            )
          : _fallback,
    );
  }

  bool get _hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  Widget get _fallback {
    return Center(
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.accent,
          fontSize: math.max(12, size * 0.42),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
