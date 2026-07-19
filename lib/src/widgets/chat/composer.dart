part of 'package:companion_flutter/main.dart';

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.height,
    required this.activePanel,
    required this.voiceInputMode,
    required this.sending,
    required this.preparingVoice,
    required this.recordingVoice,
    required this.transcribingVoice,
    required this.resolvingLink,
    required this.pendingImages,
    required this.pendingLink,
    required this.authToken,
    required this.onFocusInput,
    required this.onToggleEmoji,
    required this.onShowKeyboard,
    required this.onToggleMore,
    required this.onToggleVoiceInput,
    required this.onSend,
    required this.onVoicePressStart,
    required this.onVoicePressMove,
    required this.onVoicePressEnd,
    required this.onVoicePressCancel,
    required this.onRemoveImage,
    required this.onPreviewImage,
    required this.onRemoveLink,
    required this.onPreviewLink,
    required this.onPasteText,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final double height;
  final ComposerPanel activePanel;
  final bool voiceInputMode;
  final bool sending;
  final bool preparingVoice;
  final bool recordingVoice;
  final bool transcribingVoice;
  final bool resolvingLink;
  final List<_PendingChatImage> pendingImages;
  final _PendingLinkPreview? pendingLink;
  final String? authToken;
  final VoidCallback onFocusInput;
  final VoidCallback onToggleEmoji;
  final VoidCallback onShowKeyboard;
  final VoidCallback onToggleMore;
  final VoidCallback onToggleVoiceInput;
  final VoidCallback onSend;
  final ValueChanged<Offset> onVoicePressStart;
  final ValueChanged<Offset> onVoicePressMove;
  final ValueChanged<Offset> onVoicePressEnd;
  final VoidCallback onVoicePressCancel;
  final ValueChanged<String> onRemoveImage;
  final ValueChanged<_PendingChatImage> onPreviewImage;
  final VoidCallback onRemoveLink;
  final ValueChanged<_PendingLinkPreview> onPreviewLink;
  final Future<bool> Function(String text) onPasteText;

  @override
  Widget build(BuildContext context) {
    final voiceActive = preparingVoice || recordingVoice || transcribingVoice;
    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: const BoxDecoration(color: Color(0xFFF6FDFC)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canShowAttachmentStrip =
              constraints.maxHeight >= 118 &&
              (pendingImages.isNotEmpty || pendingLink != null);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canShowAttachmentStrip) ...[
                _ComposerAttachmentStrip(
                  images: pendingImages,
                  link: pendingLink,
                  onRemoveImage: onRemoveImage,
                  onPreviewImage: onPreviewImage,
                  onRemoveLink: onRemoveLink,
                  onPreviewLink: onPreviewLink,
                  authToken: authToken,
                ),
                const SizedBox(height: 8),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _VoiceInputToggleButton(
                    enabled: !voiceActive,
                    voiceMode: voiceInputMode,
                    onTap: onToggleVoiceInput,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: voiceInputMode
                        ? _VoiceHoldToTalkButton(
                            enabled:
                                !transcribingVoice &&
                                (preparingVoice || recordingVoice || !sending),
                            preparing: preparingVoice,
                            recording: recordingVoice,
                            transcribing: transcribingVoice,
                            onStart: onVoicePressStart,
                            onMove: onVoicePressMove,
                            onEnd: onVoicePressEnd,
                            onCancel: onVoicePressCancel,
                          )
                        : AnimatedBuilder(
                            animation: focusNode,
                            builder: (context, child) {
                              final focused = focusNode.hasFocus;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                constraints: BoxConstraints(
                                  minHeight: 36,
                                  maxHeight: resolvingLink ? 36 : 86,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: focused
                                        ? chatVoiceAccent
                                        : AppColors.hairline,
                                    width: focused ? 1.5 : 1,
                                  ),
                                ),
                                child: child,
                              );
                            },
                            child: TextField(
                              controller: controller,
                              focusNode: focusNode,
                              cursorColor: chatVoiceAccent,
                              minLines: 1,
                              maxLines: resolvingLink ? 1 : 3,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              onTap: onFocusInput,
                              contextMenuBuilder: _buildContextMenu,
                              decoration: InputDecoration(
                                hintText: '发消息...',
                                hintStyle: const TextStyle(
                                  color: Color(0xFFBFBFBF),
                                  fontSize: 12,
                                ),
                                // The surrounding AnimatedContainer draws the
                                // only border (green when focused). Explicitly
                                // clear the themed enabled/focused borders too:
                                // `border` alone does not override them, which
                                // leaked the global blue focusedBorder and
                                // produced a second border layer.
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                isDense: true,
                                prefixIcon: resolvingLink
                                    ? Center(
                                        child: CupertinoActivityIndicator(
                                          radius: 7,
                                          color: AppColors.accent,
                                        ),
                                      )
                                    : null,
                                prefixIconConstraints: resolvingLink
                                    ? const BoxConstraints(
                                        minWidth: 34,
                                        maxWidth: 34,
                                        minHeight: 24,
                                        maxHeight: 24,
                                      )
                                    : null,
                                contentPadding: const EdgeInsets.fromLTRB(
                                  14,
                                  7,
                                  14,
                                  7,
                                ),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  _RoundIconButton(
                    tooltip: activePanel == ComposerPanel.emoji ? '键盘' : '表情',
                    icon: activePanel == ComposerPanel.emoji
                        ? CupertinoIcons.keyboard
                        : CupertinoIcons.smiley,
                    selected: activePanel == ComposerPanel.emoji,
                    green: activePanel == ComposerPanel.emoji,
                    onTap: voiceActive
                        ? null
                        : activePanel == ComposerPanel.emoji
                        ? onShowKeyboard
                        : onToggleEmoji,
                  ),
                  const SizedBox(width: 10),
                  AnimatedBuilder(
                    animation: controller,
                    builder: (context, _) {
                      final canSend =
                          controller.text.trim().isNotEmpty ||
                          pendingImages.isNotEmpty ||
                          pendingLink != null;
                      if (canSend) {
                        return FilledButton(
                          onPressed: sending ? null : onSend,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(58, 38),
                            padding: EdgeInsets.zero,
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(19),
                            ),
                          ),
                          child: Text(sending ? '...' : '发送'),
                        );
                      }
                      return _RoundIconButton(
                        tooltip: '更多',
                        icon: activePanel == ComposerPanel.more
                            ? CupertinoIcons.xmark
                            : CupertinoIcons.plus,
                        selected: activePanel == ComposerPanel.more,
                        prominent: activePanel != ComposerPanel.more,
                        green: true,
                        onTap: voiceActive ? null : onToggleMore,
                      );
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    final items = editableTextState.contextMenuButtonItems
        .map(
          (item) => item.type == ContextMenuButtonType.paste
              ? ContextMenuButtonItem(
                  type: item.type,
                  label: item.label,
                  onPressed: () {
                    editableTextState.hideToolbar();
                    unawaited(_handlePasteFromToolbar());
                  },
                )
              : item,
        )
        .toList();
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: items,
    );
  }

  Future<void> _handlePasteFromToolbar() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    final consumed = await onPasteText(text);
    if (!consumed) {
      _insertPlainTextAtSelection(text);
    }
  }

  void _insertPlainTextAtSelection(String text) {
    final value = controller.value;
    final currentText = value.text;
    final selection = value.selection;
    final start = selection.isValid
        ? math.min(selection.start, selection.end).clamp(0, currentText.length)
        : currentText.length;
    final end = selection.isValid
        ? math.max(selection.start, selection.end).clamp(0, currentText.length)
        : currentText.length;
    final nextText = currentText.replaceRange(start, end, text);
    controller.value = value.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: start + text.length),
      composing: TextRange.empty,
    );
  }
}

