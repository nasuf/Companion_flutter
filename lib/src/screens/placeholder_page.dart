part of 'package:companion_flutter/main.dart';

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    required this.icon,
    this.action,
  });

  final String title;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const Spacer(),
                if (action != null) action!,
              ],
            ),
            const SizedBox(height: 26),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 52, color: AppColors.muted),
                    const SizedBox(height: 12),
                    Text(
                      '页面内容待接入',
                      style: TextStyle(color: AppColors.muted, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
