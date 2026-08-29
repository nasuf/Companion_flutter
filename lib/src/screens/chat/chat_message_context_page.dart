part of 'package:companion_flutter/main.dart';

/// Read-only "上下文" viewer opened from a text search result
/// ([ChatSearchPage]). Fetches a window of chat history around the hit
/// message using the existing [CompanionApi.loadMessages] (offset derived
/// from the hit's `rank`) and renders it with the same [_MessageRow] chat
/// itself uses — so cards/images inside the window behave exactly like they
/// do in live chat. Deliberately does not touch `_ChatPageState`'s live,
/// heavily-stateful message list: this is a separate, disposable window.
class ChatMessageContextPage extends StatefulWidget {
  const ChatMessageContextPage({
    super.key,
    required this.api,
    required this.session,
    required this.conversationId,
    required this.targetMessageId,
    required this.targetRank,
    required this.agentAvatarUrl,
    required this.userAvatarUrl,
    required this.onOpenComponentCard,
    required this.onPreviewAttachment,
  });

  final CompanionApi api;
  final AuthSession session;
  final String conversationId;
  final String targetMessageId;
  final int targetRank;
  final String? agentAvatarUrl;
  final String? userAvatarUrl;
  final Future<void> Function(ChatComponentCard card) onOpenComponentCard;
  final Future<void> Function(ChatAttachment attachment) onPreviewAttachment;

  static Future<void> push(
    BuildContext context, {
    required CompanionApi api,
    required AuthSession session,
    required String conversationId,
    required String targetMessageId,
    required int targetRank,
    String? agentAvatarUrl,
    String? userAvatarUrl,
    required Future<void> Function(ChatComponentCard card) onOpenComponentCard,
    required Future<void> Function(ChatAttachment attachment)
    onPreviewAttachment,
  }) {
    return Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => ChatMessageContextPage(
          api: api,
          session: session,
          conversationId: conversationId,
          targetMessageId: targetMessageId,
          targetRank: targetRank,
          agentAvatarUrl: agentAvatarUrl,
          userAvatarUrl: userAvatarUrl,
          onOpenComponentCard: onOpenComponentCard,
          onPreviewAttachment: onPreviewAttachment,
        ),
      ),
    );
  }

  @override
  State<ChatMessageContextPage> createState() =>
      _ChatMessageContextPageState();
}

class _ChatMessageContextPageState extends State<ChatMessageContextPage> {
  static const _windowRadius = 15;
  static const _extendStep = 15;

  final _scrollController = ScrollController();
  final _targetKey = GlobalKey();

  bool _loading = true;
  bool _loadingOlder = false;
  bool _loadingNewer = false;
  String? _error;
  List<ChatMessage> _messages = const [];
  int _oldestRank = 0;
  int _newestRank = 0;
  bool _hasMoreOlder = false;
  bool _hasMoreNewer = false;
  bool _highlight = false;