class _VoiceInputToggleButton extends StatelessWidget {
  const _VoiceInputToggleButton({
    required this.enabled,
    required this.voiceMode,
    required this.onTap,
  });

  final bool enabled;
  final bool voiceMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: voiceMode ? '键盘' : '语音',
      child: Semantics(
        button: true,
        label: voiceMode ? '切换到键盘输入' : '切换到语音输入',
        child: InkResponse(
          onTap: enabled ? onTap : null,
          radius: 23,
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(color: AppColors.hairline),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Icon(
                voiceMode ? CupertinoIcons.keyboard : CupertinoIcons.mic,
                key: ValueKey(voiceMode),
                size: 20,
                color: enabled ? AppColors.text : AppColors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceHoldToTalkButton extends StatelessWidget {
  const _VoiceHoldToTalkButton({
    required this.enabled,
    required this.preparing,
    required this.recording,
    required this.transcribing,
    required this.onStart,
    required this.onMove,
    required this.onEnd,
    required this.onCancel,
  });

  final bool enabled;
  final bool preparing;
  final bool recording;
  final bool transcribing;
  final ValueChanged<Offset> onStart;
  final ValueChanged<Offset> onMove;
  final ValueChanged<Offset> onEnd;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final label = preparing
        ? '正在准备…'
        : recording
        ? '松开发送'
        : '按住说话';
    return Semantics(
      button: true,
      enabled: enabled,
      label: transcribing ? '正在转写语音' : label,
      child: VoiceHoldGestureRegion(
        enabled: enabled,
        onStart: onStart,
        onMove: onMove,
        onEnd: onEnd,
        onCancel: onCancel,
        child: AnimatedContainer(
          key: const ValueKey('hold-to-talk-button'),
          duration: const Duration(milliseconds: 120),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: recording ? chatVoiceAccentSoft : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: recording
                  ? chatVoiceAccent.withValues(alpha: 0.56)
                  : AppColors.hairline,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (preparing) ...[
                const CupertinoActivityIndicator(
                  radius: 7,
                  color: chatVoiceAccentDeep,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: enabled || recording || transcribing
                      ? AppColors.text
                      : AppColors.muted,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComposerAttachmentStrip extends StatelessWidget {
  const _ComposerAttachmentStrip({
    required this.images,
    required this.link,
    required this.onRemoveImage,
    required this.onPreviewImage,
    required this.onRemoveLink,
    required this.onPreviewLink,
    required this.authToken,
  });

  final List<_PendingChatImage> images;
  final _PendingLinkPreview? link;
  final ValueChanged<String> onRemoveImage;
  final ValueChanged<_PendingChatImage> onPreviewImage;
  final VoidCallback onRemoveLink;
  final ValueChanged<_PendingLinkPreview> onPreviewLink;
  final String? authToken;

  @override
  Widget build(BuildContext context) {
    final leadingCount = link != null ? 1 : 0;
    final itemCount = images.length + leadingCount;
    return SizedBox(
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final pendingLink = link;
          if (pendingLink != null && index == 0) {
            return _ComposerLinkTile(
              link: pendingLink,
              onRemove: onRemoveLink,
              onTap: () => onPreviewLink(pendingLink),
              authToken: authToken,
            );
          }
          final imageIndex = leadingCount == 0 ? index : index - 1;
          final image = images[imageIndex];
          return _ComposerImageTile(
            image: image,
            onRemove: () => onRemoveImage(image.attachment.id),
            onPreview: () => onPreviewImage(image),
          );
        },
      ),
    );
  }
}

class _ComposerImageTile extends StatelessWidget {
  const _ComposerImageTile({
    required this.image,
    required this.onRemove,
    required this.onPreview,
  });

  final _PendingChatImage image;
  final VoidCallback onRemove;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onPreview,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(image.localPath),
              width: 70,
              height: 70,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: _ComposerRemoveButton(onTap: onRemove),
        ),
      ],
    );
  }
}

class _ComposerLinkTile extends StatelessWidget {
  const _ComposerLinkTile({
    required this.link,
    required this.onRemove,
    required this.onTap,
    required this.authToken,
  });

  final _PendingLinkPreview link;
  final VoidCallback onRemove;
  final VoidCallback onTap;
  final String? authToken;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final card = link.preview.componentCard;
    final accent = _composerLinkAccent(card.accent);
    final platform = _composerLinkPlatformName(link);
    final body = _composerLinkBody(link);
    final imageUrl = (link.preview.imageUrl ?? card.payload['image_url'])
        ?.toString()
        .trim();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Tooltip(
          message: link.sourceText,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 228,
              height: 70,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accent.withValues(alpha: 0.28)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            headers: _mediaHeadersForUrl(imageUrl, authToken),
                            width: 54,
                            height: 54,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _ComposerLinkFallbackIcon(accent: accent),
                          )
                        : _ComposerLinkFallbackIcon(accent: accent),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          platform,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          body,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.text,
                            fontSize: 13,
                            height: 1.18,
                            fontWeight: FontWeight.w800,
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
        Positioned(
          top: -6,
          right: -6,
          child: _ComposerRemoveButton(onTap: onRemove),
        ),
      ],
    );
  }
}

String _composerLinkPlatformName(_PendingLinkPreview link) {
  final platform = link.preview.platform.trim();
  if (platform.isNotEmpty) return platform;
  final payloadPlatform = link.preview.componentCard.payload['platform']
      ?.toString()
      .trim();
  if (payloadPlatform != null && payloadPlatform.isNotEmpty) {
    return payloadPlatform;
  }
  return '链接';
}

String _composerLinkBody(_PendingLinkPreview link) {
  final card = link.preview.componentCard;
  for (final value in [
    card.payload['original_text'],
    card.payload['content_text'],
    card.body,
    card.payload['summary'],
    link.preview.summary,
    link.preview.description,
    link.preview.title,
    link.sourceText,
  ]) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty && text != _composerLinkPlatformName(link)) {
      return text;
    }
  }
  return link.sourceText;
}

