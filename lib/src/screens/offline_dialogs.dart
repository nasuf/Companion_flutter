part of 'package:companion_flutter/main.dart';

// 打卡页相关弹窗/浮层：预言、出门小说明、归档确认、查看位置。
// 全部走 _W2b 玻璃令牌（与天气/胶囊一致）：半透明玻璃面 + 亮白描边 + 柔投影。

/// 此行小预言（spec §5.4-10）：居中玻璃卡，点卡片/遮罩关闭。
Future<void> showOfflineProphecyDialog(BuildContext context, String text) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'offline-prophecy',
    barrierColor: Colors.black.withValues(alpha: 0.48),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, _, __) {
      final w = _W2b.resolve(dialogContext);
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: GestureDetector(
            onTap: () => Navigator.of(dialogContext).pop(),
            child: _GlassDialogCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🔮', style: TextStyle(fontSize: 30, color: w.ink)),
                  const SizedBox(height: 12),
                  Text('此行小预言', style: _titleStyle(dialogContext, 19)),
                  const SizedBox(height: 14),
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: _mutedStyle(dialogContext, 15).copyWith(height: 1.7),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (_, anim, __, child) =>
        _dialogScaleFade(anim, child),
  );
}

/// 出门小说明（spec §5.2 完整文案）：居中玻璃说明卡。
Future<void> showOfflinePlayGuideDialog(BuildContext context) {
  const items = <String>[
    '你拍下的现场照片，有机会唤醒一段旅途思绪。',
    '有些思绪是瞬间的偶然感受，重复拍到一样景物，也不一定再次出现。',
    '旅途结束后，照片、对话和收集到的思绪，都会整理成记忆手札。',
    '如果忘记手动结束旅途，确认到达满 24 小时会自动帮你归档。',
  ];
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'offline-playguide',
    barrierColor: Colors.black.withValues(alpha: 0.48),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, _, __) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: _GlassDialogCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('出门小说明', style: _titleStyle(dialogContext, 19)),
                const SizedBox(height: 10),
                Text(
                  '不用赶着完成什么，慢慢逛就好。路上有几件小事，想轻轻告诉你——',
                  style: _mutedStyle(dialogContext, 14).copyWith(height: 1.6),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _PlayGuideItem(index: i + 1, text: items[i]),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: _PrimaryActivityPillButton(
                    label: '好，知道了',
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (_, anim, __, child) => _dialogScaleFade(anim, child),
  );
}

/// 归档确认（spec §5.4-12）：收好 / 再等等。返回 true 表示确认收好。
Future<bool> showOfflineArchiveConfirm(BuildContext context) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'offline-archive-confirm',
    barrierColor: Colors.black.withValues(alpha: 0.48),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (dialogContext, _, __) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: _GlassDialogCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('收好这段回忆', style: _titleStyle(dialogContext, 18)),
                const SizedBox(height: 10),
                Text(
                  '之后可以在活动回顾里再打开它，是否继续？',
                  textAlign: TextAlign.center,
                  style: _mutedStyle(dialogContext, 14).copyWith(height: 1.6),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _SecondaryActivityPillButton(
                        label: '再等等',
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PrimaryActivityPillButton(
                        label: '收好',
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (_, anim, __, child) => _dialogScaleFade(anim, child),
  );
  return result ?? false;
}

/// 取消进行中活动确认（spec §4.2）。返回 true 表示确认取消。
Future<bool> showOfflineCancelConfirm(BuildContext context) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'offline-cancel-confirm',
    barrierColor: Colors.black.withValues(alpha: 0.48),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (dialogContext, _, __) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: _GlassDialogCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('取消这次行程', style: _titleStyle(dialogContext, 18)),
                const SizedBox(height: 10),
                Text(
                  '取消后它不会再出现在待出行里，确定吗？',
                  textAlign: TextAlign.center,
                  style: _mutedStyle(dialogContext, 14).copyWith(height: 1.6),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _SecondaryActivityPillButton(
                        label: '再想想',
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PrimaryActivityPillButton(
                        label: '取消行程',
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (_, anim, __, child) => _dialogScaleFade(anim, child),
  );
  return result ?? false;
}

/// 查看位置（spec §5.4-9）：底部玻璃 sheet，展示完整地址 + 复制 + 唤起导航。
Future<void> showOfflineLocationSheet(
  BuildContext context, {
  required String name,
  required String? address,
}) {
  final display = (address == null || address.trim().isEmpty) ? name : address;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.34),
    builder: (sheetContext) {
      final w = _W2b.resolve(sheetContext);
      return _BottomSheetFrame(
        backgroundColor: w.base,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetGrabber(sheetContext),
            Text('位置', style: _titleStyle(sheetContext, 18)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: _softCardDecoration(sheetContext, radius: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: _titleStyle(sheetContext, 16)),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(CupertinoIcons.location_solid,
                          size: 16, color: w.inkSoft),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          display,
                          style: _mutedStyle(sheetContext, 14)
                              .copyWith(height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _SecondaryActivityPillButton(
                    label: '复制地址',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: display));
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop();
                        _showActivityToast(context, '地址已复制');
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PrimaryActivityPillButton(
                    label: '导航前往',
                    icon: '🧭',
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await _openOfflineMapQuery(context, display);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _openOfflineMapQuery(BuildContext context, String query) async {
  final q = Uri.encodeComponent(query);
  final src = Uri.encodeComponent('伴生');
  final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
  // 1) 优先唤起高德 App，按地址关键字搜索（无需坐标、无需 Key）。
  //    iOS 需在 Info.plist 的 LSApplicationQueriesSchemes 声明 iosamap；
  //    Android 11+ 需在 manifest 声明 <queries> androidamap，否则 canLaunchUrl 返回 false。
  final amap = Uri.parse(
    isIOS
        ? 'iosamap://search?sourceApplication=$src&keywords=$q&dev=0'
        : 'androidamap://search?sourceApplication=$src&keywords=$q&dev=0',
  );
  try {
    if (await canLaunchUrl(amap)) {
      await launchUrl(amap, mode: LaunchMode.externalApplication);
      return;
    }
  } catch (_) {
    // 未安装高德或未声明 scheme → 落系统地图。
  }
  // 2) 兜底：系统地图按地址搜索（iOS Apple 地图 / Android 唤起默认地图选择器）。
  final system = isIOS
      ? Uri.parse('http://maps.apple.com/?q=$q')
      : Uri.parse('geo:0,0?q=$q');
  try {
    await launchUrl(system, mode: LaunchMode.externalApplication);
  } catch (_) {
    if (context.mounted) _showActivityToast(context, '没有可用的地图应用');
  }
}

class _GlassDialogCard extends StatelessWidget {
  const _GlassDialogCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          decoration: BoxDecoration(
            color: w.glass,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: w.glassBorder),
            boxShadow: w.panelShadow,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PlayGuideItem extends StatelessWidget {
  const _PlayGuideItem({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: _kActivityAccent.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$index',
              style: const TextStyle(
                color: _kActivityAccent,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: _mutedStyle(context, 13).copyWith(height: 1.6, color: w.ink),
          ),
        ),
      ],
    );
  }
}

Widget _dialogScaleFade(Animation<double> anim, Widget child) {
  final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
  return FadeTransition(
    opacity: curved,
    child: ScaleTransition(
      scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
      child: child,
    ),
  );
}
