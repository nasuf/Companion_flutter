part of 'package:companion_flutter/main.dart';

class OfflineGiftPage extends StatefulWidget {
  const OfflineGiftPage({
    super.key,
    required this.api,
    required this.session,
    this.onChanged,
  });

  final CompanionApi api;
  final AuthSession session;
  final VoidCallback? onChanged;

  @override
  State<OfflineGiftPage> createState() => _OfflineGiftPageState();
}

class _OfflineGiftPageState extends State<OfflineGiftPage> {
  GiftsHome? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.fetchOfflineGifts(
        workspaceId: widget.session.workspaceId,
      );
      if (!mounted) return;
      setState(() => _data = data);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _editAddress() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => _AddressEditSheet(
        api: widget.api,
        initial: _data?.address,
        onSaved: () {
          _load();
          widget.onChanged?.call();
        },
      ),
    );
  }

  void _showGift(RealWorldGift gift) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => _GiftDetailSheet(
        api: widget.api,
        gift: gift,
        onChanged: () {
          _load();
          widget.onChanged?.call();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final colors = AppColors.of(context);
    return CupertinoPageScaffold(
      backgroundColor: colors.page,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('心意小窝'),
        border: Border(bottom: BorderSide(color: Color(0x11000000))),
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          color: colors.text,
          fontSize: 15,
          decoration: TextDecoration.none,
        ),
        child: SafeArea(
          bottom: false,
          child: _loading
              ? const Center(child: CupertinoActivityIndicator())
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('🎀 心意小窝', style: _titleStyle(context, 28)),
                            const SizedBox(height: 4),
                            Text(
                              '每一份礼物，都是被惦记的证明',
                              style: _mutedStyle(context, 15),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              _OfflineErrorBlock(
                                message: _error!,
                                onRetry: _load,
                              ),
                            ],
                            const SizedBox(height: 18),
                            _AddressCard(
                              address: data?.address,
                              onTap: _editAddress,
                            ),
                            const SizedBox(height: 18),
                            if (data?.shippingGift != null)
                              _ShippingGiftCard(
                                api: widget.api,
                                gift: data!.shippingGift!,
                                onTap: () => _showGift(data.shippingGift!),
                              )
                            else
                              _AllArrivedCard(onTap: _editAddress),
                            const SizedBox(height: 26),
                            Text('📦 收到的礼物', style: _titleStyle(context, 20)),
                          ],
                        ),
                      ),
                    ),
                    for (final group
                        in data?.groups ?? const <GiftYearGroup>[]) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                          child: _SectionTitle(title: '${group.year} 年'),
                        ),
                      ),
                      SliverList.separated(
                        itemCount: group.gifts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _GiftListCard(
                            gift: group.gifts[index],
                            onTap: () => _showGift(group.gifts[index]),
                          ),
                        ),
                      ),
                    ],
                    if ((data?.groups ?? const []).isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
                          child: _SoftEmptyPanel(
                            icon: CupertinoIcons.gift,
                            title: '还没有送出过礼物',
                            subtitle: '多和我聊聊天，让我记住你的喜好与小心愿',
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 36)),
                  ],
                ),
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.address, required this.onTap});

  final GiftAddress? address;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: _softCardDecoration(context, radius: 18),
        child: Row(
          children: [
            _RoundIcon(
              icon: CupertinoIcons.house_fill,
              color: const Color(0xFF7EC5E1),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '收货地址',
                    style: _mutedStyle(
                      context,
                      12,
                    ).copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address?.display ?? '还没有填写地址',
                    style: _titleStyle(context, 15),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 18,
              color: Color(0x8897A3AD),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllArrivedCard extends StatelessWidget {
  const _AllArrivedCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _softCardDecoration(context, radius: 22),
      child: Row(
        children: [
          _RoundIcon(
            icon: CupertinoIcons.mail_solid,
            color: const Color(0xFF7DA7FF),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('所有心意都已抵达', style: _titleStyle(context, 17)),
                const SizedBox(height: 5),
                Text('新的惊喜，正在悄悄酝酿中...', style: _mutedStyle(context, 13)),
              ],
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            borderRadius: BorderRadius.circular(999),
            color: AppColors.of(context).accentSoft,
            onPressed: onTap,
            child: Text(
              '去聊聊',
              style: TextStyle(
                color: AppColors.of(context).accent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShippingGiftCard extends StatefulWidget {
  const _ShippingGiftCard({
    required this.api,
    required this.gift,
    required this.onTap,
  });

  final CompanionApi api;
  final RealWorldGift gift;
  final VoidCallback onTap;

  @override
  State<_ShippingGiftCard> createState() => _ShippingGiftCardState();
}

class _ShippingGiftCardState extends State<_ShippingGiftCard> {
  GiftTracking? _tracking;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTracking());
  }

  @override
  void didUpdateWidget(covariant _ShippingGiftCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gift.id != widget.gift.id) {
      unawaited(_loadTracking());
    }
  }

  Future<void> _loadTracking() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tracking = await widget.api.fetchGiftTracking(widget.gift.id);
      if (!mounted) return;
      setState(() => _tracking = tracking);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = _dedupeTrackingEvents(_tracking?.events ?? const []);
    final step = _trackingStepIndex(widget.gift.status, events);
    final latest = events.isEmpty ? null : events.last;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: widget.onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: _softCardDecoration(context, radius: 22).copyWith(
          border: Border.all(color: const Color(0x667EC5E1), width: 1.4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x167EC5E1),
              blurRadius: 26,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _GiftThumb(gift: widget.gift, size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '礼物正在向你飞奔',
                        style: _titleStyle(
                          context,
                          18,
                        ).copyWith(color: const Color(0xFF3D95B5)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.gift.giftName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _mutedStyle(context, 13),
                      ),
                    ],
                  ),
                ),
                _ShippingStateChip(
                  text: _shippingStatusText(widget.gift.status),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _GiftProgressBar(currentStep: step),
            const SizedBox(height: 18),
            Row(
              children: [
                Text('物流追踪', style: _titleStyle(context, 15)),
                const Spacer(),
                Text(
                  '点开查看寄语',
                  style: _mutedStyle(
                    context,
                    12,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_loading)
              const _TrackingLoadingBlock()
            else if (_error != null)
              _TrackingErrorBlock(onRetry: _loadTracking)
            else if (latest != null)
              _TrackingTimeline(events: events, compact: true)
            else
              const _TrackingEmptyBlock(),
          ],
        ),
      ),
    );
  }
}

class _GiftListCard extends StatelessWidget {
  const _GiftListCard({required this.gift, required this.onTap});

  final RealWorldGift gift;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _softCardDecoration(context, radius: 18),
        child: Row(
          children: [
            _GiftThumb(gift: gift, size: 64),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gift.giftName,
                    style: _titleStyle(context, 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _shortDate(gift.createdAt),
                    style: _mutedStyle(context, 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    gift.giftNote ?? gift.giftReason ?? '',
                    style: _mutedStyle(context, 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 18,
              color: Color(0x8897A3AD),
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftDetailSheet extends StatefulWidget {
  const _GiftDetailSheet({
    required this.api,
    required this.gift,
    required this.onChanged,
  });

  final CompanionApi api;
  final RealWorldGift gift;
  final VoidCallback onChanged;

  @override
  State<_GiftDetailSheet> createState() => _GiftDetailSheetState();
}

class _GiftDetailSheetState extends State<_GiftDetailSheet> {
  GiftTracking? _tracking;
  bool _loadingTracking = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTracking());
  }

  Future<void> _loadTracking() async {
    setState(() => _loadingTracking = true);
    try {
      final tracking = await widget.api.fetchGiftTracking(widget.gift.id);
      if (mounted) setState(() => _tracking = tracking);
    } finally {
      if (mounted) setState(() => _loadingTracking = false);
    }
  }

  Future<void> _sendThanks() async {
    setState(() => _sending = true);
    try {
      await widget.api.sendGiftThanks(widget.gift.id, message: '我收到礼物啦，谢谢你');
      widget.onChanged();
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return _BottomSheetFrame(
      expandWhenKeyboardVisible: true,
      child: DefaultTextStyle(
        style: TextStyle(
          color: colors.text,
          fontSize: 15,
          decoration: TextDecoration.none,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetGrabber(context),
            _GiftThumb(gift: widget.gift, size: 190, wide: true),
            const SizedBox(height: 16),
            Text(widget.gift.giftName, style: _titleStyle(context, 22)),
            const SizedBox(height: 6),
            Text(
              _shortDate(widget.gift.createdAt),
              style: _mutedStyle(context, 13),
            ),
            const SizedBox(height: 14),
            if ((widget.gift.giftNote ?? '').isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8EF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFEEDCCB)),
                ),
                child: Text(
                  widget.gift.giftNote!,
                  style: const TextStyle(
                    color: Color(0xFF7C5A42),
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            const SizedBox(height: 18),
            Row(
              children: [
                Text('物流追踪详情', style: _titleStyle(context, 17)),
                const SizedBox(width: 8),
                if (_loadingTracking)
                  const CupertinoActivityIndicator(radius: 7),
              ],
            ),
            const SizedBox(height: 10),
            if (_tracking != null)
              _TrackingTimeline(
                events: _dedupeTrackingEvents(_tracking!.events),
              )
            else if (_loadingTracking)
              const _TrackingLoadingBlock()
            else
              _TrackingErrorBlock(onRetry: _loadTracking),
            const SizedBox(height: 14),
            if (widget.gift.thanksSentAt == null) ...[
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  borderRadius: BorderRadius.circular(16),
                  color: colors.accent,
                  onPressed: _sending ? null : _sendThanks,
                  child: Text(
                    _sending ? '正在传达...' : '向 TA 说声谢谢',
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.w900,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ] else
              const _SoftSuccessBar(text: '✓ 感谢已传达'),
          ],
        ),
      ),
    );
  }
}

class _GiftProgressBar extends StatelessWidget {
  const _GiftProgressBar({required this.currentStep});

  final int currentStep;

  static const _steps = [
    (label: '下单', icon: CupertinoIcons.doc_text_fill),
    (label: '打包', icon: CupertinoIcons.cube_box_fill),
    (label: '运输', icon: CupertinoIcons.car_detailed),
    (label: '派送', icon: CupertinoIcons.location_fill),
    (label: '签收', icon: CupertinoIcons.check_mark_circled_solid),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          Expanded(
            child: _GiftProgressStep(
              label: _steps[i].label,
              icon: _steps[i].icon,
              active: i <= currentStep,
              current: i == currentStep,
            ),
          ),
          if (i != _steps.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(top: 15),
                decoration: BoxDecoration(
                  color: i < currentStep
                      ? const Color(0xFF7EC5E1)
                      : const Color(0xFFE4ECF2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _GiftProgressStep extends StatelessWidget {
  const _GiftProgressStep({
    required this.label,
    required this.icon,
    required this.active,
    required this.current,
  });

  final String label;
  final IconData icon;
  final bool active;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF70C4E2) : const Color(0xFFD3DCE4);
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: current ? 34 : 30,
          height: current ? 34 : 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? color : CupertinoColors.white,
            border: Border.all(color: color, width: current ? 2.5 : 1.6),
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: Color(0x337EC5E1),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: current ? 15 : 13,
            color: active ? CupertinoColors.white : color,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFF5AA8C4) : const Color(0xFF9AA6AF),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}

class _ShippingStateChip extends StatelessWidget {
  const _ShippingStateChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F6FC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x667EC5E1)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF4C9DBC),
          fontSize: 12,
          fontWeight: FontWeight.w900,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _GiftThumb extends StatelessWidget {
  const _GiftThumb({required this.gift, required this.size, this.wide = false});

  final RealWorldGift gift;
  final double size;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final url = gift.productImageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: wide ? double.infinity : size,
        height: size,
        color: const Color(0xFFEAF5FB),
        child: url == null
            ? const Center(child: Text('🎁', style: TextStyle(fontSize: 32)))
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text('🎁', style: TextStyle(fontSize: 32)),
                ),
              ),
      ),
    );
  }
}

class _TrackingTimeline extends StatelessWidget {
  const _TrackingTimeline({required this.events, this.compact = false});

  final List<GiftTrackingEvent> events;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final visibleEvents = compact
        ? events.reversed.take(3).toList(growable: false)
        : events.reversed.toList(growable: false);
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF7FC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x227EC5E1)),
      ),
      child: Column(
        children: [
          for (var index = 0; index < visibleEvents.length; index++)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == visibleEvents.length - 1 ? 0 : 14,
              ),
              child: _TrackingTimelineRow(
                event: visibleEvents[index],
                isLatest: index == 0,
                showLine: index != visibleEvents.length - 1,
              ),
            ),
        ],
      ),
    );
  }
}

