part of 'package:companion_flutter/main.dart';

class _ImageAttachmentBubble extends StatefulWidget {
  const _ImageAttachmentBubble({
    required this.attachments,
    required this.isMine,
    required this.onTap,
    this.authToken,
    this.recognized = false,
  });

  final List<ChatAttachment> attachments;
  final bool isMine;
  final ValueChanged<ChatAttachment> onTap;
  final String? authToken;

  /// 该图片已被识图命中：叠一层暖金描边微光 + 「偶遇一缕思绪」小字。从"未识别→已识别"
  /// 实时翻转时，先播 ~1.3s 识别仪式（暗角/扫光/星点/轻抬落幅）再落定态（spec §5.2/§5.3）。
  final bool recognized;

  @override
  State<_ImageAttachmentBubble> createState() => _ImageAttachmentBubbleState();
}

class _ImageAttachmentBubbleState extends State<_ImageAttachmentBubble>
    with SingleTickerProviderStateMixin {
  AnimationController? _ceremony;
  bool _playing = false;

  @override
  void didUpdateWidget(covariant _ImageAttachmentBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 仅在"发图后识图命中"的实时翻转时播仪式；历史消息(建来即已识别)直接落定态。
    if (!oldWidget.recognized && widget.recognized) {
      _ceremony ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1350),
      )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _playing = false);
          }
        });
      setState(() => _playing = true);
      _ceremony!.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ceremony?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMine = widget.isMine;
    final recognized = widget.recognized;
    final headers = widget.authToken?.isNotEmpty == true
        ? {'Authorization': 'Bearer ${widget.authToken}'}
        : null;
    final grid = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 270),
      child: Wrap(
        alignment: isMine ? WrapAlignment.end : WrapAlignment.start,
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final attachment in widget.attachments)
            GestureDetector(
              onTap: () => widget.onTap(attachment),
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isMine ? 17 : 3),
                  topRight: Radius.circular(isMine ? 3 : 17),
                  bottomLeft: const Radius.circular(17),
                  bottomRight: const Radius.circular(17),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.isDark(context)
                        ? _chatIncomingBubbleColor(context)
                        : AppColors.surfaceMuted,
                    // 识别命中的金框由外层 _recognizedColumn 统一施加（含定格 + 仪式），
                    // 这里始终画普通描边即可。
                    border: Border.all(color: _chatHairline(context), width: 1),
                  ),
                  // Bubble loads the server-side thumbnail (~10x smaller than
                  // the original) from the persistent disk cache; the original
                  // is only fetched by the full-screen viewer. memCacheWidth
                  // caps the decode at what the bubble actually renders.
                  child: Builder(
                    builder: (context) {
                      final width = _imageWidthFor(attachment);
                      final height = _imageHeightFor(attachment);
                      final dpr = MediaQuery.devicePixelRatioOf(context);
                      return ChatCachedImage(
                        url: chatMediaThumbUrl(attachment.url),
                        headers: headers,
                        width: width,
                        height: height,
                        fit: BoxFit.cover,
                        memCacheWidth: (width * dpr).round(),
                        // 骨架屏 shimmer (与 H5 一致): 灰底 + 左右扫过的亮带。
                        placeholder: (_) =>
                            _ImageSkeleton(width: width, height: height),
                        error: (_) => _imageFallback,
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (!recognized) return grid;
    if (_playing && _ceremony != null) {
      return AnimatedBuilder(
        animation: _ceremony!,
        builder: (_, __) => _recognizedColumn(grid, _ceremony!.value, isMine),
      );
    }
    return _recognizedColumn(grid, 1.0, isMine); // 定格态（持久）
  }

  // ── 识别命中：定格态(t=1) + 仪式动画(0<t<1)，复刻 demo bubble-img ──
  static const Color _goldBorder = Color(0xB8CD9B69); // rgba(205,155,105,.72)
  static const Color _goldCaption = Color(0xFFB88955);

  Widget _recognizedColumn(Widget grid, double t, bool isMine) {
    final settled = t >= 1.0;
    final lift = -3.0 * math.sin(math.pi * t.clamp(0.0, 1.0));
    final markLocal = ((t - 0.68) / 0.32).clamp(0.0, 1.0);
    final markOp = settled ? 1.0 : markLocal;
    final markScale =
        settled ? 1.0 : (0.55 + 0.55 * Curves.easeOutBack.transform(markLocal));
    final capLocal = ((t - 0.78) / 0.22).clamp(0.0, 1.0);
    final capOp = settled ? 1.0 : capLocal;

    return Column(
      crossAxisAlignment:
          isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Transform.translate(
          offset: Offset(0, lift),
          child: DecoratedBox(
            // 定格金框 + 柔和金晕（持久保留在聊天记录中）。
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: _goldBorder, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A6E4623),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  grid,
                  if (!settled) ..._ritualOverlays(t),
                  // 左上角标记（定格持久；仪式期临近结束弹入）。
                  Positioned(
                    top: 9,
                    left: 9,
                    child: Opacity(
                      opacity: markOp,
                      child: Transform.scale(scale: markScale, child: _markBadge()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // 「偶遇一缕思绪」说明（定格持久；仪式期淡入）。
        Opacity(
          opacity: capOp,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✨', style: TextStyle(fontSize: 10)),
              const SizedBox(width: 3),
              const Text(
                '偶遇一缕思绪',
                style: TextStyle(
                  color: _goldCaption,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _markBadge() {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xF0FFFCF8),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Color(0x24785028), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: const Text(
        '✦',
        style: TextStyle(
          color: Color(0xFFC0874E),
          fontSize: 13,
          height: 1,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  // 仪式叠层：暗角 + 自下而上金色扫光带/扫光线 + 星点（复刻 demo recog-*）。
  List<Widget> _ritualOverlays(double t) {
    final vignette = (0.85 * (1 - t)).clamp(0.0, 0.85);
    final scanY = 1.35 - 2.7 * t; // 从下(+)扫到上(-)
    final scanOp = _bump(t, 0.12, 0.78);
    return [
      if (vignette > 0.01)
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.1),
                  radius: 0.95,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF1C120A).withValues(alpha: 0.42 * (vignette / 0.85)),
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
          ),
        ),
      // 宽扫光带
      Positioned.fill(
        child: IgnorePointer(
          child: Align(
            alignment: Alignment(0, scanY),
            child: FractionallySizedBox(
              widthFactor: 1.16,
              heightFactor: 0.36,
              child: Opacity(
                opacity: scanOp * 0.9,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Color(0x00FFF5DC),
                        Color(0x38FFECC8),
                        Color(0xB8FFFFFF),
                        Color(0x33FFE6BE),
                        Color(0x00FFF5DC),
                      ],
                      stops: [0.0, 0.35, 0.52, 0.68, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      // 细扫光线
      Positioned.fill(
        child: IgnorePointer(
          child: Align(
            alignment: Alignment(0, scanY - 0.18),
            child: FractionallySizedBox(
              widthFactor: 0.88,
              heightFactor: 0.012,
              child: Opacity(
                opacity: scanOp,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0x00FFF8E6), Color(0xF2FFF8E6), Color(0x00FFF8E6)],
                    ),
                    boxShadow: [
                      BoxShadow(color: Color(0x8CFFDCAA), blurRadius: 10, spreadRadius: 2),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      for (final s in _sparkSpecs)
        Positioned.fill(
          child: IgnorePointer(
            child: Align(alignment: s.$1, child: _spark(t, s.$2)),
          ),
        ),
    ];
  }

  // (对齐位置, 起始时刻) —— 复刻 demo recog-spark s1..s6 的错峰迸发。
  static const List<(Alignment, double)> _sparkSpecs = [
    (Alignment(-0.72, -0.68), 0.36),
    (Alignment(0.70, -0.52), 0.43),
    (Alignment(-0.64, 0.56), 0.49),
    (Alignment(0.60, 0.40), 0.55),
    (Alignment(-0.80, -0.16), 0.61),
    (Alignment(0.76, 0.16), 0.67),
  ];

  Widget _spark(double t, double start) {
    final local = ((t - start) / 0.30).clamp(0.0, 1.0);
    if (local <= 0.0 || local >= 1.0) return const SizedBox.shrink();
    final op = math.sin(math.pi * local);
    return Opacity(
      opacity: op,
      child: Transform.scale(
        scale: 0.4 + 1.0 * local,
        child: Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Color(0xFFFFF8E8),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Color(0xF0FFDC8C), blurRadius: 10, spreadRadius: 3),
              BoxShadow(color: Color(0x8CFFBE64), blurRadius: 18, spreadRadius: 6),
            ],
          ),
        ),
      ),
    );
  }

  double _bump(double t, double inEnd, double outStart) {
    if (t < inEnd) return (t / inEnd).clamp(0.0, 1.0);
    if (t > outStart) return (1 - (t - outStart) / (1 - outStart)).clamp(0.0, 1.0);
    return 1.0;
  }

  double _imageWidthFor(ChatAttachment attachment) {
    final width = (attachment.width ?? 180).toDouble();
    final height = (attachment.height ?? 180).toDouble();
    if (width <= 0 || height <= 0) return 180;
    final ratio = width / height;
    return ratio >= 1 ? 210 : math.max(128, 168 * ratio);
  }

  double _imageHeightFor(ChatAttachment attachment) {
    final width = (attachment.width ?? 180).toDouble();
    final height = (attachment.height ?? 180).toDouble();
    if (width <= 0 || height <= 0) return 180;
    final ratio = width / height;
    return ratio >= 1 ? math.max(118, 210 / ratio) : 168;
  }

  Widget get _imageFallback {
    return SizedBox(
      width: 180,
      height: 150,
      child: Center(child: Icon(CupertinoIcons.photo, color: AppColors.muted)),
    );
  }
}


/// 聊天图片加载骨架屏 (与 H5 一致): 不透明灰底 + 一条从左到右滑过的亮带,
/// 循环 ~1.25s。加载完成后由 Image.network 替换。
class _ImageSkeleton extends StatefulWidget {
  const _ImageSkeleton({required this.width, required this.height});

  final double width;
  final double height;

  @override
  State<_ImageSkeleton> createState() => _ImageSkeletonState();
}

class _ImageSkeletonState extends State<_ImageSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          // pos: -1 (亮带在最左) → 1 (最右)。begin/end 各偏移 1 个盒宽,
          // 使亮带中心 (stop 0.5) 随 pos 从左缘扫到右缘。
          final pos = _controller.value * 2 - 1;
          final dark = AppColors.isDark(context);
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(pos - 1, 0),
                end: Alignment(pos + 1, 0),
                colors: dark
                    ? const [
                        Color(0xFF182331),
                        Color(0xFF243044),
                        Color(0xFF182331),
                      ]
                    : const [
                        Color(0xFFE9EDF2),
                        Color(0xFFF6F8FB),
                        Color(0xFFE9EDF2),
                      ],
                stops: const [0.2, 0.5, 0.8],
              ),
            ),
          );
        },
      ),
    );
  }
}
