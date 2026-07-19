part of 'package:companion_flutter/main.dart';

enum ComposerPanel { none, emoji, more }

class VoiceRecordingOverlaySnapshot {
  const VoiceRecordingOverlaySnapshot({
    required this.action,
    required this.seconds,
    required this.preparing,
    required this.amplitude,
  });

  final VoiceReleaseAction action;
  final int seconds;
  final bool preparing;
  final ValueListenable<double> amplitude;
}

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.api,
    required this.session,
    required this.isActive,
    required this.onOpenSidebar,
    this.onAchievementDetailRequested,
    this.onAchievementOverlayChanged,
    this.onVoiceRecordingOverlayChanged,
    this.onComposerPanelChanged,
  });

  final CompanionApi api;
  final AuthSession session;
  final bool isActive;
  final VoidCallback onOpenSidebar;
  final ValueChanged<AchievementItem>? onAchievementDetailRequested;
  final ValueChanged<bool>? onAchievementOverlayChanged;
  final ValueChanged<VoiceRecordingOverlaySnapshot?>?
  onVoiceRecordingOverlayChanged;

  /// Reports whether the emoji / more panel is up, so the shell can hide the
  /// floating tab bar (the panel docks to the screen bottom like a keyboard).
  final ValueChanged<bool>? onComposerPanelChanged;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _PendingChatImage {
  const _PendingChatImage({required this.localPath, required this.attachment});

  final String localPath;
  final ChatAttachment attachment;
}

class _PendingLinkPreview {
  const _PendingLinkPreview({required this.preview, required this.sourceText});

  final ChatLinkCardResponse preview;
  final String sourceText;
}

Future<void> _openExternalLinkPayload(
  Map<String, dynamic> payload, {
  String? fallbackFinalUrl,
  String? fallbackSourceUrl,
}) async {
  final finalUrl = payload['final_url']?.toString() ?? fallbackFinalUrl;
  final sourceUrl = payload['source_url']?.toString() ?? fallbackSourceUrl;
  final candidates = [
    payload['app_url']?.toString() ??
        _externalLinkAppUrlFromPayload(payload, finalUrl, sourceUrl),
    finalUrl,
    sourceUrl,
  ];
  for (final raw in candidates) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) continue;
    final uri = Uri.tryParse(value);
    if (uri == null) continue;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened) return;
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      final fallbackOpened = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );
      if (fallbackOpened) return;
    }
  }
}

String? _externalLinkAppUrlFromPayload(
  Map<String, dynamic> payload,
  String? finalUrl,
  String? sourceUrl,
) {
  final platform = payload['platform']?.toString();
  final url =
      ((finalUrl?.trim().isNotEmpty ?? false) ? finalUrl : sourceUrl) ?? '';
  String? firstMatch(String pattern) =>
      RegExp(pattern).firstMatch(url)?.group(1);
  switch (platform) {
    case '今日头条':
      final articleId = firstMatch(r'/article/(\d+)');
      return articleId == null ? null : 'snssdk141://detail?groupid=$articleId';
    case '微博':
      final matches = RegExp(r'/(\d{10,})(?=[/?#]|$)').allMatches(url).toList();
      if (matches.isEmpty) return null;
      return 'sinaweibo://detail?mblogid=${matches.last.group(1)}';
    case '抖音':
      final videoId = firstMatch(r'/video/(\d+)');
      return videoId == null ? null : 'snssdk1128://aweme/detail/$videoId';
    case '知乎':
      final answerId = firstMatch(r'/answer/(\d+)');
      if (answerId != null) return 'zhihu://answers/$answerId';
      final questionId = firstMatch(r'/question/(\d+)');
      return questionId == null ? null : 'zhihu://questions/$questionId';
    case '小红书':
      final noteId = firstMatch(r'/(?:explore|discovery/item)/([0-9a-fA-F]+)');
      return noteId == null ? null : 'xhsdiscover://item/$noteId';
    case 'B站':
      final bvid =
          firstMatch(r'/video/(BV[0-9A-Za-z]+)') ??
          firstMatch(r'\b(BV[0-9A-Za-z]{8,})\b');
      return bvid == null ? null : 'bilibili://video/$bvid';
    default:
      return null;
  }
}

