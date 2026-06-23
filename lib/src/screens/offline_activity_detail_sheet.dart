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

  @override
  void didUpdateWidget(covariant _ActivityDetailSheetShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fullscreen != widget.fullscreen && widget.fullscreen) {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        if (widget.fullscreen) return false;
        final next = notification.extent >= 0.88;
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

class _ActivityDetailSheetState extends State<_ActivityDetailSheet> {
  final _imagePicker = ImagePicker();
  final _controller = TextEditingController();
  final List<_ActivityCompletionImage> _photos = [];
  bool _working = false;
  bool _responding = false;
  bool _uploadingPhoto = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
                    ],
                    if (canComplete) ...[
                      const SizedBox(height: 20),
                      CupertinoTextField(
                        controller: _controller,
                        minLines: 3,
                        maxLines: 5,
                        placeholder: '分享一点完成情况、文字感想或照片说明...',
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.surfaceMuted,
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CompletionPhotoPicker(
                        photos: _photos,
                        uploading: _uploadingPhoto,
                        onPick: _pickPhoto,
                        onRemove: _removePhoto,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton(
                          borderRadius: BorderRadius.circular(18),
                          color: const Color(0xFFFFA83E),
                          onPressed: (_working || _uploadingPhoto)
                              ? null
                              : _complete,
                          child: Text(
                            _working ? '发送中...' : '分享完成情况',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
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
