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
    final agentId = widget.session.agentId;
    if (agentId == null || agentId.isEmpty) return Future.value(const []);
    return widget.api.listTimeCapsules(
      agentId: agentId,
      workspaceId: widget.session.workspaceId,
    );
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
    final result = await Navigator.of(context).push<_CapsuleEditorResult>(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => CapsuleEditorPage(
          api: widget.api,
          session: widget.session,
          draft: draft,
        ),
      ),
    );
    if (!mounted) return;
    await _reloadLatestCapsules();
    if (!mounted || result == null) return;
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
      backgroundColor: AppColors.page,
      body: FutureBuilder<List<TimeCapsule>>(
        future: _capsules,
        builder: (context, snapshot) {
          final items =
              snapshot.data ?? _cachedCapsules ?? const <TimeCapsule>[];
          final hasCachedItems = _cachedCapsules != null;
          final drafts = items.where((item) => item.isDraft).toList();
          final pending = items
              .where((item) => item.isPending || item.isReady)
              .toList();
          final opened = items.where((item) => item.isOpened).toList();
          return Stack(
            children: [
              Positioned.fill(child: _CapsuleBackground()),
              SafeArea(
                bottom: false,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                        child: _CapsuleTopBar(
                          onBack: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    ),
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !hasCachedItems)
                      const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (snapshot.hasError && !hasCachedItems)
                      SliverFillRemaining(
                        child: _CapsuleError(onRetry: _refresh),
                      )
                    else ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 28, 22, 0),
                          child: _CapsuleHeroCard(
                            draftCount: drafts.length,
                            pendingCount: pending.length,
                            onWrite: () => _openEditor(),
                            onDrafts: () => _openDrafts(drafts),
                            onPending: () => _openPending(pending),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(26, 28, 26, 10),
                          child: Text(
                            opened.isEmpty
                                ? '已开启胶囊'
                                : _openedSectionTitle(opened),
                            style: const TextStyle(
                              color: Color(0xFF9BA4A1),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ),
                      if (opened.isEmpty)
                        const SliverToBoxAdapter(child: _EmptyCapsuleList())
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(22, 0, 22, bottom + 28),
                          sliver: SliverList.separated(
                            itemCount: opened.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              return _CapsuleListTile(
                                index: index + 1,
                                capsule: opened[index],
                                enabled: true,
                                onDelete: () =>
                                    _deleteOpenedCapsule(opened[index]),
                                onTap: () => _openDetail(opened[index]),
                              );
                            },
                          ),
                        ),
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
      builder: (_) => _CapsulePickerSheet(title: '草稿', capsules: drafts),
    );
    if (!mounted) return;
    if (selected == null) {
      await _reloadLatestCapsules();
      return;
    }
    await _openEditor(draft: selected);
  }

  Future<void> _openDetail(TimeCapsule capsule) async {
    final result = await Navigator.of(context).push<Object?>(
      CupertinoPageRoute<Object?>(
        fullscreenDialog: true,
        builder: (_) => CapsuleEditorPage(
          api: widget.api,
          session: widget.session,
          draft: capsule,
          readOnly: true,
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (result is CapsuleChatDraft) {
      Navigator.of(context).pop(result);
      return;
    }
    if (result is _CapsuleEditorResult && result.deleted) {
      await _reloadLatestCapsules();
    }
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (_) =>
          _CapsulePickerSheet(title: '待开启', capsules: pending, locked: true),
    );
    if (!mounted) return;
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

  @override
  State<CapsuleEditorPage> createState() => _CapsuleEditorPageState();
}

class _CapsuleEditorPageState extends State<CapsuleEditorPage> {
  static const _maxImageBytes = 2 * 1024 * 1024;
  static const _maxVoiceSeconds = 20;
  static const _maxVoiceBytes = 512 * 1024;

  late final TextEditingController _controller;
  final _imagePicker = ImagePicker();
  final _recorder = AudioRecorder();
  AudioPlayer? _audioPlayer;
  DateTime? _openDate;
  String _skin = 'paper';
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

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.draft?.content ?? '');
    _openDate = widget.draft?.openDate;
    _skin = widget.draft?.skin ?? 'paper';
    _restoreMedia(widget.draft?.media);
    _initialContent = widget.draft?.content.trim() ?? '';
    _initialSkin = _skin;
    _initialOpenDate = _openDate;
    _initialMediaKey = _mediaKey(_mediaPayload());
    unawaited(_loadDraftDetailMedia());
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
    var selected = _openDate ?? DateTime(now.year, now.month, now.day + 1);
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        return Container(
          height: 318,
          color: Colors.white,
          child: Column(
            children: [
              SizedBox(
                height: 248,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: selected,
                  minimumDate: DateTime(now.year, now.month, now.day),
                  maximumDate: DateTime(now.year + 20, 12, 31),
                  onDateTimeChanged: (value) => selected = value,
                ),
              ),
              CupertinoButton(
                child: const Text('确定'),
                onPressed: () {
                  setState(() => _openDate = selected);
                  Navigator.of(context).pop();
                },
              ),
            ],
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
    if (agentId == null || agentId.isEmpty) {
      setState(() => _error = '还没有可用的 AI 伴侣。');
      return;
    }
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
    if (draft == null || _saving) return;
    final confirmed = await _confirmDeleteCapsule(context);
    if (confirmed != true || !mounted) return;
    setState(() {
      _saving = true;
      _savingStatus = 'delete';
      _error = null;
    });
    try {
      await widget.api.deleteTimeCapsule(draft.id);
      if (mounted) {
        Navigator.of(context).pop(_CapsuleEditorResult.deleted(draft));
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _asMessage(error);
          _saving = false;
          _savingStatus = null;
        });
      }
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
          style: const TextStyle(
            color: AppColors.text,
            decoration: TextDecoration.none,
          ),
          child: Container(
            height: 270,
            decoration: const BoxDecoration(
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
        setState(() => _error = '图片需要小于 2MB。');
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
          setState(() => _skin = value);
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
                  _CapsuleCircleButton(
                    icon: CupertinoIcons.xmark,
                    onTap: _saving
                        ? null
                        : () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Text(
                      widget.readOnly ? '胶囊详情' : '写新胶囊',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (isReadOnly)
                    _ReadOnlyCapsuleActions(
                      deleting: _savingStatus == 'delete',
                      enabled: !_saving,
                      onDelete: _deleteCapsule,
                      onSend: () => Navigator.of(
                        context,
                      ).pop(_draftForCapsule(widget.draft!)),
                    )
                  else if (widget.draft == null)
                    const SizedBox(width: 54)
                  else
                    _CapsuleCircleButton(
                      icon: CupertinoIcons.delete,
                      danger: true,
                      loading: _savingStatus == 'delete',
                      onTap: _saving ? null : _deleteCapsule,
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
                  senderName: widget.session.username,
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
      accent: Color(0xFF7C3CFF),
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
      page: Color(0xFFEDEFF7),
      paper: Color(0xFF252C45),
      line: Color(0xFF3D4662),
      text: Color(0xFFF7F2E8),
      muted: Color(0xFFB8BED4),
      accent: Color(0xFF9CB4FF),
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
                  SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 86),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: math.max(0, constraints.maxHeight - 104),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: controller,
                            readOnly: readOnly,
                            showCursor: !readOnly,
                            minLines: 8,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            cursorHeight: 23,
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
                              border: InputBorder.none,
                              isCollapsed: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
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
            color: Colors.white.withValues(alpha: 0.76),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.92),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
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
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Icon(
              CupertinoIcons.calendar,
              color: Color(0xFF7C3CFF),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                openDate == null ? '开启日期' : _formatCapsuleShortDate(openDate!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_down,
              color: AppColors.muted,
              size: 16,
            ),
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
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(18),
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
  const _SheetGrabber();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Center(
        child: Container(
          width: 42,
          height: 5,
          decoration: BoxDecoration(
            color: const Color(0xFFD8DCE0),
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
      decoration: const BoxDecoration(
        color: AppColors.page,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: DefaultTextStyle(
          style: const TextStyle(
            color: AppColors.text,
            decoration: TextDecoration.none,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetGrabber(),
              const Text(
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

class _CapsuleTopBar extends StatelessWidget {
  const _CapsuleTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CapsuleCircleButton(icon: CupertinoIcons.chevron_left, onTap: onBack),
      ],
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
            color: Colors.white.withValues(alpha: 0.88),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF315B88).withValues(alpha: 0.10),
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

class _CapsuleHeroCard extends StatefulWidget {
  const _CapsuleHeroCard({
    required this.draftCount,
    required this.pendingCount,
    required this.onWrite,
    required this.onDrafts,
    required this.onPending,
  });

  final int draftCount;
  final int pendingCount;
  final VoidCallback onWrite;
  final VoidCallback onDrafts;
  final VoidCallback onPending;

  @override
  State<_CapsuleHeroCard> createState() => _CapsuleHeroCardState();
}

class _CapsuleHeroCardState extends State<_CapsuleHeroCard>
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final breath = Curves.easeInOut.transform(_controller.value);
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5D45D8).withValues(alpha: 0.12),
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -54 + breath * 10,
                top: -44 + breath * 6,
                child: _CapsuleHeroGlow(progress: breath),
              ),
              Positioned(
                right: -28,
                bottom: 18 + breath * 7,
                child: Transform.scale(
                  scale: 0.96 + breath * 0.04,
                  child: const _CapsuleGem(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FUTURE CAPSULE',
                      style: TextStyle(
                        color: Color(0xFF6F3CFF),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Padding(
                      padding: EdgeInsets.only(right: 26),
                      child: Text(
                        '此刻的低语，留给后来的自己',
                        style: TextStyle(
                          color: Color(0xFF151719),
                          fontSize: 30,
                          height: 1.14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Padding(
                      padding: EdgeInsets.only(right: 52),
                      child: Text(
                        '不必急着奔赴，此刻的心情，未来的你会慢慢读懂',
                        style: TextStyle(
                          color: Color(0xFF6F7775),
                          fontSize: 15,
                          height: 1.52,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CapsuleChip(
                          label: '写新胶囊',
                          primary: true,
                          onTap: widget.onWrite,
                        ),
                        const SizedBox(width: 10),
                        _CapsuleChip(
                          label: '草稿 ${widget.draftCount}',
                          onTap: widget.draftCount > 0 ? widget.onDrafts : null,
                        ),
                        const SizedBox(width: 10),
                        _CapsuleChip(
                          label: '待开启 ${widget.pendingCount}',
                          onTap: widget.pendingCount > 0
                              ? widget.onPending
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CapsuleHeroGlow extends StatelessWidget {
  const _CapsuleHeroGlow({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
      child: Container(
        width: 210,
        height: 210,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              const Color(0xFFCDB9FF).withValues(alpha: 0.30 + progress * 0.08),
              const Color(0xFFCDB9FF).withValues(alpha: 0.08),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _CapsuleChip extends StatelessWidget {
  const _CapsuleChip({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: enabled ? 1 : 0.42,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: primary ? const Color(0xFF7C3CFF) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: primary ? 0 : 0.76),
            ),
            boxShadow: [
              BoxShadow(
                color: (primary ? const Color(0xFF7C3CFF) : Colors.black)
                    .withValues(alpha: primary ? 0.20 : 0.045),
                blurRadius: primary ? 14 : 12,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: primary ? Colors.white : AppColors.text,
              fontWeight: primary ? FontWeight.w900 : FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _CapsuleListTile extends StatelessWidget {
  const _CapsuleListTile({
    required this.index,
    required this.capsule,
    required this.enabled,
    this.compact = false,
    this.locked = false,
    this.onDelete,
    this.onTap,
  });

  final int index;
  final TimeCapsule capsule;
  final bool enabled;
  final bool compact;
  final bool locked;
  final Future<bool> Function()? onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final openDateLabel = capsule.openDate == null
        ? '--/--'
        : _formatCapsuleShortDate(capsule.openDate!);
    final tile = CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: enabled ? 1 : 0.74,
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 76 : 86),
          padding: EdgeInsets.fromLTRB(
            compact ? 14 : 16,
            compact ? 12 : 14,
            compact ? 14 : 16,
            compact ? 12 : 14,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: compact ? 0.96 : 0.90),
            borderRadius: BorderRadius.circular(compact ? 22 : 24),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF4A5568,
                ).withValues(alpha: compact ? 0.07 : 0.045),
                blurRadius: compact ? 18 : 18,
                offset: Offset(0, compact ? 9 : 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 48 : 50,
                height: compact ? 48 : 50,
                decoration: BoxDecoration(
                  color: locked
                      ? const Color(0xFFEFEFF4)
                      : const Color(0xFFE9DCFF),
                  borderRadius: BorderRadius.circular(compact ? 15 : 16),
                ),
                alignment: Alignment.center,
                child: locked
                    ? Icon(
                        CupertinoIcons.lock_fill,
                        color: const Color(0xFF7B8280),
                        size: compact ? 19 : 23,
                      )
                    : Text(
                        '$index',
                        style: TextStyle(
                          color: Color(0xFF7C3CFF),
                          fontSize: compact ? 20 : 22,
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.none,
                        ),
                      ),
              ),
              SizedBox(width: compact ? 14 : 15),
              Expanded(
                child: Text(
                  locked
                      ? '待开启胶囊\n${_formatCapsuleCreatedStamp(capsule.createdAt)}创建'
                      : capsule.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: locked ? const Color(0xFF6F7775) : AppColors.text,
                    fontSize: compact ? 15 : 16,
                    height: 1.34,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              SizedBox(width: compact ? 10 : 12),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? 72 : 78),
                child: Text(
                  locked ? '$openDateLabel开启' : openDateLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Color(0xFF9AA19E),
                    fontSize: locked
                        ? (compact ? 13 : 15)
                        : (compact ? 16 : 15),
                    fontWeight: compact ? FontWeight.w900 : FontWeight.w800,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (onDelete == null || compact || locked) return tile;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Dismissible(
        key: ValueKey('opened-capsule-${capsule.id}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => onDelete!(),
        background: const _CapsuleDeleteSwipeBackground(),
        child: tile,
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

class _CapsulePickerSheet extends StatelessWidget {
  const _CapsulePickerSheet({
    required this.title,
    required this.capsules,
    this.locked = false,
  });

  final String title;
  final List<TimeCapsule> capsules;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: math.min(430, MediaQuery.sizeOf(context).height * 0.56),
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      decoration: const BoxDecoration(
        color: AppColors.page,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: DefaultTextStyle(
          style: const TextStyle(
            color: AppColors.text,
            decoration: TextDecoration.none,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetGrabber(),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: capsules.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _CapsuleListTile(
                    index: index + 1,
                    capsule: capsules[index],
                    enabled: !locked,
                    compact: true,
                    locked: locked,
                    onTap: () {
                      if (locked) return;
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.capsule.openDate;
    return Material(
      color: Colors.black.withValues(alpha: 0.70),
      child: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final cardTop = lerpDouble(-220, 110, _drop.value)!;
            final rotation = math.sin(_sway.value * math.pi * 2) * 0.018;
            return Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: _fade.value,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.2),
                          radius: 0.9,
                          colors: [
                            const Color(0xFFFFD86E).withValues(alpha: 0.18),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 42,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 2,
                      height: math.max(0, cardTop - 24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(999),
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
                    child: Center(child: _SealedTicket(date: date)),
                  ),
                ),
                Positioned(
                  left: 40,
                  right: 40,
                  bottom: 54,
                  child: Transform.scale(
                    scale: _button.value.clamp(0.0, 1.0),
                    child: Opacity(
                      opacity: _button.value.clamp(0.0, 1.0),
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).pop(),
                        child: Container(
                          height: 58,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(29),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.22),
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            '完成',
                            style: TextStyle(
                              color: Color(0xFF151719),
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
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
      ),
    );
  }
}

class _SealedTicket extends StatelessWidget {
  const _SealedTicket({required this.date});

  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final dateLabel = date == null ? '未来某天' : _formatCapsuleDate(date!);
    return Container(
      width: 292,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC944),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 32,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            bottom: -20,
            child: Container(
              width: 94,
              height: 94,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            children: [
              Container(
                width: 78,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  CupertinoIcons.lock_fill,
                  color: Color(0xFFFFB526),
                  size: 25,
                ),
              ),
              const SizedBox(height: 26),
              const Text(
                '封存完成',
                style: TextStyle(
                  color: Color(0xFF151719),
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '时间胶囊已经封存，期待$dateLabel开启。',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF2B2A25),
                  fontSize: 17,
                  height: 1.55,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
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
  late final AnimationController _closeController;
  late final Animation<double> _drop;
  late final Animation<double> _fade;
  late final Animation<double> _lamp;
  late final Animation<double> _button;
  late final Animation<double> _close;
  bool _closing = false;
  double? _closingCardTop;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..forward();
    _closeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _drop = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.70, curve: Curves.easeOutBack),
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.32, curve: Curves.easeOut),
    );
    _lamp = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.18, 0.86, curve: Curves.easeInOutCubic),
    );
    _button = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.58, 1, curve: Curves.easeOutBack),
    );
    _close = CurvedAnimation(
      parent: _closeController,
      curve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _closeController.dispose();
    super.dispose();
  }

  Future<void> _closeWithoutOpening() async {
    if (_closing) return;
    setState(() {
      _closing = true;
      _closingCardTop = lerpDouble(-230, 94, _drop.value)!;
    });
    _controller.stop();
    await _closeController.forward();
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.74),
      child: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([_controller, _closeController]),
          builder: (context, _) {
            final openCardTop = lerpDouble(-230, 94, _drop.value)!;
            final cardTop = _closing
                ? lerpDouble(
                    _closingCardTop ?? openCardTop,
                    -360,
                    _close.value,
                  )!
                : openCardTop;
            final closeOpacity = _closing ? 1 - _close.value : 1.0;
            final glowOpacity = (1 - _lamp.value) * 0.30 + 0.08;
            final rotation = math.sin(_lamp.value * math.pi) * -0.012;
            return Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: _fade.value * closeOpacity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.42),
                          radius: 0.78,
                          colors: [
                            const Color(
                              0xFFFFE59B,
                            ).withValues(alpha: glowOpacity),
                            const Color(0xFF7C3CFF).withValues(alpha: 0.06),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 38,
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: closeOpacity,
                    child: Center(
                      child: Container(
                        width: 2,
                        height: math.max(0, cardTop - 18),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.86),
                          borderRadius: BorderRadius.circular(999),
                        ),
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
                      child: _ReadyTicket(
                        capsule: widget.capsule,
                        onClose: _closeWithoutOpening,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 40,
                  right: 40,
                  bottom: 54,
                  child: Transform.scale(
                    scale: (_button.value * closeOpacity).clamp(0.0, 1.0),
                    child: Opacity(
                      opacity: (_button.value * closeOpacity).clamp(0.0, 1.0),
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Container(
                          height: 58,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(29),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF7C3CFF,
                                ).withValues(alpha: 0.28),
                                blurRadius: 28,
                                offset: const Offset(0, 13),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            '开启',
                            style: TextStyle(
                              color: Color(0xFF151719),
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
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
      ),
    );
  }
}

class _ReadyTicket extends StatelessWidget {
  const _ReadyTicket({required this.capsule, required this.onClose});

  final TimeCapsule capsule;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final date = capsule.openDate;
    final dateLabel = date == null ? '今天' : _formatCapsuleDate(date);
    return Container(
      width: 292,
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 26),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC944),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 34,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            top: -8,
            child: CupertinoButton(
              minimumSize: Size.zero,
              padding: EdgeInsets.zero,
              onPressed: onClose,
              child: Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                child: const Icon(
                  CupertinoIcons.xmark,
                  color: Colors.white,
                  size: 21,
                  shadows: [
                    Shadow(
                      color: Color(0x33000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -24,
            bottom: -28,
            child: Transform.rotate(
              angle: -0.45,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(34),
                ),
              ),
            ),
          ),
          Column(
            children: [
              Container(
                width: 82,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const CustomPaint(
                  size: Size(32, 32),
                  painter: _CapsuleSidebarIconPainter(
                    accent: Color(0xFFFFB526),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '灯亮了',
                style: TextStyle(
                  color: Color(0xFF151719),
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '你有一个新胶囊今天待开启。\n它约定在$dateLabel等你。',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF2B2A25),
                  fontSize: 17,
                  height: 1.48,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
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
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: enabled && !loading ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: !enabled && !loading ? 0.55 : 1,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: filled ? const Color(0xFF7C3CFF) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: filled ? const Color(0xFF7C3CFF) : const Color(0xFFE8E8EE),
            ),
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
                          filled ? Colors.white : const Color(0xFF7C3CFF),
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
                          color: filled
                              ? Colors.white
                              : const Color(0xFF7C3CFF),
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
            color: Colors.white.withValues(alpha: 0.82),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF315B88).withValues(alpha: 0.10),
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
                  color: danger ? const Color(0xFFE05555) : AppColors.text,
                  size: 25,
                ),
        ),
      ),
    );
  }
}

class _CapsuleBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFDFEFC), Color(0xFFF3F6F2)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -64,
            top: 170,
            child: _BlurSpot(
              color: const Color(0xFFB491FF).withValues(alpha: 0.26),
              size: 210,
            ),
          ),
          Positioned(
            left: -88,
            bottom: 160,
            child: _BlurSpot(
              color: const Color(0xFF85D8CA).withValues(alpha: 0.18),
              size: 220,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurSpot extends StatelessWidget {
  const _BlurSpot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _CapsuleGem extends StatelessWidget {
  const _CapsuleGem();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.18,
      child: Container(
        width: 112,
        height: 124,
        decoration: BoxDecoration(
          color: const Color(0xFF7C3CFF),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Stack(
          children: [
            Positioned(
              right: 8,
              top: 20,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.36),
                    width: 2,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              top: 16,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.90),
                      Colors.white.withValues(alpha: 0.10),
                    ],
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

class _EmptyCapsuleList extends StatelessWidget {
  const _EmptyCapsuleList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
      child: Container(
        height: 112,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white),
        ),
        child: const Text(
          '暂无胶囊开启',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 16,
            fontWeight: FontWeight.w800,
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
    },
  );
  return CapsuleChatDraft(agentText: text, card: card);
}

String _openedSectionTitle(List<TimeCapsule> opened) {
  final first = opened.first.openDate;
  if (first == null) return '已开启胶囊';
  return '${first.year} 年 ${first.month} 月开启';
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

String _formatCapsuleDate(DateTime value) {
  return '${value.year}年${value.month}月${value.day}日';
}

String _formatCapsuleShortDate(DateTime value) {
  return '${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}';
}

String _formatCapsuleCreatedStamp(DateTime value) {
  final local = value.toLocal();
  final date =
      '${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}';
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
  return '$date $time';
}

String _dateOnly(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
