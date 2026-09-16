import 'package:companion_flutter/src/emoji/emoji_assets.dart';
import 'package:companion_flutter/src/emoji/emoji_catalog.dart';
import 'package:companion_flutter/src/emoji/emoji_spans.dart';
import 'package:companion_flutter/src/emoji/emoji_text_span_builder.dart';
import 'package:companion_flutter/src/emoji/unified_emoji.dart';
import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps unicode emoji to the same glyph file on every platform', () {
    expect(emojiCode('😊'), '1f60a');
    expect(emojiCode('❤️'), '2764');
    expect(emojiCode('☀️'), '2600');
    expect(emojiCode('😵‍💫'), '1f635-200d-1f4ab');
    expect(emojiAssetPath('😊'), 'assets/emoji/glyphs/1f60a.webp');
    expect(emojiAssetPath('❤️'), 'assets/emoji/glyphs/2764.webp');
    expect(
      emojiAssetPath('😵‍💫'),
      'assets/emoji/glyphs/1f635-200d-1f4ab.webp',
    );
  });

  test('every catalog glyph has a bundled asset', () {
    final missing = [
      for (final emoji in kChatEmojiCatalog)
        if (emojiAssetPath(emoji) == null) emoji,
    ];
    expect(missing, isEmpty);
  });

  test(
    'emojiAwareSpans keeps surrounding text and swaps glyphs for images',
    () {
      const style = TextStyle(fontSize: 14);
      final spans = emojiAwareSpans(text: '今天😊好', baseStyle: style);
      expect(spans, hasLength(3));
      expect(spans[0], isA<TextSpan>());
      expect((spans[0] as TextSpan).text, '今天');
      expect(spans[1], isA<WidgetSpan>());
      expect(spans[2], isA<TextSpan>());
      expect((spans[2] as TextSpan).text, '好');
    },
  );

  test('plain text without emoji stays a single span', () {
    const style = TextStyle(fontSize: 14);
    final spans = emojiAwareSpans(text: '你好', baseStyle: style);
    expect(spans, [const TextSpan(text: '你好', style: style)]);
  });

  test(
    'EmojiTextSpanBuilder uses ImageSpan so the composer matches the panel',
    () {
      final span = EmojiTextSpanBuilder(
        emojiSize: 18,
      ).build('今天😊好', textStyle: const TextStyle(fontSize: 15));
      expect(span.children, hasLength(3));
      expect(span.children![0], isA<TextSpan>());
      expect((span.children![0] as TextSpan).text, '今天');
      expect(span.children![1], isA<ImageSpan>());
      expect((span.children![1] as ImageSpan).actualText, '😊');
      expect(span.children![2], isA<TextSpan>());
      expect((span.children![2] as TextSpan).text, '好');
    },
  );

  testWidgets('UnifiedEmoji loads the bundled glyph image', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: UnifiedEmoji('😊', size: 30),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
  });
}
