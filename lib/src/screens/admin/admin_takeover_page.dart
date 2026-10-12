part of 'package:companion_flutter/main.dart';

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

class _AdminTakeoverListPageState extends State<AdminTakeoverListPage> {
  var _scope = 'pending';
  var _loading = true;
  String? _error;
  List<TakeoverListItem> _items = const [];

  @override
  void initState() {
    super.initState();
    widget.api.authToken = widget.session.token;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.api.listTakeovers(_scope);
      if (!mounted) return;
      setState(() {
        _items = items;
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
            agentName: item.agentName?.trim().isNotEmpty == true
                ? item.agentName!
                : 'Companion',
          ),
        ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark(context);
    return Scaffold(
      backgroundColor: AppColors.of(context).page,
      appBar: AppBar(
        title: const Text('用户聊天接管'),
        backgroundColor: AppColors.of(context).page,
        foregroundColor: dark ? AppColors.text : const Color(0xFF12171B),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: CupertinoSlidingSegmentedControl<String>(
              groupValue: _scope,
              children: const {
                'pending': Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('待处理'),
                ),
                'mine': Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('我接管的'),
                ),
              },
              onValueChanged: (value) {
                if (value == null || value == _scope) return;
                setState(() => _scope = value);
                _load();
              },
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(_scope == 'pending' ? '没有待处理的新用户' : '还没有接管中的用户'),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: _items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = _items[index];
          final unread = item.unreadCount > 0;
          return ListTile(
            onTap: () => _openItem(item),
            title: Text(item.title),
            subtitle: Text(
              _scope == 'pending'
                  ? (item.agentName?.trim().isNotEmpty == true
                      ? 'Agent：${item.agentName}'
                      : 'Agent 尚未创建')
                  : (item.lastMessagePreview?.trim().isNotEmpty == true
                      ? item.lastMessagePreview!
                      : '暂无新消息'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: _scope == 'mine'
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        unread ? '未读 ${item.unreadCount}' : '已读',
                        style: TextStyle(
                          color: unread
                              ? const Color(0xFFE24B4B)
                              : const Color(0xFF7B8794),
                          fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  )
                : const Icon(CupertinoIcons.chevron_right, size: 16),
          );
        },
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
              agentName: review.agentName,
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
                          _line('生活概述', review.agent?['life_overview']?.toString()),
                          _line('MBTI', _brief(review.agent?['mbti'])),
                          _line('价值观', _brief(review.agent?['values'])),
                        ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Color(0xFFE24B4B))),
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
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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
