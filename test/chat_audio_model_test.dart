import 'package:companion_flutter/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'chat audio attachment preserves playback and transcription metadata',
    () {
      final attachment = ChatAttachment.fromJson({
        'id': 'audio-1',
        'kind': 'audio',
        'name': 'voice.m4a',
        'mime': 'audio/mp4',
        'size': 24000,
        'duration_seconds': 6,
        'url': '/chat/media/user_voice.m4a',
        'vision_status': 'skipped',
        'transcription_status': 'ready',
        'transcription_text': '明天下午三点提醒我开会',
        'transcription_model': 'fun-asr-flash-test',
        'transcription_request_id': 'request-1',
      });

      expect(attachment.isAudio, isTrue);
      expect(attachment.showsAsVoice, isTrue);
      expect(attachment.durationSeconds, 6);
      expect(attachment.transcriptionText, '明天下午三点提醒我开会');
      expect(attachment.toJson()['transcription_request_id'], 'request-1');
    },
  );
}
