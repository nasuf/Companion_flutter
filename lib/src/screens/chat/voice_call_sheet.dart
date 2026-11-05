part of 'package:companion_flutter/main.dart';

/// Full-screen voice call page, presented like the other chat sheets (gift,
/// red packet): a fullscreen-dialog route with a glass close button top-left.
///
/// Design: dark gradient background, centered agent avatar with animated
/// ripple rings during speech, prominent end-call button. Audio-only: the
/// conversation is heard, not read.
class VoiceCallSheet extends StatefulWidget {
  const VoiceCallSheet({
    super.key,
    required this.api,
    required this.session,
    required this.conversationId,
    required this.agentAvatarUrl,
    required this.agentDisplayName,
  });

  final CompanionApi api;
  final AuthSession session;
  final String conversationId;
  final String? agentAvatarUrl;
  final String agentDisplayName;

  static Future<void> show(
    BuildContext context, {
    required CompanionApi api,
    required AuthSession session,
    required String conversationId,
    required String? agentAvatarUrl,
    required String agentDisplayName,
  }) {
    return Navigator.of(context).push<void>(
      CompanionPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => VoiceCallSheet(
          api: api,
          session: session,
          conversationId: conversationId,
          agentAvatarUrl: agentAvatarUrl,
          agentDisplayName: agentDisplayName,
        ),
      ),
    );
  }

  @override
  State<VoiceCallSheet> createState() => _VoiceCallSheetState();
}

enum _CallPhase { connecting, idle, userSpeaking, aiSpeaking }

