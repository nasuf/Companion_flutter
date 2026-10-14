import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:companion_flutter/models.dart';
import 'package:companion_flutter/src/widgets/chat/voice_recording_overlay.dart';
import 'package:companion_flutter/takeover_inbox.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'takeover_flow_test.dart' as flow;

class VoiceApi extends flow.FakeTakeoverApi {
  VoiceApi({super.baseUrl});
  final modes = <String>[];
  final sentAudio = <List<ChatAttachment>>[];
  final texts = <String>[];

  @override
  Future<ChatAudioTranscription> transcribeChatAudio({
    required String conversationId,
    required String name,
    required String mime,
    required int size,
    required int durationSeconds,
    required String displayMode,
    required String base64Data,
  }) async {
    expect(conversationId, 'conv');
    expect(base64Decode(base64Data), [1, 2, 3, 4]);
    modes.add(displayMode);
    return ChatAudioTranscription(
      text: displayMode == 'text' ? '真实转写内容' : '［语音］',
      durationSeconds: 3,
      model: 'human_takeover',
      attachment: displayMode == 'text' ? null : audio(),
    );
  }

  @override
  Future<String> sendTakeoverMessage(
    String takeoverId, {
    required String text,
    String? clientId,
    List<ChatAttachment> attachments = const [],
  }) async {
    texts.add(text);
    sentAudio.add(List.of(attachments));
    return super.sendTakeoverMessage(
      takeoverId,
      text: text,
      clientId: clientId,
      attachments: attachments,
    );
  }
}

ChatAttachment audio() => ChatAttachment.fromJson({
  'id': 'recording',
  'kind': 'audio',
  'mime': 'audio/mp4',
  'size': 4,
  'duration_seconds': 3,
  'url': '/chat/media/recording.m4a',
  'transcription_status': 'ready',
  'transcription_text': '',
});

