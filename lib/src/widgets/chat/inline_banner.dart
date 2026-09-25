part of 'package:companion_flutter/main.dart';

class _InlineBanner extends StatelessWidget {
  const _InlineBanner({required this.text, required this.onRetry});

  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: dark ? const Color(0xFF3A1818) : const Color(0xFFFFF2F0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: dark ? const Color(0xFFFFB4AB) : const Color(0xFFB42318),
                fontSize: 12,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
