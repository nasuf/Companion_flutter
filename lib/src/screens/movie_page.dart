part of 'package:companion_flutter/main.dart';

class MoviePage extends StatefulWidget {
  const MoviePage({super.key});

  @override
  State<MoviePage> createState() => _MoviePageState();
}

class _MoviePageState extends State<MoviePage> with TickerProviderStateMixin {
  late final AnimationController _posterController;
  late final AnimationController _tickerController;
  late final ScrollController _railController;
  int _selectedIndex = 0;
  bool _showsControls = false;

  _MovieItem get _movie => _movieItems[_selectedIndex];

  @override
  void initState() {
    super.initState();
    _posterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9000),
    )..repeat(reverse: true);
    _tickerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 11000),
    )..repeat();
    _railController = ScrollController();
  }

  @override
  void dispose() {
    _posterController.dispose();
    _tickerController.dispose();
    _railController.dispose();
    super.dispose();
  }

  void _selectMovie(int index) {
    final next = index.clamp(0, _movieItems.length - 1);
    setState(() {
      _selectedIndex = next;
      _showsControls = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerRail(next));
  }

  void _centerRail(int index) {
    if (!_railController.hasClients) return;
    final target = (index * _MovieRail._cellExtent).clamp(
      0.0,
      _railController.position.maxScrollExtent,
    );
    _railController.animateTo(
      target,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _toggleControls() {
    setState(() => _showsControls = !_showsControls);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07080B),
      body: Stack(
        children: [
          const Positioned.fill(child: _CinemaBackdrop()),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  MediaQuery.paddingOf(context).top + 16,
                  16,
                  MediaQuery.paddingOf(context).bottom + 106,
                ),
                sliver: SliverList.list(
                  children: [
                    _CinemaActions(onBack: () => Navigator.of(context).pop()),
                    const SizedBox(height: 12),
                    _CinemaIntro(movie: _movie),
                    const SizedBox(height: 18),
                    _CinemaPlayer(
                      movie: _movie,
                      selectedIndex: _selectedIndex,
                      showsControls: _showsControls,
                      posterAnimation: _posterController,
                      railController: _railController,
                      onToggleControls: _toggleControls,
                      onSelected: _selectMovie,
                    ),
                    const SizedBox(height: 24),
                    _CinemaBarragePanel(
                      movie: _movie,
                      ticker: _tickerController,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CinemaBackdrop extends StatelessWidget {
  const _CinemaBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF151823),
            Color(0xFF15151D),
            Color(0xFF110B0D),
            Color(0xFF07080B),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _CinemaGridPainter())),
          Positioned(
            right: -98,
            top: -92,
            child: _CinemaGlow(
              size: 300,
              color: const Color(0xFFFF6A3D).withValues(alpha: 0.26),
            ),
          ),
          Positioned(
            left: -112,
            top: 310,
            child: _CinemaGlow(
              size: 280,
              color: const Color(0xFF1F6FFF).withValues(alpha: 0.18),
            ),
          ),
        ],
      ),
    );
  }
}

class _CinemaGlow extends StatelessWidget {
  const _CinemaGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 46, sigmaY: 46),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class _CinemaGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += 34) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += 68) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CinemaActions extends StatelessWidget {
  const _CinemaActions({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: onBack,
          child: _GlassCircleButton(icon: CupertinoIcons.chevron_left),
        ),
        const Spacer(),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () {},
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(21),
            ),
            child: const Text(
              '发聊天',
              style: TextStyle(
                color: Color(0xFF101820),
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _CinemaIntro extends StatelessWidget {
  const _CinemaIntro({required this.movie});

  final _MovieItem movie;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CINEMA PLAYER',
          style: TextStyle(
            color: Color(0xFFFFB3A2),
            fontSize: 13,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '你和我的共同影厅',
          style: TextStyle(
            color: Colors.white,
            fontSize: 33,
            height: 1.02,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
            shadows: [
              Shadow(
                color: Color(0x33000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 326,
          height: 44,
          child: Align(
            alignment: Alignment.topLeft,
            child: Text(
              movie.intro,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontSize: 15,
                height: 1.33,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CinemaPlayer extends StatelessWidget {
  const _CinemaPlayer({
    required this.movie,
    required this.selectedIndex,
    required this.showsControls,
    required this.posterAnimation,
    required this.railController,
    required this.onToggleControls,
    required this.onSelected,
  });

  final _MovieItem movie;
  final int selectedIndex;
  final bool showsControls;
  final Animation<double> posterAnimation;
  final ScrollController railController;
  final VoidCallback onToggleControls;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: onToggleControls,
          child: _CinemaScreen(
            movie: movie,
            showsControls: showsControls,
            animation: posterAnimation,
          ),
        ),
        const SizedBox(height: 18),
        _MovieRail(
          controller: railController,
          selectedIndex: selectedIndex,
          onSelected: onSelected,
        ),
      ],
    );
  }
}

class _CinemaScreen extends StatelessWidget {
  const _CinemaScreen({
    required this.movie,
    required this.showsControls,
    required this.animation,
  });

  final _MovieItem movie;
  final bool showsControls;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      child: Container(
        key: ValueKey(movie.poster),
        height: 408,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.54),
              blurRadius: 34,
              offset: const Offset(0, 26),
            ),
            BoxShadow(
              color: const Color(0xFFFF6A3D).withValues(alpha: 0.14),
              blurRadius: 52,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _BreathingMoviePoster(movie: movie, animation: animation),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.18),
                    Colors.black.withValues(alpha: 0.66),
                  ],
                  stops: const [0, 0.50, 1],
                ),
              ),
            ),
            Positioned(
              left: 17,
              right: 17,
              top: 18,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _MovieTopText(movie.title)),
                  const SizedBox(width: 18),
                  _MovieTopText(movie.state),
                ],
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: showsControls ? 80 : 42,
              child: _CinemaCaption(movie: movie),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 340),
              curve: Curves.easeOutCubic,
              left: 16,
              right: 16,
              bottom: showsControls ? 16 : -74,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 260),
                opacity: showsControls ? 1 : 0,
                child: _CinemaInlineControls(movie: movie),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreathingMoviePoster extends StatelessWidget {
  const _BreathingMoviePoster({required this.movie, required this.animation});

  final _MovieItem movie;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final eased = Curves.easeInOut.transform(animation.value);
        return Transform.translate(
          offset: Offset(lerpDouble(-6, 7, eased)!, lerpDouble(7, -5, eased)!),
          child: Transform.scale(
            scale: lerpDouble(1.035, 1.075, eased),
            child: child,
          ),
        );
      },
      child: Image.asset(
        movie.poster,
        fit: BoxFit.cover,
        alignment: const Alignment(0, -0.30),
      ),
    );
  }
}

