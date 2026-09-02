part of 'package:companion_flutter/main.dart';

// 两个二级页各自的主调，跟陪伴主页的入口卡片一致：活动入口是蓝色卡片、礼物入口
// 是橙色卡片。二级页/bottom sheet 里的图标、按钮、描边、聚焦态等强调元素都用各自
// 这颗主调，避免活动页混橙、礼物页混蓝。
const Color _kActivityAccent = Color(0xFF2D73FF);
const Color _kGiftAccent = Color(0xFFFF8C4B);

class _ActivityPageBackdrop extends StatelessWidget {
  const _ActivityPageBackdrop();

  @override
  Widget build(BuildContext context) {
    // 只压一层很淡的底色雾，让玻璃底的极光透出来(否则 0.70 的厚底把极光糊成
    // 一片灰、玻璃卡片也没了通透感)；列表在半透明玻璃卡片里，可读性由卡片本身
    // 保证。
    final w = _W2b.resolve(context);
    return Stack(
      children: [
        const _OfflineBackground(),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: w.base.withValues(alpha: w.isDark ? 0.40 : 0.22),
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
    final w = _W2b.resolve(context);
    return SizedBox(
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            // 统一成天气/胶囊/日常分享页那颗玻璃返回键。
            child: _WeatherBackButton(onTap: onBack, iconColor: w.ink),
          ),
          Text(
            title,
            style: TextStyle(
              color: w.ink,
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
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// 空态图标的主调色：活动页传蓝(_kActivityAccent)、礼物页传橙(_kGiftAccent)。
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 154,
      padding: const EdgeInsets.all(20),
      // 保留 _softCardDecoration 的玻璃亮白描边(不再 copyWith 一条淡橙边把玻璃
      // 边缘盖没、读成灰底)。
      decoration: _softCardDecoration(context, radius: 22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _RoundIcon(icon: icon, color: accent),
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
    this.backgroundColor,
  });

  final Widget child;

  /// sheet 底色。默认不透明 surface；表单类 sheet 传玻璃底色(_W2b.base)，
  /// 让里面的玻璃输入框有对比、能显出来(白玻璃衬在白 surface 上会看不见)。
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardHeight = media.viewInsets.bottom;
    // 键盘上方可视区最多这么高，超出则内部滚动。
    final maxVisible = math.min(
      media.size.height * 0.86,
      math.max(260.0, media.size.height - media.padding.top - 12),
    );
    // 高度由内容决定；键盘用底部 padding 抬起内容，白底顺着 padding 一直铺到
    // 屏幕底、藏在键盘背后(padding 区域也被 decoration 涂满)，所以键盘弹起时
    // 上沿两角不会露出背后蒙层。
    //
    // 二次下降修复：之前外层是 AnimatedContainer(220ms)，它动画的 height/padding
    // 本身又被系统键盘的 viewInsets 每帧改动——等于两条时间线互相追逐；键盘
    // 落到底那一刻 shouldExpand 翻假、height 从固定高 snap 到内容高，Animated
    // Container 再补一段 220ms 收拢，就成了"第二次下降"。这里改回普通 Container：
    // 高度直接跟随系统键盘的 viewInsets，单一连贯的一次动画，不再叠第二层。
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // 点击 sheet 内空白处收起键盘。
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxVisible + keyboardHeight),
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.of(context).surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
          22,
          10,
          22,
          keyboardHeight + media.padding.bottom + 18,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: child,
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

// 活动/礼物两个二级页的卡片主体都走这个共享装饰——直接换成 _W2b 玻璃令牌，
// 一处改动即让两页大部分卡片变成和天气/胶囊/日常分享页一致的半透明玻璃。
BoxDecoration _softCardDecoration(BuildContext context, {double radius = 26}) {
  final w = _W2b.resolve(context);
  return BoxDecoration(
    color: w.glass,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: w.glassBorder),
    boxShadow: w.panelShadow,
  );
}

TextStyle _titleStyle(BuildContext context, double size) {
  return TextStyle(
    color: _W2b.resolve(context).ink,
    fontSize: size,
    fontWeight: FontWeight.w900,
    letterSpacing: 0,
    height: 1.15,
    decoration: TextDecoration.none,
  );
}

TextStyle _mutedStyle(BuildContext context, double size) {
  return TextStyle(
    color: _W2b.resolve(context).inkSoft,
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
