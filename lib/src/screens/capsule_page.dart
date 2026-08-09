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
const _capsuleAssetBackChevron = 'assets/capsule/back-chevron.svg';
const _capsuleAssetDialogClose = 'assets/capsule/dialog-close.png';
const _capsuleAssetDraftIcon = 'assets/capsule/draft-icon.png';
const _capsuleAssetHomeHero = 'assets/capsule/home-hero.png';
const _capsuleAssetHomeStarLg = 'assets/capsule/home-star-lg.png';
const _capsuleAssetHomeStarSm = 'assets/capsule/home-star-sm.png';
const _capsuleAssetHomeUnderline = 'assets/capsule/home-underline.svg';
const _capsuleAssetLastOpened = 'assets/capsule/last-opened.png';
const _capsuleAssetOpenedCalendar = 'assets/capsule/opened-calendar.svg';
const _capsuleAssetOpenedIcon = 'assets/capsule/opened-icon.png';
const _capsuleAssetOpenedStar = 'assets/capsule/opened-star.svg';
const _capsuleAssetOpenedThumb = 'assets/capsule/opened-thumb.png';
const _capsuleAssetPendingBig = 'assets/capsule/pending-big.png';
const _capsuleAssetPendingIcon = 'assets/capsule/pending-icon.png';
const _capsuleAssetPendingShadowRing = 'assets/capsule/pending-shadow-ring.svg';
const _capsuleAssetWriteIcon = 'assets/capsule/write-icon.png';
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
const _capsuleGlassFill = Color(0x40FFFFFF);
const _capsuleBadgeRed = Color(0xFFFF6265);
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
      backgroundColor: Colors.white,
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
          return SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Design y=55..202: back button, hero bottle, greeting, squiggle.
                SliverToBoxAdapter(
                  child: _CapsuleHomeHeader(
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                ),
                // Design y=211, 348x96 centered.
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(21, 0, 21, 0),
                    child: _CapsuleWriteEntryCard(onTap: () => _openEditor()),
                  ),
                ),
                // Design y=351, three 86-high cards inset 24 with a 19 gutter.
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 44, 24, 0),
                    child: _CapsuleHomeShortcutGrid(
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
                  ),
                ),
                // Design y=492, 350x120 centered.
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 55, 20, bottom + 34),
                    child: _CapsuleLastOpenedCard(
                      newestOpened: newestOpened,
                      hasOpened: opened.isNotEmpty,
                    ),
                  ),
                ),
                if (snapshot.hasError && !hasCachedItems)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
                      child: _CapsuleError(onRetry: _refresh),
                    ),
                  ),
              ],
            ),
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

class CapsuleEditorPage extends StatefulWidget {
  const CapsuleEditorPage({
    super.key,
    required this.api,
    required this.session,
    this.draft,
    this.readOnly = false,
  });

  final CompanionApi api;
  final AuthSession session;
  final TimeCapsule? draft;
  final bool readOnly;

  /// The only supported way to open the editor.
  ///
  /// It finishes in three different shapes — a [_CapsuleEditorResult] when a
  /// capsule is saved or deleted, a [CapsuleChatDraft] when the reader hands it
  /// back to chat, or null when it is dismissed — so the route has to be able
  /// to carry all of them. Popping a result the route's type argument cannot
  /// hold throws inside the navigator's history flush, which both swallows the
  /// pop and leaves the navigator locked, so every later push and pop fails.
  static Future<Object?> push(
    BuildContext context, {
    required CompanionApi api,
    required AuthSession session,
    TimeCapsule? draft,
    bool readOnly = false,
  }) {
    return Navigator.of(context).push<Object?>(
      CupertinoPageRoute<Object?>(
        fullscreenDialog: true,
        builder: (_) => CapsuleEditorPage(
          api: api,
          session: session,
          draft: draft,
          readOnly: readOnly,
        ),
      ),
    );
  }

  @override
  State<CapsuleEditorPage> createState() => _CapsuleEditorPageState();
}

class _CapsuleEditorPageState extends State<CapsuleEditorPage> {
  static const _maxImageBytes = 10 * 1024 * 1024;
  static const _maxVoiceSeconds = 20;
  static const _maxVoiceBytes = 512 * 1024;

