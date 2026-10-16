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

  void _showGift(RealWorldGift gift, {bool justRevealed = false}) {
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
          justRevealed: justRevealed,
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

  Future<void> _confirmReceipt(RealWorldGift gift) async {
    final result = await _confirmGiftReceipt(context, widget.api, gift);
    if (result == null || !mounted) return;
    widget.onChanged?.call();
    unawaited(_load());
    _showGift(result.gift, justRevealed: !result.alreadyConfirmed);
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
    for (final gift in data.inTransit) {
      if (gift.id == giftId) return gift;
    }
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
    final inTransit = <RealWorldGift>[];
    final ids = <String>{};
    for (final gift in data?.inTransit ?? const <RealWorldGift>[]) {
      if (ids.add(gift.id)) inTransit.add(gift);
    }
    final received = <RealWorldGift>[];
    for (final group in data?.groups ?? const <GiftYearGroup>[]) {
      for (final gift in group.gifts) {
        if (ids.add(gift.id)) received.add(gift);
      }
    }
    // The API can contain legacy/out-of-order groups. Select by date, not position.
    received.sort((a, b) {
      final date = (DateTime.tryParse(b.createdAt)?.millisecondsSinceEpoch ?? 0)
          .compareTo(
            DateTime.tryParse(a.createdAt)?.millisecondsSinceEpoch ?? 0,
          );
      return date != 0 ? date : a.id.compareTo(b.id);
    });
    // 有在途礼物时它们占据首屏；否则聚焦最近收到的一份。
    final featured = inTransit.isEmpty && received.isNotEmpty
        ? received.first
        : null;
    final history = received.where((gift) => gift.id != featured?.id).toList();
    final years = <int, List<RealWorldGift>>{};
    for (final gift in history) {
      final year = DateTime.tryParse(gift.createdAt)?.toLocal().year ?? 0;
      years.putIfAbsent(year, () => []).add(gift);
    }
    final colors = AppColors.of(context);
    return CupertinoPageScaffold(
      backgroundColor: colors.page,
      child: DefaultTextStyle(
        style: TextStyle(
          color: colors.text,
          fontSize: 14,
          decoration: TextDecoration.none,
        ),
        child: Stack(
          children: [
            const _ActivityPageBackdrop(),
            SafeArea(
              bottom: false,
              child: CustomScrollView(
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
                  if (_loading && data == null)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CupertinoActivityIndicator()),
                    ),
                  if (_error != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: _OfflineErrorBlock(
                          message: _error!,
                          onRetry: _load,
                        ),
                      ),
                    ),
                  if (data != null) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: _AddressCard(
                          address: data.address,
                          onTap: _editAddress,
                        ),
                      ),
                    ),
                    if (inTransit.isNotEmpty || featured != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 26, 20, 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  inTransit.isNotEmpty ? '正在送达' : '收到的礼物',
                                  key: const ValueKey('gift-collection-header'),
                                  style: _titleStyle(
                                    context,
                                    16,
                                  ).copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(
                                inTransit.isNotEmpty
                                    ? '${inTransit.length} 份在途'
                                    : '${received.length} 份',
                                style: _mutedStyle(
                                  context,
                                  12,
                                ).copyWith(fontWeight: FontWeight.w400),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (inTransit.isNotEmpty)
                      SliverList.separated(
                        itemCount: inTransit.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final gift = inTransit[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _ShippingGiftCard(
                              key: ValueKey(gift.id),
                              api: widget.api,
                              gift: gift,
                              onTap: () => _showGift(gift),
                              onConfirmReceipt: () => _confirmReceipt(gift),
                            ),
                          );
                        },
                      )
                    else if (featured != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _GiftSpotlight(
                            api: widget.api,
                            gift: featured,
                            onTap: () => _showGift(featured),
                          ),
                        ),
                      ),
                    if (history.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  inTransit.isNotEmpty ? '收到的礼物' : '以往的礼物',
                                  style: _titleStyle(
                                    context,
                                    16,
                                  ).copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(
                                '${history.length} 份',
                                style: _mutedStyle(
                                  context,
                                  12,
                                ).copyWith(fontWeight: FontWeight.w400),
                              ),
                            ],
                          ),
                        ),
                      ),
                    for (final group in years.entries) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                          child: Text(
                            group.key == 0 ? '日期未记录' : '${group.key} 年',
                            style: _mutedStyle(
                              context,
                              12,
                            ).copyWith(fontWeight: FontWeight.w400),
                          ),
                        ),
                      ),
                      SliverList.separated(
                        itemCount: group.value.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _GiftListCard(
                            gift: group.value[index],
                            api: widget.api,
                            onTap: () => _showGift(group.value[index]),
                          ),
                        ),
                      ),
                    ],
                    if (received.isEmpty && inTransit.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                          child: Text(
                            '在途的心意，抵达后会收藏在这里',
                            textAlign: TextAlign.center,
                            style: _mutedStyle(
                              context,
                              12,
                            ).copyWith(fontWeight: FontWeight.w400),
                          ),
                        ),
                      ),
                    if (inTransit.isEmpty && featured == null)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _GiftEmptyCollection(),
                      ),
                  ],
                  if (inTransit.isNotEmpty || featured != null || data == null)
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: MediaQuery.paddingOf(context).bottom + 32,
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

