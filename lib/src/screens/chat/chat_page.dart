part of 'package:companion_flutter/main.dart';

enum ComposerPanel { none, emoji, more }

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  static const _animationDuration = Duration(milliseconds: 260);
  static const _animationCurve = Curves.easeOutCubic;
  static const _composerHeight = 68.0;
  static const _tabBarContentHeight = 64.0;
  static const _emojiPanelHeight = 238.0;
  static const _morePanelHeight = 258.0;
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
  bool _loadingInitial = true;
  bool _loadingOlder = false;
  bool _hasOlderMessages = false;
  bool _sending = false;
  bool _connecting = true;
  String _typingHint = '连接中...';
  String? _historyError;
  int _loadedServerMessages = 0;
  double? _lastListBottomPadding;
  double _lastKeyboardInset = 0;
  bool _pinToBottomDuringKeyboard = false;
  bool _wasNearBottomBeforePaddingChange = true;
  ({String text, String clientId})? _pendingSend;

  String get _conversationId => widget.session.conversationId!;

  @override
  void initState() {
    super.initState();
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
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _inputController.dispose();
    _inputFocus.dispose();
    _eventSub?.cancel();
    _stateSub?.cancel();
    _socket?.close();
    super.dispose();
  }

  double get _panelHeight {
    return switch (_panel) {
      ComposerPanel.emoji => _emojiPanelHeight,
      ComposerPanel.more => _morePanelHeight,
      ComposerPanel.none => 0,
    };
  }

  Future<void> _bootstrapChat() async {
    await _eventSub?.cancel();
    await _stateSub?.cancel();
    await _socket?.close();
    if (!mounted) return;
    setState(() {
      _messages.clear();
      _loadingInitial = true;
      _loadingOlder = false;
      _hasOlderMessages = false;
      _loadedServerMessages = 0;
      _historyError = null;
      _connecting = true;
      _typingHint = '连接中...';
      _pendingSend = null;
    });
    await _loadLatestMessages(showLoading: true);
    _connectSocket();
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
          setState(() {
            _connecting = true;
            _typingHint = '连接中...';
          });
        case ChatSocketStatus.open:
          setState(() {
            _connecting = false;
            _typingHint = '在线';
          });
          final pending = _pendingSend;
          if (pending != null) {
            socket.sendMessage(pending.text, pending.clientId);
            _pendingSend = null;
          }
          _loadLatestMessages(showLoading: false);
        case ChatSocketStatus.error:
          setState(() {
            _connecting = false;
            _typingHint = '连接异常';
          });
        case ChatSocketStatus.closed:
          setState(() {
            _connecting = false;
            _typingHint = state.code == 1000 ? '已断开' : '重连中';
          });
        case ChatSocketStatus.disconnected:
          setState(() {
            _connecting = false;
            _typingHint = '未连接';
          });
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
        _hasOlderMessages = newestFirst.length == _messagePageSize;
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
    });
    _messages
      ..clear()
      ..addAll(serverMessages)
      ..addAll(unsyncedUserDrafts);
    _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
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
        _hasOlderMessages = newestFirst.length == _messagePageSize;
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

  void _prependServerMessages(List<ChatMessage> older) {
    final existingIds = _messages.map((item) => item.id).toSet();
    final unique = older.where((item) => !existingIds.contains(item.id));
    _messages.insertAll(0, unique);
    _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  int _countServerMessages(List<ChatMessage> messages) {
    return messages.where((item) => !item.pending && !item.isDraft).length;
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
        final duration = (payload['duration'] as num?)?.round() ?? 0;
        setState(() => _typingHint = '预计 ${_formatEta(duration)} 后回复');
        break;
      case 'pending':
        final status = payload['status']?.toString() ?? 'pending';
        final delay = (payload['delay'] as num?)?.round() ?? 0;
        setState(() {
          _sending = false;
          if (status == 'aggregating') {
            _typingHint = '消息已进入聚合';
          } else if (status == 'queued') {
            _typingHint = delay > 0
                ? '已排队，预计 ${_formatEta(delay)} 后回复'
                : '消息已排队';
          } else {
            _typingHint = '消息处理中';
          }
        });
        break;
      case 'reply':
      case 'proactive':
        final text = payload['text']?.toString() ?? '';
        if (text.isEmpty) return;
        setState(() {
          _messages.add(
            ChatMessage.draft(
              conversationId: _conversationId,
              role: 'assistant',
              content: text,
            ),
          );
          _sending = false;
          _typingHint = '在线';
        });
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollToBottom(animated: true),
        );
        break;
      case 'done':
        setState(() {
          _sending = false;
          _typingHint = '在线';
        });
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
      default:
        break;
    }
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    final clientId =
        'draft-${DateTime.now().microsecondsSinceEpoch}-${text.hashCode}';
    final draft = ChatMessage.draft(
      conversationId: _conversationId,
      role: 'user',
      content: text,
      clientId: clientId,
    );
    setState(() {
      _messages.add(draft);
      _inputController.clear();
      _panel = ComposerPanel.none;
      _sending = true;
      _typingHint = _connecting ? '连接未就绪，正在重连...' : '已发送';
    });

    final sent = _socket?.sendMessage(text, clientId) ?? false;
    if (!sent) {
      _pendingSend = (text: text, clientId: clientId);
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
    if (panel != ComposerPanel.none) {
      FocusScope.of(context).unfocus();
    }
    setState(() {
      _panel = _panel == panel ? ComposerPanel.none : panel;
    });
  }

  void _focusInput() {
    _pinToBottomDuringKeyboard = _isNearBottomNow();
    setState(() => _panel = ComposerPanel.none);
    _inputFocus.requestFocus();
  }

  void _dismissInputSurfaces() {
    FocusScope.of(context).unfocus();
    if (_panel == ComposerPanel.none && !_pinToBottomDuringKeyboard) {
      return;
    }
    setState(() {
      _panel = ComposerPanel.none;
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
    final keyboardLift = isKeyboardOpen ? bottomInset : 0.0;
    final panelHeight = isKeyboardOpen ? 0.0 : _panelHeight;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final tabBarLift = _tabBarContentHeight + safeBottom;
    final composerBottom = isKeyboardOpen
        ? math.max(keyboardLift, tabBarLift)
        : tabBarLift + panelHeight;
    final listBottomPadding = _composerHeight + composerBottom + 18;
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
                subtitle: _connecting || _sending ? _typingHint : '在线',
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
                        ),
                ),
              ),
            ],
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
              child: _ChatPanel(panel: _panel, onEmojiTap: _appendEmoji),
            ),
          ),
        ],
      ),
    );
  }
}
