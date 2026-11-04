import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

/// Streams mono PCM16 chunks from the realtime voice socket to the speaker.
///
/// Chunks wait in a Dart-side queue and are fed to the native player only a
/// short lead ahead of playback, so [clear] (barge-in) cuts the agent off
/// within about [_leadMs] instead of after the whole buffered reply.
class VoicePcmPlayer {
  VoicePcmPlayer({this.sampleRate = 24000});

  final int sampleRate;

  static const _thresholdMs = 120;
  static const _leadMs = 240;

  final _queue = ListQueue<Uint8List>();
  bool _ready = false;
  // Native side has asked for samples and nothing was available to feed.
  bool _hungry = true;
  bool _playing = false;

  /// Called when audible playback starts (true) or drains (false).
  void Function(bool playing)? onPlayingChanged;

  bool get isPlaying => _playing;

  int get _leadBytes => sampleRate * 2 * _leadMs ~/ 1000;

  /// Must run before the microphone starts: on iOS the recorder then
  /// re-applies the playAndRecord category with the speaker route.
  Future<void> init() async {
    if (_ready) return;
    await FlutterPcmSound.setLogLevel(LogLevel.error);
    await FlutterPcmSound.setup(
      sampleRate: sampleRate,
      channelCount: 1,
      iosAudioCategory: IosAudioCategory.playAndRecord,
    );
    await FlutterPcmSound.setFeedThreshold(sampleRate * _thresholdMs ~/ 1000);
    FlutterPcmSound.setFeedCallback(_onFeed);
    _ready = true;
  }

  void addChunk(Uint8List pcm) {
    if (!_ready || pcm.isEmpty) return;
    _queue.add(pcm);
    if (_hungry) _feedNext();
  }

  /// Drop everything not yet handed to the native player (barge-in).
  void clear() {
    _queue.clear();
    _setPlaying(false);
  }

  Future<void> dispose() async {
    _queue.clear();
    _setPlaying(false);
    onPlayingChanged = null;
    if (!_ready) return;
    _ready = false;
    FlutterPcmSound.setFeedCallback(null);
    try {
      await FlutterPcmSound.release();
    } catch (_) {}
  }

  void _onFeed(int remainingFrames) {
    if (!_ready) return;
    if (_queue.isNotEmpty) {
      _feedNext();
      return;
    }
    _hungry = true;
    if (remainingFrames == 0) _setPlaying(false);
  }

  void _feedNext() {
    var total = 0;
    final batch = <Uint8List>[];
    while (_queue.isNotEmpty && total < _leadBytes) {
      final chunk = _queue.removeFirst();
      batch.add(chunk);
      total += chunk.length;
    }
    final joined = Uint8List(total);
    var offset = 0;
    for (final chunk in batch) {
      joined.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    // PCM16 frames are 2 bytes; hold back an odd trailing byte for the next
    // feed so later samples stay aligned.
    final even = total - total % 2;
    if (even != total) _queue.addFirst(Uint8List.fromList([joined[total - 1]]));
    if (even == 0) {
      _hungry = true;
      return;
    }
    final bytes = Uint8List.sublistView(joined, 0, even);
    _hungry = false;
    _setPlaying(true);
    unawaited(
      FlutterPcmSound.feed(
        PcmArrayInt16(bytes: ByteData.sublistView(Uint8List.fromList(bytes))),
      ).catchError((Object _) {
        _hungry = true;
      }),
    );
  }

  void _setPlaying(bool value) {
    if (_playing == value) return;
    _playing = value;
    onPlayingChanged?.call(value);
  }
}
