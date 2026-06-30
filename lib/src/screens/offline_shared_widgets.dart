part of 'package:companion_flutter/main.dart';

class _ActivityPageBackdrop extends StatelessWidget {
  const _ActivityPageBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _OfflineBackground(progress: 0.42),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.of(context).page.withValues(alpha: 0.70),
            ),
          ),
        ),
      ],
    );
  }
}

class _OfflineSubpageTopBar extends StatelessWidget {
  const _OfflineSubpageTopBar({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _AppNavCircleButton(
              icon: CupertinoIcons.chevron_left,
              onPressed: onBack,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: AppColors.of(context).text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.16),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: _titleStyle(context, 20))),
        if (trailing != null) Text(trailing!, style: _mutedStyle(context, 13)),
      ],
    );
  }
}

class _SoftEmptyPanel extends StatelessWidget {
  const _SoftEmptyPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 154,
      padding: const EdgeInsets.all(20),
      decoration: _softCardDecoration(context, radius: 22).copyWith(
        border: Border.all(
          color: const Color(0x22F0A66B),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _RoundIcon(icon: icon, color: const Color(0xFFFFB38A)),
          const SizedBox(height: 12),
          Text(title, style: _titleStyle(context, 16)),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: _mutedStyle(context, 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _OfflineErrorBlock extends StatelessWidget {
  const _OfflineErrorBlock({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _softCardDecoration(context, radius: 18),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle,
            color: Color(0xFFE27C55),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: _mutedStyle(context, 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onRetry,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

class _BottomSheetFrame extends StatelessWidget {
  const _BottomSheetFrame({
    required this.child,
    this.expandWhenKeyboardVisible = false,
  });

  final Widget child;
  final bool expandWhenKeyboardVisible;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardHeight = media.viewInsets.bottom;
    final availableHeight =
        media.size.height - keyboardHeight - media.padding.top - 12;
    final maxSheetHeight = math.min(
      media.size.height * 0.86,
      math.max(260.0, availableHeight),
    );
    final shouldExpand = expandWhenKeyboardVisible && keyboardHeight > 0;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: shouldExpand ? maxSheetHeight : null,
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
          padding: EdgeInsets.fromLTRB(22, 10, 22, media.padding.bottom + 18),
          decoration: BoxDecoration(
            color: AppColors.of(context).surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(bottom: keyboardHeight > 0 ? 24 : 0),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SoftSuccessBar extends StatelessWidget {
  const _SoftSuccessBar({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF173224) : const Color(0xFFE9F8EC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0x553AAF69) : const Color(0x00000000),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isDark ? const Color(0xFF85D796) : const Color(0xFF62A36E),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

Widget _sheetGrabber(BuildContext context) {
  return Center(
    child: Container(
      width: 44,
      height: 5,
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: AppColors.of(context).hairline,
        borderRadius: BorderRadius.circular(999),
      ),
    ),
  );
}

BoxDecoration _softCardDecoration(BuildContext context, {double radius = 26}) {
  final colors = AppColors.of(context);
  return BoxDecoration(
    color: colors.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: colors.hairline.withValues(alpha: 0.44)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(
          alpha: AppColors.isDark(context) ? 0.22 : 0.055,
        ),
        blurRadius: 22,
        offset: const Offset(0, 12),
      ),
    ],
  );
}

TextStyle _titleStyle(BuildContext context, double size) {
  return TextStyle(
    color: AppColors.of(context).text,
    fontSize: size,
    fontWeight: FontWeight.w900,
    letterSpacing: 0,
    height: 1.15,
    decoration: TextDecoration.none,
  );
}

TextStyle _mutedStyle(BuildContext context, double size) {
  return TextStyle(
    color: AppColors.of(context).muted,
    fontSize: size,
    fontWeight: FontWeight.w600,
    height: 1.35,
    decoration: TextDecoration.none,
  );
}

String _categoryEmoji(String? category) {
  final value = (category ?? '').toLowerCase();
  if (value.contains('音乐')) return '🎵';
  if (value.contains('咖啡')) return '☕️';
  if (value.contains('书')) return '📚';
  if (value.contains('展') || value.contains('艺术')) return '🎨';
  if (value.contains('户外') || value.contains('公园')) return '🌿';
  return '🎯';
}

String? _chipEmoji(String text) {
  if (text.contains('咖啡') || text.contains('茶')) return '☕️';
  if (text.contains('音乐') || text.contains('歌')) return '🎵';
  if (text.contains('书') || text.contains('阅读')) return '📚';
  if (text.contains('画') || text.contains('艺术') || text.contains('水彩')) {
    return '🎨';
  }
  if (text.contains('甜') || text.contains('蛋糕')) return '🍰';
  if (text.contains('户外') || text.contains('散步') || text.contains('公园')) {
    return '🌿';
  }
  if (text.contains('电影') || text.contains('剧')) return '🎬';
  if (text.contains('狗') || text.contains('猫') || text.contains('宠物')) {
    return '🐾';
  }
  if (text.contains('夜') || text.contains('睡')) return '🌙';
  return null;
}

String _shortDate(String raw) {
  final value = DateTime.tryParse(raw);
  if (value == null) return raw;
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.year}年${value.month}月${value.day}日 $hour:$minute';
}

String _shortTimeRange(String? start, String? end) {
  final a = DateTime.tryParse(start ?? '');
  final b = DateTime.tryParse(end ?? '');
  if (a == null || b == null) return '';
  return '${a.hour.toString().padLeft(2, '0')}:${a.minute.toString().padLeft(2, '0')}-${b.hour.toString().padLeft(2, '0')}:${b.minute.toString().padLeft(2, '0')}';
}
