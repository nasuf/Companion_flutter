part of 'package:companion_flutter/main.dart';

/// Server-side thumbnail variant of a chat media URL (`?v=thumb`).
///
/// The server keeps a bubble-sized sibling for every chat image and falls back
/// to the original transparently (audio, media uploaded before thumbnails
/// existed), so this is always safe to request. Non-http(s) sources (local
/// files, data URIs) are returned untouched.
String chatMediaThumbUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty || !trimmed.startsWith('http')) return url;
  if (trimmed.contains('v=thumb')) return trimmed;
  return trimmed.contains('?') ? '$trimmed&v=thumb' : '$trimmed?v=thumb';
}

/// Chat media image with persistent disk caching.
///
/// Wraps [CachedNetworkImage] so every chat surface shares the same behavior:
/// - disk cache keyed by URL — images survive app restarts (media keys are
///   immutable uuids, the server marks them `Cache-Control: immutable`);
/// - authorized fetches (`/chat/media/**` requires a Bearer header);
/// - optional decode capping via [memCacheWidth] so bubble-sized renders do
///   not decode full-resolution bitmaps.
class ChatCachedImage extends StatelessWidget {
  const ChatCachedImage({
    super.key,
    required this.url,
    this.headers,
    this.width,
    this.height,
    this.fit,
    this.memCacheWidth,
    this.placeholder,
    this.error,
    this.alignment = Alignment.center,
  });

  final String url;
  final Map<String, String>? headers;
  final double? width;
  final double? height;
  final BoxFit? fit;

  /// Cap for the decoded bitmap width in physical pixels. Pass roughly
  /// `displayWidth * devicePixelRatio`; decoding is never upscaled.
  final int? memCacheWidth;
  final WidgetBuilder? placeholder;
  final WidgetBuilder? error;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: headers,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      memCacheWidth: memCacheWidth,
      fadeInDuration: const Duration(milliseconds: 120),
      fadeOutDuration: const Duration(milliseconds: 80),
      placeholder: placeholder == null
          ? null
          : (context, _) => placeholder!(context),
      errorWidget: error == null
          ? null
          : (context, _, __) => error!(context),
    );
  }
}

/// Seeds the shared disk cache with bytes we already have locally (used right
/// after uploading a chat image, so the just-sent picture never re-downloads).
Future<void> seedChatMediaCache(
  String url,
  Uint8List bytes, {
  String fileExtension = 'jpg',
}) async {
  try {
    await DefaultCacheManager().putFile(
      url,
      bytes,
      fileExtension: fileExtension,
    );
  } catch (error) {
    // Cache seeding is best-effort: on failure the image simply downloads
    // like any other.
    debugPrint('seedChatMediaCache failed: $error');
  }
}

/// Full-screen image viewer (WeChat-style "view original"):
///
/// - opens showing the (already disk-cached) thumbnail — never downloads the
///   original on its own;
/// - a bottom-left "查看原图" pill fetches the original with a live download
///   percentage while the thumbnail stays on screen;
/// - once the original is available (this tap, an earlier session, or the
///   upload cache-seed) it is shown directly and the pill never appears.
class _ImagePreviewOverlay extends StatefulWidget {
  const _ImagePreviewOverlay({this.localPath, this.url, this.headers});

  final String? localPath;
  final String? url;
  final Map<String, String>? headers;

  @override
  State<_ImagePreviewOverlay> createState() => _ImagePreviewOverlayState();
}

enum _OriginalState { checking, idle, downloading, ready }

class _ImagePreviewOverlayState extends State<_ImagePreviewOverlay> {
  _OriginalState _state = _OriginalState.checking;
  File? _originalFile;
  double? _progress;
  StreamSubscription<FileResponse>? _downloadSub;

  @override
  void initState() {
    super.initState();
    final url = widget.url;
    if (widget.localPath != null || url == null || url.isEmpty) {
      // Local file preview (composer attachments): nothing to download.
      _state = _OriginalState.ready;
      return;
    }
    unawaited(_checkCachedOriginal(url));
  }

  Future<void> _checkCachedOriginal(String url) async {
    File? cached;
    try {
      final info = await DefaultCacheManager().getFileFromCache(url);
      cached = info?.file;
    } catch (_) {
      cached = null;
    }
    if (!mounted) return;
    setState(() {
      _originalFile = cached;
      _state = cached != null ? _OriginalState.ready : _OriginalState.idle;
    });
  }

  void _loadOriginal() {
    final url = widget.url;
    if (url == null || _state == _OriginalState.downloading) return;
    setState(() {
      _state = _OriginalState.downloading;
      _progress = null;
    });
    _downloadSub = DefaultCacheManager()
        .getFileStream(url, headers: widget.headers, withProgress: true)
        .listen(
          (event) {
            if (!mounted) return;
            if (event is DownloadProgress) {
              setState(() => _progress = event.progress);
            } else if (event is FileInfo) {
              setState(() {
                _originalFile = event.file;
                _state = _OriginalState.ready;
              });
            }
          },
          onError: (Object error) {
            debugPrint('load original failed: $error');
            if (!mounted) return;
            // Back to the idle pill so the user can retry.
            setState(() => _state = _OriginalState.idle);
          },
          cancelOnError: true,
        );
  }

  @override
  void dispose() {
    _downloadSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localPath = widget.localPath;
    final url = widget.url ?? '';
    final Widget image;
    if (localPath != null) {
      image = Image.file(File(localPath), fit: BoxFit.contain);
    } else if (_originalFile != null) {
      // gaplessPlayback keeps the decoded thumbnail on screen for the single
      // frame the original spends decoding — no white flash on swap.
      image = Image.file(
        _originalFile!,
        fit: BoxFit.contain,
        gaplessPlayback: true,
      );
    } else {
      image = ChatCachedImage(
        url: chatMediaThumbUrl(url),
        headers: widget.headers,
        fit: BoxFit.contain,
      );
    }
    final showPill =
        localPath == null &&
        (_state == _OriginalState.idle || _state == _OriginalState.downloading);
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: InteractiveViewer(
                  minScale: 0.7,
                  maxScale: 4,
                  child: Center(child: image),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: _RoundIconButton(
                tooltip: '关闭',
                icon: CupertinoIcons.xmark,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            if (showPill)
              Positioned(
                left: 16,
                bottom: 24,
                child: _ViewOriginalPill(
                  downloading: _state == _OriginalState.downloading,
                  progress: _progress,
                  onTap: _loadOriginal,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bottom-left "查看原图" pill; flips to a percentage spinner while the
/// original downloads (thumbnail stays visible behind it).
class _ViewOriginalPill extends StatelessWidget {
  const _ViewOriginalPill({
    required this.downloading,
    required this.progress,
    required this.onTap,
  });

  final bool downloading;
  final double? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final percentText = progress == null
        ? '加载中'
        : '${(progress!.clamp(0.0, 1.0) * 100).round()}%';
    return GestureDetector(
      onTap: downloading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        ),
        child: downloading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: progress,
                      color: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    percentText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : const Text(
                '查看原图',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
