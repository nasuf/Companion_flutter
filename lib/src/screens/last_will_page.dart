part of 'package:companion_flutter/main.dart';

class LastWillPage extends StatefulWidget {
  const LastWillPage({super.key, required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<LastWillPage> createState() => _LastWillPageState();
}

class _LastWillPageState extends State<LastWillPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  late Future<List<LastWill>> _wills;
  LastWill? _current;
  int _draftDays = 30;
  List<LastWillContact> _draftContacts = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _wills = _load();
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<List<LastWill>> _load() async {
    final agentId = widget.session.agentId;
    if (agentId == null || agentId.isEmpty) return const [];
    final items = await widget.api.listLastWills(
      agentId: agentId,
      workspaceId: widget.session.workspaceId,
    );
    if (mounted) {
      setState(() {
        _current = items.isEmpty ? null : items.first;
        _draftDays = _current?.inactivityDays ?? _draftDays;
        _draftContacts = _current?.contacts ?? _draftContacts;
      });
    }
    return items;
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _wills = future;
    });
    await future;
  }

  int get _days => _current?.inactivityDays ?? _draftDays;
  List<LastWillContact> get _contacts => _current?.contacts ?? _draftContacts;
  String get _content => _current?.content ?? '';
  bool get _isTiming =>
      _current?.isActive == true && _current?.hasContent == true;
  bool get _showBottomWriteButton =>
      _current == null || _current?.hasContent != true;
  bool get _canEditContacts => true;
  bool get _canEditDays => true;
  bool get _canConvertToDraft =>
      _current?.hasContent == true && _current?.status != 'draft';
  bool get _canStartFromEditor =>
      _current?.status != 'active' && _current?.status != 'triggered';
  String get _contentTrail {
    final status = _current?.status;
    if (status == 'draft') return '草稿';
    if (status == 'triggered') return '已触发';
    if (_isTiming) return '已计时';
    return '已保存';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F7),
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<List<LastWill>>(
          future: _wills,
          builder: (context, snapshot) {
            final loading = snapshot.connectionState == ConnectionState.waiting;
            final safeBottom = MediaQuery.paddingOf(context).bottom;
            return Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.72, -0.36),
                        radius: 0.92,
                        colors: [
                          const Color(0xFFE6E9E3).withValues(alpha: 0.86),
                          const Color(0xFFF8FAF8),
                        ],
                      ),
                    ),
                  ),
                ),
                CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    const SliverToBoxAdapter(child: _TopActions()),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        34,
                        24,
                        _showBottomWriteButton || _isTiming
                            ? 126 + safeBottom
                            : 104,
                      ),
                      sliver: SliverList.list(
                        children: [
                          _HeroCard(
                            animation: _glowController,
                            active: _isTiming,
                            days: _days,
                            contacts: _contacts.length,
                            onDaysTap: _canEditDays ? _openDaysSheet : null,
                            onContactsTap: _contacts.isNotEmpty
                                ? _openContactsDetailSheet
                                : _canEditContacts
                                ? _openContactsSheet
                                : null,
                          ),
                          if (_content.trim().isNotEmpty) ...[
                            const SizedBox(height: 18),
                            _LastWillContentItem(
                              id: _current?.id ?? 'draft',
                              canDelete: _current != null && !_busy,
                              onDelete: _deleteCurrentWill,
                              lead: '文',
                              title: '遗言内容',
                              body: _current?.preview ?? _content,
                              trail: _contentTrail,
                              onTap: _current == null ? null : _openEditor,
                            ),
                          ],
                          if (_contacts.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _InfoRow(
                              lead: '联',
                              title: '紧急联系人',
                              body: _contactSummary(_contacts),
                              trail: '${_contacts.length} 人',
                              onTap: _openContactsDetailSheet,
                            ),
                          ],
                          if (!_isTiming && loading)
                            const Center(child: CupertinoActivityIndicator()),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_showBottomWriteButton && !loading)
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: math.max(18, safeBottom + 10),
                    child: _BottomWriteButton(onTap: _openEditor, busy: _busy),
                  ),
                if (_isTiming && !loading)
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: math.max(18, safeBottom + 10),
                    child: _TimingFooter(
                      days: _days,
                      startedAt: _current?.startedAt,
                      animation: _glowController,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _contactSummary(List<LastWillContact> contacts) {
    return contacts
        .map((item) {
          final phone = item.phone == null ? '' : _maskPhone(item.phone!);
          final email = item.email == null ? '' : _maskEmail(item.email!);
          final channel = phone.isNotEmpty ? phone : email;
          return channel.isEmpty ? item.name : '${item.name} · $channel';
        })
        .join('；');
  }

  String _maskPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) return value;
    return '${digits.substring(0, 3)}****${digits.substring(digits.length - 4)}';
  }

  String _maskEmail(String value) {
    final at = value.indexOf('@');
    if (at <= 1) return value;
    return '${value.substring(0, 1)}***${value.substring(at)}';
  }

  Future<void> _openEditor() async {
    final result = await showModalBottomSheet<_LastWillEditResult>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      builder: (_) => _LastWillEditorSheet(
        initialContent: _content,
        canStart: _contacts.isNotEmpty,
        allowStart: _canStartFromEditor,
        canConvertToDraft: _canConvertToDraft,
        ensureContacts: _ensureContactsForTrigger,
        onDelete: _current?.hasContent == true ? _deleteCurrentWill : null,
      ),
    );
    if (result == null || !mounted) return;
    await _saveContent(
      result.content,
      start: result.startNow,
      convertToDraft: result.convertToDraft,
    );
  }

  Future<void> _saveContent(
    String content, {
    required bool start,
    bool convertToDraft = false,
  }) async {
    if (content.trim().isEmpty) {
      _toast('先写下一段遗言内容');
      return;
    }
    if (start && !await _ensureContactsForTrigger()) {
      return;
    }
    final agentId = widget.session.agentId;
    if (agentId == null || agentId.isEmpty) return;
    setState(() => _busy = true);
    try {
      final currentStatus = _current?.status;
      final status = convertToDraft
          ? 'draft'
          : start
          ? 'active'
          : currentStatus == 'active' ||
                currentStatus == 'triggered' ||
                currentStatus == 'paused'
          ? currentStatus!
          : 'draft';
      final saved = _current == null
          ? await widget.api.createLastWill(
              agentId: agentId,
              workspaceId: widget.session.workspaceId,
              content: content,
              inactivityDays: _days,
              contacts: _contacts,
              status: status,
            )
          : await widget.api.updateLastWill(
              _current!.id,
              content: content,
              inactivityDays: _days,
              contacts: _contacts,
              status: status,
            );
      setState(() {
        _current = saved;
        _draftDays = saved.inactivityDays;
        _draftContacts = saved.contacts;
      });
      await _refresh();
    } catch (error) {
      _toast(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _deleteCurrentWill() async {
    final current = _current;
    if (current == null || !current.hasContent || _busy) return false;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('删除遗言？'),
        content: const Text('只会删除遗言内容，失联天数和联系人会保留。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;
    setState(() => _busy = true);
    try {
      final saved = await widget.api.updateLastWill(
        current.id,
        content: '',
        status: 'cancelled',
      );
      setState(() {
        _current = saved;
        _draftDays = saved.inactivityDays;
        _draftContacts = saved.contacts;
      });
      await _refresh();
      return true;
    } catch (error) {
      _toast(error.toString());
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<LastWill?> _persistDraftSettings({
    int? inactivityDays,
    List<LastWillContact>? contacts,
  }) async {
    final agentId = widget.session.agentId;
    if (agentId == null || agentId.isEmpty) return null;
    final nextDays = inactivityDays ?? _days;
    final nextContacts = contacts ?? _contacts;
    if (_current == null && nextDays == 30 && nextContacts.isEmpty) {
      return null;
    }
    setState(() => _busy = true);
    try {
      final current = _current;
      final saved = current == null
          ? await widget.api.createLastWill(
              agentId: agentId,
              workspaceId: widget.session.workspaceId,
              content: '',
              inactivityDays: nextDays,
              contacts: nextContacts,
              status: 'draft',
            )
          : await widget.api.updateLastWill(
              current.id,
              inactivityDays: nextDays,
              contacts: nextContacts,
            );
      if (mounted) {
        setState(() {
          _current = saved;
          _draftDays = saved.inactivityDays;
          _draftContacts = saved.contacts;
        });
      }
      return saved;
    } catch (error) {
      _toast(error.toString());
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDaysSheet() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (_) => _DaysSheet(initial: _days),
    );
    if (selected == null || !mounted) return;
    setState(() => _draftDays = selected);
    await _persistDraftSettings(inactivityDays: selected);
  }

  Future<bool> _ensureContactsForTrigger() async {
    if (_contacts.isNotEmpty) return true;
    final saved = await _openContactsSheet();
    if (!mounted || saved == null) return false;
    if (_contacts.isEmpty) {
      _toast('先添加至少 1 位紧急联系人');
      return false;
    }
    return true;
  }

  Future<void> _openContactsDetailSheet() async {
    if (_contacts.isEmpty) {
      if (_canEditContacts) await _openContactsSheet();
      return;
    }
    final action = await showModalBottomSheet<_ContactDetailAction>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (_) =>
          _ContactsDetailSheet(contacts: _contacts, editable: _canEditContacts),
    );
    if (!mounted) return;
    if (action == _ContactDetailAction.edit) {
      await _openContactsSheet();
    }
  }

  Future<bool?> _openContactsSheet() async {
    final contacts = await showModalBottomSheet<List<LastWillContact>>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (_) => _ContactsSheet(initial: _contacts),
    );
    if (contacts == null || !mounted) return null;
    setState(() => _draftContacts = contacts);
    final saved = await _persistDraftSettings(contacts: contacts);
    return (saved?.contacts ?? contacts).isNotEmpty;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TopActions extends StatelessWidget {
  const _TopActions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Row(
        children: [
          _LegacyRoundIconButton(
            icon: CupertinoIcons.chevron_left,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

class _LegacyRoundIconButton extends StatelessWidget {
  const _LegacyRoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.86),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF27384B).withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Icon(icon, color: const Color(0xFF121A23), size: 28),
      ),
    );
  }
}

class _HeroBreathScope extends InheritedWidget {
  const _HeroBreathScope({required this.breath, required super.child});

  final double breath;

  static double of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_HeroBreathScope>()
            ?.breath ??
        0.5;
  }

  @override
  bool updateShouldNotify(covariant _HeroBreathScope oldWidget) {
    return oldWidget.breath != breath;
  }
}

class _LegacyHeroLight extends StatelessWidget {
  const _LegacyHeroLight();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _LegacyHeroLightPainter());
  }
}

class _LegacyHeroLightPainter extends CustomPainter {
  const _LegacyHeroLightPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final baseRect = Offset.zero & size;
    canvas.drawRect(
      baseRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.82),
            Colors.white.withValues(alpha: 0.58),
          ],
        ).createShader(baseRect),
    );

    void drawGlow({
      required Alignment center,
      required double radius,
      required List<Color> colors,
      List<double>? stops,
      double widthScale = 1,
      double heightScale = 1,
    }) {
      final offset = Offset(
        (center.x + 1) * size.width / 2,
        (center.y + 1) * size.height / 2,
      );
      final rect = Rect.fromCenter(
        center: offset,
        width: radius * widthScale,
        height: radius * heightScale,
      );
      canvas.drawOval(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: colors,
            stops: stops,
          ).createShader(rect)
          ..blendMode = BlendMode.srcOver,
      );
    }

    drawGlow(
      center: const Alignment(0.76, -0.76),
      radius: size.width * 0.56,
      widthScale: 1,
      heightScale: 0.88,
      colors: [
        const Color(0xFF151820).withValues(alpha: 0.18),
        const Color(0xFF151820).withValues(alpha: 0.05),
        const Color(0x00151820),
      ],
      stops: const [0, 0.66, 1],
    );
    drawGlow(
      center: const Alignment(-1.16, 0.84),
      radius: size.width * 0.56,
      widthScale: 1,
      heightScale: 0.84,
      colors: [
        const Color(0xFFCDB9FF).withValues(alpha: 0.10),
        const Color(0xFFCDB9FF).withValues(alpha: 0.04),
        const Color(0x00CDB9FF),
      ],
      stops: const [0, 0.72, 1],
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.animation,
    required this.active,
    required this.days,
    required this.contacts,
    required this.onDaysTap,
    required this.onContactsTap,
  });

  final Animation<double> animation;
  final bool active;
  final int days;
  final int contacts;
  final VoidCallback? onDaysTap;
  final VoidCallback? onContactsTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final breath = 0.5 + 0.5 * math.sin(animation.value * math.pi * 2);
        return CustomPaint(
          foregroundPainter: active
              ? _GlowBorderPainter(progress: animation.value)
              : null,
          child: _HeroBreathScope(breath: breath, child: child!),
        );
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        constraints: const BoxConstraints(minHeight: 224),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.70)),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.96),
              blurRadius: 1,
              offset: const Offset(0, -1),
            ),
            BoxShadow(
              color: const Color(0xFF20242A).withValues(alpha: 0.10),
              blurRadius: 42,
              offset: const Offset(0, 22),
            ),
            BoxShadow(
              color: const Color(0xFF7C3CFF).withValues(alpha: 0.08),
              blurRadius: 28,
              offset: const Offset(-14, 24),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            const Positioned.fill(child: _LegacyHeroLight()),
            Builder(
              builder: (context) {
                final breath = _HeroBreathScope.of(context);
                return Positioned(
                  right: -34 + breath * 6,
                  bottom: 16 + breath * 8,
                  child: Transform.rotate(
                    angle: 0.157 + breath * 0.035,
                    child: Transform.scale(
                      scale: 0.98 + breath * 0.035,
                      child: const IgnorePointer(
                        child: CustomPaint(
                          size: Size(112, 112),
                          painter: _LegacyOrbPainter(),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PRIVATE NOTE',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                      color: Color(0xFF1F252C),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Padding(
                    padding: EdgeInsets.only(right: 64),
                    child: Text(
                      '留一份遗书吧',
                      style: TextStyle(
                        fontSize: 30,
                        height: 1.12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                        color: Color(0xFF171B20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Padding(
                    padding: EdgeInsets.only(right: 74),
                    child: Text(
                      '既要生得光荣，也要死得伟大',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.52,
                        color: Color(0xFF747C82),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: 226,
                    child: Row(
                      children: [
                        Expanded(
                          child: _MetricTile(
                            value: '$days',
                            label: '失联天数',
                            onTap: onDaysTap,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MetricTile(
                            value: '$contacts',
                            label: '联系人',
                            onTap: onContactsTap,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.value, required this.label, this.onTap});

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.56),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.74)),
        ),
        alignment: Alignment.centerLeft,
        child: FittedBox(
          alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF171B20),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  height: 1.05,
                  color: Color(0xFF9AA0A4),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.lead,
    required this.title,
    required this.body,
    required this.trail,
    this.onTap,
  });

  final String lead;
  final String title;
  final String body;
  final String trail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: onTap == null ? 0.82 : 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 80),
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.76),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF314054).withValues(alpha: 0.045),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFDADCDD),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  lead,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF151A1F),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.28,
                        color: Color(0xFF777F84),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 56),
                child: Text(
                  trail,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF9AA19F),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
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

class _LastWillContentItem extends StatelessWidget {
  const _LastWillContentItem({
    required this.id,
    required this.canDelete,
    required this.onDelete,
    required this.lead,
    required this.title,
    required this.body,
    required this.trail,
    this.onTap,
  });

  final String id;
  final bool canDelete;
  final Future<bool> Function() onDelete;
  final String lead;
  final String title;
  final String body;
  final String trail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = _InfoRow(
      lead: lead,
      title: title,
      body: body,
      trail: trail,
      onTap: onTap,
    );
    if (!canDelete) return row;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Dismissible(
        key: ValueKey('last-will-content-$id'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => onDelete(),
        background: const _LastWillDeleteSwipeBackground(),
        child: row,
      ),
    );
  }
}

class _LastWillDeleteSwipeBackground extends StatelessWidget {
  const _LastWillDeleteSwipeBackground();
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE95656),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE95656).withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: EdgeInsets.only(right: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.delete_solid, color: Colors.white, size: 24),
              SizedBox(height: 4),
              Text(
                '删除',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomWriteButton extends StatelessWidget {
  const _BottomWriteButton({required this.onTap, required this.busy});

  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: busy ? null : onTap,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: const Color(0xFF121A23),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF121A23).withValues(alpha: 0.16),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: busy
            ? const CupertinoActivityIndicator(color: Colors.white)
            : const Text(
                '留遗言',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );
  }
}

class _TimingFooter extends StatelessWidget {
  const _TimingFooter({
    required this.days,
    required this.animation,
    this.startedAt,
  });

  final int days;
  final Animation<double> animation;
  final DateTime? startedAt;

  @override
  Widget build(BuildContext context) {
    final date = startedAt == null
        ? '今天'
        : '${startedAt!.month}月${startedAt!.day}日';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF121A23),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: animation,
            child: const Icon(
              CupertinoIcons.timer,
              color: Colors.white,
              size: 22,
            ),
            builder: (context, child) {
              return Transform.rotate(
                angle: animation.value * math.pi * 2,
                child: child,
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$date起，连续$days日未登录，我们将替你把未曾说出口的心意，代为转告挂念之人。',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DaysSheet extends StatefulWidget {
  const _DaysSheet({required this.initial});

  final int initial;

  @override
  State<_DaysSheet> createState() => _DaysSheetState();
}

class _DaysSheetState extends State<_DaysSheet> {
  static const _days = [5, 7, 10, 30, 60];
  late final FixedExtentScrollController _controller;
  late int _selected;

  @override
  void initState() {
    super.initState();
    final index = _initialIndex(widget.initial);
    _selected = _days[index];
    _controller = FixedExtentScrollController(initialItem: index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _initialIndex(int value) {
    final exact = _days.indexOf(value);
    if (exact >= 0) return exact;
    var best = 0;
    for (var i = 1; i < _days.length; i += 1) {
      if ((_days[i] - value).abs() < (_days[best] - value).abs()) {
        best = i;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.48,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.page,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: DefaultTextStyle(
          style: const TextStyle(
            color: AppColors.text,
            decoration: TextDecoration.none,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _LastWillSheetGrabber(),
              const Text(
                '请选择连续未登录天数',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '系统将按约定，把你未说出口的话，悄悄送达',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 206,
                child: Stack(
                  children: [
                    const Center(child: _LastWillWheelGlassSelection()),
                    CupertinoPicker(
                      scrollController: _controller,
                      itemExtent: 58,
                      diameterRatio: 1.35,
                      useMagnifier: true,
                      magnification: 1.03,
                      squeeze: 1.10,
                      selectionOverlay: const SizedBox.shrink(),
                      onSelectedItemChanged: (index) {
                        setState(() => _selected = _days[index]);
                      },
                      children: [
                        for (final day in _days)
                          _LastWillDayWheelItem(
                            day: day,
                            selected: day == _selected,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).pop(_selected),
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFF121A23),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF121A23).withValues(alpha: 0.12),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '确认 $_selected 天',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      decoration: TextDecoration.none,
                    ),
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

class _LastWillWheelGlassSelection extends StatelessWidget {
  const _LastWillWheelGlassSelection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 34),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2B3440).withValues(alpha: 0.08),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.55),
                  blurRadius: 1,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LastWillDayWheelItem extends StatelessWidget {
  const _LastWillDayWheelItem({required this.day, required this.selected});

  final int day;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? const Color(0xFF121A23)
        : const Color(0xFF9DA4AA).withValues(alpha: 0.48);
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$day',
            style: TextStyle(
              color: color,
              fontSize: selected ? 34 : 25,
              height: 1,
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(width: 5),
          Padding(
            padding: EdgeInsets.only(bottom: selected ? 3 : 1),
            child: Text(
              '天',
              style: TextStyle(
                color: color,
                fontSize: selected ? 18 : 14,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LastWillSheetGrabber extends StatelessWidget {
  const _LastWillSheetGrabber();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 12),
      child: Center(
        child: Container(
          width: 42,
          height: 5,
          decoration: BoxDecoration(
            color: const Color(0xFFD8DCE0),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _ContactsSheet extends StatefulWidget {
  const _ContactsSheet({required this.initial});

  final List<LastWillContact> initial;

  @override
  State<_ContactsSheet> createState() => _ContactsSheetState();
}

class _ContactsSheetState extends State<_ContactsSheet> {
  late final List<_ContactDraft> _drafts = [
    for (final item in widget.initial) _ContactDraft.fromContact(item),
    if (widget.initial.isEmpty) _ContactDraft(),
  ];

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.86,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 22,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _LastWillSheetGrabber(),
            const Text(
              '紧急联系人',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              '最多 3 位。邮箱或电话至少填写一个。',
              style: TextStyle(color: AppColors.muted, fontSize: 14),
            ),
            const SizedBox(height: 18),
            for (var i = 0; i < _drafts.length; i += 1) ...[
              _ContactEditor(
                index: i,
                draft: _drafts[i],
                onRemove: _drafts.length == 1
                    ? null
                    : () => setState(() {
                        final removed = _drafts.removeAt(i);
                        removed.dispose();
                      }),
              ),
              const SizedBox(height: 14),
            ],
            if (_drafts.length < 3)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => setState(() => _drafts.add(_ContactDraft())),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '添加联系人',
                    style: TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 18),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _save,
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFF121A23),
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: const Text(
                  '保存联系人',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final contacts = <LastWillContact>[];
    for (final draft in _drafts) {
      final contact = draft.toContact();
      if (contact == null) continue;
      contacts.add(contact);
    }
    Navigator.of(context).pop(contacts.take(3).toList());
  }
}

enum _ContactDetailAction { edit }

class _ContactsDetailSheet extends StatelessWidget {
  const _ContactsDetailSheet({required this.contacts, required this.editable});

  final List<LastWillContact> contacts;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.76,
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.paddingOf(context).bottom + 18,
      ),
      decoration: const BoxDecoration(
        color: AppColors.page,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: DefaultTextStyle(
          style: const TextStyle(
            color: AppColors.text,
            decoration: TextDecoration.none,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _LastWillSheetGrabber(),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '紧急联系人',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  Text(
                    '${contacts.length} 人',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: contacts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _ContactDetailCard(
                      index: index,
                      contact: contacts[index],
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(
                  context,
                ).pop(editable ? _ContactDetailAction.edit : null),
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    color: editable ? const Color(0xFF121A23) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: editable
                        ? null
                        : Border.all(color: const Color(0xFFE0E4EA)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    editable ? '编辑联系人' : '完成',
                    style: TextStyle(
                      color: editable ? Colors.white : AppColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      decoration: TextDecoration.none,
                    ),
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

class _ContactDetailCard extends StatelessWidget {
  const _ContactDetailCard({required this.index, required this.contact});

  final int index;
  final LastWillContact contact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF314054).withValues(alpha: 0.05),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFDADCDD),
              borderRadius: BorderRadius.circular(17),
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 21,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 10),
                _ContactDetailLine(
                  label: '邮箱',
                  value: contact.email?.trim().isNotEmpty == true
                      ? contact.email!.trim()
                      : '未填写',
                ),
                const SizedBox(height: 6),
                _ContactDetailLine(
                  label: '电话',
                  value: contact.phone?.trim().isNotEmpty == true
                      ? contact.phone!.trim()
                      : '未填写',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactDetailLine extends StatelessWidget {
  const _ContactDetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 42,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9AA0A4),
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF60686E),
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _ContactEditor extends StatelessWidget {
  const _ContactEditor({
    required this.index,
    required this.draft,
    required this.onRemove,
  });

  final int index;
  final _ContactDraft draft;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E9EF)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '联系人 ${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              if (onRemove != null)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: onRemove,
                  child: const Icon(CupertinoIcons.xmark_circle_fill, size: 22),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _SheetField(controller: draft.name, placeholder: '名字'),
          const SizedBox(height: 10),
          _SheetField(controller: draft.email, placeholder: '邮箱'),
          const SizedBox(height: 10),
          _SheetField(controller: draft.phone, placeholder: '电话'),
        ],
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  const _SheetField({required this.controller, required this.placeholder});

  final TextEditingController controller;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E9EF)),
      ),
    );
  }
}

class _ContactDraft {
  _ContactDraft()
    : name = TextEditingController(),
      email = TextEditingController(),
      phone = TextEditingController();

  _ContactDraft.fromContact(LastWillContact contact)
    : name = TextEditingController(text: contact.name),
      email = TextEditingController(text: contact.email ?? ''),
      phone = TextEditingController(text: contact.phone ?? '');

  final TextEditingController name;
  final TextEditingController email;
  final TextEditingController phone;

  LastWillContact? toContact() {
    final n = name.text.trim();
    final e = email.text.trim();
    final p = phone.text.trim();
    if (n.isEmpty && e.isEmpty && p.isEmpty) return null;
    if (n.isEmpty || (e.isEmpty && p.isEmpty)) return null;
    return LastWillContact(
      name: n,
      email: e.isEmpty ? null : e,
      phone: p.isEmpty ? null : p,
    );
  }

  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
  }
}

class _LastWillEditResult {
  const _LastWillEditResult({
    required this.content,
    required this.startNow,
    required this.convertToDraft,
  });

  final String content;
  final bool startNow;
  final bool convertToDraft;
}

class _LastWillEditorSheet extends StatefulWidget {
  const _LastWillEditorSheet({
    required this.initialContent,
    required this.canStart,
    required this.allowStart,
    required this.canConvertToDraft,
    required this.ensureContacts,
    this.onDelete,
  });

  final String initialContent;
  final bool canStart;
  final bool allowStart;
  final bool canConvertToDraft;
  final Future<bool> Function() ensureContacts;
  final Future<bool> Function()? onDelete;

  @override
  State<_LastWillEditorSheet> createState() => _LastWillEditorSheetState();
}

class _LastWillEditorSheetState extends State<_LastWillEditorSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialContent,
  );
  late bool _hasContacts = widget.canStart;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final availableHeight = MediaQuery.sizeOf(context).height - bottomInset;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: availableHeight,
          color: const Color(0xFFF7F9F7),
          child: SafeArea(
            top: true,
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                  child: Row(
                    children: [
                      _LegacyRoundIconButton(
                        icon: CupertinoIcons.xmark,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const Expanded(
                        child: Text(
                          '留遗言',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (widget.onDelete == null)
                        const SizedBox(width: 58)
                      else
                        _LastWillEditorDeleteButton(onTap: _delete),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF314054,
                            ).withValues(alpha: 0.08),
                            blurRadius: 30,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: CupertinoTextField(
                        controller: _controller,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        placeholder: '把想留下的话写在这里。',
                        padding: EdgeInsets.zero,
                        style: const TextStyle(fontSize: 18, height: 1.55),
                        decoration: const BoxDecoration(),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    22,
                    8,
                    22,
                    math.max(24, safeBottom + 14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => _pop(
                            startNow: false,
                            convertToDraft: widget.canConvertToDraft,
                          ),
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFE0E4EA),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              widget.canConvertToDraft ? '转草稿' : '存草稿',
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _startNow,
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                              color: const Color(0xFF121A23),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              widget.allowStart
                                  ? (_hasContacts ? '开始触发' : '添加联系人')
                                  : '更新',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
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
      ),
    );
  }

  void _pop({required bool startNow, bool convertToDraft = false}) {
    Navigator.of(context).pop(
      _LastWillEditResult(
        content: _controller.text,
        startNow: startNow,
        convertToDraft: convertToDraft,
      ),
    );
  }

  Future<void> _startNow() async {
    if (!widget.allowStart) {
      _pop(startNow: false);
      return;
    }
    if (!_hasContacts) {
      final ready = await widget.ensureContacts();
      if (!mounted || !ready) return;
      setState(() => _hasContacts = true);
      return;
    }
    _pop(startNow: true);
  }

  Future<void> _delete() async {
    final deleted = await widget.onDelete?.call() ?? false;
    if (!mounted || !deleted) return;
    Navigator.of(context).maybePop();
  }
}

class _LastWillEditorDeleteButton extends StatelessWidget {
  const _LastWillEditorDeleteButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: const Color(0xFFFFEEF0),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE95656).withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: const Icon(
          CupertinoIcons.delete,
          color: Color(0xFFE95656),
          size: 24,
        ),
      ),
    );
  }
}

class _GlowBorderPainter extends CustomPainter {
  const _GlowBorderPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.8),
      const Radius.circular(32),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().iterator;
    if (!metrics.moveNext()) return;
    final metric = metrics.current;
    final length = metric.length;
    final head = (length * progress) % length;
    const segmentCount = 72;
    final tailLength = length * 0.105;

    Path tailSegment(double start, double end) {
      final normalizedStart = (start + length) % length;
      final normalizedEnd = (end + length) % length;
      final segment = Path();
      if (normalizedStart <= normalizedEnd) {
        segment.addPath(
          metric.extractPath(normalizedStart, normalizedEnd),
          Offset.zero,
        );
      } else {
        segment
          ..addPath(metric.extractPath(normalizedStart, length), Offset.zero)
          ..addPath(metric.extractPath(0, normalizedEnd), Offset.zero);
      }
      return segment;
    }

    for (var i = segmentCount - 1; i >= 0; i--) {
      final from = head - tailLength * ((i + 1.46) / segmentCount);
      final to = head - tailLength * (i / segmentCount);
      final strength = math.pow(1 - i / segmentCount, 2.35).toDouble();
      final segment = tailSegment(from, to);
      final coreWidth = 0.18 + strength * 9.9;
      canvas.drawPath(
        segment,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.06 + strength * 0.56)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8 + strength * 16.2
          ..strokeCap = StrokeCap.butt
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawPath(
        segment,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.05 + strength * 0.88)
          ..style = PaintingStyle.stroke
          ..strokeWidth = coreWidth
          ..strokeCap = StrokeCap.butt,
      );
    }

    final tangent = metric.getTangentForOffset(head);
    if (tangent == null) return;
    canvas.drawCircle(
      tangent.position,
      10.2,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.88)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawCircle(tangent.position, 4.4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _GlowBorderPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _LegacyOrbPainter extends CustomPainter {
  const _LegacyOrbPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bodyRect = Rect.fromLTWH(
      size.width * 0.08,
      size.height * 0.08,
      size.width * 0.84,
      size.height * 0.84,
    );
    final body = RRect.fromRectAndRadius(
      bodyRect,
      Radius.circular(size.width * 0.32),
    );
    final shadow = Paint()
      ..color = const Color(0xFF151820).withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF151820), Color(0xFF111318)],
        stops: [0, 1],
      ).createShader(bodyRect);
    canvas.drawRRect(body.shift(Offset(0, size.height * 0.16)), shadow);
    canvas.drawRRect(body, bodyPaint);
    canvas.drawCircle(
      Offset(size.width * 0.35, size.height * 0.30),
      size.width * 0.22,
      Paint()
        ..shader =
            const RadialGradient(
              colors: [Color(0xDBFFFFFF), Color(0x29FFFFFF), Color(0x00FFFFFF)],
              stops: [0, 0.58, 1],
            ).createShader(
              Rect.fromCircle(
                center: Offset(size.width * 0.35, size.height * 0.30),
                radius: size.width * 0.40,
              ),
            ),
    );
    final inset = bodyRect.deflate(size.width * 0.13);
    final insetBody = RRect.fromRectAndRadius(
      inset,
      Radius.circular(size.width * 0.24),
    );
    canvas.drawRRect(
      insetBody,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      insetBody,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
