part of 'package:companion_flutter/main.dart';

/// 聊天页顶部「进行中活动」任务条（交互手册：顶栏 →（可选）任务条 → 消息流）。
/// 玻璃风格对齐天气/胶囊（_W2b 令牌 + _softCardDecoration）。点击进打卡页；
/// 左滑露出「取消」（spec §4.2），点击「取消」走确认后收起。仅在已到达时挂载。
class _ChatActivityTaskBar extends StatelessWidget {
  const _ChatActivityTaskBar({
    super.key,
    required this.activity,
    required this.onTap,
  });

  final OfflineActivity activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    final place = (activity.locationName?.trim().isNotEmpty ?? false)
        ? activity.locationName!.trim()
        : activity.title;
    // 只有状态条本身：一枚磨砂玻璃药丸，上下左右皆透明背景（chat 底色透出）。
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: w.glass,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: w.glassBorder),
                boxShadow: w.panelShadow,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _kActivityAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '进行中',
                      style: TextStyle(
                        color: _kActivityAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      place,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: w.ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '查看进度',
                    style: TextStyle(
                      color: w.inkSoft,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 17, color: w.inkSoft),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hosts composer + emoji/more panel + keyboard tracking without rebuilding
/// the message list column on every [MediaQuery.viewInsets] tick.
class _ChatInputChromeLayer extends StatefulWidget {
  const _ChatInputChromeLayer({required this.host});

  final _ChatPageState host;

  @override
  State<_ChatInputChromeLayer> createState() => _ChatInputChromeLayerState();
}

class _ChatInputChromeLayerState extends State<_ChatInputChromeLayer> {
  _ChatPageState get _host => widget.host;

  @override
  Widget build(BuildContext context) {
    final occupancyPanel = _host._panel != ComposerPanel.none
        ? _host._panel
        : _host._heldPanel;
    final paintedPanel = _host._panel;
    final occupancyPanelHeight = _host._panelHeightFor(occupancyPanel);
    final composerHeight = _host._composerHeightForWidth();
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    final tabBarLift = _ChatPageState._tabBarContentHeight + safeBottom;
    final panelVisible = paintedPanel != ComposerPanel.none;
    final panelSurfaceHeight =
        ChatScrollPolicy.keepPanelOccupancy(
          panelOpen: panelVisible,
          holdingOccupancy: _host._heldPanel != ComposerPanel.none,
        )
        ? occupancyPanelHeight + safeBottom
        : 0.0;
    final panelContentHeight = _ChatPageState._composerPanelHeight + safeBottom;
    if (panelVisible) {
      _host._lastDisplayedPanel = paintedPanel;
    }
    final displayedPanel = panelVisible
        ? paintedPanel
        : _host._lastDisplayedPanel;
    final restLift = ChatScrollPolicy.restLift(
      tabBarLift: tabBarLift,
      panelLift: panelSurfaceHeight,
    );
    _host._syncComposerDockVisibility(
      panelVisible: panelVisible || _host._heldPanel != ComposerPanel.none,
    );

    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: composerHeight + restLift,
          child: const IgnorePointer(
            child: ColoredBox(color: Color(0xFFF6FDFC)),
          ),
        ),
        Positioned.fill(
          child: _ImeChromeFollower(
            host: _host,
            restLift: restLift,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: RepaintBoundary(
                    child: _Composer(
                      controller: _host._inputController,
                      focusNode: _host._inputFocus,
                      height: composerHeight,
                      activePanel: _host._panel,
                      voiceInputMode: _host._voiceInputMode,
                      sending:
                          _host._sending ||
                          _host._uploadingImage ||
                          _host._preparingVoice ||
                          _host._recordingVoice ||
                          _host._transcribingVoice,
                      preparingVoice: _host._preparingVoice,
                      recordingVoice: _host._recordingVoice,
                      transcribingVoice: _host._transcribingVoice,
                      resolvingLink:
                          _host._linkPreviewInFlightText != null &&
                          _host._pendingLinkPreview == null,
                      pendingImages: _host._pendingImages,
                      pendingLink: _host._pendingLinkPreview,
                      authToken: _host.widget.api.authToken,
                      onFocusInput: _host._focusInput,
                      onToggleEmoji: () => _host._setPanel(ComposerPanel.emoji),
                      onShowKeyboard: _host._focusInput,
                      onToggleMore: () => _host._setPanel(ComposerPanel.more),
                      onToggleVoiceInput: _host._toggleVoiceInputMode,
                      onSend: _host._sendMessage,
                      onVoicePressStart: _host._handleVoicePressStart,
                      onVoicePressMove: _host._handleVoicePressMove,
                      onVoicePressEnd: _host._handleVoicePressEnd,
                      onVoicePressCancel: _host._handleVoicePressCancel,
                      onRemoveImage: _host._removePendingImage,
                      onPreviewImage: _host._previewPendingImage,
                      onRemoveLink: _host._removePendingLink,
                      onPreviewLink: _host._openPendingLink,
                      onPasteText: _host._handleComposerPasteText,
                      freeMessagesRemaining: _host._composerQuotaBadgeCount,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom:
                      composerHeight + ChatScrollPolicy.aiGeneratedHintHeight,
                  child: _host._buildTranscriptOverlay(),
                ),
              ],
            ),
          ),
        ),
        AnimatedPositioned(
          left: 0,
          right: 0,
          bottom: panelVisible ? 0 : -panelContentHeight,
          height: panelContentHeight,
          // Snap away when the IME is coming up so the sheet is not left
          // painted under the keyboard. User-dismiss (tap transcript) still
          // slides off.
          duration: panelVisible || !_host._imeDockActive
              ? _ChatPageState._animationDuration
              : Duration.zero,
          curve: _ChatPageState._animationCurve,
          onEnd: () {
            if (!panelVisible &&
                mounted &&
                _host._lastDisplayedPanel != ComposerPanel.none) {
              _host._lastDisplayedPanel = ComposerPanel.none;
              _host._bumpComposerShell();
            }
          },
          child: ClipRect(
            child: _ChatPanel(
              panel: displayedPanel,
              bottomInset: safeBottom,
              onEmojiTap: _host._appendEmoji,
              onPickPhoto: () =>
                  unawaited(_host._pickChatImage(ImageSource.gallery)),
              onTakePhoto: () =>
                  unawaited(_host._pickChatImage(ImageSource.camera)),
              onSendRedPacket: () => unawaited(_host._onSendRedPacket()),
              onSendGift: () => unawaited(_host._onSendGift()),
              onSendLocation: () => unawaited(_host._onSendLocation()),
              onSearch: () => unawaited(_host._openChatSearch()),
            ),
          ),
        ),
      ],
    );
  }
}

