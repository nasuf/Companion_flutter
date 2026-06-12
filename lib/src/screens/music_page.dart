part of 'package:companion_flutter/main.dart';

class MusicPage extends StatefulWidget {
  const MusicPage({
    super.key,
    required this.api,
    required this.session,
    this.initialTrack,
    this.endCoListeningOnBack = false,
  });

  final CompanionApi api;
  final AuthSession session;
  final MusicTrack? initialTrack;
  final bool endCoListeningOnBack;

  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> with TickerProviderStateMixin {
  static const _waveHeights = <double>[
    0.66,
    1.12,
    0.52,
    1.26,
    0.78,
    1.08,
    0.64,
    0.96,
    0.48,
    1.32,
    0.84,
    1.16,
    0.70,
    1.01,
    0.56,
    1.24,
    0.88,
    1.36,
    0.58,
    1.04,
    0.74,
    1.18,
    0.62,
    0.98,
  ];
  static const _fallbackLibraries = [
    MusicLibrary(id: 'focus', title: '专注', subtitle: '工作和阅读'),
    MusicLibrary(id: 'ambient', title: 'Ambient', subtitle: '随机频道'),
    MusicLibrary(id: 'sleep', title: '睡眠', subtitle: '夜间陪伴'),
  ];

  late final AnimationController _ambientController;
  late final AnimationController _discController;
  late final AnimationController _waveController;
  late final MusicPlaybackController _playback;
  StreamSubscription<void>? _completeSub;

  List<MusicLibrary> _libraries = _fallbackLibraries;
  List<MusicTrack> _favoriteTracks = const [];
  List<MusicTrack> _history = const [];
  int _historyIndex = -1;
  MusicTrack? _currentTrack;
  String _selectedLibrary = 'focus';
  Duration _position = Duration.zero;
  Duration _duration = const Duration(seconds: 238);
  bool _loading = true;
  bool _loadingTrack = false;
  bool _busyFavorite = false;
  bool _isPlaying = false;
  bool _lyricsMode = false;
  bool _seeking = false;
  int _seekGeneration = 0;
  String? _error;

  String get _agentId => widget.session.agentId ?? '';
  String get _agentName => widget.session.agentName ?? '小芜';
  bool get _canGoPrevious => _historyIndex > 0;
  List<String> get _lyricsLines {
    final metadata = _currentTrack?.metadata;
    if (metadata == null || metadata.isEmpty) return const [];
    return _extractLyrics(metadata);
  }

  static const _lyricsKeys = {
    'lyrics',
    'lyric',
    'lrc',
    'lines',
    'transcript',
    'transcription',
  };

  static List<String> _extractLyrics(
    Object? value, {
    int depth = 0,
    bool allowString = false,
  }) {
    if (value == null || depth > 4) return const [];
    if (value is String) return allowString ? _splitLyrics(value) : const [];
    if (value is List) {
      final direct = <String>[];
      for (final item in value) {
        if (item is String) {
          if (allowString) direct.addAll(_splitLyrics(item));
        } else if (item is Map) {
          final nested = _extractLyrics(
            item,
            depth: depth + 1,
            allowString: allowString,
          );
          if (nested.isNotEmpty) return nested;
          final text = item['text'] ?? item['line'] ?? item['content'];
          if (allowString) direct.addAll(_splitLyrics(text));
        }
      }
      return direct.where((line) => line.isNotEmpty).toList();
    }
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString().toLowerCase();
        if (_lyricsKeys.contains(key)) {
          final found = _extractLyrics(
            entry.value,
            depth: depth + 1,
            allowString: true,
          );
          if (found.isNotEmpty) return found;
        }
      }
      for (final entry in value.entries) {
        final found = _extractLyrics(entry.value, depth: depth + 1);
        if (found.isNotEmpty) return found;
      }
    }
    return const [];
  }

  static List<String> _splitLyrics(Object? value) {
    if (value == null) return const [];
    final text = value.toString().trim();
    if (text.isEmpty) return const [];
    return text
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.replaceAll(RegExp(r'\[[^\]]+\]'), '').trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 10500),
    )..repeat(reverse: true);
    _discController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 18000),
    );
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    );
    _playback = MusicPlaybackController.instance;
    _playback.addListener(_handlePlaybackChanged);
    _completeSub = _playback.completed.listen((_) {
      if (mounted) {
        unawaited(_playRandom(refresh: true, changeSource: 'auto_next'));
      }
    });
    _load();
  }

  @override
  void dispose() {
    _completeSub?.cancel();
    _playback.removeListener(_handlePlaybackChanged);
    _ambientController.dispose();
    _discController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _handlePlaybackChanged() {
    if (!mounted) return;
    final track = _playback.track;
    setState(() {
      if (track != null) _currentTrack = _withFavoriteState(track);
      if (!_seeking) _position = _playback.position;
      if (_playback.duration.inMilliseconds > 0) {
        _duration = _playback.duration;
      }
      _isPlaying = _playback.isPlaying;
    });
    _syncDiscAnimation(_playback.isPlaying);
    _syncWaveAnimation(_playback.isPlaying);
  }

  Future<void> _load() async {
    if (_agentId.isEmpty) {
      setState(() {
        _loading = false;
        _error = '还没有可用的 AI 伙伴，暂时不能一起听音乐。';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.api.listMusicLibraries(),
        widget.api.listMusicFavorites(agentId: _agentId),
      ]);
      if (!mounted) return;
      final libraryResponse = results[0] as MusicLibrariesResponse;
      final favorites = results[1] as MusicTracksResponse;
      final libraries = libraryResponse.libraries.isEmpty
          ? _fallbackLibraries
          : libraryResponse.libraries;
      setState(() {
        _libraries = libraries;
        _selectedLibrary = libraryResponse.defaultLibrary.isEmpty
            ? libraries.first.id
            : libraryResponse.defaultLibrary;
        _favoriteTracks = favorites.tracks;
        _loading = false;
      });
      final initialTrack = widget.initialTrack;
      if (initialTrack != null) {
        final playableInitialTrack = await _resolveInitialTrack(initialTrack);
        if (!mounted) return;
        _selectedLibrary = playableInitialTrack.library;
        await _startTrack(
          playableInitialTrack,
          addToHistory: true,
          preserveIfCurrent: true,
          changeSource: 'initial',
        );
      } else {
        await _playRandom(refresh: true, changeSource: 'initial');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _formatError(error);
        _loading = false;
      });
    }
  }

  Future<MusicTrack> _resolveInitialTrack(MusicTrack track) async {
    if (_playback.isCurrentTrack(track)) {
      return _playback.track ?? track;
    }
    if (_agentId.isEmpty || track.id.isEmpty) return track;
    try {
      final playUrl = await widget.api.getMusicTrackPlayUrl(
        agentId: _agentId,
        trackId: track.id,
      );
      if (playUrl.url.isEmpty) return track.copyWith(url: '');
      return track.copyWith(
        url: playUrl.url,
        metadata: {
          ...track.metadata,
          'play_url_refreshed_at': DateTime.now().toIso8601String(),
          if (playUrl.expiresAt != null)
            'play_url_expires_at': playUrl.expiresAt!.toIso8601String(),
        },
      );
    } catch (_) {
      return track;
    }
  }

  Future<void> _playRandom({
    required bool refresh,
    int retryCount = 0,
    String changeSource = 'manual_next',
  }) async {
    if (_agentId.isEmpty || _loadingTrack) return;
    final excludeTrackId = refresh ? _currentTrack?.id : null;
    setState(() {
      _loadingTrack = true;
      _error = null;
    });
    try {
      final response = await widget.api.listMusicTracks(
        agentId: _agentId,
        workspaceId: widget.session.workspaceId,
        library: _selectedLibrary,
        excludeTrackId: excludeTrackId,
        limit: 1,
        refresh: refresh,
      );
      if (!mounted) return;
      final track = response.tracks.isEmpty ? null : response.tracks.first;
      if (track == null) {
        setState(() => _error = '暂时没有拿到这类音乐，稍后再试一次。');
        return;
      }
      final played = await _startTrack(
        track,
        addToHistory: true,
        changeSource: changeSource,
      );
      if (!played && mounted && retryCount < 2) {
        setState(() => _loadingTrack = false);
        await _playRandom(
          refresh: true,
          retryCount: retryCount + 1,
          changeSource: changeSource,
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = _formatError(error));
    } finally {
      if (mounted) setState(() => _loadingTrack = false);
    }
  }

  Future<bool> _startTrack(
    MusicTrack track, {
    required bool addToHistory,
    bool preserveIfCurrent = false,
    String changeSource = 'sync',
  }) async {
    final selected = _withFavoriteState(track).copyWith(playedByAgent: true);
    final isPreserving =
        preserveIfCurrent && _playback.isCurrentTrack(selected);
    final nextDuration = Duration(
      seconds: selected.durationSec > 0 ? selected.durationSec : 238,
    );
    setState(() {
      _seekGeneration += 1;
      _currentTrack = selected;
      _position = isPreserving ? _playback.position : Duration.zero;
      _duration = nextDuration;
      _isPlaying = isPreserving ? _playback.isPlaying : true;
      _lyricsMode = false;
      _seeking = false;
      if (addToHistory) {
        final keptHistory = _historyIndex < 0
            ? const <MusicTrack>[]
            : _history.take(_historyIndex + 1).toList();
        _history = [...keptHistory, selected];
        _historyIndex = _history.length - 1;
      }
    });
    _syncWaveAnimation(_isPlaying);
    _syncDiscAnimation(_isPlaying);
    var didStart = false;
    if (selected.url.isNotEmpty) {
      didStart = await _playback.playTrack(
        selected,
        position: _position,
        preserveIfCurrent: preserveIfCurrent,
      );
      if (!didStart) {
        if (mounted) {
          _setPlayingState(false);
          setState(() => _error = '这首歌暂时播放不了，正在换一首。');
        }
      }
    }
    unawaited(_syncPlayback(selected, changeSource: changeSource));
    return didStart;
  }

  void _setPlayingState(bool isPlaying) {
    if (_isPlaying != isPlaying) {
      setState(() => _isPlaying = isPlaying);
    }
    _syncDiscAnimation(isPlaying);
    _syncWaveAnimation(isPlaying);
  }

  void _syncDiscAnimation(bool isPlaying) {
    if (isPlaying) {
      if (!_discController.isAnimating) _discController.repeat();
    } else if (_discController.isAnimating) {
      _discController.stop(canceled: false);
    }
  }

  void _syncWaveAnimation(bool isPlaying) {
    if (isPlaying) {
      if (!_waveController.isAnimating) _waveController.repeat();
    } else if (_waveController.isAnimating) {
      _waveController.stop(canceled: false);
    }
  }

  MusicTrack _withFavoriteState(MusicTrack track) {
    return track.copyWith(
      isFavorite: _favoriteTracks.any((item) => item.id == track.id),
    );
  }

  Future<void> _selectLibrary(String library) async {
    if (_selectedLibrary == library || _loadingTrack) return;
    setState(() => _selectedLibrary = library);
    await _playRandom(refresh: true, changeSource: 'manual_next');
  }

  Future<void> _previousTrack() async {
    if (!_canGoPrevious || _loadingTrack) return;
    final nextIndex = _historyIndex - 1;
    final track = _history[nextIndex];
    setState(() => _historyIndex = nextIndex);
    await _startTrack(
      track,
      addToHistory: false,
      changeSource: 'manual_previous',
    );
  }

  Future<void> _playFavoriteTrack(MusicTrack track) async {
    if (_loadingTrack) return;
    Navigator.of(context).maybePop();
    await _startTrack(track, addToHistory: true, changeSource: 'manual_next');
  }

  Future<void> _togglePlay() async {
    final track = _currentTrack;
    if (track == null) return;
    try {
      await _playback.toggle(track);
      unawaited(
        _syncPlayback(
          track.copyWith(playedByAgent: true),
          changeSource: _playback.isPlaying ? 'resume' : 'pause',
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = _formatError(error));
    }
  }

  void _beginSeek(double progress) {
    _seekGeneration += 1;
    _previewSeek(progress);
  }

  void _previewSeek(double progress) {
    final target = _durationFromProgress(progress);
    setState(() {
      _seeking = true;
      _position = target;
    });
  }

  Future<void> _seekTo(double progress) async {
    final generation = ++_seekGeneration;
    final target = _durationFromProgress(progress);
    setState(() {
      _position = target;
      _seeking = true;
    });
    try {
      await _playback.seek(target);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted || generation != _seekGeneration) return;
      setState(() {
        _position = target;
        _seeking = false;
      });
      final track = _currentTrack;
      if (track != null) {
        unawaited(_syncPlayback(track, changeSource: 'seek'));
      }
    } catch (error) {
      if (mounted && generation == _seekGeneration) {
        setState(() {
          _seeking = false;
          _error = _formatError(error);
        });
      }
    }
  }

  Duration _durationFromProgress(double progress) {
    return Duration(
      milliseconds: (_duration.inMilliseconds * progress.clamp(0.0, 1.0))
          .round(),
    );
  }

  Future<void> _toggleFavorite(MusicTrack track) async {
    if (_agentId.isEmpty || _busyFavorite) return;
    final wasFavorite = _favoriteTracks.any((item) => item.id == track.id);
    setState(() {
      _busyFavorite = true;
      _setFavoriteState(track.id, !wasFavorite);
    });
    try {
      if (wasFavorite) {
        await widget.api.removeMusicFavorite(
          agentId: _agentId,
          trackId: track.id,
        );
      } else {
        final saved = await widget.api.addMusicFavorite(
          agentId: _agentId,
          workspaceId: widget.session.workspaceId,
          track: track.copyWith(isFavorite: true),
        );
        if (mounted) {
          setState(() {
            _favoriteTracks = [
              saved,
              ..._favoriteTracks.where((item) => item.id != saved.id),
            ];
            _setFavoriteState(saved.id, true);
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _setFavoriteState(track.id, wasFavorite);
          _error = _formatError(error);
        });
      }
    } finally {
      if (mounted) setState(() => _busyFavorite = false);
    }
  }

  void _setFavoriteState(String trackId, bool isFavorite) {
    _favoriteTracks = isFavorite
        ? _favoriteTracks
        : _favoriteTracks.where((item) => item.id != trackId).toList();
    _history = _history
        .map(
          (item) =>
              item.id == trackId ? item.copyWith(isFavorite: isFavorite) : item,
        )
        .toList();
    if (_currentTrack?.id == trackId) {
      _currentTrack = _currentTrack!.copyWith(isFavorite: isFavorite);
    }
  }

  Future<void> _syncPlayback(
    MusicTrack track, {
    String changeSource = 'sync',
  }) async {
    if (_agentId.isEmpty) return;
    try {
      await widget.api.updateMusicNowPlaying(
        agentId: _agentId,
        workspaceId: widget.session.workspaceId,
        conversationId: widget.session.conversationId,
        track: track,
        positionSeconds: _position.inSeconds,
        isPlaying: _isPlaying,
        changeSource: changeSource,
      );
    } catch (_) {
      // Playback should stay responsive even if presence sync fails.
    }
  }

  void _toggleDisplay() {
    setState(() => _lyricsMode = !_lyricsMode);
  }

  void _shareToChat() {
    final track = _currentTrack;
    if (track == null) return;
    final card = ChatComponentCard(
      type: 'music_track',
      title: track.title,
      subtitle: track.artist,
      body: '${_libraryTitle(track.library)} 频道',
      footer: '邀请一起听',
      accent: track.accentA,
      payload: {
        'intent': 'invite',
        'mode': 'random_station',
        'source': 'music_page',
        'library': track.library,
        'library_title': _libraryTitle(track.library),
        'track': track.toJson(),
      },
    );
    Navigator.of(context).pop(CapsuleChatDraft(agentText: '', card: card));
  }

  Future<void> _endCoListeningAndBack() async {
    final conversationId = widget.session.conversationId;
    if (widget.endCoListeningOnBack &&
        _agentId.isNotEmpty &&
        conversationId != null) {
      unawaited(_endCoListeningSilently(conversationId));
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _endCoListeningSilently(String conversationId) async {
    try {
      await widget.api.endMusicCoListening(
        agentId: _agentId,
        conversationId: conversationId,
      );
    } catch (_) {
      // Leaving the player should not be blocked by co-listening presence sync.
    }
  }

  void _showFavoriteSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: false,
      builder: (context) {
        final screenHeight = MediaQuery.sizeOf(context).height;
        final topGap = MediaQuery.paddingOf(context).top + 46;
        final maxSize = ((screenHeight - topGap) / screenHeight).clamp(
          0.72,
          0.92,
        );
        return _MusicFavoritesSheetRoute(
          tracks: _favoriteTracks,
          currentTrackId: _currentTrack?.id,
          maxSize: maxSize,
          onPlay: (track) => unawaited(_playFavoriteTrack(track)),
        );
      },
    );
  }

  String _formatError(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 0) {
        return '暂时连不上音乐服务，请检查网络后重试。';
      }
      if (error.statusCode == 401 || error.statusCode == 403) {
        return '登录状态已过期，请重新登录后再听。';
      }
      if (error.statusCode == 404) {
        return '这个分类暂时没有可播放的音乐。';
      }
      if (error.statusCode >= 500) {
        return '音乐服务暂时开小差了，稍后再试一次。';
      }
      final message = error.message.trim();
      if (message.isNotEmpty &&
          !message.toLowerCase().contains('internal server error')) {
        return message;
      }
    }
    return '音乐加载失败，请稍后重试。';
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF070A10),
        body: Stack(
          children: [
            AnimatedBuilder(
              animation: _ambientController,
              builder: (context, _) {
                return _MusicBackdrop(progress: _ambientController.value);
              },
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding + 12),
                child: Column(
                  children: [
                    _MusicActions(
                      onBack: () => unawaited(_endCoListeningAndBack()),
                      onShare: _shareToChat,
                    ),
                    const SizedBox(height: 12),
                    _MusicHeader(agentName: _agentName),
                    const SizedBox(height: 12),
                    _MusicLibrarySelector(
                      libraries: _libraries,
                      selectedLibrary: _selectedLibrary,
                      onSelected: (library) =>
                          unawaited(_selectLibrary(library)),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      _MusicInlineError(message: _error!, onRetry: _load),
                    ],
                    const SizedBox(height: 12),
                    Expanded(
                      child: _MusicPlayerPanel(
                        track: _currentTrack,
                        loading:
                            _loading ||
                            _loadingTrack ||
                            _playback.isLoadingTrack(_currentTrack),
                        position: _position,
                        duration: _duration,
                        isPlaying: _isPlaying,
                        lyricsMode: _lyricsMode,
                        lyrics: _lyricsLines,
                        canGoPrevious: _canGoPrevious,
                        discAnimation: _discController,
                        waveAnimation: _waveController,
                        onToggleDisplay: _toggleDisplay,
                        onSeekStart: _beginSeek,
                        onSeekChanged: _previewSeek,
                        onSeekEnd: (progress) => unawaited(_seekTo(progress)),
                        onPrevious: () => unawaited(_previousTrack()),
                        onNext: () => unawaited(
                          _playRandom(
                            refresh: true,
                            changeSource: 'manual_next',
                          ),
                        ),
                        onTogglePlay: _togglePlay,
                        onToggleFavorite: _currentTrack == null
                            ? null
                            : () => _toggleFavorite(_currentTrack!),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _MusicHintStrip(
                      favoriteCount: _favoriteTracks.length,
                      selectedLibrary: _libraryTitle(_selectedLibrary),
                      loading: _loadingTrack,
                      onTap: _showFavoriteSheet,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _libraryTitle(String id) {
    return _libraries
        .firstWhere(
          (library) => library.id == id,
          orElse: () => MusicLibrary(id: id, title: id, subtitle: ''),
        )
        .title;
  }
}

class _MusicBackdrop extends StatelessWidget {
  const _MusicBackdrop({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final breath = Curves.easeInOutSine.transform(progress);
    final pulse = 0.5 - (0.5 - breath).abs();
    final slowDrift = (breath - 0.5) * 2;
    final counterDrift = math.sin((progress + 0.22) * math.pi * 2);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF182033), Color(0xFF0F1624), Color(0xFF070A10)],
          stops: [0, 0.52, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.68 + pulse * 0.36,
              child: Transform.scale(
                scale: 1.0 + pulse * 0.025,
                child: CustomPaint(painter: _MusicGridPainter()),
              ),
            ),
          ),
          Positioned(
            right: -122 + 56 * slowDrift,
            top: 52 + 44 * counterDrift,
            child: Opacity(
              opacity: 0.78 + pulse * 0.22,
              child: Transform.rotate(
                angle: 0.05 * slowDrift,
                child: Transform.scale(
                  scale: 0.94 + pulse * 0.16,
                  child: _MusicGlow(
                    width: 360,
                    height: 340,
                    radius: 168,
                    color: const Color(0x63276FFF),
                    blur: 18,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: -130 - 48 * slowDrift,
            top: 220 + 54 * slowDrift,
            child: Opacity(
              opacity: 0.66 + pulse * 0.28,
              child: Transform.rotate(
                angle: -0.06 * counterDrift,
                child: Transform.scale(
                  scale: 0.92 + pulse * 0.18,
                  child: _MusicGlow(
                    width: 330,
                    height: 300,
                    radius: 150,
                    color: const Color(0x5018C6C0),
                    blur: 18,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: -150 + 72 * counterDrift,
            bottom: -118 + 46 * slowDrift,
            child: Opacity(
              opacity: 0.50 + pulse * 0.28,
              child: Transform.scale(
                scale: 0.92 + pulse * 0.17,
                child: _MusicGlow(
                  width: 360,
                  height: 320,
                  radius: 170,
                  color: const Color(0x3CFFBE3D),
                  blur: 24,
                ),
              ),
            ),
          ),
          Positioned(
            left: 18 + 34 * slowDrift,
            right: 28 - 26 * counterDrift,
            bottom: 78 - 42 * slowDrift,
            child: Opacity(
              opacity: 0.36 + pulse * 0.28,
              child: Transform.scale(
                scale: 0.98 + pulse * 0.10,
                child: _MusicGlow(
                  width: 340,
                  height: 210,
                  radius: 120,
                  color: const Color(0x4611DCC4),
                  blur: 26,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MusicGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += 44) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += 68) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MusicGlow extends StatelessWidget {
  const _MusicGlow({
    required this.width,
    required this.height,
    required this.radius,
    required this.color,
    required this.blur,
  });

  final double width;
  final double height;
  final double radius;
  final Color color;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, const Color(0x2418C6C0), Colors.transparent],
          ),
        ),
      ),
    );
  }
}

class _MusicActions extends StatelessWidget {
  const _MusicActions({required this.onBack, required this.onShare});

  final VoidCallback onBack;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: onBack,
          child: const _MusicGlassButton(
            width: 54,
            height: 54,
            radius: 21,
            child: Icon(
              CupertinoIcons.chevron_left,
              color: Colors.white,
              size: 25,
            ),
          ),
        ),
        const Spacer(),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: onShare,
          child: const _MusicGlassButton(
            width: 84,
            height: 48,
            radius: 19,
            child: Text(
              '发聊天',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MusicHeader extends StatelessWidget {
  const _MusicHeader({required this.agentName});

  final String agentName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SHARED RHYTHM',
            style: TextStyle(
              color: Color(0xFF7DE7FF),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 9),
          const Text(
            '一起听一首随机歌',
            style: TextStyle(
              color: Color(0xFFF7FBFF),
              fontSize: 29,
              height: 1.03,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '选一个类别，$agentName会陪你随机播一首。收藏后，下次也能把这段旋律找回来。',
            style: const TextStyle(
              color: Color(0xA8FFFFFF),
              fontSize: 13.5,
              height: 1.62,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _MusicLibrarySelector extends StatelessWidget {
  const _MusicLibrarySelector({
    required this.libraries,
    required this.selectedLibrary,
    required this.onSelected,
  });

  final List<MusicLibrary> libraries;
  final String selectedLibrary;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = math.max(libraries.length, 1);
        const railPadding = 5.0;
        final available = constraints.maxWidth - railPadding * 2;
        final slotWidth = math.max(78.0, available / count);
        final contentWidth = slotWidth * count;
        final selectedIndex = libraries.indexWhere(
          (library) => library.id == selectedLibrary,
        );
        final activeIndex = selectedIndex < 0 ? 0 : selectedIndex;
        return ClipRRect(
          borderRadius: BorderRadius.circular(23),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 54,
              padding: const EdgeInsets.all(railPadding),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(23),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.24),
                    blurRadius: 34,
                    offset: const Offset(0, 16),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.05),
                    blurRadius: 0,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                clipBehavior: Clip.none,
                child: SizedBox(
                  width: contentWidth,
                  height: 44,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        left: activeIndex * slotWidth,
                        top: 3,
                        width: slotWidth,
                        height: 38,
                        child: const _MusicLibraryIndicator(),
                      ),
                      Row(
                        children: [
                          for (final library in libraries)
                            SizedBox(
                              width: slotWidth,
                              height: 44,
                              child: CupertinoButton(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                onPressed: () => onSelected(library.id),
                                child: Text(
                                  library.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: library.id == selectedLibrary
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.60),
                                    fontSize: 13,
                                    fontWeight: library.id == selectedLibrary
                                        ? FontWeight.w900
                                        : FontWeight.w800,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MusicLibraryIndicator extends StatelessWidget {
  const _MusicLibraryIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.18),
                  const Color(0xFF1F6FFF).withValues(alpha: 0.52),
                  const Color(0xFF18C6C0).withValues(alpha: 0.72),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF18C6C0).withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MusicInlineError extends StatelessWidget {
  const _MusicInlineError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xDFFFFFFF),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            onPressed: () => unawaited(onRetry()),
            child: const Text(
              '重试',
              style: TextStyle(
                color: Color(0xFF7DE7FF),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MusicPlayerPanel extends StatelessWidget {
  const _MusicPlayerPanel({
    required this.track,
    required this.loading,
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.lyricsMode,
    required this.lyrics,
    required this.canGoPrevious,
    required this.discAnimation,
    required this.waveAnimation,
    required this.onToggleDisplay,
    required this.onSeekStart,
    required this.onSeekChanged,
    required this.onSeekEnd,
    required this.onPrevious,
    required this.onNext,
    required this.onTogglePlay,
    required this.onToggleFavorite,
  });

  final MusicTrack? track;
  final bool loading;
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final bool lyricsMode;
  final List<String> lyrics;
  final bool canGoPrevious;
  final Animation<double> discAnimation;
  final Animation<double> waveAnimation;
  final VoidCallback onToggleDisplay;
  final ValueChanged<double> onSeekStart;
  final ValueChanged<double> onSeekChanged;
  final ValueChanged<double> onSeekEnd;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onTogglePlay;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final current = track;
    final progress = duration.inMilliseconds <= 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 580;
        final contentPadding = compact ? 14.0 : 18.0;
        final bottomPadding = compact ? 14.0 : 18.0;
        final sectionGap = compact ? 8.0 : 12.0;
        final discGap = compact ? 8.0 : 14.0;
        final waveGap = compact ? 10.0 : 16.0;
        final titleHeight = compact ? 30.0 : 32.0;
        return Container(
          padding: EdgeInsets.fromLTRB(
            contentPadding,
            contentPadding,
            contentPadding,
            bottomPadding,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF121823), Color(0xFF182B3A), Color(0xFF091119)],
              stops: [0, 0.48, 1],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.34),
                blurRadius: 80,
                offset: const Offset(0, 34),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.08),
                blurRadius: 0,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _MusicPlayerGridPainter()),
              ),
              Column(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onToggleDisplay,
                      child: LayoutBuilder(
                        builder: (context, displayConstraints) {
                          final mediaHeight = math.max(
                            0.0,
                            displayConstraints.maxHeight -
                                titleHeight -
                                discGap -
                                waveGap,
                          );
                          final discHeight = math.min(
                            compact ? 206.0 : 286.0,
                            mediaHeight * 0.60,
                          );
                          final waveHeight = math.min(
                            compact ? 82.0 : 132.0,
                            math.max(0.0, mediaHeight - discHeight),
                          );
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: lyricsMode
                                ? _MusicLyricsStage(
                                    key: const ValueKey('lyrics'),
                                    track: current,
                                    lyrics: lyrics,
                                    isPlaying: isPlaying,
                                    animation: waveAnimation,
                                  )
                                : Column(
                                    key: const ValueKey('disc-wave'),
                                    children: [
                                      SizedBox(
                                        height: discHeight,
                                        child: _MusicDiscStage(
                                          track: current,
                                          loading: loading,
                                          isPlaying: isPlaying,
                                          animation: discAnimation,
                                        ),
                                      ),
                                      SizedBox(height: discGap),
                                      SizedBox(
                                        height: titleHeight,
                                        child: Center(
                                          child: _MusicTrackInfo(
                                            track: current,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: waveGap),
                                      SizedBox(
                                        height: waveHeight,
                                        child: _MusicWaveStage(
                                          animation: waveAnimation,
                                        ),
                                      ),
                                    ],
                                  ),
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: sectionGap),
                  _MusicTransportPanel(
                    compact: compact,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MusicProgressBar(
                          position: position,
                          duration: duration,
                          progress: progress,
                          onSeekStart: onSeekStart,
                          onSeekChanged: onSeekChanged,
                          onSeekEnd: onSeekEnd,
                        ),
                        SizedBox(height: compact ? 8 : 10),
                        _MusicControlDeck(
                          isPlaying: isPlaying,
                          isFavorite: current?.isFavorite ?? false,
                          canGoPrevious: canGoPrevious,
                          loading: loading,
                          compact: compact,
                          onPrevious: onPrevious,
                          onNext: onNext,
                          onTogglePlay: onTogglePlay,
                          onToggleFavorite: onToggleFavorite,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MusicPlayerGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += 42) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MusicDiscStage extends StatelessWidget {
  const _MusicDiscStage({
    required this.track,
    required this.loading,
    required this.isPlaying,
    required this.animation,
  });

  final MusicTrack? track;
  final bool loading;
  final bool isPlaying;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(
          math.min(constraints.maxWidth, constraints.maxHeight),
          306.0,
        );
        return SizedBox.expand(
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  final angle = animation.value * math.pi * 2;
                  return Transform.rotate(angle: angle, child: child);
                },
                child: _MusicDisc(track: track, size: size),
              ),
              if (loading)
                Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                      shape: BoxShape.circle,
                    ),
                    child: const CupertinoActivityIndicator(
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MusicDisc extends StatelessWidget {
  const _MusicDisc({required this.track, required this.size});

  final MusicTrack? track;
  final double size;

  @override
  Widget build(BuildContext context) {
    final coverUrl = track?.coverImageUrl;
    final asset = track?.coverAsset;
    final coverProvider = coverUrl == null
        ? (asset == null ? null : AssetImage(asset) as ImageProvider)
        : NetworkImage(coverUrl) as ImageProvider;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.18, -0.26),
          radius: 0.78,
          colors: [
            Color(0xFF273545),
            Color(0xFF0B1118),
            Color(0xFF020405),
            Color(0xFF10151B),
          ],
          stops: [0.16, 0.48, 0.78, 1],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.48),
            blurRadius: 66,
            offset: const Offset(0, 28),
          ),
          BoxShadow(
            color: const Color(0xFF5ED8FF).withValues(alpha: 0.16),
            blurRadius: 0,
            spreadRadius: 9,
          ),
          BoxShadow(
            color: const Color(0xFF74EDFF).withValues(alpha: 0.13),
            blurRadius: 54,
            spreadRadius: -1,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.06),
            blurRadius: 0,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: CustomPaint(painter: _DiscGroovePainter())),
          Positioned.fill(child: CustomPaint(painter: _DiscSheenPainter())),
          Container(
            width: size * 0.52,
            height: size * 0.52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFF101820), Color(0xFF05080C)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.36),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
          ),
          Container(
            width: size * 0.48,
            height: size * 0.48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: coverProvider == null
                  ? null
                  : DecorationImage(image: coverProvider, fit: BoxFit.cover),
              gradient: coverProvider == null
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF9CEBFF),
                        Color(0xFF1F6FFF),
                        Color(0xFF101820),
                      ],
                    )
                  : null,
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.26),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.10),
                  blurRadius: 0,
                  spreadRadius: 1,
                ),
              ],
            ),
            foregroundDecoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.18),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.18),
                ],
                stops: const [0, 0.42, 1],
              ),
            ),
          ),
          Container(
            width: size * 0.082,
            height: size * 0.082,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFF2D3844), Color(0xFF070B10)],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.34),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscGroovePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    canvas.drawCircle(
      center,
      radius * 0.965,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = Colors.white.withValues(alpha: 0.045),
    );
    canvas.drawCircle(
      center,
      radius * 0.90,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF5ED8FF).withValues(alpha: 0.11),
    );
    for (var i = 0; i < 34; i += 1) {
      final grooveRadius = size.width * (0.19 + i * 0.011);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = i % 5 == 0 ? 1.15 : 0.75
        ..color = Colors.white.withValues(alpha: i.isEven ? 0.052 : 0.024);
      canvas.drawCircle(center, grooveRadius, paint);
    }
    for (var i = 0; i < 7; i += 1) {
      final grooveRadius = size.width * (0.34 + i * 0.035);
      canvas.drawCircle(
        center,
        grooveRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.black.withValues(alpha: 0.12),
      );
    }
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size.width * 0.43),
      -0.92,
      1.48,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF5ED8FF).withValues(alpha: 0.065),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size.width * 0.48),
      2.36,
      1.06,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.055),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DiscSheenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final clip = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius - 1));
    canvas.save();
    canvas.clipPath(clip);
    final bandPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x16FFFFFF), Colors.transparent, Color(0x0DFFFFFF)],
        stops: [0, 0.46, 1],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..blendMode = BlendMode.screen
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.42, size.height * 0.34),
        width: size.width * 0.68,
        height: size.height * 0.17,
      ),
      bandPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.82),
      -1.08,
      0.72,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.13),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.76),
      2.58,
      0.54,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF5ED8FF).withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MusicTrackInfo extends StatelessWidget {
  const _MusicTrackInfo({required this.track});

  final MusicTrack? track;

  @override
  Widget build(BuildContext context) {
    final current = track;
    return Column(
      children: [
        Text(
          current?.title ?? '正在随机取歌',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            height: 1.16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _MusicWaveStage extends StatelessWidget {
  const _MusicWaveStage({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < _MusicPageState._waveHeights.length; i += 1)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.3),
                  child: FractionallySizedBox(
                    heightFactor: _heightFactor(i),
                    alignment: Alignment.center,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFA9F5FF),
                            Color(0xFF5ED8FF),
                            Color(0xFF2178FF),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF45C6FF,
                            ).withValues(alpha: 0.32),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  double _heightFactor(int index) {
    final base = _MusicPageState._waveHeights[index] / 1.36;
    final phase = (animation.value + index * 0.09) * math.pi * 2;
    return (base * (0.74 + 0.34 * math.sin(phase))).clamp(0.18, 1.0);
  }
}

class _MusicLyricsStage extends StatelessWidget {
  const _MusicLyricsStage({
    super.key,
    required this.track,
    required this.lyrics,
    required this.isPlaying,
    required this.animation,
  });

  final MusicTrack? track;
  final List<String> lyrics;
  final bool isPlaying;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    if (lyrics.isEmpty) {
      return _MusicInstrumentalStage(
        animation: animation,
        isPlaying: isPlaying,
        isInstrumental: _isInstrumentalTrack(track),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: ShaderMask(
        shaderCallback: (bounds) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0, 0.12, 0.88, 1],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final offset = isPlaying
                ? math.sin(animation.value * math.pi * 2) * 8
                : 0.0;
            return Transform.translate(
              offset: Offset(0, offset),
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < lyrics.length; i += 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Text(
                          lyrics[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: i == 0
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.32),
                            fontSize: i == 0 ? 28 : 18,
                            height: 1.18,
                            fontWeight: i == 0
                                ? FontWeight.w900
                                : FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static bool _isInstrumentalTrack(MusicTrack? track) {
    final metadata = track?.metadata;
    if (metadata == null || metadata.isEmpty) return false;
    final direct = _metadataText(metadata['vocalinstrumental']);
    if (direct != null) return direct == 'instrumental';
    final raw = metadata['raw'];
    if (raw is Map) {
      final musicInfo = raw['musicinfo'];
      if (musicInfo is Map) {
        final nested = _metadataText(musicInfo['vocalinstrumental']);
        if (nested != null) return nested == 'instrumental';
      }
    }
    return false;
  }

  static String? _metadataText(Object? value) {
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text.isEmpty || text == 'null' ? null : text;
  }
}

class _MusicInstrumentalStage extends StatelessWidget {
  const _MusicInstrumentalStage({
    required this.animation,
    required this.isPlaying,
    required this.isInstrumental,
  });

  final Animation<double> animation;
  final bool isPlaying;
  final bool isInstrumental;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final phase = animation.value * math.pi * 2;
        final pulse = isPlaying ? (0.5 + math.sin(phase) * 0.5) : 0.42;
        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 380;
            final orbSize = compact ? 148.0 : 184.0;
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isInstrumental ? 'INSTRUMENTAL' : 'NO LYRICS',
                    style: TextStyle(
                      color: const Color(0xFF7DE7FF).withValues(alpha: 0.92),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.4,
                    ),
                  ),
                  SizedBox(height: compact ? 18 : 24),
                  SizedBox(
                    width: orbSize,
                    height: orbSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        for (var i = 0; i < 4; i += 1)
                          Transform.scale(
                            scale: 0.68 + i * 0.13 + pulse * 0.10,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(
                                    0xFF5ED8FF,
                                  ).withValues(alpha: 0.18 - i * 0.03),
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        Container(
                          width: orbSize * 0.70,
                          height: orbSize * 0.70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFF8EE7FF).withValues(alpha: 0.86),
                                const Color(
                                  0xFF1F6FFF,
                                ).withValues(alpha: 0.34 + pulse * 0.16),
                                const Color(0xFF061018).withValues(alpha: 0.92),
                              ],
                              stops: const [0, 0.48, 1],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF18C6C0,
                                ).withValues(alpha: 0.20 + pulse * 0.18),
                                blurRadius: 34 + pulse * 18,
                                spreadRadius: 2 + pulse * 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            CupertinoIcons.music_note_2,
                            color: Colors.white,
                            size: 52,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: compact ? 22 : 28),
                  Text(
                    isInstrumental ? '纯音乐片段' : '暂未收录歌词',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: compact ? 22 : 25,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isInstrumental ? '没有歌词，跟着旋律呼吸就好' : '这首歌暂时没有歌词文本',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.48),
                      fontSize: 13,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _MusicTransportPanel extends StatelessWidget {
  const _MusicTransportPanel({required this.compact, required this.child});

  final bool compact;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, compact ? 8 : 10, 12, compact ? 10 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFF071018).withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MusicProgressBar extends StatelessWidget {
  const _MusicProgressBar({
    required this.position,
    required this.duration,
    required this.progress,
    required this.onSeekStart,
    required this.onSeekChanged,
    required this.onSeekEnd,
  });

  final Duration position;
  final Duration duration;
  final double progress;
  final ValueChanged<double> onSeekStart;
  final ValueChanged<double> onSeekChanged;
  final ValueChanged<double> onSeekEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 28,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: const Color(0xFF5ED8FF),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.16),
              thumbColor: Colors.white,
              overlayColor: const Color(0xFF5ED8FF).withValues(alpha: 0.16),
            ),
            child: Slider(
              min: 0,
              max: 1,
              value: progress.clamp(0.0, 1.0),
              onChangeStart: onSeekStart,
              onChanged: onSeekChanged,
              onChangeEnd: onSeekEnd,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_time(position), style: _timeStyle),
              const Text('标准音质', style: _timeStyle),
              Text(_time(duration), style: _timeStyle),
            ],
          ),
        ),
      ],
    );
  }

  static const _timeStyle = TextStyle(
    color: Color(0xA8FFFFFF),
    fontSize: 10.5,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
  );

  static String _time(Duration duration) {
    final seconds = duration.inSeconds.clamp(0, 24 * 60 * 60).toInt();
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }
}

