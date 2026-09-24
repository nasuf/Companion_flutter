part of 'package:companion_flutter/main.dart';

/// Rebuilds the message list when the transcript or viewport shell changes.
/// Composer rest-gap and keyboard motion are derived locally so chrome build
/// never has to notify a sibling while the framework is already building.
class _ChatMessageViewport extends StatefulWidget {
  const _ChatMessageViewport({
    required this.host,
    required this.transcript,
    required this.shellListenable,
    required this.typingVisible,
    required this.scrollController,
    required this.topPadding,
  });

  final _ChatPageState host;
  final ChatTranscriptController transcript;
  final ValueListenable<int> shellListenable;
  final ValueListenable<bool> typingVisible;
  final ScrollController scrollController;
  final double topPadding;

  @override
  State<_ChatMessageViewport> createState() => _ChatMessageViewportState();
}

class _ChatMessageViewportState extends State<_ChatMessageViewport> {
  @override
  void initState() {
    super.initState();
    widget.transcript.addListener(_onTranscriptChanged);
    widget.shellListenable.addListener(_onShellChanged);
  }

  @override
  void didUpdateWidget(covariant _ChatMessageViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transcript != widget.transcript) {
      oldWidget.transcript.removeListener(_onTranscriptChanged);
      widget.transcript.addListener(_onTranscriptChanged);
    }
    if (oldWidget.shellListenable != widget.shellListenable) {
      oldWidget.shellListenable.removeListener(_onShellChanged);
      widget.shellListenable.addListener(_onShellChanged);
    }
  }

  @override
  void dispose() {
    widget.transcript.removeListener(_onTranscriptChanged);
    widget.shellListenable.removeListener(_onShellChanged);
    super.dispose();
  }

  void _onTranscriptChanged() {
    setState(() {});
  }

  void _onShellChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final host = widget.host;
    final transcript = widget.transcript;
    return Column(
      children: [
        if (transcript.historyError != null)
          _InlineBanner(
            text: transcript.historyError!,
            onRetry: () => host._loadLatestMessages(showLoading: true),
          ),
        Expanded(
          child: _TranscriptImeSlide(
            host: host,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: host._dismissInputSurfaces,
              child: transcript.loadingInitial
                  ? const Center(child: CircularProgressIndicator())
                  : _MessageList(
                      controller: widget.scrollController,
                      messages: transcript.messages,
                      isLoadingOlder: transcript.loadingOlder,
                      trackPlaybackUpdates: host.widget.isActive,
                      bottomGap: _ComposerRestGap(host: host),
                      typingVisible: widget.typingVisible,
                      topPadding: widget.topPadding,
                      onComponentCardTap: host._openComponentCard,
                      onAchievementTap: host._openAchievementDetail,
                      onResolveMusicTrack: host._resolveMusicTrack,
                      onMusicCardActivated: host._activateMusicStationCard,
                      onMusicPrevious: () =>
                          unawaited(host._playPreviousStationTrack()),
                      onMusicNext: () =>
                          unawaited(host._playNextStationTrack()),
                      onMusicFavorite: (track) =>
                          unawaited(host._toggleMusicFavorite(track)),
                      onAttachmentTap: host._previewAttachment,
                      activeMusicMessageId: host._musicStation.activeMessageId,
                      musicCardPositions: host._musicStation.cardPositions,
                      favoriteMusicTrackIds: host._favoriteMusicTrackIds,
                      busyMusicFavoriteIds: host._busyMusicFavoriteIds,
                      canGoMusicPrevious: host._canGoStationPrevious,
                      isMusicBusy: host._advancingStation,
                      stationMessageId: host._musicStation.messageId,
                      stationMessageKey: host._stationCardKey,
                      highlightMessageId: transcript.highlightMessageId,
                      highlightVisible: transcript.highlightVisible,
                      highlightQuery: transcript.highlightQuery,
                      highlightMessageKey: host._highlightMessageKey,
                      agentAvatarUrl: host._agentAvatarUrl,
                      userAvatarUrl: host.widget.session.userAvatarUrl,
                      authToken: host.widget.api.authToken,
                      apiBaseUrl: host.widget.api.baseUrl,
                      onRetryFailed: host._retryFailedMessage,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Composites the transcript directly from MediaQuery IME metrics. This widget
/// is the MediaQuery dependent; its stable repaint-boundary [child] is not
/// rebuilt or repainted on IME ticks.
class _TranscriptImeSlide extends StatelessWidget {
  const _TranscriptImeSlide({required this.host, required this.child});

  final _ChatPageState host;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: ListenableBuilder(
        listenable: host._composerShell,
        builder: (context, child) {
          final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
          final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
          final occupancyPanel = host._panel != ComposerPanel.none
              ? host._panel
              : host._heldPanel;
          final panelLift =
              ChatScrollPolicy.keepPanelOccupancy(
                panelOpen: host._panel != ComposerPanel.none,
                holdingOccupancy: host._heldPanel != ComposerPanel.none,
              )
              ? host._panelHeightFor(occupancyPanel) + safeBottom
              : 0.0;
          final restLift = ChatScrollPolicy.restLift(
            tabBarLift: _ChatPageState._tabBarContentHeight + safeBottom,
            panelLift: panelLift,
          );
          final composerBottom = bottomInset > 0
              ? math.max(bottomInset, restLift)
              : restLift;
          final slide = ChatScrollPolicy.imeSlide(
            composerBottom: composerBottom,
            restLift: restLift,
          );
          final dpr = MediaQuery.devicePixelRatioOf(context);
          final snapped = (slide * dpr).round() / dpr;
          final composerHeight = host._composerHeightForWidth();
          // Paint behind the list so bubbles cover the hint; keep it in this
          // slide so it stays glued to the composer through IME motion.
          return Transform.translate(
            offset: Offset(0, -snapped),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: composerHeight + restLift,
                  child: const IgnorePointer(child: _AiGeneratedHint()),
                ),
                if (child != null) child,
              ],
            ),
          );
        },
        child: RepaintBoundary(child: child),
      ),
    );
  }
}