Map<String, String>? _mediaHeadersForUrl(String? url, String? authToken) {
  final value = url?.trim();
  if (value == null || value.isEmpty || authToken?.isNotEmpty != true) {
    return null;
  }
  final uri = Uri.tryParse(value);
  final path = uri?.path ?? value;
  final mediaPath = path.startsWith('/api/') ? path.substring(4) : path;
  if (!mediaPath.startsWith('/chat/media/') &&
      !mediaPath.startsWith('/offline/media/')) {
    return null;
  }
  return {'Authorization': 'Bearer $authToken'};
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  static const _animationDuration = Duration(milliseconds: 260);
  static const _animationCurve = Curves.easeOutCubic;
  static const _composerMinHeight = 68.0;
  static const _composerLineHeight = 22.0;
  static const _tabBarContentHeight = 64.0;
  static const _composerPanelHeight = 236.0;
  static const _messagePageSize = 100;
  static const _loadOlderThreshold = 80.0;
  static const _maxVoiceSeconds = 60;
  static const _maxVoiceBytes = 2 * 1024 * 1024;
  static final _supportedSharedLinkPattern = RegExp(
    r'(?:https?:\/\/)?(?:[\w-]+\.)?(?:xhslink\.com|xiaohongshu\.com|v\.douyin\.com|douyin\.com|iesdouyin\.com|weibo\.com|weibo\.cn|t\.cn|toutiao\.com|snssdk\.com|zhihu\.com|zhuanlan\.zhihu\.com|b23\.tv|bilibili\.com)\/[^\s，。；：）】》]+',
    caseSensitive: false,
  );

  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  final _inputFocus = FocusNode();
  final _imagePicker = ImagePicker();
  final _voiceRecorder = AudioRecorder();
  final ValueNotifier<double> _voiceAmplitude = ValueNotifier(0.12);
  final _playback = MusicPlaybackController.instance;
  final _stationCardKey = GlobalKey(debugLabel: 'chat-station-card');
  final _musicStation = ChatMusicStationState();
  final List<ChatMessage> _messages = [];

  ChatSocket? _socket;
  StreamSubscription<WsEnvelope>? _eventSub;
  StreamSubscription<ChatSocketState>? _stateSub;
  StreamSubscription<void>? _musicCompleteSub;
  StreamSubscription<List<SharedMediaFile>>? _shareIntentSub;
  ComposerPanel _panel = ComposerPanel.none;
  ComposerPanel _heldPanel = ComposerPanel.none;
  // The panel type kept on screen during a slide-out (the panel translates off
  // the bottom before its content is dropped), so the closing animation still
  // renders real content instead of blanking instantly.
  ComposerPanel _lastDisplayedPanel = ComposerPanel.none;
  bool _notifiedComposerPanelVisible = false;
  Timer? _panelHoldTimer;
  Timer? _voiceTimer;
  StreamSubscription<Amplitude>? _voiceAmplitudeSub;
  Timer? _capsuleScanTimer;
  Timer? _conversationMetaTimer;
  TimeCapsule? _readyCapsule;
  String? _autoShownReadyCapsuleId;
  String? _dismissedReadyCapsuleId;
  bool _readyCapsuleNoticeShowing = false;
  Conversation? _conversationMeta;
  bool _loadingInitial = true;
  bool _loadingOlder = false;
  bool _hasOlderMessages = false;
  bool _sending = false;
  String? _historyError;
  int _loadedServerMessages = 0;
  double? _lastListBottomPadding;
  double _lastKeyboardInset = 0;
  // Tallest keyboard inset seen during the current focus session. Used to hold
  // the composer steady when the iOS composing-letters strip toggles the
  // keyboard height mid-typing (see build).
  double _keyboardSessionMaxInset = 0;
  bool _pinToBottomDuringKeyboard = false;
  bool _wasNearBottomBeforePaddingChange = true;
  int _newMessageCount = 0;
  ({
    String text,
    String clientId,
    ChatComponentCard? componentCard,
    List<ChatAttachment> attachments,
  })?
  _pendingSend;
  final List<_PendingChatImage> _pendingImages = [];
  _PendingLinkPreview? _pendingLinkPreview;
  bool _uploadingImage = false;
  bool _preparingVoice = false;
  bool _recordingVoice = false;
  bool _transcribingVoice = false;
  bool _voiceInputMode = false;
  bool _agentTyping = false;
  bool _voiceGestureActive = false;
  int _voiceSeconds = 0;
  int _voiceAmplitudeSampleCount = 0;
  int _voiceActiveMilliseconds = 0;
  DateTime? _voiceRecordingStartedAt;
  VoiceReleaseAction _voiceReleaseAction = VoiceReleaseAction.sendVoice;
  VoiceReleaseAction? _pendingVoiceReleaseAction;
  String? _linkPreviewInFlightText;
  String? _ignoredInputPromotionText;
  String _lastInputText = '';
  int _achievementDemoIndex = 0;
  bool _stationCardDocked = false;
  bool _stationDockActive = false;
  bool _stationDockCheckScheduled = false;
  bool _advancingStation = false;
  bool _openingMusicPage = false;
  bool _localUserCoListeningActive = false;
  Timer? _stationPauseTimer;
  final Set<String> _favoriteMusicTrackIds = {};
  final Set<String> _busyMusicFavoriteIds = {};

  String get _conversationId => widget.session.conversationId!;

  String? get _agentAvatarUrl {
    final explicit = widget.session.agentAvatarUrl?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final key = widget.session.agentAvatarKey?.trim();
    if (key == null || key.isEmpty) return null;
    return '${widget.api.baseUrl}/agents/avatar/${Uri.encodeComponent(key)}.png';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_handleScroll);
    _inputController.addListener(_handleInputChanged);
    _playback.addListener(_handleStationPlaybackChanged);
    _musicCompleteSub = _playback.completed.listen((_) {
      if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
      final completedTrack = _playback.track;
      if (_musicStation.library == null ||
          completedTrack?.library != _musicStation.library) {
        return;
      }
      unawaited(_playNextStationTrack(auto: true));
    });
    _bootstrapChat();
  }

  @override
  void didUpdateWidget(covariant ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.conversationId != widget.session.conversationId ||
        oldWidget.api.baseUrl != widget.api.baseUrl) {
      _bootstrapChat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Release the shell's hidden tab bar if we die while a panel is docked
    // (deferred: notifying an ancestor synchronously from dispose is unsafe).
    final panelCallback = widget.onComposerPanelChanged;
    if (_notifiedComposerPanelVisible && panelCallback != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        panelCallback(false);
      });
    }
    _scrollController.removeListener(_handleScroll);
    _inputController.removeListener(_handleInputChanged);
    _playback.removeListener(_handleStationPlaybackChanged);
    _scrollController.dispose();
    _inputController.dispose();
    _inputFocus.dispose();
    _eventSub?.cancel();
    _stateSub?.cancel();
    _socket?.close();
    _panelHoldTimer?.cancel();
    _voiceTimer?.cancel();
    _voiceAmplitudeSub?.cancel();
    _voiceAmplitude.dispose();
    _capsuleScanTimer?.cancel();
    _conversationMetaTimer?.cancel();
    _stationPauseTimer?.cancel();
    _musicCompleteSub?.cancel();
    _shareIntentSub?.cancel();
    unawaited(_voiceRecorder.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      if (_preparingVoice || _recordingVoice) {
        unawaited(_cancelVoiceRecording());
      }
      return;
    }
    unawaited(_scanReadyCapsules());
    unawaited(_refreshConversationMeta());
    _scheduleNextCapsuleScan();
  }

  double _panelHeightFor(ComposerPanel panel) {
    return switch (panel) {
      ComposerPanel.emoji || ComposerPanel.more => _composerPanelHeight,
      ComposerPanel.none => 0,
    };
  }

  void _handleInputChanged() {
    if (mounted) {
      final previousText = _lastInputText;
      final currentText = _inputController.text;
      _lastInputText = currentText;
      setState(() {});
      unawaited(
        _maybePromoteInputLinkToPendingCard(
          previousText: previousText,
          currentText: currentText,
        ),
      );
    }
  }

  Future<void> _bootstrapChat() async {
    if (_preparingVoice || _recordingVoice) {
      await _cancelVoiceRecording();
    }
    await _eventSub?.cancel();
    await _stateSub?.cancel();
    await _shareIntentSub?.cancel();
    _shareIntentSub = null;
    await _socket?.close();
    _panelHoldTimer?.cancel();
    _capsuleScanTimer?.cancel();
    _conversationMetaTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _messages.clear();
      _pendingImages.clear();
      _pendingLinkPreview = null;
      _linkPreviewInFlightText = null;
      _lastInputText = _inputController.text;
      _panel = ComposerPanel.none;
      _heldPanel = ComposerPanel.none;
      _loadingInitial = true;
      _loadingOlder = false;
      _hasOlderMessages = false;
      _loadedServerMessages = 0;
      _historyError = null;
      _newMessageCount = 0;
      _pendingSend = null;
      _uploadingImage = false;
      _preparingVoice = false;
      _recordingVoice = false;
      _transcribingVoice = false;
      _voiceInputMode = false;
      _agentTyping = false;
      _voiceGestureActive = false;
      _voiceSeconds = 0;
      _voiceAmplitudeSampleCount = 0;
      _voiceActiveMilliseconds = 0;
      _voiceRecordingStartedAt = null;
      _readyCapsule = null;
      _conversationMeta = null;
      _musicStation.reset();
      _stationCardDocked = false;
      _stationDockActive = false;
      _stationDockCheckScheduled = false;
      _advancingStation = false;
      _openingMusicPage = false;
      _localUserCoListeningActive = false;
      _stationPauseTimer?.cancel();
      _stationPauseTimer = null;
      _favoriteMusicTrackIds.clear();
      _busyMusicFavoriteIds.clear();
    });
    _syncVoiceRecordingOverlay();
    widget.onAchievementOverlayChanged?.call(false);
    await Future.wait([
      _loadLatestMessages(showLoading: true),
      _refreshConversationMeta(),
      _loadMusicFavorites(),
    ]);
    unawaited(_scanReadyCapsules());
    _scheduleNextCapsuleScan();
    _scheduleConversationMetaRefresh();
    _connectSocket();
    unawaited(_listenForSharedLinks());
  }

  void _scheduleConversationMetaRefresh() {
    _conversationMetaTimer?.cancel();
    _conversationMetaTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(_refreshConversationMeta());
    });
  }

  Future<void> _refreshConversationMeta() async {
    try {
      final conversation = await widget.api.getConversation(_conversationId);
      if (!mounted) return;
      setState(() => _conversationMeta = conversation);
    } catch (_) {
      // Header metadata is decorative; chat should continue when it fails.
    }
  }

  void _connectSocket() {
    final socket = ChatSocket(
      baseUrl: widget.api.baseUrl,
      conversationId: _conversationId,
    );
    _socket = socket;
    _stateSub = socket.states.listen((state) {
      if (!mounted) return;
      switch (state.status) {
        case ChatSocketStatus.connecting:
          break;
        case ChatSocketStatus.open:
          final pending = _pendingSend;
          if (pending != null) {
            socket.sendMessage(
              pending.text,
              pending.clientId,
              componentCard: pending.componentCard,
              attachments: pending.attachments,
            );
            _pendingSend = null;
          }
          // A reconnect may have missed the reply that would clear the typing
          // indicator; reconciling history below restores the true state.
          if (_agentTyping) setState(() => _agentTyping = false);
          _loadLatestMessages(showLoading: false);
        case ChatSocketStatus.error:
          break;
        case ChatSocketStatus.closed:
          break;
        case ChatSocketStatus.disconnected:
          break;
      }
    });
    _eventSub = socket.events.listen(_handleWsEvent);
    unawaited(socket.connect());
  }

  Future<void> _listenForSharedLinks() async {
    try {
      final initial = await ReceiveSharingIntent.instance.getInitialMedia();
      if (initial.isNotEmpty) {
        await _handleSharedMedia(initial);
        await ReceiveSharingIntent.instance.reset();
      }
      _shareIntentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
        (files) => unawaited(_handleSharedMedia(files)),
      );
    } catch (error) {
      debugPrint('Share intent unavailable: $error');
    }
  }

  Future<void> _handleSharedMedia(List<SharedMediaFile> files) async {
    final text = _sharedTextFromMedia(files);
    if (text.trim().isEmpty || !mounted) return;
    await _stageSharedLinkText(text, sourceApp: 'system_share_sheet');
  }

  Future<void> _maybePromoteInputLinkToPendingCard({
    required String previousText,
    required String currentText,
  }) async {
    if (!mounted ||
        _pendingLinkPreview != null ||
        _linkPreviewInFlightText != null) {
      return;
    }
    final insertedText = _insertedInputText(
      previous: previousText,
      current: currentText,
    );
    final ignoredText = _ignoredInputPromotionText;
    if (ignoredText != null) {
      _ignoredInputPromotionText = null;
      if (insertedText == ignoredText ||
          currentText == ignoredText ||
          currentText.contains(ignoredText)) {
        return;
      }
    }
    final insertedMatch = _firstSupportedSharedLink(insertedText);
    final sourceText = insertedMatch == null ? currentText : insertedText;
    final match = insertedMatch ?? _firstSupportedSharedLink(currentText);
    if (match == null) return;
    await _stageSharedLinkText(
      sourceText,
      sourceApp: 'manual_paste',
      linkText: match,
      stripText: insertedMatch == null ? match : insertedText,
      stripFromInput: true,
    );
  }

  Future<void> _stageSharedLinkText(
    String text, {
    required String sourceApp,
    String? linkText,
    String? stripText,
    bool stripFromInput = false,
    bool showError = true,
    bool requireAppPlatform = false,
  }) async {
    final match = linkText ?? _firstSupportedSharedLink(text);
    if (match == null || !mounted) return;
    if (_linkPreviewInFlightText != null) return;
    _linkPreviewInFlightText = match;
    setState(() {
      _historyError = null;
      _panel = ComposerPanel.none;
    });
    try {
      final preview = await widget.api.previewChatLink(
        conversationId: _conversationId,
        sharedText: text,
        sourceApp: sourceApp,
      );
      if (!mounted) return;
      if (requireAppPlatform && !_isSupportedAppLinkPreview(preview)) {
        return;
      }
      if (stripFromInput) {
        final currentText = _inputController.text;
        if (!_textContainsSharedLink(currentText, match)) return;
        _removeSharedLinkFromInput(stripText ?? match);
      }
      setState(() {
        _pendingLinkPreview = _PendingLinkPreview(
          preview: preview,
          sourceText: match,
        );
        _historyError = null;
        _panel = ComposerPanel.none;
      });
      _inputFocus.requestFocus();
    } catch (error) {
      debugPrint('Link preview failed: $error');
      if (mounted && showError) {
        setState(() => _historyError = _asMessage(error));
      }
    } finally {
      if (_linkPreviewInFlightText == match) {
        _linkPreviewInFlightText = null;
        if (mounted) setState(() {});
      }
    }
  }

  Future<bool> _handleComposerPasteText(String text) async {
    if (!mounted || text.trim().isEmpty) return false;
    final match = _firstSupportedSharedLink(text);
    if (match == null) return false;
    final before = _pendingLinkPreview;
    await _stageSharedLinkText(
      text,
      sourceApp: 'manual_paste',
      linkText: match,
      showError: false,
      requireAppPlatform: true,
    );
    final consumed =
        mounted && _pendingLinkPreview != null && _pendingLinkPreview != before;
    if (!consumed) {
      _ignoredInputPromotionText = text;
    }
    return consumed;
  }

  bool _isSupportedAppLinkPreview(ChatLinkCardResponse preview) {
    return const {
      '小红书',
      '微博',
      '今日头条',
      '抖音',
      '知乎',
      'B站',
    }.contains(preview.platform.trim());
  }

  String? _firstSupportedSharedLink(String text) {
    final match = _supportedSharedLinkPattern.firstMatch(text);
    return match?.group(0)?.trim();
  }

  bool _textContainsSharedLink(String text, String link) {
    return text.contains(link) || _supportedSharedLinkPattern.hasMatch(text);
  }

  String _insertedInputText({
    required String previous,
    required String current,
  }) {
    if (previous.isEmpty || current.length <= previous.length) return current;
    var prefix = 0;
    final maxPrefix = math.min(previous.length, current.length);
    while (prefix < maxPrefix &&
        previous.codeUnitAt(prefix) == current.codeUnitAt(prefix)) {
      prefix += 1;
    }
    var suffix = 0;
    while (suffix < previous.length - prefix &&
        suffix < current.length - prefix &&
        previous.codeUnitAt(previous.length - 1 - suffix) ==
            current.codeUnitAt(current.length - 1 - suffix)) {
      suffix += 1;
    }
    return current.substring(prefix, current.length - suffix);
  }

  void _removeSharedLinkFromInput(String textToRemove) {
    final stripped = _stripSharedLinkFromText(
      _inputController.text,
      textToRemove,
    );
    _lastInputText = stripped;
    _inputController.value = TextEditingValue(
      text: stripped,
      selection: TextSelection.collapsed(offset: stripped.length),
    );
  }

  String _stripSharedLinkFromText(String text, String textToRemove) {
    final withoutLink = text.replaceFirst(textToRemove, ' ');
    return withoutLink
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .replaceAll(RegExp(r' *\n *'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  String _sharedTextFromMedia(List<SharedMediaFile> files) {
    final parts = <String>[];
    for (final file in files) {
      final path = file.path.trim();
      if (path.isNotEmpty) parts.add(path);
      final message = file.message?.trim();
      if (message != null && message.isNotEmpty) parts.add(message);
    }
    return parts.toSet().join('\n');
  }

  Future<void> _loadLatestMessages({required bool showLoading}) async {
    final hadScrollPosition = _scrollController.hasClients;
    final oldPixels = hadScrollPosition ? _scrollController.position.pixels : 0;
    final wasNearBottom = hadScrollPosition ? _isNearBottomNow() : true;
    if (showLoading) {
      setState(() {
        _loadingInitial = true;
        _historyError = null;
      });
    }
    try {
      final newestFirst = await widget.api.loadMessages(
        _conversationId,
        limit: _messagePageSize,
      );
      if (!mounted) return;
      final chronological = newestFirst.reversed.toList();
      setState(() {
        if (showLoading) {
          _replaceWithServerMessages(chronological);
        } else {
          _mergeLatestServerMessages(chronological);
        }
        _hasOlderMessages =
            _countServerMessages(newestFirst) == _messagePageSize;
        _loadedServerMessages = _countServerMessages(_messages);
        _historyError = null;
      });
      _adoptLatestMusicStationFromMessages();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        if (showLoading) {
          // First load / conversation switch: chase the settling extent so we
          // land exactly on the newest message despite lazy list measurement.
          _jumpToBottomSettled();
        } else if (!hadScrollPosition || wasNearBottom) {
          _scrollToBottom();
        } else {
          final target = oldPixels.clamp(
            _scrollController.position.minScrollExtent,
            _scrollController.position.maxScrollExtent,
          );
          _scrollController.jumpTo(target.toDouble());
        }
        _scheduleStationDockCheck();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _historyError = _asMessage(error));
    } finally {
      if (mounted && showLoading) {
        setState(() => _loadingInitial = false);
      }
    }
  }

  void _replaceWithServerMessages(List<ChatMessage> serverMessages) {
    final serverIds = serverMessages.map((item) => item.id).toSet();
    final serverClientIds = serverMessages
        .map((item) => item.clientId)
        .whereType<String>()
        .toSet();
    final unsyncedUserDrafts = _messages.where((item) {
      if (!item.isMine || !item.pending) return false;
      final clientId = item.clientId ?? item.id;
      return !serverIds.contains(item.id) &&
          !serverClientIds.contains(clientId);
    }).toList();
    final transientAssistantReplies = _messages.where((item) {
      if (item.isMine || !item.isDraft) return false;
      return !_hasMatchingServerAssistant(item, serverMessages);
    }).toList();
    _messages
      ..clear()
      ..addAll(serverMessages)
      ..addAll(unsyncedUserDrafts)
      ..addAll(transientAssistantReplies);
    _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _localUserCoListeningActive =
        ChatMusicStationState.userCoListeningActiveFromMessages(_messages);
  }

  void _mergeLatestServerMessages(List<ChatMessage> serverMessages) {
    for (final serverMessage in serverMessages) {
      _upsertServerMessage(serverMessage);
    }
    _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _localUserCoListeningActive =
        ChatMusicStationState.userCoListeningActiveFromMessages(_messages);
  }

  void _upsertServerMessage(ChatMessage serverMessage) {
    final serverClientId = serverMessage.clientId;
    final exactIndex = _messages.indexWhere((message) {
      if (message.id == serverMessage.id) return true;
      return serverClientId != null && message.clientId == serverClientId;
    });
    if (exactIndex != -1) {
      _messages[exactIndex] = serverMessage;
      return;
    }
    _messages.removeWhere(
      (message) =>
          !message.isMine &&
          message.isDraft &&
          _hasMatchingServerAssistant(message, [serverMessage]),
    );
    _messages.add(serverMessage);
  }

  bool _hasMatchingServerAssistant(
    ChatMessage localReply,
    List<ChatMessage> serverMessages,
  ) {
    if (!localReply.isChatMessage) return false;
    return serverMessages.any((serverMessage) {
      if (!serverMessage.isChatMessage ||
          serverMessage.isMine ||
          serverMessage.content != localReply.content) {
        return false;
      }
      final delta = serverMessage.createdAt
          .difference(localReply.createdAt)
          .abs();
      return delta <= const Duration(minutes: 5);
    });
  }

  Future<void> _loadOlderMessages() async {
    if (_loadingOlder || !_hasOlderMessages) return;
    final oldMaxExtent = _scrollController.position.maxScrollExtent;
    final oldPixels = _scrollController.position.pixels;
    setState(() {
      _loadingOlder = true;
      _historyError = null;
    });
    try {
      final newestFirst = await widget.api.loadMessages(
        _conversationId,
        limit: _messagePageSize,
        offset: _loadedServerMessages,
      );
      if (!mounted) return;
      final chronological = newestFirst.reversed.toList();
      setState(() {
        _prependServerMessages(chronological);
        _hasOlderMessages =
            _countServerMessages(newestFirst) == _messagePageSize;
        _loadedServerMessages = _countServerMessages(_messages);
        _loadingOlder = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final delta = _scrollController.position.maxScrollExtent - oldMaxExtent;
        final target = (oldPixels + delta).clamp(
          _scrollController.position.minScrollExtent,
          _scrollController.position.maxScrollExtent,
        );
        _scrollController.jumpTo(target.toDouble());
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _historyError = _asMessage(error);
          _loadingOlder = false;
        });
      }
    }
  }

  Future<void> _openComponentCard(ChatComponentCard card) async {
    if (card.type == 'offline_activity') {
      final activityId = card.payload['activity_id']?.toString();
      if (activityId == null || activityId.isEmpty) return;
      _dismissInputSurfaces();
      await Navigator.of(context).push<void>(
        CupertinoPageRoute<void>(
          builder: (_) => OfflineActivityPage(
            api: widget.api,
            session: widget.session,
            hasLocation: true,
            initialActivityId: activityId,
          ),
        ),
      );
      return;
    }
    if (card.type == 'offline_gift') {
      final giftId = card.payload['gift_id']?.toString();
      if (giftId == null || giftId.isEmpty) return;
      _dismissInputSurfaces();
      await Navigator.of(context).push<void>(
        CupertinoPageRoute<void>(
          builder: (_) => OfflineGiftPage(
            api: widget.api,
            session: widget.session,
            initialGiftId: giftId,
            onThanksSent: _sendGiftThanksFromChat,
          ),
        ),
      );
      return;
    }
    if (card.type == 'external_link') {
      await _openExternalLinkPayload(card.payload);
      return;
    }
    if (card.type == 'music_track') {
      final rawTrack = card.payload['track'];
      final track = rawTrack is Map
          ? MusicTrack.fromJson(Map<String, dynamic>.from(rawTrack))
          : null;
      if (track == null) return;
      final cardLibrary = _libraryFromMusicCard(card);
      final stationTrack = cardLibrary == _musicStation.library
          ? _stationTrack
          : null;
      final targetTrack = stationTrack ?? track;
      await _pushMusicPage(targetTrack);
      return;
    }
    if (card.type == 'checkin_reminder' || card.type == 'checkin_habit') {
      final reminderId =
          card.payload['trigger_id']?.toString() ??
          card.payload['reminder_id']?.toString() ??
          card.payload['habit_id']?.toString();
      final result = await Navigator.of(context).push<CapsuleChatDraft>(
        CupertinoPageRoute<CapsuleChatDraft>(
          fullscreenDialog: true,
          builder: (_) => CheckinPage(
            api: widget.api,
            session: widget.session,
            initialReminderId: reminderId,
          ),
        ),
      );
      if (!mounted || result == null) return;
      sendComponentMessage(result.agentText, result.card);
      return;
    }
    if (card.type != 'time_capsule') return;
    final capsuleId = card.payload['capsule_id']?.toString();
    if (capsuleId == null || capsuleId.isEmpty) return;
    try {
      final capsule = await widget.api.getTimeCapsule(capsuleId);
      if (!mounted) return;
      final result = await Navigator.of(context).push<Object?>(
        CupertinoPageRoute<Object?>(
          fullscreenDialog: true,
          builder: (_) => CapsuleEditorPage(
            api: widget.api,
            session: widget.session,
            draft: capsule,
            readOnly: true,
          ),
        ),
      );
      if (!mounted || result == null) return;
      if (result is CapsuleChatDraft) {
        sendComponentMessage(result.agentText, result.card);
      }
    } catch (error) {
      if (mounted) setState(() => _historyError = _asMessage(error));
    }
  }

  Future<void> _openActiveMusic() async {
    final track = _conversationMeta?.musicCoListening?.track;
    if (track == null) return;
    await _pushMusicPage(track);
  }

  Future<void> _openStationMusic() async {
    final track = _stationTrack ?? _conversationMeta?.musicCoListening?.track;
    if (track == null) return;
    await _pushMusicPage(track);
  }

  Future<void> _pushMusicPage(MusicTrack initialTrack) async {
    if (_openingMusicPage) return;
    _openingMusicPage = true;
    try {
      if (!mounted) return;
      final result = await Navigator.of(context).push<CapsuleChatDraft>(
        CupertinoPageRoute<CapsuleChatDraft>(
          fullscreenDialog: true,
          builder: (_) => MusicPage(
            api: widget.api,
            session: widget.session,
            initialTrack: initialTrack,
          ),
        ),
      );
      if (!mounted || result == null) return;
      sendComponentMessage(result.agentText, result.card);
    } finally {
      _openingMusicPage = false;
    }
  }

  Future<MusicTrack?> _resolveMusicTrack(MusicTrack track) async {
    final agentId = widget.session.agentId;
    if (agentId == null || agentId.isEmpty || track.id.isEmpty) return track;
    try {
      final playUrl = await widget.api.getMusicTrackPlayUrl(
        agentId: agentId,
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
      return track.copyWith(url: '');
    }
  }

  Future<void> _loadMusicFavorites() async {
    final agentId = widget.session.agentId;
    if (agentId == null || agentId.isEmpty) return;
    try {
      final response = await widget.api.listMusicFavorites(agentId: agentId);
      if (!mounted) return;
      setState(() {
        _favoriteMusicTrackIds
          ..clear()
          ..addAll(response.tracks.map((item) => item.id));
      });
    } catch (_) {
      // Favorites are decorative in chat; playback should not depend on them.
    }
  }

  Future<void> _scanReadyCapsules() async {
    try {
      final ready = await widget.api.listTimeCapsules(state: 'ready');
      if (!mounted) return;
      final nextReady = ready.isEmpty ? null : ready.first;
      setState(() => _readyCapsule = nextReady);
      if (nextReady != null &&
          nextReady.id != _dismissedReadyCapsuleId &&
          nextReady.id != _autoShownReadyCapsuleId &&
          !_readyCapsuleNoticeShowing &&
          (ModalRoute.of(context)?.isCurrent ?? true)) {
        _autoShownReadyCapsuleId = nextReady.id;
        Future<void>.delayed(const Duration(milliseconds: 360), () {
          if (!mounted ||
              _readyCapsule?.id != nextReady.id ||
              _readyCapsuleNoticeShowing) {
            return;
          }
          unawaited(_openReadyCapsuleNotice());
        });
      }
    } catch (error) {
      debugPrint('[capsule.ready] scan failed: $error');
    }
  }

  void refreshReadyCapsules() {
    unawaited(_scanReadyCapsules());
    _scheduleNextCapsuleScan();
  }

  void _dismissReadyCapsuleBanner() {
    final capsule = _readyCapsule;
    if (capsule == null) return;
    setState(() {
      _dismissedReadyCapsuleId = capsule.id;
    });
  }

  void _scheduleNextCapsuleScan() {
    _capsuleScanTimer?.cancel();
    final next = _nextUtc8Eight();
    final delay = next.difference(DateTime.now());
    _capsuleScanTimer = Timer(
      delay.isNegative ? const Duration(seconds: 1) : delay,
      () {
        unawaited(_scanReadyCapsules());
        _scheduleNextCapsuleScan();
      },
    );
  }

  DateTime _nextUtc8Eight() {
    final utc8Now = DateTime.now().toUtc().add(const Duration(hours: 8));
    var targetUtc8 = DateTime.utc(utc8Now.year, utc8Now.month, utc8Now.day, 8);
    if (!targetUtc8.isAfter(utc8Now)) {
      targetUtc8 = targetUtc8.add(const Duration(days: 1));
    }
    return targetUtc8.subtract(const Duration(hours: 8)).toLocal();
  }

  Future<void> _openReadyCapsuleNotice() async {
    final capsule = _readyCapsule;
    if (capsule == null || _readyCapsuleNoticeShowing) return;
    _readyCapsuleNoticeShowing = true;
    _dismissInputSurfaces();
    final bool? shouldOpen;
    try {
      shouldOpen = await showGeneralDialog<bool>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'capsule-ready',
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, __, ___) => _CapsuleReadyOverlay(capsule: capsule),
        transitionBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(opacity: curved, child: child);
        },
      );
    } finally {
      _readyCapsuleNoticeShowing = false;
    }
    if (!mounted || shouldOpen != true) return;
    try {
      await _waitForNavigatorUnlock();
      if (!mounted) return;
      final opened = await widget.api.openTimeCapsule(capsule.id);
      if (!mounted) return;
      setState(() => _readyCapsule = null);
      await _waitForNavigatorUnlock();
      if (!mounted) return;
      final draft = await Navigator.of(context).push<CapsuleChatDraft>(
        CupertinoPageRoute<CapsuleChatDraft>(
          fullscreenDialog: true,
          builder: (_) => CapsuleEditorPage(
            api: widget.api,
            session: widget.session,
            draft: opened,
            readOnly: true,
          ),
        ),
      );
      if (!mounted) return;
      if (draft != null) {
        sendComponentMessage(draft.agentText, draft.card);
      } else {
        unawaited(_scanReadyCapsules());
      }
    } catch (error) {
      if (mounted) setState(() => _historyError = _asMessage(error));
    }
  }

  void _prependServerMessages(List<ChatMessage> older) {
    final existingIds = _messages.map((item) => item.id).toSet();
    final unique = older.where((item) => !existingIds.contains(item.id));
    _messages.insertAll(0, unique);
    _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  int _countServerMessages(List<ChatMessage> messages) {
    return messages
        .where((item) => item.isChatMessage && !item.pending && !item.isDraft)
        .length;
  }

  bool _isMusicStationCard(ChatComponentCard? card) {
    return ChatMusicStationState.isMusicCard(card);
  }

  String? _libraryFromMusicCard(ChatComponentCard? card) {
    return ChatMusicStationState.libraryFromCard(card);
  }

  void _adoptLatestMusicStationFromMessages() {
    final changed = _musicStation.adoptLatestFrom(_messages);
    if (changed && mounted) setState(() {});
  }

  bool _adoptMusicStation(ChatComponentCard card, String messageId) {
    return _musicStation.adopt(card, messageId);
  }

  void _activateMusicStationCard(ChatComponentCard card, String messageId) {
    if (!_isMusicStationCard(card)) return;
    final beforeMessageId = _musicStation.messageId;
    final beforeTitle = _musicStation.card?.title;
    final beforeLibrary = _musicStation.library;
    _musicStation.activate(card, messageId);
    final changed =
        beforeTitle != _musicStation.card?.title ||
        beforeMessageId != _musicStation.messageId ||
        beforeLibrary != _musicStation.library;
    if (changed && mounted) {
      setState(() {});
    } else if (mounted) {
      setState(() {});
    }
    _scheduleStationDockCheck();
  }

  void _cacheActiveMusicPosition() {
    _musicStation.cacheActivePosition(_playback.track, _playback.position);
  }

  void _rememberStationTrack(MusicTrack track) {
    _musicStation.remember(track);
  }

  MusicTrack? get _stationTrack {
    return _musicStation.currentTrack(_playback.track);
  }

  bool get _isStationPlaying {
    final track = _stationTrack;
    return track != null &&
        _playback.isCurrentTrack(track) &&
        _playback.isPlaying;
  }

  bool get _isStationLoading {
    final track = _stationTrack;
    return track != null && _playback.isLoadingTrack(track);
  }

  bool get _isUserCoListening {
    return _localUserCoListeningActive ||
        ChatMusicStationState.activeSessionIncludesUser(
          _conversationMeta?.musicCoListening,
        );
  }

  bool get _canGoStationPrevious => _musicStation.canGoPrevious;

  void _cancelStationPauseTimer() {
    _stationPauseTimer?.cancel();
    _stationPauseTimer = null;
  }

  void _activateStationDock() {
    _cancelStationPauseTimer();
    _stationDockActive = true;
    _stationCardDocked = true;
  }

  void _clearStationDock() {
    _cancelStationPauseTimer();
    _stationDockActive = false;
    _stationCardDocked = false;
  }

  void _scheduleStationPauseExit() {
    if (_stationPauseTimer?.isActive ?? false) return;
    _stationPauseTimer = Timer(const Duration(minutes: 1), () {
      if (!mounted) return;
      if (_isStationPlaying || _isStationLoading || _advancingStation) return;
      final shouldNotifyCoListeningExit = _isUserCoListening;
      setState(_clearStationDock);
      if (!shouldNotifyCoListeningExit) return;
      final agentId = widget.session.agentId;
      if (agentId == null || agentId.isEmpty) return;
      unawaited(
        widget.api.endMusicCoListening(
          agentId: agentId,
          conversationId: _conversationId,
          reason: 'user_pause_timeout',
        ),
      );
    });
  }

  void _syncStationDockLifecycle() {
    final track = _stationTrack;
    if (track == null) {
      _clearStationDock();
      return;
    }
    if (_isStationPlaying || _isStationLoading || _advancingStation) {
      _activateStationDock();
      return;
    }
    if (_stationDockActive) {
      _scheduleStationPauseExit();
    }
  }

  void _handleStationPlaybackChanged() {
    _cacheActiveMusicPosition();
    final track = _stationTrack;
    if (track != null &&
        _musicStation.library != null &&
        track.library == _musicStation.library) {
      _rememberStationTrack(track);
    }
    _syncStationDockLifecycle();
    final trackId = track?.id;
    final playing = _isStationPlaying;
    final loading = _isStationLoading;
    final shouldRebuild =
        trackId != _musicStation.lastTrackId ||
        playing != _musicStation.lastPlaying ||
        loading != _musicStation.lastLoading;
    _musicStation.lastTrackId = trackId;
    _musicStation.lastPlaying = playing;
    _musicStation.lastLoading = loading;
    if (shouldRebuild) {
      if (track != null) unawaited(_syncStationPlayback(track));
      _scheduleStationDockCheck();
      if (mounted) setState(() {});
    }
  }

  Future<void> _playPreviousStationTrack() async {
    if (!_canGoStationPrevious || _advancingStation) return;
    final track = _musicStation.movePrevious();
    if (track == null) return;
    setState(() {});
    await _startStationTrack(
      track,
      addToHistory: false,
      changeSource: 'manual_previous',
    );
  }

  Future<void> _playNextStationTrack({
    bool auto = false,
    int retryCount = 0,
  }) async {
    final agentId = widget.session.agentId;
    final library = _musicStation.library;
    if (agentId == null ||
        agentId.isEmpty ||
        library == null ||
        library.isEmpty ||
        _advancingStation) {
      return;
    }
    var shouldRetry = false;
    _advancingStation = true;
    if (mounted) setState(() {});
    try {
      final response = await widget.api.listMusicTracks(
        agentId: agentId,
        workspaceId: widget.session.workspaceId,
        library: library,
        excludeTrackId: _playback.track?.id ?? _stationTrack?.id,
        limit: 1,
        refresh: true,
      );
      if (!mounted || response.tracks.isEmpty) return;
      final didStart = await _startStationTrack(
        response.tracks.first,
        changeSource: auto ? 'auto_next' : 'manual_next',
      );
      shouldRetry = !didStart && retryCount < 2;
      if (!didStart && !shouldRetry && mounted && !auto) {
        setState(() => _historyError = '这首歌暂时播放不了，正在换一首。');
      }
    } catch (error) {
      if (mounted && !auto) setState(() => _historyError = _asMessage(error));
    } finally {
      _advancingStation = false;
      _syncStationDockLifecycle();
      if (mounted) setState(() {});
    }
    if (mounted && shouldRetry) {
      await _playNextStationTrack(auto: auto, retryCount: retryCount + 1);
    }
  }

  Future<bool> _startStationTrack(
    MusicTrack track, {
    bool addToHistory = true,
    Duration position = Duration.zero,
    String changeSource = 'sync',
  }) async {
    final resolved = await _resolveMusicTrack(track) ?? track;
    if (!mounted) return false;
    final playable = resolved.url.isEmpty ? track : resolved;
    final didStart = await _playback.playTrack(playable, position: position);
    if (!mounted) return didStart;
    if (didStart) {
      _activateStationDock();
    }
    if (addToHistory) {
      setState(() => _rememberStationTrack(playable));
    }
    unawaited(_syncStationPlayback(playable, changeSource: changeSource));
    return didStart;
  }

  Future<void> _toggleStationPlayback() async {
    var track = _stationTrack;
    if (track == null) return;
    try {
      if (_playback.isCurrentTrack(track)) {
        if (!_playback.isPlaying && track.url.isEmpty) {
          track = await _resolveMusicTrack(track) ?? track;
        }
        await _playback.toggle(track);
      } else {
        await _startStationTrack(track, changeSource: 'manual_next');
        _syncStationDockLifecycle();
        return;
      }
      _syncStationDockLifecycle();
      final activeTrack = _playback.track ?? track;
      unawaited(
        _syncStationPlayback(
          activeTrack,
          changeSource: _playback.isPlaying ? 'resume' : 'pause',
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _historyError = '这首歌暂时播放不了，正在换一首。');
    }
  }

  Future<void> _toggleMusicFavorite(MusicTrack track) async {
    final agentId = widget.session.agentId;
    if (agentId == null ||
        agentId.isEmpty ||
        track.id.isEmpty ||
        _busyMusicFavoriteIds.contains(track.id)) {
      return;
    }
    final wasFavorite = _favoriteMusicTrackIds.contains(track.id);
    setState(() {
      _busyMusicFavoriteIds.add(track.id);
      if (wasFavorite) {
        _favoriteMusicTrackIds.remove(track.id);
      } else {
        _favoriteMusicTrackIds.add(track.id);
      }
    });
    try {
      if (wasFavorite) {
        await widget.api.removeMusicFavorite(
          agentId: agentId,
          trackId: track.id,
        );
      } else {
        final saved = await widget.api.addMusicFavorite(
          agentId: agentId,
          workspaceId: widget.session.workspaceId,
          track: track.copyWith(isFavorite: true),
        );
        if (mounted && saved.id != track.id) {
          setState(() {
            _favoriteMusicTrackIds
              ..remove(track.id)
              ..add(saved.id);
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (wasFavorite) {
            _favoriteMusicTrackIds.add(track.id);
          } else {
            _favoriteMusicTrackIds.remove(track.id);
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busyMusicFavoriteIds.remove(track.id));
      }
    }
  }

  Future<void> _syncStationPlayback(
    MusicTrack track, {
    String changeSource = 'sync',
  }) async {
    final agentId = widget.session.agentId;
    if (agentId == null || agentId.isEmpty) return;
    try {
      await widget.api.updateMusicNowPlaying(
        agentId: agentId,
        workspaceId: widget.session.workspaceId,
        conversationId: _conversationId,
        track: track,
        positionSeconds: _playback.position.inSeconds,
        isPlaying: _playback.isPlaying,
        changeSource: changeSource,
      );
      unawaited(_refreshConversationMeta());
    } catch (_) {
      // Playback controls should remain local even when presence sync fails.
    }
  }

  void _updateStationCardDocked() {
    if (!mounted) return;
    _stationDockCheckScheduled = false;
    final hasStation = _musicStation.card != null && _stationTrack != null;
    if (!hasStation) {
      if (_stationCardDocked) setState(() => _stationCardDocked = false);
      return;
    }
    final context = _stationCardKey.currentContext;
    var shouldDock = false;
    if (context != null) {
      final renderObject = context.findRenderObject();
      if (renderObject is RenderBox && renderObject.hasSize) {
        final topLeft = renderObject.localToGlobal(Offset.zero);
        final bottom = topLeft.dy + renderObject.size.height;
        final screenHeight = MediaQuery.sizeOf(this.context).height;
        final composerHeight = _composerHeightForWidth(
          MediaQuery.sizeOf(this.context).width,
        );
        final bottomLimit =
            screenHeight - composerHeight - _tabBarContentHeight;
        const dockRevealLine = 144.0;
        shouldDock = bottom < dockRevealLine || topLeft.dy > bottomLimit;
      }
    }
    if (_stationCardDocked != shouldDock) {
      setState(() => _stationCardDocked = shouldDock);
    }
  }

  void _scheduleStationDockCheck() {
    if (_stationDockCheckScheduled) return;
    _stationDockCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _stationDockCheckScheduled = false;
        return;
      }
      _updateStationCardDocked();
    });
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels <= _loadOlderThreshold &&
        _hasOlderMessages &&
        !_loadingOlder) {
      unawaited(_loadOlderMessages());
    }
    if (_newMessageCount > 0 && _isNearBottomNow()) {
      setState(() => _newMessageCount = 0);
    }
    _scheduleStationDockCheck();
  }

  void _handleWsEvent(WsEnvelope envelope) {
    final payload = envelope.data;
    switch (envelope.type) {
      case 'ack':
        final clientId = payload['client_id']?.toString() ?? '';
        final messageId = payload['message_id']?.toString() ?? '';
        if (clientId.isEmpty) return;
        setState(() {
          for (var i = 0; i < _messages.length; i += 1) {
            final message = _messages[i];
            if (message.id == clientId || message.clientId == clientId) {
              _messages[i] = message.copyWith(
                id: messageId.isEmpty ? message.id : messageId,
                read: true,
                pending: false,
                metadata: {...?message.metadata, 'client_id': clientId},
              );
              if (messageId.isNotEmpty) {
                _musicStation.acknowledgeMessageId(clientId, messageId);
              }
              break;
            }
          }
          _sending = false;
        });
        break;
      case 'delay':
        setState(() => _agentTyping = true);
        if (widget.isActive && _isNearBottomNow()) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom(animated: true);
          });
        }
        break;
      case 'pending':
        setState(() {
          _sending = false;
          _agentTyping = true;
        });
        if (widget.isActive && _isNearBottomNow()) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom(animated: true);
          });
        }
        break;
      case 'message':
        _handleRealtimeMessageEvent(payload);
        break;
      case 'reply':
      case 'proactive':
        final text = payload['text']?.toString() ?? '';
        if (text.isEmpty) return;
        final wasNearBottom = _isNearBottomNow();
        final shouldAutoScroll = widget.isActive && wasNearBottom;
        final messageId = payload['message_id']?.toString();
        final assistantMessageId = payload['assistant_message_id']?.toString();
        final replyIndex = _payloadReplyIndex(payload);
        final shouldEmitInAppNotification =
            !widget.isActive && (replyIndex == null || replyIndex == 0);
        final rawComponentCard =
            payload['component_card'] ?? payload['componentCard'];
        final componentCard = rawComponentCard is Map
            ? ChatComponentCard.fromJson(rawComponentCard)
            : null;
        setState(() {
          final draft = ChatMessage.draft(
            conversationId: _conversationId,
            role: 'assistant',
            content: text,
            metadata: componentCard == null
                ? null
                : {'component_card': componentCard.toJson()},
          );
          _messages.add(draft);
          if (_isMusicStationCard(componentCard)) {
            _adoptMusicStation(componentCard!, draft.id);
          }
          _sending = false;
          _agentTyping = false;
          if (!shouldAutoScroll) {
            _newMessageCount += 1;
          }
        });
        if (shouldEmitInAppNotification) {
          AppNotificationService.instance.emitAgentMessage(
            text: text,
            session: widget.session,
            eventType: envelope.type,
            messageId: messageId?.isNotEmpty == true
                ? messageId
                : assistantMessageId?.isNotEmpty == true
                ? assistantMessageId
                : null,
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (shouldAutoScroll) {
            _scrollToBottom(animated: true);
          }
          _scheduleStationDockCheck();
        });
        break;
      case 'music_status':
        final text = payload['text']?.toString() ?? '';
        if (text.isEmpty) return;
        final shouldAutoScroll = widget.isActive && _isNearBottomNow();
        final messageId = payload['message_id']?.toString();
        final status = payload['status']?.toString() ?? 'started';
        final actor = payload['actor']?.toString() ?? '';
        setState(() {
          if (status == 'ended' && actor == 'user') {
            _clearStationDock();
          }
          if (status == 'started' && actor == 'user') {
            _localUserCoListeningActive = true;
          } else if (status == 'ended') {
            _localUserCoListeningActive = false;
          }
          _upsertServerMessage(
            ChatMessage(
              id: messageId?.isNotEmpty == true
                  ? messageId!
                  : 'music-status-${DateTime.now().microsecondsSinceEpoch}',
              conversationId: _conversationId,
              role: 'assistant',
              content: text,
              createdAt: DateTime.now(),
              metadata: {
                'music_status': status,
                'music_track_title': payload['track_title']?.toString() ?? '',
                'music_track_id': payload['track_id']?.toString() ?? '',
                'music_co_listening': status == 'started',
                'music_status_actor': actor,
                'music_status_actor_name':
                    payload['actor_name']?.toString() ?? '',
                if (payload['reason'] != null)
                  'music_ended_reason': payload['reason']?.toString() ?? '',
              },
              read: true,
            ),
          );
          _sending = false;
          _agentTyping = false;
        });
        unawaited(_refreshConversationMeta());
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (shouldAutoScroll) _scrollToBottom(animated: true);
          _scheduleStationDockCheck();
        });
        break;
      case 'game_status':
        final text = payload['text']?.toString() ?? '';
        if (text.isEmpty) return;
        final shouldAutoScroll = widget.isActive && _isNearBottomNow();
        final messageId = payload['message_id']?.toString();
        final status = payload['status']?.toString() ?? 'started';
        setState(() {
          _messages.add(
            ChatMessage(
              id: messageId?.isNotEmpty == true
                  ? messageId!
                  : 'game-status-${DateTime.now().microsecondsSinceEpoch}',
              conversationId: _conversationId,
              role: 'assistant',
              content: text,
              createdAt: DateTime.now(),
              metadata: {
                'game_status': status,
                'game_title': payload['game_title']?.toString() ?? '',
                'game_session_id': payload['session_id']?.toString() ?? '',
                'game_mg_id': payload['mg_id']?.toString() ?? '',
                'game_status_actor': payload['actor']?.toString() ?? '',
                'game_status_actor_name':
                    payload['actor_name']?.toString() ?? '',
                if (payload['reason'] != null)
                  'game_ended_reason': payload['reason']?.toString() ?? '',
              },
              read: true,
            ),
          );
          _sending = false;
          _agentTyping = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (shouldAutoScroll) _scrollToBottom(animated: true);
          _scheduleStationDockCheck();
        });
        break;
      case 'done':
        setState(() {
          _sending = false;
          _agentTyping = false;
        });
        unawaited(_loadLatestMessages(showLoading: false));
        break;
      case 'error':
        setState(() {
          _sending = false;
          _agentTyping = false;
          _historyError = payload['message']?.toString() ?? '聊天失败';
        });
        break;
      case 'pong':
      case 'memory_extracted':
      case 'reminder_changed':
      case 'trace_ready':
        break;
      case 'achievement_unlocked':
        _showAchievementNotice(AchievementItem.fromJson(payload));
        break;
      default:
        break;
    }
  }

  void _handleRealtimeMessageEvent(Map<String, dynamic> payload) {
    final role = payload['role']?.toString() ?? '';
    if (role != 'user' && role != 'assistant') return;
    final text = payload['text']?.toString() ?? '';
    final rawComponentCard =
        payload['component_card'] ?? payload['componentCard'];
    final componentCard = rawComponentCard is Map
        ? ChatComponentCard.fromJson(rawComponentCard)
        : null;
    final rawAttachments = payload['attachments'];
    final attachments = rawAttachments is List
        ? [
            for (final item in rawAttachments)
              if (item is Map)
                ChatAttachment.fromJson(Map<String, dynamic>.from(item)),
          ]
        : const <ChatAttachment>[];
    if (text.isEmpty && componentCard == null && attachments.isEmpty) return;

    final messageId = payload['message_id']?.toString() ?? '';
    final clientId = payload['client_id']?.toString() ?? '';
    final wasNearBottom = _isNearBottomNow();
    final shouldAutoScroll = widget.isActive && wasNearBottom;
    final metadata = <String, dynamic>{
      for (final key in const [
        'real_world_type',
        'source_id',
        'trigger_type',
        'client_id',
      ])
        if (payload[key] != null) key: payload[key],
      if (componentCard != null) 'component_card': componentCard.toJson(),
      if (attachments.isNotEmpty)
        'attachments': attachments.map((item) => item.toJson()).toList(),
    };
    final createdAt =
        DateTime.tryParse(payload['created_at']?.toString() ?? '') ??
        DateTime.now();
    if (clientId.isNotEmpty) {
      final draftIndex = _messages.indexWhere(
        (message) => message.id == clientId || message.clientId == clientId,
      );
      if (draftIndex != -1) {
        setState(() {
          _messages[draftIndex] = ChatMessage(
            id: messageId.isEmpty ? _messages[draftIndex].id : messageId,
            conversationId:
                payload['conversation_id']?.toString() ?? _conversationId,
            role: role,
            content: text,
            createdAt: createdAt,
            metadata: metadata.isEmpty ? null : metadata,
            pending: false,
            read: true,
          );
          _sending = false;
          if (_isMusicStationCard(componentCard)) {
            _adoptMusicStation(componentCard!, messageId);
          }
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (shouldAutoScroll) {
            _scrollToBottom(animated: true);
          }
          _scheduleStationDockCheck();
        });
        return;
      }
    }
    if (messageId.isNotEmpty &&
        _messages.any((message) => message.id == messageId)) {
      return;
    }
    setState(() {
      _messages.add(
        ChatMessage(
          id: messageId.isEmpty
              ? 'ws-${DateTime.now().microsecondsSinceEpoch}-${text.hashCode}'
              : messageId,
          conversationId:
              payload['conversation_id']?.toString() ?? _conversationId,
          role: role,
          content: text,
          createdAt: createdAt,
          metadata: metadata.isEmpty ? null : metadata,
          pending: false,
          read: true,
        ),
      );
      if (_isMusicStationCard(componentCard)) {
        _adoptMusicStation(componentCard!, messageId);
      }
      if (role == 'assistant') {
        _agentTyping = false;
      }
      if (!shouldAutoScroll && role == 'assistant') {
        _newMessageCount += 1;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (shouldAutoScroll) {
        _scrollToBottom(animated: true);
      }
      _scheduleStationDockCheck();
    });
  }

  void _sendGiftThanksFromChat(
    RealWorldGift gift,
    String message,
    String clientId,
  ) {
    final content = _giftThanksChatContent(gift, message);
    final draft = ChatMessage.draft(
      conversationId: _conversationId,
      role: 'user',
      content: content,
      clientId: clientId,
      metadata: {
        'real_world_type': 'gift',
        'source_id': gift.id,
        'trigger_type': 'gift_thanks',
      },
    );
    setState(() {
      _messages.add(draft);
      _panel = ComposerPanel.none;
      _sending = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animated: true);
      _scheduleStationDockCheck();
    });
    unawaited(_submitGiftThanks(gift, message, clientId));
  }

  Future<void> _submitGiftThanks(
    RealWorldGift gift,
    String message,
    String clientId,
  ) async {
    try {
      await widget.api.sendGiftThanks(
        gift.id,
        message: message,
        clientId: clientId,
      );
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < _messages.length; i += 1) {
          final item = _messages[i];
          if (item.id == clientId || item.clientId == clientId) {
            _messages[i] = item.copyWith(pending: false, read: true);
            break;
          }
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _historyError = _asMessage(error);
        for (var i = 0; i < _messages.length; i += 1) {
          final item = _messages[i];
          if (item.id == clientId || item.clientId == clientId) {
            _messages[i] = item.copyWith(pending: false, read: false);
            break;
          }
        }
      });
    }
  }

  String _giftThanksChatContent(RealWorldGift gift, String message) {
    final name = gift.giftName.trim();
    final prefix = name.isEmpty ? '我收到礼物啦' : '我收到了「$name」';
    return '$prefix，想说：$message';
  }

  void _showAchievementNotice(AchievementItem item) {
    final shouldAutoScroll = widget.isActive && _isNearBottomNow();
    final message = ChatMessage.achievement(
      conversationId: _conversationId,
      item: item,
    );
    setState(() {
      _messages.add(message);
      _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (shouldAutoScroll) _scrollToBottom(animated: true);
      _scheduleStationDockCheck();
    });
  }

  void _openAchievementDetail(AchievementItem item) {
    _dismissInputSurfaces();
    widget.onAchievementDetailRequested?.call(item);
    widget.onAchievementOverlayChanged?.call(true);
  }

  void _openInteractionDetail() {
    _dismissInputSurfaces();
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => _InteractionStreakPage(
          agentAvatarUrl: _agentAvatarUrl,
          userAvatarUrl: widget.session.userAvatarUrl,
          interactionDays: _conversationMeta?.interactionDays ?? 0,
        ),
      ),
    );
  }

  void _showDemoAchievementNotice() {
    const samples = [
      ('初次开口', '哇哦！成功打破沉默，冷场彻底退退退！', '第一次给TA发消息', '用户累计给ai发送1条信息', '微光痕迹', 1),
      ('轻声开场', '三个字轻松开场，简短但存在感超强！', '今天第一句话超级短', '当日首条消息≤3个字', '微光痕迹', 3),
      (
        '双向奔赴',
        '你回应了TA的主动，故事开始了～',
        '24小时内回复TA的主动消息',
        '用户24小时内回复AI主动消息',
        '心澜痕迹',
        25,
      ),
      (
        '畅聊艺术家',
        '今日聊天量爆表，灵感像瀑布一样落下来！',
        '一天内聊到10000字',
        '24小时内聊天>=10000字',
        '清响痕迹',
        60,
      ),
    ];
    final sample = samples[_achievementDemoIndex % samples.length];
    _achievementDemoIndex += 1;
    _showAchievementNotice(
      AchievementItem(
        id: sample.$6,
        category: '测试触发',
        name: sample.$1,
        popupText: sample.$2,
        conditionText: sample.$3,
        ruleText: sample.$4,
        levelName: sample.$5,
        score: 10,
        unlocked: true,
        unlockedAt: DateTime.now(),
      ),
    );
  }

  void scrollToLatest({bool animated = true}) {
    if (mounted && _newMessageCount > 0) {
      setState(() => _newMessageCount = 0);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToBottom(animated: animated);
    });
  }

  void sendComponentMessage(String text, ChatComponentCard componentCard) {
    _sendText(text.trim(), componentCard: componentCard, clearComposer: false);
  }

  int? _payloadReplyIndex(Map<String, dynamic> payload) {
    final value = payload['index'] ?? payload['reply_index'];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (_uploadingImage) return;
    final attachments = _pendingImages.map((item) => item.attachment).toList();
    final linkPreview = _pendingLinkPreview;
    _sendText(
      text,
      componentCard: linkPreview?.preview.componentCard,
      attachments: attachments,
      clearComposer: true,
    );
  }

  void _handleVoicePressStart(Offset position) {
    if (_preparingVoice ||
        _recordingVoice ||
        _transcribingVoice ||
        _uploadingImage ||
        _sending) {
      return;
    }
    unawaited(triggerVoiceVibration());
    setState(() {
      _voiceGestureActive = true;
      _voiceReleaseAction = _voiceActionForPosition(position);
      _pendingVoiceReleaseAction = null;
    });
    unawaited(_startVoiceRecording());
  }

  void _handleVoicePressMove(Offset position) {
    if (!_voiceGestureActive) return;
    final action = _voiceActionForPosition(position);
    if (action == _voiceReleaseAction) return;
    if (shouldHapticOnVoiceActionEntry(
      previous: _voiceReleaseAction,
      next: action,
    )) {
      unawaited(triggerVoiceVibration());
    }
    setState(() {
      _voiceReleaseAction = action;
    });
    _syncVoiceRecordingOverlay();
  }

  void _handleVoicePressEnd(Offset position) {
    if (!_voiceGestureActive) return;
    final now = DateTime.now();
    final recordingStartedAt = _voiceRecordingStartedAt;
    final capturedDuration = recordingStartedAt == null
        ? null
        : now.difference(recordingStartedAt);
    var action = _voiceActionForPosition(position);
    final tooShort =
        action != VoiceReleaseAction.cancel &&
        isVoiceCaptureTooShort(capturedDuration);
    if (tooShort) action = VoiceReleaseAction.cancel;
    unawaited(triggerVoiceVibration());
    setState(() {
      _voiceGestureActive = false;
      _voiceReleaseAction = action;
      _pendingVoiceReleaseAction = action;
      if (tooShort) _historyError = '说话时间太短，请按住后再说。';
    });
    _syncVoiceRecordingOverlay();
    if (!_preparingVoice) {
      unawaited(_completeVoiceGesture(action));
    }
  }

  void _handleVoicePressCancel() {
    if (!_voiceGestureActive && !_preparingVoice && !_recordingVoice) return;
    setState(() {
      _voiceGestureActive = false;
      _voiceReleaseAction = VoiceReleaseAction.cancel;
      _pendingVoiceReleaseAction = VoiceReleaseAction.cancel;
    });
    _syncVoiceRecordingOverlay();
    unawaited(_cancelVoiceRecording());
  }

  void _syncVoiceRecordingOverlay() {
    final callback = widget.onVoiceRecordingOverlayChanged;
    if (callback == null) return;
    final visible = _voiceGestureActive && (_preparingVoice || _recordingVoice);
    callback(
      visible
          ? VoiceRecordingOverlaySnapshot(
              action: _voiceReleaseAction,
              seconds: _voiceSeconds,
              preparing: _preparingVoice,
              amplitude: _voiceAmplitude,
            )
          : null,
    );
  }

  /// Mirrors the derived panel visibility to the shell (which hides the
  /// floating tab bar while a panel is docked). Called from build, so the
  /// actual notification is deferred to after the frame: flipping parent
  /// state mid-build is not allowed.
  void _syncComposerPanelVisibility(bool visible) {
    if (_notifiedComposerPanelVisible == visible) return;
    _notifiedComposerPanelVisible = visible;
    final callback = widget.onComposerPanelChanged;
    if (callback == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) callback(visible);
    });
  }

  VoiceReleaseAction _voiceActionForPosition(Offset position) {
    return voiceReleaseActionForPosition(
      position: position,
      screenSize: MediaQuery.sizeOf(context),
      safeBottom: MediaQuery.paddingOf(context).bottom,
      currentAction: _voiceReleaseAction,
    );
  }

  Future<void> _completeVoiceGesture(VoiceReleaseAction action) async {
    _pendingVoiceReleaseAction = null;
    if (action == VoiceReleaseAction.cancel) {
      await _cancelVoiceRecording();
      return;
    }
    await _stopVoiceRecording(action);
  }

  Future<void> _startVoiceRecording() async {
    if (_preparingVoice ||
        _recordingVoice ||
        _transcribingVoice ||
        _uploadingImage ||
        _sending) {
      return;
    }
    setState(() {
      _preparingVoice = true;
      _panel = ComposerPanel.none;
      _historyError = null;
    });
    _syncVoiceRecordingOverlay();
    _inputFocus.unfocus();
    try {
      if (!await _voiceRecorder.hasPermission()) {
        if (mounted) {
          setState(() {
            _voiceGestureActive = false;
            _pendingVoiceReleaseAction = null;
            _historyError = '需要麦克风权限才能进行语音输入。';
          });
          _syncVoiceRecordingOverlay();
        }
        return;
      }
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/chat_voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
      await _voiceAmplitudeSub?.cancel();
      _voiceAmplitudeSub = null;
      if (!mounted) return;
      _voiceAmplitude.value = 0.12;
      _voiceAmplitudeSampleCount = 0;
      _voiceActiveMilliseconds = 0;
      await _voiceRecorder.start(chatVoiceRecordConfig, path: path);
      if (!mounted) {
        await _voiceRecorder.cancel();
        return;
      }
      setState(() {
        _preparingVoice = false;
        _recordingVoice = true;
        _voiceSeconds = 0;
        _voiceRecordingStartedAt = DateTime.now();
      });
      _syncVoiceRecordingOverlay();
      _voiceAmplitudeSub = _voiceRecorder
          .onAmplitudeChanged(voiceAmplitudeSampleInterval)
          .listen((amplitude) {
            final current = amplitude.current.isFinite
                ? amplitude.current
                : -55.0;
            _voiceAmplitudeSampleCount += 1;
            if (current >= voiceSpeechThresholdDbfs) {
              _voiceActiveMilliseconds +=
                  voiceAmplitudeSampleInterval.inMilliseconds;
            }
            _voiceAmplitude.value = ((current + 55) / 55)
                .clamp(0.08, 1.0)
                .toDouble();
          }, onError: (_) {});
      _voiceTimer?.cancel();
      _voiceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || !_recordingVoice) {
          timer.cancel();
          return;
        }
        final next = _voiceSeconds + 1;
        setState(() => _voiceSeconds = next);
        _syncVoiceRecordingOverlay();
        if (next >= _maxVoiceSeconds) {
          timer.cancel();
          setState(() {
            _voiceGestureActive = false;
            _voiceReleaseAction = VoiceReleaseAction.sendVoice;
          });
          _syncVoiceRecordingOverlay();
          HapticFeedback.heavyImpact();
          unawaited(_stopVoiceRecording(VoiceReleaseAction.sendVoice));
        }
      });
      final pendingAction = _pendingVoiceReleaseAction;
      if (pendingAction != null) {
        await _completeVoiceGesture(pendingAction);
        return;
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _recordingVoice = false;
          _voiceGestureActive = false;
          _voiceRecordingStartedAt = null;
          _pendingVoiceReleaseAction = null;
          _historyError = error is MissingPluginException
              ? '语音功能需要完整重启 App 后才能使用。'
              : _asMessage(error);
        });
        _syncVoiceRecordingOverlay();
      }
    } finally {
      if (mounted && _preparingVoice) {
        setState(() => _preparingVoice = false);
        _syncVoiceRecordingOverlay();
      }
    }
  }

  Future<void> _stopVoiceRecording(VoiceReleaseAction action) async {
    if (!_recordingVoice || _transcribingVoice) return;
    _voiceTimer?.cancel();
    _voiceTimer = null;
    final amplitudeSub = _voiceAmplitudeSub;
    _voiceAmplitudeSub = null;
    _voiceAmplitude.value = 0.12;
    final startedAt = _voiceRecordingStartedAt;
    final elapsedMilliseconds = startedAt == null
        ? _voiceSeconds * 1000
        : DateTime.now().difference(startedAt).inMilliseconds;
    final durationSeconds = math.max(1, (elapsedMilliseconds / 1000).ceil());
    final conversationId = _conversationId;
    final processingId =
        'voice-processing-${DateTime.now().microsecondsSinceEpoch}';
    final processingMessage = ChatMessage.draft(
      conversationId: conversationId,
      role: 'user',
      content: '',
      clientId: processingId,
      metadata: {
        if (action == VoiceReleaseAction.sendText)
          'voice_transcription_pending': true
        else
          'voice_upload_pending': true,
        'voice_duration_seconds': durationSeconds,
      },
    );
    setState(() {
      _recordingVoice = false;
      _voiceRecordingStartedAt = null;
      _transcribingVoice = true;
    });
    _syncVoiceRecordingOverlay();
    scrollToLatest();
    await amplitudeSub?.cancel();
    final amplitudeSampleCount = _voiceAmplitudeSampleCount;
    final activeMilliseconds = _voiceActiveMilliseconds;

    String? path;
    try {
      path = await _voiceRecorder.stop();
      if (path == null || path.isEmpty) {
        throw Exception('没有录制到语音内容');
      }
      if (shouldRejectSilentVoiceCapture(
        amplitudeSampleCount: amplitudeSampleCount,
        activeMilliseconds: activeMilliseconds,
      )) {
        unawaited(HapticFeedback.warningNotification());
        throw Exception('没有检测到清晰的语音，请重新录制');
      }
      final file = File(path);
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxVoiceBytes) {
        throw Exception('语音文件过大，请录制更短的内容');
      }
      if (mounted && _conversationId == conversationId) {
        setState(() => _messages.add(processingMessage));
        scrollToLatest();
      }
      final result = await widget.api.transcribeChatAudio(
        conversationId: conversationId,
        name: path.split(Platform.pathSeparator).last,
        mime: 'audio/mp4',
        size: bytes.length,
        durationSeconds: durationSeconds,
        displayMode: action == VoiceReleaseAction.sendText ? 'text' : 'voice',
        base64Data: base64Encode(bytes),
      );
      if (!mounted || _conversationId != conversationId) return;
      setState(() {
        _messages.removeWhere((message) => message.id == processingId);
        _transcribingVoice = false;
        _pendingVoiceReleaseAction = null;
        _voiceSeconds = 0;
        _historyError = null;
      });
      if (action == VoiceReleaseAction.sendText) {
        HapticFeedback.mediumImpact();
      }
      final attachment = result.attachment;
      _sendText(
        result.text,
        attachments: attachment == null ? const [] : [attachment],
        clearComposer: false,
      );
    } catch (error) {
      if (mounted && _conversationId == conversationId) {
        setState(() {
          _messages.removeWhere((message) => message.id == processingId);
          _historyError = error is MissingPluginException
              ? '语音功能需要完整重启 App 后才能使用。'
              : _asMessage(error);
        });
      }
    } finally {
      if (path != null) {
        try {
          await File(path).delete();
        } on FileSystemException {
          // Temporary audio is best-effort cleanup; the OS also clears this dir.
        }
      }
      if (mounted && _conversationId == conversationId && _transcribingVoice) {
        setState(() {
          _transcribingVoice = false;
          _voiceSeconds = 0;
          _voiceAmplitudeSampleCount = 0;
          _voiceActiveMilliseconds = 0;
        });
      }
    }
  }

  Future<void> _cancelVoiceRecording() async {
    _pendingVoiceReleaseAction = VoiceReleaseAction.cancel;
    if (_preparingVoice && !_recordingVoice) {
      if (mounted && _voiceGestureActive) {
        setState(() => _voiceGestureActive = false);
      }
      _syncVoiceRecordingOverlay();
      return;
    }
    if (!_recordingVoice) {
      _syncVoiceRecordingOverlay();
      return;
    }
    _voiceTimer?.cancel();
    _voiceTimer = null;
    final amplitudeSub = _voiceAmplitudeSub;
    _voiceAmplitudeSub = null;
    _voiceAmplitude.value = 0.12;
    _voiceAmplitudeSampleCount = 0;
    _voiceActiveMilliseconds = 0;
    if (mounted) {
      setState(() {
        _recordingVoice = false;
        _voiceGestureActive = false;
        _voiceRecordingStartedAt = null;
        _voiceSeconds = 0;
      });
      _syncVoiceRecordingOverlay();
    }
    await amplitudeSub?.cancel();
    try {
      await _voiceRecorder.cancel();
    } on Exception {
      // Cancellation is also used during app lifecycle changes and teardown.
    }
    _voiceAmplitudeSampleCount = 0;
    _voiceActiveMilliseconds = 0;
    _pendingVoiceReleaseAction = null;
  }

  void _sendText(
    String text, {
    ChatComponentCard? componentCard,
    List<ChatAttachment> attachments = const [],
    bool clearComposer = true,
  }) {
    if (text.isEmpty && componentCard == null && attachments.isEmpty) return;
    final clientId =
        'draft-${DateTime.now().microsecondsSinceEpoch}-${(text.isEmpty ? (componentCard?.title ?? attachments.map((item) => item.id).join(',')) : text).hashCode}';
    final metadata = <String, dynamic>{
      if (componentCard != null) 'component_card': componentCard.toJson(),
      if (attachments.isNotEmpty)
        'attachments': attachments.map((item) => item.toJson()).toList(),
    };
    final draft = ChatMessage.draft(
      conversationId: _conversationId,
      role: 'user',
      content: text,
      clientId: clientId,
      metadata: metadata.isEmpty ? null : metadata,
    );
    setState(() {
      _messages.add(draft);
      if (_isMusicStationCard(componentCard)) {
        _musicStation.activate(componentCard!, draft.id);
      }
      if (clearComposer) {
        _inputController.clear();
        _lastInputText = '';
        _pendingImages.clear();
        _pendingLinkPreview = null;
      }
      _panel = ComposerPanel.none;
      _sending = true;
      // Show the typing indicator immediately; the server's pending/delay
      // events keep it alive and the reply clears it.
      _agentTyping = true;
    });
    if (clearComposer && attachments.isEmpty) {
      _inputFocus.requestFocus();
    }

    final sent =
        _socket?.sendMessage(
          text,
          clientId,
          componentCard: componentCard,
          attachments: attachments,
        ) ??
        false;
    if (!sent) {
      _pendingSend = (
        text: text,
        clientId: clientId,
        componentCard: componentCard,
        attachments: attachments,
      );
      unawaited(_socket?.connect());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && clearComposer && attachments.isEmpty) {
        _inputFocus.requestFocus();
      }
      _scrollToBottom(animated: true);
      _scheduleStationDockCheck();
    });
  }

  Future<void> _pickChatImage(ImageSource source) async {
    if (_pendingImages.length >= 3 || _uploadingImage) return;
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
      );
      if (picked == null) return;
      if (!mounted) return;
      setState(() {
        _uploadingImage = true;
        _panel = ComposerPanel.none;
      });
      final bytes = await picked.readAsBytes();
      final dimensions = await _decodeImageDimensions(bytes);
      final mime = picked.mimeType ?? _mimeFromPath(picked.path);
      final attachment = await widget.api.uploadChatImage(
        conversationId: _conversationId,
        name: picked.name,
        mime: mime,
        size: bytes.length,
        width: dimensions.width.round(),
        height: dimensions.height.round(),
        base64Data: base64Encode(bytes),
      );
      if (!mounted) return;
      setState(() {
        _pendingImages.add(
          _PendingChatImage(localPath: picked.path, attachment: attachment),
        );
        _historyError = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _historyError = _asMessage(error));
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<Size> _decodeImageDimensions(Uint8List bytes) async {
    final codec = await instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    return Size(image.width.toDouble(), image.height.toDouble());
  }

  String _mimeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  void _removePendingImage(String id) {
    setState(
      () => _pendingImages.removeWhere((item) => item.attachment.id == id),
    );
  }

  void _removePendingLink() {
    setState(() => _pendingLinkPreview = null);
  }

  Future<void> _openPendingLink(_PendingLinkPreview pendingLink) async {
    await _openComponentCard(pendingLink.preview.componentCard);
  }

  Future<void> _previewPendingImage(_PendingChatImage image) async {
    await _showImagePreview(localPath: image.localPath);
  }

  Future<void> _previewAttachment(ChatAttachment attachment) async {
    await _showImagePreview(url: attachment.url);
  }

  Future<void> _showImagePreview({String? localPath, String? url}) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'image-preview',
      barrierColor: Colors.black.withValues(alpha: 0.86),
      pageBuilder: (_, __, ___) {
        final headers = widget.api.authToken?.isNotEmpty == true
            ? {'Authorization': 'Bearer ${widget.api.authToken}'}
            : null;
        final image = localPath != null
            ? Image.file(File(localPath), fit: BoxFit.contain)
            : Image.network(url ?? '', fit: BoxFit.contain, headers: headers);
        return Material(
          type: MaterialType.transparency,
          child: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: InteractiveViewer(
                      minScale: 0.7,
                      maxScale: 4,
                      child: Center(child: image),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _RoundIconButton(
                    tooltip: '关闭',
                    icon: CupertinoIcons.xmark,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _scrollToBottom({bool animated = false}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animated) {
      unawaited(
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        ),
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  /// Jumps to the newest message and keeps chasing the true bottom across the
  /// next few frames. On first open the ListView.builder only measures the
  /// visible items, so its initial maxScrollExtent is an estimate; a single
  /// jump lands short. Re-jumping while the extent keeps growing settles the
  /// list exactly at the latest message.
  void _jumpToBottomSettled({int remaining = 6}) {
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    _scrollController.jumpTo(position.maxScrollExtent);
    if (remaining <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final next = _scrollController.position;
      if (next.pixels < next.maxScrollExtent - 1) {
        _jumpToBottomSettled(remaining: remaining - 1);
      }
    });
  }

  void _setPanel(ComposerPanel panel) {
    _panelHoldTimer?.cancel();
    final nextPanel = _panel == panel ? ComposerPanel.none : panel;
    final opening = nextPanel != ComposerPanel.none;
    setState(() {
      _heldPanel = ComposerPanel.none;
      _panel = nextPanel;
      // Opening the emoji / more panel returns the composer to text mode so
      // the "按住说话" button is replaced by the text field.
      if (opening) {
        _voiceInputMode = false;
      }
    });
    if (opening) {
      FocusScope.of(context).unfocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToBottom(animated: true);
      });
    }
  }

  void _focusInput() {
    // Summoning the keyboard always pulls the conversation to the newest
    // message, mirroring the emoji/more panel behaviour. The pin then keeps
    // the list glued to the composer while the keyboard animates up.
    _pinToBottomDuringKeyboard = true;
    _panelHoldTimer?.cancel();
    final panelToHold = _panel != ComposerPanel.none ? _panel : _heldPanel;
    setState(() {
      _panel = ComposerPanel.none;
      _heldPanel = panelToHold;
    });
    _inputFocus.requestFocus();
    // Covers the cases the keyboard-pin cannot: keyboard already open (cursor
    // re-tap, panel -> keyboard switch with unchanged composer offset), where
    // no padding delta ever fires the pinned scroll sync.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToBottom(animated: true);
    });
    if (panelToHold != ComposerPanel.none) {
      _panelHoldTimer = Timer(const Duration(milliseconds: 360), () {
        if (!mounted || _heldPanel == ComposerPanel.none) return;
        setState(() => _heldPanel = ComposerPanel.none);
      });
    }
  }

  void _toggleVoiceInputMode() {
    if (_preparingVoice || _recordingVoice || _transcribingVoice) return;
    _panelHoldTimer?.cancel();
    final next = !_voiceInputMode;
    setState(() {
      _voiceInputMode = next;
      _panel = ComposerPanel.none;
      _heldPanel = ComposerPanel.none;
      _pinToBottomDuringKeyboard = false;
    });
    if (next) {
      FocusScope.of(context).unfocus();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _inputFocus.requestFocus();
      });
    }
  }

  void _dismissInputSurfaces() {
    FocusScope.of(context).unfocus();
    _panelHoldTimer?.cancel();
    if (_panel == ComposerPanel.none &&
        _heldPanel == ComposerPanel.none &&
        !_pinToBottomDuringKeyboard) {
      return;
    }
    setState(() {
      _panel = ComposerPanel.none;
      _heldPanel = ComposerPanel.none;
      _pinToBottomDuringKeyboard = false;
    });
  }

  bool _isNearBottomNow() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels < 120;
  }

  double _composerHeightForWidth(double screenWidth) {
    final inputWidth = math.max(120.0, screenWidth - 190.0);
    final text = _inputController.text.isEmpty ? ' ' : _inputController.text;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 16, height: 1.25),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 3,
    )..layout(maxWidth: inputWidth);
    final lineHeight = painter.preferredLineHeight;
    final lineCount = (painter.height / lineHeight).ceil().clamp(1, 3);
    final hasPendingAttachment =
        _pendingImages.isNotEmpty || _pendingLinkPreview != null;
    final attachmentHeight = hasPendingAttachment ? 86.0 : 0.0;
    return _composerMinHeight +
        attachmentHeight +
        (lineCount - 1) * _composerLineHeight;
  }

  void _appendEmoji(String emoji) {
    final text = _inputController.text;
    final selection = _inputController.selection;
    final index = selection.isValid ? selection.start : text.length;
    final updated = text.replaceRange(index, index, emoji);
    _inputController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: index + emoji.length),
    );
  }

  void _syncScrollWithBottomPadding(
    double nextPadding, {
    required bool forcePinToBottom,
    required bool followKeyboardMetrics,
  }) {
    final previousPadding = _lastListBottomPadding;
    if (_scrollController.hasClients && previousPadding != null) {
      final position = _scrollController.position;
      _wasNearBottomBeforePaddingChange =
          forcePinToBottom || position.maxScrollExtent - position.pixels < 120;
    }
    _lastListBottomPadding = nextPadding;
    if (previousPadding == null) return;
    final delta = nextPadding - previousPadding;
    if (delta.abs() < 1) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      final double target;
      if (forcePinToBottom || _wasNearBottomBeforePaddingChange) {
        target = position.maxScrollExtent;
      } else {
        return;
      }
      if (followKeyboardMetrics) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(
          target,
          duration: _animationDuration,
          curve: _animationCurve,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isKeyboardOpen = bottomInset > 0;
    final wasKeyboardOpen = _lastKeyboardInset > 0;
    if (!wasKeyboardOpen && isKeyboardOpen) {
      // Keyboard opening always pins the list to the newest message (also for
      // focus paths that bypass _focusInput, e.g. leaving voice input mode).
      _pinToBottomDuringKeyboard = true;
    } else if (wasKeyboardOpen && bottomInset < _lastKeyboardInset) {
      // Keyboard began closing: drop the hard pin so a drag-to-dismiss is not
      // fought by per-frame bottom jumps. The near-bottom tracking inside
      // _syncScrollWithBottomPadding still rides the composer down when the
      // user is at the live end.
      _pinToBottomDuringKeyboard = false;
    }
    final visiblePanel = _panel != ComposerPanel.none ? _panel : _heldPanel;
    final visiblePanelHeight = _panelHeightFor(visiblePanel);
    final composerHeight = _composerHeightForWidth(
      MediaQuery.sizeOf(context).width,
    );
    // Lift the composer by the tallest keyboard inset seen this focus session
    // instead of the live inset. iOS pinyin keyboards grow/shrink by a row as
    // the composing-letters strip toggles mid-typing; following the live inset
    // made the whole composer bob up and down on every word boundary. Holding
    // the session max lifts it once (when the strip first appears) and then
    // keeps it steady. When focus is lost (keyboard closing / dismissed) we
    // follow the inset straight down so the close still tracks the keyboard.
    final double keyboardLift;
    if (!isKeyboardOpen) {
      _keyboardSessionMaxInset = 0;
      keyboardLift = 0;
    } else if (_inputFocus.hasFocus) {
      if (bottomInset > _keyboardSessionMaxInset) {
        _keyboardSessionMaxInset = bottomInset;
      }
      keyboardLift = _keyboardSessionMaxInset;
    } else {
      _keyboardSessionMaxInset = bottomInset;
      keyboardLift = bottomInset;
    }
    final panelHeight = visiblePanelHeight;
    // Use viewPadding (not padding) for the bottom safe area: an open keyboard
    // collapses padding.bottom to 0, which would shrink tabBarLift while the
    // keyboard is up and re-grow it as the keyboard closes. Because that regrow
    // lags the keyboard's descent, the composer would dip below its rest offset
    // then rise back ("先下落再回升"). viewPadding stays constant regardless of
    // the keyboard, keeping the panel/rest target stable for a direct transition.
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    final safeTop = MediaQuery.paddingOf(context).top;
    final tabBarLift = _tabBarContentHeight + safeBottom;
    final panelVisible = visiblePanel != ComposerPanel.none;
    // The emoji / more panel docks to the very bottom of the screen and owns
    // the safe-area strip, mirroring the keyboard (the shell hides the floating
    // tab bar while it is up — see onComposerPanelChanged). It keeps its own
    // content height rather than copying the keyboard's: matching the keyboard
    // left large dead space inside the panel, and the max() below still gives
    // a direct no-bounce ride between the two heights when switching.
    final panelSurfaceHeight = panelVisible ? panelHeight + safeBottom : 0.0;
    // Fixed full height of the panel surface (content + safe area). Used to
    // slide the panel in/out from below rather than growing its height.
    final panelContentHeight = _composerPanelHeight + safeBottom;
    if (panelVisible) {
      _lastDisplayedPanel = visiblePanel;
    }
    // While closing, keep rendering the last panel so it can slide down with
    // real content; it is cleared in the panel's onEnd once fully off screen.
    final displayedPanel = panelVisible ? visiblePanel : _lastDisplayedPanel;
    // Where the composer settles once the keyboard is fully closed: on top of
    // the docked panel, or above the floating tab bar when nothing is up.
    final restLift = panelVisible ? panelSurfaceHeight : tabBarLift;
    // max() keeps the composer from ever dipping below its rest target while
    // the keyboard animates away (direct transition, no bounce).
    final composerBottom = isKeyboardOpen
        ? math.max(keyboardLift, restLift)
        : restLift;
    final inputSurfaceHeight = composerHeight + composerBottom;
    _syncComposerPanelVisibility(panelVisible);
    final stationTrack = _stationTrack;
    final showStationDock = stationTrack != null && _stationDockActive;
    final listBottomPadding = inputSurfaceHeight + 18;
    const listTopPadding = 10.0;
    final keyboardTransition = isKeyboardOpen || wasKeyboardOpen;
    // Keyboard-driven moves stay instant (they track the OS keyboard metrics
    // frame by frame, which already ease out). Pure panel opens / switches use
    // an ease-out (fast then slow) transition.
    final positionDuration = keyboardTransition
        ? Duration.zero
        : _animationDuration;
    final forceKeyboardPin = _pinToBottomDuringKeyboard && keyboardTransition;
    _syncScrollWithBottomPadding(
      listBottomPadding,
      forcePinToBottom: forceKeyboardPin,
      followKeyboardMetrics: keyboardTransition,
    );
    _lastKeyboardInset = bottomInset;
    if (!isKeyboardOpen && wasKeyboardOpen) {
      _pinToBottomDuringKeyboard = false;
    }
    final agentAvatarUrl = _agentAvatarUrl;

    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFF6FDFC)),
      child: Stack(
        children: [
          Column(
            children: [
              _ChatHeader(
                agentName: widget.session.agentName ?? 'Companion',
                topInset: safeTop,
                interactionDays: _conversationMeta?.interactionDays,
                aiStatus: _conversationMeta?.aiStatus,
                aiStatusLabel: _conversationMeta?.aiStatusLabel,
                aiActivity: _conversationMeta?.aiActivity,
                avatarUrl: agentAvatarUrl,
                isMusicListening: _isUserCoListening,
                isMusicPlaying:
                    _conversationMeta?.musicCoListening?.isPlaying ?? false,
                onMusicTap: _openActiveMusic,
                onAvatarDoubleTap: _showDemoAchievementNotice,
                onInteractionTap: _openInteractionDetail,
                onOpenSidebar: widget.onOpenSidebar,
              ),
              if (_historyError != null)
                _InlineBanner(
                  text: _historyError!,
                  onRetry: () => _loadLatestMessages(showLoading: true),
                ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _dismissInputSurfaces,
                  child: _loadingInitial
                      ? const Center(child: CircularProgressIndicator())
                      : _MessageList(
                          controller: _scrollController,
                          messages: _messages,
                          isLoadingOlder: _loadingOlder,
                          showTyping: _agentTyping,
                          bottomPadding: listBottomPadding,
                          topPadding: listTopPadding,
                          onComponentCardTap: _openComponentCard,
                          onAchievementTap: _openAchievementDetail,
                          onResolveMusicTrack: _resolveMusicTrack,
                          onMusicCardActivated: _activateMusicStationCard,
                          onMusicPrevious: () =>
                              unawaited(_playPreviousStationTrack()),
                          onMusicNext: () => unawaited(_playNextStationTrack()),
                          onMusicFavorite: (track) =>
                              unawaited(_toggleMusicFavorite(track)),
                          onAttachmentTap: _previewAttachment,
                          activeMusicMessageId: _musicStation.activeMessageId,
                          musicCardPositions: _musicStation.cardPositions,
                          favoriteMusicTrackIds: _favoriteMusicTrackIds,
                          busyMusicFavoriteIds: _busyMusicFavoriteIds,
                          canGoMusicPrevious: _canGoStationPrevious,
                          isMusicBusy: _advancingStation,
                          stationMessageId: _musicStation.messageId,
                          stationMessageKey: _stationCardKey,
                          agentAvatarUrl: agentAvatarUrl,
                          userAvatarUrl: widget.session.userAvatarUrl,
                          authToken: widget.api.authToken,
                          apiBaseUrl: widget.api.baseUrl,
                        ),
                ),
              ),
            ],
          ),
          AnimatedPositioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: inputSurfaceHeight,
            duration: positionDuration,
            curve: _animationCurve,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Color(0xFFF6FDFC)),
              ),
            ),
          ),
          AnimatedPositioned(
            left: 0,
            right: 0,
            bottom: composerBottom,
            duration: positionDuration,
            curve: _animationCurve,
            child: _Composer(
              controller: _inputController,
              focusNode: _inputFocus,
              height: composerHeight,
              activePanel: _panel,
              voiceInputMode: _voiceInputMode,
              sending:
                  _sending ||
                  _uploadingImage ||
                  _preparingVoice ||
                  _recordingVoice ||
                  _transcribingVoice,
              preparingVoice: _preparingVoice,
              recordingVoice: _recordingVoice,
              transcribingVoice: _transcribingVoice,
              resolvingLink:
                  _linkPreviewInFlightText != null &&
                  _pendingLinkPreview == null,
              pendingImages: _pendingImages,
              pendingLink: _pendingLinkPreview,
              authToken: widget.api.authToken,
              onFocusInput: _focusInput,
              onToggleEmoji: () => _setPanel(ComposerPanel.emoji),
              onShowKeyboard: _focusInput,
              onToggleMore: () => _setPanel(ComposerPanel.more),
              onToggleVoiceInput: _toggleVoiceInputMode,
              onSend: _sendMessage,
              onVoicePressStart: _handleVoicePressStart,
              onVoicePressMove: _handleVoicePressMove,
              onVoicePressEnd: _handleVoicePressEnd,
              onVoicePressCancel: _handleVoicePressCancel,
              onRemoveImage: _removePendingImage,
              onPreviewImage: _previewPendingImage,
              onRemoveLink: _removePendingLink,
              onPreviewLink: _openPendingLink,
              onPasteText: _handleComposerPasteText,
            ),
          ),
          AnimatedPositioned(
            left: 0,
            right: 0,
            // Slide the whole panel up from below the screen (like the
            // keyboard) instead of growing its height in place: fixed height +
            // animated offset keeps content from squishing. Uses its own
            // duration (not the keyboard-synced positionDuration) so the slide
            // also plays during keyboard <-> panel switches.
            bottom: panelVisible ? 0 : -panelContentHeight,
            height: panelContentHeight,
            duration: _animationDuration,
            curve: _animationCurve,
            onEnd: () {
              if (!panelVisible &&
                  mounted &&
                  _lastDisplayedPanel != ComposerPanel.none) {
                setState(() => _lastDisplayedPanel = ComposerPanel.none);
              }
            },
            child: ClipRect(
              child: _ChatPanel(
                panel: displayedPanel,
                bottomInset: safeBottom,
                onEmojiTap: _appendEmoji,
                onPickPhoto: () =>
                    unawaited(_pickChatImage(ImageSource.gallery)),
                onTakePhoto: () =>
                    unawaited(_pickChatImage(ImageSource.camera)),
              ),
            ),
          ),
          AnimatedPositioned(
            left: 0,
            right: 0,
            bottom: inputSurfaceHeight + 12,
            duration: _animationDuration,
            curve: _animationCurve,
            child: IgnorePointer(
              ignoring: _newMessageCount == 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                opacity: _newMessageCount > 0 ? 1 : 0,
                child: Center(
                  child: _NewMessagesButton(
                    count: _newMessageCount,
                    onTap: () => scrollToLatest(),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: safeTop + 74,
            left: 26,
            right: 24,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              offset: showStationDock ? Offset.zero : const Offset(0, -0.35),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                opacity: showStationDock ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !showStationDock,
                  child: stationTrack == null
                      ? const SizedBox.shrink()
                      : _StickyMusicDock(
                          track: stationTrack,
                          isPlaying: _isStationPlaying,
                          isLoading: _isStationLoading || _advancingStation,
                          canGoPrevious: _canGoStationPrevious,
                          isBusy: _advancingStation,
                          onTap: _openStationMusic,
                          onPrevious: () =>
                              unawaited(_playPreviousStationTrack()),
                          onNext: () => unawaited(_playNextStationTrack()),
                          onTogglePlay: () =>
                              unawaited(_toggleStationPlayback()),
                        ),
                ),
              ),
            ),
          ),
          Positioned(
            top: safeTop + 84,
            left: 58,
            right: 58,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final curved = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                );
                return FadeTransition(
                  opacity: curved,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.18),
                      end: Offset.zero,
                    ).animate(curved),
                    child: child,
                  ),
                );
              },
              child:
                  _readyCapsule == null ||
                      _readyCapsule!.id == _dismissedReadyCapsuleId
                  ? const SizedBox.shrink()
                  : _ReadyCapsuleBanner(
                      key: ValueKey(_readyCapsule!.id),
                      capsule: _readyCapsule!,
                      onTap: _openReadyCapsuleNotice,
                      onDismiss: _dismissReadyCapsuleBanner,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewMessagesButton extends StatelessWidget {
  const _NewMessagesButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = count <= 1 ? '有新消息' : '$count 条新消息';
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 16, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.arrow_down,
                color: Colors.white,
                size: 15,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StickyMusicDock extends StatefulWidget {
  const _StickyMusicDock({
    required this.track,
    required this.isPlaying,
    required this.isLoading,
    required this.canGoPrevious,
    required this.isBusy,
    required this.onTap,
    required this.onPrevious,
    required this.onNext,
    required this.onTogglePlay,
  });

  final MusicTrack track;
  final bool isPlaying;
  final bool isLoading;
  final bool canGoPrevious;
  final bool isBusy;
  final VoidCallback onTap;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onTogglePlay;

  @override
  State<_StickyMusicDock> createState() => _StickyMusicDockState();
}

class _StickyMusicDockState extends State<_StickyMusicDock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _discController;

  @override
  void initState() {
    super.initState();
    _discController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 18000),
    );
    _syncDisc();
  }

  @override
  void didUpdateWidget(covariant _StickyMusicDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying ||
        oldWidget.isLoading != widget.isLoading ||
        oldWidget.track.id != widget.track.id) {
      _syncDisc();
    }
  }

  void _syncDisc() {
    if (widget.isPlaying && !widget.isLoading) {
      if (!_discController.isAnimating) _discController.repeat();
    } else if (_discController.isAnimating) {
      _discController.stop(canceled: false);
    }
  }

  @override
  void dispose() {
    _discController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _musicAccentForTrack(widget.track);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF0F1A27).withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.20),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: RepaintBoundary(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.24),
                              blurRadius: 18,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: AnimatedBuilder(
                          animation: _discController,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _discController.value * math.pi * 2,
                              child: child,
                            );
                          },
                          child: _MusicDisc(track: widget.track, size: 64),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LoopingMarqueeText(
                          text: widget.track.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            height: 1.12,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${_musicLibraryTitle(widget.track.library)} 频道 · ${widget.track.artist}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.62),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  height: 1.12,
                                ),
                              ),
                            ),
                            Text(
                              ' · ',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.48),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                height: 1.12,
                              ),
                            ),
                            _MusicCountdownText(
                              track: widget.track,
                              isActiveCard: true,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.66),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                height: 1.12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  _DockIconButton(
                    icon: CupertinoIcons.backward_fill,
                    enabled: widget.canGoPrevious && !widget.isBusy,
                    accent: accent,
                    onPressed: widget.onPrevious,
                  ),
                  _DockIconButton(
                    icon: widget.isPlaying
                        ? CupertinoIcons.pause_fill
                        : CupertinoIcons.play_fill,
                    emphasized: true,
                    enabled: !widget.isBusy && !widget.isLoading,
                    loading: widget.isLoading,
                    accent: accent,
                    onPressed: widget.onTogglePlay,
                  ),
                  _DockIconButton(
                    icon: CupertinoIcons.forward_fill,
                    enabled: !widget.isBusy,
                    accent: accent,
                    onPressed: widget.onNext,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockIconButton extends StatelessWidget {
  const _DockIconButton({
    required this.icon,
    required this.enabled,
    required this.accent,
    required this.onPressed,
    this.emphasized = false,
    this.loading = false,
  });

  final IconData icon;
  final bool enabled;
  final Color accent;
  final bool emphasized;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final boxSize = emphasized ? 40.0 : 32.0;
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: enabled && !loading ? onPressed : null,
      child: SizedBox(
        width: boxSize,
        height: boxSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: emphasized && (enabled || loading) ? accent : null,
          ),
          child: Center(
            child: loading
                ? const CupertinoActivityIndicator(
                    radius: 8,
                    color: Colors.white,
                  )
                : Transform.translate(
                    offset: emphasized && icon == CupertinoIcons.play_fill
                        ? const Offset(1.2, 0)
                        : Offset.zero,
                    child: Icon(
                      icon,
                      color: enabled
                          ? (emphasized
                                ? _musicButtonForeground(accent)
                                : Colors.white.withValues(alpha: 0.72))
                          : Colors.white.withValues(alpha: 0.26),
                      size: emphasized ? 18 : 15,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

Color _musicAccentForTrack(MusicTrack? track) {
  final primary = _parseMusicAccent(track?.accentA);
  if (_isReadableMusicAccent(primary)) return primary;
  final secondary = _parseMusicAccent(track?.accentB);
  if (_isReadableMusicAccent(secondary)) return secondary;
  return _fallbackMusicAccent(track);
}

String _musicLibraryTitle(String? id) {
  return switch ((id ?? '').trim().toLowerCase()) {
    'focus' => '专注',
    'ambient' => 'Ambient',
    'sleep' => '睡眠',
    'relax' => '放松',
    'vocal' => '原声',
    'default' => '默认',
    final value when value.isNotEmpty => value,
    _ => '音乐',
  };
}

String _formatMusicClock(Duration value) {
  final totalSeconds = math.max(value.inSeconds, 0);
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

Color _parseMusicAccent(String? value) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) return const Color(0xFF2CD6C9);
  final normalized = raw.startsWith('#') ? raw : '#$raw';
  const palette = {
    '#1F6FFF': Color(0xFF2F80FF),
    '#18C6C0': Color(0xFF2CD6C9),
    '#7C3CFF': Color(0xFF7B5CFF),
    '#FF7A2F': Color(0xFFFF7A2F),
    '#20C46B': Color(0xFF21D57B),
  };
  final key = normalized.toUpperCase();
  final mapped = palette[key];
  if (mapped != null) return mapped;
  return _parseMusicDockColor(normalized);
}

bool _isReadableMusicAccent(Color color) {
  return color.computeLuminance() >= 0.10;
}

Color _musicButtonForeground(Color accent) {
  return accent.computeLuminance() >= 0.34
      ? const Color(0xFF071522)
      : Colors.white;
}

Color _fallbackMusicAccent(MusicTrack? track) {
  const palette = [
    Color(0xFF2F80FF),
    Color(0xFF2CD6C9),
    Color(0xFF21D57B),
    Color(0xFFFF7A2F),
    Color(0xFF8D6CFF),
  ];
  final seed =
      '${track?.id ?? ''}|${track?.title ?? ''}|${track?.artist ?? ''}|${track?.library ?? ''}';
  var hash = 17;
  for (final unit in seed.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return palette[hash % palette.length];
}

Color _parseMusicDockColor(String value) {
  final hex = value.replaceFirst('#', '').trim();
  if (hex.length != 6) return const Color(0xFF2CD6C9);
  final intValue = int.tryParse(hex, radix: 16);
  if (intValue == null) return const Color(0xFF2CD6C9);
  return Color(0xFF000000 | intValue);
}

class _ReadyCapsuleBanner extends StatelessWidget {
  const _ReadyCapsuleBanner({
    super.key,
    required this.capsule,
    required this.onTap,
    required this.onDismiss,
  });

  final TimeCapsule capsule;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final date = capsule.openDate;
    final dateText = date == null ? '今天' : _formatCapsuleShortDate(date);
    final colors = AppColors.of(context);
    final isDark = AppColors.isDark(context);
    final accent = const Color(0xFF7C3CFF);
    return SizedBox(
      height: 62,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfaceMuted.withValues(alpha: 0.92)
                  : Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.80),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.34)
                      : accent.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: isDark ? 0.04 : 0.70),
                  blurRadius: 1,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CupertinoButton(
                    minimumSize: Size.zero,
                    padding: EdgeInsets.zero,
                    onPressed: onTap,
                    child: const SizedBox.expand(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 7, 42, 7),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/chat_sidebar/sidebar-capsule.png',
                        width: 48,
                        height: 48,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '有一个新胶囊待开启',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.text,
                                fontSize: 15,
                                height: 1.12,
                                fontWeight: FontWeight.w900,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$dateText 开启，点一下看看',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.muted,
                                fontSize: 12,
                                height: 1.1,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: CupertinoButton(
                      minimumSize: Size.zero,
                      padding: EdgeInsets.zero,
                      onPressed: onDismiss,
                      child: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFF3F6FA),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : const Color(0xFFE4EAF1),
                          ),
                        ),
                        child: Icon(
                          CupertinoIcons.xmark,
                          color: isDark
                              ? colors.muted
                              : const Color(0xFF7F8893),
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