class _MusicControlDeck extends StatelessWidget {
  const _MusicControlDeck({
    required this.isPlaying,
    required this.isFavorite,
    required this.canGoPrevious,
    required this.loading,
    required this.compact,
    required this.onPrevious,
    required this.onNext,
    required this.onTogglePlay,
    required this.onToggleFavorite,
  });

  final bool isPlaying;
  final bool isFavorite;
  final bool canGoPrevious;
  final bool loading;
  final bool compact;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onTogglePlay;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final playSize = compact ? 56.0 : 68.0;
    final playIconSize = compact ? 26.0 : 30.0;
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: _PlayerIconButton(
              icon: CupertinoIcons.heart_fill,
              color: isFavorite
                  ? const Color(0xFF5ED8FF)
                  : Colors.white.withValues(alpha: 0.74),
              onPressed: onToggleFavorite,
            ),
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.center,
            child: _PlayerIconButton(
              icon: CupertinoIcons.backward_fill,
              onPressed: canGoPrevious && !loading ? onPrevious : null,
            ),
          ),
        ),
        SizedBox(
          width: playSize + (compact ? 18 : 24),
          child: Center(
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: loading ? null : onTogglePlay,
              child: Container(
                width: playSize,
                height: playSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF8EE7FF), Color(0xFF1F6FFF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1F6FFF).withValues(alpha: 0.30),
                      blurRadius: 34,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Center(
                  child: loading
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : isPlaying
                      ? Icon(
                          CupertinoIcons.pause_fill,
                          color: Colors.white,
                          size: compact ? 27 : 31,
                        )
                      : Transform.translate(
                          offset: const Offset(2, 0),
                          child: Icon(
                            CupertinoIcons.play_fill,
                            color: Colors.white,
                            size: playIconSize,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.center,
            child: _PlayerIconButton(
              icon: CupertinoIcons.forward_fill,
              onPressed: loading ? null : onNext,
            ),
          ),
        ),
        const Expanded(child: SizedBox.shrink()),
      ],
    );
  }
}

