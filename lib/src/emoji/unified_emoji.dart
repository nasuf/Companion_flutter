import 'package:flutter/widgets.dart';

import 'emoji_assets.dart';

/// Same bundled glyph on iOS and Android. Falls back to the platform font
/// only when the sequence is missing from the pack.
class UnifiedEmoji extends StatelessWidget {
  const UnifiedEmoji(this.emoji, {super.key, this.size = 24});

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = emojiAssetPath(emoji);
    if (path == null) {
      return Text(
        emoji,
        style: TextStyle(fontSize: size * 0.86, height: 1),
        textAlign: TextAlign.center,
      );
    }
    return Image.asset(
      path,
      width: size,
      height: size,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => Text(
        emoji,
        style: TextStyle(fontSize: size * 0.86, height: 1),
        textAlign: TextAlign.center,
      ),
    );
  }
}
