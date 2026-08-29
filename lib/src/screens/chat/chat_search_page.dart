part of 'package:companion_flutter/main.dart';

/// Which slice of the conversation a [ChatSearchPage] instance shows.
///
/// `all` is the entry screen (search box + quick filters + recent
/// searches + a small preview of each match kind). Tapping a quick filter
/// or a section's "查看全部" re-pushes the *same* page class with a single
/// non-`all` scope, which switches into a real paginated list/grid — one
/// widget, two roles, no separate gallery page to build/maintain.
enum ChatSearchScope { all, text, card, image }

String _scopeQueryValue(ChatSearchScope scope) {
  return switch (scope) {
    ChatSearchScope.all => 'all',
    ChatSearchScope.text => 'text',
    ChatSearchScope.card => 'card',
    ChatSearchScope.image => 'image',
  };
}

class ChatSearchPage extends StatefulWidget {
  const ChatSearchPage({
    super.key,
    required this.api,
    required this.session,
    required this.conversationId,
    this.agentAvatarUrl,
    this.userAvatarUrl,
    required this.onOpenComponentCard,
    required this.onPreviewAttachment,
    this.initialScope = ChatSearchScope.all,
    this.initialQuery,
  });

  final CompanionApi api;
  final AuthSession session;
  final String conversationId;
  final String? agentAvatarUrl;
  final String? userAvatarUrl;
  final Future<void> Function(ChatComponentCard card) onOpenComponentCard;
  final Future<void> Function(ChatAttachment attachment) onPreviewAttachment;
  final ChatSearchScope initialScope;
  final String? initialQuery;

  static Future<void> push(
    BuildContext context, {
    required CompanionApi api,
    required AuthSession session,
    required String conversationId,
    String? agentAvatarUrl,
    String? userAvatarUrl,
    required Future<void> Function(ChatComponentCard card) onOpenComponentCard,
    required Future<void> Function(ChatAttachment attachment)
    onPreviewAttachment,
    ChatSearchScope initialScope = ChatSearchScope.all,
    String? initialQuery,
  }) {
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, __, ___) => ChatSearchPage(
          api: api,
          session: session,
          conversationId: conversationId,
          agentAvatarUrl: agentAvatarUrl,
          userAvatarUrl: userAvatarUrl,
          onOpenComponentCard: onOpenComponentCard,
          onPreviewAttachment: onPreviewAttachment,
          initialScope: initialScope,
          initialQuery: initialQuery,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  State<ChatSearchPage> createState() => _ChatSearchPageState();
}

class _ChatSearchPageState extends State<ChatSearchPage> {
  static const _pageSize = 30;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _historyStore = ChatSearchHistoryStore();
  final _scrollController = ScrollController();

  late ChatSearchScope _scope;
  String _query = '';
  Timer? _debounce;
  List<String> _history = const [];

  bool _loading = false;
  String? _error;

  // Bumped on every _runSearch() call; a response is only applied if this
  // still matches by the time it arrives. Without it, two searches in
  // flight at once (type "A", pause, then quickly type "B" before "A"'s
  // response lands) could let "A"'s slower response overwrite "B"'s results
  // if it happens to arrive later — an ordinary out-of-order network race,
  // not something the 300ms debounce alone prevents once both requests are
  // actually in flight.
  int _searchGeneration = 0;

  // scope == all
  MessageSearchResult? _preview;

  // scope != all
  final List<MessageSearchHit> _pagedItems = [];
  bool _hasMorePaged = false;
  bool _loadingMore = false;
  int _pagedOffset = 0;

  String get _agentName => widget.session.agentName ?? 'Companion';

