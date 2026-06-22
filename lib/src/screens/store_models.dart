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
  outfit('装扮'),
  tool('道具');

  const _ExchangeCategory(this.label);

  final String label;
}

enum _StoreCurrency { ticket, point }

enum _StoreItemKind {
  tea,
  cake,
  coffee,
  cola,
  flower,
  plush,
  capsuleSkin,
  chatFrame,
  bubble,
  backdrop,
  theme,
  stationery,
  checkinSkin,
  signCard,
  musicCoupon,
  gameCoupon,
  movieCoupon,
  musicBundle,
  gameBundle,
  movieBundle,
}

class _StoreProduct {
  const _StoreProduct({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.kind,
    this.yearlyPrice,
    this.imageAsset,
    this.badge,
    this.category,
  });

  final String title;
  final String subtitle;
  final int price;
  final _StoreItemKind kind;
  final int? yearlyPrice;
  final String? imageAsset;
  final String? badge;
  final _ExchangeCategory? category;
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
