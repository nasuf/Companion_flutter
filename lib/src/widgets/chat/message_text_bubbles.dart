part of 'package:companion_flutter/main.dart';

const _chatMineColor = Color(0xFF06C893);
const _chatFontSize = 14.0;
const _chatLineHeight = 1.42;
const _chatBubblePadding = EdgeInsets.symmetric(horizontal: 12, vertical: 9);

/// A one-line text bubble's height; voice bubbles use it so both line up.
const _chatSingleLineBubbleHeight = 9 * 2 + _chatFontSize * _chatLineHeight;

TextStyle _chatMessageTextStyle(bool isMine) => TextStyle(
  color: isMine ? Colors.white : AppColors.text,
  fontSize: _chatFontSize,
  height: _chatLineHeight,
);

/// Shared surface for pending typing and the actual reply: same fill, border,
/// corners, shadow, text-line height and insets, in both appearance modes.
class _MessageBubbleSurface extends StatelessWidget {
  const _MessageBubbleSurface({required this.isMine, required this.child});
  final bool isMine;
  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 270),
    child: DecoratedBox(
      decoration: _chatBubbleDecoration(context, isMine: isMine),
      child: Padding(padding: _chatBubblePadding, child: child),
    ),
  );
}

class _MessageTextBubble extends StatelessWidget {
  const _MessageTextBubble({
    required this.message,
    this.highlighted = false,
    this.highlightQuery,
  });

  final ChatMessage message;

  /// True for the one message a search-result tap just jumped to.
  final bool highlighted;

  /// The search query whose matches in [message.content] get a background
  /// highlight while [highlighted] — font/size/weight/spacing never change,
  /// only [highlightedSpans]' `highlightStyle` background color does, eased
  /// by [TweenAnimationBuilder] from fully visible down to transparent.
  final String? highlightQuery;

