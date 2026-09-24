part of 'package:companion_flutter/main.dart';

class _MusicComponentCard extends StatefulWidget {
  const _MusicComponentCard({
    required this.card,
    required this.isMine,
    required this.onTap,
    required this.onResolveTrack,
    required this.onPlaybackActivated,
    required this.onPrevious,
    required this.onNext,
    required this.onFavorite,
    required this.isActiveCard,
    required this.initialPosition,
    required this.favoriteMusicTrackIds,
    required this.busyMusicFavoriteIds,
    required this.canGoPrevious,
    required this.isBusy,
    this.trackPlaybackUpdates = true,
  });

  final ChatComponentCard card;
  final bool isMine;
  final VoidCallback onTap;
  final Future<MusicTrack?> Function(MusicTrack track) onResolveTrack;
  final VoidCallback onPlaybackActivated;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<MusicTrack> onFavorite;
  final bool isActiveCard;
  final Duration initialPosition;
  final Set<String> favoriteMusicTrackIds;
  final Set<String> busyMusicFavoriteIds;
  final bool canGoPrevious;
  final bool isBusy;
  final bool trackPlaybackUpdates;

  @override
  State<_MusicComponentCard> createState() => _MusicComponentCardState();
}

class _MusicComponentCardState extends State<_MusicComponentCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _discController;
  final _playback = MusicPlaybackController.instance;
  MusicTrack? _resolvedTrack;
  bool _loadingPlayback = false;
  String? _lastPlaybackSignature;
  bool _playbackListening = false;

  @override
  void initState() {
    super.initState();
    _discController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 18000),
    );
    _lastPlaybackSignature = _playbackSignature;
    _syncPlaybackSubscription(widget.trackPlaybackUpdates);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncDiscAnimation());
  }

  @override
  void didUpdateWidget(covariant _MusicComponentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackPlaybackUpdates != widget.trackPlaybackUpdates) {
      _syncPlaybackSubscription(widget.trackPlaybackUpdates);
    }
    _lastPlaybackSignature = _playbackSignature;
    _syncDiscAnimation();
  }

  @override
  void dispose() {
    _syncPlaybackSubscription(false);
    _discController.dispose();
    super.dispose();
  }

  void _syncPlaybackSubscription(bool enabled) {
    if (enabled && !_playbackListening) {
      _playback.addListener(_handlePlaybackChanged);
      _playbackListening = true;
      return;
    }
    if (!enabled && _playbackListening) {
      _playback.removeListener(_handlePlaybackChanged);
      _playbackListening = false;
    }
  }

  void _handlePlaybackChanged() {
    final signature = _playbackSignature;
    if (signature == _lastPlaybackSignature) return;
    _lastPlaybackSignature = signature;
    _syncDiscAnimation();
    if (mounted) setState(() {});
  }

  String get _playbackSignature {
    final track = _displayTrack;
    final isCurrent = widget.isActiveCard && _playback.isCurrentTrack(track);
    final isPlaying = isCurrent && _playback.isPlaying;
    final isLoading = isCurrent && _playback.isLoadingTrack(track);
    return [
      widget.isActiveCard,
      track?.id ?? '',
      isCurrent,
      isPlaying,
      isLoading,
    ].join('|');
  }

  void _syncDiscAnimation() {
    if (!mounted) return;
    if (!widget.isActiveCard ||
        !_playback.isCurrentTrack(_displayTrack) ||
        !_playback.isPlaying) {
      if (_discController.isAnimating) {
        _discController.stop(canceled: false);
      }
      return;
    }
    if (!_discController.isAnimating) _discController.repeat();
  }

  Future<void> _toggleCardPlayback(MusicTrack? track) async {
    if (track == null || _loadingPlayback) return;
    setState(() => _loadingPlayback = true);
    try {
      if (widget.isActiveCard && _playback.isCurrentTrack(track)) {
        if (_playback.isPlaying) {
          final toggled = await _playback.toggle(track);
          if (toggled) widget.onPlaybackActivated();
          return;
        }
        final resumed = await _playback.toggle(track);
        if (resumed) {
          widget.onPlaybackActivated();
          return;
        }
        final resolved = await widget.onResolveTrack(track);
        if (!mounted) return;
        final playable = resolved ?? track;
        setState(() => _resolvedTrack = playable);
        final played = await _playback.playTrack(
          playable,
          position: _playback.position,
        );
        if (played) widget.onPlaybackActivated();
        return;
      }
      final resolved = await widget.onResolveTrack(track);
      if (!mounted) return;
      final playable = resolved ?? track;
      setState(() => _resolvedTrack = playable);
      final played = await _playback.playTrack(
        playable,
        position: widget.initialPosition,
      );
      if (played) widget.onPlaybackActivated();
    } catch (_) {
      // Chat card controls should stay silent; the player page can show errors.
    } finally {
      if (mounted) setState(() => _loadingPlayback = false);
    }
  }

  void _toggleFavorite(MusicTrack? track) {
    if (track == null || widget.busyMusicFavoriteIds.contains(track.id)) return;
    widget.onFavorite(track);
  }

  @override
  Widget build(BuildContext context) {
    final displayTrack = _displayTrack;
    final track = _resolvedTrack?.id == displayTrack?.id
        ? _resolvedTrack
        : displayTrack;
    final title = track?.title ?? widget.card.title;
    final artist = track?.artist ?? widget.card.subtitle;
    final library = _musicLibraryTitle(track?.library ?? _stationLibrary);
    final accent = _musicAccentForTrack(track);
    final isCurrent = widget.isActiveCard && _playback.isCurrentTrack(track);
    final isPlaying = isCurrent && _playback.isPlaying;
    final isPlaybackLoading =
        _loadingPlayback || (isCurrent && _playback.isLoadingTrack(track));
    final isFavorite =
        track != null && widget.favoriteMusicTrackIds.contains(track.id);
    final isFavoriteBusy =
        track != null && widget.busyMusicFavoriteIds.contains(track.id);
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
            border: Border.all(color: accent.withValues(alpha: 0.32)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.18),
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.68),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            ' · ',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.50),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          _MusicCountdownText(
                            track: track,
                            isActiveCard: widget.isActiveCard,
                            trackPlaybackUpdates: widget.trackPlaybackUpdates,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.68),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.music_note_2,
                            color: accent,
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
                          const SizedBox(width: 6),
                          _MusicCardIconButton(
                            icon: isFavorite
                                ? CupertinoIcons.heart_fill
                                : CupertinoIcons.heart,
                            enabled: track != null && !isFavoriteBusy,
                            color: isFavorite
                                ? const Color(0xFF5ED8FF)
                                : Colors.white.withValues(alpha: 0.70),
                            onPressed: () => _toggleFavorite(track),
                          ),
                          _MusicCardIconButton(
                            icon: CupertinoIcons.backward_fill,
                            enabled: widget.canGoPrevious && !widget.isBusy,
                            color: Colors.white.withValues(alpha: 0.70),
                            onPressed: widget.onPrevious,
                          ),
                          _MusicCardIconButton(
                            icon: isPlaying
                                ? CupertinoIcons.pause_fill
                                : CupertinoIcons.play_fill,
                            emphasized: true,
                            enabled:
                                track != null &&
                                !widget.isBusy &&
                                !isPlaybackLoading,
                            loading: isPlaybackLoading,
                            color: accent,
                            onPressed: () =>
                                unawaited(_toggleCardPlayback(track)),
                          ),
                          _MusicCardIconButton(
                            icon: CupertinoIcons.forward_fill,
                            enabled: !widget.isBusy,
                            color: Colors.white.withValues(alpha: 0.70),
                            onPressed: widget.onNext,
                          ),
                        ],
                      ),
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

  MusicTrack? get _currentCardTrack {
    final rawTrack = widget.card.payload['track'];
    return rawTrack is Map
        ? MusicTrack.fromJson(Map<String, dynamic>.from(rawTrack))
        : null;
  }

  MusicTrack? get _displayTrack {
    final library = _stationLibrary;
    final liveTrack = _playback.track;
    if (widget.isActiveCard &&
        library != null &&
        liveTrack != null &&
        liveTrack.library == library) {
      return liveTrack;
    }
    return _currentCardTrack;
  }

  String? get _stationLibrary {
    final payloadLibrary = widget.card.payload['library']?.toString().trim();
    if (payloadLibrary != null && payloadLibrary.isNotEmpty) {
      return payloadLibrary;
    }
    final cardLibrary = _currentCardTrack?.library.trim();
    return cardLibrary == null || cardLibrary.isEmpty ? null : cardLibrary;
  }
}

