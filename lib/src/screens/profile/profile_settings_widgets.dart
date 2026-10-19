part of 'package:companion_flutter/main.dart';

class _SettingsColors {
  const _SettingsColors._();

  static bool get isDark => AppColors.current.page == AppColors.dark.page;

  static Color get page =>
      isDark ? const Color(0xFF080D14) : const Color(0xFFE8ECF1);
  static Color get bg =>
      isDark ? const Color(0xFF0D141D) : const Color(0xFFF0F4F8);
  static Color get headerA =>
      isDark ? const Color(0xFF101B27) : const Color(0xFFE3F0FA);
  static Color get headerB =>
      isDark ? const Color(0xFF261D1B) : const Color(0xFFFFF7F2);
  static Color get headerC =>
      isDark ? const Color(0xFF1A1721) : const Color(0xFFFDF0E8);
  static Color get card =>
      isDark ? const Color(0xFF101820) : const Color(0xFFFFFFFF);
  static Color get text =>
      isDark ? const Color(0xFFF2F7FB) : const Color(0xFF1C1C1E);
  static Color get tertiary =>
      isDark ? const Color(0xFF9AA8B8) : const Color(0xFF8E8E93);
  static Color get separator =>
      isDark ? const Color(0xFF263445) : const Color(0xFFE5E5EA);
  static Color get blueLight =>
      isDark ? const Color(0xFF17324C) : const Color(0xFFE8F2FB);
  static Color get blue =>
      isDark ? const Color(0xFF4BA3FF) : const Color(0xFF7AB8E0);
  static Color get blueDark =>
      isDark ? const Color(0xFF6CB6FF) : const Color(0xFF5A9CC8);
  static Color get orangeLight =>
      isDark ? const Color(0xFF3B2A21) : const Color(0xFFFFF0E8);
  static Color get orange =>
      isDark ? const Color(0xFFF3A66E) : const Color(0xFFF5B78A);
  static Color get orangeDark =>
      isDark ? const Color(0xFFFFB783) : const Color(0xFFE8945C);
  static Color get gold =>
      isDark ? const Color(0xFFF1C864) : const Color(0xFFD4A843);
  static Color get goldLight =>
      isDark ? const Color(0xFF3D3218) : const Color(0xFFFDF3D0);
  static Color get red =>
      isDark ? const Color(0xFFFF7777) : const Color(0xFFE8553D);
}

TextStyle _settingsRowTitleStyle() => TextStyle(
  color: _SettingsColors.text,
  fontSize: 15,
  fontWeight: FontWeight.w600,
  letterSpacing: 0,
);

TextStyle _settingsRowValueStyle(Color color) => TextStyle(
  color: color,
  fontSize: 13,
  fontWeight: FontWeight.w500,
  letterSpacing: 0,
);

BoxDecoration _settingsCardDecoration({double radius = 16}) {
  return BoxDecoration(
    color: _SettingsColors.card,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: _SettingsColors.isDark
          ? Colors.white.withValues(alpha: 0.07)
          : Colors.transparent,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(
          alpha: _SettingsColors.isDark ? 0.30 : 0.06,
        ),
        blurRadius: _SettingsColors.isDark ? 10 : 3,
        offset: Offset(0, _SettingsColors.isDark ? 5 : 1),
      ),
    ],
  );
}

typedef _RelationHeaderBuilder =
    Widget Function(double motion, double collapse);

/// Geometry is driven directly by scroll position, including reverse drags.
/// No second avatar tree or time-based collapse animation is needed.
class _SettingsRelationHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SettingsRelationHeaderDelegate({
    required this.topInset,
    required this.textScale,
    required this.motion,
    required this.builder,
  });
  final double topInset;
  final double textScale;
  final Animation<double> motion;
  final _RelationHeaderBuilder builder;
  @override
  double get minExtent => topInset + 64;
  @override
  double get maxExtent =>
      topInset + 254 + 2 * math.max(0, 13 * (textScale - 1));
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final collapse = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: collapse == 1 ? const AlwaysStoppedAnimation(0.0) : motion,
        builder: (context, _) =>
            builder(collapse == 1 ? 0 : motion.value, collapse),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SettingsRelationHeaderDelegate oldDelegate) =>
      oldDelegate.topInset != topInset ||
      oldDelegate.textScale != textScale ||
      oldDelegate.motion != motion ||
      oldDelegate.builder != builder;
}