/// Occupies only the composer/tab-bar or composer/panel height. IME height is
/// intentionally excluded because [_TranscriptImeSlide] handles it in paint.
class _ComposerRestGap extends StatelessWidget {
  const _ComposerRestGap({required this.host});

  final _ChatPageState host;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: host._composerShell,
      builder: (context, _) {
        final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
        final occupancyPanel = host._panel != ComposerPanel.none
            ? host._panel
            : host._heldPanel;
        final panelLift =
            ChatScrollPolicy.keepPanelOccupancy(
              panelOpen: host._panel != ComposerPanel.none,
              holdingOccupancy: host._heldPanel != ComposerPanel.none,
            )
            ? host._panelHeightFor(occupancyPanel) + safeBottom
            : 0.0;
        final restLift = ChatScrollPolicy.restLift(
          tabBarLift: _ChatPageState._tabBarContentHeight + safeBottom,
          panelLift: panelLift,
        );
        final gap = ChatScrollPolicy.restComposerGap(
          composerHeight: host._composerHeightForWidth(),
          restLift: restLift,
        );
        return SizedBox(height: gap);
      },
    );
  }
}

class _NewMessagesButton extends StatelessWidget {
  const _NewMessagesButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = count <= 1 ? '有新消息' : '$count 条新消息';
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 16, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.arrow_down,
                color: Colors.white,
                size: 15,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
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

/// Shown in the exact same floating-pill slot as [_NewMessagesButton]
/// (mutually exclusive — a search jump and unread-new-messages never need
/// to compete for it) whenever a chat-search tap has replaced the live tail
/// with a historical window; tapping it resyncs via [_returnToLive].
class _ReturnToLiveButton extends StatelessWidget {
  const _ReturnToLiveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 16, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.arrow_down_circle,
                color: Colors.white,
                size: 15,
              ),
              const SizedBox(width: 6),
              const Text(
                '回到最新消息',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
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
