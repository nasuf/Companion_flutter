part of 'package:companion_flutter/main.dart';

class CapsuleChatDraft {
  const CapsuleChatDraft({required this.agentText, required this.card});

  final String agentText;
  final ChatComponentCard card;
}

class _CapsuleEditorResult {
  const _CapsuleEditorResult.saved(this.capsule) : deleted = false;
  const _CapsuleEditorResult.deleted(this.capsule) : deleted = true;

  final TimeCapsule capsule;
  final bool deleted;
}

const _capsuleAssetArrivedPostcard = 'assets/capsule/arrived-postcard.png';
const _capsuleAssetDialogClose = 'assets/capsule/dialog-close.png';
const _capsuleAssetHomeHero = 'assets/capsule/home-hero.png';
const _capsuleAssetHomeStarLg = 'assets/capsule/home-star-lg.png';
const _capsuleAssetHomeStarSm = 'assets/capsule/home-star-sm.png';
const _capsuleAssetHomeUnderline = 'assets/capsule/home-underline.svg';
const _capsuleAssetLastOpened = 'assets/capsule/last-opened.png';
const _capsuleAssetOpenedStar = 'assets/capsule/opened-star.svg';
const _capsuleAssetOpenedThumb = 'assets/capsule/opened-thumb.png';
const _capsuleAssetPendingBig = 'assets/capsule/pending-big.png';
const _capsuleAssetPendingShadowRing = 'assets/capsule/pending-shadow-ring.svg';
const _capsuleAssetPendingSticker54 = 'assets/capsule/pending-sticker-54.png';
const _capsuleAssetPendingSticker55 = 'assets/capsule/pending-sticker-55.png';
const _capsuleAssetPendingSticker56 = 'assets/capsule/pending-sticker-56.png';
const _capsuleAssetPendingSticker58 = 'assets/capsule/pending-sticker-58.png';
const _capsuleAssetPendingSticker59 = 'assets/capsule/pending-sticker-59.png';
const _capsuleAssetPendingSticker64 = 'assets/capsule/pending-sticker-64.png';
const _capsuleAssetPendingSticker65 = 'assets/capsule/pending-sticker-65.png';

// Design tokens shared by the capsule home / opened screens. Coordinates in
// those widgets are expressed against the 390x844 reference canvas.
const _capsuleDesignWidth = 390.0;
const _capsuleOrange = Color(0xFFFE9631);
const _capsuleHairline = Color(0xFFF6F5F5);
// One destructive / attention red for the whole feature: delete actions, error
// copy, the record-active glyph and the shortcut count badge all share it, so a
// single token replaces the old #E05555 / #E95656 / #FF6265 trio.
const _capsuleDanger = Color(0xFFE05555);
const _capsuleInk = Color(0xFF333333);
const _capsuleGlassShadow = BoxShadow(
  color: Color(0x40FFDCB0),
  blurRadius: 16,
  offset: Offset(0, 8),
);
const _capsuleOrangeShadow = BoxShadow(
  color: Color(0x40FE9631),
  blurRadius: 4,
  offset: Offset(0, 4),
);

