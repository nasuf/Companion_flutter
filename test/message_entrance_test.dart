import 'package:companion_flutter/models.dart';
import 'package:companion_flutter/src/screens/chat/chat_transcript_controller.dart';
import 'package:companion_flutter/src/widgets/chat/message_entrance.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';

ChatMessage _message(String id, {String? clientId}) => ChatMessage(
  id: id,
  conversationId: 'conv',
  role: 'assistant',
  content: id,
  createdAt: DateTime.utc(2026, 10, 20),
  metadata: clientId == null ? null : {'client_id': clientId},
);

void main() {
  test('history, replay and acknowledgements never create a second entrance', () {
    final transcript = ChatTranscriptController()..loadingInitial = false;
    addTearDown(transcript.dispose);
    transcript.messages.add(_message('history'));
    transcript.publish();
    expect(transcript.takeEnteringKeys(), isEmpty);
    expect(
      ChatTranscriptController.rowIdentity(_message('no-client', clientId: '')),
      'no-client',
    );
    transcript.messages.add(_message('draft', clientId: 'client'));
    transcript.publish(animateInsertions: true);
    // An immediate ack before the view builds must retain the pending entrance.
    transcript.messages[1] = _message('server', clientId: 'client');
    transcript.publish();
    expect(transcript.takeEnteringKeys(), {'client'});
    transcript.publish(animateInsertions: true);
    expect(transcript.takeEnteringKeys(), isEmpty);
    transcript.messages.add(_message('replayed'));
    transcript.publish();
    expect(transcript.takeEnteringKeys(), isEmpty);
    transcript.messages.addAll([_message('next1'), _message('next2')]);
    transcript.publish(animateInsertions: true);
    expect(transcript.takeEnteringKeys(), {'next1', 'next2'});
    transcript.resetForConversationSwitch();
    transcript.messages.add(_message('other-conversation'));
    transcript.publish(animateInsertions: true);
    expect(transcript.takeEnteringKeys(), isEmpty);
  });

  Widget harness(Widget child, {bool reduceMotion = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Align(alignment: Alignment.bottomCenter, child: child),
    ),
  );

  testWidgets(
    'full bubbles move with history without a local wipe, fade or scale',
    (tester) async {
      final rows = ValueNotifier(false);
      addTearDown(rows.dispose);
      await tester.pumpWidget(
        harness(
          ValueListenableBuilder<bool>(
            valueListenable: rows,
            builder: (context, show, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(key: Key('old'), height: 50, width: 200),
                if (show)
                  const MessageEntrance(
                    key: Key('new'),
                    animate: true,
                    child: SizedBox(
                      key: Key('content'),
                      height: 100,
                      width: 200,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      final before = tester.getTopLeft(find.byKey(const Key('old'))).dy;
      rows.value = true;
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(const Key('old'))).dy, before);
      final content = find.byKey(const Key('content'));
      // The entire new bubble already exists, with its top touching the old
      // row's bottom; only its position changes as the space is inserted.
      expect(tester.getTopLeft(content).dy, before + 50);
      expect(
        find.descendant(
          of: find.byKey(const Key('new')),
          matching: find.byType(ClipRect),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('new')),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
      await tester.pump(const Duration(milliseconds: 80));
      final during = tester.getTopLeft(find.byKey(const Key('old'))).dy;
      expect(during, inExclusiveRange(before - 100, before));
      expect(tester.getTopLeft(content).dy, during + 50);
      expect(tester.getSize(content).height, 100);
      await tester.pump(MessageEntrance.duration);
      expect(tester.getTopLeft(find.byKey(const Key('old'))).dy, before - 100);
    },
  );

  testWidgets(
    'ack rebuild keeps progress, drag settles, and remount stays full',
    (tester) async {
      final settle = ValueNotifier(0);
      addTearDown(settle.dispose);
      Widget row(bool animate) => harness(
        MessageEntrance(
          key: const Key('stable-client'),
          animate: animate,
          settle: settle,
          child: const SizedBox(height: 100, width: 200),
        ),
      );
      await tester.pumpWidget(row(true));
      await tester.pump(const Duration(milliseconds: 60));
      final height = tester.getSize(find.byType(MessageEntrance)).height;
      expect(height, inExclusiveRange(0, 100));
      await tester.pumpWidget(row(false));
      expect(tester.getSize(find.byType(MessageEntrance)).height, height);
      settle.value++;
      await tester.pump();
      expect(tester.getSize(find.byType(MessageEntrance)).height, 100);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(row(false));
      expect(tester.getSize(find.byType(MessageEntrance)).height, 100);
    },
  );

  testWidgets('bubble shadow paints above the row boundary at rest', (
    tester,
  ) async {
    final previousShadows = debugDisableShadows;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = previousShadows);
    const captureKey = Key('shadow-capture');
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: captureKey,
            child: SizedBox(
              width: 240,
              height: 200,
              child: ColoredBox(
                color: Color(0xFFFFFFFF),
                child: Stack(
                  children: [
                    Positioned(
                      left: 40,
                      top: 80,
                      width: 160,
                      child: MessageEntrance(
                        child: SizedBox(
                          width: 160,
                          height: 64,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0xFFFFFFFF),
                              borderRadius: BorderRadius.all(
                                Radius.circular(20),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x66000000),
                                  blurRadius: 16,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(captureKey),
    );
    final pixels = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      } finally {
        image.dispose();
      }
    });
    debugDisableShadows = previousShadows;
    int redAt(int x, int y) => pixels!.getUint8((y * 240 + x) * 4);
    expect(
      redAt(120, 74),
      lessThan(250),
      reason: 'the shadow must extend above the row, not end at y=80',
    );
    expect(redAt(120, 10), 255);
    expect(redAt(120, 100), 255);
  });

  testWidgets('reduce motion shows the complete row immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const MessageEntrance(animate: true, child: SizedBox(height: 100)),
        reduceMotion: true,
      ),
    );
    expect(tester.getSize(find.byType(MessageEntrance)).height, 100);
    expect(tester.binding.transientCallbackCount, 0);
  });
}