class _MusicCardIconButton extends StatelessWidget {
  const _MusicCardIconButton({
    required this.icon,
    required this.enabled,
    required this.color,
    required this.onPressed,
    this.emphasized = false,
    this.loading = false,
  });

  final IconData icon;
  final bool enabled;
  final Color color;
  final VoidCallback onPressed;
  final bool emphasized;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final size = emphasized ? 30.0 : 25.0;
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: enabled && !loading ? onPressed : null,
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: emphasized && (enabled || loading)
                ? color
                : Colors.transparent,
          ),
          child: Center(
            child: loading
                ? const CupertinoActivityIndicator(
                    radius: 6.5,
                    color: Colors.white,
                  )
                : Transform.translate(
                    offset: emphasized && icon == CupertinoIcons.play_fill
                        ? const Offset(1.0, 0)
                        : Offset.zero,
                    child: Icon(
                      icon,
                      size: emphasized ? 14 : 13,
                      color: enabled
                          ? (emphasized ? _musicButtonForeground(color) : color)
                          : Colors.white.withValues(alpha: 0.24),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _MusicCountdownText extends StatefulWidget {
  const _MusicCountdownText({
    required this.track,
    required this.isActiveCard,
    required this.style,
    this.trackPlaybackUpdates = true,
  });

  final MusicTrack? track;
  final bool isActiveCard;
  final TextStyle style;
  final bool trackPlaybackUpdates;

  @override
  State<_MusicCountdownText> createState() => _MusicCountdownTextState();
}

class _MusicCountdownTextState extends State<_MusicCountdownText> {
  final _playback = MusicPlaybackController.instance;
  String? _lastLabel;
  bool _playbackListening = false;

  @override
  void initState() {
    super.initState();
    _lastLabel = _label;
    _syncPlaybackSubscription(widget.trackPlaybackUpdates);
  }

  @override
  void didUpdateWidget(covariant _MusicCountdownText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackPlaybackUpdates != widget.trackPlaybackUpdates) {
      _syncPlaybackSubscription(widget.trackPlaybackUpdates);
    }
    _lastLabel = _label;
  }

  @override
  void dispose() {
    _syncPlaybackSubscription(false);
    super.dispose();
  }

  void _syncPlaybackSubscription(bool enabled) {
    if (enabled && !_playbackListening) {
      _playback.addListener(_handlePlaybackChanged);
      _playbackListening = true;
      return;
    }
    if (!enabled && _playbackListening) {
      _playback.removeListener(_handlePlaybackChanged);
      _playbackListening = false;
    }
  }

  void _handlePlaybackChanged() {
    final label = _label;
    if (label == _lastLabel) return;
    _lastLabel = label;
    if (mounted) setState(() {});
  }

  String get _label {
    final track = widget.track;
    if (track == null) return '--:--';
    final duration = _durationFor(track);
    if (!widget.isActiveCard || !_playback.isCurrentTrack(track)) {
      return _formatMusicClock(duration);
    }
    final remaining = duration - _playback.position;
    return _formatMusicClock(remaining.isNegative ? Duration.zero : remaining);
  }

  Duration _durationFor(MusicTrack track) {
    final playbackDuration = _playback.duration;
    if (_playback.isCurrentTrack(track) && playbackDuration.inSeconds > 0) {
      return playbackDuration;
    }
    return Duration(seconds: math.max(track.durationSec, 0));
  }

  @override
  Widget build(BuildContext context) {
    return Text(_label, maxLines: 1, style: widget.style);
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
    return RepaintBoundary(
      child: SizedBox(
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
