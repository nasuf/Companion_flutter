import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:companion_flutter/src/chat/music_activity_logic.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _base = DateTime(2026, 10, 1, 21, 40);

ChatMessage _status(String id, String status, String actor, int minute) {
  return ChatMessage(
    id: id,
    conversationId: 'conv-1',
    role: 'assistant',
    content: 'status',
    createdAt: _base.add(Duration(minutes: minute)),
    metadata: {
      'music_status': status,
      'music_track_title': 'Quiet Realm',
      'music_track_id': 'track-1',
      'music_status_actor': actor,
    },
    read: true,
  );
}

MusicActivitySegment _segment(
  String action,
  String actor,
  int minute, {
  bool shared = false,
  String trackId = 'track-1',
  String title = 'Quiet Realm',
}) {
  return MusicActivitySegment(
    at: _base.add(Duration(minutes: minute)),
    action: action,
    actor: actor,
    sessionId: 'conv-1',
    trackId: trackId,
    trackTitle: title,
    shared: shared,
  );
}

ChatMessage _burst(String id, List<MusicActivitySegment> segments) {
  return ChatMessage(
    id: id,
    conversationId: 'conv-1',
    role: 'assistant',
    content: '一起听了《Quiet Realm》',
    createdAt: segments.first.at,
    metadata: {
      'kind': 'music_activity_burst',
      'segments': [for (final segment in segments) segment.toJson()],
    },
    read: true,
  );
}

