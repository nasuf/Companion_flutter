import 'package:companion_flutter/src/widgets/chat/voice_recording_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    expect(decoration.color, chatVoiceCancelSoft.withValues(alpha: 0.34));
    expect(
      (decoration.border! as Border).top.color,
      chatVoiceCancel.withValues(alpha: 0.40),
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

  test('silent capture check fails open without platform samples', () {
    expect(
      shouldRejectSilentVoiceCapture(
        amplitudeSampleCount: 0,
        activeMilliseconds: 0,
      ),
      isFalse,
    );
    expect(
      shouldRejectSilentVoiceCapture(
        amplitudeSampleCount: 10,
        activeMilliseconds: 160,
      ),
      isTrue,
    );
    expect(
      shouldRejectSilentVoiceCapture(
        amplitudeSampleCount: 10,
        activeMilliseconds: voiceMinimumActiveMilliseconds,
      ),
      isFalse,
    );
  });

  test('iOS recording session keeps haptics enabled', () {
    expect(
      chatVoiceRecordConfig
          .iosConfig
          .allowHapticsAndSystemSoundsDuringRecording,
      isTrue,
    );
  });

  testWidgets('voice vibration uses a short impact haptic', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await triggerVoiceVibration();

    expect(
      calls,
      contains(
        isA<MethodCall>()
            .having((call) => call.method, 'method', 'HapticFeedback.vibrate')
            .having(
              (call) => call.arguments,
              'arguments',
              'HapticFeedbackType.lightImpact',
            ),
      ),
    );
  });

  test('haptics fire only when entering cancel or text targets', () {
    expect(
      shouldHapticOnVoiceActionEntry(
        previous: VoiceReleaseAction.sendVoice,
        next: VoiceReleaseAction.cancel,
      ),
      isTrue,
    );
    expect(
      shouldHapticOnVoiceActionEntry(
        previous: VoiceReleaseAction.sendVoice,
        next: VoiceReleaseAction.sendText,
      ),
      isTrue,
    );
    expect(
      shouldHapticOnVoiceActionEntry(
        previous: VoiceReleaseAction.cancel,
        next: VoiceReleaseAction.sendVoice,
      ),
      isFalse,
    );
    expect(
      shouldHapticOnVoiceActionEntry(
        previous: VoiceReleaseAction.cancel,
        next: VoiceReleaseAction.cancel,
      ),
      isFalse,
    );
  });

  testWidgets(
    'hold gesture stays tracked after a full-screen overlay appears',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final events = <String>[];
      var covered = false;
      late StateSetter setHostState;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return Stack(
                fit: StackFit.expand,
                children: [
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      width: 260,
                      height: 48,
                      child: VoiceHoldGestureRegion(
                        enabled: true,
                        onStart: (_) => events.add('start'),
                        onMove: (_) => events.add('move'),
                        onEnd: (_) => events.add('end'),
                        onCancel: () => events.add('cancel'),
                        child: const ColoredBox(color: chatVoiceAccent),
                      ),
                    ),
                  ),
                  if (covered)
                    const Positioned.fill(
                      child: ColoredBox(color: Color(0x70101B17)),
                    ),
                ],
              );
            },
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(195, 820));
      expect(events, ['start']);

      setHostState(() => covered = true);
      await tester.pump();
      await gesture.moveTo(const Offset(70, 610));
      await gesture.up();

      expect(events, containsAllInOrder(['start', 'move', 'end']));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('waveform smoothly accepts rapid amplitude updates', (
    tester,
  ) async {
    final amplitude = ValueNotifier<double>(0.10);
    addTearDown(amplitude.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: VoiceRecordingOverlay(
          action: VoiceReleaseAction.sendVoice,
          seconds: 2,
          preparing: false,
          amplitude: amplitude,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 220));

    amplitude.value = 0.92;
    await tester.pump(const Duration(milliseconds: 32));
    amplitude.value = 0.24;
    await tester.pump(const Duration(milliseconds: 32));
    amplitude.value = 0.70;
    await tester.pump(const Duration(milliseconds: 160));

    expect(tester.takeException(), isNull);
  });

  testWidgets('transcription spinner has no visible status copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: VoiceTranscriptionSpinner())),
    );
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.bySemanticsLabel('正在转写语音'), findsOneWidget);
    expect(find.textContaining('正在转成文字'), findsNothing);
    expect(tester.takeException(), isNull);
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
