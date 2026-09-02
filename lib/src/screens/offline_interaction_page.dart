part of 'package:companion_flutter/main.dart';

class OfflineInteractionPage extends StatefulWidget {
  const OfflineInteractionPage({
    super.key,
    required this.api,
    required this.session,
    required this.agentName,
    required this.active,
  });

  final CompanionApi api;
  final AuthSession session;
  final String agentName;
  final bool active;

  @override
  State<OfflineInteractionPage> createState() => _OfflineInteractionPageState();
}

class _OfflineInteractionPageState extends State<OfflineInteractionPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  OfflineHome? _home;
  bool _locationRequestStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 21000),
    )..repeat(reverse: true);
    _load();
    _requestLocationWhenActive();
  }

  @override
  void didUpdateWidget(covariant OfflineInteractionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.workspaceId != widget.session.workspaceId) {
      _load();
    }
    if (!oldWidget.active && widget.active) {
      _requestLocationWhenActive();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final home = await widget.api.fetchOfflineHome(
        workspaceId: widget.session.workspaceId,
      );
      if (mounted) setState(() => _home = home);
    } catch (_) {
      if (mounted) setState(() => _home = null);
    }
  }

  void _requestLocationWhenActive() {
    if (!widget.active) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.active) return;
      _requestLocationOnce();
    });
  }

  Future<void> _requestLocationOnce() async {
    if (_locationRequestStarted) return;
    _locationRequestStarted = true;
    await _requestAndSaveUserLocation(widget.api);
    await _load();
  }

  void _openActivities() {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => OfflineActivityPage(
          api: widget.api,
          session: widget.session,
          hasLocation: _home?.hasLocation == true,
          onChanged: _load,
        ),
      ),
    );
  }

  void _openGifts() {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => OfflineGiftPage(
          api: widget.api,
          session: widget.session,
          onChanged: _load,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tags = _home?.tags ?? const <String>[];
    // 整页不再滚动：hero 和功能卡片行保持原有的固定高度，记忆胶囊面板拿
    // 剩余空间用 Expanded 撑满（自己内部按拿到的高度等比收缩，见
    // _OfflineMemoryPanel），而不是像之前那样整页内容比视口高、必须手动
    // 划一下才能看到底部的记忆胶囊。
    const memoryPanelBottomClearance = 140.0; // 留给 main_shell 悬浮 tab bar。
    // 呼吸/漂移动画不再包整页：背景与 hero 各自内部用 AnimatedBuilder +
    // RepaintBoundary 只重绘自己那一块；底部记忆 tag 每张各带本地 ticker
    // (见 _FloatingMemoryChip)。整页(功能卡片行等)不再每帧重建——这正是
    // "日常分享"页卡片呼吸流畅、而这里卡顿的差别所在。
    return Stack(
      children: [
        _OfflineBackground(controller: _controller),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                28,
                MediaQuery.paddingOf(context).top + 32,
                28,
                0,
              ),
              child: _OfflineHero(controller: _controller),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _OfflineFeatureCard(
                      icon: CupertinoIcons.scope,
                      iconColor: const Color(0xFF2D73FF),
                      title: '看看活动',
                      subtitle: _activitySubtitle,
                      status: '推荐',
                      gradient: const [
                        Color(0xFF88B7FF),
                        Color(0xFF63CEEA),
                        Color(0xFFBDF7E3),
                      ],
                      onTap: _openActivities,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _OfflineFeatureCard(
                      icon: CupertinoIcons.gift_fill,
                      iconColor: const Color(0xFFFF8C4B),
                      title: '我的礼物',
                      subtitle: _home?.giftSummary ?? '你有一份惊喜在路上',
                      status: '礼物',
                      gradient: const [
                        Color(0xFFFFB695),
                        Color(0xFFFFD98D),
                        Color(0xFFFFF0BF),
                      ],
                      onTap: _openGifts,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  28,
                  0,
                  28,
                  memoryPanelBottomClearance,
                ),
                child: _OfflineMemoryPanel(tags: tags),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String get _activitySubtitle {
    final pendingCount = _home?.pendingActivityCount ?? 0;
    if (pendingCount > 0) return '$pendingCount 个待确认邀请';
    final acceptedCount = _home?.acceptedActivityCount ?? 0;
    if (acceptedCount > 0) return '$acceptedCount 个待出行活动';
    final completedCount = _home?.completedActivityCount ?? 0;
    if (completedCount > 0) return '$completedCount 个已完成活动';
    return '周末一起出去走走';
  }
}

String? _firstNonEmptyLocationPart(List<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

Future<bool> _requestAndSaveUserLocation(
  CompanionApi api, {
  bool openSettingsWhenBlocked = false,
}) async {
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await api.saveUserLocation(permissionStatus: 'service_disabled');
      if (openSettingsWhenBlocked) {
        await Geolocator.openLocationSettings();
      }
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      await api.saveUserLocation(permissionStatus: permission.name);
      if (openSettingsWhenBlocked) {
        await Geolocator.openAppSettings();
      }
      return false;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 8),
      ),
    );
    String? city;
    String? region;
    String? country;
    try {
      final places = await geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (places.isNotEmpty) {
        final place = places.first;
        city = _firstNonEmptyLocationPart([
          place.locality,
          place.subAdministrativeArea,
          place.administrativeArea,
        ]);
        region = _firstNonEmptyLocationPart([
          place.administrativeArea,
          place.subAdministrativeArea,
        ]);
        country = _firstNonEmptyLocationPart([
          place.country,
          place.isoCountryCode,
        ]);
      }
    } catch (_) {
      // Coordinates are still useful to persist even when reverse geocoding fails.
    }
    return api.saveUserLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      city: city,
      region: region,
      country: country,
      permissionStatus: permission.name,
    );
  } catch (_) {
    // Location is an enhancer for offline activities; never block the board.
    return false;
  }
}

