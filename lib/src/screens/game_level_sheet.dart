part of 'package:companion_flutter/main.dart';

const _hubGloveArt = '$_hubArt/gloves';
const _hubFrameFill = Color(0xFFECAF5D);
const _hubFrameEdge = Color(0xFF632601);

/// Stage artwork keyed by the glove material in the ladder's copy. The kit has
/// no yellow or rainbow glove, so those steps borrow the nearest tone.
const _hubGloveByMaterial = <String, String>{
  '皮革': 'glove_1.png',
  '尼龙': 'glove_2.png',
  '战术': 'glove_3.png',
  '巨岩': 'glove_9.png',
  '玄铁': 'glove_11.png',
};

/// Artwork for a step inside a stage, keyed by its colour.
const _hubGloveByColour = <String, String>{
  '白': 'glove_2.png',
  '绿': 'glove_4.png',
  '黄': 'glove_6.png',
  '蓝': 'glove_7.png',
  '黑': 'glove_11.png',
  '彩': 'glove_10.png',
};

const _hubGloveFallback = <String>[
  'glove_1.png',
  'glove_2.png',
  'glove_3.png',
  'glove_9.png',
  'glove_11.png',
];

String _hubStageGlove(String stageName, int index) {
  for (final entry in _hubGloveByMaterial.entries) {
    if (stageName.contains(entry.key)) return '$_hubGloveArt/${entry.value}';
  }
  return '$_hubGloveArt/${_hubGloveFallback[index % _hubGloveFallback.length]}';
}

String _hubTierGlove(String tierName, String stageName, int index) {
  for (final entry in _hubGloveByColour.entries) {
    if (tierName.contains(entry.key)) return '$_hubGloveArt/${entry.value}';
  }
  return _hubStageGlove(stageName, index);
}

/// One stage of the ladder plus the tiers inside it.
class _HubLevelStage {
  const _HubLevelStage({required this.name, required this.tiers});

  final String name;
  final List<GameLevelTier> tiers;

  int get first => tiers.first.cumulativePoints;
  int get last => tiers.last.cumulativePoints;
}

List<_HubLevelStage> _hubGroupStages(List<GameLevelTier> tiers) {
  final ordered = [...tiers]
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  final stages = <_HubLevelStage>[];
  for (final tier in ordered) {
    if (stages.isNotEmpty && stages.last.name == tier.stageName) {
      stages.last.tiers.add(tier);
    } else {
      stages.add(_HubLevelStage(name: tier.stageName, tiers: [tier]));
    }
  }
  return stages;
}

Future<void> showHubLevelSheet(
  BuildContext context, {
  required Future<List<GameLevelTier>> tiers,
  required int lifetimeEarned,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭',
    barrierColor: Colors.black.withValues(alpha: 0.28),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, _, _) =>
        _HubLevelSheet(tiers: tiers, lifetimeEarned: lifetimeEarned),
    transitionBuilder: (_, animation, _, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.94, end: 1).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    ),
  );
}

class _HubLevelSheet extends StatelessWidget {
  const _HubLevelSheet({required this.tiers, required this.lifetimeEarned});

  final Future<List<GameLevelTier>> tiers;
  final int lifetimeEarned;

