part of 'package:companion_flutter/main.dart';

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.agentName,
    required this.subtitle,
    this.avatarUrl,
    required this.onOpenSidebar,
  });

  final String agentName;
  final String subtitle;
  final String? avatarUrl;
  final VoidCallback onOpenSidebar;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.page,
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          _Avatar(
            size: 44,
            label: '伴',
            imageUrl: avatarUrl,
            gradient: [Color(0xFFE8F3FF), Color(0xFFDDEBFF)],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agentName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      CupertinoIcons.flame_fill,
                      size: 12,
                      color: Color(0xFFFF8A22),
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        subtitle,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '更多',
            onPressed: onOpenSidebar,
            icon: const Icon(CupertinoIcons.ellipsis, size: 24),
          ),
        ],
      ),
    );
  }
}
