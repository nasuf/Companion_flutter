part of 'package:companion_flutter/main.dart';

class _ActivityCompletionFeedbackView extends StatefulWidget {
  const _ActivityCompletionFeedbackView({
    required this.feedback,
    required this.api,
    required this.authToken,
  });

  final OfflineActivityCompletionFeedback? feedback;
  final CompanionApi api;
  final String? authToken;

  @override
  State<_ActivityCompletionFeedbackView> createState() =>
      _ActivityCompletionFeedbackViewState();
}

class _ActivityCompletionFeedbackViewState
    extends State<_ActivityCompletionFeedbackView> {
  AudioPlayer? _player;
  bool _playing = false;
  bool _loadingAudio = false;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggleRemoteAudio(ChatAttachment attachment) async {
    if (_loadingAudio) return;
    final player = _player ??= AudioPlayer();
    if (_playing) {
      await player.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }
    setState(() => _loadingAudio = true);
    try {
      final bytes = await widget.api.fetchAuthorizedBytes(attachment.url);
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/offline_activity_play_${attachment.id}.m4a',
      );
      await file.writeAsBytes(bytes, flush: true);
      await player.stop();
      player.onPlayerComplete.first.then((_) {
        if (mounted) setState(() => _playing = false);
      });
      await player.play(DeviceFileSource(file.path));
      if (mounted) setState(() => _playing = true);
    } finally {
      if (mounted) setState(() => _loadingAudio = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.feedback;
    final text = value?.text.trim() ?? '';
    final photos = value?.photoAttachments ?? const <ChatAttachment>[];
    final audio = value?.audioAttachment;
    if (text.isEmpty && photos.isEmpty && audio == null) {
      return const _SoftSuccessBar(text: '✓ 已完成分享');
    }
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SoftSuccessBar(text: '✓ 已完成分享'),
        if (text.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: colors.text,
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
        if (photos.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final photo in photos)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  borderRadius: BorderRadius.circular(18),
                  onPressed: () => _showOfflineActivityImagePreview(
                    context,
                    url: photo.url,
                    authToken: widget.authToken,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(
                      photo.url,
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      headers: _mediaHeadersForUrl(photo.url, widget.authToken),
                      errorBuilder: (_, __, ___) => Container(
                        width: 96,
                        height: 96,
                        color: colors.surfaceMuted,
                        child: Icon(CupertinoIcons.photo, color: colors.muted),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (audio != null) ...[
          const SizedBox(height: 14),
          _ActivityVoiceChip(
            label: '语音 ${_formatActivityDuration(audio.durationSeconds)}',
            playing: _playing,
            busy: _loadingAudio,
            recording: false,
            onPlay: () => _toggleRemoteAudio(audio),
            onRemove: null,
          ),
        ],
      ],
    );
  }
}

Future<void> _showOfflineActivityImagePreview(
  BuildContext context, {
  required String url,
  required String? authToken,
}) async {
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'activity-image-preview',
    barrierColor: Colors.black.withValues(alpha: 0.86),
    pageBuilder: (_, __, ___) {
      final headers = _mediaHeadersForUrl(url, authToken);
      return Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: InteractiveViewer(
                    minScale: 0.7,
                    maxScale: 4,
                    child: Center(
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        headers: headers,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: _RoundIconButton(
                  tooltip: '关闭',
                  icon: CupertinoIcons.xmark,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

String _formatActivityDuration(int? seconds) {
  final value = math.max(1, seconds ?? 1);
  final minutes = value ~/ 60;
  final rest = value % 60;
  if (minutes <= 0) return '$rest 秒';
  return '$minutes:${rest.toString().padLeft(2, '0')}';
}

/// 已完成回顾里的语音播放条（原属完成 composer，随 composer 移除后归入回顾反馈）。
class _ActivityVoiceChip extends StatelessWidget {
  const _ActivityVoiceChip({
    required this.label,
    required this.playing,
    required this.busy,
    required this.recording,
    required this.onPlay,
    required this.onRemove,
  });

  final String label;
  final bool playing;
  final bool busy;
  final bool recording;
  final VoidCallback? onPlay;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final w = _W2b.resolve(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: w.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: w.glassBorder),
        boxShadow: w.panelShadow,
      ),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: busy || recording ? null : onPlay,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: recording
                    ? const Color(0xFFFFE9E2)
                    : colors.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: busy
                  ? const CupertinoActivityIndicator()
                  : Icon(
                      recording
                          ? CupertinoIcons.waveform
                          : playing
                          ? CupertinoIcons.pause_fill
                          : CupertinoIcons.play_fill,
                      size: 17,
                      color: recording
                          ? const Color(0xFFFF6E4A)
                          : colors.accent,
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: w.ink,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          if (onRemove != null)
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: onRemove,
              child: Icon(CupertinoIcons.xmark, size: 18, color: colors.muted),
            ),
        ],
      ),
    );
  }
}