class CapsulePage extends StatefulWidget {
  const CapsulePage({super.key, required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<CapsulePage> createState() => _CapsulePageState();
}

class _CapsulePageState extends State<CapsulePage> {
  late Future<List<TimeCapsule>> _capsules;
  List<TimeCapsule>? _cachedCapsules;

  @override
  void initState() {
    super.initState();
    _capsules = _loadAndCache();
  }

  Future<List<TimeCapsule>> _load() {
    return widget.api.listTimeCapsules();
  }

  Future<List<TimeCapsule>> _loadAndCache() async {
    final items = await _load();
    if (mounted) _cachedCapsules = items;
    return items;
  }

  void _refresh() {
    setState(() => _capsules = _loadAndCache());
  }

  Future<void> _reloadLatestCapsules() async {
    final future = _loadAndCache();
    setState(() {
      _capsules = future;
    });
    try {
      final items = await future;
      if (!mounted) return;
      setState(() {
        _cachedCapsules = items;
        _capsules = Future.value(items);
      });
    } catch (_) {
      // FutureBuilder renders the error state; no extra handling needed here.
    }
  }

  Future<void> _openEditor({TimeCapsule? draft}) async {
    final result = await CapsuleEditorPage.push(
      context,
      api: widget.api,
      session: widget.session,
      draft: draft,
    );
    if (!mounted) return;
    await _reloadLatestCapsules();
    if (!mounted || result is! _CapsuleEditorResult) return;
    if (!result.deleted && result.capsule.status == 'sealed') {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'capsule-sealed',
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, __, ___) =>
            _CapsuleSealedOverlay(capsule: result.capsule),
        transitionBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          );
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.55),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: _W2b.resolve(context).isDark
          ? _capsuleWarmBaseDark
          : _capsuleWarmBase,
      body: FutureBuilder<List<TimeCapsule>>(
        future: _capsules,
        builder: (context, snapshot) {
          final items =
              snapshot.data ?? _cachedCapsules ?? const <TimeCapsule>[];
          final hasCachedItems = _cachedCapsules != null;
          final drafts = items.where((item) => item.isDraft).toList();
          final pending = items.where((item) => item.isPending).toList();
          final opened = items.where((item) => item.isOpened).toList();
          final arrived = <TimeCapsule>[
            ...opened,
            ...items.where((item) => item.isReady),
          ];
          // "距上一个胶囊开启过去" tracks the last actual open, not the
          // scheduled unlock date.
          final newestOpened = opened.isEmpty
              ? null
              : opened.reduce((a, b) {
                  final aDate = a.openedAt ?? a.openDate ?? a.createdAt;
                  final bDate = b.openedAt ?? b.openDate ?? b.createdAt;
                  return aDate.isAfter(bDate) ? a : b;
                });
          return Stack(
            children: [
              // 暖光呼吸背景（与天气/商城同套分层玻璃，自带呼吸动画）。
              const Positioned.fill(child: _CapsuleBackground()),
              SafeArea(
                bottom: false,
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 34),
                  children: [
                    _CapsuleHomeHeader(
                      onBack: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(height: 18),
                    _CapsuleWriteEntryCard(onTap: () => _openEditor()),
                    const SizedBox(height: 14),
                    _CapsuleHomeShortcutGrid(
                      draftCount: drafts.length,
                      pendingCount: pending.length,
                      openedCount: arrived.length,
                      onDrafts: drafts.isEmpty
                          ? null
                          : () => _openDrafts(drafts),
                      onPending: pending.isEmpty
                          ? null
                          : () => _openPending(pending),
                      onOpened: arrived.isEmpty
                          ? null
                          : () => _openOpened(arrived),
                    ),
                    const SizedBox(height: 14),
                    _CapsuleLastOpenedCard(
                      newestOpened: newestOpened,
                      hasOpened: opened.isNotEmpty,
                    ),
                    if (snapshot.hasError && !hasCachedItems) ...[
                      const SizedBox(height: 14),
                      _CapsuleError(onRetry: _refresh),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openDrafts(List<TimeCapsule> drafts) async {
    if (drafts.isEmpty) return;
    final selected = await showModalBottomSheet<TimeCapsule>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (_) => _CapsuleDraftSheet(capsules: drafts),
    );
    if (!mounted) return;
    if (selected == null) {
      await _reloadLatestCapsules();
      return;
    }
    await _openEditor(draft: selected);
  }

  Future<Object?> _showDetail(TimeCapsule capsule) {
    return CapsuleEditorPage.push(
      context,
      api: widget.api,
      session: widget.session,
      draft: capsule,
      readOnly: true,
    );
  }

  Future<bool> _deleteOpenedCapsule(TimeCapsule capsule) async {
    final confirmed = await _confirmDeleteCapsule(context);
    if (confirmed != true || !mounted) return false;
    try {
      await widget.api.deleteTimeCapsule(capsule.id);
      if (!mounted) return true;
      await _reloadLatestCapsules();
      return true;
    } catch (error) {
      if (mounted) {
        await showCupertinoDialog<void>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('删除失败'),
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
      return false;
    }
  }

  Future<void> _openPending(List<TimeCapsule> pending) async {
    if (pending.isEmpty) return;
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => _PendingCapsuleScene(capsules: pending),
      ),
    );
    if (!mounted) return;
    await _reloadLatestCapsules();
  }

  Future<void> _openOpened(List<TimeCapsule> capsules) async {
    if (capsules.isEmpty) return;
    final result = await Navigator.of(context).push<Object?>(
      CupertinoPageRoute<Object?>(
        builder: (_) => _OpenedCapsulesPage(
          capsules: capsules,
          onOpen: (capsule) => widget.api.openTimeCapsule(capsule.id),
          onView: _showDetail,
          onDelete: _deleteOpenedCapsule,
        ),
      ),
    );
    if (!mounted) return;
    if (result is CapsuleChatDraft) {
      Navigator.of(context).pop(result);
      return;
    }
    await _reloadLatestCapsules();
  }
}
