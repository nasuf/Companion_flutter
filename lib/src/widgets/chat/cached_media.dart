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
