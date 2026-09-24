part of 'package:companion_flutter/main.dart';

class _AboutCompanionPage extends StatelessWidget {
  const _AboutCompanionPage({required this.onContact});

  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    return _SettingsSubScaffold(
      title: '关于我们',
      child: _SubPageContent(
        center: true,
        children: [
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/prototype/logo.png',
              width: 88,
              height: 88,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '伴生·SoulMate',
            style: TextStyle(
              color: _SettingsColors.text,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '让每一次陪伴都有温度',
            style: TextStyle(
              color: _SettingsColors.tertiary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 16),
          _SubCard(
            children: [
              const _SubCardRow(label: '开发者团队', value: '启序科技'),
              _SubCardRow(label: '联系我们/意见反馈', value: '›', onTap: onContact),
              _SubCardRow(
                label: '用户协议',
                value: '›',
                onTap: () => Navigator.of(context).push(
                  CompanionPageRoute<void>(
                    builder: (_) => const _LegalDocumentPage(
                      title: '用户协议',
                      assetPath: 'assets/legal/service_agreement.txt',
                    ),
                  ),
                ),
              ),
              _SubCardRow(
                label: '隐私政策',
                value: '›',
                showDivider: false,
                onTap: () => Navigator.of(context).push(
                  CompanionPageRoute<void>(
                    builder: (_) => const _LegalDocumentPage(
                      title: '隐私政策',
                      assetPath: 'assets/legal/privacy_policy.txt',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '© 2026 启序科技',
            style: TextStyle(
              color: _SettingsColors.isDark
                  ? const Color(0xFF687789)
                  : const Color(0xFFBBBBBB),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactFeedbackPage extends StatefulWidget {
  const _ContactFeedbackPage({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_ContactFeedbackPage> createState() => _ContactFeedbackPageState();
}

class _ContactFeedbackPageState extends State<_ContactFeedbackPage> {
  final _contentController = TextEditingController();
  final _contactController = TextEditingController();
  final _occurredAtController = TextEditingController();
  final _picker = ImagePicker();
  final List<_FeedbackAttachmentDraft> _attachments = [];
  bool _submitting = false;

  @override
  void dispose() {
    _contentController.dispose();
    _contactController.dispose();
    _occurredAtController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = 3 - _attachments.length;
    if (remaining <= 0) return;

    if (remaining == 1) {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _attachments.add(
          _FeedbackAttachmentDraft(
            bytes: bytes,
            name: file.name,
            mime: 'image/jpeg',
          ),
        );
      });
      return;
    }

    final files = await _picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;
    if (files.length > remaining) {
      _showSnack('最多还能选择 $remaining 张图片');
    }
    for (final file in files.take(remaining)) {
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _attachments.add(
          _FeedbackAttachmentDraft(
            bytes: bytes,
            name: file.name,
            mime: 'image/jpeg',
          ),
        );
      });
    }
  }

  Future<void> _previewAttachment(int index) async {
    if (index < 0 || index >= _attachments.length) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'feedback-photo-preview',
      barrierColor: Colors.black.withValues(alpha: 0.78),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, _, __) {
        return _FeedbackAttachmentPreviewDialog(
          attachments: List<_FeedbackAttachmentDraft>.unmodifiable(
            _attachments,
          ),
          initialIndex: index,
          onClose: () => Navigator.of(context).pop(),
        );
      },
      transitionBuilder: (context, animation, _, child) {
        final curved = Curves.easeOutCubic.transform(animation.value);
        return Opacity(
          opacity: curved,
          child: Transform.scale(scale: 1.02 - 0.02 * curved, child: child),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final content = _contentController.text.trim();
    final contact = _contactController.text.trim();
    if (content.length < 5) {
      _showSnack('请至少输入 5 个字的反馈内容');
      return;
    }
    if (contact.isEmpty) {
      _showSnack('请填写联系方式');
      return;
    }
    setState(() => _submitting = true);
    try {
      widget.api.authToken = widget.session.token;
      final clientInfo = await ClientInfo.load();
      await widget.api.submitUserFeedback(
        content: content,
        contact: contact,
        occurredAt: _occurredAtController.text.trim(),
        appVersion: clientInfo.appVersion,
        platform: clientInfo.platform,
        imageBytes: _attachments.map((item) => item.bytes).toList(),
        imageNames: _attachments.map((item) => item.name).toList(),
        imageMimes: _attachments.map((item) => item.mime).toList(),
      );
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('提交成功'),
          content: const Text('感谢你的反馈，我们会尽快处理。'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      _showSnack('提交失败：${_asMessage(error)}');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsSubScaffold(
      title: '联系我们/意见反馈',
      child: _SubPageContent(
        children: [
          _SubCard(
            padding: const EdgeInsets.all(16),
            children: [
              const _SubTitle('问题与意见 *'),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: _contentController,
                maxLines: 5,
                minLines: 4,
                placeholder: '请详细描述您的问题或建议...',
                decoration: BoxDecoration(
                  color: _SettingsColors.page,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SubCard(
            padding: const EdgeInsets.all(16),
            children: [
              const _SubTitle('上传图片（选填）'),
              const SizedBox(height: 10),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _attachments.length >= 3 ? null : _pickImages,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _SettingsColors.separator),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _attachments.isEmpty
                        ? '点击上传截图（最多3张）'
                        : '已选 ${_attachments.length}/3，点击继续添加',
                    style: TextStyle(
                      color: _SettingsColors.tertiary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (_attachments.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < _attachments.length; i += 1)
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          GestureDetector(
                            onTap: () => _previewAttachment(i),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                _attachments[i].bytes,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: -6,
                            right: -6,
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              onPressed: () =>
                                  setState(() => _attachments.removeAt(i)),
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  color: Color(0x99000000),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  CupertinoIcons.xmark,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _SubCard(
            children: [
              _SubCardRow(
                label: '问题发生时间',
                value: '',
                trailing: SizedBox(
                  width: 160,
                  child: CupertinoTextField(
                    controller: _occurredAtController,
                    placeholder: '如：2026-06-22',
                    textAlign: TextAlign.right,
                    decoration: null,
                  ),
                ),
              ),
              _SubCardRow(
                label: '联系方式 *',
                value: '',
                showDivider: false,
                trailing: SizedBox(
                  width: 180,
                  child: CupertinoTextField(
                    controller: _contactController,
                    placeholder: '邮箱或手机号',
                    textAlign: TextAlign.right,
                    keyboardType: TextInputType.emailAddress,
                    decoration: null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CupertinoButton(
            color: _SettingsColors.blueDark,
            borderRadius: BorderRadius.circular(16),
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const CupertinoActivityIndicator(color: Colors.white)
                : const Text(
                    '提交反馈',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackAttachmentDraft {
  const _FeedbackAttachmentDraft({
    required this.bytes,
    required this.name,
    required this.mime,
  });

  final Uint8List bytes;
  final String name;
  final String mime;
}

class _FeedbackAttachmentPreviewDialog extends StatefulWidget {
  const _FeedbackAttachmentPreviewDialog({
    required this.attachments,
    required this.initialIndex,
    required this.onClose,
  });

  final List<_FeedbackAttachmentDraft> attachments;
  final int initialIndex;
  final VoidCallback onClose;

  @override
  State<_FeedbackAttachmentPreviewDialog> createState() =>
      _FeedbackAttachmentPreviewDialogState();
}

class _FeedbackAttachmentPreviewDialogState
    extends State<_FeedbackAttachmentPreviewDialog> {
  late final PageController _pageController;
  late final ScrollController _thumbController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.attachments.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _thumbController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerThumbnail());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbController.dispose();
    super.dispose();
  }

  void _handlePageChanged(int index) {
    setState(() => _currentIndex = index);
    _centerThumbnail();
  }

  void _selectPhoto(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
    _centerThumbnail(index);
  }

  void _centerThumbnail([int? index]) {
    if (!_thumbController.hasClients) return;
    final targetIndex = index ?? _currentIndex;
    final viewport = _thumbController.position.viewportDimension;
    final target =
        targetIndex * _DailyPreviewMetrics.thumbStride -
        viewport / 2 +
        _DailyPreviewMetrics.thumbWidth / 2;
    _thumbController.animateTo(
      target.clamp(
        _thumbController.position.minScrollExtent,
        _thumbController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final attachments = widget.attachments;
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: const SizedBox.expand(),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: _DailyCircleButton(
                      icon: CupertinoIcons.xmark,
                      onPressed: widget.onClose,
                      dark: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      onPageChanged: _handlePageChanged,
                      itemCount: attachments.length,
                      itemBuilder: (context, index) {
                        return Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(34),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.42),
                                    blurRadius: 80,
                                    offset: const Offset(0, 34),
                                  ),
                                ],
                              ),
                              child: InteractiveViewer(
                                minScale: 1,
                                maxScale: 4,
                                clipBehavior: Clip.none,
                                panEnabled: true,
                                scaleEnabled: true,
                                child: Image.memory(
                                  attachments[index].bytes,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (attachments.length > 1) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 66,
                      child: ListView.separated(
                        controller: _thumbController,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        itemCount: attachments.length,
                        separatorBuilder: (_, __) => const SizedBox(
                          width: _DailyPreviewMetrics.thumbGap,
                        ),
                        itemBuilder: (context, index) {
                          final selected = index == _currentIndex;
                          return GestureDetector(
                            onTap: () => _selectPhoto(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              width: selected
                                  ? _DailyPreviewMetrics.thumbWidth + 8
                                  : _DailyPreviewMetrics.thumbWidth,
                              height: _DailyPreviewMetrics.thumbHeight,
                              padding: EdgeInsets.all(selected ? 2 : 0),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withValues(
                                    alpha: selected ? 0.88 : 0,
                                  ),
                                  width: selected ? 2 : 0,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: AnimatedOpacity(
                                  opacity: selected ? 1 : 0.62,
                                  duration: const Duration(milliseconds: 180),
                                  child: Image.memory(
                                    attachments[index].bytes,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    '反馈截图 · 第 ${_currentIndex + 1} 张',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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

class _LegalDocumentPage extends StatefulWidget {
  const _LegalDocumentPage({required this.title, required this.assetPath});

  final String title;
  final String assetPath;

  @override
  State<_LegalDocumentPage> createState() => _LegalDocumentPageState();
}

class _LegalDocumentPageState extends State<_LegalDocumentPage> {
  late final Future<String> _textFuture = rootBundle.loadString(
    widget.assetPath,
  );

  @override
  Widget build(BuildContext context) {
    return _SettingsSubScaffold(
      title: widget.title,
      child: FutureBuilder<String>(
        future: _textFuture,
        builder: (context, snapshot) {
          final text = snapshot.data;
          if (text == null) {
            return Center(
              child: CupertinoActivityIndicator(
                color: _SettingsColors.blueDark,
              ),
            );
          }
          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _settingsCardDecoration(),
                child: Text(
                  text,
                  style: TextStyle(
                    color: _SettingsColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                    height: 1.62,
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
