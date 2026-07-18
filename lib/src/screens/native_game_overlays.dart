part of 'package:companion_flutter/main.dart';

class _NativeGameInteractionLayer extends StatefulWidget {
  const _NativeGameInteractionLayer({
    required this.runtime,
    required this.game,
    required this.child,
    required this.onPlayAgain,
    required this.onCloseGame,
    required this.userTurnActive,
    required this.turnToken,
    required this.turnTimeout,
    required this.turnLabel,
    required this.moveCount,
    this.showPlayers = true,
  });

  final _NativeGameRuntime runtime;
  final _GameTile game;
  final Widget child;
  final Future<void> Function() onPlayAgain;
  final Future<void> Function() onCloseGame;
  final bool userTurnActive;
  final String turnToken;
  final Duration turnTimeout;
  final String turnLabel;
  final int moveCount;
  final bool showPlayers;

  @override
  State<_NativeGameInteractionLayer> createState() =>
      _NativeGameInteractionLayerState();
}

class _NativeGameInteractionLayerState
    extends State<_NativeGameInteractionLayer> {
  @override
  void initState() {
    super.initState();
    _syncTimeout();
  }

  @override
  void didUpdateWidget(covariant _NativeGameInteractionLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userTurnActive != widget.userTurnActive ||
        oldWidget.turnToken != widget.turnToken ||
        oldWidget.turnTimeout != widget.turnTimeout) {
      _syncTimeout();
    }
  }

  void _syncTimeout() {
    widget.runtime.syncUserTurnTimeout(
      active: widget.userTurnActive,
      token: widget.turnToken,
      duration: widget.turnTimeout,
    );
  }

  @override
  Widget build(BuildContext context) {
    final runtime = widget.runtime;
    final content = widget.showPlayers
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NativePlayersTurnBar(
                runtime: runtime,
                userActive: widget.userTurnActive,
                agentActive:
                    runtime.aiThinking &&
                    !runtime.completed &&
                    !runtime.turnTimeoutVisible,
                turnLabel: widget.turnLabel,
                moveCount: widget.moveCount,
              ),
              const SizedBox(height: 12),
              widget.child,
            ],
          )
        : widget.child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        content,
        if (runtime.terminalPayload case final payload?)
          Positioned.fill(
            child: _NativeGameOverlay(
              key: ValueKey(
                '${runtime.session?.id}:${runtime.terminalPresentedAt?.microsecondsSinceEpoch}',
              ),
              gameKey: widget.game.nativeGameKey,
              gameTitle: widget.game.title,
              agentName: runtime.agentName,
              payload: payload,
              presentedAt: runtime.terminalPresentedAt ?? DateTime.now(),
              onPrimary: widget.onPlayAgain,
              onClose: widget.onCloseGame,
            ),
          )
        else if (runtime.turnTimeoutVisible)
          Positioned.fill(
            child: _NativeGameOverlay(
              gameKey: widget.game.nativeGameKey,
              gameTitle: widget.game.title,
              agentName: runtime.agentName,
              timeout: widget.turnTimeout,
              onPrimary: () async => runtime.continueAfterTurnTimeout(),
              onClose: widget.onCloseGame,
            ),
          ),
      ],
    );
  }
}

class _NativePlayersTurnBar extends StatefulWidget {
  const _NativePlayersTurnBar({
    required this.runtime,
    required this.userActive,
    required this.agentActive,
    required this.turnLabel,
    required this.moveCount,
  });

  final _NativeGameRuntime runtime;
  final bool userActive;
  final bool agentActive;
  final String turnLabel;
  final int moveCount;

  @override
  State<_NativePlayersTurnBar> createState() => _NativePlayersTurnBarState();
}

class _NativePlayersTurnBarState extends State<_NativePlayersTurnBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _pulse,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 330;
        return Row(
          children: [
            _NativePlayerIdentity(
              name: '你',
              imageUrl: widget.runtime.authSession.userAvatarUrl,
              active: widget.userActive,
              pulse: _pulse.value,
              compact: compact,
            ),
            Expanded(
              child: _NativeTurnStatus(
                label: widget.turnLabel,
                moveCount: widget.moveCount,
                active: widget.userActive || widget.agentActive,
              ),
            ),
            _NativePlayerIdentity(
              name: widget.runtime.agentName,
              imageUrl: widget.runtime.authSession.agentAvatarUrl,
              active: widget.agentActive,
              pulse: _pulse.value,
              compact: compact,
              alignEnd: true,
            ),
          ],
        );
      },
    ),
  );
}

class _NativePlayerIdentity extends StatelessWidget {
  const _NativePlayerIdentity({
    required this.name,
    required this.imageUrl,
    required this.active,
    required this.pulse,
    required this.compact,
    this.alignEnd = false,
  });

