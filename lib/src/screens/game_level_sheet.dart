part of 'package:companion_flutter/main.dart';

const _hubGloveArt = '$_hubArt/gloves';
const _hubFrameFill = Color(0xFFECAF5D);
const _hubFrameEdge = Color(0xFF632601);

/// The design lays the gloves out as a 5×5 grid: a row per material, and the
/// same material in five colours across it. Material is the visible difference
/// (plain leather, ribbed nylon, fingerless tactical, segmented rock, etched
/// crystal), so the row is picked by the stage's name and the column by the
/// step's position inside that stage.
const _hubGloveMaterials = <String>[
  'leather',
  'nylon',
  'tactical',
  'rock',
  'crystal',
];

/// Keyword in the ladder's stage name → row of the grid.
const _hubMaterialByStage = <String, String>{
  '皮革': 'leather',
  '尼龙': 'nylon',
  '战术': 'tactical',
  '巨岩': 'rock',
  '玄铁': 'crystal',
};

/// Columns, in ladder order. The artwork's third step is orange on some rows
/// and gold on others, so the column is positional rather than colour-matched.
const _hubGloveColours = <String>['white', 'green', 'gold', 'blue', 'dark'];

String _hubGloveAsset(String material, int colourIndex) {
  final colour =
      _hubGloveColours[colourIndex.clamp(0, _hubGloveColours.length - 1)];
  return '$_hubGloveArt/${material}_$colour.png';
}

/// Falls back to the stage's position when an admin renames a stage away from
/// the seeded material names.
String _hubStageMaterial(String stageName, int stageIndex) {
  for (final entry in _hubMaterialByStage.entries) {
    if (stageName.contains(entry.key)) return entry.value;
  }
  return _hubGloveMaterials[stageIndex % _hubGloveMaterials.length];
}

/// The row's own icon is its last (darkest) step, exactly as in the design.
String _hubStageGlove(String stageName, int stageIndex) => _hubGloveAsset(
  _hubStageMaterial(stageName, stageIndex),
  _hubGloveColours.length - 1,
);

String _hubTierGlove(String stageName, int stageIndex, int colourIndex) =>
    _hubGloveAsset(_hubStageMaterial(stageName, stageIndex), colourIndex);

/// Column for a step named by its colour. The wallet reports the player's level
/// by name only, without its position in the ladder.
const _hubColumnByTierName = <String, int>{
  '白': 0,
  '绿': 1,
  '黄': 2,
  '蓝': 3,
  '黑': 4,
  '彩': 4,
};

/// Glove for the player's current level, for the hub's badge.
String hubLevelGlove(GameLevel? level) {
  if (level == null) return _hubGloveAsset(_hubGloveMaterials.first, 0);
  var column = 0;
  for (final entry in _hubColumnByTierName.entries) {
    if (level.tierName.contains(entry.key)) {
      column = entry.value;
      break;
    }
  }
  return _hubTierGlove(level.stageName, 0, column);
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

/// Strength of the frosted backdrop once the sheet is fully open.
const _hubSheetBlurSigma = 14.0;

Future<void> showHubLevelSheet(
  BuildContext context, {
  required Future<List<GameLevelTier>> tiers,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭',
    // The frosted layer below carries the dim, so the barrier itself stays
    // clear; two stacked scrims would double up during the transition.
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, _, _) => _HubLevelSheet(tiers: tiers),
    // Runs on every frame of the transition, so it reads the animation directly
    // rather than wrapping it again.
    transitionBuilder: (_, animation, _, child) {
      final curve = animation.status == AnimationStatus.reverse
          ? Curves.easeInCubic
          : Curves.easeOutCubic;
      final t = curve.transform(animation.value.clamp(0.0, 1.0));
      // A zero-sigma blur still costs a full-screen filter pass, so the frosted
      // layer only exists while the sheet is on screen.
      final backdrop = t <= 0.001
          ? const SizedBox.shrink()
          : BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: _hubSheetBlurSigma * t,
                sigmaY: _hubSheetBlurSigma * t,
              ),
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.28 * t),
                child: const SizedBox.expand(),
              ),
            );
      return Stack(
        fit: StackFit.expand,
        children: [
          // Taps have to reach the barrier underneath for dismissal, and a
          // ColoredBox is hit-test opaque on its own.
          IgnorePointer(child: backdrop),
          Opacity(
            opacity: t,
            child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
          ),
        ],
      );
    },
  );
}

class _HubLevelSheet extends StatelessWidget {
  const _HubLevelSheet({required this.tiers});

  final Future<List<GameLevelTier>> tiers;

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
  });

  final double scale;
  final _HubLevelStage stage;
  final int index;

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
            child: Image.asset(
              asset,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
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
                for (final (colourIndex, tier) in stage.tiers.indexed)
                  _HubLevelTierMark(
                    scale: s,
                    asset: _hubTierGlove(stage.name, index, colourIndex),
                    points: tier.cumulativePoints,
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
  });

  final double scale;
  final String asset;
  final int points;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return SizedBox(
      width: 26 * s,
      child: Column(
        children: [
          SizedBox(
            width: 18 * s,
            height: 22 * s,
            child: Image.asset(
              asset,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
          ),
          SizedBox(height: 1 * s),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$points',
              maxLines: 1,
              style: TextStyle(
                color: _hubInkSoft,
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
