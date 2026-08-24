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

  // CLAUDE.md 权益项 6: 音乐陪伴时长计量。控制器是全局单例 (聊天里"一起听
  // 音乐"和独立音乐页共用同一份播放状态), 计量逻辑放这里而不是某个屏幕,
  // 才能覆盖两个入口。
  CompanionApi? _quotaApi;
  Timer? _quotaTimer;
  int _quotaPendingSeconds = 0;
  bool _quotaAwaitingResponse = false;
  final StreamController<MusicQuotaReport> _quotaEvents =
      StreamController<MusicQuotaReport>.broadcast();

  /// 服务端要求"暂停并确认/去买/去订阅"时触发；订阅方 (当前可见的音乐 UI)
  /// 负责弹框, 并在用户响应后调用 [resolveQuotaPrompt]。
  Stream<MusicQuotaReport> get quotaEvents => _quotaEvents.stream;

  /// 任何持有 [CompanionApi] 的音乐 UI 在进入时调用一次即可 (幂等)。

  MusicTrack? _track;
  Duration _position = Duration.zero;
  Duration _duration = const Duration(seconds: 238);
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _seeking = false;
  String? _loadingTrackId;

  MusicTrack? get track => _track;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  Stream<void> get completed => _completed.stream;

  void configureQuota(CompanionApi api) {
    _quotaApi = api;
    _quotaTimer ??= Timer.periodic(const Duration(seconds: 15), (_) {
      if (_isPlaying && !_quotaAwaitingResponse) {
        unawaited(_reportQuotaTick(15));
      }
    });
  }

  Future<void> _reportQuotaTick(int seconds, {bool paidConfirmed = false}) async {
    final api = _quotaApi;
    if (api == null || seconds <= 0) return;
    MusicQuotaReport report;
    try {
      report = await api.reportMusicQuota(
        deltaSeconds: seconds,
        paidConfirmed: paidConfirmed,
      );
    } catch (_) {
      // 网络抖动: 这次不计, 下一个 15s tick 再试, 不打断正在播放的音乐。
      return;
    }
    if (report.action == MusicQuotaAction.none) return;
    _quotaAwaitingResponse = true;
    _quotaPendingSeconds = report.pendingSeconds;
    if (_isPlaying) {
      _isPlaying = false;
      notifyListeners();
      try {
        await _player.pause();
      } catch (_) {
        // Best-effort; UI 状态已经翻转为暂停。
      }
    }
    _quotaEvents.add(report);
  }

  /// 弹框结果回传。[confirmed]=true 时按之前挂起的秒数补报并扣钞票、恢复播放；
  /// false 时保持暂停 —— 这一秒数就此放弃, 不会在下次播放时重新计费。
  Future<void> resolveQuotaPrompt({required bool confirmed}) async {
    final pending = _quotaPendingSeconds;
    _quotaAwaitingResponse = false;
    _quotaPendingSeconds = 0;
    if (!confirmed) return;
    if (pending > 0) {
      await _reportQuotaTick(pending, paidConfirmed: true);
    }
    // 补报本身也可能又被拦截 (确认和实际扣费之间余额发生变化, 比如另一台
    // 设备同时花掉了钞票): _reportQuotaTick 会把 _quotaAwaitingResponse 重新
    // 置 true 并再发一个新事件。这种情况绝不能恢复播放 —— 钱没真正扣上,
    // 播放要等这个新事件被解决, 否则等于免费听了这段时长。
    if (_quotaAwaitingResponse) return;
    if (_track != null && !_isPlaying) {
      _isPlaying = true;
      notifyListeners();
      try {
        await _player.resume();
      } catch (_) {
        _isPlaying = false;
        notifyListeners();
      }
    }
  }

  Source _sourceFor(MusicTrack track) {
    return UrlSource(track.url, mimeType: 'audio/mpeg');
  }

  bool isCurrentTrack(MusicTrack? value) =>
      value != null && _track != null && value.id == _track!.id;

  bool isLoadingTrack(MusicTrack? value) =>
      value != null && _isLoading && value.id == _loadingTrackId;

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
    _isPlaying = false;
    _isLoading = track.url.isNotEmpty;
    _loadingTrackId = _isLoading ? track.id : null;
    notifyListeners();
    if (track.url.isEmpty) return false;
    try {
      await _player.stop();
      await _player.play(_sourceFor(track), position: position);
      _isPlaying = true;
      return true;
    } catch (_) {
      _isPlaying = false;
      return false;
    } finally {
      _isLoading = false;
      _loadingTrackId = null;
      notifyListeners();
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
      _isLoading = true;
      _loadingTrackId = track.id;
      notifyListeners();
      try {
        if (_player.state == PlayerState.paused) {
          await _player.resume();
        } else if (track.url.isNotEmpty) {
          await _player.play(_sourceFor(track), position: _position);
        } else {
          _isPlaying = false;
          return false;
        }
        _isPlaying = true;
        return true;
      } catch (_) {
        _isPlaying = false;
        return false;
      } finally {
        _isLoading = false;
        _loadingTrackId = null;
        notifyListeners();
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

  Future<void> stop() async {
    _track = null;
    _position = Duration.zero;
    _isPlaying = false;
    _isLoading = false;
    _loadingTrackId = null;
    notifyListeners();
    await _player.stop();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _completeSub?.cancel();
    _completed.close();
    _quotaTimer?.cancel();
    _quotaEvents.close();
    _player.dispose();
    super.dispose();
  }
}
