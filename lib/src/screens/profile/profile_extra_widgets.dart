part of 'package:companion_flutter/main.dart';

class _ProfileSectionV6 extends StatelessWidget {
  const _ProfileSectionV6({
    required this.title,
    required this.trailing,
    required this.child,
  });

  final String title;
  final String trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : const Color(0x14181F2A),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? AppColors.text : const Color(0xFF12171B),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    trailing,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _ProfileSettingRowV6 extends StatelessWidget {
  const _ProfileSettingRowV6({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    this.enabled = true,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = enabled && onTap != null;
    return Tooltip(
      message: active ? title : '暂未开放',
      child: InkWell(
        onTap: active ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : const Color(0x14181F2A),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: enabled ? 1 : 0.45),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark
                              ? AppColors.text
                              : const Color(0xFF12171B),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark
                              ? const Color(0x9EEBF2EE)
                              : AppColors.muted,
                          fontSize: 11.2,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '›',
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.32)
                        : const Color(0x52182026),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileBackgroundPainter extends CustomPainter {
  const _ProfileBackgroundPainter({
    required this.progress,
    required this.isDark,
  });

  final double progress;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? const [Color(0xFF101614), Color(0xFF0D1211)]
            : const [Color(0xFFFFFAF4), Color(0xFFF9FBFF), Color(0xFFEEF9F8)],
        stops: isDark ? null : const [0, 0.5, 1],
      ).createShader(rect);
    canvas.drawRect(rect, basePaint);

    _drawRadial(
      canvas,
      center: Offset(size.width * 0.82, size.height * 0.08),
      radius: 280,
      color: const Color(0xFF1F6FFF).withValues(alpha: isDark ? 0.16 : 0.20),
    );
    _drawRadial(
      canvas,
      center: Offset(size.width * 0.08, size.height * 0.26),
      radius: 230,
      color: (isDark ? const Color(0xFF7C3CFF) : const Color(0xFFFF8A3D))
          .withValues(alpha: isDark ? 0.13 : 0.16),
    );
    if (!isDark) {
      _drawRadial(
        canvas,
        center: Offset(size.width * 0.78, size.height * 0.68),
        radius: 260,
        color: const Color(0xFF7C3CFF).withValues(alpha: 0.12),
      );
    }

    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : const Color(0xFF202D3A)).withValues(
        alpha: isDark ? 0.025 : 0.042,
      )
      ..strokeWidth = 1;
    const step = 36.0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (!isDark) {
      _drawRadial(
        canvas,
        center: Offset(size.width * 0.84, size.height * 0.18),
        radius: 280,
        color: Colors.white.withValues(alpha: 0.66),
      );
    }
  }

  void _drawRadial(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
      ).createShader(rect);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _ProfileBackgroundPainter oldDelegate) {
    return progress != oldDelegate.progress || isDark != oldDelegate.isDark;
  }
}

enum _DeleteGlassPhase { running, success, error }

class _DeleteGlassStep {
  const _DeleteGlassStep({
    required this.label,
    required this.detail,
    required this.icon,
    required this.statKeys,
  });

  final String label;
  final String detail;
  final IconData icon;
  final List<String> statKeys;
}

const _kDeleteGlassSteps = <_DeleteGlassStep>[
  _DeleteGlassStep(
    label: '聊天记录',
    detail: '对话与消息',
    icon: CupertinoIcons.chat_bubble_2,
    statKeys: ['messages', 'conversations'],
  ),
  _DeleteGlassStep(
    label: '记忆与画像',
    detail: '记忆库、向量与画像',
    icon: CupertinoIcons.square_stack_3d_up,
    statKeys: [
      'user_memories',
      'ai_memories',
      'embeddings',
      'portraits',
      'profiles',
      'changelogs',
    ],
  ),
  _DeleteGlassStep(
    label: '关系与作息',
    detail: '亲密度、作息与主动消息',
    icon: CupertinoIcons.heart,
    statKeys: [
      'intimacy',
      'schedules',
      'triggers',
      'proactive_logs',
      'proactive_states',
      'proactive_event_logs',
    ],
  ),
  _DeleteGlassStep(
    label: '游戏对局',
    detail: '对局记录、过程与熟练度',
    icon: CupertinoIcons.game_controller,
    statKeys: ['game_sessions', 'game_events', 'native_game_skill_states'],
  ),
  _DeleteGlassStep(
    label: '缓存与会话',
    detail: '运行时状态',
    icon: CupertinoIcons.bolt,
    statKeys: ['redis'],
  ),
  _DeleteGlassStep(
    label: '好友资料',
    detail: '这位好友的主记录',
    icon: CupertinoIcons.person_crop_circle,
    statKeys: ['agent'],
  ),
];