  late final TextEditingController _controller;
  final _imagePicker = ImagePicker();
  final _recorder = AudioRecorder();
  AudioPlayer? _audioPlayer;
  DateTime? _openDate;
  String _skin = '';
  _CapsuleImageAttachment? _image;
  _CapsuleVoiceAttachment? _voice;
  late String _initialContent;
  late String _initialSkin;
  late DateTime? _initialOpenDate;
  late String _initialMediaKey;
  bool _voicePlaying = false;
  Timer? _recordTimer;
  bool _recording = false;
  int _recordSeconds = 0;
  bool _saving = false;
  String? _savingStatus;
  String? _savingMessage;
  String? _error;
  bool _skinInitialized = false;
  bool _skinManuallySelected = false;
  bool _routeSettled = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.draft?.content ?? '');
    _openDate = widget.draft?.openDate;
    _skin = widget.draft?.skin ?? '';
    _restoreMedia(widget.draft?.media);
    _initialContent = widget.draft?.content.trim() ?? '';
    _initialOpenDate = _openDate;
    _initialMediaKey = _mediaKey(_mediaPayload());
    unawaited(_loadDraftDetailMedia());
    unawaited(_markRouteSettled());
  }

  Future<void> _markRouteSettled() async {
    await _waitForNavigatorUnlock(delay: const Duration(milliseconds: 340));
    if (!mounted) return;
    setState(() => _routeSettled = true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final initialSkin = _initialSkinForContext(context);
    if (!_skinInitialized) {
      _skin = initialSkin;
      _initialSkin = _skin;
      _skinInitialized = true;
      return;
    }
    if ((widget.draft == null || widget.readOnly) &&
        !_skinManuallySelected &&
        _skin != initialSkin) {
      _skin = initialSkin;
      _initialSkin = _skin;
    }
  }

  String _initialSkinForContext(BuildContext context) {
    return _effectiveCapsuleSkinId(
      context,
      widget.draft?.skin,
      useThemeDefaultForPaper: widget.readOnly,
    );
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    unawaited(_recorder.dispose());
    final audioPlayer = _audioPlayer;
    if (audioPlayer != null) {
      unawaited(audioPlayer.dispose());
    }
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadDraftDetailMedia() async {
    final draft = widget.draft;
    if (draft == null || draft.media != null) return;
    try {
      final detail = await widget.api.getTimeCapsule(draft.id);
      if (!mounted || _saving) return;
      if (_mediaKey(_mediaPayload()) != _initialMediaKey) return;
      setState(() {
        _restoreMedia(detail.media);
        _initialMediaKey = _mediaKey(_mediaPayload());
      });
    } catch (error) {
      debugPrint('[capsule.detail] failed: $error');
    }
  }

  void _restoreMedia(Map<String, dynamic>? media) {
    if (media == null) return;
    final images = media['images'];
    if (images is List && images.isNotEmpty && images.first is Map) {
      final raw = Map<String, dynamic>.from(images.first as Map);
      final base64Value = _normalizeBase64(raw['base64']);
      if (base64Value.isNotEmpty) {
        try {
          final bytes = base64Decode(base64Value);
          _image = _CapsuleImageAttachment(
            name: raw['name']?.toString() ?? 'capsule-image',
            mime: raw['mime']?.toString() ?? 'image/jpeg',
            size: (raw['size'] as num?)?.round() ?? bytes.length,
            base64Data: base64Value,
            bytes: bytes,
            storageKey: raw['storage_key']?.toString(),
            url: raw['url']?.toString(),
          );
        } catch (_) {
          _image = null;
        }
      }
    }
    final audio = media['audio'];
    if (audio is Map) {
      final raw = Map<String, dynamic>.from(audio);
      final base64Value = _normalizeBase64(raw['base64']);
      if (base64Value.isNotEmpty) {
        _voice = _CapsuleVoiceAttachment(
          name: raw['name']?.toString() ?? 'capsule-voice.m4a',
          mime: raw['mime']?.toString() ?? 'audio/mp4',
          size: (raw['size'] as num?)?.round() ?? 0,
          durationSeconds: (raw['duration_seconds'] as num?)?.round() ?? 1,
          base64Data: base64Value,
          storageKey: raw['storage_key']?.toString(),
          url: raw['url']?.toString(),
        );
      }
    }
  }

  String _normalizeBase64(Object? value) {
    final raw = value?.toString().trim() ?? '';
    final comma = raw.indexOf(',');
    return comma >= 0 ? raw.substring(comma + 1) : raw;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final latest = DateTime(now.year + 20, 12, 31);
    var selected = _openDate ?? today;
    // A capsule can only be scheduled for today or later, so a draft that has
    // gone stale must not seed the wheel outside its own bounds.
    if (selected.isBefore(today)) selected = today;
    if (selected.isAfter(latest)) selected = latest;
    final skin = _CapsuleSkin.byId(_skin);
    final isDark = AppColors.isDark(context);
    final sheetColor = isDark ? skin.paper : skin.page;
    final pickerSurface = isDark
        ? Color.lerp(skin.paper, Colors.white, 0.03)!
        : skin.paper;
    final overlayColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    await showCupertinoModalPopup<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: isDark ? 0.58 : 0.26),
      builder: (context) {
        final bottom = MediaQuery.paddingOf(context).bottom;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: sheetColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border(
              top: BorderSide(color: skin.line.withValues(alpha: 0.38)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.44 : 0.10),
                blurRadius: 28,
                offset: const Offset(0, -12),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, bottom + 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _SheetGrabber(),
                  Row(
                    children: [
                      Text(
                        '开启日期',
                        style: TextStyle(
                          color: skin.text,
                          fontSize: 18,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const Spacer(),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        borderRadius: BorderRadius.circular(999),
                        color: skin.accent.withValues(
                          alpha: isDark ? 0.18 : 0.12,
                        ),
                        onPressed: () {
                          setState(() => _openDate = selected);
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          '确定',
                          style: TextStyle(
                            color: skin.accent,
                            fontSize: 15,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: ColoredBox(
                      color: pickerSurface,
                      child: SizedBox(
                        height: 238,
                        child: _CapsuleDateWheels(
                          initial: selected,
                          first: today,
                          last: latest,
                          overlayColor: overlayColor,
                          textStyle: TextStyle(
                            color: skin.text,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                          onChanged: (value) => selected = value,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _save(String status) async {
    final content = _controller.text.trim();
    if (content.isEmpty) {
      setState(() => _error = '先写一点内容，再把它交给时间。');
      return;
    }
    if (status == 'sealed' && _openDate == null) {
      await _pickDate();
      if (_openDate == null) return;
    }
    final agentId = widget.session.agentId;
    setState(() {
      _saving = true;
      _savingStatus = status;
      _savingMessage = status == 'sealed' ? '准备封存' : '准备保存';
      _error = null;
    });
    try {
      final existing = widget.draft;
      final TimeCapsule saved;
      if (existing == null) {
        final mediaForSave = await _prepareMediaForSave();
        _logSavePlan(
          action: 'create',
          status: status,
          mediaAction: mediaForSave == null ? 'none' : 'reference',
          requestFields: const [
            'content',
            'status',
            'open_date',
            'skin',
            'media',
          ],
        );
        _setSavingMessage('保存文字');
        saved = await widget.api.createTimeCapsule(
          agentId: agentId,
          workspaceId: widget.session.workspaceId,
          content: content,
          status: status,
          openDate: _openDate,
          media: mediaForSave,
          skin: _skin,
        );
      } else {
        var currentMedia = _mediaPayload();
        final mediaChanged = _mediaKey(currentMedia) != _initialMediaKey;
        final contentChanged = content != _initialContent;
        final skinChanged = _skin != _initialSkin;
        final openDateChanged = !_sameDay(_openDate, _initialOpenDate);
        final statusChanged = status != existing.status;
        final requestFields = <String>[
          if (contentChanged) 'content',
          if (statusChanged) 'status',
          if (openDateChanged) 'open_date',
          if (skinChanged) 'skin',
          if (mediaChanged) 'media',
        ];
        if (requestFields.isEmpty) {
          debugPrint('[capsule.save] no changes; skip network update');
          if (mounted) {
            Navigator.of(context).pop(_CapsuleEditorResult.saved(existing));
          }
          return;
        }
        if (mediaChanged && currentMedia != null) {
          currentMedia = await _prepareMediaForSave();
        }
        final mediaAction = !mediaChanged
            ? 'skip'
            : currentMedia == null
            ? 'clear'
            : 'reference';
        _logSavePlan(
          action: 'update',
          status: status,
          mediaAction: mediaAction,
          requestFields: requestFields,
        );
        _setSavingMessage(
          mediaAction == 'reference'
              ? '保存附件'
              : statusChanged
              ? '更新状态'
              : '保存修改',
        );
        saved = await widget.api.updateTimeCapsule(
          existing.id,
          content: contentChanged ? content : null,
          status: statusChanged ? status : null,
          openDate: openDateChanged ? _openDate : null,
          media: mediaChanged ? currentMedia : null,
          clearMedia: mediaChanged && currentMedia == null,
          skin: skinChanged ? _skin : null,
        );
      }
      _setSavingMessage('完成');
      if (mounted) Navigator.of(context).pop(_CapsuleEditorResult.saved(saved));
    } catch (error) {
      if (mounted) setState(() => _error = _asMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _savingStatus = null;
          _savingMessage = null;
        });
      }
    }
  }

  Future<void> _deleteCapsule() async {
    final draft = widget.draft;
    if (draft == null || _saving || !_routeSettled) return;
    bool? confirmed;
    try {
      await _waitForNavigatorUnlock();
      if (!mounted) return;
      confirmed = await _confirmDeleteCapsule(context);
    } catch (error) {
      if (mounted) setState(() => _error = _asMessage(error));
      return;
    }
    if (confirmed != true || !mounted) return;
    setState(() {
      _saving = true;
      _savingStatus = 'delete';
      _error = null;
    });
    try {
      await widget.api.deleteTimeCapsule(draft.id);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _asMessage(error);
          _saving = false;
          _savingStatus = null;
        });
      }
      return;
    }
    // Past this point the capsule is gone on the server, so nothing here may
    // surface as a retryable "删除失败" — a second attempt would only come back
    // as "Capsule not found".
    if (mounted) {
      await _waitForNavigatorUnlock(delay: Duration.zero);
    }
    if (mounted) {
      Navigator.of(context).pop(_CapsuleEditorResult.deleted(draft));
    }
  }

  Future<void> _closeEditor([Object? result]) async {
    if (_saving || !_routeSettled) return;
    await _waitForNavigatorUnlock(delay: Duration.zero);
    if (!mounted) return;
    if (result == null) {
      await Navigator.of(context).maybePop();
    } else {
      Navigator.of(context).pop(result);
    }
  }

  Map<String, dynamic>? _mediaPayload() {
    if (_image == null && _voice == null) return null;
    return {
      'images': [if (_image != null) _image!.toJson()],
      if (_voice != null) 'audio': _voice!.toJson(),
    };
  }

  Future<Map<String, dynamic>?> _prepareMediaForSave() async {
    if (_image == null && _voice == null) return null;
    if (_image != null && _image!.storageKey == null) {
      _setSavingMessage('上传图片');
      final uploaded = await widget.api.uploadTimeCapsuleMedia(
        kind: 'image',
        name: _image!.name,
        mime: _image!.mime,
        size: _image!.size,
        base64Data: _image!.base64Data,
      );
      _image = _image!.withRemote(uploaded);
    }
    if (_voice != null && _voice!.storageKey == null) {
      _setSavingMessage('上传语音');
      final uploaded = await widget.api.uploadTimeCapsuleMedia(
        kind: 'audio',
        name: _voice!.name,
        mime: _voice!.mime,
        size: _voice!.size,
        durationSeconds: _voice!.durationSeconds,
        base64Data: _voice!.base64Data,
      );
      _voice = _voice!.withRemote(uploaded);
    }
    if (mounted) setState(() {});
    return _mediaPayload();
  }

  String _mediaKey(Map<String, dynamic>? media) =>
      media == null ? 'null' : jsonEncode(media);

  bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _setSavingMessage(String message) {
    if (!mounted) return;
    setState(() => _savingMessage = message);
  }

  void _logSavePlan({
    required String action,
    required String status,
    required String mediaAction,
    required List<String> requestFields,
  }) {
    final media = _mediaPayload();
    final payloadBytes = media == null
        ? 0
        : utf8.encode(jsonEncode(media)).length;
    debugPrint(
      '[capsule.save] action=$action status=$status fields=${requestFields.join(',')} mediaAction=$mediaAction mediaBytes=$payloadBytes image=${_image?.size ?? 0} audio=${_voice?.size ?? 0}',
    );
  }

  void _appendEmoji(String emoji) {
    final text = _controller.text;
    final selection = _controller.selection;
    final index = selection.isValid ? selection.start : text.length;
    final updated = text.replaceRange(index, index, emoji);
    _controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: index + emoji.length),
    );
  }

  Future<void> _openEmojiSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (_) => MediaQuery(
        data: MediaQuery.of(context),
        child: DefaultTextStyle(
          style: TextStyle(
            color: AppColors.text,
            decoration: TextDecoration.none,
          ),
          child: Container(
            height: 270,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const _SheetGrabber(),
                  Expanded(
                    child: _EmojiPanel(onEmojiTap: _appendEmoji, compact: true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 82,
        requestFullMetadata: false,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.length > _maxImageBytes) {
        setState(() => _error = '图片需要小于 10MB。');
        return;
      }
      setState(() {
        _image = _CapsuleImageAttachment(
          name: picked.name,
          mime: picked.mimeType ?? 'image/jpeg',
          size: bytes.length,
          base64Data: base64Encode(bytes),
          bytes: bytes,
        );
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is MissingPluginException
            ? '图片功能需要完整重启 App 后才能使用。'
            : _asMessage(error);
      });
    }
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      await _stopRecord();
      return;
    }
    try {
      if (!await _recorder.hasPermission()) {
        setState(() => _error = '需要麦克风权限才能录音。');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/capsule_voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 32000,
          sampleRate: 16000,
          numChannels: 1,
          noiseSuppress: true,
        ),
        path: path,
      );
      setState(() {
        _recording = true;
        _recordSeconds = 0;
        _error = null;
      });
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
        if (!mounted) return;
        setState(() => _recordSeconds += 1);
        if (_recordSeconds >= _maxVoiceSeconds) {
          await _stopRecord();
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _recording = false;
        _error = error is MissingPluginException
            ? '语音功能需要完整重启 App 后才能使用。'
            : _asMessage(error);
      });
    }
  }

  Future<void> _stopRecord() async {
    _recordTimer?.cancel();
    _recordTimer = null;
    final duration = math.max(1, _recordSeconds);
    final String? path;
    try {
      path = await _recorder.stop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _recording = false;
        _error = error is MissingPluginException
            ? '语音功能需要完整重启 App 后才能使用。'
            : _asMessage(error);
      });
      return;
    }
    if (!mounted) return;
    setState(() => _recording = false);
    if (path == null) return;
    final file = File(path);
    final bytes = await file.readAsBytes();
    if (bytes.length > _maxVoiceBytes) {
      setState(() => _error = '语音文件太大，请重新录一段更短的。');
      return;
    }
    setState(() {
      _voice = _CapsuleVoiceAttachment(
        name: 'capsule-voice.m4a',
        mime: 'audio/mp4',
        size: bytes.length,
        durationSeconds: duration,
        base64Data: base64Encode(bytes),
      );
      _error = null;
    });
  }

  Future<void> _toggleVoicePlayback() async {
    final voice = _voice;
    if (voice == null) return;
    try {
      final player = _audioPlayer ?? AudioPlayer();
      if (_audioPlayer == null) {
        _audioPlayer = player;
        player.onPlayerComplete.listen((_) {
          if (mounted) setState(() => _voicePlaying = false);
        });
      }
      if (_voicePlaying) {
        await player.stop();
        if (mounted) setState(() => _voicePlaying = false);
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/capsule_preview_${voice.base64Data.hashCode}.m4a';
      final file = File(path);
      if (!await file.exists()) {
        await file.writeAsBytes(base64Decode(voice.base64Data));
      }
      await player.stop();
      await player.play(DeviceFileSource(path));
      if (mounted) setState(() => _voicePlaying = true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _voicePlaying = false;
        _error = error is MissingPluginException
            ? '语音播放需要完整重启 App 后才能使用。'
            : _asMessage(error);
      });
    }
  }

  Future<void> _openSkinSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (_) => _CapsuleSkinSheet(
        selected: _skin,
        onSelected: (value) {
          setState(() {
            _skin = value;
            _skinManuallySelected = true;
          });
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final skin = _CapsuleSkin.byId(_skin);
    final isReadOnly = widget.readOnly && widget.draft != null;
    return Scaffold(
      backgroundColor: skin.page,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
              child: Row(
                children: [
                  // The module's own circle buttons rather than the shared app
                  // one, which is tinted with the app accent and clashes here.
                  // Sized to whatever sits opposite it: the read-only header
                  // carries 44pt mini actions, the editor a 54pt button or the
                  // 54pt spacer standing in for one.
                  if (isReadOnly)
                    _CapsuleMiniActionButton(
                      icon: CupertinoIcons.xmark,
                      onTap: _saving || !_routeSettled
                          ? null
                          : () => unawaited(_closeEditor()),
                    )
                  else
                    _CapsuleCircleButton(
                      icon: CupertinoIcons.xmark,
                      onTap: _saving || !_routeSettled
                          ? null
                          : () => unawaited(_closeEditor()),
                    ),
                  Expanded(
                    child: Text(
                      widget.readOnly ? '胶囊详情' : '写新胶囊',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: skin.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (isReadOnly)
                    _ReadOnlyCapsuleActions(
                      deleting: _savingStatus == 'delete',
                      enabled: !_saving && _routeSettled,
                      onDelete: _deleteCapsule,
                      onSend: () => unawaited(
                        _closeEditor(_draftForCapsule(widget.draft!)),
                      ),
                    )
                  else if (widget.draft == null)
                    const SizedBox(width: 54)
                  else
                    _CapsuleCircleButton(
                      icon: CupertinoIcons.delete,
                      danger: true,
                      loading: _savingStatus == 'delete',
                      onTap: _saving || !_routeSettled ? null : _deleteCapsule,
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                child: _CapsuleLetterPaper(
                  skin: skin,
                  controller: _controller,
                  senderName: widget.session.userFacingName,
                  readOnly: widget.readOnly,
                ),
              ),
            ),
            _CapsuleAttachmentStrip(
              image: _image,
              voice: _voice,
              accent: skin.accent,
              voicePlaying: _voicePlaying,
              onOpenImage: _image == null
                  ? null
                  : () => Navigator.of(context).push<void>(
                      CupertinoPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => _CapsuleImageViewer(image: _image!),
                      ),
                    ),
              onRemoveImage: _saving || widget.readOnly
                  ? null
                  : () => setState(() => _image = null),
              onToggleVoice: _saving ? null : _toggleVoicePlayback,
              onRemoveVoice: _saving || widget.readOnly
                  ? null
                  : () async {
                      await _audioPlayer?.stop();
                      setState(() {
                        _voice = null;
                        _voicePlaying = false;
                      });
                    },
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFE05555),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(22, 12, 22, bottom + 18),
              child: widget.readOnly
                  ? _CapsuleDatePill(openDate: _openDate, onTap: null)
                  : Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 9,
                              child: _CapsuleEditorToolbar(
                                recording: _recording,
                                recordSeconds: _recordSeconds,
                                onPickImage: _saving ? null : _pickImage,
                                onToggleRecord: _saving ? null : _toggleRecord,
                                onPickSkin: _saving ? null : _openSkinSheet,
                                onEmoji: _saving ? null : _openEmojiSheet,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 7,
                              child: _CapsuleDatePill(
                                openDate: _openDate,
                                onTap: _saving ? null : _pickDate,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _CapsuleActionButton(
                                label: '存草稿',
                                filled: false,
                                enabled: !_saving,
                                loading: _savingStatus == 'draft',
                                loadingLabel: _savingStatus == 'draft'
                                    ? _savingMessage
                                    : null,
                                onTap: () => _save('draft'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _CapsuleActionButton(
                                label: '封存',
                                filled: true,
                                enabled: !_saving,
                                loading: _savingStatus == 'sealed',
                                loadingLabel: _savingStatus == 'sealed'
                                    ? _savingMessage
                                    : null,
                                onTap: () => _save('sealed'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapsuleImageAttachment {
  const _CapsuleImageAttachment({
    required this.name,
    required this.mime,
    required this.size,
    required this.base64Data,
    required this.bytes,
    this.storageKey,
    this.url,
  });

  final String name;
  final String mime;
  final int size;
  final String base64Data;
  final Uint8List bytes;
  final String? storageKey;
  final String? url;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'mime': mime,
      'size': size,
      if (storageKey != null) 'storage_key': storageKey,
      if (url != null) 'url': url,
      if (storageKey == null) 'base64': base64Data,
    };
  }

  _CapsuleImageAttachment withRemote(Map<String, dynamic> remote) {
    return _CapsuleImageAttachment(
      name: remote['name']?.toString() ?? name,
      mime: remote['mime']?.toString() ?? mime,
      size: (remote['size'] as num?)?.round() ?? size,
      base64Data: base64Data,
      bytes: bytes,
      storageKey: remote['storage_key']?.toString(),
      url: remote['url']?.toString(),
    );
  }
}

class _CapsuleVoiceAttachment {
  const _CapsuleVoiceAttachment({
    required this.name,
    required this.mime,
    required this.size,
    required this.durationSeconds,
    required this.base64Data,
    this.storageKey,
    this.url,
  });

  final String name;
  final String mime;
  final int size;
  final int durationSeconds;
  final String base64Data;
  final String? storageKey;
  final String? url;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'mime': mime,
      'size': size,
      'duration_seconds': durationSeconds,
      if (storageKey != null) 'storage_key': storageKey,
      if (url != null) 'url': url,
      if (storageKey == null) 'base64': base64Data,
    };
  }

  _CapsuleVoiceAttachment withRemote(Map<String, dynamic> remote) {
    return _CapsuleVoiceAttachment(
      name: remote['name']?.toString() ?? name,
      mime: remote['mime']?.toString() ?? mime,
      size: (remote['size'] as num?)?.round() ?? size,
      durationSeconds:
          (remote['duration_seconds'] as num?)?.round() ?? durationSeconds,
      base64Data: base64Data,
      storageKey: remote['storage_key']?.toString(),
      url: remote['url']?.toString(),
    );
  }
}

class _CapsuleSkin {
  const _CapsuleSkin({
    required this.id,
    required this.name,
    required this.page,
    required this.paper,
    required this.line,
    required this.text,
    required this.muted,
    required this.accent,
  });

  final String id;
  final String name;
  final Color page;
  final Color paper;
  final Color line;
  final Color text;
  final Color muted;
  final Color accent;

  static const all = [
    _CapsuleSkin(
      id: 'paper',
      name: '白色信纸',
      page: Color(0xFFF8F8F3),
      paper: Color(0xFFFFFEFA),
      line: Color(0xFFE6E1D5),
      text: Color(0xFF37342D),
      muted: Color(0xFF928D82),
      // Every other skin accents with its own palette; this default one used
      // to reach for the app-wide purple, which belongs to no capsule screen.
      accent: _capsuleOrange,
    ),
    _CapsuleSkin(
      id: 'warm',
      name: '暖光便签',
      page: Color(0xFFFBF2E5),
      paper: Color(0xFFFFF6E7),
      line: Color(0xFFEBD5B8),
      text: Color(0xFF4A3525),
      muted: Color(0xFFA27E5F),
      accent: Color(0xFFE48B3F),
    ),
    _CapsuleSkin(
      id: 'mint',
      name: '薄荷晨雾',
      page: Color(0xFFEFF8F4),
      paper: Color(0xFFF7FFFC),
      line: Color(0xFFD5E9E0),
      text: Color(0xFF2E4038),
      muted: Color(0xFF7E948A),
      accent: Color(0xFF19A983),
    ),
    _CapsuleSkin(
      id: 'night',
      name: '深夜蓝纸',
      page: Color(0xFF070D16),
      paper: Color(0xFF101A25),
      line: Color(0xFF5C6878),
      text: Color(0xFFF4F8FC),
      muted: Color(0xFF9FAEC0),
      accent: Color(0xFF4BA3FF),
    ),
    _CapsuleSkin(
      id: 'rose',
      name: '玫瑰信笺',
      page: Color(0xFFFFF1F4),
      paper: Color(0xFFFFF7F8),
      line: Color(0xFFEBCBD2),
      text: Color(0xFF51313A),
      muted: Color(0xFFA77D86),
      accent: Color(0xFFE06A8A),
    ),
    _CapsuleSkin(
      id: 'lavender',
      name: '薰衣草纸',
      page: Color(0xFFF4F1FF),
      paper: Color(0xFFFAF8FF),
      line: Color(0xFFDCD3F2),
      text: Color(0xFF39304D),
      muted: Color(0xFF9085AA),
      accent: Color(0xFF8E6BE8),
    ),
    _CapsuleSkin(
      id: 'sky',
      name: '晴空蓝笺',
      page: Color(0xFFEFF7FF),
      paper: Color(0xFFF8FCFF),
      line: Color(0xFFD1E4F3),
      text: Color(0xFF2C3D4D),
      muted: Color(0xFF7D95A8),
      accent: Color(0xFF3489D6),
    ),
    _CapsuleSkin(
      id: 'linen',
      name: '亚麻手札',
      page: Color(0xFFF4F0E8),
      paper: Color(0xFFFBF6EB),
      line: Color(0xFFE4D6BD),
      text: Color(0xFF46392B),
      muted: Color(0xFF9A8770),
      accent: Color(0xFFB98345),
    ),
  ];

  static _CapsuleSkin byId(String id) {
    return all.firstWhere((item) => item.id == id, orElse: () => all.first);
  }
}

class _CapsuleLetterPaper extends StatelessWidget {
  const _CapsuleLetterPaper({
    required this.skin,
    required this.controller,
    required this.senderName,
    this.readOnly = false,
  });

  final _CapsuleSkin skin;
  final TextEditingController controller;
  final String senderName;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: skin.paper,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A5568).withValues(alpha: 0.10),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final senderTop = _LetterLinePainter.senderTopForHeight(
              constraints.maxHeight,
              fontSize: 14,
              lineHeight: 1.76,
            );
            return CustomPaint(
              painter: _LetterLinePainter(lineColor: skin.line),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 86),
                      child: TextField(
                        controller: controller,
                        readOnly: readOnly,
                        showCursor: !readOnly,
                        expands: true,
                        minLines: null,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        cursorHeight: 23,
                        cursorColor: skin.accent,
                        style: TextStyle(
                          color: skin.text,
                          fontSize: 17,
                          height: 1.76,
                        ),
                        decoration: InputDecoration(
                          hintText: '我想对未来的我说...',
                          hintStyle: TextStyle(
                            color: skin.muted.withValues(alpha: 0.72),
                            fontSize: 17,
                            height: 1.76,
                          ),
                          filled: false,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: senderTop,
                    right: 20,
                    child: Text(
                      '寄信人：$senderName',
                      style: TextStyle(
                        color: skin.muted,
                        fontSize: 14,
                        height: 1.76,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LetterLinePainter extends CustomPainter {
  const _LetterLinePainter({required this.lineColor});

  static const startY = 50.0;
  static const gap = 30.0;
  static const bottomInset = 24.0;
  static const horizontalInset = 18.0;

  final Color lineColor;

  static double senderTopForHeight(
    double height, {
    required double fontSize,
    required double lineHeight,
  }) {
    final textHeight = fontSize * lineHeight;
    final lastLine =
        startY + ((height - bottomInset - startY) / gap).floor() * gap;
    final previousLine = math.max(startY, lastLine - gap);
    return previousLine + ((lastLine - previousLine - textHeight) / 2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor.withValues(alpha: 0.70)
      ..strokeWidth = 1;
    for (var y = startY; y < size.height - bottomInset; y += gap) {
      canvas.drawLine(
        Offset(horizontalInset, y),
        Offset(size.width - horizontalInset, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LetterLinePainter oldDelegate) {
    return oldDelegate.lineColor != lineColor;
  }
}

class _CapsuleAttachmentStrip extends StatelessWidget {
  const _CapsuleAttachmentStrip({
    required this.image,
    required this.voice,
    required this.accent,
    required this.voicePlaying,
    required this.onOpenImage,
    required this.onRemoveImage,
    required this.onToggleVoice,
    required this.onRemoveVoice,
  });

  final _CapsuleImageAttachment? image;
  final _CapsuleVoiceAttachment? voice;
  final Color accent;
  final bool voicePlaying;
  final VoidCallback? onOpenImage;
  final VoidCallback? onRemoveImage;
  final VoidCallback? onToggleVoice;
  final VoidCallback? onRemoveVoice;

  @override
  Widget build(BuildContext context) {
    if (image == null && voice == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          height: 66,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface(context, light: 0.76),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.glassBorder(context), width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withValues(
                  alpha: AppColors.isDark(context) ? 0.42 : 0.06,
                ),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (image != null) ...[
                _CapsuleImageThumb(
                  image: image!,
                  onTap: onOpenImage,
                  onRemove: onRemoveImage,
                ),
                if (voice != null) const SizedBox(width: 8),
              ],
              if (voice != null)
                _CapsuleVoiceChip(
                  voice: voice!,
                  accent: accent,
                  playing: voicePlaying,
                  compact: image != null,
                  onTap: onToggleVoice,
                  onRemove: onRemoveVoice,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapsuleImageThumb extends StatelessWidget {
  const _CapsuleImageThumb({
    required this.image,
    required this.onTap,
    required this.onRemove,
  });

  final _CapsuleImageAttachment image;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 54,
      child: Stack(
        children: [
          Positioned.fill(
            child: CupertinoButton(
              minimumSize: Size.zero,
              padding: EdgeInsets.zero,
              onPressed: onTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(
                      image.bytes,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.82),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (onRemove != null)
            Positioned(
              right: 3,
              top: 3,
              child: _CapsuleAttachmentCloseButton(
                onTap: onRemove!,
                elevated: true,
              ),
            ),
        ],
      ),
    );
  }
}

class _CapsuleVoiceChip extends StatelessWidget {
  const _CapsuleVoiceChip({
    required this.voice,
    required this.accent,
    required this.playing,
    required this.compact,
    required this.onTap,
    required this.onRemove,
  });

  final _CapsuleVoiceAttachment voice;
  final Color accent;
  final bool playing;
  final bool compact;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 202 : 238,
      height: 54,
      child: CupertinoButton(
        minimumSize: Size.zero,
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 0, 8, 0),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.075),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  playing ? CupertinoIcons.pause_fill : CupertinoIcons.waveform,
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '语音留言',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${voice.durationSeconds} 秒',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.muted.withValues(alpha: 0.78),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (onRemove != null) ...[
                const SizedBox(width: 6),
                _CapsuleAttachmentCloseButton(onTap: onRemove!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CapsuleAttachmentCloseButton extends StatelessWidget {
  const _CapsuleAttachmentCloseButton({
    required this.onTap,
    this.elevated = false,
  });

  final VoidCallback onTap;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 24,
        height: 24,
        child: Center(
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: elevated
                  ? Colors.black.withValues(alpha: 0.42)
                  : const Color(0xFF8A8790).withValues(alpha: 0.28),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              CupertinoIcons.xmark,
              color: elevated ? Colors.white : const Color(0xFF615D68),
              size: 10.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _CapsuleImageViewer extends StatelessWidget {
  const _CapsuleImageViewer({required this.image});

  final _CapsuleImageAttachment image;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 18, 0),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.chevron_left,
                        color: Colors.white,
                        size: 23,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '胶囊图片',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        Text(
                          image.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.56),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Center(
                  child: Image.memory(image.bytes, fit: BoxFit.contain),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.72),
                  ],
                ),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 54,
                    height: 68,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.memory(image.bytes, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapsuleDatePill extends StatelessWidget {
  const _CapsuleDatePill({required this.openDate, required this.onTap});

  final DateTime? openDate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.elevatedSurface(context, light: 0.88),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.glassBorder(context)),
        ),
        child: Row(
          children: [
            const Icon(
              CupertinoIcons.calendar,
              color: _capsuleOrange,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                openDate == null ? '开启日期' : _formatCapsuleShortDate(openDate!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(CupertinoIcons.chevron_down, color: AppColors.muted, size: 16),
          ],
        ),
      ),
    );
  }
}

class _CapsuleEditorToolbar extends StatelessWidget {
  const _CapsuleEditorToolbar({
    required this.recording,
    required this.recordSeconds,
    required this.onPickImage,
    required this.onToggleRecord,
    required this.onPickSkin,
    required this.onEmoji,
  });

  final bool recording;
  final int recordSeconds;
  final VoidCallback? onPickImage;
  final VoidCallback? onToggleRecord;
  final VoidCallback? onPickSkin;
  final VoidCallback? onEmoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface(context, light: 0.86),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder(context)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _CapsuleToolButton(icon: CupertinoIcons.camera, onTap: onPickImage),
          _CapsuleToolButton(
            icon: recording ? CupertinoIcons.stop_circle : CupertinoIcons.mic,
            active: recording,
            label: recording ? '${math.max(1, recordSeconds)}s' : null,
            onTap: onToggleRecord,
          ),
          _CapsuleToolButton(
            customIcon: const _CapsuleSkinIcon(),
            onTap: onPickSkin,
          ),
          _CapsuleToolButton(icon: CupertinoIcons.smiley, onTap: onEmoji),
        ],
      ),
    );
  }
}

class _CapsuleToolButton extends StatelessWidget {
  const _CapsuleToolButton({
    required this.onTap,
    this.icon,
    this.customIcon,
    this.active = false,
    this.label,
  });

  final IconData? icon;
  final Widget? customIcon;
  final VoidCallback? onTap;
  final bool active;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: SizedBox(
        width: 42,
        height: 42,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            customIcon ??
                Icon(
                  icon,
                  color: active ? const Color(0xFFE05555) : AppColors.text,
                  size: 26,
                ),
            if (label != null)
              Text(
                label!,
                style: const TextStyle(
                  color: Color(0xFFE05555),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CapsuleSkinIcon extends StatelessWidget {
  const _CapsuleSkinIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 27,
      height: 27,
      child: CustomPaint(painter: _CapsuleSkinIconPainter()),
    );
  }
}

class _CapsuleSkinIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = AppColors.text
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = Colors.transparent
      ..style = PaintingStyle.fill;

    final page = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.24,
        size.height * 0.18,
        size.width * 0.52,
        size.height * 0.64,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(page, fill);
    canvas.drawRRect(page, stroke);

    final fold = Path()
      ..moveTo(size.width * 0.61, size.height * 0.18)
      ..lineTo(size.width * 0.76, size.height * 0.33)
      ..lineTo(size.width * 0.61, size.height * 0.33)
      ..close();
    canvas.drawPath(fold, stroke);

    canvas.drawLine(
      Offset(size.width * 0.34, size.height * 0.47),
      Offset(size.width * 0.66, size.height * 0.47),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width * 0.34, size.height * 0.60),
      Offset(size.width * 0.58, size.height * 0.60),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SheetGrabber extends StatelessWidget {
  // The default grey rides on the editor sheets, which follow the agent skin
  // and can be dark. Only the warm capsule sheets pass a colour.
  const _SheetGrabber({this.color = const Color(0xFFD8DCE0)});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Center(
        child: Container(
          width: 42,
          height: 5,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _CapsuleSkinSheet extends StatelessWidget {
  const _CapsuleSkinSheet({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.66,
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.page,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: DefaultTextStyle(
          style: TextStyle(
            color: AppColors.text,
            decoration: TextDecoration.none,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetGrabber(),
              Text(
                '选择信纸皮肤',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: GridView.builder(
                  itemCount: _CapsuleSkin.all.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.9,
                  ),
                  itemBuilder: (context, index) {
                    final skin = _CapsuleSkin.all[index];
                    final isSelected = skin.id == selected;
                    return CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => onSelected(skin.id),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: skin.paper,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected ? skin.accent : Colors.white,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              skin.name,
                              style: TextStyle(
                                color: skin.text,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const Spacer(),
                            Container(height: 1, color: skin.line),
                            const SizedBox(height: 8),
                            Container(width: 60, height: 1, color: skin.line),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapsuleSendChatButton extends StatelessWidget {
  const _CapsuleSendChatButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF101922),
          borderRadius: BorderRadius.circular(22),
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
              fontSize: 15,
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
        _CapsuleMiniActionButton(
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

class _CapsuleMiniActionButton extends StatelessWidget {
  const _CapsuleMiniActionButton({
    required this.icon,
    required this.onTap,
    this.danger = false,
    this.loading = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool danger;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: onTap == null && !loading ? 0.5 : 1,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface(context, light: 0.88),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.glassBorder(context)),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withValues(
                  alpha: AppColors.isDark(context) ? 0.42 : 0.10,
                ),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFE05555),
                    ),
                  ),
                )
              : Icon(
                  icon,
                  color: danger ? const Color(0xFFE05555) : AppColors.text,
                  size: 21,
                ),
        ),
      ),
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

/// Design y=55..211 of the home screen: back button, hero bottle, greeting and
/// the hand-drawn squiggle. Laid out with absolute offsets scaled off the 390pt
/// reference width so the bottle keeps overlapping the greeting on any device.
class _CapsuleHomeHeader extends StatelessWidget {
  const _CapsuleHomeHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    // Scale off the width we were actually given rather than the screen: the
    // two agree on phones, and only the local width keeps the absolute design
    // coordinates inside the box we occupy.
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / _capsuleDesignWidth;
        double x(double value) => value * scale;
        // Design coordinates are absolute; the status bar (47pt) is already
        // consumed by the enclosing SafeArea.
        const statusBar = 47.0;
        return SizedBox(
          height: x(211 - statusBar),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: x(194),
                top: x(58 - statusBar),
                width: x(178),
                height: x(144),
                child: Image.asset(_capsuleAssetHomeHero, fit: BoxFit.contain),
              ),
              Positioned(
                left: x(20),
                top: x(55 - statusBar),
                child: _CapsuleWarmBackButton(onTap: onBack, light: true),
              ),
              Positioned(
                left: x(56),
                top: x(108 - statusBar),
                child: Text(
                  'Hi，未来的自己',
                  style: TextStyle(
                    color: _capsuleOrange,
                    fontSize: x(24),
                    height: 29 / 24,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              Positioned(
                left: x(117),
                top: x(154 - statusBar),
                child: SvgPicture.asset(
                  _capsuleAssetHomeUnderline,
                  width: x(76),
                  height: x(13.91),
                  fit: BoxFit.fill,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Design "Rectangle 282" — 348x96 translucent orange card.
class _CapsuleWriteEntryCard extends StatelessWidget {
  const _CapsuleWriteEntryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        height: 96,
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              _capsuleOrange.withValues(alpha: 0.40),
              _capsuleOrange.withValues(alpha: 0.25),
            ],
          ),
          border: Border.all(color: _capsuleHairline.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [_capsuleGlassShadow],
        ),
        child: Row(
          children: [
            const _CapsuleIconMedallion(
              diameter: 55.43,
              asset: _capsuleAssetWriteIcon,
              iconSize: 24,
              bordered: true,
            ),
            const SizedBox(width: 18),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '写新胶囊',
                    style: TextStyle(
                      color: _capsuleInk,
                      fontSize: 20,
                      height: 24 / 20,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '写一封信给未来的自己',
                    style: TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 12,
                      height: 14 / 12,
                      fontWeight: FontWeight.w400,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Solid orange circle holding a white line icon — the design reuses this for
/// the write card and for every shortcut card.
class _CapsuleIconMedallion extends StatelessWidget {
  const _CapsuleIconMedallion({
    required this.diameter,
    required this.asset,
    required this.iconSize,
    this.opacity = 1,
    this.bordered = false,
  });

  final double diameter;
  final String asset;
  final double iconSize;
  final double opacity;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: _capsuleOrange.withValues(alpha: opacity),
        shape: BoxShape.circle,
        border: bordered
            ? Border.all(color: _capsuleHairline.withValues(alpha: 0.5))
            : null,
        boxShadow: const [_capsuleOrangeShadow],
      ),
      alignment: Alignment.center,
      child: Image.asset(asset, height: iconSize, fit: BoxFit.contain),
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
            icon: _capsuleAssetDraftIcon,
            onTap: onDrafts,
          ),
        ),
        const SizedBox(width: 19),
        Expanded(
          child: _CapsuleHomeShortcutCard(
            label: '待解封',
            count: pendingCount,
            icon: _capsuleAssetPendingIcon,
            onTap: onPending,
          ),
        ),
        const SizedBox(width: 19),
        Expanded(
          child: _CapsuleHomeShortcutCard(
            label: '已解封',
            count: openedCount,
            icon: _capsuleAssetOpenedIcon,
            onTap: onOpened,
          ),
        ),
      ],
    );
  }
}

/// Design "Rectangle 206/207" — 86-high glass card with an orange medallion,
/// a label and a red count badge. The empty variant dims the medallion and the
/// label and drops the badge.
class _CapsuleHomeShortcutCard extends StatelessWidget {
  const _CapsuleHomeShortcutCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final int count;
  final String icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        height: 86,
        decoration: BoxDecoration(
          color: _capsuleGlassFill,
          border: Border.all(color: _capsuleHairline),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [_capsuleGlassShadow],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Center(
                child: _CapsuleIconMedallion(
                  diameter: 48,
                  asset: icon,
                  iconSize: 24,
                  opacity: enabled ? 1 : 0.5,
                ),
              ),
            ),
            Positioned(
              top: 63,
              left: 0,
              right: 0,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _capsuleInk.withValues(alpha: enabled ? 1 : 0.5),
                  fontSize: 14,
                  height: 17 / 14,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            if (count > 0)
              Positioned(top: 5, right: 6, child: _CapsuleCountBadge(count)),
          ],
        ),
      ),
    );
  }
}

/// Design "Frame 331" — 16-high red pill. Counts above 99 collapse to "99+" so
/// the pill cannot outgrow the card corner it sits on.
class _CapsuleCountBadge extends StatelessWidget {
  const _CapsuleCountBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: _capsuleBadgeRed,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          height: 12 / 10,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.none,
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
      decoration: BoxDecoration(
        color: _capsuleGlassFill,
        border: Border.all(color: _capsuleHairline),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [_capsuleGlassShadow],
      ),
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

/// A draft row inside [_CapsuleDraftSheet]. Deliberately shares the white card
/// language of [_OpenedCapsuleSheetTile] — hairline border, radius 20, ink
/// title over a 10pt grey meta line — at a shorter 80pt height, so the drafts
/// read as the same family of list rows one screen earlier.
class _CapsuleDraftTile extends StatelessWidget {
  const _CapsuleDraftTile({required this.capsule, required this.onTap});

  final TimeCapsule capsule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _capsuleHairline),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [_capsuleGlassShadow],
        ),
        child: Row(
          children: [
            // Same 48/24 medallion as the 草稿 shortcut card on the home
            // screen, so the sheet looks like it grew out of the tapped card.
            const _CapsuleIconMedallion(
              diameter: 48,
              asset: _capsuleAssetDraftIcon,
              iconSize: 24,
              bordered: true,
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
                    style: const TextStyle(
                      color: _capsuleInk,
                      fontSize: 14,
                      height: 17 / 14,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      SvgPicture.asset(
                        _capsuleAssetOpenedCalendar,
                        width: 10,
                        height: 10,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF666666),
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
            const Icon(
              CupertinoIcons.chevron_forward,
              size: 16,
              color: Color(0xFFCFCFCF),
            ),
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
        color: const Color(0xFFE95656),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE95656).withValues(alpha: 0.22),
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

class _PendingCapsuleScene extends StatefulWidget {
  const _PendingCapsuleScene({required this.capsules});

  final List<TimeCapsule> capsules;

  @override
  State<_PendingCapsuleScene> createState() => _PendingCapsuleSceneState();
}

class _PendingCapsuleSceneState extends State<_PendingCapsuleScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final safeTop = MediaQuery.paddingOf(context).top;
    final sx = size.width / 390;
    final sy = size.height / 844;
    double x(double value) => value * sx;
    double y(double value) => value * sy;
    final first = widget.capsules.first;
    final dateText = first.openDate == null
        ? '未知'
        : _formatCapsuleShortDate(first.openDate!);
    return Material(
      color: const Color(0xFFEB772A),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final breath = Curves.easeInOut.transform(_controller.value);
          Widget sticker(
            String asset, {
            required double left,
            required double top,
            required double width,
            required double height,
            double rotate = 0,
            double dx = 0,
            double dy = 0,
          }) {
            return Positioned(
              left: x(left),
              top: y(top),
              width: x(width),
              height: y(height),
              child: Transform.translate(
                offset: Offset(dx * breath, dy * breath),
                child: Transform.rotate(
                  angle: rotate,
                  child: Image.asset(asset, fit: BoxFit.contain),
                ),
              ),
            );
          }

          return Stack(
            children: [
              Positioned(
                left: x(-284.31),
                top: y(331),
                width: x(881.32),
                height: y(746.82),
                child: Transform.rotate(
                  angle: 0.351,
                  child: _WarmBlurSpot(
                    color: const Color(0xFFFFF2C5).withValues(alpha: 0.56),
                    size: x(720),
                  ),
                ),
              ),
              Positioned(
                left: x(243),
                top: y(-99),
                width: x(300),
                height: y(313),
                child: _WarmBlurSpot(
                  color: Colors.white.withValues(alpha: 0.34),
                  size: x(313),
                ),
              ),
              Positioned(
                left: x(20),
                top: safeTop + 8,
                child: _CapsuleWarmBackButton(
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
              Positioned(
                left: x(-82),
                top: y(639),
                width: x(503),
                height: y(379),
                child: Transform.rotate(
                  angle: 0.349,
                  child: Container(color: const Color(0xFFFFC271)),
                ),
              ),
              Positioned(
                left: x(10),
                top: y(650),
                width: x(181.4574),
                height: y(95.3926),
                child: SvgPicture.asset(
                  _capsuleAssetPendingShadowRing,
                  fit: BoxFit.fill,
                ),
              ),
              Positioned(
                left: x(44),
                top: y(281) + breath * y(8),
                width: x(294),
                height: y(409),
                child: Image.asset(
                  _capsuleAssetPendingBig,
                  fit: BoxFit.contain,
                  opacity: const AlwaysStoppedAnimation<double>(0.80),
                ),
              ),
              Positioned(
                left: x(0),
                right: 0,
                top: y(99),
                child: Column(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white, Color(0xFFFFD697)],
                      ).createShader(bounds),
                      child: const Text(
                        '时间胶囊',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    SizedBox(height: y(16)),
                    Container(
                      width: x(160),
                      height: y(38),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9215),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFFFFC9F)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '开启时间：$dateText',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              sticker(
                _capsuleAssetPendingSticker58,
                left: 16,
                top: 267,
                width: 92,
                height: 42,
                dx: -3,
                dy: 5,
              ),
              sticker(
                _capsuleAssetPendingSticker65,
                left: 16,
                top: 367,
                width: 74,
                height: 64,
                dx: 4,
                dy: -5,
              ),
              sticker(
                _capsuleAssetPendingSticker54,
                left: 133,
                top: 422,
                width: 53,
                height: 44,
                dx: -2,
                dy: -4,
              ),
              sticker(
                _capsuleAssetPendingSticker55,
                left: 96,
                top: 488,
                width: 64,
                height: 61,
                rotate: 0.551,
                dx: 3,
                dy: 4,
              ),
              sticker(
                _capsuleAssetPendingSticker56,
                left: 180,
                top: 494,
                width: 67,
                height: 76,
                dx: -3,
                dy: 4,
              ),
              sticker(
                _capsuleAssetPendingSticker64,
                left: 299,
                top: 521,
                width: 64,
                height: 65,
                dx: 2,
                dy: -4,
              ),
              sticker(
                _capsuleAssetPendingSticker59,
                left: 247,
                top: 610,
                width: 112,
                height: 94,
                rotate: 0.524,
                dx: -4,
                dy: -5,
              ),
            ],
          );
        },
      ),
    );
  }
}

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
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: const Color(0xFFFEFCFA),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Color(0xFF111111),
          decoration: TextDecoration.none,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Design y=55..91: back button with the page title centred on it.
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  height: 36,
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: Center(
                          child: Text(
                            '已解封',
                            style: TextStyle(
                              color: Colors.black,
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
                        child: _CapsuleWarmBackButton(
                          onTap: () => Navigator.of(context).maybePop(),
                          light: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Design y=110, 348x96 centred.
              Padding(
                padding: const EdgeInsets.fromLTRB(21, 19, 21, 0),
                child: _OpenedSummaryCard(count: _capsules.length),
              ),
              // Design y=229 "Frame 334".
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
                    const Text(
                      '我的胶囊',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                        height: 24 / 20,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _capsules.isEmpty
                    ? const Center(
                        child: Text(
                          '暂无已解封胶囊',
                          style: TextStyle(
                            color: Color(0xFF9A9A9A),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      )
                    // Design y=270 with a 125 pitch on 96-high cards.
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(20, 17, 20, bottom + 34),
                        itemCount: _capsules.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 29),
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
                              final deleted = await widget.onDelete(capsule);
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
    );
  }
}

/// Design "Rectangle 282" on the opened screen — same translucent orange card
/// as the home write entry, with the count spelled out over two lines.
class _OpenedSummaryCard extends StatelessWidget {
  const _OpenedSummaryCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            _capsuleOrange.withValues(alpha: 0.40),
            _capsuleOrange.withValues(alpha: 0.25),
          ],
        ),
        border: Border.all(color: _capsuleHairline),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [_capsuleGlassShadow],
      ),
      child: Row(
        children: [
          const _CapsuleIconMedallion(
            diameter: 55.06,
            asset: _capsuleAssetOpenedIcon,
            iconSize: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The count is the one word the design blows up and tints; the
                // rest of the sentence stays 20/700 black.
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
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    height: 25 / 20,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '已经解封',
                  style: TextStyle(
                    color: Color(0xFF333333),
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
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _capsuleHairline),
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
                    style: const TextStyle(
                      color: _capsuleInk,
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
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 10,
                      height: 12 / 10,
                      fontWeight: FontWeight.w400,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      SvgPicture.asset(
                        _capsuleAssetOpenedCalendar,
                        width: 10,
                        height: 10,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '$open 开启',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF666666),
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
        boxShadow: [
          BoxShadow(
            color: _capsuleOrange.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
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

class _CapsuleWarmBackButton extends StatelessWidget {
  const _CapsuleWarmBackButton({required this.onTap, this.light = false});

  final VoidCallback onTap;
  final bool light;

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
          // Design "Ellipse 46": opaque white on the light screens; the warm
          // pending scene keeps the translucent treatment it was built for.
          color: light ? Colors.white : Colors.white.withValues(alpha: 0.40),
          shape: BoxShape.circle,
          border: light ? Border.all(color: _capsuleHairline) : null,
          boxShadow: [
            light
                ? _capsuleOrangeShadow
                : BoxShadow(
                    color: const Color(0xFFFFE3C8).withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 4),
                  ),
          ],
        ),
        alignment: Alignment.center,
        child: light
            ? SvgPicture.asset(_capsuleAssetBackChevron, width: 24, height: 24)
            : const Icon(CupertinoIcons.back, color: Colors.white, size: 25),
      ),
    );
  }
}

/// The 草稿 sheet. Carries the capsule palette rather than the app surface
/// tokens, because it is only ever reached from the warm capsule home.
class _CapsuleDraftSheet extends StatelessWidget {
  const _CapsuleDraftSheet({required this.capsules});

  final List<TimeCapsule> capsules;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Hugs its rows instead of always claiming half the screen: one draft
      // under a tall white slab reads as a loading failure.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.58,
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        // merge, not replace: a plain DefaultTextStyle would also drop the font
        // family the app installs.
        child: DefaultTextStyle.merge(
          style: const TextStyle(
            color: _capsuleInk,
            decoration: TextDecoration.none,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetGrabber(color: Color(0xFFFFDCB0)),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text(
                    '草稿',
                    style: TextStyle(
                      color: _capsuleInk,
                      fontSize: 18,
                      height: 22 / 18,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _capsuleOrange,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [_capsuleOrangeShadow],
                    ),
                    child: Text(
                      '${capsules.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        height: 13 / 11,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                '还没封存，随时可以接着写',
                style: TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 11,
                  height: 13 / 11,
                  fontWeight: FontWeight.w400,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: ListView.separated(
                  // The viewport clips, so the last row needs room to drop its
                  // shadow.
                  padding: const EdgeInsets.only(bottom: 8),
                  shrinkWrap: true,
                  itemCount: capsules.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _CapsuleDraftTile(
                    capsule: capsules[index],
                    onTap: () {
                      final selected = capsules[index];
                      Navigator.of(context).pop(selected);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapsuleSealedOverlay extends StatefulWidget {
  const _CapsuleSealedOverlay({required this.capsule});

  final TimeCapsule capsule;

  @override
  State<_CapsuleSealedOverlay> createState() => _CapsuleSealedOverlayState();
}

class _CapsuleSealedOverlayState extends State<_CapsuleSealedOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _drop;
  late final Animation<double> _fade;
  late final Animation<double> _sway;
  late final Animation<double> _button;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 980),
    )..forward();
    _drop = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.72, curve: Curves.elasticOut),
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.34, curve: Curves.easeOut),
    );
    _sway = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.28, 1, curve: Curves.easeInOutCubic),
    );
    _button = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 1, curve: Curves.easeOutBack),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The card drops in on the very first frame; without this it spends a
    // frame or two as a bare shadow while the artwork decodes.
    unawaited(
      precacheImage(
        const AssetImage('assets/capsule/sealed-card.png'),
        context,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final sx = size.width / 390;
    final sy = size.height / 844;
    double x(double value) => value * sx;
    double y(double value) => value * sy;
    final date = widget.capsule.openDate;
    return Material(
      color: Colors.black.withValues(alpha: 0.76),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final cardTop = lerpDouble(y(-360), y(143), _drop.value)!;
          final rotation = math.sin(_sway.value * math.pi * 2) * 0.012;
          return Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: _fade.value,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.16),
                        radius: 0.86,
                        colors: [
                          const Color(0xFFFFDA66).withValues(alpha: 0.22),
                          const Color(0xFFFFB52A).withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: y(50),
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: math.max(1.2, x(1.5)),
                    height: math.max(0, cardTop - y(50)),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.70),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFFFFD767,
                          ).withValues(alpha: 0.36),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: cardTop - y(3),
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: x(7),
                    height: x(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC34A),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFFFFD767,
                          ).withValues(alpha: 0.64),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: cardTop,
                left: 0,
                right: 0,
                child: Transform.rotate(
                  angle: rotation,
                  child: Center(
                    child: _SealedTicket(
                      date: date,
                      // The card keeps the design's proportions, so on screens
                      // that are wide for their height the width has to give
                      // way rather than let the card grow into the button.
                      width: math.min(
                        x(282),
                        y(565 - 143 - 24) / _SealedTicket.aspectRatio,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: x(42),
                right: x(42),
                top: y(565),
                child: Transform.scale(
                  scale: _button.value.clamp(0.0, 1.0),
                  child: Opacity(
                    opacity: _button.value.clamp(0.0, 1.0),
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                      child: Container(
                        height: y(56),
                        constraints: const BoxConstraints(minHeight: 52),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.84),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.28),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.42),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '完成',
                          style: TextStyle(
                            color: const Color(0xFF151719),
                            fontSize: math.max(20, x(22)),
                            fontWeight: FontWeight.w900,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Year/month/day wheels that only ever list selectable values.
///
/// [CupertinoDatePicker] renders every month and day of the year regardless of
/// `minimumDate` and merely bounces back off the invalid ones, which reads as
/// "the past is offered but refused". Here the lists themselves are clipped to
/// [first]..[last], so today is simply the first row on the wheel.
class _CapsuleDateWheels extends StatefulWidget {
  const _CapsuleDateWheels({
    required this.initial,
    required this.first,
    required this.last,
    required this.textStyle,
    required this.overlayColor,
    required this.onChanged,
  });

  final DateTime initial;
  final DateTime first;
  final DateTime last;
  final TextStyle textStyle;
  final Color overlayColor;
  final ValueChanged<DateTime> onChanged;

  @override
  State<_CapsuleDateWheels> createState() => _CapsuleDateWheelsState();
}

class _CapsuleDateWheelsState extends State<_CapsuleDateWheels> {
  late int _year;
  late int _month;
  late int _day;
  late final FixedExtentScrollController _yearCtrl;
  late final FixedExtentScrollController _monthCtrl;
  late final FixedExtentScrollController _dayCtrl;

  @override
  void initState() {
    super.initState();
    // A caller that seeds a stale draft date must not produce a negative row
    // index, which would take the wheel down with an assertion.
    final seed = widget.initial.isBefore(widget.first)
        ? widget.first
        : (widget.initial.isAfter(widget.last) ? widget.last : widget.initial);
    _year = seed.year;
    _month = seed.month;
    _day = seed.day;
    _yearCtrl = FixedExtentScrollController(
      initialItem: _year - widget.first.year,
    );
    _monthCtrl = FixedExtentScrollController(initialItem: _month - _minMonth);
    _dayCtrl = FixedExtentScrollController(initialItem: _day - _minDay);
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    super.dispose();
  }

  int get _minMonth => _year == widget.first.year ? widget.first.month : 1;
  int get _maxMonth => _year == widget.last.year ? widget.last.month : 12;

  int get _minDay => _year == widget.first.year && _month == widget.first.month
      ? widget.first.day
      : 1;

  int get _maxDay {
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    return _year == widget.last.year && _month == widget.last.month
        ? math.min(widget.last.day, daysInMonth)
        : daysInMonth;
  }

  /// Picking a boundary year or month resizes the wheels to its right, so both
  /// the value and the row index below the change have to be pulled back into
  /// the new range once the shorter list has been laid out.
  void _reclamp() {
    setState(() {
      _month = _month.clamp(_minMonth, _maxMonth);
      _day = _day.clamp(_minDay, _maxDay);
    });
    widget.onChanged(DateTime(_year, _month, _day));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final monthIndex = _month - _minMonth;
      if (_monthCtrl.hasClients && _monthCtrl.selectedItem != monthIndex) {
        _monthCtrl.jumpToItem(monthIndex);
      }
      final dayIndex = _day - _minDay;
      if (_dayCtrl.hasClients && _dayCtrl.selectedItem != dayIndex) {
        _dayCtrl.jumpToItem(dayIndex);
      }
    });
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required List<int> values,
    required String suffix,
    required int column,
    required ValueChanged<int> onChanged,
  }) {
    return Expanded(
      child: CupertinoPicker(
        scrollController: controller,
        itemExtent: 38,
        squeeze: 1.1,
        magnification: 1.06,
        useMagnifier: true,
        backgroundColor: Colors.transparent,
        selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
          background: widget.overlayColor,
          capStartEdge: column == 0,
          capEndEdge: column == 2,
        ),
        onSelectedItemChanged: onChanged,
        children: [
          for (final value in values)
            Center(child: Text('$value$suffix', style: widget.textStyle)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final years = [
      for (var y = widget.first.year; y <= widget.last.year; y++) y,
    ];
    final months = [for (var m = _minMonth; m <= _maxMonth; m++) m];
    final days = [for (var d = _minDay; d <= _maxDay; d++) d];
    return Row(
      children: [
        _wheel(
          controller: _yearCtrl,
          values: years,
          suffix: '年',
          column: 0,
          onChanged: (index) {
            _year = years[index];
            _reclamp();
          },
        ),
        _wheel(
          controller: _monthCtrl,
          values: months,
          suffix: '月',
          column: 1,
          // The wheel can report a stale index for one frame after the list
          // shrinks; the post-frame jump in _reclamp settles it.
          onChanged: (index) {
            if (index < months.length) _month = months[index];
            _reclamp();
          },
        ),
        _wheel(
          controller: _dayCtrl,
          values: days,
          suffix: '日',
          column: 2,
          onChanged: (index) {
            if (index < days.length) _day = days[index];
            _reclamp();
          },
        ),
      ],
    );
  }
}

class _SealedTicket extends StatelessWidget {
  const _SealedTicket({required this.date, required this.width});

  /// The frame the artwork was cut from, in its own pixels. Anything the live
  /// sentence has to line up with — the divider above it, the jar it tucks
  /// into — is baked into the asset, so the placement below is written as
  /// fractions of this frame instead of round numbers.
  static const double _artWidth = 840;
  static const double _artHeight = 1004;
  static const double aspectRatio = _artHeight / _artWidth;

  /// Design-space geometry of the two body lines the asset had painted out.
  static const double _bodyBlockTop = 615;
  static const double _bodyLinePitch = 74;
  static const double _bodyFontSize = 49;

  final DateTime? date;
  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width * aspectRatio;
    final dateLabel = date == null ? '未来某天' : _formatCapsuleDate(date!);
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(width * 100 / _artWidth),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFC94E).withValues(alpha: 0.30),
                    blurRadius: 44,
                  ),
                  BoxShadow(
                    color: const Color(0xFF6B4600).withValues(alpha: 0.22),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
            ),
          ),
          // Everything static — gradient, inset groove, clouds, jar, sparkles,
          // lock badge, title, divider — is one cut of the design so the card
          // matches it exactly instead of approximating it in paint calls.
          Positioned.fill(
            child: Image.asset(
              'assets/capsule/sealed-card.png',
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
            ),
          ),
          Positioned(
            top: height * (_bodyBlockTop / _artHeight),
            left: width * 0.08,
            right: width * 0.08,
            child: Text.rich(
              textAlign: TextAlign.center,
              // The title above and the scenery below are pixels, so growing
              // this one sentence with the system text size would push it into
              // the clouds instead of making the card readable.
              textScaler: TextScaler.noScaling,
              TextSpan(
                style: TextStyle(
                  color: const Color(0xFF3D2607),
                  fontSize: width * (_bodyFontSize / _artWidth),
                  height: _bodyLinePitch / _bodyFontSize,
                  // Even leading keeps the glyphs centred in the line box, so
                  // the block lands where the painted-out one used to sit.
                  leadingDistribution: TextLeadingDistribution.even,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
                children: [
                  const TextSpan(text: '时间胶囊已经封存，\n期待'),
                  TextSpan(
                    text: dateLabel,
                    style: const TextStyle(color: Color(0xFFB56E00)),
                  ),
                  const TextSpan(text: '开启。'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CapsuleReadyOverlay extends StatefulWidget {
  const _CapsuleReadyOverlay({required this.capsule});

  final TimeCapsule capsule;

  @override
  State<_CapsuleReadyOverlay> createState() => _CapsuleReadyOverlayState();
}

class _CapsuleReadyOverlayState extends State<_CapsuleReadyOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _entrance;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    )..forward();
    _entrance = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // The route owns the fade in/out (see chat_page's showGeneralDialog), so
  // dismissing only has to pop; there is no exit animation to await here.
  void _dismiss({required bool open}) {
    if (_dismissed) return;
    _dismissed = true;
    Navigator.of(context).pop(open);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = constraints.maxWidth / _capsuleDesignWidth;
          double x(double value) => value * scale;
          return Stack(
            children: [
              // Design "Rectangle 245" — a flat 70% black scrim. Tapping it is the
              // same "look later" exit as the close button.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _dismiss(open: false),
                  child: const ColoredBox(color: Color(0xB3000000)),
                ),
              ),
              Center(
                // Design puts the postcard + buttons group at y=238..571 of the
                // 844 canvas, which is 17.5 above the vertical centre.
                child: Transform.translate(
                  offset: Offset(0, -x(17.5)),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) => Transform.scale(
                      scale: 0.92 + 0.08 * _entrance.value,
                      child: child,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ReadyPostcard(
                          capsule: widget.capsule,
                          scale: scale,
                          onClose: () => _dismiss(open: false),
                        ),
                        SizedBox(height: x(36)),
                        // Design y=541: two 124x30 pills with a 24 gutter, which
                        // centres the pair on the canvas.
                        SizedBox(
                          width: x(272),
                          child: Row(
                            children: [
                              Expanded(
                                child: _ReadyActionPill(
                                  label: '稍后再看',
                                  scale: scale,
                                  filled: false,
                                  onTap: () => _dismiss(open: false),
                                ),
                              ),
                              SizedBox(width: x(24)),
                              Expanded(
                                child: _ReadyActionPill(
                                  label: '立即查看',
                                  scale: scale,
                                  filled: true,
                                  onTap: () => _dismiss(open: true),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReadyPostcard extends StatelessWidget {
  const _ReadyPostcard({
    required this.capsule,
    required this.scale,
    required this.onClose,
  });

  final TimeCapsule capsule;
  final double scale;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    double x(double value) => value * scale;
    final sealedAt = capsule.sealedAt ?? capsule.createdAt;
    // The 20pt gutter on both sides makes the 324-wide card land on the
    // design's x=33 while leaving room for the close button's overhang.
    return SizedBox(
      width: x(364),
      height: x(267),
      child: Stack(
        children: [
          Positioned(
            left: x(20),
            top: x(20),
            width: x(324),
            height: x(247),
            // Swallow taps: the scrim behind treats a tap as "look later",
            // and hitting the artwork itself should not close the card.
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: Image.asset(
                _capsuleAssetArrivedPostcard,
                fit: BoxFit.contain,
              ),
            ),
          ),
          // Design "Frame 363" at (72, 427) — the only dynamic copy; the
          // heading and illustration are baked into the postcard artwork.
          Positioned(
            left: x(59),
            top: x(189),
            width: x(150),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '《${capsule.displayTitle}》',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _capsuleInk,
                    fontSize: x(14),
                    height: 17 / 14,
                    fontWeight: FontWeight.w400,
                    decoration: TextDecoration.none,
                  ),
                ),
                SizedBox(height: x(4)),
                Text(
                  '封存于${_formatCapsuleDate(sealedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF999999),
                    fontSize: x(10),
                    height: 12 / 10,
                    fontWeight: FontWeight.w400,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          // Design "close" sits detached off the card's top-right corner
          // (x=353/y=238 against a card at 33..357/258..505). The 44pt tap
          // target grows inwards so the glyph keeps that exact slot.
          Positioned(
            right: 0,
            top: 0,
            child: CupertinoButton(
              minimumSize: Size.zero,
              padding: EdgeInsets.zero,
              onPressed: onClose,
              child: SizedBox(
                width: x(44),
                height: x(44),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Image.asset(
                    _capsuleAssetDialogClose,
                    width: x(24),
                    height: x(24),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadyActionPill extends StatelessWidget {
  const _ReadyActionPill({
    required this.label,
    required this.scale,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final double scale;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    double x(double value) => value * scale;
    // Design "Rectangle 243/244": #F29048 fill vs 1px #F29048 outline.
    const accent = Color(0xFFF29048);
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        height: x(30),
        decoration: BoxDecoration(
          color: filled ? accent : Colors.transparent,
          border: filled ? null : Border.all(color: accent),
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: filled ? Colors.white.withValues(alpha: 0.9) : accent,
            fontSize: x(14),
            height: 17 / 14,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

class _CapsuleActionButton extends StatelessWidget {
  const _CapsuleActionButton({
    required this.label,
    required this.filled,
    required this.enabled,
    required this.loading,
    required this.loadingLabel,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final bool enabled;
  final bool loading;
  final String? loadingLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: enabled && !loading ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: !enabled && !loading ? 0.55 : 1,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: filled
                ? _capsuleOrange
                : AppColors.elevatedSurface(context, light: 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: filled ? _capsuleOrange : AppColors.glassBorder(context),
            ),
            boxShadow: [
              if (!filled && isDark)
                BoxShadow(
                  color: AppColors.shadow.withValues(alpha: 0.42),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          alignment: Alignment.center,
          child: loading
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.1,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          filled ? Colors.white : _capsuleOrange,
                        ),
                      ),
                    ),
                    if ((loadingLabel ?? '').isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        loadingLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: filled ? Colors.white : _capsuleOrange,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                )
              : Text(
                  label,
                  style: TextStyle(
                    color: filled ? Colors.white : AppColors.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }
}

class _CapsuleCircleButton extends StatelessWidget {
  const _CapsuleCircleButton({
    required this.icon,
    required this.onTap,
    this.danger = false,
    this.loading = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool danger;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: onTap == null && !loading ? 0.55 : 1,
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface(context, light: 0.82),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.glassBorder(context)),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withValues(alpha: isDark ? 0.72 : 0.10),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFE05555),
                    ),
                  ),
                )
              : Icon(
                  icon,
                  color: danger
                      ? const Color(0xFFE05555)
                      : (isDark ? const Color(0xFFEAF2F8) : AppColors.text),
                  size: 25,
                ),
        ),
      ),
    );
  }
}

class _CapsuleError extends StatelessWidget {
  const _CapsuleError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CupertinoButton(
        onPressed: onRetry,
        child: const Text('胶囊暂时没有回来，点一下重试'),
      ),
    );
  }
}

CapsuleChatDraft _draftForCapsule(TimeCapsule capsule) {
  final created = _formatCapsuleDate(capsule.createdAt);
  final open = capsule.openDate == null
      ? '约定的那一天'
      : _formatCapsuleDate(capsule.openDate!);
  final text = '我于$created埋下了时间胶囊，于$open开启，胶囊内容是：${capsule.content}';
  final card = ChatComponentCard(
    type: 'time_capsule',
    title: '时间胶囊',
    subtitle: '$open开启',
    body: capsule.content,
    footer: '时间胶囊 · 已开启',
    accent: '#7C3CFF',
    payload: {
      'capsule_id': capsule.id,
      'created_date': _dateOnly(capsule.createdAt),
      'open_date': capsule.openDate == null
          ? null
          : _dateOnly(capsule.openDate!),
      'content': capsule.content,
      'skin': capsule.skin,
    },
  );
  return CapsuleChatDraft(agentText: text, card: card);
}

String _effectiveCapsuleSkinId(
  BuildContext context,
  String? storedSkin, {
  required bool useThemeDefaultForPaper,
}) {
  final raw = storedSkin?.trim() ?? '';
  final defaultSkin = AppColors.isDark(context) ? 'night' : 'paper';
  if (raw.isEmpty) return defaultSkin;
  if (useThemeDefaultForPaper && raw == 'paper' && AppColors.isDark(context)) {
    return defaultSkin;
  }
  return raw;
}

Future<bool?> _confirmDeleteCapsule(BuildContext context) {
  return showCupertinoDialog<bool>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: const Text('删除这个胶囊？'),
      content: const Text('删除后，里面的文字、图片和语音都会被彻底删除，无法恢复。'),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
}

Future<void> _waitForNavigatorUnlock({
  Duration delay = const Duration(milliseconds: 80),
}) async {
  await WidgetsBinding.instance.endOfFrame;
  if (delay > Duration.zero) {
    await Future<void>.delayed(delay);
  }
  await WidgetsBinding.instance.endOfFrame;
}

String _formatCapsuleDate(DateTime value) {
  return '${value.year}年${value.month}月${value.day}日';
}

String _formatCapsuleShortDate(DateTime value) {
  return '${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}';
}

/// Compact Chinese form for the draft rows ("7月12日 编辑"), where the year is
/// noise and the row only has a 10pt line to spend.
String _formatCapsuleMonthDay(DateTime value) {
  return '${value.month}月${value.day}日';
}

/// Dotted form used by the opened-capsule list design ("2025.07.12 创建").
String _formatCapsuleDotDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}.$month.$day';
}

String _dateOnly(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
