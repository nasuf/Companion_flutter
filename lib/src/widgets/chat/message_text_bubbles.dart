part of 'package:companion_flutter/main.dart';

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
    final baseStyle = TextStyle(
      color: message.isMine ? Colors.white : AppColors.text,
      fontSize: 14,
      height: 1.42,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 270),
      child: DecoratedBox(
        decoration: _bubbleDecoration(message.isMine),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
        ),
      ),
    );
  }

  BoxDecoration _bubbleDecoration(bool isMine) {
    const mineColor = Color(0xFF06C893);
    return BoxDecoration(
      color: isMine ? mineColor : AppColors.surface,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(isMine ? 20 : 3),
        topRight: Radius.circular(isMine ? 3 : 20),
        bottomLeft: const Radius.circular(20),
        bottomRight: const Radius.circular(20),
      ),
      border: Border.all(color: isMine ? mineColor : Colors.transparent),
      boxShadow: [
        BoxShadow(
          color: isMine
              ? mineColor.withValues(alpha: 0.25)
              : Colors.black.withValues(alpha: 0.10),
          blurRadius: isMine ? 4 : 16,
          offset: const Offset(0, 4),
        ),
      ],
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
        height: 44,
        alignment: Alignment.center,
        decoration: _pendingVoiceBubbleDecoration(),
        child: const VoiceTranscriptionSpinner(size: 24, color: Colors.white),
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
    final width = (108.0 + duration * 2.2).clamp(116.0, 250.0).toDouble();
    return Container(
      width: width,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: _pendingVoiceBubbleDecoration(),
      child: Row(
        children: [
          const CupertinoActivityIndicator(radius: 8, color: Colors.white),
          const SizedBox(width: 9),
          Expanded(
            child: Icon(
              Icons.graphic_eq_rounded,
              color: Colors.white.withValues(alpha: 0.88),
              size: 29,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            '$duration″',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _pendingVoiceBubbleDecoration() {
  const mineColor = Color(0xFF06C893);
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
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.hairline),
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
        });
      }
    });
  }

  @override
  void dispose() {
    _completeSubscription?.cancel();
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
    final duration = math.max(1, widget.attachment.durationSeconds ?? 1);
    final width = (108.0 + duration * 2.2).clamp(116.0, 250.0).toDouble();
    final foreground = widget.isMine ? Colors.white : AppColors.text;
    const mineColor = Color(0xFF06C893);
    return GestureDetector(
      onTap: _togglePlayback,
      child: Container(
        width: width,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: widget.isMine ? mineColor : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(widget.isMine ? 20 : 3),
            topRight: Radius.circular(widget.isMine ? 3 : 20),
            bottomLeft: const Radius.circular(20),
            bottomRight: const Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: widget.isMine
                  ? mineColor.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.10),
              blurRadius: widget.isMine ? 4 : 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            if (_loading)
              CupertinoActivityIndicator(radius: 9, color: foreground)
            else
              Icon(
                _playing ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                color: foreground,
                size: 18,
              ),
            const SizedBox(width: 9),
            Expanded(
              child: Icon(
                Icons.graphic_eq_rounded,
                color: foreground.withValues(alpha: 0.88),
                size: 30,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              '$duration″',
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