  @override
  Widget build(BuildContext context) {
    final baseStyle = _chatMessageTextStyle(message.isMine);
    return _MessageBubbleSurface(
      isMine: message.isMine,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: highlighted ? 1.0 : 0.0),
        duration: highlighted
            ? Duration.zero
            : const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        builder: (context, progress, _) {
          final highlightStyle = baseStyle.copyWith(
            backgroundColor: AppColors.accent.withValues(
              alpha: 0.35 * progress,
            ),
          );
          return Text.rich(
            TextSpan(
              children: emojiAwareSpans(
                text: message.content,
                baseStyle: baseStyle,
                emojiSize: 18,
                wrapPlainText: (chunk) => highlightedSpans(
                  text: chunk,
                  query: highlightQuery ?? '',
                  baseStyle: baseStyle,
                  highlightStyle: highlightStyle,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VoiceTranscriptionPendingBubble extends StatelessWidget {
  const _VoiceTranscriptionPendingBubble();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: '正在转写语音',
      excludeSemantics: true,
      child: Container(
        key: const ValueKey('voice-transcription-pending-bubble'),
        width: 52,
        height: _chatSingleLineBubbleHeight,
        alignment: Alignment.center,
        decoration: _pendingVoiceBubbleDecoration(),
        child: const VoiceTranscriptionSpinner(size: 20, color: Colors.white),
      ),
    );
  }
}

class _VoiceUploadPendingBubble extends StatelessWidget {
  const _VoiceUploadPendingBubble({required this.durationSeconds});

  final int durationSeconds;

  @override
  Widget build(BuildContext context) {
    final duration = math.max(1, durationSeconds);
    return Container(
      width: _voiceBubbleWidth(duration),
      height: _chatSingleLineBubbleHeight,
      decoration: _pendingVoiceBubbleDecoration(),
      child: _VoiceBubbleContent(
        isMine: true,
        seed: 'pending-$duration',
        label: '$duration″',
        progress: 0,
        active: false,
        button: const CupertinoActivityIndicator(radius: 7, color: _chatMineColor),
      ),
    );
  }
}

/// WeChat-style: longer messages get wider bubbles, within one line's width.
double _voiceBubbleWidth(int seconds) =>
    (96.0 + seconds * 4.0).clamp(112.0, 236.0).toDouble();

/// Play control, waveform and duration, inset to match a text bubble.
class _VoiceBubbleContent extends StatelessWidget {
  const _VoiceBubbleContent({
    required this.isMine,
    required this.seed,
    required this.label,
    required this.progress,
    required this.active,
    required this.button,
  });

  final bool isMine;

  /// Stable per message so its waveform never reshuffles on rebuild.
  final String seed;
  final String label;

  /// Played fraction, 0–1.
  final double progress;

  /// Playing or paused: the waveform shows the played part.
  final bool active;
  final Widget button;

  static const _buttonSize = 26.0;

  @override
  Widget build(BuildContext context) {
    final foreground = isMine ? Colors.white : AppColors.text;
    // Same inset on all sides of the round control: (37.9 - 26) / 2.
    const inset = (_chatSingleLineBubbleHeight - _buttonSize) / 2;
    return Padding(
      padding: const EdgeInsets.only(left: inset, right: 12),
      child: Row(
        children: [
          Container(
            width: _buttonSize,
            height: _buttonSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMine ? Colors.white : _chatMineColor,
            ),
            child: button,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: SizedBox(
              height: 18,
              child: CustomPaint(
                painter: _VoiceWaveformBarsPainter(
                  seed: seed,
                  progress: progress,
                  active: active,
                  color: foreground,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Speech-like bars from a seeded generator (no amplitude data is stored),
/// tapering at both ends. Played bars are solid, the rest translucent.
class _VoiceWaveformBarsPainter extends CustomPainter {
  _VoiceWaveformBarsPainter({
    required this.seed,
    required this.progress,
    required this.active,
    required this.color,
  });

  final String seed;
  final double progress;
  final bool active;
  final Color color;

  static const _barWidth = 2.4;
  static const _gap = 2.2;

  static int _hash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final count = ((size.width + _gap) / (_barWidth + _gap)).floor();
    if (count <= 0) return;
    final random = math.Random(_hash(seed));
    final paint = Paint()..strokeCap = StrokeCap.round;
    final used = count * (_barWidth + _gap) - _gap;
    final left = (size.width - used) / 2 + _barWidth / 2;
    final middle = size.height / 2;
    var previous = 0.5;
    for (var index = 0; index < count; index++) {
      final raw = random.nextDouble();
      final smoothed = previous * 0.45 + raw * 0.55;
      previous = raw;
      final position = count == 1 ? 0.5 : index / (count - 1);
      final envelope = 0.55 + 0.45 * math.sin(position * math.pi);
      final amplitude = (0.22 + 0.78 * smoothed) * envelope;
      final barHeight = math.max(_barWidth, amplitude * size.height);
      final played = active && (index + 0.5) / count <= progress;
      paint
        ..color = color.withValues(
          alpha: active ? (played ? 1.0 : 0.32) : 0.62,
        )
        ..strokeWidth = _barWidth;
      final x = left + index * (_barWidth + _gap);
      canvas.drawLine(
        Offset(x, middle - barHeight / 2 + _barWidth / 2),
        Offset(x, middle + barHeight / 2 - _barWidth / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_VoiceWaveformBarsPainter old) =>
      old.seed != seed ||
      old.progress != progress ||
      old.active != active ||
      old.color != color;
}

BoxDecoration _chatBubbleDecoration(
  BuildContext context, {
  required bool isMine,
}) {
  const mineColor = _chatMineColor;
  final dark = AppColors.isDark(context);
  return BoxDecoration(
    color: isMine ? mineColor : _chatIncomingBubbleColor(context),
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(isMine ? 20 : 3),
      topRight: Radius.circular(isMine ? 3 : 20),
      bottomLeft: const Radius.circular(20),
      bottomRight: const Radius.circular(20),
    ),
    // A same-colour border on the green bubble doesn't change the fill, and a
    // transparent one would inset Container-based bubbles (voice) by 1px.
    // Only the dark incoming bubble needs a hairline so it separates from
    // the night canvas.
    border: !isMine && dark
        ? Border.all(color: Colors.white.withValues(alpha: 0.08))
        : null,
    boxShadow: [
      BoxShadow(
        color: isMine
            ? mineColor.withValues(alpha: 0.25)
            : Colors.black.withValues(alpha: dark ? 0.28 : 0.10),
        blurRadius: isMine ? 4 : 16,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

BoxDecoration _pendingVoiceBubbleDecoration() {
  const mineColor = _chatMineColor;
  return BoxDecoration(
    color: mineColor,
    borderRadius: const BorderRadius.only(
      topLeft: Radius.circular(20),
      topRight: Radius.circular(3),
      bottomLeft: Radius.circular(20),
      bottomRight: Radius.circular(20),
    ),
    boxShadow: [
      BoxShadow(
        color: mineColor.withValues(alpha: 0.25),
        blurRadius: 4,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

class _VoiceMessageBubble extends StatefulWidget {
  const _VoiceMessageBubble({
    required this.attachment,
    required this.isMine,
    required this.transcript,
    this.authToken,
    this.apiBaseUrl,
  });

  final ChatAttachment attachment;
  final bool isMine;
  final String? transcript;
  final String? authToken;
  final String? apiBaseUrl;

  @override
  State<_VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<_VoiceMessageBubble> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final transcript = widget.transcript?.trim() ?? '';
    return Column(
      crossAxisAlignment: widget.isMine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        _AudioAttachmentBubble(
          attachment: widget.attachment,
          isMine: widget.isMine,
          authToken: widget.authToken,
          apiBaseUrl: widget.apiBaseUrl,
        ),
        if (transcript.isNotEmpty && !widget.isMine) ...[
          const SizedBox(height: 5),
          CupertinoButton(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? '收起文字' : '查看文字',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: _expanded
                ? Container(
                    constraints: const BoxConstraints(maxWidth: 270),
                    margin: const EdgeInsets.only(top: 3),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.isDark(context)
                          ? _chatIncomingBubbleColor(context)
                          : AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _chatHairline(context)),
                    ),
                    child: Text(
                      transcript,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 13,
                        height: 1.42,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }
}

class _AudioAttachmentBubble extends StatefulWidget {
  const _AudioAttachmentBubble({
    required this.attachment,
    required this.isMine,
    this.authToken,
    this.apiBaseUrl,
  });

  final ChatAttachment attachment;
  final bool isMine;
  final String? authToken;
  final String? apiBaseUrl;

  @override
  State<_AudioAttachmentBubble> createState() => _AudioAttachmentBubbleState();
}

class _AudioAttachmentBubbleState extends State<_AudioAttachmentBubble> {
  late final AudioPlayer _player;
  StreamSubscription<void>? _completeSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _playing = false;
  bool _paused = false;
  bool _loading = false;
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _completeSubscription = _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _paused = false;
          _position = Duration.zero;
        });
      }
    });
    _positionSubscription = _player.onPositionChanged.listen((position) {
      if (mounted && (_playing || _paused)) setState(() => _position = position);
    });
    _durationSubscription = _player.onDurationChanged.listen((duration) {
      if (mounted && duration > Duration.zero) {
        setState(() => _duration = duration);
      }
    });
  }

  @override
  void dispose() {
    _completeSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    unawaited(_player.dispose());
    final path = _localPath;
    if (path != null) {
      unawaited(File(path).delete().then<void>((_) {}, onError: (_) {}));
    }
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_loading) return;
    if (_playing) {
      await _player.pause();
      if (mounted) {
        setState(() {
          _playing = false;
          _paused = true;
        });
      }
      return;
    }
    setState(() => _loading = true);
    try {
      // Voice messages always play on the loudspeaker, even if something
      // (a call, a recording) left the session on the earpiece.
      await restoreSpeakerPlayback();
      if (_paused) {
        await _player.resume();
      } else {
        final path = _localPath ?? await _downloadAudio();
        _localPath = path;
        await _player.play(DeviceFileSource(path));
      }
      if (mounted) {
        setState(() {
          _playing = true;
          _paused = false;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('语音加载失败，请稍后重试')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String> _downloadAudio() async {
    final uri = _audioUri();
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final headers = _isApiOrigin(uri)
          ? _mediaHeadersForUrl(uri.toString(), widget.authToken)
          : null;
      if (headers != null) {
        headers.forEach(request.headers.set);
      }
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Audio download failed (${response.statusCode})',
          uri: uri,
        );
      }
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
      }
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/chat_audio_${widget.attachment.id}${_fileExtension()}';
      await File(path).writeAsBytes(bytes, flush: true);
      return path;
    } finally {
      client.close(force: true);
    }
  }

  String _fileExtension() {
    return switch (widget.attachment.mime.toLowerCase()) {
      'audio/wav' || 'audio/x-wav' => '.wav',
      'audio/mpeg' || 'audio/mp3' => '.mp3',
      'audio/ogg' => '.ogg',
      'audio/opus' => '.opus',
      'audio/flac' => '.flac',
      'audio/aac' => '.aac',
      _ => '.m4a',
    };
  }

  Uri _audioUri() {
    final raw = widget.attachment.url.trim();
    final parsed = Uri.tryParse(raw);
    if (parsed == null) throw const FormatException('Invalid audio URL');
    if (parsed.hasScheme) return parsed;
    final base = widget.apiBaseUrl?.trim();
    if (base == null || base.isEmpty) {
      throw const FormatException('Missing API base URL');
    }
    if (raw.startsWith('/')) return Uri.parse('$base$raw');
    return Uri.parse(base.endsWith('/') ? base : '$base/').resolve(raw);
  }

  bool _isApiOrigin(Uri uri) {
    final rawBase = widget.apiBaseUrl?.trim();
    if (rawBase == null || rawBase.isEmpty) return false;
    final base = Uri.tryParse(rawBase);
    if (base == null || !base.hasScheme || !uri.hasScheme) return false;
    return uri.scheme == base.scheme &&
        uri.host == base.host &&
        uri.port == base.port;
  }

  @override
  Widget build(BuildContext context) {
    final seconds = math.max(1, widget.attachment.durationSeconds ?? 1);
    final total = _duration ?? Duration(seconds: seconds);
    final active = _playing || _paused;
    final progress = total.inMilliseconds <= 0
        ? 0.0
        : (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    // While playing, count down what is left, like WeChat.
    final shown = active
        ? math.max(0, (total - _position).inMilliseconds / 1000).ceil()
        : seconds;
    final buttonColor = widget.isMine ? _chatMineColor : Colors.white;
    return Semantics(
      button: true,
      label: '语音 $seconds 秒，${_playing ? '暂停' : '播放'}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _togglePlayback,
        child: Container(
          width: _voiceBubbleWidth(seconds),
          height: _chatSingleLineBubbleHeight,
          decoration: _chatBubbleDecoration(context, isMine: widget.isMine),
          child: _VoiceBubbleContent(
            isMine: widget.isMine,
            seed: widget.attachment.id,
            label: '$shown″',
            progress: progress,
            active: active,
            button: _loading
                ? CupertinoActivityIndicator(radius: 7, color: buttonColor)
                : Padding(
                    // Optical centring: a play triangle reads left of centre.
                    padding: EdgeInsets.only(left: _playing ? 0 : 1.5),
                    child: Icon(
                      _playing
                          ? CupertinoIcons.pause_fill
                          : CupertinoIcons.play_fill,
                      color: buttonColor,
                      size: 13,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
