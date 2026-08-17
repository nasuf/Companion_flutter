part of 'package:companion_flutter/main.dart';

class _CapsuleSendChatButton extends StatelessWidget {
  const _CapsuleSendChatButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: const Color(0xFF101922),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF101922).withValues(alpha: 0.16),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: onTap == null ? 0.58 : 1,
          child: const Text(
            '发聊天',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyCapsuleActions extends StatelessWidget {
  const _ReadOnlyCapsuleActions({
    required this.enabled,
    required this.deleting,
    required this.onDelete,
    required this.onSend,
  });

  final bool enabled;
  final bool deleting;
  final VoidCallback onDelete;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CapsuleCircleButton(
          icon: CupertinoIcons.delete,
          danger: true,
          loading: deleting,
          onTap: enabled ? onDelete : null,
        ),
        const SizedBox(width: 8),
        _CapsuleSendChatButton(onTap: enabled ? onSend : null),
      ],
    );
  }
}

class _WarmBlurSpot extends StatelessWidget {
  const _WarmBlurSpot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

/// 首页头部：玻璃返回键 + 招呼语 + 保留的瓶子主插画（响应式，不再用绝对坐标）。
class _CapsuleHomeHeader extends StatelessWidget {
  const _CapsuleHomeHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    // Restores the original hero: the bottle (with its clouds) floats big in the
    // top-right, the greeting sits lower-left with the hand-drawn underline
    // beneath it, and the weather-page back button anchors the top-left. A fixed
    // Stack band lets the greeting overlap the bottle exactly like the design.
    return SizedBox(
      height: 148,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -4,
            top: -6,
            child: SizedBox(
              width: 172,
              height: 140,
              child: Image.asset(_capsuleAssetHomeHero, fit: BoxFit.contain),
            ),
          ),
          Positioned(left: 0, top: 4, child: _WeatherBackButton(onTap: onBack)),
          const Positioned(
            left: 2,
            bottom: 28,
            child: Text(
              'Hi，未来的自己',
              style: TextStyle(
                color: _capsuleOrange,
                fontSize: 24,
                height: 29 / 24,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          Positioned(
            left: 62,
            bottom: 8,
            child: SvgPicture.asset(
              _capsuleAssetHomeUnderline,
              width: 80,
              height: 15,
              fit: BoxFit.fill,
            ),
          ),
        ],
      ),
    );
  }
}

