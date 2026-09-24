part of 'package:companion_flutter/main.dart';

/// Centered rules popup with a gaussian-blurred backdrop and a themed close (×)
/// button in the top-right corner.
// Shared game-art rules popup (cream card + blurred backdrop + themed close),
// used by both five-in-a-row and reversi.
// Returns the dialog's Future so callers can pause the turn countdown while
// the popup is open and resume when it closes (reversi / gomoku / checkers).
Future<void> _showGameRulesDialog(
  BuildContext context, {
  required String gameName,
  required List<String> rules,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭',
    barrierColor: Colors.black.withValues(alpha: 0.2),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (dialogContext, _, __) => Center(
      child: _GameRulesCard(
        gameName: gameName,
        rules: rules,
        onClose: () => Navigator.of(dialogContext).pop(),
      ),
    ),
    transitionBuilder: (_, animation, __, child) {
      // Ramp the gaussian blur in with the entrance and back out on close, in
      // step with the card's fade, rather than snapping to the final blur.
      return AnimatedBuilder(
        animation: animation,
        builder: (context, inner) {
          final t = animation.value.clamp(0.0, 1.0);
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10 * t, sigmaY: 10 * t),
            child: Opacity(opacity: t, child: inner),
          );
        },
        child: child,
      );
    },
  );
}

class _GameRulesCard extends StatelessWidget {
  const _GameRulesCard({
    required this.gameName,
    required this.rules,
    required this.onClose,
  });

  final String gameName;
  final List<String> rules;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final cardW = math.min(screenW * 0.74, 340.0);
    return SizedBox(
      width: cardW,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Dark-brown outer frame + tan inner line = the design's double edge.
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF6DEB4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF7A3D1E), width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5A2E14).withValues(alpha: 0.45),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            padding: const EdgeInsets.all(4),
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFDEFD6), Color(0xFFF6DEB4)],
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFFE7C58C), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: _StrokeText(text: gameName, fontSize: cardW * 0.092),
                  ),
                  const SizedBox(height: 2),
                  Center(
                    child: _StrokeText(text: '规则说明', fontSize: cardW * 0.082),
                  ),
                  const SizedBox(height: 20),
                  for (var i = 0; i < rules.length; i += 1) ...[
                    if (i > 0) const SizedBox(height: 12),
                    Text(
                      rules[i],
                      style: TextStyle(
                        color: const Color(0xFF7A4A22),
                        fontSize: cardW * 0.052,
                        height: 1.35,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            top: -14,
            right: -14,
            child: _GomokuCloseButton(onTap: onClose),
          ),
        ],
      ),
    );
  }
}

/// Themed circular close (×) button used in the top-right of the rules popup.
