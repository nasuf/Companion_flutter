part of 'package:companion_flutter/main.dart';

class _OpenedCapsulesPage extends StatefulWidget {
  const _OpenedCapsulesPage({
    required this.capsules,
    required this.onOpen,
    required this.onView,
    required this.onDelete,
  });

  final List<TimeCapsule> capsules;
  final Future<TimeCapsule> Function(TimeCapsule capsule) onOpen;
  final Future<Object?> Function(TimeCapsule capsule) onView;
  final Future<bool> Function(TimeCapsule capsule) onDelete;

  @override
  State<_OpenedCapsulesPage> createState() => _OpenedCapsulesPageState();
}

class _OpenedCapsulesPageState extends State<_OpenedCapsulesPage> {
  late final List<TimeCapsule> _capsules = List.of(widget.capsules);
  String? _openingCapsuleId;
  bool _showingCapsuleDetail = false;

  Future<void> _showCapsuleDetail(TimeCapsule capsule) async {
    if (_showingCapsuleDetail) return;
    setState(() => _showingCapsuleDetail = true);
    Object? result;
    try {
      result = await widget.onView(capsule);
    } finally {
      if (mounted) setState(() => _showingCapsuleDetail = false);
    }
    if (!mounted || result == null) return;
    if (result is CapsuleChatDraft) {
      Navigator.of(context).pop(result);
      return;
    }
    if (result is _CapsuleEditorResult && result.deleted) {
      setState(() => _capsules.removeWhere((item) => item.id == capsule.id));
    }
  }

