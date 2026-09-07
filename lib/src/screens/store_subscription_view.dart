part of 'package:companion_flutter/main.dart';

class _SubscriptionStoreView extends StatefulWidget {
  const _SubscriptionStoreView({
    required this.selectedPlan,
    required this.onSelectPlan,
    required this.onSubscribe,
    required this.onRestore,
    required this.bottomSpace,
    required this.subscribeUi,
    this.activeProductId,
    this.autoRenewEnabled = false,
    this.autoRenewActive = false,
    this.subscriptionExpires,
    this.planPrices = const [],
    this.subscribing = false,
    this.isVip = false,
    this.vipUntil,
  });

  final int selectedPlan;
  final ValueChanged<int> onSelectPlan;
  final VoidCallback onSubscribe;
  final VoidCallback onRestore;
  final double bottomSpace;
  final StoreSubscribeUiState subscribeUi;
  final String? activeProductId;
  final bool autoRenewEnabled;
  final bool autoRenewActive;
  final DateTime? subscriptionExpires;

  /// 当前会员状态：驱动标题下方的状态行（是否已开通 / 有效期）。
  final bool isVip;
  final DateTime? vipUntil;

  /// StoreKit 本地化价格（与 _plans 同序）；缺失（未拉到/离线）回退到营销价。
  final List<String?> planPrices;

  /// 购买+校验进行中：按钮转圈禁用。
  final bool subscribing;

  static const _plans = [
    ('连续包月', '¥29', '¥39', '特惠推荐'),
    ('月卡', '¥39', '¥69', null),
    ('季卡', '¥89', '¥165', null),
    ('年卡', '¥249', '¥399', '最划算'),
  ];

  @override
  State<_SubscriptionStoreView> createState() => _SubscriptionStoreViewState();
}

class _SubscriptionStoreViewState extends State<_SubscriptionStoreView> {
  static const double _planCardWidth = 124;
  static const double _planGap = 12;
  static const double _planLeadPadding = 12;

  late final ScrollController _planController;
  bool _agreementChecked = false;

  @override
  void initState() {
    super.initState();
    _planController = ScrollController();
  }

  @override
  void dispose() {
    _planController.dispose();
    super.dispose();
  }

  void _selectPlan(int index) {
    widget.onSelectPlan(index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_planController.hasClients) {
        return;
      }

      final position = _planController.position;
      if (!position.hasViewportDimension) {
        return;
      }

      // 把选中卡尽量居中：两侧自然露出相邻卡片的一角——选季卡能带出年卡，
      // 选月卡能带出连续包月。末端用 clamp 收住，不会滚过头。
      // _planLeadPadding 是横向列表的左内边距，卡片在滚动内容里的起点。
      final cardCenter =
          _planLeadPadding +
          index * (_planCardWidth + _planGap) +
          _planCardWidth / 2;
      final target = (cardCenter - position.viewportDimension / 2).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );

      if ((_planController.offset - target).abs() < 0.5) {
        return;
      }

      _planController.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _toggleAgreement() {
    setState(() {
      _agreementChecked = !_agreementChecked;
    });
  }

  @override
  Widget build(BuildContext context) {
    const edge = EdgeInsets.symmetric(horizontal: 12);
    final currentPlanIndex = planIndexForProductId(widget.activeProductId);
    final detailLine = buildMembershipDetailLine(
      isVip: widget.isVip,
      vipUntil: widget.vipUntil,
      subscriptionExpires: widget.subscriptionExpires,
      autoRenewEnabled: widget.autoRenewEnabled,
      autoRenewActive: widget.autoRenewActive,
      selectedPlanIndex: widget.selectedPlan,
      planHint: widget.subscribeUi.hintText,
    );
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(8, 8, 8, widget.bottomSpace),
      children: [
        const SizedBox(height: 4),
        const Padding(padding: edge, child: _VipTitle()),
        const SizedBox(height: 6),
        Padding(
          padding: edge,
          child: _MembershipStatusBanner(
            headline: buildMembershipHeadline(
              isVip: widget.isVip,
              activeProductId: widget.activeProductId,
            ),
            detailLine: detailLine,
          ),
        ),
        const SizedBox(height: 10),
        const _MemberBenefitGrid(),
        const SizedBox(height: 12),
        SizedBox(
          height: 148,
          child: ListView.separated(
            controller: _planController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            padding: const EdgeInsets.fromLTRB(12, 0, 24, 0),
            itemCount: _SubscriptionStoreView._plans.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final plan = _SubscriptionStoreView._plans[index];
              final localized = index < widget.planPrices.length
                  ? widget.planPrices[index]
                  : null;
              return _PlanCard(
                selected: widget.selectedPlan == index,
                isCurrentPlan: currentPlanIndex == index,
                title: plan.$1,
                price: localized ?? plan.$2,
                origin: plan.$3,
                badge: plan.$4,
                onTap: () => _selectPlan(index),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: edge,
          child: _StorePrimaryButton(
            label: widget.subscribeUi.buttonLabel,
            // 未勾选会员协议则置灰不可点（合规要求用户明示同意续费条款）。
            onPressed: _agreementChecked ? widget.onSubscribe : null,
            loading: widget.subscribing,
            height: 56,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleAgreement,
          child: Padding(
            padding: edge.add(const EdgeInsets.symmetric(vertical: 6)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 19,
                  height: 19,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _agreementChecked
                        ? AppColors.accent
                        : Colors.transparent,
                    border: Border.all(
                      color: _agreementChecked
                          ? AppColors.accent
                          : const Color(0xFFB7C3CF),
                      width: 1.3,
                    ),
                    boxShadow: _agreementChecked
                        ? [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.18),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: _agreementChecked
                      ? const Icon(Icons.check, color: Colors.white, size: 13)
                      : null,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '已阅读同意《会员协议与续费条款》',
                    style: TextStyle(
                      color: _W2b.resolve(context).inkSoft,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 恢复购买：Apple 审核硬性要求（有订阅必须提供）。换设备/重装后据此
        // 恢复订阅态；消耗型钞票不参与恢复（符合预期）。
        Center(
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
            minimumSize: Size.zero,
            onPressed: widget.subscribing ? null : widget.onRestore,
            child: Text(
              '恢复购买',
              style: TextStyle(
                color: _W2b.resolve(context).inkSoft,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 标题下的会员状态：会员类型 + 有效期/续费说明（最多两行，不额外占套餐下方空间）。
class _MembershipStatusBanner extends StatelessWidget {
  const _MembershipStatusBanner({
    required this.headline,
    this.detailLine,
  });

  final String headline;
  final String? detailLine;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    final isActive = !headline.startsWith('尚未开通');
    final dotColor = isActive ? const Color(0xFF16C6D4) : w.inkSoft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                headline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isActive ? w.ink : w.inkSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
        if (detailLine != null && detailLine!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 15),
            child: Text(
              detailLine!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: w.inkSoft,
                fontSize: 11,
                height: 1.35,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
