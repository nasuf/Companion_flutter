part of 'package:companion_flutter/main.dart';

/// VIP 权益共用弹框（对话额度 §1 / 音乐时长 §6）。
///
/// 三类场景共享同一套措辞和跳转目标：
///   - 免费额度用完但钞票够 -> 询问是否继续扣费
///   - 钞票也不够、非VIP -> 询问是否订阅VIP
///   - 钞票也不够、VIP -> 询问是否购买对应礼包（音乐畅听券）
///
/// 全部返回 `true` 表示用户确认继续；`false`/`null` 表示取消 —— 调用方在
/// 取消时必须什么都不做（文本留在输入框 / 播放保持暂停)，不能自行兜底发送。

/// 对话额度耗尽后询问是否扣钞票继续发送（CLAUDE.md 权益项 1）。
Future<bool> showChatOverageConfirmDialog(
  BuildContext context, {
  required double perMsgCost,
}) async {
  final costLabel = perMsgCost == perMsgCost.roundToDouble()
      ? perMsgCost.toStringAsFixed(0)
      : perMsgCost.toStringAsFixed(1);
  final confirmed = await showCupertinoDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return CupertinoAlertDialog(
        title: const Text('免费额度已用完'),
        content: Text('继续发送将消耗 $costLabel 钞票，是否继续？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('继续发送'),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}

/// 音乐时长额度耗尽后询问是否扣钞票继续听（CLAUDE.md 权益项 6）。
Future<bool> showMusicOverageConfirmDialog(
  BuildContext context, {
  required int ticketCost,
}) async {
  final confirmed = await showCupertinoDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return CupertinoAlertDialog(
        title: const Text('今日免费时长已用完'),
        content: Text('继续收听将消耗 $ticketCost 钞票（每 0.5 小时），是否继续？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('暂停'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('继续收听'),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}

/// 钞票也不够时询问是否跳转订阅 VIP；确认则打开商城「订阅」tab。
Future<void> showVipUpsellDialog(
  BuildContext context, {
  required CompanionApi api,
  required AuthSession session,
  String content = '钞票余额不足，订阅 VIP 可获得更高免费额度和更低价格，是否订阅？',
}) async {
  final goSubscribe = await showCupertinoDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return CupertinoAlertDialog(
        title: const Text('钞票不足'),
        content: Text(content),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('去订阅'),
          ),
        ],
      );
    },
  );
  if (goSubscribe != true || !context.mounted) return;
  await Navigator.of(context).push<void>(
    CupertinoPageRoute<void>(
      builder: (_) => StorePage(api: api, session: session),
    ),
  );
}

/// VIP 用户钞票也不够听歌时询问是否去买音乐畅听券；确认则打开商城「礼包」tab。
Future<void> showBuyMusicCouponDialog(
  BuildContext context, {
  required CompanionApi api,
  required AuthSession session,
}) async {
  final goBuy = await showCupertinoDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return CupertinoAlertDialog(
        title: const Text('钞票不足'),
        content: const Text('钞票余额不足，去商城购买音乐畅听券即可继续收听，是否前往？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('去购买'),
          ),
        ],
      );
    },
  );
  if (goBuy != true || !context.mounted) return;
  await Navigator.of(context).push<void>(
    CupertinoPageRoute<void>(
      builder: (_) => StorePage(api: api, session: session, openBundle: true),
    ),
  );
}
