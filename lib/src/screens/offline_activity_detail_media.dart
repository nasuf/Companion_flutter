part of 'package:companion_flutter/main.dart';

class _ActivityCompletionImage {
  const _ActivityCompletionImage({
    required this.localPath,
    required this.attachment,
  });

  final String localPath;
  final ChatAttachment attachment;
}

Future<Size> _decodeActivityImageDimensions(Uint8List bytes) async {
  final codec = await instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  return Size(image.width.toDouble(), image.height.toDouble());
}

String _activityMimeFromPath(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}
