import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('MessageSearchHit.fromJson', () {
    test('wraps a real ChatMessage and reads the extra search fields', () {
      final hit = MessageSearchHit.fromJson({
        'id': 'm1',
        'conversation_id': 'c1',
        'role': 'user',
        'content': '今天天气真好',
        'metadata': null,
        'created_at': '2026-08-01T00:00:00+00:00',
        'match_type': 'text',
        'rank': 7,
        'matched_attachment_id': null,
      });

      expect(hit.message.id, 'm1');
      expect(hit.message.content, '今天天气真好');
      expect(hit.message.isMine, isTrue);
      expect(hit.matchType, 'text');
      expect(hit.rank, 7);
      expect(hit.matchedAttachmentId, isNull);
    });

    test('carries the matched attachment id for image hits', () {
      final hit = MessageSearchHit.fromJson({
        'id': 'm2',
        'conversation_id': 'c1',
        'role': 'assistant',
        'content': '',
        'metadata': {
          'attachments': [
            {
              'id': 'att1',
              'kind': 'image',
              'mime': 'image/jpeg',
              'size': 100,
              'url': 'https://cdn.example.com/a.jpg',
              'vision_summary': '一只猫',
            },
          ],
        },
        'created_at': '2026-08-01T00:00:00+00:00',
        'match_type': 'image',
        'rank': 0,
        'matched_attachment_id': 'att1',
      });

      expect(hit.matchType, 'image');
      expect(hit.matchedAttachmentId, 'att1');
      expect(hit.message.attachments.single.visionSummary, '一只猫');
    });
  });

  group('MessageSearchResult.fromJson', () {
    test('parses each section and has_more flag independently', () {
      final result = MessageSearchResult.fromJson({
        'text': [
          {
            'id': 't1',
            'conversation_id': 'c1',
            'role': 'user',
            'content': 'hi',
            'match_type': 'text',
            'rank': 0,
          },
        ],
        'cards': [],
        'images': [],
        'has_more_text': true,
        'has_more_cards': false,
        'has_more_images': false,
      });

      expect(result.text, hasLength(1));
      expect(result.cards, isEmpty);
      expect(result.images, isEmpty);
      expect(result.hasMoreText, isTrue);
      expect(result.hasMoreCards, isFalse);
    });

    test('missing sections default to empty, not a throw', () {
      final result = MessageSearchResult.fromJson({});
      expect(result.text, isEmpty);
      expect(result.cards, isEmpty);
      expect(result.images, isEmpty);
      expect(result.hasMoreText, isFalse);
    });
  });

  group('ChatSearchHistoryStore', () {
    test('add is most-recent-first and deduplicates', () async {
      final store = ChatSearchHistoryStore();
      await store.add('conv-1', '猫');
      await store.add('conv-1', '狗');
      final updated = await store.add('conv-1', '猫');

      expect(updated, ['猫', '狗']);
    });

    test('caps history at 12 entries', () async {
      final store = ChatSearchHistoryStore();
      List<String> latest = const [];
      for (var i = 0; i < 15; i++) {
        latest = await store.add('conv-1', 'term-$i');
      }
      expect(latest, hasLength(12));
      expect(latest.first, 'term-14');
    });

    test('history is isolated per conversation', () async {
      final store = ChatSearchHistoryStore();
      await store.add('conv-1', 'a');
      await store.add('conv-2', 'b');

      expect(await store.load('conv-1'), ['a']);
      expect(await store.load('conv-2'), ['b']);
    });

    test('clear removes all entries for that conversation', () async {
      final store = ChatSearchHistoryStore();
      await store.add('conv-1', 'a');
      await store.clear('conv-1');

      expect(await store.load('conv-1'), isEmpty);
    });
  });

  group('groupHitsByMonth', () {
    MessageSearchHit hitAt(String id, DateTime createdAt) {
      return MessageSearchHit(
        message: ChatMessage(
          id: id,
          conversationId: 'c1',
          role: 'user',
          content: id,
          createdAt: createdAt,
        ),
        matchType: 'text',
        rank: 0,
      );
    }

    test('splits into one group per month, no zero-padding', () {
      final hits = [
        hitAt('a', DateTime(2026, 8, 20)),
        hitAt('b', DateTime(2026, 8, 5)),
        hitAt('c', DateTime(2023, 4, 8)),
      ];

      final groups = groupHitsByMonth(hits);

      expect(groups.map((g) => g.label), ['2026-8', '2023-4']);
      expect(groups[0].hits.map((h) => h.message.id), ['a', 'b']);
      expect(groups[1].hits.map((h) => h.message.id), ['c']);
    });

    test('re-entering the same month later starts a new group', () {
      // Input is assumed newest-first; a month reappearing non-consecutively
      // (shouldn't happen with real server ordering, but the function must
      // not silently merge it back into an earlier group of the same label).
      final hits = [
        hitAt('a', DateTime(2026, 8, 20)),
        hitAt('b', DateTime(2023, 4, 8)),
        hitAt('c', DateTime(2026, 8, 1)),
      ];

      final groups = groupHitsByMonth(hits);

      expect(groups.map((g) => g.label), ['2026-8', '2023-4', '2026-8']);
    });

    test('empty input yields no groups', () {
      expect(groupHitsByMonth(const []), isEmpty);
    });

    test('groups by local calendar month, not the raw UTC one', () {
      // Late-in-the-UTC-day timestamps land on the *next* local calendar
      // date for any timezone ahead of UTC — grouping by the raw .month
      // (no .toLocal()) silently misfiled early-local-morning messages into
      // the previous month. Deriving "expected" the same way keeps this
      // assertion meaningful regardless of the machine's own timezone,
      // while still catching a regression to the un-converted field.
      final utcTime = DateTime.utc(2026, 7, 31, 20, 0);
      final hit = hitAt('a', utcTime);

      final groups = groupHitsByMonth([hit]);

      final expectedLocal = utcTime.toLocal();
      expect(groups.single.label, '${expectedLocal.year}-${expectedLocal.month}');
    });
  });

  group('highlightedSpans', () {
    const base = TextStyle(color: Color(0xFF000000));
    const highlight = TextStyle(color: Color(0xFF0A84FF));

    test('colors every case-insensitive occurrence of the query', () {
      final spans = highlightedSpans(
        text: '今天天气真好，今天心情也好',
        query: '今天',
        baseStyle: base,
        highlightStyle: highlight,
      );

      expect(spans.map((s) => s.text), [
        '今天',
        '天气真好，',
        '今天',
        '心情也好',
      ]);
      expect(spans[0].style, highlight);
      expect(spans[1].style, base);
      expect(spans[2].style, highlight);
      expect(spans[3].style, base);
    });

    test('matches regardless of case', () {
      final spans = highlightedSpans(
        text: 'Hello World',
        query: 'world',
        baseStyle: base,
        highlightStyle: highlight,
      );

      expect(spans.map((s) => s.text), ['Hello ', 'World']);
      expect(spans.last.style, highlight);
    });

    test('empty query returns the text unhighlighted, not empty', () {
      final spans = highlightedSpans(
        text: 'hello',
        query: '  ',
        baseStyle: base,
        highlightStyle: highlight,
      );

      expect(spans, [const TextSpan(text: 'hello', style: base)]);
    });

    test('no match returns the whole text as one plain span', () {
      final spans = highlightedSpans(
        text: 'hello',
        query: 'xyz',
        baseStyle: base,
        highlightStyle: highlight,
      );

      expect(spans, [const TextSpan(text: 'hello', style: base)]);
    });
  });
}