class _PlayerIconButton extends StatelessWidget {
  const _PlayerIconButton({
    required this.icon,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: Icon(
        icon,
        color: enabled
            ? color ?? Colors.white.withValues(alpha: 0.78)
            : Colors.white.withValues(alpha: 0.22),
        size: 28,
      ),
    );
  }
}

class _MusicHintStrip extends StatelessWidget {
  const _MusicHintStrip({
    required this.favoriteCount,
    required this.selectedLibrary,
    required this.loading,
    required this.onTap,
  });

  final int favoriteCount;
  final String selectedLibrary;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  loading
                      ? CupertinoIcons.shuffle
                      : CupertinoIcons.music_note_2,
                  color: const Color(0xFF7DE7FF),
                  size: 22,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    loading
                        ? '正在从 $selectedLibrary 随机取一首'
                        : '$selectedLibrary 频道 · 收藏 $favoriteCount 首',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xDFFFFFFF),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  CupertinoIcons.chevron_up,
                  color: Color(0x78FFFFFF),
                  size: 17,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MusicFavoritesSheetRoute extends StatefulWidget {
  const _MusicFavoritesSheetRoute({
    required this.tracks,
    required this.currentTrackId,
    required this.maxSize,
    required this.onPlay,
  });

  static const initialSize = 0.42;

  final List<MusicTrack> tracks;
  final String? currentTrackId;
  final double maxSize;
  final ValueChanged<MusicTrack> onPlay;

  @override
  State<_MusicFavoritesSheetRoute> createState() =>
      _MusicFavoritesSheetRouteState();
}

