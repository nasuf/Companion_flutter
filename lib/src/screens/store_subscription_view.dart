part of 'package:companion_flutter/main.dart';

class _SubscriptionStoreView extends StatefulWidget {
  const _SubscriptionStoreView({
    required this.selectedPlan,
    required this.onSelectPlan,
    required this.onSubscribe,
    required this.bottomSpace,
  });

  final int selectedPlan;
  final ValueChanged<int> onSelectPlan;
  final VoidCallback onSubscribe;
  final double bottomSpace;

  static const _plans = [
    ('月卡', '¥29', '¥39', null),
    ('季卡', '¥79', '¥99', '特惠推荐'),
    ('年卡', '¥249', '¥299', '最划算'),
  ];

  @override
  State<_SubscriptionStoreView> createState() => _SubscriptionStoreViewState();
}

class _SubscriptionStoreViewState extends State<_SubscriptionStoreView> {
  static const double _planCardWidth = 132;
  static const double _planGap = 12;

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

      final cardStart = index * (_planCardWidth + _planGap);
      final cardEnd = cardStart + _planCardWidth;
      final visibleStart = position.pixels;
      final visibleEnd = visibleStart + position.viewportDimension;
      double? targetOffset;

      if (cardStart < visibleStart) {
        targetOffset = cardStart;
      } else if (cardEnd > visibleEnd) {
        targetOffset = cardEnd - position.viewportDimension;
      }

      if (targetOffset == null) {
        return;
      }

      _planController.animateTo(
        targetOffset.clamp(position.minScrollExtent, position.maxScrollExtent),
        duration: const Duration(milliseconds: 260),
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
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 8, 20, widget.bottomSpace),
      children: [
        const _VipHeroCard(),
        const SizedBox(height: 18),
        const _MemberBenefitGrid(),
        const SizedBox(height: 12),
        SizedBox(
          height: 158,
          child: ListView.separated(
            controller: _planController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            padding: const EdgeInsets.only(right: 24),
            itemCount: _SubscriptionStoreView._plans.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final plan = _SubscriptionStoreView._plans[index];
              return _PlanCard(
                selected: widget.selectedPlan == index,
                title: plan.$1,
                price: plan.$2,
                origin: plan.$3,
                badge: plan.$4,
                onTap: () => _selectPlan(index),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '到期按所选周期自动续费，可随时取消',
          style: TextStyle(
            color: Color(0xFF53616E),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 20),
        _StorePrimaryButton(label: '立即开通', onPressed: widget.onSubscribe),
        const SizedBox(height: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleAgreement,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
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
                const Flexible(
                  child: Text(
                    '已阅读同意《会员协议与续费条款》',
                    style: TextStyle(
                      color: Color(0xFF66727E),
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
      ],
    );
  }
}
