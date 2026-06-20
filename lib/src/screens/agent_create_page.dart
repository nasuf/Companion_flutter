part of 'package:companion_flutter/main.dart';

const _llmEstimatedSeconds = 45.0;
const _llmPercentBase = 15.0;
const _llmPercentRange = 55.0;
const _llmMessageRotationSeconds = 6;
const _llmRotatingMessages = [
  '正在塑造身份基础...',
  '正在编织生活经历...',
  '正在唤醒情绪记忆...',
  '正在确立价值观与思维...',
  '正在校对一致性...',
];

class AgentCreatePage extends StatefulWidget {
  const AgentCreatePage({super.key, this.api, this.session, this.onCreated});

  final CompanionApi? api;
  final AuthSession? session;
  final ValueChanged<AuthSession>? onCreated;

  @override
  State<AgentCreatePage> createState() => _AgentCreatePageState();
}

class _AgentCreatePageState extends State<AgentCreatePage>
    with TickerProviderStateMixin {
  late final AnimationController _breathController;
  late final AnimationController _traitMoveController;
  final _nameController = TextEditingController(text: '小芜');
  var _gender = _AgentGender.female;
  late List<_TraitDraft> _traits;
  List<int>? _previousTraitValues;
  Timer? _provisionPollTimer;
  Timer? _llmTickerTimer;
  DateTime? _llmStartedAt;
  AgentProvisionStatus? _provisionStatus;
  bool _submitting = false;
  bool _finishingProvision = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _traitMoveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
      value: 1,
    );
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
    _provisionPollTimer?.cancel();
    _llmTickerTimer?.cancel();
    _breathController.dispose();
    _traitMoveController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _randomizeTraits() {
    final random = math.Random.secure();
    final traitMoveProgress = Curves.easeOutCubic.transform(
      _traitMoveController.value,
    );
    final previousValues = List<int>.generate(_traits.length, (index) {
      final previousValue =
          _previousTraitValues != null && index < _previousTraitValues!.length
          ? _previousTraitValues![index]
          : _traits[index].value;
      return (lerpDouble(
                previousValue,
                _traits[index].value,
                traitMoveProgress,
              ) ??
              _traits[index].value)
          .round();
    }, growable: false);
    final nextTraits = <_TraitDraft>[];
    for (final trait in _traits) {
      nextTraits.add(trait.copyWith(value: 42 + random.nextInt(35)));
    }
    _traitMoveController.value = 0;
    setState(() {
      _previousTraitValues = previousValues;
      _traits = nextTraits;
    });
    _traitMoveController.forward();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    final api = widget.api;
    final session = widget.session;
    final onCreated = widget.onCreated;
    if (api == null || session == null || onCreated == null) {
      setState(() => _error = '请先完成账号登录，再创建 Agent。');
      return;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '先给TA起一个名字吧。');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final agent = await api.createAgent(
        userId: session.userId,
        name: name,
        gender: _gender.apiValue,
        personality: {
          'lively': _traitValue('活泼度'),
          'rational': _traitValue('理性度'),
          'emotional': _traitValue('感性度'),
          'planned': _traitValue('计划度'),
          'spontaneous': _traitValue('随性度'),
          'creative': _traitValue('脑洞度'),
          'humor': _traitValue('幽默度'),
        },
      );
      _setProvisionStatus(
        AgentProvisionStatus(
          agentId: agent.id,
          status: 'provisioning',
          stage: 'initializing',
          percent: 0,
          message: '正在初始化...',
        ),
      );
      _startProvisionPolling(api, session, agent);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _asMessage(error);
          _submitting = false;
        });
      }
    }
  }

  void _startProvisionPolling(
    CompanionApi api,
    AuthSession session,
    AgentProfile agent,
  ) {
    _provisionPollTimer?.cancel();

    Future<void> poll() async {
      if (!mounted || _finishingProvision) return;
      try {
        final status = await api.getAgentProvisionStatus(agent.id);
        if (!mounted || _finishingProvision) return;
        _setProvisionStatus(status);
        if (status.isComplete) {
          await _finishProvision(api, session, agent);
        } else if (status.isFailed) {
          _provisionPollTimer?.cancel();
          _stopLlmTicker();
          if (mounted) {
            setState(() => _submitting = false);
          }
        }
      } catch (error) {
        debugPrint('[agent-provision-poll] $error');
      }
    }

    unawaited(poll());
    _provisionPollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(poll()),
    );
  }

  void _setProvisionStatus(AgentProvisionStatus status) {
    final previous = _provisionStatus;
    final continuingLlm =
        previous?.stage == 'llm_generating' && status.stage == 'llm_generating';
    final incomingPercent = status.isComplete
        ? 100
        : math.min(status.percent, 99);
    final nextPercent = status.stage == 'failed'
        ? status.percent
        : math.max(previous?.percent ?? 0, incomingPercent).toInt();
    final nextMessage = continuingLlm ? previous!.message : status.message;
    setState(() {
      _provisionStatus = status.copyWith(
        percent: nextPercent,
        message: nextMessage,
      );
      _error = null;
    });

    if (status.stage == 'llm_generating') {
      _llmStartedAt ??= DateTime.now();
      _startLlmTicker();
    } else {
      _llmStartedAt = null;
      _stopLlmTicker();
    }
  }

  void _startLlmTicker() {
    if (_llmTickerTimer != null) return;
    final startedAt = _llmStartedAt ?? DateTime.now();
    var tick = 0;
    _llmTickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final status = _provisionStatus;
      if (!mounted || status == null || status.stage != 'llm_generating') {
        _stopLlmTicker();
        return;
      }
      tick += 1;
      final elapsedSeconds =
          DateTime.now().difference(startedAt).inMilliseconds / 1000;
      final localPercent =
          _llmPercentBase +
          math.min(
            _llmPercentRange,
            (elapsedSeconds / _llmEstimatedSeconds) * _llmPercentRange,
          );
      final messageIndex =
          (tick / _llmMessageRotationSeconds).floor() %
          _llmRotatingMessages.length;
      final nextMessage = _llmRotatingMessages[messageIndex];
      setState(() {
        _provisionStatus = status.copyWith(
          percent: math.max(status.percent, localPercent.round()),
          message: nextMessage,
        );
      });
    });
  }

  void _stopLlmTicker() {
    _llmTickerTimer?.cancel();
    _llmTickerTimer = null;
  }

  Future<void> _finishProvision(
    CompanionApi api,
    AuthSession session,
    AgentProfile agent,
  ) async {
    if (_finishingProvision) return;
    _finishingProvision = true;
    _provisionPollTimer?.cancel();
    _stopLlmTicker();
    if (mounted) {
      setState(() {
        _provisionStatus =
            (_provisionStatus ??
                    AgentProvisionStatus(
                      agentId: agent.id,
                      status: 'active',
                      stage: 'complete',
                      percent: 100,
                      message: '初始化完成',
                    ))
                .copyWith(
                  status: 'active',
                  stage: 'complete',
                  percent: 100,
                  message: '创建完成，即将进入聊天...',
                );
      });
    }
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    try {
      AgentProfile latestAgent = agent;
      try {
        latestAgent = await api.getAgent(agent.id);
      } catch (error) {
        debugPrint('[agent-provision-agent-refresh] $error');
      }
      if (!mounted) return;
      await _precacheAgentAvatar(latestAgent.avatarUrl);
      if (!mounted) return;
      final createdSession = AuthSession(
        token: session.token,
        userId: session.userId,
        username: session.username,
        userDisplayName: session.userDisplayName,
        userAvatarUrl: session.userAvatarUrl,
        role: session.role,
        hasAgent: true,
        agentId: latestAgent.id,
        agentName: latestAgent.name,
        agentAvatarKey: latestAgent.avatarKey,
        agentAvatarUrl: latestAgent.avatarUrl,
        agentCity: latestAgent.city,
        workspaceId: latestAgent.workspaceId ?? agent.workspaceId,
      );
      final readySession = await api.ensureConversation(createdSession);
      if (!mounted) return;
      widget.onCreated!(readySession);
      Navigator.of(context).pop();
    } catch (error) {
      _finishingProvision = false;
      if (mounted) {
        setState(() {
          _error = _asMessage(error);
          _submitting = false;
        });
      }
    } finally {
      if (mounted && !_finishingProvision) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _precacheAgentAvatar(String? avatarUrl) async {
    final url = avatarUrl?.trim();
    if (url == null || url.isEmpty) return;
    try {
      await precacheImage(NetworkImage(url), context);
    } catch (error) {
      debugPrint('[agent-avatar-precache] $error');
    }
  }

  int _traitValue(String name) {
    return _traits.firstWhere((trait) => trait.name == name).value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: AnimatedBuilder(
        animation: Listenable.merge([_breathController, _traitMoveController]),
        builder: (context, _) {
          final progress = Curves.easeInOut.transform(_breathController.value);
          final moveProgress = Curves.easeOutCubic.transform(
            _traitMoveController.value,
          );
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
                        padding: const EdgeInsets.fromLTRB(30, 14, 30, 0),
                        child: _TraitStudio(
                          traits: _traits,
                          previousTraitValues: _previousTraitValues,
                          progress: progress,
                          moveProgress: moveProgress,
                          onRandomize: _randomizeTraits,
                          onChanged: (index, value) {
                            _traitMoveController.value = 1;
                            setState(() {
                              _previousTraitValues = null;
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
                        child: Column(
                          children: [
                            if (_error != null) ...[
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFD95B5B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            _CreateAgentButton(
                              loading: _submitting,
                              onPressed: _submit,
                            ),
                            const SizedBox(height: 22),
                          ],
                        ),
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
              if (_provisionStatus != null) ...[
                Positioned.fill(
                  child: AbsorbPointer(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: ColoredBox(
                        color: const Color(0xFFEAF4FF).withValues(alpha: 0.36),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: SafeArea(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 42),
                        child: _ProvisionProgressOverlay(
                          status: _provisionStatus!,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
    final colors = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.page,
            Color.lerp(colors.page, colors.surfaceMuted, 0.44)!,
            Color.lerp(colors.page, colors.accentSoft, 0.22)!,
          ],
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
      height: 264,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -68 + 18 * progress,
            top: 96 + 18 * (0.5 - progress),
            child: _BreathingGlassOrb(progress: progress),
          ),
          const Positioned(
            left: 0,
            top: 36,
            child: _ProfileKicker('FIRST PROFILE'),
          ),
          Positioned(
            left: 0,
            top: 88,
            right: 0,
            child: Text(
              '没有偶然的相遇\n只有灵魂与灵魂的\n呼应',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 38,
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
                fontSize: 15,
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
    return Padding(
      padding: EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileKicker('SOUL PROFILE'),
          SizedBox(height: 12),
          Text(
            '灵魂印记',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 28,
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
              fontSize: 14,
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
      style: TextStyle(
        color: AppColors.text,
        fontSize: 13,
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
            style: TextStyle(
              color: AppColors.text,
              fontSize: 21,
              height: 1.08,
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
        constraints: const BoxConstraints(minHeight: 58),
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
    final selectedIndex = value.index;
    return Container(
      height: 38,
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / 3;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: segmentWidth * selectedIndex,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.accentDeep.withValues(alpha: 0.94),
                          AppColors.accentCyan.withValues(alpha: 0.88),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentDeep.withValues(alpha: 0.16),
                          blurRadius: 18,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
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
            ],
          );
        },
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
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0x8A181F26),
              fontSize: 13,
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
    required this.previousTraitValues,
    required this.progress,
    required this.moveProgress,
    required this.onRandomize,
    required this.onChanged,
  });

  final List<_TraitDraft> traits;
  final List<int>? previousTraitValues;
  final double progress;
  final double moveProgress;
  final VoidCallback onRandomize;
  final void Function(int index, double value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
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
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.accentDeep.withValues(alpha: 0.92),
                      AppColors.accentCyan.withValues(alpha: 0.84),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentDeep.withValues(alpha: 0.13),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: CupertinoButton(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  borderRadius: BorderRadius.circular(999),
                  onPressed: onRandomize,
                  child: const Text(
                    '随机生成',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 138,
          child: CustomPaint(
            painter: _TraitMapPainter(
              traits: traits,
              previousTraitValues: previousTraitValues,
              progress: progress,
              moveProgress: moveProgress,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 4),
        Column(
          children: [
            for (var i = 0; i < traits.length; i += 1)
              _TraitSliderRow(
                trait: traits[i],
                previousValue:
                    previousTraitValues != null &&
                        i < previousTraitValues!.length
                    ? previousTraitValues![i]
                    : null,
                previousColor: i == 0 ? null : traits[i - 1].color,
                nextColor: i == traits.length - 1 ? null : traits[i + 1].color,
                fadeTop: i == 0,
                fadeBottom: i == traits.length - 1,
                progress: progress,
                moveProgress: moveProgress,
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
    required this.previousValue,
    required this.previousColor,
    required this.nextColor,
    required this.fadeTop,
    required this.fadeBottom,
    required this.progress,
    required this.moveProgress,
    required this.onChanged,
  });

  final _TraitDraft trait;
  final int? previousValue;
  final Color? previousColor;
  final Color? nextColor;
  final bool fadeTop;
  final bool fadeBottom;
  final double progress;
  final double moveProgress;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final value =
        lerpDouble(previousValue ?? trait.value, trait.value, moveProgress) ??
        trait.value.toDouble();
    final displayedValue = value.round();
    return SizedBox(
      height: 58,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _TraitRowBackgroundPainter(
                color: trait.color,
                progress: progress,
                fadeTop: fadeTop,
                fadeBottom: fadeBottom,
              ),
            ),
          ),
          Row(
            children: [
              SizedBox(
                width: 18,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.center,
                        child: Container(
                          width: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                (previousColor ?? trait.color).withValues(
                                  alpha: previousColor == null ? 0.02 : 0.16,
                                ),
                                trait.color.withValues(alpha: 0.24),
                                (nextColor ?? trait.color).withValues(
                                  alpha: nextColor == null ? 0.02 : 0.16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    AnimatedScale(
                      scale: 1 + 0.05 * progress,
                      duration: const Duration(milliseconds: 120),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: trait.color,
                          boxShadow: [
                            BoxShadow(
                              color: trait.color.withValues(
                                alpha: 0.12 + 0.10 * progress,
                              ),
                              blurRadius: 10 + 6 * progress,
                              spreadRadius: 3 + 3 * progress,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
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
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 13,
                              height: 1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          displayedValue.toString(),
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 11,
                            height: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          trait.low,
                          style: const TextStyle(
                            color: Color(0x66181F26),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          trait.high,
                          style: const TextStyle(
                            color: Color(0x66181F26),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2.6,
                        activeTrackColor: trait.color.withValues(alpha: 0.72),
                        inactiveTrackColor: const Color(0x12181F26),
                        thumbColor: Colors.white,
                        overlayColor: trait.color.withValues(alpha: 0.12),
                        trackShape: const _FullWidthSliderTrackShape(),
                        thumbShape: _RingSliderThumbShape(color: trait.color),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 12,
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
        ],
      ),
    );
  }
}

class _TraitRowBackgroundPainter extends CustomPainter {
  const _TraitRowBackgroundPainter({
    required this.color,
    required this.progress,
    required this.fadeTop,
    required this.fadeBottom,
  });

  final Color color;
  final double progress;
  final bool fadeTop;
  final bool fadeBottom;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.saveLayer(rect, Paint());
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            color.withValues(alpha: 0.026 + 0.018 * progress),
            color.withValues(alpha: 0.038 + 0.022 * progress),
            Colors.transparent,
          ],
          stops: const [0, 0.24, 0.58, 1],
        ).createShader(rect),
    );

    if (fadeTop || fadeBottom) {
      final stops = fadeTop ? const [0.0, 0.42, 1.0] : const [0.0, 0.58, 1.0];
      final colors = fadeTop
          ? const [Colors.transparent, Colors.white, Colors.white]
          : const [Colors.white, Colors.white, Colors.transparent];
      canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
            stops: stops,
          ).createShader(rect),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TraitRowBackgroundPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.progress != progress ||
        oldDelegate.fadeTop != fadeTop ||
        oldDelegate.fadeBottom != fadeBottom;
  }
}

class _TraitMapPainter extends CustomPainter {
  const _TraitMapPainter({
    required this.traits,
    required this.previousTraitValues,
    required this.progress,
    required this.moveProgress,
  });

  final List<_TraitDraft> traits;
  final List<int>? previousTraitValues;
  final double progress;
  final double moveProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.saveLayer(rect, Paint());
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x12FFFFFF),
            Color(0x0E18C6C0),
            Color(0x0B1F6FFF),
            Color(0x12FFFFFF),
          ],
          stops: [0, 0.36, 0.72, 1],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.78, -0.68),
          radius: 0.9,
          colors: [
            AppColors.accentDeep.withValues(alpha: 0.10),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.72, 0.72),
          radius: 0.86,
          colors: [
            AppColors.accentCyan.withValues(alpha: 0.10),
            Colors.transparent,
          ],
        ).createShader(rect),
    );

    final gridPaint = Paint()
      ..color = const Color(0x0E181F26)
      ..strokeWidth = 1;
    for (var x = 34.0; x < size.width; x += 34) {
      canvas.drawLine(Offset(x, 12), Offset(x, size.height - 12), gridPaint);
    }

    final axisPaint = Paint()
      ..color = const Color(0x24181F26)
      ..strokeWidth = 1.2;
    final axisY = size.height * 0.5;
    for (var y = axisY - 34; y >= 12; y -= 34) {
      canvas.drawLine(Offset(12, y), Offset(size.width - 12, y), gridPaint);
    }
    for (var y = axisY + 34; y < size.height - 12; y += 34) {
      canvas.drawLine(Offset(12, y), Offset(size.width - 12, y), gridPaint);
    }
    canvas.drawLine(
      Offset(30, axisY),
      Offset(size.width - 30, axisY),
      axisPaint,
    );

    for (var i = 0; i < traits.length; i += 1) {
      final trait = traits[i];
      final x = size.width * (0.18 + i * 0.105);
      final previousValue =
          previousTraitValues != null && i < previousTraitValues!.length
          ? previousTraitValues![i]
          : trait.value;
      final displayedValue =
          lerpDouble(previousValue, trait.value, moveProgress) ?? trait.value;
      final valueY = (100 - displayedValue) / 100;
      final y = 22 + valueY * (size.height - 54);
      final center = Offset(x, y);
      final haloRadius = 13 + 7 * progress;
      final dotRadius = 6.5 + 1.5 * progress;
      final haloPaint = Paint()
        ..color = trait.color.withValues(alpha: 0.11 - 0.04 * progress);
      canvas.drawCircle(center, haloRadius, haloPaint);
      final glowPaint = Paint()
        ..color = trait.color.withValues(alpha: 0.16 + 0.08 * progress)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + 3 * progress);
      canvas.drawCircle(center.translate(0, 7), 10 + 5 * progress, glowPaint);
      final dotPaint = Paint()..color = trait.color;
      canvas.drawCircle(center, dotRadius, dotPaint);
    }

    _applyEdgeMask(canvas, size);
    canvas.restore();
  }

  void _applyEdgeMask(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final maskPaint = Paint()
      ..blendMode = BlendMode.dstIn
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent,
        ],
        stops: [0, 0.22, 0.78, 1],
      ).createShader(rect);
    canvas.drawRect(rect, maskPaint);

    maskPaint.shader = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Colors.transparent,
        Colors.white,
        Colors.white,
        Colors.transparent,
      ],
      stops: [0, 0.08, 0.92, 1],
    ).createShader(rect);
    canvas.drawRect(rect, maskPaint);
  }

  @override
  bool shouldRepaint(covariant _TraitMapPainter oldDelegate) {
    return oldDelegate.traits != traits ||
        oldDelegate.previousTraitValues != previousTraitValues ||
        oldDelegate.progress != progress ||
        oldDelegate.moveProgress != moveProgress;
  }
}

class _RingSliderThumbShape extends SliderComponentShape {
  const _RingSliderThumbShape({required this.color});

  final Color color;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return const Size(15, 15);
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
      11,
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(center, 7.5, Paint()..color = color);
    canvas.drawCircle(center, 3.5, Paint()..color = Colors.white);
  }
}

class _FullWidthSliderTrackShape extends RoundedRectSliderTrackShape {
  const _FullWidthSliderTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 2;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    return Rect.fromLTWH(
      offset.dx,
      trackTop,
      parentBox.size.width,
      trackHeight,
    );
  }
}

class _ProvisionProgressOverlay extends StatelessWidget {
  const _ProvisionProgressOverlay({required this.status});

  final AgentProvisionStatus status;

  @override
  Widget build(BuildContext context) {
    final failed = status.isFailed;
    final percent = status.percent.clamp(0, 100).toInt();
    final color = failed ? const Color(0xFFD95B5B) : AppColors.accent;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: percent / 100),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ProvisionBreathingIcon(failed: failed, color: color),
            const SizedBox(height: 22),
            Text(
              failed ? '创建遇到问题' : '正在创建你的 AI 伙伴',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 21,
                height: 1.15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 7,
                      value: failed ? null : value,
                      backgroundColor: Colors.white.withValues(alpha: 0.58),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  failed ? '--' : '$percent%',
                  style: TextStyle(
                    color: failed
                        ? const Color(0xFFD95B5B)
                        : AppColors.accentDeep,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              status.message.isEmpty ? '正在初始化...' : status.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0x9A181F26),
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProvisionBreathingIcon extends StatefulWidget {
  const _ProvisionBreathingIcon({required this.failed, required this.color});

  final bool failed;
  final Color color;

  @override
  State<_ProvisionBreathingIcon> createState() =>
      _ProvisionBreathingIconState();
}

class _ProvisionBreathingIconState extends State<_ProvisionBreathingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: 108,
        height: 108,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final first = Curves.easeOutCubic.transform(t);
            final second = Curves.easeOutCubic.transform((t + 0.48) % 1);
            final centerPulse =
                0.5 + 0.5 * math.sin((t * math.pi * 2) - math.pi / 2);
            final centerScale = 0.94 + 0.12 * centerPulse;
            return Stack(
              alignment: Alignment.center,
              children: [
                _ProvisionHalo(
                  color: widget.color,
                  progress: first,
                  maxSize: 104,
                ),
                _ProvisionHalo(
                  color: widget.color,
                  progress: second,
                  maxSize: 92,
                ),
                Transform.scale(
                  scale: centerScale,
                  child: Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.25, -0.30),
                        radius: 0.92,
                        colors: [
                          Colors.white.withValues(alpha: 0.76),
                          widget.color.withValues(alpha: 0.13),
                          Colors.white.withValues(alpha: 0.34),
                        ],
                        stops: const [0, 0.62, 1],
                      ),
                    ),
                    child: Icon(
                      widget.failed
                          ? CupertinoIcons.exclamationmark_triangle_fill
                          : CupertinoIcons.sparkles,
                      color: widget.color,
                      size: 31,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProvisionHalo extends StatelessWidget {
  const _ProvisionHalo({
    required this.color,
    required this.progress,
    required this.maxSize,
  });

  final Color color;
  final double progress;
  final double maxSize;

  @override
  Widget build(BuildContext context) {
    final size = 58 + (maxSize - 58) * progress;
    final opacity = (1 - progress).clamp(0.0, 1.0);
    return Opacity(
      opacity: 0.30 * opacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.40),
              color.withValues(alpha: 0.12),
              Colors.transparent,
            ],
            stops: const [0, 0.58, 1],
          ),
        ),
      ),
    );
  }
}

class _CreateAgentButton extends StatelessWidget {
  const _CreateAgentButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          gradient: LinearGradient(
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
          onPressed: loading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
          ),
          child: loading
              ? const CupertinoActivityIndicator(color: Colors.white)
              : const Text(
                  '让故事开始',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                ),
        ),
      ),
    );
  }
}

enum _AgentGender { male, female, random }

extension _AgentGenderApi on _AgentGender {
  String get apiValue {
    return switch (this) {
      _AgentGender.male => 'male',
      _AgentGender.female => 'female',
      _AgentGender.random =>
        math.Random.secure().nextBool() ? 'male' : 'female',
    };
  }
}

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