class RealHttp extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  String? path;
  late List<String> recordCalls;
  late List<MethodCall> playerCalls;
  setUpAll(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => null,
      );
    }
    await AudioPlayer.global.ensureInitialized();
  });
  setUp(() {
    directory = Directory.systemTemp.createTempSync('takeover-audio-');
    path = null;
    recordCalls = [];
    playerCalls = [];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => directory.path,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (call) async {
        recordCalls.add(call.method);
        final args = call.arguments as Map;
        switch (call.method) {
          case 'create':
            messenger.setMockMethodCallHandler(
              MethodChannel(
                'com.llfbandit.record/events/${args['recorderId']}',
              ),
              (_) async => null,
            );
          case 'hasPermission':
            return true;
          case 'isRecording':
            return true;
          case 'getAmplitude':
            return {'current': -10.0, 'max': -10.0};
          case 'start':
            path = args['path'] as String;
            File(path!).writeAsBytesSync([1, 2, 3, 4]);
          case 'stop':
            return path;
        }
        return null;
      },
    );
    for (final name in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => null,
      );
    }
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async {
        playerCalls.add(call);
        final id = (call.arguments as Map?)?['playerId'];
        if (id != null) {
          final channel = 'xyz.luan/audioplayers/events/$id';
          messenger.setMockMethodCallHandler(
            MethodChannel(channel),
            (_) async => null,
          );
          if (call.method == 'setSourceUrl') {
            ui.channelBuffers.push(
              channel,
              const StandardMethodCodec().encodeSuccessEnvelope({
                'event': 'audio.onPrepared',
                'value': true,
              }),
              (_) {},
            );
          }
        }
        return null;
      },
    );
  });
  tearDown(() async {
    await TakeoverInbox.instance.stop();
    directory.deleteSync(recursive: true);
  });

  for (final action in ['voice', 'text', 'cancel']) {
    testWidgets(
      'takeover uses the shared recorder and preserves $action intent',
      (tester) async {
        final api = VoiceApi()..failFirstSend = action == 'voice';
        await flow.chat(tester, api);
        await tester.tap(find.bySemanticsLabel('切换到语音输入'));
        await flow.drain(tester);
        expect(find.text('按住说话'), findsOneWidget);
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('按住说话')),
        );
        await flow.drain(tester);
        expect(find.byType(VoiceRecordingOverlay), findsOneWidget);
        expect(find.text('左右滑动选择'), findsOneWidget);
        expect(find.text('松开发送'), findsWidgets);
        expect(recordCalls, contains('start'));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 750)),
        );
        await tester.pump(const Duration(milliseconds: 750));
        if (action != 'voice') {
          await gesture.moveTo(
            tester.getCenter(
              find.byKey(
                ValueKey(
                  'voice-action-${action == 'cancel' ? 'cancel' : 'text'}',
                ),
              ),
            ),
          );
          await tester.pump();
        }
        await gesture.up();
        for (var n = 0; n < 30; n++) {
          await tester.pump(const Duration(milliseconds: 20));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
        }
        await flow.drain(tester);
        if (action == 'cancel') {
          expect(recordCalls, contains('cancel'));
          expect(api.sentAudio, isEmpty);
          expect(api.modes, isEmpty);
        } else {
          expect(api.modes, [action], reason: recordCalls.toString());
          expect(
            api.sentAudio.single.map((a) => a.id),
            action == 'voice' ? ['recording'] : isEmpty,
          );
          expect(api.texts, [action == 'voice' ? '［语音］' : '真实转写内容']);
          if (action == 'voice') {
            expect(find.text('3″'), findsOneWidget);
            expect(find.text('［语音］'), findsNothing);
            final retry = find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.label == '发送失败，点击重试',
            );
            expect(retry, findsOneWidget);
            await tester.tap(retry);
            await flow.drain(tester);
            expect(api.sends, hasLength(2));
            expect(api.sends.toSet(), hasLength(1));
            expect(api.sentAudio.last.single.id, 'recording');
            expect(find.text('3″'), findsOneWidget);
            expect(retry, findsNothing);
          }
          expect(File(path!).existsSync(), isFalse);
        }
        expect(find.byType(VoiceRecordingOverlay), findsNothing);
        await tester.pumpWidget(const SizedBox());
        for (var n = 0; n < 30 && !recordCalls.contains('dispose'); n++) {
          await tester.pump(const Duration(milliseconds: 20));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
        }
        await flow.drain(tester);
        expect(recordCalls, contains('dispose'));
      },
    );
  }

  testWidgets(
    'saved administrator audio reloads and replays through the normal authenticated player',
    (tester) async {
      await HttpOverrides.runZoned(() async {
        late HttpServer server;
        final requests = <String>[];
        await tester.runAsync(() async {
          server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          server.listen((request) async {
            requests.add(request.uri.path);
            expect(request.headers.value('authorization'), 'Bearer synthetic');
            request.response.add([1, 2, 3, 4]);
            await request.response.close();
          });
        });
        try {
          final api = VoiceApi(baseUrl: 'http://127.0.0.1:${server.port}')
            ..authToken = 'synthetic';
          api.scriptedHistory = [
            ChatMessage(
              id: 'saved',
              conversationId: 'conv',
              role: 'assistant',
              content: '［语音］',
              createdAt: DateTime.now(),
              metadata: {
                'human_takeover': true,
                'attachments': [audio().toJson()],
              },
            ),
          ];
          await flow.chat(tester, api);
          expect(find.text('［语音］'), findsNothing);
          expect(find.text('3″'), findsOneWidget);
          await tester.tap(find.byIcon(CupertinoIcons.play_fill));
          for (var n = 0; n < 30; n++) {
            await tester.pump(const Duration(milliseconds: 20));
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
          }
          await flow.drain(tester);
          expect(requests, ['/chat/media/recording.m4a']);
          expect(playerCalls.map((c) => c.method), contains('setSourceUrl'));
          expect(find.byIcon(CupertinoIcons.pause_fill), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
          await flow.drain(tester);
        } finally {
          await tester.runAsync(() => server.close(force: true));
        }
      }, createHttpClient: (context) => RealHttp().createHttpClient(context));
    },
  );
}