class _TrackingTimelineRow extends StatelessWidget {
  const _TrackingTimelineRow({
    required this.event,
    required this.isLatest,
    required this.showLine,
  });

  final GiftTrackingEvent event;
  final bool isLatest;
  final bool showLine;

  @override
  Widget build(BuildContext context) {
    final dotColor = isLatest
        ? const Color(0xFF57BEE0)
        : const Color(0xFF9ED3E8);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 18,
          child: Column(
            children: [
              Container(
                width: isLatest ? 16 : 12,
                height: isLatest ? 16 : 12,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                  border: Border.all(color: CupertinoColors.white, width: 2),
                  boxShadow: isLatest
                      ? const [
                          BoxShadow(
                            color: Color(0x337EC5E1),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
              ),
              if (showLine)
                Container(
                  width: 2,
                  height: 32,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x557EC5E1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                style: _titleStyle(
                  context,
                  14,
                ).copyWith(decoration: TextDecoration.none),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  _shortDate(event.occurredAt),
                  if ((event.location ?? '').isNotEmpty) event.location!,
                ].join(' · '),
                style: _mutedStyle(
                  context,
                  12,
                ).copyWith(decoration: TextDecoration.none),
              ),
              if ((event.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  event.description!,
                  style: _mutedStyle(
                    context,
                    12,
                  ).copyWith(decoration: TextDecoration.none),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TrackingLoadingBlock extends StatelessWidget {
  const _TrackingLoadingBlock();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF7FC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const CupertinoActivityIndicator(radius: 8),
          const SizedBox(width: 10),
          Text('正在同步物流...', style: _mutedStyle(context, 13)),
        ],
      ),
    );
  }
}

class _TrackingEmptyBlock extends StatelessWidget {
  const _TrackingEmptyBlock();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF7FC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text('暂时还没有物流更新', style: _mutedStyle(context, 13)),
    );
  }
}

class _TrackingErrorBlock extends StatelessWidget {
  const _TrackingErrorBlock({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(child: Text('物流同步失败', style: _mutedStyle(context, 13))),
          CupertinoButton(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            borderRadius: BorderRadius.circular(999),
            color: const Color(0xFFFFE2D7),
            onPressed: onRetry,
            child: const Text(
              '重试',
              style: TextStyle(
                color: Color(0xFFB96542),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

List<GiftTrackingEvent> _dedupeTrackingEvents(List<GiftTrackingEvent> events) {
  final seen = <String>{};
  final result = <GiftTrackingEvent>[];
  for (final event in events) {
    final key = [
      event.status.trim(),
      event.title.trim(),
      (event.description ?? '').trim(),
      (event.location ?? '').trim(),
    ].join('\u0001');
    if (seen.add(key)) {
      result.add(event);
    }
  }
  return result;
}

int _trackingStepIndex(String giftStatus, List<GiftTrackingEvent> events) {
  final statuses = {
    ...events.map((event) => event.status.toLowerCase()),
    giftStatus.toLowerCase(),
  };
  if (statuses.any(
    (status) => status.contains('delivered') || status == 'signed',
  )) {
    return 4;
  }
  if (statuses.any((status) => status.contains('deliver'))) {
    return 3;
  }
  if (statuses.any(
    (status) => status.contains('shipping') || status.contains('transit'),
  )) {
    return 2;
  }
  if (statuses.any(
    (status) => status.contains('packed') || status.contains('picked'),
  )) {
    return 1;
  }
  return 0;
}

String _shippingStatusText(String status) {
  final normalized = status.toLowerCase();
  if (normalized.contains('delivered')) return '已签收';
  if (normalized.contains('deliver')) return '派送中';
  if (normalized.contains('shipping') || normalized.contains('transit')) {
    return '运输中';
  }
  if (normalized.contains('ordered')) return '已下单';
  return '处理中';
}
