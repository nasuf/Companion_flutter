part of 'package:companion_flutter/main.dart';

enum ComposerPanel { none, emoji, more }

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.api,
    required this.session,
    required this.isActive,
    required this.onOpenSidebar,
    this.onAchievementDetailRequested,
    this.onAchievementOverlayChanged,
  });

  final CompanionApi api;
  final AuthSession session;
  final bool isActive;
  final VoidCallback onOpenSidebar;
  final ValueChanged<AchievementItem>? onAchievementDetailRequested;
  final ValueChanged<bool>? onAchievementOverlayChanged;

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
  if (!path.startsWith('/chat/media/')) return null;
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
  static final _supportedSharedLinkPattern = RegExp(
    r'(?:https?:\/\/)?(?:[\w-]+\.)?(?:xhslink\.com|xiaohongshu\.com|v\.douyin\.com|douyin\.com|iesdouyin\.com|weibo\.com|weibo\.cn|t\.cn|toutiao\.com|snssdk\.com|zhihu\.com|zhuanlan\.zhihu\.com|b23\.tv|bilibili\.com)\/[^\s，。；：）】》]+',
    caseSensitive: false,
  );

  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  final _inputFocus = FocusNode();
  final _imagePicker = ImagePicker();
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
  Timer? _panelHoldTimer;
  Timer? _capsuleScanTimer;
  Timer? _conversationMetaTimer;
  TimeCapsule? _readyCapsule;
  Conversation? _conversationMeta;
  bool _loadingInitial = true;
  bool _loadingOlder = false;
  bool _hasOlderMessages = false;
  bool _sending = false;
  String? _historyError;
  int _loadedServerMessages = 0;
  double? _lastListBottomPadding;
  double _lastKeyboardInset = 0;
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
    _capsuleScanTimer?.cancel();
    _conversationMetaTimer?.cancel();
    _stationPauseTimer?.cancel();
    _musicCompleteSub?.cancel();
    _shareIntentSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
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
        if (showLoading || !hadScrollPosition || wasNearBottom) {
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
    _localUserCoListeningActive = _userCoListeningActiveFromMessages(_messages);
  }

  void _mergeLatestServerMessages(List<ChatMessage> serverMessages) {
    for (final serverMessage in serverMessages) {
      _upsertServerMessage(serverMessage);
    }
    _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _localUserCoListeningActive = _userCoListeningActiveFromMessages(_messages);
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

  bool _userCoListeningActiveFromMessages(List<ChatMessage> messages) {
    var active = false;
    for (final message in messages) {
      final metadata = message.metadata;
      if (metadata == null) continue;
      final status = metadata['music_status']?.toString();
      if (status == 'started') {
        active = true;
      } else if (status == 'ended') {
        active = false;
      }
    }
    return active;
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
      setState(() => _readyCapsule = ready.isEmpty ? null : ready.first);
    } catch (error) {
      debugPrint('[capsule.ready] scan failed: $error');
    }
  }

  void refreshReadyCapsules() {
    unawaited(_scanReadyCapsules());
    _scheduleNextCapsuleScan();
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
    if (capsule == null) return;
    _dismissInputSurfaces();
    final shouldOpen = await showGeneralDialog<bool>(
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
    final session = _conversationMeta?.musicCoListening;
    return _localUserCoListeningActive ||
        (session?.isActive == true && session?.initiatedBy != 'agent_auto');
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
        break;
      case 'pending':
        setState(() => _sending = false);
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
        setState(() {
          if (status == 'ended') {
            _clearStationDock();
          }
          final actor = payload['actor']?.toString() ?? '';
          if (status == 'started') {
            _localUserCoListeningActive = true;
          } else if (status == 'ended') {
            _localUserCoListeningActive = false;
          }
          _messages.add(
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
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (shouldAutoScroll) _scrollToBottom(animated: true);
          _scheduleStationDockCheck();
        });
        break;
      case 'done':
        setState(() => _sending = false);
        unawaited(_loadLatestMessages(showLoading: false));
        break;
      case 'error':
        setState(() {
          _sending = false;
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

  void _setPanel(ComposerPanel panel) {
    _panelHoldTimer?.cancel();
    final nextPanel = _panel == panel ? ComposerPanel.none : panel;
    setState(() {
      _heldPanel = ComposerPanel.none;
      _panel = nextPanel;
    });
    if (nextPanel != ComposerPanel.none) {
      FocusScope.of(context).unfocus();
    }
  }

  void _focusInput() {
    _pinToBottomDuringKeyboard = _isNearBottomNow();
    _panelHoldTimer?.cancel();
    final panelToHold = _panel != ComposerPanel.none ? _panel : _heldPanel;
    setState(() {
      _panel = ComposerPanel.none;
      _heldPanel = panelToHold;
    });
    _inputFocus.requestFocus();
    if (panelToHold != ComposerPanel.none) {
      _panelHoldTimer = Timer(const Duration(milliseconds: 360), () {
        if (!mounted || _heldPanel == ComposerPanel.none) return;
        setState(() => _heldPanel = ComposerPanel.none);
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
      _pinToBottomDuringKeyboard = _isNearBottomNow();
    }
    final visiblePanel = _panel != ComposerPanel.none ? _panel : _heldPanel;
    final visiblePanelHeight = _panelHeightFor(visiblePanel);
    final composerHeight = _composerHeightForWidth(
      MediaQuery.sizeOf(context).width,
    );
    final keyboardLift = isKeyboardOpen ? bottomInset : 0.0;
    final panelHeight = visiblePanelHeight;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final tabBarLift = _tabBarContentHeight + safeBottom;
    final composerBottom = isKeyboardOpen
        ? math.max(keyboardLift, tabBarLift + panelHeight)
        : tabBarLift + panelHeight;
    final inputSurfaceHeight = composerHeight + composerBottom;
    final stationTrack = _stationTrack;
    final showStationDock = stationTrack != null && _stationDockActive;
    final listBottomPadding = inputSurfaceHeight + 18;
    const listTopPadding = 10.0;
    final keyboardTransition = isKeyboardOpen || wasKeyboardOpen;
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

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          Column(
            children: [
              _ChatHeader(
                agentName: widget.session.agentName ?? 'Companion',
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
                decoration: BoxDecoration(
                  color: AppColors.page.withValues(alpha: 0.96),
                ),
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
              sending: _sending || _uploadingImage,
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
              onSend: _sendMessage,
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
            bottom: tabBarLift,
            height: panelHeight,
            duration: positionDuration,
            curve: _animationCurve,
            child: ClipRect(
              child: _ChatPanel(
                panel: visiblePanel,
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
            top: 74,
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
            top: 74,
            left: 18,
            right: 18,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _readyCapsule == null
                  ? const SizedBox.shrink()
                  : _ReadyCapsuleBanner(
                      key: ValueKey(_readyCapsule!.id),
                      capsule: _readyCapsule!,
                      onTap: _openReadyCapsuleNotice,
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
  });

  final TimeCapsule capsule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = capsule.openDate;
    final dateText = date == null ? '今天' : _formatCapsuleShortDate(date);
    final colors = AppColors.of(context);
    final isDark = AppColors.isDark(context);
    final accent = const Color(0xFF7C3CFF);
    return Align(
      alignment: Alignment.topCenter,
      child: CupertinoButton(
        minimumSize: Size.zero,
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: 54,
              padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceMuted.withValues(alpha: 0.92)
                    : Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.78),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.38)
                        : accent.withValues(alpha: 0.16),
                    blurRadius: isDark ? 26 : 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [accent, colors.accentDeep],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: isDark ? 0.34 : 0.18),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: CustomPaint(
                        size: Size(22, 22),
                        painter: _CapsuleSidebarIconPainter(
                          accent: Color(0xFF7C3CFF),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
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
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        Text(
                          '$dateText 开启，点一下看看',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    CupertinoIcons.chevron_down,
                    color: isDark ? colors.accentDeep : accent,
                    size: 18,
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
