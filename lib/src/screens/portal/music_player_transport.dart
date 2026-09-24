part of 'package:companion_flutter/main.dart';

class _MusicTransportPanel extends StatelessWidget {
  const _MusicTransportPanel({required this.compact, required this.child});

  final bool compact;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, compact ? 8 : 10, 12, compact ? 10 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFF071018).withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MusicProgressBar extends StatelessWidget {
  const _MusicProgressBar({
    required this.position,
    required this.duration,
    required this.progress,
    required this.onSeekStart,
    required this.onSeekChanged,
    required this.onSeekEnd,
  });

  final Duration position;
  final Duration duration;
  final double progress;
  final ValueChanged<double> onSeekStart;
  final ValueChanged<double> onSeekChanged;
  final ValueChanged<double> onSeekEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 28,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: const Color(0xFF5ED8FF),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.16),
              thumbColor: Colors.white,
              overlayColor: const Color(0xFF5ED8FF).withValues(alpha: 0.16),
            ),
            child: Slider(
              min: 0,
              max: 1,
              value: progress.clamp(0.0, 1.0),
              onChangeStart: onSeekStart,
              onChanged: onSeekChanged,
              onChangeEnd: onSeekEnd,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_time(position), style: _timeStyle),
              const Text('标准音质', style: _timeStyle),
              Text(_time(duration), style: _timeStyle),
            ],
          ),
        ),
      ],
    );
  }

  static const _timeStyle = TextStyle(
    color: Color(0xA8FFFFFF),
    fontSize: 10.5,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
  );

  static String _time(Duration duration) {
    final seconds = duration.inSeconds.clamp(0, 24 * 60 * 60).toInt();
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }
}

class _MusicControlDeck extends StatelessWidget {
  const _MusicControlDeck({
    required this.isPlaying,
    required this.isFavorite,
    required this.canGoPrevious,
    required this.loading,
    required this.compact,
    required this.onPrevious,
    required this.onNext,
    required this.onTogglePlay,
    required this.onToggleFavorite,
  });

  final bool isPlaying;
  final bool isFavorite;
  final bool canGoPrevious;
  final bool loading;
  final bool compact;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onTogglePlay;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final playSize = compact ? 56.0 : 68.0;
    final playIconSize = compact ? 26.0 : 30.0;
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: _PlayerIconButton(
              icon: CupertinoIcons.heart_fill,
              color: isFavorite
                  ? const Color(0xFF5ED8FF)
                  : Colors.white.withValues(alpha: 0.74),
              onPressed: onToggleFavorite,
            ),
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.center,
            child: _PlayerIconButton(
              icon: CupertinoIcons.backward_fill,
              onPressed: canGoPrevious && !loading ? onPrevious : null,
            ),
          ),
        ),
        SizedBox(
          width: playSize + (compact ? 18 : 24),
          child: Center(
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: loading ? null : onTogglePlay,
              child: Container(
                width: playSize,
                height: playSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF8EE7FF), Color(0xFF1F6FFF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1F6FFF).withValues(alpha: 0.30),
                      blurRadius: 34,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Center(
                  child: loading
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : isPlaying
                      ? Icon(
                          CupertinoIcons.pause_fill,
                          color: Colors.white,
                          size: compact ? 27 : 31,
                        )
                      : Transform.translate(
                          offset: const Offset(2, 0),
                          child: Icon(
                            CupertinoIcons.play_fill,
                            color: Colors.white,
                            size: playIconSize,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.center,
            child: _PlayerIconButton(
              icon: CupertinoIcons.forward_fill,
              onPressed: loading ? null : onNext,
            ),
          ),
        ),
        const Expanded(child: SizedBox.shrink()),
      ],
    );
  }
}

class _PlayerIconButton extends StatelessWidget {
  const _PlayerIconButton({
    required this.icon,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: Icon(
        icon,
        color: enabled
            ? color ?? Colors.white.withValues(alpha: 0.78)
            : Colors.white.withValues(alpha: 0.22),
        size: 28,
      ),
    );
  }
}

class _MusicHintStrip extends StatelessWidget {
  const _MusicHintStrip({
    required this.favoriteCount,
    required this.selectedLibrary,
    required this.loading,
    required this.onTap,
  });

  final int favoriteCount;
  final String selectedLibrary;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: RouteSettledBlur.backdrop(
          sigma: 20,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  loading
                      ? CupertinoIcons.shuffle
                      : CupertinoIcons.music_note_2,
                  color: const Color(0xFF7DE7FF),
                  size: 22,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    loading
                        ? '正在从 $selectedLibrary 随机取一首'
                        : '$selectedLibrary 频道 · 收藏 $favoriteCount 首',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xDFFFFFFF),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  CupertinoIcons.chevron_up,
                  color: Color(0x78FFFFFF),
                  size: 17,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
