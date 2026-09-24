part of 'package:companion_flutter/main.dart';

class _StickyMusicDock extends StatefulWidget {
  const _StickyMusicDock({
    required this.track,
    required this.isPlaying,
    required this.isLoading,
    required this.canGoPrevious,
    required this.isBusy,
    this.trackPlaybackUpdates = true,
    required this.onTap,
    required this.onPrevious,
    required this.onNext,
    required this.onTogglePlay,
    required this.onDismissed,
  });

  final MusicTrack track;
  final bool isPlaying;
  final bool isLoading;
  final bool canGoPrevious;
  final bool isBusy;
  final bool trackPlaybackUpdates;
  final VoidCallback onTap;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onTogglePlay;
  final VoidCallback onDismissed;

  @override
  State<_StickyMusicDock> createState() => _StickyMusicDockState();
}

class _StickyMusicDockState extends State<_StickyMusicDock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _discController;
  // 每次真正划走后自增,拼进 Dismissible 的 key 里强制换一个全新实例——
  // 划走后这个 dock 并不会被移出树(还得靠外层的 opacity/slide 隐藏它),
  // 复用同一个 key 会让内部已经"划出去"的位移状态一直留着,下次这里再显示
  // 音乐时它会带着上次划走的偏移量直接出现,而不是回到正常位置。
  int _dismissGeneration = 0;
  // 横向拖拽的实时进度,0=没动,1=已经完全划出容器(见 DismissUpdateDetails.
  // progress);只用来给"播放中"的暂停按钮做过渡预览,不影响真正的播放状态。
  double _dragProgress = 0;

  @override
  void initState() {
    super.initState();
    _discController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 18000),
    );
    _syncDisc();
  }

  @override
  void didUpdateWidget(covariant _StickyMusicDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying ||
        oldWidget.isLoading != widget.isLoading ||
        oldWidget.track.id != widget.track.id) {
      _syncDisc();
    }
  }

  void _syncDisc() {
    if (widget.isPlaying && !widget.isLoading) {
      if (!_discController.isAnimating) _discController.repeat();
    } else if (_discController.isAnimating) {
      _discController.stop(canceled: false);
    }
  }

  @override
  void dispose() {
    _discController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _musicAccentForTrack(widget.track);
    return Dismissible(
      key: ValueKey('sticky-music-dock-$_dismissGeneration'),
      direction: DismissDirection.horizontal,
      // 不需要划走后再收缩尺寸的二段动画——它已经飞出屏幕了,父级的
      // opacity/slide 紧接着会把它整个隐藏掉,没有"从列表移除"的场景要处理。
      resizeDuration: null,
      onUpdate: (details) {
        final progress = details.progress.clamp(0.0, 1.0);
        if (progress == _dragProgress) return;
        setState(() => _dragProgress = progress);
      },
      onDismissed: (_) {
        _dismissGeneration += 1;
        _dragProgress = 0;
        widget.onDismissed();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: PlatformBackdropGlass(
            sigma: 18,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF0F1A27).withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.20),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: RepaintBoundary(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.24),
                                blurRadius: 18,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: AnimatedBuilder(
                            animation: _discController,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _discController.value * math.pi * 2,
                                child: child,
                              );
                            },
                            child: _MusicDisc(track: widget.track, size: 64),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LoopingMarqueeText(
                            text: widget.track.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              height: 1.12,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '${_musicLibraryTitle(widget.track.library)} 频道 · ${widget.track.artist}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.62),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    height: 1.12,
                                  ),
                                ),
                              ),
                              Text(
                                ' · ',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.48),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  height: 1.12,
                                ),
                              ),
                              _MusicCountdownText(
                                track: widget.track,
                                isActiveCard: true,
                                trackPlaybackUpdates:
                                    widget.trackPlaybackUpdates,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.66),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  height: 1.12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    _DockIconButton(
                      icon: CupertinoIcons.backward_fill,
                      enabled: widget.canGoPrevious && !widget.isBusy,
                      accent: accent,
                      onPressed: widget.onPrevious,
                    ),
                    _DockIconButton(
                      icon: widget.isPlaying
                          ? CupertinoIcons.pause_fill
                          : CupertinoIcons.play_fill,
                      // 播放中被划走时,暂停图标随拖拽进度慢慢过渡成播放图标,
                      // 预告"划到底会停止播放"；没在播放或没在拖拽时不生效。
                      morphToIcon: widget.isPlaying
                          ? CupertinoIcons.play_fill
                          : null,
                      morphProgress: widget.isPlaying ? _dragProgress : 0,
                      emphasized: true,
                      enabled: !widget.isBusy && !widget.isLoading,
                      loading: widget.isLoading,
                      accent: accent,
                      onPressed: widget.onTogglePlay,
                    ),
                    _DockIconButton(
                      icon: CupertinoIcons.forward_fill,
                      enabled: !widget.isBusy,
                      accent: accent,
                      onPressed: widget.onNext,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockIconButton extends StatelessWidget {
  const _DockIconButton({
    required this.icon,
    required this.enabled,
    required this.accent,
    required this.onPressed,
    this.emphasized = false,
    this.loading = false,
    this.morphToIcon,
    this.morphProgress = 0,
  });

  final IconData icon;
  final bool enabled;
  final Color accent;
  final bool emphasized;
  final bool loading;
  // 拖拽划走时把 icon 慢慢过渡成 morphToIcon(如暂停→播放),预告松手后的
  // 结果；progress 为 0 时纯粹显示 icon,不产生任何额外开销。
  final IconData? morphToIcon;
  final double morphProgress;
  final VoidCallback onPressed;

  Widget _glyph(IconData glyph, Color color, double size) {
    return Transform.translate(
      offset: emphasized && glyph == CupertinoIcons.play_fill
          ? const Offset(1.2, 0)
          : Offset.zero,
      child: Icon(glyph, color: color, size: size),
    );
  }

  @override
  Widget build(BuildContext context) {
    final boxSize = emphasized ? 40.0 : 32.0;
    final color = enabled
        ? (emphasized
              ? _musicButtonForeground(accent)
              : Colors.white.withValues(alpha: 0.72))
        : Colors.white.withValues(alpha: 0.26);
    final size = emphasized ? 18.0 : 15.0;
    final morphing =
        !loading &&
        morphToIcon != null &&
        morphToIcon != icon &&
        morphProgress > 0;
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: enabled && !loading ? onPressed : null,
      child: SizedBox(
        width: boxSize,
        height: boxSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: emphasized && (enabled || loading) ? accent : null,
          ),
          child: Center(
            child: loading
                ? const CupertinoActivityIndicator(
                    radius: 8,
                    color: Colors.white,
                  )
                : morphing
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: 1 - morphProgress,
                        child: _glyph(icon, color, size),
                      ),
                      Opacity(
                        opacity: morphProgress,
                        child: _glyph(morphToIcon!, color, size),
                      ),
                    ],
                  )
                : _glyph(icon, color, size),
          ),
        ),
      ),
    );
  }
}