// A true empty collection is a quiet part of the page, not a disabled card.
class _GiftEmptyCollection extends StatelessWidget {
  const _GiftEmptyCollection();

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return Padding(
      key: const ValueKey('gift-empty-collection'),
      padding: EdgeInsets.fromLTRB(
        32,
        40,
        32,
        48 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _kGiftAccent.withValues(alpha: .10),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [w.glass, _kGiftAccent.withValues(alpha: .08)],
                      ),
                      border: Border.all(color: w.glassBorder),
                    ),
                    child: const Icon(
                      CupertinoIcons.gift,
                      size: 34,
                      color: _kGiftAccent,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '还没有收到礼物',
              textAlign: TextAlign.center,
              style: _titleStyle(
                context,
                16,
              ).copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            Text(
              '每一份收到的心意\n都会在这里好好收藏',
              textAlign: TextAlign.center,
              style: _mutedStyle(
                context,
                14,
              ).copyWith(fontWeight: FontWeight.w400, height: 1.6),
            ),
          ],
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
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address?.display ?? '添加地址，方便接收礼物',
                    style: _mutedStyle(
                      context,
                      12,
                    ).copyWith(fontWeight: FontWeight.w400),
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
    super.key,
    required this.api,
    required this.gift,
    required this.onTap,
    this.onConfirmReceipt,
  });

  final CompanionApi api;
  final RealWorldGift gift;
  final VoidCallback onTap;
  final VoidCallback? onConfirmReceipt;

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
    if (oldWidget.gift != widget.gift || oldWidget.api != widget.api) {
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
    return _GiftSpotlight(
      api: widget.api,
      gift: widget.gift,
      onTap: widget.onTap,
      delivery: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GiftProgressBar(
            currentStep: _trackingStepIndex(widget.gift.status, events),
          ),
          if (_loading || _error != null || events.isEmpty) ...[
            const SizedBox(height: 14),
            if (_loading)
              const _TrackingLoadingBlock()
            else if (_error != null)
              _TrackingErrorBlock(onRetry: _loadTracking)
            else
              const _TrackingEmptyBlock(),
          ],
          if (widget.gift.canConfirmReceipt &&
              widget.onConfirmReceipt != null) ...[
            const SizedBox(height: 18),
            _ConfirmReceiptButton(
              key: ValueKey('gift-confirm-receipt-${widget.gift.id}'),
              onPressed: widget.onConfirmReceipt,
            ),
          ],
        ],
      ),
    );
  }
}

