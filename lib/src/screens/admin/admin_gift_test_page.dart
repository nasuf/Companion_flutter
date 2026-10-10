part of 'package:companion_flutter/main.dart';

class AdminGiftTestPage extends StatefulWidget {
  const AdminGiftTestPage({
    super.key,
    required this.api,
    required this.session,
  });
  final CompanionApi api;
  final AuthSession session;

  @override
  State<AdminGiftTestPage> createState() => _AdminGiftTestPageState();
}

class _AdminGiftTestPageState extends State<AdminGiftTestPage> {
  bool _busy = false;
  bool _clearing = false;
  String? _error;

  Future<void> _injectMockGift({required bool delivered}) async {
    if (_busy) return;
    setState(() => _busy = true);

    var progressOpen = true;
    unawaited(
      showCupertinoDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _AdminProgressDialog(
          title: delivered ? '正在注入已送达礼物' : '正在注入运输中礼物',
          message: '正在走 mock 链路下单并生成物流轨迹...',
        ),
      ).whenComplete(() {
        progressOpen = false;
      }),
    );

    try {
      widget.api.authToken = widget.session.token;
      final gift = await widget.api.createMockGift(
        workspaceId: widget.session.workspaceId,
        delivered: delivered,
      );
      if (!mounted) return;
      if (progressOpen) Navigator.of(context, rootNavigator: true).pop();
      setState(() => _busy = false);
      await _showGiftResult(
        title: '测试礼物已注入',
        message: delivered
            ? '已生成「${gift.giftName}」并标记为已送达，可去赠礼页查看历史礼物分组与感谢交互。'
            : '已生成「${gift.giftName}」（运输中），可去赠礼页查看礼物卡与物流时间线。',
      );
    } catch (error) {
      if (!mounted) return;
      if (progressOpen) Navigator.of(context, rootNavigator: true).pop();
      setState(() => _busy = false);
      await _showGiftResult(title: '注入失败', message: _asMessage(error));
    }
  }

  Future<void> _showGiftResult({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    final action = await showCupertinoDialog<String>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop('ok'),
              child: const Text('知道了'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop('open'),
              child: const Text('去赠礼页'),
            ),
          ],
        );
      },
    );
    if (!mounted || action != 'open') return;
    await Navigator.of(context).push(
      CompanionPageRoute<void>(
        builder: (_) =>
            OfflineGiftPage(api: widget.api, session: widget.session),
      ),
    );
  }

  Future<void> _clearAll() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('清空所有礼物信息？'),
          content: const Text(
            '删除当前账号在所有工作区、所有状态下的礼物、物流轨迹和礼物关联聊天消息。收货地址会保留。此操作无法撤销，也不会取消已向商家提交的订单。',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确认清空'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() {
        _clearing = true;
        _error = null;
      });
      widget.api.authToken = widget.session.token;
      final result = await widget.api.clearOfflineGiftsForCurrentUser();
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('礼物信息已清空'),
          content: Text(
            '已删除 ${result.deletedGifts} 份礼物、${result.deletedTrackingEvents} 条物流轨迹、${result.deletedMessages} 条关联消息，并重置 ${result.resetTriggerStates} 条赠礼冷却记录。',
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
      if (mounted) setState(() => _error = '清空失败：${_asMessage(error)}');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _clearing = false;
        });
      }
    }
  }

  Widget _action(
    String title,
    String description,
    VoidCallback onPressed, {
    bool destructive = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.of(context).muted,
              ),
            ),
            const SizedBox(height: 12),
            _TestActionButton(
              label: title,
              onPressed: _busy ? null : onPressed,
              busy: destructive && _clearing,
              color: destructive ? CupertinoColors.systemRed : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _AdminScaffold(
      title: '测试礼物赠送',
      subtitle: '仅影响当前登录账号',
      child: widget.session.role != UserRole.admin
          ? const Center(child: Text('仅管理员可用'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
              children: [
                _action(
                  '注入运输中礼物',
                  '生成一份测试礼物，附 mock 物流轨迹。',
                  () => _injectMockGift(delivered: false),
                ),
                _action(
                  '注入已送达礼物',
                  '生成已送达礼物并推送送达消息，验证感谢交互。',
                  () => _injectMockGift(delivered: true),
                ),
                _action(
                  '清空所有礼物信息',
                  '清空当前账号所有工作区的礼物与关联数据，保留收货地址。',
                  _clearAll,
                  destructive: true,
                ),
                if (_error != null)
                  _AdminCard(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: CupertinoColors.systemRed),
                    ),
                  ),
              ],
            ),
    );
  }
}
