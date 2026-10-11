part of 'package:companion_flutter/main.dart';

class OfflineGiftPage extends StatefulWidget {
  const OfflineGiftPage({
    super.key,
    required this.api,
    required this.session,
    this.initialGiftId,
    this.onChanged,
    this.onThanksSent,
  });

  final CompanionApi api;
  final AuthSession session;
  final String? initialGiftId;
  final VoidCallback? onChanged;
  final void Function(RealWorldGift gift, String message, String clientId)?
  onThanksSent;

  @override
  State<OfflineGiftPage> createState() => _OfflineGiftPageState();
}

class _OfflineGiftPageState extends State<OfflineGiftPage> {
  GiftsHome? _data;
  bool _loading = true;
  String? _error;
  bool _initialGiftOpened = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.fetchOfflineGifts(
        workspaceId: widget.session.workspaceId,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _data = data);
      _scheduleInitialGiftOpen(data);
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _error = '礼物暂时加载失败，请重试');
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  void _editAddress() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      builder: (_) => _AddressEditSheet(
        api: widget.api,
        initial: _data?.address,
        onSaved: () {
          if (!mounted) return;
          _load();
          widget.onChanged?.call();
        },
      ),
    );
  }

  void _showGift(RealWorldGift gift) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.86,
        minChildSize: 0.55,
        maxChildSize: 1,
        expand: false,
        builder: (_, controller) => _GiftDetailSheet(
          api: widget.api,
          gift: gift,
          scrollController: controller,
          onThanksSent: widget.onThanksSent,
          onChanged: () {
            _load();
            widget.onChanged?.call();
          },
        ),
      ),
    );
  }

  void _scheduleInitialGiftOpen(GiftsHome data) {
    final giftId = widget.initialGiftId?.trim();
    if (_initialGiftOpened || giftId == null || giftId.isEmpty) return;
    _initialGiftOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      var gift = _findGift(data, giftId);
      gift ??= await _fetchInitialGift(giftId);
      if (!mounted || gift == null) return;
      _showGift(gift);
    });
  }

  RealWorldGift? _findGift(GiftsHome data, String giftId) {
    final shipping = data.shippingGift;
    if (shipping?.id == giftId) return shipping;
    for (final group in data.groups) {
      for (final gift in group.gifts) {
        if (gift.id == giftId) return gift;
      }
    }
    return null;
  }

  Future<RealWorldGift?> _fetchInitialGift(String giftId) async {
    try {
      return await widget.api.fetchOfflineGift(giftId);
    } catch (error) {
      if (mounted) {
        setState(() {
          _initialGiftOpened = false;
          _error = '这份礼物暂时无法打开，请重试';
        });
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final giftCount =
        data?.groups.fold<int>(
          0,
          (count, group) => count + group.gifts.length,
        ) ??
        0;
    final colors = AppColors.of(context);
    return CupertinoPageScaffold(
      backgroundColor: colors.page,
      child: DefaultTextStyle(
        style: TextStyle(
          color: colors.text,
          fontSize: 15,
          decoration: TextDecoration.none,
        ),
        child: Stack(
          children: [
            const _GiftCollectionBackdrop(),
            SafeArea(
              bottom: false,
              child: _loading && data == null
                  ? const Center(child: CupertinoActivityIndicator())
                  : CustomScrollView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      slivers: [
                        CupertinoSliverRefreshControl(onRefresh: _load),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                            child: _OfflineSubpageTopBar(
                              title: '我的礼物',
                              onBack: () => Navigator.of(context).maybePop(),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_error != null) ...[
                                  const SizedBox(height: 16),
                                  _OfflineErrorBlock(
                                    message: _error!,
                                    onRetry: _load,
                                  ),
                                ],
                                if (data != null) ...[
                                  _GiftCollectionIntro(count: giftCount),
                                  const SizedBox(height: 22),
                                  _AddressCard(
                                    address: data.address,
                                    onTap: _editAddress,
                                  ),
                                  if (data.shippingGift != null) ...[
                                    const SizedBox(height: 24),
                                    _ShippingGiftCard(
                                      api: widget.api,
                                      gift: data.shippingGift!,
                                      onTap: () =>
                                          _showGift(data.shippingGift!),
                                    ),
                                  ],
                                  const SizedBox(height: 32),
                                  Text(
                                    '收到的礼物',
                                    key: const ValueKey(
                                      'gift-collection-header',
                                    ),
                                    style: _titleStyle(
                                      context,
                                      18,
                                    ).copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        for (final group
                            in (data?.groups ?? const <GiftYearGroup>[]).where(
                              (group) => group.gifts.isNotEmpty,
                            )) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                              child: Row(
                                children: [
                                  Text(
                                    '${group.year} 年',
                                    style: _mutedStyle(
                                      context,
                                      12,
                                    ).copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Container(
                                      height: 0.5,
                                      color: _W2b.resolve(
                                        context,
                                      ).inkFaint.withValues(alpha: 0.18),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            sliver: SliverLayoutBuilder(
                              builder: (context, constraints) {
                                final largeText =
                                    MediaQuery.textScalerOf(context).scale(16) >
                                    21;
                                final columns =
                                    largeText ||
                                        constraints.crossAxisExtent < 350
                                    ? 1
                                    : 2;
                                return SliverGrid(
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: columns,
                                        crossAxisSpacing: 14,
                                        mainAxisSpacing: 16,
                                        mainAxisExtent: columns == 1
                                            ? 300 +
                                                  MediaQuery.textScalerOf(
                                                    context,
                                                  ).scale(54)
                                            : 272,
                                      ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) => _GiftListCard(
                                      gift: group.gifts[index],
                                      api: widget.api,
                                      onTap: () =>
                                          _showGift(group.gifts[index]),
                                    ),
                                    childCount: group.gifts.length,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                        if (data != null &&
                            data.groups.every((g) => g.gifts.isEmpty))
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
                              child: _SoftEmptyPanel(
                                icon: CupertinoIcons.gift,
                                title: '还没有收到礼物',
                                subtitle: '收到的心意，会好好收藏在这里',
                                accent: _kGiftAccent,
                              ),
                            ),
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 36)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftCollectionBackdrop extends StatelessWidget {
  const _GiftCollectionBackdrop();
  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark(context);
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? const [
                    Color(0xFF142323),
                    Color(0xFF111A23),
                    Color(0xFF222122),
                  ]
                : const [
                    Color(0xFFF7F6F2),
                    Color(0xFFEAF3F2),
                    Color(0xFFF2F0EB),
                  ],
          ),
        ),
        child: Align(
          alignment: Alignment.topRight,
          child: FractionallySizedBox(
            widthFactor: .8,
            heightFactor: .5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFD4C5AF).withValues(alpha: dark ? .10 : .28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GiftCollectionIntro extends StatelessWidget {
  const _GiftCollectionIntro({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '珍藏的，是心意',
            style: _titleStyle(context, 30).copyWith(
              fontWeight: FontWeight.w500,
              letterSpacing: -1,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 18,
                height: 1,
                color: _W2b.resolve(context).inkFaint,
              ),
              const SizedBox(width: 10),
              Text(
                '$count 份',
                style: _mutedStyle(
                  context,
                  12,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text('礼物，留住被惦记的瞬间', style: _mutedStyle(context, 12)),
              ),
            ],
          ),
        ],
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
        key: const ValueKey('gift-address-entry'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: _softCardDecoration(
          context,
          radius: 20,
        ).copyWith(boxShadow: []),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _W2b.resolve(context).glass,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                CupertinoIcons.location,
                size: 17,
                color: _W2b.resolve(context).inkSoft,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '收货地址',
                    style: _mutedStyle(
                      context,
                      12,
                    ).copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address?.display ?? '添加地址，方便接收礼物',
                    style: _mutedStyle(context, 13),
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
  int _generation = 0;

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
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _tracking = null;
      _error = null;
    });
    try {
      final tracking = await widget.api.fetchGiftTracking(widget.gift.id);
      if (!mounted || generation != _generation) return;
      setState(() => _tracking = tracking);
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
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
        decoration: _softCardDecoration(
          context,
          radius: 24,
        ).copyWith(boxShadow: []),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _GiftThumb(gift: widget.gift, size: 56, api: widget.api),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.gift.giftName,
                        style: _titleStyle(
                          context,
                          16,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text('正在向你靠近', style: _mutedStyle(context, 12)),
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
                Expanded(
                  child: Text(
                    '配送动态',
                    style: _titleStyle(
                      context,
                      14,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text('查看物流', style: _mutedStyle(context, 12)),
                const SizedBox(width: 4),
                Icon(
                  CupertinoIcons.arrow_up_right,
                  size: 13,
                  color: _W2b.resolve(context).inkSoft,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_loading)
              const _TrackingLoadingBlock()
            else if (_error != null)
              _TrackingErrorBlock(onRetry: _loadTracking)
            else if (latest != null)
              Text(
                latest.title,
                style: _mutedStyle(context, 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            else
              const _TrackingEmptyBlock(),
          ],
        ),
      ),
    );
  }
}

class _GiftListCard extends StatelessWidget {
  const _GiftListCard({
    required this.gift,
    required this.onTap,
    required this.api,
  });
  final RealWorldGift gift;
  final CompanionApi api;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final note =
        (gift.giftNote?.trim().isNotEmpty == true
                ? gift.giftNote
                : gift.giftReason)
            ?.trim();
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: _softCardDecoration(
              context,
              radius: 24,
            ).copyWith(boxShadow: []),
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SizedBox(
                    width: double.infinity,
                    child: LayoutBuilder(
                      builder: (context, constraints) => _GiftThumb(
                        gift: gift,
                        api: api,
                        size: constraints.maxWidth,
                        fill: true,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _giftCollectionDate(gift.createdAt),
                        style: _mutedStyle(context, 11),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        gift.giftName,
                        style: _titleStyle(
                          context,
                          16,
                        ).copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 7),
                      SizedBox(
                        height: MediaQuery.textScalerOf(context).scale(36),
                        child: Text(
                          note ?? '',
                          style: _mutedStyle(context, 12).copyWith(height: 1.5),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
}

class _GiftDetailSheet extends StatefulWidget {
  const _GiftDetailSheet({
    required this.api,
    required this.gift,
    required this.onChanged,
    required this.scrollController,
    this.onThanksSent,
  });

  final CompanionApi api;
  final ScrollController scrollController;
  final RealWorldGift gift;
  final VoidCallback onChanged;
  final void Function(RealWorldGift gift, String message, String clientId)?
  onThanksSent;

  @override
  State<_GiftDetailSheet> createState() => _GiftDetailSheetState();
}

class _GiftDetailSheetState extends State<_GiftDetailSheet> {
  GiftTracking? _tracking;
  bool _loadingTracking = false;
  bool _sending = false;
  String? _trackingError;
  String? _thanksError;
  late final String _thanksClientId =
      'gift-thanks-${widget.gift.id}-${DateTime.now().microsecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    unawaited(_loadTracking());
  }

  Future<void> _loadTracking() async {
    if (_loadingTracking) return;
    setState(() {
      _loadingTracking = true;
      _trackingError = null;
    });
    try {
      final tracking = await widget.api.fetchGiftTracking(widget.gift.id);
      if (mounted) setState(() => _tracking = tracking);
    } catch (_) {
      if (mounted) setState(() => _trackingError = '物流同步失败');
    } finally {
      if (mounted) setState(() => _loadingTracking = false);
    }
  }

  Future<void> _sendThanks() async {
    if (_sending) return;
    final message = '我收到礼物啦，谢谢你';
    final clientId = _thanksClientId;
    setState(() {
      _sending = true;
      _thanksError = null;
    });
    try {
      final onThanksSent = widget.onThanksSent;
      if (onThanksSent != null) {
        onThanksSent(widget.gift, message, clientId);
      } else {
        await widget.api.sendGiftThanks(
          widget.gift.id,
          message: message,
          clientId: clientId,
        );
      }
      if (!mounted) return;
      widget.onChanged();
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _thanksError = '感谢暂时没有传达成功，请重试');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _OfflineDetailSheetFrame(
      title: '礼物详情',
      compact: true,
      showCloseButton: false,
      scrollController: widget.scrollController,
      children: [
        _GiftThumb(gift: widget.gift, size: 210, wide: true, api: widget.api),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                widget.gift.giftName,
                style: _titleStyle(
                  context,
                  24,
                ).copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 10),
            _ShippingStateChip(text: _shippingStatusText(widget.gift.status)),
          ],
        ),
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
              color: _W2b.resolve(context).glass,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _W2b.resolve(context).glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TA 的赠言', style: _mutedStyle(context, 11)),
                const SizedBox(height: 8),
                Text(
                  widget.gift.giftNote!,
                  style: TextStyle(
                    color: AppColors.isDark(context)
                        ? const Color(0xFFFFC99E)
                        : const Color(0xFF7C5A42),
                    height: 1.5,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        Row(
          children: [
            Text('物流追踪详情', style: _titleStyle(context, 16)),
            const SizedBox(width: 8),
            if (_loadingTracking) const CupertinoActivityIndicator(radius: 7),
          ],
        ),
        if (_visibleGiftCarrier(widget.gift).isNotEmpty ||
            (widget.gift.trackingNumber ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          SelectableText(
            [
              if (_visibleGiftCarrier(widget.gift).isNotEmpty)
                _visibleGiftCarrier(widget.gift),
              if ((widget.gift.trackingNumber ?? '').trim().isNotEmpty)
                '运单号 ${widget.gift.trackingNumber}',
            ].join(' · '),
            style: _mutedStyle(context, 12),
          ),
        ],
        if ((widget.gift.lastTrackingSyncedAt ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            '上次同步 ${_shortDate(widget.gift.lastTrackingSyncedAt!)}',
            style: _mutedStyle(context, 12),
          ),
        ],
        const SizedBox(height: 10),
        if (_loadingTracking)
          const _TrackingLoadingBlock()
        else if (_trackingError != null)
          _TrackingErrorBlock(onRetry: _loadTracking)
        else if (_tracking?.events.isNotEmpty == true)
          _TrackingTimeline(events: _dedupeTrackingEvents(_tracking!.events))
        else
          const _TrackingEmptyBlock(),
        const SizedBox(height: 14),
        if (_thanksError != null) ...[
          Text(
            _thanksError!,
            style: _mutedStyle(
              context,
              13,
            ).copyWith(color: CupertinoColors.systemRed),
          ),
          const SizedBox(height: 10),
        ],
        if (widget.gift.thanksSentAt == null) ...[
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              borderRadius: BorderRadius.circular(16),
              color: _kGiftAccent,
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
                      ? const Color(0xFFFF8C4B)
                      : const Color(0xFFEFE3D8),
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
    final color = active ? const Color(0xFFFF9A57) : const Color(0xFFE1D4C8);
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
                      color: Color(0x33FF8C4B),
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
            color: active ? const Color(0xFFCE7333) : const Color(0xFFB0A090),
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
    final isDark = AppColors.isDark(context);
    final background = isDark
        ? const Color(0x1FFF9A57)
        : const Color(0xFFFFF1E6);
    final border = isDark ? const Color(0x55FF8C4B) : const Color(0x66FF8C4B);
    final foreground = isDark
        ? const Color(0xFFFFB27E)
        : const Color(0xFFCE7333);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

// The mock catalogue supplies raw Unsplash URLs. Request a display-sized file
// at the CDN; decode limits alone do not reduce transferred bytes. Other hosts
// and signed URLs keep their exact URLs.
String? _giftDisplayImageUrl(String? value) {
  final url = value?.trim();
  if (url == null || url.isEmpty) return null;
  final uri = Uri.tryParse(url);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host != 'images.unsplash.com' ||
      uri.queryParameters.containsKey('s')) {
    return url;
  }
  final params = Map<String, String>.of(uri.queryParameters);
  final width = int.tryParse(params['w'] ?? '');
  params['w'] = (width != null && width > 0 ? math.min(width, 960) : 960)
      .toString();
  params.putIfAbsent('auto', () => 'format');
  params.putIfAbsent('q', () => '80');
  return uri.replace(queryParameters: params).toString();
}

// Protected images are scoped to the API session without persisting credentials
// in cache keys. Public product URLs can reuse their disk cache across sessions.
final _giftImageSessions = Expando<(String?, String)>();
String _giftImageCacheKey(CompanionApi api, String url, bool protected) {
  if (!protected) return url;
  var session = _giftImageSessions[api];
  if (session == null || session.$1 != api.authToken) {
    session = (
      api.authToken,
      '${DateTime.now().microsecondsSinceEpoch}-${math.Random.secure().nextInt(1 << 32)}',
    );
    _giftImageSessions[api] = session;
  }
  return 'gift-${session.$2}-$url';
}

class _GiftThumb extends StatefulWidget {
  const _GiftThumb({
    required this.gift,
    required this.size,
    required this.api,
    this.wide = false,
    this.fill = false,
  });

  final RealWorldGift gift;
  final double size;
  final bool wide;
  final bool fill;
  final CompanionApi api;

  @override
  State<_GiftThumb> createState() => _GiftThumbState();
}

class _GiftThumbState extends State<_GiftThumb> {
  int _attempt = 0;

  Map<String, String>? _headers(String url) {
    final uri = Uri.tryParse(url);
    final base = Uri.tryParse(widget.api.baseUrl);
    if (uri == null ||
        base == null ||
        !uri.hasAuthority ||
        !base.hasAuthority ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.origin != base.origin) {
      return null;
    }
    return _mediaHeadersForUrl(url, widget.api.authToken);
  }

  Future<void> _retry(String url) async {
    try {
      // A failed decode may be a corrupt cached file. Retry both cache layers.
      await CachedNetworkImageProvider.defaultCacheManager.removeFile(
        _giftImageCacheKey(widget.api, url, _headers(url) != null),
      );
      await _provider(url).evict();
    } catch (_) {
      // Cache cleanup is best effort; the image still gets a retry affordance.
    }
    if (mounted) setState(() => _attempt++);
  }

  ImageProvider _provider(String url) {
    final headers = _headers(url);
    // Both surfaces use the same bounded decoded bitmap, so opening details
    // reuses the list image synchronously. Original bytes are cached on disk.
    return ResizeImage(
      CachedNetworkImageProvider(
        url,
        headers: headers,
        cacheKey: _giftImageCacheKey(widget.api, url, headers != null),
      ),
      width: 960,
      height: 960,
      policy: ResizeImagePolicy.fit,
    );
  }

  Widget _placeholder(
    BuildContext context, {
    bool loading = false,
    String? url,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const CupertinoActivityIndicator(radius: 10)
          else
            Icon(
              CupertinoIcons.gift,
              size: widget.wide ? 42 : 26,
              color: _kGiftAccent,
            ),
          if (widget.wide) ...[
            const SizedBox(height: 10),
            Text(
              loading
                  ? '正在加载图片…'
                  : url == null
                  ? '暂无礼物图片'
                  : '图片暂时加载失败',
              style: _mutedStyle(context, 13),
            ),
          ],
          if (url != null && !loading)
            CupertinoButton(
              minimumSize: Size.zero,
              padding: const EdgeInsets.all(6),
              onPressed: () => _retry(url),
              child: widget.wide
                  ? const Text(
                      '重新加载',
                      style: TextStyle(color: _kGiftAccent, fontSize: 13),
                    )
                  : const Icon(
                      CupertinoIcons.refresh,
                      size: 14,
                      color: _kGiftAccent,
                    ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = _giftDisplayImageUrl(widget.gift.productImageUrl);
    final hasImage = url != null && url.isNotEmpty;
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(widget.wide ? 22 : 16),
      child: ColoredBox(
        color: _W2b.resolve(context).glass,
        child: !hasImage
            ? _placeholder(context)
            : Image(
                image: _provider(url),
                key: ValueKey('$url:$_attempt'),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                frameBuilder: (context, child, frame, synchronous) =>
                    synchronous || frame != null
                    ? child
                    : _placeholder(context, loading: true),
                errorBuilder: (_, __, ___) => _placeholder(context, url: url),
              ),
      ),
    );
    return Semantics(
      label: '${widget.gift.giftName}图片',
      child: widget.wide
          ? AspectRatio(aspectRatio: 1.6, child: content)
          : widget.fill
          ? SizedBox.expand(child: content)
          : SizedBox(width: widget.size, height: widget.size, child: content),
    );
  }
}

class _TrackingTimeline extends StatelessWidget {
  const _TrackingTimeline({required this.events});

  final List<GiftTrackingEvent> events;

  @override
  Widget build(BuildContext context) {
    final visibleEvents = events.reversed.toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _W2b.resolve(context).glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _W2b.resolve(context).glassBorder),
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
    final isDark = AppColors.isDark(context);
    final dotColor = isLatest
        ? (isDark ? const Color(0xFFFFB27E) : const Color(0xFFFF9A57))
        : (isDark ? const Color(0xFFB07648) : const Color(0xFFF6C9A6));
    final dotBorderColor = isDark
        ? const Color(0xFF241811)
        : CupertinoColors.white;
    final lineColor = isDark
        ? const Color(0x55E0813A)
        : const Color(0x55FF8C4B);
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
                  border: Border.all(color: dotBorderColor, width: 2),
                  boxShadow: isLatest
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFFFF8C4B,
                            ).withValues(alpha: isDark ? 0.32 : 0.20),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
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
                    color: lineColor,
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
        color: _W2b.resolve(context).glass,
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
        color: _W2b.resolve(context).glass,
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
    final isDark = AppColors.isDark(context);
    final retryBackground = isDark
        ? const Color(0x332F1510)
        : const Color(0xFFFFE2D7);
    final retryText = isDark
        ? const Color(0xFFFFA681)
        : const Color(0xFFB96542);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A1815) : const Color(0xFFFFF5F1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(child: Text('物流同步失败', style: _mutedStyle(context, 13))),
          CupertinoButton(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            borderRadius: BorderRadius.circular(999),
            color: retryBackground,
            onPressed: onRetry,
            child: Text(
              '重试',
              style: TextStyle(
                color: retryText,
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
  final sorted = events.toList()
    ..sort((a, b) {
      final left = DateTime.tryParse(a.occurredAt);
      final right = DateTime.tryParse(b.occurredAt);
      if (left == null && right == null) {
        return a.occurredAt.compareTo(b.occurredAt);
      }
      if (left == null) return -1;
      if (right == null) return 1;
      return left.compareTo(right);
    });
  final seen = <String>{};
  return [
    for (final event in sorted)
      if (seen.add(
        jsonEncode([
          event.status.trim(),
          event.title.trim(),
          (event.description ?? '').trim(),
          (event.location ?? '').trim(),
          event.occurredAt,
        ]),
      ))
        event,
  ];
}

int _trackingStepIndex(String giftStatus, List<GiftTrackingEvent> events) {
  if (giftStatus == 'pending_address' && events.isEmpty) return -1;
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
  if (normalized.contains('delivered') || normalized == 'signed') return '已签收';
  if (normalized.contains('deliver')) return '派送中';
  if (normalized.contains('shipping') || normalized.contains('transit')) {
    return '运输中';
  }
  if (normalized == 'pending_address') return '待填写地址';
  if (normalized.contains('packed') || normalized.contains('picked')) {
    return '已打包';
  }
  if (normalized.contains('ordered')) return '已下单';
  return '处理中';
}

String _visibleGiftCarrier(RealWorldGift gift) {
  final carrier = gift.logisticsProvider?.trim() ?? '';
  return carrier.toLowerCase() == 'mock' ? '' : carrier;
}

String _giftCollectionDate(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  return date == null ? '日期未知' : '${date.month}月${date.day}日';
}
