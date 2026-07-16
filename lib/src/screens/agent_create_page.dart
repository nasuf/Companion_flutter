part of 'package:companion_flutter/main.dart';

const _agentCreateAccent = Color(0xFF06C893);
const _agentCreateMintText = Color(0xFF90CBBB);
const _agentCreateViewport = Size(390, 844);
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
  late final AnimationController _traitMoveController;
  final _nameController = TextEditingController(text: '小芜');
  var _gender = _AgentGender.female;
  var _step = _AgentCreateStep.gender;
  int? _openTraitInfoIndex;
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
    _traitMoveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
      value: 1,
    );
    _traits = _defaultTraits
        .map(
          (trait) => _TraitDraft(
            name: trait.name,
            low: trait.low,
            high: trait.high,
            value: trait.value,
            description: trait.description,
            lowDescription: trait.lowDescription,
            highDescription: trait.highDescription,
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    _provisionPollTimer?.cancel();
    _llmTickerTimer?.cancel();
    _traitMoveController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _showTraits() {
    setState(() {
      _step = _AgentCreateStep.traits;
      _openTraitInfoIndex = null;
      _error = null;
    });
  }

  void _showGender() {
    setState(() {
      _step = _AgentCreateStep.gender;
      _openTraitInfoIndex = null;
      _error = null;
    });
  }

  void _handleBack() {
    if (_submitting) return;
    if (_step == _AgentCreateStep.traits) {
      _showGender();
      return;
    }
    Navigator.of(context).maybePop();
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
    final nextTraits = _traits
        .map((trait) => trait.copyWith(value: random.nextInt(101)))
        .toList(growable: false);
    _traitMoveController.value = 0;
    setState(() {
      _previousTraitValues = previousValues;
      _traits = nextTraits;
      _openTraitInfoIndex = null;
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
      _openTraitInfoIndex = null;
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
      setState(() {
        _provisionStatus = status.copyWith(
          percent: math.max(status.percent, localPercent.round()),
          message: _llmRotatingMessages[messageIndex],
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFD1FFF4),
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox.fromSize(
                    size: _agentCreateViewport,
                    child: AnimatedBuilder(
                      animation: _traitMoveController,
                      builder: (context, _) {
                        final moveProgress = Curves.easeOutCubic.transform(
                          _traitMoveController.value,
                        );
                        return MediaQuery.withNoTextScaling(
                          child: _AgentCreateCanvas(
                            step: _step,
                            gender: _gender,
                            traits: _traits,
                            previousTraitValues: _previousTraitValues,
                            traitMoveProgress: moveProgress,
                            openTraitInfoIndex: _openTraitInfoIndex,
                            submitting: _submitting,
                            error: _error,
                            onBack: _handleBack,
                            onGenderChanged: (gender) =>
                                setState(() => _gender = gender),
                            onNext: _showTraits,
                            onPrevious: _showGender,
                            onRandomize: _randomizeTraits,
                            onTraitInfoPressed: (index) {
                              setState(() {
                                _openTraitInfoIndex =
                                    _openTraitInfoIndex == index ? null : index;
                              });
                            },
                            onTraitChanged: (index, value) {
                              _traitMoveController.value = 1;
                              setState(() {
                                _previousTraitValues = null;
                                _openTraitInfoIndex = null;
                                _traits[index] = _traits[index].copyWith(
                                  value: value.round(),
                                );
                              });
                            },
                            onSubmit: _submit,
                          ),
                        );
                      },
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
                      color: const Color(0xFFE8FEFB).withValues(alpha: 0.72),
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
        ),
      ),
    );
  }
}

class _AgentCreateCanvas extends StatelessWidget {
  const _AgentCreateCanvas({
    required this.step,
    required this.gender,
    required this.traits,
    required this.previousTraitValues,
    required this.traitMoveProgress,
    required this.openTraitInfoIndex,
    required this.submitting,
    required this.error,
    required this.onBack,
    required this.onGenderChanged,
    required this.onNext,
    required this.onPrevious,
    required this.onRandomize,
    required this.onTraitInfoPressed,
    required this.onTraitChanged,
    required this.onSubmit,
  });

  final _AgentCreateStep step;
  final _AgentGender gender;
  final List<_TraitDraft> traits;
  final List<int>? previousTraitValues;
  final double traitMoveProgress;
  final int? openTraitInfoIndex;
  final bool submitting;
  final String? error;
  final VoidCallback onBack;
  final ValueChanged<_AgentGender> onGenderChanged;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onRandomize;
  final ValueChanged<int> onTraitInfoPressed;
  final void Function(int index, double value) onTraitChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: const TextStyle(
        color: Colors.black,
        fontFamilyFallback: ['PingFang SC', 'Noto Sans CJK SC'],
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: _AgentCreateBackground()),
          _AgentCreateHeader(onBack: onBack),
          if (step == _AgentCreateStep.gender)
            _GenderStep(
              gender: gender,
              onGenderChanged: onGenderChanged,
              onNext: onNext,
            )
          else
            _TraitsStep(
              traits: traits,
              previousTraitValues: previousTraitValues,
              moveProgress: traitMoveProgress,
              openInfoIndex: openTraitInfoIndex,
              submitting: submitting,
              error: error,
              onPrevious: onPrevious,
              onRandomize: onRandomize,
              onInfoPressed: onTraitInfoPressed,
              onChanged: onTraitChanged,
              onSubmit: onSubmit,
            ),
        ],
      ),
    );
  }
}