void main() {
  test('user joins and leaves without agent: no shared status', () {
    final processed = preprocessMusicActivityMessages([
      _status('user-join', 'started', 'user', 0),
      _status('user-exit', 'ended', 'user', 1),
    ]);
    expect(processed.$1, isEmpty);
    expect(processed.$2, {'user-join', 'user-exit'});
  });

  test(
    'shared join is visible immediately, including a single legacy join',
    () {
      final processed = preprocessMusicActivityMessages([
        _status('user-join', 'started', 'user', 0),
        _status('agent-join', 'started', 'agent', 1),
      ]);
      expect(processed.$1.map((m) => m.content), ['你们一起在听《Quiet Realm》']);
      expect(processed.$1.single.id, 'agent-join');
      expect(processed.$2, {'user-join'});
      expect(
        musicActivityTimelineLabel(processed.$1.single),
        '你们一起在听《Quiet Realm》',
      );
    },
  );

  test('a user exit while the agent waits does not show a shared exit', () {
    final processed = preprocessMusicActivityMessages([
      _burst('old-burst', [
        _segment('joined', 'agent', 0),
        _segment('listened', 'user', 1),
      ]),
    ]);
    expect(processed.$1.map((m) => m.content), ['你们一起在听《Quiet Realm》']);
  });

  test('two old participant exits become one joint exit, without a count', () {
    final processed = preprocessMusicActivityMessages([
      _burst('old-burst', [
        _segment('joined', 'agent', 0),
        _segment('listened', 'user', 1),
        _segment('listened', 'agent', 2),
        _segment('listened', 'agent', 2),
      ]),
    ]);
    expect(processed.$1.map((m) => m.content), [
      '你们一起在听《Quiet Realm》',
      '你们已退出共听《Quiet Realm》',
    ]);
    expect(processed.$1.last.id, 'old-burst');
    expect(processed.$1.last.createdAt, _base.add(const Duration(minutes: 2)));
  });

  test(
    'participant events separated by normal replies still form joint states',
    () {
      final reply = ChatMessage(
        id: 'reply',
        conversationId: 'conv-1',
        role: 'assistant',
        content: '下次再一起听',
        createdAt: _base.add(const Duration(seconds: 90)),
      );
      final processed = preprocessMusicActivityMessages([
        _status('agent-join', 'started', 'agent', 0),
        _status('user-exit', 'ended', 'user', 1),
        reply,
        _status('agent-exit', 'ended', 'agent', 2),
      ]);
      expect(processed.$1.map((m) => m.content), [
        '你们一起在听《Quiet Realm》',
        '下次再一起听',
        '你们已退出共听《Quiet Realm》',
      ]);
      expect(processed.$2, {'user-exit'});
    },
  );

  test(
    'new confirmed exit remains visible when the join is outside loaded history',
    () {
      final message = _burst('new-exit', [
        _segment('exited', 'user', 2, shared: true),
      ]);
      final processed = preprocessMusicActivityMessages([message]);
      expect(processed.$1.single.content, '你们已退出共听《Quiet Realm》');
      expect(processed.$1.single.id, 'new-exit');
      expect(
        musicActivityTimelineLabel(processed.$1.single),
        '你们已退出共听《Quiet Realm》',
      );
    },
  );

  test('user rejoining an agent also confirms a shared start', () {
    final processed = preprocessMusicActivityMessages([
      _burst('resume', [_segment('joined', 'user', 1, shared: true)]),
    ]);
    expect(processed.$1.single.content, '你们一起在听《Quiet Realm》');
  });

  test(
    'quick repeated sessions and different tracks remain separate statuses',
    () {
      final messages = [
        _burst('start-1', [_segment('joined', 'agent', 0, shared: true)]),
        _burst('end-1', [_segment('exited', 'agent', 1, shared: true)]),
        _burst('start-2', [
          _segment(
            'joined',
            'agent',
            2,
            shared: true,
            trackId: 'track-2',
            title: 'Song B',
          ),
        ]),
        _burst('end-2', [
          _segment(
            'exited',
            'agent',
            3,
            shared: true,
            trackId: 'track-2',
            title: 'Song B',
          ),
        ]),
      ];
      final processed = preprocessMusicActivityMessages(messages);
      expect(processed.$1.map((m) => m.content), [
        '你们一起在听《Quiet Realm》',
        '你们已退出共听《Quiet Realm》',
        '你们一起在听《Song B》',
        '你们已退出共听《Song B》',
      ]);
      expect(processed.$1.map((m) => m.id), messages.map((m) => m.id));
    },
  );

  test(
    'old digest statuses use event times instead of the burst creation time',
    () {
      final reply = ChatMessage(
        id: 'reply',
        conversationId: 'conv-1',
        role: 'assistant',
        content: '中间的回复',
        createdAt: _base.add(const Duration(seconds: 90)),
      );
      final processed = preprocessMusicActivityMessages([
        _burst('old-burst', [
          _segment('joined', 'agent', 0),
          _segment('listened', 'agent', 2),
        ]),
        reply,
      ]);
      expect(processed.$1.map((m) => m.content), [
        '你们一起在听《Quiet Realm》',
        '中间的回复',
        '你们已退出共听《Quiet Realm》',
      ]);
    },
  );

  test('unproven old exits and malformed metadata stay hidden', () {
    final processed = preprocessMusicActivityMessages([
      _status('unproven-exit', 'ended', 'agent', 0),
      ChatMessage(
        id: 'empty',
        conversationId: 'conv-1',
        role: 'assistant',
        content: '',
        createdAt: _base,
        metadata: {'kind': 'music_activity_burst', 'segments': []},
      ),
    ]);
    expect(processed.$1, isEmpty);
    expect(processed.$2, {'unproven-exit', 'empty'});
  });

  test('duplicate confirmed transitions do not add duplicate status rows', () {
    final processed = preprocessMusicActivityMessages([
      _burst('start-1', [_segment('joined', 'agent', 0, shared: true)]),
      _burst('start-duplicate', [_segment('joined', 'agent', 1, shared: true)]),
      _burst('end-1', [_segment('exited', 'agent', 2, shared: true)]),
      _burst('end-duplicate', [_segment('exited', 'agent', 3, shared: true)]),
      _burst('start-2', [_segment('joined', 'user', 4, shared: true)]),
    ]);
    expect(processed.$1.map((m) => m.content), [
      '你们一起在听《Quiet Realm》',
      '你们已退出共听《Quiet Realm》',
      '你们一起在听《Quiet Realm》',
    ]);
    expect(processed.$2, {'start-duplicate', 'end-duplicate'});
  });

  testWidgets(
    'shared status wraps long titles and has no detail dialog or chevron',
    (tester) async {
      const title = 'When Waves Trying to Catch a Marvel';
      final message = _burst('shared', [
        _segment('joined', 'agent', 0, shared: true, title: title),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 260,
              child: MusicActivityBurstRow(message: message),
            ),
          ),
        ),
      );
      final row = find.byType(MusicActivityBurstRow);
      expect(find.text('你们一起在听《$title》'), findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.byType(InkWell)),
        findsNothing,
      );
      expect(
        find.descendant(of: row, matching: find.byType(GestureDetector)),
        findsNothing,
      );
      expect(find.byIcon(CupertinoIcons.chevron_right), findsNothing);
      await tester.tap(find.text('你们一起在听《$title》'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.textContaining('次'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