class _VoiceCallSheetState extends State<VoiceCallSheet>
    with TickerProviderStateMixin {
  late final VoiceCallSocket _socket;
  late final VoiceMicStream _mic;
  late final VoicePcmPlayer _player;

  _CallPhase _phase = _CallPhase.connecting;

  Timer? _durationTimer;
  int _callSeconds = 0;
  bool _disposed = false;
  bool _ending = false;

  // Ripple animation
  late final AnimationController _rippleCtrl;
  late final Animation<double> _rippleAnim;

  // Pulse animation for avatar
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  // Always running: drives the ring rotation and the connected halo's breath.
  late final AnimationController _ambientCtrl;
  // One-shot burst when the call connects.
  late final AnimationController _connectCtrl;

  StreamSubscription? _statusSub;
  StreamSubscription? _audioSub;
  StreamSubscription? _eventSub;

  @override
  void initState() {
    super.initState();
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _rippleAnim = CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();
    _connectCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _mic = VoiceMicStream(sampleRate: 24000);
    _player = VoicePcmPlayer(sampleRate: 24000);
    _player.onPlayingChanged = _onPlayingChanged;

    _socket = VoiceCallSocket(
      baseUrl: widget.api.baseUrl,
      conversationId: widget.conversationId,
      ticketProvider: () =>
          widget.api.getWebSocketTicket(widget.conversationId),
    );

    _listen();
    _connect();
  }

  void _listen() {
    _statusSub = _socket.statusStream.listen((status) {
      if (_disposed) return;
      switch (status) {
        case VoiceCallStatus.ready:
          unawaited(_startAudio());
        case VoiceCallStatus.error:
          _showError(
            _socket.errorMessage ??
                (_phase == _CallPhase.connecting
                    ? '连接失败，请稍后重试'
                    : '通话连接中断，请稍后重试'),
          );
          _endCall();
        case VoiceCallStatus.ended:
          _endCall();
        default:
          break;
      }
    });

    _audioSub = _socket.audioChunks.listen((chunk) {
      _player.addChunk(chunk);
    });

    _eventSub = _socket.rawEvents.listen((type) {
      if (_disposed || !mounted) return;
      switch (type) {
        case 'speech.started':
          // Barge-in. StepFun finishes generating long before playback
          // ends, so most of the reply is still queued here: drop it now
          // rather than talk over the user.
          _player.clear();
          setState(() => _phase = _CallPhase.userSpeaking);
          _rippleCtrl.repeat();
          _pulseCtrl.stop();
          _pulseCtrl.value = 0;
        case 'speech.stopped':
          setState(() => _phase = _CallPhase.idle);
          _rippleCtrl.stop();
          _rippleCtrl.value = 0;
        case 'interrupted':
          // Barge-in: drop the agent's unplayed audio; the player's drain
          // callback moves the phase back to idle.
          _player.clear();
        case 'session.expiring':
          // Could show a warning; for now just let it end naturally.
          break;
      }
    });
  }

  Future<void> _connect() async {
    // A failed connect also emits VoiceCallStatus.error, whose handler
    // reports it; ending here too is safe because _endCall runs once. Popping
    // directly would pop the chat page as well once that handler ran.
    final ok = await _socket.connect();
    if (!ok && !_disposed) unawaited(_endCall());
  }

  /// Speaker first, then microphone: on iOS the recorder re-applies the
  /// playAndRecord session with the speaker route the player relies on.
  Future<void> _startAudio() async {
    try {
      await _player.init();
    } catch (_) {
      if (_disposed) return;
      _showError('无法打开扬声器，请稍后重试');
      unawaited(_endCall());
      return;
    }
    if (_disposed) return;
    final ok = await _mic.start(onData: _socket.sendAudio);
    if (_disposed) return;
    if (!ok) {
      _showError('需要麦克风权限才能进行语音通话');
      unawaited(_endCall());
      return;
    }
    _startDurationTimer();
    // Let the agent say hello first.
    _socket.sendGreet();
    if (!mounted) return;
    setState(() => _phase = _CallPhase.idle);
    _connectCtrl.forward(from: 0);
    unawaited(HapticFeedback.mediumImpact());
  }

  void _onPlayingChanged(bool playing) {
    if (_disposed || !mounted) return;
    if (playing) {
      setState(() => _phase = _CallPhase.aiSpeaking);
      _pulseCtrl.repeat(reverse: true);
      _rippleCtrl.stop();
      _rippleCtrl.value = 0;
    } else if (_phase == _CallPhase.aiSpeaking) {
      setState(() => _phase = _CallPhase.idle);
      _pulseCtrl.stop();
      _pulseCtrl.value = 0;
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callSeconds++);
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  /// Hangs up at once, with a short tap and the hang-up tone instead of a
  /// confirmation dialog.
  Future<void> _endCall() async {
    if (_ending) return;
    _ending = true;
    unawaited(HapticFeedback.mediumImpact());
    _durationTimer?.cancel();
    _rippleCtrl.stop();
    _pulseCtrl.stop();
    _ambientCtrl.stop();
    await _mic.stop();
    await _socket.dispose();
    await _player.dispose();
    // After the PCM player releases its audio session, so it can't cut the
    // tone off; the tone player outlives this page.
    _playHangUpTone();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _disposed = true;
    _durationTimer?.cancel();
    _statusSub?.cancel();
    _audioSub?.cancel();
    _eventSub?.cancel();
    _rippleCtrl.dispose();
    _pulseCtrl.dispose();
    _ambientCtrl.dispose();
    _connectCtrl.dispose();
    _mic.dispose();
    unawaited(_player.dispose());
    unawaited(_socket.dispose());
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _statusText => switch (_phase) {
    _CallPhase.connecting => '正在连接…',
    _CallPhase.idle => '通话中',
    _CallPhase.userSpeaking => '正在聆听…',
    _CallPhase.aiSpeaking => '正在说话…',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return PopScope(
      canPop: _ending,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_endCall());
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [const Color(0xFF0A1628), const Color(0xFF0D1F35)]
                    : [const Color(0xFF1A2A42), const Color(0xFF0F1E30)],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  const Spacer(flex: 2),
                  _buildAvatar(),
                  const SizedBox(height: 20),
                  _buildAgentName(),
                  const SizedBox(height: 8),
                  _buildStatusLine(),
                  const Spacer(flex: 3),
                  _buildEndCallButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Same header geometry as the gift sheets: 44pt bar, 36pt glass close
  /// button pinned left, title centered on the screen axis.
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
      child: SizedBox(
        height: 44,
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: Text(
                  _phase == _CallPhase.connecting
                      ? '语音通话'
                      : _formatDuration(_callSeconds),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: _VoiceCallCloseButton(onTap: () => _endCall()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return _CallAvatar(
      phase: _phase,
      avatarUrl: widget.agentAvatarUrl,
      ambient: _ambientCtrl,
      pulse: _pulseCtrl,
      pulseScale: _pulseAnim,
      ripple: _rippleAnim,
      connect: _connectCtrl,
    );
  }

  Widget _buildAgentName() {
    return Text(
      widget.agentDisplayName,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildStatusLine() {
    final color = switch (_phase) {
      _CallPhase.connecting => Colors.white38,
      _CallPhase.idle => Colors.white70,
      _CallPhase.userSpeaking => AppColors.accentCyan,
      _CallPhase.aiSpeaking => AppColors.accent,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_phase == _CallPhase.connecting)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
            ),
          ),
        if (_phase == _CallPhase.idle)
          Padding(
            padding: const EdgeInsets.only(right: 7),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.7),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        if (_phase == _CallPhase.userSpeaking ||
            _phase == _CallPhase.aiSpeaking)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _AnimatedDots(color: color),
          ),
        Text(_statusText, style: TextStyle(color: color, fontSize: 14)),
      ],
    );
  }

  Widget _buildEndCallButton() {
    return GestureDetector(
      onTap: () => _endCall(),
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFFF4455),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF4455).withValues(alpha: 0.4),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(
          Icons.call_end_rounded,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }
}

/// Frosted-glass close button tuned for the dark call background; same 36pt
/// circle as `_GiftSheetCloseButton`.
/// The agent avatar and everything that signals the call state around it:
/// a white arc spins while connecting; once connected a gradient ring turns
/// slowly and a halo breathes, blue (accent) while the agent talks (stronger, in
/// time with the pulse) and cyan with ripples while the user talks.
class _CallAvatar extends StatelessWidget {
  const _CallAvatar({
    required this.phase,
    required this.avatarUrl,
    required this.ambient,
    required this.pulse,
    required this.pulseScale,
    required this.ripple,
    required this.connect,
  });

  final _CallPhase phase;
  final String? avatarUrl;
  final Animation<double> ambient;
  final Animation<double> pulse;
  final Animation<double> pulseScale;
  final Animation<double> ripple;
  final Animation<double> connect;

  static const _avatarSize = 110.0;
  static const _ringSize = _avatarSize + 12;

  @override
  Widget build(BuildContext context) {
    final connected = phase != _CallPhase.connecting;
    final glow = phase == _CallPhase.userSpeaking
        ? AppColors.accentCyan
        : AppColors.accent;
    return SizedBox(
      width: _avatarSize + 90,
      height: _avatarSize + 90,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (connected)
            TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: glow),
              duration: const Duration(milliseconds: 300),
              builder: (_, color, __) => AnimatedBuilder(
                animation: Listenable.merge([ambient, pulse, connect]),
                builder: (_, __) => _halo(color ?? glow),
              ),
            ),
          if (phase == _CallPhase.userSpeaking) ..._rippleRings(),
          _connectBurst(),
          AnimatedBuilder(
            animation: ambient,
            builder: (_, __) => CustomPaint(
              size: const Size.square(_ringSize),
              painter: connected
                  ? _CallRingPainter(
                      rotation: ambient.value * 2 * math.pi,
                      strokeWidth: 2.5,
                      colors: [
                        AppColors.accent,
                        AppColors.accentCyan,
                        AppColors.accent.withValues(alpha: 0.35),
                        AppColors.accentCyan,
                        AppColors.accent,
                      ],
                    )
                  : _CallRingPainter(
                      rotation: ambient.value * 6 * math.pi,
                      strokeWidth: 2,
                      base: Colors.white.withValues(alpha: 0.12),
                      colors: [
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(alpha: 0.75),
                      ],
                    ),
            ),
          ),
          ScaleTransition(
            scale: phase == _CallPhase.aiSpeaking
                ? pulseScale
                : const AlwaysStoppedAnimation(1.0),
            child: ClipOval(
              child: SizedBox(
                width: _avatarSize,
                height: _avatarSize,
                child: AgentAvatarImage(
                  imageUrl: avatarUrl,
                  width: _avatarSize,
                  height: _avatarSize,
                  fit: BoxFit.cover,
                  fallback: Container(
                    color: AppColors.accentSoft,
                    child: Icon(
                      Icons.person,
                      size: _avatarSize * 0.5,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _halo(Color color) {
    // 3 s breath, inside the 6 s ambient cycle.
    final breath = 0.5 - 0.5 * math.cos(ambient.value * 4 * math.pi);
    final talking = phase == _CallPhase.aiSpeaking ? pulse.value : 0.0;
    final burst = connect.value > 0 && connect.value < 1
        ? 1 - connect.value
        : 0.0;
    final strength = (0.22 + 0.10 * breath + 0.28 * talking + 0.35 * burst)
        .clamp(0.0, 0.8);
    return Container(
      width: _ringSize,
      height: _ringSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: strength),
            blurRadius: 26 + 10 * breath + 14 * talking,
            spreadRadius: 2 + 4 * breath + 6 * talking + 6 * burst,
          ),
        ],
      ),
    );
  }

  Widget _connectBurst() {
    return AnimatedBuilder(
      animation: connect,
      builder: (_, __) {
        final value = connect.value;
        if (value <= 0 || value >= 1) return const SizedBox.shrink();
        final t = Curves.easeOutCubic.transform(value);
        final size = _ringSize + 76 * t;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.75 * (1 - t)),
              width: 2.5,
            ),
          ),
        );
      },
    );
  }

  List<Widget> _rippleRings() {
    return List.generate(3, (i) {
      final delay = i * 0.33;
      return AnimatedBuilder(
        animation: ripple,
        builder: (_, __) {
          final t = (ripple.value + delay) % 1.0;
          final scale = 1.0 + t * 0.5;
          final opacity = (1.0 - t).clamp(0.0, 0.4);
          return Container(
            width: (_ringSize + 4) * scale,
            height: (_ringSize + 4) * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accentCyan.withValues(alpha: opacity),
                width: 1.5,
              ),
            ),
          );
        },
      );
    });
  }
}

