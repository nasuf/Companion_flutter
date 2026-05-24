part of 'package:companion_flutter/main.dart';

class AgentCreatePage extends StatefulWidget {
  const AgentCreatePage({super.key});

  @override
  State<AgentCreatePage> createState() => _AgentCreatePageState();
}

class _AgentCreatePageState extends State<AgentCreatePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathController;
  final _nameController = TextEditingController(text: '小芜');
  var _gender = _AgentGender.female;
  late List<_TraitDraft> _traits;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7600),
    )..repeat(reverse: true);
    _traits = _defaultTraits
        .map(
          (trait) => _TraitDraft(
            name: trait.name,
            low: trait.low,
            high: trait.high,
            color: trait.color,
            value: trait.value,
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    _breathController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _randomizeTraits() {
    setState(() {
      for (var i = 0; i < _traits.length; i += 1) {
        final seed = DateTime.now().millisecondsSinceEpoch + i * 97;
        _traits[i] = _traits[i].copyWith(value: 42 + seed % 34);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: AnimatedBuilder(
        animation: _breathController,
        builder: (context, _) {
          final progress = Curves.easeInOut.transform(_breathController.value);
          return Stack(
            children: [
              _AgentCreateBackdrop(progress: progress),
              SafeArea(
                bottom: false,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(30, 54, 30, 0),
                        child: _CreateHero(progress: progress),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(30, 0, 30, 0),
                        child: _SoulProfileIntro(),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(30, 8, 30, 0),
                        child: _AgentBasicFields(
                          nameController: _nameController,
                          gender: _gender,
                          onGenderChanged: (gender) =>
                              setState(() => _gender = gender),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(30, 20, 30, 0),
                        child: _TraitStudio(
                          traits: _traits,
                          progress: progress,
                          onRandomize: _randomizeTraits,
                          onChanged: (index, value) {
                            setState(() {
                              _traits[index] = _traits[index].copyWith(
                                value: value.round(),
                              );
                            });
                          },
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(30, 26, 30, 36),
                        child: _CreateAgentButton(onPressed: () {}),
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8),
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(42, 42),
                      borderRadius: BorderRadius.circular(21),
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: Icon(
                        CupertinoIcons.chevron_left,
                        color: AppColors.text.withValues(alpha: 0.68),
                        size: 24,
                      ),
                    ),
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

class _AgentCreateBackdrop extends StatelessWidget {
  const _AgentCreateBackdrop({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFBFEFD), Color(0xFFF7FBFA), Color(0xFFF7FBFF)],
          stops: [0, 0.58, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -142 + 20 * progress,
            top: 76 + 26 * progress,
            child: _AgentAuraBlob(
              width: 340,
              height: 300,
              colors: const [Color(0x3658A8FF), Color(0x2618C6C0)],
              opacity: 0.72,
            ),
          ),
          Positioned(
            left: -168 - 12 * progress,
            top: 356 + 16 * progress,
            child: _AgentAuraBlob(
              width: 300,
              height: 360,
              colors: const [Color(0x247C3CFF), Color(0x1A18C6C0)],
              opacity: 0.56,
            ),
          ),
          Positioned(
            right: -96,
            bottom: 80 - 20 * progress,
            child: _AgentAuraBlob(
              width: 280,
              height: 360,
              colors: const [Color(0x1F1F6FFF), Color(0x1418C6C0)],
              opacity: 0.48,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentAuraBlob extends StatelessWidget {
  const _AgentAuraBlob({
    required this.width,
    required this.height,
    required this.colors,
    required this.opacity,
  });

  final double width;
  final double height;
  final List<Color> colors;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: RadialGradient(
              center: const Alignment(-0.12, -0.54),
              radius: 0.76,
              colors: [colors.first, Colors.transparent],
            ),
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: RadialGradient(
              center: const Alignment(0.46, 0.42),
              radius: 0.82,
              colors: [colors.last, Colors.transparent],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateHero extends StatelessWidget {
  const _CreateHero({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 286,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -28 + 14 * progress,
            top: 94 + 16 * (0.5 - progress),
            child: _BreathingGlassOrb(progress: progress),
          ),
          const Positioned(
            left: 0,
            top: 44,
            child: _ProfileKicker('FIRST PROFILE'),
          ),
          const Positioned(
            left: 0,
            top: 102,
            right: 0,
            child: Text(
              '没有偶然的相遇\n只有灵魂与灵魂的\n呼应',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 43,
                height: 1.04,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
          const Positioned(
            left: 0,
            bottom: 8,
            child: Text(
              '在这里，你设定的每一笔，都是找寻的起点',
              style: TextStyle(
                color: Color(0x8A181F26),
                fontSize: 17,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoulProfileIntro extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileKicker('SOUL PROFILE'),
          SizedBox(height: 12),
          Text(
            '灵魂印记',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 31,
              height: 1.12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          SizedBox(height: 10),
          Text(
            '设定你的轮廓，让同频的TA找到你',
            style: TextStyle(
              color: Color(0x82181F26),
              fontSize: 15,
              height: 1.52,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileKicker extends StatelessWidget {
  const _ProfileKicker(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.text,
        fontSize: 14,
        height: 1,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _AgentBasicFields extends StatelessWidget {
  const _AgentBasicFields({
    required this.nameController,
    required this.gender,
    required this.onGenderChanged,
  });

  final TextEditingController nameController;
  final _AgentGender gender;
  final ValueChanged<_AgentGender> onGenderChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DividerRow(
          label: '名字',
          child: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 21,
              height: 1.1,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        _DividerRow(
          label: '性别',
          child: _GenderControl(value: gender, onChanged: onGenderChanged),
        ),
      ],
    );
  }
}

class _DividerRow extends StatelessWidget {
  const _DividerRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x10181F26), width: 1)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0x7A181F26),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _GenderControl extends StatelessWidget {
  const _GenderControl({required this.value, required this.onChanged});

  final _AgentGender value;
  final ValueChanged<_AgentGender> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.34),
        border: Border.all(color: const Color(0x12181F26)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.58),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          _GenderPill(
            label: '男',
            selected: value == _AgentGender.male,
            onTap: () => onChanged(_AgentGender.male),
          ),
          _GenderPill(
            label: '女',
            selected: value == _AgentGender.female,
            onTap: () => onChanged(_AgentGender.female),
          ),
          _GenderPill(
            label: '随机',
            selected: value == _AgentGender.random,
            onTap: () => onChanged(_AgentGender.random),
          ),
        ],
      ),
    );
  }
}

class _GenderPill extends StatelessWidget {
  const _GenderPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: CupertinoButton(
        minimumSize: Size.zero,
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(999),
        onPressed: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected ? Colors.white.withValues(alpha: 0.86) : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF385258).withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.text : const Color(0x8A181F26),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _TraitStudio extends StatelessWidget {
  const _TraitStudio({
    required this.traits,
    required this.progress,
    required this.onRandomize,
    required this.onChanged,
  });

  final List<_TraitDraft> traits;
  final double progress;
  final VoidCallback onRandomize;
  final void Function(int index, double value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '灵魂倾向',
                  style: TextStyle(
                    color: Color(0x7A181F26),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              CupertinoButton(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                borderRadius: BorderRadius.circular(999),
                color: Colors.white.withValues(alpha: 0.44),
                onPressed: onRandomize,
                child: const Text(
                  '随机生成',
                  style: TextStyle(
                    color: Color(0xFF143137),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 174,
          child: CustomPaint(
            painter: _TraitMapPainter(traits: traits, progress: progress),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 18),
        Column(
          children: [
            for (var i = 0; i < traits.length; i += 1)
              _TraitSliderRow(
                trait: traits[i],
                progress: progress,
                onChanged: (value) => onChanged(i, value),
              ),
          ],
        ),
      ],
    );
  }
}

class _TraitSliderRow extends StatelessWidget {
  const _TraitSliderRow({
    required this.trait,
    required this.progress,
    required this.onChanged,
  });

  final _TraitDraft trait;
  final double progress;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final value = trait.value.toDouble();
    return Container(
      height: 112,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            trait.color.withValues(alpha: 0.035 + 0.025 * progress),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 1,
                      color: trait.color.withValues(alpha: 0.13),
                    ),
                  ),
                ),
                AnimatedScale(
                  scale: 1 + 0.08 * progress,
                  duration: const Duration(milliseconds: 120),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: trait.color,
                      boxShadow: [
                        BoxShadow(
                          color: trait.color.withValues(
                            alpha: 0.16 + 0.14 * progress,
                          ),
                          blurRadius: 14 + 10 * progress,
                          spreadRadius: 4 + 4 * progress,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        trait.name,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 22,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      trait.value.toString(),
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 18,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      trait.low,
                      style: const TextStyle(
                        color: Color(0x66181F26),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      trait.high,
                      style: const TextStyle(
                        color: Color(0x66181F26),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    activeTrackColor: trait.color.withValues(alpha: 0.72),
                    inactiveTrackColor: const Color(0x12181F26),
                    thumbColor: Colors.white,
                    overlayColor: trait.color.withValues(alpha: 0.12),
                    thumbShape: _RingSliderThumbShape(color: trait.color),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 18,
                    ),
                  ),
                  child: Slider(
                    min: 0,
                    max: 100,
                    value: value,
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TraitMapPainter extends CustomPainter {
  const _TraitMapPainter({required this.traits, required this.progress});

  final List<_TraitDraft> traits;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final fadePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Color(0x4DFFFFFF), Colors.transparent],
        stops: [0, 0.5, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, fadePaint);

    final gridPaint = Paint()
      ..color = const Color(0x11181F26)
      ..strokeWidth = 1;
    for (var x = 34.0; x < size.width; x += 34) {
      canvas.drawLine(Offset(x, 12), Offset(x, size.height - 12), gridPaint);
    }
    for (var y = 26.0; y < size.height; y += 34) {
      canvas.drawLine(Offset(12, y), Offset(size.width - 12, y), gridPaint);
    }

    final axisPaint = Paint()
      ..color = const Color(0x24181F26)
      ..strokeWidth = 1.2;
    final axisY = size.height * 0.52;
    canvas.drawLine(
      Offset(30, axisY),
      Offset(size.width - 30, axisY),
      axisPaint,
    );

    for (var i = 0; i < traits.length; i += 1) {
      final trait = traits[i];
      final x = size.width * (0.18 + i * 0.105);
      final valueY = (100 - trait.value) / 100;
      final drift = math.sin(progress * math.pi * 2 + i * 0.74) * 4;
      final y = 22 + valueY * (size.height - 54) + drift;
      final center = Offset(x, y);
      final haloPaint = Paint()
        ..color = trait.color.withValues(alpha: 0.10 + 0.05 * progress);
      canvas.drawCircle(center, 28 + 6 * progress, haloPaint);
      final glowPaint = Paint()
        ..color = trait.color.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(center.translate(0, 8), 16, glowPaint);
      final dotPaint = Paint()..color = trait.color;
      canvas.drawCircle(center, 8 + 1.2 * progress, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TraitMapPainter oldDelegate) {
    return true;
  }
}

class _RingSliderThumbShape extends SliderComponentShape {
  const _RingSliderThumbShape({required this.color});

  final Color color;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return const Size(20, 20);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(
      center,
      15,
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(center, 10, Paint()..color = color);
    canvas.drawCircle(center, 4.2, Paint()..color = Colors.white);
  }
}

class _CreateAgentButton extends StatelessWidget {
  const _CreateAgentButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(21),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [AppColors.accentDeep, AppColors.accentCyan],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentDeep.withValues(alpha: 0.22),
              blurRadius: 40,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(21),
            ),
          ),
          child: const Text(
            '让故事开始',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

enum _AgentGender { male, female, random }

class _TraitDraft {
  const _TraitDraft({
    required this.name,
    required this.low,
    required this.high,
    required this.color,
    required this.value,
  });

  final String name;
  final String low;
  final String high;
  final Color color;
  final int value;

  _TraitDraft copyWith({int? value}) {
    return _TraitDraft(
      name: name,
      low: low,
      high: high,
      color: color,
      value: value ?? this.value,
    );
  }
}

const _defaultTraits = [
  _TraitDraft(
    name: '活泼度',
    low: '内敛',
    high: '活泼',
    color: Color(0xFF18C6C0),
    value: 62,
  ),
  _TraitDraft(
    name: '理性度',
    low: '感性',
    high: '理性',
    color: Color(0xFF2F6FFF),
    value: 54,
  ),
  _TraitDraft(
    name: '感性度',
    low: '冷静',
    high: '感性',
    color: Color(0xFF7C3CFF),
    value: 68,
  ),
  _TraitDraft(
    name: '计划度',
    low: '随性',
    high: '计划',
    color: Color(0xFFFF6A3D),
    value: 47,
  ),
  _TraitDraft(
    name: '随性度',
    low: '规矩',
    high: '随性',
    color: Color(0xFF22C66B),
    value: 58,
  ),
  _TraitDraft(
    name: '脑洞度',
    low: '务实',
    high: '脑洞',
    color: Color(0xFFFFC936),
    value: 73,
  ),
  _TraitDraft(
    name: '幽默度',
    low: '严肃',
    high: '幽默',
    color: Color(0xFFE85B6D),
    value: 61,
  ),
];
