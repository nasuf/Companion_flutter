part of 'package:companion_flutter/main.dart';

class TakeoverUnreadBadge extends StatelessWidget {
  const TakeoverUnreadBadge({super.key, this.controller});
  final TakeoverUnreadController? controller;

  @override
  Widget build(BuildContext context) {
    final state = controller ?? TakeoverUnreadController.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final count = state.count;
        if (!state.configured || (count == 0 && !state.stale)) {
          return const SizedBox.shrink();
        }
        return Tooltip(
          message: state.stale
              ? '未读信息刷新失败，请进入列表重试'
              : count == null
              ? '未读信息正在加载'
              : '$count 条未读消息',
          child: Container(
            key: const ValueKey('takeover-unread-badge'),
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE24B4B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count == null
                  ? (state.stale ? '!' : '…')
                  : '$count${state.stale ? '!' : ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        );
      },
    );
  }
}

class AdminTakeoverListPage extends StatefulWidget {
  const AdminTakeoverListPage({
    super.key,
    required this.api,
    required this.session,
  });

  final CompanionApi api;
  final AuthSession session;

  @override
  State<AdminTakeoverListPage> createState() => _AdminTakeoverListPageState();
}

class _AdminTakeoverListPageState extends State<AdminTakeoverListPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final AnimationController _motionController;
  var _scope = 'mine';
  int _loadGeneration = 0;
  StreamSubscription<WsEnvelope>? _inboxEvents;
  var _loading = true;
  String? _error;
  List<TakeoverListItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    widget.api.authToken = widget.session.token;
    WidgetsBinding.instance.addObserver(this);
    _inboxEvents = TakeoverInbox.instance.events.listen((event) {
      if (!{
        'pong',
        'takeover_user_typing',
        'takeover_user_read',
        'inbox_disconnected',
      }.contains(event.type)) {
        unawaited(_load());
      }
    });
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inboxEvents?.cancel();
    _motionController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final scope = _scope;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.api.listTakeovers(scope);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openItem(TakeoverListItem item) async {
    if (_scope == 'pending') {
      await Navigator.of(context).push(
        CompanionPageRoute<void>(
          builder: (_) => AdminTakeoverReviewPage(
            api: widget.api,
            session: widget.session,
            takeoverId: item.id,
          ),
        ),
      );
      if (mounted) _load();
      return;
    }
    final conversationId = item.conversationId;
    if (conversationId == null || conversationId.isEmpty) return;
    await Navigator.of(context).push(
      CompanionPageRoute<void>(
        builder: (_) => ChatPage(
          api: widget.api,
          session: widget.session,
          isActive: true,
          onOpenSidebar: () {},
          takeover: TakeoverChatTarget(
            takeoverId: item.id,
            conversationId: conversationId,
            userName: item.title,
            agentName: item.agentName ?? '',
            userAvatarUrl: item.userAvatarUrl,
            agentAvatarUrl: item.agentAvatarUrl,
          ),
        ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _adminPageHost(
      body: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: _motionController,
          builder: (context, _) {
            return _buildAdminKeyboardAwareStack(
              context: context,
              motionProgress: _motionController.value,
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      18,
                      media.padding.top + 12,
                      18,
                      0,
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 48,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: _AppNavCircleButton(
                                  icon: CupertinoIcons.chevron_left,
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ),
                              Text(
                                '用户聊天接管',
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.text
                                      : const Color(0xFF12171B),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: _loading
                                    ? const CupertinoActivityIndicator(
                                        radius: 10,
                                      )
                                    : _AppNavCircleButton(
                                        icon: CupertinoIcons.refresh,
                                        onPressed: () => _load(),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _AdminFilterRow(
                          label: '范围',
                          options: const [
                            MapEntry('mine', '我接管的'),
                            MapEntry('pending', '待处理'),
                          ],
                          value: _scope,
                          onChanged: (value) {
                            if (value == null || value == _scope) return;
                            setState(() => _scope = value);
                            _load();
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 42),
                      children: [
                        _ProfileSectionV6(
                          title: '会话列表',
                          trailing: _loading && _items.isEmpty
                              ? '加载中'
                              : '共 ${_items.length} 人',
                          child: _buildListBody(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildListBody() {
    if (_loading && _items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: CupertinoActivityIndicator(radius: 12),
      );
    }
    if (_error != null && _items.isEmpty) {
      return _AdminStatePanel(
        title: '加载失败',
        message: _error!,
        actionText: '重试',
        onTap: _load,
      );
    }
    if (_items.isEmpty) {
      return _AdminStatePanel(
        title: _scope == 'pending' ? '没有待处理用户' : '还没有接管中的用户',
        message: _scope == 'pending'
            ? '新注册用户会出现在这里。'
            : '接管成功后，会话会列在这里。',
      );
    }
    return Column(
      children: [
        for (final item in _items)
          _TakeoverUserRow(
            item: item,
            pending: _scope == 'pending',
            onTap: () => _openItem(item),
          ),
      ],
    );
  }
}

class _TakeoverUserRow extends StatelessWidget {
  const _TakeoverUserRow({
    required this.item,
    required this.pending,
    required this.onTap,
  });

  final TakeoverListItem item;
  final bool pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unread = !pending && item.unreadCount > 0;
    final subtitle = pending
        ? (item.agentName?.trim().isNotEmpty == true
              ? 'Agent：${item.agentName}'
              : 'Agent 尚未创建')
        : (item.lastMessagePreview?.trim().isNotEmpty == true
              ? item.lastMessagePreview!
              : '暂无新消息');
    final initial = item.title.trim().isEmpty
        ? '?'
        : String.fromCharCode(item.title.trim().runes.first);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : const Color(0x14181F2A),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 44,
                  height: 44,
                  color: const Color(0xFF1FA97A).withValues(alpha: 0.14),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Color(0xFF1FA97A),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? AppColors.text : const Color(0xFF12171B),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark
                            ? const Color(0x9EEBF2EE)
                            : AppColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!pending)
                Text(
                  unread ? '未读 ${item.unreadCount}' : '已读',
                  style: TextStyle(
                    color: unread
                        ? const Color(0xFFE24B4B)
                        : (isDark
                              ? const Color(0x9EEBF2EE)
                              : const Color(0xFF7B8794)),
                    fontSize: 12,
                    fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
              const SizedBox(width: 6),
              Text(
                '›',
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.32)
                      : const Color(0x52182026),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1,
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

class AdminTakeoverReviewPage extends StatefulWidget {
  const AdminTakeoverReviewPage({
    super.key,
    required this.api,
    required this.session,
    required this.takeoverId,
  });

  final CompanionApi api;
  final AuthSession session;
  final String takeoverId;

  @override
  State<AdminTakeoverReviewPage> createState() =>
      _AdminTakeoverReviewPageState();
}

class _AdminTakeoverReviewPageState extends State<AdminTakeoverReviewPage> {
  TakeoverReview? _review;
  var _loading = true;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.api.authToken = widget.session.token;
    _load();
  }

  Future<void> _load() async {
    try {
      final review = await widget.api.getTakeover(widget.takeoverId);
      if (!mounted) return;
      setState(() {
        _review = review;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _continueWithAgent() async {
    setState(() => _busy = true);
    try {
      await widget.api.dismissTakeover(widget.takeoverId);
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _claim() async {
    setState(() => _busy = true);
    try {
      final review = await widget.api.claimTakeover(widget.takeoverId);
      if (!mounted) return;
      final conversationId = review.conversationId;
      if (conversationId == null || conversationId.isEmpty) {
        setState(() {
          _busy = false;
          _error = '这个用户还没有可用的会话';
        });
        return;
      }
      await Navigator.of(context).pushReplacement(
        CompanionPageRoute<void>(
          builder: (_) => ChatPage(
            api: widget.api,
            session: widget.session,
            isActive: true,
            onOpenSidebar: () {},
            takeover: TakeoverChatTarget(
              takeoverId: review.id,
              conversationId: conversationId,
              userName: review.userName,
              agentName: review.agentName,
              userAvatarUrl: review.userAvatarUrl,
              agentAvatarUrl: review.agentAvatarUrl,
            ),
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
        _review = _review;
      });
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = _review;
    return Scaffold(
      backgroundColor: AppColors.of(context).page,
      appBar: AppBar(
        title: const Text('新用户'),
        backgroundColor: AppColors.of(context).page,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : review == null
          ? Center(child: Text(_error ?? '没有找到这个用户'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _section('用户', [
                  _line('昵称', review.user['display_name']?.toString()),
                  _line('用户名', review.user['username']?.toString()),
                  _line('手机', review.user['phone_masked']?.toString()),
                  _line('注册来源', review.user['signup_source']?.toString()),
                  _line('注册时间', review.user['created_at']?.toString()),
                ]),
                const SizedBox(height: 16),
                _section(
                  'Agent',
                  review.agent == null
                      ? const [Text('Agent 尚未创建，暂时不能接管')]
                      : [
                          _line('名字', review.agent?['name']?.toString()),
                          _line('性别', review.agent?['gender']?.toString()),
                          _line('年龄', review.agent?['age']?.toString()),
                          _line('城市', review.agent?['city']?.toString()),
                          _line('职业', review.agent?['occupation']?.toString()),
                          _line('背景', review.agent?['background']?.toString()),
                          _line(
                            '生活概述',
                            review.agent?['life_overview']?.toString(),
                          ),
                          _line('MBTI', _brief(review.agent?['mbti'])),
                          _line('价值观', _brief(review.agent?['values'])),
                        ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFE24B4B)),
                  ),
                ],
                if (review.status == 'active') ...[
                  const SizedBox(height: 20),
                  Text(
                    review.ownerAdminId == widget.session.userId
                        ? '这个用户已经由你接管'
                        : '该用户已由${review.ownerName ?? '其他管理员'}接管',
                  ),
                ] else ...[
                  const SizedBox(height: 24),
                  CupertinoButton.filled(
                    onPressed: _busy || !review.canClaim ? null : _claim,
                    child: const Text('人工接管'),
                  ),
                  const SizedBox(height: 12),
                  CupertinoButton(
                    onPressed: _busy ? null : _continueWithAgent,
                    child: const Text('继续由 agent 回复'),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _line(String label, String? value) {
    final text = value?.trim();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text('$label：${text == null || text.isEmpty ? '—' : text}'),
    );
  }

  String? _brief(Object? value) {
    if (value == null) return null;
    final text = value.toString();
    if (text.length <= 180) return text;
    return '${text.substring(0, 179)}…';
  }
}
