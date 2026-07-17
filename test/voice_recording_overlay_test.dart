import 'package:companion_flutter/src/widgets/chat/voice_recording_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'voice recording overlay matches the approved interaction state',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
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
      await tester.pump(const Duration(milliseconds: 220));

      expect(find.bySemanticsLabel('正在录音 00:08'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('转文字'), findsOneWidget);
      expect(find.text('左右滑动选择'), findsOneWidget);
      expect(find.text('松开发送'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is ColoredBox && widget.color == const Color(0x70101B17),
        ),
        findsOneWidget,
      );
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/voice_recording_overlay.png'),
      );
    },
  );

  testWidgets('cancel target uses the red selected treatment', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: VoiceRecordingOverlay(
          action: VoiceReleaseAction.cancel,
          seconds: 7,
          preparing: false,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 220));

    final cancelTarget = find.byKey(const ValueKey('voice-action-cancel'));
    final cancelIcon = tester.widget<Icon>(
      find.descendant(of: cancelTarget, matching: find.byType(Icon)),
    );
    final cancelContainer = tester.widget<AnimatedContainer>(
      find.descendant(
        of: cancelTarget,
        matching: find.byType(AnimatedContainer),
      ),
    );
    final decoration = cancelContainer.decoration! as BoxDecoration;

    expect(cancelIcon.color, chatVoiceCancelDeep);
    expect(decoration.color, chatVoiceCancelSoft.withValues(alpha: 0.78));
    expect(
      (decoration.border! as Border).top.color,
      chatVoiceCancel.withValues(alpha: 0.70),
    );
  });

  test('voice release geometry maps send, cancel, and text actions', () {
    const screenSize = Size(390, 844);
    expect(
      voiceReleaseActionForPosition(
        position: const Offset(195, 760),
        screenSize: screenSize,
        safeBottom: 34,
      ),
      VoiceReleaseAction.sendVoice,
    );
    expect(
      voiceReleaseActionForPosition(
        position: const Offset(70, 610),
        screenSize: screenSize,
        safeBottom: 34,
      ),
      VoiceReleaseAction.cancel,
    );
    expect(
      voiceReleaseActionForPosition(
        position: const Offset(320, 610),
        screenSize: screenSize,
        safeBottom: 34,
      ),
      VoiceReleaseAction.sendText,
    );
    expect(
      voiceReleaseActionForPosition(
        position: const Offset(195, 610),
        screenSize: screenSize,
        safeBottom: 34,
        currentAction: VoiceReleaseAction.sendText,
      ),
      VoiceReleaseAction.sendText,
    );
  });

  test('recordings shorter than the minimum are cancelled', () {
    expect(isVoiceCaptureTooShort(null), isTrue);
    expect(isVoiceCaptureTooShort(const Duration(milliseconds: 649)), isTrue);
    expect(isVoiceCaptureTooShort(const Duration(milliseconds: 650)), isFalse);
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
