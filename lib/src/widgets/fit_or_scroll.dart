part of 'package:companion_flutter/main.dart';

/// 整屏布局的小屏兜底：一屏放得下时按原样铺满（Spacer / Expanded 照常分配
/// 剩余高度）且不接受拖动；矮屏或系统字体调大放不下时，按内容实际高度展开并
/// 允许滚动，保证底部的按钮和链接都能滚到、点到。
///
/// 放不放得下按 [child] 的 max intrinsic height 判断，所以子树里不能有不支持
/// intrinsic 的组件（LayoutBuilder、shrinkWrap 的 ListView/GridView）。这类
/// 组件要么外面套定高 SizedBox，要么用 [FitOrScrollFloor] 包住它所在的
/// Expanded 区域。
class FitOrScroll extends StatelessWidget {
  const FitOrScroll({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      // 不挂 PrimaryScrollController：商城几个分区同在一个 PageView 里，共用会冲突。
      primary: false,
      // 放得下时滚动范围为 0，Clamping 不会拖出回弹。
      physics: const ClampingScrollPhysics(),
      slivers: [
        // padding 放在 SliverFillRemaining 里面：套在外层 SliverPadding 上时，
        // 它会先铺满整个视口再加底部留白，放得下也能多滚出一截。
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(padding: padding, child: child),
        ),
      ],
    );
  }
}

/// 固定列数、固定宽高比的非滚动网格，排法与 shrinkWrap 的 GridView 相同，
/// 但支持 intrinsic 测量，可以直接放进 [FitOrScroll]。
class FitOrScrollGrid extends StatelessWidget {
  const FitOrScrollGrid({
    super.key,
    required this.crossAxisCount,
    required this.childAspectRatio,
    this.mainAxisSpacing = 0,
    this.crossAxisSpacing = 0,
    required this.children,
  });

  final int crossAxisCount;
  final double childAspectRatio;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < children.length; row += crossAxisCount) ...[
          if (row > 0) SizedBox(height: mainAxisSpacing),
          Row(
            children: [
              for (var col = 0; col < crossAxisCount; col += 1) ...[
                if (col > 0) SizedBox(width: crossAxisSpacing),
                Expanded(
                  child: row + col < children.length
                      ? AspectRatio(
                          aspectRatio: childAspectRatio,
                          child: children[row + col],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// 给 [FitOrScroll] 里的 Expanded 区域报一个最小高度：子树本身不用支持
/// intrinsic，屏幕再矮这块也至少留 [minHeight]，不够时整页滚动。
class FitOrScrollFloor extends SingleChildRenderObjectWidget {
  const FitOrScrollFloor({
    super.key,
    required this.minHeight,
    required Widget super.child,
  });

  final double minHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderFitOrScrollFloor(minHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderFitOrScrollFloor renderObject,
  ) {
    renderObject.minHeight = minHeight;
  }
}

class RenderFitOrScrollFloor extends RenderProxyBox {
  RenderFitOrScrollFloor(this._minHeight);

  double _minHeight;
  set minHeight(double value) {
    if (_minHeight == value) return;
    _minHeight = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicHeight(double width) => _minHeight;

  @override
  double computeMaxIntrinsicHeight(double width) => _minHeight;
}
