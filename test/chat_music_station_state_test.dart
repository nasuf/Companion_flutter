import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:flutter_test/flutter_test.dart';

const _track = MusicTrack(
  id: 'track-1',
  title: 'Quiet Realm',
  artist: 'Artist',
  album: 'Album',
  library: 'focus',
  url: '',
  durationSec: 180,
  coverKey: 'music-cover-01.jpg',
  accentA: '#1f6fff',
  accentB: '#18c6c0',
  source: 'jamendo',
  isFavorite: false,
  playedByAgent: true,
);

ChatMessage _statusMessage(String status, String actor, int second) {
  return ChatMessage(
    id: '$status-$actor-$second',
    conversationId: 'conv-1',
    role: 'assistant',
    content: '',
    createdAt: DateTime(2026, 7, 11, 12, 0, second),
    metadata: {'music_status': status, 'music_status_actor': actor},
  );
}

MusicCoListening _session(String initiatedBy, {String status = 'active'}) {
  return MusicCoListening(
    status: status,
    track: _track,
    positionSeconds: 0,
    isPlaying: false,
    initiatedBy: initiatedBy,
  );
}

void main() {
  test('agent join alone does not mark the user as co-listening', () {
    final active = ChatMusicStationState.userCoListeningActiveFromMessages([
      _statusMessage('started', 'agent', 1),
    ]);

    expect(active, isFalse);
  });

  test('only user join starts membership and any exit ends it', () {
    final joined = ChatMusicStationState.userCoListeningActiveFromMessages([
      _statusMessage('started', 'user', 1),
      _statusMessage('started', 'agent', 2),
    ]);
    final ended = ChatMusicStationState.userCoListeningActiveFromMessages([
      _statusMessage('started', 'user', 1),
      _statusMessage('ended', 'agent', 2),
    ]);

    expect(joined, isTrue);
    expect(ended, isFalse);
  });

  test('agent-only sessions are not treated as user membership', () {
    expect(
      ChatMusicStationState.activeSessionIncludesUser(_session('agent')),
      isFalse,
    );
    expect(
      ChatMusicStationState.activeSessionIncludesUser(_session('agent_auto')),
      isFalse,
    );
    expect(
      ChatMusicStationState.activeSessionIncludesUser(_session('user_joined')),
      isTrue,
    );
    expect(
      ChatMusicStationState.activeSessionIncludesUser(
        _session('user_joined', status: 'ended'),
      ),
      isFalse,
    );
  });
}
