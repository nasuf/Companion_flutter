part of 'package:companion_flutter/main.dart';

// 打卡页相关弹窗/浮层：预言、出门小说明、归档确认、查看位置。
// 背景走高斯模糊；弹框卡片本身用实底（不透底），与记忆手札浮层一致。

/// 此行小预言（spec §5.4-10）：居中玻璃卡，点卡片/遮罩关闭。
Future<void> showOfflineProphecyDialog(BuildContext context, String text) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'offline-prophecy',
    barrierColor: Colors.transparent, // 背景改用高斯模糊（见 transitionBuilder）
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
    transitionBuilder: (ctx, anim, __, child) =>
        _blurGlassBarrier(ctx, anim, child),
  );
}

/// 出门小说明（spec §5.2 完整文案）：居中实底说明卡。
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
    barrierColor: Colors.transparent, // 背景改用高斯模糊（见 transitionBuilder）
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
    transitionBuilder: (ctx, anim, __, child) =>
        _blurGlassBarrier(ctx, anim, child),
  );
}

/// 归档确认（spec §5.4-12）：收好 / 再等等。返回 true 表示确认收好。
Future<bool> showOfflineArchiveConfirm(BuildContext context) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'offline-archive-confirm',
    barrierColor: Colors.transparent, // 背景改用高斯模糊（见 transitionBuilder）
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
    transitionBuilder: (ctx, anim, __, child) =>
        _blurGlassBarrier(ctx, anim, child),
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

  // 高德 URI 的导航 action 需要目的地坐标（没有坐标时 iosamap://search 之类会被高德判
  // 「版本不支持该功能」）。用系统地理编码把地址解析成坐标——免费、无需高德 key。国内
  // Apple CLGeocoder 返回 GCJ-02，与高德同坐标系，故 dev=0 不再二次偏移。
  double? lat;
  double? lon;
  try {
    final results = await geocoding
        .locationFromAddress(query)
        .timeout(const Duration(seconds: 4));
    if (results.isNotEmpty) {
      lat = results.first.latitude;
      lon = results.first.longitude;
    }
  } catch (_) {
    // 解析失败（如安卓无 Google 后端）→ 走下面的关键字兜底。
  }

  // 1) 有坐标 → 唤起高德 App 导航（iOS 需 Info.plist 声明 iosamap；
  //    Android 11+ 需 manifest <queries> androidamap，否则 canLaunchUrl 返回 false）。
  if (lat != null && lon != null) {
    final amap = Uri.parse(
      isIOS
          ? 'iosamap://navi?sourceApplication=$src&poiname=$q&lat=$lat&lon=$lon&dev=0&style=2'
          : 'androidamap://navi?sourceApplication=$src&poiname=$q&lat=$lat&lon=$lon&dev=0&style=2',
    );
    try {
      if (await canLaunchUrl(amap)) {
        await launchUrl(amap, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {
      // 未装高德/无法唤起 → 落系统地图。
    }
  }

  // 2) 兜底：系统地图按地址搜索。Android 的 geo: 常直接进高德/唤起地图选择器（高德自己
  //    做地址搜索，无需坐标）；iOS 进 Apple 地图。
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
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: _opaqueActivitySurface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _opaqueActivityBorder(context)),
        boxShadow: w.panelShadow,
      ),
      child: child,
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

/// 玻璃弹窗背景：**高斯模糊**而非压暗（barrierColor 设 transparent，改用这个）。
/// 背景随弹窗淡入模糊；点背景可关闭（dismissible 时），弹窗卡片仍走缩放淡入。
Widget _blurGlassBarrier(
  BuildContext dialogContext,
  Animation<double> anim,
  Widget child, {
  bool dismissible = true,
}) {
  return Stack(
    children: [
      Positioned.fill(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: dismissible
                ? () => Navigator.of(dialogContext).maybePop()
                : null,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              // 极淡冷调，只为把卡片从背景里托出来，不压暗画面。
              child: const ColoredBox(color: Color(0x141B2430)),
            ),
          ),
        ),
      ),
      _dialogScaleFade(anim, child),
    ],
  );
}
