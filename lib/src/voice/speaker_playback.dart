import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

final _speakerPlayback = AudioContext(
  iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
);

/// Puts the shared iOS audio session back to plain media playback, which
/// always uses the loudspeaker.
///
/// A realtime call leaves the session in play-and-record with voice
/// processing, which routes to the earpiece; audioplayers only applies its
/// category once at startup, so without this every voice message and the
/// hang-up tone after a call would stay on the earpiece. Android needs
/// nothing: the recorder restores the audio mode when the call stops.
Future<void> restoreSpeakerPlayback() async {
  if (defaultTargetPlatform != TargetPlatform.iOS) return;
  try {
    await AudioPlayer.global.setAudioContext(_speakerPlayback);
  } catch (error) {
    debugPrint('[audio] restoring speaker playback failed: $error');
  }
}