  final String name;
  final String? imageUrl;
  final bool active;
  final double pulse;
  final bool compact;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent;
    final avatar = Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: active
              ? accent.withValues(alpha: 0.72 + pulse * 0.28)
              : AppColors.text.withValues(alpha: 0.08),
          width: active ? 2.4 : 1,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.12 + pulse * 0.14),
                  blurRadius: 10 + pulse * 8,
                  spreadRadius: pulse * 1.5,
                ),
              ]
            : const [],
      ),
      child: _Avatar(
        size: compact ? 30 : 36,
        label: name.trim().isEmpty ? '?' : name.trim().characters.first,
        gradient: const [Color(0xFFEAF4FF), Color(0xFFDDE8FF)],
        imageUrl: imageUrl,
      ),
    );
    return SizedBox(
      width: compact ? 72 : 92,
      child: Row(
        mainAxisAlignment: alignEnd
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (alignEnd) ...[Flexible(child: _name()), const SizedBox(width: 7)],
          avatar,
          if (!alignEnd) ...[
            const SizedBox(width: 7),
            Flexible(child: _name()),
          ],
        ],
      ),
    );
  }

  Widget _name() => Text(
    name,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    textAlign: alignEnd ? TextAlign.right : TextAlign.left,
    style: TextStyle(
      color: AppColors.text.withValues(alpha: active ? 0.94 : 0.58),
      fontSize: compact ? 10 : 11,
      fontWeight: active ? FontWeight.w900 : FontWeight.w800,
    ),
  );
}

class _NativeTurnStatus extends StatelessWidget {
  const _NativeTurnStatus({
    required this.label,
    required this.moveCount,
    required this.active,
  });