class _AgentCreateBackground extends StatelessWidget {
  const _AgentCreateBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.66, -1),
          end: Alignment(0.54, 1),
          colors: [Color(0xFFE8FEFB), Color(0xFFD1FFF4)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -36,
            top: -26,
            width: 138,
            height: 138,
            child: Image.asset(
              'assets/prototype/agent-creation-top-orb.png',
              fit: BoxFit.fill,
            ),
          ),
          Positioned(
            right: -64,
            bottom: -40,
            width: 170,
            height: 170,
            child: Image.asset(
              'assets/prototype/agent-creation-bottom-orb.png',
              fit: BoxFit.fill,
            ),
          ),
          Positioned(
            right: -51,
            top: 90,
            width: 202,
            height: 124,
            child: Image.asset(
              'assets/prototype/agent-creation-planet.png',
              fit: BoxFit.fill,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentCreateHeader extends StatelessWidget {
  const _AgentCreateHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned(
          top: 58,
          left: 0,
          right: 0,
          child: Text(
            '寻找专属你的TA',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              height: 25 / 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Positioned(
          left: 16,
          top: 54,
          width: 36,
          height: 36,
          child: CupertinoButton(
            key: const ValueKey('agent-create-back'),
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: 0.62),
            pressedOpacity: 0.72,
            onPressed: onBack,
            child: const Icon(
              CupertinoIcons.chevron_left,
              size: 25,
              color: Color(0xFF111111),
            ),
          ),
        ),
      ],
    );
  }
}

class _GenderStep extends StatelessWidget {
  const _GenderStep({
    required this.gender,
    required this.onGenderChanged,
    required this.onNext,
  });

  final _AgentGender gender;
  final ValueChanged<_AgentGender> onGenderChanged;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 36,
          top: 122,
          width: 133,
          height: 71,
          child: Image.asset(
            'assets/prototype/agent-creation-hi.png',
            fit: BoxFit.fill,
          ),
        ),
        const Positioned(
          left: 41,
          top: 283,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TA是男生还是女生？',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  height: 22 / 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '性别设置后将无法修改',
                style: TextStyle(
                  color: _agentCreateMintText,
                  fontSize: 12,
                  height: 17 / 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 41,
          top: 350,
          child: Row(
            children: [
              _GenderCard(
                gender: _AgentGender.female,
                selected: gender == _AgentGender.female,
                onPressed: () => onGenderChanged(_AgentGender.female),
              ),
              const SizedBox(width: 12),
              _GenderCard(
                gender: _AgentGender.male,
                selected: gender == _AgentGender.male,
                onPressed: () => onGenderChanged(_AgentGender.male),
              ),
            ],
          ),
        ),
        Positioned(
          left: 14,
          top: 734,
          width: 362,
          height: 52,
          child: _AgentCreateButton(
            key: const ValueKey('agent-create-next'),
            label: '下一步',
            filled: true,
            onPressed: onNext,
          ),
        ),
      ],
    );
  }
}