class _ConfirmReceiptButton extends StatelessWidget {
  const _ConfirmReceiptButton({
    super.key,
    required this.onPressed,
    this.busy = false,
  });

  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        borderRadius: BorderRadius.circular(16),
        color: _kGiftAccent,
        onPressed: busy ? null : onPressed,
        child: Text(
          busy ? '正在签收...' : '已收到快递，确认签收',
          style: const TextStyle(
            color: CupertinoColors.white,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

/// 道谢前让用户写几句话；取消返回 null。
Future<String?> _askThanksMessage(BuildContext context) async {
  final controller = TextEditingController();
  try {
    return await showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final text = controller.text.trim();
          return CupertinoAlertDialog(
            title: const Text('想对 TA 说点什么？'),
            content: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: CupertinoTextField(
                key: const ValueKey('gift-thanks-input'),
                controller: controller,
                autofocus: true,
                minLines: 3,
                maxLines: 5,
                maxLength: 300,
                placeholder: '比如：收到啦，好喜欢，谢谢你～',
                onChanged: (_) => setDialogState(() {}),
              ),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                key: const ValueKey('gift-thanks-send'),
                isDefaultAction: true,
                onPressed: text.isEmpty
                    ? null
                    : () => Navigator.of(dialogContext).pop(text),
                child: const Text('发送'),
              ),
            ],
          );
        },
      ),
    );
  } finally {
    controller.dispose();
  }
}

