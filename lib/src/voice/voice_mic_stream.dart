import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

/// Streams 24 kHz mono PCM16 from the device microphone.
///
/// Uses the `record` package's `startStream` API with [AudioEncoder.pcm16bits].
/// Each chunk from the stream is a raw PCM16 little-endian byte buffer that can
/// be sent directly over the voice WebSocket as a binary frame.
class VoiceMicStream {
  VoiceMicStream({int sampleRate = 24000}) : _sampleRate = sampleRate;

  final int _sampleRate;
  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _sub;
  StreamSubscription<RecordState>? _stateSub;
  bool _active = false;

  bool get isActive => _active;

  /// Check (and request if needed) microphone permission.
  /// Returns true if permission is granted.
  Future<bool> checkPermission() async {
    _recorder ??= AudioRecorder();
    return _recorder!.hasPermission();
  }

  /// Start streaming PCM16 audio. Calls [onData] with each chunk.
  /// Returns false if permission was denied or recording failed to start.
  /// [onFailure] fires once if the recorder stops working mid-call: the
  /// native side reports that only on the state stream, never on the data.
  Future<bool> start({
    required void Function(Uint8List pcm) onData,
    void Function()? onFailure,
  }) async {
    if (_active) return true;
    _recorder ??= AudioRecorder();

    if (!await _recorder!.hasPermission()) return false;

    try {
      final stream = await _recorder!.startStream(
        // The agent plays through the speaker while the mic stays open, so
        // echo cancellation keeps server VAD from hearing the agent itself
        // and interrupting its own reply.
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
          // Android's communication capture is quiet (about -38 dBFS RMS on
          // a PHB110); server VAD needs roughly -26. iOS voice
          // processing already levels it, so its gain stays untouched.
          autoGain: defaultTargetPlatform == TargetPlatform.android,
          androidConfig: const AndroidRecordConfig(
            audioSource: AndroidAudioSource.voiceCommunication,
            audioManagerMode: AudioManagerMode.modeInCommunication,
            speakerphone: true,
          ),
        ),
      );
      _active = true;
      var failed = false;
      void fail() {
        if (failed || !_active) return;
        failed = true;
        onFailure?.call();
      }

      _stateSub = _recorder!.onStateChanged().listen(
        (_) {},
        onError: (Object _) => fail(),
      );
      _sub = stream.listen(
        (data) {
          if (_active && data.isNotEmpty) {
            onData(data);
          }
        },
        onError: (Object _) => fail(),
        cancelOnError: false,
      );
      return true;
    } catch (_) {
      _active = false;
      return false;
    }
  }

  /// Stop streaming and release the recorder.
  Future<void> stop() async {
    _active = false;
    await _sub?.cancel();
    _sub = null;
    await _stateSub?.cancel();
    _stateSub = null;
    try {
      await _recorder?.stop();
    } catch (_) {}
  }

  /// Fully dispose the recorder instance.
  Future<void> dispose() async {
    await stop();
    await _recorder?.dispose();
    _recorder = null;
  }
}