class _MusicFavoritesSheetRouteState extends State<_MusicFavoritesSheetRoute> {
  late final DraggableScrollableController _sheetController;
  late final ValueNotifier<double> _expansionProgress;

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
    _expansionProgress = ValueNotifier<double>(0);
    _sheetController.addListener(_updateExpansionProgress);
  }

  @override
  void dispose() {
    _sheetController.removeListener(_updateExpansionProgress);
    _sheetController.dispose();
    _expansionProgress.dispose();
    super.dispose();
  }

  void _updateExpansionProgress() {
    if (!_sheetController.isAttached) return;
    final denominator = widget.maxSize - _MusicFavoritesSheetRoute.initialSize;
    if (denominator <= 0) return;
    final progress =
        ((_sheetController.size - _MusicFavoritesSheetRoute.initialSize) /
                denominator)
            .clamp(0.0, 1.0);
    if ((progress - _expansionProgress.value).abs() > 0.005) {
      _expansionProgress.value = progress;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      expand: false,
      initialChildSize: _MusicFavoritesSheetRoute.initialSize,
      minChildSize: 0.32,
      maxChildSize: widget.maxSize,
      snap: true,
      snapSizes: [_MusicFavoritesSheetRoute.initialSize, widget.maxSize],
      builder: (context, scrollController) {
        return _MusicFavoritesSheet(
          tracks: widget.tracks,
          currentTrackId: widget.currentTrackId,
          scrollController: scrollController,
          expansionProgress: _expansionProgress,
          onPlay: widget.onPlay,
        );
      },
    );
  }
}

