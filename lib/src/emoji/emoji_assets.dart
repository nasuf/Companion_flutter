import 'emoji_assets.g.dart';

const kEmojiAssetPrefix = 'assets/emoji/glyphs/';

/// File stem for a single emoji grapheme.
///
/// Matches twemoji.js: strip U+FE0F unless the sequence contains ZWJ.
/// Fluent Emoji's flattened pack uses the same hex naming.
String emojiCode(String emoji) {
  final runes = emoji.runes.toList();
  final hasZwj = runes.contains(0x200D);
  final codes = <String>[];
  for (final rune in runes) {
    if (!hasZwj && rune == 0xFE0F) continue;
    codes.add(rune.toRadixString(16));
  }
  return codes.join('-');
}

Iterable<String> emojiCodeCandidates(String emoji) sync* {
  final runes = emoji.runes.toList();
  String join(Iterable<int> values) =>
      values.map((value) => value.toRadixString(16)).join('-');
  final hasZwj = runes.contains(0x200D);
  if (hasZwj) {
    yield join(runes);
    yield join(runes.where((rune) => rune != 0xFE0F));
  } else {
    yield join(runes.where((rune) => rune != 0xFE0F));
    yield join(runes);
  }
}

String? emojiAssetPath(String emoji) {
  for (final code in emojiCodeCandidates(emoji)) {
    if (kEmojiAssetNames.contains(code)) {
      return '$kEmojiAssetPrefix$code.webp';
    }
  }
  return null;
}
