import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

class AgentAvatarImage extends StatelessWidget {
  const AgentAvatarImage({
    super.key,
    required this.imageUrl,
    required this.fallback,
    this.width,
    this.height,
    this.fit,
  });

  static const _precacheTimeout = Duration(seconds: 8);

  final String? imageUrl;
  final Widget fallback;
  final double? width;
  final double? height;
  final BoxFit? fit;

  static CachedNetworkImageProvider? providerFor(String? imageUrl) {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) return null;
    return CachedNetworkImageProvider(url);
  }

  static Future<void> precache(BuildContext context, String? imageUrl) async {
    final provider = providerFor(imageUrl);
    if (provider == null) return;
    await precacheImage(provider, context).timeout(_precacheTimeout);
  }

  @override
  Widget build(BuildContext context) {
    final provider = providerFor(imageUrl);
    if (provider == null) return fallback;
    return Image(
      key: ValueKey(provider.url),
      image: provider,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => fallback,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return fallback;
      },
    );
  }
}