class _GenderCard extends StatelessWidget {
  const _GenderCard({
    required this.gender,
    required this.selected,
    required this.onPressed,
  });

  final _AgentGender gender;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final female = gender == _AgentGender.female;
    return Semantics(
      selected: selected,
      button: true,
      label: female ? '女生' : '男生',
      child: CupertinoButton(
        key: ValueKey(female ? 'agent-gender-female' : 'agent-gender-male'),
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        pressedOpacity: 0.82,
        borderRadius: BorderRadius.circular(16),
        onPressed: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 148,
          height: 212,
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFD0FFF2)
                : Colors.white.withValues(alpha: 0.40),
            borderRadius: BorderRadius.circular(16),
            border: selected
                ? Border.all(color: _agentCreateAccent, width: 2)
                : null,
            boxShadow: const [
              BoxShadow(
                color: Color(0x2606C893),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 16,
                width: 100,
                height: 130,
                child: Image.asset(
                  female
                      ? 'assets/prototype/agent-creation-female.png'
                      : 'assets/prototype/agent-creation-male.png',
                  fit: BoxFit.fill,
                ),
              ),
              Positioned(
                top: 155,
                child: Text(
                  female ? '女生' : '男生',
                  style: TextStyle(
                    color: selected
                        ? _agentCreateAccent
                        : _agentCreateAccent.withValues(alpha: 0.40),
                    fontSize: 20,
                    height: 28 / 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (selected)
                const Positioned(
                  bottom: 6,
                  width: 60,
                  height: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _agentCreateAccent,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TraitsStep extends StatelessWidget {
  const _TraitsStep({
    required this.traits,
    required this.previousTraitValues,
    required this.moveProgress,
    required this.openInfoIndex,
    required this.submitting,
    required this.error,
    required this.onPrevious,
    required this.onRandomize,
    required this.onInfoPressed,
    required this.onChanged,
    required this.onSubmit,
  });

  final List<_TraitDraft> traits;
  final List<int>? previousTraitValues;
  final double moveProgress;
  final int? openInfoIndex;
  final bool submitting;
  final String? error;
  final VoidCallback onPrevious;
  final VoidCallback onRandomize;
  final ValueChanged<int> onInfoPressed;
  final void Function(int index, double value) onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final infoIndex = openInfoIndex;
    return Stack(
      children: [
        const Positioned(
          left: 20,
          top: 104,
          child: Text(
            '灵魂倾向',
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              height: 22 / 16,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        Positioned(
          left: 286,
          top: 104,
          width: 84,
          height: 29,
          child: _RandomizeButton(onPressed: onRandomize),
        ),
        const Positioned(
          left: 21,
          top: 140,
          width: 350,
          height: 14,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.info_circle,
                size: 14,
                color: _agentCreateMintText,
              ),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  '温馨提示：参数直接影响TA的寻找匹配，提交后无法修改，请谨慎选择。',
                  maxLines: 1,
                  style: TextStyle(
                    color: _agentCreateMintText,
                    fontSize: 10,
                    height: 14 / 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 20,
          top: 174,
          width: 350,
          child: Column(
            children: [
              for (var i = 0; i < traits.length; i += 1) ...[
                _TraitCard(
                  trait: traits[i],
                  displayedValue:
                      (lerpDouble(
                                previousTraitValues != null &&
                                        i < previousTraitValues!.length
                                    ? previousTraitValues![i]
                                    : traits[i].value,
                                traits[i].value,
                                moveProgress,
                              ) ??
                              traits[i].value)
                          .round(),
                  onInfoPressed: () => onInfoPressed(i),
                  onChanged: (value) => onChanged(i, value),
                ),
                if (i < traits.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        if (infoIndex != null)
          Positioned(
            left: 102,
            top: _traitInfoTop[infoIndex],
            width: 256,
            child: _TraitInfoPanel(trait: traits[infoIndex]),
          ),
        if (error != null)
          Positioned(
            left: 20,
            right: 20,
            top: 644,
            child: Text(
              error!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFD95B5B),
                fontSize: 11,
                height: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Positioned(
          left: 14,
          top: 670,
          width: 362,
          height: 52,
          child: _AgentCreateButton(
            key: const ValueKey('agent-create-previous'),
            label: '上一步',
            filled: false,
            onPressed: submitting ? null : onPrevious,
          ),
        ),
        Positioned(
          left: 14,
          top: 734,
          width: 362,
          height: 52,
          child: _AgentCreateButton(
            key: const ValueKey('agent-create-submit'),
            label: '让故事开始',
            filled: true,
            loading: submitting,
            onPressed: submitting ? null : onSubmit,
          ),
        ),
      ],
    );
  }
}

class _RandomizeButton extends StatelessWidget {
  const _RandomizeButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      key: const ValueKey('agent-create-randomize'),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      minimumSize: Size.zero,
      pressedOpacity: 0.76,
      borderRadius: BorderRadius.circular(999),
      color: Colors.white,
      onPressed: onPressed,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.sparkles, color: _agentCreateAccent, size: 16),
          SizedBox(width: 4),
          Text(
            '随机生成',
            style: TextStyle(
              color: _agentCreateAccent,
              fontSize: 12,
              height: 17 / 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _TraitCard extends StatelessWidget {
  const _TraitCard({
    required this.trait,
    required this.displayedValue,
    required this.onInfoPressed,
    required this.onChanged,
  });

  final _TraitDraft trait;
  final int displayedValue;
  final VoidCallback onInfoPressed;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350,
      height: 56,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2606C893),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            height: 32,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 5,
                  child: Text(
                    trait.name,
                    style: const TextStyle(
                      color: Color(0xFF333333),
                      fontSize: 16,
                      height: 22 / 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Positioned(
                  left: 50,
                  top: 0,
                  width: 12,
                  height: 12,
                  child: CupertinoButton(
                    key: ValueKey('agent-trait-info-${trait.name}'),
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    pressedOpacity: 0.62,
                    onPressed: onInfoPressed,
                    child: const Icon(
                      CupertinoIcons.question_circle,
                      size: 12,
                      color: Color(0xFF8B8B8B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 206,
            height: 16,
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 14,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      trait.low,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Color(0x80000000),
                        fontSize: 10,
                        height: 14 / 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 150,
                  height: 16,
                  child: _FigmaTraitSlider(
                    value: displayedValue.toDouble(),
                    onChanged: onChanged,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 20,
                  height: 14,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      trait.high,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Color(0xFF808080),
                        fontSize: 10,
                        height: 14 / 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 42,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _agentCreateAccent),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4006C893),
                  blurRadius: 4,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              '$displayedValue',
              style: const TextStyle(
                color: _agentCreateAccent,
                fontFamily: 'SF Pro',
                fontFamilyFallback: ['SF Pro Display', 'Arial'],
                fontSize: 16,
                height: 19 / 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FigmaTraitSlider extends StatelessWidget {
  const _FigmaTraitSlider({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  void _update(Offset localPosition, double width) {
    if (width <= 0) return;
    onChanged((localPosition.dx / width * 100).clamp(0, 100));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final normalized = (value / 100).clamp(0.0, 1.0);
        final thumbLeft = (width - 16) * normalized;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _update(details.localPosition, width),
          onHorizontalDragUpdate: (details) =>
              _update(details.localPosition, width),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 4,
                height: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _agentCreateAccent),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 4,
                width: math.max(8, thumbLeft + 8),
                height: 8,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: _agentCreateAccent,
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                  ),
                ),
              ),
              Positioned(
                left: thumbLeft,
                top: 0,
                width: 16,
                height: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: _agentCreateAccent, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x4006C893),
                        blurRadius: 4,
                        offset: Offset(0, 4),
                      ),
                    ],
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

class _TraitInfoPanel extends StatelessWidget {
  const _TraitInfoPanel({required this.trait});

  final _TraitDraft trait;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 95,
      color: const Color(0xFF737373),
      child: Stack(
        children: [
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            height: 17,
            child: Text(
              trait.description,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                height: 17 / 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 41,
            height: 19,
            child: _TraitInfoLine(
              label: '数值偏低',
              description: trait.lowDescription,
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 60,
            height: 19,
            child: _TraitInfoLine(
              label: '数值偏高',
              description: trait.highDescription,
            ),
          ),
        ],
      ),
    );
  }
}

class _TraitInfoLine extends StatelessWidget {
  const _TraitInfoLine({required this.label, required this.description});

  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: '——$description'),
          ],
        ),
        maxLines: 1,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          height: 19 / 12,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _AgentCreateButton extends StatelessWidget {
  const _AgentCreateButton({
    super.key,
    required this.label,
    required this.filled,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final bool filled;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: filled ? _agentCreateAccent : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: filled ? null : Border.all(color: _agentCreateAccent),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2606C893),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        pressedOpacity: 0.78,
        borderRadius: BorderRadius.circular(999),
        onPressed: onPressed,
        child: loading
            ? const CupertinoActivityIndicator(color: Colors.white)
            : Text(
                label,
                style: TextStyle(
                  color: filled ? Colors.white : _agentCreateAccent,
                  fontSize: 18,
                  height: 25 / 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
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
    final color = failed ? const Color(0xFFD95B5B) : _agentCreateAccent;
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
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 21,
                height: 1.15,
                fontWeight: FontWeight.w700,
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
                      backgroundColor: Colors.white.withValues(alpha: 0.68),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  failed ? '--' : '$percent%',
                  style: TextStyle(
                    color: color,
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
                color: Color(0x99111111),
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
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
                  scale: 0.94 + 0.12 * centerPulse,
                  child: Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.72),
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

enum _AgentCreateStep { gender, traits }

enum _AgentGender { male, female }

extension _AgentGenderApi on _AgentGender {
  String get apiValue {
    return switch (this) {
      _AgentGender.male => 'male',
      _AgentGender.female => 'female',
    };
  }
}

class _TraitDraft {
  const _TraitDraft({
    required this.name,
    required this.low,
    required this.high,
    required this.value,
    required this.description,
    required this.lowDescription,
    required this.highDescription,
  });

  final String name;
  final String low;
  final String high;
  final int value;
  final String description;
  final String lowDescription;
  final String highDescription;

  _TraitDraft copyWith({int? value}) {
    return _TraitDraft(
      name: name,
      low: low,
      high: high,
      value: value ?? this.value,
      description: description,
      lowDescription: lowDescription,
      highDescription: highDescription,
    );
  }
}

const _traitInfoTop = [196.0, 265.0, 333.0, 401.0, 469.0, 537.0, 605.0];

const _defaultTraits = [
  _TraitDraft(
    name: '活泼度',
    low: '内敛',
    high: '活泼',
    value: 100,
    description: '代表日常表达与相处状态',
    lowDescription: '偏内敛安静',
    highDescription: '外向热情、乐于主动互动',
  ),
  _TraitDraft(
    name: '理性度',
    low: '感性',
    high: '理性',
    value: 55,
    description: '代表遇事思考方式',
    lowDescription: '更侧重情绪感受',
    highDescription: '习惯客观冷静、逻辑优先',
  ),
  _TraitDraft(
    name: '感性度',
    low: '冷静',
    high: '感性',
    value: 100,
    description: '代表共情感知能力',
    lowDescription: '情绪克制沉稳',
    highDescription: '心思细腻，容易共情他人情绪',
  ),
  _TraitDraft(
    name: '计划度',
    low: '随性',
    high: '计划',
    value: 100,
    description: '代表生活处事习惯',
    lowDescription: '随性松弛，不爱拘束',
    highDescription: '做事有条理，偏爱提前规划',
  ),
  _TraitDraft(
    name: '随性度',
    low: '规矩',
    high: '随性',
    value: 100,
    description: '代表行事包容程度',
    lowDescription: '守规矩、偏爱稳定流程',
    highDescription: '不受条条框框束缚，灵活自在',
  ),
  _TraitDraft(
    name: '脑洞度',
    low: '务实',
    high: '脑洞',
    value: 100,
    description: '代表想象力与思维模式',
    lowDescription: '务实落地、看重现实',
    highDescription: '想象力丰富，浪漫富有奇思',
  ),
  _TraitDraft(
    name: '幽默度',
    low: '严肃',
    high: '幽默',
    value: 100,
    description: '代表相处趣味感',
    lowDescription: '稳重严肃，不爱玩笑',
    highDescription: '风趣轻松，擅长制造轻松氛围',
  ),
];
