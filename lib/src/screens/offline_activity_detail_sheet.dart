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
  late bool _expanded = widget.fullscreen;
  late bool _hasReachedFullscreen = widget.fullscreen;
  bool _closing = false;

  @override
  void didUpdateWidget(covariant _ActivityDetailSheetShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fullscreen != widget.fullscreen && widget.fullscreen) {
      _expanded = true;
      _hasReachedFullscreen = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        if (widget.fullscreen || _closing) return false;
        final extent = notification.extent;
        final reachedFullscreen = extent >= 0.985;
        if (reachedFullscreen && !_hasReachedFullscreen) {
          _hasReachedFullscreen = true;
        }
        if (_hasReachedFullscreen && extent < 0.94) {
          _closing = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final navigator = Navigator.of(context);
            if (navigator.canPop()) {
              navigator.pop();
            }
          });
          return true;
        }
        final next = _hasReachedFullscreen || reachedFullscreen;
        if (next != _expanded) {
          setState(() => _expanded = next);
        }
        return false;
      },
      child: _ActivityDetailSheet(
        api: widget.api,
        activity: widget.activity,
        scrollController: widget.scrollController,
        fullscreen: widget.fullscreen,
        expanded: _expanded,
        onAccept: widget.onAccept,
        onIgnore: widget.onIgnore,
        onCompleted: widget.onCompleted,
      ),
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
  final _controller = TextEditingController();
  final _completionFocusNode = FocusNode();
  final _completionComposerKey = GlobalKey();
  Timer? _completionScrollTimer;
  final List<_ActivityCompletionImage> _photos = [];
  bool _working = false;
  bool _responding = false;
  bool _uploadingPhoto = false;

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
    if (_working || _uploadingPhoto) return;
    setState(() => _working = true);
    try {
      await widget.api.completeOfflineActivity(
        widget.activity.id,
        text: _controller.text.trim(),
        photoAttachmentIds: _photos
            .map((photo) => photo.attachment.id)
            .where((id) => id.isNotEmpty)
            .toList(),
      );
      widget.onCompleted();
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _pickPhoto() async {
    if (_photos.length >= 3 || _uploadingPhoto) {
      return;
    }
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
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
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _removePhoto(_ActivityCompletionImage photo) {
    setState(() => _photos.remove(photo));
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
                        uploading: _uploadingPhoto,
                        working: _working,
                        onPick: _pickPhoto,
                        onRemove: _removePhoto,
                        onComplete: _complete,
                      ),
                    ] else if (isCompleted) ...[
                      const SizedBox(height: 18),
                      _ActivityCompletionFeedbackView(
                        feedback: widget.activity.completionFeedback,
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

class _CompletionComposer extends StatelessWidget {
  const _CompletionComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.photos,
    required this.uploading,
    required this.working,
    required this.onPick,
    required this.onRemove,
    required this.onComplete,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<_ActivityCompletionImage> photos;
  final bool uploading;
  final bool working;
  final VoidCallback onPick;
  final ValueChanged<_ActivityCompletionImage> onRemove;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedBuilder(
          animation: focusNode,
          builder: (context, child) {
            return CupertinoTextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 3,
              maxLines: 5,
              placeholder: '分享一点完成情况、文字感想或照片说明...',
              padding: const EdgeInsets.all(16),
              textInputAction: TextInputAction.newline,
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: focusNode.hasFocus
                      ? colors.accent.withValues(alpha: 0.24)
                      : Colors.transparent,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _CompletionPhotoPicker(
          photos: photos,
          uploading: uploading,
          onPick: onPick,
          onRemove: onRemove,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            borderRadius: BorderRadius.circular(18),
            color: const Color(0xFFFFA83E),
            onPressed: (working || uploading) ? null : onComplete,
            child: Text(
              working ? '发送中...' : '分享完成情况',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ],
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
