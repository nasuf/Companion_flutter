part of 'package:companion_flutter/main.dart';

class _ActivitySwipeDeck extends StatefulWidget {
  const _ActivitySwipeDeck({
    required this.activities,
    required this.authToken,
    required this.working,
    required this.onAccept,
    required this.onIgnore,
    required this.onOpen,
  });

  final List<OfflineActivity> activities;
  final String? authToken;
  final bool working;
  final Future<Object?> Function(OfflineActivity activity) onAccept;
  final Future<bool> Function(OfflineActivity activity) onIgnore;
  final void Function(OfflineActivity activity) onOpen;

  @override
  State<_ActivitySwipeDeck> createState() => _ActivitySwipeDeckState();
}

class _ActivitySwipeDeckState extends State<_ActivitySwipeDeck> {
  Offset _drag = Offset.zero;
  bool _settling = false;
  bool _dragging = false;

  OfflineActivity get _topActivity => widget.activities.first;

  void _onPanStart(DragStartDetails details) {
    if (widget.working || _settling || widget.activities.isEmpty) return;
    setState(() => _dragging = true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (widget.working || _settling || widget.activities.isEmpty) return;
    setState(() => _drag += details.delta);
  }

  Future<void> _onPanEnd(DragEndDetails details) async {
    if (widget.working || _settling || widget.activities.isEmpty) {
      _resetDrag();
      return;
    }
    setState(() => _dragging = false);
    final velocity = details.velocity.pixelsPerSecond.dx;
    final dx = _drag.dx + velocity * 0.08;
    if (dx > 118) {
      await _commitSwipe(accepted: true);
    } else if (dx < -118) {
      await _commitSwipe(accepted: false);
    } else {
      _resetDrag();
    }
  }

  Future<void> _commitSwipe({required bool accepted}) async {
    if (_settling || widget.working || widget.activities.isEmpty) return;
    final activity = _topActivity;
    setState(() {
      _settling = true;
      _dragging = false;
      _drag = Offset(accepted ? 420 : -420, _drag.dy);
    });
    if (accepted) {
      await widget.onAccept(activity);
    } else {
      await widget.onIgnore(activity);
    }
    if (!mounted) return;
    setState(() {
      _drag = Offset.zero;
      _settling = false;
      _dragging = false;
    });
  }

  void _resetDrag() {
    if (!mounted || (_drag == Offset.zero && !_dragging)) return;
    setState(() {
      _drag = Offset.zero;
      _dragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final top = _topActivity;
    final rotation = (_drag.dx / 760).clamp(-0.16, 0.16).toDouble();
    final actionStrength = (_drag.dx.abs() / 140).clamp(0.0, 1.0).toDouble();
    final accepting = _drag.dx > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _ActivityStateBadge(
              label: '待确定 ${widget.activities.length}个',
              color: const Color(0xFFD88A42),
            ),
            const Spacer(),
            Text(
              '右滑接受 · 左滑暂不考虑',
              style: _mutedStyle(context, 12).copyWith(
                fontWeight: FontWeight.w800,
                color: colors.muted.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 616,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              for (var index = widget.activities.length - 1; index >= 1; index--)
                if (index < 3)
                  _ActivityDeckBackCard(
                    activity: widget.activities[index],
                    authToken: widget.authToken,
                    depth: index,
                  ),
              AnimatedContainer(
                duration: _dragging
                    ? Duration.zero
                    : _settling
                    ? const Duration(milliseconds: 160)
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                transform: Matrix4.identity()
                  ..translateByDouble(_drag.dx, _drag.dy * 0.22, 0, 1)
                  ..rotateZ(rotation),
                transformAlignment: Alignment.center,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: Stack(
                    children: [
                      _ActivityHeroCard(
                        activity: top,
                        authToken: widget.authToken,
                        working: widget.working || _settling,
                        onAccept: () => _commitSwipe(accepted: true),
                        onIgnore: () => _commitSwipe(accepted: false),
                        onOpen: () => widget.onOpen(top),
                      ),
                      if (actionStrength > 0.02)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: _SwipeIntentOverlay(
                              accepting: accepting,
                              opacity: actionStrength,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActivityDeckBackCard extends StatelessWidget {
  const _ActivityDeckBackCard({
    required this.activity,
    required this.authToken,
    required this.depth,
  });

  final OfflineActivity activity;
  final String? authToken;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final offset = 12.0 * depth;
    final scale = 1 - depth * 0.035;
    return Positioned(
      top: offset,
      left: 8 + depth * 5,
      right: 8 + depth * 5,
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.topCenter,
        child: Opacity(
          opacity: depth == 1 ? 0.54 : 0.28,
          child: Container(
            height: 586,
            decoration: _softCardDecoration(context).copyWith(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Column(
                children: [
                  _ActivityImage(
                    activity: activity,
                    height: 176,
                    authToken: authToken,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      color: AppColors.of(context).surface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeIntentOverlay extends StatelessWidget {
  const _SwipeIntentOverlay({required this.accepting, required this.opacity});

  final bool accepting;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final color = accepting
        ? const Color(0xFF4BCB84)
        : const Color(0xFFE08A51);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: color.withValues(alpha: 0.42 * opacity)),
        gradient: LinearGradient(
          begin: accepting ? Alignment.topLeft : Alignment.topRight,
          end: accepting ? Alignment.bottomRight : Alignment.bottomLeft,
          colors: [
            color.withValues(alpha: 0.20 * opacity),
            Colors.transparent,
            Colors.white.withValues(alpha: 0.08 * opacity),
          ],
        ),
      ),
      child: Align(
        alignment: accepting ? Alignment.topLeft : Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Transform.rotate(
            angle: accepting ? -0.16 : 0.16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.92 * opacity),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
              ),
              child: Text(
                accepting ? '接受邀请' : '暂不考虑',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: opacity),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
