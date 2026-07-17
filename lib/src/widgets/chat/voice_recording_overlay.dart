import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

enum VoiceReleaseAction { sendVoice, cancel, sendText }

const chatVoiceAccent = Color(0xFF06C893);
const chatVoiceAccentDeep = Color(0xFF068A66);
const chatVoiceAccentSoft = Color(0xFFE7F8F2);
const chatVoiceCancel = Color(0xFFFF5A5F);
const chatVoiceCancelDeep = Color(0xFFC6383D);
const chatVoiceCancelSoft = Color(0xFFFFE9EA);
const voiceMinimumCapturedDuration = Duration(milliseconds: 650);

const _voiceSelectionThresholdFromBottom = 146.0;
const _voiceHorizontalDeadZone = 20.0;

bool isVoiceCaptureTooShort(Duration? capturedDuration) {
  return capturedDuration == null ||
      capturedDuration < voiceMinimumCapturedDuration;
}

VoiceReleaseAction voiceReleaseActionForPosition({
  required Offset position,
  required Size screenSize,
  required double safeBottom,
  VoiceReleaseAction currentAction = VoiceReleaseAction.sendVoice,
}) {
  final selectionThreshold =
      screenSize.height - safeBottom - _voiceSelectionThresholdFromBottom;
  if (position.dy >= selectionThreshold) {
    return VoiceReleaseAction.sendVoice;
  }

  final centerX = screenSize.width / 2;
  if (position.dx <= centerX - _voiceHorizontalDeadZone) {
    return VoiceReleaseAction.cancel;
  }
  if (position.dx >= centerX + _voiceHorizontalDeadZone) {
    return VoiceReleaseAction.sendText;
  }
  return currentAction;
}

class VoiceRecordingOverlay extends StatelessWidget {
  const VoiceRecordingOverlay({
    super.key,
    required this.action,
    required this.seconds,
    required this.preparing,
    this.amplitude,
  });

