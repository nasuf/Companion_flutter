import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum VoiceReleaseAction { sendVoice, cancel, sendText }

const voiceQuickTapThreshold = Duration(milliseconds: 450);
const voiceMinimumCapturedDuration = Duration(milliseconds: 650);

bool shouldLatchVoiceRecordingAfterRelease({
  required VoiceReleaseAction action,
  required Duration pressDuration,
  required bool preparing,
  Duration? capturedDuration,
}) {
  if (action != VoiceReleaseAction.sendVoice) return false;
  if (preparing || pressDuration < voiceQuickTapThreshold) return true;
  return capturedDuration != null &&
      capturedDuration < voiceMinimumCapturedDuration;
}

class VoiceRecordingOverlay extends StatelessWidget {
  const VoiceRecordingOverlay({
    super.key,
    required this.action,
    required this.seconds,
    required this.preparing,
    this.tapMode = false,
  });

  final VoiceReleaseAction action;
  final int seconds;
  final bool preparing;
  final bool tapMode;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remaining = (seconds % 60).toString().padLeft(2, '0');
    const lime = Color(0xFF93F25F);
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.68),
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(0, 0.04),
            child: Semantics(
              label: preparing ? '正在准备麦克风' : '正在录音 $minutes:$remaining',
              child: Container(
                width: 250,
                height: 96,
                decoration: BoxDecoration(
                  color: lime,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 22,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: preparing
                      ? const CupertinoActivityIndicator(
                          radius: 14,
                          color: Color(0xFF38622D),
                        )
                      : const Icon(
                          Icons.graphic_eq_rounded,
                          color: Color(0xFF38622D),
                          size: 54,
                        ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: safeBottom + 98,
            child: Row(
              children: [
                Expanded(
                  child: _VoiceActionTarget(
                    label: '取消',
                    icon: CupertinoIcons.xmark,
                    selected: action == VoiceReleaseAction.cancel,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _VoiceActionTarget(
                    label: '滑到这里  转文字',
                    icon: CupertinoIcons.textformat,
                    selected: action == VoiceReleaseAction.sendText,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: -18,
            right: -18,
            bottom: -18,
            height: safeBottom + 104,
            child: Container(
              alignment: const Alignment(0, -0.25),
              decoration: const BoxDecoration(
                color: Color(0xFFF9FAFA),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(48),
                  topRight: Radius.circular(48),
                ),
              ),
              child: Text(
                tapMode
                    ? '再次点击麦克风  发送'
                    : action == VoiceReleaseAction.sendVoice
                    ? '松开  发送'
                    : '移回这里  发送',
                style: const TextStyle(
                  color: Color(0xFF202422),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceActionTarget extends StatelessWidget {
  const _VoiceActionTarget({
    required this.label,
    required this.icon,
    required this.selected,
  });

  final String label;
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      height: 82,
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFF93F25F).withValues(alpha: 0.30)
            : Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(38),
        border: Border.all(
          color: selected
              ? const Color(0xFF93F25F)
              : Colors.white.withValues(alpha: 0.08),
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