class _ComposerLinkFallbackIcon extends StatelessWidget {
  const _ComposerLinkFallbackIcon({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      color: accent.withValues(alpha: 0.12),
      child: Icon(CupertinoIcons.link, color: accent, size: 21),
    );
  }
}

class _ComposerRemoveButton extends StatelessWidget {
  const _ComposerRemoveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: const Color(0xE6000000),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 13),
      ),
    );
  }
}

Color _composerLinkAccent(String value) {
  final hex = value.replaceFirst('#', '').trim();
  final parsed = hex.length == 6 ? int.tryParse(hex, radix: 16) : null;
  return parsed == null ? AppColors.accent : Color(0xFF000000 | parsed);
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.selected = false,
    this.prominent = false,
    this.green = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;
  final bool selected;
  final bool prominent;
  final bool green;

  @override
  Widget build(BuildContext context) {
    const figmaGreen = Color(0xFF06C893);
    const figmaGreenLight = Color(0xFF24D7D3);
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 23,
        child: Container(
          width: prominent ? 30 : 38,
          height: prominent ? 30 : 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected
                ? null
                : prominent
                ? (green ? figmaGreen : AppColors.accent)
                : AppColors.surface,
            gradient: selected && !prominent
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: green
                        ? [figmaGreen, figmaGreenLight]
                        : [AppColors.accentDeep, AppColors.accentCyan],
                  )
                : null,
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.28)
                  : prominent
                  ? Colors.transparent
                  : AppColors.hairline,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: (green ? figmaGreen : AppColors.accent).withValues(
                        alpha: 0.18,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: prominent ? 22 : 21,
            color: onTap == null
                ? const Color(0xFFC8CECD)
                : selected
                ? Colors.white
                : prominent
                ? Colors.white
                : AppColors.text,
          ),
        ),
      ),
    );
  }
}