Color _musicAccentForTrack(MusicTrack? track) {
  final primary = _parseMusicAccent(track?.accentA);
  if (_isReadableMusicAccent(primary)) return primary;
  final secondary = _parseMusicAccent(track?.accentB);
  if (_isReadableMusicAccent(secondary)) return secondary;
  return _fallbackMusicAccent(track);
}

String _musicLibraryTitle(String? id) {
  return switch ((id ?? '').trim().toLowerCase()) {
    'focus' => '专注',
    'ambient' => 'Ambient',
    'sleep' => '睡眠',
    'relax' => '放松',
    'vocal' => '原声',
    'default' => '默认',
    final value when value.isNotEmpty => value,
    _ => '音乐',
  };
}

String _formatMusicClock(Duration value) {
  final totalSeconds = math.max(value.inSeconds, 0);
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

Color _parseMusicAccent(String? value) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) return const Color(0xFF2CD6C9);
  final normalized = raw.startsWith('#') ? raw : '#$raw';
  const palette = {
    '#1F6FFF': Color(0xFF2F80FF),
    '#18C6C0': Color(0xFF2CD6C9),
    '#7C3CFF': Color(0xFF7B5CFF),
    '#FF7A2F': Color(0xFFFF7A2F),
    '#20C46B': Color(0xFF21D57B),
  };
  final key = normalized.toUpperCase();
  final mapped = palette[key];
  if (mapped != null) return mapped;
  return _parseMusicDockColor(normalized);
}

bool _isReadableMusicAccent(Color color) {
  return color.computeLuminance() >= 0.10;
}

Color _musicButtonForeground(Color accent) {
  return accent.computeLuminance() >= 0.34
      ? const Color(0xFF071522)
      : Colors.white;
}

Color _fallbackMusicAccent(MusicTrack? track) {
  const palette = [
    Color(0xFF2F80FF),
    Color(0xFF2CD6C9),
    Color(0xFF21D57B),
    Color(0xFFFF7A2F),
    Color(0xFF8D6CFF),
  ];
  final seed =
      '${track?.id ?? ''}|${track?.title ?? ''}|${track?.artist ?? ''}|${track?.library ?? ''}';
  var hash = 17;
  for (final unit in seed.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return palette[hash % palette.length];
}

Color _parseMusicDockColor(String value) {
  final hex = value.replaceFirst('#', '').trim();
  if (hex.length != 6) return const Color(0xFF2CD6C9);
  final intValue = int.tryParse(hex, radix: 16);
  if (intValue == null) return const Color(0xFF2CD6C9);
  return Color(0xFF000000 | intValue);
}
