part of 'package:companion_flutter/main.dart';

/// 从任意页面（聊天卡片 / 深链）**直达**该活动对应详情，不经活动列表主页：
/// accepted→打卡页, completed→回顾页, 其余(pending/ignored)→地点详情 sheet。
/// 返回即回到调用页（如聊天）。
/// 返回值：仅当从回顾页点「查看原始聊天」时，返回其「我到了」到达卡消息 id（供调用方
/// ——聊天页——回跳并滚动定位）；其余情况返回 null。
Future<String?> openOfflineActivityDetail(
  BuildContext context, {
  required CompanionApi api,
  required AuthSession session,
  required OfflineActivity activity,
  String? takeoverId,
  VoidCallback? onChanged,
  VoidCallback? onNavigateToChat,
}) async {
  try {
    activity = takeoverId == null
        ? await api.fetchOfflineActivity(activity.id)
        : await api.fetchTakeoverActivity(takeoverId, activity.id);
  } on ApiException catch (error) {
    if (context.mounted) _showActivityToast(context, error.message);
    return null;
  } catch (_) {
    if (context.mounted) _showActivityToast(context, '暂时无法加载活动，请稍后重试');
    return null;
  }
  if (!context.mounted) return null;
  if (activity.status == 'cancelled' || activity.status == 'expired') {
    _showActivityToast(context, '这项活动已移除或过期');
    return null;
  }
  if (activity.status == 'accepted') {
    await Navigator.of(context).push(
      CompanionPageRoute<void>(
        builder: (_) => OfflineCheckinPage(
          api: api,
          session: session,
          activityId: activity.id,
          initialActivity: activity,
          takeoverId: takeoverId,
          onChanged: onChanged,
          onNavigateToChat: onNavigateToChat,
        ),
      ),
    );
    return null;
  }
  if (activity.status == 'completed') {
    return await Navigator.of(context).push<String>(
      CompanionPageRoute<String>(
        builder: (_) => OfflineReviewPage(
          api: api,
          session: session,
          activityId: activity.id,
          takeoverId: takeoverId,
        ),
      ),
    );
  }
  // pending / ignored → 地点详情 sheet（想去看看 / 先放一放）。
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    enableDrag: false,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.34),
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 1.0,
      minChildSize: 1.0,
      maxChildSize: 1.0,
      snap: false,
      expand: false,
      builder: (_, scrollController) => _ActivityDetailSheetShell(
        api: api,
        activity: activity,
        readOnly: takeoverId != null,
        scrollController: scrollController,
        onAccept: () async {
          if (takeoverId != null) return null;
          try {
            return await api.acceptOfflineActivity(activity.id);
          } on ApiException catch (error) {
            if (context.mounted) _showActivityToast(context, error.message);
            return null;
          } catch (_) {
            return null;
          }
        },
        onIgnore: () async {
          if (takeoverId != null) return false;
          try {
            await api.ignoreOfflineActivity(activity.id);
            return true;
          } catch (_) {
            return false;
          }
        },
        // 接受后 sheet 已自行关闭；用外层 context 打开打卡页（sheet context 已失效）。
        onAccepted: (updated) {
          onChanged?.call();
          Navigator.of(context).push(
            CompanionPageRoute<void>(
              builder: (_) => OfflineCheckinPage(
                api: api,
                session: session,
                activityId: updated.id,
                initialActivity: updated,
                onChanged: onChanged,
                onNavigateToChat: onNavigateToChat,
              ),
            ),
          );
        },
      ),
    ),
  );
  return null; // pending/ignored 详情 sheet 无跳转结果
}

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
    this.readOnly = false,
  });

  final CompanionApi api;
  final bool readOnly;
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
      readOnly: readOnly,
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
    this.readOnly = false,
  });

  final CompanionApi api;
  final bool readOnly;
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
    if (widget.readOnly || _responding) return;
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
    if (widget.readOnly || _responding) return;
    setState(() => _responding = true);
    final success = await widget.onIgnore();
    if (!mounted) return;
    setState(() => _responding = false);
    if (success) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    final canRespond = !widget.readOnly && activity.status == 'pending';
    final canReaccept = !widget.readOnly && activity.status == 'ignored';
    final isCompleted = activity.status == 'completed';
    return _OfflineDetailSheetFrame(
      title: '活动详情',
      scrollController: widget.scrollController,
      children: [
        _ActivityImageGallery(
          imageUrls: activity.imageUrls,
          category: activity.category,
          authToken: widget.api.authToken,
        ),
        const SizedBox(height: 18),
        if (activity.kind == 'event' && activity.imageUrls.isNotEmpty) ...[
          Text('活动地点实景', style: _mutedStyle(context, 12)),
          const SizedBox(height: 8),
        ],
        Text(activity.title, style: _activityTitleStyle(context)),
        const SizedBox(height: 10),
        SelectableText(
          activity.summary,
          style: _activityBodyStyle(context, secondary: true),
        ),
        if ((activity.recommendationMessage ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          _ActivityRecommendationMessage(
            message: activity.recommendationMessage!,
          ),
        ],
        if (activity.description.trim().isNotEmpty &&
            activity.description != activity.summary) ...[
          const SizedBox(height: 16),
          _ActivityDescription(text: activity.description),
        ],
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
          _ActivityReacceptButton(working: _responding, onPressed: _accept),
        ] else if (isCompleted) ...[
          const SizedBox(height: 18),
          _ActivityCompletionFeedbackView(
            feedback: activity.completionFeedback,
            api: widget.api,
            authToken: widget.api.authToken,
          ),
        ],
      ],
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
