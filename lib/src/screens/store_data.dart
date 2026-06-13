part of 'package:companion_flutter/main.dart';

const _bundleProducts = [
  _StoreProduct(
    title: '音乐畅听',
    subtitle: '每月音乐券、无打断收听和专属陪听权益',
    price: 15,
    yearlyPrice: 129,
    kind: _StoreItemKind.musicBundle,
    imageUrl:
        'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Headphone/3D/headphone_3d.png',
  ),
  _StoreProduct(
    title: '游戏畅玩',
    subtitle: '解锁更多小游戏次数和陪玩互动权益',
    price: 15,
    yearlyPrice: 129,
    kind: _StoreItemKind.gameBundle,
    imageUrl:
        'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Video%20game/3D/video_game_3d.png',
  ),
  _StoreProduct(
    title: '影视畅看',
    subtitle: '电影券与观影陪伴权益组合包',
    price: 25,
    yearlyPrice: 229,
    kind: _StoreItemKind.movieBundle,
    imageUrl:
        'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Clapper%20board/3D/clapper_board_3d.png',
  ),
];

const _exchangeProducts = [
  _StoreProduct(
    title: '奶茶',
    subtitle: '每日限购 0/1',
    price: 99,
    kind: _StoreItemKind.tea,
    category: _ExchangeCategory.gift,
    imageUrl:
        'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Bubble%20tea/3D/bubble_tea_3d.png',
  ),
  _StoreProduct(
    title: '提拉米苏',
    subtitle: '每日限购 0/1',
    price: 99,
    kind: _StoreItemKind.cake,
    category: _ExchangeCategory.gift,
    badge: '甜品',
    imageUrl:
        'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Shortcake/3D/shortcake_3d.png',
  ),
  _StoreProduct(
    title: '咖啡',
    subtitle: '每日限购 0/1',
    price: 288,
    kind: _StoreItemKind.coffee,
    category: _ExchangeCategory.gift,
    imageUrl:
        'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Hot%20beverage/3D/hot_beverage_3d.png',
  ),
  _StoreProduct(
    title: '可乐',
    subtitle: '每日限购 0/1',
    price: 512,
    kind: _StoreItemKind.cola,
    category: _ExchangeCategory.gift,
    imageUrl:
        'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Cup%20with%20straw/3D/cup_with_straw_3d.png',
  ),
  _StoreProduct(
    title: '鲜花',
    subtitle: '每日限购 0/1',
    price: 1314,
    kind: _StoreItemKind.flower,
    category: _ExchangeCategory.gift,
    imageUrl:
        'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Bouquet/3D/bouquet_3d.png',
  ),
  _StoreProduct(
    title: '毛绒玩具',
    subtitle: '每周限购 0/1',
    price: 9999,
    kind: _StoreItemKind.plush,
    category: _ExchangeCategory.gift,
    imageUrl:
        'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Teddy%20bear/3D/teddy_bear_3d.png',
  ),
  _StoreProduct(
    title: '胶囊皮肤',
    subtitle: '点击选择样式',
    price: 188,
    kind: _StoreItemKind.capsuleSkin,
    category: _ExchangeCategory.outfit,
    imageUrl:
        'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Gem%20stone/3D/gem_stone_3d.png',
  ),
  _StoreProduct(
    title: '聊天框皮肤',
    subtitle: '点击选择样式',
    price: 388,
    kind: _StoreItemKind.chatFrame,
    category: _ExchangeCategory.outfit,
    imageUrl:
        'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Framed%20picture/3D/framed_picture_3d.png',
  ),
  _StoreProduct(
    title: '聊天气泡',
    subtitle: '点击选择样式',
    price: 288,
    kind: _StoreItemKind.bubble,
    category: _ExchangeCategory.outfit,
    imageUrl:
        'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Speech%20balloon/3D/speech_balloon_3d.png',
  ),
  _StoreProduct(
    title: '聊天背景',
    subtitle: '点击选择样式',
    price: 588,
    kind: _StoreItemKind.backdrop,
    category: _ExchangeCategory.outfit,
    imageUrl:
        'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Sunrise/3D/sunrise_3d.png',
  ),
  _StoreProduct(
    title: '主题皮肤',
    subtitle: '点击选择样式',
    price: 888,
    kind: _StoreItemKind.theme,
    category: _ExchangeCategory.outfit,
    imageUrl:
        'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Artist%20palette/3D/artist_palette_3d.png',
  ),
  _StoreProduct(
    title: '信纸皮肤',
    subtitle: '点击选择样式',
    price: 688,
    kind: _StoreItemKind.stationery,
    category: _ExchangeCategory.outfit,
    imageUrl:
        'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Memo/3D/memo_3d.png',
  ),
  _StoreProduct(
    title: '打卡页面皮肤',
    subtitle: '点击选择样式',
    price: 1888,
    kind: _StoreItemKind.checkinSkin,
    category: _ExchangeCategory.outfit,
    imageUrl:
        'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Calendar/3D/calendar_3d.png',
  ),
  _StoreProduct(
    title: '补签卡',
    subtitle: '每日限购 0/3',
    price: 100,
    kind: _StoreItemKind.signCard,
    category: _ExchangeCategory.tool,
    imageUrl:
        'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Ticket/3D/ticket_3d.png',
  ),
  _StoreProduct(
    title: '音乐券',
    subtitle: '每周限购 0/10',
    price: 1888,
    kind: _StoreItemKind.musicCoupon,
    category: _ExchangeCategory.tool,
    imageUrl:
        'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Headphone/3D/headphone_3d.png',
  ),
  _StoreProduct(
    title: '游戏券',
    subtitle: '每周限购 0/10',
    price: 1888,
    kind: _StoreItemKind.gameCoupon,
    category: _ExchangeCategory.tool,
    imageUrl:
        'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Video%20game/3D/video_game_3d.png',
  ),
  _StoreProduct(
    title: '影视券',
    subtitle: '每周限购 0/10',
    price: 1888,
    kind: _StoreItemKind.movieCoupon,
    category: _ExchangeCategory.tool,
    imageUrl:
        'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Clapper%20board/3D/clapper_board_3d.png',
  ),
];

const _ticketRechargePacks = [
  _RechargePack(amount: 10, cost: 1, currency: _StoreCurrency.ticket),
  _RechargePack(amount: 80, cost: 8, currency: _StoreCurrency.ticket),
  _RechargePack(amount: 180, cost: 18, currency: _StoreCurrency.ticket),
  _RechargePack(amount: 300, cost: 30, currency: _StoreCurrency.ticket),
  _RechargePack(amount: 980, cost: 98, currency: _StoreCurrency.ticket),
  _RechargePack(amount: 1980, cost: 198, currency: _StoreCurrency.ticket),
];

const _pointRechargePacks = [
  _RechargePack(amount: 10, cost: 1, currency: _StoreCurrency.point),
  _RechargePack(amount: 80, cost: 8, currency: _StoreCurrency.point),
  _RechargePack(amount: 180, cost: 18, currency: _StoreCurrency.point),
  _RechargePack(amount: 300, cost: 30, currency: _StoreCurrency.point),
  _RechargePack(amount: 980, cost: 98, currency: _StoreCurrency.point),
  _RechargePack(amount: 1980, cost: 198, currency: _StoreCurrency.point),
];
