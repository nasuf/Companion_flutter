part of 'package:companion_flutter/main.dart';

class MusicPlaybackController extends ChangeNotifier {
  MusicPlaybackController._() {
    _positionSub = _player.onPositionChanged.listen((value) {
      if (_seeking) return;
      _position = value;
      notifyListeners();
    });
    _durationSub = _player.onDurationChanged.listen((value) {
      if (value.inMilliseconds <= 0) return;
      _duration = value;
      notifyListeners();
    });
    _stateSub = _player.onPlayerStateChanged.listen((state) {
      final playing = state == PlayerState.playing;
      if (_isPlaying == playing) return;
      _isPlaying = playing;
      notifyListeners();
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      _isPlaying = false;
      _position = Duration.zero;
      notifyListeners();
      _completed.add(null);
    });
  }

  static final MusicPlaybackController instance = MusicPlaybackController._();

  final AudioPlayer _player = AudioPlayer();
  final StreamController<void> _completed = StreamController<void>.broadcast();
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<void>? _completeSub;

  MusicTrack? _track;
  Duration _position = Duration.zero;
  Duration _duration = const Duration(seconds: 238);
  bool _isPlaying = false;
  bool _seeking = false;

  MusicTrack? get track => _track;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isPlaying => _isPlaying;
  Stream<void> get completed => _completed.stream;

  Source _sourceFor(MusicTrack track) {
    return UrlSource(track.url, mimeType: 'audio/mpeg');
  }

  bool isCurrentTrack(MusicTrack? value) =>
      value != null && _track != null && value.id == _track!.id;

  void adoptIfCurrent(MusicTrack track) {
    if (!isCurrentTrack(track)) return;
    notifyListeners();
  }

  Future<bool> playTrack(
    MusicTrack track, {
    Duration position = Duration.zero,
    bool preserveIfCurrent = false,
  }) async {
    if (preserveIfCurrent && isCurrentTrack(track)) {
      notifyListeners();
      return true;
    }
    _track = track;
    _position = position;
    _duration = Duration(
      seconds: track.durationSec > 0 ? track.durationSec : _duration.inSeconds,
    );
    _isPlaying = track.url.isNotEmpty;
    notifyListeners();
    if (track.url.isEmpty) return false;
    try {
      await _player.stop();
      await _player.play(_sourceFor(track), position: position);
      return true;
    } catch (_) {
      _isPlaying = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggle(MusicTrack track) async {
    if (!isCurrentTrack(track)) {
      return playTrack(track);
    }
    if (_isPlaying) {
      _isPlaying = false;
      notifyListeners();
      await _player.pause();
      return true;
    } else {
      _isPlaying = true;
      notifyListeners();
      try {
        if (_player.state == PlayerState.paused) {
          await _player.resume();
        } else if (track.url.isNotEmpty) {
          await _player.play(_sourceFor(track), position: _position);
        }
        return true;
      } catch (_) {
        _isPlaying = false;
        notifyListeners();
        return false;
      }
    }
  }

  Future<void> seek(Duration target) async {
    _seeking = true;
    _position = target;
    notifyListeners();
    await _player.seek(target);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _seeking = false;
    _position = target;
    notifyListeners();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _completeSub?.cancel();
    _completed.close();
    _player.dispose();
    super.dispose();
  }
}