class _CallRingPainter extends CustomPainter {
  _CallRingPainter({
    required this.rotation,
    required this.strokeWidth,
    required this.colors,
    this.base,
  });

  final double rotation;
  final double strokeWidth;
  final List<Color> colors;

  /// Faint full circle under the sweep (the connecting track).
  final Color? base;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = (size.shortestSide - strokeWidth) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    if (base != null) {
      canvas.drawCircle(rect.center, radius, paint..color = base!);
    }
    paint.shader = SweepGradient(
      colors: colors,
      transform: GradientRotation(rotation),
    ).createShader(rect);
    canvas.drawCircle(rect.center, radius, paint);
  }

  @override
  bool shouldRepaint(_CallRingPainter old) =>
      old.rotation != rotation ||
      old.strokeWidth != strokeWidth ||
      old.base != base ||
      !listEquals(old.colors, colors);
}

final AudioPlayer _hangUpTonePlayer = AudioPlayer()
  ..setReleaseMode(ReleaseMode.stop);

void _playHangUpTone() {
  unawaited(
    _hangUpTonePlayer
        .play(AssetSource('sounds/call_end.wav'), volume: 0.8)
        .catchError((Object _) {}),
  );
}

class _VoiceCallCloseButton extends StatelessWidget {
  const _VoiceCallCloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '结束通话',
      child: CupertinoButton(
        minimumSize: Size.zero,
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: ClipOval(
          child: RouteSettledBlur.backdrop(
            sigma: 18,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              ),
              child: const Icon(
                CupertinoIcons.xmark,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Three-dot animation for active states.
class _AnimatedDots extends StatefulWidget {
  const _AnimatedDots({required this.color});
  final Color color;

  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = ((_ctrl.value * 3 - i) % 3).clamp(0.0, 1.0);
            final scale = 0.5 + 0.5 * (t < 0.5 ? t * 2 : (1 - t) * 2);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