/// Moves the stable composer/overlay subtree as a retained repaint boundary.
/// IME metrics rebuild this tiny AnimatedBuilder, never the composer, message
/// list, or shell.
class _ImeChromeFollower extends StatefulWidget {
  const _ImeChromeFollower({
    required this.host,
    required this.restLift,
    required this.child,
  });

  final _ChatPageState host;
  final double restLift;
  final Widget child;

  @override
  State<_ImeChromeFollower> createState() => _ImeChromeFollowerState();
}

class _ImeChromeFollowerState extends State<_ImeChromeFollower>
    with SingleTickerProviderStateMixin {
  late final AnimationController _restController;
  late double _restStart;
  late double _restEnd;
  double _lastKeyboardInset = 0;
  bool _imeClosedScheduled = false;

  double get _animatedRestLift {
    final progress = _ChatPageState._animationCurve.transform(
      _restController.value,
    );
    return lerpDouble(_restStart, _restEnd, progress)!;
  }

  @override
  void initState() {
    super.initState();
    _restStart = widget.restLift;
    _restEnd = widget.restLift;
    _restController = AnimationController(
      vsync: this,
      duration: _ChatPageState._animationDuration,
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant _ImeChromeFollower oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.restLift == widget.restLift) return;
    _restStart = _animatedRestLift;
    _restEnd = widget.restLift;
    if (_lastKeyboardInset > 0) {
      _restController.value = 1;
    } else {
      _restController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _restController.dispose();
    super.dispose();
  }

  void _scheduleImeClosedIfNeeded(double bottomInset) {
    if (bottomInset > 0.5) {
      _imeClosedScheduled = false;
      return;
    }
    final host = widget.host;
    if (host._inputFocus.hasFocus) return;
    if (!host._imeDockActive && host._heldPanel == ComposerPanel.none) {
      return;
    }
    if (_imeClosedScheduled) return;
    _imeClosedScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _imeClosedScheduled = false;
      if (!mounted) return;
      if (MediaQuery.viewInsetsOf(context).bottom > 0.5) return;
      widget.host._onImeFullyClosed();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _restController,
      child: RepaintBoundary(child: widget.child),
      builder: (context, child) {
        final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
        final composerBottom = math.max(bottomInset, _animatedRestLift);
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final snapped = (composerBottom * dpr).round() / dpr;
        _lastKeyboardInset = bottomInset;
        _scheduleImeClosedIfNeeded(bottomInset);
        return Transform.translate(offset: Offset(0, -snapped), child: child);
      },
    );
  }
}
