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

class _ShippingGiftCard extends StatelessWidget {
  const _ShippingGiftCard({required this.gift, required this.onTap});

  final RealWorldGift gift;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _softCardDecoration(context, radius: 22).copyWith(
          border: Border.all(color: const Color(0xFF7EC5E1), width: 1.4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '• 礼物正在向你飞奔',
              style: _titleStyle(
                context,
                17,
              ).copyWith(color: const Color(0xFF4C9DBC)),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                for (var i = 0; i < 5; i++) ...[
                  _ProgressDot(
                    active: i < 3,
                    icon: i == 2 ? CupertinoIcons.car_detailed : null,
                  ),
                  if (i != 4)
                    const Expanded(
                      child: Divider(thickness: 2, color: Color(0xFF8CCAE3)),
                    ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  '打包',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6DAFC8),
                  ),
                ),
                Text(
                  '签收',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF9AA6AF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '追踪详情 →',
                style: TextStyle(
                  color: AppColors.of(context).accent,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
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
                ),
              ),
            ),
          const SizedBox(height: 14),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _loadingTracking ? null : _loadTracking,
            child: Text(
              _loadingTracking ? '加载中...' : '物流追踪详情',
              style: TextStyle(
                color: colors.accent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (_tracking != null) _TrackingTimeline(events: _tracking!.events),
          const SizedBox(height: 12),
          if (widget.gift.thanksSentAt == null) ...[
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                borderRadius: BorderRadius.circular(16),
                color: colors.accent,
                onPressed: _sending ? null : _sendThanks,
                child: Text(
                  _sending ? '发送中...' : '🤝 说声谢谢',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ] else
            const _SoftSuccessBar(text: '✓ 感谢已传达'),
        ],
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
  const _TrackingTimeline({required this.events});

  final List<GiftTrackingEvent> events;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.of(context).surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (final event in events)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.only(top: 3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF7FC5E5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.title, style: _titleStyle(context, 14)),
                        const SizedBox(height: 3),
                        Text(
                          '${_shortDate(event.occurredAt)} ${event.location ?? ''}',
                          style: _mutedStyle(context, 12),
                        ),
                      ],
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

class _ProgressDot extends StatelessWidget {
  const _ProgressDot({required this.active, this.icon});

  final bool active;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF7EC5E1) : const Color(0xFFD6DEE4);
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? color : Colors.white,
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(
        icon ?? CupertinoIcons.check_mark,
        size: 15,
        color: active ? Colors.white : color,
      ),
    );
  }
}