class _AgentDeleteGlassOverlay extends StatefulWidget {
  const _AgentDeleteGlassOverlay({
    required this.agentName,
    required this.delete,
  });

  final String agentName;
  final Future<AgentDeleteResult> Function() delete;

  @override
  State<_AgentDeleteGlassOverlay> createState() =>
      _AgentDeleteGlassOverlayState();
}

class _AgentDeleteGlassOverlayState extends State<_AgentDeleteGlassOverlay>
    with TickerProviderStateMixin {
  static const _minWalk = Duration(milliseconds: 380);

  late final AnimationController _motion;
  late final AnimationController _enter;
  Timer? _walk;
  _DeleteGlassPhase _phase = _DeleteGlassPhase.running;
  int _index = 0;
  bool _requestDone = false;
  bool _finishing = false;
  AgentDeleteResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..forward();
    _walk = Timer.periodic(_minWalk, (_) {
      if (!mounted || _phase != _DeleteGlassPhase.running) return;
      final last = _kDeleteGlassSteps.length - 1;
      if (_index < last) {
        setState(() => _index += 1);
        return;
      }
      if (_requestDone) unawaited(_complete());
    });
    unawaited(_run());
  }

  @override
  void dispose() {
    _walk?.cancel();
    _motion.dispose();
    _enter.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    try {
      final result = await widget.delete();
      if (!mounted) return;
      if (!result.ok) {
        throw StateError('delete failed');
      }
      _result = result;
      _requestDone = true;
      if (_index >= _kDeleteGlassSteps.length - 1) {
        await _complete();
      }
    } catch (error) {
      if (!mounted) return;
      _walk?.cancel();
      setState(() {
        _phase = _DeleteGlassPhase.error;
        _error = _asMessage(error);
      });
    }
  }

  bool _rowFinished(int index) {
    if (_phase == _DeleteGlassPhase.success) return true;
    return _phase == _DeleteGlassPhase.running && index < _index;
  }

  Future<void> _complete() async {
    if (_finishing || !mounted || _result == null) return;
    _finishing = true;
    _walk?.cancel();
    _motion.stop();
    setState(() => _phase = _DeleteGlassPhase.success);
    // Keep the finished list on screen, then the shell opens agent create.
    await Future<void>.delayed(const Duration(seconds: 5));
    if (!mounted) return;
    Navigator.of(context).pop(_result);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _SettingsColors.isDark;
    final progress = _phase == _DeleteGlassPhase.success
        ? 1.0
        : (_index + 0.35) / _kDeleteGlassSteps.length;
    return PopScope(
      canPop: _phase == _DeleteGlassPhase.error,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            const Positioned.fill(child: _DeleteGlassScrim()),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: -48,
                          right: -6,
                          child: PlatformSoftAura(
                            size: const Size(168, 168),
                            color: _SettingsColors.blueDark.withValues(
                              alpha: isDark ? 0.28 : 0.22,
                            ),
                            blur: 36,
                          ),
                        ),
                        Positioned(
                          bottom: -36,
                          left: -18,
                          child: PlatformSoftAura(
                            size: const Size(140, 140),
                            color: const Color(
                              0xFFF3A66E,
                            ).withValues(alpha: isDark ? 0.16 : 0.18),
                            blur: 32,
                          ),
                        ),
                        _DeleteGlassCard(
                          isDark: isDark,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _DeleteGlassRing(
                                  motion: _motion,
                                  done: _phase == _DeleteGlassPhase.success,
                                  failed: _phase == _DeleteGlassPhase.error,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  _phase == _DeleteGlassPhase.error
                                      ? '删除未完成'
                                      : '删除「${widget.agentName}」',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _SettingsColors.text,
                                    fontSize: 20,
                                    height: 1.2,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _phase == _DeleteGlassPhase.success
                                      ? '这些数据已经清除'
                                      : _phase == _DeleteGlassPhase.error
                                      ? (_error ?? '请稍后再试')
                                      : '正在清除和这位好友有关的数据',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _SettingsColors.tertiary,
                                    fontSize: 13,
                                    height: 1.35,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _DeleteGlassTrack(
                                  progress: progress,
                                  done: _phase == _DeleteGlassPhase.success,
                                ),
                                const SizedBox(height: 8),
                                AnimatedBuilder(
                                  animation: _enter,
                                  builder: (context, _) {
                                    return Column(
                                      children: [
                                        for (
                                          var i = 0;
                                          i < _kDeleteGlassSteps.length;
                                          i++
                                        )
                                          _DeleteGlassRow(
                                            step: _kDeleteGlassSteps[i],
                                            index: i,
                                            enter: _enter.value,
                                            active:
                                                _phase ==
                                                    _DeleteGlassPhase.running &&
                                                i == _index,
                                            finished: _rowFinished(i),
                                            showCount:
                                                _phase ==
                                                _DeleteGlassPhase.success,
                                            count: _countFor(
                                              _kDeleteGlassSteps[i].statKeys,
                                              _result?.stats,
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '游戏积分跟账号走，删除好友不会清掉余额',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _SettingsColors.tertiary.withValues(
                                      alpha: 0.9,
                                    ),
                                    fontSize: 11,
                                    height: 1.35,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0,
                                  ),
                                ),
                                if (_phase == _DeleteGlassPhase.error) ...[
                                  const SizedBox(height: 12),
                                  CupertinoButton(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 8,
                                    ),
                                    color: _SettingsColors.blueDark.withValues(
                                      alpha: 0.16,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: Text(
                                      '关闭',
                                      style: TextStyle(
                                        color: _SettingsColors.text,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
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

int _countFor(List<String> keys, Map<String, int>? stats) {
  if (stats == null) return 0;
  var total = 0;
  for (final key in keys) {
    total += stats[key] ?? 0;
  }
  return total;
}

class _DeleteGlassScrim extends StatelessWidget {
  const _DeleteGlassScrim();

  @override
  Widget build(BuildContext context) {
    final isDark = _SettingsColors.isDark;
    final tint = isDark ? const Color(0x80101820) : const Color(0x73F4F7FB);
    if (useLightweightGlassEffects) {
      return ColoredBox(color: tint);
    }
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
      child: ColoredBox(color: tint),
    );
  }
}

class _DeleteGlassCard extends StatelessWidget {
  const _DeleteGlassCard({required this.isDark, required this.child});

  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final lineAlpha = isDark ? 0.38 : 0.95;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned.fill(
              child: isDark
                  ? const _DeleteGlassSurface.dark()
                  : const _DeleteGlassSurface.light(),
            ),
            child,
            Positioned(
              top: 0,
              left: 22,
              right: 22,
              child: IgnorePointer(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(alpha: lineAlpha),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
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

/// Static glass fill. Const so a step change does not rebuild the blur layer.
class _DeleteGlassSurface extends StatelessWidget {
  const _DeleteGlassSurface.dark() : isDark = true;

  const _DeleteGlassSurface.light() : isDark = false;

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final fill = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xE01C2836), Color(0xCC141C28)]
              : const [Color(0xF2FFFFFF), Color(0xD6F4F8FC)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.16 : 0.86),
        ),
      ),
    );
    if (useLightweightGlassEffects) return fill;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
      child: fill,
    );
  }
}

class _DeleteGlassRing extends StatelessWidget {
  const _DeleteGlassRing({
    required this.motion,
    required this.done,
    required this.failed,
  });

  final Animation<double> motion;
  final bool done;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final color = failed
        ? _SettingsColors.red
        : done
        ? const Color(0xFF2F9E6B)
        : _SettingsColors.blueDark;
    return SizedBox(
      width: 58,
      height: 58,
      child: AnimatedBuilder(
        animation: motion,
        builder: (context, _) {
          return CustomPaint(
            painter: _DeleteGlassRingPainter(
              turn: done ? 0 : motion.value,
              done: done,
              color: color,
              track: Colors.white.withValues(
                alpha: _SettingsColors.isDark ? 0.14 : 0.55,
              ),
            ),
            child: Center(
              child: Icon(
                failed
                    ? CupertinoIcons.exclamationmark
                    : done
                    ? CupertinoIcons.check_mark
                    : CupertinoIcons.trash,
                size: done ? 22 : 18,
                color: color,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DeleteGlassRingPainter extends CustomPainter {
  const _DeleteGlassRingPainter({
    required this.turn,
    required this.done,
    required this.color,
    required this.track,
  });

  final double turn;
  final bool done;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 2.4;
    final rect = (Offset.zero & size).deflate(stroke);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    canvas.drawArc(
      rect,
      done ? -math.pi / 2 : (turn * math.pi * 2) - math.pi / 2,
      done ? math.pi * 2 : math.pi * 0.7,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _DeleteGlassRingPainter oldDelegate) {
    return oldDelegate.turn != turn ||
        oldDelegate.done != done ||
        oldDelegate.color != color;
  }
}

class _DeleteGlassTrack extends StatelessWidget {
  const _DeleteGlassTrack({required this.progress, required this.done});

  final double progress;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final isDark = _SettingsColors.isDark;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: progress.clamp(0, 1)),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.55),
                ),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value == 0 ? 0.001 : value,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: done
                            ? const [Color(0xFF7DCEA0), Color(0xFF2F9E6B)]
                            : const [Color(0xFF8EC4EA), Color(0xFF5A9CC8)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DeleteGlassRow extends StatelessWidget {
  const _DeleteGlassRow({
    required this.step,
    required this.index,
    required this.enter,
    required this.active,
    required this.finished,
    required this.showCount,
    required this.count,
  });

  final _DeleteGlassStep step;
  final int index;
  final double enter;
  final bool active;
  final bool finished;
  final bool showCount;
  final int count;

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.07).clamp(0.0, 0.6);
    final t = Interval(
      start,
      (start + 0.4).clamp(0.0, 1.0),
      curve: Curves.easeOutCubic,
    ).transform(enter.clamp(0, 1));
    final titleColor = active || finished
        ? _SettingsColors.text
        : _SettingsColors.text.withValues(alpha: 0.72);
    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, (1 - t) * 10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          child: Row(
            children: [
              _DeleteGlassMark(
                icon: step.icon,
                active: active,
                finished: finished,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.label,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      active ? '正在清除' : step.detail,
                      style: TextStyle(
                        color: _SettingsColors.tertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              if (showCount && count > 0)
                Text(
                  '$count',
                  style: TextStyle(
                    color: _SettingsColors.tertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteGlassMark extends StatelessWidget {
  const _DeleteGlassMark({
    required this.icon,
    required this.active,
    required this.finished,
  });

  final IconData icon;
  final bool active;
  final bool finished;

  @override
  Widget build(BuildContext context) {
    final isDark = _SettingsColors.isDark;
    final color = finished
        ? const Color(0xFF2F9E6B)
        : active
        ? _SettingsColors.blueDark
        : _SettingsColors.tertiary;
    // Circle chrome stays constant. Only the glyph crossfades, so finishing
    // a row does not flash a highlight on and off.
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.62),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.14 : 0.85),
        ),
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: active
              ? CupertinoActivityIndicator(
                  key: const ValueKey('spin'),
                  radius: 7,
                  color: color,
                )
              : Icon(
                  key: ValueKey(finished ? 'check' : 'icon'),
                  finished ? CupertinoIcons.check_mark : icon,
                  size: 13,
                  color: color,
                ),
        ),
      ),
    );
  }
}