class _MovieTopText extends StatelessWidget {
  const _MovieTopText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.84),
        fontSize: 12,
        height: 1.16,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _CinemaCaption extends StatelessWidget {
  const _CinemaCaption({required this.movie});

  final _MovieItem movie;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF6A3D),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6A3D).withValues(alpha: 0.70),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '正在播放 · ${movie.title}',
                maxLines: 2,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1.16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                  shadows: [
                    Shadow(
                      color: Color(0x5C000000),
                      blurRadius: 9,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Text(
          '“${movie.subtitle}”',
          maxLines: 2,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.18,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
            shadows: [
              Shadow(
                color: Color(0x5C000000),
                blurRadius: 9,
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CinemaInlineControls extends StatelessWidget {
  const _CinemaInlineControls({required this.movie});

  final _MovieItem movie;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.96),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.24),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.play_fill,
                  color: Color(0xFF101820),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        _ControlTimeText(movie.time),
                        const Spacer(),
                        _ControlTimeText(movie.duration),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 92,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.96),
                              borderRadius: BorderRadius.circular(99),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.28),
                                  blurRadius: 10,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlTimeText extends StatelessWidget {
  const _ControlTimeText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.88),
        fontSize: 12,
        height: 1,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
        shadows: const [
          Shadow(color: Color(0x99000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
    );
  }
}

class _MovieRail extends StatelessWidget {
  const _MovieRail({
    required this.controller,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const double _cellWidth = 112;
  static const double _cellExtent = 108;

  final ScrollController controller;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 182,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sidePadding = math.max(
            0.0,
            (constraints.maxWidth - _cellWidth) / 2,
          );
          return Stack(
            alignment: Alignment.center,
            children: [
              NotificationListener<ScrollEndNotification>(
                onNotification: (notification) {
                  final next = (controller.offset / _cellExtent).round().clamp(
                    0,
                    _movieItems.length - 1,
                  );
                  if (next != selectedIndex) {
                    onSelected(next);
                  } else if (controller.hasClients) {
                    final target = next * _cellExtent;
                    if ((controller.offset - target).abs() > 0.5) {
                      controller.animateTo(
                        target,
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  }
                  return false;
                },
                child: ListView.builder(
                  controller: controller,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: sidePadding),
                  itemCount: _movieItems.length,
                  itemBuilder: (context, index) {
                    return SizedBox(
                      width: _cellExtent,
                      child: Align(
                        alignment: Alignment.center,
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          onPressed: () => onSelected(index),
                          child: AnimatedBuilder(
                            animation: controller,
                            builder: (context, _) {
                              final center = controller.hasClients
                                  ? controller.offset / _cellExtent
                                  : selectedIndex.toDouble();
                              final distance = (index - center).abs();
                              final focus = (1 - distance).clamp(0.0, 1.0);
                              return _CinemaPosterThumb(
                                movie: _movieItems[index],
                                focus: Curves.easeOutCubic.transform(focus),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: _RailArrow(
                    icon: CupertinoIcons.chevron_left,
                    disabled: selectedIndex == 0,
                    onTap: () => onSelected(selectedIndex - 1),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _RailArrow(
                    icon: CupertinoIcons.chevron_right,
                    disabled: selectedIndex == _movieItems.length - 1,
                    onTap: () => onSelected(selectedIndex + 1),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RailArrow extends StatelessWidget {
  const _RailArrow({
    required this.icon,
    required this.disabled,
    required this.onTap,
  });

  final IconData icon;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: disabled ? null : onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 38,
            height: 78,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: disabled ? 0.08 : 0.13),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Icon(
              icon,
              size: 22,
              color: Colors.white.withValues(alpha: disabled ? 0.40 : 0.86),
            ),
          ),
        ),
      ),
    );
  }
}

class _CinemaPosterThumb extends StatelessWidget {
  const _CinemaPosterThumb({required this.movie, required this.focus});

  final _MovieItem movie;
  final double focus;

  @override
  Widget build(BuildContext context) {
    final width = lerpDouble(74, 112, focus)!;
    final height = lerpDouble(98, 140, focus)!;
    final radius = lerpDouble(20, 24, focus)!;
    final dim = lerpDouble(0.24, 0, focus)!;
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: lerpDouble(0.22, 0.42, focus)!,
            ),
            blurRadius: lerpDouble(10, 20, focus)!,
            offset: Offset(0, lerpDouble(7, 12, focus)!),
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: Colors.black.withValues(alpha: dim),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(movie.poster, fit: BoxFit.cover),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(lerpDouble(8, 12, focus)!),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(
                      alpha: lerpDouble(0.56, 0.70, focus)!,
                    ),
                  ],
                ),
              ),
              child: Text(
                movie.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(
                    alpha: lerpDouble(0.72, 1, focus)!,
                  ),
                  fontSize: lerpDouble(10, 13, focus),
                  height: 1.10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CinemaBarragePanel extends StatelessWidget {
  const _CinemaBarragePanel({required this.movie, required this.ticker});

  final _MovieItem movie;
  final Animation<double> ticker;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF242126).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.46),
            blurRadius: 34,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                '正在播放弹幕',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  movie.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.48),
                    fontSize: 13,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 21),
          _CinemaBarrageTicker(animation: ticker),
        ],
      ),
    );
  }
}

class _CinemaBarrageTicker extends StatelessWidget {
  const _CinemaBarrageTicker({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final rows = [..._barrageRows, ..._barrageRows];
    return SizedBox(
      height: 204,
      child: ShaderMask(
        shaderCallback: (rect) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black,
              Colors.black,
              Colors.transparent,
            ],
            stops: [0, 0.18, 0.82, 1],
          ).createShader(rect);
        },
        blendMode: BlendMode.dstIn,
        child: ClipRect(
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final y = lerpDouble(
                214,
                -_barrageRows.length * 70,
                animation.value,
              )!;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: y,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final row in rows) ...[
                          _CinemaBarrageRow(row: row),
                          const SizedBox(height: 14),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CinemaBarrageRow extends StatelessWidget {
  const _CinemaBarrageRow({required this.row});

  final _BarrageRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.065),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF6A3D),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6A3D).withValues(alpha: 0.48),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              row.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 15,
                height: 1.22,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            row.time,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.48),
              fontSize: 14,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _MovieItem {
  const _MovieItem({
    required this.title,
    required this.poster,
    required this.state,
    required this.time,
    required this.duration,
    required this.barrage,
    required this.intro,
    required this.subtitle,
  });

  final String title;
  final String poster;
  final String state;
  final String time;
  final String duration;
  final String barrage;
  final String intro;
  final String subtitle;
}

class _BarrageRow {
  const _BarrageRow(this.time, this.text);

  final String time;
  final String text;
}

const _movieItems = [
  _MovieItem(
    title: '超级马力欧银河大电影',
    poster: 'assets/prototype/movie-super-mario-galaxy.jpeg',
    state: '正在热映',
    time: '00:18:42',
    duration: '01:38',
    barrage: '26 弹幕',
    intro: '真期待一起和你看这部电影，终于上映了，我等了很久呢',
    subtitle: '这段像把周末直接点亮了。',
  ),
  _MovieItem(
    title: '曼达洛人与古古',
    poster: 'assets/prototype/movie-mandalorian-grogu.jpg',
    state: '近期上映',
    time: '预告 01:08',
    duration: '02:16',
    barrage: '42 想看',
    intro: '这部马上就要上映了，我们先把预告看完。',
    subtitle: '等上映那天，我们把第一场留给它。',
  ),
  _MovieItem(
    title: 'Project Hail Mary',
    poster: 'assets/prototype/movie-project-hail-mary.jpg',
    state: '近期上映',
    time: '00:36:05',
    duration: '02:12',
    barrage: '19 弹幕',
    intro: '这部刚上映不久，很适合留一个安静的夜晚。',
    subtitle: '如果宇宙只剩一个声音，我想和你一起听。',
  ),
];

const _barrageRows = [
  _BarrageRow('01:46', '小芜：如果你不想说话，我们就先看完这一幕。'),
  _BarrageRow('01:42', '小芜：这里的眼神好适合暂停一下。'),
  _BarrageRow('01:43', '你：这句台词有点像我们刚才说的。'),
];