/// 写新胶囊：主玻璃卡 + 橙色线性徽章 + 右侧橙色圆箭头。
class _CapsuleWriteEntryCard extends StatelessWidget {
  const _CapsuleWriteEntryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
        decoration: _capsuleGlassCard(context),
        child: Row(
          children: [
            const _CapsuleMedallion(icon: CupertinoIcons.pencil, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '写新胶囊',
                    style: TextStyle(
                      color: w.ink,
                      fontSize: 16,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '写一封信给未来的自己',
                    style: TextStyle(
                      color: w.inkSoft,
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: FontWeight.w400,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _capsuleOrange,
                boxShadow: [
                  BoxShadow(
                    color: _capsuleOrange.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                CupertinoIcons.chevron_forward,
                color: Colors.white,
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapsuleHomeShortcutGrid extends StatelessWidget {
  const _CapsuleHomeShortcutGrid({
    required this.draftCount,
    required this.pendingCount,
    required this.openedCount,
    required this.onDrafts,
    required this.onPending,
    required this.onOpened,
  });

  final int draftCount;
  final int pendingCount;
  final int openedCount;
  final VoidCallback? onDrafts;
  final VoidCallback? onPending;
  final VoidCallback? onOpened;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CapsuleHomeShortcutCard(
            label: '草稿',
            count: draftCount,
            icon: CupertinoIcons.doc_text_fill,
            onTap: onDrafts,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _CapsuleHomeShortcutCard(
            label: '待解封',
            count: pendingCount,
            icon: CupertinoIcons.lock_fill,
            onTap: onPending,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _CapsuleHomeShortcutCard(
            label: '已解封',
            count: openedCount,
            icon: CupertinoIcons.envelope_open_fill,
            onTap: onOpened,
          ),
        ),
      ],
    );
  }
}

/// 三宫格入口卡：仿天气页四个数据卡片 / 成就页三张统计卡——玻璃面、圆角 24，
/// 顶部小标题（草稿 / 待解封 / 已解封），底部一行「橙色徽章 + 大号数量」。
/// 数量当作"数值"（像天气的体感/湿度），不再用右上角红色角标。空态整卡调暗。
class _CapsuleHomeShortcutCard extends StatelessWidget {
  const _CapsuleHomeShortcutCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    final enabled = onTap != null;
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Container(
          height: 88,
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          decoration: _capsuleGlassCard(context, radius: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: w.inkSoft,
                  fontSize: 12.5,
                  height: 1,
                  fontWeight: FontWeight.w400,
                  decoration: TextDecoration.none,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  _CapsuleMedallion(icon: icon, size: 34),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$count',
                      maxLines: 1,
                      style: TextStyle(
                        color: w.ink,
                        fontSize: 22,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        decoration: TextDecoration.none,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Design "Rectangle 283" — 350x120 glass card with the opened-capsule
/// illustration bleeding out to the right.
class _CapsuleLastOpenedCard extends StatelessWidget {
  const _CapsuleLastOpenedCard({
    required this.newestOpened,
    required this.hasOpened,
  });

  final TimeCapsule? newestOpened;
  final bool hasOpened;

  @override
  Widget build(BuildContext context) {
    final openedAt =
        newestOpened?.openedAt ??
        newestOpened?.openDate ??
        newestOpened?.createdAt;
    final days = !hasOpened || openedAt == null
        ? 0
        : DateTime.now().difference(openedAt).inDays.clamp(0, 9999);
    return Container(
      height: 120,
      decoration: _capsuleGlassCard(context, radius: 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Design "胶囊 2" and the two stars sit against the card's right edge,
          // so they are anchored from the right to survive wider screens.
          Positioned(
            right: 43,
            top: 0,
            width: 110,
            height: 110,
            child: Image.asset(_capsuleAssetLastOpened, fit: BoxFit.contain),
          ),
          Positioned(
            right: 25,
            top: 14,
            child: Image.asset(_capsuleAssetHomeStarLg, width: 14, height: 14),
          ),
          Positioned(
            right: 23,
            top: 32,
            child: Image.asset(_capsuleAssetHomeStarSm, width: 6, height: 6),
          ),
          const Positioned(
            left: 28,
            top: 24,
            child: Text(
              '距上一个胶囊开启过去',
              style: TextStyle(
                color: _capsuleInk,
                fontSize: 16,
                height: 19 / 16,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          Positioned(
            left: 28,
            top: 57,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$days',
                  style: const TextStyle(
                    color: _capsuleOrange,
                    fontSize: 36,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(width: 10),
                const Padding(
                  padding: EdgeInsets.only(bottom: 3),
                  child: Text(
                    '天',
                    style: TextStyle(
                      color: Color(0xFFBFBFBF),
                      fontSize: 12,
                      height: 14 / 12,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 28,
            top: 96,
            child: Container(width: 86, height: 3, color: _capsuleOrange),
          ),
        ],
      ),
    );
  }
}

/// A draft row inside [_CapsuleDraftSheet]. Shares the glass-card language of
/// the home shortcuts — the same `doc_text_fill` medallion as the 草稿 card the
/// sheet grew from, a glass panel, radius 20 — so the drafts read as the same
/// family of rows one tap earlier.
class _CapsuleDraftTile extends StatelessWidget {
  const _CapsuleDraftTile({required this.capsule, required this.onTap});

  final TimeCapsule capsule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    final edited = _formatCapsuleMonthDay(capsule.updatedAt);
    final openDate = capsule.openDate;
    // A draft's open date is optional and often unset, so the last edit is the
    // line that always earns its place.
    final meta = openDate == null
        ? '$edited 编辑'
        : '$edited 编辑 · ${_formatCapsuleMonthDay(openDate)} 开启';
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        // minHeight rather than a fixed 80: the two text lines are the only
        // thing that grows under a large system text scale, and a hard height
        // would overflow instead of letting the row breathe.
        constraints: const BoxConstraints(minHeight: 80),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: _capsuleGlassCard(context, radius: 20),
        child: Row(
          children: [
            // Same medallion glyph as the 草稿 shortcut card on the home
            // screen, so the sheet looks like it grew out of the tapped card.
            const _CapsuleMedallion(
              icon: CupertinoIcons.doc_text_fill,
              size: 48,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    capsule.preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: w.ink,
                      fontSize: 14,
                      height: 17 / 14,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(CupertinoIcons.calendar, size: 11, color: w.inkSoft),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: w.inkSoft,
                            fontSize: 10,
                            height: 12 / 10,
                            fontWeight: FontWeight.w400,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(CupertinoIcons.chevron_forward, size: 16, color: w.inkFaint),
          ],
        ),
      ),
    );
  }
}

class _CapsuleDeleteSwipeBackground extends StatelessWidget {
  const _CapsuleDeleteSwipeBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _capsuleDanger,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _capsuleDanger.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(CupertinoIcons.delete_solid, color: Colors.white, size: 24),
              SizedBox(height: 4),
              Text(
                '删除',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
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