class _SettingsRelationHeader extends StatelessWidget {
  const _SettingsRelationHeader({
    required this.progress,
    required this.collapse,
    required this.topPadding,
    required this.userName,
    required this.agentName,
    required this.onUserTap,
    required this.onAgentTap,
    this.userAvatarUrl,
    this.agentAvatarUrl,
    this.memberActive = false,
    this.showAdminEntry = false,
    this.onAdminTap,
  });
  final double progress;
  final double collapse;
  final double topPadding;
  final String userName;
  final String agentName;
  final String? userAvatarUrl;
  final String? agentAvatarUrl;
  final bool memberActive;
  final bool showAdminEntry;
  final VoidCallback onUserTap;
  final VoidCallback onAgentTap;
  final VoidCallback? onAdminTap;

  @override
  Widget build(BuildContext context) {
    final t = Curves.easeInOutCubic.transform(collapse);
    final fade = (1 - collapse / .65).clamp(0.0, 1.0);
    final size = lerpDouble(88, 36, t)!;
    final nameHeight = MediaQuery.textScalerOf(context).scale(13);
    Widget fading(Widget child) => IgnorePointer(
      ignoring: fade < .05,
      child: ExcludeSemantics(
        excluding: fade < .05,
        child: Opacity(opacity: fade, child: child),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        bottom: Radius.circular(lerpDouble(32, 20, t)!),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14 * t, sigmaY: 14 * t),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors:
                  [
                        _SettingsColors.headerA,
                        _SettingsColors.headerB,
                        _SettingsColors.headerC,
                        _SettingsColors.headerB,
                        _SettingsColors.headerA,
                      ]
                      .map(
                        (color) => Color.lerp(
                          color,
                          _SettingsColors.card.withValues(alpha: .88),
                          t,
                        )!,
                      )
                      .toList(),
            ),
            border: Border(
              bottom: BorderSide(
                color: _SettingsColors.separator.withValues(alpha: .5 * t),
                width: .5,
              ),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final expandedTop = topPadding + 68;
              Widget avatar({required bool user}) {
                final phase = user ? .28 : 0.0;
                final lift =
                    math.sin((progress + phase) * math.pi * 2) * 3 * (1 - t);
                final x = lerpDouble(
                  width * (user ? .76 : .24) - 44,
                  user ? 46 : 20,
                  t,
                )!;
                final y = lerpDouble(expandedTop, topPadding + 14, t)! + lift;
                final hitSize = math.max(44.0, size);
                final name = user ? userName : agentName;
                final onTap = user ? onUserTap : onAgentTap;
                return Positioned(
                  left: x - (hitSize - size) / 2,
                  top: y - (hitSize - size) / 2,
                  width: hitSize,
                  height: hitSize,
                  child: Semantics(
                    button: true,
                    label: user ? '查看我的资料：$name' : '查看伙伴形象：$name',
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      onPressed: onTap,
                      child: SizedBox(
                        key: ValueKey(
                          user ? 'profile-user-avatar' : 'profile-agent-avatar',
                        ),
                        width: size,
                        height: size,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _SettingsAvatarImage(
                              assetPath: user
                                  ? 'assets/prototype/user-avatar-shanmu.jpg'
                                  : 'assets/prototype/agent-avatar.png',
                              imageUrl: user ? userAvatarUrl : agentAvatarUrl,
                              accent: user
                                  ? (memberActive
                                        ? _SettingsColors.gold
                                        : _SettingsColors.blueDark)
                                  : _SettingsColors.orangeDark,
                              size: size,
                            ),
                            if (user)
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: fading(const _AvatarEditDot(size: 25)),
                              ),
                            if (user && memberActive)
                              Positioned(
                                right: size * -5 / 64,
                                top: size * -12 / 64,
                                child: Semantics(
                                  label: 'VIP 会员',
                                  child: Text(
                                    '👑',
                                    key: const ValueKey('profile-vip-badge'),
                                    style: TextStyle(fontSize: size * 18 / 64),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }

              Widget name({required bool user}) => Positioned(
                left:
                    lerpDouble(width * (user ? .76 : .24), user ? 64 : 38, t)! -
                    width * .24,
                top: lerpDouble(expandedTop + 99, topPadding + 14, t)!,
                width: width * .48,
                height: nameHeight + 16,
                child: fading(
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: user ? onUserTap : onAgentTap,
                    child: Text(
                      user ? userName : agentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _SettingsColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    left: width / 2 - 29,
                    top: lerpDouble(expandedTop + 12, topPadding + 14, t)!,
                    width: 58,
                    height: 64,
                    child: fading(
                      _SettingsConnectionBridge(progress: progress),
                    ),
                  ),
                  name(user: false),
                  name(user: true),
                  Positioned(
                    left: 20,
                    right: 20,
                    top: lerpDouble(
                      expandedTop + 146 + math.max(0, nameHeight - 13),
                      topPadding + 24,
                      t,
                    )!,
                    child: fading(
                      Text(
                        '故事从这里开始',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _SettingsColors.tertiary,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          letterSpacing: .5,
                        ),
                      ),
                    ),
                  ),
                  if (showAdminEntry && onAdminTap != null)
                    Positioned(
                      top: topPadding + 10,
                      right: 18,
                      child: fading(_ProfileAdminButton(onTap: onAdminTap!)),
                    ),
                  avatar(user: false),
                  avatar(user: true),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SettingsAvatarImage extends StatelessWidget {
  const _SettingsAvatarImage({
    required this.assetPath,
    required this.accent,
    this.imageUrl,
    this.size = 64,
  });

  final String assetPath;
  final String? imageUrl;
  final Color accent;

  /// 直径。默认 64 供「个人资料 / AI 形象」两个二级页的行内小头像用；「我的」
  /// 页顶部的关系头图传更大的值。
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset(assetPath, fit: BoxFit.cover);
    final image = AgentAvatarImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      fallback: fallback,
    );
    return Container(
      width: size,
      height: size,
      // 描边随直径走, 否则放大后那圈渐变边会显得过细。
      padding: EdgeInsets.all(size * 3 / 64),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: _SettingsColors.isDark ? 0.64 : 0.72),
            _SettingsColors.isDark ? _SettingsColors.card : Colors.white,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(child: image),
    );
  }
}

class _AvatarEditDot extends StatelessWidget {
  const _AvatarEditDot({this.size = 23});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _SettingsColors.isDark ? _SettingsColors.card : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: _SettingsColors.isDark ? 0.24 : 0.08,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        CupertinoIcons.pencil,
        size: size * 12 / 23,
        color: _SettingsColors.blueDark,
      ),
    );
  }
}

class _SettingsConnectionBridge extends StatelessWidget {
  const _SettingsConnectionBridge({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final rotation = progress * math.pi * 2;
    final pulse = 1 + math.sin(progress * math.pi * 4) * 0.08;
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.rotate(
          angle: rotation,
          child: CustomPaint(
            size: const Size(40, 40),
            painter: _DashedOrbitPainter(
              color:
                  (_SettingsColors.isDark
                          ? _SettingsColors.orangeDark
                          : const Color(0xFFE0C8B0))
                      .withValues(alpha: 0.82),
            ),
          ),
        ),
        Transform.rotate(
          angle: rotation,
          child: Transform.translate(
            offset: const Offset(0, -18),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _SettingsColors.orange,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        Transform.scale(
          scale: pulse,
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            child: Icon(
              CupertinoIcons.sparkles,
              color: _SettingsColors.orangeDark,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }
}

class _DashedOrbitPainter extends CustomPainter {
  const _DashedOrbitPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.butt;
    const dashCount = 12;
    const sweep = math.pi / 12;
    for (var i = 0; i < dashCount; i += 1) {
      canvas.drawArc(
        rect.deflate(2),
        i * math.pi * 2 / dashCount,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedOrbitPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _SettingsDashboardGrid extends StatelessWidget {
  const _SettingsDashboardGrid({
    required this.stats,
    required this.loading,
    required this.error,
  });

  final ProfileStats? stats;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _DashboardCardData(
        glyph: _SettingsGlyph.heart,
        iconAccent: _SettingsColors.orange,
        label: '亲密度',
        value: stats == null
            ? (loading ? '...' : '--')
            : stats!.topicIntimacy.round().toString(),
        subtext: stats?.intimacySubtitle ?? (loading ? '同步中' : '暂无数据'),
      ),
      _DashboardCardData(
        glyph: _SettingsGlyph.calendar,
        iconAccent: _SettingsColors.blue,
        label: '相识时间',
        value: stats == null
            ? (loading ? '...' : '--')
            : stats!.companionDays.toString(),
        subtext: stats?.companionStartedOn == null
            ? (loading ? '后台同步中' : '暂无开始日期')
            : '始于 ${stats!.companionStartedOn}',
      ),
      _DashboardCardData(
        glyph: _SettingsGlyph.stopwatch,
        iconAccent: const Color(0xFFA0C8E8),
        label: '相处时光',
        value: stats == null
            ? (loading ? '...' : '--')
            : stats!.chatDurationLabel,
        subtext: stats?.chatDurationSubtitle ?? '累计聊天时长',
      ),
      _DashboardCardData(
        glyph: _SettingsGlyph.chat,
        iconAccent: const Color(0xFFD4B89C),
        label: '讯息总数',
        value: stats == null
            ? (loading ? '...' : '--')
            : stats!.messageCount.toString(),
        subtext: stats?.recent7dMessageLabel ?? '来自后台真实数据',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final oneColumn =
                constraints.maxWidth < 290 ||
                MediaQuery.textScalerOf(context).scale(14) > 20;
            final cardWidth = oneColumn
                ? constraints.maxWidth
                : (constraints.maxWidth - 12) / 2;
            return Column(
              children: [
                for (var i = 0; i < cards.length; i += oneColumn ? 1 : 2) ...[
                  if (i > 0) const SizedBox(height: 12),
                  if (oneColumn)
                    SizedBox(
                      width: cardWidth,
                      child: _SettingsDashboardCard(cards[i]),
                    )
                  else
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _SettingsDashboardCard(cards[i])),
                          const SizedBox(width: 12),
                          Expanded(child: _SettingsDashboardCard(cards[i + 1])),
                        ],
                      ),
                    ),
                ],
              ],
            );
          },
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            '后台数据暂不可用：$error',
            style: TextStyle(
              color: _SettingsColors.red,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );
  }
}

class _DashboardCardData {
  const _DashboardCardData({
    required this.glyph,
    required this.iconAccent,
    required this.label,
    required this.value,
    required this.subtext,
  });

  final _SettingsGlyph glyph;
  final Color iconAccent;
  final String label;
  final String value;
  final String subtext;
}

class _SettingsDashboardCard extends StatelessWidget {
  const _SettingsDashboardCard(this.data);
  final _DashboardCardData data;
  @override
  Widget build(BuildContext context) {
    final dark = _SettingsColors.isDark;
    final icon = switch (data.glyph) {
      _SettingsGlyph.heart => CupertinoIcons.heart,
      _SettingsGlyph.calendar => CupertinoIcons.calendar,
      _SettingsGlyph.stopwatch => CupertinoIcons.time,
      _ => CupertinoIcons.chat_bubble_2,
    };
    return Semantics(
      container: true,
      label: '${data.label}，${data.value}，${data.subtext}',
      excludeSemantics: true,
      child: CustomPaint(
        foregroundPainter: _SettingsDashboardEdgePainter(
          color: data.iconAccent,
          dark: dark,
        ),
        child: Container(
          key: ValueKey('profile-stat-${data.label}'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _SettingsColors.card.withValues(alpha: dark ? .82 : .88),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: dark ? .08 : .72),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? .12 : .025),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      data.label,
                      style: TextStyle(
                        color: _SettingsColors.tertiary,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(icon, size: 16, color: data.iconAccent),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                data.value,
                style: TextStyle(
                  color: _SettingsColors.text,
                  fontSize: 26,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                data.subtext,
                style: TextStyle(
                  color: _SettingsColors.tertiary,
                  fontSize: 12,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keep the outside flush with the tile; taper the inside to zero at both tips.
class _SettingsDashboardEdgePainter extends CustomPainter {
  const _SettingsDashboardEdgePainter({
    required this.color,
    required this.dark,
  });
  final Color color;
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final radius = math.min(22.0, math.min(size.width, size.height) / 2);
    final width = math.min(3.0, radius);
    final outline = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()
      ..moveTo(radius, 0)
      ..arcToPoint(
        Offset(0, radius),
        radius: Radius.circular(radius),
        clockwise: false,
      )
      ..lineTo(0, size.height - radius)
      ..arcToPoint(
        Offset(radius, size.height),
        radius: Radius.circular(radius),
        clockwise: false,
      );

    // A filled ribbon changes its real width; opacity alone leaves blunt caps.
    // Keep the outer circular arcs exact and sample only the inner contour.
    const steps = 32;
    for (var i = steps; i >= 0; i--) {
      final t = i / steps;
      final progress = 1 - t;
      final taper = progress * progress * (3 - 2 * progress);
      final innerRadius = radius - width * taper;
      final angle = math.pi - t * math.pi / 2;
      path.lineTo(
        radius + innerRadius * math.cos(angle),
        size.height - radius + innerRadius * math.sin(angle),
      );
    }
    path.lineTo(width, radius);
    for (var i = steps; i >= 0; i--) {
      final t = i / steps;
      final taper = t * t * (3 - 2 * t);
      final innerRadius = radius - width * taper;
      final angle = -math.pi / 2 - t * math.pi / 2;
      path.lineTo(
        radius + innerRadius * math.cos(angle),
        radius + innerRadius * math.sin(angle),
      );
    }
    path.close();
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: .25),
          color,
          color,
          color.withValues(alpha: .25),
        ],
        stops: const [0, .24, .76, 1],
      ).createShader(Offset.zero & size);
    canvas.save();
    canvas.clipRRect(outline);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SettingsDashboardEdgePainter oldDelegate) =>
      color != oldDelegate.color || dark != oldDelegate.dark;
}

class _SettingsBackpackCard extends StatelessWidget {
  const _SettingsBackpackCard({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SettingsTappableCard(
      onTap: onTap,
      child: Row(
        children: [
          _SettingsFlatIcon(
            glyph: _SettingsGlyph.bag,
            accent: _SettingsColors.blue,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('我的背包', style: _settingsRowTitleStyle())),
          Container(
            constraints: const BoxConstraints(minWidth: 30),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: _SettingsColors.orange,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              count.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const _SettingsArrow(),
        ],
      ),
    );
  }
}

class _SettingsMemberCard extends StatelessWidget {
  const _SettingsMemberCard({required this.membership, required this.onTap});

  final IapMembership? membership;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = membership?.vip.isVip ?? false;
    final status = membership == null
        ? '成为会员'
        : membershipPlanBadgeFromMembership(membership!);
    return _SettingsTappableCard(
      onTap: onTap,
      decoration: BoxDecoration(
        color: _SettingsColors.goldLight.withValues(
          alpha: active ? 0.72 : 0.38,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _SettingsColors.gold.withValues(alpha: active ? 0.35 : 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: _SettingsColors.isDark ? 0.24 : 0.05,
            ),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          _SettingsFlatIcon(
            glyph: _SettingsGlyph.star,
            accent: _SettingsColors.gold,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('我的会员 · 尊享特权', style: _settingsRowTitleStyle())),
          Text(
            status,
            style: _settingsRowValueStyle(
              active ? const Color(0xFFA89050) : _SettingsColors.gold,
            ),
          ),
          const SizedBox(width: 8),
          const _SettingsArrow(),
        ],
      ),
    );
  }
}

class _SettingsSectionCard extends StatelessWidget {
  const _SettingsSectionCard({
    required this.label,
    required this.rows,
    this.footer,
  });

  final String label;
  final List<_SettingsRowData> rows;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _settingsCardDecoration(radius: 22),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 5),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: TextStyle(
                  color: _SettingsColors.tertiary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
          for (var i = 0; i < rows.length; i += 1)
            _SettingsRow(data: rows[i], showDivider: i < rows.length - 1),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: footer!,
            ),
        ],
      ),
    );
  }
}

class _SettingsRowData {
  const _SettingsRowData({
    required this.glyph,
    required this.iconAccent,
    required this.title,
    this.value,
    this.secondaryAction,
    this.trailing,
    this.onTap,
  });

  final _SettingsGlyph glyph;
  final Color iconAccent;
  final String title;
  final String? value;
  final String? secondaryAction;
  final Widget? trailing;
  final VoidCallback? onTap;
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.data, required this.showDivider});

  final _SettingsRowData data;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: _SettingsColors.separator,
                  width: 0.8,
                ),
              )
            : null,
      ),
      child: Row(
        children: [
          _SettingsFlatIcon(glyph: data.glyph, accent: data.iconAccent),
          const SizedBox(width: 12),
          Expanded(child: Text(data.title, style: _settingsRowTitleStyle())),
          if (data.value != null) ...[
            Text(
              data.value!,
              style: _settingsRowValueStyle(_SettingsColors.tertiary),
            ),
            const SizedBox(width: 8),
          ],
          if (data.secondaryAction != null)
            Text(
              data.secondaryAction!,
              style: TextStyle(
                color: _SettingsColors.blueDark,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            )
          else if (data.trailing != null)
            data.trailing!
          else
            const _SettingsArrow(),
        ],
      ),
    );
    if (data.onTap == null) return content;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.zero,
      onPressed: data.onTap,
      child: content,
    );
  }
}

