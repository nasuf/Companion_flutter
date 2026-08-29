import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
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
}
