import 'package:flutter/widgets.dart';

import 'emoji_assets.dart';
import 'unified_emoji.dart';

List<InlineSpan> emojiAwareSpans({
  required String text,
  required TextStyle baseStyle,
  List<InlineSpan> Function(String text)? wrapPlainText,
  double emojiSize = 18,
}) {
  final spans = <InlineSpan>[];
  final buffer = StringBuffer();

  void flush() {
    if (buffer.isEmpty) return;
    final chunk = buffer.toString();
    buffer.clear();
    if (wrapPlainText != null) {
      spans.addAll(wrapPlainText(chunk));
    } else {
      spans.add(TextSpan(text: chunk, style: baseStyle));
    }
  }

  for (final grapheme in text.characters) {
    if (emojiAssetPath(grapheme) == null) {
      buffer.write(grapheme);
      continue;
    }
    flush();
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0.5),
          child: UnifiedEmoji(grapheme, size: emojiSize),
        ),
      ),
    );
  }
  flush();
  return spans;
}
