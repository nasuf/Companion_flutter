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
  int _pendingDays = 30;
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
    final items = await widget.api.listLastWills();
    if (mounted) {
      setState(() {
        _current = items.isEmpty ? null : items.first;
        _pendingDays = _current?.inactivityDays ?? _pendingDays;
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

  int? get _savedDays => _current?.inactivityDays;
  List<LastWillContact> get _contacts => _current?.contacts ?? _draftContacts;
  String get _content => _current?.content ?? '';
  bool get _isTiming =>
      _current?.isActive == true && _current?.hasContent == true;
  bool get _canConvertToDraft =>
      _current?.hasContent == true && _current?.status != 'draft';
  bool get _canStartFromEditor =>
      _current?.status != 'active' && _current?.status != 'triggered';

  /// Trailing label of the 遗言 card: the status once the countdown runs, the
  /// edit affordance otherwise.
  String get _contentTrail {
    final status = _current?.status;
    if (status == 'triggered') return '已触发';
    if (_isTiming) return '已计时';
    if (status == 'draft' && _current?.hasContent == true) return '草稿';
    return '编辑';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _LegacyBackground()),
          SafeArea(
            bottom: false,
            child: FutureBuilder<List<LastWill>>(
              future: _wills,
              builder: (context, snapshot) {
                final w = _W2b.of(context);
                final loading =
                    snapshot.connectionState == ConnectionState.waiting;
                final safeBottom = MediaQuery.paddingOf(context).bottom;
                return Column(
                  children: [
                    _LegacyHeader(
                      title: 'Hi，牵挂之人',
                      onBack: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          _legacyGutter,
                          // 头部收窄到 36pt 后补的呼吸间距（原来靠 84pt 高的头部
                          // 自带间距）。
                          20,
                          _legacyGutter,
                          math.max(24, safeBottom + 12),
                        ),
                        children: [
                          // Without this a failed load is indistinguishable
                          // from "nothing saved yet", and the user would write
                          // a second will over the one already on the server.
                          if (snapshot.hasError) ...[
                            const _LegacyLoadErrorNotice(),
                            const SizedBox(height: 16),
                          ],
                          _LegacyCountdownCard(
                            animation: _glowController,
                            glowing: _isTiming,
                            days: _pendingDays,
                            onDaysChanged: (value) {
                              setState(() => _pendingDays = value);
                            },
                            onSettled: _autoConfirmDays,
                          ),
                          const SizedBox(height: 24),
                          _LegacyContactsCard(
                            contacts: _contacts,
                            onManage: _openContactsManager,
                            onSlotTap: _openContactSlot,
                          ),
                          const SizedBox(height: 24),
                          _LegacyWillCard(
                            content: _content,
                            trail: _contentTrail,
                            editedAt: _current?.updatedAt,
                            onEdit: _busy ? null : _openEditor,
                          ),
                          if (_isTiming) ...[
                            const SizedBox(height: 32),
                            _LegacyGuardBanner(
                              days: _savedDays ?? _pendingDays,
                              startedAt: _current?.startedAt,
                            ),
                          ],
                          if (loading) ...[
                            const SizedBox(height: 24),
                            // 直接铺在亮底页面上（不在卡片内），用 w.ink，
                            // 否则白色指示器在亮底上几乎看不见。
                            Center(
                              child: CupertinoActivityIndicator(color: w.ink),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Fires once the ruler comes to rest on a whole day — no more explicit
  /// "确认" button or dialog; scrolling to a value and stopping there IS the
  /// confirmation now.
  Future<void> _autoConfirmDays(int days) async {
    // `days == _savedDays` covers the ruler catching up to an already-saved
    // value — e.g. the animated hop from the default 30 to a loaded record's
    // real day count — which is UI reflecting existing state, not a change to
    // persist. `_busy` avoids overlapping saves if another one is in flight.
    if (_busy || days == _savedDays) return;
    // Still `force: true` — a user who explicitly scrolls to (or back to) 30
    // on a brand-new record means it, the same as the old confirm button did
    // regardless of which day was showing.
    await _persistDraftSettings(inactivityDays: days, force: true);
  }

  Future<void> _openEditor() async {
    final result = await Navigator.of(context).push<_LastWillEditResult>(
      PageRouteBuilder<_LastWillEditResult>(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, __, ___) => _LastWillEditorPage(
          initialContent: _content,
          hasContacts: _contacts.isNotEmpty,
          allowStart: _canStartFromEditor,
          canConvertToDraft: _canConvertToDraft,
          ensureContacts: _ensureContactsForTrigger,
          onDelete: _current?.hasContent == true ? _deleteCurrentWill : null,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          );
        },
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
              content: content,
              inactivityDays: _savedDays ?? _pendingDays,
              contacts: _contacts,
              status: status,
            )
          : await widget.api.updateLastWill(
              _current!.id,
              content: content,
              contacts: _contacts,
              status: status,
            );
      setState(() {
        _current = saved;
        _pendingDays = saved.inactivityDays;
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
    // System dialog, not the module's custom blurred sheet — matches how
    // capsule confirms its own deletes (_confirmDeleteCapsule) and how
    // _LegacyContactSheet._remove now confirms contact deletion.
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
        _pendingDays = saved.inactivityDays;
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

  /// [inactivityDays] is only sent when the caller changed it — a contacts-only
  /// edit must not silently commit a day count the user has not confirmed yet.
  Future<LastWill?> _persistDraftSettings({
    int? inactivityDays,
    List<LastWillContact>? contacts,
    bool force = false,
  }) async {
    final current = _current;
    final nextDays = inactivityDays ?? current?.inactivityDays ?? _pendingDays;
    final nextContacts = contacts ?? _contacts;
    if (!force && current == null && nextDays == 30 && nextContacts.isEmpty) {
      return null;
    }
    setState(() => _busy = true);
    try {
      final saved = current == null
          ? await widget.api.createLastWill(
              content: '',
              inactivityDays: nextDays,
              contacts: nextContacts,
              status: 'draft',
            )
          : await widget.api.updateLastWill(
              current.id,
              inactivityDays: inactivityDays,
              contacts: nextContacts,
            );
      if (mounted) {
        setState(() {
          _current = saved;
          _pendingDays = saved.inactivityDays;
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

  Future<bool> _ensureContactsForTrigger() async {
    if (_contacts.isNotEmpty) return true;
    await _openContactSlot(_contacts.length);
    if (!mounted) return false;
    if (_contacts.isEmpty) {
      _toast('先添加至少 1 位紧急联系人');
      return false;
    }
    return true;
  }

  Future<void> _openContactsManager() async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute(
        builder: (_) => _LegacyContactsManagePage(
          contacts: _contacts,
          onSave: _saveContacts,
        ),
      ),
    );
  }

  /// Opens the add / edit sheet for a slot on the home card.
  Future<void> _openContactSlot(int index) async {
    final contacts = _contacts;
    final existing = index < contacts.length ? contacts[index] : null;
    if (existing == null && contacts.length >= _legacyMaxContacts) {
      _toast('最多添加 $_legacyMaxContacts 位紧急联系人');
      return;
    }
    final result = await _showLegacyContactSheet(
      context,
      // A tap on the third bubble while only one contact exists still adds the
      // second one, so label the sheet by the slot it will occupy.
      index: existing == null ? contacts.length : index,
      initial: existing,
    );
    if (result == null || !mounted) return;
    final next = [...contacts];
    if (result.deleted) {
      if (existing != null) next.removeAt(index);
    } else if (result.contact != null) {
      if (existing == null) {
        next.add(result.contact!);
      } else {
        next[index] = result.contact!;
      }
    }
    await _saveContacts(next);
  }

  /// Returns the list that ended up in effect, so the manage page never shows a
  /// contact the server refused.
  Future<List<LastWillContact>> _saveContacts(
    List<LastWillContact> contacts,
  ) async {
    final next = contacts.take(_legacyMaxContacts).toList();
    final previous = _contacts;
    setState(() => _draftContacts = next);
    final saved = await _persistDraftSettings(contacts: next);
    if (saved == null && _current != null) {
      if (mounted) setState(() => _draftContacts = previous);
      return previous;
    }
    return saved?.contacts ?? next;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// 失联倒计时 card: big day readout, scrubbable day ruler and preset chips.
/// The day count auto-confirms once the ruler settles (see
/// _LegacyDayRulerState._onNotification) — there is no separate confirm step.
class _LegacyCountdownCard extends StatelessWidget {
  const _LegacyCountdownCard({
    required this.animation,
    required this.glowing,
    required this.days,
    required this.onDaysChanged,
    required this.onSettled,
  });

  final Animation<double> animation;
  final bool glowing;
  final int days;
  final ValueChanged<int> onDaysChanged;
  final ValueChanged<int> onSettled;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.of(context);
    final card = _LegacyCard(
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            '失联倒计时',
            style: TextStyle(
              color: w.ink,
              fontSize: 16,
              height: 19 / 16,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$days',
            style: TextStyle(
              color: w.ink,
              fontSize: 40,
              height: 48 / 40,
              fontWeight: FontWeight.w400,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 8),
          _LegacyDayRuler(
            value: days,
            onChanged: onDaysChanged,
            onSettled: onSettled,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final preset in _legacyDayPresets)
                  _LegacyChip(
                    label: '$preset天',
                    selected: preset == days,
                    onTap: () => onDaysChanged(preset),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 13),
        ],
      ),
    );
    if (!glowing) return card;
    // Isolates the glow's per-frame repaint to its own compositor layer, so
    // the animation (now cheap — see _GlowBorderPainter) never forces the
    // surrounding list to repaint.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: animation,
        child: card,
        builder: (context, child) {
          return CustomPaint(
            foregroundPainter: _GlowBorderPainter(
              progress: animation.value,
              color: Colors.white,
            ),
            child: child,
          );
        },
      ),
    );
  }
}

/// Horizontal day ruler. One tick every 32px; the tick under the marker is the
/// selection, and emphasis falls off continuously to either side of it.
class _LegacyDayRuler extends StatefulWidget {
  const _LegacyDayRuler({
    required this.value,
    required this.onChanged,
    required this.onSettled,
  });

  final int value;
  final ValueChanged<int> onChanged;

  /// Fired once the ruler comes to a full stop (whether from a drag/fling or
  /// the animated hop a preset chip triggers) with whatever day it settled
  /// on — the day count auto-confirms here instead of behind a button.
  final ValueChanged<int> onSettled;

  @override
  State<_LegacyDayRuler> createState() => _LegacyDayRulerState();
}

class _LegacyDayRulerState extends State<_LegacyDayRuler> {
  static const _count = _legacyMaxDays - _legacyMinDays + 1;

  late final ScrollController _controller;
  late int _centre;

  @override
  void initState() {
    super.initState();
    _centre = _clampDay(widget.value);
    _controller = ScrollController(initialScrollOffset: _offsetFor(_centre));
  }

  @override
  void didUpdateWidget(covariant _LegacyDayRuler oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A scrub reports through onChanged and comes straight back here, so the
    // guard below is what stops it from animating against the finger: _centre is
    // already the reported day, and only an outside change (a preset chip) can
    // disagree with it.
    final target = _clampDay(widget.value);
    if (target == _centre) return;
    // A rebuild of this widget is already in flight, so no setState is needed.
    _centre = target;
    // Starting the scroll here would dispatch ScrollStartNotification while the
    // tree is still building, and reporting from that notification would call
    // setState on the page mid-build. Hand it to the next frame instead.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      if (_clampDay(widget.value) != _centre) return;
      _controller.animateTo(
        _offsetFor(_centre),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _clampDay(int value) => value.clamp(_legacyMinDays, _legacyMaxDays);

  double _offsetFor(int day) => (day - _legacyMinDays) * _legacyRulerPitch;

  double get _offset =>
      _controller.hasClients ? _controller.offset : _offsetFor(_centre);

  /// Reports while the finger is still down so the big readout tracks the ruler.
  bool _onNotification(ScrollNotification notification) {
    if (!_controller.hasClients) return false;
    final index = (_controller.offset / _legacyRulerPitch).round().clamp(
      0,
      _count - 1,
    );
    final day = _legacyMinDays + index;
    if (day != _centre) {
      // One light click per day crossed — same feel as a native picker,
      // whether the day changed from a drag or the animated hop a preset
      // chip triggers.
      HapticFeedback.selectionClick();
      setState(() => _centre = day);
      widget.onChanged(day);
    }
    // Fires once the ballistic simulation (or the preset chip's animateTo)
    // has fully come to rest, i.e. always on a whole tick — the day count
    // auto-confirms right here instead of waiting on a button tap.
    if (notification is ScrollEndNotification) {
      widget.onSettled(day);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _legacyRulerHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = math.max(
            0.0,
            constraints.maxWidth / 2 - _legacyRulerPitch / 2,
          );
          return Stack(
            children: [
              Positioned.fill(
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onNotification,
                  child: ListView.builder(
                    controller: _controller,
                    scrollDirection: Axis.horizontal,
                    physics: const _LegacyRulerPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: side),
                    itemExtent: _legacyRulerPitch,
                    itemCount: _count,
                    itemBuilder: (context, index) {
                      return AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) {
                          final ticksFromCentre =
                              (index * _legacyRulerPitch - _offset) /
                              _legacyRulerPitch;
                          return _LegacyDayTick(
                            day: _legacyMinDays + index,
                            emphasis: _legacyRulerEmphasis(ticksFromCentre),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: constraints.maxWidth / 2 - _legacyRulerMarkerSize / 2,
                child: const IgnorePointer(child: _LegacyRulerMarker()),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Lands the ruler on whole ticks, modelled on [FixedExtentScrollPhysics].
///
/// Correcting after a `ScrollEndNotification` with `animateTo` leaves the marker
/// a fraction of a tick off whenever that correction is interrupted; making the
/// ballistic simulation itself stop on a multiple cannot drift.
class _LegacyRulerPhysics extends ScrollPhysics {
  const _LegacyRulerPhysics({super.parent});

  @override
  _LegacyRulerPhysics applyTo(ScrollPhysics? ancestor) {
    return _LegacyRulerPhysics(parent: buildParent(ancestor));
  }

  double _settleFor(double offset, ScrollMetrics metrics) {
    final clamped = offset.clamp(
      metrics.minScrollExtent,
      metrics.maxScrollExtent,
    );
    return (clamped / _legacyRulerPitch).round() * _legacyRulerPitch;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics metrics,
    double velocity,
  ) {
    // Out of range and not heading back in: let the parent spring to the edge.
    if ((velocity <= 0 && metrics.pixels <= metrics.minScrollExtent) ||
        (velocity >= 0 && metrics.pixels >= metrics.maxScrollExtent)) {
      return super.createBallisticSimulation(metrics, velocity);
    }
    final natural = super.createBallisticSimulation(metrics, velocity);
    final naturalEnd = natural?.x(double.infinity) ?? metrics.pixels;
    if (natural != null &&
        (naturalEnd == metrics.minScrollExtent ||
            naturalEnd == metrics.maxScrollExtent)) {
      return super.createBallisticSimulation(metrics, velocity);
    }

    final settle = _settleFor(naturalEnd, metrics);
    final tolerance = toleranceFor(metrics);
    if (velocity.abs() < tolerance.velocity &&
        (settle - metrics.pixels).abs() < tolerance.distance) {
      return null;
    }
    if (settle == _settleFor(metrics.pixels, metrics)) {
      return SpringSimulation(
        spring,
        metrics.pixels,
        settle,
        velocity,
        tolerance: tolerance,
      );
    }
    return FrictionSimulation.through(
      metrics.pixels,
      settle,
      velocity,
      tolerance.velocity * velocity.sign,
    );
  }
}

class _LegacyDayTick extends StatelessWidget {
  const _LegacyDayTick({required this.day, required this.emphasis});

  final int day;

  /// 1 directly under the marker, easing to 0 by [_legacyRulerEmphasisSpan].
  final double emphasis;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.of(context);
    // Colour is the only thing emphasis drives now — the tick height and label
    // size used to grow toward the marker too, which read as jitter while
    // scrolling rather than a clean highlight.
    final color = Color.lerp(w.inkFaint, w.ink, emphasis)!;
    return Column(
      children: [
        const SizedBox(height: _legacyRulerMarkerSize + _legacyRulerMarkerGap),
        SizedBox(
          height: 12,
          child: Center(child: Container(width: 2, height: 8, color: color)),
        ),
        SizedBox(
          height: 16,
          child: Center(
            child: Text(
              '$day',
              key: Key('legacy-day-label-$day'),
              style: TextStyle(
                color: color,
                fontSize: 13,
                height: 1,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LegacyRulerMarker extends StatelessWidget {
  const _LegacyRulerMarker();

  @override
  Widget build(BuildContext context) {
    final w = _W2b.of(context);
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.fromBorderSide(BorderSide(color: w.ink)),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: w.ink, shape: BoxShape.circle),
      ),
    );
  }
}

/// 紧急联系人 card: three 48px slots, filled or "点击添加".
class _LegacyContactsCard extends StatelessWidget {
  const _LegacyContactsCard({
    required this.contacts,
    required this.onManage,
    required this.onSlotTap,
  });

  final List<LastWillContact> contacts;
  final VoidCallback onManage;
  final ValueChanged<int> onSlotTap;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.of(context);
    return _LegacyCard(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              _legacyGutter,
              16,
              _legacyGutter,
              24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '紧急联系人',
                  style: TextStyle(
                    color: w.ink,
                    fontSize: 16,
                    height: 19 / 16,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 19),
                Row(
                  children: [
                    for (var index = 0; index < _legacyMaxContacts; index += 1)
                      Padding(
                        padding: EdgeInsets.only(left: index == 0 ? 0 : 16),
                        child: _LegacyContactSlot(
                          contact: index < contacts.length
                              ? contacts[index]
                              : null,
                          onTap: () => onSlotTap(index),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            right: _legacyGutter,
            top: 18,
            child: _LegacyCardAction(label: '管理', onTap: onManage),
          ),
        ],
      ),
    );
  }
}

class _LegacyContactSlot extends StatelessWidget {
  const _LegacyContactSlot({required this.contact, required this.onTap});

  final LastWillContact? contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.of(context);
    final contact = this.contact;
    final label = contact == null
        ? '点击添加'
        : (contact.name.trim().isEmpty ? '未命名' : contact.name.trim());
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: SizedBox(
        width: 48,
        child: Column(
          children: [
            _LegacyContactAvatar(filled: contact != null),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: w.ink,
                fontSize: 12,
                height: 14 / 12,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 遗言 card: headline is the first line of the note, body is the preview panel.
class _LegacyWillCard extends StatelessWidget {
  const _LegacyWillCard({
    required this.content,
    required this.trail,
    required this.editedAt,
    required this.onEdit,
  });

  final String content;
  final String trail;
  final DateTime? editedAt;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.of(context);
    final body = content.trim();
    final empty = body.isEmpty;
    final headline = empty ? _legacyWillEmptyHeadline : _legacyWillHeadline;
    return _LegacyCard(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              _legacyGutter,
              16,
              _legacyGutter,
              18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 64),
                  child: Text(
                    headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: w.ink,
                      fontSize: 16,
                      height: 19 / 16,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                const SizedBox(height: 19),
                if (empty)
                  _LegacyWillEmptyPanel(onTap: onEdit)
                else
                  _LegacyWillPreviewPanel(body: body, onTap: onEdit),
                if (!empty) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 13),
                    child: Text(
                      _editedLabel(editedAt),
                      style: TextStyle(
                        color: w.inkSoft,
                        fontSize: 10,
                        height: 12 / 10,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            right: _legacyGutter,
            top: 18,
            child: _LegacyCardAction(
              label: trail,
              onTap: trail == '编辑' ? onEdit : null,
            ),
          ),
        ],
      ),
    );
  }

  static String _editedLabel(DateTime? value) {
    if (value == null) return '尚未保存';
    final local = value.toLocal();
    return '编辑于${local.year}年${local.month}月${local.day}日';
  }
}

class _LegacyWillEmptyPanel extends StatelessWidget {
  const _LegacyWillEmptyPanel({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: w.heroChipBg,
        borderRadius: _legacyCardBorderRadius,
        border: Border.all(color: w.heroChipBorder),
      ),
      child: SizedBox(
        height: 130,
        width: double.infinity,
        child: Column(
          children: [
            const SizedBox(height: 24),
            SizedBox(
              width: 24,
              height: 24,
              child: CustomPaint(painter: _LegacyDocPainter(color: w.ink)),
            ),
            const SizedBox(height: 4),
            Text(
              '尚未填写遗言内容',
              style: TextStyle(
                color: w.inkSoft,
                fontSize: 12,
                height: 14 / 12,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 12),
            _LegacyChip(label: '去填写', selected: true, onTap: onTap),
          ],
        ),
      ),
    );
  }
}

class _LegacyWillPreviewPanel extends StatelessWidget {
  const _LegacyWillPreviewPanel({required this.body, required this.onTap});

  final String body;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.of(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: w.heroChipBg,
          borderRadius: _legacyCardBorderRadius,
          border: Border.all(color: w.heroChipBorder),
        ),
        child: Container(
          height: 108,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(13, 21, 13, 14),
          child: Text(
            body,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: w.ink,
              fontSize: 12,
              height: 14 / 12,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _LegacyLoadErrorNotice extends StatelessWidget {
  const _LegacyLoadErrorNotice();

  @override
  Widget build(BuildContext context) {
    final w = _W2b.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: w.glass,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: w.glassBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 10, 20, 10),
        child: Row(
          children: [
            Icon(CupertinoIcons.exclamationmark_circle, size: 20, color: w.ink),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '没能读取到已保存的遗言，下面显示的可能不是最新内容，请检查网络后重新进入。',
                style: TextStyle(
                  color: w.ink,
                  fontSize: 12,
                  height: 14 / 12,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 遗言守护开启 banner, shown once the countdown is running.
class _LegacyGuardBanner extends StatelessWidget {
  const _LegacyGuardBanner({required this.days, required this.startedAt});

  final int days;
  final DateTime? startedAt;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.of(context);
    final started = startedAt?.toLocal();
    final date = started == null ? '今天' : '${started.month}月${started.day}日';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: w.glass,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: w.glassBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 10, 32, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.clock, size: 24, color: w.ink),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '遗言守护开启—$date起，连续$days日未登录，我们将替你把未曾说出口的心意，代为转告挂念之人。',
                style: TextStyle(
                  color: w.ink,
                  fontSize: 12,
                  height: 14 / 12,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sheet-of-paper glyph for the empty 遗言 panel.
class _LegacyDocPainter extends CustomPainter {
  const _LegacyDocPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 * scale
      ..strokeCap = StrokeCap.round;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(4 * scale, 2 * scale, 16 * scale, 20 * scale),
      Radius.circular(2 * scale),
    );
    canvas.drawRRect(body, stroke);
    canvas.drawLine(
      Offset(12 * scale, 2 * scale),
      Offset(20 * scale, 10 * scale),
      stroke,
    );
    canvas.drawLine(
      Offset(8 * scale, 13 * scale),
      Offset(16 * scale, 13 * scale),
      stroke,
    );
    canvas.drawLine(
      Offset(8 * scale, 16 * scale),
      Offset(16 * scale, 16 * scale),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _LegacyDocPainter oldDelegate) =>
      oldDelegate.color != color;
}
