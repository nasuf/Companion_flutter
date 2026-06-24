part of 'package:companion_flutter/main.dart';

class _ActivityDetailSheetShell extends StatefulWidget {
  const _ActivityDetailSheetShell({
    required this.api,
    required this.activity,
    required this.scrollController,
    required this.fullscreen,
    required this.onAccept,
    required this.onIgnore,
    required this.onCompleted,
  });

  final CompanionApi api;
  final OfflineActivity activity;
  final ScrollController scrollController;
  final bool fullscreen;
  final Future<OfflineActivity?> Function() onAccept;
  final Future<bool> Function() onIgnore;
  final VoidCallback onCompleted;

  @override
  State<_ActivityDetailSheetShell> createState() =>
      _ActivityDetailSheetShellState();
}

class _ActivityDetailSheetShellState extends State<_ActivityDetailSheetShell> {
  @override
  Widget build(BuildContext context) {
    return _ActivityDetailSheet(
      api: widget.api,
      activity: widget.activity,
      scrollController: widget.scrollController,
      fullscreen: true,
      expanded: true,
      onAccept: widget.onAccept,
      onIgnore: widget.onIgnore,
      onCompleted: widget.onCompleted,
    );
  }
}

class _ActivityDetailSheet extends StatefulWidget {
  const _ActivityDetailSheet({
    required this.api,
    required this.activity,
    required this.scrollController,
    required this.fullscreen,
    required this.expanded,
    required this.onAccept,
    required this.onIgnore,
    required this.onCompleted,
  });

  final CompanionApi api;
  final OfflineActivity activity;
  final ScrollController scrollController;
  final bool fullscreen;
  final bool expanded;
  final Future<OfflineActivity?> Function() onAccept;
  final Future<bool> Function() onIgnore;
  final VoidCallback onCompleted;

  @override
  State<_ActivityDetailSheet> createState() => _ActivityDetailSheetState();
}