  Future<void> _openReadyCapsule(TimeCapsule capsule) async {
    if (!capsule.isReady || _openingCapsuleId != null) return;
    setState(() => _openingCapsuleId = capsule.id);
    try {
      final opened = await widget.onOpen(capsule);
      if (!mounted) return;
      setState(() {
        final index = _capsules.indexWhere((item) => item.id == capsule.id);
        if (index >= 0) _capsules[index] = opened;
        _openingCapsuleId = null;
      });
      await _showCapsuleDetail(opened);
    } catch (error) {
      if (!mounted) return;
      setState(() => _openingCapsuleId = null);
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('开启失败'),
          content: Text(_asMessage(error)),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: w.isDark ? _capsuleWarmBaseDark : _capsuleWarmBase,
      child: Stack(
        children: [
          // Same breathing warm ground as the home, so the opened list reads as
          // one step deeper into the same room rather than a new screen.
          const Positioned.fill(child: _CapsuleBackground()),
          DefaultTextStyle.merge(
            style: TextStyle(color: w.ink, decoration: TextDecoration.none),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      height: 36,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Center(
                              child: Text(
                                '已解封',
                                style: TextStyle(
                                  color: w.ink,
                                  fontSize: 24,
                                  height: 29 / 24,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 20,
                            child: _WeatherBackButton(
                              onTap: () => Navigator.of(context).maybePop(),
                              iconColor: _capsuleOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 19, 20, 0),
                    child: _OpenedSummaryCard(count: _capsules.length),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 23, 20, 0),
                    child: Row(
                      children: [
                        SvgPicture.asset(
                          _capsuleAssetOpenedStar,
                          width: 20,
                          height: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '我的胶囊',
                          style: TextStyle(
                            color: w.ink,
                            fontSize: 20,
                            height: 24 / 20,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _capsules.isEmpty
                        ? Center(
                            child: Text(
                              '暂无已解封胶囊',
                              style: TextStyle(
                                color: w.inkSoft,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              20,
                              17,
                              20,
                              bottom + 34,
                            ),
                            itemCount: _capsules.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 20),
                            itemBuilder: (context, index) {
                              final capsule = _capsules[index];
                              final isOpening = _openingCapsuleId == capsule.id;
                              final interactionLocked =
                                  _openingCapsuleId != null ||
                                  _showingCapsuleDetail;
                              return _OpenedCapsuleSheetTile(
                                capsule: capsule,
                                isOpening: isOpening,
                                interactionLocked: interactionLocked,
                                onTap: () {
                                  if (capsule.isReady) {
                                    unawaited(_openReadyCapsule(capsule));
                                  } else {
                                    unawaited(_showCapsuleDetail(capsule));
                                  }
                                },
                                onDelete: () async {
                                  if (_openingCapsuleId != null) return false;
                                  final deleted = await widget.onDelete(
                                    capsule,
                                  );
                                  if (deleted && mounted) {
                                    setState(() => _capsules.removeAt(index));
                                  }
                                  return deleted;
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The opened-screen hero: the same glass card + line-glyph medallion language
/// as the home write entry, with the count spelled out over two lines.
class _OpenedSummaryCard extends StatelessWidget {
  const _OpenedSummaryCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return Container(
      height: 96,
      padding: const EdgeInsets.fromLTRB(15, 0, 16, 0),
      decoration: _capsuleGlassCard(context),
      child: Row(
        children: [
          const _CapsuleMedallion(
            icon: CupertinoIcons.envelope_open_fill,
            size: 52,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The count is the one word the design blows up and tints; the
                // rest of the sentence stays 20/700 ink.
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: '共有 '),
                      TextSpan(
                        text: '$count',
                        style: const TextStyle(
                          color: _capsuleOrange,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(text: ' 枚胶囊'),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: w.ink,
                    fontSize: 20,
                    height: 25 / 20,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '已经解封',
                  style: TextStyle(
                    color: w.inkSoft,
                    fontSize: 14,
                    height: 17 / 14,
                    fontWeight: FontWeight.w400,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Design "Group 430" — 350x96 white list card. Capsules that are due but not
/// yet opened keep a locked thumbnail and an "开启" pill.
class _OpenedCapsuleSheetTile extends StatelessWidget {
  const _OpenedCapsuleSheetTile({
    required this.capsule,
    required this.isOpening,
    required this.interactionLocked,
    required this.onTap,
    required this.onDelete,
  });

  final TimeCapsule capsule;
  final bool isOpening;
  final bool interactionLocked;
  final VoidCallback onTap;
  final Future<bool> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    final isReady = capsule.isReady;
    final open = capsule.openDate == null
        ? '未知日期'
        : _formatCapsuleDotDate(capsule.openDate!);
    final created = _formatCapsuleDotDate(capsule.createdAt);
    final tile = CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: interactionLocked ? () {} : onTap,
      child: Container(
        height: 96,
        padding: const EdgeInsets.fromLTRB(22, 0, 15, 0),
        // No shadow here: the ClipRRect below would eat it, so the outer box
        // paints it instead.
        decoration: BoxDecoration(
          color: w.glass,
          border: Border.all(color: w.glassBorder),
          borderRadius: BorderRadius.circular(20),
        ),
        // Design anchors each column to its own y inside the 96-high card
        // (thumb 23, copy 11, pill 56) rather than centring them together.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 23),
              child: SizedBox(
                width: 52,
                height: 51,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: isReady ? 0.42 : 1,
                      child: Image.asset(
                        _capsuleAssetOpenedThumb,
                        fit: BoxFit.contain,
                      ),
                    ),
                    if (isReady)
                      const Icon(
                        CupertinoIcons.lock_fill,
                        color: _capsuleOrange,
                        size: 26,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 26),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 11),
                  Text(
                    isReady ? '一封来自过去的信' : capsule.preview,
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
                  const SizedBox(height: 4),
                  Text(
                    '$created 创建',
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
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(CupertinoIcons.calendar, size: 11, color: w.inkSoft),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '$open 开启',
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
            // Design "Rectangle 237" — 82x27 orange pill sitting low in the card.
            Padding(
              padding: const EdgeInsets.only(top: 56),
              child: Container(
                width: 82,
                height: 27,
                decoration: BoxDecoration(
                  color: _capsuleOrange,
                  border: Border.all(
                    color: _capsuleHairline.withValues(alpha: 0.5),
                  ),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [_capsuleOrangeShadow],
                ),
                alignment: Alignment.center,
                child: isOpening
                    ? const CupertinoActivityIndicator(
                        radius: 8,
                        color: Colors.white,
                      )
                    : Text(
                        isReady ? '开启' : '查看详情',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 17 / 14,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.none,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
    // The swipe-to-delete background has to be clipped to the card radius, but
    // clipping would also eat the card's drop shadow — so the shadow is painted
    // by an outer box that the clip never touches.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [_capsuleGlassShadow],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Dismissible(
          key: ValueKey('arrived-sheet-${capsule.id}'),
          direction: interactionLocked
              ? DismissDirection.none
              : DismissDirection.endToStart,
          confirmDismiss: (_) async {
            await onDelete();
            return false;
          },
          background: const _CapsuleDeleteSwipeBackground(),
          child: tile,
        ),
      ),
    );
  }
}

/// Translucent white back button for the full-bleed pending scene, where the
/// weather page's glass button would disappear against the orange artwork. The
/// glass home / opened screens use [_WeatherBackButton] for an exact match.
class _CapsuleWarmBackButton extends StatelessWidget {
  const _CapsuleWarmBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.40),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFE3C8).withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Icon(CupertinoIcons.back, color: Colors.white, size: 25),
      ),
    );
  }
}