class _SettingsAccountActions extends StatelessWidget {
  const _SettingsAccountActions({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return _SettingsActionButton(label: '退出登录', onTap: onLogout);
  }
}

class _SettingsActionButton extends StatelessWidget {
  const _SettingsActionButton({
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(14),
      onPressed: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          width: double.infinity,
          height: 50,
          alignment: Alignment.center,
          decoration: destructive
              ? _settingsDangerButtonDecoration(radius: 14)
              : _settingsCardDecoration(radius: 14),
          child: Text(
            label,
            style: TextStyle(
              color: destructive
                  ? (_SettingsColors.isDark
                        ? const Color(0xFFFF8F8A)
                        : const Color(0xFFD43D2E))
                  : _SettingsColors.blueDark,
              fontSize: 15,
              fontWeight: destructive ? FontWeight.w800 : FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration _settingsDangerButtonDecoration({double radius = 16}) {
  final isDark = _SettingsColors.isDark;
  return BoxDecoration(
    color: isDark ? const Color(0xFF331618) : const Color(0xFFFFF5F5),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: isDark
          ? const Color(0xFFFF7777).withValues(alpha: 0.24)
          : const Color(0xFFFFD6D2),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
        blurRadius: isDark ? 10 : 3,
        offset: Offset(0, isDark ? 5 : 1),
      ),
    ],
  );
}

class _SettingsTappableCard extends StatelessWidget {
  const _SettingsTappableCard({
    required this.onTap,
    required this.child,
    this.decoration,
  });

  final VoidCallback onTap;
  final Widget child;
  final BoxDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(16),
      onPressed: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: decoration ?? _settingsCardDecoration(),
        child: child,
      ),
    );
  }
}

/// Settings row glyphs — solid white filled PNGs (weather/capsule flat style).
/// Main silhouette is filled white; 面线 uses tiny cut-outs only (bell stripes,
/// calendar dots, chat dots) — never a hollow body that shows the accent circle.
/// 设置项圆标里的白色字形。
///
/// 用矢量 [IconData] 而非位图 PNG: 原来的 glyph_*.png 是 0.7-1.6KB 的低分辨率
/// 位图, 每张内部留白/线宽各不相同, 放到统一尺寸的圆里就显得"不精致、大小不一"。
/// 矢量图标任意尺寸都清晰, 且视觉重量天然一致 —— 跟天气页度量圆标同一套做法。
enum _SettingsGlyph {
  bell(CupertinoIcons.bell_fill),
  moon(CupertinoIcons.moon_fill),
  lock(CupertinoIcons.lock_fill),
  tray(CupertinoIcons.tray_fill),
  info(CupertinoIcons.info),
  cube(CupertinoIcons.cube_box_fill),
  heart(CupertinoIcons.heart_fill),
  calendar(CupertinoIcons.calendar),
  stopwatch(CupertinoIcons.stopwatch_fill),
  chat(CupertinoIcons.chat_bubble_2_fill),
  bag(CupertinoIcons.bag_fill),
  star(CupertinoIcons.star_fill);

