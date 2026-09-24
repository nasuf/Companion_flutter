part of 'package:companion_flutter/main.dart';

class _MusicFavoritesSheetRoute extends StatefulWidget {
  const _MusicFavoritesSheetRoute({
    required this.tracks,
    required this.currentTrackId,
    required this.maxSize,
    required this.onPlay,
  });

  static const initialSize = 0.42;

  final List<MusicTrack> tracks;
  final String? currentTrackId;
  final double maxSize;
  final ValueChanged<MusicTrack> onPlay;

  @override
  State<_MusicFavoritesSheetRoute> createState() =>
      _MusicFavoritesSheetRouteState();
}

class _MusicFavoritesSheetRouteState extends State<_MusicFavoritesSheetRoute> {
  late final DraggableScrollableController _sheetController;
  late final ValueNotifier<double> _expansionProgress;

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
    _expansionProgress = ValueNotifier<double>(0);
    _sheetController.addListener(_updateExpansionProgress);
  }

  @override
  void dispose() {
    _sheetController.removeListener(_updateExpansionProgress);
    _sheetController.dispose();
    _expansionProgress.dispose();
    super.dispose();
  }

  void _updateExpansionProgress() {
    if (!_sheetController.isAttached) return;
    final denominator = widget.maxSize - _MusicFavoritesSheetRoute.initialSize;
    if (denominator <= 0) return;
    final progress =
        ((_sheetController.size - _MusicFavoritesSheetRoute.initialSize) /
                denominator)
            .clamp(0.0, 1.0);
    if ((progress - _expansionProgress.value).abs() > 0.005) {
      _expansionProgress.value = progress;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      expand: false,
      initialChildSize: _MusicFavoritesSheetRoute.initialSize,
      minChildSize: 0.32,
      maxChildSize: widget.maxSize,
      snap: true,
      snapSizes: [_MusicFavoritesSheetRoute.initialSize, widget.maxSize],
      builder: (context, scrollController) {
        return _MusicFavoritesSheet(
          tracks: widget.tracks,
          currentTrackId: widget.currentTrackId,
          scrollController: scrollController,
          expansionProgress: _expansionProgress,
          onPlay: widget.onPlay,
        );
      },
    );
  }
}

class _MusicFavoritesSheet extends StatelessWidget {
  const _MusicFavoritesSheet({
    required this.tracks,
    required this.currentTrackId,
    required this.scrollController,
    required this.expansionProgress,
    required this.onPlay,
  });

  final List<MusicTrack> tracks;
  final String? currentTrackId;
  final ScrollController scrollController;
  final ValueListenable<double> expansionProgress;
  final ValueChanged<MusicTrack> onPlay;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return ValueListenableBuilder<double>(
      valueListenable: expansionProgress,
      builder: (context, progress, child) {
        final horizontalMargin = lerpDouble(12, 0, progress)!;
        final bottomMargin = lerpDouble(12, 0, progress)!;
        final bottomRadius = lerpDouble(30, 0, progress)!;
        return Container(
          margin: EdgeInsets.fromLTRB(
            horizontalMargin,
            0,
            horizontalMargin,
            bottomMargin,
          ),
          padding: EdgeInsets.fromLTRB(16, 10, 16, bottomPadding + 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF182033), Color(0xFF0D1420), Color(0xFF070A10)],
            ),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(30),
              bottom: Radius.circular(bottomRadius),
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.40),
                blurRadius: 48,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: CustomScrollView(
            controller: scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.heart_fill,
                          color: Color(0xFF5ED8FF),
                          size: 23,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            '我的收藏',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        Text(
                          '${tracks.length} 首',
                          style: const TextStyle(
                            color: Color(0x8CFFFFFF),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
              if (tracks.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(10, 22, 10, 30),
                    child: Text(
                      '还没有收藏歌曲。播放时点爱心，这里就会出现你的歌单。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0x8CFFFFFF),
                        fontSize: 14,
                        height: 1.5,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                )
              else
                SliverList.separated(
                  itemCount: tracks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    final selected = track.id == currentTrackId;
                    return _FavoriteTrackTile(
                      track: track,
                      selected: selected,
                      onTap: () => onPlay(track),
                    );
                  },
                ),
              SliverToBoxAdapter(child: SizedBox(height: bottomPadding + 8)),
            ],
          ),
        );
      },
    );
  }
}

class _FavoriteTrackTile extends StatelessWidget {
  const _FavoriteTrackTile({
    required this.track,
    required this.selected,
    required this.onTap,
  });

  final MusicTrack track;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0x3318C6C0)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? const Color(0x665ED8FF)
                : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Row(
          children: [
            _FavoriteDisc(track: track, selected: selected),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.durationLabel,
                    style: const TextStyle(
                      color: Color(0x8CFFFFFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? CupertinoIcons.play_circle_fill
                  : CupertinoIcons.play_circle,
              color: selected
                  ? const Color(0xFF7DE7FF)
                  : Colors.white.withValues(alpha: 0.38),
              size: 26,
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteDisc extends StatelessWidget {
  const _FavoriteDisc({required this.track, required this.selected});

  final MusicTrack track;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final coverUrl = track.coverImageUrl;
    final coverProvider = coverUrl == null
        ? AssetImage(track.coverAsset) as ImageProvider
        : NetworkImage(coverUrl) as ImageProvider;
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFF22313F), Color(0xFF071018), Color(0xFF020507)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF1F6FFF,
            ).withValues(alpha: selected ? 0.25 : 0.10),
            blurRadius: selected ? 18 : 12,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(image: coverProvider, fit: BoxFit.cover),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
        ),
      ),
    );
  }
}

class _MusicGlassButton extends StatelessWidget {
  const _MusicGlassButton({
    required this.width,
    required this.height,
    required this.radius,
    required this.child,
  });

  final double width;
  final double height;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: RouteSettledBlur.backdrop(
        sigma: 22,
        child: Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 42,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
