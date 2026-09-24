part of 'package:companion_flutter/main.dart';

enum _StoreSection {
  subscription('订阅', CupertinoIcons.doc_text_fill),
  bundle('礼包', CupertinoIcons.gift_fill),
  exchange('兑换', CupertinoIcons.circle_grid_hex_fill),
  recharge('充值', CupertinoIcons.creditcard_fill);

  const _StoreSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

enum _ExchangeCategory {
  gift('礼物'),
  blind('盲盒'),
  outfit('装扮'),
  bundle('礼包');

  const _ExchangeCategory(this.label);

  final String label;
}

// 子 tab 显示顺序 = 声明顺序：饮品-鲜花-生活-饰品-配饰-数码-美食-奢享。
enum _GiftSubcategory {
  drink('饮品'),
  flower('鲜花'),
  life('生活'),
  jewelry('饰品'),
  accessory('配饰'),
  digital('数码'),
  food('美食'),
  luxury('奢享');

  const _GiftSubcategory(this.label);

  final String label;
}

enum _BundleKind { music, game, makeup, vip }

enum _StoreCurrency { ticket, point }

class _BundleTier {
  const _BundleTier({
    required this.id,
    required this.label,
    required this.ticketPrice,
    required this.grantAmount,
  });

  final String id;
  final String label;
  final int ticketPrice;
  final int grantAmount;
}

class _BundleOffer {
  const _BundleOffer({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.accent,
    this.imageAsset,
    this.tiers = const [],
    this.yuanPrice,
  });

  final _BundleKind kind;
  final String title;
  final String subtitle;
  final Color accent;
  final String? imageAsset;
  final List<_BundleTier> tiers;
  final int? yuanPrice;

  bool get isVipTrial => kind == _BundleKind.vip;
}

class _StoreProduct {
  const _StoreProduct({
    required this.title,
    required this.subtitle,
    required this.productKind,
    required this.memberPrice,
    required this.listPrice,
    this.imageAsset,
    this.category,
    this.giftSubcategory,
    this.contents,
  });

  final String title;
  final String subtitle;
  final String productKind;
  final int memberPrice;
  final int listPrice;
  final String? imageAsset;
  final _ExchangeCategory? category;
  final _GiftSubcategory? giftSubcategory;
  final String? contents;

  int priceFor({required bool isVip}) => isVip ? memberPrice : listPrice;
}

class _RechargePack {
  const _RechargePack({
    required this.amount,
    required this.cost,
    required this.currency,
  });

  final int amount;
  final int cost;
  final _StoreCurrency currency;
}