  const _SettingsGlyph(this.icon);

  final IconData icon;
}

class _SettingsFlatIcon extends StatelessWidget {
  const _SettingsFlatIcon({
    required this.glyph,
    required this.accent,
    this.size = 40,
    double? glyphSize,
  }) : glyphSize = glyphSize ?? size * 0.50;

  final _SettingsGlyph glyph;
  final Color accent;
  final double size;

  /// 白色字形直径。统一取圆直径的 0.50 —— 与天气页度量圆标 (24pt / 48pt) 同比,
  /// 让所有圆标里的图标看起来一样大。矢量图标边到边, 不像旧 PNG 自带留白, 所以
  /// 从 0.60 收到 0.50 才不会显得过大。
  final double glyphSize;

  @override
  Widget build(BuildContext context) {
    final dark = _SettingsColors.isDark;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent,
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: accent.withValues(alpha: 0.30),
                  blurRadius: size >= 36 ? 8 : 6,
                  offset: Offset(0, size >= 36 ? 3 : 2),
                ),
              ],
      ),
      child: Icon(glyph.icon, size: glyphSize, color: Colors.white),
    );
  }
}

class _SettingsArrow extends StatelessWidget {
  const _SettingsArrow();

  @override
  Widget build(BuildContext context) {
    return Text(
      '›',
      style: TextStyle(
        color: _SettingsColors.isDark
            ? const Color(0xFF5F6F82)
            : const Color(0xFFC7C7CC),
        fontSize: 24,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1,
      ),
    );
  }
}