class _ActivityDetailSheetState extends State<_ActivityDetailSheet>
    with WidgetsBindingObserver {
  final _imagePicker = ImagePicker();
  final _recorder = AudioRecorder();
  final _controller = TextEditingController();
  final _completionFocusNode = FocusNode();
  final _completionComposerKey = GlobalKey();
  Timer? _completionScrollTimer;
  Timer? _recordTimer;
  AudioPlayer? _audioPlayer;
  final List<_ActivityCompletionImage> _photos = [];
  _ActivityCompletionVoice? _voice;
  bool _working = false;
  bool _responding = false;
  bool _uploadingPhoto = false;
  bool _uploadingVoice = false;
  bool _recording = false;
  bool _voicePlaying = false;
  int _recordSeconds = 0;

  static const int _maxVoiceSeconds = 90;
  static const int _maxVoiceBytes = 5 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _completionFocusNode.addListener(_handleCompletionFocusChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _completionScrollTimer?.cancel();
    _recordTimer?.cancel();
    _recorder.dispose();
    _audioPlayer?.dispose();
    _completionFocusNode.removeListener(_handleCompletionFocusChanged);
    _completionFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (_completionFocusNode.hasFocus) {
      _scheduleCompletionComposerIntoView();
    }
  }

  void _handleCompletionFocusChanged() {
    if (_completionFocusNode.hasFocus) {
      _scheduleCompletionComposerIntoView(
        delay: const Duration(milliseconds: 220),
      );
    }
  }

  void _scheduleCompletionComposerIntoView({
    Duration delay = const Duration(milliseconds: 180),
  }) {
    _completionScrollTimer?.cancel();
    _completionScrollTimer = Timer(delay, () {
      if (!mounted || !_completionFocusNode.hasFocus) return;
      final context = _completionComposerKey.currentContext;
      if (context == null) return;
      if (!context.mounted) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        alignment: 0.12,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    });
  }

  Future<void> _complete() async {
    if (_working || _uploadingPhoto || _uploadingVoice || _recording) return;
    setState(() => _working = true);
    try {
      await widget.api.completeOfflineActivity(
        widget.activity.id,
        text: _controller.text.trim(),
        photoAttachmentIds: _photos
            .map((photo) => photo.attachment.id)
            .where((id) => id.isNotEmpty)
            .toList(),
        audioAttachmentId: _voice?.attachment.id,
      );
      widget.onCompleted();
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_photos.length >= 3 || _uploadingPhoto) {
      return;
    }
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
      );
      if (picked == null) return;
      setState(() => _uploadingPhoto = true);
      final bytes = await picked.readAsBytes();
      final dimensions = await _decodeActivityImageDimensions(bytes);
      final attachment = await widget.api.uploadOfflineActivityImage(
        activityId: widget.activity.id,
        name: picked.name,
        mime: picked.mimeType ?? _activityMimeFromPath(picked.path),
        size: bytes.length,
        width: dimensions.width.round(),
        height: dimensions.height.round(),
        base64Data: base64Encode(bytes),
      );
      if (!mounted) return;
      setState(() {
        _photos.add(
          _ActivityCompletionImage(
            localPath: picked.path,
            attachment: attachment,
          ),
        );
      });
    } on Exception {
      _showToast(source == ImageSource.camera ? '需要相机权限才能拍照' : '需要相册权限才能选择照片');
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _removePhoto(_ActivityCompletionImage photo) {
    setState(() => _photos.remove(photo));
  }

  void _showToast(String message) {
    if (!mounted) return;
    _showActivityToast(context, message);
  }

  Future<void> _toggleRecord() async {
    if (_uploadingVoice || _working) return;
    if (_recording) {
      await _stopRecord();
      return;
    }
    final permitted = await _recorder.hasPermission();
    if (!mounted) return;
    if (!permitted) {
      _showToast('需要麦克风权限才能录音');
      return;
    }
    await _audioPlayer?.stop();
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/offline_activity_voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
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
      _voicePlaying = false;
      _recording = true;
      _recordSeconds = 0;
    });
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted || !_recording) {
        timer.cancel();
        return;
      }
      final next = _recordSeconds + 1;
      setState(() => _recordSeconds = next);
      if (next >= _maxVoiceSeconds) {
        timer.cancel();
        await _stopRecord();
      }
    });
  }

  Future<void> _stopRecord() async {
    if (!_recording) return;
    _recordTimer?.cancel();
    final duration = math.max(1, _recordSeconds);
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _uploadingVoice = true;
    });
    try {
      if (path == null || path.isEmpty) return;
      final file = File(path);
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.length > _maxVoiceBytes) {
        _showToast('语音太长了，换一段短一点的吧');
        return;
      }
      final attachment = await widget.api.uploadOfflineActivityAudio(
        activityId: widget.activity.id,
        name: 'activity-voice.m4a',
        mime: 'audio/mp4',
        size: bytes.length,
        durationSeconds: duration,
        base64Data: base64Encode(bytes),
      );
      if (!mounted) return;
      setState(() {
        _voice = _ActivityCompletionVoice(
          localPath: path,
          attachment: attachment,
          durationSeconds: duration,
        );
      });
    } finally {
      if (mounted) setState(() => _uploadingVoice = false);
    }
  }

  Future<void> _toggleVoicePlayback() async {
    final voice = _voice;
    if (voice == null) return;
    final player = _audioPlayer ??= AudioPlayer();
    if (_voicePlaying) {
      await player.stop();
      if (mounted) setState(() => _voicePlaying = false);
      return;
    }
    await player.stop();
    player.onPlayerComplete.first.then((_) {
      if (mounted) setState(() => _voicePlaying = false);
    });
    await player.play(DeviceFileSource(voice.localPath));
    if (mounted) setState(() => _voicePlaying = true);
  }

  void _removeVoice() {
    _audioPlayer?.stop();
    setState(() {
      _voice = null;
      _voicePlaying = false;
    });
  }

  Future<void> _accept() async {
    if (_responding) return;
    setState(() => _responding = true);
    final updated = await widget.onAccept();
    if (!mounted) return;
    setState(() => _responding = false);
    if (updated != null) Navigator.of(context).pop();
  }

  Future<void> _ignore() async {
    if (_responding) return;
    setState(() => _responding = true);
    final success = await widget.onIgnore();
    if (!mounted) return;
    setState(() => _responding = false);
    if (success) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final task = widget.activity.easterEggTask;
    final canRespond = widget.activity.status == 'pending';
    final canReaccept = widget.activity.status == 'ignored';
    final canComplete = widget.activity.status == 'accepted';
    final isCompleted = widget.activity.status == 'completed';
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final bottomPadding =
        MediaQuery.paddingOf(context).bottom + viewInsets.bottom + 18;
    final expanded = widget.fullscreen || widget.expanded;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: expanded
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: expanded
                ? _ExpandedSheetTopBar(
                    key: const ValueKey('expandedHeader'),
                    title: '活动详情',
                    onClose: () => Navigator.of(context).pop(),
                  )
                : const _CollapsedSheetGrabber(
                    key: ValueKey('collapsedGrabber'),
                  ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                controller: widget.scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(22, 4, 22, bottomPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ActivityImage(
                      activity: widget.activity,
                      height: 178,
                      authToken: widget.api.authToken,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      widget.activity.title,
                      style: _titleStyle(context, 24),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.activity.description,
                      style: _mutedStyle(context, 16),
                    ),
                    const SizedBox(height: 16),
                    _MetaLine(activity: widget.activity),
                    if (task != null) ...[
                      const SizedBox(height: 18),
                      _ActivityTaskPanel(task: task),
                    ],
                    if (canRespond) ...[
                      const SizedBox(height: 22),
                      _ActivityResponseButtons(
                        working: _responding,
                        onAccept: _accept,
                        onIgnore: _ignore,
                      ),
                    ] else if (canReaccept) ...[
                      const SizedBox(height: 22),
                      _ActivityReacceptButton(
                        working: _responding,
                        onPressed: _accept,
                      ),
                    ],
                    if (canComplete) ...[
                      const SizedBox(height: 20),
                      _CompletionComposer(
                        key: _completionComposerKey,
                        controller: _controller,
                        focusNode: _completionFocusNode,
                        photos: _photos,
                        voice: _voice,
                        uploadingPhoto: _uploadingPhoto,
                        uploadingVoice: _uploadingVoice,
                        recording: _recording,
                        recordSeconds: _recordSeconds,
                        voicePlaying: _voicePlaying,
                        working: _working,
                        onPickGallery: () => _pickPhoto(ImageSource.gallery),
                        onTakePhoto: () => _pickPhoto(ImageSource.camera),
                        onRemove: _removePhoto,
                        onToggleRecord: _toggleRecord,
                        onToggleVoice: _toggleVoicePlayback,
                        onRemoveVoice: _removeVoice,
                        onComplete: _complete,
                      ),
                    ] else if (isCompleted) ...[
                      const SizedBox(height: 18),
                      _ActivityCompletionFeedbackView(
                        feedback: widget.activity.completionFeedback,
                        api: widget.api,
                        authToken: widget.api.authToken,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityReacceptButton extends StatelessWidget {
  const _ActivityReacceptButton({
    required this.working,
    required this.onPressed,
  });

  final bool working;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: _PrimaryActivityPillButton(
        label: working ? '处理中...' : '重新接受邀请',
        icon: '✨',
        enabled: !working,
        onPressed: onPressed,
      ),
    );
  }
}
