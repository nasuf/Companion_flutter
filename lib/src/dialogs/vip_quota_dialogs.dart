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
        content: Text('之后每句消息将消耗 $costLabel 钞票，是否继续发送？'),
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

enum _VipUpsellChoice { recharge, subscribe }

/// 钞票也不够时询问是否订阅 VIP，同时给一个更直接的"去充值"选项——用户此刻
/// 最迫切的诉求是"马上能继续发消息", 充值比先看订阅套餐介绍更直接; 订阅
/// 仍保留 (且是默认高亮的那个) 因为它是长期更划算的方案, 只是不该是唯一
/// 出口 (2026-08-26 用户反馈: 点开这个弹框却只能被导向订阅页, 体验不对)。
Future<void> showVipUpsellDialog(
  BuildContext context, {
  required CompanionApi api,
  required AuthSession session,
  String content = '钞票余额不足，订阅 VIP 可获得更高免费额度和更低价格，是否订阅？',
}) async {
  final choice = await showCupertinoDialog<_VipUpsellChoice>(
    context: context,
    builder: (dialogContext) {
      return CupertinoAlertDialog(
        title: const Text('钞票不足'),
        content: Text(content),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_VipUpsellChoice.recharge),
            child: const Text('去充值'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () =>
                Navigator.of(dialogContext).pop(_VipUpsellChoice.subscribe),
            child: const Text('去订阅'),
          ),
        ],
      );
    },
  );
  if (choice == null || !context.mounted) return;
  await Navigator.of(context).push<void>(
    CupertinoPageRoute<void>(
      builder: (_) => StorePage(
        api: api,
        session: session,
        openTicketRecharge: choice == _VipUpsellChoice.recharge,
      ),
    ),
  );
}

/// 本周期已经用 [showVipUpsellDialog] 提示过一次订阅了 (`_vipUpsellAcknowledged`)，
/// 后续同周期内不再用打断式弹框重复推销订阅，但发送仍会被拦——用户需要一个
/// 明确的、不会被键盘挡住的入口去充值。系统弹框（而不是底部 SnackBar）能
/// 保证不管键盘是否弹出都完整可见；调用方需先自行收起键盘，避免弹框和
/// 键盘同时抢占视觉焦点。确认则打开商城「充值」tab。
Future<void> showTicketExhaustedDialog(
  BuildContext context, {
  required CompanionApi api,
  required AuthSession session,
  String content = '钞票已用完，去商城订阅 VIP 或充值后即可继续发送',
}) async {
  final goRecharge = await showCupertinoDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return CupertinoAlertDialog(
        title: const Text('钞票已用完'),
        content: Text(content),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('去充值'),
          ),
        ],
      );
    },
  );
  if (goRecharge != true || !context.mounted) return;
  await Navigator.of(context).push<void>(
    CupertinoPageRoute<void>(
      builder: (_) => StorePage(
        api: api,
        session: session,
        openTicketRecharge: true,
      ),
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