class _SettingsSubScaffold extends StatelessWidget {
  const _SettingsSubScaffold({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    return Scaffold(
      backgroundColor: _SettingsColors.page,
      body: Column(
        children: [
          SizedBox(
            height: padding.top + 56,
            child: Padding(
              padding: EdgeInsets.only(top: padding.top),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _WeatherBackButton(
                        onTap: () => Navigator.of(context).pop(),
                        iconColor: _SettingsColors.blueDark,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 72),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _SettingsColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  if (trailing != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: trailing,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SubPageContent extends StatelessWidget {
  const _SubPageContent({required this.children, this.center = false});

  final List<Widget> children;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 36),
      children: [
        if (center)
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: children),
          )
        else
          ...children,
      ],
    );
  }
}

class _SubCard extends StatelessWidget {
  const _SubCard({required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(15),
      decoration: _settingsCardDecoration(),
      child: Column(children: children),
    );
  }
}

class _SubCardRow extends StatelessWidget {
  const _SubCardRow({
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.showDivider = true,
  });

  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: _SettingsColors.separator,
                  width: 0.8,
                ),
              )
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: destructive ? _SettingsColors.red : _SettingsColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
          if (value != null)
            Text(
              value!,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: _SettingsColors.tertiary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          if (trailing != null) trailing!,
        ],
      ),
    );
    if (onTap == null) return content;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.zero,
      onPressed: onTap,
      child: content,
    );
  }
}

