part of 'package:companion_flutter/main.dart';

/// 地点详情：spec §5.4-5「相册 → 名称+推荐理由 → 地址 → 双操作(想去看看/先放一放)」。
///
/// 重构（P1）：移除完成 composer（媒体改由聊天路径在到达后进入活动，见 P3）；
/// 详情只承担「三态入口」：
/// - pending  → 想去看看 / 先放一放
/// - ignored  → 重新接受邀请
/// - accepted → 进行中提示（打卡页由 P2 接入，届时改为跳打卡页）
/// - completed→ 只读回顾反馈（回顾页由 P5 接入）
class _ActivityDetailSheetShell extends StatelessWidget {
  const _ActivityDetailSheetShell({
    required this.api,
    required this.activity,
    required this.scrollController,
    required this.onAccept,
    required this.onIgnore,
    required this.onAccepted,
  });

  final CompanionApi api;
  final OfflineActivity activity;
  final ScrollController scrollController;
  final Future<OfflineActivity?> Function() onAccept;
  final Future<bool> Function() onIgnore;

  /// 接受成功（含同地点复用返回的既有活动）后回调，由外层打开打卡页。
  final void Function(OfflineActivity activity) onAccepted;

  @override
  Widget build(BuildContext context) {
    return _ActivityDetailSheet(
      api: api,
      activity: activity,
      scrollController: scrollController,
      onAccept: onAccept,
      onIgnore: onIgnore,
      onAccepted: onAccepted,
    );
  }
}

class _ActivityDetailSheet extends StatefulWidget {
  const _ActivityDetailSheet({
    required this.api,
    required this.activity,
    required this.scrollController,
    required this.onAccept,
    required this.onIgnore,
    required this.onAccepted,
  });

  final CompanionApi api;
  final OfflineActivity activity;
  final ScrollController scrollController;
  final Future<OfflineActivity?> Function() onAccept;
  final Future<bool> Function() onIgnore;
  final void Function(OfflineActivity activity) onAccepted;

  @override
  State<_ActivityDetailSheet> createState() => _ActivityDetailSheetState();
}

class _ActivityDetailSheetState extends State<_ActivityDetailSheet> {
  bool _responding = false;

  Future<void> _accept() async {
    if (_responding) return;
    setState(() => _responding = true);
    final updated = await widget.onAccept();
    if (!mounted) return;
    setState(() => _responding = false);
    if (updated != null) {
      // 先关详情，再由外层打开打卡页（spec §2.1「想去看看」后进打卡页）。
      Navigator.of(context).pop();
      widget.onAccepted(updated);
    }
  }

  Future<void> _ignore() async {
    if (_responding) return;
    setState(() => _responding = true);
    final success = await widget.onIgnore();
    if (!mounted) return;
    setState(() => _responding = false);
    if (success) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    final canRespond = activity.status == 'pending';
    final canReaccept = activity.status == 'ignored';
    final isCompleted = activity.status == 'completed';
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 18;
    // sheet 底用极光玻璃底色（跟地址 sheet 一致），衬出内部分层玻璃。
    final w = _W2b.resolve(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: w.base,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: Column(
        children: [
          _ExpandedSheetTopBar(
            title: '活动详情',
            onClose: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: EdgeInsets.fromLTRB(22, 4, 22, bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ActivityImage(
                    activity: activity,
                    height: 178,
                    authToken: widget.api.authToken,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  const SizedBox(height: 18),
                  Text(activity.title, style: _titleStyle(context, 24)),
                  const SizedBox(height: 10),
                  Text(activity.description, style: _mutedStyle(context, 16)),
                  const SizedBox(height: 16),
                  _MetaLine(activity: activity),
                  if (canRespond) ...[
                    const SizedBox(height: 22),
                    _ActivityResponseButtons(
                      working: _responding,
                      onAccept: _accept,
                      onIgnore: _ignore,
                    ),
                  ] else if (canReaccept) ...[
                    const SizedBox(height: 22),
                    _ActivityReacceptButton(
                      working: _responding,
                      onPressed: _accept,
                    ),
                  ] else if (isCompleted) ...[
                    const SizedBox(height: 18),
                    _ActivityCompletionFeedbackView(
                      feedback: activity.completionFeedback,
                      api: widget.api,
                      authToken: widget.api.authToken,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityReacceptButton extends StatelessWidget {
  const _ActivityReacceptButton({
    required this.working,
    required this.onPressed,
  });

  final bool working;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: _PrimaryActivityPillButton(
        label: working ? '处理中...' : '重新接受邀请',
        icon: '✨',
        enabled: !working,
        onPressed: onPressed,
      ),
    );
  }
}