  // `targetRank` is a snapshot from when the search ran; if new messages
  // arrived in this conversation before the user tapped through (a
  // proactive message, a reply from another device, ...), the target's true
  // position may have shifted enough that it falls outside the fetched
  // window entirely. Rather than silently scrolling to the wrong spot with
  // no highlight and no explanation, surface it.
  bool _targetFound = true;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final start = math.max(0, widget.targetRank - _windowRadius);
    const take = _windowRadius * 2 + 1;
    try {
      final newestFirst = await widget.api.loadMessages(
        widget.conversationId,
        limit: take,
        offset: start,
      );
      if (!mounted) return;
      setState(() {
        _messages = newestFirst.reversed.toList();
        _newestRank = start;
        _oldestRank = start + newestFirst.length - 1;
        _hasMoreNewer = start > 0;
        _hasMoreOlder = newestFirst.length == take;
        _targetFound = _messages.any((m) => m.id == widget.targetMessageId);
        _loading = false;
      });
      _scheduleScrollToTarget();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _asMessage(error);
        _loading = false;
      });
    }
  }

  void _scheduleScrollToTarget() {
    if (!_targetFound) return; // nothing to scroll to or highlight
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetContext = _targetKey.currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          alignment: 0.5,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
      setState(() => _highlight = true);
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _highlight = false);
      });
    });
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMoreOlder) return;
    setState(() => _loadingOlder = true);
    try {
      final nextOffset = _oldestRank + 1;
      final newestFirst = await widget.api.loadMessages(
        widget.conversationId,
        limit: _extendStep,
        offset: nextOffset,
      );
      if (!mounted) return;
      setState(() {
        _messages = [...newestFirst.reversed, ..._messages];
        _oldestRank = nextOffset + newestFirst.length - 1;
        _hasMoreOlder = newestFirst.length == _extendStep;
        _loadingOlder = false;
        if (!_targetFound) {
          _targetFound = _messages.any((m) => m.id == widget.targetMessageId);
        }
      });
      _scheduleScrollToTarget();
    } catch (_) {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  Future<void> _loadNewer() async {
    if (_loadingNewer || !_hasMoreNewer) return;
    setState(() => _loadingNewer = true);
    try {
      final take = math.min(_extendStep, _newestRank);
      final nextOffset = _newestRank - take;
      final newestFirst = await widget.api.loadMessages(
        widget.conversationId,
        limit: take,
        offset: nextOffset,
      );
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, ...newestFirst.reversed];
        _newestRank = nextOffset;
        _hasMoreNewer = nextOffset > 0;
        _loadingNewer = false;
        if (!_targetFound) {
          _targetFound = _messages.any((m) => m.id == widget.targetMessageId);
        }
      });
      _scheduleScrollToTarget();
    } catch (_) {
      if (mounted) setState(() => _loadingNewer = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('聊天记录'),
        backgroundColor: AppColors.surface,
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Text(_error!, style: TextStyle(color: AppColors.muted)),
              )
            : ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                children: [
                  if (!_targetFound)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        '未能精确定位到这条消息，以下是附近的聊天记录',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ),
                  _LoadMoreRow(
                    visible: _hasMoreOlder,
                    loading: _loadingOlder,
                    label: '加载更早的消息',
                    onTap: _loadOlder,
                  ),
                  for (final message in _messages)
                    _ContextMessageRow(
                      key: message.id == widget.targetMessageId
                          ? _targetKey
                          : null,
                      message: message,
                      highlighted:
                          _highlight && message.id == widget.targetMessageId,
                      agentAvatarUrl: widget.agentAvatarUrl,
                      userAvatarUrl: widget.userAvatarUrl,
                      authToken: widget.api.authToken,
                      apiBaseUrl: widget.api.baseUrl,
                      onComponentCardTap: (card) =>
                          unawaited(widget.onOpenComponentCard(card)),
                      onAttachmentTap: (attachment) =>
                          unawaited(widget.onPreviewAttachment(attachment)),
                    ),
                  _LoadMoreRow(
                    visible: _hasMoreNewer,
                    loading: _loadingNewer,
                    label: '加载更晚的消息',
                    onTap: _loadNewer,
                  ),
                ],
              ),
      ),
    );
  }
}

class _ContextMessageRow extends StatelessWidget {
  const _ContextMessageRow({
    super.key,
    required this.message,
    required this.highlighted,
    required this.agentAvatarUrl,
    required this.userAvatarUrl,
    required this.authToken,
    required this.apiBaseUrl,
    required this.onComponentCardTap,
    required this.onAttachmentTap,
  });

  final ChatMessage message;
  final bool highlighted;
  final String? agentAvatarUrl;
  final String? userAvatarUrl;
  final String? authToken;
  final String? apiBaseUrl;
  final ValueChanged<ChatComponentCard> onComponentCardTap;
  final ValueChanged<ChatAttachment> onAttachmentTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.accent.withValues(alpha: 0.16)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: _MessageRow(
        message: message,
        onComponentCardTap: onComponentCardTap,
        onAchievementTap: (_) {},
        onResolveMusicTrack: (track) async => track,
        onMusicCardActivated: (_, __) {},
        onMusicPrevious: () {},
        onMusicNext: () {},
        onMusicFavorite: (_) {},
        onAttachmentTap: onAttachmentTap,
        activeMusicMessageId: null,
        musicCardPositions: const {},
        favoriteMusicTrackIds: const {},
        busyMusicFavoriteIds: const {},
        canGoMusicPrevious: false,
        isMusicBusy: false,
        agentAvatarUrl: agentAvatarUrl,
        userAvatarUrl: userAvatarUrl,
        authToken: authToken,
        apiBaseUrl: apiBaseUrl,
      ),
    );
  }
}

class _LoadMoreRow extends StatelessWidget {
  const _LoadMoreRow({
    required this.visible,
    required this.loading,
    required this.label,
    required this.onTap,
  });

  final bool visible;
  final bool loading;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                onPressed: onTap,
                child: Text(
                  label,
                  style: TextStyle(color: AppColors.accent, fontSize: 12),
                ),
              ),
      ),
    );
  }
}