/// 账号类型胶囊，跟后台用户管理的 AuthMethodBadges 同一个表达方式：一个账号可能
/// 同时绑了微信和手机号，所以是并排的多个而不是单一文案。
class _LoginMethodBadges extends StatelessWidget {
  const _LoginMethodBadges({required this.methods});

  final List<LoginMethodInfo> methods;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final method in methods)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: _LoginMethodBadge(method),
          ),
      ],
    );
  }
}

class _LoginMethodBadge extends StatelessWidget {
  const _LoginMethodBadge(this.method);

  final LoginMethodInfo method;

  @override
  Widget build(BuildContext context) {
    final dark = _SettingsColors.isDark;
    // 微信用它的品牌绿: 这是个品牌标识, 借用 app 的暖/冷强调色反而让人认不出。
    // 手机号走蓝、密码走中性灰 —— 两者都在既有色板内。
    final (Color bg, Color fg) = switch (method.kind) {
      LoginMethod.wechat =>
        dark
            ? (const Color(0xFF16301F), const Color(0xFF5FD08A))
            : (const Color(0xFFE6F6EC), const Color(0xFF2E9E5B)),
      LoginMethod.phone => (
        _SettingsColors.blueLight,
        _SettingsColors.blueDark,
      ),
      LoginMethod.password => (
        dark ? const Color(0xFF1B2430) : const Color(0xFFEFEFF4),
        _SettingsColors.tertiary,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.28)),
      ),
      child: Text(
        method.label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _SubSectionHeader extends StatelessWidget {
  const _SubSectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            color: _SettingsColors.text,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}
