import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/widgets.dart';

import 'emoji_assets.dart';

/// Replaces emoji graphemes with the same bundled glyphs used by the picker.
class EmojiTextSpanBuilder extends SpecialTextSpanBuilder {
  EmojiTextSpanBuilder({this.emojiSize});

  final double? emojiSize;

  @override
  SpecialText? createSpecialText(
    String flag, {
    TextStyle? textStyle,
    SpecialTextGestureTapCallback? onTap,
    required int index,
  }) {
    return null;
  }

  @override
  TextSpan build(
    String data, {
    TextStyle? textStyle,
    SpecialTextGestureTapCallback? onTap,
  }) {
    if (data.isEmpty) {
      return TextSpan(text: '', style: textStyle);
    }

    final children = <InlineSpan>[];
    final buffer = StringBuffer();
    var start = 0;
    final size = emojiSize ?? ((textStyle?.fontSize ?? 16) * 1.15);

    void flush() {
      if (buffer.isEmpty) return;
      children.add(TextSpan(text: buffer.toString(), style: textStyle));
      buffer.clear();
    }

    for (final grapheme in data.characters) {
      final path = emojiAssetPath(grapheme);
      if (path == null) {
        buffer.write(grapheme);
        start += grapheme.length;
        continue;
      }
      flush();
      children.add(
        ImageSpan(
          AssetImage(path),
          imageWidth: size,
          imageHeight: size,
          actualText: grapheme,
          start: start,
          alignment: PlaceholderAlignment.middle,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
        ),
      );
      start += grapheme.length;
    }
    flush();
    return TextSpan(style: textStyle, children: children);
  }
}