  final VoiceReleaseAction action;
  final int seconds;
  final bool preparing;
  final ValueListenable<double>? amplitude;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 190);

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0x70101B17)),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: duration,
          curve: Curves.easeOutCubic,
          child: _VoiceOverlayContent(
            action: action,
            seconds: seconds,
            preparing: preparing,
            safeBottom: safeBottom,
            amplitude: amplitude,
          ),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * 18),
                child: child,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _VoiceOverlayContent extends StatelessWidget {
  const _VoiceOverlayContent({
    required this.action,
    required this.seconds,
    required this.preparing,
    required this.safeBottom,
    required this.amplitude,
  });

  final VoiceReleaseAction action;
  final int seconds;
  final bool preparing;
  final double safeBottom;
  final ValueListenable<double>? amplitude;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: safeBottom + 236,
          child: Center(
            child: _RecordingCapsule(
              seconds: seconds,
              preparing: preparing,
              amplitude: amplitude,
            ),
          ),
        ),
        Positioned(
          left: 22,
          right: 22,
          bottom: safeBottom + 150,
          child: Row(
            children: [
              Expanded(
                child: _VoiceActionTarget(
                  key: const ValueKey('voice-action-cancel'),
                  label: '取消',
                  semanticsLabel: '取消录音',
                  icon: CupertinoIcons.xmark,
                  selected: action == VoiceReleaseAction.cancel,
                  danger: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _VoiceActionTarget(
                  key: const ValueKey('voice-action-text'),
                  label: '转文字',
                  semanticsLabel: '转文字发送',
                  icon: CupertinoIcons.textformat,
                  selected: action == VoiceReleaseAction.sendText,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: safeBottom + 132,
          child: const Text(
            '左右滑动选择',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFC8D3CE),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Positioned(
          left: 22,
          right: 22,
          bottom: safeBottom + 74,
          child: _VoiceSendTarget(
            selected: action == VoiceReleaseAction.sendVoice,
          ),
        ),
      ],
    );
  }
}

class _RecordingCapsule extends StatelessWidget {
  const _RecordingCapsule({
    required this.seconds,
    required this.preparing,
    required this.amplitude,
  });

  final int seconds;
  final bool preparing;
  final ValueListenable<double>? amplitude;

  @override
  Widget build(BuildContext context) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remaining = (seconds % 60).toString().padLeft(2, '0');
    final progress = (seconds / 60).clamp(0.0, 1.0);
    return Semantics(
      excludeSemantics: true,
      label: preparing ? '正在准备麦克风' : '正在录音 $minutes:$remaining',
      child: Container(
        width: 244,
        height: 58,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FCFA).withValues(alpha: 0.80),
          borderRadius: BorderRadius.circular(29),
          border: Border.all(color: Colors.white.withValues(alpha: 0.74)),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 3),
              child: preparing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CupertinoActivityIndicator(
                          radius: 8,
                          color: chatVoiceAccentDeep,
                        ),
                        SizedBox(width: 9),
                        Text(
                          '正在准备麦克风…',
                          style: TextStyle(
                            color: chatVoiceAccentDeep,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        const SizedBox(
                          width: 8,
                          height: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0xFFFF4D4F),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: RepaintBoundary(
                            child: _VoiceWaveform(amplitude: amplitude),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$minutes:$remaining',
                          style: const TextStyle(
                            color: chatVoiceAccentDeep,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
            ),
            if (!preparing)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 3,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress,
                    child: const ColoredBox(color: chatVoiceAccent),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VoiceWaveform extends StatelessWidget {
  const _VoiceWaveform({required this.amplitude});

  final ValueListenable<double>? amplitude;

  @override
  Widget build(BuildContext context) {
    final listenable = amplitude;
    if (listenable == null) {
      return const CustomPaint(
        painter: _VoiceWaveformPainter(amplitude: 0.36),
        size: Size.infinite,
      );
    }
    return ValueListenableBuilder<double>(
      valueListenable: listenable,
      builder: (context, value, _) {
        return CustomPaint(
          painter: _VoiceWaveformPainter(amplitude: value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _VoiceWaveformPainter extends CustomPainter {
  const _VoiceWaveformPainter({required this.amplitude});

  final double amplitude;

  @override
  void paint(Canvas canvas, Size size) {
    const barCount = 27;
    const barWidth = 2.2;
    final gap = (size.width - barCount * barWidth) / (barCount - 1);
    final normalized = amplitude.clamp(0.08, 1.0);
    final paint = Paint()
      ..color = chatVoiceAccent
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < barCount; index++) {
      final rhythm =
          0.34 + math.sin(index * 1.73 + normalized * 2.6).abs() * 0.66;
      final height = size.height * (0.16 + rhythm * normalized * 0.78);
      final x = index * (barWidth + gap) + barWidth / 2;
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VoiceWaveformPainter oldDelegate) {
    return (oldDelegate.amplitude - amplitude).abs() > 0.015;
  }
}

class _VoiceActionTarget extends StatelessWidget {
  const _VoiceActionTarget({
    super.key,
    required this.label,
    required this.semanticsLabel,
    required this.icon,
    required this.selected,
    this.danger = false,
  });

  final String label;
  final String semanticsLabel;
  final IconData icon;
  final bool selected;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final selectedAccent = danger ? chatVoiceCancel : chatVoiceAccent;
    final selectedDeep = danger ? chatVoiceCancelDeep : chatVoiceAccentDeep;
    final selectedSoft = danger ? chatVoiceCancelSoft : chatVoiceAccentSoft;
    return Semantics(
      label: semanticsLabel,
      selected: selected,
      child: AnimatedScale(
        scale: selected ? 1.03 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          height: 62,
          decoration: BoxDecoration(
            color: selected
                ? selectedSoft.withValues(alpha: 0.78)
                : const Color(0xFFF7FBF9).withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(31),
            border: Border.all(
              color: selected
                  ? selectedAccent.withValues(alpha: 0.70)
                  : Colors.white.withValues(alpha: 0.56),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? selectedDeep : const Color(0xFF405049),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? selectedDeep : const Color(0xFF24302B),
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceSendTarget extends StatelessWidget {
  const _VoiceSendTarget({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '松开发送语音',
      selected: selected,
      child: AnimatedScale(
        scale: selected ? 1 : 0.985,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          key: const ValueKey('voice-action-send'),
          duration: const Duration(milliseconds: 110),
          height: 56,
          decoration: BoxDecoration(
            color: selected
                ? chatVoiceAccent.withValues(alpha: 0.80)
                : chatVoiceAccent.withValues(alpha: 0.54),
            borderRadius: BorderRadius.circular(28),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '松开发送',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 7),
              Icon(CupertinoIcons.mic_fill, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
