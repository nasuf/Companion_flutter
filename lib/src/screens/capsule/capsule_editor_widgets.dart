part of 'package:companion_flutter/main.dart';

class _CapsuleLetterPaper extends StatelessWidget {
  const _CapsuleLetterPaper({
    required this.skin,
    required this.controller,
    required this.senderName,
    this.readOnly = false,
  });

  final _CapsuleSkin skin;
  final TextEditingController controller;
  final String senderName;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: skin.paper,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A5568).withValues(alpha: 0.10),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final senderTop = _LetterLinePainter.senderTopForHeight(
              constraints.maxHeight,
              fontSize: 14,
              lineHeight: 1.76,
            );
            return CustomPaint(
              painter: _LetterLinePainter(lineColor: skin.line),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 86),
                      child: TextField(
                        controller: controller,
                        readOnly: readOnly,
                        showCursor: !readOnly,
                        expands: true,
                        minLines: null,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        cursorHeight: 23,
                        cursorColor: skin.accent,
                        style: TextStyle(
                          color: skin.text,
                          fontSize: 17,
                          height: 1.76,
                        ),
                        decoration: InputDecoration(
                          hintText: '我想对未来的我说...',
                          hintStyle: TextStyle(
                            color: skin.muted.withValues(alpha: 0.72),
                            fontSize: 17,
                            height: 1.76,
                          ),
                          filled: false,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: senderTop,
                    right: 20,
                    child: Text(
                      '寄信人：$senderName',
                      style: TextStyle(
                        color: skin.muted,
                        fontSize: 14,
                        height: 1.76,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LetterLinePainter extends CustomPainter {
  const _LetterLinePainter({required this.lineColor});

  static const startY = 50.0;
  static const gap = 30.0;
  static const bottomInset = 24.0;
  static const horizontalInset = 18.0;

  final Color lineColor;

  static double senderTopForHeight(
    double height, {
    required double fontSize,
    required double lineHeight,
  }) {
    final textHeight = fontSize * lineHeight;
    final lastLine =
        startY + ((height - bottomInset - startY) / gap).floor() * gap;
    final previousLine = math.max(startY, lastLine - gap);
    return previousLine + ((lastLine - previousLine - textHeight) / 2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor.withValues(alpha: 0.70)
      ..strokeWidth = 1;
    for (var y = startY; y < size.height - bottomInset; y += gap) {
      canvas.drawLine(
        Offset(horizontalInset, y),
        Offset(size.width - horizontalInset, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LetterLinePainter oldDelegate) {
    return oldDelegate.lineColor != lineColor;
  }
}

class _CapsuleAttachmentStrip extends StatelessWidget {
  const _CapsuleAttachmentStrip({
    required this.image,
    required this.voice,
    required this.accent,
    required this.voicePlaying,
    required this.onOpenImage,
    required this.onRemoveImage,
    required this.onToggleVoice,
    required this.onRemoveVoice,
  });

  final _CapsuleImageAttachment? image;
  final _CapsuleVoiceAttachment? voice;
  final Color accent;
  final bool voicePlaying;
  final VoidCallback? onOpenImage;
  final VoidCallback? onRemoveImage;
  final VoidCallback? onToggleVoice;
  final VoidCallback? onRemoveVoice;

  @override
  Widget build(BuildContext context) {
    if (image == null && voice == null) return const SizedBox.shrink();
    final w = _W2b.resolve(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          height: 66,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: w.glass,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: w.glassBorder, width: 1),
            boxShadow: [w.pillShadow],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (image != null) ...[
                _CapsuleImageThumb(
                  image: image!,
                  onTap: onOpenImage,
                  onRemove: onRemoveImage,
                ),
                if (voice != null) const SizedBox(width: 8),
              ],
              if (voice != null)
                _CapsuleVoiceChip(
                  voice: voice!,
                  accent: accent,
                  playing: voicePlaying,
                  compact: image != null,
                  onTap: onToggleVoice,
                  onRemove: onRemoveVoice,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapsuleImageThumb extends StatelessWidget {
  const _CapsuleImageThumb({
    required this.image,
    required this.onTap,
    required this.onRemove,
  });

  final _CapsuleImageAttachment image;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 54,
      child: Stack(
        children: [
          Positioned.fill(
            child: CupertinoButton(
              minimumSize: Size.zero,
              padding: EdgeInsets.zero,
              onPressed: onTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(
                      image.bytes,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.82),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (onRemove != null)
            Positioned(
              right: 3,
              top: 3,
              child: _CapsuleAttachmentCloseButton(
                onTap: onRemove!,
                elevated: true,
              ),
            ),
        ],
      ),
    );
  }
}

class _CapsuleVoiceChip extends StatelessWidget {
  const _CapsuleVoiceChip({
    required this.voice,
    required this.accent,
    required this.playing,
    required this.compact,
    required this.onTap,
    required this.onRemove,
  });

  final _CapsuleVoiceAttachment voice;
  final Color accent;
  final bool playing;
  final bool compact;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 202 : 238,
      height: 54,
      child: CupertinoButton(
        minimumSize: Size.zero,
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 0, 8, 0),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.075),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  playing ? CupertinoIcons.pause_fill : CupertinoIcons.waveform,
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '语音留言',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${voice.durationSeconds} 秒',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.muted.withValues(alpha: 0.78),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (onRemove != null) ...[
                const SizedBox(width: 6),
                _CapsuleAttachmentCloseButton(onTap: onRemove!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CapsuleAttachmentCloseButton extends StatelessWidget {
  const _CapsuleAttachmentCloseButton({
    required this.onTap,
    this.elevated = false,
  });

  final VoidCallback onTap;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 24,
        height: 24,
        child: Center(
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: elevated
                  ? Colors.black.withValues(alpha: 0.42)
                  : const Color(0xFF8A8790).withValues(alpha: 0.28),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              CupertinoIcons.xmark,
              color: elevated ? Colors.white : const Color(0xFF615D68),
              size: 10.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _CapsuleImageViewer extends StatelessWidget {
  const _CapsuleImageViewer({required this.image});

  final _CapsuleImageAttachment image;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 18, 0),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.chevron_left,
                        color: Colors.white,
                        size: 23,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '胶囊图片',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        Text(
                          image.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.56),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Center(
                  child: Image.memory(image.bytes, fit: BoxFit.contain),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.72),
                  ],
                ),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 54,
                    height: 68,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.memory(image.bytes, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapsuleDatePill extends StatelessWidget {
  const _CapsuleDatePill({required this.openDate, required this.onTap});

  final DateTime? openDate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: w.glass,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: w.glassBorder),
          boxShadow: [w.pillShadow],
        ),
        child: Row(
          children: [
            const Icon(
              CupertinoIcons.calendar,
              color: _capsuleOrange,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                openDate == null ? '开启日期' : _formatCapsuleShortDate(openDate!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: w.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(CupertinoIcons.chevron_down, color: w.inkFaint, size: 16),
          ],
        ),
      ),
    );
  }
}

class _CapsuleEditorToolbar extends StatelessWidget {
  const _CapsuleEditorToolbar({
    required this.recording,
    required this.recordSeconds,
    required this.onPickImage,
    required this.onToggleRecord,
    required this.onPickSkin,
    required this.onEmoji,
  });

  final bool recording;
  final int recordSeconds;
  final VoidCallback? onPickImage;
  final VoidCallback? onToggleRecord;
  final VoidCallback? onPickSkin;
  final VoidCallback? onEmoji;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: w.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: w.glassBorder),
        boxShadow: [w.pillShadow],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _CapsuleToolButton(icon: CupertinoIcons.camera, onTap: onPickImage),
          _CapsuleToolButton(
            icon: recording ? CupertinoIcons.stop_circle : CupertinoIcons.mic,
            active: recording,
            label: recording ? '${math.max(1, recordSeconds)}s' : null,
            onTap: onToggleRecord,
          ),
          _CapsuleToolButton(
            customIcon: const _CapsuleSkinIcon(),
            onTap: onPickSkin,
          ),
          _CapsuleToolButton(icon: CupertinoIcons.smiley, onTap: onEmoji),
        ],
      ),
    );
  }
}

class _CapsuleToolButton extends StatelessWidget {
  const _CapsuleToolButton({
    required this.onTap,
    this.icon,
    this.customIcon,
    this.active = false,
    this.label,
  });

  final IconData? icon;
  final Widget? customIcon;
  final VoidCallback? onTap;
  final bool active;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: SizedBox(
        width: 42,
        height: 42,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            customIcon ??
                Icon(icon, color: active ? _capsuleDanger : w.ink, size: 26),
            if (label != null)
              Text(
                label!,
                style: const TextStyle(
                  color: _capsuleDanger,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CapsuleSkinIcon extends StatelessWidget {
  const _CapsuleSkinIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 27,
      height: 27,
      child: CustomPaint(
        painter: _CapsuleSkinIconPainter(color: _W2b.resolve(context).ink),
      ),
    );
  }
}

class _CapsuleSkinIconPainter extends CustomPainter {
  _CapsuleSkinIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = Colors.transparent
      ..style = PaintingStyle.fill;

    final page = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.24,
        size.height * 0.18,
        size.width * 0.52,
        size.height * 0.64,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(page, fill);
    canvas.drawRRect(page, stroke);

    final fold = Path()
      ..moveTo(size.width * 0.61, size.height * 0.18)
      ..lineTo(size.width * 0.76, size.height * 0.33)
      ..lineTo(size.width * 0.61, size.height * 0.33)
      ..close();
    canvas.drawPath(fold, stroke);

    canvas.drawLine(
      Offset(size.width * 0.34, size.height * 0.47),
      Offset(size.width * 0.66, size.height * 0.47),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width * 0.34, size.height * 0.60),
      Offset(size.width * 0.58, size.height * 0.60),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _CapsuleSkinIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _SheetGrabber extends StatelessWidget {
  // The default grey rides on the editor sheets, which follow the agent skin
  // and can be dark. Only the warm capsule sheets pass a colour.
  const _SheetGrabber({this.color = const Color(0xFFD8DCE0)});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Center(
        child: Container(
          width: 42,
          height: 5,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}
