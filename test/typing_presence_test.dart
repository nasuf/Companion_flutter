import 'package:companion_flutter/src/chat/typing_presence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('editing expires even when a nonempty draft remains', (
    tester,
  ) async {
    final events = <bool>[];
    final local = LocalChatTyping(
      onSend: (active, _, __) => events.add(active),
    );
    local.textChanged('private draft');
    expect(events, [true]);
    await tester.pump(const Duration(seconds: 3));
    expect(events, [true, true]);
    await tester.pump(const Duration(seconds: 1));
    expect(events.last, false);
    final count = events.length;
    await tester.pump(const Duration(seconds: 12));
    expect(events.length, count);
    local.dispose();
  });

  testWidgets('continued editing renews activity and clear stops immediately', (
    tester,
  ) async {
    final events = <bool>[];
    final local = LocalChatTyping(
      onSend: (active, _, __) => events.add(active),
    );
    local.textChanged('a');
    await tester.pump(const Duration(seconds: 3));
    local.textChanged('ab');
    await tester.pump(const Duration(seconds: 2));
    expect(events.last, true);
    local.textChanged('');
    expect(events.last, false);
    local.dispose();
  });

  testWidgets(
    'voice refreshes while active; background never revives a draft',
    (tester) async {
      final events = <bool>[];
      final local = LocalChatTyping(
        onSend: (active, _, __) => events.add(active),
      );
      local.voiceChanged(true);
      await tester.pump(const Duration(seconds: 10));
      expect(events.every((value) => value), true);
      local.setVisible(false);
      expect(events.last, false);
      final count = events.length;
      local.textChanged('hidden draft');
      local.setVisible(true);
      await tester.pump(const Duration(seconds: 10));
      expect(events.length, count);
      local.dispose();
    },
  );

  testWidgets(
    'stop/dispose are idempotent and revisions increase within a session',
    (tester) async {
      final events = <(bool, int, String)>[];
      final local = LocalChatTyping(
        onSend: (active, revision, session) =>
            events.add((active, revision, session)),
      );
      local.textChanged('a');
      local.stop();
      local.stop();
      local.textChanged('b');
      local.dispose();
      expect(events.map((e) => e.$1), [true, false, true, false]);
      expect(events.map((e) => e.$2), [1, 2, 3, 4]);
      expect(events.map((e) => e.$3).toSet(), {local.sessionId});
    },
  );

  testWidgets(
    'remote ordering rejects late starts, expires lost stops and accepts a new epoch',
    (tester) async {
      final events = <bool>[];
      final remote = RemoteChatTyping(onChanged: events.add);
      remote.apply({'active': true, 'revision': 10});
      remote.apply({'active': false, 'revision': 12});
      remote.apply({'active': true, 'revision': 11});
      expect(events, [true, false]);
      remote.apply({'active': true, 'revision': 13});
      await tester.pump(const Duration(seconds: 8));
      expect(events, [true, false, true, false]);
      remote.apply({'active': true, 'revision': 1});
      expect(events.last, true);
      remote.clear();
      expect(events.last, false);
      remote.dispose();
    },
  );
}
