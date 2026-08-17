part of 'package:companion_flutter/main.dart';

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
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        borderRadius: BorderRadius.circular(999),
                        color: skin.accent.withValues(
                          alpha: isDark ? 0.18 : 0.12,
                        ),
                        onPressed: () {
                          setState(() => _openDate = selected);
                          Navigator.of(context).pop();
                        },
                        // Fixed-height pill with centred content: dropping the
                        // Text's height:1 lets the CJK glyph sit on its natural
                        // baseline, and the Container centres it top-to-bottom.
                        child: Container(
                          height: 34,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.center,
                          child: Text(
                            '确定',
                            style: TextStyle(
                              color: skin.accent,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              decoration: TextDecoration.none,
                            ),
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
    // Skin-themed like the date sheet, so it reads as part of the letter paper
    // rather than the app-grey surface popping out of a warm editor.
    final skin = _CapsuleSkin.byId(_skin);
    final isDark = AppColors.isDark(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (_) => MediaQuery(
        data: MediaQuery.of(context),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: skin.text, decoration: TextDecoration.none),
          child: Container(
            height: 270,
            decoration: BoxDecoration(
              color: isDark ? skin.paper : skin.page,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border(
                top: BorderSide(color: skin.line.withValues(alpha: 0.38)),
              ),
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
              child: SizedBox(
                height: 44,
                child: Stack(
                  children: [
                    // Centred on the whole header rather than the space left by
                    // the buttons, so 胶囊详情's wider right actions can't shove
                    // the title off-centre.
                    Positioned.fill(
                      child: Center(
                        child: Text(
                          widget.readOnly ? '胶囊详情' : '写新胶囊',
                          style: TextStyle(
                            color: skin.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    // Left close — the same 36pt glass circle as the home back
                    // button.
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _CapsuleCircleButton(
                          icon: CupertinoIcons.xmark,
                          onTap: _saving || !_routeSettled
                              ? null
                              : () => unawaited(_closeEditor()),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: isReadOnly
                            ? _ReadOnlyCapsuleActions(
                                deleting: _savingStatus == 'delete',
                                enabled: !_saving && _routeSettled,
                                onDelete: _deleteCapsule,
                                onSend: () => unawaited(
                                  _closeEditor(_draftForCapsule(widget.draft!)),
                                ),
                              )
                            : widget.draft == null
                            ? const SizedBox.shrink()
                            : _CapsuleCircleButton(
                                icon: CupertinoIcons.delete,
                                danger: true,
                                loading: _savingStatus == 'delete',
                                onTap: _saving || !_routeSettled
                                    ? null
                                    : _deleteCapsule,
                              ),
                      ),
                    ),
                  ],
                ),
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
                    color: _capsuleDanger,
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