  static const String _intro = '通过棋类、休闲游戏积累积分，积分达标即可完成等级晋升，晋升标准如下：';
  static const String _footer =
      '平台内全部棋类、休闲小游戏共享统一积分池，胜利可获得积分；双人游戏仅完成通关可获取积分。游戏中途退出、失败无积分发放。\n\n'
      '伴生将针对不同段位等级分层筹备专属激励内容，包含小伙伴定制互动惊喜、专属权益福利等；段位等级越高，可解锁的激励内容越丰富。';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final s = constraints.maxWidth / _hubRefWidth;
        final media = MediaQuery.paddingOf(context);
        return Material(
          type: MaterialType.transparency,
          child: Center(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                28 * s,
                media.top + 20 * s,
                28 * s,
                media.bottom + 20 * s,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: _hubFrameFill,
                      borderRadius: BorderRadius.circular(13 * s),
                      border: Border.all(color: _hubFrameEdge, width: 3 * s),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.32),
                          blurRadius: 22,
                          offset: Offset(0, 10 * s),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(7 * s),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _hubCream,
                        borderRadius: BorderRadius.circular(13 * s),
                      ),
                      child: _body(s),
                    ),
                  ),
                  Positioned(
                    right: -6 * s,
                    top: -6 * s,
                    child: _HubCloseButton(
                      scale: s,
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body(double s) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(13 * s),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(30 * s, 20 * s, 30 * s, 24 * s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '等级说明',
              style: TextStyle(
                color: _hubInk,
                fontSize: 24 * s,
                height: 1,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.none,
              ),
            ),
            SizedBox(height: 17 * s),
            _paragraph(_intro, s),
            SizedBox(height: 16 * s),
            FutureBuilder<List<GameLevelTier>>(
              future: tiers,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 40 * s),
                    child: const Center(child: CupertinoActivityIndicator()),
                  );
                }
                final error = snapshot.error;
                if (error != null) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 24 * s),
                    child: _paragraph(
                      '等级表没拉到：${error is ApiException ? error.message : error}',
                      s,
                    ),
                  );
                }
                final stages = _hubGroupStages(snapshot.data ?? const []);
                if (stages.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 24 * s),
                    child: _paragraph('后台还没配置等级表。', s),
                  );
                }
                return Column(
                  children: [
                    for (var index = 0; index < stages.length; index += 1)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: index == stages.length - 1 ? 0 : 19 * s,
                        ),
                        child: _HubLevelStageRow(
                          scale: s,
                          stage: stages[index],
                          index: index,
                          lifetimeEarned: lifetimeEarned,
                        ),
                      ),
                  ],
                );
              },
            ),
            SizedBox(height: 19 * s),
            _paragraph(_footer, s),
          ],
        ),
      ),
    );
  }

  Widget _paragraph(String text, double s) => Text(
    text,
    style: TextStyle(
      color: _hubInkSoft,
      fontSize: 12 * s,
      height: 20 / 12,
      fontWeight: FontWeight.w900,
      decoration: TextDecoration.none,
    ),
  );
}

class _HubLevelStageRow extends StatelessWidget {
  const _HubLevelStageRow({
    required this.scale,
    required this.stage,
    required this.index,
    required this.lifetimeEarned,
  });

  final double scale;
  final _HubLevelStage stage;
  final int index;
  final int lifetimeEarned;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final asset = _hubStageGlove(stage.name, index);
    return SizedBox(
      height: 32 * s,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 27 * s,
            height: 32 * s,
            child: Image.asset(asset, fit: BoxFit.contain),
          ),
          SizedBox(width: 4 * s),
          SizedBox(
            width: 51 * s,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 3 * s),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    stage.name,
                    maxLines: 1,
                    style: TextStyle(
                      color: _hubInkSoft,
                      fontSize: 10 * s,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                SizedBox(height: 5 * s),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${stage.first}-${stage.last}',
                    maxLines: 1,
                    style: TextStyle(
                      color: _hubInkSoft,
                      fontSize: 10 * s,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final tier in stage.tiers)
                  _HubLevelTierMark(
                    scale: s,
                    asset: _hubTierGlove(tier.tierName, stage.name, index),
                    points: tier.cumulativePoints,
                    reached: lifetimeEarned >= tier.cumulativePoints,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HubLevelTierMark extends StatelessWidget {
  const _HubLevelTierMark({
    required this.scale,
    required this.asset,
    required this.points,
    required this.reached,
  });

  final double scale;
  final String asset;
  final int points;
  final bool reached;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return SizedBox(
      width: 26 * s,
      child: Column(
        children: [
          Opacity(
            opacity: reached ? 1 : 0.32,
            child: SizedBox(
              width: 18 * s,
              height: 22 * s,
              child: Image.asset(asset, fit: BoxFit.contain),
            ),
          ),
          SizedBox(height: 1 * s),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$points',
              maxLines: 1,
              style: TextStyle(
                color: _hubInkSoft.withValues(alpha: reached ? 1 : 0.55),
                fontSize: 7 * s,
                height: 1,
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

class _HubCloseButton extends StatelessWidget {
  const _HubCloseButton({required this.scale, required this.onTap});

  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final size = 34 * s;
    return _HubPress(
      onTap: onTap,
      pressedScale: 0.9,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _hubFrameFill,
          shape: BoxShape.circle,
          border: Border.all(color: _hubFrameEdge, width: 3 * s),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: Offset(0, 3 * s),
            ),
          ],
        ),
        child: Icon(CupertinoIcons.xmark, size: 16 * s, color: _hubFrameEdge),
      ),
    );
  }
}