/// 确认签收：先二次确认（防误触提前揭晓），再调接口。成功返回已揭晓的礼物；
/// 用户取消或失败返回 null（失败会弹出原因）。
Future<GiftReceiptResult?> _confirmGiftReceipt(
  BuildContext context,
  CompanionApi api,
  RealWorldGift gift,
) async {
  final confirmed = await showCupertinoDialog<bool>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: const Text('确认已经收到礼物了吗？'),
      content: const Text('签收后就能拆开看看 TA 送了什么。还没拿到快递的话，先别点哦。'),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('还没收到'),
        ),
        CupertinoDialogAction(
          key: const ValueKey('gift-confirm-receipt-dialog-ok'),
          isDefaultAction: true,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('确认签收'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return null;
  try {
    return await api.confirmGiftReceipt(gift.id);
  } catch (error) {
    if (!context.mounted) return null;
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('签收没有成功'),
        content: Text(
          error is ApiException && error.message.trim().isNotEmpty
              ? error.message
              : '网络好像不太稳定，请稍后再试',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
    return null;
  }
}

String _giftNote(RealWorldGift gift) =>
    (gift.giftNote?.trim().isNotEmpty == true ? gift.giftNote : gift.giftReason)
        ?.trim() ??
    '';

class _GiftSpotlight extends StatelessWidget {
  const _GiftSpotlight({
    required this.api,
    required this.gift,
    required this.onTap,
    this.delivery,
  });
  final CompanionApi api;
  final RealWorldGift gift;
  final VoidCallback onTap;
  final Widget? delivery;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    final note = _giftNote(gift);
    return CupertinoButton(
      key: ValueKey('gift-spotlight-${gift.id}'),
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: _softCardDecoration(
              context,
              radius: 28,
            ).copyWith(boxShadow: []),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GiftThumb(gift: gift, size: 210, api: api, wide: true),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 18, 6, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (delivery == null) ...[
                        Text(
                          '最近收到 · ${_giftCollectionDate(gift.createdAt)}',
                          style: _mutedStyle(
                            context,
                            12,
                          ).copyWith(fontWeight: FontWeight.w400),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        gift.giftName,
                        style: _titleStyle(
                          context,
                          20,
                        ).copyWith(fontWeight: FontWeight.w600, height: 1.25),
                      ),
                      if (!gift.revealed && gift.isInTransit) ...[
                        const SizedBox(height: 8),
                        Text(
                          gift.canConfirmReceipt
                              ? '快递正在派送，收到后签收就能揭晓'
                              : '礼物还在路上，签收后揭晓',
                          style: _mutedStyle(
                            context,
                            13,
                          ).copyWith(fontWeight: FontWeight.w400),
                        ),
                      ],
                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.only(left: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: _kGiftAccent.withValues(alpha: .45),
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            note,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: w.inkSoft,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                      if (delivery != null) ...[
                        const SizedBox(height: 22),
                        delivery!,
                      ],
                      const SizedBox(height: 18),
                      Container(
                        height: .5,
                        color: w.inkFaint.withValues(alpha: .16),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              delivery != null ? '查看配送详情' : '打开这份心意',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: w.inkSoft,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                          Icon(
                            CupertinoIcons.arrow_right,
                            size: 17,
                            color: w.inkSoft,
                          ),
                        ],
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
    return CupertinoButton(
      key: ValueKey('gift-history-${gift.id}'),
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _softCardDecoration(
          context,
          radius: 22,
        ).copyWith(boxShadow: []),
        child: Row(
          children: [
            _GiftThumb(gift: gift, size: 64, api: api),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gift.giftName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _titleStyle(
                      context,
                      14,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _giftCollectionDate(gift.createdAt),
                    style: _mutedStyle(
                      context,
                      12,
                    ).copyWith(fontWeight: FontWeight.w400),
                  ),
                  if (_giftNote(gift).isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      _giftNote(gift),
                      style: _mutedStyle(
                        context,
                        12,
                      ).copyWith(fontWeight: FontWeight.w400),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: _W2b.resolve(context).inkFaint,
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
    required this.scrollController,
    this.justRevealed = false,
    this.onThanksSent,
  });

  final CompanionApi api;
  final ScrollController scrollController;
  final RealWorldGift gift;
  final bool justRevealed;
  final VoidCallback onChanged;
  final void Function(RealWorldGift gift, String message, String clientId)?
  onThanksSent;

  @override
  State<_GiftDetailSheet> createState() => _GiftDetailSheetState();
}

class _GiftDetailSheetState extends State<_GiftDetailSheet> {
  // 签收后在弹层里原地揭晓，所以礼物是本地状态而不是 widget.gift。
  late RealWorldGift _gift = widget.gift;
  late bool _justRevealed = widget.justRevealed;
  GiftTracking? _tracking;
  bool _loadingTracking = false;
  bool _sending = false;
  bool _confirming = false;
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
      final tracking = await widget.api.fetchGiftTracking(_gift.id);
      if (mounted) setState(() => _tracking = tracking);
    } catch (_) {
      if (mounted) setState(() => _trackingError = '物流同步失败');
    } finally {
      if (mounted) setState(() => _loadingTracking = false);
    }
  }

  Future<void> _confirmReceipt() async {
    if (_confirming) return;
    setState(() => _confirming = true);
    final result = await _confirmGiftReceipt(context, widget.api, _gift);
    if (!mounted) return;
    setState(() {
      _confirming = false;
      if (result != null) {
        _gift = result.gift;
        _justRevealed = !result.alreadyConfirmed;
      }
    });
    if (result == null) return;
    widget.onChanged();
    unawaited(_loadTracking());
  }

  Future<void> _sendThanks() async {
    if (_sending) return;
    final message = await _askThanksMessage(context);
    if (message == null || !mounted) return;
    final clientId = _thanksClientId;
    setState(() {
      _sending = true;
      _thanksError = null;
    });
    try {
      final onThanksSent = widget.onThanksSent;
      if (onThanksSent != null) {
        onThanksSent(_gift, message, clientId);
      } else {
        await widget.api.sendGiftThanks(
          _gift.id,
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

  Widget _footer(BuildContext context) {
    if (_gift.revealed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          if (_gift.thanksSentAt == null)
            CupertinoButton(
              borderRadius: BorderRadius.circular(16),
              color: _kGiftAccent,
              onPressed: _sending ? null : _sendThanks,
              child: Text(
                _sending ? '正在传达...' : '向 TA 说声谢谢',
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            )
          else
            const _SoftSuccessBar(text: '✓ 感谢已传达'),
        ],
      );
    }
    if (_gift.canConfirmReceipt) {
      return _ConfirmReceiptButton(
        key: ValueKey('gift-sheet-confirm-receipt-${_gift.id}'),
        busy: _confirming,
        onPressed: _confirmReceipt,
      );
    }
    final text = _gift.isInTransit
        ? '快递进入派送后，就可以在这里确认签收'
        : _gift.status == 'cancelled'
        ? '这份礼物已取消'
        : '这份礼物没能寄出';
    return Text(
      text,
      textAlign: TextAlign.center,
      style: _mutedStyle(context, 13).copyWith(fontWeight: FontWeight.w400),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gift = _gift;
    return _OfflineDetailSheetFrame(
      title: '礼物详情',
      compact: true,
      showCloseButton: false,
      scrollController: widget.scrollController,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          switchInCurve: Curves.easeOutBack,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween(begin: .92, end: 1.0).animate(animation),
              child: child,
            ),
          ),
          child: _GiftThumb(
            key: ValueKey('gift-thumb-${gift.id}-${gift.revealed}'),
            gift: gift,
            size: 210,
            wide: true,
            api: widget.api,
          ),
        ),
        if (_justRevealed && gift.revealed) ...[
          const SizedBox(height: 14),
          Text(
            '礼物揭晓啦',
            key: const ValueKey('gift-revealed-banner'),
            style: _mutedStyle(
              context,
              13,
            ).copyWith(color: _kGiftAccent, fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                gift.giftName,
                style: _titleStyle(
                  context,
                  20,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 10),
            _ShippingStateChip(text: _shippingStatusText(gift.status)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _giftLocalDate(gift.createdAt),
          style: _mutedStyle(context, 12).copyWith(fontWeight: FontWeight.w400),
        ),
        const SizedBox(height: 14),
        if (!gift.revealed && gift.isInTransit)
          Text(
            gift.canConfirmReceipt
                ? '快递正在派送，拿到包裹后点下方「确认签收」，就能看到 TA 送了什么。'
                : '这是一份神秘礼物，签收之前先保密。可以在下面看看它走到哪儿了。',
            style: _mutedStyle(
              context,
              13,
            ).copyWith(fontWeight: FontWeight.w400, height: 1.5),
          ),
        if ((gift.giftNote ?? '').isNotEmpty)
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
                Text(
                  'TA 的赠言',
                  style: _mutedStyle(
                    context,
                    12,
                  ).copyWith(fontWeight: FontWeight.w400),
                ),
                const SizedBox(height: 8),
                Text(
                  gift.giftNote!,
                  style: TextStyle(
                    color: AppColors.isDark(context)
                        ? const Color(0xFFFFC99E)
                        : const Color(0xFF7C5A42),
                    height: 1.5,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
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
        if (_visibleGiftCarrier(gift).isNotEmpty ||
            (gift.trackingNumber ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          SelectableText(
            [
              if (_visibleGiftCarrier(gift).isNotEmpty)
                _visibleGiftCarrier(gift),
              if ((gift.trackingNumber ?? '').trim().isNotEmpty)
                '运单号 ${gift.trackingNumber}',
            ].join(' · '),
            style: _mutedStyle(
              context,
              12,
            ).copyWith(fontWeight: FontWeight.w400),
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
        _footer(context),
      ],
    );
  }
}

class _GiftProgressBar extends StatelessWidget {
  const _GiftProgressBar({required this.currentStep});

  final int currentStep;

  // 用户只看到四个节点：下单 → 运输 → 派送 → 签收（揽收/打包都算运输）。
  static const _steps = [
    (label: '下单', icon: CupertinoIcons.doc_text_fill),
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
    return Semantics(
      selected: current,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            key: ValueKey('gift-progress-$label'),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? color : CupertinoColors.white,
              border: Border.all(color: color, width: 1.6),
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
              size: 13,
              color: active ? CupertinoColors.white : color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: active ? const Color(0xFFCE7333) : const Color(0xFFB0A090),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
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
          fontWeight: FontWeight.w600,
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
    super.key,
    required this.gift,
    required this.size,
    required this.api,
    this.wide = false,
  });

  final RealWorldGift gift;
  final double size;
  final bool wide;
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
              style: _mutedStyle(
                context,
                12,
              ).copyWith(fontWeight: FontWeight.w400),
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

  Widget _mystery(BuildContext context) {
    final w = _W2b.resolve(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [w.glass, _kGiftAccent.withValues(alpha: .16)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  CupertinoIcons.gift_fill,
                  size: widget.wide ? 48 : 28,
                  color: _kGiftAccent,
                ),
                Positioned(
                  right: widget.wide ? -10 : -7,
                  top: widget.wide ? -8 : -6,
                  child: Text(
                    '?',
                    style: TextStyle(
                      color: _kGiftAccent,
                      fontSize: widget.wide ? 22 : 14,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
            if (widget.wide) ...[
              const SizedBox(height: 12),
              Text(
                '签收后揭晓',
                style: _mutedStyle(
                  context,
                  12,
                ).copyWith(fontWeight: FontWeight.w400),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.gift.revealed) {
      final content = ClipRRect(
        borderRadius: BorderRadius.circular(widget.wide ? 22 : 16),
        child: _mystery(context),
      );
      return Semantics(
        label: '神秘礼物，签收后揭晓',
        child: widget.wide
            ? AspectRatio(aspectRatio: 1.6, child: content)
            : SizedBox(width: widget.size, height: widget.size, child: content),
      );
    }
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
                style: _titleStyle(context, 14).copyWith(
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  _giftLocalDate(event.occurredAt),
                  if ((event.location ?? '').isNotEmpty) event.location!,
                ].join(' · '),
                style: _mutedStyle(context, 12).copyWith(
                  fontWeight: FontWeight.w400,
                  decoration: TextDecoration.none,
                ),
              ),
              if ((event.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  event.description!,
                  style: _mutedStyle(context, 12).copyWith(
                    fontWeight: FontWeight.w400,
                    decoration: TextDecoration.none,
                  ),
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
          Text(
            '正在同步物流...',
            style: _mutedStyle(
              context,
              12,
            ).copyWith(fontWeight: FontWeight.w400),
          ),
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
      child: Text(
        '暂时还没有物流更新',
        style: _mutedStyle(context, 12).copyWith(fontWeight: FontWeight.w400),
      ),
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
          Expanded(
            child: Text(
              '物流同步失败',
              style: _mutedStyle(
                context,
                12,
              ).copyWith(fontWeight: FontWeight.w400),
            ),
          ),
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
                fontWeight: FontWeight.w600,
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
    return 3;
  }
  if (statuses.any((status) => status.contains('deliver'))) {
    return 2;
  }
  if (statuses.any(
    (status) =>
        status.contains('shipping') ||
        status.contains('transit') ||
        status.contains('packed') ||
        status.contains('picked'),
  )) {
    return 1;
  }
  return 0;
}

String _shippingStatusText(String status) {
  final normalized = status.toLowerCase();
  if (normalized.contains('delivered') || normalized == 'signed') return '已签收';
  if (normalized.contains('deliver')) return '派送中';
  if (normalized.contains('shipping') ||
      normalized.contains('transit') ||
      normalized.contains('packed') ||
      normalized.contains('picked')) {
    return '运输中';
  }
  if (normalized == 'pending_address') return '待填写地址';
  if (normalized == 'cancelled') return '已取消';
  if (normalized == 'failed' || normalized == 'skipped') return '未能寄出';
  if (normalized.contains('ordered')) return '已下单';
  return '处理中';
}

String _visibleGiftCarrier(RealWorldGift gift) {
  final carrier = gift.logisticsProvider?.trim() ?? '';
  return carrier.toLowerCase() == 'mock' ? '' : carrier;
}

/// 服务端时间是 UTC（带时区），展示要换成手机本地时间。
String _giftLocalDate(String raw) {
  final value = DateTime.tryParse(raw)?.toLocal();
  if (value == null) return raw;
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.year}年${value.month}月${value.day}日 $hour:$minute';
}

String _giftCollectionDate(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  return date == null ? '日期未知' : '${date.month}月${date.day}日';
}