class _MusicFavoritesSheet extends StatelessWidget {
  const _MusicFavoritesSheet({
    required this.tracks,
    required this.currentTrackId,
    required this.scrollController,
    required this.expansionProgress,
    required this.onPlay,
  });

  final List<MusicTrack> tracks;
  final String? currentTrackId;
  final ScrollController scrollController;
  final ValueListenable<double> expansionProgress;
  final ValueChanged<MusicTrack> onPlay;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return ValueListenableBuilder<double>(
      valueListenable: expansionProgress,
      builder: (context, progress, child) {
        final horizontalMargin = lerpDouble(12, 0, progress)!;
        final bottomMargin = lerpDouble(12, 0, progress)!;
        final bottomRadius = lerpDouble(30, 0, progress)!;
        return Container(
          margin: EdgeInsets.fromLTRB(
            horizontalMargin,
            0,
            horizontalMargin,
            bottomMargin,
          ),
          padding: EdgeInsets.fromLTRB(16, 10, 16, bottomPadding + 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF182033), Color(0xFF0D1420), Color(0xFF070A10)],
            ),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(30),
              bottom: Radius.circular(bottomRadius),
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.40),
                blurRadius: 48,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: CustomScrollView(
            controller: scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.heart_fill,
                          color: Color(0xFF5ED8FF),
                          size: 23,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            '我的收藏',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        Text(
                          '${tracks.length} 首',
                          style: const TextStyle(
                            color: Color(0x8CFFFFFF),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
              if (tracks.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(10, 22, 10, 30),
                    child: Text(
                      '还没有收藏歌曲。播放时点爱心，这里就会出现你的歌单。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0x8CFFFFFF),
                        fontSize: 14,
                        height: 1.5,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                )
              else
                SliverList.separated(
                  itemCount: tracks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    final selected = track.id == currentTrackId;
                    return _FavoriteTrackTile(
                      track: track,
                      selected: selected,
                      onTap: () => onPlay(track),
                    );
                  },
                ),
              SliverToBoxAdapter(child: SizedBox(height: bottomPadding + 8)),
            ],
          ),
        );
      },
    );
  }
}

