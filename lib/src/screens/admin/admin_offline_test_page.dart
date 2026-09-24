part of 'package:companion_flutter/main.dart';

/// 管理员测试页：生成活动 → 查看活动细节 + 需要完成的任务(拍摄物品)。
/// 「生成任务物品」绕过到达校验(admin 专用)，方便不走真实到达流程就能看到任务。
class _OfflineActivityTestPage extends StatefulWidget {
  const _OfflineActivityTestPage({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_OfflineActivityTestPage> createState() =>
      _OfflineActivityTestPageState();
}

class _OfflineActivityTestPageState extends State<_OfflineActivityTestPage> {
  bool _generating = false;
  bool _generatingItems = false;
  bool _clearing = false;
  bool _accepting = false;
  bool _loadingExisting = false;
  String? _error;
  OfflineActivity? _activity;
  OfflineActivityInspect? _inspect;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  /// 打开测试页时载入最近一个活动（pending 推荐卡或已接受的），并拉一次任务检视。
  /// 这样离开后重开仍能看到刚生成的活动，而不是空白页。
  Future<void> _loadExisting() async {
    setState(() => _loadingExisting = true);
    try {
      widget.api.authToken = widget.session.token;
      final data = await widget.api.fetchOfflineActivities(
        workspaceId: widget.session.workspaceId,
      );
      final existing = data.latest ??
          (data.pending.isNotEmpty ? data.pending.first : null);
      if (!mounted) return;
      setState(() {
        _loadingExisting = false;
        _activity = existing;
      });
      if (existing != null) await _inspectOnly(existing.id);
    } catch (_) {
      if (mounted) setState(() => _loadingExisting = false);
    }
  }

  /// 接受活动（想去看看）：pending → accepted，进「待出行」，可继续到达/打卡流程。
  Future<void> _accept() async {
    final activity = _activity;
    if (activity == null || _accepting) return;
    setState(() {
      _accepting = true;
      _error = null;
    });
    try {
      widget.api.authToken = widget.session.token;
      final updated = await widget.api.acceptOfflineActivity(activity.id);
      if (!mounted) return;
      setState(() {
        _accepting = false;
        _activity = updated;
      });
      await _inspectOnly(updated.id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _accepting = false;
        _error = _asMessage(error);
      });
    }
  }

  Future<void> _clearAll() async {
    if (_clearing) return;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('清理所有活动？'),
        content: const Text('这会删除当前登录用户下的全部线下活动推荐记录和完成反馈，无法撤销。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认清理'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _clearing = true;
      _error = null;
    });
    try {
      widget.api.authToken = widget.session.token;
      final result = await widget.api.clearOfflineActivitiesForCurrentUser();
      if (!mounted) return;
      setState(() {
        _clearing = false;
        _activity = null;
        _inspect = null;
      });
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('活动已清理'),
          content: Text(
            '已删除 ${result.deletedActivities} 条活动记录和 ${result.deletedFeedback} 条反馈记录。',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('好'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _clearing = false;
        _error = _asMessage(error);
      });
    }
  }