  final String label;
  final int moveCount;
  final bool active;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.11)
              : AppColors.surfaceMuted.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active
                ? AppColors.accent.withValues(alpha: 0.24)
                : AppColors.text.withValues(alpha: 0.06),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active
                ? AppColors.accent
                : AppColors.text.withValues(alpha: 0.55),
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        '$moveCount 步',
        style: TextStyle(
          color: AppColors.text.withValues(alpha: 0.38),
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _NativeGameOverlay extends StatefulWidget {
  const _NativeGameOverlay({
    super.key,
    required this.gameKey,
    required this.gameTitle,
    required this.agentName,
    required this.onPrimary,
    required this.onClose,
    this.payload,
    this.presentedAt,
    this.timeout,
  });

  final String gameKey;
  final String gameTitle;
  final String agentName;
  final Map<String, dynamic>? payload;
  final DateTime? presentedAt;
  final Duration? timeout;
  final Future<void> Function() onPrimary;
  final Future<void> Function() onClose;

  bool get isTimeout => timeout != null;

  @override
  State<_NativeGameOverlay> createState() => _NativeGameOverlayState();
}

class _NativeGameOverlayState extends State<_NativeGameOverlay> {
  Timer? _countdown;
  int _seconds = 10;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isTimeout) {
      _tick();
      _countdown = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  void _tick() {
    final started = widget.presentedAt ?? DateTime.now();
    final remaining = 10 - DateTime.now().difference(started).inSeconds;
    if (remaining <= 0) {
      _countdown?.cancel();
      unawaited(_close());
      return;
    }
    if (mounted) setState(() => _seconds = remaining.clamp(1, 10).toInt());
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    _countdown?.cancel();
    await widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final visual = _NativeFullscreenVisual.forGame(widget.gameKey);
    final outcome = widget.payload?['user_outcome'] as String? ?? 'draw';
    final isCooperative = _nativeCooperativeGameKeys.contains(widget.gameKey);
    final title = widget.isTimeout
        ? '先别让这一回合停住'
        : isCooperative
        // 合作过关类游戏没有对手，胜负只看共同目标，绝不能出现
        // 「你赢了 / 对方拿下」这类对抗措辞。
        ? (outcome == 'win' ? '这一关，你们一起过了' : '这一关，差一点就过了')
        : switch (outcome) {
            'win' => '这一局，你赢了',
            'lose' => '${widget.agentName} 拿下了这一局',
            _ => '这一局打成平手',
          };
    final subtitle = widget.isTimeout
        ? '你已经有 ${widget.timeout!.inSeconds} 秒没有行动。可以继续想，也可以把这一局留在这里。'
        : _resultSubtitle(widget.gameKey, outcome, widget.agentName);
    final icon = widget.isTimeout
        ? Icons.hourglass_bottom_rounded
        : outcome == 'win'
        ? Icons.emoji_events_rounded
        : outcome == 'lose'
        ? Icons.handshake_outlined
        : Icons.balance_rounded;
    return ColoredBox(
      color: visual.ink.withValues(alpha: 0.72),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.88, end: 1),
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutBack,
            builder: (context, value, child) => Transform.scale(
              scale: value,
              child: Opacity(opacity: value.clamp(0, 1), child: child),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 390),
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(visual.chromeBackground, Colors.white, 0.18)!,
                    visual.chromeBackground,
                  ],
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: visual.accent.withValues(alpha: 0.62),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: visual.shadow.withValues(alpha: 0.48),
                    blurRadius: 34,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: visual.accent.withValues(alpha: 0.18),
                      border: Border.all(
                        color: visual.accent.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Icon(icon, color: visual.accent, size: 31),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.gameTitle,
                    style: TextStyle(
                      color: visual.chromeForeground.withValues(alpha: 0.62),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: visual.chromeForeground,
                      fontSize: 22,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: visual.chromeForeground.withValues(alpha: 0.66),
                      fontSize: 12,
                      height: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _NativeGameOverlayButton(
                    label: widget.isTimeout ? '继续这一回合' : '再来一局',
                    icon: widget.isTimeout
                        ? Icons.play_arrow_rounded
                        : Icons.refresh_rounded,
                    background: visual.accent,
                    foreground: _contrastColor(visual.accent),
                    onPressed: widget.onPrimary,
                  ),
                  const SizedBox(height: 9),
                  _NativeGameOverlayButton(
                    label: widget.isTimeout ? '结束本局' : '收起游戏 $_seconds s',
                    icon: widget.isTimeout
                        ? Icons.stop_circle_outlined
                        : Icons.keyboard_arrow_down_rounded,
                    background: visual.chromeForeground.withValues(alpha: 0.08),
                    foreground: visual.chromeForeground,
                    border: visual.chromeBorder,
                    onPressed: _close,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Color _contrastColor(Color color) =>
      color.computeLuminance() > 0.46 ? const Color(0xFF17130F) : Colors.white;

  static String _resultSubtitle(
    String gameKey,
    String outcome,
    String agentName,
  ) {
    final ending = outcome == 'win'
        ? '这次的节奏被你稳稳抓住了。'
        : outcome == 'lose'
        ? '输赢先放一边，这局的过程已经完整留下。'
        : '谁也没把谁甩开，正好再约一局。';
    return switch (gameKey) {
      _nativeMatch3GameKey =>
        outcome == 'win'
            ? '最后一串连消很漂亮，你和 $agentName 把这一关一起解开了。'
            : '就差最后一点能量。这局的连消和配合都已经保存，下次接着这个节奏再试一次。',
      _nativeMinesweeperGameKey =>
        outcome == 'win'
            ? '雷区已经清空，你和 $agentName 的每一步推理都对上了。'
            : '那颗雷藏得够深。你们的线索和选择已经保存，下局再一起把它找出来。',
      _nativeNumberMergeGameKey =>
        outcome == 'win'
            ? '数字终于合到目标，你和 $agentName 的接力没有断。'
            : '盘面满之前你们已经一起救回来好几次了。这局的合并过程已经保存，下次再合远一点。',
      _nativeChineseCheckersGameKey => '$ending 连跳路线和进营过程都已经保存。',
      _nativeGoGameKey => '$ending 棋形、提子和终局数目都已经保存。',
      _nativeReversiGameKey => '$ending 翻子和角落争夺都已经保存。',
      _nativeGomokuGameKey => '$ending 关键落子和攻防变化都已经保存。',
      _nativeXiangqiGameKey || _nativeChessGameKey => '$ending 棋谱和关键局面都已经保存。',
      _nativeTetrisDuelGameKey =>
        outcome == 'win'
            ? '最后几秒你把节奏顶住了。双方的消行、连击和进攻都已经保存。'
            : '$ending 双方的消行、连击和进攻都已经保存。',
      _ => ending,
    };
  }
}

class _NativeGameOverlayButton extends StatefulWidget {
  const _NativeGameOverlayButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.border,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color? border;
  final Future<void> Function() onPressed;

  @override
  State<_NativeGameOverlayButton> createState() =>
      _NativeGameOverlayButtonState();
}

class _NativeGameOverlayButtonState extends State<_NativeGameOverlayButton> {
  bool _pressed = false;
  bool _loading = false;

  Future<void> _tap() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: widget.label,
    child: GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        unawaited(_tap());
      },
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: widget.background,
            borderRadius: BorderRadius.circular(15),
            border: widget.border == null
                ? null
                : Border.all(color: widget.border!),
          ),
          alignment: Alignment.center,
          child: _loading
              ? CupertinoActivityIndicator(color: widget.foreground)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, color: widget.foreground, size: 19),
                    const SizedBox(width: 7),
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: widget.foreground,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    ),
  );
}

Duration _nativeGameTurnTimeout(String gameKey) => switch (gameKey) {
  _nativeGoGameKey => const Duration(seconds: 90),
  _nativeXiangqiGameKey || _nativeChessGameKey => const Duration(seconds: 90),
  _nativeChineseCheckersGameKey => const Duration(seconds: 60),
  _nativeGomokuGameKey || _nativeReversiGameKey => const Duration(seconds: 45),
  _nativeMinesweeperGameKey => const Duration(seconds: 45),
  _nativeNumberMergeGameKey => const Duration(seconds: 30),
  _nativeMatch3GameKey => const Duration(seconds: 25),
  _nativeTetrisDuelGameKey => const Duration(seconds: 15),
  _ => const Duration(seconds: 45),
};
