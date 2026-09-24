part of 'package:companion_flutter/main.dart';

class _MusicPlayerPanel extends StatelessWidget {
  const _MusicPlayerPanel({
    required this.track,
    required this.loading,
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.lyricsMode,
    required this.lyrics,
    required this.canGoPrevious,
    required this.discAnimation,
    required this.waveAnimation,
    required this.onToggleDisplay,
    required this.onSeekStart,
    required this.onSeekChanged,
    required this.onSeekEnd,
    required this.onPrevious,
    required this.onNext,
    required this.onTogglePlay,
    required this.onToggleFavorite,
  });

  final MusicTrack? track;
  final bool loading;
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final bool lyricsMode;
  final List<String> lyrics;
  final bool canGoPrevious;
  final Animation<double> discAnimation;
  final Animation<double> waveAnimation;
  final VoidCallback onToggleDisplay;
  final ValueChanged<double> onSeekStart;
  final ValueChanged<double> onSeekChanged;
  final ValueChanged<double> onSeekEnd;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onTogglePlay;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final current = track;
    final progress = duration.inMilliseconds <= 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 580;
        final contentPadding = compact ? 14.0 : 18.0;
        final bottomPadding = compact ? 14.0 : 18.0;
        final sectionGap = compact ? 8.0 : 12.0;
        final discGap = compact ? 8.0 : 14.0;
        final waveGap = compact ? 10.0 : 16.0;
        final titleHeight = compact ? 30.0 : 32.0;
        return Container(
          padding: EdgeInsets.fromLTRB(
            contentPadding,
            contentPadding,
            contentPadding,
            bottomPadding,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF121823), Color(0xFF182B3A), Color(0xFF091119)],
              stops: [0, 0.48, 1],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.34),
                blurRadius: 80,
                offset: const Offset(0, 34),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.08),
                blurRadius: 0,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _MusicPlayerGridPainter()),
              ),
              Column(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onToggleDisplay,
                      child: LayoutBuilder(
                        builder: (context, displayConstraints) {
                          final mediaHeight = math.max(
                            0.0,
                            displayConstraints.maxHeight -
                                titleHeight -
                                discGap -
                                waveGap,
                          );
                          final discHeight = math.min(
                            compact ? 206.0 : 286.0,
                            mediaHeight * 0.60,
                          );
                          final waveHeight = math.min(
                            compact ? 82.0 : 132.0,
                            math.max(0.0, mediaHeight - discHeight),
                          );
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: lyricsMode
                                ? _MusicLyricsStage(
                                    key: const ValueKey('lyrics'),
                                    track: current,
                                    lyrics: lyrics,
                                    isPlaying: isPlaying,
                                    animation: waveAnimation,
                                  )
                                : Column(
                                    key: const ValueKey('disc-wave'),
                                    children: [
                                      SizedBox(
                                        height: discHeight,
                                        child: _MusicDiscStage(
                                          track: current,
                                          loading: loading,
                                          isPlaying: isPlaying,
                                          animation: discAnimation,
                                        ),
                                      ),
                                      SizedBox(height: discGap),
                                      SizedBox(
                                        height: titleHeight,
                                        child: Center(
                                          child: _MusicTrackInfo(
                                            track: current,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: waveGap),
                                      SizedBox(
                                        height: waveHeight,
                                        child: _MusicWaveStage(
                                          animation: waveAnimation,
                                        ),
                                      ),
                                    ],
                                  ),
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: sectionGap),
                  _MusicTransportPanel(
                    compact: compact,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MusicProgressBar(
                          position: position,
                          duration: duration,
                          progress: progress,
                          onSeekStart: onSeekStart,
                          onSeekChanged: onSeekChanged,
                          onSeekEnd: onSeekEnd,
                        ),
                        SizedBox(height: compact ? 8 : 10),
                        _MusicControlDeck(
                          isPlaying: isPlaying,
                          isFavorite: current?.isFavorite ?? false,
                          canGoPrevious: canGoPrevious,
                          loading: loading,
                          compact: compact,
                          onPrevious: onPrevious,
                          onNext: onNext,
                          onTogglePlay: onTogglePlay,
                          onToggleFavorite: onToggleFavorite,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MusicPlayerGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += 42) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MusicDiscStage extends StatelessWidget {
  const _MusicDiscStage({
    required this.track,
    required this.loading,
    required this.isPlaying,
    required this.animation,
  });

  final MusicTrack? track;
  final bool loading;
  final bool isPlaying;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(
          math.min(constraints.maxWidth, constraints.maxHeight),
          306.0,
        );
        return SizedBox.expand(
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  final angle = animation.value * math.pi * 2;
                  return Transform.rotate(angle: angle, child: child);
                },
                child: _MusicDisc(track: track, size: size),
              ),
              if (loading)
                Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                      shape: BoxShape.circle,
                    ),
                    child: const CupertinoActivityIndicator(
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MusicDisc extends StatelessWidget {
  const _MusicDisc({required this.track, required this.size});

  final MusicTrack? track;
  final double size;

  @override
  Widget build(BuildContext context) {
    final coverUrl = track?.coverImageUrl;
    final asset = track?.coverAsset;
    final coverProvider = coverUrl == null
        ? (asset == null ? null : AssetImage(asset) as ImageProvider)
        : NetworkImage(coverUrl) as ImageProvider;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.18, -0.26),
          radius: 0.78,
          colors: [
            Color(0xFF273545),
            Color(0xFF0B1118),
            Color(0xFF020405),
            Color(0xFF10151B),
          ],
          stops: [0.16, 0.48, 0.78, 1],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.48),
            blurRadius: 66,
            offset: const Offset(0, 28),
          ),
          BoxShadow(
            color: const Color(0xFF5ED8FF).withValues(alpha: 0.16),
            blurRadius: 0,
            spreadRadius: 9,
          ),
          BoxShadow(
            color: const Color(0xFF74EDFF).withValues(alpha: 0.13),
            blurRadius: 54,
            spreadRadius: -1,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.06),
            blurRadius: 0,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: CustomPaint(painter: _DiscGroovePainter())),
          Positioned.fill(child: CustomPaint(painter: _DiscSheenPainter())),
          Container(
            width: size * 0.52,
            height: size * 0.52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFF101820), Color(0xFF05080C)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.36),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
          ),
          Container(
            width: size * 0.48,
            height: size * 0.48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: coverProvider == null
                  ? null
                  : DecorationImage(image: coverProvider, fit: BoxFit.cover),
              gradient: coverProvider == null
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF9CEBFF),
                        Color(0xFF1F6FFF),
                        Color(0xFF101820),
                      ],
                    )
                  : null,
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.26),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.10),
                  blurRadius: 0,
                  spreadRadius: 1,
                ),
              ],
            ),
            foregroundDecoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.18),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.18),
                ],
                stops: const [0, 0.42, 1],
              ),
            ),
          ),
          Container(
            width: size * 0.082,
            height: size * 0.082,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFF2D3844), Color(0xFF070B10)],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.34),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscGroovePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    canvas.drawCircle(
      center,
      radius * 0.965,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = Colors.white.withValues(alpha: 0.045),
    );
    canvas.drawCircle(
      center,
      radius * 0.90,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF5ED8FF).withValues(alpha: 0.11),
    );
    for (var i = 0; i < 34; i += 1) {
      final grooveRadius = size.width * (0.19 + i * 0.011);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = i % 5 == 0 ? 1.15 : 0.75
        ..color = Colors.white.withValues(alpha: i.isEven ? 0.052 : 0.024);
      canvas.drawCircle(center, grooveRadius, paint);
    }
    for (var i = 0; i < 7; i += 1) {
      final grooveRadius = size.width * (0.34 + i * 0.035);
      canvas.drawCircle(
        center,
        grooveRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.black.withValues(alpha: 0.12),
      );
    }
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size.width * 0.43),
      -0.92,
      1.48,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF5ED8FF).withValues(alpha: 0.065),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size.width * 0.48),
      2.36,
      1.06,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.055),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DiscSheenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final clip = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius - 1));
    canvas.save();
    canvas.clipPath(clip);
    final bandPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x16FFFFFF), Colors.transparent, Color(0x0DFFFFFF)],
        stops: [0, 0.46, 1],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..blendMode = BlendMode.screen
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.42, size.height * 0.34),
        width: size.width * 0.68,
        height: size.height * 0.17,
      ),
      bandPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.82),
      -1.08,
      0.72,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.13),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.76),
      2.58,
      0.54,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF5ED8FF).withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MusicTrackInfo extends StatelessWidget {
  const _MusicTrackInfo({required this.track});

  final MusicTrack? track;

  @override
  Widget build(BuildContext context) {
    final current = track;
    return Column(
      children: [
        Text(
          current?.title ?? '正在随机取歌',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            height: 1.16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _MusicWaveStage extends StatelessWidget {
  const _MusicWaveStage({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < _MusicPageState._waveHeights.length; i += 1)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.3),
                  child: FractionallySizedBox(
                    heightFactor: _heightFactor(i),
                    alignment: Alignment.center,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFA9F5FF),
                            Color(0xFF5ED8FF),
                            Color(0xFF2178FF),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF45C6FF,
                            ).withValues(alpha: 0.32),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  double _heightFactor(int index) {
    final base = _MusicPageState._waveHeights[index] / 1.36;
    final phase = (animation.value + index * 0.09) * math.pi * 2;
    return (base * (0.74 + 0.34 * math.sin(phase))).clamp(0.18, 1.0);
  }
}

class _MusicLyricsStage extends StatelessWidget {
  const _MusicLyricsStage({
    super.key,
    required this.track,
    required this.lyrics,
    required this.isPlaying,
    required this.animation,
  });

  final MusicTrack? track;
  final List<String> lyrics;
  final bool isPlaying;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    if (lyrics.isEmpty) {
      return _MusicInstrumentalStage(
        animation: animation,
        isPlaying: isPlaying,
        isInstrumental: _isInstrumentalTrack(track),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: ShaderMask(
        shaderCallback: (bounds) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0, 0.12, 0.88, 1],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final offset = isPlaying
                ? math.sin(animation.value * math.pi * 2) * 8
                : 0.0;
            return Transform.translate(
              offset: Offset(0, offset),
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < lyrics.length; i += 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Text(
                          lyrics[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: i == 0
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.32),
                            fontSize: i == 0 ? 28 : 18,
                            height: 1.18,
                            fontWeight: i == 0
                                ? FontWeight.w900
                                : FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static bool _isInstrumentalTrack(MusicTrack? track) {
    final metadata = track?.metadata;
    if (metadata == null || metadata.isEmpty) return false;
    final direct = _metadataText(metadata['vocalinstrumental']);
    if (direct != null) return direct == 'instrumental';
    final raw = metadata['raw'];
    if (raw is Map) {
      final musicInfo = raw['musicinfo'];
      if (musicInfo is Map) {
        final nested = _metadataText(musicInfo['vocalinstrumental']);
        if (nested != null) return nested == 'instrumental';
      }
    }
    return false;
  }

  static String? _metadataText(Object? value) {
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text.isEmpty || text == 'null' ? null : text;
  }
}

class _MusicInstrumentalStage extends StatelessWidget {
  const _MusicInstrumentalStage({
    required this.animation,
    required this.isPlaying,
    required this.isInstrumental,
  });

  final Animation<double> animation;
  final bool isPlaying;
  final bool isInstrumental;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final phase = animation.value * math.pi * 2;
        final pulse = isPlaying ? (0.5 + math.sin(phase) * 0.5) : 0.42;
        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 380;
            final orbSize = compact ? 148.0 : 184.0;
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isInstrumental ? 'INSTRUMENTAL' : 'NO LYRICS',
                    style: TextStyle(
                      color: const Color(0xFF7DE7FF).withValues(alpha: 0.92),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.4,
                    ),
                  ),
                  SizedBox(height: compact ? 18 : 24),
                  SizedBox(
                    width: orbSize,
                    height: orbSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        for (var i = 0; i < 4; i += 1)
                          Transform.scale(
                            scale: 0.68 + i * 0.13 + pulse * 0.10,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(
                                    0xFF5ED8FF,
                                  ).withValues(alpha: 0.18 - i * 0.03),
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        Container(
                          width: orbSize * 0.70,
                          height: orbSize * 0.70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFF8EE7FF).withValues(alpha: 0.86),
                                const Color(
                                  0xFF1F6FFF,
                                ).withValues(alpha: 0.34 + pulse * 0.16),
                                const Color(0xFF061018).withValues(alpha: 0.92),
                              ],
                              stops: const [0, 0.48, 1],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF18C6C0,
                                ).withValues(alpha: 0.20 + pulse * 0.18),
                                blurRadius: 34 + pulse * 18,
                                spreadRadius: 2 + pulse * 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            CupertinoIcons.music_note_2,
                            color: Colors.white,
                            size: 52,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: compact ? 22 : 28),
                  Text(
                    isInstrumental ? '纯音乐片段' : '暂未收录歌词',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: compact ? 22 : 25,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isInstrumental ? '没有歌词，跟着旋律呼吸就好' : '这首歌暂时没有歌词文本',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.48),
                      fontSize: 13,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
