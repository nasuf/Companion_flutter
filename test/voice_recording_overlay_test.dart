import 'package:companion_flutter/src/widgets/chat/voice_recording_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'voice recording overlay matches the approved interaction state',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                _ChatBackdrop(),
                VoiceRecordingOverlay(
                  action: VoiceReleaseAction.sendVoice,
                  seconds: 8,
                  preparing: false,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.bySemanticsLabel('正在录音 00:08'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('滑到这里  转文字'), findsOneWidget);
      expect(find.text('松开  发送'), findsOneWidget);
      expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
    },
  );

  test('quick tap or release while preparing latches recording', () {
    expect(
      shouldLatchVoiceRecordingAfterRelease(
        action: VoiceReleaseAction.sendVoice,
        pressDuration: const Duration(milliseconds: 200),
        preparing: false,
        capturedDuration: const Duration(milliseconds: 100),
      ),
      isTrue,
    );
    expect(
      shouldLatchVoiceRecordingAfterRelease(
        action: VoiceReleaseAction.sendVoice,
        pressDuration: const Duration(seconds: 1),
        preparing: true,
      ),
      isTrue,
    );
    expect(
      shouldLatchVoiceRecordingAfterRelease(
        action: VoiceReleaseAction.sendVoice,
        pressDuration: const Duration(seconds: 2),
        preparing: false,
        capturedDuration: const Duration(seconds: 1),
      ),
      isFalse,
    );
    expect(
      shouldLatchVoiceRecordingAfterRelease(
        action: VoiceReleaseAction.sendText,
        pressDuration: const Duration(milliseconds: 100),
        preparing: false,
      ),
      isFalse,
    );
  });

  testWidgets('tap recording mode explains how to send', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VoiceRecordingOverlay(
          action: VoiceReleaseAction.sendVoice,
          seconds: 2,
          preparing: false,
          tapMode: true,
        ),
      ),
    );

    expect(find.text('再次点击麦克风  发送'), findsOneWidget);
  });
}

class _ChatBackdrop extends StatelessWidget {
  const _ChatBackdrop();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF6FDFC),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(
              height: 58,
              child: Center(
                child: Text(
                  'Companion',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: const [
                  Align(
                    alignment: Alignment.centerRight,
                    child: _FakeBubble(text: '哪种方便？', mine: true),
                  ),
                  SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _FakeBubble(text: '可以直接发语音，我会帮你转成文字。'),
                  ),
                  SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _FakeBubble(text: '那我试一下', mine: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FakeBubble extends StatelessWidget {
  const _FakeBubble({required this.text, this.mine = false});

  final String text;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: mine ? const Color(0xFF06C893) : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: TextStyle(color: mine ? Colors.white : Colors.black87),
      ),
    );
  }
}
