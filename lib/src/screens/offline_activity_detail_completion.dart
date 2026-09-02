part of 'package:companion_flutter/main.dart';

class _CompletionComposer extends StatelessWidget {
  const _CompletionComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.photos,
    required this.voice,
    required this.uploadingPhoto,
    required this.uploadingVoice,
    required this.recording,
    required this.recordSeconds,
    required this.voicePlaying,
    required this.working,
    required this.onPickGallery,
    required this.onTakePhoto,
    required this.onRemove,
    required this.onToggleRecord,
    required this.onToggleVoice,
    required this.onRemoveVoice,
    required this.onComplete,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<_ActivityCompletionImage> photos;
  final _ActivityCompletionVoice? voice;
  final bool uploadingPhoto;
  final bool uploadingVoice;
  final bool recording;
  final int recordSeconds;
  final bool voicePlaying;
  final bool working;
  final VoidCallback onPickGallery;
  final VoidCallback onTakePhoto;
  final ValueChanged<_ActivityCompletionImage> onRemove;
  final VoidCallback onToggleRecord;
  final VoidCallback onToggleVoice;
  final VoidCallback onRemoveVoice;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
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
              placeholder: '写一点感受，也可以直接拍照或录一小段声音...',
              placeholderStyle: TextStyle(
                color: w.inkSoft,
                decoration: TextDecoration.none,
              ),
              style: TextStyle(color: w.ink, decoration: TextDecoration.none),
              padding: const EdgeInsets.all(16),
              textInputAction: TextInputAction.newline,
              // 玻璃输入框：半透明白玻璃衬在 sheet 的极光底上，聚焦时描边收成
              // 活动主题蓝(与入口卡片蓝一致)。
              decoration: BoxDecoration(
                color: w.glass,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: focusNode.hasFocus
                      ? _kActivityAccent.withValues(alpha: 0.55)
                      : w.glassBorder,
                ),
                boxShadow: w.panelShadow,
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _CompletionActionToolbar(
          photoCount: photos.length,
          hasVoice: voice != null,
          recording: recording,
          recordSeconds: recordSeconds,
          uploadingPhoto: uploadingPhoto,
          uploadingVoice: uploadingVoice,
          onPickGallery: onPickGallery,
          onTakePhoto: onTakePhoto,
          onToggleRecord: onToggleRecord,
        ),
        if (photos.isNotEmpty) ...[
          const SizedBox(height: 12),
          _CompletionPhotoPicker(photos: photos, onRemove: onRemove),
        ],
        if (voice != null || uploadingVoice || recording) ...[
          const SizedBox(height: 12),
          _ActivityVoiceChip(
            label: recording
                ? '录音中 ${_formatActivityDuration(recordSeconds)}'
                : uploadingVoice
                ? '正在保存语音...'
                : '语音 ${_formatActivityDuration(voice?.durationSeconds)}',
            playing: voicePlaying,
            busy: uploadingVoice,
            recording: recording,
            onPlay: voice == null ? null : onToggleVoice,
            onRemove: voice == null ? null : onRemoveVoice,
          ),
        ],
        const SizedBox(height: 16),
        _CompletionSubmitButton(
          busy: working,
          onPressed: (working || uploadingPhoto || uploadingVoice || recording)
              ? null
              : onComplete,
        ),
      ],
    );
  }
}

/// 与天气/打卡/胶囊页主按钮同一套设计：整宽胶囊 + 主题色填充 + 柔和投影，白字
/// 20/w600；忙碌转圈；禁用变淡去掉投影。活动页主调是蓝色(与入口卡片一致)。
class _CompletionSubmitButton extends StatelessWidget {
  const _CompletionSubmitButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    const base = _kActivityAccent;
    final enabled = onPressed != null && !busy;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size.fromHeight(52),
      borderRadius: BorderRadius.circular(999),
      onPressed: enabled ? onPressed : null,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? base : base.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: base.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(2, 8),
                  ),
                ]
              : null,
        ),
        child: busy
            ? const CupertinoActivityIndicator(color: Colors.white)
            : const Text(
                '完成并分享',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
      ),
    );
  }
}

class _CompletionActionToolbar extends StatelessWidget {
  const _CompletionActionToolbar({
    required this.photoCount,
    required this.hasVoice,
    required this.recording,
    required this.recordSeconds,
    required this.uploadingPhoto,
    required this.uploadingVoice,
    required this.onPickGallery,
    required this.onTakePhoto,
    required this.onToggleRecord,
  });

  final int photoCount;
  final bool hasVoice;
  final bool recording;
  final int recordSeconds;
  final bool uploadingPhoto;
  final bool uploadingVoice;
  final VoidCallback onPickGallery;
  final VoidCallback onTakePhoto;
  final VoidCallback onToggleRecord;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CompletionToolButton(
          icon: CupertinoIcons.photo,
          label: '相册',
          enabled: photoCount < 3 && !uploadingPhoto,
          onTap: onPickGallery,
        ),
        const SizedBox(width: 10),
        _CompletionToolButton(
          icon: CupertinoIcons.camera,
          label: '拍照',
          enabled: photoCount < 3 && !uploadingPhoto,
          onTap: onTakePhoto,
        ),
        const SizedBox(width: 10),
        // 不再用 Expanded 把录语音撑到最右、留一大段空隙；跟相册/拍照一样按
        // 内容宽度、10 的间距左对齐排列。
        _CompletionToolButton(
          icon: recording ? CupertinoIcons.stop_fill : CupertinoIcons.mic,
          label: recording
              ? '停止 ${_formatActivityDuration(recordSeconds)}'
              : hasVoice
              ? '重录语音'
              : '录语音',
          enabled: !uploadingVoice,
          emphasized: recording,
          onTap: onToggleRecord,
        ),
      ],
    );
  }
}

class _CompletionToolButton extends StatelessWidget {
  const _CompletionToolButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final bool emphasized;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final w = _W2b.resolve(context);
    // 录音强调态保留暖红作为"正在录音"的警示色；其余用活动主题蓝。
    final fg = emphasized ? const Color(0xFFFF6E4A) : _kActivityAccent;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        // 玻璃药丸：录音强调态用暖桃底，其余半透明白玻璃，跟 sheet 里其他玻璃
        // 元素统一。
        decoration: BoxDecoration(
          color: emphasized ? const Color(0xFFFFE9E2) : w.glass,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: emphasized
                ? const Color(0xFFFFB39E).withValues(alpha: 0.82)
                : w.glassBorder,
          ),
          boxShadow: [w.pillShadow],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: enabled ? fg : colors.muted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: enabled ? fg : colors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

void _showActivityToast(BuildContext context, String message) {
  showCupertinoDialog<void>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      content: Text(message),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}
