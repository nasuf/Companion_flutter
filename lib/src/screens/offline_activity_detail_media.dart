part of 'package:companion_flutter/main.dart';

class _ActivityCompletionImage {
  const _ActivityCompletionImage({
    required this.localPath,
    required this.attachment,
  });

  final String localPath;
  final ChatAttachment attachment;
}

class _ActivityCompletionVoice {
  const _ActivityCompletionVoice({
    required this.localPath,
    required this.attachment,
    required this.durationSeconds,
  });

  final String localPath;
  final ChatAttachment attachment;
  final int durationSeconds;
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

String _formatActivityDuration(int? seconds) {
  final value = math.max(1, seconds ?? 1);
  final minutes = value ~/ 60;
  final rest = value % 60;
  if (minutes <= 0) return '$rest 秒';
  return '$minutes:${rest.toString().padLeft(2, '0')}';
}