  @override
  void initState() {
    super.initState();
    _scope = widget.initialScope;
    _controller.text = widget.initialQuery ?? '';
    _query = _controller.text.trim();
    _loadHistory();
    _scrollController.addListener(_maybeLoadMore);
    if (_scope != ChatSearchScope.all || _query.isNotEmpty) {
      _runSearch();
    }
    if (_scope == ChatSearchScope.all && _query.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final history = await _historyStore.load(widget.conversationId);
    if (mounted) setState(() => _history = history);
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed == _query) return;
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _query = trimmed);
      _runSearch();
    });
  }

  Future<void> _onSubmitted(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    _debounce?.cancel();
    setState(() => _query = trimmed);
    await _runSearch();
    final history = await _historyStore.add(widget.conversationId, trimmed);
    if (mounted) setState(() => _history = history);
  }

  void _selectHistoryTerm(String term) {
    _controller.text = term;
    _controller.selection = TextSelection.collapsed(offset: term.length);
    unawaited(_onSubmitted(term));
  }

  Future<void> _clearHistory() async {
    await _historyStore.clear(widget.conversationId);
    if (mounted) setState(() => _history = const []);
  }

  Future<void> _runSearch() async {
    if (_scope == ChatSearchScope.all && _query.isEmpty) {
      // Landing state — quick filters + recent searches, no request needed.
      // (Reachable when the user clears the box back to empty; without this
      // early-out every keystroke down to "" fired a full unfiltered
      // scope=all fetch — including the card scan's up-to-5000-row raw SQL
      // scan — purely to have `_buildBody` throw the result away in favor
      // of the landing view a line later.)
      _searchGeneration++;
      setState(() {
        _preview = null;
        _error = null;
      });
      return;
    }
    final generation = ++_searchGeneration;
    setState(() {
      _loading = true;
      _error = null;
      _preview = null;
      _pagedItems.clear();
      _pagedOffset = 0;
      _hasMorePaged = false;
    });
    try {
      if (_scope == ChatSearchScope.all) {
        final result = await widget.api.searchMessages(
          widget.conversationId,
          query: _query,
          scope: 'all',
        );
        if (!mounted || generation != _searchGeneration) return;
        setState(() {
          _preview = result;
          _loading = false;
        });
        return;
      }
      final result = await widget.api.searchMessages(
        widget.conversationId,
        query: _query,
        scope: _scopeQueryValue(_scope),
        limit: _pageSize,
        offset: 0,
      );
      if (!mounted || generation != _searchGeneration) return;
      final items = _hitsFor(result, _scope);
      setState(() {
        _pagedItems.addAll(items);
        _pagedOffset = items.length;
        _hasMorePaged = _hasMoreFor(result, _scope);
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _error = _asMessage(error);
        _loading = false;
      });
    }
  }

  void _maybeLoadMore() {
    if (_scope == ChatSearchScope.all) return;
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 240) return;
    _loadMorePaged();
  }

  Future<void> _loadMorePaged() async {
    if (_loadingMore || !_hasMorePaged || _loading) return;
    final generation = _searchGeneration;
    setState(() => _loadingMore = true);
    try {
      final result = await widget.api.searchMessages(
        widget.conversationId,
        query: _query,
        scope: _scopeQueryValue(_scope),
        limit: _pageSize,
        offset: _pagedOffset,
      );
      if (!mounted || generation != _searchGeneration) return;
      final items = _hitsFor(result, _scope);
      setState(() {
        _pagedItems.addAll(items);
        _pagedOffset += items.length;
        _hasMorePaged = _hasMoreFor(result, _scope);
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted && generation == _searchGeneration) {
        setState(() => _loadingMore = false);
      }
    }
  }

  List<MessageSearchHit> _hitsFor(MessageSearchResult result, ChatSearchScope scope) {
    return switch (scope) {
      ChatSearchScope.text => result.text,
      ChatSearchScope.card => result.cards,
      ChatSearchScope.image => result.images,
      ChatSearchScope.all => const [],
    };
  }

  bool _hasMoreFor(MessageSearchResult result, ChatSearchScope scope) {
    return switch (scope) {
      ChatSearchScope.text => result.hasMoreText,
      ChatSearchScope.card => result.hasMoreCards,
      ChatSearchScope.image => result.hasMoreImages,
      ChatSearchScope.all => false,
    };
  }

  void _openScope(ChatSearchScope scope) {
    unawaited(
      ChatSearchPage.push(
        context,
        api: widget.api,
        session: widget.session,
        conversationId: widget.conversationId,
        agentAvatarUrl: widget.agentAvatarUrl,
        userAvatarUrl: widget.userAvatarUrl,
        onOpenComponentCard: widget.onOpenComponentCard,
        onPreviewAttachment: widget.onPreviewAttachment,
        initialScope: scope,
        initialQuery: _query.isEmpty ? null : _query,
      ),
    );
  }

  void _openContext(MessageSearchHit hit) {
    unawaited(
      ChatMessageContextPage.push(
        context,
        api: widget.api,
        session: widget.session,
        conversationId: widget.conversationId,
        targetMessageId: hit.message.id,
        targetRank: hit.rank,
        agentAvatarUrl: widget.agentAvatarUrl,
        userAvatarUrl: widget.userAvatarUrl,
        onOpenComponentCard: widget.onOpenComponentCard,
        onPreviewAttachment: widget.onPreviewAttachment,
      ),
    );
  }

  void _openCard(MessageSearchHit hit) {
    final card = hit.message.componentCard;
    if (card == null) return;
    unawaited(widget.onOpenComponentCard(card));
  }

  void _openImagePreview(MessageSearchHit hit) {
    final attachment = matchedImageAttachment(hit);
    if (attachment == null || attachment.url.isEmpty) return;
    unawaited(widget.onPreviewAttachment(attachment));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = _W2b.resolve(context);
    return Scaffold(
      backgroundColor: scheme.base,
      body: Stack(
        children: [
          Positioned.fill(child: _SearchBackdrop(scheme: scheme)),
          SafeArea(
            child: Column(
              children: [
                _SearchBar(
                  scheme: scheme,
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: _scope == ChatSearchScope.all,
                  onChanged: _onQueryChanged,
                  onSubmitted: _onSubmitted,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                if (_scope != ChatSearchScope.all)
                  _ScopeHeader(scope: _scope),
                Expanded(child: _buildBody(scheme)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(_W2b scheme) {
    if (_loading && _pagedItems.isEmpty && _preview == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.inkSoft),
          ),
        ),
      );
    }
    if (_scope == ChatSearchScope.all && _query.isEmpty) {
      return _SearchLanding(
        scheme: scheme,
        history: _history,
        onQuickFilter: _openScope,
        onHistoryTap: _selectHistoryTerm,
        onClearHistory: _clearHistory,
      );
    }
    if (_scope == ChatSearchScope.all) {
      final preview = _preview;
      if (preview == null) return const SizedBox.shrink();
      if (preview.text.isEmpty && preview.cards.isEmpty && preview.images.isEmpty) {
        return _EmptyResults(scheme: scheme);
      }
      return _AllResultsList(
        scheme: scheme,
        preview: preview,
        agentName: _agentName,
        authToken: widget.api.authToken,
        apiBaseUrl: widget.api.baseUrl,
        onTextTap: _openContext,
        onCardTap: _openCard,
        onImageTap: _openImagePreview,
        onSeeAll: _openScope,
      );
    }
    if (_pagedItems.isEmpty) {
      return _EmptyResults(scheme: scheme);
    }
    if (_scope == ChatSearchScope.image) {
      return _ImageGrid(
        items: _pagedItems,
        authToken: widget.api.authToken,
        loadingMore: _loadingMore,
        controller: _scrollController,
        onTap: _openImagePreview,
      );
    }
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
      itemCount: _pagedItems.length + (_loadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        if (index == _pagedItems.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final hit = _pagedItems[index];
        return _scope == ChatSearchScope.card
            ? SearchCardResultRow(
                hit: hit,
                agentName: _agentName,
                onTap: () => _openCard(hit),
                authToken: widget.api.authToken,
                apiBaseUrl: widget.api.baseUrl,
              )
            : SearchTextResultRow(
                hit: hit,
                agentName: _agentName,
                onTap: () => _openContext(hit),
              );
      },
    );
  }
}

class _SearchBackdrop extends StatelessWidget {
  const _SearchBackdrop({required this.scheme});

  final _W2b scheme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.9),
          radius: 1.3,
          colors: [
            scheme.isDark
                ? const Color(0xFF14243A)
                : const Color(0xFFF3F8FF),
            scheme.base,
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.scheme,
    required this.controller,
    required this.focusNode,
    required this.autofocus,
    required this.onChanged,
    required this.onSubmitted,
    required this.onBack,
  });

  final _W2b scheme;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool autofocus;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 14, 10),
      child: Row(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.all(6),
            minimumSize: Size.zero,
            onPressed: onBack,
            child: Icon(CupertinoIcons.back, color: scheme.ink),
          ),
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: scheme.glass,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scheme.glassBorder),
                boxShadow: [scheme.pillShadow],
              ),
              child: Row(
                children: [
                  Icon(CupertinoIcons.search, size: 18, color: scheme.inkSoft),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      autofocus: autofocus,
                      onChanged: onChanged,
                      onSubmitted: onSubmitted,
                      textInputAction: TextInputAction.search,
                      style: TextStyle(color: scheme.ink, fontSize: 15),
                      cursorColor: scheme.ink,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: '搜索聊天记录',
                        hintStyle: TextStyle(color: scheme.inkFaint, fontSize: 15),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) {
                      if (value.text.isEmpty) return const SizedBox.shrink();
                      return GestureDetector(
                        onTap: () {
                          controller.clear();
                          onChanged('');
                        },
                        child: Icon(
                          CupertinoIcons.clear_circled_solid,
                          size: 18,
                          color: scheme.inkFaint,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeHeader extends StatelessWidget {
  const _ScopeHeader({required this.scope});

  final ChatSearchScope scope;

  @override
  Widget build(BuildContext context) {
    final label = switch (scope) {
      ChatSearchScope.card => '卡片',
      ChatSearchScope.image => '图片',
      ChatSearchScope.text => '聊天记录',
      ChatSearchScope.all => '',
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SearchLanding extends StatelessWidget {
  const _SearchLanding({
    required this.scheme,
    required this.history,
    required this.onQuickFilter,
    required this.onHistoryTap,
    required this.onClearHistory,
  });

  final _W2b scheme;
  final List<String> history;
  final ValueChanged<ChatSearchScope> onQuickFilter;
  final ValueChanged<String> onHistoryTap;
  final VoidCallback onClearHistory;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: _QuickFilterCard(
                scheme: scheme,
                icon: CupertinoIcons.square_grid_2x2_fill,
                label: '卡片',
                onTap: () => onQuickFilter(ChatSearchScope.card),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickFilterCard(
                scheme: scheme,
                icon: CupertinoIcons.photo_on_rectangle,
                label: '图片',
                onTap: () => onQuickFilter(ChatSearchScope.image),
              ),
            ),
          ],
        ),
        if (history.isNotEmpty) ...[
          const SizedBox(height: 26),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '最近搜索',
                style: TextStyle(
                  color: scheme.inkSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              GestureDetector(
                onTap: onClearHistory,
                child: Icon(
                  CupertinoIcons.delete,
                  size: 18,
                  color: scheme.inkFaint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final term in history)
                GestureDetector(
                  onTap: () => onHistoryTap(term),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.glass,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: scheme.glassBorder),
                    ),
                    child: Text(
                      term,
                      style: TextStyle(color: scheme.ink, fontSize: 13),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _QuickFilterCard extends StatelessWidget {
  const _QuickFilterCard({
    required this.scheme,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final _W2b scheme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: scheme.glass,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.glassBorder),
          boxShadow: scheme.panelShadow,
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.accent, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: scheme.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.scheme});

  final _W2b scheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('没有找到相关内容', style: TextStyle(color: scheme.inkSoft)),
    );
  }
}

class _AllResultsList extends StatelessWidget {
  const _AllResultsList({
    required this.scheme,
    required this.preview,
    required this.agentName,
    required this.authToken,
    required this.apiBaseUrl,
    required this.onTextTap,
    required this.onCardTap,
    required this.onImageTap,
    required this.onSeeAll,
  });

  final _W2b scheme;
  final MessageSearchResult preview;
  final String agentName;
  final String? authToken;
  final String? apiBaseUrl;
  final ValueChanged<MessageSearchHit> onTextTap;
  final ValueChanged<MessageSearchHit> onCardTap;
  final ValueChanged<MessageSearchHit> onImageTap;
  final ValueChanged<ChatSearchScope> onSeeAll;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
      children: [
        if (preview.images.isNotEmpty)
          _SearchSectionHeader(
            scheme: scheme,
            title: '图片',
            hasMore: preview.hasMoreImages,
            onSeeAll: () => onSeeAll(ChatSearchScope.image),
          ),
        if (preview.images.isNotEmpty)
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: preview.images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final hit = preview.images[index];
                final attachment = matchedImageAttachment(hit);
                if (attachment == null) return const SizedBox.shrink();
                return SearchImageThumb(
                  attachment: attachment,
                  authToken: authToken,
                  onTap: () => onImageTap(hit),
                );
              },
            ),
          ),
        if (preview.cards.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SearchSectionHeader(
            scheme: scheme,
            title: '卡片',
            hasMore: preview.hasMoreCards,
            onSeeAll: () => onSeeAll(ChatSearchScope.card),
          ),
          const SizedBox(height: 10),
          for (final hit in preview.cards) ...[
            SearchCardResultRow(
              hit: hit,
              agentName: agentName,
              onTap: () => onCardTap(hit),
              authToken: authToken,
              apiBaseUrl: apiBaseUrl,
            ),
            const SizedBox(height: 14),
          ],
        ],
        if (preview.text.isNotEmpty) ...[
          const SizedBox(height: 6),
          _SearchSectionHeader(
            scheme: scheme,
            title: '聊天记录',
            hasMore: preview.hasMoreText,
            onSeeAll: () => onSeeAll(ChatSearchScope.text),
          ),
          const SizedBox(height: 10),
          for (final hit in preview.text) ...[
            SearchTextResultRow(
              hit: hit,
              agentName: agentName,
              onTap: () => onTextTap(hit),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ],
    );
  }
}

class _SearchSectionHeader extends StatelessWidget {
  const _SearchSectionHeader({
    required this.scheme,
    required this.title,
    required this.hasMore,
    required this.onSeeAll,
  });

  final _W2b scheme;
  final String title;
  final bool hasMore;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: scheme.inkSoft,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (hasMore)
            GestureDetector(
              onTap: onSeeAll,
              child: Row(
                children: [
                  Text(
                    '查看全部',
                    style: TextStyle(color: AppColors.accent, fontSize: 12),
                  ),
                  Icon(
                    CupertinoIcons.chevron_forward,
                    size: 12,
                    color: AppColors.accent,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ImageGrid extends StatelessWidget {
  const _ImageGrid({
    required this.items,
    required this.authToken,
    required this.loadingMore,
    required this.controller,
    required this.onTap,
  });

  final List<MessageSearchHit> items;
  final String? authToken;
  final bool loadingMore;
  final ScrollController controller;
  final ValueChanged<MessageSearchHit> onTap;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: controller,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final hit = items[index];
                final attachment = matchedImageAttachment(hit);
                if (attachment == null) return const SizedBox.shrink();
                return SearchImageThumb(
                  attachment: attachment,
                  authToken: authToken,
                  size: null,
                  onTap: () => onTap(hit),
                );
              },
              childCount: items.length,
            ),
          ),
        ),
        if (loadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
      ],
    );
  }
}
