part of 'package:companion_flutter/main.dart';

class _DailyPhotoPreviewDialog extends StatefulWidget {
  const _DailyPhotoPreviewDialog({
    required this.group,
    required this.initialIndex,
    required this.headers,
    required this.onClose,
  });

  final DailySharePhotoGroup group;
  final int initialIndex;
  final Map<String, String>? headers;
  final VoidCallback onClose;

  @override
  State<_DailyPhotoPreviewDialog> createState() =>
      _DailyPhotoPreviewDialogState();
}

class _DailyPhotoPreviewDialogState extends State<_DailyPhotoPreviewDialog> {
  late final PageController _pageController;
  late final ScrollController _thumbController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(
      0,
      widget.group.photos.length - 1,
    );
    _pageController = PageController(initialPage: _currentIndex);
    _thumbController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerThumbnail());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbController.dispose();
    super.dispose();
  }

  void _handlePageChanged(int index) {
    setState(() => _currentIndex = index);
    _centerThumbnail();
  }

  void _selectPhoto(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
    _centerThumbnail(index);
  }

  void _centerThumbnail([int? index]) {
    if (!_thumbController.hasClients) return;
    final targetIndex = index ?? _currentIndex;
    final viewport = _thumbController.position.viewportDimension;
    final target =
        targetIndex * _DailyPreviewMetrics.thumbStride -
        viewport / 2 +
        _DailyPreviewMetrics.thumbWidth / 2;
    _thumbController.animateTo(
      target.clamp(
        _thumbController.position.minScrollExtent,
        _thumbController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.group.photos;
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: const SizedBox.expand(),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: _DailyCircleButton(
                      icon: CupertinoIcons.xmark,
                      onPressed: widget.onClose,
                      dark: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: PageView.builder(
                      key: const ValueKey('daily-photo-preview-page-view'),
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      onPageChanged: _handlePageChanged,
                      itemCount: photos.length,
                      itemBuilder: (context, index) {
                        final photo = photos[index];
                        return _DailyZoomablePreviewImage(
                          photo: photo,
                          index: index,
                          headers: widget.headers,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DailyPreviewThumbStrip(
                    photos: photos,
                    currentIndex: _currentIndex,
                    headers: widget.headers,
                    controller: _thumbController,
                    onSelect: _selectPhoto,
                  ),
                  const SizedBox(height: 12),
                  _DailyPreviewCaption(
                    title: widget.group.title,
                    note: '${widget.group.subtitle} · 第 ${_currentIndex + 1} 张',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyPreviewMetrics {
  const _DailyPreviewMetrics._();

  static const thumbWidth = 42.0;
  static const thumbHeight = 54.0;
  static const thumbGap = 8.0;
  static const thumbStride = thumbWidth + thumbGap;
}

class _DailyZoomablePreviewImage extends StatelessWidget {
  const _DailyZoomablePreviewImage({
    required this.photo,
    required this.index,
    required this.headers,
  });

  final ChatAttachment photo;
  final int index;
  final Map<String, String>? headers;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.42),
                blurRadius: 80,
                offset: const Offset(0, 34),
              ),
            ],
          ),
          child: InteractiveViewer(
            key: ValueKey('daily-photo-preview-zoom-$index'),
            minScale: 1,
            maxScale: 4,
            clipBehavior: Clip.none,
            panEnabled: true,
            scaleEnabled: true,
            child: Image.network(
              photo.url,
              key: ValueKey('daily-photo-preview-$index'),
              headers: headers,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const _DailyImageFallback(dark: true),
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyPreviewThumbStrip extends StatelessWidget {
  const _DailyPreviewThumbStrip({
    required this.photos,
    required this.currentIndex,
    required this.headers,
    required this.controller,
    required this.onSelect,
  });

  final List<ChatAttachment> photos;
  final int currentIndex;
  final Map<String, String>? headers;
  final ScrollController controller;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('daily-photo-preview-thumbs'),
      height: 66,
      child: ListView.separated(
        controller: controller,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        itemCount: photos.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: _DailyPreviewMetrics.thumbGap),
        itemBuilder: (context, index) {
          final selected = index == currentIndex;
          final photo = photos[index];
          return GestureDetector(
            key: ValueKey('daily-photo-preview-thumb-$index'),
            onTap: () => onSelect(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: selected
                  ? _DailyPreviewMetrics.thumbWidth + 8
                  : _DailyPreviewMetrics.thumbWidth,
              height: _DailyPreviewMetrics.thumbHeight,
              padding: EdgeInsets.all(selected ? 2 : 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: selected ? 0.88 : 0),
                  width: selected ? 2 : 0,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AnimatedOpacity(
                  opacity: selected ? 1 : 0.62,
                  duration: const Duration(milliseconds: 180),
                  child: Image.network(
                    photo.url,
                    headers: headers,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const _DailyImageFallback(dark: true),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