  Future<void> _generate() async {
    if (_generating) return;
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      widget.api.authToken = widget.session.token;
      final activity = await widget.api.createOfflineActivityRecommendation(
        workspaceId: widget.session.workspaceId,
      );
      if (!mounted) return;
      setState(() {
        _generating = false;
        _activity = activity;
        _inspect = null;
        if (activity == null) {
          _error = '暂时没有生成活动：请确认已授权定位且有可用聊天会话。';
        }
      });
      if (activity != null) {
        // 推荐卡此时已发到聊天里；顺带拉一次检视（此时通常还没有拍摄物品）。
        await _inspectOnly(activity.id);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = _asMessage(error);
      });
    }
  }

  Future<void> _inspectOnly(String activityId) async {
    try {
      widget.api.authToken = widget.session.token;
      final inspect = await widget.api.adminInspectOfflineActivity(activityId);
      if (!mounted) return;
      setState(() => _inspect = inspect);
    } catch (_) {
      // 检视失败不阻断主流程（活动已生成）。
    }
  }

  Future<void> _generateItems() async {
    final activity = _activity;
    if (activity == null || _generatingItems) return;
    setState(() {
      _generatingItems = true;
      _error = null;
    });
    try {
      widget.api.authToken = widget.session.token;
      final inspect =
          await widget.api.adminGenerateOfflineActivityItems(activity.id);
      if (!mounted) return;
      setState(() {
        _generatingItems = false;
        _inspect = inspect;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _generatingItems = false;
        _error = _asMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AdminScaffold(
      title: '测试生成活动',
      subtitle: '生成活动 → 查看任务细节',
      trailing: _loadingExisting
          ? const Padding(
              padding: EdgeInsets.only(right: 4),
              child: CupertinoActivityIndicator(radius: 10),
            )
          : (_activity == null
              ? null
              : _AppNavCircleButton(
                  icon: CupertinoIcons.refresh,
                  onPressed: () => _loadExisting(),
                )),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        children: [
          _AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('第一步：生成活动',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('调用真实推荐链路（联网搜点 + 生成推荐卡，推荐卡会发到聊天里）。',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.of(context).muted)),
                const SizedBox(height: 12),
                _TestActionButton(
                  label: _generating ? '正在生成...' : '生成新活动',
                  busy: _generating,
                  onPressed: _generating ? null : _generate,
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            _AdminCard(
              child: Text(_error!,
                  style: TextStyle(
                      fontSize: 13, color: AppColors.of(context).danger)),
            ),
          ],
          if (_activity != null) ...[
            const SizedBox(height: 14),
            _buildActivityCard(context, _activity!),
            const SizedBox(height: 14),
            _AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('第二步：生成任务物品',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(
                    '拍摄物品(任务)本应在「到达」后生成。此按钮绕过到达校验，直接生成 3–5 个物品，方便测试查看。',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.of(context).muted),
                  ),
                  const SizedBox(height: 12),
                  _TestActionButton(
                    label: _generatingItems ? '正在生成任务...' : '生成任务物品',
                    busy: _generatingItems,
                    onPressed: _generatingItems ? null : _generateItems,
                  ),
                ],
              ),
            ),
          ],
          if (_inspect != null) ...[
            const SizedBox(height: 14),
            _buildTaskCard(context, _inspect!),
          ],
          const SizedBox(height: 14),
          _AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('清理所有推荐活动',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('删除当前登录用户下的全部线下活动推荐记录和完成反馈，无法撤销。',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.of(context).muted)),
                const SizedBox(height: 12),
                _TestActionButton(
                  label: _clearing ? '正在清理...' : '清理所有推荐活动',
                  busy: _clearing,
                  color: const Color(0xFFE35B6F),
                  onPressed: _clearing ? null : _clearAll,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(BuildContext context, OfflineActivity a) {
    final muted = AppColors.of(context).muted;
    return _AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(a.title.isEmpty ? '(未命名活动)' : a.title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          _kv(context, '地点', a.locationName ?? a.address ?? '—'),
          _kv(context, '类型', a.category ?? '—'),
          _kv(context, '状态', '${_statusLabel(a.status)}${a.reached ? ' · 已到达' : ''}'),
          if (a.summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(a.summary, style: TextStyle(fontSize: 13, color: muted)),
          ],
          if (a.status == 'pending') ...[
            const SizedBox(height: 6),
            Text('提示：pending 推荐只在聊天里以推荐卡出现，不进活动列表；「想去看看」后进「待出行」。',
                style: TextStyle(fontSize: 12, color: muted)),
            const SizedBox(height: 10),
            _TestActionButton(
              label: _accepting ? '正在接受...' : '想去看看（接受 → 待出行）',
              busy: _accepting,
              onPressed: _accepting ? null : _accept,
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'pending（推荐未决定）';
      case 'accepted':
        return 'accepted（待出行/进行中）';
      case 'ignored':
        return 'ignored（暂不考虑）';
      case 'completed':
        return 'completed（已完成）';
      default:
        return status;
    }
  }

  Widget _buildTaskCard(BuildContext context, OfflineActivityInspect ins) {
    final muted = AppColors.of(context).muted;
    return _AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('任务：拍摄物品（${ins.items.length}）',
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('这些物品不对用户展示；用户拍到其中任一未触发的即可掉思绪碎片。',
              style: TextStyle(fontSize: 12, color: muted)),
          const SizedBox(height: 10),
          if (ins.items.isEmpty)
            Text('（还没有拍摄物品——点上面「生成任务物品」）',
                style: TextStyle(fontSize: 13, color: muted))
          else
            ...ins.items.map((it) => _taskItemRow(context, it)),
          if (ins.fragments.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('已产出碎片（${ins.fragments.length}）',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ...ins.fragments.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('· [${f.tier}] ${f.text}',
                    style: TextStyle(fontSize: 13, color: muted)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _taskItemRow(BuildContext context, OfflineActivityInspectItem it) {
    final muted = AppColors.of(context).muted;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.of(context).surfaceMuted.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  it.shortName + (it.category.isNotEmpty ? '（${it.category}）' : ''),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                it.triggered ? '✅ 已触发' : '⬜ 未触发',
                style: TextStyle(
                    fontSize: 12,
                    color: it.triggered ? const Color(0xFF34C759) : muted),
              ),
            ],
          ),
          if (it.criteria.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('判定要点：${it.criteria}',
                style: TextStyle(fontSize: 12, color: muted)),
          ],
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(k,
                style: TextStyle(
                    fontSize: 13, color: AppColors.of(context).muted)),
          ),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

/// 测试页操作按钮（填充态 + busy 转圈）。
class _TestActionButton extends StatelessWidget {
  const _TestActionButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.of(context).accent;
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 12),
        borderRadius: BorderRadius.circular(14),
        color: accent,
        onPressed: onPressed,
        child: busy
            ? const CupertinoActivityIndicator(color: Colors.white, radius: 10)
            : Text(label,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
      ),
    );
  }
}