class _OfflineBackground extends StatelessWidget {
  const _OfflineBackground({this.controller});

  /// null 时渲染一帧静态柔光(给活动/礼物二级页当静态背景用)，非 null 时随
  /// controller 漂移(陪伴主页)。
  final AnimationController? controller;

  Widget _drift(double progress) {
    final plateBreath = math.sin(progress * math.pi);
    final plateDrift = math.sin(progress * math.pi * 2);
    return Stack(
      children: [
        Positioned(
          right: -78 + 10 * plateDrift,
          top: 88 - 7 * plateBreath,
          child: Transform.rotate(
            angle: (-7 + plateDrift * 1.4) * math.pi / 180,
            child: _OfflineBreathingPlate(progress: progress),
          ),
        ),
        Positioned(
          left: -76 - 6 * progress,
          top: 388 + 9 * progress,
          child: _OnlineAura(
            size: const Size(270, 230),
            color: const Color(0x66FFCF98),
            blur: 42,
          ),
        ),
        Positioned(
          right: -32 + 6 * progress,
          bottom: 78 - 8 * progress,
          child: _OnlineAura(
            size: const Size(230, 210),
            color: const Color(0x5ECBD3FF),
            blur: 38,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = AppColors.isDark(context);
    final ctrl = controller;
    // 跟互动页同一套"极光粉彩"底色思路(见 online_interaction_page.dart 的
    // 说明)，但这里刻意偏暖——陪伴页讲的是走到现实世界里，暖阳/户外的暖调
    // 占主导，冷色收在底部，跟互动页(线上、偏冷)拉开性格差异。深色模式仍走
    // 主题色。底色本身是静态的，放在动画外面；只有会漂移的柔光块/呼吸盘用
    // AnimatedBuilder + RepaintBoundary 单独重绘，不牵连整页。
    final Gradient baseGradient = isDark
        ? LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.page,
              Color.lerp(colors.page, colors.surfaceMuted, 0.45)!,
              Color.lerp(colors.page, colors.accentDeep, 0.14)!,
            ],
            stops: const [0, 0.52, 1],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFE7CE), // 左上暖阳杏色，提亮一档，暖调占主导
              Color(0xFFFFF4E7), // 暖奶油，更亮
              Color(0xFFEAF2FF), // 天蓝，提亮
              Color(0xFFE0F5EA), // 右下薄荷，提亮
            ],
            stops: [0, 0.34, 0.68, 1],
          );
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: baseGradient),
        child: Stack(
          children: [
            if (ctrl != null)
              AnimatedBuilder(
                animation: ctrl,
                builder: (context, _) =>
                    _drift(Curves.easeInOut.transform(ctrl.value)),
              )
            else
              _drift(0.42),
            // 右上角高光(静态)，挑亮角落但不冲淡暖粉彩。
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.76, -0.62),
                    radius: 0.87,
                    colors: [
                      isDark
                          ? colors.accentSoft.withValues(alpha: 0.38)
                          : Colors.white.withValues(alpha: 0.50),
                      Colors.transparent,
                    ],
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

class _OfflineBreathingPlate extends StatelessWidget {
  const _OfflineBreathingPlate({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final breath = math.sin(progress * math.pi);
    final drift = math.sin(progress * math.pi * 2);
    final highlightAlpha = isDark ? 0.14 + breath * 0.07 : 0.60 + breath * 0.18;
    return Transform.translate(
      offset: Offset(drift * 3, -breath * 5),
      child: Transform.scale(
        scale: 0.985 + breath * 0.045,
        child: Container(
          width: 248,
          height: 214,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(72),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(
                        0xFF6AA8DC,
                      ).withValues(alpha: 0.24 + breath * 0.07),
                      const Color(
                        0xFF4C83C7,
                      ).withValues(alpha: 0.17 + breath * 0.06),
                      const Color(
                        0xFF2DD8D2,
                      ).withValues(alpha: 0.11 + breath * 0.05),
                    ]
                  : [
                      // 右上这块大色块是"顶部发灰"的主因——继续提亮提饱和、
                      // 加大不透明度，让它读成明快的蓝青而不是灰蓝。
                      const Color(
                        0xFF6FB0FF,
                      ).withValues(alpha: 0.60 + breath * 0.12),
                      const Color(
                        0xFF52CCFF,
                      ).withValues(alpha: 0.46 + breath * 0.10),
                      const Color(
                        0xFF2FDCC8,
                      ).withValues(alpha: 0.36 + breath * 0.08),
                    ],
              stops: const [0, 0.58, 1],
            ),
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(72),
            gradient: RadialGradient(
              center: Alignment(-0.10 + drift * 0.03, -0.40 - breath * 0.04),
              radius: 0.52 + breath * 0.08,
              colors: [
                Colors.white.withValues(alpha: highlightAlpha),
                Colors.white.withValues(alpha: isDark ? 0.04 : 0.15),
                Colors.transparent,
              ],
              stops: const [0, 0.50, 1],
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflineHero extends StatelessWidget {
  const _OfflineHero({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = AppColors.isDark(context);
    // 之前"看看有没有你感兴趣的"那行字删掉后，这块 hero 的最下方内容就只剩
    // LIVE 图形了——用这个把它（连同 hero 自身高度）一起再往上收一截，给
    // 下面功能卡片和记忆胶囊标签多让一点空间，不需要再顾着已经删掉的文案。
    const lowerContentLift = 32.0;
    return SizedBox(
      height: 300 - lowerContentLift,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 10,
            child: Text(
              'REAL WORLD BOARD',
              style: TextStyle(
                color: colors.accent,
                fontSize: 14,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 54,
            child: Text(
              '今天想一起做点什么？',
              maxLines: 1,
              style: TextStyle(
                color: colors.text,
                fontSize: 26,
                height: 1.15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 172 - lowerContentLift,
            // LIVE 图形区是这块 hero 里唯一动的东西——只让它用 AnimatedBuilder
            // + RepaintBoundary 单独重绘，标题/副标题这些静态文字不跟着重建。
            child: RepaintBoundary(
              child: SizedBox(
                width: 226,
                height: 122,
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) {
                    final progress = Curves.easeInOut.transform(
                      controller.value,
                    );
                    return CustomPaint(
                      painter: _OfflineLivePainter(progress: progress),
                      child: Stack(
                        children: [
                          _OfflineLiveDot(
                            left: 14,
                            top: 66 + math.sin(progress * math.pi * 2) * 3,
                            color: const Color(0xFFFF7047),
                            progress: progress,
                            phase: 0.00,
                          ),
                          _OfflineLiveDot(
                            left: 110,
                            top: 44 - math.sin(progress * math.pi * 2 + 0.7) * 3,
                            color: const Color(0xFF2D73FF),
                            progress: progress,
                            phase: 0.18,
                          ),
                          _OfflineLiveDot(
                            left: 166,
                            top: 14 + math.sin(progress * math.pi * 2 + 1.2) * 3,
                            color: const Color(0xFF58C87B),
                            progress: progress,
                            phase: 0.36,
                          ),
                          Positioned(
                            right: 12,
                            bottom: 18,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? colors.surfaceMuted.withValues(
                                        alpha: 0.76,
                                      )
                                    : Colors.white.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.10)
                                      : Colors.transparent,
                                ),
                              ),
                              child: Text(
                                'LIVE',
                                style: TextStyle(
                                  color: colors.accent,
                                  fontSize: 12,
                                  height: 1,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineLivePainter extends CustomPainter {
  const _OfflineLivePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final orange = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4
      ..color = const Color(0xFFFF8152);
    final gray = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4
      ..color = const Color(0xFFD9E1DE);

    final lift = math.sin(progress * math.pi * 2) * 3;
    final first = Path()
      ..moveTo(0, 72 + lift)
      ..cubicTo(42, 15 - lift, 84, 12 + lift, 122, 55 - lift);
    final second = Path()
      ..moveTo(126, 58 - lift)
      ..cubicTo(158, 92 + lift, 190, 70 - lift, 202, 18 + lift);
    canvas.drawPath(first, orange);
    canvas.drawPath(second, gray);
  }

  @override
  bool shouldRepaint(covariant _OfflineLivePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _OfflineLiveDot extends StatelessWidget {
  const _OfflineLiveDot({
    required this.left,
    required this.top,
    required this.color,
    required this.progress,
    required this.phase,
  });

  final double left;
  final double top;
  final Color color;
  final double progress;
  final double phase;

  @override
  Widget build(BuildContext context) {
    final wave = math.sin((progress + phase) * math.pi * 2);
    final breath = 0.5 + wave * 0.5;
    final haloSize = 38 + breath * 14;
    final dotSize = 12 + breath * 5;

    return Positioned(
      left: left,
      top: top,
      child: SizedBox(
        width: 56,
        height: 56,
        child: Center(
          child: Container(
            width: haloSize,
            height: haloSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.08 + breath * 0.15),
            ),
            child: Center(
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.92 + breath * 0.08),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.20 + breath * 0.24),
                      blurRadius: 12 + breath * 14,
                      offset: Offset(0, 5 + breath * 5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflineFeatureCard extends StatelessWidget {
  const _OfflineFeatureCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String status;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = AppColors.isDark(context);
    final cardGradient = isDark
        ? [
            Color.lerp(colors.surface, gradient.first, 0.24)!,
            Color.lerp(colors.surfaceMuted, gradient[1], 0.22)!,
            Color.lerp(colors.surface, gradient.last, 0.16)!,
          ]
        : gradient;
    final primaryText = isDark ? colors.text : const Color(0xFF11161A);
    final secondaryText = isDark
        ? colors.muted.withValues(alpha: 0.88)
        : const Color(0xFF16212B).withValues(alpha: 0.58);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      borderRadius: BorderRadius.circular(28),
      onPressed: onTap,
      child: Container(
        height: 182,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: cardGradient,
          ),
          border: isDark
              ? Border.all(color: Colors.white.withValues(alpha: 0.10))
              : null,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.30)
                  : gradient.first.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.18)
                  : gradient.last.withValues(alpha: 0.16),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.72, -0.88),
                      radius: 1.05,
                      colors: [
                        Colors.white.withValues(alpha: isDark ? 0.10 : 0.34),
                        Colors.white.withValues(alpha: isDark ? 0.04 : 0.08),
                        Colors.transparent,
                      ],
                      stops: const [0, 0.46, 1],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(painter: _OfflineCardLinePainter()),
              ),
              Positioned(
                left: 18,
                top: 18,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: isDark
                        ? colors.surface.withValues(alpha: 0.78)
                        : Colors.white.withValues(alpha: 0.82),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.transparent,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withValues(
                          alpha: isDark ? 0.10 : 0.16,
                        ),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
              ),
              Positioned(
                right: 16,
                top: 18,
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surface.withValues(alpha: 0.72)
                        : Colors.white.withValues(alpha: 0.58),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.white.withValues(alpha: 0.40),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(
                          alpha: isDark ? 0.02 : 0.20,
                        ),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      status,
                      style: TextStyle(
                        color: isDark ? colors.text : const Color(0xFF31414C),
                        fontSize: 12,
                        height: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 22,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 20,
                        height: 1.08,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 9),
                    SizedBox(
                      height: 34,
                      child: Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: secondaryText,
                          fontSize: 13,
                          height: 1.28,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '进入',
                          style: TextStyle(
                            color: primaryText,
                            fontSize: 13,
                            height: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          CupertinoIcons.chevron_right,
                          color: primaryText,
                          size: 12,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineCardLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.26)
      ..strokeWidth = 1.2;
    for (var x = size.width * 0.50; x < size.width + 40; x += 16) {
      canvas.drawLine(
        Offset(x, size.height * 0.68),
        Offset(x + 22, size.height + 20),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OfflineMemoryPanel extends StatelessWidget {
  const _OfflineMemoryPanel({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final display = <String>[
      for (final tag in tags)
        if (tag.trim().isNotEmpty && !_isMemoryCategoryLabel(tag)) tag.trim(),
    ].take(9).toList();
    while (display.length < 5) {
      display.add('');
    }
    const palette = [
      Color(0xFF8BDCA6),
      Color(0xFFFFC777),
      Color(0xFFBFA7FF),
      Color(0xFFFFA7B8),
      Color(0xFF82CEF1),
    ];
    final specs = _chipSpecs(display.length);
    // 原来这块是写死 296 高的画布，绝对坐标摆放悬浮卡片。这一块要能塞进
    // 页面剩余的任意高度而不滚动——卡片本身保持设计原尺寸不缩小，只把纵向
    // 坐标的间距按实际高度相对 296 设计高度收紧；下限压到 0.72 封顶，不管
    // 屏幕多矮都不让间距缩没——留原有间距的大部分，让"挨得近的几张卡片
    // 略有交叠"读成错落感，而不是所有卡片挤成一团完全盖住彼此。横向坐标
    // 继续用现成的 constraints.maxWidth 逻辑，两个轴各自适应。
    const designHeight = 296.0;
    const minHeightScale = 0.72;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;
        final heightScale = availableHeight.isFinite
            ? (availableHeight / designHeight).clamp(minHeightScale, 1.0)
            : 1.0;
        final paintOrder =
            List<int>.generate(display.length, (index) => index)..sort((
              a,
              b,
            ) {
              final aPlaceholder = display[a].isEmpty;
              final bPlaceholder = display[b].isEmpty;
              if (aPlaceholder == bPlaceholder) return a.compareTo(b);
              return aPlaceholder ? -1 : 1;
            });
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final i in paintOrder)
              Positioned(
                left: (width * specs[i].x - specs[i].w / 2).clamp(
                  0.0,
                  math.max(0, width - specs[i].w),
                ),
                top: specs[i].y * heightScale,
                child: _FloatingMemoryChip(
                  text: display[i],
                  color: palette[i % palette.length],
                  placeholder: display[i].isEmpty,
                  phase: specs[i].phase,
                  width: specs[i].w,
                ),
              ),
          ],
        );
      },
    );
  }
}

const Set<String> _memoryCategoryLabels = {
  '姓名',
  '性别',
  '年龄',
  '职业',
  '职业与经济',
  '经济',
  '禁忌',
  '雷区',
  '禁忌/雷区',
  '人生观',
  '价值观',
  '信仰',
  '寄托',
  '信仰/寄托',
  '理想',
  '目标',
  '理想与目标',
  '身份',
  '情绪',
  '偏好边界',
  '生活',
  '思维',
  '其他',
  '日常',
};

bool _isMemoryCategoryLabel(String value) {
  final normalized = value.trim().replaceAll('／', '/');
  if (normalized.isEmpty) return true;
  if (_memoryCategoryLabels.contains(normalized)) return true;
  return _memoryCategoryLabels.any((label) => normalized == '$label为');
}

class _FloatingMemoryChip extends StatefulWidget {
  const _FloatingMemoryChip({
    required this.text,
    required this.color,
    required this.phase,
    required this.width,
    this.placeholder = false,
  });

  final String text;
  final Color color;
  final double phase;
  final double width;
  final bool placeholder;

  @override
  State<_FloatingMemoryChip> createState() => _FloatingMemoryChipState();
}

class _FloatingMemoryChipState extends State<_FloatingMemoryChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 每张 tag 各带一个本地 ticker(相位由 phase 错开)，做法跟"日常分享"页的
    // _DailyBreathingArt 一致：呼吸只在这一小块内重绘、被 RepaintBoundary
    // 隔离，不再靠页面级动画每帧重建整页 + 全部 tag——那才是之前卡顿的根因。
    // 周期 ~4.6s 的连续正弦，跟旧的 sin(progress*2π+phase) 同形但不牵连整页。
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4600),
      value: (widget.phase % (math.pi * 2)) / (math.pi * 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final placeholder = widget.placeholder;
    final width = widget.width;
    final text = widget.text;
    final colors = AppColors.of(context);
    // 卡片视觉内容是帧不变的(阴影固定)，用 RepaintBoundary 缓存成一张纹理；
    // 外面的浮动/呼吸只是在 GPU 上平移缩放这张现成纹理，不逐帧重画。
    final chip = RepaintBoundary(
      child: Container(
        width: width,
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: placeholder
              ? color.withValues(alpha: AppColors.isDark(context) ? 0.10 : 0.16)
              : color.withValues(
                  alpha: AppColors.isDark(context) ? 0.16 : 0.18,
                ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: placeholder
                ? color.withValues(
                    alpha: AppColors.isDark(context) ? 0.16 : 0.28,
                  )
                : color.withValues(alpha: .30),
          ),
          boxShadow: [
            BoxShadow(
              color: (placeholder ? Colors.white : color).withValues(
                alpha: AppColors.isDark(context) ? 0.05 : 0.13,
              ),
              blurRadius: 17,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: placeholder
              ? Container(
                      height: 14,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: color.withValues(
                          alpha: AppColors.isDark(context) ? 0.12 : 0.20,
                        ),
                      ),
                    )
                  : Text(
                      _chipEmoji(text) == null
                          ? text
                          : '${_chipEmoji(text)}  $text',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color.lerp(
                          color,
                          colors.text,
                          AppColors.isDark(context) ? 0.28 : 0.40,
                        ),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        );
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final wave = math.sin(_controller.value * math.pi * 2);
        return Transform.translate(
          offset: Offset(0, wave * 7),
          child: Transform.scale(scale: 1 + wave * .025, child: child),
        );
      },
      child: chip,
    );
  }
}

class _ChipSpec {
  const _ChipSpec(this.x, this.y, this.w, this.phase);

  final double x;
  final double y;
  final double w;
  final double phase;
}

List<_ChipSpec> _chipSpecs(int count) {
  const base = [
    _ChipSpec(.25, 12, 132, .1),
    _ChipSpec(.66, 20, 142, 1.2),
    _ChipSpec(.50, 70, 164, 2.4),
    _ChipSpec(.23, 86, 122, 3.1),
    _ChipSpec(.76, 92, 130, 4.0),
    _ChipSpec(.34, 142, 134, 5.0),
    _ChipSpec(.63, 150, 126, 2.0),
    _ChipSpec(.48, 194, 150, 3.7),
    _ChipSpec(.78, 184, 112, 1.7),
  ];
  return base.take(count).toList();
}