class _FavoriteTrackTile extends StatelessWidget {
  const _FavoriteTrackTile({
    required this.track,
    required this.selected,
    required this.onTap,
  });

  final MusicTrack track;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0x3318C6C0)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? const Color(0x665ED8FF)
                : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Row(
          children: [
            _FavoriteDisc(track: track, selected: selected),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.durationLabel,
                    style: const TextStyle(
                      color: Color(0x8CFFFFFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? CupertinoIcons.play_circle_fill
                  : CupertinoIcons.play_circle,
              color: selected
                  ? const Color(0xFF7DE7FF)
                  : Colors.white.withValues(alpha: 0.38),
              size: 26,
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteDisc extends StatelessWidget {
  const _FavoriteDisc({required this.track, required this.selected});

  final MusicTrack track;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final coverUrl = track.coverImageUrl;
    final coverProvider = coverUrl == null
        ? AssetImage(track.coverAsset) as ImageProvider
        : NetworkImage(coverUrl) as ImageProvider;
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFF22313F), Color(0xFF071018), Color(0xFF020507)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF1F6FFF,
            ).withValues(alpha: selected ? 0.25 : 0.10),
            blurRadius: selected ? 18 : 12,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(image: coverProvider, fit: BoxFit.cover),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
        ),
      ),
    );
  }
}

class _MusicGlassButton extends StatelessWidget {
  const _MusicGlassButton({
    required this.width,
    required this.height,
    required this.radius,
    required this.child,
  });

  final double width;
  final double height;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 42,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
