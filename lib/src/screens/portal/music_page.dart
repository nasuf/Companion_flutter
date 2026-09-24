part of 'package:companion_flutter/main.dart';

class MusicPage extends StatefulWidget {
  const MusicPage({
    super.key,
    required this.api,
    required this.session,
    this.initialTrack,
  });

  final CompanionApi api;
  final AuthSession session;
  final MusicTrack? initialTrack;

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
  StreamSubscription<MusicQuotaReport>? _quotaSub;

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
  bool _loadArmed = false;

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
    _playback.configureQuota(widget.api);
    _completeSub = _playback.completed.listen((_) {
      if (mounted && _loadArmed) {
        unawaited(_playRandom(refresh: true, changeSource: 'auto_next'));
      }
    });
    _quotaSub = _playback.quotaEvents.listen(_handleMusicQuotaEvent);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadArmed || !RouteSettled.of(context)) return;
    _loadArmed = true;
    // Singleton playback can already be running. Sync after the slide so
    // that listener setState does not rebuild during the Cupertino push.
    _handlePlaybackChanged();
    unawaited(_load());
  }

  @override
  void dispose() {
    _completeSub?.cancel();
    _quotaSub?.cancel();
    _playback.removeListener(_handlePlaybackChanged);
    _ambientController.dispose();
    _discController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  /// CLAUDE.md 权益项 6: 控制器已暂停播放, 这里只负责按 action 弹对应的框
  /// 并把结果回传给控制器决定是否恢复播放。
  Future<void> _handleMusicQuotaEvent(MusicQuotaReport report) async {
    if (!mounted || !_loadArmed) return;
    switch (report.action) {
      case MusicQuotaAction.confirmTicket:
        final confirmed = await showMusicOverageConfirmDialog(
          context,
          ticketCost: report.ticketCost,
        );
        await _playback.resolveQuotaPrompt(confirmed: confirmed);
      case MusicQuotaAction.buyCoupon:
        await _playback.resolveQuotaPrompt(confirmed: false);
        if (!mounted) return;
        await showBuyMusicCouponDialog(
          context,
          api: widget.api,
          session: widget.session,
        );
      case MusicQuotaAction.buyVip:
        await _playback.resolveQuotaPrompt(confirmed: false);
        if (!mounted) return;
        await showVipUpsellDialog(
          context,
          api: widget.api,
          session: widget.session,
          content: '今日免费听歌时长已用完，订阅 VIP 可获得每月畅听券和更低价格，是否订阅？',
        );
      case MusicQuotaAction.none:
        break;
    }
  }

  void _handlePlaybackChanged() {
    if (!mounted || !_loadArmed) return;
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
    if (_error != null || !_loading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
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

  void _goBack() {
    if (mounted) Navigator.of(context).pop();
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
                    _MusicActions(onBack: _goBack, onShare: _shareToChat),
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
