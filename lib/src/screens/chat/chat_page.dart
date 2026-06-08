part of 'package:companion_flutter/main.dart';

enum ComposerPanel { none, emoji, more }

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.api,
    required this.session,
    required this.onOpenSidebar,
    this.onAchievementDetailRequested,
    this.onAchievementOverlayChanged,
  });

  final CompanionApi api;
  final AuthSession session;
  final VoidCallback onOpenSidebar;
  final ValueChanged<AchievementItem>? onAchievementDetailRequested;
  final ValueChanged<bool>? onAchievementOverlayChanged;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  static const _animationDuration = Duration(milliseconds: 260);
  static const _animationCurve = Curves.easeOutCubic;
  static const _composerHeight = 68.0;
  static const _tabBarContentHeight = 64.0;
  static const _emojiPanelHeight = 238.0;
  static const _morePanelHeight = 236.0;
  static const _messagePageSize = 100;
  static const _loadOlderThreshold = 80.0;

  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  final _inputFocus = FocusNode();
  final List<ChatMessage> _messages = [];

  ChatSocket? _socket;
  StreamSubscription<WsEnvelope>? _eventSub;
  StreamSubscription<ChatSocketState>? _stateSub;
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
  ({String text, String clientId, ChatComponentCard? componentCard})?
  _pendingSend;
  int _achievementDemoIndex = 0;

  String get _conversationId => widget.session.conversationId!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_handleScroll);
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
    _scrollController.dispose();
    _inputController.dispose();
    _inputFocus.dispose();
    _eventSub?.cancel();
    _stateSub?.cancel();
    _socket?.close();
    _panelHoldTimer?.cancel();
    _capsuleScanTimer?.cancel();
    _conversationMetaTimer?.cancel();
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
      ComposerPanel.emoji => _emojiPanelHeight,
      ComposerPanel.more => _morePanelHeight,
      ComposerPanel.none => 0,
    };
  }

  Future<void> _bootstrapChat() async {
    await _eventSub?.cancel();
    await _stateSub?.cancel();
    await _socket?.close();
    _panelHoldTimer?.cancel();
    _capsuleScanTimer?.cancel();
    _conversationMetaTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _messages.clear();
      _panel = ComposerPanel.none;
      _heldPanel = ComposerPanel.none;
      _loadingInitial = true;
      _loadingOlder = false;
      _hasOlderMessages = false;
      _loadedServerMessages = 0;
      _historyError = null;
      _pendingSend = null;
      _readyCapsule = null;
      _conversationMeta = null;
    });
    widget.onAchievementOverlayChanged?.call(false);
    await Future.wait([
      _loadLatestMessages(showLoading: true),
      _refreshConversationMeta(),
    ]);
    unawaited(_scanReadyCapsules());
    _scheduleNextCapsuleScan();
    _scheduleConversationMetaRefresh();
    _connectSocket();
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

  Future<void> _loadLatestMessages({required bool showLoading}) async {
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
        _replaceWithServerMessages(chronological);
        _hasOlderMessages =
            _countServerMessages(newestFirst) == _messagePageSize;
        _loadedServerMessages = _countServerMessages(_messages);
        _historyError = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
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
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final delta = _scrollController.position.maxScrollExtent - oldMaxExtent;
        _scrollController.jumpTo(oldPixels + delta);
      });
    } catch (error) {
      if (mounted) setState(() => _historyError = _asMessage(error));
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  Future<void> _openComponentCard(ChatComponentCard card) async {
    if (card.type == 'music_track') {
      final rawTrack = card.payload['track'];
      final track = rawTrack is Map
          ? MusicTrack.fromJson(Map<String, dynamic>.from(rawTrack))
          : null;
      if (track == null) return;
      final initialTrack = await _resolveMusicTrack(track) ?? track;
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
    final initialTrack = await _resolveMusicTrack(track) ?? track;
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
      final opened = await widget.api.openTimeCapsule(capsule.id);
      if (!mounted) return;
      setState(() => _readyCapsule = null);
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

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels <= _loadOlderThreshold &&
        _hasOlderMessages &&
        !_loadingOlder) {
      unawaited(_loadOlderMessages());
    }
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
        final rawComponentCard =
            payload['component_card'] ?? payload['componentCard'];
        final componentCard = rawComponentCard is Map
            ? ChatComponentCard.fromJson(rawComponentCard)
            : null;
        setState(() {
          _messages.add(
            ChatMessage.draft(
              conversationId: _conversationId,
              role: 'assistant',
              content: text,
              metadata: componentCard == null
                  ? null
                  : {'component_card': componentCard.toJson()},
            ),
          );
          _sending = false;
        });
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollToBottom(animated: true),
        );
        break;
      case 'music_status':
        final text = payload['text']?.toString() ?? '';
        if (text.isEmpty) return;
        final messageId = payload['message_id']?.toString();
        setState(() {
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
                'music_status': payload['status']?.toString() ?? 'started',
                'music_track_title': payload['track_title']?.toString() ?? '',
                'music_track_id': payload['track_id']?.toString() ?? '',
                'music_co_listening': true,
              },
              read: true,
            ),
          );
          _sending = false;
        });
        unawaited(_refreshConversationMeta());
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollToBottom(animated: true),
        );
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
    final message = ChatMessage.achievement(
      conversationId: _conversationId,
      item: item,
    );
    setState(() {
      _messages.add(message);
      _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToBottom(animated: true),
    );
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

  void sendComponentMessage(String text, ChatComponentCard componentCard) {
    _sendText(text.trim(), componentCard: componentCard);
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    _sendText(text);
  }

  void _sendText(String text, {ChatComponentCard? componentCard}) {
    if (text.isEmpty && componentCard == null) return;
    final clientId =
        'draft-${DateTime.now().microsecondsSinceEpoch}-${(text.isEmpty ? componentCard!.title : text).hashCode}';
    final draft = ChatMessage.draft(
      conversationId: _conversationId,
      role: 'user',
      content: text,
      clientId: clientId,
      metadata: componentCard == null
          ? null
          : {'component_card': componentCard.toJson()},
    );
    setState(() {
      _messages.add(draft);
      if (componentCard == null) _inputController.clear();
      _panel = ComposerPanel.none;
      _sending = true;
    });

    final sent =
        _socket?.sendMessage(text, clientId, componentCard: componentCard) ??
        false;
    if (!sent) {
      _pendingSend = (
        text: text,
        clientId: clientId,
        componentCard: componentCard,
      );
      unawaited(_socket?.connect());
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToBottom(animated: true),
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
      } else if (delta > 0) {
        target = (position.pixels + delta)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
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
    final keyboardLift = isKeyboardOpen ? bottomInset : 0.0;
    final panelHeight = visiblePanelHeight;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final tabBarLift = _tabBarContentHeight + safeBottom;
    final composerBottom = isKeyboardOpen
        ? math.max(keyboardLift, tabBarLift + panelHeight)
        : tabBarLift + panelHeight;
    final inputSurfaceHeight = _composerHeight + composerBottom;
    final listBottomPadding = inputSurfaceHeight + 18;
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

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          Column(
            children: [
              _ChatHeader(
                agentName: widget.session.agentName ?? 'Companion',
                interactionDays: _conversationMeta?.interactionDays,
                avatarUrl: widget.session.agentAvatarUrl,
                isMusicListening:
                    _conversationMeta?.musicCoListening?.isActive ?? false,
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
                          onComponentCardTap: _openComponentCard,
                          onAchievementTap: _openAchievementDetail,
                          onResolveMusicTrack: _resolveMusicTrack,
                          agentAvatarUrl: widget.session.agentAvatarUrl,
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
              activePanel: _panel,
              sending: _sending,
              onFocusInput: _focusInput,
              onToggleEmoji: () => _setPanel(ComposerPanel.emoji),
              onShowKeyboard: _focusInput,
              onToggleMore: () => _setPanel(ComposerPanel.more),
              onSend: _sendMessage,
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
              child: _ChatPanel(panel: visiblePanel, onEmojiTap: _appendEmoji),
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
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3CFF).withValues(alpha: 0.16),
                    blurRadius: 22,
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
                      color: const Color(0xFF7C3CFF),
                      borderRadius: BorderRadius.circular(12),
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
                        const Text(
                          '有一个新胶囊待开启',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        Text(
                          '$dateText 开启，点一下看看',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    CupertinoIcons.chevron_down,
                    color: Color(0xFF7C3CFF),
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
