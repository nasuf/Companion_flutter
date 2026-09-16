import 'package:companion_flutter/models.dart';
import 'package:companion_flutter/src/chat/music_activity_logic.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _musicStatusMessage({
  required String id,
  required DateTime createdAt,
  required String status,
  String actor = 'user',
  String trackTitle = 'Quiet Realm',
  String trackId = 'track-1',
}) {
  return ChatMessage(
    id: id,
    conversationId: 'conversation-1',
    role: 'assistant',
    content: 'status',
    createdAt: createdAt,
    metadata: {
      'music_status': status,
      'music_track_title': trackTitle,
      'music_track_id': trackId,
      'music_status_actor': actor,
      'music_status_actor_name': actor == 'agent' ? '小芜' : '',
    },
    read: true,
  );
}

void main() {
  test('hides legacy user join and exit without agent join', () {
    final base = DateTime(2026, 9, 16, 14, 42);
    final messages = [
      _musicStatusMessage(id: 'm1', createdAt: base, status: 'started'),
      _musicStatusMessage(
        id: 'm2',
        createdAt: base.add(const Duration(seconds: 20)),
        status: 'ended',
      ),
    ];

    final processed = preprocessMusicActivityMessages(messages);

    expect(processed.$1, isEmpty);
    expect(processed.$2, {'m1', 'm2'});
  });

  test('collapses meaningful co-listening into one quiet digest', () {
    final base = DateTime(2026, 9, 16, 14, 42);
    final messages = [
      _musicStatusMessage(
        id: 'm1',
        createdAt: base,
        status: 'started',
        actor: 'agent',
      ),
      _musicStatusMessage(
        id: 'm2',
        createdAt: base.add(const Duration(minutes: 1)),
        status: 'ended',
        actor: 'user',
      ),
    ];

    final processed = preprocessMusicActivityMessages(messages);

    expect(processed.$1.length, 1);
    expect(processed.$1.first.content, '一起听了《Quiet Realm》');
    expect(processed.$2, {'m1'});
  });

  test('collapses multiple tracks within five minutes', () {
    final base = DateTime(2026, 8, 9, 10, 10);
    final messages = <ChatMessage>[
      _musicStatusMessage(
        id: 'a1',
        createdAt: base,
        status: 'started',
        actor: 'agent',
        trackTitle: 'Song A',
        trackId: 'track-a',
      ),
      _musicStatusMessage(
        id: 'a2',
        createdAt: base.add(const Duration(minutes: 1)),
        status: 'ended',
        actor: 'user',
        trackTitle: 'Song A',
        trackId: 'track-a',
      ),
      _musicStatusMessage(
        id: 'b1',
        createdAt: base.add(const Duration(minutes: 2)),
        status: 'started',
        actor: 'agent',
        trackTitle: 'Song B',
        trackId: 'track-b',
      ),
      _musicStatusMessage(
        id: 'b2',
        createdAt: base.add(const Duration(minutes: 3)),
        status: 'ended',
        actor: 'user',
        trackTitle: 'Song B',
        trackId: 'track-b',
      ),
    ];

    final processed = preprocessMusicActivityMessages(messages);

    expect(processed.$1.length, 1);
    expect(processed.$1.first.content, '一起听了 2 首歌');
  });
}
